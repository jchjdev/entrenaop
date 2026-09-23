-- Publicar es una acción administrativa explícita. Solo hace visible la
-- plantilla en la biblioteca pública; no crea agenda ni prescripción.
begin;

create function public.publish_admin_workout_draft(p_template_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if (select auth.uid()) is null or not (select public.is_admin()) then
    raise exception 'No tienes permiso para publicar sesiones oficiales.'
      using errcode = '42501';
  end if;

  perform 1
  from public.workout_templates as template
  join public.program_workout_templates as link
    on link.template_id = template.id
  where template.id = p_template_id
    and template.origin = 'system'
    and template.owner_user_id is null
    and template.visibility = 'private'
    and template.status = 'draft'
  for update of template;
  if not found then
    raise exception 'No existe un borrador oficial publicable.'
      using errcode = '22023';
  end if;

  update public.workout_templates
  set visibility = 'public', status = 'published'
  where id = p_template_id;
end;
$$;

revoke all on function public.publish_admin_workout_draft(uuid)
from public, anon;
grant execute on function public.publish_admin_workout_draft(uuid)
to authenticated;

commit;
