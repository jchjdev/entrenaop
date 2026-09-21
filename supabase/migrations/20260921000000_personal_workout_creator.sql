-- Creación atómica de sesiones privadas convencionales.
-- Flutter envía el borrador completo, pero PostgreSQL vuelve a validar los
-- límites y la accesibilidad de cada ejercicio antes de guardar nada.

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
  exercise_json jsonb;
  set_json jsonb;
  v_exercise_id uuid;
  v_item_id uuid;
  exercise_order integer := 0;
  set_order integer;
  workout_name text := btrim(coalesce(p_payload ->> 'name', ''));
  workout_description text := nullif(btrim(p_payload ->> 'description'), '');
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

  if coalesce(jsonb_typeof(p_payload -> 'exercises'), 'null') <> 'array'
    or jsonb_array_length(p_payload -> 'exercises') not between 1 and 20 then
    raise exception 'Workout must contain between 1 and 20 exercises';
  end if;

  insert into public.workout_templates (
    name,
    description,
    origin,
    owner_user_id,
    visibility,
    status,
    estimated_duration_minutes
  )
  values (
    workout_name,
    workout_description,
    'user',
    current_user_id,
    'private',
    'published',
    duration_minutes
  )
  returning id into v_template_id;

  insert into public.workout_blocks (
    template_id,
    order_index,
    name,
    format,
    rounds,
    rest_after_seconds
  )
  values (v_template_id, 0, 'Sesión', 'straight_sets', 1, 0)
  returning id into v_block_id;

  for exercise_json in
    select value from jsonb_array_elements(p_payload -> 'exercises')
  loop
    v_exercise_id := (exercise_json ->> 'exercise_id')::uuid;

    if not exists (
      select 1
      from public.exercises as exercise
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
      select 1
      from public.workout_items as existing_item
      where existing_item.block_id = v_block_id
        and existing_item.exercise_id = v_exercise_id
    ) then
      raise exception 'An exercise cannot be repeated in the same workout';
    end if;

    if coalesce(jsonb_typeof(exercise_json -> 'sets'), 'null') <> 'array'
      or jsonb_array_length(exercise_json -> 'sets') not between 1 and 20 then
      raise exception 'Exercise must contain between 1 and 20 sets';
    end if;

    insert into public.workout_items (
      block_id,
      exercise_id,
      order_index
    )
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
        target_reps,
        target_duration_seconds,
        target_distance_meters
      ) <> 1 then
        raise exception 'Each set must contain exactly one main target';
      end if;

      insert into public.workout_sets (
        item_id,
        order_index,
        target_reps,
        target_duration_seconds,
        target_distance_meters,
        target_load_kg,
        target_rir,
        rest_after_seconds
      )
      values (
        v_item_id,
        set_order,
        target_reps,
        target_duration_seconds,
        target_distance_meters,
        (set_json ->> 'target_load_kg')::numeric,
        (set_json ->> 'target_rir')::numeric,
        coalesce((set_json ->> 'rest_after_seconds')::integer, 0)
      );
      set_order := set_order + 1;
    end loop;

    exercise_order := exercise_order + 1;
  end loop;

  return v_template_id;
end;
$$;

revoke all on function public.create_personal_workout_template(jsonb)
from public, anon;
grant execute on function public.create_personal_workout_template(jsonb)
to authenticated;

commit;
