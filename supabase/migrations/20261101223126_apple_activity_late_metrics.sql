begin;

-- Se conserva la correspondencia revisada, no una propuesta reconstruida.
-- Los recibos anteriores quedan sin mapping y no se infieren retrospectivamente.
alter table device_private.apple_activity_confirmations add column mapping jsonb
 check(mapping is null or (jsonb_typeof(mapping)='array' and jsonb_array_length(mapping)<=100 and octet_length(mapping::text)<=65536));

create function device_private.enrich_apple_execution(p_owner uuid,p_result uuid) returns void
language plpgsql security definer set search_path='' as $$
declare r device_private.apple_activity_results;c device_private.apple_activity_confirmations;
 m jsonb;part jsonb;idx integer;meters numeric;recovery_meters numeric;complete boolean;
begin
 perform device_private.apple_result_identity(p_owner);
 select * into r from device_private.apple_activity_results where id=p_result and owner_id=p_owner for update;
 if not found or r.is_test or r.needs_review then return;end if;
 select * into c from device_private.apple_activity_confirmations where result_id=r.id and owner_id=p_owner;
 if not found or c.source_revision is distinct from device_private.history_hash(r.source_snapshot) then return;end if;
 perform 1 from public.workout_executions where id=c.execution_id and user_id=p_owner
  and status='completed' and result_source='device' for update;
 if not found then return;end if;
 update public.workout_executions e set
  observed_distance_meters=coalesce(e.observed_distance_meters,(r.observation->>'distance_meters')::numeric),
  average_heart_rate_bpm=coalesce(e.average_heart_rate_bpm,round((r.observation->>'average_heart_rate')::numeric)::integer),
  max_heart_rate_bpm=coalesce(e.max_heart_rate_bpm,round((r.observation->>'max_heart_rate')::numeric)::integer)
 where e.id=c.execution_id and e.user_id=p_owner and e.status='completed' and e.result_source='device' and (
  e.observed_distance_meters is null and r.observation->>'distance_meters' is not null or
  e.average_heart_rate_bpm is null and r.observation->>'average_heart_rate' is not null or
  e.max_heart_rate_bpm is null and r.observation->>'max_heart_rate' is not null);
 if c.mapping is null then return;end if;
 for m in select value from jsonb_array_elements(c.mapping) loop
  if coalesce((m->>'skipped')::boolean,false) then continue;end if;
  meters:=0;complete:=jsonb_array_length(m->'lap_indices')>0;
  for idx in select value::text::integer from jsonb_array_elements(m->'lap_indices') loop
   part:=r.observation->'intervals'->idx;
   if part->>'distance_meters' is null then complete:=false;else meters:=meters+(part->>'distance_meters')::numeric;end if;
  end loop;
  if not complete then meters:=null;end if;
  recovery_meters:=0;complete:=jsonb_array_length(m->'recovery_lap_indices')>0;
  for idx in select value::text::integer from jsonb_array_elements(m->'recovery_lap_indices') loop
   part:=r.observation->'intervals'->idx;
   if part->>'distance_meters' is null then complete:=false;else recovery_meters:=recovery_meters+(part->>'distance_meters')::numeric;end if;
  end loop;
  if not complete then recovery_meters:=null;end if;
  update public.workout_execution_sets w set actual_distance_meters=coalesce(w.actual_distance_meters,meters),
   actual_recovery_distance_meters=coalesce(w.actual_recovery_distance_meters,recovery_meters)
   where w.execution_id=c.execution_id and w.block_order=(m->>'block_order')::integer
    and w.item_order=(m->>'item_order')::integer and w.set_order=(m->>'set_order')::integer
    and w.status='completed' and w.result_source='device' and (
     w.actual_distance_meters is null and meters is not null or
     w.actual_recovery_distance_meters is null and recovery_meters is not null);
 end loop;
end $$;
revoke all on function device_private.enrich_apple_execution(uuid,uuid) from public,anon,authenticated,service_role;

do $$declare definition text;anchor text;begin
 definition:=pg_get_functiondef('device_private.apple_results_observed_v1(uuid,text,jsonb)'::regprocedure);
 anchor:='input_hash,source_revision,observation_revision)';
 if strpos(definition,anchor)=0 then raise exception 'Revisar recibo Apple';end if;
 definition:=replace(definition,anchor,'input_hash,source_revision,observation_revision,mapping)');
 anchor:='values(operation,p_owner,r.id,execution,hash,src->>''revision'',rev);';
 if strpos(definition,anchor)=0 then raise exception 'Revisar correspondencia Apple';end if;
 execute replace(definition,anchor,$body$values(operation,p_owner,r.id,execution,hash,src->>'revision',rev,
  (select jsonb_agg(jsonb_build_object('block_order',(confirmed_step->>'block_order')::integer,'item_order',(confirmed_step->>'item_order')::integer,
   'set_order',(confirmed_step->>'set_order')::integer,'lap_indices',coalesce(confirmed_step->'lap_indices','[]'::jsonb),
   'recovery_lap_indices',coalesce(confirmed_step->'recovery_lap_indices','[]'::jsonb),'skipped',coalesce((confirmed_step->>'skipped')::boolean,false)))
   from jsonb_array_elements(mapping) confirmed_step));$body$);
 definition:=pg_get_functiondef('device_private.complete_apple_result_automatically(uuid,uuid)'::regprocedure);
 anchor:='if found then';
 if strpos(definition,anchor)=0 then raise exception 'Revisar enriquecimiento Apple';end if;
 execute replace(definition,anchor,$body$if found then
  begin
   perform device_private.enrich_apple_execution(p_owner,r.id);
  exception when others then
   -- Una corrección concurrente no revierte la observación recién recibida.
   -- Releer Salud permite reintentar sin duplicar ni reabrir el entrenamiento.
   null;
  end;
$body$);
end $$;

commit;
