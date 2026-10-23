begin;

-- Conservar los snapshots y hashes de carrera byte a byte. Solo fuerza añade
-- identidad propia de catálogo; ningún dato del fabricante entra en el editor.
create function device_private.strength_snapshot(p_recipe jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare b jsonb; i jsonb; ex public.exercises; blocks jsonb:='[]'; items jsonb;
begin
 if exists(select 1 from jsonb_array_elements(p_recipe->'blocks') x where x->>'format'='running') then return p_recipe; end if;
 if p_recipe->>'source'<>'coach' then raise exception 'unsupported_prescription' using errcode='22023'; end if;
 for b in select value from jsonb_array_elements(p_recipe->'blocks') loop
  if b->>'format'<>'straight_sets' then raise exception 'unsupported_prescription' using errcode='22023'; end if;
  items:='[]';
  for i in select value from jsonb_array_elements(b->'items') loop
   select * into ex from public.exercises where id=(i->>'exercise_id')::uuid and is_public
    and training_profile_version=1 and training_profile_code in ('bench_press_barbell','push_up_standard','pull_up_pronated');
   if not found then raise exception 'unsupported_prescription' using errcode='22023'; end if;
   items:=items||jsonb_build_array(i||jsonb_build_object('exercise_code',ex.training_profile_code,'exercise_name',ex.name));
  end loop;
  blocks:=blocks||jsonb_build_array(b||jsonb_build_object('items',items));
 end loop;
 return p_recipe||jsonb_build_object('sport','strength','blocks',blocks);
end $$;
revoke all on function device_private.strength_snapshot(jsonb) from public,anon,authenticated,service_role;

create function device_private.device_training_template(p_template uuid) returns boolean
language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.workout_blocks b where b.template_id=p_template and b.format='running')
 or (exists(select 1 from public.workout_blocks where template_id=p_template)
 and not exists(select 1 from public.workout_blocks b where b.template_id=p_template and
  (b.format<>'straight_sets' or b.rounds<>1 or b.rest_after_seconds<>0 or b.time_cap_seconds is not null))
 and not exists(select 1 from public.workout_blocks b join public.workout_items i on i.block_id=b.id
  left join public.exercises e on e.id=i.exercise_id where b.template_id=p_template and
   (e.training_profile_code is null or e.training_profile_version<>1 or not e.is_public or
    e.training_profile_code not in ('bench_press_barbell','push_up_standard','pull_up_pronated'))));
$$;
revoke all on function device_private.device_training_template(uuid) from public,anon,authenticated,service_role;

-- Una sesión de fuerza no mide distancia. NULL expresa ausencia, nunca cero ficticio.
alter table public.workout_executions drop constraint workout_observed_totals;
alter table public.workout_executions add constraint workout_observed_totals check (
 (observed_timer_seconds is null and observed_elapsed_seconds is null and observed_distance_meters is null) or
 (observed_timer_seconds>0 and observed_timer_seconds<=172800 and observed_timer_seconds is not null
  and observed_elapsed_seconds is not null and observed_elapsed_seconds>=observed_timer_seconds and observed_elapsed_seconds<=172800
  and (observed_distance_meters is null or observed_distance_meters>0 and observed_distance_meters<=1000000)));

-- Sustituir únicamente los checks de forma V1, manteniendo privacidad y tamaño.
do $$ declare c record; n integer:=0; begin
 for c in select conname,pg_get_constraintdef(oid) as def from pg_constraint
  where conrelid='device_private.activity_observations'::regclass and contype='c' loop
  if c.def like '%schemaVersion%' or c.def like '%''laps''%' or c.def like '%''distanceMeters''%' then
   execute format('alter table device_private.activity_observations drop constraint %I',c.conname); n:=n+1;
  end if;
 end loop;
 if n<>3 then raise exception 'Unexpected observation shape constraints: %',n; end if;
