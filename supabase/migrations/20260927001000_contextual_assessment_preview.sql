-- Resolución y simulación de una evaluación contextual. No persiste marcas.
begin;

create function public.assessment_age_on_date(p_birth_date date, p_on_date date)
returns integer language plpgsql immutable set search_path = ''
as $$
begin
  if p_birth_date is null or p_on_date is null or p_birth_date > p_on_date then
    raise exception 'Fecha de nacimiento o referencia inválida.' using errcode = '22023';
  end if;
  return date_part('year', age(p_on_date, p_birth_date))::integer;
end;
$$;

create function public.resolve_program_assessment_tests_v2(
  p_program_id text, p_category text, p_birth_date date,
  p_assessed_on date, p_reference_on date
) returns jsonb language plpgsql stable security definer set search_path = ''
as $$
declare
  v_rule public.program_assessment_scoring_rules%rowtype;
  v_age integer;
  v_date date;
  v_tests jsonb;
begin
  if (select auth.uid()) is null then
    raise exception 'Inicia sesión para consultar la evaluación.' using errcode = '42501';
  end if;
  if not (select public.is_admin()) and not exists (
    select 1 from public.preparation_programs p
    where p.id = p_program_id and p.enabled) then
    raise exception 'Evaluación no disponible.' using errcode = '42501';
  end if;
  if p_category not in ('men','women') then
    raise exception 'Selecciona la columna H o M.' using errcode = '22023';
  end if;
  select * into v_rule from public.program_assessment_scoring_rules
  where program_id = p_program_id;
  if not found then
    raise exception 'Falta la regla de evaluación.' using errcode = '22023';
  end if;
  if p_assessed_on is null or
     v_rule.effective_on is not null and p_assessed_on < v_rule.effective_on or
     v_rule.expires_on is not null and p_assessed_on > v_rule.expires_on then
    raise exception 'La fecha no corresponde a esta versión del baremo.'
      using errcode = '22023';
  end if;
  v_date := case v_rule.age_reference
    when 'reference_date' then p_reference_on
    else p_assessed_on end;
  if v_rule.age_reference = 'calendar_year' then
    if p_birth_date is null or p_birth_date > p_assessed_on then
      raise exception 'Fecha de nacimiento inválida.' using errcode = '22023';
    end if;
    v_age := extract(year from p_assessed_on)::integer -
      extract(year from p_birth_date)::integer;
  else
    v_age := public.assessment_age_on_date(p_birth_date, v_date);
  end if;
  if v_age < 0 or v_age > 120 then
    raise exception 'Edad fuera del baremo.' using errcode = '22023';
  end if;
  select coalesce(jsonb_agg(jsonb_build_object(
    'test_id', t.id, 'name', t.name, 'unit', t.unit,
    'better_direction', t.better_direction,
    'mark_step', t.mark_step, 'display_order', t.display_order,
    'protocol_notes', t.protocol_notes) order by t.display_order), '[]'::jsonb)
  into v_tests from public.program_assessment_tests t
  where t.program_id = p_program_id and t.category in ('both',p_category)
    and v_age between t.min_age and t.max_age;
  return jsonb_build_object(
    'program_id', p_program_id, 'scoring_version', v_rule.scoring_version,
    'source_url', v_rule.source_url, 'stage_label', v_rule.stage_label,
    'scoring_mode', v_rule.scoring_mode, 'aggregation', v_rule.aggregation,
    'category', p_category, 'age', v_age, 'tests', v_tests);
end;
$$;

create function public.preview_program_assessment_attempt_v2(
  p_program_id text, p_category text, p_birth_date date,
  p_assessed_on date, p_reference_on date, p_marks jsonb
) returns jsonb language plpgsql stable security definer set search_path = ''
as $$
declare
  v_context jsonb;
  v_rule public.program_assessment_scoring_rules%rowtype;
  v_age integer;
  v_expected integer;
  v_entry jsonb;
  v_test public.program_assessment_tests%rowtype;
  v_seen uuid[] := array[]::uuid[];
  v_mark numeric;
  v_count integer;
  v_points numeric;
  v_threshold numeric;
  v_margin numeric;
  v_test_passed boolean;
  v_all_passed boolean := true;
  v_sum numeric := 0;
  v_total numeric;
  v_details jsonb := '[]'::jsonb;
