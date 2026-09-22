-- El registro manual de carrera conserva cada parcial y recuperación, además
-- del RPE global y la frecuencia cardíaca opcional de la sesión.

begin;

alter table public.workout_execution_sets
  add column actual_recovery_duration_seconds integer,
  add column actual_recovery_distance_meters numeric,
  add column result_source text;

update public.workout_execution_sets
set result_source = 'manual'
where status = 'completed';

alter table public.workout_execution_sets
  add constraint workout_execution_sets_actual_recovery_check check (
    (actual_recovery_duration_seconds is null
      or actual_recovery_duration_seconds > 0)
    and (actual_recovery_distance_meters is null
      or actual_recovery_distance_meters > 0)
  ),
  add constraint workout_execution_sets_result_source_check check (
    result_source is null or result_source in ('manual', 'device')
  ),
  add constraint workout_execution_sets_completed_source_check check (
    status <> 'completed' or result_source is not null
  );

alter table public.workout_executions
  add column average_heart_rate_bpm integer,
  add column max_heart_rate_bpm integer,
  add column result_source text;

update public.workout_executions
set result_source = 'manual'
where status = 'completed';

alter table public.workout_executions
  add constraint workout_executions_heart_rate_check check (
    (average_heart_rate_bpm is null
      or average_heart_rate_bpm between 30 and 250)
    and (max_heart_rate_bpm is null or max_heart_rate_bpm between 30 and 250)
    and (average_heart_rate_bpm is null or max_heart_rate_bpm is null
      or max_heart_rate_bpm >= average_heart_rate_bpm)
  ),
  add constraint workout_executions_result_source_check check (
    result_source is null or result_source in ('manual', 'device')
  );

drop function public.complete_workout_set_idempotent(
  uuid, uuid, integer, integer, numeric, numeric, numeric, numeric
);
drop function public.complete_workout_set(
  uuid, integer, integer, numeric, numeric, numeric, numeric
);

