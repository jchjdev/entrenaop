begin;

create schema admin_work_private;
revoke all on schema admin_work_private from public,anon,authenticated;
grant usage on schema admin_work_private to authenticated;
create table admin_work_private.session_work (
  id uuid primary key,
  owner_id uuid not null references auth.users(id) on delete cascade,
  origin jsonb not null,
  state jsonb not null,
  revision bigint not null check(revision>0),
  result_id uuid,
  discarded boolean not null default false,
  updated_at timestamptz not null default clock_timestamp(),
  check(jsonb_typeof(origin)='object' and octet_length(origin::text)<4096),
  check(jsonb_typeof(state)='object' and octet_length(state::text)<=524288)
);
create index session_work_owner on admin_work_private.session_work(owner_id,updated_at desc);
create index session_work_base on admin_work_private.session_work((origin->>'baseId')) where not discarded and result_id is null;
alter table admin_work_private.session_work enable row level security;
revoke all on admin_work_private.session_work from public,anon,authenticated;

create function admin_work_private.check_owner(p_expected_owner uuid) returns void
language plpgsql stable security invoker set search_path='' as $$
begin
  if auth.uid() is null or p_expected_owner is distinct from auth.uid()
    or not coalesce(public.is_admin(),false)
    or (auth.jwt()->>'aal') is distinct from 'aal2'
    or not exists(select 1 from auth.mfa_factors where user_id=auth.uid() and factor_type='totp' and status='verified')
    then raise insufficient_privilege; end if;
end $$;

create function admin_work_private.read_work(p_expected_owner uuid,p_id uuid default null)
returns jsonb language plpgsql stable security definer set search_path='' as $$
begin
  perform admin_work_private.check_owner(p_expected_owner);
  if p_id is not null then
    return (select to_jsonb(w) from admin_work_private.session_work w
      where w.id=p_id and w.owner_id=auth.uid());
  end if;
  -- Lista acotada: incluye recibos de hijos cuyo enlace puede seguir pendiente.
  return coalesce((select jsonb_agg((to_jsonb(w)-'state') || jsonb_build_object('state',
    jsonb_build_object('editor',jsonb_build_object('nameText',left(w.state->'editor'->>'nameText',160)))
      || case when w.state ? 'intent' then '{"intent":true}'::jsonb else '{}'::jsonb end)
    order by w.updated_at desc) from (
    select w.* from admin_work_private.session_work w
    where w.owner_id=auth.uid() and not w.discarded
      and (w.result_id is null or exists(select 1 from public.admin_guided_work_drafts p,
        jsonb_array_elements(p.state->'phases') phase where p.owner_id=auth.uid()
        and p.id=(w.origin->>'parentWorkId')::uuid and phase->'sessionWorks' ? w.id::text))
    order by w.updated_at desc limit 100
  ) w),'[]'::jsonb);
end $$;

