begin;
create function pg_temp.strategy_exposure(p jsonb,day date,outcome text default null) returns jsonb language sql as $$
 select jsonb_build_object('completed_on',day,'status','completed','dose',p->'dose','abandonment_reason',outcome,
  'sets',(select jsonb_agg(jsonb_build_object('status','completed','prescription',(p->'dose'->'task')||jsonb_build_object('target_value',v),
   'result',jsonb_strip_nulls(jsonb_build_object('value',v,'succeeded',true,'rir',4,'rpe',6,
    'load_kg',p->'dose'->'task'->'external_load_kg','actual_duration_seconds',p->'dose'->'task'->'fixed_duration_seconds',
    'technique_valid',true,'tolerated',true,'conditions_confirmed',true,'stop_reason','none'))))
   from jsonb_array_elements(p->'dose'->'targets') v))
$$;

do $$
declare profile jsonb; ref jsonb; p jsonb; q jsonb; h jsonb; exposure jsonb; doses jsonb; candidate jsonb; placement jsonb;
 wk date:=date '2026-10-05'; name text; measurement text; value numeric; count_sessions int; assigned int;
begin
 for name,measurement,value in values ('push_up_standard','REPS',55),('bench_press_barbell','LOAD_REPS',12),('front_plank_forearms','DURATION',60) loop
   select definition into profile from public.exercise_training_profiles where code=name and definition_version=1;
   ref:=jsonb_build_object('id',name,'role','specific','reference_kind','performed_set','observed_on',wk-1,
    'current_capacity_confirmed',true,'reported_rir',3,'reported_rpe',6,'targets',jsonb_build_array(value),'frequency',1,'rep_min',4,'rep_max',6,
    'task',jsonb_strip_nulls(jsonb_build_object('exercise_code',name,'exercise_version',1,'protocol_key','fixture','protocol_version',1,
     'setup_key','standard:fixture','measurement',measurement,'load_mode',case when measurement='LOAD_REPS' then 'external_load' else 'bodyweight' end,
     'external_load_kg',case when measurement='LOAD_REPS' then 30 end,'target_value',value,'intent','work')));
   p:=public.performance_task_v5(ref,profile,'[]',wk,wk+180);
   -- Una frecuencia ya entregada de tres no debe volver al dos del motor antiguo.
   p:=p||'{"frequency":3,"phase":"development"}';
   select jsonb_agg(p->'dose') into doses from generate_series(1,3);
   p:=p||jsonb_build_object('exposure_doses',doses);
   h:=jsonb_build_array(pg_temp.strategy_exposure(p,wk),pg_temp.strategy_exposure(p,wk+2),pg_temp.strategy_exposure(p,wk+4));
   q:=public.performance_task_v5(ref,profile,h,wk+7,wk+180,p,wk);
   if (q->>'frequency')::int<3 then raise exception 'Techo universal sigue activo: %',q; end if;
   if q->>'outcome'='redistribute' then
     if (select sum(v::numeric) from jsonb_array_elements(q->'exposure_doses') d,jsonb_array_elements_text(d->'targets') v)
       >(select 3*sum(v::numeric) from jsonb_array_elements_text(p->'dose'->'targets') v) then raise exception 'Duplica volumen'; end if;
     candidate:=public.performance_frequency_candidate_v2(q,3);
     if candidate->>'outcome'<>'progress' and name<>'bench_press_barbell' then raise exception 'Intentar frecuencia bloquea dosis: %',candidate; end if;
   end if;
   candidate:=public.performance_task_v5(ref,profile,h,wk+7,wk+12,p,wk);
   if candidate->>'frequency'<>'2' then raise exception 'Taper no procede de frecuencia conocida: %',candidate; end if;
   h:=jsonb_build_array(pg_temp.strategy_exposure(p,wk,'too_difficult'),pg_temp.strategy_exposure(p,wk+2,'too_difficult'),pg_temp.strategy_exposure(p,wk+4));
   candidate:=public.performance_task_v5(ref,profile,h,wk+7,wk+180,p,wk);
   if (candidate->>'frequency')::int>=3 and candidate->>'status'='ready' then raise exception 'Dificultad repetida no revisa frecuencia: %',candidate; end if;
   h:=jsonb_build_array(pg_temp.strategy_exposure(p,wk),pg_temp.strategy_exposure(p,wk+2,'lack_of_time'),pg_temp.strategy_exposure(p,wk+4));
   candidate:=public.performance_task_v5(ref,profile,h,wk+7,wk+180,p,wk);
   if (candidate->>'frequency')::int>3 then raise exception 'Promueve semana incompleta'; end if;
 end loop;

 -- No trocear flexiones hasta convertir una serie útil en unas pocas repeticiones.
 select definition into profile from public.exercise_training_profiles where code='push_up_standard' and definition_version=1;
 ref:=jsonb_build_object('id','push','role','specific','reference_kind','performed_set','observed_on',wk-1,
   'current_capacity_confirmed',true,'reported_rir',3,'targets','[55]'::jsonb,'frequency',1,
   'task','{"exercise_code":"push_up_standard","exercise_version":1,"protocol_key":"fixture","protocol_version":1,"setup_key":"standard:fixture","measurement":"REPS","load_mode":"bodyweight","target_value":55,"intent":"work"}'::jsonb);
 p:=public.performance_task_v5(ref,profile,'[]',wk,wk+180);
 p:=p||'{"frequency":2,"phase":"development"}';
 p:=jsonb_set(p,'{dose,targets}','[27]');
 p:=jsonb_set(p,'{dose,task,target_value}','27');
 select jsonb_agg(p->'dose') into doses from generate_series(1,2); p:=p||jsonb_build_object('exposure_doses',doses);
 h:=jsonb_build_array(pg_temp.strategy_exposure(p,wk),pg_temp.strategy_exposure(p,wk+2));
 q:=public.performance_task_v5(ref,profile,h,wk+7,wk+180,p,wk);
 if q->>'frequency'<>'2' or q->>'outcome'<>'progress' then raise exception 'Diluye el estímulo para aumentar frecuencia: %',q; end if;
 -- La dosis mayor está observada, no deducida del número de huecos disponibles.
 p:=jsonb_set(p,'{dose,targets}','[41]'); p:=jsonb_set(p,'{dose,task,target_value}','41');
 select jsonb_agg(p->'dose') into doses from generate_series(1,2); p:=p||jsonb_build_object('exposure_doses',doses);
 h:=jsonb_build_array(pg_temp.strategy_exposure(p,wk),pg_temp.strategy_exposure(p,wk+2));
 q:=public.performance_task_v5(ref,profile,h,wk+7,wk+180,p,wk);
 if q->>'frequency'<>'3' or q->'dose'->'targets'<>'[27]'::jsonb then raise exception 'No redistribuye volumen practicable conocido: %',q; end if;

 -- Política técnica: cinco exposiciones pueden caber sin cambiar ese cinco por un techo.
 select definition into profile from public.exercise_training_profiles where code='slalom_ball_course_16m' and definition_version=1;
 ref:=jsonb_build_object('id','course','role','specific','reference_kind','performed_set','observed_on',wk-1,
   'current_capacity_confirmed',true,'targets','[15.5]'::jsonb,'frequency',1,
   'task','{"exercise_code":"slalom_ball_course_16m","exercise_version":1,"protocol_key":"fixture","protocol_version":1,"setup_key":"standard:fixture","measurement":"TIME_FOR_COURSE","load_mode":"bodyweight","target_value":15.5,"intent":"practice"}'::jsonb);
 p:=public.performance_task_v5(ref,profile,'[]',wk,wk+180);
 h:=jsonb_build_array(pg_temp.strategy_exposure(p,wk),pg_temp.strategy_exposure(p,wk+7));
 p:=public.performance_task_v5(ref,profile,h,wk+14,wk+180,p,wk);
 p:=p||'{"frequency":4,"phase":"development"}';
 p:=jsonb_set(p,'{dose,targets}','[1,1]');
 select jsonb_agg(p->'dose') into doses from generate_series(1,4);
 p:=p||jsonb_build_object('exposure_doses',doses);
 h:='[]';
 for count_sessions in 0..3 loop h:=h||jsonb_build_array(pg_temp.strategy_exposure(p,wk+14+count_sessions)); end loop;
 q:=public.performance_task_v5(ref,profile,h,wk+21,wk+180,p,wk);
 if q->>'frequency'<>'5' or q->>'outcome'<>'redistribute' then raise exception 'No propone quinta práctica técnica: %',q; end if;
 if (select sum(jsonb_array_length(d->'targets')) from jsonb_array_elements(q->'exposure_doses') d)<>8 then raise exception 'Pierde intentos indivisibles'; end if;
 q:=q||'{"required_for_objective":true,"objective_key":"course"}';
 placement:=public.performance_place_v4(jsonb_build_array(q),'{"1":60,"2":60,"3":60,"4":60,"5":60,"6":60,"7":60}','[]','[]',0,wk+21,wk+180);
 select count(*) into assigned from jsonb_each(placement->'days') d,jsonb_array_elements(d.value->'work') w;
 if assigned<>5 then raise exception 'Distribuidor sigue limitado: %',placement; end if;
 if (select sum(jsonb_array_length(w->'dose'->'targets')) from jsonb_each(placement->'days') d,jsonb_array_elements(d.value->'work') w)<>8 then raise exception 'Publica dosis iguales y duplica intentos'; end if;
 -- La misma frecuencia con trabajo exigente no admite días adyacentes.
 q:=jsonb_set(q,'{recovery_days}','2');
 placement:=public.performance_place_v4(jsonb_build_array(q),'{"1":60,"2":60,"3":60,"4":60,"5":60,"6":60,"7":60}','[]','[]',0,wk+21,wk+180);
 select count(*) into assigned from jsonb_each(placement->'days') d,jsonb_array_elements(d.value->'work') w;
 if assigned<>4 then raise exception 'La separación real no permite cuatro o admite cinco: %',placement; end if;
 -- Domingo previo y lunes actual son fechas contiguas; lunes y domingo de la
 -- misma semana NO lo son. También protege carga de carrera sobre las piernas.
 placement:=public.performance_place_v4(jsonb_build_array(q),'{"1":60}','[]','[{"day":0,"body_regions":["lower_body"],"recovery_days":2}]',0,wk+21,wk+180);
 if exists(select 1 from jsonb_each(placement->'days') d where (d.value->>'minutes')::int>0) then raise exception 'Ignora frontera con semana previa'; end if;

 -- Los apoyos siguen subordinados a su objetivo, pero tampoco se recortan a
 -- una frecuencia fija si su propia respuesta permite otra distribución.
 p:=jsonb_build_object('status','ready','reference_id','main','objective_key','push','exercise_code','push_up_standard',
   'role','specific','phase','development','frequency',3,'outcome','maintain',
   'dose','{"targets":[8,8],"rest_seconds":90,"task":{"exercise_code":"push_up_standard","measurement":"REPS","load_mode":"bodyweight"}}'::jsonb);
 candidate:=p||'{"reference_id":"support","exercise_code":"push_up_weighted","role":"support"}';
 placement:=public.performance_select_v4(jsonb_build_array(p,candidate));
 if not exists(select 1 from jsonb_array_elements(placement) s where s->>'optional'='true' and s->>'frequency'='3') then raise exception 'Selector vuelve a limitar apoyo a una exposición: %',placement; end if;
 placement:=public.performance_select_v4(jsonb_build_array(p||'{"phase":"base"}',candidate));
 if jsonb_array_length(placement)<>1 then raise exception 'Introduce apoyo antes de consolidar principal'; end if;
 placement:=public.performance_select_v4(jsonb_build_array(p||'{"outcome":"reduce"}',candidate));
 if jsonb_array_length(placement)<>1 then raise exception 'Añade apoyo mientras se reduce principal'; end if;
 p:=p||'{"objective_key":"plank","exercise_code":"front_plank_forearms"}';
 candidate:=candidate||'{"objective_key":"plank","exercise_code":"front_plank_high","role":"support"}';
 placement:=public.performance_select_v4(jsonb_build_array(p,candidate));
 if jsonb_array_length(placement)<>2 then raise exception 'Compara el apoyo isométrico con el propio principal y lo pierde'; end if;

 -- La coordinación regional puede aplazar un escalón de carga. Reservar el
 -- mayor coste impide que al volver a más repeticiones se exceda el tiempo.
 p:=p||jsonb_build_object('outcome','progress','dose','{"targets":[4,4,4,4],"rest_seconds":180,"task":{"measurement":"LOAD_REPS"}}'::jsonb,
   'comparison_dose','{"targets":[10,10,10,10],"rest_seconds":180,"task":{"measurement":"LOAD_REPS"}}'::jsonb);
 p:=public.performance_exposure_v2(p,0);
 if (p->>'reservation_minutes')::int<ceil(public.performance_work_seconds_v2(p->'comparison_dose')/60.0) then raise exception 'Reserva insuficiente para mantener dosis anterior'; end if;
 p:=p||jsonb_build_object('exposure_doses',jsonb_build_array(p->'dose'),
   'comparison_exposure_doses',jsonb_build_array(p->'comparison_dose'),'dose',p->'comparison_dose','outcome','maintain');
 p:=public.performance_reconcile_exposures_v2(p);
 if public.performance_exposure_v2(p,0)->'dose' is distinct from p->'comparison_dose' then raise exception 'Ejecutor recibe escalón que coordinación aplazó'; end if;
