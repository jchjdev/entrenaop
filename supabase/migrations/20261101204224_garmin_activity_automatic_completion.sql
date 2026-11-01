begin;

alter table device_private.activity_return_jobs
 add column completion_state text check(completion_state in ('completed','review')),
 add column completion_code text;

-- Conservamos el receptor/manual existente y sus ACL. Las acciones nuevas son
-- exclusivas del trabajador con el lease vivo que acaba de guardar el FIT.
do $$declare definition text;begin
 definition:=pg_get_functiondef('device_private.garmin_activity_command(text,uuid,uuid,jsonb)'::regprocedure);
 execute replace(definition,'device_private.garmin_activity_command(', 'device_private.garmin_activity_received_v1(');
end $$;
revoke all on function device_private.garmin_activity_received_v1(text,uuid,uuid,jsonb) from public,anon,authenticated,service_role;

create function device_private.garmin_automatic_result(p_action text,p_owner uuid,p_input jsonb)
returns jsonb language plpgsql security definer set search_path='' as $$
declare j device_private.activity_return_jobs;c device_private.garmin_connections;
 a device_private.activity_observations;d device_private.training_deliveries;
 receipt device_private.activity_confirmations;source jsonb;candidates jsonb;local_day date;offset_minutes integer;
 execution uuid;operation uuid;mapping jsonb;count_rows integer;code text;
 previous_claims text;previous_sub text;context_changed boolean:=false;