create function public.complete_workout_set(
  p_result_id uuid,
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
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  prescribed_result record;
begin
  select result.* into prescribed_result
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
  if p_result_source not in ('manual', 'device') then
    raise exception 'Workout result source is invalid';
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
  if prescribed_result.block_format = 'running' then
    if p_actual_duration_seconds is null or p_actual_distance_meters is null then
      raise exception 'Running results require actual duration and distance';
    end if;
    if prescribed_result.recovery_duration_seconds is not null
      and p_actual_recovery_duration_seconds is null then
      raise exception 'Actual recovery duration is required';
    end if;
    if prescribed_result.recovery_distance_meters is not null
      and p_actual_recovery_distance_meters is null then
      raise exception 'Actual recovery distance is required';
    end if;
  elsif p_actual_recovery_duration_seconds is not null
    or p_actual_recovery_distance_meters is not null then
    raise exception 'Recovery results belong only to running segments';
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
    actual_recovery_duration_seconds = p_actual_recovery_duration_seconds,
    actual_recovery_distance_meters = p_actual_recovery_distance_meters,
    result_source = p_result_source,
    completed_at = now()
  where result.id = p_result_id and result.status = 'pending';
end;
$$;

create function public.complete_workout_set_idempotent(
  p_operation_id uuid,
  p_result_id uuid,
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
begin
  if exists (
    select 1 from public.workout_mutation_receipts
    where id = p_operation_id and user_id = auth.uid()
      and mutation_kind = 'complete_set' and resource_id = p_result_id
  ) then return; end if;
  perform public.complete_workout_set(
    p_result_id, p_actual_reps, p_actual_duration_seconds,
    p_actual_distance_meters, p_actual_load_kg, p_actual_rpe, p_actual_rir,
    p_actual_recovery_duration_seconds, p_actual_recovery_distance_meters,
    p_result_source
  );
  insert into public.workout_mutation_receipts
    (id, user_id, mutation_kind, resource_id)
  values (p_operation_id, auth.uid(), 'complete_set', p_result_id);
end;
$$;

drop function public.correct_workout_set_result(
  uuid, text, integer, integer, numeric, numeric, numeric, numeric
);

create function public.correct_workout_set_result(
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

drop function public.finish_workout_execution_idempotent(
  uuid, uuid, integer, text
);
drop function public.finish_workout_execution(uuid, integer, text);

create function public.finish_workout_execution(
  p_execution_id uuid,
  p_final_rpe integer,
  p_notes text default null,
  p_average_heart_rate_bpm integer default null,
  p_max_heart_rate_bpm integer default null,
  p_result_source text default 'manual'
)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if p_final_rpe not between 1 and 10 then
    raise exception 'Final RPE must be between 1 and 10';
  end if;
  if p_result_source not in ('manual', 'device') then
    raise exception 'Workout result source is invalid';
  end if;
  if (p_average_heart_rate_bpm is not null
      and p_average_heart_rate_bpm not between 30 and 250)
    or (p_max_heart_rate_bpm is not null
      and p_max_heart_rate_bpm not between 30 and 250)
    or (p_average_heart_rate_bpm is not null
      and p_max_heart_rate_bpm is not null
      and p_max_heart_rate_bpm < p_average_heart_rate_bpm) then
    raise exception 'Heart rate values are invalid';
  end if;
  if exists (
    select 1 from public.workout_execution_sets
    where execution_id = p_execution_id and status = 'pending'
  ) then
    raise exception 'Workout execution still has pending sets';
  end if;
  update public.workout_executions set
    status = 'completed',
    completed_at = now(),
    final_rpe = p_final_rpe,
    notes = nullif(btrim(p_notes), ''),
    average_heart_rate_bpm = p_average_heart_rate_bpm,
    max_heart_rate_bpm = p_max_heart_rate_bpm,
    result_source = p_result_source
  where id = p_execution_id and user_id = auth.uid()
    and status = 'in_progress';
  if not found then raise exception 'Active workout execution not found'; end if;
end;
$$;

create function public.finish_workout_execution_idempotent(
  p_operation_id uuid,
  p_execution_id uuid,
  p_final_rpe integer,
  p_notes text default null,
  p_average_heart_rate_bpm integer default null,
  p_max_heart_rate_bpm integer default null,
  p_result_source text default 'manual'
)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if exists (
    select 1 from public.workout_mutation_receipts
    where id = p_operation_id and user_id = auth.uid()
      and mutation_kind = 'finish' and resource_id = p_execution_id
  ) then return; end if;
  perform public.finish_workout_execution(
    p_execution_id, p_final_rpe, p_notes, p_average_heart_rate_bpm,
    p_max_heart_rate_bpm, p_result_source
  );
  insert into public.workout_mutation_receipts
    (id, user_id, mutation_kind, resource_id)
  values (p_operation_id, auth.uid(), 'finish', p_execution_id);
end;
$$;

revoke all on function public.complete_workout_set(
  uuid, integer, integer, numeric, numeric, numeric, numeric, integer, numeric,
  text
) from public, anon, authenticated;
revoke all on function public.complete_workout_set_idempotent(
  uuid, uuid, integer, integer, numeric, numeric, numeric, numeric, integer,
  numeric, text
) from public, anon, authenticated;
revoke all on function public.correct_workout_set_result(
  uuid, text, integer, integer, numeric, numeric, numeric, numeric, integer,
  numeric, text
) from public, anon, authenticated;
revoke all on function public.finish_workout_execution(
  uuid, integer, text, integer, integer, text
) from public, anon, authenticated;
revoke all on function public.finish_workout_execution_idempotent(
  uuid, uuid, integer, text, integer, integer, text
) from public, anon, authenticated;

grant execute on function public.complete_workout_set(
  uuid, integer, integer, numeric, numeric, numeric, numeric, integer, numeric,
  text
) to authenticated;
grant execute on function public.complete_workout_set_idempotent(
  uuid, uuid, integer, integer, numeric, numeric, numeric, numeric, integer,
  numeric, text
) to authenticated;
grant execute on function public.correct_workout_set_result(
  uuid, text, integer, integer, numeric, numeric, numeric, numeric, integer,
  numeric, text
) to authenticated;
grant execute on function public.finish_workout_execution(
  uuid, integer, text, integer, integer, text
) to authenticated;
grant execute on function public.finish_workout_execution_idempotent(
  uuid, uuid, integer, text, integer, integer, text
) to authenticated;

commit;
