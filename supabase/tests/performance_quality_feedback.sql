begin;
do $$
declare ep record; mode text; initial numeric; actual numeric; ref jsonb; task jsonb;
 p jsonb; hist jsonb; wk date:='2026-10-05';
begin
 for ep in select * from public.exercise_training_profiles where code in
   ('standing_broad_jump','slalom_ball_course_16m','rope_climb','farmer_carry') loop
   mode:=case ep.code when 'slalom_ball_course_16m' then 'TIME_FOR_COURSE'
     when 'rope_climb' then 'TIME_FOR_DISTANCE' else 'DISTANCE' end;
   initial:=case ep.code when 'standing_broad_jump' then 2 else 20 end;
   actual:=case ep.code when 'standing_broad_jump' then 2.1 when 'farmer_carry' then 20 else 19 end;
   task:=jsonb_build_object('schema_version',1,'exercise_code',ep.code,'exercise_version',1,
     'protocol_key','fixture','protocol_version',1,'setup_key','Montaje estable','measurement',mode,
     'load_mode',case when ep.code='farmer_carry' then 'external_load' else 'bodyweight' end,
     'policy_version','performance_v1','target_value',initial,'intent','practice');
   if ep.code='farmer_carry' then task:=task||'{"external_load_kg":20}'::jsonb; end if;
   if mode='TIME_FOR_DISTANCE' then task:=task||'{"fixed_distance_meters":5}'::jsonb; end if;
   ref:=jsonb_build_object('id','quality','task',task,'targets',jsonb_build_array(initial),
     'observed_on',wk-7,'current_capacity_confirmed',true,'rest_seconds',180,'frequency',2,'role','specific');
   p:=public.performance_task_v1(ref,ep.definition,'[]',wk-7,wk+90);
   select jsonb_agg(jsonb_build_object('execution_id',d,'completed_on',wk-d,'status','completed','dose',p->'dose',
     'sets',jsonb_build_array(jsonb_build_object('status','completed','prescription',p->'dose'->'task',
       'result',jsonb_build_object('value',actual,'load_kg',task->'external_load_kg','technique_valid',true,
         'conditions_confirmed',true,'tolerated',true,'stop_reason','none'))))) into hist from unnest(array[2,5]) d;
   p:=public.performance_task_v1(ref,ep.definition,hist,wk,wk+90,p);
   if ep.code='farmer_carry' then
     if p->'dose'->'targets'<>'[21]'::jsonb or p->>'outcome'<>'progress' then raise exception 'Transporte no progresa: %',p; end if;
   elsif p->>'outcome'<>'consolidated_performance' or (p->'dose'->'targets'->>0)::numeric<>actual then
     raise exception 'No incorpora rendimiento demostrado: % %',ep.code,p;
   end if;
   if jsonb_array_length(p->'dose'->'targets')<>1 then raise exception 'Inventa más intentos'; end if;
   if p->'evidence'->0->'exposure' is null then raise exception 'No conserva evidencia de la decisión'; end if;
 end loop;
end $$;
select 'Saltos, circuito, cuerda y transportes: respuesta real sin inventar récords: OK' as result;
rollback;
