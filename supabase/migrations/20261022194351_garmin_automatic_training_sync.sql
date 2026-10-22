begin;

-- Preferencia ligada a una generación: reconectar otra cuenta nunca hereda el
-- permiso automático de la anterior. Desactivar no cancela citas ya enviadas.
create table device_private.training_sync_preferences (
 owner_id uuid primary key references auth.users(id) on delete cascade,
 enabled boolean not null default false,
 generation bigint not null,
 next_scan_at timestamptz not null default clock_timestamp()
);
create table device_private.training_sync_jobs (
 id uuid primary key default gen_random_uuid(),
 owner_id uuid not null references auth.users(id) on delete cascade,
 scheduled_id uuid not null,
 epoch bigint not null default 1,
 claimed_epoch bigint,
 target jsonb,
 state text not null default 'pending' check(state in ('pending','running','done','review')),
 lease_id uuid, lease_until timestamptz,
 next_attempt_at timestamptz not null default clock_timestamp(),
 attempts integer not null default 0,
 error_code text,
 updated_at timestamptz not null default clock_timestamp(),
 unique(owner_id,scheduled_id),
 check((lease_id is null)=(lease_until is null))
);
create index training_sync_due on device_private.training_sync_jobs(next_attempt_at) where state in ('pending','running');
create index training_sync_scan on device_private.training_sync_preferences(next_scan_at) where enabled;
create table device_private.training_delivery_versions (
 id bigint generated always as identity primary key,
 delivery_id uuid not null references device_private.training_deliveries(id) on delete cascade,
 revision text not null, snapshot jsonb not null, status text not null,
 workout_id bigint, schedule_id bigint, recorded_at timestamptz not null default clock_timestamp(),
 unique(delivery_id,revision,status)
);
create index training_delivery_versions_delivery on device_private.training_delivery_versions(delivery_id);
create table device_private.training_sync_worker (
 singleton boolean primary key default true check(singleton),
 enabled boolean not null default false,
 token_hash text not null check(token_hash ~ '^[0-9a-f]{64}$')
);
alter table device_private.training_sync_preferences enable row level security;
alter table device_private.training_sync_jobs enable row level security;
alter table device_private.training_delivery_versions enable row level security;
alter table device_private.training_sync_worker enable row level security;
revoke all on device_private.training_sync_preferences,device_private.training_sync_jobs,
 device_private.training_delivery_versions,device_private.training_sync_worker from public,anon,authenticated,service_role;
revoke all on sequence device_private.training_delivery_versions_id_seq from public,anon,authenticated,service_role;

-- Estados de operaciones sobre IDs conocidos: pueden repetirse sin crear otra
-- sesión. Un POST incierto conserva la política estricta de la entrega inicial.
alter table device_private.training_deliveries drop constraint training_deliveries_status_check;
alter table device_private.training_deliveries add constraint training_deliveries_status_check check(status in
 ('prepared','refreshing','creating','workout_created','scheduling','sent','failed','uncertain','updating','cancelling','cancelled'));

create function device_private.training_sync_enabled(p_owner uuid) returns boolean language sql stable set search_path='' as $$
 select exists(select 1 from device_private.training_sync_preferences p join device_private.garmin_connections c on c.owner_id=p.owner_id
 where p.owner_id=p_owner and p.enabled and p.generation=c.generation and c.status='connected' and c.can_send);
