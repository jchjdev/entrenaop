-- Repeticiones válidas/nulas configurables por prueba y cálculo autoritativo.
begin;

alter table public.program_assessment_tests
  add column max_attempts integer not null default 1
    check (max_attempts between 1 and 5),
  add column retry_policy text not null default 'none'
    check (retry_policy in ('none','invalid_only','always')),
  add constraint program_test_attempt_policy_check check (
    (max_attempts = 1 and retry_policy = 'none') or
    (max_attempts > 1 and retry_policy <> 'none'));

-- El borrador CNP es el único catálogo cargado que requiere repetición por nulo.
update public.program_assessment_tests
set max_attempts = 2, retry_policy = 'invalid_only'
where program_id = 'police_national_basic_2026' and code = 'agility_circuit';

create function public.create_admin_program_assessment_test_v4(
  p_program_id text, p_code text, p_name text, p_unit text,
  p_better_direction text, p_protocol_notes text, p_category text,
  p_group_code text, p_display_order integer, p_mark_step numeric,
  p_min_age integer, p_max_age integer,
  p_max_attempts integer, p_retry_policy text
) returns uuid language plpgsql security definer set search_path = ''
as $$
declare v_id uuid;
begin
  v_id := public.create_admin_program_assessment_test_v3(
    p_program_id,p_code,p_name,p_unit,p_better_direction,p_protocol_notes,
    p_category,p_group_code,p_display_order,p_mark_step,p_min_age,p_max_age);
  update public.program_assessment_tests set
    max_attempts = p_max_attempts, retry_policy = p_retry_policy
  where id = v_id;
  return v_id;
end;
$$;

create function public.update_admin_program_assessment_test_v4(
  p_test_id uuid, p_name text, p_unit text, p_better_direction text,
  p_protocol_notes text, p_category text, p_display_order integer,
  p_mark_step numeric, p_min_age integer, p_max_age integer,
  p_reset_bands boolean, p_max_attempts integer, p_retry_policy text
) returns void language plpgsql security definer set search_path = ''
as $$
begin
  perform public.update_admin_program_assessment_test_v3(
    p_test_id,p_name,p_unit,p_better_direction,p_protocol_notes,p_category,
    p_display_order,p_mark_step,p_min_age,p_max_age,p_reset_bands);
  update public.program_assessment_tests set
    max_attempts = p_max_attempts, retry_policy = p_retry_policy
  where id = p_test_id;
end;
$$;

create function public.resolve_program_assessment_tests_v3(
  p_program_id text, p_category text, p_birth_date date,
  p_assessed_on date, p_reference_on date
) returns jsonb language plpgsql stable security definer set search_path = ''
as $$
declare v_rule public.program_assessment_scoring_rules%rowtype;
declare v_context jsonb;
begin
  select * into v_rule from public.program_assessment_scoring_rules
    where program_id = p_program_id;
  if v_rule.age_reference = 'reference_date' and
      p_reference_on is distinct from v_rule.age_reference_on or
      v_rule.age_reference <> 'reference_date' and p_reference_on is not null then
    raise exception 'La fecha de referencia no coincide con el baremo publicado.'
      using errcode = '22023';
  end if;
  v_context := public.resolve_program_assessment_tests_v2(
    p_program_id,p_category,p_birth_date,p_assessed_on,p_reference_on);
  return jsonb_set(v_context,'{tests}',
    (select coalesce(jsonb_agg(value || jsonb_build_object(
      'max_attempts',t.max_attempts,'retry_policy',t.retry_policy)
      order by (value->>'display_order')::integer),'[]'::jsonb)
      from jsonb_array_elements(v_context->'tests') value
      join public.program_assessment_tests t on t.id = (value->>'test_id')::uuid));
end;
$$;

create function public.preview_program_assessment_attempt_v3(
  p_program_id text, p_category text, p_birth_date date,
  p_assessed_on date, p_reference_on date, p_marks jsonb
) returns jsonb language plpgsql stable security definer set search_path = ''
as $$
declare
  v_context jsonb;
  v_rule public.program_assessment_scoring_rules%rowtype;
  v_entry jsonb;
  v_attempt jsonb;
  v_attempts jsonb;
  v_test public.program_assessment_tests%rowtype;
  v_seen uuid[] := array[]::uuid[];
  v_mark numeric;
  v_best numeric;
  v_valid boolean;
  v_previous_valid boolean;
  v_count integer;
  v_resolved jsonb := '[]'::jsonb;
  v_invalid uuid[] := array[]::uuid[];
  v_result jsonb;
  v_details jsonb := '[]'::jsonb;
  v_detail jsonb;
  v_sum numeric := 0;
  v_total numeric;
  v_passed boolean := true;
