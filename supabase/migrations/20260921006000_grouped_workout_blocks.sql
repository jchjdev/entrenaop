-- Superseries y circuitos ejecutables. El formato queda copiado en cada
-- resultado y el descanso del bloque se aplica solo al final de cada ronda.

begin;

alter table public.workout_execution_sets
  add column block_format text not null default 'straight_sets',
  add constraint workout_execution_sets_block_format_check
    check (
      block_format in (
        'straight_sets', 'superset', 'circuit', 'intervals', 'emom',
        'amrap', 'tabata', 'warm_up', 'cool_down'
      )
    );

create or replace function public.create_personal_workout_template(
  p_payload jsonb
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_user_id uuid := auth.uid();
  v_template_id uuid;
  v_block_id uuid;
  block_json jsonb;
  exercise_json jsonb;
  set_json jsonb;
  v_exercise_id uuid;
  v_item_id uuid;
  block_order integer := 0;
  exercise_order integer;
  set_order integer;
  total_exercises integer := 0;
  workout_name text := btrim(coalesce(p_payload ->> 'name', ''));
  workout_description text := nullif(btrim(p_payload ->> 'description'), '');
  block_name text;
  block_format text;
  block_rounds integer;
  block_rest_seconds integer;
  block_exercise_count integer;
  duration_minutes integer;
  target_reps integer;
  target_duration_seconds integer;
  target_distance_meters numeric;
begin
  if current_user_id is null then
    raise exception 'Authentication required';
  end if;
  if char_length(workout_name) not between 3 and 80 then
    raise exception 'Workout name must contain between 3 and 80 characters';
  end if;
  if char_length(coalesce(workout_description, '')) > 500 then
    raise exception 'Workout description is too long';
  end if;

  if p_payload ? 'estimated_duration_minutes'
    and p_payload ->> 'estimated_duration_minutes' is not null then
    duration_minutes := (p_payload ->> 'estimated_duration_minutes')::integer;
    if duration_minutes not between 1 and 600 then
      raise exception 'Estimated duration is out of range';
    end if;
  end if;

  if coalesce(jsonb_typeof(p_payload -> 'blocks'), 'null') <> 'array'
    or jsonb_array_length(p_payload -> 'blocks') not between 1 and 10 then
    raise exception 'Workout must contain between 1 and 10 blocks';
  end if;

  insert into public.workout_templates (
    name, description, origin, owner_user_id, visibility, status,
    estimated_duration_minutes
  ) values (
    workout_name, workout_description, 'user', current_user_id, 'private',
    'published', duration_minutes
  ) returning id into v_template_id;

  for block_json in
    select value from jsonb_array_elements(p_payload -> 'blocks')
  loop
    block_name := btrim(coalesce(block_json ->> 'name', ''));
    block_format := coalesce(block_json ->> 'format', 'straight_sets');
    block_rounds := coalesce((block_json ->> 'rounds')::integer, 1);
    block_rest_seconds :=
      coalesce((block_json ->> 'rest_after_seconds')::integer, 0);

    if char_length(block_name) not between 1 and 60 then
      raise exception 'Block name must contain between 1 and 60 characters';
    end if;
    if block_format not in ('straight_sets', 'superset', 'circuit') then
      raise exception 'Workout block format is not supported by this creator';
    end if;
    if block_rounds not between 1 and 20 then
      raise exception 'Block rounds are out of range';
    end if;
    if block_rest_seconds not between 0 and 3600 then
      raise exception 'Block rest is out of range';
    end if;
    if block_format = 'straight_sets'
      and (block_rounds <> 1 or block_rest_seconds <> 0) then
      raise exception 'Straight set blocks cannot define rounds or block rest';
    end if;
    if coalesce(jsonb_typeof(block_json -> 'exercises'), 'null') <> 'array'
      or jsonb_array_length(block_json -> 'exercises') not between 1 and 20 then
      raise exception 'Each block must contain between 1 and 20 exercises';
    end if;

    block_exercise_count := jsonb_array_length(block_json -> 'exercises');
    if block_format = 'superset' and block_exercise_count <> 2 then
      raise exception 'A superset must contain exactly two exercises';
    end if;
    if block_format = 'circuit' and block_exercise_count < 2 then
      raise exception 'A circuit must contain at least two exercises';
    end if;

    total_exercises := total_exercises + block_exercise_count;
    if total_exercises > 40 then
      raise exception 'Workout cannot contain more than 40 exercises';
    end if;

    insert into public.workout_blocks (
      template_id, order_index, name, format, rounds, rest_after_seconds
    ) values (
      v_template_id, block_order, block_name, block_format, block_rounds,
      block_rest_seconds
    ) returning id into v_block_id;

    exercise_order := 0;
    for exercise_json in
      select value from jsonb_array_elements(block_json -> 'exercises')
    loop
      v_exercise_id := (exercise_json ->> 'exercise_id')::uuid;

      if not exists (
        select 1 from public.exercises as exercise
        where exercise.id = v_exercise_id
          and (
            exercise.is_public is true
            or exercise.created_by = current_user_id
            or public.is_admin()
          )
      ) then
        raise exception 'Exercise is not accessible';
      end if;
      if exists (
        select 1 from public.workout_items as existing_item
        where existing_item.block_id = v_block_id
          and existing_item.exercise_id = v_exercise_id
      ) then
        raise exception 'An exercise cannot be repeated in the same block';
      end if;
      if coalesce(jsonb_typeof(exercise_json -> 'sets'), 'null') <> 'array'
        or jsonb_array_length(exercise_json -> 'sets') not between 1 and 20 then
        raise exception 'Exercise must contain between 1 and 20 sets';
      end if;
      if block_format in ('superset', 'circuit')
        and jsonb_array_length(exercise_json -> 'sets') <> block_rounds then
        raise exception 'Grouped exercises require one set per round';
      end if;

      insert into public.workout_items (block_id, exercise_id, order_index)
      values (v_block_id, v_exercise_id, exercise_order)
      returning id into v_item_id;

      set_order := 0;
      for set_json in
        select value from jsonb_array_elements(exercise_json -> 'sets')
      loop
        target_reps := (set_json ->> 'target_reps')::integer;
        target_duration_seconds :=
          (set_json ->> 'target_duration_seconds')::integer;
        target_distance_meters :=
          (set_json ->> 'target_distance_meters')::numeric;

        if num_nonnulls(
          target_reps, target_duration_seconds, target_distance_meters
        ) <> 1 then
          raise exception 'Each set must contain exactly one main target';
        end if;

        insert into public.workout_sets (
          item_id, order_index, target_reps, target_duration_seconds,
          target_distance_meters, target_load_kg, target_rir,
          rest_after_seconds
        ) values (
          v_item_id, set_order, target_reps, target_duration_seconds,
          target_distance_meters,
          (set_json ->> 'target_load_kg')::numeric,
          (set_json ->> 'target_rir')::numeric,
          coalesce((set_json ->> 'rest_after_seconds')::integer, 0)
        );
        set_order := set_order + 1;
      end loop;
      exercise_order := exercise_order + 1;
    end loop;
    block_order := block_order + 1;
  end loop;

  return v_template_id;
end;
$$;

create or replace function public.start_workout_execution(p_template_id uuid)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_user_id uuid := auth.uid();
  selected_template record;
  execution_id uuid;
begin
  if current_user_id is null then
    raise exception 'Authentication required';
  end if;

  select template.id, template.name, template.version
  into selected_template
  from public.workout_templates as template
  where template.id = p_template_id
    and (
      (template.visibility = 'public' and template.status = 'published')
      or template.owner_user_id = current_user_id
      or public.is_admin()
    );

  if not found then
    raise exception 'Workout template is not accessible';
  end if;

  select execution.id into execution_id
  from public.workout_executions as execution
  where execution.user_id = current_user_id
    and execution.template_id = p_template_id
    and execution.status = 'in_progress';

  if execution_id is not null then
    return execution_id;
  end if;

  insert into public.workout_executions (
    user_id, template_id, template_name, template_version
  ) values (
    current_user_id, selected_template.id, selected_template.name,
    selected_template.version
  ) returning id into execution_id;

  insert into public.workout_execution_sets (
    execution_id, source_set_id, block_order, block_name, block_format,
    item_order, exercise_id, exercise_name, exercise_description,
    exercise_video_url, set_order, target_reps, target_duration_seconds,
    target_distance_meters, target_load_kg, target_rpe, target_rir,
    rest_after_seconds
  )
  select
    execution_id,
    prescribed_set.id,
    block.order_index,
    block.name,
    block.format,
    item.order_index,
    exercise.id,
    exercise.name,
    exercise.description,
    exercise.video_url,
    prescribed_set.order_index,
    prescribed_set.target_reps,
    prescribed_set.target_duration_seconds,
    prescribed_set.target_distance_meters,
    prescribed_set.target_load_kg,
    prescribed_set.target_rpe,
    prescribed_set.target_rir,
    case
      when block.format in ('superset', 'circuit')
        and item.order_index = (
          select max(last_item.order_index)
          from public.workout_items as last_item
          where last_item.block_id = block.id
        ) then block.rest_after_seconds
      when block.format in ('superset', 'circuit') then 0
      else prescribed_set.rest_after_seconds
    end
  from public.workout_blocks as block
  join public.workout_items as item on item.block_id = block.id
  join public.workout_sets as prescribed_set on prescribed_set.item_id = item.id
  join public.exercises as exercise on exercise.id = item.exercise_id
  where block.template_id = p_template_id;

  if not found then
    raise exception 'Workout template has no prescribed sets';
  end if;

  return execution_id;
end;
$$;

commit;