begin
  v_context := public.resolve_program_assessment_tests_v2(
    p_program_id,p_category,p_birth_date,p_assessed_on,p_reference_on);
  v_age := (v_context->>'age')::integer;
  select * into v_rule from public.program_assessment_scoring_rules
  where program_id = p_program_id;
  v_expected := jsonb_array_length(v_context->'tests');
  if p_marks is null or jsonb_typeof(p_marks) <> 'array' or
     v_expected = 0 or jsonb_array_length(p_marks) <> v_expected then
    raise exception 'Faltan pruebas aplicables o hay marcas de más.'
      using errcode = '22023';
  end if;
  for v_entry in select value from jsonb_array_elements(p_marks) loop
    if v_entry->>'test_id' is null then
      raise exception 'Cada marca necesita una prueba.' using errcode = '22023';
    end if;
    if (v_entry->>'test_id')::uuid = any(v_seen) then
      raise exception 'Prueba repetida.' using errcode = '22023';
    end if;
    select * into v_test from public.program_assessment_tests t
    where t.id = (v_entry->>'test_id')::uuid
      and t.program_id = p_program_id
      and t.category in ('both',p_category)
      and v_age between t.min_age and t.max_age;
    if not found then
      raise exception 'Prueba ajena o no aplicable.' using errcode = '22023';
    end if;
    v_seen := array_append(v_seen, v_test.id);
    v_mark := (v_entry->>'mark')::numeric;
    if v_mark is null or v_mark < 0 or
       (v_test.unit in ('seconds','meters') and v_mark = 0) or
       mod(v_mark,v_test.mark_step) <> 0 then
      raise exception 'Marca inválida para %.', v_test.name using errcode = '22023';
    end if;
    v_points := null;
    v_threshold := null;
    v_margin := null;
    if v_rule.scoring_mode = 'pass_fail' then
      select count(*), max(s.threshold) into v_count, v_threshold
      from public.program_assessment_pass_standards s
      where s.test_id = v_test.id and s.category = p_category
        and v_age between s.min_age and s.max_age;
      if v_count <> 1 then
        raise exception 'Falta un mínimo único para % y % años.',
          v_test.name, v_age using errcode = '22023';
      end if;
      v_margin := case v_test.better_direction
        when 'higher' then v_mark - v_threshold
        else v_threshold - v_mark end;
      v_test_passed := v_margin >= 0;
    else
      select count(*), max(b.points) into v_count, v_points
      from public.program_assessment_score_bands b
      where b.test_id = v_test.id and b.category = p_category
        and v_age between b.min_age and b.max_age
        and (b.min_mark is null or v_mark >= b.min_mark)
        and (b.max_mark is null or v_mark <= b.max_mark);
      if v_count <> 1 then
        raise exception 'Falta un tramo único para % y % años.',
          v_test.name, v_age using errcode = '22023';
      end if;
      if v_test.better_direction = 'higher' then
        select min(b.min_mark) into v_threshold
        from public.program_assessment_score_bands b
        where b.test_id = v_test.id and b.category = p_category
          and v_age between b.min_age and b.max_age
          and b.points >= v_rule.min_each_points;
        v_margin := v_mark - v_threshold;
      else
        select max(b.max_mark) into v_threshold
        from public.program_assessment_score_bands b
        where b.test_id = v_test.id and b.category = p_category
          and v_age between b.min_age and b.max_age
          and b.points >= v_rule.min_each_points;
        v_margin := v_threshold - v_mark;
      end if;
      v_test_passed := v_points >= v_rule.min_each_points;
      v_sum := v_sum + v_points;
    end if;
    v_all_passed := v_all_passed and v_test_passed;
    v_details := v_details || jsonb_build_array(jsonb_build_object(
      'test_id',v_test.id,'name',v_test.name,'mark',v_mark,
      'points',v_points,'minimum_mark',v_threshold,
      'margin',v_margin,'passed',v_test_passed));
  end loop;
  v_total := case when v_rule.scoring_mode = 'pass_fail' or
                       v_rule.aggregation = 'none' then null
    when v_rule.aggregation = 'average' then v_sum / v_expected
    else v_sum end;
  return jsonb_build_object(
    'program_id',p_program_id,'scoring_version',v_rule.scoring_version,
    'scoring_mode',v_rule.scoring_mode,'aggregation',v_rule.aggregation,
    'category',p_category,'age',v_age,
    'total',v_total,'each_passed',v_all_passed,
    'passed',v_all_passed and
      (v_total is null or v_total >= v_rule.min_aggregate_points),
    'details',v_details);
end;
$$;

revoke all on function public.assessment_age_on_date(date,date)
from public, anon;
grant execute on function public.assessment_age_on_date(date,date)
to authenticated;
revoke all on function public.resolve_program_assessment_tests_v2(
  text,text,date,date,date) from public, anon;
grant execute on function public.resolve_program_assessment_tests_v2(
  text,text,date,date,date) to authenticated;
revoke all on function public.preview_program_assessment_attempt_v2(
  text,text,date,date,date,jsonb) from public, anon;
grant execute on function public.preview_program_assessment_attempt_v2(
  text,text,date,date,date,jsonb) to authenticated;

commit;