create function admin_work_private.save_work(
  p_expected_owner uuid,p_id uuid,p_revision bigint,p_origin jsonb,p_state jsonb
) returns jsonb language plpgsql security definer set search_path='' as $$
declare w admin_work_private.session_work; parent public.admin_guided_work_drafts;
begin
  perform admin_work_private.check_owner(p_expected_owner);
  perform pg_advisory_xact_lock(hashtextextended(auth.uid()::text,72));
  if p_id is null or p_revision is null or p_revision<0 or p_origin is null or p_state is null
    or jsonb_typeof(p_origin)<>'object' or jsonb_typeof(p_state)<>'object'
    or octet_length(p_state::text)>524288 or octet_length(p_origin::text)>=4096
    or p_state->>'schema' is distinct from '1'
    or (p_state-array['schema','editor','context','intent'])<>'{}'::jsonb
    or ((p_state->'context')-'showInLibrary')<>'{}'::jsonb
    or p_state->'editor'->>'schema' is distinct from '1'
    or jsonb_typeof(p_state->'context'->'showInLibrary') is distinct from 'boolean'
    or jsonb_typeof(p_state->'editor') is distinct from 'object'
    or (p_state ? 'intent' and jsonb_typeof(p_state->'intent')<>'object')
    or (p_origin - array['baseId','programId','parentWorkId','phaseId','positionId','duplicate'])<>'{}'::jsonb
    or jsonb_typeof(p_origin->'duplicate') is distinct from 'boolean' then
    raise exception 'Trabajo de sesión incompatible.' using errcode='22023';
  end if;
  if p_origin->>'parentWorkId' is not null then
    select * into parent from public.admin_guided_work_drafts
      where id=(p_origin->>'parentWorkId')::uuid for update;
    if not found or parent.owner_id<>auth.uid() or parent.discarded_at is not null
      or exists(select 1 from public.guided_programs where id=parent.base_program_id and trashed_at is not null)
      or parent.finalized_program_id is not null or not exists(
        select 1 from jsonb_array_elements(parent.state->'phases') phase
        where phase->>'phaseId'=p_origin->>'phaseId'
          and phase->'sessionWorks'->p_id::text=p_origin
      ) then
      raise exception 'El destino de la sesión ha cambiado. Conserva el trabajo.' using errcode='40001';
    end if;
  elsif p_origin->>'phaseId' is not null or p_origin->>'positionId' is not null then
    raise exception 'Destino de sesión inválido.' using errcode='22023';
  end if;
  if p_origin->>'baseId' is not null and not exists(
    select 1 from public.workout_templates t join public.program_workout_templates l on l.template_id=t.id
    where t.id=(p_origin->>'baseId')::uuid and t.origin='system' and t.owner_user_id is null
      and t.trashed_at is null and t.status in ('draft','published')
      and l.program_id is not distinct from p_origin->>'programId'
  ) then raise exception 'La sesión de origen no está disponible.' using errcode='22023'; end if;
  perform pg_advisory_xact_lock(hashtextextended(p_id::text,71));
  select * into w from admin_work_private.session_work where id=p_id for update;
  if found then
    if w.owner_id<>auth.uid() then raise insufficient_privilege; end if;
    if w.origin<>p_origin or w.discarded or w.result_id is not null then
      raise exception 'Trabajo cerrado o cambiado.' using errcode='40001'; end if;
    if w.revision=p_revision+1 and w.state=p_state then return to_jsonb(w); end if;
    if w.revision<>p_revision then raise exception 'Otra pestaña ha cambiado el trabajo.' using errcode='40001'; end if;
    if w.state ? 'intent' and w.state<>p_state then
      raise exception 'Confirma o cancela la intención antes de editar.' using errcode='40001'; end if;
    update admin_work_private.session_work set state=p_state,revision=revision+1,updated_at=clock_timestamp()
      where id=p_id returning * into w;
  else
    if p_revision<>0 then raise exception 'Trabajo no disponible.' using errcode='40001'; end if;
    if (select count(*) from admin_work_private.session_work where owner_id=auth.uid())>=1000 then
      raise exception 'Se ha alcanzado el límite técnico de trabajos conservados.' using errcode='22023'; end if;
    insert into admin_work_private.session_work(id,owner_id,origin,state,revision)
      values(p_id,auth.uid(),p_origin,p_state,1) returning * into w;
  end if;
  return to_jsonb(w);
end $$;

create function admin_work_private.finish_work(p_expected_owner uuid,p_id uuid,p_revision bigint)
returns uuid language plpgsql security definer set search_path='' as $$
declare w admin_work_private.session_work; result uuid; payload jsonb; parent_id uuid;
begin
  perform admin_work_private.check_owner(p_expected_owner);
  -- Mismo orden que guardar: programa padre antes de trabajo hijo.
  select (origin->>'parentWorkId')::uuid into parent_id
    from admin_work_private.session_work where id=p_id and owner_id=auth.uid();
  if parent_id is not null then
    perform 1 from public.admin_guided_work_drafts where id=parent_id and owner_id=auth.uid()
      and discarded_at is null and finalized_program_id is null
      and not exists(select 1 from public.guided_programs where id=base_program_id and trashed_at is not null) for update;
    if not found then raise exception 'El programa no está abierto.' using errcode='40001'; end if;
  end if;
  select * into w from admin_work_private.session_work where id=p_id for update;
  if not found or w.owner_id<>auth.uid() then raise insufficient_privilege; end if;
  if w.result_id is not null then return w.result_id; end if;
  if w.discarded or w.revision is distinct from p_revision or not(w.state ? 'intent') then
    raise exception 'Revisa el trabajo antes de guardar.' using errcode='40001'; end if;
  payload:=(w.state->'intent') || jsonb_build_object('show_in_library',(w.state->'context'->>'showInLibrary')::boolean);
  begin
    if w.origin->>'baseId' is not null and not (w.origin->>'duplicate')::boolean then
      result:=public.revise_admin_workout((w.origin->>'baseId')::uuid,payload);
    else
      result:=public.create_admin_workout_draft(w.origin->>'programId',payload);
    end if;
  exception when raise_exception then
    -- Los validadores heredados usan P0001. Es un rechazo definitivo y atómico,
    -- no una respuesta de red incierta; permite corregir el formulario conservado.
    raise exception 'No se pudo validar la receta. Vuelve a editar el trabajo.' using errcode='22023';
  end;
  update admin_work_private.session_work set result_id=result,updated_at=clock_timestamp() where id=p_id;
  return result;
