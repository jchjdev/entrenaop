-- Asociación tipada y versionada entre prueba y módulo. Todo se revierte.
begin;

select set_config('request.jwt.claim.sub',
  (select user_id::text from public.admin_permissions limit 1), true);
set local role authenticated;

do $$
declare
  v_program text;
  v_test uuid;
  v_other uuid;
  v_rejected boolean;
  v_admin text := current_setting('request.jwt.claim.sub');
begin
  v_program := public.create_admin_preparation_program(
    'Módulo de carrera temporal', 'access');
  perform public.save_admin_program_scoring_rule(
    v_program, 'module_test_v1', 'https://www.boe.es',
    'Fuente temporal', 'average', 10, 1, 5);
  v_test := public.create_admin_program_assessment_test_v5(
    v_program, 'run_2000', 'Carrera 2.000 m', 'seconds', 'lower',
    'Carrera continua cronometrada desde salida de pie.', 'both',
    'carrera', 1, 1, 18, 60, 1, 'none', 2000, 'run_2000m_v1');
  v_other := public.create_admin_program_assessment_test_v5(
    v_program, 'run_1000', 'Carrera 1.000 m', 'seconds', 'lower',
    'Carrera cronometrada desde salida de pie.', 'both',
    'carrera_1000', 2, 1, 18, 60, 1, 'none', 1000, null);

  v_rejected := false;
  begin
    perform public.set_admin_program_training_module(v_other, 'running_2000m_v1');
  exception when sqlstate '22023' then v_rejected := true;
  end;
  if not v_rejected then raise exception 'Se vinculó una prueba de 1 km.'; end if;

  v_rejected := false;
  begin
    perform public.create_admin_program_assessment_test_v5(
      v_program, 'fake_protocol', 'Carrera falsa', 'seconds', 'lower',
      'Medición incompatible declarada.', 'both', 'fake', 3, 1,
      18, 60, 1, 'none', 1000, 'run_2000m_v1');
  exception when check_violation then v_rejected := true;
  end;
  if not v_rejected then raise exception 'Se aceptó un protocolo de 2 km con 1 km.'; end if;

  perform set_config('request.jwt.claim.sub', gen_random_uuid()::text, true);
  v_rejected := false;
  begin
    perform public.set_admin_program_training_module(v_test, 'running_2000m_v1');
  exception when sqlstate '42501' then v_rejected := true;
  end;
  perform set_config('request.jwt.claim.sub', v_admin, true);
  if not v_rejected then raise exception 'Una cuenta no administradora vinculó el módulo.'; end if;

  perform public.set_admin_program_training_module(v_test, 'running_2000m_v1');
  if not exists (select 1 from public.program_training_modules
      where test_id = v_test and program_id = v_program
        and module_key = 'running_2000m_v1') then
    raise exception 'No se guardó la asociación.';
  end if;

  v_rejected := false;
  begin
    perform public.update_admin_program_assessment_test_v5(
      v_test, 'Carrera 2.000 m', 'seconds', 'lower',
      'Carrera continua cronometrada desde salida de pie.', 'both',
      1, 1, 18, 60, false, 1, 'none', 1000, null);
  exception when sqlstate '22023' then v_rejected := true;
  end;
  if not v_rejected then raise exception 'Se alteró una medición vinculada.'; end if;
  perform set_config('test.training_program', v_program, true);
  perform set_config('test.training_test', v_test::text, true);
end;
$$;

-- Publicación simulada para probar la inmutabilidad y la copia. No deja datos.
reset role;
update public.preparation_programs set enabled = true
where id = current_setting('test.training_program');
set local role authenticated;

do $$
declare
  v_program text := current_setting('test.training_program');
  v_test uuid := current_setting('test.training_test')::uuid;
  v_rejected boolean := false;
  v_clone text;
begin
  begin
    perform public.set_admin_program_training_module(v_test, null);
  exception when sqlstate '22023' then v_rejected := true;
  end;
  if not v_rejected then raise exception 'Se desvinculó un módulo publicado.'; end if;
  v_clone := public.clone_admin_program_assessment_version_v2(
    v_program, 'Copia temporal módulo', 'module_test_v2');
  if not exists (
    select 1 from public.program_training_modules m
    join public.program_assessment_tests t on t.id = m.test_id
    where m.program_id = v_clone and t.distance_meters = 2000
      and t.measurement_protocol = 'run_2000m_v1'
      and m.module_key = 'running_2000m_v1'
  ) then
    raise exception 'La nueva versión perdió la asociación o el protocolo.';
  end if;
end;
$$;

rollback;
