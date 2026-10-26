begin;
create table device_private.ciq_links (
 id uuid primary key default gen_random_uuid(),
 token_hash text not null unique check(token_hash ~ '^[0-9a-f]{64}$'),
 code_hash text unique check(code_hash ~ '^[0-9a-f]{64}$'),
 owner_id uuid references auth.users(id) on delete cascade,
 approved_session uuid,
 created_at timestamptz not null default clock_timestamp(),
 pair_until timestamptz not null default clock_timestamp()+interval '10 minutes',
 valid_until timestamptz, revoked_at timestamptz, last_seen_at timestamptz,
 check((owner_id is null)=(valid_until is null)),
 check(valid_until is null or valid_until>created_at)
);
create index ciq_links_owner on device_private.ciq_links(owner_id);
create table device_private.ciq_limits (
 bucket text primary key check(length(bucket)<=100), since timestamptz not null,
 attempts integer not null check(attempts>0)
);
create table device_private.ciq_exports (
 id uuid primary key default gen_random_uuid(),
 owner_id uuid not null references auth.users(id) on delete cascade,
 scheduled_id uuid not null,
 revision text not null check(revision ~ '^[0-9a-f]{64}$'),
 serial bigint generated always as identity (start with 1000000000),
 created_at timestamptz not null default clock_timestamp(),
 snapshot jsonb not null check(jsonb_typeof(snapshot)='object' and octet_length(snapshot::text)<=131072),
 unique(owner_id,scheduled_id,revision), check(serial between 1 and 4294967294)
);
alter table device_private.ciq_links enable row level security;
alter table device_private.ciq_limits enable row level security;
alter table device_private.ciq_exports enable row level security;
revoke all on device_private.ciq_links,device_private.ciq_limits,device_private.ciq_exports from public,anon,authenticated,service_role;
revoke all on sequence device_private.ciq_exports_serial_seq from public,anon,authenticated,service_role;

create function device_private.ciq_rate(p_bucket text,p_max integer) returns boolean
language plpgsql security definer set search_path='' as $$
declare n integer;
begin
 insert into device_private.ciq_limits(bucket,since,attempts) values(p_bucket,clock_timestamp(),1)
 on conflict(bucket) do update set
  since=case when ciq_limits.since<clock_timestamp()-interval '1 minute' then clock_timestamp() else ciq_limits.since end,
  attempts=case when ciq_limits.since<clock_timestamp()-interval '1 minute' then 1 else least(ciq_limits.attempts+1,p_max+1) end
 returning attempts into n;
 return n<=p_max;
end $$;
revoke all on function device_private.ciq_rate(text,integer) from public,anon,authenticated,service_role;

-- Solo Edge invoca esta fachada tras verificar JWT o capacidad del reloj.
-- PostgreSQL conserva hashes, nunca las credenciales originales.
create function device_private.ciq_command(p_action text,p_owner uuid,p_session uuid,p_input jsonb)
returns jsonb language plpgsql security definer set search_path='' as $$
declare l device_private.ciq_links; e device_private.ciq_exports; s record;
 src jsonb; result jsonb:='[]'; blocked integer:=0; n integer;
