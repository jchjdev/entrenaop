-- El derecho profesional y el vínculo no cambian Pro ni las cuotas personales.
create schema trainer_private;
revoke all on schema trainer_private from public, anon, authenticated;
grant usage on schema trainer_private to authenticated;

create table public.trainer_access_settings (
  singleton boolean primary key default true check (singleton),
  manual_access_enabled boolean not null default false
);
insert into public.trainer_access_settings(singleton) values(true);
alter table public.trainer_access_settings enable row level security;
revoke all on public.trainer_access_settings from public, anon, authenticated;

create table public.trainer_access (
  trainer_id uuid primary key references public.profiles(id) on delete cascade,
  enabled boolean not null,
  client_limit integer not null check (client_limit > 0),
  valid_until timestamptz,
  revision bigint not null default 1 check (revision > 0),
  membership_version bigint not null default 0 check (membership_version >= 0),
  updated_at timestamptz not null default clock_timestamp(),
  updated_by uuid references auth.users(id) on delete set null,
  last_reason text not null check (char_length(last_reason) between 3 and 500)
);
create index trainer_access_updated_by on public.trainer_access(updated_by);
alter table public.trainer_access enable row level security;
revoke all on public.trainer_access from public, anon, authenticated;
grant select(trainer_id,enabled,client_limit,valid_until,revision,updated_at)
  on public.trainer_access to authenticated;
create policy trainer_access_read on public.trainer_access for select to authenticated
  using (trainer_id=(select auth.uid()) or (select public.can_manage_pro_accounts()));

create table public.trainer_access_audit (
  id uuid primary key default gen_random_uuid(),
  trainer_id uuid not null references public.profiles(id) on delete cascade,
  actor_id uuid references auth.users(id) on delete set null,
  revision bigint not null,
  previous_access jsonb,
  new_access jsonb not null,
  reason text not null,
  created_at timestamptz not null default clock_timestamp(),
  unique(trainer_id,revision)
);
create index trainer_access_audit_actor on public.trainer_access_audit(actor_id);
alter table public.trainer_access_audit enable row level security;
revoke all on public.trainer_access_audit from public, anon, authenticated;
grant select on public.trainer_access_audit to authenticated;
create policy trainer_access_audit_manager on public.trainer_access_audit for select to authenticated
  using ((select public.can_manage_pro_accounts()));

create table public.trainer_client_relations (
  id uuid primary key default gen_random_uuid(),
  trainer_id uuid not null references public.profiles(id) on delete cascade,
  client_id uuid not null references public.profiles(id) on delete cascade,
  accepted_at timestamptz not null default clock_timestamp(),
  ended_at timestamptz,
  ended_by uuid references auth.users(id) on delete set null,
  check (trainer_id <> client_id),
  check (ended_at is null or ended_at >= accepted_at),
  check (ended_by is null or ended_by in (trainer_id,client_id))
);
-- La base de datos impide dos preparadores activos incluso fuera del recorrido RPC.
create unique index trainer_client_one_active on public.trainer_client_relations(client_id)
  where ended_at is null;
create index trainer_client_by_trainer on public.trainer_client_relations(trainer_id,accepted_at desc,id);
create index trainer_client_by_client on public.trainer_client_relations(client_id,accepted_at desc,id);
create index trainer_client_ended_by on public.trainer_client_relations(ended_by);
alter table public.trainer_client_relations enable row level security;
revoke all on public.trainer_client_relations from public, anon, authenticated;
grant select on public.trainer_client_relations to authenticated;
create policy trainer_client_participant on public.trainer_client_relations for select to authenticated
  using (trainer_id=(select auth.uid()) or client_id=(select auth.uid()));

