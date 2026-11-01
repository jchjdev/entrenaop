begin;

-- El día real se conserva separado del día de sincronización. No adelantamos
-- otras citas ni cerramos una pauta realizada más de siete días después.
create function device_private.activity_in_completion_window(p_started timestamptz,p_offset integer,p_date date)
returns boolean language sql immutable set search_path='' as $$
 select coalesce(p_started is not null and p_offset between -840 and 840 and p_date is not null
  and ((p_started at time zone 'UTC')+make_interval(mins=>p_offset))::date-p_date between 0 and 7,false)
$$;
revoke all on function device_private.activity_in_completion_window(timestamptz,integer,date) from public,anon,authenticated,service_role;

-- final_rpe ya admite NULL. Los cierres de dispositivo conservan ese valor
-- ausente; no se sustituye por cero ni por una estimación del ritmo/pulso.
do $$declare definition text; signature text;begin
 foreach signature in array array[
  'device_private.garmin_activity_command(text,uuid,uuid,jsonb)',
  'device_private.apple_results_command(uuid,text,jsonb)'] loop
  definition:=pg_get_functiondef(signature::regprocedure);
  if position('v_rpe is null or v_rpe not between 1 and 10' in definition)=0 then
   raise exception 'No se encuentra la validación RPE esperada en %',signature;end if;
  execute replace(definition,'v_rpe is null or v_rpe not between 1 and 10','v_rpe is not null and v_rpe not between 1 and 10');
 end loop;
end $$;

create function device_private.add_device_workout_effort(p_expected_owner uuid,p_execution_id uuid,p_rpe integer)
returns void language plpgsql security definer set search_path='' as $$
declare actor uuid:=auth.uid(); current_rpe integer;begin
 if actor is null or actor is distinct from p_expected_owner or coalesce((auth.jwt()->>'is_anonymous')::boolean,false)
  or not exists(select 1 from auth.sessions where id=(auth.jwt()->>'session_id')::uuid and user_id=actor
    and (not_after is null or not_after>statement_timestamp())) then raise insufficient_privilege;end if;
 if p_rpe is null or p_rpe not between 1 and 10 then raise invalid_parameter_value;end if;
 select final_rpe into current_rpe from public.workout_executions
  where id=p_execution_id and user_id=actor and status='completed' and result_source='device' for update;
 if not found then raise insufficient_privilege;end if;
 if current_rpe is not null then
  if current_rpe=p_rpe then return;end if;
  raise exception 'effort_already_recorded' using errcode='22023';
 end if;
 update public.workout_executions set final_rpe=p_rpe where id=p_execution_id and user_id=actor;
end $$;
create function public.add_device_workout_effort(p_expected_owner uuid,p_execution_id uuid,p_rpe integer)
returns void language sql security invoker set search_path='' as $$
 select device_private.add_device_workout_effort(p_expected_owner,p_execution_id,p_rpe)
$$;
revoke all on function device_private.add_device_workout_effort(uuid,uuid,integer),public.add_device_workout_effort(uuid,uuid,integer)
 from public,anon,authenticated,service_role;
grant execute on function device_private.add_device_workout_effort(uuid,uuid,integer),public.add_device_workout_effort(uuid,uuid,integer) to authenticated;

-- La referencia WorkoutKit ya identifica la receta. Solo se propone una
-- correspondencia automática cuando Salud devuelve todas sus fases, en orden.
create function device_private.apple_automatic_mapping(p_observation jsonb,p_snapshot jsonb)
returns jsonb language plpgsql immutable set search_path='' as $$
declare block_json jsonb;item_json jsonb;set_json jsonb;result jsonb:='[]';v_position integer:=0;part jsonb;needed integer;entry jsonb;
begin
 select count(*)+count(*) filter(where w->>'recovery_type' is not null) into needed
  from jsonb_array_elements(p_snapshot->'blocks') b,jsonb_array_elements(b->'items') i,jsonb_array_elements(i->'sets') w;
 if needed<1 or needed>100 or jsonb_array_length(coalesce(p_observation->'intervals','[]'))<>needed then return null;end if;
 for block_json in select value from jsonb_array_elements(p_snapshot->'blocks') loop
  for item_json in select value from jsonb_array_elements(block_json->'items') loop
   for set_json in select value from jsonb_array_elements(item_json->'sets') loop
    part:=p_observation->'intervals'->v_position;
    if part is null then return null;end if;
    entry:=jsonb_build_object('block_order',block_json->'order_index','item_order',item_json->'order_index','set_order',set_json->'order_index',
      'lap_indices',jsonb_build_array(v_position),'skipped',false,'recovery_lap_indices','[]'::jsonb);
    v_position:=v_position+1;
    if set_json->>'recovery_type' is not null then
     entry:=entry||jsonb_build_object('recovery_lap_indices',jsonb_build_array(v_position));v_position:=v_position+1;
    end if;
    result:=result||jsonb_build_array(entry);
   end loop;
  end loop;
 end loop;
 return result;
end $$;
revoke all on function device_private.apple_automatic_mapping(jsonb,jsonb) from public,anon,authenticated,service_role;