begin
  v_context := public.resolve_program_assessment_tests_v3(
    p_program_id,p_category,p_birth_date,p_assessed_on,p_reference_on);
  select * into v_rule from public.program_assessment_scoring_rules
    where program_id = p_program_id;
  if p_marks is null or jsonb_typeof(p_marks) <> 'array' or
      jsonb_array_length(p_marks) <> jsonb_array_length(v_context->'tests') or
      jsonb_array_length(p_marks) = 0 then
    raise exception 'Faltan pruebas aplicables o hay marcas de más.'
      using errcode = '22023';
  end if;
  for v_entry in select value from jsonb_array_elements(p_marks) loop
    if v_entry->>'test_id' is null or
        (v_entry->>'test_id')::uuid = any(v_seen) then
      raise exception 'Prueba ausente o repetida.' using errcode = '22023';
    end if;
    select * into v_test from public.program_assessment_tests
      where id = (v_entry->>'test_id')::uuid and program_id = p_program_id
        and category in ('both',p_category)
        and (v_context->>'age')::integer between min_age and max_age;
    if not found then
      raise exception 'Prueba ajena o no aplicable.' using errcode = '22023';
    end if;
    v_seen := array_append(v_seen,v_test.id);
    v_attempts := case when v_entry ? 'attempts' then v_entry->'attempts'
      else jsonb_build_array(jsonb_build_object('valid',true,'mark',v_entry->'mark')) end;
    if v_attempts is null or jsonb_typeof(v_attempts) <> 'array' or
        jsonb_array_length(v_attempts) < 1 or
        jsonb_array_length(v_attempts) > v_test.max_attempts then
      raise exception 'Número de intentos inválido en %.', v_test.name
        using errcode = '22023';
    end if;
    v_best := null;
    v_previous_valid := false;
    v_count := 0;
    for v_attempt in select value from jsonb_array_elements(v_attempts) loop
      v_count := v_count + 1;
      if v_count > 1 and (v_test.retry_policy = 'none' or
          v_test.retry_policy = 'invalid_only' and v_previous_valid) then
        raise exception 'No se permite repetir % tras un intento válido.',
          v_test.name using errcode = '22023';
      end if;
      if jsonb_typeof(v_attempt->'valid') <> 'boolean' then
        raise exception 'Indica si el intento de % es válido.', v_test.name
          using errcode = '22023';
      end if;
      v_valid := (v_attempt->>'valid')::boolean;
      if v_valid then
        v_mark := (v_attempt->>'mark')::numeric;
        if v_mark is null or v_mark < 0 or
            (v_test.unit in ('seconds','meters') and v_mark = 0) or
            mod(v_mark,v_test.mark_step) <> 0 then
          raise exception 'Marca inválida para %.', v_test.name
            using errcode = '22023';
        end if;
        if v_best is null or
            (v_test.better_direction = 'higher' and v_mark > v_best) or
            (v_test.better_direction = 'lower' and v_mark < v_best) then
          v_best := v_mark;
        end if;
      elsif v_attempt ? 'mark' and v_attempt->'mark' <> 'null'::jsonb then
        raise exception 'Un intento nulo no lleva marca.' using errcode = '22023';
      end if;
      v_previous_valid := v_valid;
    end loop;
    if v_best is null then
      v_invalid := array_append(v_invalid,v_test.id);
      -- La marca provisional solo permite reutilizar el evaluador de tramos.
      -- El resultado nulo se sustituye por cero y no conserva esa marca.
      v_best := v_test.mark_step;
    end if;
    v_resolved := v_resolved || jsonb_build_array(jsonb_build_object(
      'test_id',v_test.id,'mark',v_best));
  end loop;
  v_result := public.preview_program_assessment_attempt_v2(
    p_program_id,p_category,p_birth_date,p_assessed_on,p_reference_on,v_resolved);
  if cardinality(v_invalid) = 0 then return v_result; end if;
  for v_detail in select value from jsonb_array_elements(v_result->'details') loop
    if (v_detail->>'test_id')::uuid = any(v_invalid) then
      v_detail := v_detail || jsonb_build_object(
        'mark',null,'points',case when v_rule.scoring_mode = 'points' then 0 else null end,
        'minimum_mark',null,'margin',null,'passed',false,'invalid',true);
    end if;
    v_passed := v_passed and (v_detail->>'passed')::boolean;
    if v_rule.scoring_mode = 'points' then
      v_sum := v_sum + (v_detail->>'points')::numeric;
    end if;
    v_details := v_details || jsonb_build_array(v_detail);
  end loop;
  v_total := case when v_rule.scoring_mode = 'pass_fail' or
      v_rule.aggregation = 'none' then null
    when v_rule.aggregation = 'average' then v_sum / jsonb_array_length(v_details)
    else v_sum end;
  return v_result || jsonb_build_object('details',v_details,'total',v_total,
    'each_passed',v_passed,
    'passed',v_passed and
      (v_total is null or v_total >= v_rule.min_aggregate_points));
