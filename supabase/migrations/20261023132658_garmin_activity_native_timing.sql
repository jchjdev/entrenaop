begin;
-- El resultado heredado continúa entero; el tiempo nativo evita recalcular un
-- ritmo distinto después del redondeo. Solo RPC internas pueden escribirlo.
alter table public.workout_execution_sets
 add column observed_duration_seconds numeric check(observed_duration_seconds between 0 and 172800),
 add column observed_recovery_duration_seconds numeric check(observed_recovery_duration_seconds between 0 and 172800);

create function device_private.clear_observed_set_timing() returns trigger
language plpgsql set search_path='' as $$
begin
 if new.result_source='manual' or new.actual_duration_seconds is distinct from old.actual_duration_seconds
  or new.actual_recovery_duration_seconds is distinct from old.actual_recovery_duration_seconds then
  new.observed_duration_seconds:=null; new.observed_recovery_duration_seconds:=null;
 end if;
 return new;
end $$;
revoke all on function device_private.clear_observed_set_timing() from public,anon,authenticated,service_role;
create trigger clear_observed_set_timing before update of result_source,actual_duration_seconds,actual_recovery_duration_seconds
 on public.workout_execution_sets for each row execute function device_private.clear_observed_set_timing();

create function device_private.store_activity_timing(p_execution uuid,p_activity jsonb,p_mapping jsonb) returns void
language plpgsql security definer set search_path='' as $$
declare m jsonb; work_seconds numeric; rest_seconds numeric; meters numeric;
begin
 for m in select value from jsonb_array_elements(p_mapping) loop
  if coalesce((m->>'skipped')::boolean,false) then continue; end if;
  if p_activity->>'sport'='strength' then
   work_seconds:=(p_activity->'sets'->(m->'lap_indices'->>0)::integer->>'seconds')::numeric;
   rest_seconds:=null; meters:=null;
  else
   select sum((p_activity->'laps'->(x.value::text::integer)->>'timerSeconds')::numeric),
    sum((p_activity->'laps'->(x.value::text::integer)->>'distanceMeters')::numeric)
    into work_seconds,meters from jsonb_array_elements(coalesce(m->'lap_indices',jsonb_build_array(m->'lap_index'))) x;
   select sum((p_activity->'laps'->(x.value::text::integer)->>'timerSeconds')::numeric) into rest_seconds
    from jsonb_array_elements(coalesce(m->'recovery_lap_indices',case when m->>'recovery_lap_index' is null then '[]'::jsonb else jsonb_build_array(m->'recovery_lap_index') end)) x;
  end if;
  -- También protege el enriquecimiento del historial: no tocar marcas corregidas.
  update public.workout_execution_sets set observed_duration_seconds=work_seconds,observed_recovery_duration_seconds=rest_seconds
   where execution_id=p_execution and block_order=(m->>'block_order')::integer and item_order=(m->>'item_order')::integer
   and set_order=(m->>'set_order')::integer and result_source='device' and status='completed'
   and actual_duration_seconds=round(work_seconds)::integer
   and actual_recovery_duration_seconds is not distinct from round(rest_seconds)::integer
   and actual_distance_meters is not distinct from meters;
 end loop;
end $$;
revoke all on function device_private.store_activity_timing(uuid,jsonb,jsonb) from public,anon,authenticated,service_role;

do $$ declare definition text; anchor text:='  perform public.finish_workout_observed_idempotent'; begin
 definition:=pg_get_functiondef('device_private.garmin_activity_command(text,uuid,uuid,jsonb)'::regprocedure);
 if (length(definition)-length(replace(definition,anchor,'')))/length(anchor)<>1 then raise exception 'Revisar contrato de cierre Garmin'; end if;
 execute replace(definition,anchor,'  perform device_private.store_activity_timing(e,a.observation,v_mapping);'||chr(10)||anchor);
end $$;

do $$ declare item record; begin
 for item in select c.execution_id,c.mapping,a.observation from device_private.activity_confirmations c
  join device_private.activity_observations a on a.id=c.activity_id and a.owner_id=c.owner_id loop
  perform device_private.store_activity_timing(item.execution_id,item.observation,item.mapping);
 end loop;
end $$;
commit;
