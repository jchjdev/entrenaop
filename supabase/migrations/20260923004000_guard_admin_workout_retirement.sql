-- No retirar una plantilla que aún sostiene citas pendientes o activas.
begin;

create or replace function public.remove_admin_workout(p_template_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  template_status text;
begin
  if (select auth.uid()) is null or not (select public.is_admin()) then
    raise exception 'No tienes permiso para retirar sesiones oficiales.'
      using errcode = '42501';
  end if;

  select template.status into template_status
  from public.workout_templates as template
  join public.program_workout_templates as link
    on link.template_id = template.id
  where template.id = p_template_id
    and template.origin = 'system'
    and template.owner_user_id is null
  for update of template;
  if not found or template_status = 'archived' then
    raise exception 'La sesión oficial no existe o ya está retirada.'
      using errcode = '22023';
  end if;

  if exists (
    select 1 from public.scheduled_workouts
    where template_id = p_template_id
      and status in ('planned', 'in_progress')
  ) then
    raise exception 'Hay entrenamientos pendientes o en curso. Reprográmalos antes de retirar esta sesión.'
      using errcode = '22023';
  end if;

  if template_status = 'draft'
    and not exists (
      select 1 from public.scheduled_workouts where template_id = p_template_id
    )
    and not exists (
      select 1 from public.workout_executions where template_id = p_template_id
    ) then
    delete from public.workout_templates where id = p_template_id;
  else
    update public.workout_templates
    set status = 'archived', visibility = 'private', updated_at = now()
    where id = p_template_id;
  end if;
end;
$$;

commit;
