begin;

-- Publicar permite usar la receta; esta marca solo decide su descubrimiento.
-- Se conserva el listado anterior hasta que ADMIN cambie cada sesión.
alter table public.workout_templates
  add column show_in_library boolean not null default true;

create or replace function public.create_admin_workout_draft(p_program_id text,p_payload jsonb)
returns uuid language plpgsql security definer set search_path='' as $$
declare new_template_id uuid;
begin
  if (select auth.uid()) is null or not (select public.is_admin()) then
    raise exception 'No tienes permiso para crear sesiones oficiales.' using errcode='42501';
  end if;
  if p_payload ? 'show_in_library' and jsonb_typeof(p_payload->'show_in_library')<>'boolean' then
    raise exception 'La visibilidad de la sesión debe ser verdadera o falsa.' using errcode='22023';
  end if;
  if p_program_id is not null and not exists(select 1 from public.preparation_programs where id=p_program_id) then
    raise exception 'El programa no existe.' using errcode='22023';
  end if;
  perform set_config('entrenaop.creating_official_template','true',true);
  new_template_id:=public.create_personal_workout_template(p_payload);
  perform set_config('entrenaop.creating_official_template','false',true);
  if exists(select 1 from public.workout_blocks b join public.workout_items i on i.block_id=b.id
    join public.exercises e on e.id=i.exercise_id where b.template_id=new_template_id and e.is_public is distinct from true) then
    raise exception 'Una sesión oficial solo puede usar ejercicios públicos.' using errcode='22023';
  end if;
  update public.workout_templates set origin='system',owner_user_id=null,visibility='private',status='draft',
    show_in_library=case when p_program_id is not null then false else coalesce((p_payload->>'show_in_library')::boolean,true) end,
    updated_at=now() where id=new_template_id;
  insert into public.program_workout_templates(program_id,template_id,catalog_scope)
    values(p_program_id,new_template_id,case when p_program_id is null then 'general' else 'program' end);
  return new_template_id;
end $$;

create function public.set_admin_workout_library_visibility(p_template_id uuid,p_show_in_library boolean,p_expected boolean)
returns void language plpgsql security definer set search_path='' as $$
declare current_value boolean;
begin
  if (select auth.uid()) is null or not (select public.is_admin()) then
    raise exception 'No tienes permiso para cambiar la visibilidad de sesiones oficiales.' using errcode='42501';
  end if;
  if p_show_in_library is null or p_expected is null then
    raise exception 'Indica la visibilidad actual y la nueva.' using errcode='22023';
  end if;
  select t.show_in_library into current_value from public.workout_templates t
    join public.program_workout_templates l on l.template_id=t.id and l.catalog_scope='general'
    where t.id=p_template_id and t.origin='system' and t.owner_user_id is null and t.status in ('draft','published')
    for update of t;
  if not found then raise exception 'La sesión no está disponible en este catálogo.' using errcode='22023'; end if;
  if current_value<>p_expected then
    raise exception 'La visibilidad ha cambiado. Recarga la sesión antes de continuar.' using errcode='40001';
  end if;
  update public.workout_templates set show_in_library=p_show_in_library where id=p_template_id;
end $$;
revoke all on function public.set_admin_workout_library_visibility(uuid,boolean,boolean) from public,anon,authenticated;
grant execute on function public.set_admin_workout_library_visibility(uuid,boolean,boolean) to authenticated;

-- No se filtra por el texto o chip elegido: las opciones no desaparecen al
-- buscar. Solo cuentan las versiones publicadas vigentes del catálogo.
create function public.get_guided_program_catalog_categories()
returns setof public.guided_program_categories language sql stable security invoker set search_path='' as $$
  select c.* from public.guided_program_categories c
  where auth.uid() is not null and c.is_active and exists(
    select 1 from public.guided_program_category_links l join public.guided_programs p on p.id=l.program_id
    where l.category_id=c.id and p.status='published' and not exists(
      select 1 from public.guided_programs newer where newer.family_id=p.family_id
        and newer.status='published' and newer.version>p.version
    )
  ) order by c.name,c.id;
$$;
revoke all on function public.get_guided_program_catalog_categories() from public,anon,authenticated;
grant execute on function public.get_guided_program_catalog_categories() to authenticated;
create or replace function public.revise_admin_workout(
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
  -- La revisión deportiva conserva la elección editorial de la sesión fuente.
  update public.workout_templates set show_in_library=(select show_in_library from public.workout_templates where id=p_template_id) where id=new_template_id;
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


commit;
