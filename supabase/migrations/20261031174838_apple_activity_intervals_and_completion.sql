begin;
create table device_private.apple_activity_confirmations (
 operation_id uuid primary key, owner_id uuid not null references auth.users(id) on delete cascade,
 result_id uuid not null unique references device_private.apple_activity_results(id) on delete cascade,
 execution_id uuid not null unique references public.workout_executions(id),
 input_hash text not null, source_revision text not null, observation_revision text not null,
 confirmed_at timestamptz not null default now()
);
create index apple_confirmation_owner on device_private.apple_activity_confirmations(owner_id);
alter table device_private.apple_activity_confirmations enable row level security;
revoke all on device_private.apple_activity_confirmations from public,anon,authenticated,service_role;

create function device_private.apple_interval_extension(x jsonb,parent jsonb) returns jsonb
language plpgsql immutable set search_path='' as $$
declare part jsonb; v jsonb; result jsonb:='{}'; items jsonb:='[]'; ids uuid[]:='{}'; id uuid;
 started timestamptz; ended timestamptz; previous_end timestamptz; timer numeric; total numeric:=0; n numeric; key text;
begin
 if x?'effort_score' then
  if jsonb_typeof(x->'effort_score')<>'number' or not((x->>'effort_score')::numeric between 0 and 10) then raise invalid_parameter_value;end if;
  result:=result||jsonb_build_object('effort_score',x->'effort_score');end if;
 if x?'offset_minutes' then
  if jsonb_typeof(x->'offset_minutes')<>'number' or x->>'offset_minutes' !~ '^-?[0-9]+$'
   or not((x->>'offset_minutes')::integer between -840 and 840) then raise invalid_parameter_value;end if;
  result:=result||jsonb_build_object('offset_minutes',x->'offset_minutes');end if;
 if x?'intervals' then
  if jsonb_typeof(x->'intervals')<>'array' or jsonb_array_length(x->'intervals')>100 then raise invalid_parameter_value;end if;
  previous_end:=(parent->>'started_at')::timestamptz;
  for part in select value from jsonb_array_elements(x->'intervals') loop
   if jsonb_typeof(part)<>'object' or exists(select 1 from jsonb_object_keys(part) k where k not in
    ('id','started_at','ended_at','timer_seconds','distance_meters','average_heart_rate','max_heart_rate')) then raise invalid_parameter_value;end if;
   id:=(part->>'id')::uuid;started:=(part->>'started_at')::timestamptz;ended:=(part->>'ended_at')::timestamptz;timer:=(part->>'timer_seconds')::numeric;
   if id is null or id=any(ids) or started is null or ended is null or not isfinite(started) or not isfinite(ended)
    or started<previous_end or ended<started or ended>(parent->>'ended_at')::timestamptz+interval '1 second'
    or timer is null or jsonb_typeof(part->'timer_seconds')<>'number' or not(timer>0 and timer<=172800)
    or timer>extract(epoch from ended-started)+1 then raise invalid_parameter_value;end if;
   foreach key in array array['distance_meters','average_heart_rate','max_heart_rate'] loop
    if coalesce(part->key,'null'::jsonb)='null'::jsonb then continue;end if;
    n:=(part->>key)::numeric;
    if jsonb_typeof(part->key)<>'number' or not(n>=0 and n<100000000)
     or (key<>'distance_meters' and not(n>0 and n<=400)) then raise invalid_parameter_value;end if;
   end loop;
   if (part->>'max_heart_rate')::numeric<(part->>'average_heart_rate')::numeric then raise invalid_parameter_value;end if;
   v:=jsonb_strip_nulls(part||jsonb_build_object('id',id,'started_at',to_char(started at time zone 'UTC','YYYY-MM-DD"T"HH24:MI:SS.US"Z"'),
    'ended_at',to_char(ended at time zone 'UTC','YYYY-MM-DD"T"HH24:MI:SS.US"Z"')));
   items:=items||jsonb_build_array(v);ids:=array_append(ids,id);previous_end:=ended;total:=total+timer;
  end loop;
  if total>(parent->>'timer_seconds')::numeric+1 then raise invalid_parameter_value;end if;
  if (parent->>'distance_meters')::numeric is not null and
   (select sum((value->>'distance_meters')::numeric) from jsonb_array_elements(items))>(parent->>'distance_meters')::numeric+2 then raise invalid_parameter_value;end if;
  result:=result||jsonb_build_object('intervals',items);
 end if;
 if x?'markers' then
  if jsonb_typeof(x->'markers')<>'array' or jsonb_array_length(x->'markers')>200 then raise invalid_parameter_value;end if;
  for part in select value from jsonb_array_elements(x->'markers') loop
   if jsonb_typeof(part)<>'object' or exists(select 1 from jsonb_object_keys(part) k where k not in ('kind','started_at','ended_at'))
    or part->>'kind' is null or part->>'kind' not in ('lap','segment') then raise invalid_parameter_value;end if;
   started:=(part->>'started_at')::timestamptz;ended:=(part->>'ended_at')::timestamptz;
   if started is null or ended is null or not isfinite(started) or not isfinite(ended) or ended<started
    or started<(parent->>'started_at')::timestamptz or ended>(parent->>'ended_at')::timestamptz+interval '1 second' then raise invalid_parameter_value;end if;
  end loop;
  result:=result||jsonb_build_object('markers',x->'markers');
 end if;
 return result;
