begin;

-- La autorización depende de la cita concreta, nunca de conocer el UUID de una
-- plantilla. Consultar esta función no crea ejecuciones ni confirma avisos.
create function trainer_private.get_scheduled_workout_preview(
  p_expected_owner uuid,
  p_scheduled_id uuid
) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare
  scheduled public.scheduled_workouts;
  template public.workout_templates;
  assignment public.trainer_assignments;
  coach_name text;
  payload jsonb;
  prescription jsonb;
begin
  if auth.uid() is null or p_expected_owner is distinct from auth.uid() then
    raise insufficient_privilege;
  end if;

  select * into scheduled from public.scheduled_workouts
    where id = p_scheduled_id and user_id = p_expected_owner
      and status in ('planned', 'in_progress', 'completed', 'abandoned', 'skipped');
  if not found then raise insufficient_privilege; end if;

  select * into template from public.workout_templates
    where id = scheduled.template_id and version = scheduled.template_version;
  if not found then
    raise exception 'La pauta ha cambiado. Vuelve a consultar tu entrenamiento.' using errcode = '40001';
  end if;
  if template.status not in ('published', 'archived') then
    raise insufficient_privilege;
  end if;

  if scheduled.source = 'coach' then
    select a.* into assignment
      from public.trainer_assignments a
      join public.trainer_client_relations r on r.id = a.relation_id
      where a.scheduled_id = scheduled.id and a.client_id = p_expected_owner
        and r.client_id = a.client_id and r.trainer_id = a.trainer_id
        and (r.ended_at is null or scheduled.execution_id is not null)
        and not exists (
          select 1 from trainer_private.assignment_lifecycle l
          where l.assignment_id = a.scheduled_id and l.archived_at is not null
        );
    if not found or template.origin is distinct from 'coach'
      or template.owner_user_id is distinct from assignment.trainer_id then
      raise insufficient_privilege;
    end if;
    select nullif(btrim(full_name), '') into coach_name
      from public.profiles where id = assignment.trainer_id;
  elsif template.origin = 'coach' or not coalesce((
    template.owner_user_id = p_expected_owner
    or (template.visibility = 'public' and template.status in ('published', 'archived'))
    or (template.origin = 'system' and template.status = 'archived')
  ), false) then
    raise insufficient_privilege;
  end if;

  -- Tener una cita propia no autoriza ejercicios privados ajenos insertados
  -- mediante una referencia FK. Los oficiales retirados conservan la consulta
  -- de recetas existentes, como exercise_retained_official_read.
  if exists (
    select 1 from public.workout_blocks b
    join public.workout_items i on i.block_id = b.id
    join public.exercises e on e.id = i.exercise_id
    where b.template_id = template.id and not coalesce((
      e.is_public or e.created_by = p_expected_owner or e.origin = 'system'
      or (scheduled.source = 'coach' and e.origin = 'coach' and e.created_by = assignment.trainer_id)
    ), false)
  ) then raise insufficient_privilege; end if;

  -- Cada revisión posee otro UUID. Se conserva el UUID y la versión asignados,
  -- incluso si esa versión se archivó al publicar la siguiente en la biblioteca.
  -- El contrato coincide con WorkoutTemplateModel, sin exponer metadatos privados
  -- de la biblioteca del preparador ni otras versiones de ejercicios o programas.
  select jsonb_build_object(
    'id', template.id,
    'name', template.name,
    'description', template.description,
    'version', template.version,
    'estimated_duration_minutes', template.estimated_duration_minutes,
    'workout_blocks', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', b.id, 'order_index', b.order_index, 'name', b.name,
        'format', b.format, 'rounds', b.rounds,
        'time_cap_seconds', b.time_cap_seconds,
        'rest_after_seconds', b.rest_after_seconds,
        'workout_items', coalesce((
          select jsonb_agg(jsonb_build_object(
            'id', i.id, 'order_index', i.order_index, 'notes', i.notes,
            'exercises', jsonb_build_object('id', e.id, 'name', e.name, 'description', e.description),
            'workout_sets', coalesce((
              select jsonb_agg(jsonb_build_object(
                'id', w.id, 'order_index', w.order_index,
                'target_reps', w.target_reps,
                'target_duration_seconds', w.target_duration_seconds,
                'target_distance_meters', w.target_distance_meters,
                'target_load_kg', w.target_load_kg,
                'target_rpe', w.target_rpe, 'target_rir', w.target_rir,
                'target_pace_min_seconds_per_km', w.target_pace_min_seconds_per_km,
                'target_pace_max_seconds_per_km', w.target_pace_max_seconds_per_km,
                'recovery_type', w.recovery_type,
                'recovery_duration_seconds', w.recovery_duration_seconds,
                'recovery_distance_meters', w.recovery_distance_meters,
                'rest_after_seconds', w.rest_after_seconds,
                'performance_prescription', w.performance_prescription,
                'running_step', w.running_step
              ) order by w.order_index, w.id)
              from public.workout_sets w where w.item_id = i.id
            ), '[]'::jsonb)
          ) order by i.order_index, i.id)
          from public.workout_items i
          join public.exercises e on e.id = i.exercise_id
          where i.block_id = b.id
        ), '[]'::jsonb)
      ) order by b.order_index, b.id)
      from public.workout_blocks b where b.template_id = template.id
    ), '[]'::jsonb)
  ) into prescription;

  payload := jsonb_build_object(
    'scheduled_workout', jsonb_build_object(
      'id', scheduled.id,
      'template_id', scheduled.template_id,
      'template_name', scheduled.template_name,
      'template_version', scheduled.template_version,
      'estimated_duration_minutes', scheduled.estimated_duration_minutes,
      'scheduled_date', scheduled.scheduled_date,
      'scheduled_time', scheduled.scheduled_time,
      'preparation_goal_id', scheduled.preparation_goal_id,
      'source', scheduled.source,
      'status', scheduled.status,
      'execution_id', scheduled.execution_id,
      'trainer_assignments', case when assignment.scheduled_id is null then null
        else jsonb_build_object('note', assignment.note) end,
      'trainer_name', case when scheduled.source = 'coach' then coalesce(coach_name, 'Preparador') end,
      'is_self', scheduled.source = 'coach' and assignment.trainer_id = p_expected_owner
    ),
    'template', prescription,
    'planning_revision', assignment.planning_revision
  );
  return payload || jsonb_build_object(
    -- El inicio modifica estado y vínculo de ejecución, no la prescripción.
    -- Excluirlos permite reintentar el mismo contenido, pero no retomar otra
    -- revisión que una segunda pantalla ya haya iniciado mientras tanto.
    'revision', encode(sha256(convert_to(jsonb_set(payload, '{scheduled_workout}',
      (payload->'scheduled_workout') - 'status' - 'execution_id')::text, 'UTF8')), 'hex')
  );
