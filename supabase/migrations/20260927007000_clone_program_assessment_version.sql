-- Una nueva edición parte de la publicada sin alterar su historial.
begin;

create function public.clone_admin_program_assessment_version(
  p_source_program_id text, p_name text, p_scoring_version text
) returns text language plpgsql security definer set search_path = ''
as $$
declare
  v_source public.preparation_programs%rowtype;
  v_rule public.program_assessment_scoring_rules%rowtype;
  v_test public.program_assessment_tests%rowtype;
  v_new_program text;
  v_new_test uuid;
begin
  if (select auth.uid()) is null or not (select public.is_admin()) then
    raise exception 'Solo administración puede crear versiones.' using errcode = '42501';
  end if;
  select * into v_source from public.preparation_programs
    where id = p_source_program_id and enabled for share;
  if not found then
    raise exception 'Selecciona un programa publicado.' using errcode = '22023';
  end if;
  select * into v_rule from public.program_assessment_scoring_rules
    where program_id = p_source_program_id;
  if not found then
    raise exception 'El programa no tiene baremo.' using errcode = '22023';
  end if;
  if p_scoring_version is null or char_length(btrim(p_scoring_version)) not between 3 and 120 or
      btrim(p_scoring_version) = v_rule.scoring_version then
    raise exception 'Indica una versión nueva del baremo.' using errcode = '22023';
  end if;
  v_new_program := public.create_admin_preparation_program(p_name,v_source.kind);
  insert into public.program_assessment_scoring_rules
    (program_id,scoring_version,source_url,source_label,aggregation,
     max_points,min_each_points,min_aggregate_points,scoring_mode,
     age_reference,age_reference_on,stage_label,effective_on,expires_on)
  values (v_new_program,btrim(p_scoring_version),v_rule.source_url,
    v_rule.source_label,v_rule.aggregation,v_rule.max_points,
    v_rule.min_each_points,v_rule.min_aggregate_points,v_rule.scoring_mode,
    v_rule.age_reference,v_rule.age_reference_on,v_rule.stage_label,
    v_rule.effective_on,v_rule.expires_on);
  for v_test in select * from public.program_assessment_tests
      where program_id = p_source_program_id order by display_order,category loop
    insert into public.program_assessment_tests
      (program_id,code,name,unit,better_direction,protocol_notes,
       definition_version,category,group_code,display_order,mark_step,
       min_age,max_age,max_attempts,retry_policy)
    values (v_new_program,v_test.code,v_test.name,v_test.unit,
      v_test.better_direction,v_test.protocol_notes,v_test.definition_version,
      v_test.category,v_test.group_code,v_test.display_order,v_test.mark_step,
      v_test.min_age,v_test.max_age,v_test.max_attempts,v_test.retry_policy)
    returning id into v_new_test;
    insert into public.program_assessment_score_bands
      (test_id,category,min_mark,max_mark,points,min_age,max_age)
    select v_new_test,category,min_mark,max_mark,points,min_age,max_age
    from public.program_assessment_score_bands where test_id = v_test.id;
    insert into public.program_assessment_pass_standards
      (test_id,category,min_age,max_age,threshold)
    select v_new_test,category,min_age,max_age,threshold
    from public.program_assessment_pass_standards where test_id = v_test.id;
  end loop;
  return v_new_program;
end;
$$;

revoke all on function public.clone_admin_program_assessment_version(text,text,text)
from public,anon;
grant execute on function public.clone_admin_program_assessment_version(text,text,text)
to authenticated;

commit;
