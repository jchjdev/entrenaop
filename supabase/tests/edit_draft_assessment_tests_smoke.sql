-- Edición, borrado y permisos del baremo. Todo se revierte.
begin;

select set_config('request.jwt.claim.sub',
  (select user_id::text from public.admin_permissions limit 1), true);
set local role authenticated;

do $$
declare
  v_program text;
  v_test uuid;
  v_band uuid;
  v_rejected boolean;
  v_admin text := current_setting('request.jwt.claim.sub');
begin
  v_program := public.create_admin_preparation_program('Edición temporal baremo', 'access');
  perform public.save_admin_program_scoring_rule(v_program, 'test_v1',
    'https://www.boe.es', 'Baremo de prueba', 'average', 10, 1, 5);
  v_test := public.create_admin_program_assessment_test_v2(v_program,
    'carrera_1000', 'Carrera 1.000 m', 'seconds', 'lower',
    'Correr la distancia medida.', 'both', 'carrera', 1, 1);
  v_band := public.add_admin_program_score_band(v_test, 'men', 220, 230, 1);

  perform set_config('request.jwt.claim.sub', gen_random_uuid()::text, true);
  v_rejected := false;
  begin
    perform public.delete_admin_program_assessment_test(v_test);
  exception when sqlstate '42501' then v_rejected := true;
  end;
  perform set_config('request.jwt.claim.sub', v_admin, true);
  if not v_rejected then raise exception 'Una cuenta no administradora pudo borrar la prueba.'; end if;

  perform public.update_admin_program_assessment_test(v_test, 'Carrera de 1.000 m',
    'seconds', 'lower', 'Salida de pie y cronometraje manual.', 'both', 1, 1);
  if (select name from public.program_assessment_tests where id = v_test)
      <> 'Carrera de 1.000 m' then
    raise exception 'No se actualizó el nombre.';
  end if;

  v_rejected := false;
  begin
    perform public.update_admin_program_assessment_test(v_test, 'Carrera',
      'meters', 'higher', 'Medir distancia.', 'both', 1, 1);
  exception when sqlstate '22023' then v_rejected := true;
  end;
  if not v_rejected then raise exception 'Se cambió la medición sin confirmar el borrado.'; end if;
  if not exists (select 1 from public.program_assessment_score_bands where id = v_band) then
    raise exception 'El intento fallido borró el baremo.';
  end if;

  v_rejected := false;
  begin
    perform public.update_admin_program_score_band(v_band, 'women', 220, 230, 11);
  exception when sqlstate '22023' then v_rejected := true;
  end;
  if not v_rejected then raise exception 'Se permitió superar el máximo de puntos.'; end if;
  perform public.update_admin_program_score_band(v_band, 'men', 225, 235, 2);
  if public.score_program_assessment_mark(v_test, 'men', 230) <> 2 then
    raise exception 'No se aplicó el tramo editado.';
  end if;

  perform public.update_admin_program_assessment_test(v_test, 'Carrera',
    'meters', 'higher', 'Medir distancia.', 'both', 1, 1, true);
  if exists (select 1 from public.program_assessment_score_bands where test_id = v_test) then
    raise exception 'El cambio de medición conservó tramos incompatibles.';
  end if;
  perform public.add_admin_program_score_band(v_test, 'men', 200, null, 10);
  perform public.delete_admin_program_assessment_test(v_test);
  if exists (select 1 from public.program_assessment_tests where id = v_test) or
     exists (select 1 from public.program_assessment_score_bands where test_id = v_test) then
    raise exception 'El borrado dejó prueba o tramos.';
  end if;
end;
$$;

rollback;
