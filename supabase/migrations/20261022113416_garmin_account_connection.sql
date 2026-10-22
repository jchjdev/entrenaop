begin;

-- Estado del conector separado del historial de Salud. Solo lo opera el backend.
create table device_private.garmin_connections (
 owner_id uuid primary key references auth.users(id) on delete cascade,
 generation bigint not null default 0 check(generation>=0),
 status text not null default 'disconnected' check(status in
  ('disconnected','authorizing','connected','authorization_failed','disconnecting','revocation_pending')),
 attempt_hash text unique check(attempt_hash ~ '^[0-9a-f]{64}$'),
 attempt_session uuid,
 attempt_deadline timestamptz,
 verifier_cipher text check(octet_length(verifier_cipher)<=4096),
 claim_id uuid,
 garmin_user_id text unique check(length(garmin_user_id) between 1 and 256),
 tokens_cipher text check(octet_length(tokens_cipher)<=32768),
 access_expires_at timestamptz,
 refresh_expires_at timestamptz,
 can_read boolean not null default false,
 can_send boolean not null default false,
 disconnect_lease uuid,
 disconnect_lease_until timestamptz,
 updated_at timestamptz not null default clock_timestamp(),
 check((tokens_cipher is null)=(access_expires_at is null)),
 check((tokens_cipher is null)=(refresh_expires_at is null)),
 check(status<>'connected' or (tokens_cipher is not null and garmin_user_id is not null)),
 check(status<>'disconnected' or (tokens_cipher is null and claim_id is null and attempt_hash is null))
);
alter table device_private.garmin_connections enable row level security;
revoke all on device_private.garmin_connections from public,anon,authenticated,service_role;

create function device_private.garmin_access(p_owner uuid) returns boolean
language sql stable security definer set search_path='' as $$
 select public.has_pro_access(p_owner) or exists(
  select 1 from public.trainer_client_relations r join public.trainer_access a on a.trainer_id=r.trainer_id
  where r.client_id=p_owner and r.ended_at is null and a.enabled
   and (a.valid_until is null or a.valid_until>statement_timestamp())
 );
$$;
revoke all on function device_private.garmin_access(uuid) from public,anon,authenticated,service_role;

create function device_private.garmin_snapshot(p_owner uuid) returns jsonb
language sql stable set search_path='' as $$
 select jsonb_build_object('allowed',device_private.garmin_access(p_owner),
  'status',coalesce(c.status,'disconnected'),'generation',coalesce(c.generation,0),
  'can_read',coalesce(c.can_read,false),'can_send',coalesce(c.can_send,false),
  'updated_at',c.updated_at,'authorization_expires_at',c.attempt_deadline)
 from (select p_owner as id) o left join device_private.garmin_connections c on c.owner_id=o.id;
$$;
revoke all on function device_private.garmin_snapshot(uuid) from public,anon,authenticated,service_role;

-- Los parámetros de identidad solo proceden del adaptador Edge tras verificar Auth.
-- La existencia de sesión se comprueba también aquí para invalidar logout/borrado.
create function device_private.garmin_account_command(p_action text,p_owner uuid,p_session uuid,p_input jsonb)
returns jsonb language plpgsql security definer set search_path='' as $$
declare c device_private.garmin_connections; v_owner uuid:=p_owner; v_now timestamptz:=clock_timestamp();
 v_generation bigint; v_claim uuid; v_hash text; v_lease uuid; v_tokens text; v_access timestamptz; v_refresh timestamptz; v_session_valid boolean;
