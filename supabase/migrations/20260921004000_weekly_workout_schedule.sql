-- Agenda semanal global del usuario. Cada entrada fija una versión concreta de
-- sesión y puede proceder de la biblioteca, del usuario o de una prescripción.

begin;

create table public.scheduled_workouts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  template_id uuid not null
    references public.workout_templates (id) on delete restrict,
  -- Conservamos la etiqueta visible de la versión programada. Así, un cambio
  -- posterior en la biblioteca no reescribe retrospectivamente la agenda.
  template_name text not null,
  template_version integer not null,
  estimated_duration_minutes integer,
  preparation_goal_id uuid
    references public.preparation_goals (id) on delete set null,
  execution_id uuid unique
    references public.workout_executions (id) on delete set null,
  scheduled_date date not null,
  scheduled_time time,
  order_index integer not null default 0,
  source text not null,
  status text not null default 'planned',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint scheduled_workouts_source_check
    check (source in ('library', 'user', 'preparation', 'algorithm', 'coach')),
  constraint scheduled_workouts_status_check
    check (
      status in (
        'planned',
        'in_progress',
        'completed',
        'abandoned',
        'skipped',
        'cancelled'
      )
    ),
  constraint scheduled_workouts_order_nonnegative check (order_index >= 0),
  constraint scheduled_workouts_template_version_positive
    check (template_version > 0),
  constraint scheduled_workouts_duration_positive
    check (
      estimated_duration_minutes is null
      or estimated_duration_minutes > 0
    ),
  constraint scheduled_workouts_execution_consistency
    check (
      (status in ('planned', 'skipped', 'cancelled') and execution_id is null)
      or (status in ('in_progress', 'completed', 'abandoned') and execution_id is not null)
    )
);

create index scheduled_workouts_user_date_idx
  on public.scheduled_workouts (user_id, scheduled_date, scheduled_time, order_index);
create index scheduled_workouts_template_idx
  on public.scheduled_workouts (template_id);

alter table public.scheduled_workouts enable row level security;
revoke all on table public.scheduled_workouts from anon, authenticated;
grant select on table public.scheduled_workouts to authenticated;

create policy scheduled_workouts_select_own
on public.scheduled_workouts
for select
to authenticated
using (user_id = (select auth.uid()) or (select public.is_admin()));

create or replace function public.set_scheduled_workout_updated_at()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

revoke all on function public.set_scheduled_workout_updated_at()
from public, anon, authenticated;

create trigger set_scheduled_workout_updated_at
before update on public.scheduled_workouts
for each row execute function public.set_scheduled_workout_updated_at();

create or replace function public.schedule_workout(
  p_template_id uuid,
  p_scheduled_date date,
  p_scheduled_time time default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_user_id uuid := auth.uid();
  selected_template record;
  scheduled_id uuid;
  schedule_source text;
begin
  if current_user_id is null then
    raise exception 'Authentication required';
  end if;

  if p_scheduled_date < current_date then
    raise exception 'A workout cannot be scheduled in the past';
  end if;

  select
    template.id,
    template.name,
    template.version,
    template.estimated_duration_minutes,
    template.origin,
    template.visibility,
    template.status
  into selected_template
  from public.workout_templates as template
  where template.id = p_template_id
    and (
      (template.visibility = 'public' and template.status = 'published')
      or (
        template.owner_user_id = current_user_id
        and template.status <> 'archived'
      )
      or public.is_admin()
    );

  if not found then
    raise exception 'Workout template is not accessible';
  end if;

  schedule_source := case selected_template.origin
    when 'system' then 'library'
    when 'user' then 'user'
    when 'coach' then 'coach'
    when 'algorithm' then 'algorithm'
    else 'preparation'
  end;

  insert into public.scheduled_workouts (
    user_id,
    template_id,
    template_name,
    template_version,
    estimated_duration_minutes,
    scheduled_date,
    scheduled_time,
    source
  )
  values (
    current_user_id,
    selected_template.id,
    selected_template.name,
    selected_template.version,
    selected_template.estimated_duration_minutes,
    p_scheduled_date,
    p_scheduled_time,
    schedule_source
  )
  returning id into scheduled_id;

  return scheduled_id;
end;
$$;

create or replace function public.reschedule_workout(
  p_scheduled_id uuid,
  p_scheduled_date date,
  p_scheduled_time time default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;
  if p_scheduled_date < current_date then
    raise exception 'A workout cannot be scheduled in the past';
  end if;

  update public.scheduled_workouts as scheduled
  set
    scheduled_date = p_scheduled_date,
    scheduled_time = p_scheduled_time
  where scheduled.id = p_scheduled_id
    and scheduled.user_id = auth.uid()
    and scheduled.status = 'planned';

  if not found then
    raise exception 'Planned workout is not accessible';
  end if;
end;
$$;

create or replace function public.cancel_scheduled_workout(
  p_scheduled_id uuid
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  update public.scheduled_workouts as scheduled
  set status = 'cancelled'
  where scheduled.id = p_scheduled_id
    and scheduled.user_id = auth.uid()
    and scheduled.status = 'planned';

  if not found then
    raise exception 'Planned workout is not accessible';
  end if;
end;
$$;

create or replace function public.start_scheduled_workout(
  p_scheduled_id uuid
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  selected_schedule record;
  v_execution_id uuid;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  select scheduled.*
  into selected_schedule
  from public.scheduled_workouts as scheduled
  where scheduled.id = p_scheduled_id
    and scheduled.user_id = auth.uid()
    and scheduled.status in ('planned', 'in_progress')
  for update;

  if not found then
    raise exception 'Scheduled workout is not accessible';
  end if;

  if selected_schedule.execution_id is not null then
    return selected_schedule.execution_id;
  end if;

  v_execution_id := public.start_workout_execution(
    selected_schedule.template_id
  );

  if exists (
    select 1
    from public.scheduled_workouts as other_schedule
    where other_schedule.execution_id = v_execution_id
      and other_schedule.id <> selected_schedule.id
  ) then
    raise exception 'This workout already has another scheduled execution in progress';
  end if;

  update public.scheduled_workouts as scheduled
  set
    execution_id = v_execution_id,
    status = 'in_progress'
  where scheduled.id = selected_schedule.id;

  return v_execution_id;
end;
$$;

create or replace function public.sync_scheduled_workout_status()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.scheduled_workouts as scheduled
  set status = case new.status
    when 'in_progress' then 'in_progress'
    when 'completed' then 'completed'
    when 'abandoned' then 'abandoned'
  end
  where scheduled.execution_id = new.id;
  return new;
end;
$$;

revoke all on function public.sync_scheduled_workout_status()
from public, anon, authenticated;

create trigger sync_scheduled_workout_status
after update of status on public.workout_executions
for each row execute function public.sync_scheduled_workout_status();

revoke all on function public.schedule_workout(uuid, date, time)
from public, anon;
revoke all on function public.reschedule_workout(uuid, date, time)
from public, anon;
revoke all on function public.cancel_scheduled_workout(uuid)
from public, anon;
revoke all on function public.start_scheduled_workout(uuid)
from public, anon;
grant execute on function public.schedule_workout(uuid, date, time)
to authenticated;
grant execute on function public.reschedule_workout(uuid, date, time)
to authenticated;
grant execute on function public.cancel_scheduled_workout(uuid)
to authenticated;
grant execute on function public.start_scheduled_workout(uuid)
to authenticated;

commit;
