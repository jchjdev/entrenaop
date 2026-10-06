-- Simulación determinista sin persistir marcas. El deportista todavía no usa
-- borradores: esta función sirve para verificar baremos antes de publicarlos.
begin;

create function public.preview_program_assessment_attempt(
  p_program_id text, p_category text, p_marks jsonb
) returns jsonb
language plpgsql stable security invoker set search_path = ''
as $$
declare
  v_rule public.program_assessment_scoring_rules%rowtype;
  v_expected integer;
  v_item jsonb;
  v_test_id uuid;
  v_test public.program_assessment_tests%rowtype;
  v_seen uuid[] := array[]::uuid[];
  v_mark numeric;
  v_points numeric;
  v_sum numeric := 0;
  v_total numeric;
  v_each_passed boolean := true;
  v_details jsonb := '[]'::jsonb;
begin
  if p_category not in ('men', 'women') then
    raise exception 'Selecciona una columna de baremo válida.'
      using errcode = '22023';
  end if;
  select * into v_rule from public.program_assessment_scoring_rules
  where program_id = p_program_id;
  if not found then
    raise exception 'El programa no tiene regla de puntuación disponible.'
      using errcode = '22023';
  end if;
  select count(*) into v_expected from public.program_assessment_tests
  where program_id = p_program_id and category in ('both', p_category);
  if p_marks is null or pg_catalog.jsonb_typeof(p_marks) <> 'array' then
    raise exception 'Envía las marcas como una lista.' using errcode = '22023';
  end if;
  if v_expected = 0 or pg_catalog.jsonb_array_length(p_marks) <> v_expected then
    raise exception 'Faltan ejercicios o hay marcas de más.'
      using errcode = '22023';
  end if;
  for v_item in select value from pg_catalog.jsonb_array_elements(p_marks)
  loop
    v_test_id := (v_item->>'test_id')::uuid;
    v_mark := (v_item->>'mark')::numeric;
    if v_test_id = any(v_seen) then
      raise exception 'Hay un ejercicio repetido.' using errcode = '22023';
    end if;
    select * into v_test from public.program_assessment_tests
    where id = v_test_id and program_id = p_program_id
      and category in ('both', p_category);
    if not found then
      raise exception 'Ejercicio ajeno al programa o a la columna.'
        using errcode = '22023';
    end if;
    v_points := public.score_program_assessment_mark(
      v_test_id, p_category, v_mark);
    v_seen := pg_catalog.array_append(v_seen, v_test_id);
    v_sum := v_sum + v_points;
    v_each_passed := v_each_passed and
      v_points >= v_rule.min_each_points;
    v_details := v_details || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object(
        'test_id', v_test_id, 'mark', v_mark, 'points', v_points));
  end loop;
  v_total := case when v_rule.aggregation = 'average'
    then v_sum / v_expected else v_sum end;
  return pg_catalog.jsonb_build_object(
    'category', p_category, 'scoring_version', v_rule.scoring_version,
    'aggregation', v_rule.aggregation, 'total', v_total,
    'each_passed', v_each_passed,
    'passed', v_each_passed and v_total >= v_rule.min_aggregate_points,
    'details', v_details);
end;
$$;

revoke all on function public.preview_program_assessment_attempt(
  text,text,jsonb) from public, anon;
grant execute on function public.preview_program_assessment_attempt(
  text,text,jsonb) to authenticated;

commit;