-- Conserva los contratos manuales, revisión de fuente y enriquecimiento ya
-- publicados. La fachada añade la conciliación solo tras una ingesta válida.
do $$declare definition text;begin
 definition:=pg_get_functiondef('device_private.apple_results_command(uuid,text,jsonb)'::regprocedure);
 execute replace(definition,'device_private.apple_results_command(', 'device_private.apple_results_observed_v1(');
end $$;
revoke all on function device_private.apple_results_observed_v1(uuid,text,jsonb) from public,anon,authenticated,service_role;

create function device_private.complete_apple_result_automatically(p_owner uuid,p_result uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare r device_private.apple_activity_results; receipt device_private.apple_activity_confirmations;
 preview jsonb; mapping jsonb; offset_minutes integer; effort integer; operation uuid; answer jsonb;code text;
begin
 perform device_private.apple_result_identity(p_owner);
 perform pg_advisory_xact_lock(hashtextextended('trainer-client:'||p_owner::text,0));
 select * into r from device_private.apple_activity_results where id=p_result and owner_id=p_owner for update;
 if not found then raise insufficient_privilege;end if;
 -- Un esfuerzo posterior enriquece únicamente un NULL, nunca pisa la valoración
 -- introducida por la persona ni cambia el recibo/hora de finalización.
 if (r.observation->>'effort_score')::numeric between 1 and 10 and
  trunc((r.observation->>'effort_score')::numeric)=(r.observation->>'effort_score')::numeric then
  effort:=((r.observation->>'effort_score')::numeric)::integer;end if;
 select * into receipt from device_private.apple_activity_confirmations where owner_id=p_owner and result_id=r.id;
 if found then
  if effort is not null and not r.is_test and not r.needs_review then update public.workout_executions set final_rpe=effort
    where id=receipt.execution_id and user_id=p_owner and status='completed' and result_source='device' and final_rpe is null;end if;
  return jsonb_build_object('state','completed','execution_id',receipt.execution_id);
 end if;
 if r.is_test or r.needs_review then return jsonb_build_object('state','review','code',case when r.is_test then 'test_activity' else 'activity_conflict' end);end if;
 begin
  preview:=device_private.apple_results_observed_v1(p_owner,'preview',jsonb_build_object('activity_id',r.id,'scheduled_id',r.scheduled_id));
  if preview->>'blocked_reason' is not null then return jsonb_build_object('state','review','code',preview->>'blocked_reason');end if;
  offset_minutes:=(r.observation->>'offset_minutes')::integer;
  if not device_private.activity_in_completion_window((r.observation->>'started_at')::timestamptz,offset_minutes,(r.source_snapshot->>'date')::date)
   then return jsonb_build_object('state','review','code','completion_window_required');end if;
  mapping:=device_private.apple_automatic_mapping(r.observation,r.source_snapshot);
  if mapping is null then return jsonb_build_object('state','review','code','intervals_require_review');end if;
  operation:=substr(device_private.history_hash(jsonb_build_object('automatic_apple_result',r.id)),1,32)::uuid;
  answer:=device_private.apple_results_observed_v1(p_owner,'confirm',jsonb_build_object(
    'operation_id',operation,'activity_id',r.id,'scheduled_id',r.scheduled_id,'rpe',effort,'utc_offset_minutes',offset_minutes,
    'mapping',mapping,'source_revision',preview->>'source_revision','activity_revision',preview->>'activity_revision'));
  return answer||jsonb_build_object('state','completed');
 exception when others then
  -- La subtransacción revierte un inicio parcial; la observación recibida
  -- permanece guardada. Un error de cierre no se convierte en fallo de ingesta.
  code:=case when sqlerrm in ('invalid_mapping','source_not_available','stale_review','activity_already_confirmed','access_required') then sqlerrm else 'review_required' end;
  return jsonb_build_object('state','review','code',code);
 end;
end $$;
revoke all on function device_private.complete_apple_result_automatically(uuid,uuid) from public,anon,authenticated,service_role;

create or replace function device_private.apple_results_command(p_owner uuid,p_action text,p_input jsonb default '{}')
returns jsonb language plpgsql security definer set search_path='' as $$
declare answer jsonb;x jsonb;id uuid;automatic jsonb:='[]';begin
 answer:=device_private.apple_results_observed_v1(p_owner,p_action,p_input);
 if p_action='ingest' then
  for x in select value from jsonb_array_elements(p_input->'observations') loop
   select r.id into id from device_private.apple_activity_results r where r.owner_id=p_owner and r.workout_id=(x->>'workout_id')::uuid;
   automatic:=automatic||jsonb_build_array(device_private.complete_apple_result_automatically(p_owner,id));
  end loop;
  return answer||jsonb_build_object('automatic',automatic);
 end if;
 return answer;
end $$;
revoke all on function device_private.apple_results_command(uuid,text,jsonb) from public,anon,authenticated,service_role;
grant execute on function device_private.apple_results_command(uuid,text,jsonb) to authenticated;

commit;
