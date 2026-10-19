-- El trabajo incompleto vive fuera del catálogo y conserva incluso texto inválido.
create table public.admin_guided_work_drafts (
  id uuid primary key,
  owner_id uuid not null references auth.users(id) on delete cascade,
  base_program_id uuid references public.guided_programs(id),
  state jsonb not null check (jsonb_typeof(state) = 'object' and octet_length(state::text) <= 524288),
  revision bigint not null default 1 check (revision > 0),
  updated_at timestamptz not null default now(),
  finalized_program_id uuid references public.guided_programs(id),
  final_request jsonb,
  discarded_at timestamptz
);
create index admin_guided_work_owner_updated on public.admin_guided_work_drafts(owner_id, updated_at desc);
create index admin_guided_work_base on public.admin_guided_work_drafts(base_program_id);
create index admin_guided_work_finalized on public.admin_guided_work_drafts(finalized_program_id);
alter table public.admin_guided_work_drafts enable row level security;
revoke all on public.admin_guided_work_drafts from anon, authenticated;
grant select on public.admin_guided_work_drafts to authenticated;
create policy admin_guided_work_read on public.admin_guided_work_drafts for select to authenticated
  using (owner_id = (select auth.uid()) and (select public.is_admin()));

create function public.save_admin_guided_work(
  p_id uuid, p_revision bigint, p_state jsonb, p_base_program_id uuid default null
) returns jsonb language plpgsql security definer set search_path = '' as $$
declare v public.admin_guided_work_drafts;
begin
  if auth.uid() is null or not public.is_admin() then raise insufficient_privilege; end if;
  if p_id is null or p_revision is null or p_revision < 0 or p_state is null
    or jsonb_typeof(p_state) <> 'object' or octet_length(p_state::text) > 524288
    or p_state->>'schema' is distinct from '1' then
    raise exception 'Borrador de trabajo inválido.' using errcode='22023';
  end if;
  -- Serializa también la primera inserción y sus reintentos tras perder la respuesta.
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(p_id::text, 1));
  select * into v from public.admin_guided_work_drafts where id=p_id for update;
  if found then
    if v.owner_id <> auth.uid() then raise insufficient_privilege; end if;
    if v.finalized_program_id is not null or v.discarded_at is not null then
      raise exception 'Este trabajo ya está cerrado.' using errcode='40001';
    end if;
    if v.base_program_id is distinct from p_base_program_id then
      raise exception 'No se puede cambiar el programa de origen.' using errcode='22023';
    end if;
    if v.state=p_state and (v.revision=p_revision or v.revision=p_revision+1) then return to_jsonb(v); end if;
    if v.revision <> p_revision then
      raise exception 'Otra pestaña ha actualizado el borrador.' using errcode='40001';
    end if;
    update public.admin_guided_work_drafts set state=p_state, revision=revision+1, updated_at=clock_timestamp()
      where id=p_id returning * into v;
  else
    if p_revision <> 0 then raise exception 'Borrador no disponible.' using errcode='40001'; end if;
    insert into public.admin_guided_work_drafts(id,owner_id,base_program_id,state)
      values(p_id,auth.uid(),p_base_program_id,p_state) returning * into v;
  end if;
  return to_jsonb(v);
end $$;

create function public.finalize_admin_guided_work(
  p_id uuid, p_revision bigint, p_content jsonb, p_category_ids uuid[], p_primary_category_id uuid default null
) returns uuid language plpgsql security definer set search_path = '' as $$
declare v public.admin_guided_work_drafts; result uuid; request jsonb;
begin
  if auth.uid() is null or not public.is_admin() then raise insufficient_privilege; end if;
  select * into v from public.admin_guided_work_drafts where id=p_id for update;
  if not found or v.owner_id <> auth.uid() then raise insufficient_privilege; end if;
  request:=jsonb_build_object('content',p_content,'categories',p_category_ids,'primary',p_primary_category_id);
  if v.finalized_program_id is not null and v.final_request=request then return v.finalized_program_id; end if;
  if v.finalized_program_id is not null or v.discarded_at is not null or v.revision is distinct from p_revision then
    raise exception 'Este trabajo ha cambiado o ya está cerrado.' using errcode='40001';
  end if;
  -- Conserva todas las validaciones y el versionado existentes en una sola transacción.
  result:=public.save_guided_program(p_content,v.base_program_id,p_category_ids,p_primary_category_id);
  update public.admin_guided_work_drafts set finalized_program_id=result, final_request=request, updated_at=clock_timestamp()
    where id=p_id;
  return result;
end $$;

create function public.discard_admin_guided_work(p_id uuid, p_revision bigint)
returns void language plpgsql security definer set search_path = '' as $$
declare v public.admin_guided_work_drafts;
begin
  if auth.uid() is null or not public.is_admin() then raise insufficient_privilege; end if;
  select * into v from public.admin_guided_work_drafts where id=p_id for update;
  if not found or v.owner_id <> auth.uid() then raise insufficient_privilege; end if;
  if v.revision is distinct from p_revision or v.finalized_program_id is not null then
    raise exception 'El trabajo ha cambiado o ya se guardó en el catálogo.' using errcode='40001';
  end if;
  update public.admin_guided_work_drafts set discarded_at=clock_timestamp() where id=p_id;
end $$;

revoke all on function public.save_admin_guided_work(uuid,bigint,jsonb,uuid) from public, anon;
revoke all on function public.finalize_admin_guided_work(uuid,bigint,jsonb,uuid[],uuid) from public, anon;
revoke all on function public.discard_admin_guided_work(uuid,bigint) from public, anon;
grant execute on function public.save_admin_guided_work(uuid,bigint,jsonb,uuid) to authenticated;
grant execute on function public.finalize_admin_guided_work(uuid,bigint,jsonb,uuid[],uuid) to authenticated;
grant execute on function public.discard_admin_guided_work(uuid,bigint) to authenticated;