end;
$$;

create function public.get_scheduled_workout_preview(
  p_expected_owner uuid,
  p_scheduled_id uuid
) returns jsonb
language sql stable security invoker set search_path = '' as $$
  select trainer_private.get_scheduled_workout_preview(p_expected_owner, p_scheduled_id);
$$;

-- El inicio explícito fija la misma revisión que acaba de ver el deportista.
  -- Conserva el orden cliente/cita. El catálogo se bloquea antes de la fila de
  -- plantilla, igual que papelera/versionado y sus triggers de referencias.
create function trainer_private.start_reviewed_scheduled_workout(
  p_expected_owner uuid,
  p_scheduled_id uuid,
  p_expected_revision text
) returns uuid
language plpgsql volatile security definer set search_path = '' as $$
declare
  scheduled public.scheduled_workouts;
  preview jsonb;
  mutable_personal boolean;
  resource_ids uuid[];
  fenced_ids uuid[];
begin
  if auth.uid() is null or p_expected_owner is distinct from auth.uid() then
    raise insufficient_privilege;
  end if;
  -- La revisión personal toma perfil → plantilla. Retener primero la FK del
  -- perfil evita invertir ese orden al insertar la ejecución con su plantilla
  -- bloqueada; no serializa las consultas de otros deportistas.
  perform 1 from public.profiles where id = p_expected_owner for key share;
  perform pg_advisory_xact_lock(hashtextextended('trainer-client:' || p_expected_owner::text, 0));
  select * into scheduled from public.scheduled_workouts
    where id = p_scheduled_id and user_id = p_expected_owner for update;
  if not found then raise insufficient_privilege; end if;
  if scheduled.status not in ('planned', 'in_progress') then
    raise exception 'El estado de la pauta ha cambiado. Vuelve a consultar el entrenamiento.' using errcode = '40001';
  end if;
  preview := trainer_private.get_scheduled_workout_preview(p_expected_owner, p_scheduled_id);
  if p_expected_revision is null or preview->>'revision' is distinct from p_expected_revision then
    raise exception 'La pauta ha cambiado. Revisa el entrenamiento antes de comenzar.' using errcode = '40001';
  end if;

  select t.origin = 'user' and t.owner_user_id = p_expected_owner
    into mutable_personal from public.workout_templates t where t.id = scheduled.template_id;
  if not found then raise serialization_failure; end if;

  if mutable_personal then
    -- Solo se bloquean UUID de la consulta ya autorizada. Si otra escritura
    -- introduce referencias distintas antes del cierre, se detectan después.
    select array_agg(x order by x) into resource_ids from (
      select scheduled.template_id x
      union select (b->>'id')::uuid from jsonb_array_elements(preview#>'{template,workout_blocks}') b
      union select (i->>'id')::uuid from jsonb_array_elements(preview#>'{template,workout_blocks}') b,
        jsonb_array_elements(b->'workout_items') i
      union select (w->>'id')::uuid from jsonb_array_elements(preview#>'{template,workout_blocks}') b,
        jsonb_array_elements(b->'workout_items') i, jsonb_array_elements(i->'workout_sets') w
      union select (i#>>'{exercises,id}')::uuid from jsonb_array_elements(preview#>'{template,workout_blocks}') b,
        jsonb_array_elements(b->'workout_items') i
    ) resources;
    perform trainer_private.catalog_lock_ids(resource_ids);

    -- Estas filas propias admiten DML bajo las políticas existentes. UPDATE en
    -- los padres bloquea también nuevos hijos por FK; SHARE fija dosis y texto
    -- hasta que el motor haya copiado la prescripción a su ejecución.
    perform 1 from public.workout_templates t where t.id = scheduled.template_id for update nowait;
    perform 1 from public.workout_blocks b where b.template_id = scheduled.template_id order by b.id for update nowait;
    perform 1 from public.workout_items i join public.workout_blocks b on b.id = i.block_id
      where b.template_id = scheduled.template_id order by i.id for update of i nowait;
    perform 1 from public.workout_sets w join public.workout_items i on i.id = w.item_id
      join public.workout_blocks b on b.id = i.block_id
      where b.template_id = scheduled.template_id order by w.id for share of w nowait;

    select array_agg(x order by x) into fenced_ids from (
      select scheduled.template_id x
      union select b.id from public.workout_blocks b where b.template_id = scheduled.template_id
      union select i.id from public.workout_items i join public.workout_blocks b on b.id = i.block_id
        where b.template_id = scheduled.template_id
      union select w.id from public.workout_sets w join public.workout_items i on i.id = w.item_id
        join public.workout_blocks b on b.id = i.block_id where b.template_id = scheduled.template_id
      union select i.exercise_id from public.workout_items i join public.workout_blocks b on b.id = i.block_id
        where b.template_id = scheduled.template_id
    ) resources;
    -- Si cambió el árbol mientras se esperaba, no se bloquea otra familia de
    -- catálogo en un orden distinto: se exige volver a consultar la pauta.
    if fenced_ids is distinct from resource_ids then raise serialization_failure; end if;
    perform 1 from public.exercises e where e.id in (
      select i.exercise_id from public.workout_items i join public.workout_blocks b on b.id = i.block_id
      where b.template_id = scheduled.template_id
    ) order by e.id for share nowait;
  else
    perform trainer_private.catalog_lock_ids(array[scheduled.template_id]);
    perform 1 from public.workout_templates where id = scheduled.template_id for share;
    if exists (
      select 1 from public.workout_templates t where t.id = scheduled.template_id
        and t.origin = 'user' and t.owner_user_id = p_expected_owner
    ) then raise serialization_failure; end if;
  end if;
  preview := trainer_private.get_scheduled_workout_preview(p_expected_owner, p_scheduled_id);
  if p_expected_revision is null or preview->>'revision' is distinct from p_expected_revision then
    raise exception 'La pauta ha cambiado. Revisa el entrenamiento antes de comenzar.' using errcode = '40001';
  end if;

  -- Se valida la revisión incluso al retomar: otra pantalla podría haber
  -- iniciado una adaptación distinta de la que vio este cliente.
  if scheduled.execution_id is not null then
    if not exists (
      select 1 from public.workout_executions e
      where e.id = scheduled.execution_id and e.user_id = p_expected_owner
        and e.template_id = scheduled.template_id and e.template_version = scheduled.template_version
    ) then raise insufficient_privilege; end if;
    return scheduled.execution_id;
  end if;

  return trainer_private.start_scheduled_workout(p_scheduled_id);
exception when lock_not_available then
  -- Un editor directo puede bloquear las filas en otro orden. Se reconsulta
  -- antes de empezar en vez de mantener un ciclo entre padres e hijos.
  raise exception 'La pauta se está editando. Vuelve a consultar el entrenamiento.' using errcode = '40001';
end;
$$;

create function public.start_reviewed_scheduled_workout(
  p_expected_owner uuid,
  p_scheduled_id uuid,
  p_expected_revision text
) returns uuid
language sql volatile security invoker set search_path = '' as $$
  select trainer_private.start_reviewed_scheduled_workout(p_expected_owner, p_scheduled_id, p_expected_revision);
$$;

revoke all on function trainer_private.get_scheduled_workout_preview(uuid, uuid),
  public.get_scheduled_workout_preview(uuid, uuid),
  trainer_private.start_reviewed_scheduled_workout(uuid, uuid, text),
  public.start_reviewed_scheduled_workout(uuid, uuid, text) from public, anon, authenticated;
grant execute on function trainer_private.get_scheduled_workout_preview(uuid, uuid),
  public.get_scheduled_workout_preview(uuid, uuid),
  trainer_private.start_reviewed_scheduled_workout(uuid, uuid, text),
  public.start_reviewed_scheduled_workout(uuid, uuid, text) to authenticated;

commit;
