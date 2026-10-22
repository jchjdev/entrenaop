-- Carrera V2: semántica independiente del fabricante y finalización manual.
-- Las filas antiguas mantienen running_step NULL; no se reescribe el historial.
begin;
alter table public.workout_sets add column running_step jsonb;
alter table public.workout_execution_sets add column running_step jsonb;

create function public.valid_running_step_v2(p jsonb,seconds integer,meters numeric)
returns boolean language plpgsql immutable set search_path='' as $$
begin
 if p is null or p='null'::jsonb then return num_nonnulls(seconds,meters)=1; end if;
 if jsonb_typeof(p)<>'object' or p->'schema_version' is distinct from '2'::jsonb
  or (p-array['schema_version','kind','completion'])<>'{}'::jsonb
  or not(p ?& array['schema_version','kind','completion'])
  or jsonb_typeof(p->'kind') is distinct from 'string'
  or p->>'kind' not in ('warmup','run','recovery','rest','cooldown','walking','jogging')
  or jsonb_typeof(p->'completion') is distinct from 'string'
  then return false; end if;
 if p->>'kind'='rest' and meters is not null then return false;end if;
 return case p->>'completion'
  when 'manual' then seconds is null and meters is null
  when 'time' then seconds>0 and meters is null
  when 'distance' then meters>0 and seconds is null
  else false end;
end $$;
revoke all on function public.valid_running_step_v2(jsonb,integer,numeric) from public,anon;
grant execute on function public.valid_running_step_v2(jsonb,integer,numeric) to authenticated,service_role;

alter table public.workout_sets drop constraint workout_sets_has_target;
alter table public.workout_sets add constraint workout_sets_has_target check (
 target_reps is not null or target_duration_seconds is not null or target_distance_meters is not null
 or performance_prescription is not null or coalesce(running_step->>'completion'='manual',false));
alter table public.workout_sets add constraint workout_sets_running_step_v2 check(running_step is null or (
 public.valid_running_step_v2(running_step,target_duration_seconds,target_distance_meters) is true
 and target_reps is null and target_load_kg is null and target_rir is null and performance_prescription is null
 and (running_step->>'kind'<>'rest' or target_pace_min_seconds_per_km is null)));
alter table public.workout_execution_sets add constraint execution_running_step_v2 check(running_step is null or (
 public.valid_running_step_v2(running_step,target_duration_seconds,target_distance_meters) is true
 and target_reps is null and performance_prescription is null));

-- El snapshot nace con la ejecución y nunca sigue las ediciones de la plantilla.
create function public.snapshot_running_step_v2() returns trigger
language plpgsql security definer set search_path='' as $$
begin
 if TG_OP='INSERT' then
  select s.running_step into new.running_step from public.workout_sets s where s.id=new.source_set_id;
 elsif new.running_step is distinct from old.running_step or
  (old.running_step is not null and (new.target_duration_seconds,new.target_distance_meters,new.source_set_id,new.block_format)
    is distinct from (old.target_duration_seconds,old.target_distance_meters,old.source_set_id,old.block_format)) then
  raise exception 'La prescripción de carrera ejecutada es inmutable.' using errcode='22023';
 end if;
 return new;
end $$;
revoke all on function public.snapshot_running_step_v2() from public,anon,authenticated;
create trigger snapshot_running_step_v2 before insert or update on public.workout_execution_sets
 for each row execute function public.snapshot_running_step_v2();

create or replace function public.validate_running_workout_set()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  parent_format text;
begin
  select block.format into parent_format
  from public.workout_items as item
  join public.workout_blocks as block on block.id = item.block_id
  where item.id = new.item_id;

  if parent_format = 'running' then
    if public.valid_running_step_v2(new.running_step,new.target_duration_seconds,new.target_distance_meters) is not true
      or new.target_reps is not null
      or new.target_load_kg is not null
      or new.target_rir is not null
      or new.rest_after_seconds <> 0 then
      raise exception 'Running segments require one distance or duration target';
    end if;
  elsif new.running_step is not null
    or new.target_pace_min_seconds_per_km is not null
    or new.target_pace_max_seconds_per_km is not null
    or new.recovery_type is not null
    or new.recovery_duration_seconds is not null
    or new.recovery_distance_meters is not null then
    raise exception 'Running metadata belongs only to running blocks';
  end if;
  return new;
end;
$$;


