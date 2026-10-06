-- Publicación validada y registro por preparación. Termina en ROLLBACK.
begin;

select set_config('request.jwt.claim.sub',
  (select user_id::text from public.admin_permissions limit 1), true);
set local role authenticated;

do $$
declare
  v_program text;
  v_test uuid;
  v_goal uuid;
  v_attempt uuid;
  v_issues jsonb;
  v_new_program text;
  v_rejected boolean := false;
begin
  v_program := public.create_admin_preparation_program('Programa temporal publicable', 'access');
  perform public.save_admin_program_scoring_rule_v3(v_program,'temporal_v1',
    'https://www.boe.es/','Fuente temporal','pass_fail','none',1,0,0,
    'assessment_date',null,'Ingreso',null,null);
  v_test := public.create_admin_program_assessment_test_v3(v_program,
    'carrera','Carrera','seconds','lower','Recorrer el circuito oficial.',
    'both','carrera',1,1,18,30);
  v_issues := public.admin_program_assessment_issues(v_program);
  if jsonb_array_length(v_issues) = 0 then
    raise exception 'Se aceptó un borrador sin mínimos.';
  end if;
  begin
    perform public.publish_admin_program_assessment(v_program);
  exception when sqlstate '22023' then v_rejected := true;
  end;
  if not v_rejected then raise exception 'Se publicó un baremo incompleto.'; end if;
  perform public.save_admin_program_pass_standard(v_test,null,'men',18,30,300);
  perform public.save_admin_program_pass_standard(v_test,null,'women',18,30,330);
  v_issues := public.admin_program_assessment_issues(v_program);
  if jsonb_array_length(v_issues) <> 0 then
    raise exception 'El borrador completo se rechazó: %', v_issues;
  end if;
  perform public.publish_admin_program_assessment(v_program);
  if not exists (select 1 from public.preparation_programs
      where id = v_program and enabled) then
    raise exception 'El programa no quedó publicado.';
  end if;
  v_rejected := false;
  begin
    perform public.save_admin_program_pass_standard(v_test,null,'men',18,30,299);
  exception when sqlstate '22023' then v_rejected := true;
  end;
  if not v_rejected then raise exception 'Se modificó un baremo publicado.'; end if;

  if not exists (select 1 from public.profiles where id = auth.uid()) then
    raise exception 'El usuario admin de pruebas no tiene perfil.';
  end if;
  update public.profiles set fecha_nacimiento = '2000-01-01'
    where id = auth.uid();
  update public.preparation_goals set status = 'archived', archived_at = now()
    where user_id = auth.uid() and status = 'active';
  insert into public.preparation_goals(user_id,program_id,status)
    values (auth.uid(),v_program,'active') returning id into v_goal;
  v_attempt := public.save_program_assessment_attempt(v_goal,'men',
    '2000-01-01','2026-09-27',
    jsonb_build_array(jsonb_build_object('test_id',v_test,'mark',299)));
  if not exists (select 1 from public.program_assessment_attempts
      where id = v_attempt and preparation_goal_id = v_goal
        and scoring_version = 'temporal_v1'
        and (result->>'passed')::boolean) then
    raise exception 'No se guardó el resultado con su versión.';
  end if;
  v_new_program := public.clone_admin_program_assessment_version(
    v_program,'Programa temporal segunda edición','temporal_v2');
  if not exists (select 1 from public.program_assessment_scoring_rules
      where program_id = v_new_program and scoring_version = 'temporal_v2') or
      not exists (select 1 from public.program_assessment_pass_standards s
        join public.program_assessment_tests t on t.id = s.test_id
        where t.program_id = v_new_program and s.category = 'men') or
      not exists (select 1 from public.program_assessment_attempts
        where id = v_attempt and program_id = v_program
          and scoring_version = 'temporal_v1') then
    raise exception 'La copia no preservó baremos e historial.';
  end if;
end;
$$;

rollback;
