begin;

-- Un mapa confirmado prevalece sobre la interpretación por orden. Esta
-- sobrecarga solo proyecta su semántica; no altera ni reconstruye recibos.
create function device_private.apple_recorded_phases(p_observation jsonb,p_snapshot jsonb,p_mapping jsonb) returns jsonb
language plpgsql immutable set search_path='' as $$
declare recorded jsonb:=device_private.apple_recorded_intervals(p_observation);result jsonb:=recorded;
 entry jsonb;w jsonb;b jsonb;kind text;indices jsonb;idx integer;seen integer[]:='{}';recovery boolean;label jsonb;
begin
 if p_mapping is null or p_mapping='null' then return device_private.apple_recorded_phases(p_observation,p_snapshot);end if;
 for entry in select value from jsonb_array_elements(p_mapping) loop
  if coalesce((entry->>'skipped')::boolean,false) then continue;end if;
  select block.value,work.value into b,w from jsonb_array_elements(p_snapshot->'blocks') block,
   jsonb_array_elements(block.value->'items') item,jsonb_array_elements(item.value->'sets') work
   where block.value->>'order_index'=entry->>'block_order' and item.value->>'order_index'=entry->>'item_order'
    and work.value->>'order_index'=entry->>'set_order';
  if w is null then return recorded;end if;
  kind:=coalesce(w->'running_step'->>'kind',case b->>'format' when 'warm_up' then 'warmup' when 'cool_down' then 'cooldown' else 'run' end);
  if kind not in ('warmup','run','recovery','rest','cooldown','walking','jogging') then return recorded;end if;
  foreach recovery in array array[false,true] loop
   indices:=coalesce(entry->case when recovery then 'recovery_lap_indices' else 'lap_indices' end,'[]');
   label:=jsonb_build_object('phase_kind',case when recovery then 'recovery' else kind end,'phase_source','prescription',
    'pace_relevant',not recovery and kind<>'rest' and (kind in ('warmup','run','cooldown') or w->>'target_pace_min_seconds_per_km' is not null));
   for idx in select value::text::integer from jsonb_array_elements(indices) loop
    if idx<0 or idx>=jsonb_array_length(recorded) or idx=any(seen) then return recorded;end if;
    seen:=array_append(seen,idx);
    result:=jsonb_set(result,array[idx::text],(result->idx)||label);
   end loop;
  end loop;
 end loop;
 return result;
end $$;
revoke all on function device_private.apple_recorded_phases(jsonb,jsonb,jsonb) from public,anon,authenticated,service_role;

do $migration$ declare definition text;anchor text:='device_private.apple_recorded_phases(r.observation,r.source_snapshot)';begin
 definition:=pg_get_functiondef('device_private.apple_result_json(device_private.apple_activity_results)'::regprocedure);
 if strpos(definition,anchor)=0 then raise exception 'Revisar proyección confirmada Apple';end if;
 execute replace(definition,anchor,$body$device_private.apple_recorded_phases(r.observation,r.source_snapshot,
  (select c.mapping from device_private.apple_activity_confirmations c where c.result_id=r.id))$body$);
end $migration$;

commit;
