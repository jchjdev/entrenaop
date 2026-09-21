-- Cada posición de un bloque es una estación independiente. Un mismo
-- ejercicio puede aparecer varias veces con objetivos distintos.

begin;

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
  block_time_cap_seconds integer;
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
    block_time_cap_seconds :=
      (block_json ->> 'time_cap_seconds')::integer;

    if char_length(block_name) not between 1 and 60 then
      raise exception 'Block name must contain between 1 and 60 characters';
    end if;
    if block_format not in (
      'straight_sets', 'superset', 'circuit', 'intervals', 'tabata', 'emom',
      'amrap'
    ) then
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
    if block_format = 'tabata'
      and (block_rounds <> 8 or block_rest_seconds <> 10) then
      raise exception 'Tabata requires 8 rounds and 10 seconds of recovery';
    end if;
    if block_format = 'emom' and block_rest_seconds <> 60 then
      raise exception 'Each EMOM station must occupy exactly one minute';
    end if;
    if block_format = 'amrap' and (
      block_rounds <> 1 or block_rest_seconds <> 0
      or block_time_cap_seconds not between 60 and 3600
    ) then
      raise exception 'AMRAP requires a time cap between one and sixty minutes';
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
    if block_format in ('intervals', 'tabata')
      and block_exercise_count <> 1 then
      raise exception 'Intervals and Tabata require exactly one exercise';
    end if;
    if block_format = 'emom'
      and block_rounds * block_exercise_count > 60 then
      raise exception 'An EMOM block cannot exceed sixty minutes';
    end if;

    total_exercises := total_exercises + block_exercise_count;
    if total_exercises > 40 then
      raise exception 'Workout cannot contain more than 40 exercises';
    end if;

    insert into public.workout_blocks (
      template_id, order_index, name, format, rounds, time_cap_seconds,
      rest_after_seconds
    ) values (
      v_template_id, block_order, block_name, block_format, block_rounds,
      case
        when block_format = 'emom'
          then block_rounds * block_exercise_count * 60
        when block_format = 'amrap' then block_time_cap_seconds
        else null
      end,
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
      if coalesce(jsonb_typeof(exercise_json -> 'sets'), 'null') <> 'array'
        or jsonb_array_length(exercise_json -> 'sets') not between 1 and 20 then
        raise exception 'Exercise must contain between 1 and 20 sets';
      end if;
      if block_format in ('superset', 'circuit', 'intervals', 'tabata', 'emom')
        and jsonb_array_length(exercise_json -> 'sets') <> block_rounds then
        raise exception 'Round-based exercises require one set per round';
      end if;
      if block_format = 'amrap'
        and jsonb_array_length(exercise_json -> 'sets') <> 1 then
        raise exception 'Each AMRAP exercise requires one target';
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
        if block_format = 'amrap'
          and (target_reps is null or target_duration_seconds is not null
            or target_distance_meters is not null) then
          raise exception 'AMRAP exercises require a repetition target';
        end if;
        if block_format = 'tabata'
          and (
            target_duration_seconds is distinct from 20
            or target_reps is not null
            or target_distance_meters is not null
          ) then
          raise exception 'Each Tabata work interval must last 20 seconds';
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

commit;
