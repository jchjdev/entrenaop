-- Las preparaciones oficiales son de solo lectura para el deportista. Las
-- sesiones libres pueden convivir en su agenda, pero nunca se vinculan desde
-- el cliente a una preparación ni permiten alterar una prescripción oficial.

begin;

drop function public.schedule_workout(uuid, date, time, uuid);

create function public.schedule_workout(
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
    template.origin
  into selected_template
  from public.workout_templates as template
  where template.id = p_template_id
    and (
      (
        template.visibility = 'public'
        and template.status = 'published'
        and template.origin = 'system'
      )
      or (
        template.owner_user_id = current_user_id
        and template.origin = 'user'
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
    preparation_goal_id,
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
    null,
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
    and scheduled.preparation_goal_id is null
    and scheduled.status = 'planned';

  if not found then
    raise exception 'Editable planned workout is not accessible';
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
    and scheduled.preparation_goal_id is null
    and scheduled.status = 'planned';

  if not found then
    raise exception 'Editable planned workout is not accessible';
  end if;
end;
$$;

revoke all on function public.schedule_workout(uuid, date, time)
from public, anon;
grant execute on function public.schedule_workout(uuid, date, time)
to authenticated;

commit;
