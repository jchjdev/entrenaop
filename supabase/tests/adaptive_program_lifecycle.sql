begin;
-- El ensayo deportivo necesita derechos Pro explícitos, siempre con ROLLBACK.
insert into public.pro_access_grants(user_id,source,ends_at,reason)
select candidate.id,'development_manual',now()+interval '1 day','Fixture SQL de programa adaptativo'
from public.profiles candidate where not public.has_pro_access(candidate.id);

select set_config('request.jwt.claim.sub',(select user_id::text from public.admin_permissions limit 1),true);
update public.profiles set fecha_nacimiento='1996-01-01' where id=auth.uid();
update public.preparation_goals set status='archived',archived_at=now() where user_id=auth.uid() and status='active';
update public.scheduled_workouts set scheduled_date=scheduled_date-365 where user_id=auth.uid() and scheduled_date>=current_date-2;
do $$
declare g uuid; a uuid; control_id uuid; pending_id uuid; ref_id uuid; wk date:=current_date+1-extract(isodow from current_date)::int;
 p jsonb; again jsonb; next_plan jsonb; s record; es record; e uuid; r jsonb;
begin
 insert into public.preparation_goals(user_id,program_id,target_date)
 values(auth.uid(),'fas_periodic_assessment',current_date+90) returning id into g;
 insert into public.fas_periodic_assessments(user_id,preparation_goal_id,catalog_version,category,age_at_assessment,age_band,is_pre_effective_reference)
 values(auth.uid(),g,'es_def_15_2026_periodic_2027_v1','men',30,'26_30',true) returning id into a;
 insert into public.fas_periodic_marks(assessment_id,test_id,value) values(a,'run_2000_m',478000);
 insert into public.running_reference_selections(preparation_goal_id,reference_source,reference_record_id) values(g,'fasPeriodicAssessment',a::text);
 insert into public.running_intake_contexts(preparation_goal_id,context_version,available_minutes_by_weekday,
 reserved_strength_weekdays,running_days_last_four_weeks,running_minutes_last_four_weeks,recent_weeks_end_on,
 reports_pain,requires_professional_review,health_observed_at,comfortable_continuous_minutes,target_2k_seconds,goal_mode)
 values(g,'running_initial_context_v2','{"1":60,"3":60,"5":60}','{}',array[3,3,3,3],array[110,110,110,110],
 current_date-extract(isodow from current_date)::int,false,false,now(),60,465,'time');
 perform public.save_performance_context('{"1":60,"3":60,"5":60}','{}',false,true);
 ref_id:=public.save_performance_reference(g,jsonb_build_object('goal_code','push_up_standard','goal_version',1,'goal_measurement','REPS_IN_TIME','program_objective_key','legacy:upper_body_push_ups_2_min',
   'task','{"exercise_code":"push_up_standard","exercise_version":1,"protocol_key":"floor_v1","protocol_version":1,"setup_key":"Suelo y recorrido completo","measurement":"REPS","load_mode":"bodyweight","target_value":8,"target_rir":3,"intent":"work"}'::jsonb,
   'reference_kind','repeated_work','targets','[8,8]'::jsonb,'observed_on',wk-1,'current_capacity_confirmed',true,
   'reported_rir',3,'rest_seconds',120,'frequency',2));
 perform public.save_performance_reference(g,jsonb_build_object('goal_code','front_plank_forearms','goal_version',1,'goal_measurement','DURATION','program_objective_key','legacy:abdominal_plank',
   'task','{"exercise_code":"front_plank_forearms","exercise_version":1,"protocol_key":"def_15_2026_plank","protocol_version":1,"setup_key":"Suelo antideslizante y codos bajo hombros","measurement":"DURATION","load_mode":"bodyweight","target_value":20,"intent":"work"}'::jsonb,
   'reference_kind','repeated_work','targets','[20,20]'::jsonb,'observed_on',wk-1,'current_capacity_confirmed',true,'rest_seconds',90,'frequency',1));
 perform public.save_performance_reference(g,jsonb_build_object('goal_code','slalom_ball_course_16m','goal_version',1,'goal_measurement','TIME_FOR_COURSE','program_objective_key','legacy:agility_speed_circuit','equipment_confirmed',true,
   'task','{"exercise_code":"slalom_ball_course_16m","exercise_version":1,"protocol_key":"def_15_2026_agility","protocol_version":1,"setup_key":"Siete conos y corredor medido de 16 por 2 metros","measurement":"TIME_FOR_COURSE","load_mode":"bodyweight","target_value":15.5,"intent":"practice"}'::jsonb,
   'reference_kind','repeated_work','targets','[15.5,15.6]'::jsonb,'observed_on',wk-1,'current_capacity_confirmed',true,'rest_seconds',180,'frequency',1));
 if jsonb_array_length(public.get_preparation_training_setup(g)->'objectives')<>3 then raise exception 'No reconoce las tres pruebas FAS'; end if;
 select reference into r from public.performance_training_references where id=ref_id;
 perform public.save_performance_reference(g,r||'{"goal_version":1,"goal_measurement":"REPS","program_objective_key":null}');
 insert into public.preparation_running_tests(user_id,preparation_goal_id,completed_at,duration_seconds,rpe)
 values(auth.uid(),g,now(),478,8) returning id into control_id;
 update public.running_reference_selections set reference_source='trainingControl',reference_record_id=control_id::text where preparation_goal_id=g;
 if (public.resolve_program_running_reference(g)->>'value')::numeric is distinct from 478000 then
   raise exception 'El control común no resuelve la marca FAS: %',public.resolve_program_running_reference(g); end if;
 p:=public.calculate_preparation_week(g,wk);
 if exists(select 1 from jsonb_array_elements(p->'sessions') ses where
   (select count(*) from jsonb_array_elements(ses->'work') w where w->>'exercise_code'='push_up_standard')>1) then
   raise exception 'Duplica flexiones compartidas entre dos objetivos'; end if;
 if not exists(select 1 from jsonb_array_elements(p->'proposals') w where jsonb_array_length(w->'covered_reference_ids')=2) then
   raise exception 'Pierde el vínculo de objetivos compartidos'; end if;
 if p->>'status'<>'ready' or jsonb_array_length(p->'sessions')<>2
   or jsonb_array_length(p->'running'->'sessions')<2 then raise exception 'No coordina fuerza y carrera: %',p; end if;
 for s in select key,value from jsonb_each(p->'availability') loop
   if coalesce((select sum((x->>'minutes')::int) from jsonb_array_elements(p->'sessions') x where extract(isodow from (x->>'date')::date)::int=s.key::int),0)
      +coalesce((select sum((x->>'minutes')::int) from jsonb_array_elements(p->'running'->'sessions') x where extract(isodow from (x->>'date')::date)::int=s.key::int),0)
      >(s.value::text)::int then raise exception 'Excede disponibilidad total'; end if;
 end loop;
 begin
   perform public.publish_preparation_week(g,wk,p||'{"status":"inventado"}');
   raise exception 'Publica una propuesta alterada';
 exception when invalid_parameter_value then null; end;
 perform public.save_adaptive_program_preferences(g,current_date+90,'{}');
 p:=public.activate_adaptive_program(g,wk,p);
 if exists(select 1 from public.scheduled_workouts sw where sw.preparation_goal_id=g and sw.status='planned'
   group by scheduled_date having count(*)>1) then raise exception 'Publica dos sesiones separadas el mismo día'; end if;
 for s in select sw.*,rs.prescription from public.scheduled_workouts sw join public.running_week_sessions rs on rs.scheduled_workout_id=sw.id where sw.preparation_goal_id=g loop
   if (select count(*) from public.workout_sets ws join public.workout_items wi on wi.id=ws.item_id join public.workout_blocks b on b.id=wi.block_id
     where b.template_id=s.template_id and b.format='running')<>jsonb_array_length(s.prescription->'segments') then raise exception 'Duplica o pierde un tramo de carrera'; end if;
 end loop;
 again:=public.publish_preparation_week(g,wk,'{}');
 if p->>'decision_id'<>again->>'decision_id' or again->>'already_published'<>'true' then raise exception 'Publicación no idempotente'; end if;
 for s in select sw.id,sw.scheduled_date from public.scheduled_workouts sw where sw.preparation_goal_id=g and sw.scheduled_date between wk and wk+6 and sw.status='planned' order by sw.scheduled_date loop
   if (select count(*) from public.preparation_week_decisions where preparation_goal_id=g)<>1 then raise exception 'Adapta antes de cerrar todas las sesiones'; end if;
   e:=public.start_scheduled_workout(s.id);
   for es in select * from public.workout_execution_sets where execution_id=e order by block_order,set_order loop
     if es.block_format='running' then
       perform public.complete_workout_set(es.id,p_actual_duration_seconds=>coalesce(es.target_duration_seconds,ceil(es.target_distance_meters*es.target_pace_max_seconds_per_km/1000.0)::int),
         p_actual_distance_meters=>coalesce(es.target_distance_meters,es.target_duration_seconds*1000.0/coalesce(es.target_pace_max_seconds_per_km,360)),
         p_actual_recovery_duration_seconds=>es.recovery_duration_seconds,p_actual_rpe=>case when es.target_rpe is not null then 5 end);
     elsif es.performance_prescription is null then
       perform public.complete_workout_set(es.id,p_actual_duration_seconds=>es.target_duration_seconds);
     else
       r:=jsonb_build_object('value',case when es.performance_prescription->>'measurement'<>'PASS_FAIL' then es.performance_prescription->'target_value' end,
         'succeeded',case when es.performance_prescription->>'measurement'='PASS_FAIL' then true end,
         'rir',case when es.performance_prescription->>'effort_mode'='rir' then 3 end,
         'rpe',case when es.performance_prescription->>'effort_mode'='rpe' then 6 end,'technique_valid',true,
         'conditions_confirmed',true,'tolerated',true,'stop_reason','none');
       perform public.complete_performance_set_idempotent(gen_random_uuid(),es.id,r);
     end if;
   end loop;
   perform public.finish_workout_execution(e,6,null,null,null,'manual');
   -- Fechas sintéticas separadas para comprobar dos exposiciones, no dos clics.
   update public.workout_executions set completed_at=s.scheduled_date+time '12:00' where id=e;
 end loop;
 if (select count(*) from public.preparation_week_decisions where preparation_goal_id=g)<>2 then
   raise exception 'No prepara la siguiente semana al cerrar la última sesión: %',public.get_preparation_training_setup(g)->'program_state'; end if;
 next_plan:=public.calculate_preparation_week(g,wk+7);
 if next_plan->>'decision_id' is null then raise exception 'Semana siguiente no publicada'; end if;
 if not exists(select 1 from jsonb_array_elements(next_plan->'proposals') x where x->>'outcome'='progress'
   and x->'dose'->'targets'='[7,6]'::jsonb) then raise exception 'Resultados de fuerza: %',(select jsonb_agg(jsonb_build_object('name',x->'name','outcome',x->'outcome','reason',x->'reason','evidence_count',jsonb_array_length(x->'evidence'),'targets',x->'dose'->'targets')) from jsonb_array_elements(next_plan->'proposals') x); end if;
 perform public.advance_adaptive_program(g);
 if (select count(*) from public.preparation_week_decisions where preparation_goal_id=g)<>2 then raise exception 'Reintento duplicado'; end if;
 if exists(select 1 from public.scheduled_workouts where preparation_goal_id=g and scheduled_date>=wk+7 and status<>'cancelled' group by scheduled_date having count(*)>1) then raise exception 'Sesiones duplicadas'; end if;
 -- Una semana sin completar nada requiere revisar; no encadena progresión ficticia.
 update public.scheduled_workouts set status='skipped' where preparation_goal_id=g and scheduled_date between wk+7 and wk+13 and status='planned';
 if (select count(*) from public.preparation_week_decisions where preparation_goal_id=g)<>2 then raise exception 'Encadena semanas futuras'; end if;
 if public.get_preparation_training_setup(g)->'program_state'->>'status'<>'needs_review' then raise exception 'Una semana omitida no pide revisar el contexto'; end if;
 insert into public.scheduled_workouts(user_id,template_id,template_name,template_version,preparation_goal_id,scheduled_date,source,status,order_index)
 select user_id,template_id,template_name,template_version,g,current_date,'algorithm','planned',99
 from public.scheduled_workouts where preparation_goal_id=g limit 1 returning id into pending_id;
 perform public.skip_preparation_session(pending_id);
 if not exists(select 1 from public.scheduled_workouts where id=pending_id and status='skipped') then raise exception 'No conserva la omisión explícita'; end if;
 begin
  perform public.skip_preparation_session((select id from public.scheduled_workouts where preparation_goal_id=g and status='completed' limit 1));
  raise exception 'Permite omitir una sesión completada';
 exception when invalid_parameter_value then null; end;
 begin
  perform public.save_adaptive_program_preferences(g,current_date+90,'{"objetivo_ajeno":{"measurement":"REPS","value":20}}');
  raise exception 'Acepta metas ajenas al programa';
 exception when invalid_parameter_value then null; end;
 if has_table_privilege('authenticated','public.adaptive_program_states','insert')
  or has_function_privilege('authenticated','public.preparation_can_advance(uuid,date)','execute') then raise exception 'Estado o rutina interna expuestos'; end if;
 if has_function_privilege('authenticated','public.materialize_running_week_plan(uuid,date,jsonb)','execute') then raise exception 'Materializador expuesto'; end if;
 perform set_config('request.jwt.claim.sub',gen_random_uuid()::text,true);
 begin perform public.calculate_preparation_week(g,wk); raise exception 'Plan ajeno visible'; exception when insufficient_privilege then null; end;
end $$;
select 'Programa ficticio: activación → sesiones reales → cierre → siguiente semana automática → reintento idempotente: OK' as result;
rollback;