$$;
create function device_private.training_sync_target(p_owner uuid,p_schedule uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare s public.scheduled_workouts; d device_private.training_deliveries; src jsonb;
 today date:=(clock_timestamp() at time zone 'Europe/Madrid')::date;
begin
 select * into s from public.scheduled_workouts where user_id=p_owner and id=p_schedule;
 select * into d from device_private.training_deliveries where owner_id=p_owner and scheduled_id=p_schedule;
 -- No retirar ni reescribir entrenamientos comenzados o históricos.
 if s.id is not null and (s.execution_id is not null or s.status in ('in_progress','completed','abandoned') or s.scheduled_date<today)
  then return '{"mode":"hold"}'::jsonb; end if;
 if s.id is null and (d.id is null or (d.snapshot->>'date')::date<today) then return '{"mode":"hold"}'::jsonb; end if;
 if s.id is null or s.status in ('cancelled','skipped') then
  if d.workout_id is null and d.status in ('uncertain','creating','scheduling','refreshing') then return '{"mode":"review"}'::jsonb;end if;
  return jsonb_build_object('mode',case when d.workout_id is not null and d.status<>'cancelled' then 'cancel' else 'hold' end);
 end if;
 if s.id is not null and not exists(select 1 from public.workout_blocks where template_id=s.template_id and format='running') then return '{"mode":"hold"}'::jsonb;end if;
 if s.source not in ('coach','algorithm') or s.status<>'planned' then return '{"mode":"hold"}'::jsonb; end if;
 if d.id is null and s.scheduled_date>today+14 then return '{"mode":"hold"}'::jsonb; end if;
 if not device_private.garmin_access(p_owner) then return '{"mode":"hold"}'::jsonb; end if;
 -- Una decisión sustituida ya no publica prescripciones nuevas.
 if s.source='algorithm' and exists(select 1 from public.running_week_sessions rs join public.running_week_decisions w on w.id=rs.decision_id
  where rs.scheduled_workout_id=s.id and w.superseded_at is not null) then
  return jsonb_build_object('mode',case when d.workout_id is not null and d.status<>'cancelled' then 'cancel' else 'hold' end);
 end if;
 begin src:=device_private.training_source(p_owner,p_owner,p_schedule);
 exception when insufficient_privilege or serialization_failure then return '{"mode":"hold"}'::jsonb; end;
 return src||jsonb_build_object('mode','sync');
end $$;
create function device_private.training_sync_valid(p_owner uuid,p_input jsonb) returns boolean
language sql volatile set search_path='' as $$
 select exists(select 1 from device_private.training_sync_jobs j where j.id=(p_input->>'auto_job')::uuid
 and j.owner_id=p_owner and j.lease_id=(p_input->>'auto_lease')::uuid and j.state='running' and j.lease_until>clock_timestamp()
 and j.epoch=j.claimed_epoch and device_private.training_sync_enabled(p_owner)
 and j.target=device_private.training_sync_target(p_owner,j.scheduled_id));
$$;

-- El conciliador consulta únicamente transacciones confirmadas. No se añaden
-- triggers que bloqueen o cambien las escrituras profesionales/de algoritmo.
create function device_private.garmin_training_sync_preferences(p_owner uuid,p_session uuid,p_enabled boolean default null) returns jsonb
language plpgsql security definer set search_path='' as $$
declare c device_private.garmin_connections;
begin
 perform pg_advisory_xact_lock(hashtextextended('trainer-client:'||p_owner::text,0));
 if not exists(select 1 from auth.sessions where id=p_session and user_id=p_owner and (not_after is null or not_after>clock_timestamp())) then
  raise exception 'account_changed' using errcode='42501';end if;
 select * into c from device_private.garmin_connections where owner_id=p_owner for update;
 if p_enabled is not null then
  if p_enabled and (not device_private.garmin_access(p_owner) or c.status is distinct from 'connected' or not coalesce(c.can_send,false)) then
   raise exception 'access_required' using errcode='42501';end if;
  insert into device_private.training_sync_preferences(owner_id,enabled,generation) values(p_owner,p_enabled,coalesce(c.generation,0))
   on conflict(owner_id) do update set enabled=excluded.enabled,generation=excluded.generation,next_scan_at=clock_timestamp();
 end if;
 return jsonb_build_object('enabled',device_private.training_sync_enabled(p_owner),'window_days',14,
  'pending',(select count(*) from device_private.training_sync_jobs where owner_id=p_owner and state in ('pending','running')),
  'review',(select count(*) from device_private.training_sync_jobs where owner_id=p_owner and state='review'));
end $$;
revoke all on function device_private.garmin_training_sync_preferences(uuid,uuid,boolean) from public,anon,authenticated;
grant execute on function device_private.garmin_training_sync_preferences(uuid,uuid,boolean) to service_role;
create function public.garmin_training_sync_preferences(p_owner uuid,p_session uuid,p_enabled boolean default null) returns jsonb
language sql security invoker set search_path='' as $$select device_private.garmin_training_sync_preferences(p_owner,p_session,p_enabled);$$;
revoke all on function public.garmin_training_sync_preferences(uuid,uuid,boolean) from public,anon,authenticated;
grant execute on function public.garmin_training_sync_preferences(uuid,uuid,boolean) to service_role;

-- Solo la fachada de servidor puede presentar una prueba de trabajo reclamada.
-- El endpoint manual no copia estos campos de una petición del cliente.
do $$declare definition text; anchor text:='perform 1 from auth.sessions where id=p_session';begin
 definition:=pg_get_functiondef('device_private.garmin_training_command(text,uuid,uuid,uuid,jsonb)'::regprocedure);
 if strpos(definition,anchor)=0 then raise exception 'Revisar contrato de autenticación de entrega';end if;
 definition:=replace(definition,anchor,'if p_session is null and p_actor=p_owner and device_private.training_sync_valid(p_owner,p_input) then null; else '||anchor);
 anchor:='if p_action=''list'' then';
 definition:=replace(definition,anchor,'end if; '||anchor);
 execute definition;
end $$;

create function device_private.garmin_training_sync_command(p_action text,p_input jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare j device_private.training_sync_jobs; c device_private.garmin_connections; d device_private.training_deliveries;
 p device_private.training_sync_preferences; x record; t jsonb; v_now timestamptz:=clock_timestamp(); v_lease uuid; v_out text;
begin
 if jsonb_typeof(p_input)<>'object' or octet_length(p_input::text)>40000 then raise invalid_parameter_value;end if;
 if p_action='authorize' then return jsonb_build_object('authorized',exists(select 1 from device_private.training_sync_worker
  where enabled and token_hash=encode(sha256(convert_to(p_input->>'token','UTF8')),'hex')));end if;
 if p_action='scan' then
  for p in select * from device_private.training_sync_preferences where enabled and next_scan_at<=v_now order by next_scan_at limit 200 for update skip locked loop
   if device_private.training_sync_enabled(p.owner_id) then
    for x in select id from public.scheduled_workouts where user_id=p.owner_id and source in ('coach','algorithm')
       and scheduled_date between (v_now at time zone 'Europe/Madrid')::date and (v_now at time zone 'Europe/Madrid')::date+14
     union select scheduled_id from device_private.training_deliveries where owner_id=p.owner_id and (snapshot->>'date')::date>=(v_now at time zone 'Europe/Madrid')::date loop
     t:=device_private.training_sync_target(p.owner_id,x.id);
     insert into device_private.training_sync_jobs(owner_id,scheduled_id) values(p.owner_id,x.id)
      on conflict(owner_id,scheduled_id) do update set state=case when training_sync_jobs.state='running' then 'running' else 'pending' end,
       epoch=training_sync_jobs.epoch+1,next_attempt_at=v_now
      where training_sync_jobs.target is distinct from t;
    end loop;
   end if;
   update device_private.training_sync_preferences set next_scan_at=v_now+interval '1 minute' where owner_id=p.owner_id;
  end loop;
  return '{}'::jsonb;
 end if;
 if p_action='take' then
  select q.* into j from device_private.training_sync_jobs q where q.state in ('pending','running') and q.next_attempt_at<=v_now
   and (q.lease_until is null or q.lease_until<=v_now) and device_private.training_sync_enabled(q.owner_id)
   order by q.next_attempt_at,q.id limit 1 for update skip locked;
  if j.id is null then return '{}'::jsonb;end if;
  t:=device_private.training_sync_target(j.owner_id,j.scheduled_id);v_lease:=gen_random_uuid();
  select * into d from device_private.training_deliveries where owner_id=j.owner_id and scheduled_id=j.scheduled_id;
  update device_private.training_sync_jobs set target=t,state='running',lease_id=v_lease,lease_until=v_now+interval '3 minutes',
   claimed_epoch=epoch,attempts=attempts+1,updated_at=v_now where id=j.id;
  return jsonb_build_object('id',j.id,'owner',j.owner_id,'scheduled',j.scheduled_id,'lease',v_lease,'target',t,
   'operation',case when d.workout_id is null then 'create' else 'change' end);
 end if;
 select * into j from device_private.training_sync_jobs where id=(p_input->>'job_id')::uuid;
 if j.id is null then raise insufficient_privilege;end if;
 perform pg_advisory_xact_lock(hashtextextended('trainer-client:'||j.owner_id::text,0));
 select * into c from device_private.garmin_connections where owner_id=j.owner_id for update;
 select * into j from device_private.training_sync_jobs where id=j.id for update;
 if (j.state<>'running' and p_action<>'release_change') or j.lease_id is distinct from (p_input->>'job_lease')::uuid or j.lease_until<=v_now then
  raise exception 'stale_attempt' using errcode='40001';end if;
 if p_action='finish' then
  v_out:=p_input->>'outcome';if v_out not in ('done','review','retry') then raise invalid_parameter_value;end if;
  if v_out<>'done' and c.training_lease=j.lease_id then
   update device_private.training_deliveries set status=case when coalesce((p_input->>'refresh_uncertain')::boolean,false) then 'uncertain' else 'failed' end,
    error_code=case when p_input->>'code' in ('provider_rejected','provider_unavailable','rate_limited','permission_denied','reauthorization_required',
     'delivery_uncertain','connection_changed','stale_prescription') then p_input->>'code' else 'garmin_unavailable' end,
    updated_at=v_now where owner_id=j.owner_id and scheduled_id=j.scheduled_id and status in ('updating','cancelling','refreshing');
  end if;
  if coalesce((p_input->>'refresh_uncertain')::boolean,false) then
   update device_private.garmin_connections set status='revocation_pending',can_read=false,can_send=false where owner_id=j.owner_id;
  end if;
  update device_private.training_sync_jobs set state=case when epoch<>claimed_epoch then 'pending' when v_out='retry' then 'pending' else v_out end,
   next_attempt_at=v_now+make_interval(secs=>case when epoch<>claimed_epoch then 0 else least(3600,30*power(2,least(attempts,7))::integer) end),
   error_code=case when p_input->>'code' in ('provider_rejected','provider_unavailable','rate_limited','permission_denied','reauthorization_required',
     'delivery_uncertain','delivery_needs_review','connection_changed','stale_attempt','unsupported_prescription','invalid_prescription','provider_missing') then p_input->>'code' else null end,
   lease_id=case when c.training_lease=j.lease_id then lease_id else null end,
   lease_until=case when c.training_lease=j.lease_id then lease_until else null end,
   updated_at=v_now where id=j.id;
  -- El lease de cambio se libera después de guardar el resultado incluso si la
  -- cuenta desactiva la automatización durante la petición HTTP.
  return '{}'::jsonb;
 end if;
 if p_action='claim_change' then
  if not device_private.training_sync_valid(j.owner_id,jsonb_build_object('auto_job',j.id,'auto_lease',j.lease_id)) then
   raise exception 'stale_attempt' using errcode='40001';end if;
  if c.training_lease_until>v_now or c.disconnect_lease_until>v_now then raise exception 'connection_busy' using errcode='40001';end if;
  select * into d from device_private.training_deliveries where owner_id=j.owner_id and scheduled_id=j.scheduled_id for update;
  if d.workout_id is null or d.connection_generation<>c.generation or d.status in ('uncertain','refreshing','creating','scheduling','cancelled')
   or (j.target->>'mode'='sync' and d.schedule_id is null) then raise exception 'delivery_needs_review' using errcode='40001';end if;
  insert into device_private.training_delivery_versions(delivery_id,revision,snapshot,status,workout_id,schedule_id)
   values(d.id,d.revision,d.snapshot,d.status,d.workout_id,d.schedule_id) on conflict(delivery_id,revision,status) do nothing;
  update device_private.garmin_connections set training_lease=j.lease_id,training_lease_until=j.lease_until where owner_id=j.owner_id;
  update device_private.training_deliveries set lease_id=j.lease_id,lease_until=j.lease_until,lease_actor=j.owner_id,lease_session=null,
   status=case when j.target->>'mode'='cancel' then 'cancelling' else 'updating' end where id=d.id;
  return jsonb_build_object('generation',c.generation,'tokens_cipher',c.tokens_cipher,'access_expires_at',c.access_expires_at,
   'refresh_expires_at',c.refresh_expires_at,'garmin_user_id',c.garmin_user_id,'workout_id',d.workout_id,'schedule_id',d.schedule_id);
 end if;
 if c.training_lease is distinct from j.lease_id then raise exception 'stale_attempt' using errcode='40001';end if;
 if p_action='release_change' then
  update device_private.garmin_connections set training_lease=null,training_lease_until=null where owner_id=j.owner_id;
  update device_private.training_deliveries set lease_id=null,lease_until=null where owner_id=j.owner_id and scheduled_id=j.scheduled_id;
  update device_private.training_sync_jobs set lease_id=null,lease_until=null where id=j.id;
  return '{}'::jsonb;
 end if;
 if c.training_lease_until<=v_now then raise exception 'stale_attempt' using errcode='40001';end if;
 if p_action in ('before_write','mark_refreshing') then
  if not device_private.training_sync_valid(j.owner_id,jsonb_build_object('auto_job',j.id,'auto_lease',j.lease_id)) then
   raise exception 'stale_attempt' using errcode='40001';end if;
  if p_action='mark_refreshing' then update device_private.training_deliveries set status='refreshing' where owner_id=j.owner_id and scheduled_id=j.scheduled_id;end if;
 elsif p_action='rotate' then
  if coalesce(p_input->>'tokens_cipher','')='' or not isfinite((p_input->>'access_expires_at')::timestamptz)
   or not isfinite((p_input->>'refresh_expires_at')::timestamptz) or (p_input->>'access_expires_at')::timestamptz<=v_now
   or (p_input->>'refresh_expires_at')::timestamptz<=v_now then raise invalid_parameter_value;end if;
  update device_private.garmin_connections set tokens_cipher=p_input->>'tokens_cipher',access_expires_at=(p_input->>'access_expires_at')::timestamptz,
   refresh_expires_at=(p_input->>'refresh_expires_at')::timestamptz where owner_id=j.owner_id;
  update device_private.training_deliveries set status=case when j.target->>'mode'='cancel' then 'cancelling' else 'updating' end where owner_id=j.owner_id and scheduled_id=j.scheduled_id;
 elsif p_action='permissions' then
  update device_private.garmin_connections set can_read=status='connected' and (p_input->>'can_read')::boolean,
   can_send=status='connected' and (p_input->>'can_send')::boolean where owner_id=j.owner_id;
 elsif p_action='save_change' then
  -- Guardar el hecho remoto aunque haya llegado una revisión nueva. El epoch
  -- conserva esa revisión pendiente para el siguiente ciclo.
  update device_private.training_deliveries set status=case when j.target->>'mode'='cancel' then 'cancelled' else 'sent' end,
   revision=case when j.target->>'mode'='sync' then j.target->>'revision' else revision end,
   snapshot=case when j.target->>'mode'='sync' then j.target->'snapshot' else snapshot end,error_code=null,updated_at=v_now
   where owner_id=j.owner_id and scheduled_id=j.scheduled_id;
 else raise invalid_parameter_value;end if;
 return '{}'::jsonb;
end $$;
revoke all on function device_private.garmin_training_sync_command(text,jsonb) from public,anon,authenticated;
grant execute on function device_private.garmin_training_sync_command(text,jsonb) to service_role;
create function public.garmin_training_sync_command(p_action text,p_input jsonb) returns jsonb
language sql security invoker set search_path='' as $$select device_private.garmin_training_sync_command(p_action,p_input);$$;
revoke all on function public.garmin_training_sync_command(text,jsonb) from public,anon,authenticated;
grant execute on function public.garmin_training_sync_command(text,jsonb) to service_role;
revoke all on function device_private.training_sync_enabled(uuid),device_private.training_sync_target(uuid,uuid),
 device_private.training_sync_valid(uuid,jsonb) from public,anon,authenticated,service_role;
commit;
