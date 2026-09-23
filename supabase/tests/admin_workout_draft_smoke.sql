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

rollback;