end $$;
select set_config('request.jwt.claim.sub',(select user_id::text from public.admin_permissions limit 1),true);
do $$
declare g uuid; rid uuid; input jsonb;
begin
 insert into public.preparation_goals(user_id,program_id,target_date) values(auth.uid(),'fas_periodic_assessment',current_date+90) returning id into g;
 input:=jsonb_build_object('goal_code','push_up_standard','goal_version',1,'goal_measurement','REPS','reference_kind','performed_set',
  'observed_on',current_date,'current_capacity_confirmed',true,'reported_rir',3,'targets','[8]'::jsonb,'frequency',3,
  'task','{"exercise_code":"push_up_standard","exercise_version":1,"protocol_key":"fixture","protocol_version":1,"setup_key":"standard:fixture","measurement":"REPS","load_mode":"bodyweight","target_value":8,"target_rir":3,"intent":"work"}'::jsonb);
 rid:=public.save_performance_reference(g,input);
 if (select reference->>'frequency' from public.performance_training_references where id=rid)<>'3' then raise exception 'Alta sigue limitada a dos'; end if;
 begin perform public.save_performance_reference(g,input||'{"frequency":8}'); raise exception 'Admite más días de los que representa la semana';
 exception when invalid_parameter_value then null; end;
end $$;
rollback;