end $$;
alter table device_private.activity_observations add constraint activity_observation_sport_shape check ((
 (observation->>'schemaVersion'='1' and observation->>'sport' is null and jsonb_typeof(observation->'laps')='array'
  and jsonb_array_length(observation->'laps')<=2000 and (observation->>'distanceMeters')::numeric>0
  and not observation?'sets') or
 (observation->>'schemaVersion'='2' and observation->>'sport'='strength' and observation->'distanceMeters'='null'::jsonb
  and jsonb_typeof(observation->'sets')='array' and jsonb_array_length(observation->'sets') between 1 and 2000
  and not observation?'laps')) is true);
alter table device_private.activity_observations add constraint activity_observation_timer check((observation->>'timerSeconds')::numeric>0);

create function device_private.strength_observation_valid(a jsonb) returns boolean
language plpgsql immutable set search_path='' as $$
declare s jsonb; idx integer:=0; seconds numeric:=0; previous_end timestamptz; started timestamptz;
begin
 if a->>'sport' is distinct from 'strength' or a->>'schemaVersion' is distinct from '2' or
  a->>'startedAt' is null or a->>'startedAt' !~ 'Z$' or
  jsonb_typeof(a->'sets') is distinct from 'array' or jsonb_array_length(a->'sets') not between 1 and 2000 or
  (a->>'timerSeconds')::numeric is null or (a->>'timerSeconds')::numeric<=0 or
  (a->>'elapsedSeconds')::numeric is null or (a->>'elapsedSeconds')::numeric not between (a->>'timerSeconds')::numeric and 172800 then return false; end if;
 previous_end:=(a->>'startedAt')::timestamptz;
 for s in select value from jsonb_array_elements(a->'sets') loop
  if s->>'index' is distinct from idx::text or s->>'kind' is null or s->>'kind' not in ('active','rest')
   or s->>'seconds' is null or (s->>'seconds')::numeric<=0 or (s->>'seconds')::numeric>172800
   or s->>'startedAt' is null or s->>'startedAt' !~ 'Z$'
   or not (s ?& array['repetitions','loadKg','exerciseCode','workoutStepIndex'])
   or (s->>'repetitions' is not null and (s->>'repetitions' !~ '^[0-9]+$' or (s->>'repetitions')::integer>1000))
   or (s->>'loadKg' is not null and ((s->>'loadKg')::numeric<0 or (s->>'loadKg')::numeric>1000 or s->>'loadKg' in ('NaN','Infinity','-Infinity')))
   or (s->>'workoutStepIndex' is not null and (s->>'workoutStepIndex' !~ '^[0-9]+$' or (s->>'workoutStepIndex')::integer>10000))
   or (s->>'exerciseCode' is not null and s->>'exerciseCode' not in ('bench_press_barbell','push_up_standard','pull_up_pronated')) then return false; end if;
  started:=(s->>'startedAt')::timestamptz;
  if started<previous_end-interval '1100 milliseconds' then return false; end if;
  previous_end:=started+make_interval(secs=>(s->>'seconds')::double precision);
  seconds:=seconds+(s->>'seconds')::numeric; idx:=idx+1;
 end loop;
 return seconds<=(a->>'elapsedSeconds')::numeric+2 and previous_end<=(a->>'startedAt')::timestamptz+make_interval(secs=>(a->>'elapsedSeconds')::double precision+2);
exception when others then return false;
end $$;
revoke all on function device_private.strength_observation_valid(jsonb) from public,anon,authenticated,service_role;
alter table device_private.activity_observations add constraint activity_strength_valid check (
 observation->>'schemaVersion'<>'2' or device_private.strength_observation_valid(observation));

