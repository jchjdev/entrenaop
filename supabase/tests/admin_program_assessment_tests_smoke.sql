-- Autoría de pruebas de un borrador. No deja datos en desarrollo.
-- supabase db query --linked --file supabase/tests/admin_program_assessment_tests_smoke.sql
begin;

select set_config('request.jwt.claim.sub',
  (select user_id::text from public.admin_permissions limit 1), true);
set local role authenticated;

do $$
declare
  v_program_id text;
  v_test_id uuid;
  v_other uuid := gen_random_uuid();
  v_rejected boolean;
begin
  v_program_id := public.create_admin_preparation_program(
    'Programa temporal de pruebas', 'access'
  );
  v_test_id := public.create_admin_program_assessment_test_v2(
    v_program_id, 'carrera_1000_m', 'Carrera 1.000 m', 'seconds', 'lower',
    'Recorrer 1.000 metros en pista según el protocolo revisado.',
    'both', 'run_1000', 1, 1
  );
  if not exists (
    select 1 from public.program_assessment_tests
    where id = v_test_id and program_id = v_program_id
      and definition_version = 1
  ) then
    raise exception 'No se guardó la prueba del programa.';
  end if;

  perform set_config('request.jwt.claim.sub', v_other::text, true);
  if exists (
    select 1 from public.program_assessment_tests where id = v_test_id
  ) then
    raise exception 'Un deportista leyó una prueba de borrador.';
  end if;
  v_rejected := false;
  begin
    perform public.create_admin_program_assessment_test_v2(
      v_program_id, 'salto', 'Salto', 'meters', 'higher',
      'Registrar distancia en el protocolo oficial.',
      'both', 'jump', 2, 0.01
    );
  exception when insufficient_privilege then
    v_rejected := true;
  end;
  if not v_rejected then
    raise exception 'Un usuario sin permiso creó una prueba.';
  end if;
end;
$$;

rollback;