end;
$$;

create or replace function public.save_program_assessment_attempt(
  p_goal_id uuid, p_category text, p_birth_date date,
  p_assessed_on date, p_marks jsonb
) returns uuid language plpgsql security definer set search_path = ''
as $$
declare
  v_goal public.preparation_goals%rowtype;
  v_result jsonb;
  v_profile_birth date;
  v_reference_on date;
  v_id uuid;
begin
  if (select auth.uid()) is null then
    raise exception 'Inicia sesión para registrar tus marcas.' using errcode = '42501';
  end if;
  select * into v_goal from public.preparation_goals
    where id = p_goal_id and user_id = (select auth.uid()) and status = 'active';
  if not found then
    raise exception 'Preparación activa no disponible.' using errcode = '42501';
  end if;
  if not exists (select 1 from public.preparation_programs
      where id = v_goal.program_id and enabled) then
    raise exception 'Programa no publicado.' using errcode = '22023';
  end if;
  select fecha_nacimiento into v_profile_birth from public.profiles
    where id = (select auth.uid());
  if v_profile_birth is null or v_profile_birth <> p_birth_date then
    raise exception 'Confirma primero tu fecha de nacimiento en el perfil.'
      using errcode = '22023';
  end if;
  if p_assessed_on is null or p_assessed_on > current_date then
    raise exception 'Fecha de prueba inválida.' using errcode = '22023';
  end if;
  select age_reference_on into v_reference_on
    from public.program_assessment_scoring_rules where program_id = v_goal.program_id;
  v_result := public.preview_program_assessment_attempt_v3(
    v_goal.program_id,p_category,p_birth_date,p_assessed_on,v_reference_on,p_marks);
  insert into public.program_assessment_attempts
    (user_id,preparation_goal_id,program_id,scoring_version,category,
     birth_date,assessed_on,reference_on,marks,result)
  values ((select auth.uid()),p_goal_id,v_goal.program_id,
    v_result->>'scoring_version',p_category,p_birth_date,p_assessed_on,v_reference_on,
    p_marks,v_result)
  returning id into v_id;
  return v_id;
end;
$$;

revoke all on function public.create_admin_program_assessment_test_v4(
  text,text,text,text,text,text,text,text,integer,numeric,integer,integer,integer,text)
from public,anon;
grant execute on function public.create_admin_program_assessment_test_v4(
  text,text,text,text,text,text,text,text,integer,numeric,integer,integer,integer,text)
to authenticated;
revoke all on function public.update_admin_program_assessment_test_v4(
  uuid,text,text,text,text,text,integer,numeric,integer,integer,boolean,integer,text)
from public,anon;
grant execute on function public.update_admin_program_assessment_test_v4(
  uuid,text,text,text,text,text,integer,numeric,integer,integer,boolean,integer,text)
to authenticated;
revoke all on function public.preview_program_assessment_attempt_v3(
  text,text,date,date,date,jsonb) from public,anon;
grant execute on function public.preview_program_assessment_attempt_v3(
  text,text,date,date,date,jsonb) to authenticated;
revoke all on function public.resolve_program_assessment_tests_v3(
  text,text,date,date,date) from public,anon;
grant execute on function public.resolve_program_assessment_tests_v3(
  text,text,date,date,date) to authenticated;

commit;
