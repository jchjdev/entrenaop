-- Biblioteca general y plantillas de programa son destinos distintos.
-- Las publicaciones anteriores ya eran generales: conservamos ese significado.
begin;

alter table public.program_workout_templates
  alter column program_id drop not null;

alter table public.program_workout_templates
  add column catalog_scope text not null default 'program';

update public.program_workout_templates as link
set catalog_scope = 'general'
from public.workout_templates as template
where template.id = link.template_id
  and template.visibility = 'public';

alter table public.program_workout_templates
  add constraint program_workout_templates_scope_check
  check (
    (catalog_scope = 'program' and program_id is not null)
    or catalog_scope = 'general'
  );

create index program_workout_templates_scope_idx
  on public.program_workout_templates (catalog_scope, created_at desc);

create or replace function public.create_admin_workout_draft(
  p_program_id text,
  p_payload jsonb
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  new_template_id uuid;
begin
  if (select auth.uid()) is null or not (select public.is_admin()) then
    raise exception 'No tienes permiso para crear sesiones oficiales.'
      using errcode = '42501';
  end if;

  if p_program_id is not null and not exists (
    select 1 from public.preparation_programs where id = p_program_id
  ) then
    raise exception 'El programa no existe.' using errcode = '22023';
  end if;

  new_template_id := public.create_personal_workout_template(p_payload);

  if exists (
    select 1
    from public.workout_blocks as block
    join public.workout_items as item on item.block_id = block.id
    join public.exercises as exercise on exercise.id = item.exercise_id
    where block.template_id = new_template_id
      and exercise.is_public is distinct from true
  ) then
    raise exception 'Una sesión oficial solo puede usar ejercicios públicos.'
      using errcode = '22023';
  end if;

  update public.workout_templates
  set origin = 'system', owner_user_id = null,
      visibility = 'private', status = 'draft', updated_at = now()
  where id = new_template_id;

  insert into public.program_workout_templates
    (program_id, template_id, catalog_scope)
  values (
    p_program_id, new_template_id,
    case when p_program_id is null then 'general' else 'program' end
  );

  return new_template_id;
end;
$$;

create or replace function public.publish_admin_workout_draft(p_template_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  target_scope text;
begin
  if (select auth.uid()) is null or not (select public.is_admin()) then
    raise exception 'No tienes permiso para publicar sesiones oficiales.'
      using errcode = '42501';
  end if;

  select link.catalog_scope into target_scope
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
  set visibility = case when target_scope = 'general' then 'public' else 'private' end,
      status = 'published', updated_at = now()
  where id = p_template_id;
end;
$$;

create function public.remove_admin_workout(p_template_id uuid)
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

  -- La prescripción o el resultado histórico nunca se borra.
  if template_status = 'draft'
    and not exists (
      select 1 from public.scheduled_workouts
      where template_id = p_template_id
    )
    and not exists (
      select 1 from public.workout_executions
      where template_id = p_template_id
    ) then
    delete from public.workout_templates where id = p_template_id;
  else
    update public.workout_templates
    set status = 'archived', visibility = 'private', updated_at = now()
    where id = p_template_id;
  end if;
end;
$$;

revoke all on function public.remove_admin_workout(uuid) from public, anon;
grant execute on function public.remove_admin_workout(uuid) to authenticated;

create function public.revise_admin_workout(
  p_template_id uuid,
  p_payload jsonb
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  source record;
  old_link public.program_workout_templates%rowtype;
  old_status text;
  old_version integer;
  old_family uuid;
  old_previous uuid;
  new_template_id uuid;
begin
  if (select auth.uid()) is null or not (select public.is_admin()) then
    raise exception 'No tienes permiso para revisar sesiones oficiales.'
      using errcode = '42501';
  end if;

  select link.program_id, link.catalog_scope, template.status,
         template.version, template.family_id, template.previous_version_id
  into source
  from public.program_workout_templates as link
  join public.workout_templates as template on template.id = link.template_id
  where template.id = p_template_id
    and template.origin = 'system'
    and template.owner_user_id is null
    and template.status in ('draft', 'published')
  for update of template;
  if not found then
    raise exception 'La sesión no admite una revisión.' using errcode = '22023';
  end if;
  old_link.program_id := source.program_id;
  old_link.catalog_scope := source.catalog_scope;
  old_status := source.status;
  old_version := source.version;
  old_family := source.family_id;
  old_previous := source.previous_version_id;

  if old_status = 'draft' and (
    exists (select 1 from public.scheduled_workouts where template_id = p_template_id)
    or exists (select 1 from public.workout_executions where template_id = p_template_id)
  ) then
    raise exception 'Un borrador ya usado no se puede reemplazar.'
      using errcode = '22023';
  end if;
  if old_status = 'published' and exists (
    select 1 from public.workout_templates
    where family_id = old_family and status = 'draft'
  ) then
    raise exception 'Ya hay una nueva versión en borrador de esta sesión.'
      using errcode = '22023';
  end if;

  new_template_id := public.create_admin_workout_draft(
    case when old_link.catalog_scope = 'program' then old_link.program_id else null end,
    p_payload
  );
  update public.program_workout_templates
  set program_id = old_link.program_id,
      catalog_scope = old_link.catalog_scope
  where template_id = new_template_id;

  -- El borrador no tiene consumidores: su reemplazo se confirma en la misma
  -- transacción. Una versión publicada permanece intacta.
  if old_status = 'draft' then
    delete from public.workout_templates where id = p_template_id;
    update public.workout_templates
    set family_id = old_family,
        previous_version_id = old_previous,
        version = old_version
    where id = new_template_id;
  else
    update public.workout_templates
    set family_id = old_family,
        previous_version_id = p_template_id,
        version = old_version + 1
    where id = new_template_id;
  end if;
  return new_template_id;
end;
$$;

revoke all on function public.revise_admin_workout(uuid, jsonb)
  from public, anon;
grant execute on function public.revise_admin_workout(uuid, jsonb)
  to authenticated;

commit;
