-- Cuenta ficticia aislada: altas parciales, cambio, pausa, reanudación y permisos.
begin;
-- El ensayo deportivo necesita derechos Pro explícitos, siempre con ROLLBACK.
insert into public.pro_access_grants(user_id,source,ends_at,reason)
select candidate.id,'development_manual',now()+interval '1 day','Fixture SQL de programa adaptativo'
from public.profiles candidate where not public.has_pro_access(candidate.id);

do $$
declare u uuid; stranger uuid; run_goal uuid; force_goal uuid; assessment uuid;
 wk date:=current_date+8-extract(isodow from current_date)::int;
 p jsonb; saved jsonb; q jsonb; setup jsonb; old_ids uuid[]; s record; obj record;
 ref jsonb; exercise text; measure text; protocol text; n numeric; e uuid;
begin
 insert into auth.users(id,email) values(gen_random_uuid(),'program-mode-fixture@example.invalid') returning id into u;
-- El ensayo deportivo necesita derechos Pro explícitos, siempre con ROLLBACK.
insert into public.pro_access_grants(user_id,source,ends_at,reason)
select candidate.id,'development_manual',now()+interval '1 day','Fixture SQL de programa adaptativo'
from public.profiles candidate where not public.has_pro_access(candidate.id);

 insert into auth.users(id,email) values(gen_random_uuid(),'program-mode-other@example.invalid') returning id into stranger;
