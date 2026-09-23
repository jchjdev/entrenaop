-- Prueba de integración en desarrollo. Toda la autoría se revierte.
-- Ejecutar con: supabase db query --linked --file supabase/tests/admin_workout_draft_smoke.sql
begin;

select set_config(
  'request.jwt.claim.sub',
  (select user_id::text from public.admin_permissions limit 1),
  true
);
set local role authenticated;

do $$
declare
  v_program_id text;
  v_template_id uuid;
  v_strength_id uuid;
  v_general_id uuid;
  v_revision_id uuid;
  v_replacement_id uuid;
  v_scheduled_id uuid;
  v_exercise_id uuid;
  v_sets jsonb;
begin
  select id into v_program_id from public.preparation_programs limit 1;
  if v_program_id is null then
    raise exception 'La prueba necesita un programa existente.';
  end if;

  v_template_id := public.create_admin_workout_draft(
    v_program_id,
    jsonb_build_object(
      'name', 'Comprobación temporal de carrera',
      'blocks', jsonb_build_array(
        jsonb_build_object(
          'name', 'Carrera',
          'format', 'running',
          'rounds', 1,
          'rest_after_seconds', 0,
          'exercises', jsonb_build_array(
            jsonb_build_object(
              'exercise_id', '20000000-0000-4000-8000-000000000004',
              'sets', jsonb_build_array(
                jsonb_build_object(
                  'target_distance_meters', 200,
                  'target_pace_min_seconds_per_km', 230,
                  'target_pace_max_seconds_per_km', 230,
                  'rest_after_seconds', 0
                )
              )
            )
          )
        )
      )
    )
  );

  if not exists (
    select 1
    from public.workout_templates as template
    join public.program_workout_templates as link
      on link.template_id = template.id
    where template.id = v_template_id
      and link.program_id = v_program_id
      and template.origin = 'system'
      and template.owner_user_id is null
      and template.visibility = 'private'
      and template.status = 'draft'
  ) then
    raise exception 'La sesión no quedó como borrador oficial vinculado.';
  end if;

  select id into v_exercise_id
  from public.exercises
  where is_public is true
    and id <> '20000000-0000-4000-8000-000000000004'
  limit 1;
  if v_exercise_id is null then
    raise exception 'La prueba necesita un ejercicio público de fuerza.';
  end if;
  v_sets := jsonb_build_array(
    jsonb_build_object('target_reps', 10, 'rest_after_seconds', 0),
    jsonb_build_object('target_reps', 10, 'rest_after_seconds', 0),
    jsonb_build_object('target_reps', 10, 'rest_after_seconds', 0)
  );
  v_strength_id := public.create_admin_workout_draft(
    v_program_id,
    jsonb_build_object(
      'name', 'Comprobación temporal de superserie',
      'blocks', jsonb_build_array(
        jsonb_build_object(
          'name', 'Superserie',
          'format', 'superset',
          'rounds', 3,
          'rest_after_seconds', 60,
          'exercises', jsonb_build_array(
            jsonb_build_object('exercise_id', v_exercise_id, 'sets', v_sets),
            jsonb_build_object('exercise_id', v_exercise_id, 'sets', v_sets)
          )
        )
      )
    )
  );
  if not exists (
    select 1 from public.workout_blocks
    where template_id = v_strength_id
      and format = 'superset'
      and rounds = 3
  ) then
    raise exception 'La superserie no conservó su formato.';
  end if;

  perform public.publish_admin_workout_draft(v_template_id);
  if not exists (
    select 1 from public.workout_templates
    where id = v_template_id
      and visibility = 'private'
      and status = 'published'
  ) then
    raise exception 'La plantilla de programa se filtró a la biblioteca general.';
  end if;

  v_revision_id := public.revise_admin_workout(
    v_template_id,
    jsonb_build_object(
      'name', 'Comprobación temporal de carrera revisada',
      'blocks', jsonb_build_array(jsonb_build_object(
        'name', 'Carrera', 'format', 'running', 'rounds', 1,
        'rest_after_seconds', 0,
        'exercises', jsonb_build_array(jsonb_build_object(
          'exercise_id', '20000000-0000-4000-8000-000000000004',
          'sets', jsonb_build_array(jsonb_build_object(
            'target_distance_meters', 400,
            'target_pace_min_seconds_per_km', 240,
            'target_pace_max_seconds_per_km', 240,
            'rest_after_seconds', 0
          ))
        ))
      ))
    )
  );
  if not exists (
    select 1 from public.workout_templates as new_version
    join public.workout_templates as old_version
      on old_version.id = new_version.previous_version_id
    where new_version.id = v_revision_id
      and old_version.id = v_template_id
      and new_version.family_id = old_version.family_id
      and new_version.version = 2
      and new_version.status = 'draft'
      and old_version.status = 'published'
  ) then
    raise exception 'La revisión publicada perdió su versión o historial.';
  end if;

  v_replacement_id := public.revise_admin_workout(
    v_revision_id,
    jsonb_build_object(
      'name', 'Comprobación temporal de carrera corregida',
      'blocks', jsonb_build_array(jsonb_build_object(
        'name', 'Carrera', 'format', 'running', 'rounds', 1,
        'rest_after_seconds', 0,
        'exercises', jsonb_build_array(jsonb_build_object(
          'exercise_id', '20000000-0000-4000-8000-000000000004',
          'sets', jsonb_build_array(jsonb_build_object(
            'target_distance_meters', 400,
            'target_pace_min_seconds_per_km', 245,
            'target_pace_max_seconds_per_km', 245,
            'rest_after_seconds', 0
          ))
        ))
      ))
    )
  );
  if exists (select 1 from public.workout_templates where id = v_revision_id)
    or not exists (
      select 1 from public.workout_templates
      where id = v_replacement_id and version = 2
        and previous_version_id = v_template_id
    ) then
    raise exception 'La edición del borrador alteró el historial de versiones.';
  end if;
  perform public.remove_admin_workout(v_template_id);
  if not exists (
    select 1 from public.workout_templates
    where id = v_template_id and status = 'archived' and visibility = 'private'
  ) then
    raise exception 'La retirada borró una versión publicada o la dejó visible.';
  end if;

  v_general_id := public.create_admin_workout_draft(
    null,
    jsonb_build_object(
      'name', 'Comprobación temporal general',
      'blocks', jsonb_build_array(jsonb_build_object(
        'name', 'Carrera', 'format', 'running', 'rounds', 1,
        'rest_after_seconds', 0,
        'exercises', jsonb_build_array(jsonb_build_object(
          'exercise_id', '20000000-0000-4000-8000-000000000004',
          'sets', jsonb_build_array(jsonb_build_object(
            'target_distance_meters', 200,
            'target_pace_min_seconds_per_km', 230,
            'target_pace_max_seconds_per_km', 230,
            'rest_after_seconds', 0
          ))
        ))
      ))
    )
  );
  if not exists (
    select 1 from public.program_workout_templates
    where template_id = v_general_id
      and program_id is null and catalog_scope = 'general'
  ) then
    raise exception 'La sesión general quedó asociada a un programa.';
  end if;
  perform public.publish_admin_workout_draft(v_general_id);
  if not exists (
    select 1 from public.workout_templates
    where id = v_general_id
      and visibility = 'public' and status = 'published'
  ) then
    raise exception 'La publicación general no es pública.';
  end if;
  v_scheduled_id := public.schedule_workout(v_general_id, current_date + 1);
  begin
    perform public.remove_admin_workout(v_general_id);
    raise exception 'Se retiró una sesión con cita pendiente.';
  exception
    when invalid_parameter_value then null;
  end;
  if not exists (
    select 1 from public.scheduled_workouts
    where id = v_scheduled_id and status = 'planned'
  ) then
    raise exception 'La cita pendiente no se conservó.';
  end if;

  perform public.remove_admin_workout(v_strength_id);
  if exists (select 1 from public.workout_templates where id = v_strength_id) then
    raise exception 'El borrador no se borró.';
  end if;
