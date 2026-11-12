begin;

alter table public.workout_execution_sets
  add column exercise_media_frozen boolean not null default false,
  add column exercise_image_path text;

-- La foto anterior se consultaba en directo. Fijamos esa misma referencia
-- sin volver a contabilizar los resultados que ya revisó un entrenador.
alter table public.workout_execution_sets disable trigger trainer_set_revision;
update public.workout_execution_sets s
set exercise_media_frozen = true,
    exercise_image_path = e.image_path,
    exercise_description = coalesce(s.exercise_description, e.description),
    exercise_video_url = coalesce(s.exercise_video_url, e.video_url)
from public.exercises e
where e.id = s.exercise_id and e.origin = 'coach';
alter table public.workout_execution_sets enable trigger trainer_set_revision;

create index workout_execution_sets_frozen_image_idx
  on public.workout_execution_sets (exercise_image_path, execution_id)
  where exercise_media_frozen and exercise_image_path is not null;

create function trainer_private.freeze_coach_exercise_media() returns trigger
language plpgsql security definer set search_path = '' as $$
declare exercise public.exercises;
begin
  select e.* into exercise from public.exercises e
    where e.id = new.exercise_id and e.origin = 'coach' for share;
  if found then
    new.exercise_media_frozen := true;
    new.exercise_image_path := exercise.image_path;
    new.exercise_description := exercise.description;
    new.exercise_video_url := exercise.video_url;
  end if;
  return new;
end $$;

revoke all on function trainer_private.freeze_coach_exercise_media() from public, anon, authenticated;
-- Se ejecuta antes del guard de medios, que protege la ruta recién fijada.
create trigger a0_freeze_coach_exercise_media before insert on public.workout_execution_sets
  for each row execute function trainer_private.freeze_coach_exercise_media();

create or replace function trainer_private.can_read_exercise_image(p_path text) returns boolean
language sql stable security definer set search_path = '' as $$
  select (
    trainer_private.has_trainer_mfa() and exists (
      select 1 from trainer_private.exercise_images
      where path = p_path and trainer_id = auth.uid()
        and cleanup_state = 'active' and deleted_at is null
    )
  ) or exists (
    select 1 from public.exercises e
    where e.origin = 'coach' and e.image_path = p_path and trainer_private.can_read_exercise(e.id)
  ) or exists (
    select 1 from public.workout_execution_sets s
    join public.workout_executions x on x.id = s.execution_id
    where s.exercise_media_frozen and s.exercise_image_path = p_path and x.user_id = auth.uid()
  );
$$;

create table trainer_private.exercise_presentation_writes (
  trainer_id uuid not null references public.profiles(id) on delete cascade,
  operation_id uuid not null,
  exercise_id uuid not null,
  payload jsonb not null check (octet_length(payload::text) <= 8192),
  primary key (trainer_id, operation_id)
);
alter table trainer_private.exercise_presentation_writes enable row level security;
revoke all on trainer_private.exercise_presentation_writes from public, anon, authenticated;

create or replace function trainer_private.save_exercise(
  p_operation_id uuid, p_payload jsonb, p_previous_id uuid default null
) returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  previous_version trainer_private.exercise_versions;
  prior trainer_private.exercise_versions;
  presentation trainer_private.exercise_presentation_writes;
  previous_exercise public.exercises;
  normalized record;
  result uuid := gen_random_uuid();
  new_image_path text := p_payload->>'image_path';
