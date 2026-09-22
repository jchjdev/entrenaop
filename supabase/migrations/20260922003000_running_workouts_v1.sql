-- Carrera V1 reutiliza la jerarquía y la ejecución existentes, pero conserva
-- ritmo y recuperación como parte explícita de cada tramo versionado.

begin;

alter table public.workout_blocks
  drop constraint workout_blocks_format_check;
alter table public.workout_blocks
  add constraint workout_blocks_format_check
    check (
      format in (
        'straight_sets', 'circuit', 'superset', 'intervals', 'emom',
        'amrap', 'tabata', 'running', 'warm_up', 'cool_down'
      )
    );

alter table public.workout_sets
  add column target_pace_min_seconds_per_km integer,
  add column target_pace_max_seconds_per_km integer,
  add column recovery_type text,
  add column recovery_duration_seconds integer,
  add column recovery_distance_meters numeric,
  add constraint workout_sets_pace_pair_check check (
    (target_pace_min_seconds_per_km is null
      and target_pace_max_seconds_per_km is null)
    or (
      target_pace_min_seconds_per_km > 0
      and target_pace_max_seconds_per_km
        between target_pace_min_seconds_per_km and 3600
    )
  ),
  add constraint workout_sets_recovery_check check (
    (
      recovery_type is null
      and recovery_duration_seconds is null
      and recovery_distance_meters is null
    )
    or (
      recovery_type in ('passive', 'walking', 'jogging')
      and num_nonnulls(
        recovery_duration_seconds,
        recovery_distance_meters
      ) = 1
      and (recovery_duration_seconds is null
        or recovery_duration_seconds > 0)
      and (recovery_distance_meters is null
        or recovery_distance_meters > 0)
      and (recovery_type <> 'passive'
        or recovery_duration_seconds is not null)
    )
  );

alter table public.workout_execution_sets
  add column target_pace_min_seconds_per_km integer,
  add column target_pace_max_seconds_per_km integer,
  add column recovery_type text,
  add column recovery_duration_seconds integer,
  add column recovery_distance_meters numeric,
  add constraint workout_execution_sets_pace_pair_check check (
    (target_pace_min_seconds_per_km is null
      and target_pace_max_seconds_per_km is null)
    or (
      target_pace_min_seconds_per_km > 0
      and target_pace_max_seconds_per_km
        between target_pace_min_seconds_per_km and 3600
    )
  ),
  add constraint workout_execution_sets_recovery_check check (
    (
      recovery_type is null
      and recovery_duration_seconds is null
      and recovery_distance_meters is null
    )
    or (
      recovery_type in ('passive', 'walking', 'jogging')
      and num_nonnulls(
        recovery_duration_seconds,
        recovery_distance_meters
      ) = 1
      and (recovery_duration_seconds is null
        or recovery_duration_seconds > 0)
      and (recovery_distance_meters is null
        or recovery_distance_meters > 0)
      and (recovery_type <> 'passive'
        or recovery_duration_seconds is not null)
    )
  );

insert into public.exercises (
  id, name, description, muscle_groups, equipment, difficulty,
  exercise_type, is_public, created_by, origin
) values (
  '20000000-0000-4000-8000-000000000004',
  'Carrera',
  'Completa cada tramo con su distancia o duración, ritmo y recuperación prescritos.',
  array['cardiovascular'],
  array[]::text[],
  'inicial',
  'distancia',
  true,
  null,
  'system'
);

-- Los CHECK validan cada fila; este trigger protege además la relación entre
-- los metadatos especializados y el formato del bloque padre.
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
    if num_nonnulls(
      new.target_duration_seconds,
      new.target_distance_meters
    ) <> 1
      or new.target_reps is not null
      or new.target_load_kg is not null
      or new.target_rpe is not null
      or new.target_rir is not null
      or new.rest_after_seconds <> 0 then
      raise exception 'Running segments require one distance or duration target';
    end if;
  elsif new.target_pace_min_seconds_per_km is not null
    or new.target_pace_max_seconds_per_km is not null
    or new.recovery_type is not null
    or new.recovery_duration_seconds is not null
    or new.recovery_distance_meters is not null then
    raise exception 'Running metadata belongs only to running blocks';
  end if;
  return new;
end;
$$;

revoke all on function public.validate_running_workout_set()
from public, anon, authenticated;

create trigger validate_running_workout_set
before insert or update on public.workout_sets
for each row execute function public.validate_running_workout_set();

-- El motor de ejecución existente inserta las series base. El trigger copia
-- los campos de carrera en la misma transacción y crea la instantánea histórica.
create or replace function public.snapshot_running_execution_set()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  select
    prescribed.target_pace_min_seconds_per_km,
    prescribed.target_pace_max_seconds_per_km,
    prescribed.recovery_type,
    prescribed.recovery_duration_seconds,
    prescribed.recovery_distance_meters
  into
    new.target_pace_min_seconds_per_km,
    new.target_pace_max_seconds_per_km,
    new.recovery_type,
    new.recovery_duration_seconds,
    new.recovery_distance_meters
  from public.workout_sets as prescribed
  where prescribed.id = new.source_set_id;
  return new;