end;
$$;

set local role anon;
do $$
begin
  if not exists (
    select 1
    from public.workout_templates as template
    join public.workout_blocks as block on block.template_id = template.id
    where template.name = 'Comprobación temporal general'
      and template.visibility = 'public'
      and template.status = 'published'
  ) then
    raise exception 'La biblioteca pública no puede leer la sesión publicada.';
  end if;
  if exists (
    select 1 from public.workout_templates
    where name = 'Comprobación temporal de carrera'
  ) then
    raise exception 'La sesión de programa es visible para anon.';
  end if;
end;
$$;

rollback;

-- Un usuario autenticado sin permiso administrativo no puede crear contenido.
begin;
select set_config('request.jwt.claim.sub', gen_random_uuid()::text, true);
set local role authenticated;

do $$
begin
  perform public.create_admin_workout_draft(
    (select id from public.preparation_programs limit 1),
    '{}'::jsonb
  );
  raise exception 'Se aceptó una creación sin permiso de administrador.';
exception
  when insufficient_privilege then null;
end;
$$;

do $$
begin
  perform public.publish_admin_workout_draft(gen_random_uuid());
  raise exception 'Se aceptó una publicación sin permiso de administrador.';
exception
  when insufficient_privilege then null;
end;
$$;

do $$
begin
  perform public.remove_admin_workout(gen_random_uuid());
  raise exception 'Se aceptó una retirada sin permiso de administrador.';
exception
  when insufficient_privilege then null;
end;
$$;

do $$
begin
  perform public.revise_admin_workout(gen_random_uuid(), '{}'::jsonb);
  raise exception 'Se aceptó una revisión sin permiso de administrador.';
exception
  when insufficient_privilege then null;
end;
$$;

rollback;