begin
 if auth.jwt()->>'role' is distinct from 'service_role' or p_owner is null or
  p_input is null or jsonb_typeof(p_input)<>'object' then raise insufficient_privilege;end if;
 -- Mismo orden de exclusión que planificación, archivo y desconexión.
 perform pg_advisory_xact_lock(hashtextextended('trainer-client:'||p_owner::text,0));
 select * into c from device_private.garmin_connections where owner_id=p_owner for update;
 select * into j from device_private.activity_return_jobs where id=(p_input->>'id')::uuid and owner_id=p_owner for update;
 if not found or c.owner_id is null or j.status<>'done' or j.phase<>'stored'
  or j.lease_id is distinct from (p_input->>'lease_id')::uuid or j.lease_until is null or j.lease_until<=clock_timestamp()
  or c.training_lease_until is null or c.training_lease_until<=clock_timestamp()
  or c.training_lease is distinct from j.lease_id or c.generation<>j.generation then
  raise exception 'connection_changed' using errcode='40001';end if;
 if c.status<>'connected' or not c.can_read or not device_private.garmin_access(p_owner) then raise insufficient_privilege;end if;
 select * into a from device_private.activity_observations where owner_id=p_owner and channel='garmin'
  and external_id=j.metadata->>'activityId' and id=(p_input->>'activity_id')::uuid and revision=p_input->>'activity_revision';
 if not found then raise exception 'activity_not_found' using errcode='22023';end if;
 select * into receipt from device_private.activity_confirmations where owner_id=p_owner and external_id=a.external_id;
 if found then
  update device_private.activity_return_jobs set completion_state='completed',completion_code=null where id=j.id;
  return jsonb_build_object('completed',true,'execution_id',receipt.execution_id);
 end if;
 if p_action='automatic.review' then
  code:=case when p_input->>'code' in ('ambiguous_prescription','prescription_not_identified','stale_prescription','intervals_require_review')
    then p_input->>'code' else 'review_required' end;
  update device_private.activity_return_jobs set completion_state='review',completion_code=code where id=j.id;
  return jsonb_build_object('blocked',true,'code',code);
 end if;
 if a.observation->>'prescriptionReference' is null or a.observation->>'offsetSeconds' is null or
  (a.observation->>'offsetSeconds')::integer%60<>0 then
  update device_private.activity_return_jobs set completion_state='review',completion_code='reference_or_timezone_required' where id=j.id;
  return jsonb_build_object('blocked',true,'code','reference_or_timezone_required');end if;
 offset_minutes:=(a.observation->>'offsetSeconds')::integer/60;
 if offset_minutes not between -840 and 840 then raise invalid_parameter_value;end if;
 local_day:=(((a.observation->>'startedAt')::timestamptz at time zone 'UTC')+make_interval(mins=>offset_minutes))::date;
 if p_action='automatic.context' then
  -- Incluye versiones retiradas: ocultarlas podría hacer pasar por inequívoca
  -- una receta compartida con otra cita o con una versión antigua.
  with versions as (
   select t.scheduled_id,t.revision,t.snapshot,true as current from device_private.training_deliveries t
    where t.owner_id=p_owner and t.provider='garmin' and (t.snapshot->>'date')::date between local_day-7 and local_day
   union
   select t.scheduled_id,v.revision,v.snapshot,false from device_private.training_delivery_versions v
    join device_private.training_deliveries t on t.id=v.delivery_id
    where t.owner_id=p_owner and t.provider='garmin' and (v.snapshot->>'date')::date between local_day-7 and local_day
  ), bounded as (select * from versions limit 201)
  select count(*),coalesce(jsonb_agg(to_jsonb(bounded)),'[]') into count_rows,candidates from bounded;
  if count_rows>200 or octet_length(candidates::text)>2097152 then
   update device_private.activity_return_jobs set completion_state='review',completion_code='too_many_candidates' where id=j.id;
   return jsonb_build_object('blocked',true,'code','too_many_candidates');end if;
  return jsonb_build_object('activity_id',a.id,'activity_revision',a.revision,'candidates',candidates);
 end if;
 if p_action<>'automatic.complete' then raise invalid_parameter_value;end if;
 if a.id is distinct from (p_input->>'activity_id')::uuid or a.revision is distinct from p_input->>'activity_revision' then
  raise exception 'stale_review' using errcode='40001';end if;
 select * into d from device_private.training_deliveries where owner_id=p_owner and provider='garmin'
  and scheduled_id=(p_input->>'scheduled_id')::uuid for update;
 if not found or d.status<>'sent' or d.connection_generation<>c.generation or d.revision is distinct from p_input->>'delivery_revision' then
  raise exception 'stale_prescription' using errcode='40001';end if;
 source:=device_private.activity_source(p_owner,p_owner,d.scheduled_id);
 if source->'snapshot'<>d.snapshot or not device_private.activity_in_completion_window(
  (a.observation->>'startedAt')::timestamptz,offset_minutes,(d.snapshot->>'date')::date) then
  raise exception 'stale_prescription' using errcode='40001';end if;
 if coalesce(source->'snapshot'->>'sport','running')<>coalesce(a.observation->>'sport','running') then raise invalid_parameter_value;end if;
 mapping:=p_input->'mapping';
 if jsonb_typeof(mapping) is distinct from 'array' or jsonb_array_length(mapping) not between 1 and 100 or
  exists(select 1 from jsonb_array_elements(mapping) x where coalesce((x->>'skipped')::boolean,false)) then raise invalid_parameter_value;end if;
 operation:=substr(device_private.history_hash(jsonb_build_object('automatic_garmin_owner',p_owner,'external_id',a.external_id)),1,32)::uuid;
 -- La autoridad es la concesión Garmin vigente y el lease privado, no una
 -- sesión ficticia. Se fija únicamente el sujeto para reutilizar los comandos
 -- de ejecución, y se restaura siempre el contexto original del trabajador.
 previous_claims:=current_setting('request.jwt.claims',true);previous_sub:=current_setting('request.jwt.claim.sub',true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',p_owner,'role','authenticated')::text,true);
 perform set_config('request.jwt.claim.sub',p_owner::text,true);context_changed:=true;
 execution:=public.start_scheduled_workout(d.scheduled_id);
 if jsonb_array_length(mapping)<>(select count(*) from public.workout_execution_sets where execution_id=execution) then raise invalid_parameter_value;end if;
 update public.workout_executions set started_at=(a.observation->>'startedAt')::timestamptz,
  observed_timer_seconds=(a.observation->>'timerSeconds')::numeric,
  observed_elapsed_seconds=(a.observation->>'elapsedSeconds')::numeric,
  observed_distance_meters=(a.observation->>'distanceMeters')::numeric where id=execution and user_id=p_owner;
 if a.observation->>'sport'='strength' then perform device_private.apply_strength_mapping(execution,a.observation,mapping);
 else perform device_private.apply_activity_mapping(execution,a.observation,mapping);end if;
 perform device_private.store_activity_timing(execution,a.observation,mapping);
 perform public.finish_workout_observed_idempotent(operation,execution,null,(a.observation->>'startedAt')::timestamptz,
  offset_minutes,null,round((a.observation->>'averageHeartRate')::numeric)::integer,round((a.observation->>'maxHeartRate')::numeric)::integer,'device');
 insert into device_private.activity_confirmations(id,owner_id,activity_id,external_id,scheduled_id,execution_id,source_revision,input_hash,mapping)
 values(operation,p_owner,a.id,a.external_id,d.scheduled_id,execution,source->>'revision',device_private.history_hash(p_input),mapping);
 perform set_config('request.jwt.claims',coalesce(previous_claims,''),true);perform set_config('request.jwt.claim.sub',coalesce(previous_sub,''),true);context_changed:=false;
 update device_private.activity_return_jobs set completion_state='completed',completion_code=null where id=j.id;
 return jsonb_build_object('completed',true,'execution_id',execution);
exception when others then
 if context_changed then
  perform set_config('request.jwt.claims',coalesce(previous_claims,''),true);perform set_config('request.jwt.claim.sub',coalesce(previous_sub,''),true);
 end if;
 raise;
end $$;
revoke all on function device_private.garmin_automatic_result(text,uuid,jsonb) from public,anon,authenticated,service_role;

create or replace function device_private.garmin_activity_command(p_action text,p_owner uuid,p_session uuid,p_input jsonb)
returns jsonb language plpgsql security definer set search_path='' as $$
declare answer jsonb; saved jsonb;
begin
 if p_action in ('automatic.context','automatic.complete','automatic.review') then
  if p_session is not null then raise insufficient_privilege;end if;
  return device_private.garmin_automatic_result(p_action,p_owner,p_input);
 end if;
 answer:=device_private.garmin_activity_received_v1(p_action,p_owner,p_session,p_input);
 if p_action='save' then
  -- La referencia enlaza exactamente la versión recién recibida. Una repetición
  -- antigua no debe conciliarse con otra observación posterior del mismo FIT.
  select jsonb_build_object('activity_id',a.id,'activity_revision',a.revision) into saved
   from device_private.activity_return_jobs j join device_private.activity_observations a
    on a.owner_id=j.owner_id and a.channel='garmin' and a.external_id=j.metadata->>'activityId'
   where j.id=(p_input->>'id')::uuid and a.observation=p_input->'activity';
  answer:=answer||coalesce(saved,'{}'::jsonb);
 end if;
 return answer;
end $$;
revoke all on function device_private.garmin_activity_command(text,uuid,uuid,jsonb) from public,anon,authenticated,service_role;
grant execute on function device_private.garmin_activity_command(text,uuid,uuid,jsonb) to service_role;

commit;
