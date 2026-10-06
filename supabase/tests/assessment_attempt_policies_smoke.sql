-- Intentos nulos y repetición condicionada del circuito CNP. ROLLBACK.
begin;
select set_config('request.jwt.claim.sub',
  (select user_id::text from public.admin_permissions limit 1), true);
set local role authenticated;

do $$
declare
  v_program text;
  v_test public.program_assessment_tests%rowtype;
  v_mark numeric;
  v_agility uuid;
  v_marks jsonb := '[]'::jsonb;
  v_result jsonb;
  v_rejected boolean := false;
begin
  select program_id into v_program
  from public.program_assessment_scoring_rules
  where scoring_version = 'boe_a_2026_15055_anexo_ii_v1';
  if v_program is null then raise exception 'Falta el borrador CNP.'; end if;
  for v_test in select * from public.program_assessment_tests
      where program_id = v_program and category in ('both','men')
      order by display_order loop
    select coalesce(nullif(b.min_mark,0),b.max_mark,v_test.mark_step)
      into v_mark from public.program_assessment_score_bands b
      where b.test_id = v_test.id and b.category = 'men' and b.points = 5
      limit 1;
    if v_mark is null then raise exception 'Falta una marca de prueba.'; end if;
    v_marks := v_marks || jsonb_build_array(jsonb_build_object(
      'test_id',v_test.id,'attempts',
      case when v_test.code = 'agility_circuit' then
        jsonb_build_array(jsonb_build_object('valid',false),
          jsonb_build_object('valid',true,'mark',v_mark))
      else jsonb_build_array(jsonb_build_object('valid',true,'mark',v_mark)) end));
  end loop;
  if not exists (select 1 from public.program_assessment_tests
      where program_id = v_program and code = 'agility_circuit'
        and max_attempts = 2 and retry_policy = 'invalid_only') then
    raise exception 'La agilidad CNP no tiene su política de intentos.';
  end if;
  v_result := public.preview_program_assessment_attempt_v3(v_program,'men',
    '2000-01-01','2026-09-27',null,v_marks);
  if not (v_result->>'passed')::boolean then
    raise exception 'El segundo intento válido no se puntuó: %',v_result;
  end if;
  select id into v_agility from public.program_assessment_tests
    where program_id = v_program and code = 'agility_circuit';
  v_marks := (select jsonb_agg(case when value->>'test_id' = v_agility::text
    then jsonb_set(value,'{attempts}',
      jsonb_build_array(jsonb_build_object('valid',false),
        jsonb_build_object('valid',false))) else value end)
    from jsonb_array_elements(v_marks));
  v_result := public.preview_program_assessment_attempt_v3(v_program,'men',
    '2000-01-01','2026-09-27',null,v_marks);
  if (v_result->>'passed')::boolean or not exists (
    select 1 from jsonb_array_elements(v_result->'details') d
    where d->>'test_id' = v_agility::text and d->>'points' = '0'
      and d->'mark' = 'null'::jsonb) then
    raise exception 'Los dos intentos nulos no eliminaron la prueba: %',v_result;
  end if;
  v_marks := (select jsonb_agg(case when value->>'test_id' = v_agility::text
    then jsonb_set(value,'{attempts}',jsonb_build_array(
      jsonb_build_object('valid',true,'mark',10),
      jsonb_build_object('valid',true,'mark',9))) else value end)
    from jsonb_array_elements(v_marks));
  begin
    perform public.preview_program_assessment_attempt_v3(v_program,'men',
      '2000-01-01','2026-09-27',null,v_marks);
  exception when sqlstate '22023' then v_rejected := true;
  end;
  if not v_rejected then
    raise exception 'Se aceptó repetir después de un intento válido.';
  end if;
end;
$$;
rollback;
