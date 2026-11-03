begin;

create function device_private.apple_can_map_details(p_observation jsonb,p_snapshot jsonb) returns boolean
language plpgsql immutable set search_path='' as $$
declare mapping jsonb:=device_private.apple_automatic_mapping(p_observation,p_snapshot);begin
 if mapping is null then return false;end if;
 return not exists(
  select 1 from jsonb_array_elements(mapping) m,
   jsonb_array_elements(p_snapshot->'blocks') b,jsonb_array_elements(b->'items') i,jsonb_array_elements(i->'sets') w
  where m->>'block_order'=b->>'order_index' and m->>'item_order'=i->>'order_index' and m->>'set_order'=w->>'order_index'
   and w->>'target_distance_meters' is not null and exists(
    select 1 from jsonb_array_elements(m->'lap_indices') ix
    where p_observation->'intervals'->(ix::text::integer)->>'distance_meters' is null));
end $$;
revoke all on function device_private.apple_can_map_details(jsonb,jsonb) from public,anon,authenticated,service_role;

-- La referencia exacta de WorkoutKit acredita la sesión, aunque Salud no
-- entregue una correspondencia segura para cada serie. NULL no significa cero.
create function device_private.complete_apple_partial_result(p_owner uuid,p_result uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare r device_private.apple_activity_results;src jsonb;execution uuid;operation uuid;effort integer;begin
 perform device_private.apple_result_identity(p_owner);
 perform pg_advisory_xact_lock(hashtextextended('trainer-client:'||p_owner::text,0));
 select * into r from device_private.apple_activity_results where id=p_result and owner_id=p_owner for update;
 if not found then raise insufficient_privilege;end if;
 if r.is_test or r.needs_review or jsonb_array_length(device_private.apple_measured_laps(r.observation,r.source_snapshot))<2
 then return jsonb_build_object('state','review','code','intervals_require_review');end if;
 if not device_private.training_device_access(p_owner) then raise insufficient_privilege;end if;
 src:=device_private.activity_source(p_owner,p_owner,r.scheduled_id);
 if src->'snapshot' is distinct from r.source_snapshot or not device_private.activity_in_completion_window(
  (r.observation->>'started_at')::timestamptz,(r.observation->>'offset_minutes')::integer,(r.source_snapshot->>'date')::date)
 then return jsonb_build_object('state','review','code','source_not_available');end if;
 if (r.observation->>'effort_score')::numeric between 1 and 10 and
  trunc((r.observation->>'effort_score')::numeric)=(r.observation->>'effort_score')::numeric
 then effort:=((r.observation->>'effort_score')::numeric)::integer;end if;
 operation:=substr(device_private.history_hash(jsonb_build_object('automatic_apple_partial',r.id)),1,32)::uuid;
 execution:=public.start_scheduled_workout(r.scheduled_id);
 update public.workout_executions set started_at=(r.observation->>'started_at')::timestamptz,
  observed_timer_seconds=(r.observation->>'timer_seconds')::numeric,
  observed_elapsed_seconds=extract(epoch from (r.observation->>'ended_at')::timestamptz-(r.observation->>'started_at')::timestamptz),
  observed_distance_meters=(r.observation->>'distance_meters')::numeric where id=execution and user_id=p_owner;
 -- El recibo privado habilita exclusivamente este cierre con desglose pendiente.
 -- No se completan ni se omiten artificialmente las series de la receta.
 insert into device_private.apple_activity_confirmations(operation_id,owner_id,result_id,execution_id,input_hash,source_revision,observation_revision,mapping)
 values(operation,p_owner,r.id,execution,device_private.history_hash(jsonb_build_object('partial_result',r.id)),
  src->>'revision',device_private.history_hash(r.observation),null);
 perform public.finish_workout_observed_idempotent(operation,execution,effort,(r.observation->>'started_at')::timestamptz,
  (r.observation->>'offset_minutes')::integer,null,round((r.observation->>'average_heart_rate')::numeric)::integer,
  round((r.observation->>'max_heart_rate')::numeric)::integer,'device');
 return jsonb_build_object('state','completed','execution_id',execution,'details_incomplete',true);
end $$;
revoke all on function device_private.complete_apple_partial_result(uuid,uuid) from public,anon,authenticated,service_role;

do $migration$ declare definition text;anchor text;begin
 definition:=pg_get_functiondef('public.finish_workout_execution(uuid,integer,text,integer,integer,text)'::regprocedure);
 anchor:=$anchor$  ) then
    raise exception 'Workout execution still has pending sets';$anchor$;
 if strpos(definition,anchor)=0 then raise exception 'Revisar cierre de series pendientes';end if;
 execute replace(definition,anchor,$body$  ) and not (p_result_source='device' and exists(
    select 1 from device_private.apple_activity_confirmations c
    join device_private.apple_activity_results r on r.id=c.result_id and r.owner_id=c.owner_id
    where c.execution_id=p_execution_id and c.owner_id=auth.uid() and c.mapping is null
      and not r.is_test and not r.needs_review
      and c.observation_revision=device_private.history_hash(r.observation)
  )) then
    raise exception 'Workout execution still has pending sets';$body$);
 definition:=pg_get_functiondef('device_private.complete_apple_result_automatically(uuid,uuid)'::regprocedure);
 anchor:=$anchor$if mapping is null then return jsonb_build_object('state','review','code','intervals_require_review');end if;$anchor$;
 if strpos(definition,anchor)=0 then raise exception 'Revisar mapa automático Apple';end if;
 execute replace(definition,anchor,$body$if not device_private.apple_can_map_details(r.observation,r.source_snapshot)
  then return device_private.complete_apple_partial_result(p_owner,r.id);end if;$body$);
