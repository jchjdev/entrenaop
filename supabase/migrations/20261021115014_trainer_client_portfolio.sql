-- La cartera permanece; los vínculos representan etapas aceptadas del servicio.
begin;
create table public.trainer_clients (
  trainer_id uuid not null references public.profiles(id) on delete cascade,
  client_id uuid not null references public.profiles(id) on delete cascade,
  display_name text not null check (btrim(display_name)<>''),
  created_at timestamptz not null,
  updated_at timestamptz not null,
  archived_at timestamptz,
  primary key(trainer_id,client_id),
  check (trainer_id<>client_id)
);
create index trainer_clients_by_client on public.trainer_clients(client_id);
create index trainer_clients_page on public.trainer_clients(trainer_id,updated_at desc,client_id desc);
create index trainer_relations_client_episodes on public.trainer_client_relations(trainer_id,client_id,accepted_at desc,id desc);
alter table public.trainer_clients enable row level security;
revoke all on public.trainer_clients from public,anon,authenticated;
grant select on public.trainer_clients to authenticated;
create policy trainer_clients_owner on public.trainer_clients for select to authenticated
  using(trainer_id=(select auth.uid()) and (select trainer_private.has_trainer_mfa()));

insert into public.trainer_clients(trainer_id,client_id,display_name,created_at,updated_at)
select r.trainer_id,r.client_id,coalesce(nullif(btrim(p.full_name),''),'Usuario de EntrenaOP'),
  min(r.accepted_at),max(coalesce(r.ended_at,r.accepted_at))
from public.trainer_client_relations r join public.profiles p on p.id=r.client_id
 group by r.trainer_id,r.client_id,p.full_name;

create function trainer_private.keep_client_portfolio() returns trigger
language plpgsql security definer set search_path='' as $$
begin
  if tg_op='INSERT' then
    -- Solo una aceptación nueva actualiza la identidad visible y saca del archivo.
    insert into public.trainer_clients(trainer_id,client_id,display_name,created_at,updated_at)
      select new.trainer_id,new.client_id,coalesce(nullif(btrim(p.full_name),''),'Usuario de EntrenaOP'),
        new.accepted_at,clock_timestamp() from public.profiles p where p.id=new.client_id
    on conflict(trainer_id,client_id) do update set
      display_name=excluded.display_name,updated_at=excluded.updated_at,archived_at=null;
  elsif new.ended_at is distinct from old.ended_at then
    update public.trainer_clients set updated_at=clock_timestamp()
      where trainer_id=new.trainer_id and client_id=new.client_id;
  end if;
  return new;
end $$;
revoke all on function trainer_private.keep_client_portfolio() from public,anon,authenticated;
create trigger trainer_relations_keep_portfolio after insert or update of ended_at
on public.trainer_client_relations for each row execute function trainer_private.keep_client_portfolio();

create function trainer_private.list_trainer_clients(
 p_state text default 'active',p_before_at timestamptz default null,p_before_client_id uuid default null
) returns jsonb language plpgsql stable security definer set search_path='' as $$
begin
  if not trainer_private.has_trainer_mfa() then raise insufficient_privilege; end if;
  if p_state is null or p_state not in ('active','inactive','archived')
    or ((p_before_at is null)<>(p_before_client_id is null)) then
    raise exception 'Estado o paginación inválidos.' using errcode='22023'; end if;
  return (select coalesce(jsonb_agg(to_jsonb(items) order by updated_at desc,person_id desc),'[]'::jsonb) from (
    select c.client_id as person_id,c.display_name as person_name,c.created_at,c.updated_at,c.archived_at,
      latest.accepted_at,latest.ended_at,
      active.id as active_relation_id,
      (select count(*) from public.trainer_client_relations r
        where r.trainer_id=c.trainer_id and r.client_id=c.client_id) as episode_count
    from public.trainer_clients c
    join lateral(select r.accepted_at,r.ended_at from public.trainer_client_relations r
      where r.trainer_id=c.trainer_id and r.client_id=c.client_id
      order by r.accepted_at desc,r.id desc limit 1) latest on true
    left join public.trainer_client_relations active on active.trainer_id=c.trainer_id
      and active.client_id=c.client_id and active.ended_at is null
    where c.trainer_id=auth.uid()
      and case p_state when 'archived' then c.archived_at is not null
        when 'active' then c.archived_at is null and active.id is not null
        else c.archived_at is null and active.id is null end
      and (p_before_at is null or (c.updated_at,c.client_id)<(p_before_at,p_before_client_id))
    order by c.updated_at desc,c.client_id desc limit 50
  ) items);