end;
$$;

revoke all on function public.snapshot_running_execution_set()
from public, anon, authenticated;

create trigger snapshot_running_execution_set
before insert on public.workout_execution_sets
for each row execute function public.snapshot_running_execution_set();

-- Conservamos intacto el creador de fuerza y añadimos un despachador común.
alter function public.create_personal_workout_template(jsonb)
  rename to create_personal_strength_workout_template;

revoke all on function public.create_personal_strength_workout_template(jsonb)
from public, anon, authenticated;

create function public.create_personal_running_workout_template(
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

    if num_nonnulls(target_duration, target_distance) <> 1 then
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
      recovery_type, recovery_duration_seconds, recovery_distance_meters
    ) values (
      v_item_id, segment_order, target_duration, target_distance, 0,
      pace_min, pace_max, recovery_mode, recovery_duration,
      recovery_distance
    );
    segment_order := segment_order + 1;
  end loop;

  return v_template_id;
end;
$$;

revoke all on function public.create_personal_running_workout_template(jsonb)
from public, anon, authenticated;

create function public.create_personal_workout_template(p_payload jsonb)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
begin
  if p_payload -> 'blocks' -> 0 ->> 'format' = 'running' then
    return public.create_personal_running_workout_template(p_payload);
  end if;
  return public.create_personal_strength_workout_template(p_payload);
end;
$$;

revoke all on function public.create_personal_workout_template(jsonb)
from public, anon;
grant execute on function public.create_personal_workout_template(jsonb)
to authenticated;

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
        recovery_duration_seconds, recovery_distance_meters
      )
      select
        v_item_id, prescribed.order_index, prescribed.target_reps,
        prescribed.target_duration_seconds, prescribed.target_distance_meters,
        prescribed.target_load_kg, prescribed.target_rpe,
        prescribed.target_rir, prescribed.rest_after_seconds,
        prescribed.target_pace_min_seconds_per_km,
        prescribed.target_pace_max_seconds_per_km,
        prescribed.recovery_type, prescribed.recovery_duration_seconds,
        prescribed.recovery_distance_meters
      from public.workout_sets as prescribed
      where prescribed.item_id = source_item.id
      order by prescribed.order_index;
    end loop;
  end loop;
  return v_template_id;
end;
$$;

revoke all on function public.duplicate_personal_workout_template(uuid)
from public, anon;
grant execute on function public.duplicate_personal_workout_template(uuid)
to authenticated;

create or replace function public.complete_workout_set(
  p_result_id uuid,
  p_actual_reps integer default null,
  p_actual_duration_seconds integer default null,
  p_actual_distance_meters numeric default null,
  p_actual_load_kg numeric default null,
  p_actual_rpe numeric default null,
  p_actual_rir numeric default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  prescribed_result record;
begin
  select
    result.block_format,
    result.target_reps,
    result.target_duration_seconds,
    result.target_distance_meters
  into prescribed_result
  from public.workout_execution_sets as result
  join public.workout_executions as execution
    on execution.id = result.execution_id
  where result.id = p_result_id
    and execution.user_id = auth.uid()
    and execution.status = 'in_progress'
    and result.status = 'pending';

  if not found then
    raise exception 'Pending workout set not found';
  end if;
  if prescribed_result.target_reps is not null
    and p_actual_reps is null then
    raise exception 'Actual repetitions are required';
  end if;
  if prescribed_result.target_duration_seconds is not null
    and p_actual_duration_seconds is null then
    raise exception 'Actual duration is required';
  end if;
  if prescribed_result.target_distance_meters is not null
    and p_actual_distance_meters is null then
    raise exception 'Actual distance is required';
  end if;
  if prescribed_result.block_format = 'running'
    and (p_actual_duration_seconds is null
      or p_actual_distance_meters is null) then
    raise exception 'Running results require actual duration and distance';
  end if;

  update public.workout_execution_sets as result
  set
    status = 'completed',
    actual_reps = p_actual_reps,
    actual_duration_seconds = p_actual_duration_seconds,
    actual_distance_meters = p_actual_distance_meters,
    actual_load_kg = p_actual_load_kg,
    actual_rpe = p_actual_rpe,
    actual_rir = p_actual_rir,
    completed_at = now()
  where result.id = p_result_id and result.status = 'pending';
  if not found then
    raise exception 'Pending workout set not found';
  end if;
end;
$$;

revoke all on function public.complete_workout_set(
  uuid, integer, integer, numeric, numeric, numeric, numeric
) from public, anon, authenticated;
grant execute on function public.complete_workout_set(
  uuid, integer, integer, numeric, numeric, numeric, numeric
) to authenticated;

commit;