end $migration$;

-- Lista positiva de medidas deportivas; no se publican UUID nativos,
-- referencias privadas, localización, metadatos ni credenciales.
create function device_private.apple_recorded_intervals(p_observation jsonb) returns jsonb
language sql immutable set search_path='' as $$
 select coalesce(jsonb_agg(jsonb_strip_nulls(jsonb_build_object('index',ordinality,
  'timer_seconds',value->'timer_seconds','distance_meters',value->'distance_meters',
  'average_heart_rate',value->'average_heart_rate','max_heart_rate',value->'max_heart_rate')) order by ordinality),'[]')
 from jsonb_array_elements(coalesce(p_observation->'intervals','[]')) with ordinality
$$;
revoke all on function device_private.apple_recorded_intervals(jsonb) from public,anon,authenticated,service_role;

do $migration$ declare definition text;anchor text;begin
 definition:=pg_get_functiondef('device_private.apple_result_json(device_private.apple_activity_results)'::regprocedure);
 anchor:=$anchor$'timer_seconds',r.observation->'timer_seconds'$anchor$;
 if strpos(definition,anchor)=0 then raise exception 'Revisar resumen Apple';end if;
 execute replace(definition,anchor,$body$'intervals',device_private.apple_recorded_intervals(r.observation),
  'details_incomplete',not exists(select 1 from device_private.apple_activity_confirmations c where c.result_id=r.id and c.mapping is not null)
    and not device_private.apple_can_map_details(r.observation,r.source_snapshot),
  'timer_seconds',r.observation->'timer_seconds'$body$);
end $migration$;

create function device_private.execution_device_details(p_owner uuid,p_execution uuid) returns jsonb
language sql stable security definer set search_path='' as $$
 select jsonb_build_object('device_details_incomplete',exists(
  select 1 from device_private.apple_activity_confirmations c where c.owner_id=p_owner and c.execution_id=p_execution and c.mapping is null
   and exists(select 1 from public.workout_execution_sets w where w.execution_id=p_execution and w.status='pending')),
  'device_results',coalesce((select device_private.results_for_schedule(p_owner,p_owner,s.id)
   from public.scheduled_workouts s where s.user_id=p_owner and s.execution_id=p_execution limit 1),'[]'::jsonb))
$$;
revoke all on function device_private.execution_device_details(uuid,uuid) from public,anon,authenticated,service_role;
create function device_private.my_execution_device_details(p_owner uuid,p_execution uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
begin
 perform device_private.apple_result_identity(p_owner);
 if not exists(select 1 from public.workout_executions where id=p_execution and user_id=p_owner) then raise insufficient_privilege;end if;
 return device_private.execution_device_details(p_owner,p_execution);
end $$;
create function public.my_execution_device_details(p_owner uuid,p_execution uuid) returns jsonb
language sql stable security invoker set search_path='' as $$
 select device_private.my_execution_device_details(p_owner,p_execution)
$$;
revoke all on function public.my_execution_device_details(uuid,uuid),device_private.my_execution_device_details(uuid,uuid)
 from public,anon,authenticated,service_role;
grant execute on function public.my_execution_device_details(uuid,uuid),device_private.my_execution_device_details(uuid,uuid) to authenticated;

-- Las fachadas conservan todas sus comprobaciones antes de ampliar el detalle.
do $migration$ declare definition text;begin
 definition:=pg_get_functiondef('trainer_private.shared_workout_result(uuid,uuid,uuid)'::regprocedure);
 execute replace(definition,'trainer_private.shared_workout_result(', 'trainer_private.shared_workout_result_before_recordings(');
 definition:=pg_get_functiondef('trainer_private.get_trainer_assignment_result(uuid)'::regprocedure);
 execute replace(definition,'trainer_private.get_trainer_assignment_result(', 'trainer_private.assignment_result_before_recordings(');
end $migration$;
revoke all on function trainer_private.shared_workout_result_before_recordings(uuid,uuid,uuid),
 trainer_private.assignment_result_before_recordings(uuid) from public,anon,authenticated,service_role;
create or replace function trainer_private.shared_workout_result(p_expected_owner uuid,p_client_id uuid,p_scheduled_id uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare answer jsonb;begin
 answer:=trainer_private.shared_workout_result_before_recordings(p_expected_owner,p_client_id,p_scheduled_id);
 if answer is null then return null;end if;
 return answer||device_private.execution_device_details(p_client_id,(answer->>'id')::uuid);
end $$;
create or replace function trainer_private.get_trainer_assignment_result(p_id uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare answer jsonb;owner uuid;begin
 answer:=trainer_private.assignment_result_before_recordings(p_id);
 if answer is null then return null;end if;
 select client_id into strict owner from public.trainer_assignments where scheduled_id=p_id and trainer_id=auth.uid();
 -- La pauta y sus resultados siguen siendo de solo lectura para el autor.
 return answer||device_private.execution_device_details(owner,(answer->>'id')::uuid);
end $$;

commit;
