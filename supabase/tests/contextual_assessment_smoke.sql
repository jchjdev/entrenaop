-- El creador ADMIN permite mínimos y puntos por columna y edad.
-- No deja datos: supabase db query --linked --file supabase/tests/contextual_assessment_smoke.sql
begin;

select set_config('request.jwt.claim.sub',
  (select user_id::text from public.admin_permissions limit 1), true);
set local role authenticated;

do $$
declare
  v_program text;
  v_test uuid;
  v_standard uuid;
  v_points_program text;
  v_points_test uuid;
  v_result jsonb;
  v_rejected boolean;
  v_other uuid := gen_random_uuid();
begin
  v_program := public.create_admin_preparation_program('Temporal mínimos por edad', 'access');
  perform public.save_admin_program_scoring_rule_v2(v_program, 'temporal_v1',
    'https://www.boe.es/', 'Convocatoria temporal', 'pass_fail', 'none',
    1, 0, 0, 'assessment_date', 'Ingreso', null, null);
  v_test := public.create_admin_program_assessment_test_v3(v_program,
    'carrera', 'Carrera', 'seconds', 'lower', 'Circuito medido en segundos.',
    'both', 'carrera', 1, 1, 18, 60);
  v_standard := public.save_admin_program_pass_standard(v_test, null,
    'men', 18, 34, 300);
  perform public.save_admin_program_pass_standard(v_test, null,
    'men', 35, 60, 320);
  perform public.save_admin_program_pass_standard(v_test, null,
    'women', 18, 60, 360);

  v_result := public.preview_program_assessment_attempt_v2(v_program, 'men',
    '1992-09-28', '2026-09-27', null,
    jsonb_build_array(jsonb_build_object('test_id', v_test, 'mark', 310)));
  if (v_result->>'age')::integer <> 33 or
     (v_result->>'passed')::boolean or
     (v_result->'details'->0->>'minimum_mark')::numeric <> 300 then
    raise exception 'El mínimo H menor de 35 no se aplicó.';
  end if;
  v_result := public.preview_program_assessment_attempt_v2(v_program, 'men',
    '1991-09-27', '2026-09-27', null,
    jsonb_build_array(jsonb_build_object('test_id', v_test, 'mark', 310)));
  if (v_result->>'age')::integer <> 35 or
     not (v_result->>'passed')::boolean or
     (v_result->'details'->0->>'minimum_mark')::numeric <> 320 then
    raise exception 'El mínimo H desde 35 no se aplicó.';
  end if;
  v_result := public.preview_program_assessment_attempt_v2(v_program, 'women',
    '1991-09-27', '2026-09-27', null,
    jsonb_build_array(jsonb_build_object('test_id', v_test, 'mark', 350)));
  if not (v_result->>'passed')::boolean or
     (v_result->'details'->0->>'minimum_mark')::numeric <> 360 then
    raise exception 'El mínimo M no se aplicó.';
  end if;
  v_rejected := false;
  begin
    perform public.save_admin_program_pass_standard(v_test, null,
      'men', 30, 40, 300);
  exception when sqlstate '22023' then v_rejected := true;
  end;
  if not v_rejected then raise exception 'Se admitieron edades solapadas.'; end if;
  v_points_program := public.create_admin_preparation_program('Temporal puntos por edad', 'access');
  perform public.save_admin_program_scoring_rule_v2(v_points_program, 'puntos_v1',
    'https://www.boe.es/', 'Convocatoria temporal', 'points', 'none',
    10, 1, 0, 'calendar_year', 'Evaluación periódica', null, null);
  v_points_test := public.create_admin_program_assessment_test_v3(v_points_program,
    'salto', 'Salto', 'meters', 'higher', 'Salto medido en metros.',
    'both', 'salto', 1, 1, 18, 60);
  perform public.save_admin_program_score_band_v2(v_points_test, null,
    'men', 18, 34, 0, 1, 0);
  perform public.save_admin_program_score_band_v2(v_points_test, null,
    'men', 18, 34, 2, null, 5);
  perform public.save_admin_program_score_band_v2(v_points_test, null,
    'men', 35, 60, 0, 1, 0);
  perform public.save_admin_program_score_band_v2(v_points_test, null,
    'men', 35, 60, 2, null, 8);
  v_result := public.preview_program_assessment_attempt_v2(v_points_program,
    'men', '1991-12-31', '2026-09-27', null,
    jsonb_build_array(jsonb_build_object('test_id', v_points_test, 'mark', 2)));
  if (v_result->>'age')::integer <> 35 or
     (v_result->'details'->0->>'points')::numeric <> 8 or
     not (v_result->>'passed')::boolean then
    raise exception 'Puntos por edad de año natural no aplicados.';
  end if;
  perform public.delete_admin_program_pass_standard(v_standard);
  if exists (select 1 from public.program_assessment_pass_standards
      where id = v_standard) then
    raise exception 'No se borró el mínimo.';
  end if;
  perform set_config('request.jwt.claim.sub', v_other::text, true);
  v_rejected := false;
  begin
    perform public.save_admin_program_pass_standard(v_test, null,
      'men', 18, 34, 300);
  exception when insufficient_privilege then v_rejected := true;
  end;
  if not v_rejected then
    raise exception 'Un usuario sin permiso editó los mínimos.';
  end if;
end;
$$;

rollback;
