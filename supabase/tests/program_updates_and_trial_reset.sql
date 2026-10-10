-- Recálculo con datos reales de entrada, sin borrar historial. Todo se revierte.
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
declare g uuid; a uuid; ref_id uuid; wk date:=current_date+8-extract(isodow from current_date)::int;
 p jsonb; old_run jsonb; old_common jsonb; revision jsonb; old_ids uuid[]; new_id uuid; sw uuid; e uuid; count_before int;
 result jsonb; personal uuid; personal_template uuid; owner_id uuid:=auth.uid(); ref_count int; total_before int;
 other_goal uuid; other_template uuid; shared_session uuid;
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
 values(g,'running_initial_context_v2','{"1":90,"2":90,"3":90,"4":90,"5":90}','{}',array[3,3,3,3],array[110,110,110,110],
 current_date-extract(isodow from current_date)::int,false,false,now(),60,465,'time');
 old_run:=public.publish_running_week(g,wk);
 select array_agg(id) into old_ids from public.preparation_revision_session_ids(g,wk) id;
 perform public.save_performance_context('{"1":90,"2":90,"3":90,"4":90,"5":90}','{}',false,true);
 ref_id:=public.save_performance_reference(g,jsonb_build_object('goal_code','front_plank_forearms','goal_version',1,'goal_measurement','DURATION','program_objective_key','legacy:abdominal_plank',
   'task','{"exercise_code":"front_plank_forearms","exercise_version":1,"protocol_key":"def_15_2026_plank","protocol_version":1,"setup_key":"standard:def_15_2026_plank:front_plank_forearms:1:DURATION","measurement":"DURATION","load_mode":"bodyweight","target_value":55,"intent":"work"}'::jsonb,
   'reference_kind','performed_set','targets','[55]'::jsonb,'observed_on',current_date,'current_capacity_confirmed',true,'frequency',1));
 if (select reference->>'rest_seconds' from public.performance_training_references where id=ref_id)<>'0' then raise exception 'Inventa descanso con una serie'; end if;
 perform public.save_performance_reference(g,jsonb_build_object('goal_code','push_up_standard','goal_version',1,'goal_measurement','REPS_IN_TIME','program_objective_key','legacy:upper_body_push_ups_2_min',
   'task','{"exercise_code":"push_up_standard","exercise_version":1,"protocol_key":"floor_v1","protocol_version":1,"setup_key":"Suelo y recorrido completo","measurement":"REPS","load_mode":"bodyweight","target_value":8,"target_rir":3,"intent":"work"}'::jsonb,
   'reference_kind','repeated_work','targets','[8,8]'::jsonb,'observed_on',current_date,'current_capacity_confirmed',true,'reported_rir',3,'rest_seconds',120,'frequency',2));
 perform public.save_performance_reference(g,jsonb_build_object('goal_code','slalom_ball_course_16m','goal_version',1,'goal_measurement','TIME_FOR_COURSE','program_objective_key','legacy:agility_speed_circuit','equipment_confirmed',true,
   'task','{"exercise_code":"slalom_ball_course_16m","exercise_version":1,"protocol_key":"def_15_2026_agility","protocol_version":1,"setup_key":"standard:def_15_2026_agility:slalom_ball_course_16m:1:TIME_FOR_COURSE","measurement":"TIME_FOR_COURSE","load_mode":"bodyweight","target_value":13.25,"intent":"practice"}'::jsonb,
   'reference_kind','performed_set','targets','[13.25]'::jsonb,'observed_on',current_date,'current_capacity_confirmed',true,'rest_seconds',0,'frequency',1));

 p:=public.preview_preparation_week_revision(g,wk);
 p:=public.publish_preparation_week_revision(g,wk,p);
 perform public.save_adaptive_program_preferences(g,current_date+100,'{}');
 perform public.activate_adaptive_program(g,wk,p);
 if not (public.get_preparation_training_setup(g)->'can_reset_trial')::boolean
   or not (public.get_preparation_training_setup(g)->'update_options'->'can_replace_pending')::boolean then
  raise exception 'No ofrece revisión y reinicio al administrador propietario'; end if;
 -- Guardar entradas no modifica una decisión ya publicada.
 perform public.save_adaptive_program_preferences(g,current_date+110,'{}');
 if public.calculate_preparation_week(g,wk)->>'decision_id'<>p->>'decision_id' then raise exception 'Guardar entradas cambia la pauta publicada'; end if;
 begin perform public.reset_adaptive_program_trial(g,'SI'); raise exception 'Acepta confirmación incorrecta'; exception when invalid_parameter_value then null; end;
 begin perform public.reset_adaptive_program_trial(gen_random_uuid(),'REINICIAR'); raise exception 'Acepta otra preparación'; exception when insufficient_privilege then null; end;
 perform set_config('request.jwt.claim.sub',gen_random_uuid()::text,true);
 begin perform public.reset_adaptive_program_trial(g,'REINICIAR'); raise exception 'Acepta usuario no administrador'; exception when insufficient_privilege then null; end;
 perform set_config('request.jwt.claim.sub',owner_id::text,true);
 select scheduled_workout_id into sw from public.performance_week_work where decision_id=(p->>'decision_id')::uuid limit 1;
 e:=public.start_scheduled_workout(sw);
 if (public.get_preparation_training_setup(g)->'update_options'->'can_replace_pending')::boolean then raise exception 'Permite revisar una semana empezada'; end if;
 select count(*) into total_before from public.scheduled_workouts where preparation_goal_id=g;
 begin perform public.reset_adaptive_program_trial(g,'REINICIAR'); raise exception 'Reinicia con ejecución activa'; exception when invalid_parameter_value then null; end;
 if not exists(select 1 from public.workout_executions where id=e) or (select count(*) from public.scheduled_workouts where preparation_goal_id=g)<>total_before then
  raise exception 'El reinicio rechazado borra datos'; end if;
 perform public.abandon_workout_execution(e,'other');
 insert into public.workout_mutation_receipts(id,user_id,mutation_kind,resource_id) values(gen_random_uuid(),auth.uid(),'abandon',e);
 insert into public.workout_templates(name,origin,owner_user_id,visibility,status,version)
 values('Sesión personal ajena al algoritmo','user',auth.uid(),'private','draft',1) returning id into personal_template;
 insert into public.scheduled_workouts(user_id,template_id,template_name,template_version,preparation_goal_id,scheduled_date,source)
 values(auth.uid(),personal_template,'Personal',1,g,wk,'user') returning id into personal;
 select count(*) into ref_count from public.performance_training_references where preparation_goal_id=g;
 -- No tocar otro programa ni destruir una plantilla que alguien reutilizó.
 insert into public.preparation_goals(user_id,program_id,target_date,status,archived_at)
 values(auth.uid(),'fas_periodic_assessment',current_date+90,'archived',now()) returning id into other_goal;
 insert into public.workout_templates(name,origin,owner_user_id,visibility,status,version)
 values('Otro programa','algorithm',auth.uid(),'private','published',1) returning id into other_template;
 insert into public.scheduled_workouts(user_id,template_id,template_name,template_version,preparation_goal_id,scheduled_date,source)
 values(auth.uid(),other_template,'Otro programa',1,other_goal,wk,'algorithm');
 insert into public.scheduled_workouts(user_id,template_id,template_name,template_version,scheduled_date,source)
 select auth.uid(),template_id,'Reutilizada',1,wk,'user' from public.scheduled_workouts where id=sw returning id into shared_session;
 begin perform public.reset_adaptive_program_trial(g,'REINICIAR'); raise exception 'Borra plantilla reutilizada'; exception when invalid_parameter_value then null; end;
 delete from public.scheduled_workouts where id=shared_session;
 result:=public.reset_adaptive_program_trial(g,'REINICIAR');
 if (result->>'executions')::int<>1 or (result->>'sessions')::int<3 then raise exception 'Reinicio incompleto: %',result; end if;
 if exists(select 1 from public.preparation_week_decisions where preparation_goal_id=g)
  or exists(select 1 from public.running_week_decisions where preparation_goal_id=g)
  or exists(select 1 from public.scheduled_workouts where preparation_goal_id=g and source='algorithm')
  or exists(select 1 from public.workout_executions where id=e)
  or exists(select 1 from public.workout_mutation_receipts where resource_id=e) then raise exception 'Quedan datos automáticos de ensayo'; end if;
 if (select target_date from public.preparation_goals where id=g)<>current_date+110
  or not exists(select 1 from public.fas_periodic_marks where assessment_id=a and value=478000)
  or not exists(select 1 from public.running_reference_selections where preparation_goal_id=g)
  or not exists(select 1 from public.running_intake_contexts where preparation_goal_id=g)
  or not exists(select 1 from public.performance_training_contexts where user_id=auth.uid())
  or (select count(*) from public.performance_training_references where preparation_goal_id=g)<>ref_count
  or not exists(select 1 from public.scheduled_workouts where id=personal)
  or not exists(select 1 from public.workout_templates where id=personal_template)
  or not exists(select 1 from public.scheduled_workouts where preparation_goal_id=other_goal and template_id=other_template)
  or not exists(select 1 from public.workout_templates where id=other_template) then raise exception 'Borra las entradas actuales, marcas oficiales, sesión personal u otro programa'; end if;
 if (select auto_advance or status<>'draft' or started_week is not null or last_generated_week is not null from public.adaptive_program_states where preparation_goal_id=g) then
  raise exception 'No vuelve al alta con las entradas conservadas'; end if;
 if (public.reset_adaptive_program_trial(g,'REINICIAR')->>'sessions')::int<>0 then raise exception 'Reinicio no idempotente'; end if;
 p:=public.calculate_preparation_week(g,wk);
 if p->>'status'<>'ready' or p ? 'decision_id' then raise exception 'No prepara una propuesta nueva tras el reinicio: %',p; end if;
 p:=public.activate_adaptive_program(g,wk,p);
 if p->>'decision_id' is null or not(select auto_advance from public.adaptive_program_states where preparation_goal_id=g) then raise exception 'No reactiva el programa'; end if;
 if has_function_privilege('authenticated','public.preparation_program_update_options(uuid)','execute')
  or has_function_privilege('anon','public.reset_adaptive_program_trial(uuid,text)','execute') then raise exception 'Permisos incorrectos'; end if;
end $$;
select 'Cambios sin reescribir, revisión elegible, reinicio conjunto, conservación, permisos e idempotencia: OK' as result;
rollback;
