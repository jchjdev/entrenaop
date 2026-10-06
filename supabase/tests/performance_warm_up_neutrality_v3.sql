-- Ejecuciones reales: igual trabajo, distinta elección de calentamiento.
begin;
create function pg_temp.perform_week_v3(omit_warm boolean) returns jsonb language plpgsql as $$
declare u uuid; g uuid; wk date:=current_date+1-extract(isodow from current_date)::int;
 obj record; s record; es record; e uuid; ref jsonb; p jsonb; r jsonb; value numeric; measurement text;
begin
 insert into auth.users(id,email) values(gen_random_uuid(),'warm-'||omit_warm||'@example.invalid') returning id into u;
 perform set_config('request.jwt.claim.sub',u::text,true);
 update public.profiles set fecha_nacimiento='1996-01-01' where id=u;
 insert into public.preparation_goals(user_id,program_id,target_date) values(u,'fas_periodic_assessment',current_date+90) returning id into g;
 perform public.save_performance_context('{"1":60,"2":60,"3":60,"4":60,"5":60}',array['cones','measuring_tape','tennis_ball','chalk'],false,true);
 for obj in select * from public.performance_legacy_objectives where program_id='fas_periodic_assessment' loop
  measurement:=case when obj.profile_code='push_up_standard' then 'REPS' else obj.measurement end;
  value:=case when measurement='REPS' then 20 when measurement='DURATION' then 55 else 13 end;
  ref:=jsonb_build_object('goal_code',obj.profile_code,'goal_version',1,'goal_measurement',obj.measurement,
   'program_objective_key',obj.objective_key,'reference_kind','performed_set','targets',jsonb_build_array(value),
   'observed_on',wk-1,'current_capacity_confirmed',true,'equipment_confirmed',true,'frequency',2,
   'task',jsonb_build_object('exercise_code',obj.profile_code,'exercise_version',1,'protocol_key',obj.protocol_key,'protocol_version',1,
    'setup_key','standard:'||obj.protocol_key||':'||obj.profile_code||':1:'||measurement,'measurement',measurement,
    'load_mode','bodyweight','target_value',value,'intent',case when measurement='TIME_FOR_COURSE' then 'practice' else 'work' end));
  if measurement='REPS' then ref:=ref||jsonb_build_object('reported_rir',3,'task',(ref->'task')||'{"target_rir":3}'); end if;
  perform public.save_performance_reference(g,ref);
 end loop;
 perform public.save_adaptive_program_preferences(g,current_date+90,'{}','performance');
 p:=public.preview_adaptive_program_activation(g,wk);
 if p->>'status'<>'ready' then raise exception 'Alta neutral bloqueada: %',p; end if;
 perform public.activate_adaptive_program(g,wk,p);
 for s in select id,scheduled_date from public.scheduled_workouts where preparation_goal_id=g and status='planned' order by scheduled_date loop
  e:=public.start_scheduled_workout(s.id);
  if (select sum(target_duration_seconds) from public.workout_execution_sets where execution_id=e and block_format='warm_up')<>420 then raise exception 'Duración del guiado distinta del presupuesto'; end if;
  if (select count(*) from public.workout_execution_sets where execution_id=e and block_format='warm_up')<>3 then raise exception 'Calentamiento sin tres tareas'; end if;
  for es in select * from public.workout_execution_sets where execution_id=e order by block_order,item_order,set_order loop
   if es.block_format='warm_up' and omit_warm then
    perform public.skip_workout_set(es.id);
   elsif es.performance_prescription is null then
    perform public.complete_workout_set(es.id,p_actual_duration_seconds=>es.target_duration_seconds);
   else
    r:=jsonb_strip_nulls(jsonb_build_object('value',case when es.performance_prescription->>'measurement'<>'PASS_FAIL' then es.performance_prescription->'target_value' end,
     'succeeded',case when es.performance_prescription->>'measurement'='PASS_FAIL' then true end,
     'rir',case when es.performance_prescription->>'effort_mode'='rir' then 3 end,
     'rpe',case when es.performance_prescription->>'effort_mode'='rpe' then 6 end,
     'technique_valid',true,'conditions_confirmed',true,'tolerated',true,'stop_reason','none'));
    perform public.complete_performance_set_idempotent(gen_random_uuid(),es.id,r);
   end if;
  end loop;
  perform public.finish_workout_execution(e,6,null,null,null,'manual');
  update public.workout_executions set completed_at=s.scheduled_date+time '12:00' where id=e;
 end loop;
 p:=public.calculate_preparation_week(g,wk+7);
 if p->>'decision_id' is null then raise exception 'No continúa automáticamente después del calentamiento %',omit_warm; end if;
 return (select jsonb_agg(jsonb_build_object('exercise',w->'exercise_code','dose',w->'dose','phase',w->'phase','outcome',w->'outcome') order by w->>'exercise_code') from jsonb_array_elements(p->'proposals') w);
end $$;
do $$ declare performed jsonb; omitted jsonb; g uuid; old_id uuid; r jsonb; timed_id uuid; objective record; setup jsonb; equipment text[]; begin
 performed:=pg_temp.perform_week_v3(false); omitted:=pg_temp.perform_week_v3(true);
 if performed is distinct from omitted then raise exception 'Calentamiento altera la adaptación: % vs %',performed,omitted; end if;
 select id into g from public.preparation_goals where user_id=auth.uid() and status='active';
 select id,reference into old_id,r from public.performance_training_references where preparation_goal_id=g and target_profile_code='push_up_standard' and active;
 select * into objective from public.performance_legacy_objectives where program_id='fas_periodic_assessment' and profile_code='push_up_standard';
 timed_id:=public.save_performance_reference(g,r||jsonb_build_object('goal_version',1,'goal_measurement','REPS_IN_TIME',
  'observed_on',current_date,'reference_kind','official_test','reported_rir',null,
  'task',((r->'task')-'target_rir')||jsonb_build_object('measurement','REPS_IN_TIME','intent','test','fixed_duration_seconds',120)));
 if (select count(*) from public.performance_training_references where preparation_goal_id=g and active and target_profile_code='push_up_standard')<>2 then raise exception 'Marca temporal sustituye la serie libre'; end if;
 perform public.save_performance_reference(g,r||jsonb_build_object('goal_version',1,'goal_measurement','REPS_IN_TIME','observed_on',current_date));
 if not exists(select 1 from public.performance_training_references where id=timed_id and active)
  or exists(select 1 from public.performance_training_references where id=old_id and active) then raise exception 'Recalibración cambia otra medición'; end if;
 select array_agg(value) into equipment from public.exercise_training_profiles ep,jsonb_array_elements_text(ep.definition->'required_equipment') value where ep.code='bench_press_barbell' and ep.definition_version=1;
 perform public.save_performance_context('{"1":60,"2":60,"3":60,"4":60,"5":60}',equipment,false,true);
 setup:=public.get_preparation_training_setup(g);
 if (select count(*) from jsonb_array_elements(setup->'calibration_options') c where c->>'work_code'='bench_press_barbell')<>1 then raise exception 'Calibración de banca inexistente o duplicada: %',setup->'calibration_options'; end if;
 perform set_config('request.jwt.claim.sub',gen_random_uuid()::text,true);
 begin perform public.get_preparation_training_setup(g); raise exception 'Opciones de otra cuenta accesibles'; exception when insufficient_privilege then null; end;
end $$;
select 'Completar y omitir el guiado: misma dosis, fase y progresión automática' result;
rollback;