end $$;
revoke all on function trainer_private.list_trainer_clients(text,timestamptz,uuid) from public,anon,authenticated;
grant execute on function trainer_private.list_trainer_clients(text,timestamptz,uuid) to authenticated;
create function public.list_trainer_clients(p_state text default 'active',p_before_at timestamptz default null,p_before_client_id uuid default null)
returns jsonb language sql stable security invoker set search_path='' as $$
 select trainer_private.list_trainer_clients(p_state,p_before_at,p_before_client_id);
$$;
revoke all on function public.list_trainer_clients(text,timestamptz,uuid) from public,anon,authenticated;
grant execute on function public.list_trainer_clients(text,timestamptz,uuid) to authenticated;

create function trainer_private.archive_trainer_client(p_client_id uuid,p_archived boolean)
returns void language plpgsql security definer set search_path='' as $$
begin
  if not trainer_private.has_trainer_mfa() then raise insufficient_privilege; end if;
  if p_client_id is null or p_archived is null then
    raise exception 'Indica el cliente y la acción.' using errcode='22023'; end if;
  -- Mismo orden que aceptar/finalizar: alumno -> acceso -> cartera.
  perform pg_advisory_xact_lock(hashtextextended('trainer-client:'||p_client_id::text,0));
  perform 1 from public.trainer_access where trainer_id=auth.uid() for update;
  perform 1 from public.trainer_clients where trainer_id=auth.uid() and client_id=p_client_id for update;
  if not found then raise insufficient_privilege; end if;
  if p_archived and exists(select 1 from public.trainer_client_relations
    where trainer_id=auth.uid() and client_id=p_client_id and ended_at is null) then
    raise exception 'Desactiva el servicio antes de archivar al cliente.' using errcode='22023'; end if;
  update public.trainer_clients set archived_at=case when p_archived then clock_timestamp() else null end,
    updated_at=clock_timestamp() where trainer_id=auth.uid() and client_id=p_client_id
    and (archived_at is not null) is distinct from p_archived;
end $$;
revoke all on function trainer_private.archive_trainer_client(uuid,boolean) from public,anon,authenticated;
grant execute on function trainer_private.archive_trainer_client(uuid,boolean) to authenticated;
create function public.archive_trainer_client(p_client_id uuid,p_archived boolean) returns void
language sql volatile security invoker set search_path='' as $$
 select trainer_private.archive_trainer_client(p_client_id,p_archived);
$$;
revoke all on function public.archive_trainer_client(uuid,boolean) from public,anon,authenticated;
grant execute on function public.archive_trainer_client(uuid,boolean) to authenticated;

create function trainer_private.get_trainer_client_relations(
 p_client_id uuid,p_before_at timestamptz default null,p_before_id uuid default null
) returns jsonb language plpgsql stable security definer set search_path='' as $$
begin
  if not trainer_private.has_trainer_mfa() or not exists(select 1 from public.trainer_clients
    where trainer_id=auth.uid() and client_id=p_client_id) then raise insufficient_privilege; end if;
  if (p_before_at is null)<>(p_before_id is null) then
    raise exception 'Paginación inválida.' using errcode='22023'; end if;
  return(select coalesce(jsonb_agg(to_jsonb(items) order by accepted_at desc,id desc),'[]'::jsonb) from (
    select r.id,r.client_id as person_id,c.display_name as person_name,r.accepted_at,r.ended_at
    from public.trainer_client_relations r join public.trainer_clients c
      on c.trainer_id=r.trainer_id and c.client_id=r.client_id
    where r.trainer_id=auth.uid() and r.client_id=p_client_id
      and (p_before_at is null or (r.accepted_at,r.id)<(p_before_at,p_before_id))
    order by r.accepted_at desc,r.id desc limit 50
  ) items);
end $$;
revoke all on function trainer_private.get_trainer_client_relations(uuid,timestamptz,uuid) from public,anon,authenticated;
grant execute on function trainer_private.get_trainer_client_relations(uuid,timestamptz,uuid) to authenticated;
create function public.get_trainer_client_relations(p_client_id uuid,p_before_at timestamptz default null,p_before_id uuid default null)
returns jsonb language sql stable security invoker set search_path='' as $$
 select trainer_private.get_trainer_client_relations(p_client_id,p_before_at,p_before_id);
$$;
revoke all on function public.get_trainer_client_relations(uuid,timestamptz,uuid) from public,anon,authenticated;
grant execute on function public.get_trainer_client_relations(uuid,timestamptz,uuid) to authenticated;
commit;