end $$;
revoke all on function device_private.apple_interval_extension(jsonb,jsonb) from public,anon,authenticated,service_role;

-- La actividad por defecto que cubre todo el entrenamiento no se convierte
-- en una fase de una receta con varios pasos.
create function device_private.apple_measured_laps(observation jsonb,snapshot jsonb) returns jsonb
language plpgsql immutable set search_path='' as $$
declare count_steps integer; parts jsonb:=coalesce(observation->'intervals','[]');begin
 select count(*)+count(*) filter(where w->>'recovery_type' is not null) into count_steps
  from jsonb_array_elements(snapshot->'blocks') b,jsonb_array_elements(b->'items') i,jsonb_array_elements(i->'sets') w;
 if jsonb_array_length(parts)=1 and count_steps>1 and parts->0->>'started_at'=observation->>'started_at'
  and parts->0->>'ended_at'=observation->>'ended_at' then return '[]';end if;
 return coalesce((select jsonb_agg(jsonb_strip_nulls(jsonb_build_object('index',ordinality-1,
  'startedAt',value->>'started_at','timerSeconds',value->'timer_seconds','distanceMeters',value->'distance_meters',
  'averageHeartRate',value->'average_heart_rate','maxHeartRate',value->'max_heart_rate')) order by ordinality)
  from jsonb_array_elements(parts) with ordinality),'[]');
end $$;
revoke all on function device_private.apple_measured_laps(jsonb,jsonb) from public,anon,authenticated,service_role;

do $$declare definition text;begin
 definition:=pg_get_functiondef('device_private.apple_results_command(uuid,text,jsonb)'::regprocedure);
 execute replace(definition,'device_private.apple_results_command(', 'device_private.apple_results_summary_v1(');
end $$;
revoke all on function device_private.apple_results_summary_v1(uuid,text,jsonb) from public,anon,authenticated,service_role;

create or replace function device_private.apple_results_command(p_owner uuid,p_action text,p_input jsonb default '{}') returns jsonb
language plpgsql security definer set search_path='' as $$
declare x jsonb; core jsonb:='[]'; extension jsonb; candidate jsonb; answer jsonb;
 r device_private.apple_activity_results; receipt device_private.apple_activity_confirmations;
 src jsonb; activity jsonb; mapping jsonb; m jsonb; lap jsonb; idx integer;
 execution uuid; operation uuid; v_rpe integer; offset_minutes integer; hash text; rev text; bounds jsonb; timer numeric; distance numeric;
