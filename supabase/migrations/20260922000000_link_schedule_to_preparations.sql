-- Conecta una entrada de agenda con una preparación activa sin confundir esa
-- relación con el origen de la plantilla. El vínculo es opcional para conservar
-- sesiones personales o generales que no pertenecen a ninguna oposición.

begin;

create index scheduled_workouts_preparation_goal_date_idx
  on public.scheduled_workouts (
    preparation_goal_id,
    scheduled_date,
    scheduled_time
  )
  where preparation_goal_id is not null;

drop function public.schedule_workout(uuid, date, time);

create function public.schedule_workout(
  p_template_id uuid,
  p_scheduled_date date,
  p_scheduled_time time default null,
  p_preparation_goal_id uuid default null
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

  if p_preparation_goal_id is not null and not exists (
    select 1
    from public.preparation_goals as goal
    where goal.id = p_preparation_goal_id
      and goal.user_id = current_user_id
      and goal.status = 'active'
  ) then
    raise exception 'Active preparation goal is not accessible';
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
    p_preparation_goal_id,
    p_scheduled_date,
    p_scheduled_time,
    schedule_source
  )
  returning id into scheduled_id;

  return scheduled_id;
end;
$$;

revoke all on function public.schedule_workout(uuid, date, time, uuid)
from public, anon;
grant execute on function public.schedule_workout(uuid, date, time, uuid)
to authenticated;

commit;