create function device_private.apply_strength_mapping(p_execution uuid,p_activity jsonb,p_mapping jsonb) returns void
language plpgsql security definer set search_path='' as $$
declare m jsonb; r public.workout_execution_sets; observed jsonb; i integer; used integer[]:='{}'; seen uuid[]:='{}';
begin
 for m in select value from jsonb_array_elements(p_mapping) loop
  select * into r from public.workout_execution_sets where execution_id=p_execution
   and block_order=(m->>'block_order')::integer and item_order=(m->>'item_order')::integer
   and set_order=(m->>'set_order')::integer for update;
  if not found or r.id=any(seen) or r.block_format<>'straight_sets' or r.performance_prescription is not null then
   raise exception 'invalid_mapping' using errcode='22023'; end if;
  seen:=array_append(seen,r.id);
  if coalesce((m->>'skipped')::boolean,false) then perform public.skip_workout_set(r.id); continue; end if;
  if jsonb_typeof(m->'lap_indices') is distinct from 'array' or jsonb_array_length(m->'lap_indices')<>1
   or coalesce(m->'recovery_lap_indices','[]')<>'[]'::jsonb
   or (m->'lap_indices'->0)::text !~ '^[0-9]+$' then raise exception 'invalid_mapping' using errcode='22023'; end if;
  i:=(m->'lap_indices'->>0)::integer; observed:=p_activity->'sets'->i;
  if i=any(used) or observed is null or observed->>'kind'<>'active' or
   (r.target_reps is not null and observed->>'repetitions' is null) then raise exception 'invalid_mapping' using errcode='22023'; end if;
  used:=array_append(used,i);
  -- Solo mediciones de la evidencia privada; el cliente aporta índices, no marcas.
  perform public.complete_workout_set(r.id,p_actual_reps=>(observed->>'repetitions')::integer,
   p_actual_duration_seconds=>round((observed->>'seconds')::numeric)::integer,
   p_actual_load_kg=>(observed->>'loadKg')::numeric,p_result_source=>'device');
 end loop;
end $$;
revoke all on function device_private.apply_strength_mapping(uuid,jsonb,jsonb) from public,anon,authenticated,service_role;


-- Proyecciones vigentes ampliadas sin cambiar las autoridades de cuenta/cita.

