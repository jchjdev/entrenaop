begin;

create or replace function device_private.activity_source(p_actor uuid,p_owner uuid,p_schedule uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare s public.scheduled_workouts; t public.workout_templates; a public.trainer_assignments;
 decision jsonb; recipe jsonb;
begin
 select * into s from public.scheduled_workouts where id=p_schedule and user_id=p_owner for share;
 if not found or s.status<>'planned' or s.execution_id is not null then raise exception 'source_not_available' using errcode='42501'; end if;
 select * into t from public.workout_templates where id=s.template_id for share;
 if not found or t.status not in ('published','archived') or t.version<>s.template_version then raise exception 'stale_prescription' using errcode='40001'; end if;
 if s.source='algorithm' then
  if p_actor<>p_owner or t.origin is distinct from 'algorithm' or t.owner_user_id is distinct from p_owner then raise insufficient_privilege; end if;
  select jsonb_build_object('decision_id',d.id,'policy_version',d.policy_version) into decision
   from public.running_week_sessions rs join public.running_week_decisions d on d.id=rs.decision_id
   join public.preparation_goals g on g.id=s.preparation_goal_id
   where rs.scheduled_workout_id=s.id and d.user_id=p_owner and d.preparation_goal_id=g.id and g.user_id=p_owner and g.status='active';
  if decision is null then raise exception 'source_not_allowed' using errcode='42501'; end if;
 elsif s.source='coach' then
  select * into a from public.trainer_assignments where scheduled_id=s.id and client_id=p_owner;
  if not found or (p_actor<>p_owner and a.trainer_id<>p_actor) then raise insufficient_privilege; end if;
  if not exists(select 1 from public.trainer_client_relations r join public.trainer_access x on x.trainer_id=r.trainer_id
    where r.id=a.relation_id and r.client_id=p_owner and r.trainer_id=a.trainer_id and r.ended_at is null and x.enabled
    and (x.valid_until is null or x.valid_until>clock_timestamp())) then raise insufficient_privilege; end if;
  if t.origin is distinct from 'coach' or t.owner_user_id is distinct from a.trainer_id then raise exception 'source_not_allowed' using errcode='42501'; end if;
  decision:=jsonb_build_object('assignment_id',s.id,'planning_revision',a.planning_revision);
 else raise exception 'source_not_allowed' using errcode='42501'; end if;
 select jsonb_build_object('name',s.template_name,'description',t.description,'date',s.scheduled_date,'source',s.source,
   'template_id',t.id,'template_version',t.version,'authority',decision,'blocks',coalesce(jsonb_agg(
    jsonb_build_object('order_index',b.order_index,'name',b.name,'format',b.format,'rounds',b.rounds,
      'rest_after_seconds',b.rest_after_seconds,'time_cap_seconds',b.time_cap_seconds,'items',
      (select coalesce(jsonb_agg(jsonb_build_object('order_index',i.order_index,'exercise_id',i.exercise_id,'notes',i.notes,
       'sets',(select coalesce(jsonb_agg((to_jsonb(w)-'id'-'item_id'-'running_step') || case when w.running_step is null then '{}'::jsonb else jsonb_build_object('running_step',w.running_step) end order by w.order_index),'[]'::jsonb)
        from public.workout_sets w where w.item_id=i.id)) order by i.order_index),'[]'::jsonb)
       from public.workout_items i where i.block_id=b.id)) order by b.order_index),'[]'::jsonb)) into recipe
  from public.workout_blocks b where b.template_id=t.id;
 if octet_length(recipe::text)>131072 then raise exception 'unsupported_prescription' using errcode='22023'; end if;
 -- Archivar la biblioteca no retira una pauta ya entregada y aún vigente.
 if t.status='archived' and (s.source<>'coach' or not exists(
   select 1 from device_private.training_deliveries d where d.owner_id=p_owner
   and d.scheduled_id=s.id and d.status='sent' and d.snapshot=recipe
   and d.revision=encode(sha256(convert_to(recipe::text,'UTF8')),'hex'))) then
  raise exception 'stale_prescription' using errcode='40001'; end if;
 return jsonb_build_object('snapshot',recipe,'revision',encode(sha256(convert_to(recipe::text,'UTF8')),'hex'));
end $$;
revoke all on function device_private.activity_source(uuid,uuid,uuid) from public,anon,authenticated,service_role;

create or replace function device_private.garmin_activity_command(p_action text,p_owner uuid,p_session uuid,p_input jsonb)
returns jsonb language plpgsql security definer set search_path='' as $$
declare
 c device_private.garmin_connections; j device_private.activity_return_jobs;
 a device_private.activity_observations; receipt device_private.activity_confirmations;
 u uuid:=p_owner; v_id uuid; v_lease uuid; v_now timestamptz:=clock_timestamp();
 src jsonb; snap jsonb; current_aal text; v_input_hash text;
 s public.scheduled_workouts; e uuid; v_mapping jsonb; m jsonb; lap jsonb; recovery jsonb;
 r public.workout_execution_sets; seen uuid[]:='{}'; used integer[]:='{}'; li integer; ri integer;
 offset_minutes integer; v_rpe integer;
begin
 if p_input is null or jsonb_typeof(p_input)<>'object' or octet_length(p_input::text)>540000 then
  raise exception 'invalid_request' using errcode='22023'; end if;
 if p_action='authorize' then
  update device_private.activity_return_worker set ticket_used=true where enabled and not ticket_used
   and ticket_expires_at>v_now and token_hash=encode(sha256(convert_to(p_input->>'token','UTF8')),'hex');
  return jsonb_build_object('authorized',found);
 end if;
 if p_action='enqueue' then
  select * into c from device_private.garmin_connections where garmin_user_id=p_input->>'provider_user_id'
   and status='connected' and can_read;
  if not found or not device_private.garmin_access(c.owner_id) then return jsonb_build_object('ignored',true); end if;
  perform 1 from auth.users where id=c.owner_id for key share;
  if not found then return jsonb_build_object('ignored',true); end if;
  select * into c from device_private.garmin_connections where owner_id=c.owner_id for update;
  if c.status<>'connected' or not c.can_read or c.garmin_user_id is distinct from p_input->>'provider_user_id' then
   return jsonb_build_object('ignored',true); end if;
  if exists(select 1 from device_private.activity_return_jobs where event_key=p_input->>'event_key') then
   return jsonb_build_object('queued',true); end if;
  if (select count(*) from device_private.activity_return_jobs where owner_id=c.owner_id and status in ('pending','running'))>=100 then
   raise exception 'activity_queue_full' using errcode='54000'; end if;
  insert into device_private.activity_return_jobs(id,event_key,owner_id,generation,callback_cipher,metadata)
   values((p_input->>'id')::uuid,p_input->>'event_key',c.owner_id,c.generation,p_input->>'callback_cipher',p_input->'metadata')
   on conflict(event_key) do nothing;
  return jsonb_build_object('queued',true);
 end if;
 if p_action='pending' then
  -- Tras caída del worker, una descarga o renovación incierta exige revisión.
  for j in select * from device_private.activity_return_jobs where status='running' and lease_until<v_now loop
   perform pg_advisory_xact_lock(hashtextextended('trainer-client:'||j.owner_id::text,0));
   update device_private.garmin_connections set training_lease=null,training_lease_until=null,
    status=case when j.phase='refreshing' then 'revocation_pending' else status end
    where owner_id=j.owner_id and training_lease=j.lease_id;
   update device_private.activity_return_jobs set status='review',error_code='activity_uncertain',callback_cipher=null
    where id=j.id and status='running' and lease_until<v_now;
  end loop;
  delete from device_private.activity_return_jobs where created_at<v_now-interval '7 days' and status in ('done','review');
  return jsonb_build_object('ids',(select coalesce(jsonb_agg(id),'[]'::jsonb) from
   (select id from device_private.activity_return_jobs where status='pending' and next_attempt_at<=v_now order by created_at limit 5) x));
 end if;
 if p_action in ('claim','refreshing','rotate','downloading','save','failed','release') then
  select owner_id into u from device_private.activity_return_jobs where id=(p_input->>'id')::uuid;
  if u is null then raise exception 'activity_not_found' using errcode='42501'; end if;
 end if;
 if u is null then raise insufficient_privilege; end if;
 perform pg_advisory_xact_lock(hashtextextended('trainer-client:'||u::text,0));
 perform 1 from auth.users where id=u for key share;
 if not found then raise exception 'account_changed' using errcode='42501'; end if;
 if p_action in ('list','preview','confirm') then
  select aal into current_aal from auth.sessions where id=p_session and user_id=u
   and (not_after is null or not_after>v_now) for key share;
  if not found then raise exception 'account_changed' using errcode='42501'; end if;
  perform set_config('request.jwt.claim.sub',u::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',u,'session_id',p_session,'role','authenticated','aal',current_aal)::text,true);
 end if;
 if p_action='list' then
  return jsonb_build_object('activities',(select coalesce(jsonb_agg(to_jsonb(x)),'[]'::jsonb) from (
   select z.id,z.external_id,z.revision,z.observation-'laps' as activity,
    (select f.execution_id from device_private.activity_confirmations f where f.owner_id=u and f.external_id=z.external_id) as execution_id
    from (select distinct on(external_id) * from device_private.activity_observations where owner_id=u
      order by external_id,created_at desc,id desc) z order by z.created_at desc,z.id desc limit 50) x),
   'candidates',(select coalesce(jsonb_agg(to_jsonb(x)),'[]'::jsonb) from (
    select sw.id,sw.template_name as name,sw.scheduled_date as date,sw.source from public.scheduled_workouts sw
    where sw.user_id=u and sw.status='planned' and sw.execution_id is null and sw.source in ('coach','algorithm')
     and sw.scheduled_date between current_date-90 and current_date+14
     and exists(select 1 from public.workout_blocks b where b.template_id=sw.template_id and b.format='running')
    order by sw.scheduled_date desc,sw.order_index limit 100) x),
   'problems',(select coalesce(jsonb_agg(to_jsonb(x)),'[]'::jsonb) from (
    select error_code,created_at from device_private.activity_return_jobs where owner_id=u and status='review'
    order by created_at desc limit 10) x));
 end if;
 if p_action in ('preview','confirm') then
  v_input_hash:=encode(sha256(convert_to(p_input::text,'UTF8')),'hex');
  if p_action='confirm' then
   select * into receipt from device_private.activity_confirmations where id=(p_input->>'operation_id')::uuid;
   if found then
    if receipt.owner_id<>u or receipt.input_hash<>v_input_hash then raise exception 'operation_reused' using errcode='22023'; end if;
    return jsonb_build_object('execution_id',receipt.execution_id,'replayed',true);
   end if;
  end if;
  select * into a from device_private.activity_observations where id=(p_input->>'activity_id')::uuid and owner_id=u for share;
  if not found then raise exception 'activity_not_found' using errcode='42501'; end if;
  if exists(select 1 from device_private.activity_confirmations where owner_id=u and external_id=a.external_id) then
   raise exception 'activity_already_confirmed' using errcode='22023'; end if;
  if a.id is distinct from (select id from device_private.activity_observations where owner_id=u and external_id=a.external_id
     order by created_at desc,id desc limit 1) then raise exception 'stale_activity' using errcode='40001'; end if;
  select * into s from public.scheduled_workouts where id=(p_input->>'scheduled_id')::uuid and user_id=u for update;
  if not found then raise exception 'source_not_available' using errcode='42501'; end if;
  src:=device_private.activity_source(u,u,s.id); snap:=src->'snapshot';
  if p_action='preview' then
   return jsonb_build_object('activity_id',a.id,'activity_revision',a.revision,'activity',a.observation,
    'scheduled_id',s.id,'snapshot',snap,'source_revision',src->>'revision'); end if;
  if src->>'revision' is distinct from p_input->>'source_revision' or a.revision is distinct from p_input->>'activity_revision' then
   raise exception 'stale_review' using errcode='40001'; end if;
  v_rpe:=(p_input->>'rpe')::integer;
  if v_rpe is null or v_rpe not between 1 and 10 then raise exception 'invalid_rpe' using errcode='22023'; end if;
  if a.observation->>'offsetSeconds' is not null and (a.observation->>'offsetSeconds')::integer%60<>0 then
   raise exception 'invalid_offset' using errcode='22023'; end if;
  offset_minutes:=coalesce((a.observation->>'offsetSeconds')::integer/60,(p_input->>'utc_offset_minutes')::integer);
  if offset_minutes is null or offset_minutes not between -840 and 840 then raise exception 'invalid_offset' using errcode='22023'; end if;
  v_mapping:=p_input->'mapping';
  if jsonb_typeof(v_mapping) is distinct from 'array' or jsonb_array_length(v_mapping)>100 then
   raise exception 'invalid_mapping' using errcode='22023'; end if;
  e:=public.start_scheduled_workout(s.id);
  -- La ejecución nace ahora, pero representa un entrenamiento ya realizado.
  -- El reloj procede de la evidencia; completed_at conserva el momento de confirmación.
  if (a.observation->>'startedAt')::timestamptz>v_now+interval '5 minutes'
    or (a.observation->>'startedAt')::timestamptz<'2000-01-01'::timestamptz then
   raise exception 'invalid_activity_clock' using errcode='22023'; end if;
  update public.workout_executions set started_at=(a.observation->>'startedAt')::timestamptz,
   observed_timer_seconds=(a.observation->>'timerSeconds')::numeric,
   observed_elapsed_seconds=(a.observation->>'elapsedSeconds')::numeric,
   observed_distance_meters=(a.observation->>'distanceMeters')::numeric where id=e;
  if jsonb_array_length(v_mapping)<>(select count(*) from public.workout_execution_sets where execution_id=e) then
   raise exception 'invalid_mapping' using errcode='22023'; end if;
  perform device_private.apply_activity_mapping(e,a.observation,v_mapping);
  perform public.finish_workout_observed_idempotent((p_input->>'operation_id')::uuid,e,v_rpe,
   (a.observation->>'startedAt')::timestamptz,offset_minutes,null,
   round((a.observation->>'averageHeartRate')::numeric)::integer,round((a.observation->>'maxHeartRate')::numeric)::integer,'device');
  insert into device_private.activity_confirmations(id,owner_id,activity_id,external_id,scheduled_id,execution_id,source_revision,input_hash,mapping)
   values((p_input->>'operation_id')::uuid,u,a.id,a.external_id,s.id,e,src->>'revision',v_input_hash,v_mapping);
  return jsonb_build_object('execution_id',e,'replayed',false);
 end if;
 select * into c from device_private.garmin_connections where owner_id=u for update;
 select * into j from device_private.activity_return_jobs where id=(p_input->>'id')::uuid and owner_id=u for update;
 if not found then raise exception 'activity_not_found' using errcode='42501'; end if;
 if p_action='claim' then
  if j.status<>'pending' then return jsonb_build_object('done',true); end if;
  if c.status<>'connected' or not c.can_read or c.generation<>j.generation or not device_private.garmin_access(u) then
   update device_private.activity_return_jobs set status='review',error_code='connection_changed',callback_cipher=null where id=j.id;
   return jsonb_build_object('done',true); end if;
  if c.training_lease is not null then return jsonb_build_object('busy',true); end if;
  v_lease:=(p_input->>'lease_id')::uuid;
  update device_private.garmin_connections set training_lease=v_lease,training_lease_until=v_now+interval '90 seconds' where owner_id=u;
  update device_private.activity_return_jobs set status='running',phase='claimed',lease_id=v_lease,lease_until=v_now+interval '90 seconds',attempts=attempts+1 where id=j.id;
  return jsonb_build_object('id',j.id,'owner',u,'generation',j.generation,'lease',v_lease,'callback',j.callback_cipher,'metadata',j.metadata,
   'tokens',c.tokens_cipher,'accessExpiresAt',c.access_expires_at,'refreshExpiresAt',c.refresh_expires_at,'providerUserId',c.garmin_user_id);
 end if;
 if j.lease_id is distinct from (p_input->>'lease_id')::uuid or c.training_lease is distinct from j.lease_id then
  raise exception 'connection_changed' using errcode='40001'; end if;
 if p_action='release' then
  update device_private.garmin_connections set training_lease=null,training_lease_until=null where owner_id=u and training_lease=j.lease_id;
  return '{}'::jsonb; end if;
 if j.lease_until<v_now or c.generation<>j.generation then raise exception 'connection_changed' using errcode='40001'; end if;
 -- Igual que en el envío: conservar una renovación ya devuelta aunque el
 -- usuario desconecte mientras Garmin responde; la revocación necesita el token nuevo.
 if p_action='rotate' then
  update device_private.garmin_connections set tokens_cipher=p_input->>'tokens_cipher',
   access_expires_at=(p_input->>'access_expires_at')::timestamptz,refresh_expires_at=(p_input->>'refresh_expires_at')::timestamptz where owner_id=u;
  return '{}'::jsonb;
 end if;
 if p_action not in ('failed') and c.status<>'connected' then raise exception 'connection_changed' using errcode='40001'; end if;
 if p_action in ('refreshing','downloading') then
  update device_private.activity_return_jobs set phase=p_action where id=j.id; return '{}'::jsonb;
 elsif p_action='failed' then
  if c.status='connected' and not coalesce((p_input->>'uncertain')::boolean,false) and p_input->>'code' in ('provider_unavailable','rate_limited','activity_unavailable') and j.attempts<3 then
   update device_private.activity_return_jobs set status='pending',error_code=left(p_input->>'code',80),
    next_attempt_at=v_now+make_interval(secs=>30*power(2,j.attempts)::integer) where id=j.id;
  else
   update device_private.activity_return_jobs set status='review',error_code=left(p_input->>'code',80),callback_cipher=null where id=j.id;
  end if;
  if j.phase='refreshing' and coalesce((p_input->>'uncertain')::boolean,false) then
   update device_private.garmin_connections set status='revocation_pending' where owner_id=u; end if;
  if p_input->>'code'='permission_denied' then update device_private.garmin_connections set can_read=false where owner_id=u; end if;
  return '{}'::jsonb;
 elsif p_action='save' then
  if c.status<>'connected' or not c.can_read or not device_private.garmin_access(u) then raise insufficient_privilege; end if;
  v_input_hash:=encode(sha256(convert_to((p_input->'activity')::text,'UTF8')),'hex');
  insert into device_private.activity_observations(owner_id,channel,external_id,revision,observation)
   values(u,'garmin',p_input->'activity'->>'externalId',v_input_hash,p_input->'activity')
   on conflict(owner_id,channel,external_id,revision) do nothing;
  update device_private.activity_return_jobs set status='done',phase='stored',callback_cipher=null where id=j.id;
  return '{}'::jsonb;
 end if;
 raise exception 'invalid_request' using errcode='22023';
end $$;

commit;
