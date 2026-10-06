begin;
do $$
declare ep record; opt jsonb; ref jsonb; task jsonb; p jsonb; previous jsonb;
  hist jsonb; dose jsonb; sample jsonb; wk date:='2026-10-05'; weeks int; i int;
  mode text; load_mode text; count_models int:=0; horizon int; plan jsonb;
begin
  -- Todas las variantes y mediciones: ninguna recibe una conversión implícita a RM.
  for ep in select * from public.exercise_training_profiles loop
    for opt in select value from jsonb_array_elements(ep.definition->'measurement_options') loop
      mode:=opt->>'mode'; load_mode:=opt->'load_modes'->>0;
      task:=jsonb_build_object('schema_version',1,'exercise_code',ep.code,'exercise_version',ep.definition_version,
        'protocol_key','fixture_protocol','protocol_version',1,'setup_key','Montaje de prueba estable',
        'measurement',mode,'load_mode',load_mode,'policy_version','performance_v1','target_value',4,'intent','work');
      if mode in ('REPS','LOAD_REPS','REPS_IN_TIME') then task:=task||'{"target_rir":3}'::jsonb; end if;
      if mode='REPS_IN_TIME' then task:=task||'{"fixed_duration_seconds":120}'::jsonb; end if;
      if mode='TIME_FOR_DISTANCE' then task:=task||'{"fixed_distance_meters":5}'::jsonb; end if;
      if load_mode<>'bodyweight' then task:=task||'{"external_load_kg":40}'::jsonb; end if;
      if load_mode='bodyweight_plus_external' then task:=task||'{"body_mass_kg":75}'::jsonb; end if;
      ref:=jsonb_build_object('id','catalog_fixture','task',task,'targets','[4,4]'::jsonb,'observed_on',wk-1,
        'current_capacity_confirmed',true,'reported_rir',3,'rest_seconds',180,'frequency',2,'role','specific');
      p:=public.performance_task_v1(ref,ep.definition,'[]',wk,wk+90);
      if mode='MAX_LOAD' then
        if p->>'status'<>'needs_calibration' then raise exception 'Prescribe máximos: %',ep.code; end if;
      elsif p->>'status'<>'ready' or (p->>'work_minutes')::int<=0 then
        raise exception 'Variante sin modelo o duración: % % %',ep.code,mode,p;
      end if;
      count_models:=count_models+1;
    end loop;
  end loop;
  if count_models<64 then raise exception 'Cobertura insuficiente'; end if;

  -- Horizontes de 1, 2, 3, 4, 6 y 12 meses; semanas regeneradas desde resultados.
  for ep in select * from public.exercise_training_profiles where code in
    ('push_up_standard','bench_press_barbell','front_plank_forearms','standing_broad_jump','rope_climb','slalom_ball_course_16m') loop
    mode:=case ep.code when 'bench_press_barbell' then 'LOAD_REPS' when 'front_plank_forearms' then 'DURATION'
      when 'standing_broad_jump' then 'DISTANCE' when 'rope_climb' then 'TIME_FOR_DISTANCE'
      when 'slalom_ball_course_16m' then 'TIME_FOR_COURSE' else 'REPS' end;
    task:=jsonb_build_object('schema_version',1,'exercise_code',ep.code,'exercise_version',1,
      'protocol_key','horizon_protocol','protocol_version',1,'setup_key','Montaje estable',
      'measurement',mode,'load_mode',case when mode='LOAD_REPS' then 'external_load' else 'bodyweight' end,
      'policy_version','performance_v1','target_value',4,'intent','work');
    if mode in ('REPS','LOAD_REPS') then task:=task||'{"target_rir":3}'::jsonb; end if;
    if mode='LOAD_REPS' then task:=task||'{"external_load_kg":40}'::jsonb; end if;
    if mode='TIME_FOR_DISTANCE' then task:=task||'{"fixed_distance_meters":5}'::jsonb; end if;
    ref:=jsonb_build_object('id','horizon_fixture','task',task,'targets','[4,4]'::jsonb,'observed_on',wk-1,
      'current_capacity_confirmed',true,'reported_rir',3,'rest_seconds',180,'frequency',2,'role','specific',
      'load_step_kg',2,'rep_min',4,'rep_max',6);
    foreach horizon in array array[4,8,13,17,26,52] loop
      hist:='[]'; previous:='{}';
      for i in 0..horizon-1 loop
        p:=public.performance_task_v1(ref,ep.definition,hist,wk+7*i,wk+7*horizon-1,previous);
        if p->>'status'<>'ready' then raise exception 'Interrumpe horizonte % semana % %: %',horizon,i,ep.code,p; end if;
        if p<>public.performance_task_v1(ref,ep.definition,hist,wk+7*i,wk+7*horizon-1,previous) then raise exception 'No determinista'; end if;
        if i=horizon-1 and (p->>'phase'<>'taper' or jsonb_array_length(p->'dose'->'targets')<>1) then raise exception 'Sin puesta a punto'; end if;
        if mode in ('DISTANCE','TIME_FOR_DISTANCE','TIME_FOR_COURSE') and p->>'outcome'='progress' then raise exception 'Inventa mejora de velocidad/potencia'; end if;
        dose:=p->'dose';
        select jsonb_agg(jsonb_build_object('status','completed','prescription',jsonb_set(dose->'task','{target_value}',v),
          'result',jsonb_build_object('value',v,'rir',case when mode in ('REPS','LOAD_REPS') then 3 end,
            'load_kg',dose->'task'->'external_load_kg','technique_valid',true,'conditions_confirmed',true,'tolerated',true,'stop_reason','none')))
          into sample from jsonb_array_elements(dose->'targets') v;
        select jsonb_agg(jsonb_build_object('execution_id',i*2+d,'completed_on',wk+i*7+d,'status','completed','dose',dose,'sets',sample))
          into hist from unnest(array[0,3]) d;
        previous:=p;
      end loop;
    end loop;
  end loop;
  p:=public.performance_coordinate_progression_v1('[
    {"reference_id":"push","role":"specific","outcome":"progress","body_regions":["upper_body"],"dose":{"targets":[9]},"comparison_dose":{"targets":[8]}},
    {"reference_id":"pull","role":"specific","outcome":"progress","body_regions":["upper_body"],"dose":{"targets":[7]},"comparison_dose":{"targets":[6]}},
    {"reference_id":"squat","role":"specific","outcome":"progress","body_regions":["lower_body"],"dose":{"targets":[5]},"comparison_dose":{"targets":[4]}}
  ]','{"outcome":"progress"}',wk);
  if (select count(*) from jsonb_array_elements(p) x where x->>'outcome'='progress')<>1
    or exists(select 1 from jsonb_array_elements(p) x where x->>'reference_id'='squat' and x->>'outcome'='progress') then
    raise exception 'Progresa todo simultáneamente: %',p; end if;
  -- Recuperación y presupuesto diario, incluida la frontera domingo/lunes.
  p:='[{"status":"ready","reference_id":"one","objective_key":"one","role":"specific","frequency":2,"work_minutes":15,"body_regions":["lower_body"],"model":"power"}]';
  plan:=public.performance_place_v1(p,'{"1":40,"2":40,"3":40}','[]','[{"day":0,"body_regions":["lower_body"]}]',0,wk,wk+90);
  if plan->'days'->'1'->>'minutes'<>'0' then raise exception 'Ignora carga previa del domingo'; end if;
  if exists(select 1 from jsonb_each(plan->'days') d where (d.value->>'minutes')::int>40) then raise exception 'Exceso de tiempo'; end if;
end $$;
select 'Catálogo completo, seis horizontes, modelos y frontera de recuperación: OK' as result;
rollback;