-- El ensayo deportivo necesita derechos Pro explícitos, siempre con ROLLBACK.
insert into public.pro_access_grants(user_id,source,ends_at,reason)
select candidate.id,'development_manual',now()+interval '1 day','Fixture SQL de programa adaptativo'
from public.profiles candidate where not public.has_pro_access(candidate.id);

 perform set_config('request.jwt.claim.sub',u::text,true);
 update public.profiles set fecha_nacimiento='1996-01-01' where id=u;
 insert into public.preparation_goals(user_id,program_id,target_date) values(u,'fas_periodic_assessment',current_date+90) returning id into run_goal;
 insert into public.preparation_goals(user_id,program_id,target_date) values(u,'armed_forces_troop_entry',current_date+120) returning id into force_goal;
 perform public.save_performance_context('{"1":60,"2":60,"3":60,"4":60,"5":60}',array['cones','measuring_tape','tennis_ball','chalk'],false,true);
 insert into public.fas_periodic_assessments(user_id,preparation_goal_id,catalog_version,category,age_at_assessment,age_band,is_pre_effective_reference)
 values(u,run_goal,'es_def_15_2026_periodic_2027_v1','men',30,'26_30',true) returning id into assessment;
 insert into public.fas_periodic_marks(assessment_id,test_id,value) values(assessment,'run_2000_m',478000);
 insert into public.running_reference_selections(preparation_goal_id,reference_source,reference_record_id) values(run_goal,'fasPeriodicAssessment',assessment::text);
 insert into public.running_intake_contexts(preparation_goal_id,context_version,available_minutes_by_weekday,reserved_strength_weekdays,
 running_days_last_four_weeks,running_minutes_last_four_weeks,recent_weeks_end_on,reports_pain,requires_professional_review,
 health_observed_at,comfortable_continuous_minutes,target_2k_seconds,goal_mode)
 values(run_goal,'running_initial_context_v2','{"1":60,"2":60,"3":60,"4":60,"5":60}','{}',array[0,0,0,0],array[0,0,0,0],
 current_date-extract(isodow from current_date)::int,false,false,now(),60,465,'time');
 perform public.save_adaptive_program_preferences(run_goal,current_date+90,'{}','running');
 setup:=public.get_preparation_training_setup(run_goal);
 if not (setup->>'has_running')::boolean or jsonb_array_length(setup->'objectives')<>0 then raise exception 'Solo carrera exige fuerza'; end if;
 p:=public.preview_adaptive_program_activation(run_goal,wk);
 if p->>'status'<>'ready' or jsonb_array_length(p->'sessions')<>0 or jsonb_array_length(p->'running'->'sessions')=0 then raise exception 'Alta solo carrera: %',p; end if;
 saved:=public.activate_adaptive_program(run_goal,wk,p);
 q:=public.activate_adaptive_program(run_goal,wk,p);
 if saved->>'decision_id'<>q->>'decision_id' then raise exception 'Alta duplicada al reintentar'; end if;
 select array_agg(id) into old_ids from public.scheduled_workouts where preparation_goal_id=run_goal and status='planned';

 -- Fuerza no necesita cuestionario ni marca de carrera, pero sí sus referencias.
 perform public.save_adaptive_program_preferences(force_goal,current_date+120,'{}','performance');
 setup:=public.get_preparation_training_setup(force_goal);
 if (setup->>'has_running')::boolean or jsonb_array_length(setup->'objectives')<>3 then raise exception 'Solo rendimiento muestra carrera'; end if;
 p:=public.preview_adaptive_program_activation(force_goal,wk);
 if p->>'status'='ready' then raise exception 'Activa fuerza sin referencias'; end if;
 begin
  perform public.activate_adaptive_program(force_goal,wk,p);
  raise exception 'Acepta un cambio incompleto';
 exception when invalid_parameter_value then null; end;
 if not (select auto_advance from public.adaptive_program_states where preparation_goal_id=run_goal)
 or exists(select 1 from public.scheduled_workouts where id=any(old_ids) and status<>'planned') then raise exception 'Fallo de alta pausa el programa actual'; end if;

 for obj in select * from public.performance_legacy_objectives where program_id='armed_forces_troop_entry' loop
  exercise:=obj.profile_code;
  measure:=case when exercise='push_up_standard' then 'REPS' else obj.measurement end;
  n:=case when measure='REPS' then 20 when measure='DURATION' then 55 else 13 end;
  ref:=jsonb_build_object('goal_code',exercise,'goal_version',1,'goal_measurement',obj.measurement,
   'program_objective_key',obj.objective_key,'reference_kind','performed_set','targets',jsonb_build_array(n),
   'observed_on',current_date,'current_capacity_confirmed',true,'equipment_confirmed',true,'frequency',1,
   'task',jsonb_build_object('exercise_code',exercise,'exercise_version',1,'protocol_key',obj.protocol_key,'protocol_version',1,
    'setup_key','standard:'||obj.protocol_key||':'||exercise||':1:'||measure,'measurement',measure,
    'load_mode','bodyweight','target_value',n,'intent',case when measure='TIME_FOR_COURSE' then 'practice' else 'work' end));
  if measure='REPS' then ref:=ref||jsonb_build_object('reported_rir',3,'task',(ref->'task')||'{"target_rir":3}'); end if;
  perform public.save_performance_reference(force_goal,ref);
 end loop;
 -- Reproduce una publicación antigua de carrera sin estado común.
 delete from public.adaptive_program_states where preparation_goal_id=run_goal;
 p:=public.preview_adaptive_program_activation(force_goal,wk);
 if p->>'status'<>'ready' or p->'running' is distinct from 'null'::jsonb and p->'running' is not null then raise exception 'Solo rendimiento: %',p; end if;
 if jsonb_array_length(p->'activation'->'pauses')<>1 then raise exception 'No avisa del cambio de programa'; end if;
 if exists(select 1 from public.scheduled_workouts where id=any(old_ids) and status<>'planned') then raise exception 'La vista previa modifica sesiones'; end if;
 saved:=public.activate_adaptive_program(force_goal,wk,p);
 if (select count(*) from public.adaptive_program_states where user_id=u and auto_advance)<>1
 or (select status from public.adaptive_program_states where preparation_goal_id=run_goal)<>'paused'
 or exists(select 1 from public.scheduled_workouts where id=any(old_ids) and status<>'cancelled') then raise exception 'No pausa el programa anterior'; end if;
 if not exists(select 1 from public.fas_periodic_marks where assessment_id=assessment) then raise exception 'Borra marcas al pausar'; end if;
 begin
  perform public.publish_running_week(run_goal,wk+7);
  raise exception 'La vía antigua publica un programa pausado';
 exception when invalid_parameter_value then null; end;
 perform public.advance_adaptive_program(run_goal);
 if exists(select 1 from public.scheduled_workouts where preparation_goal_id=run_goal and status='planned') then raise exception 'El pausado sigue pautando'; end if;

 select id into s from public.scheduled_workouts where preparation_goal_id=force_goal and status='planned' order by scheduled_date limit 1;
 e:=public.start_scheduled_workout(s.id);
 begin
  perform public.pause_adaptive_program(force_goal);
  raise exception 'Pausa una ejecución en curso';
 exception when invalid_parameter_value then null; end;
 p:=public.preview_adaptive_program_activation(run_goal,wk);
 if p->>'status'='ready' then raise exception 'Cambia programa con ejecución en curso'; end if;
 perform public.abandon_workout_execution(e,'other');
 perform public.pause_adaptive_program(force_goal);
 if not exists(select 1 from public.workout_executions where id=e) then raise exception 'Pierde el resultado al pausar'; end if;

 -- Retomar crea una decisión actual, sin resucitar las sesiones canceladas.
 perform public.save_adaptive_program_preferences(run_goal,current_date+90,'{}','running');
 p:=public.preview_adaptive_program_activation(run_goal,wk+7);
 if p->>'status'<>'ready' then raise exception 'No permite retomar: %',p; end if;
 saved:=public.activate_adaptive_program(run_goal,wk+7,p);
 if exists(select 1 from public.scheduled_workouts where id=any(old_ids) and status<>'cancelled')
 or (select status from public.adaptive_program_states where preparation_goal_id=force_goal)<>'paused' then raise exception 'Retoma la agenda antigua'; end if;
 if (public.get_preparation_training_setup(run_goal)->>'training_scope')<>'running' then raise exception 'No conserva selección al retomar'; end if;
 begin
  insert into public.adaptive_program_states(preparation_goal_id,auto_advance,status) values(force_goal,true,'training')
   on conflict(preparation_goal_id) do update set auto_advance=true,status='training';
  raise exception 'Dos generadores simultáneos';
 exception when unique_violation then null; end;
 begin
  update public.adaptive_program_states set user_id=stranger where preparation_goal_id=run_goal;
  raise exception 'Permite cambiar el propietario del programa';
 exception when insufficient_privilege then null; end;
 perform set_config('request.jwt.claim.sub',stranger::text,true);
 begin perform public.pause_adaptive_program(run_goal); raise exception 'Pausa preparación ajena'; exception when insufficient_privilege then null; end;
 begin perform public.preview_adaptive_program_activation(run_goal,wk); raise exception 'Consulta preparación ajena'; exception when insufficient_privilege then null; end;
 if has_function_privilege('authenticated','public.get_preparation_training_setup_base(uuid)','execute')
 or has_function_privilege('authenticated','public.materialize_preparation_week_scoped(uuid,date,jsonb,boolean)','execute') then raise exception 'Publica sin los controles públicos'; end if;
end $$;
set local role authenticated;
do $$ begin
 if exists(select 1 from public.adaptive_program_states) then raise exception 'RLS expone estado de otra cuenta'; end if;
 begin
  update public.adaptive_program_states set auto_advance=false;
  raise exception 'El cliente puede modificar estados directamente';
 exception when insufficient_privilege then null; end;
end $$;
reset role;
select 'program_pause_and_training_scope_ok' as result;
rollback;
