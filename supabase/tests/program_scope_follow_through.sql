-- Ejecuciones reales con cuentas ficticias: cada alcance continúa automáticamente.
begin;
-- El ensayo deportivo necesita derechos Pro explícitos, siempre con ROLLBACK.
insert into public.pro_access_grants(user_id,source,ends_at,reason)
select candidate.id,'development_manual',now()+interval '1 day','Fixture SQL de programa adaptativo'
from public.profiles candidate where not public.has_pro_access(candidate.id);

do $$
declare u uuid; g uuid; a uuid; e uuid; old_execution uuid; second_goal uuid; control_id uuid; scope text; obj record; s record; es record;
 wk date:=current_date+1-extract(isodow from current_date)::int;
 p jsonb; r jsonb; ref jsonb; exercise text; measure text; n numeric; generated int;
begin
 for scope in select unnest(array['running','performance','full']) loop
  insert into auth.users(id,email) values(gen_random_uuid(),'follow-'||scope||'@example.invalid') returning id into u;
-- El ensayo deportivo necesita derechos Pro explícitos, siempre con ROLLBACK.
insert into public.pro_access_grants(user_id,source,ends_at,reason)
select candidate.id,'development_manual',now()+interval '1 day','Fixture SQL de programa adaptativo'
from public.profiles candidate where not public.has_pro_access(candidate.id);

  perform set_config('request.jwt.claim.sub',u::text,true);
  update public.profiles set fecha_nacimiento='1996-01-01' where id=u;
  insert into public.preparation_goals(user_id,program_id,target_date)
   values(u,'fas_periodic_assessment',current_date+90) returning id into g;
  perform public.save_performance_context('{"1":60,"2":60,"3":60,"4":60,"5":60}',
   array['cones','measuring_tape','tennis_ball','chalk'],false,true);
  if scope<>'performance' then
   insert into public.fas_periodic_assessments(user_id,preparation_goal_id,catalog_version,category,age_at_assessment,age_band,is_pre_effective_reference)
    values(u,g,'es_def_15_2026_periodic_2027_v1','men',30,'26_30',true) returning id into a;
   insert into public.fas_periodic_marks(assessment_id,test_id,value) values(a,'run_2000_m',478000);
   insert into public.running_reference_selections(preparation_goal_id,reference_source,reference_record_id)
    values(g,'fasPeriodicAssessment',a::text);
   insert into public.running_intake_contexts(preparation_goal_id,context_version,available_minutes_by_weekday,reserved_strength_weekdays,
    running_days_last_four_weeks,running_minutes_last_four_weeks,recent_weeks_end_on,reports_pain,requires_professional_review,
    health_observed_at,comfortable_continuous_minutes,target_2k_seconds,goal_mode)
    values(g,'running_initial_context_v2','{"1":60,"2":60,"3":60,"4":60,"5":60}','{}',array[3,3,3,3],array[110,110,110,110],
     current_date-extract(isodow from current_date)::int,false,false,now(),60,465,'time');
  end if;
  if scope<>'running' then
   for obj in select * from public.performance_legacy_objectives where program_id='fas_periodic_assessment' loop
    exercise:=obj.profile_code;
    measure:=case when exercise='push_up_standard' then 'REPS' else obj.measurement end;
    n:=case when measure='REPS' then 20 when measure='DURATION' then 55 else 13 end;
    ref:=jsonb_build_object('goal_code',exercise,'goal_version',1,'goal_measurement',obj.measurement,
     'program_objective_key',obj.objective_key,'reference_kind','performed_set','targets',jsonb_build_array(n),
     'observed_on',wk-1,'current_capacity_confirmed',true,'equipment_confirmed',true,'frequency',1,
     'task',jsonb_build_object('exercise_code',exercise,'exercise_version',1,'protocol_key',obj.protocol_key,'protocol_version',1,
      'setup_key','standard:'||obj.protocol_key||':'||exercise||':1:'||measure,'measurement',measure,
      'load_mode','bodyweight','target_value',n,'intent',case when measure='TIME_FOR_COURSE' then 'practice' else 'work' end));
    if measure='REPS' then ref:=ref||jsonb_build_object('reported_rir',3,'task',(ref->'task')||'{"target_rir":3}'); end if;
    perform public.save_performance_reference(g,ref);
   end loop;
  end if;
  perform public.save_adaptive_program_preferences(g,current_date+90,'{}',scope);
  p:=public.preview_adaptive_program_activation(g,wk);
  if p->>'status'<>'ready' then raise exception 'Alta % bloqueada: %',scope,p; end if;
  perform public.activate_adaptive_program(g,wk,p);
  for s in select id,scheduled_date from public.scheduled_workouts
    where preparation_goal_id=g and status='planned' order by scheduled_date loop
   if (select count(*) from public.preparation_week_decisions where preparation_goal_id=g)<>1 then
    raise exception 'Adapta % antes de resolver la semana',scope; end if;
   e:=public.start_scheduled_workout(s.id);
   old_execution:=e;
   for es in select * from public.workout_execution_sets where execution_id=e order by block_order,item_order,set_order loop
    if es.block_format='running' then
     perform public.complete_workout_set(es.id,
      p_actual_duration_seconds=>coalesce(es.target_duration_seconds,ceil(es.target_distance_meters*es.target_pace_max_seconds_per_km/1000.0)::int),
      p_actual_distance_meters=>coalesce(es.target_distance_meters,es.target_duration_seconds*1000.0/coalesce(es.target_pace_max_seconds_per_km,360)),
      p_actual_recovery_duration_seconds=>es.recovery_duration_seconds,p_actual_rpe=>case when es.target_rpe is not null then 5 end);
    elsif es.performance_prescription is null then
     perform public.complete_workout_set(es.id,p_actual_duration_seconds=>es.target_duration_seconds);
    else
     r:=jsonb_build_object('value',case when es.performance_prescription->>'measurement'<>'PASS_FAIL' then es.performance_prescription->'target_value' end,
      'succeeded',case when es.performance_prescription->>'measurement'='PASS_FAIL' then true end,
      'rir',case when es.performance_prescription->>'effort_mode'='rir' then 3 end,
      'rpe',case when es.performance_prescription->>'effort_mode'='rpe' then 6 end,
      'technique_valid',true,'conditions_confirmed',true,'tolerated',true,'stop_reason','none');
     perform public.complete_performance_set_idempotent(gen_random_uuid(),es.id,r);
    end if;
   end loop;
   perform public.finish_workout_execution(e,6,null,null,null,'manual');
   update public.workout_executions set completed_at=s.scheduled_date+time '12:00' where id=e;
  end loop;
  select count(*) into generated from public.preparation_week_decisions where preparation_goal_id=g and superseded_at is null;
  if generated<>2 then raise exception 'No continúa % automáticamente: %',scope,public.get_preparation_training_setup(g)->'program_state'; end if;
  p:=public.calculate_preparation_week(g,wk+7);
  if p->>'training_scope'<>scope or p->>'decision_id' is null then raise exception 'Pierde alcance % en continuación',scope; end if;
  if scope='running' and exists(select 1 from public.performance_week_work pw join public.scheduled_workouts sw on sw.id=pw.scheduled_workout_id where sw.preparation_goal_id=g) then raise exception 'Solo carrera genera fuerza'; end if;
  if scope='performance' and exists(select 1 from public.running_week_decisions where preparation_goal_id=g) then raise exception 'Solo rendimiento genera carrera'; end if;
  if scope<>'running' and not exists(select 1 from jsonb_array_elements(p->'proposals') x where jsonb_array_length(x->'evidence')>0) then
   raise exception 'La continuación % ignora los resultados de fuerza',scope; end if;
  if scope<>'performance' and coalesce(jsonb_array_length(p->'running'->'evidence'->'observations'),0)=0 then
   raise exception 'La continuación % ignora los resultados de carrera: %',scope,p->'running'; end if;
  perform public.advance_adaptive_program(g);
  if (select count(*) from public.preparation_week_decisions where preparation_goal_id=g and superseded_at is null)<>generated then raise exception 'Duplicación %',scope; end if;
  -- Cambiar el alcance conserva ejecuciones y prepara solo sesiones actuales.
  if scope='full' then
   perform public.save_adaptive_program_preferences(g,current_date+90,'{}','running');
   if (select training_scope from public.adaptive_program_states where preparation_goal_id=g)<>'full' then raise exception 'Cambia alcance sin aceptación'; end if;
   p:=public.preview_adaptive_program_activation(g,wk+7);
   if p->>'status'<>'ready' then raise exception 'Cambio de alcance bloqueado: %',p; end if;
   perform public.activate_adaptive_program(g,wk+7,p);
   if not exists(select 1 from public.workout_executions where id=old_execution and status='completed') then raise exception 'Cambio borra resultados'; end if;
   if exists(select 1 from public.performance_week_work pw join public.scheduled_workouts sw on sw.id=pw.scheduled_workout_id
      where sw.preparation_goal_id=g and sw.scheduled_date>=wk+7 and sw.status='planned') then raise exception 'Cambio deja fuerza pendiente'; end if;
   if not exists(select 1 from public.performance_training_references where preparation_goal_id=g and active) then raise exception 'Cambio pierde referencias'; end if;
  end if;
  if scope='running' then
   -- Otro programa conserva su propia marca y aprovecha la carga real compatible.
   insert into public.preparation_goals(user_id,program_id,target_date)
    values(u,'armed_forces_troop_entry',current_date+90) returning id into second_goal;
   insert into public.preparation_running_tests(user_id,preparation_goal_id,completed_at,duration_seconds,rpe)
    values(u,second_goal,now(),490,8) returning id into control_id;
   insert into public.running_reference_selections(preparation_goal_id,reference_source,reference_record_id)
    values(second_goal,'trainingControl',control_id::text);
   insert into public.running_intake_contexts(preparation_goal_id,context_version,available_minutes_by_weekday,reserved_strength_weekdays,
    running_days_last_four_weeks,running_minutes_last_four_weeks,recent_weeks_end_on,reports_pain,requires_professional_review,
    health_observed_at,comfortable_continuous_minutes,target_2k_seconds,goal_mode)
    select second_goal,context_version,available_minutes_by_weekday,reserved_strength_weekdays,running_days_last_four_weeks,
     running_minutes_last_four_weeks,recent_weeks_end_on,reports_pain,requires_professional_review,
     health_observed_at,comfortable_continuous_minutes,target_2k_seconds,goal_mode
    from public.running_intake_contexts where preparation_goal_id=g;
   perform public.save_adaptive_program_preferences(second_goal,current_date+90,'{}','running');
   p:=public.preview_adaptive_program_activation(second_goal,wk+7);
   if p->>'status'<>'ready' or coalesce(jsonb_array_length(p->'running'->'evidence'->'observations'),0)=0
    or (p->'running'->>'anchor_seconds')::numeric<>490 then raise exception 'Mezcla marca o pierde carga del otro programa: %',p; end if;
   perform public.activate_adaptive_program(second_goal,wk+7,p);
   update public.running_intake_contexts set health_observed_at=now()-interval '40 days' where preparation_goal_id=g;
   p:=public.preview_adaptive_program_activation(g,wk+7);
   if p->>'status'='ready' then raise exception 'Retoma con contexto de salud antiguo'; end if;
   begin
    perform public.activate_adaptive_program(g,wk+7,p);
    raise exception 'Acepta reanudación inválida';
   exception when invalid_parameter_value then null; end;
   if not (select auto_advance from public.adaptive_program_states where preparation_goal_id=second_goal) then
    raise exception 'La reanudación inválida pausa al programa actual'; end if;
  end if;
 end loop;
end $$;
select 'program_scope_follow_through_ok' as result;
rollback;