end $$;

create function admin_work_private.reopen_work(p_expected_owner uuid,p_id uuid,p_revision bigint)
returns jsonb language plpgsql security definer set search_path='' as $$
declare w admin_work_private.session_work;
begin
  perform admin_work_private.check_owner(p_expected_owner);
  select * into w from admin_work_private.session_work where id=p_id for update;
  if not found or w.owner_id<>auth.uid() then raise insufficient_privilege; end if;
  if w.result_id is not null or w.discarded then
    raise exception 'El trabajo ya está cerrado.' using errcode='40001'; end if;
  if w.revision=p_revision+1 and not(w.state ? 'intent') then return to_jsonb(w); end if;
  if w.revision is distinct from p_revision then raise exception 'El trabajo ha cambiado.' using errcode='40001'; end if;
  update admin_work_private.session_work set state=state-'intent',revision=revision+1,updated_at=clock_timestamp()
    where id=p_id returning * into w;
  return to_jsonb(w);
end $$;

create function admin_work_private.discard_work(p_expected_owner uuid,p_id uuid,p_revision bigint)
returns void language plpgsql security definer set search_path='' as $$
declare w admin_work_private.session_work;
begin
  perform admin_work_private.check_owner(p_expected_owner);
  select * into w from admin_work_private.session_work where id=p_id for update;
  if not found or w.owner_id<>auth.uid() then raise insufficient_privilege; end if;
  if w.result_id is not null or w.revision is distinct from p_revision then
    raise exception 'El trabajo ha cambiado o ya está guardado.' using errcode='40001'; end if;
  update admin_work_private.session_work set discarded=true,updated_at=clock_timestamp() where id=p_id;
end $$;

-- Evita que una versión anterior del editor pierda los trabajos hijos al guardar.
create function admin_work_private.guard_parent() returns trigger
language plpgsql security definer set search_path='' as $$
declare phase jsonb; entry record; child admin_work_private.session_work; next_phase jsonb;
begin
  if exists(select 1 from jsonb_array_elements(new.state->'phases') q(value) where q.value ? 'phaseId'
    group by q.value->>'phaseId' having count(*)>1) then
    raise exception 'Las fases necesitan identidades distintas.' using errcode='22023'; end if;
  for phase in select value from jsonb_array_elements(new.state->'phases') loop
    for entry in select * from jsonb_each(coalesce(phase->'sessionWorks','{}'::jsonb)) loop
      if entry.value->>'parentWorkId' is distinct from new.id::text
        or entry.value->>'phaseId' is distinct from phase->>'phaseId'
        or entry.value->>'positionId' is null then
        raise exception 'Destino de trabajo hijo incompatible.' using errcode='22023'; end if;
      if entry.value->>'baseId' is not null and entry.value->>'duplicate'='false' and not exists(
        select 1 from jsonb_array_elements(phase->'sessions') slot
        where slot->>'positionId'=entry.value->>'positionId' and slot->>'id'=entry.value->>'baseId') then
        raise exception 'La posición tiene una edición pendiente. Retómala antes de sustituirla.' using errcode='40001'; end if;
    end loop;
  end loop;
  for phase in select value from jsonb_array_elements(old.state->'phases') loop
    for entry in select * from jsonb_each(coalesce(phase->'sessionWorks','{}'::jsonb)) loop
      select value into next_phase from jsonb_array_elements(new.state->'phases')
        where value->>'phaseId'=phase->>'phaseId';
      if next_phase->'sessionWorks'->entry.key=entry.value and new.finalized_program_id is null then continue; end if;
      select * into child from admin_work_private.session_work where id=entry.key::uuid;
      if not found or child.discarded then continue; end if;
      if child.result_id is not null and exists(
        select 1 from jsonb_array_elements(next_phase->'sessions') slot
        where slot->>'positionId'=entry.value->>'positionId' and slot->>'id'=child.result_id::text
      ) then continue; end if;
      raise exception 'Hay una sesión incompleta pendiente. Retómala o descártala antes de cambiar su destino.' using errcode='40001';
    end loop;
  end loop;
  return new;
