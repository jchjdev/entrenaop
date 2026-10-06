-- Recálculo con datos reales de entrada, sin borrar historial. Todo se revierte.
begin;
select set_config('request.jwt.claim.sub',(select user_id::text from public.admin_permissions limit 1),true);
update public.profiles set fecha_nacimiento='1996-01-01' where id=auth.uid();
update public.preparation_goals set status='archived',archived_at=now() where user_id=auth.uid() and status='active';
update public.scheduled_workouts set scheduled_date=scheduled_date-365 where user_id=auth.uid() and scheduled_date>=current_date-2;
do $$
declare g uuid; a uuid; ref_id uuid; wk date:=current_date+8-extract(isodow from current_date)::int;
 p jsonb; old_run jsonb; old_common jsonb; revision jsonb; old_ids uuid[]; new_id uuid; sw uuid; e uuid; count_before int;
 rejected_instruction_change boolean:=false;
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
 if p->>'status'<>'ready' then raise exception 'No propone una revisión conjunta: %',p; end if;
 if (select count(*) from public.scheduled_workouts where id=any(old_ids) and status='planned')<>cardinality(old_ids)
   or (select superseded_at from public.running_week_decisions where id=(old_run->>'decision_id')::uuid) is not null then raise exception 'La vista previa cambia la agenda'; end if;
 if exists(select 1 from jsonb_array_elements(p->'proposals') w where w->>'exercise_code'='front_plank_forearms'
   and (w->'dose'->'targets'->>0)::numeric>=55) then raise exception 'Copia la referencia como dosis'; end if;
 begin perform public.publish_preparation_week_revision(g,wk,p||'{"reason":"alterada"}'); raise exception 'Acepta revisión alterada'; exception when invalid_parameter_value then null; end;
 perform public.save_performance_context('{"1":120,"2":120,"3":120,"4":120,"5":120}',array['cones','measuring_tape','tennis_ball','chalk'],false,true);
 begin perform public.publish_preparation_week_revision(g,wk,p); raise exception 'Publica con contexto cambiado'; exception when invalid_parameter_value then null; end;
 p:=public.preview_preparation_week_revision(g,wk);
 revision:=p->'revision';
 p:=public.publish_preparation_week_revision(g,wk,p);
 new_id:=(p->>'decision_id')::uuid;
 if (select count(*) from public.scheduled_workouts where id=any(old_ids) and status='cancelled')<>cardinality(old_ids) then raise exception 'No cancela todos los pendientes antiguos'; end if;
 if not exists(select 1 from public.running_week_decisions where id=(old_run->>'decision_id')::uuid and superseded_at is not null and decision=old_run-'decision_id'-'already_published') then raise exception 'Pierde la decisión original'; end if;
 if public.calculate_preparation_week(g,wk)->>'decision_id'<>new_id::text then raise exception 'Lee la revisión obsoleta'; end if;
 if public.calculate_running_week(g,wk)->>'decision_id'=old_run->>'decision_id' then raise exception 'Carrera sigue leyendo la decisión sustituida'; end if;
 if (select count(*) from jsonb_array_elements(public.get_preparation_training_setup(g)->'published_weeks'))<>1 then raise exception 'Duplica semanas por revisiones'; end if;
 if public.publish_preparation_week_revision(g,wk,p-'decision_id'-'already_published')->>'decision_id'<>new_id::text then raise exception 'Reintento no idempotente'; end if;
 -- Revisar también una semana que ya era conjunta, manteniendo sus vínculos.
 old_common:=p;
 p:=public.preview_preparation_week_revision(g,wk);
 p:=public.publish_preparation_week_revision(g,wk,p);
 if p->>'decision_id'=old_common->>'decision_id' then raise exception 'No crea otra revisión conjunta'; end if;
 if not exists(select 1 from public.performance_week_work where decision_id=(old_common->>'decision_id')::uuid) then raise exception 'Borra vínculos antiguos'; end if;
 if exists(select 1 from jsonb_array_elements(p->'sessions') s where s->>'warm_up_instructions' is null)
   then raise exception 'La propuesta no permite revisar el calentamiento'; end if;
 select scheduled_workout_id into sw from public.performance_week_work
   where decision_id=(p->>'decision_id')::uuid limit 1;
 e:=public.start_scheduled_workout(sw);
 if not exists(select 1 from public.workout_execution_sets where execution_id=e
   and exercise_id='21000000-0000-4000-8000-000000000001' and (item_instructions like '%3. Ensaya el trabajo%' or item_instructions like '%Ya has realizado la activación general%' or item_instructions like 'Ensayo de los movimientos%')) then
   raise exception 'El ejecutor pierde las instrucciones de calentamiento'; end if;
 -- La ejecución mantiene sus instrucciones aunque se editen las notas de plantilla.
 update public.workout_items set notes='Notas posteriores' where id in (
   select s.item_id from public.workout_sets s join public.workout_execution_sets es on es.source_set_id=s.id
     where es.execution_id=e and es.exercise_id='21000000-0000-4000-8000-000000000001');
 if exists(select 1 from public.workout_execution_sets where execution_id=e and item_instructions='Notas posteriores') then
   raise exception 'Reinterpreta instrucciones históricas'; end if;
 begin
   update public.workout_execution_sets set item_instructions='Cambio manual' where execution_id=e;
 exception when raise_exception then rejected_instruction_change:=true;
 end;
 if not rejected_instruction_change then raise exception 'Permite cambiar instrucciones de una ejecución'; end if;
 begin perform public.preview_preparation_week_revision(g,wk); raise exception 'Permite sustituir ejecución iniciada'; exception when invalid_parameter_value then null; end;
 if not exists(select 1 from public.workout_executions where id=e) then raise exception 'Borra la ejecución'; end if;
 perform set_config('request.jwt.claim.sub',gen_random_uuid()::text,true);
 begin perform public.preview_preparation_week_revision(g,wk); raise exception 'Permite revisar preparación ajena'; exception when insufficient_privilege then null; end;
 if has_function_privilege('authenticated','public.calculate_preparation_week_core(uuid,date,boolean)','execute')
   or has_function_privilege('authenticated','public.check_preparation_week_revision(uuid,date)','execute') then raise exception 'Expone funciones internas'; end if;
end $$;
select 'Serie única, revisión sin escritura, sustitución atómica, historial, reintentos y permisos: OK' as result;
rollback;