begin
 perform device_private.apple_result_identity(p_owner);
 if p_input is null or jsonb_typeof(p_input)<>'object' or octet_length(p_input::text)>524288 then raise invalid_parameter_value;end if;
 if p_action='ingest' then
  if jsonb_typeof(p_input->'observations') is distinct from 'array' or jsonb_array_length(p_input->'observations')>20 then raise invalid_parameter_value;end if;
  for x in select value from jsonb_array_elements(p_input->'observations') loop
   core:=core||jsonb_build_array(x-'intervals'-'markers'-'effort_score'-'offset_minutes');
  end loop;
  answer:=device_private.apple_results_summary_v1(p_owner,p_action,jsonb_build_object('observations',core));
  for x in select value from jsonb_array_elements(p_input->'observations') loop
   select * into r from device_private.apple_activity_results where owner_id=p_owner and workout_id=(x->>'workout_id')::uuid for update;
   extension:=device_private.apple_interval_extension(x,r.observation);
   candidate:=r.observation||extension;
   if exists(select 1 from jsonb_each(extension) e where r.observation ? e.key and r.observation->e.key<>e.value) then
    update device_private.apple_activity_results set needs_review=true where id=r.id;
   else update device_private.apple_activity_results set observation=candidate where id=r.id;end if;
   if (select count(*) from device_private.apple_activity_revisions where result_id=r.id)<32 then
    insert into device_private.apple_activity_revisions(result_id,revision,observation)
     values(r.id,device_private.history_hash(candidate),candidate) on conflict do nothing;end if;
  end loop;
  return answer;
 end if;
 if p_action not in ('preview','confirm') then
  if p_action='classify' and exists(select 1 from device_private.apple_activity_confirmations where result_id=(p_input->>'id')::uuid and owner_id=p_owner) then
   raise exception 'activity_already_confirmed' using errcode='22023';end if;
  return device_private.apple_results_summary_v1(p_owner,p_action,p_input);
 end if;
 perform pg_advisory_xact_lock(hashtextextended('trainer-client:'||p_owner::text,0));
 hash:=device_private.history_hash(p_input);
 if p_action='confirm' then
  operation:=(p_input->>'operation_id')::uuid;if operation is null then raise invalid_parameter_value;end if;
  select * into receipt from device_private.apple_activity_confirmations where operation_id=operation;
  if found then
   if receipt.owner_id<>p_owner or receipt.input_hash<>hash then raise exception 'operation_reused' using errcode='22023';end if;
   return jsonb_build_object('execution_id',receipt.execution_id,'replayed',true);end if;
 end if;
 select * into r from device_private.apple_activity_results where owner_id=p_owner and id=(p_input->>'activity_id')::uuid for update;
 if not found then raise insufficient_privilege;end if;
 if (p_input->>'scheduled_id')::uuid is distinct from r.scheduled_id then raise insufficient_privilege;end if;
 if exists(select 1 from device_private.apple_activity_confirmations where result_id=r.id) then raise exception 'activity_already_confirmed' using errcode='22023';end if;
 src:=device_private.activity_source(p_owner,p_owner,r.scheduled_id);
 rev:=device_private.history_hash(r.observation);
 activity:=jsonb_strip_nulls(jsonb_build_object('name',r.source_snapshot->>'name','sport','running',
  'startedAt',r.observation->>'started_at','timerSeconds',r.observation->'timer_seconds',
  'elapsedSeconds',extract(epoch from (r.observation->>'ended_at')::timestamptz-(r.observation->>'started_at')::timestamptz),
  'distanceMeters',r.observation->'distance_meters','averageHeartRate',r.observation->'average_heart_rate','maxHeartRate',r.observation->'max_heart_rate',
  'offsetSeconds',(r.observation->>'offset_minutes')::integer*60,'laps',device_private.apple_measured_laps(r.observation,r.source_snapshot)));
 if p_action='preview' then
  return jsonb_build_object('activity_id',r.id,'scheduled_id',r.scheduled_id,'activity_revision',rev,
   'source_revision',src->>'revision','snapshot',r.source_snapshot,'activity',activity,'is_test',r.is_test,
   'recorded_rpe',case when (r.observation->>'effort_score')::numeric between 1 and 10
     and trunc((r.observation->>'effort_score')::numeric)=(r.observation->>'effort_score')::numeric then ((r.observation->>'effort_score')::numeric)::integer end,
   'blocked_reason',case when r.needs_review then 'activity_conflict' when src->'snapshot'<>r.source_snapshot then 'stale_prescription' end);
 end if;
 if r.is_test then raise exception 'test_activity' using errcode='22023';end if;
 if not device_private.training_device_access(p_owner) then raise exception 'access_required' using errcode='42501';end if;
 if r.needs_review or src->'snapshot'<>r.source_snapshot or src->>'revision' is distinct from p_input->>'source_revision'
  or rev is distinct from p_input->>'activity_revision' then raise exception 'stale_review' using errcode='40001';end if;
 v_rpe:=(p_input->>'rpe')::integer;offset_minutes:=coalesce((r.observation->>'offset_minutes')::integer,(p_input->>'utc_offset_minutes')::integer);
 if v_rpe is null or v_rpe not between 1 and 10 then raise exception 'invalid_rpe' using errcode='22023';end if;
 if offset_minutes is null or offset_minutes not between -840 and 840 then raise exception 'invalid_offset' using errcode='22023';end if;
 mapping:=p_input->'mapping';
 if jsonb_typeof(mapping) is distinct from 'array' or jsonb_array_length(mapping)>100
  or not exists(select 1 from jsonb_array_elements(mapping) a where coalesce((a->>'skipped')::boolean,false)=false and jsonb_array_length(a->'lap_indices')>0)
  then raise exception 'invalid_mapping' using errcode='22023';end if;
 -- Una distancia ausente nunca se sustituye por cero, ni al sumar varias fases.
 for m in select value from jsonb_array_elements(mapping) loop
  if coalesce((m->>'skipped')::boolean,false) then continue;end if;
  for idx in select (value::text)::integer from jsonb_array_elements(coalesce(m->'lap_indices','[]')||coalesce(m->'recovery_lap_indices','[]')) loop
   lap:=activity->'laps'->idx;
   if lap is null then raise exception 'invalid_mapping' using errcode='22023';end if;
  end loop;
 end loop;
 execution:=public.start_scheduled_workout(r.scheduled_id);
 if jsonb_array_length(mapping)<>(select count(*) from public.workout_execution_sets where execution_id=execution) then raise exception 'invalid_mapping' using errcode='22023';end if;
 update public.workout_executions set started_at=(r.observation->>'started_at')::timestamptz,
  observed_timer_seconds=(r.observation->>'timer_seconds')::numeric,observed_distance_meters=(r.observation->>'distance_meters')::numeric,
  observed_elapsed_seconds=(activity->>'elapsedSeconds')::numeric where id=execution;
 perform device_private.apply_activity_mapping(execution,activity,mapping);
 perform device_private.store_activity_timing(execution,activity,mapping);
 perform public.finish_workout_observed_idempotent(operation,execution,v_rpe,(r.observation->>'started_at')::timestamptz,offset_minutes,null,
  round((r.observation->>'average_heart_rate')::numeric)::integer,round((r.observation->>'max_heart_rate')::numeric)::integer,'device');
 insert into device_private.apple_activity_confirmations(operation_id,owner_id,result_id,execution_id,input_hash,source_revision,observation_revision)
  values(operation,p_owner,r.id,execution,hash,src->>'revision',rev);
 return jsonb_build_object('execution_id',execution,'replayed',false);
end $$;

do $$declare definition text;begin
 definition:=pg_get_functiondef('device_private.apple_result_json(device_private.apple_activity_results)'::regprocedure);
 if strpos(definition,'''name'',r.source_snapshot')=0 then raise exception 'Revisar proyección del resumen Apple';end if;
 execute replace(definition,'''name'',r.source_snapshot',
  '''execution_id'',(select execution_id from device_private.apple_activity_confirmations where result_id=r.id),''scheduled_date'',r.source_snapshot->>''date'',''interval_count'',jsonb_array_length(device_private.apple_measured_laps(r.observation,r.source_snapshot)),''effort_score'',r.observation->''effort_score'',''name'',r.source_snapshot');
end $$;
commit;