begin
 if jsonb_typeof(p_input) is distinct from 'object' or octet_length(p_input::text)>4096 then raise invalid_parameter_value; end if;
 if p_action in ('account','review','approve','revoke') then
  perform 1 from auth.sessions where id=p_session and user_id=p_owner
   and (not_after is null or not_after>clock_timestamp()) for key share;
  if not found then raise exception 'account_changed' using errcode='42501'; end if;
  perform pg_advisory_xact_lock(hashtextextended('ciq-owner:'||p_owner::text,0));
  if p_action='account' then
   return jsonb_build_object('allowed',device_private.garmin_access(p_owner),'links',(
    select coalesce(jsonb_agg(jsonb_build_object('id',id,'created_at',created_at,'valid_until',valid_until,
      'revoked',revoked_at is not null,'last_seen_at',last_seen_at) order by created_at desc),'[]')
    from device_private.ciq_links where owner_id=p_owner));
  elsif p_action='revoke' then
   update device_private.ciq_links set revoked_at=coalesce(revoked_at,clock_timestamp()),code_hash=null
    where id=(p_input->>'id')::uuid and owner_id=p_owner;
   if not found then raise exception 'link_not_found' using errcode='42501'; end if;
   return jsonb_build_object('revoked',true);
  end if;
  if not device_private.garmin_access(p_owner) then raise exception 'access_required' using errcode='42501'; end if;
  if not device_private.ciq_rate('approve:'||p_owner::text,10) then return jsonb_build_object('error','rate_limited'); end if;
  select * into l from device_private.ciq_links where code_hash=p_input->>'code_hash' for update;
  if not found or l.pair_until<=clock_timestamp() or l.revoked_at is not null or l.owner_id is not null then
   -- Conservar el contador incluso ante códigos incorrectos.
   return jsonb_build_object('error','invalid_code');
  end if;
  if p_action='review' then return jsonb_build_object('id',l.id,'pair_until',l.pair_until,'device','fēnix 8 · Connect IQ'); end if;
  if l.id is distinct from (p_input->>'id')::uuid then return jsonb_build_object('error','invalid_code'); end if;
  if (select count(*) from device_private.ciq_links where owner_id=p_owner and revoked_at is null and valid_until>clock_timestamp())>=5 then
   return jsonb_build_object('error','device_limit'); end if;
  update device_private.ciq_links set owner_id=p_owner,approved_session=p_session,code_hash=null,
   valid_until=clock_timestamp()+interval '90 days' where id=l.id;
  return jsonb_build_object('linked',true);
 end if;
 if p_action='begin' then
  if coalesce(p_input->>'token_hash','') !~ '^[0-9a-f]{64}$' or coalesce(p_input->>'code_hash','') !~ '^[0-9a-f]{64}$' then raise invalid_parameter_value; end if;
  if not device_private.ciq_rate('begin',60) then return jsonb_build_object('error','rate_limited'); end if;
  -- Solo intentos anónimos vencidos; nunca concesiones o historial.
  delete from device_private.ciq_links where owner_id is null and pair_until<clock_timestamp()-interval '1 hour';
  insert into device_private.ciq_links(token_hash,code_hash) values(p_input->>'token_hash',p_input->>'code_hash') returning * into l;
  return jsonb_build_object('id',l.id,'pair_until',l.pair_until,'status','pending');
 end if;
 if coalesce(p_input->>'token_hash','') !~ '^[0-9a-f]{64}$' then raise exception 'link_required' using errcode='42501'; end if;
 select * into l from device_private.ciq_links where token_hash=p_input->>'token_hash' for update;
 if not found then raise exception 'link_required' using errcode='42501'; end if;
 if p_action='unlink' then
  update device_private.ciq_links set revoked_at=coalesce(revoked_at,clock_timestamp()),code_hash=null where id=l.id;
  return jsonb_build_object('revoked',true);
 end if;
 if l.revoked_at is not null or (l.valid_until is not null and l.valid_until<=clock_timestamp()) then
  raise exception 'link_revoked' using errcode='42501'; end if;
 if l.owner_id is null then
  if l.pair_until<=clock_timestamp() then raise exception 'pair_expired' using errcode='42501'; end if;
  if p_action<>'status' then raise exception 'link_required' using errcode='42501'; end if;
  return jsonb_build_object('status','pending','pair_until',l.pair_until);
 end if;
 if not device_private.garmin_access(l.owner_id) then raise exception 'access_required' using errcode='42501'; end if;
 update device_private.ciq_links set last_seen_at=clock_timestamp() where id=l.id;
 if p_action='status' then return jsonb_build_object('status','linked','valid_until',l.valid_until); end if;
 perform pg_advisory_xact_lock(hashtextextended('trainer-client:'||l.owner_id::text,0));
 if p_action='manifest' then
  if not device_private.ciq_rate('manifest:'||l.id::text,6) then return jsonb_build_object('error','rate_limited'); end if;
  select count(*) into n from public.scheduled_workouts where user_id=l.owner_id and status='planned' and execution_id is null
   and source in ('coach','algorithm') and scheduled_date between current_date-1 and current_date+14;
  if n>30 then raise exception 'too_many_sessions' using errcode='54000'; end if;
  for s in select id from public.scheduled_workouts where user_id=l.owner_id and status='planned' and execution_id is null
   and source in ('coach','algorithm') and scheduled_date between current_date-1 and current_date+14 order by scheduled_date,order_index,id loop
   begin
    src:=device_private.training_source(l.owner_id,l.owner_id,s.id);
    if src->'snapshot'->>'sport' is distinct from 'strength' then continue; end if;
   exception when insufficient_privilege or serialization_failure or invalid_parameter_value then
    blocked:=blocked+1; continue;
   end;
   insert into device_private.ciq_exports(owner_id,scheduled_id,revision,snapshot)
    values(l.owner_id,s.id,src->>'revision',src->'snapshot') on conflict(owner_id,scheduled_id,revision) do nothing;
   select * into e from device_private.ciq_exports where owner_id=l.owner_id and scheduled_id=s.id and revision=src->>'revision';
   result:=result||jsonb_build_array(jsonb_build_object('id',e.id,'scheduled_id',e.scheduled_id,'revision',e.revision,
    'serial',e.serial,'created_at',e.created_at,'snapshot',e.snapshot));
  end loop;
  return jsonb_build_object('complete',true,'entries',result,'blocked',blocked,'valid_until',l.valid_until);
 elsif p_action='download' then
  select * into e from device_private.ciq_exports where id=(p_input->>'id')::uuid and owner_id=l.owner_id;
  if not found then raise exception 'source_not_available' using errcode='42501'; end if;
  src:=device_private.training_source(l.owner_id,l.owner_id,e.scheduled_id);
  if src->>'revision' is distinct from e.revision then raise exception 'stale_prescription' using errcode='40001'; end if;
  if (src->'snapshot'->>'date')::date not between current_date-1 and current_date+14 then raise exception 'source_not_available' using errcode='42501'; end if;
  return jsonb_build_object('id',e.id,'serial',e.serial,'created_at',e.created_at,'snapshot',src->'snapshot');
 end if;
 raise invalid_parameter_value;
end $$;
revoke all on function device_private.ciq_command(text,uuid,uuid,jsonb) from public,anon,authenticated;
create function public.garmin_ciq_command(p_action text,p_owner uuid,p_session uuid,p_input jsonb)
returns jsonb language sql security invoker set search_path='' as $$
 select device_private.ciq_command(p_action,p_owner,p_session,p_input);
$$;
revoke all on function public.garmin_ciq_command(text,uuid,uuid,jsonb) from public,anon,authenticated;
grant execute on function public.garmin_ciq_command(text,uuid,uuid,jsonb) to service_role;
grant execute on function device_private.ciq_command(text,uuid,uuid,jsonb) to service_role;
commit;
