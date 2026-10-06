-- Contraste de extremos del anexo II de BOE-A-2026-15055; sin datos nuevos.
-- supabase db query --linked --file supabase/tests/cnp_2026_scoring_smoke.sql
begin;

select set_config('request.jwt.claim.sub',
  (select user_id::text from public.admin_permissions limit 1), true);
set local role authenticated;

do $$
declare
  v_program text;
  v_agility uuid;
  v_pullups uuid;
  v_hang uuid;
  v_run uuid;
  v_result jsonb;
  v_rejected boolean;
begin
  select id into v_program from public.preparation_programs
  where id = 'police_national_basic_2026' or name = 'CNP'
  order by (id = 'police_national_basic_2026') desc limit 1;
  if v_program is null then raise exception 'Falta el borrador CNP.'; end if;
  if jsonb_array_length(public.admin_program_assessment_issues_v3(v_program)) <> 0 then
    raise exception 'El baremo CNP no supera la validación previa a publicar.';
  end if;
  if (select count(*) from public.program_assessment_tests
      where program_id = v_program) <> 4 or
     (select count(*) from public.program_assessment_score_bands b
      join public.program_assessment_tests t on t.id = b.test_id
      where t.program_id = v_program) <> 66 then
    raise exception 'El anexo CNP no tiene cuatro variantes y 66 tramos.';
  end if;
  select id into v_agility from public.program_assessment_tests
    where program_id = v_program and code = 'agility_circuit';
  select id into v_pullups from public.program_assessment_tests
    where program_id = v_program and code = 'pull_ups_men';
  select id into v_hang from public.program_assessment_tests
    where program_id = v_program and code = 'bar_hang_women';
  select id into v_run from public.program_assessment_tests
    where program_id = v_program and code = 'run_1000_m';

  if public.score_program_assessment_mark(v_agility,'men',11.7) <> 0 or
     public.score_program_assessment_mark(v_agility,'men',11.6) <> 1 or
     public.score_program_assessment_mark(v_agility,'men',8.2) <> 10 or
     public.score_program_assessment_mark(v_agility,'women',12.8) <> 0 or
     public.score_program_assessment_mark(v_agility,'women',12.7) <> 1 or
     public.score_program_assessment_mark(v_agility,'women',9.3) <> 10 or
     public.score_program_assessment_mark(v_pullups,'men',4) <> 0 or
     public.score_program_assessment_mark(v_pullups,'men',5) <> 1 or
     public.score_program_assessment_mark(v_pullups,'men',17) <> 10 or
     public.score_program_assessment_mark(v_hang,'women',35) <> 0 or
     public.score_program_assessment_mark(v_hang,'women',36) <> 1 or
     public.score_program_assessment_mark(v_hang,'women',95) <> 10 or
     public.score_program_assessment_mark(v_run,'men',229) <> 0 or
     public.score_program_assessment_mark(v_run,'men',228) <> 1 or
     public.score_program_assessment_mark(v_run,'men',174) <> 10 or
     public.score_program_assessment_mark(v_run,'women',286) <> 0 or
     public.score_program_assessment_mark(v_run,'women',285) <> 1 or
     public.score_program_assessment_mark(v_run,'women',204) <> 10 then
    raise exception 'Algún extremo del anexo II puntúa mal.';
  end if;

  v_rejected := false;
  begin
    perform public.score_program_assessment_mark(v_run, 'men', 0);
  exception when others then
    if sqlstate <> '22023' then raise; end if;
    v_rejected := true;
  end;
  if not v_rejected then
    raise exception 'Cero segundos puntuó como carrera perfecta.';
  end if;

  v_result := public.preview_program_assessment_attempt(v_program, 'men',
    jsonb_build_array(
      jsonb_build_object('test_id',v_agility,'mark',11.7),
      jsonb_build_object('test_id',v_pullups,'mark',17),
      jsonb_build_object('test_id',v_run,'mark',174)));
  if (v_result->>'passed')::boolean then
    raise exception 'Se aprobó un cero con media superior a cinco.';
  end if;
  v_result := public.preview_program_assessment_attempt(v_program, 'women',
    jsonb_build_array(
      jsonb_build_object('test_id',v_agility,'mark',9.3),
      jsonb_build_object('test_id',v_hang,'mark',95),
      jsonb_build_object('test_id',v_run,'mark',204)));
  if not (v_result->>'passed')::boolean or
     (v_result->>'total')::numeric <> 10 then
    raise exception 'No se aprobó el caso de máximas marcas M.';
  end if;
end;
$$;

rollback;
