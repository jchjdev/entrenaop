-- Permite corregir errores de registro sin perder la trazabilidad histórica.
-- Solo el propietario puede corregir una serie completada durante 24 horas y
-- cada serie admite como máximo tres correcciones.

begin;

create table public.workout_set_corrections (
  id uuid primary key default gen_random_uuid(),
  execution_set_id uuid not null
    references public.workout_execution_sets (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  reason text not null,
  previous_result jsonb not null,
  corrected_result jsonb not null,
  corrected_at timestamptz not null default now(),
  constraint workout_set_corrections_reason_length
    check (char_length(btrim(reason)) between 3 and 300)
);

create index workout_set_corrections_set_idx
  on public.workout_set_corrections (execution_set_id, corrected_at desc);

alter table public.workout_set_corrections enable row level security;

revoke all on table public.workout_set_corrections from anon, authenticated;
grant select on table public.workout_set_corrections to authenticated;

create policy workout_set_corrections_select_own
on public.workout_set_corrections
for select
to authenticated
using (user_id = (select auth.uid()) or (select public.is_admin()));

create or replace function public.correct_workout_set_result(
  p_result_id uuid,
  p_reason text,
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
  selected_result record;
  previous_values jsonb;
  corrected_values jsonb;
begin
  select result.*, execution.user_id as execution_user_id
  into selected_result
  from public.workout_execution_sets as result
  join public.workout_executions as execution
    on execution.id = result.execution_id
  where result.id = p_result_id
    and execution.user_id = auth.uid()
  for update of result;

  if not found or selected_result.status <> 'completed' then
    raise exception 'Completed workout set not found';
  end if;

  if selected_result.completed_at < now() - interval '24 hours' then
    raise exception 'Correction period has expired';
  end if;

  if (
    select count(*)
    from public.workout_set_corrections as correction
    where correction.execution_set_id = p_result_id
  ) >= 3 then
    raise exception 'Correction limit reached';
  end if;

  if char_length(btrim(coalesce(p_reason, ''))) not between 3 and 300 then
    raise exception 'A correction reason between 3 and 300 characters is required';
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

  previous_values = jsonb_build_object(
    'actual_reps', selected_result.actual_reps,
    'actual_duration_seconds', selected_result.actual_duration_seconds,
    'actual_distance_meters', selected_result.actual_distance_meters,
    'actual_load_kg', selected_result.actual_load_kg,
    'actual_rpe', selected_result.actual_rpe,
    'actual_rir', selected_result.actual_rir
  );
  corrected_values = jsonb_build_object(
    'actual_reps', p_actual_reps,
    'actual_duration_seconds', p_actual_duration_seconds,
    'actual_distance_meters', p_actual_distance_meters,
    'actual_load_kg', p_actual_load_kg,
    'actual_rpe', p_actual_rpe,
    'actual_rir', p_actual_rir
  );

  insert into public.workout_set_corrections (
    execution_set_id,
    user_id,
    reason,
    previous_result,
    corrected_result
  ) values (
    p_result_id,
    selected_result.execution_user_id,
    btrim(p_reason),
    previous_values,
    corrected_values
  );

  update public.workout_execution_sets
  set
    actual_reps = p_actual_reps,
    actual_duration_seconds = p_actual_duration_seconds,
    actual_distance_meters = p_actual_distance_meters,
    actual_load_kg = p_actual_load_kg,
    actual_rpe = p_actual_rpe,
    actual_rir = p_actual_rir
  where id = p_result_id;
end;
$$;

revoke all on function public.correct_workout_set_result(
  uuid,
  text,
  integer,
  integer,
  numeric,
  numeric,
  numeric,
  numeric
) from public, anon, authenticated;

grant execute on function public.correct_workout_set_result(
  uuid,
  text,
  integer,
  integer,
  numeric,
  numeric,
  numeric,
  numeric
) to authenticated;

commit;