end $$;
create trigger session_work_parent_guard before update on public.admin_guided_work_drafts
  for each row execute function admin_work_private.guard_parent();

create function admin_work_private.guard_pending_source() returns trigger
language plpgsql security definer set search_path='' as $$
begin
  if TG_TABLE_NAME='workout_templates' then
    if TG_OP='UPDATE' and new.trashed_at is null then return new; end if;
    if exists(select 1 from admin_work_private.session_work where not discarded and result_id is null
      and origin->>'baseId'=old.id::text) then
      raise exception 'Hay una sesión incompleta basada en esta receta. Retómala o descártala antes de retirarla.' using errcode='22023'; end if;
  else
    if exists(select 1 from admin_work_private.session_work where not discarded
      and origin->>'parentWorkId'=old.id::text and old.state::text like '%'||id::text||'%') then
      raise exception 'El programa conserva una sesión incompleta. Retómala o descártala antes del borrado definitivo.' using errcode='22023'; end if;
  end if;
  if TG_OP='DELETE' then return old; end if;
  return new;
end $$;
create trigger session_work_source_guard before delete or update of trashed_at on public.workout_templates
  for each row execute function admin_work_private.guard_pending_source();
create trigger session_work_parent_delete_guard before delete on public.admin_guided_work_drafts
  for each row execute function admin_work_private.guard_pending_source();

create function public.list_admin_session_work(p_expected_owner uuid) returns jsonb
language sql stable security invoker set search_path='' as $$select admin_work_private.read_work(p_expected_owner,null)$$;
create function public.get_admin_session_work(p_expected_owner uuid,p_id uuid) returns jsonb
language sql stable security invoker set search_path='' as $$select admin_work_private.read_work(p_expected_owner,p_id)$$;
create function public.save_admin_session_work(p_expected_owner uuid,p_id uuid,p_revision bigint,p_origin jsonb,p_state jsonb) returns jsonb
language sql security invoker set search_path='' as $$select admin_work_private.save_work(p_expected_owner,p_id,p_revision,p_origin,p_state)$$;
create function public.finalize_admin_session_work(p_expected_owner uuid,p_id uuid,p_revision bigint) returns uuid
language sql security invoker set search_path='' as $$select admin_work_private.finish_work(p_expected_owner,p_id,p_revision)$$;
create function public.discard_admin_session_work(p_expected_owner uuid,p_id uuid,p_revision bigint) returns void
language sql security invoker set search_path='' as $$select admin_work_private.discard_work(p_expected_owner,p_id,p_revision)$$;
create function public.reopen_admin_session_work(p_expected_owner uuid,p_id uuid,p_revision bigint) returns jsonb
language sql security invoker set search_path='' as $$select admin_work_private.reopen_work(p_expected_owner,p_id,p_revision)$$;

revoke all on all functions in schema admin_work_private from public,anon,authenticated;
grant execute on function admin_work_private.read_work(uuid,uuid),admin_work_private.save_work(uuid,uuid,bigint,jsonb,jsonb),
  admin_work_private.finish_work(uuid,uuid,bigint),admin_work_private.discard_work(uuid,uuid,bigint),admin_work_private.reopen_work(uuid,uuid,bigint),admin_work_private.check_owner(uuid) to authenticated;
revoke all on function public.list_admin_session_work(uuid),public.get_admin_session_work(uuid,uuid),
  public.save_admin_session_work(uuid,uuid,bigint,jsonb,jsonb),public.finalize_admin_session_work(uuid,uuid,bigint),
  public.discard_admin_session_work(uuid,uuid,bigint),public.reopen_admin_session_work(uuid,uuid,bigint) from public,anon;
grant execute on function public.list_admin_session_work(uuid),public.get_admin_session_work(uuid,uuid),
  public.save_admin_session_work(uuid,uuid,bigint,jsonb,jsonb),public.finalize_admin_session_work(uuid,uuid,bigint),
  public.discard_admin_session_work(uuid,uuid,bigint),public.reopen_admin_session_work(uuid,uuid,bigint) to authenticated;
commit;
