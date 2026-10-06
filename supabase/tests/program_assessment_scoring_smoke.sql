-- Autoría y puntuación de borradores; termina sin datos persistentes.
-- supabase db query --linked --file supabase/tests/program_assessment_scoring_smoke.sql
begin;

select set_config('request.jwt.claim.sub',
  (select user_id::text from public.admin_permissions limit 1), true);
set local role authenticated;

do $$
declare
  v_program text;
  v_men uuid;
  v_women uuid;
  v_agility uuid;
  v_band uuid;
  v_result jsonb;
  v_other uuid := gen_random_uuid();
  v_rejected boolean;
begin
  v_program := public.create_admin_preparation_program(
    'Borrador temporal baremos', 'access');
  perform public.save_admin_program_scoring_rule(
    v_program, 'boe_cnp_2026_v1',
    'https://www.boe.es/buscar/doc.php?id=BOE-A-2026-15055',
    'BOE-A-2026-15055, anexo II', 'average', 10, 1, 5);

  v_men := public.create_admin_program_assessment_test_v2(
    v_program, 'dominadas_h', 'Dominadas', 'repetitions', 'higher',
    'Dominadas estrictas según anexo II.', 'men', 'barra', 2, 1);
  v_women := public.create_admin_program_assessment_test_v2(
    v_program, 'suspension_m', 'Suspensión en barra', 'seconds', 'higher',
    'Suspensión con agarre supino según anexo II.', 'women', 'barra', 2, 1);
  v_agility := public.create_admin_program_assessment_test_v2(
    v_program, 'agilidad', 'Circuito de agilidad', 'seconds', 'lower',
    'Circuito de agilidad según anexo II.', 'both', 'agilidad', 1, 0.1);
  perform public.add_admin_program_score_band(v_men, 'men', null, 4, 0);
  perform public.add_admin_program_score_band(v_men, 'men', 5, 5, 1);
  perform public.add_admin_program_score_band(v_men, 'men', 17, null, 10);
  perform public.add_admin_program_score_band(v_women, 'women', null, 35, 0);
  perform public.add_admin_program_score_band(v_women, 'women', 36, 40, 1);
  perform public.add_admin_program_score_band(v_women, 'women', 95, null, 10);
  perform public.add_admin_program_score_band(v_agility, 'men', null, 8.2, 10);
  perform public.add_admin_program_score_band(v_agility, 'men', 11.7, null, 0);
  perform public.add_admin_program_score_band(v_agility, 'women', null, 9.3, 10);
  perform public.add_admin_program_score_band(v_agility, 'women', 12.8, null, 0);

  if public.score_program_assessment_mark(v_men, 'men', 5) <> 1 or
     public.score_program_assessment_mark(v_women, 'women', 36) <> 1 or
     public.score_program_assessment_mark(v_men, 'men', 18) <> 10 then
    raise exception 'El baremo no asignó los puntos esperados.';
  end if;

  v_rejected := false;
  begin
    perform public.add_admin_program_score_band(v_men, 'men', 4, 6, 2);
  exception when others then
    if sqlstate <> '22023' then raise; end if;
    v_rejected := true;
  end;
  if not v_rejected then
    raise exception 'Se permitió solapar tramos de puntuación.';
  end if;

  v_band := public.add_admin_program_score_band(v_men, 'men', 6, 6, 2);
  perform public.delete_admin_program_score_band(v_band);
  if exists (select 1 from public.program_assessment_score_bands
    where id = v_band) then
    raise exception 'No se quitó el tramo del borrador.';
  end if;
  v_rejected := false;
  begin
    perform public.save_admin_program_scoring_rule(
      v_program, 'boe_cnp_2026_v1',
      'https://www.boe.es/buscar/doc.php?id=BOE-A-2026-15055',
      'BOE-A-2026-15055, anexo II', 'average', 5, 1, 5);
  exception when others then
    if sqlstate <> '22023' then raise; end if;
    v_rejected := true;
  end;
  if not v_rejected then
    raise exception 'Se redujo el máximo por debajo de un tramo existente.';
  end if;

  v_rejected := false;
  begin
    perform public.score_program_assessment_mark(v_men, 'women', 5);
  exception when others then
    if sqlstate <> '22023' then raise; end if;
    v_rejected := true;
  end;
  if not v_rejected then
    raise exception 'Se aplicó el ejercicio H a la columna M.';
  end if;

  v_result := public.preview_program_assessment_attempt(v_program, 'men',
    jsonb_build_array(
      jsonb_build_object('test_id', v_agility, 'mark', 11.7),
      jsonb_build_object('test_id', v_men, 'mark', 17)));
  if (v_result->>'total')::numeric <> 5 or
     (v_result->>'each_passed')::boolean or
     (v_result->>'passed')::boolean then
    raise exception 'Un cero no eliminó pese a media de cinco.';
  end if;
  v_result := public.preview_program_assessment_attempt(v_program, 'women',
    jsonb_build_array(
      jsonb_build_object('test_id', v_agility, 'mark', 9.3),
      jsonb_build_object('test_id', v_women, 'mark', 95)));
  if (v_result->>'total')::numeric <> 10 or
     not (v_result->>'passed')::boolean then
    raise exception 'La simulación M no aplicó media y mínimo.';
  end if;

  perform set_config('request.jwt.claim.sub', v_other::text, true);
  if exists (select 1 from public.program_assessment_score_bands
    where test_id = v_men) then
    raise exception 'Se leyeron baremos de un borrador ajeno.';
  end if;
  v_rejected := false;
  begin
    perform public.add_admin_program_score_band(v_men, 'men', 6, 6, 2);
  exception when insufficient_privilege then
    v_rejected := true;
  end;
  if not v_rejected then
    raise exception 'Un usuario sin permiso añadió un tramo.';
  end if;
end;
$$;

rollback;