begin
 if p_input is null or jsonb_typeof(p_input)<>'object' or octet_length(p_input::text)>40000 then
  raise exception 'invalid_request' using errcode='22023'; end if;
 if p_action='claim' then
  v_hash:=p_input->>'state_hash';
  if v_hash is null or v_hash !~ '^[0-9a-f]{64}$' then raise exception 'invalid_attempt' using errcode='22023'; end if;
  select owner_id into v_owner from device_private.garmin_connections where attempt_hash=v_hash;
 end if;
 if v_owner is null then raise exception 'invalid_attempt' using errcode='42501'; end if;
 -- Orden uniforme Auth -> conexión, compatible con el CASCADE de eliminar cuenta.
 perform 1 from auth.users where id=v_owner for key share;
 if not found then raise exception 'account_changed' using errcode='42501'; end if;
 if p_action in ('status','begin','disconnect') then
  perform 1 from auth.sessions s where s.id=p_session and s.user_id=v_owner
   and (s.not_after is null or s.not_after>v_now) for key share;
  if not found then raise exception 'account_changed' using errcode='42501'; end if;
 end if;
 if p_action='status' then return device_private.garmin_snapshot(v_owner); end if;
 if p_action='begin' then
  if not device_private.garmin_access(v_owner) then raise exception 'access_required' using errcode='42501'; end if;
  insert into device_private.garmin_connections(owner_id) values(v_owner) on conflict do nothing;
 end if;
 select * into c from device_private.garmin_connections where owner_id=v_owner for update;
 v_now:=clock_timestamp();
 if not found then
  if p_action='disconnect' then return device_private.garmin_snapshot(v_owner); end if;
  raise exception 'invalid_attempt' using errcode='42501';
 end if;

 if p_action='begin' then
  if c.status not in ('disconnected','authorization_failed','authorizing') or c.claim_id is not null then
   raise exception 'connection_busy' using errcode='40001'; end if;
  if c.generation>0 and c.updated_at>v_now-interval '30 seconds' then
   raise exception 'rate_limited' using errcode='54000'; end if;
  v_hash:=p_input->>'state_hash';
  if v_hash is null or v_hash !~ '^[0-9a-f]{64}$' or coalesce(p_input->>'verifier_cipher','')='' then
   raise exception 'invalid_request' using errcode='22023'; end if;
  update device_private.garmin_connections set generation=generation+1,status='authorizing',
   attempt_hash=v_hash,attempt_session=p_session,attempt_deadline=v_now+interval '10 minutes',
   verifier_cipher=p_input->>'verifier_cipher',claim_id=null,can_read=false,can_send=false,
   updated_at=v_now where owner_id=v_owner;
  return device_private.garmin_snapshot(v_owner);
 elsif p_action='claim' then
  perform 1 from auth.sessions s where s.id=c.attempt_session and s.user_id=v_owner
   and (s.not_after is null or s.not_after>v_now) for key share;
  v_session_valid:=found;
  if c.attempt_hash is distinct from v_hash or c.status<>'authorizing' or c.claim_id is not null
   or c.attempt_deadline<=v_now or not device_private.garmin_access(v_owner)
   or not v_session_valid then
   raise exception 'invalid_attempt' using errcode='42501'; end if;
  v_claim:=(p_input->>'claim_id')::uuid;
  if v_claim is null then raise exception 'invalid_request' using errcode='22023'; end if;
  update device_private.garmin_connections set claim_id=v_claim,verifier_cipher=null,updated_at=v_now where owner_id=v_owner;
  return jsonb_build_object('owner_id',v_owner,'generation',c.generation,'verifier_cipher',c.verifier_cipher,
   'claim_id',v_claim,'state_hash',v_hash);
 elsif p_action in ('stash_grant','complete','fail') then
  v_generation:=(p_input->>'generation')::bigint; v_claim:=(p_input->>'claim_id')::uuid;
  if c.generation is distinct from v_generation or c.claim_id is distinct from v_claim or v_claim is null
   or c.status not in ('authorizing','disconnecting','revocation_pending') then
   raise exception 'stale_attempt' using errcode='40001'; end if;
  if p_action='fail' then
   if coalesce((p_input->>'account_in_use')::boolean,false) then
    -- No revocar el Garmin que ya pertenece a otra conexión legítima de EntrenaOP.
    update device_private.garmin_connections set status='authorization_failed',attempt_hash=null,verifier_cipher=null,
     claim_id=null,tokens_cipher=null,access_expires_at=null,refresh_expires_at=null,
     can_read=false,can_send=false,updated_at=v_now where owner_id=v_owner;
    return device_private.garmin_snapshot(v_owner);
   end if;
   update device_private.garmin_connections set status=case when coalesce((p_input->>'no_grant')::boolean,false)
      and tokens_cipher is null then 'authorization_failed' else 'revocation_pending' end,
    claim_id=case when coalesce((p_input->>'no_grant')::boolean,false) and tokens_cipher is null then null else claim_id end,
    attempt_hash=null,verifier_cipher=null,updated_at=v_now where owner_id=v_owner;
  else
   v_tokens:=p_input->>'tokens_cipher'; v_access:=(p_input->>'access_expires_at')::timestamptz;
   v_refresh:=(p_input->>'refresh_expires_at')::timestamptz;
   if coalesce(v_tokens,'')='' or v_access is null or v_refresh is null or not isfinite(v_access) or not isfinite(v_refresh)
    or v_access<=v_now or v_refresh<=v_now then
    raise exception 'invalid_request' using errcode='22023'; end if;
   if p_action='stash_grant' then
    update device_private.garmin_connections set tokens_cipher=v_tokens,access_expires_at=v_access,
     refresh_expires_at=v_refresh,updated_at=v_now where owner_id=v_owner;
    return device_private.garmin_snapshot(v_owner);
   end if;
   if coalesce(p_input->>'garmin_user_id','')='' then raise exception 'invalid_request' using errcode='22023'; end if;
   if exists(select 1 from device_private.garmin_connections where garmin_user_id=p_input->>'garmin_user_id' and owner_id<>v_owner) then
    raise exception 'provider_account_in_use' using errcode='23505'; end if;
   -- Acceso/sesión perdidos durante HTTP: conservar el grant solo para revocarlo.
   perform 1 from auth.sessions s where s.id=c.attempt_session and s.user_id=v_owner
    and (s.not_after is null or s.not_after>v_now) for key share;
   v_session_valid:=found;
   begin
   update device_private.garmin_connections set status=case when status='authorizing'
    and attempt_deadline>v_now and device_private.garmin_access(v_owner)
    and v_session_valid then 'connected' else 'revocation_pending' end,
    garmin_user_id=p_input->>'garmin_user_id',tokens_cipher=v_tokens,access_expires_at=v_access,refresh_expires_at=v_refresh,
    can_read=(p_input->>'can_read')::boolean,can_send=(p_input->>'can_send')::boolean,
    attempt_hash=null,verifier_cipher=null,claim_id=null,updated_at=v_now where owner_id=v_owner;
   exception when unique_violation then
    raise exception 'provider_account_in_use' using errcode='23505';
   end;
  end if;
  return device_private.garmin_snapshot(v_owner);
 elsif p_action='disconnect' then
  if c.generation is distinct from (p_input->>'generation')::bigint then
   raise exception 'stale_attempt' using errcode='40001'; end if;
  if c.status='disconnected' then return device_private.garmin_snapshot(v_owner); end if;
  update device_private.garmin_connections set status=case when tokens_cipher is null and claim_id is null
    then 'disconnected' else 'disconnecting' end,
   attempt_hash=null,verifier_cipher=null,can_read=false,can_send=false,updated_at=v_now
   where owner_id=v_owner;
  return device_private.garmin_snapshot(v_owner);
 elsif p_action='claim_revoke' then
  if c.status not in ('disconnecting','revocation_pending') or c.tokens_cipher is null
    or (c.disconnect_lease_until is not null and c.disconnect_lease_until>v_now) then
   return jsonb_build_object('pending',true); end if;
  v_lease:=(p_input->>'lease_id')::uuid;
  if v_lease is null then raise exception 'invalid_request' using errcode='22023'; end if;
  update device_private.garmin_connections set disconnect_lease=v_lease,
   disconnect_lease_until=v_now+interval '2 minutes',updated_at=v_now where owner_id=v_owner;
  return jsonb_build_object('owner_id',v_owner,'generation',c.generation,'tokens_cipher',c.tokens_cipher,
   'access_expires_at',c.access_expires_at,'refresh_expires_at',c.refresh_expires_at);
 elsif p_action in ('identify_revoke','rotate_revoke','finish_revoke','fail_revoke') then
  if c.status not in ('disconnecting','revocation_pending') or c.generation is distinct from (p_input->>'generation')::bigint
   or c.disconnect_lease is distinct from (p_input->>'lease_id')::uuid or c.disconnect_lease is null
   or c.disconnect_lease_until<=v_now then raise exception 'stale_attempt' using errcode='40001'; end if;
  if p_action='identify_revoke' then
   if coalesce(p_input->>'garmin_user_id','')='' or (c.garmin_user_id is not null
     and c.garmin_user_id is distinct from p_input->>'garmin_user_id') then
    raise exception 'invalid_request' using errcode='22023'; end if;
   begin
    update device_private.garmin_connections set garmin_user_id=p_input->>'garmin_user_id' where owner_id=v_owner;
   exception when unique_violation then raise exception 'provider_account_in_use' using errcode='23505'; end;
  elsif p_action='rotate_revoke' then
   v_access:=(p_input->>'access_expires_at')::timestamptz; v_refresh:=(p_input->>'refresh_expires_at')::timestamptz;
   if coalesce(p_input->>'tokens_cipher','')='' or v_access is null or v_refresh is null
    or not isfinite(v_access) or not isfinite(v_refresh) or v_access<=v_now or v_refresh<=v_now then
    raise exception 'invalid_request' using errcode='22023'; end if;
   update device_private.garmin_connections set tokens_cipher=p_input->>'tokens_cipher',
    access_expires_at=v_access,refresh_expires_at=v_refresh,updated_at=v_now where owner_id=v_owner;
  elsif p_action='finish_revoke' then
   update device_private.garmin_connections set status='disconnected',attempt_session=null,attempt_deadline=null,
    claim_id=null,garmin_user_id=null,tokens_cipher=null,access_expires_at=null,refresh_expires_at=null,
    can_read=false,can_send=false,disconnect_lease=null,disconnect_lease_until=null,updated_at=v_now where owner_id=v_owner;
  else
   update device_private.garmin_connections set status='revocation_pending',disconnect_lease=null,
    disconnect_lease_until=null,updated_at=v_now where owner_id=v_owner;
  end if;
  return device_private.garmin_snapshot(v_owner);
 end if;
 raise exception 'invalid_request' using errcode='22023';
end;
$$;
revoke all on function device_private.garmin_account_command(text,uuid,uuid,jsonb) from public,anon,authenticated;
grant usage on schema device_private to service_role;
grant execute on function device_private.garmin_account_command(text,uuid,uuid,jsonb) to service_role;
create function public.garmin_account_command(p_action text,p_owner uuid,p_session uuid,p_input jsonb)
returns jsonb language sql security invoker set search_path='' as $$
 select device_private.garmin_account_command(p_action,p_owner,p_session,p_input);
$$;
revoke all on function public.garmin_account_command(text,uuid,uuid,jsonb) from public,anon,authenticated;
grant execute on function public.garmin_account_command(text,uuid,uuid,jsonb) to service_role;

commit;
