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
      and visibility = 'public'
      and status = 'published'
  ) then
    raise exception 'La publicación no hizo visible la plantilla.';
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
    where template.name = 'Comprobación temporal de carrera'
      and template.visibility = 'public'
      and template.status = 'published'
  ) then
    raise exception 'La biblioteca pública no puede leer la sesión publicada.';
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

rollback;
