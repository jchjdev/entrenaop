-- La administración de contenido oficial no requiere un derecho Pro personal.
begin;

create or replace function public.enforce_personal_session_quota() returns trigger
language plpgsql security definer set search_path = '' as $$
declare revision public.workout_templates%rowtype; revision_id text;
begin
  -- El contexto solo lo fija el RPC administrativo tras comprobar is_admin().
  -- La fila nace oficial y privada; nunca ocupa una plaza personal intermedia.
  if tg_op = 'INSERT' and current_setting('entrenaop.creating_official_template',true) = 'true'
    and coalesce(public.is_admin(),false) then
    new.origin := 'system';
    new.owner_user_id := null;
    new.status := 'draft';
    new.visibility := 'private';
  end if;
  if new.origin <> 'user' or new.status = 'archived' then return new; end if;
  if tg_op = 'UPDATE' and old.origin = 'user' and old.status <> 'archived'
    and old.owner_user_id = new.owner_user_id and old.family_id = new.family_id then return new; end if;
  perform 1 from public.profiles where id = new.owner_user_id for update;
  if tg_op = 'INSERT' then
    revision_id := nullif(current_setting('entrenaop.revising_template', true), '');
    if revision_id is not null then
      select * into revision from public.workout_templates where id::text = revision_id
        and origin = 'user' and status <> 'archived' and owner_user_id = auth.uid()
        and owner_user_id = new.owner_user_id for update;
      if not found then raise exception 'Revisión no disponible.' using errcode = '42501'; end if;
      -- El contexto interno no omite la cuota: vincula la versión a una familia
      -- propia existente. No permite obtener otra plaza ni cambiar de dueño.
      new.family_id := revision.family_id;
      new.previous_version_id := revision.id;
      new.version := revision.version + 1;
    end if;
  end if;
  if not public.has_pro_access(new.owner_user_id)
    and not exists(select 1 from public.workout_templates where owner_user_id = new.owner_user_id
      and origin = 'user' and status <> 'archived' and family_id = new.family_id and id <> new.id)
    and (select count(distinct family_id) from public.workout_templates where owner_user_id = new.owner_user_id
      and origin = 'user' and status <> 'archived' and id <> new.id) >= 4 then
    raise exception 'Has alcanzado las 4 sesiones propias incluidas en Free. Con Pro puedes guardar más.'
      using errcode = 'P0001', detail = 'free_session_limit';
  end if;
  return new;
end $$;

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

  perform set_config('entrenaop.creating_official_template','true',true);
  new_template_id := public.create_personal_workout_template(p_payload);
  perform set_config('entrenaop.creating_official_template','false',true);

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

commit;
