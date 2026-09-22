-- Conserva las validaciones generales del corrector al ampliarlo con los
-- resultados específicos de recuperación de carrera.

begin;

create or replace function public.correct_workout_set_result(
  p_result_id uuid,
  p_reason text,
  p_actual_reps integer default null,
  p_actual_duration_seconds integer default null,
  p_actual_distance_meters numeric default null,
  p_actual_load_kg numeric default null,
  p_actual_rpe numeric default null,
  p_actual_rir numeric default null,
  p_actual_recovery_duration_seconds integer default null,
  p_actual_recovery_distance_meters numeric default null,
  p_result_source text default 'manual'
)
returns void language plpgsql security definer set search_path = '' as $$
declare
  selected_result record;
  previous_values jsonb;
  corrected_values jsonb;
begin
  select result.*, execution.user_id as execution_user_id
  into selected_result
  from public.workout_execution_sets as result
  join public.workout_executions as execution on execution.id = result.execution_id
  where result.id = p_result_id and execution.user_id = auth.uid()
  for update of result;

  if not found or selected_result.status <> 'completed' then
    raise exception 'Completed workout set not found';
  end if;
  if selected_result.completed_at < now() - interval '24 hours' then
    raise exception 'Correction period has expired';
  end if;
  if (select count(*) from public.workout_set_corrections
      where execution_set_id = p_result_id) >= 3 then
    raise exception 'Correction limit reached';
  end if;
  if char_length(btrim(coalesce(p_reason, ''))) not between 3 and 300 then
    raise exception 'A correction reason between 3 and 300 characters is required';
  end if;
  if p_result_source not in ('manual', 'device') then
    raise exception 'Workout result source is invalid';
  end if;
  if selected_result.target_reps is not null and p_actual_reps is null then
    raise exception 'Actual repetitions are required';
  end if;
  if selected_result.target_duration_seconds is not null
    and p_actual_duration_seconds is null then
    raise exception 'Actual duration is required';
  end if;
  if selected_result.target_distance_meters is not null
    and p_actual_distance_meters is null then
    raise exception 'Actual distance is required';
  end if;
  if selected_result.block_format = 'running' then
    if p_actual_duration_seconds is null or p_actual_distance_meters is null then
      raise exception 'Running results require actual duration and distance';
    end if;
    if selected_result.recovery_duration_seconds is not null
      and p_actual_recovery_duration_seconds is null then
      raise exception 'Actual recovery duration is required';
    end if;
    if selected_result.recovery_distance_meters is not null
      and p_actual_recovery_distance_meters is null then
      raise exception 'Actual recovery distance is required';
    end if;
  elsif p_actual_recovery_duration_seconds is not null
    or p_actual_recovery_distance_meters is not null then
    raise exception 'Recovery results belong only to running segments';
  end if;

  previous_values = jsonb_build_object(
    'actual_reps', selected_result.actual_reps,
    'actual_duration_seconds', selected_result.actual_duration_seconds,
    'actual_distance_meters', selected_result.actual_distance_meters,
    'actual_load_kg', selected_result.actual_load_kg,
    'actual_rpe', selected_result.actual_rpe,
    'actual_rir', selected_result.actual_rir,
    'actual_recovery_duration_seconds',
      selected_result.actual_recovery_duration_seconds,
    'actual_recovery_distance_meters',
      selected_result.actual_recovery_distance_meters,
    'result_source', selected_result.result_source
  );
  corrected_values = jsonb_build_object(
    'actual_reps', p_actual_reps,
    'actual_duration_seconds', p_actual_duration_seconds,
    'actual_distance_meters', p_actual_distance_meters,
    'actual_load_kg', p_actual_load_kg,
    'actual_rpe', p_actual_rpe,
    'actual_rir', p_actual_rir,
    'actual_recovery_duration_seconds', p_actual_recovery_duration_seconds,
    'actual_recovery_distance_meters', p_actual_recovery_distance_meters,
    'result_source', p_result_source
  );
  insert into public.workout_set_corrections (
    execution_set_id, user_id, reason, previous_result, corrected_result
  ) values (
    p_result_id, selected_result.execution_user_id, btrim(p_reason),
    previous_values, corrected_values
  );
  update public.workout_execution_sets set
    actual_reps = p_actual_reps,
    actual_duration_seconds = p_actual_duration_seconds,
    actual_distance_meters = p_actual_distance_meters,
    actual_load_kg = p_actual_load_kg,
    actual_rpe = p_actual_rpe,
    actual_rir = p_actual_rir,
    actual_recovery_duration_seconds = p_actual_recovery_duration_seconds,
    actual_recovery_distance_meters = p_actual_recovery_distance_meters,
    result_source = p_result_source
  where id = p_result_id;
end;
$$;

commit;