create table public.trainer_invitations (
  id uuid primary key,
  trainer_id uuid not null references public.profiles(id) on delete cascade,
  secret_hash bytea not null unique check (octet_length(secret_hash)=32),
  created_at timestamptz not null default clock_timestamp(),
  expires_at timestamptz not null,
  revoked_at timestamptz,
  accepted_at timestamptz,
  accepted_by uuid references auth.users(id) on delete set null,
  relation_id uuid references public.trainer_client_relations(id) on delete set null,
  check (expires_at > created_at)
);
create index trainer_invitation_owner on public.trainer_invitations(trainer_id,created_at desc);
create index trainer_invitation_accepted_by on public.trainer_invitations(accepted_by);
create index trainer_invitation_relation on public.trainer_invitations(relation_id);
alter table public.trainer_invitations enable row level security;
revoke all on public.trainer_invitations from public, anon, authenticated;
-- El resumen del preparador no expone el hash ni recupera el secreto compartido.
grant select(id,trainer_id,created_at,expires_at,revoked_at,accepted_at,accepted_by,relation_id)
  on public.trainer_invitations to authenticated;
create policy trainer_invitation_owner on public.trainer_invitations for select to authenticated
  using (trainer_id=(select auth.uid()));

create function trainer_private.get_trainer_access(p_trainer_id uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare v public.trainer_access; used integer;
begin
  if auth.uid() is null or (p_trainer_id is distinct from auth.uid()
    and not public.can_manage_pro_accounts()) then raise insufficient_privilege; end if;
  select * into v from public.trainer_access where trainer_id=p_trainer_id;
  select count(*) into used from public.trainer_client_relations
    where trainer_id=p_trainer_id and ended_at is null;
  return jsonb_build_object('trainer_id',p_trainer_id,
    'enabled',coalesce(v.enabled,false),'client_limit',coalesce(v.client_limit,0),
    'valid_until',v.valid_until,'revision',coalesce(v.revision,0),
    'active_clients',used,'over_limit',used>coalesce(v.client_limit,0),
    'effective',coalesce(v.enabled and (v.valid_until is null or v.valid_until>statement_timestamp()),false));
end $$;

create function trainer_private.admin_set_trainer_access(
  p_trainer_id uuid,p_client_limit integer,p_enabled boolean,
  p_expected_revision bigint,p_reason text,p_valid_until timestamptz
) returns jsonb language plpgsql security definer set search_path='' as $$
declare v public.trainer_access; previous jsonb; result jsonb;
begin
  if auth.uid() is null or not public.can_manage_pro_accounts()
    or not coalesce((select manual_access_enabled from public.trainer_access_settings where singleton),false)
    then raise insufficient_privilege; end if;
  if p_trainer_id is null or p_client_limit is null or p_client_limit<1 or p_enabled is null
    or p_expected_revision is null or p_expected_revision<0
    or p_reason is null or char_length(btrim(p_reason)) not between 3 and 500
    or (p_enabled and p_valid_until is not null and p_valid_until<=clock_timestamp()) then
    raise exception 'Revisa el cupo, la vigencia y el motivo.' using errcode='22023';
  end if;
  -- Incluye la primera concesión, cuando aún no existe una fila que bloquear.
  perform pg_advisory_xact_lock(hashtextextended('trainer-access:'||p_trainer_id::text,0));
  select * into v from public.trainer_access where trainer_id=p_trainer_id for update;
  if found then
    if v.revision=p_expected_revision+1 and v.client_limit=p_client_limit and v.enabled=p_enabled
      and v.valid_until is not distinct from p_valid_until and v.updated_by=auth.uid()
      and v.last_reason=btrim(p_reason) then
      return trainer_private.get_trainer_access(p_trainer_id);
    end if;
    if v.revision<>p_expected_revision then
      raise exception 'El acceso ha cambiado; actualiza la ficha.' using errcode='40001';
    end if;
    -- La política comercial de bajada de paquete sigue pendiente: no desactiva alumnos por su cuenta.
    if p_enabled and p_client_limit < (select count(*) from public.trainer_client_relations
      where trainer_id=p_trainer_id and ended_at is null) then
      raise exception 'Finaliza los vínculos necesarios antes de reducir el cupo.' using errcode='23514';
    end if;
    previous:=jsonb_build_object('enabled',v.enabled,'client_limit',v.client_limit,
      'valid_until',v.valid_until,'revision',v.revision);
    update public.trainer_access set enabled=p_enabled,client_limit=p_client_limit,
      valid_until=p_valid_until,revision=revision+1,updated_at=clock_timestamp(),
      updated_by=auth.uid(),last_reason=btrim(p_reason) where trainer_id=p_trainer_id;
  else
    if p_expected_revision<>0 then raise exception 'El acceso ha cambiado.' using errcode='40001'; end if;
    insert into public.trainer_access(trainer_id,enabled,client_limit,valid_until,updated_by,last_reason)
      values(p_trainer_id,p_enabled,p_client_limit,p_valid_until,auth.uid(),btrim(p_reason));
  end if;
  result:=trainer_private.get_trainer_access(p_trainer_id);
  insert into public.trainer_access_audit(trainer_id,actor_id,revision,previous_access,new_access,reason)
    values(p_trainer_id,auth.uid(),(result->>'revision')::bigint,previous,result,btrim(p_reason));
  return result;
end $$;

create function trainer_private.create_trainer_invitation(p_id uuid,p_secret text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v public.trainer_access; invite public.trainer_invitations; hashed bytea;
begin
  if auth.uid() is null or coalesce((auth.jwt()->>'is_anonymous')::boolean,false) then raise insufficient_privilege; end if;
  if p_id is null or p_secret is null or p_secret !~ '^[0-9a-f]{64}$' then
    raise exception 'Invitación inválida.' using errcode='22023';
  end if;
  hashed:=extensions.digest(p_secret,'sha256');
  select * into v from public.trainer_access where trainer_id=auth.uid() for update;
  if not found or not v.enabled or (v.valid_until is not null and v.valid_until<=clock_timestamp()) then
    raise insufficient_privilege;
  end if;
  select * into invite from public.trainer_invitations where id=p_id for update;
  if found then
    if invite.trainer_id<>auth.uid() or invite.secret_hash<>hashed then raise insufficient_privilege; end if;
  else
    -- El cliente genera 32 bytes con un generador seguro y conserva ID/secreto para reintentar.
    insert into public.trainer_invitations(id,trainer_id,secret_hash,expires_at)
      values(p_id,auth.uid(),hashed,clock_timestamp()+interval '7 days') returning * into invite;
  end if;
  return jsonb_build_object('id',invite.id,'trainer_id',invite.trainer_id,
    'expires_at',invite.expires_at,'revoked_at',invite.revoked_at,'accepted_at',invite.accepted_at);
end $$;

create function trainer_private.preview_trainer_invitation(p_secret text)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare invite public.trainer_invitations; v public.trainer_access; name text;
begin
  if auth.uid() is null or coalesce((auth.jwt()->>'is_anonymous')::boolean,false) then raise insufficient_privilege; end if;
  if p_secret is null or p_secret !~ '^[0-9a-f]{64}$' then
    raise exception 'Invitación no disponible.' using errcode='22023'; end if;
  select * into invite from public.trainer_invitations where secret_hash=extensions.digest(p_secret,'sha256');
  if not found or invite.revoked_at is not null or invite.accepted_at is not null
    or invite.expires_at<=statement_timestamp() then
    raise exception 'Invitación no disponible.' using errcode='22023'; end if;
  select * into v from public.trainer_access where trainer_id=invite.trainer_id;
  if not found or not v.enabled or (v.valid_until is not null and v.valid_until<=statement_timestamp()) then
    raise exception 'Invitación no disponible.' using errcode='22023'; end if;
  select full_name into name from public.profiles where id=invite.trainer_id;
  -- Solo quien posee el código puede conocer a quién solicita vincularse.
  return jsonb_build_object('id',invite.id,'trainer_id',invite.trainer_id,
    'trainer_name',name,'expires_at',invite.expires_at);
end $$;

create function trainer_private.accept_trainer_invitation(p_secret text)
returns uuid language plpgsql security definer set search_path='' as $$
declare invite public.trainer_invitations; v public.trainer_access; relation uuid; used integer;
begin
  if auth.uid() is null or coalesce((auth.jwt()->>'is_anonymous')::boolean,false) then raise insufficient_privilege; end if;
  if p_secret is null or p_secret !~ '^[0-9a-f]{64}$' then
    raise exception 'Invitación no disponible.' using errcode='22023'; end if;
  select * into invite from public.trainer_invitations where secret_hash=extensions.digest(p_secret,'sha256');
  if not found then raise exception 'Invitación no disponible.' using errcode='22023'; end if;
  if invite.trainer_id=auth.uid() then raise exception 'No puedes ser tu propio preparador.' using errcode='22023'; end if;
  -- Orden único: alumno -> acceso del preparador -> invitación -> vínculo.
  perform pg_advisory_xact_lock(hashtextextended('trainer-client:'||auth.uid()::text,0));
  select * into v from public.trainer_access where trainer_id=invite.trainer_id for update;
  select * into invite from public.trainer_invitations where id=invite.id for update;
  if invite.accepted_at is not null then
    if invite.accepted_by=auth.uid() and exists(select 1 from public.trainer_client_relations
      where id=invite.relation_id and client_id=auth.uid() and ended_at is null) then return invite.relation_id; end if;
    raise exception 'Invitación no disponible.' using errcode='22023';
  end if;
  if v.trainer_id is null or not v.enabled or (v.valid_until is not null and v.valid_until<=clock_timestamp())
    or invite.revoked_at is not null or invite.expires_at<=clock_timestamp() then
    raise exception 'Invitación no disponible.' using errcode='22023'; end if;
  if exists(select 1 from public.trainer_client_relations where client_id=auth.uid() and ended_at is null) then
    raise exception 'Ya tienes un preparador activo.' using errcode='23505'; end if;
  select count(*) into used from public.trainer_client_relations
    where trainer_id=invite.trainer_id and ended_at is null;
  if used>=v.client_limit then raise exception 'El preparador ha completado su cupo.' using errcode='23514'; end if;
  -- Fuerza conflicto ante snapshots obsoletos en REPEATABLE READ, además del bloqueo del cupo.
  update public.trainer_access set membership_version=membership_version+1 where trainer_id=invite.trainer_id;
  insert into public.trainer_client_relations(trainer_id,client_id)
    values(invite.trainer_id,auth.uid()) returning id into relation;
  update public.trainer_invitations set accepted_at=clock_timestamp(),accepted_by=auth.uid(),relation_id=relation
    where id=invite.id;
  return relation;
end $$;

create function trainer_private.cancel_trainer_invitation(p_id uuid)
returns void language plpgsql security definer set search_path='' as $$
declare invite public.trainer_invitations;
begin
  if auth.uid() is null then raise insufficient_privilege; end if;
  select * into invite from public.trainer_invitations where id=p_id for update;
  if not found or invite.trainer_id<>auth.uid() then raise insufficient_privilege; end if;
  if invite.accepted_at is not null then
    raise exception 'La invitación ya se utilizó; cancelar no termina el vínculo.' using errcode='22023'; end if;
  update public.trainer_invitations set revoked_at=coalesce(revoked_at,clock_timestamp()) where id=p_id;
end $$;

create function trainer_private.end_trainer_relation(p_id uuid)
returns void language plpgsql security definer set search_path='' as $$
declare v public.trainer_client_relations;
begin
  if auth.uid() is null then raise insufficient_privilege; end if;
  select * into v from public.trainer_client_relations where id=p_id;
  if not found or auth.uid() not in (v.trainer_id,v.client_id) then raise insufficient_privilege; end if;
  perform pg_advisory_xact_lock(hashtextextended('trainer-client:'||v.client_id::text,0));
  perform 1 from public.trainer_access where trainer_id=v.trainer_id for update;
  select * into v from public.trainer_client_relations where id=p_id for update;
  if v.ended_at is not null then return; end if;
  update public.trainer_access set membership_version=membership_version+1 where trainer_id=v.trainer_id;
  update public.trainer_client_relations set ended_at=clock_timestamp(),ended_by=auth.uid() where id=p_id;
end $$;

-- Las RPC expuestas son invoker; las operaciones privilegiadas viven fuera de la API.
create function public.get_trainer_access(p_trainer_id uuid default auth.uid()) returns jsonb
language sql stable security invoker set search_path='' as $$
  select trainer_private.get_trainer_access(p_trainer_id);
$$;
revoke all on function trainer_private.get_trainer_access(uuid) from public,anon,authenticated;
grant execute on function trainer_private.get_trainer_access(uuid) to authenticated;
revoke all on function public.get_trainer_access(uuid) from public,anon,authenticated;
grant execute on function public.get_trainer_access(uuid) to authenticated;

create function public.admin_set_trainer_access(p_trainer_id uuid,p_client_limit integer,p_enabled boolean,p_expected_revision bigint,p_reason text,p_valid_until timestamptz default null) returns jsonb
language sql volatile security invoker set search_path='' as $$
  select trainer_private.admin_set_trainer_access(p_trainer_id,p_client_limit,p_enabled,p_expected_revision,p_reason,p_valid_until);
$$;
revoke all on function trainer_private.admin_set_trainer_access(uuid,integer,boolean,bigint,text,timestamptz) from public,anon,authenticated;
grant execute on function trainer_private.admin_set_trainer_access(uuid,integer,boolean,bigint,text,timestamptz) to authenticated;
revoke all on function public.admin_set_trainer_access(uuid,integer,boolean,bigint,text,timestamptz) from public,anon,authenticated;
grant execute on function public.admin_set_trainer_access(uuid,integer,boolean,bigint,text,timestamptz) to authenticated;

create function public.create_trainer_invitation(p_id uuid,p_secret text) returns jsonb
language sql volatile security invoker set search_path='' as $$
  select trainer_private.create_trainer_invitation(p_id,p_secret);
$$;
revoke all on function trainer_private.create_trainer_invitation(uuid,text) from public,anon,authenticated;
grant execute on function trainer_private.create_trainer_invitation(uuid,text) to authenticated;
revoke all on function public.create_trainer_invitation(uuid,text) from public,anon,authenticated;
grant execute on function public.create_trainer_invitation(uuid,text) to authenticated;

create function public.preview_trainer_invitation(p_secret text) returns jsonb
language sql stable security invoker set search_path='' as $$
  select trainer_private.preview_trainer_invitation(p_secret);
$$;
revoke all on function trainer_private.preview_trainer_invitation(text) from public,anon,authenticated;
grant execute on function trainer_private.preview_trainer_invitation(text) to authenticated;
revoke all on function public.preview_trainer_invitation(text) from public,anon,authenticated;
grant execute on function public.preview_trainer_invitation(text) to authenticated;

create function public.accept_trainer_invitation(p_secret text) returns uuid
language sql volatile security invoker set search_path='' as $$
  select trainer_private.accept_trainer_invitation(p_secret);
$$;
revoke all on function trainer_private.accept_trainer_invitation(text) from public,anon,authenticated;
grant execute on function trainer_private.accept_trainer_invitation(text) to authenticated;
revoke all on function public.accept_trainer_invitation(text) from public,anon,authenticated;
grant execute on function public.accept_trainer_invitation(text) to authenticated;

create function public.cancel_trainer_invitation(p_id uuid) returns void
language sql volatile security invoker set search_path='' as $$
  select trainer_private.cancel_trainer_invitation(p_id);
$$;
revoke all on function trainer_private.cancel_trainer_invitation(uuid) from public,anon,authenticated;
grant execute on function trainer_private.cancel_trainer_invitation(uuid) to authenticated;
revoke all on function public.cancel_trainer_invitation(uuid) from public,anon,authenticated;
grant execute on function public.cancel_trainer_invitation(uuid) to authenticated;

create function public.end_trainer_relation(p_id uuid) returns void
language sql volatile security invoker set search_path='' as $$
  select trainer_private.end_trainer_relation(p_id);
$$;
revoke all on function trainer_private.end_trainer_relation(uuid) from public,anon,authenticated;
grant execute on function trainer_private.end_trainer_relation(uuid) to authenticated;
revoke all on function public.end_trainer_relation(uuid) from public,anon,authenticated;
grant execute on function public.end_trainer_relation(uuid) to authenticated;