create or replace function public.create_personal_running_workout_template(
  p_payload jsonb
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_user_id uuid := auth.uid();
  block_json jsonb;
  exercise_json jsonb;
  segment_json jsonb;
  v_template_id uuid;
  v_block_id uuid;
  v_item_id uuid;
  segment_order integer := 0;
  normalized_name text := btrim(coalesce(p_payload ->> 'name', ''));
  normalized_description text := nullif(
    btrim(p_payload ->> 'description'), ''
  );
  estimated_minutes integer :=
    (p_payload ->> 'estimated_duration_minutes')::integer;
  target_duration integer;
  target_distance numeric;
  pace_min integer;
  pace_max integer;
  recovery_mode text;
  recovery_duration integer;
  recovery_distance numeric;
begin
  if current_user_id is null then
    raise exception 'Authentication required';
  end if;
  if char_length(normalized_name) not between 3 and 80 then
    raise exception 'Workout name must contain between 3 and 80 characters';
  end if;
  if char_length(coalesce(normalized_description, '')) > 500 then
    raise exception 'Workout description is too long';
  end if;
  if estimated_minutes is not null
    and estimated_minutes not between 1 and 600 then
    raise exception 'Estimated duration is invalid';
  end if;
  if coalesce(jsonb_typeof(p_payload -> 'blocks'), 'null') <> 'array'
    or jsonb_array_length(p_payload -> 'blocks') <> 1 then
    raise exception 'A running workout requires exactly one block';
  end if;

  block_json := p_payload -> 'blocks' -> 0;
  if block_json ->> 'format' <> 'running'
    or coalesce((block_json ->> 'rounds')::integer, 1) <> 1
    or coalesce((block_json ->> 'rest_after_seconds')::integer, 0) <> 0
    or coalesce(jsonb_typeof(block_json -> 'exercises'), 'null') <> 'array'
    or jsonb_array_length(block_json -> 'exercises') <> 1 then
    raise exception 'Running block structure is invalid';
  end if;
  exercise_json := block_json -> 'exercises' -> 0;
  if exercise_json ->> 'exercise_id'
      <> '20000000-0000-4000-8000-000000000004'
    or coalesce(jsonb_typeof(exercise_json -> 'sets'), 'null') <> 'array'
    or jsonb_array_length(exercise_json -> 'sets') not between 1 and 40 then
    raise exception 'Running workout must contain between 1 and 40 segments';
  end if;

  insert into public.workout_templates (
    name, description, origin, owner_user_id, visibility, status,
    estimated_duration_minutes
  ) values (
    normalized_name, normalized_description, 'user', current_user_id,
    'private', 'published', estimated_minutes
  ) returning id into v_template_id;

  insert into public.workout_blocks (
    template_id, order_index, name, format, rounds, rest_after_seconds
  ) values (
    v_template_id, 0,
    left(coalesce(nullif(btrim(block_json ->> 'name'), ''), 'Carrera'), 60),
    'running', 1, 0
  ) returning id into v_block_id;

  insert into public.workout_items (
    block_id, exercise_id, order_index, notes
  ) values (
    v_block_id, '20000000-0000-4000-8000-000000000004', 0, null
  ) returning id into v_item_id;

  for segment_json in
    select value from jsonb_array_elements(exercise_json -> 'sets')
  loop
    target_duration := (segment_json ->> 'target_duration_seconds')::integer;
    target_distance := (segment_json ->> 'target_distance_meters')::numeric;
    pace_min :=
      (segment_json ->> 'target_pace_min_seconds_per_km')::integer;
    pace_max :=
      (segment_json ->> 'target_pace_max_seconds_per_km')::integer;
    recovery_mode := nullif(segment_json ->> 'recovery_type', '');
    recovery_duration :=
      (segment_json ->> 'recovery_duration_seconds')::integer;
    recovery_distance :=
      (segment_json ->> 'recovery_distance_meters')::numeric;

    if public.valid_running_step_v2(segment_json->'running_step',target_duration,target_distance) is not true then
      raise exception 'Each running segment needs one distance or duration';
    end if;
    if (pace_min is null) <> (pace_max is null)
      or (pace_min is not null
        and (pace_min <= 0 or pace_max < pace_min or pace_max > 3600)) then
      raise exception 'Running pace is invalid';
    end if;
    if (recovery_mode is null
        and num_nonnulls(recovery_duration, recovery_distance) <> 0)
      or (recovery_mode is not null
        and (
          recovery_mode not in ('passive', 'walking', 'jogging')
          or num_nonnulls(recovery_duration, recovery_distance) <> 1
          or coalesce(recovery_duration, 1) <= 0
          or coalesce(recovery_distance, 1) <= 0
          or (recovery_mode = 'passive' and recovery_duration is null)
        )) then
      raise exception 'Running recovery is invalid';
    end if;

    insert into public.workout_sets (
      item_id, order_index, target_duration_seconds,
      target_distance_meters, rest_after_seconds,
      target_pace_min_seconds_per_km, target_pace_max_seconds_per_km,
      recovery_type, recovery_duration_seconds, recovery_distance_meters, running_step
    ) values (
      v_item_id, segment_order, target_duration, target_distance, 0,
      pace_min, pace_max, recovery_mode, recovery_duration,
      recovery_distance, nullif(segment_json->'running_step','null'::jsonb)
    );
    segment_order := segment_order + 1;
  end loop;

  return v_template_id;
end;
$$;


create or replace function public.duplicate_personal_workout_template(
  p_template_id uuid
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_user_id uuid := auth.uid();
  source_template record;
  source_block record;
  source_item record;
  v_template_id uuid;
  v_block_id uuid;
  v_item_id uuid;
begin
  if current_user_id is null then
    raise exception 'Authentication required';
  end if;
  select template.* into source_template
  from public.workout_templates as template
  where template.id = p_template_id
    and template.owner_user_id = current_user_id
    and template.origin = 'user'
    and template.status <> 'archived';
  if not found then
    raise exception 'Personal workout is not accessible';
  end if;

  insert into public.workout_templates (
    name, description, origin, owner_user_id, visibility, status,
    estimated_duration_minutes, version
  ) values (
    left(source_template.name, 72) || ' (copia)',
    source_template.description, 'user', current_user_id, 'private',
    'published', source_template.estimated_duration_minutes, 1
  ) returning id into v_template_id;

  for source_block in
    select block.* from public.workout_blocks as block
    where block.template_id = p_template_id order by block.order_index
  loop
    insert into public.workout_blocks (
      template_id, order_index, name, format, rounds, time_cap_seconds,
      rest_after_seconds
    ) values (
      v_template_id, source_block.order_index, source_block.name,
      source_block.format, source_block.rounds, source_block.time_cap_seconds,
      source_block.rest_after_seconds
    ) returning id into v_block_id;

    for source_item in
      select item.* from public.workout_items as item
      where item.block_id = source_block.id order by item.order_index
    loop
      insert into public.workout_items (
        block_id, exercise_id, order_index, notes
      ) values (
        v_block_id, source_item.exercise_id, source_item.order_index,
        source_item.notes
      ) returning id into v_item_id;

      insert into public.workout_sets (
        item_id, order_index, target_reps, target_duration_seconds,
        target_distance_meters, target_load_kg, target_rpe, target_rir,
        rest_after_seconds, target_pace_min_seconds_per_km,
        target_pace_max_seconds_per_km, recovery_type,
        recovery_duration_seconds, recovery_distance_meters, running_step
      )
      select
        v_item_id, prescribed.order_index, prescribed.target_reps,
        prescribed.target_duration_seconds, prescribed.target_distance_meters,
        prescribed.target_load_kg, prescribed.target_rpe,
        prescribed.target_rir, prescribed.rest_after_seconds,
        prescribed.target_pace_min_seconds_per_km,
        prescribed.target_pace_max_seconds_per_km,
        prescribed.recovery_type, prescribed.recovery_duration_seconds,
        prescribed.recovery_distance_meters, prescribed.running_step
      from public.workout_sets as prescribed
      where prescribed.item_id = source_item.id
      order by prescribed.order_index;
    end loop;
  end loop;
  return v_template_id;
end;
$$;


create or replace function trainer_private.validate_session_work_state(p_state jsonb) returns void
language plpgsql immutable set search_path='' as $$
declare editor jsonb;segment jsonb;block jsonb;exercise jsonb;variation jsonb;indices integer[];idx integer;total integer:=0;
begin
 perform trainer_private.session_work_fields(p_state,array['schema','editor','context'],array['intent'],'{}');
 if p_state->'schema' is distinct from '1'::jsonb or p_state->'context' is distinct from '{}'::jsonb
  or octet_length(p_state::text)>524288
  or (p_state ? 'intent' and jsonb_typeof(p_state->'intent')<>'object') then raise invalid_parameter_value;end if;
 editor:=p_state->'editor';
 perform trainer_private.session_work_fields(editor,
  array['schema','running','nameText','descriptionText','durationText','segments','blocks'],'{}',
  array['nameText','descriptionText','durationText']);
 if editor->'schema' is distinct from '1'::jsonb or jsonb_typeof(editor->'running') is distinct from 'boolean'
  or jsonb_typeof(editor->'segments') is distinct from 'array' or jsonb_typeof(editor->'blocks') is distinct from 'array'
  or jsonb_array_length(editor->'segments')>40 or jsonb_array_length(editor->'blocks')>100 then raise invalid_parameter_value;end if;
 for segment in select value from jsonb_array_elements(editor->'segments') loop
  perform trainer_private.session_work_fields(segment,
   array['countText','targetText','paceText','paceMaxText','recoveryTimeText','byDistance','recoveryByDistance','recoveryType'],array['stepKind','manual'],
   array['countText','targetText','paceText','paceMaxText','recoveryTimeText']);
  if (segment ? 'manual' and jsonb_typeof(segment->'manual') is distinct from 'boolean')
   or (segment ? 'stepKind' and (jsonb_typeof(segment->'stepKind') is distinct from 'string' or segment->>'stepKind' not in ('warmup','run','recovery','rest','cooldown','walking','jogging')))
   or jsonb_typeof(segment->'byDistance') is distinct from 'boolean' or jsonb_typeof(segment->'recoveryByDistance') is distinct from 'boolean'
   or (segment->'recoveryType'<>'null'::jsonb and (jsonb_typeof(segment->'recoveryType')<>'string'
    or segment->>'recoveryType' not in ('passive','walking','jogging'))) then raise invalid_parameter_value;end if;
 end loop;
 for block in select value from jsonb_array_elements(editor->'blocks') loop
  perform trainer_private.session_work_fields(block,array['nameText','format','roundsText','restText','capText','exercises'],'{}',
   array['nameText','roundsText','restText','capText']);
  if jsonb_typeof(block->'format') is distinct from 'string' or block->>'format' not in
   ('straightSets','circuit','superset','intervals','emom','amrap','tabata','running','warmUp','coolDown')
   or jsonb_typeof(block->'exercises') is distinct from 'array' or jsonb_array_length(block->'exercises')>100 then raise invalid_parameter_value;end if;
  for exercise in select value from jsonb_array_elements(block->'exercises') loop
   total:=total+1;if total>4096 then raise invalid_parameter_value;end if;
   perform trainer_private.session_work_fields(exercise,
    array['exerciseId','targetType','automaticSlot','customSets','countText','targetText','restText','loadText','rirText','amrapRepetitionsText','amrapRirText','variations'],'{}',
    array['countText','targetText','restText','loadText','rirText','amrapRepetitionsText','amrapRirText']);
   if (exercise->'exerciseId'<>'null'::jsonb and (jsonb_typeof(exercise->'exerciseId')<>'string' or length(exercise->>'exerciseId')>128))
    or jsonb_typeof(exercise->'targetType') is distinct from 'string' or exercise->>'targetType' not in ('repetitions','duration','distance')
    or jsonb_typeof(exercise->'automaticSlot') is distinct from 'boolean' or jsonb_typeof(exercise->'customSets') is distinct from 'boolean'
    or jsonb_typeof(exercise->'variations') is distinct from 'array' or jsonb_array_length(exercise->'variations')>20 then raise invalid_parameter_value;end if;
   indices:='{}';
   for variation in select value from jsonb_array_elements(exercise->'variations') loop
    perform trainer_private.session_work_fields(variation,array['setIndex','targetText','restText','loadText','rirText'],'{}',
     array['targetText','restText','loadText','rirText']);
    if jsonb_typeof(variation->'setIndex') is distinct from 'number' or variation->>'setIndex' !~ '^[0-9]{1,2}$' then raise invalid_parameter_value;end if;
    idx:=(variation->>'setIndex')::integer;
    if idx>=20 or idx=any(indices) then raise invalid_parameter_value;end if;
    indices:=array_append(indices,idx);
   end loop;
  end loop;
 end loop;
end $$;


-- Mantener el hash V1: una columna NULL nueva no cambia la identidad de envío.
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
 if octet_length(recipe::text)>131072 then raise exception 'unsupported_prescription' using errcode='22023'; end if;
 return jsonb_build_object('snapshot',recipe,'revision',encode(sha256(convert_to(recipe::text,'UTF8')),'hex'));
end $$;

commit;