create or replace function device_private.training_source(p_actor uuid,p_owner uuid,p_schedule uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare s public.scheduled_workouts; t public.workout_templates; a public.trainer_assignments;
 decision jsonb; recipe jsonb;
begin
 select * into s from public.scheduled_workouts where id=p_schedule and user_id=p_owner for share;
 if not found or s.status<>'planned' or s.execution_id is not null then raise exception 'source_not_available' using errcode='42501'; end if;
 select * into t from public.workout_templates where id=s.template_id for share;
 if not found or t.status<>'published' or t.version<>s.template_version then raise exception 'stale_prescription' using errcode='40001'; end if;
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
 recipe:=device_private.strength_snapshot(recipe);
 if octet_length(recipe::text)>131072 then raise exception 'unsupported_prescription' using errcode='22023'; end if;
 return jsonb_build_object('snapshot',recipe,'revision',encode(sha256(convert_to(recipe::text,'UTF8')),'hex'));
end $$;

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
 recipe:=device_private.strength_snapshot(recipe);
 if octet_length(recipe::text)>131072 then raise exception 'unsupported_prescription' using errcode='22023'; end if;
 -- Archivar la biblioteca no retira una pauta ya entregada y aún vigente.
 if t.status='archived' and (s.source<>'coach' or not exists(
   select 1 from device_private.training_deliveries d where d.owner_id=p_owner
   and d.scheduled_id=s.id and d.status='sent' and d.snapshot=recipe
   and d.revision=encode(sha256(convert_to(recipe::text,'UTF8')),'hex'))) then
  raise exception 'stale_prescription' using errcode='40001'; end if;
 return jsonb_build_object('snapshot',recipe,'revision',encode(sha256(convert_to(recipe::text,'UTF8')),'hex'));
end $$;

create or replace function device_private.garmin_training_command(p_action text,p_actor uuid,p_owner uuid,p_session uuid,p_input jsonb)
returns jsonb language plpgsql security definer set search_path='' as $$
declare c device_private.garmin_connections; j device_private.training_deliveries; src jsonb;
 v_now timestamptz; v_schedule uuid; v_lease uuid; v_generation bigint; v_code text; v_count integer;
begin
 if p_input is null or jsonb_typeof(p_input)<>'object' or octet_length(p_input::text)>40000 or p_owner is null or p_actor is null then
  raise invalid_parameter_value; end if;
 -- Mismo orden que la edición/retirada profesional, antes de cita y conexión.
 perform pg_advisory_xact_lock(hashtextextended('trainer-client:'||p_owner::text,0));
 perform 1 from auth.users where id=p_owner for key share;
 if not found then raise insufficient_privilege; end if;
 if p_action in ('list','preview','claim','mark_refreshing','mark_creating','mark_scheduling') then
 if p_session is null and p_actor=p_owner and device_private.training_sync_valid(p_owner,p_input) then null; else perform 1 from auth.sessions where id=p_session and user_id=p_actor and (not_after is null or not_after>clock_timestamp())
  and (p_actor=p_owner or aal='aal2') for key share;
 if not found then raise exception 'account_changed' using errcode='42501'; end if;
 if p_actor<>p_owner and not exists(select 1 from public.trainer_client_relations r join public.trainer_access a on a.trainer_id=r.trainer_id
  where r.trainer_id=p_actor and r.client_id=p_owner and r.ended_at is null and a.enabled
   and (a.valid_until is null or a.valid_until>clock_timestamp())) then raise insufficient_privilege; end if;
 end if;
 end if; if p_action='list' then
  return jsonb_build_object('candidates',(select coalesce(jsonb_agg(to_jsonb(x)),'[]'::jsonb) from (
   select s.id,s.template_name as name,s.scheduled_date as date,s.source
    from public.scheduled_workouts s where s.user_id=p_owner and s.status='planned' and s.execution_id is null
    and s.scheduled_date between current_date-1 and current_date+366
    and ((p_actor=p_owner and s.source='algorithm') or (s.source='coach' and exists(select 1 from public.trainer_assignments a
     where a.scheduled_id=s.id and a.client_id=p_owner and (p_actor=p_owner or a.trainer_id=p_actor))))
    and device_private.device_training_template(s.template_id)
    order by s.scheduled_date,s.order_index,s.id limit 30) x),
   'deliveries',(select coalesce(jsonb_agg(device_private.training_receipt(x.id)),'[]'::jsonb) from (
    select d.id from device_private.training_deliveries d where d.owner_id=p_owner and (p_actor=p_owner or exists(
     select 1 from public.trainer_assignments a where a.scheduled_id=d.scheduled_id and a.trainer_id=p_actor))
     order by d.created_at desc limit 30) x));
 end if;
 if p_action in ('preview','claim') then
  if not device_private.garmin_access(p_owner) then raise exception 'access_required' using errcode='42501'; end if;
  v_schedule:=(p_input->>'scheduled_id')::uuid;
  src:=device_private.training_source(p_actor,p_owner,v_schedule);
  if p_action='preview' then return src; end if;
  if src->>'revision' is distinct from p_input->>'revision' then raise exception 'stale_prescription' using errcode='40001'; end if;
 end if;
 select * into c from device_private.garmin_connections where owner_id=p_owner for update;
 if not found then raise exception 'connection_required' using errcode='42501'; end if;
 v_now:=clock_timestamp();
 if p_action='claim' then
  select * into j from device_private.training_deliveries where owner_id=p_owner and scheduled_id=v_schedule for update;
  if found then
   if j.revision<>src->>'revision' or (j.connection_generation<>c.generation and (j.workout_id is not null or j.status not in ('prepared','failed'))) then
    raise exception 'delivery_needs_review' using errcode='40001'; end if;
   if j.status='sent' then return jsonb_build_object('done',true,'receipt',device_private.training_receipt(j.id)); end if;
   if j.status in ('refreshing','creating','scheduling','uncertain') then
    if j.lease_until>v_now then raise exception 'connection_busy' using errcode='40001'; end if;
    return jsonb_build_object('done',true,'receipt',device_private.training_receipt(j.id)||jsonb_build_object('status','uncertain'));
   end if;
   if j.lease_until>v_now then raise exception 'connection_busy' using errcode='40001'; end if;
   if j.last_attempt_at>v_now-interval '30 seconds' then raise exception 'rate_limited' using errcode='P0001'; end if;
  end if;
  if c.status<>'connected' or not c.can_send then raise exception 'connection_required' using errcode='42501'; end if;
  if c.training_lease_until>v_now or c.disconnect_lease_until>v_now then raise exception 'connection_busy' using errcode='40001'; end if;
  if j.id is null then
   insert into device_private.training_deliveries(owner_id,scheduled_id,connection_generation,revision,snapshot)
    values(p_owner,v_schedule,c.generation,src->>'revision',src->'snapshot') returning * into j;
  elsif j.connection_generation<>c.generation then
   -- Reconectar permite continuar solo si se sabe que no se creó nada remoto.
   update device_private.training_deliveries set connection_generation=c.generation where id=j.id;
  end if;
  v_lease:=(p_input->>'lease_id')::uuid;
  if v_lease is null then raise invalid_parameter_value; end if;
  update device_private.garmin_connections set training_lease=v_lease,training_lease_until=v_now+interval '3 minutes' where owner_id=p_owner;
  update device_private.training_deliveries set lease_id=v_lease,lease_until=v_now+interval '3 minutes',lease_actor=p_actor,lease_session=p_session,
   last_attempt_at=v_now,updated_at=v_now where id=j.id;
  return jsonb_build_object('done',false,'id',j.id,'generation',c.generation,'snapshot',j.snapshot,
   'workout_id',j.workout_id,'garmin_user_id',c.garmin_user_id,'tokens_cipher',c.tokens_cipher,'access_expires_at',c.access_expires_at,'refresh_expires_at',c.refresh_expires_at);
 end if;
 select * into j from device_private.training_deliveries where id=(p_input->>'id')::uuid and owner_id=p_owner for update;
 if not found or j.lease_actor is distinct from p_actor or j.lease_session is distinct from p_session then
  raise insufficient_privilege; end if;
 v_lease:=(p_input->>'lease_id')::uuid;
 if j.lease_id is distinct from v_lease or v_lease is null or c.training_lease is distinct from v_lease
  or c.generation<>j.connection_generation or j.lease_until<=v_now or c.training_lease_until<=v_now then
  raise exception 'stale_attempt' using errcode='40001'; end if;
 if p_action='release' then
  update device_private.training_deliveries set lease_id=null,lease_until=null where id=j.id;
  update device_private.garmin_connections set training_lease=null,training_lease_until=null where owner_id=p_owner;
  return device_private.training_receipt(j.id);
 end if;
 if p_action='fail' then
  if j.status='sent' then return device_private.training_receipt(j.id); end if;
  v_code:=p_input->>'code';
  if j.status='refreshing' and coalesce((p_input->>'uncertain')::boolean,false) then
   update device_private.garmin_connections set status='revocation_pending',can_read=false,can_send=false where owner_id=p_owner;
  end if;
  -- Una respuesta local perdida no borra hechos que sí quedaron confirmados:
  -- reutilizar el workout guardado o devolver el recibo final, sin otro POST.
  update device_private.training_deliveries set status=case when coalesce((p_input->>'uncertain')::boolean,false)
    and j.status in ('refreshing','creating','scheduling') then 'uncertain' else 'failed' end,
   error_code=v_code,updated_at=v_now where id=j.id;
  return device_private.training_receipt(j.id);
 end if;
 if p_action='rotate' then
  if j.status<>'refreshing' or coalesce(p_input->>'tokens_cipher','')='' or
   (p_input->>'access_expires_at')::timestamptz<=v_now or (p_input->>'refresh_expires_at')::timestamptz<=v_now or
   not isfinite((p_input->>'access_expires_at')::timestamptz) or not isfinite((p_input->>'refresh_expires_at')::timestamptz) then
    raise invalid_parameter_value; end if;
  update device_private.garmin_connections set tokens_cipher=p_input->>'tokens_cipher',
   access_expires_at=(p_input->>'access_expires_at')::timestamptz,refresh_expires_at=(p_input->>'refresh_expires_at')::timestamptz where owner_id=p_owner;
  update device_private.training_deliveries set status=case when workout_id is null then 'prepared' else 'workout_created' end where id=j.id;
  return '{}'::jsonb;
 end if;
 if p_action='permissions' then
  update device_private.garmin_connections set can_read=status='connected' and (p_input->>'can_read')::boolean,
   can_send=status='connected' and (p_input->>'can_send')::boolean where owner_id=p_owner;
  return '{}'::jsonb;
 end if;
 if p_action='mark_refreshing' then
  if c.status<>'connected' or not c.can_send or j.status not in ('prepared','workout_created','failed') then raise exception 'connection_changed' using errcode='40001'; end if;
  update device_private.training_deliveries set status='refreshing',updated_at=v_now where id=j.id;
  return '{}'::jsonb;
 end if;
 if p_action in ('mark_creating','mark_scheduling') then
  if c.status<>'connected' or not c.can_send then raise exception 'connection_changed' using errcode='40001'; end if;
  if not device_private.garmin_access(p_owner) then raise exception 'access_required' using errcode='42501'; end if;
  -- Revalidar autoridad/versión justo antes de cada escritura externa.
  src:=device_private.training_source(p_actor,p_owner,j.scheduled_id);
  if src->>'revision'<>j.revision then raise exception 'stale_prescription' using errcode='40001'; end if;
  if (p_action='mark_creating' and (j.status not in ('prepared','failed') or j.workout_id is not null))
   or (p_action='mark_scheduling' and (j.status not in ('workout_created','failed') or j.workout_id is null)) then raise invalid_parameter_value; end if;
  update device_private.training_deliveries set status=case p_action when 'mark_creating' then 'creating' else 'scheduling' end,
   error_code=null,updated_at=v_now where id=j.id;
 elsif p_action='save_workout' then
  if j.status<>'creating' then raise invalid_parameter_value; end if;
  update device_private.training_deliveries set status='workout_created',workout_id=(p_input->>'workout_id')::bigint,updated_at=v_now where id=j.id;
 elsif p_action='save_schedule' then
  if j.status<>'scheduling' then raise invalid_parameter_value; end if;
  update device_private.training_deliveries set status='sent',schedule_id=(p_input->>'schedule_id')::bigint,error_code=null,updated_at=v_now where id=j.id;
 else raise invalid_parameter_value; end if;
 return device_private.training_receipt(j.id);
end $$;

create or replace function device_private.training_sync_target(p_owner uuid,p_schedule uuid) returns jsonb
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
 if s.id is not null and not device_private.device_training_template(s.template_id) then return '{"mode":"hold"}'::jsonb;end if;
 if s.source='algorithm' and not exists(select 1 from public.workout_blocks where template_id=s.template_id and format='running') then return '{"mode":"hold"}'::jsonb; end if;
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
   select z.id,z.external_id,z.revision,z.observation-'laps'-'sets' as activity,
    (select f.execution_id from device_private.activity_confirmations f where f.owner_id=u and f.external_id=z.external_id) as execution_id
    from (select distinct on(external_id) * from device_private.activity_observations where owner_id=u
      order by external_id,created_at desc,id desc) z order by z.created_at desc,z.id desc limit 50) x),
   'candidates',(select coalesce(jsonb_agg(to_jsonb(x)),'[]'::jsonb) from (
    select sw.id,sw.template_name as name,sw.scheduled_date as date,sw.source,case when exists(select 1 from public.workout_blocks b where b.template_id=sw.template_id and b.format='running') then 'running' else 'strength' end as sport from public.scheduled_workouts sw
    where sw.user_id=u and sw.status='planned' and sw.execution_id is null and sw.source in ('coach','algorithm')
     and sw.scheduled_date between current_date-90 and current_date+14
     and device_private.device_training_template(sw.template_id)
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
  if coalesce(snap->>'sport','running') is distinct from coalesce(a.observation->>'sport','running') then raise exception 'invalid_mapping' using errcode='22023'; end if;
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
  if a.observation->>'sport'='strength' then perform device_private.apply_strength_mapping(e,a.observation,v_mapping);
  else perform device_private.apply_activity_mapping(e,a.observation,v_mapping); end if;
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
