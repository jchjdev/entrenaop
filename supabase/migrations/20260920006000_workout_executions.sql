-- Ejecuciones inmutables de una plantilla y resultados de cada serie.
-- Las prescripciones se copian al comenzar para que una edición futura de la
-- plantilla nunca reinterprete lo que el usuario entrenó.

begin;

create table public.workout_executions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  template_id uuid not null
    references public.workout_templates (id) on delete restrict,
  template_name text not null,
  template_version integer not null,
  status text not null default 'in_progress',
  started_at timestamptz not null default now(),
  completed_at timestamptz,
  final_rpe integer,
  notes text,
  constraint workout_executions_status_check
    check (status in ('in_progress', 'completed', 'abandoned')),
  constraint workout_executions_completion_check
    check (
      (status = 'in_progress' and completed_at is null)
      or (status <> 'in_progress' and completed_at is not null)
    ),
  constraint workout_executions_rpe_range
    check (final_rpe is null or final_rpe between 1 and 10)
);

create unique index workout_executions_one_active_template_idx
on public.workout_executions (user_id, template_id)
where status = 'in_progress';

create index workout_executions_user_started_idx
on public.workout_executions (user_id, started_at desc);

create table public.workout_execution_sets (
  id uuid primary key default gen_random_uuid(),
  execution_id uuid not null
    references public.workout_executions (id) on delete cascade,
  source_set_id uuid not null
    references public.workout_sets (id) on delete restrict,
  block_order integer not null,
  block_name text not null,
  item_order integer not null,
  exercise_id uuid not null
    references public.exercises (id) on delete restrict,
  exercise_name text not null,
  set_order integer not null,
  target_reps integer,
  target_duration_seconds integer,
  target_distance_meters numeric,
  target_load_kg numeric,
  target_rpe numeric,
  target_rir numeric,
  rest_after_seconds integer not null,
  status text not null default 'pending',
  actual_reps integer,
  actual_duration_seconds integer,
  actual_distance_meters numeric,
  actual_load_kg numeric,
  actual_rpe numeric,
  actual_rir numeric,
  completed_at timestamptz,
  constraint workout_execution_sets_position_nonnegative
    check (block_order >= 0 and item_order >= 0 and set_order >= 0),
  constraint workout_execution_sets_rest_nonnegative
    check (rest_after_seconds >= 0),
  constraint workout_execution_sets_status_check
    check (status in ('pending', 'completed', 'skipped')),
  constraint workout_execution_sets_completion_check
    check (
      (status = 'pending' and completed_at is null)
      or (status <> 'pending' and completed_at is not null)
    ),
  constraint workout_execution_sets_actual_reps_nonnegative
    check (actual_reps is null or actual_reps >= 0),
  constraint workout_execution_sets_actual_duration_nonnegative
    check (actual_duration_seconds is null or actual_duration_seconds >= 0),
  constraint workout_execution_sets_actual_distance_nonnegative
    check (actual_distance_meters is null or actual_distance_meters >= 0),
  constraint workout_execution_sets_actual_load_nonnegative
    check (actual_load_kg is null or actual_load_kg >= 0),
  constraint workout_execution_sets_actual_rpe_range
    check (actual_rpe is null or actual_rpe between 1 and 10),
  constraint workout_execution_sets_actual_rir_range
    check (actual_rir is null or actual_rir between 0 and 10),
  constraint workout_execution_sets_source_unique
    unique (execution_id, source_set_id),
  constraint workout_execution_sets_position_unique
    unique (execution_id, block_order, item_order, set_order)
);

create index workout_execution_sets_execution_idx
on public.workout_execution_sets (
  execution_id,
  block_order,
  item_order,
  set_order
);

alter table public.workout_executions enable row level security;
alter table public.workout_execution_sets enable row level security;

revoke all on table public.workout_executions from anon, authenticated;
revoke all on table public.workout_execution_sets from anon, authenticated;
grant select on table public.workout_executions to authenticated;
grant select on table public.workout_execution_sets to authenticated;

create policy workout_executions_select_own
on public.workout_executions
for select
to authenticated
using (user_id = (select auth.uid()) or (select public.is_admin()));

create policy workout_execution_sets_select_own
on public.workout_execution_sets
for select
to authenticated
using (
  exists (
    select 1
    from public.workout_executions as execution
    where execution.id = workout_execution_sets.execution_id
      and (
        execution.user_id = (select auth.uid())
        or (select public.is_admin())
      )
  )
);

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

  select execution.id
  into execution_id
  from public.workout_executions as execution
  where execution.user_id = current_user_id
    and execution.template_id = p_template_id
    and execution.status = 'in_progress';

  if execution_id is not null then
    return execution_id;
  end if;

  insert into public.workout_executions (
    user_id,
    template_id,
    template_name,
    template_version
  )
  values (
    current_user_id,
    selected_template.id,
    selected_template.name,
    selected_template.version
  )
  returning id into execution_id;

  insert into public.workout_execution_sets (
    execution_id,
    source_set_id,
    block_order,
    block_name,
    item_order,
    exercise_id,
    exercise_name,
    set_order,
    target_reps,
    target_duration_seconds,
    target_distance_meters,
    target_load_kg,
    target_rpe,
    target_rir,
    rest_after_seconds
  )
  select
    execution_id,
    prescribed_set.id,
    block.order_index,
    block.name,
    item.order_index,
    exercise.id,
    exercise.name,
    prescribed_set.order_index,
    prescribed_set.target_reps,
    prescribed_set.target_duration_seconds,
    prescribed_set.target_distance_meters,
    prescribed_set.target_load_kg,
    prescribed_set.target_rpe,
    prescribed_set.target_rir,
    prescribed_set.rest_after_seconds
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
begin
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

create or replace function public.finish_workout_execution(
  p_execution_id uuid,
  p_final_rpe integer,
  p_notes text default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if p_final_rpe not between 1 and 10 then
    raise exception 'Final RPE must be between 1 and 10';
  end if;

  if exists (
    select 1
    from public.workout_execution_sets as result
    where result.execution_id = p_execution_id
      and result.status = 'pending'
  ) then
    raise exception 'Workout execution still has pending sets';
  end if;

  update public.workout_executions as execution
  set
    status = 'completed',
    completed_at = now(),
    final_rpe = p_final_rpe,
    notes = nullif(btrim(p_notes), '')
  where execution.id = p_execution_id
    and execution.user_id = auth.uid()
    and execution.status = 'in_progress';

  if not found then
    raise exception 'Active workout execution not found';
  end if;
end;
$$;

revoke all on function public.start_workout_execution(uuid)
from public, anon, authenticated;
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
revoke all on function public.finish_workout_execution(uuid, integer, text)
from public, anon, authenticated;

grant execute on function public.start_workout_execution(uuid)
to authenticated;
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
grant execute on function public.finish_workout_execution(uuid, integer, text)
to authenticated;

commit;
