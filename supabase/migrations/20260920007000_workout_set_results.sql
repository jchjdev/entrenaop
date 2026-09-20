-- Registra resultados reales y permite omitir una serie de forma explicita.
-- La base de datos valida la metrica principal prescrita para que la seguridad
-- y la integridad no dependan exclusivamente del formulario de Flutter.

begin;

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
  where result.id = p_result_id
    and result.status = 'pending';

  if not found then
    raise exception 'Pending workout set not found';
  end if;
end;
$$;

create or replace function public.skip_workout_set(p_result_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.workout_execution_sets as result
  set
    status = 'skipped',
    completed_at = now()
  from public.workout_executions as execution
  where result.id = p_result_id
    and execution.id = result.execution_id
    and execution.user_id = auth.uid()
    and execution.status = 'in_progress'
    and result.status = 'pending';

  if not found then
    raise exception 'Pending workout set not found';
  end if;
end;
$$;

revoke all on function public.complete_workout_set(
  uuid,
  integer,
  integer,
  numeric,
  numeric,
  numeric,
  numeric
)
from public, anon, authenticated;
revoke all on function public.skip_workout_set(uuid)
from public, anon, authenticated;

grant execute on function public.complete_workout_set(
  uuid,
  integer,
  integer,
  numeric,
  numeric,
  numeric,
  numeric
)
to authenticated;
grant execute on function public.skip_workout_set(uuid)
to authenticated;

commit;