begin
  perform trainer_private.require_authoring_access();
  perform trainer_private.catalog_lock_ids(array[p_previous_id]);
  if exists (
    select 1 from trainer_private.catalog_deleted_writes
    where owner_id = auth.uid() and kind = 'exercise' and operation_id = p_operation_id
  ) then
    raise exception 'El contenido de esta operación fue eliminado definitivamente.' using errcode = 'P0001';
  end if;
  if p_operation_id is null or p_payload is null or jsonb_typeof(p_payload) <> 'object' then
    raise invalid_parameter_value;
  end if;

  select * into prior from trainer_private.exercise_versions
    where trainer_id = auth.uid() and operation_id = p_operation_id;
  if found then
    if prior.payload is distinct from p_payload or prior.previous_id is distinct from p_previous_id then
      raise exception 'El reintento no coincide con el ejercicio original.' using errcode = '22023';
    end if;
    return prior.exercise_id;
  end if;
  select * into presentation from trainer_private.exercise_presentation_writes
    where trainer_id = auth.uid() and operation_id = p_operation_id;
  if found then
    if presentation.payload is distinct from p_payload or presentation.exercise_id is distinct from p_previous_id then
      raise exception 'El reintento no coincide con el ejercicio original.' using errcode = '22023';
    end if;
    if not exists (select 1 from public.exercises where id = presentation.exercise_id) then
      raise exception 'El contenido de esta operación fue eliminado definitivamente.' using errcode = 'P0001';
    end if;
    return presentation.exercise_id;
  end if;

  if p_previous_id is not null then
    select v.* into previous_version from trainer_private.exercise_versions v
      join public.exercises e on e.id = v.exercise_id
      where v.exercise_id = p_previous_id and v.trainer_id = auth.uid()
        and v.current and e.trashed_at is null for update of v;
    if not found then
      raise exception 'El ejercicio cambió. Recarga antes de revisarlo.' using errcode = '40001';
    end if;
    select * into previous_exercise from public.exercises where id = p_previous_id;
  end if;
  select * into normalized from public.normalize_exercise_draft(
    p_payload->>'name', p_payload->>'description', p_payload->>'video_url',
    array(select jsonb_array_elements_text(p_payload->'muscle_groups')),
    array(select jsonb_array_elements_text(p_payload->'equipment')),
    p_payload->>'difficulty', p_payload->>'exercise_type'
  );
  if new_image_path is not null and not exists (
    select 1 from trainer_private.exercise_images i join storage.objects o
      on o.name = i.path and o.bucket_id = 'trainer-exercise-images'
    where i.path = new_image_path and i.trainer_id = auth.uid()
  ) then
    raise exception 'Sube primero una imagen profesional propia.' using errcode = '22023';
  end if;

  -- La receta mantiene el ID. Los resultados se leen desde su instantánea.
  if p_previous_id is not null and (
    previous_exercise.name, previous_exercise.muscle_groups, previous_exercise.equipment,
    previous_exercise.difficulty, previous_exercise.exercise_type
  ) is not distinct from (
    normalized.normalized_name, normalized.normalized_muscle_groups, normalized.normalized_equipment,
    normalized.normalized_difficulty, normalized.normalized_exercise_type
  ) then
    update public.exercises
    set description = normalized.normalized_description,
        video_url = normalized.normalized_video_url,
        image_path = new_image_path
    where id = p_previous_id and (description, video_url, image_path) is distinct from
      (normalized.normalized_description, normalized.normalized_video_url, new_image_path);
    insert into trainer_private.exercise_presentation_writes (trainer_id, operation_id, exercise_id, payload)
      values (auth.uid(), p_operation_id, p_previous_id, p_payload);
    return p_previous_id;
  end if;

  insert into trainer_private.exercise_limits (trainer_id) values (auth.uid()) on conflict do nothing;
  update trainer_private.exercise_limits set exercise_used = exercise_used + 1
    where trainer_id = auth.uid() and exercise_used < exercise_limit;
  if not found then
    raise exception 'Has alcanzado el límite de ejercicios y versiones profesionales.' using errcode = '22023';
  end if;
  insert into public.exercises (
    id, name, description, video_url, muscle_groups, equipment, difficulty, exercise_type,
    is_public, created_by, origin, image_path
  ) values (
    result, normalized.normalized_name, normalized.normalized_description, normalized.normalized_video_url,
    normalized.normalized_muscle_groups, normalized.normalized_equipment, normalized.normalized_difficulty,
    normalized.normalized_exercise_type, false, auth.uid(), 'coach', new_image_path
  );
  if p_previous_id is not null then
    update trainer_private.exercise_versions set current = false where exercise_id = p_previous_id;
  end if;
  insert into trainer_private.exercise_versions (exercise_id, trainer_id, family_id, version, previous_id, operation_id, payload)
    values (result, auth.uid(), coalesce(previous_version.family_id, result),
      coalesce(previous_version.version, 0) + 1, p_previous_id, p_operation_id, p_payload);
  return result;
end $$;

do $migration$
declare
  definition text;
  anchor text;
begin
  -- El guard es compartido con las imágenes, que no tienen execution_id.
  -- La expresión original podía evaluar sus campos aunque no fuera un vídeo.
  definition := pg_get_functiondef('trainer_private.media_asset_guard()'::regprocedure);
  anchor := 'old.execution_id is not null';
  if strpos(definition, anchor) = 0 then raise exception 'Revisar la protección de los recursos.'; end if;
  definition := replace(definition, anchor, '(to_jsonb(old)->>''execution_id'') is not null');
  definition := replace(definition, 'new.execution_id is null and new.execution_set_id is null',
    '(to_jsonb(new)->>''execution_id'') is null and (to_jsonb(new)->>''execution_set_id'') is null');
  execute definition;

  -- La vista de una ejecución existente conserva también el texto congelado.
  definition := pg_get_functiondef('trainer_private.get_scheduled_workout_preview(uuid,uuid)'::regprocedure);
  anchor := '''description'', e.description';
  if strpos(definition, anchor) = 0 then raise exception 'Revisar la consulta de la pauta.'; end if;
  execute replace(definition, anchor, $sql$'description', case
    when e.origin = 'coach' and scheduled.execution_id is not null then (
      select s.exercise_description from public.workout_execution_sets s
      where s.execution_id = scheduled.execution_id and s.exercise_id = e.id
        and s.exercise_media_frozen
      order by s.set_order limit 1
    ) else e.description end$sql$);

  -- La comprobación de la receta y el inicio leen la misma ficha del ejercicio.
  definition := pg_get_functiondef('trainer_private.start_reviewed_scheduled_workout(uuid,uuid,text)'::regprocedure);
  anchor := 'perform 1 from public.workout_templates where id = scheduled.template_id for share;';
  if strpos(definition, anchor) = 0 then raise exception 'Revisar el bloqueo de inicio de la pauta.'; end if;
  execute replace(definition, anchor, anchor || $sql$
    perform 1 from public.exercises e where e.origin = 'coach' and e.id in (
      select i.exercise_id from public.workout_items i
      join public.workout_blocks b on b.id = i.block_id
      where b.template_id = scheduled.template_id
    ) order by e.id for share nowait;$sql$);
end
$migration$;

commit;
