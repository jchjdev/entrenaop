-- Regresión por los RPC de la app con deportistas ficticios y ROLLBACK.
begin;
set local timezone='UTC';
set local statement_timeout='45s';

create function pg_temp.check_control_coverage(goal uuid,wk date,push_up_id uuid,plank_id uuid) returns void language plpgsql as $$
declare
 push_up jsonb; plank jsonb; optional_work jsonb; plan jsonb; result jsonb;
begin
 push_up:=jsonb_build_object('reference_id',push_up_id,'objective_key','legacy:upper_body_push_ups_2_min',
  'name','Flexiones','status','ready','required_for_objective',true,'exercise_code','push_up_standard','frequency',1,
  'dose','{"task":{"measurement":"REPS","target_value":7},"targets":[7,6],"rest_seconds":120}'::jsonb);
 plank:=jsonb_build_object('reference_id',plank_id,'objective_key','legacy:abdominal_plank',
  'name','Plancha','status','ready','required_for_objective',true,'exercise_code','front_plank_forearms','frequency',2,
  'dose','{"task":{"measurement":"DURATION","target_value":50},"targets":[50,45],"rest_seconds":90}'::jsonb);
 optional_work:=push_up||jsonb_build_object('reference_id',gen_random_uuid(),'optional',true,'required_for_objective',false);
 plan:=jsonb_build_object('status','ready','week_start',wk,'proposals',jsonb_build_array(push_up,plank,optional_work),
  'pending',jsonb_build_array(jsonb_build_object('reference_id',plank_id,'requested',3,'scheduled',2)),
  'sessions',jsonb_build_array(
   jsonb_build_object('date',wk+2,'minutes',25,'work',jsonb_build_array(push_up,plank)),
   jsonb_build_object('date',wk+5,'minutes',25,'work',jsonb_build_array(optional_work,plank))),
  'running',jsonb_build_object('mode','normal','phase','specific','outcome','maintain','anchor_seconds',595,
   'normal_budget',70,'goal','{"seconds":500}'::jsonb,'reference_completed_at',wk-30,
   'evidence',jsonb_build_object('observations',(select jsonb_agg(jsonb_build_object('date',wk-days,
    'signal','{"status":"tolerated"}'::jsonb)) from unnest(array[8,11,15,18]) days)),
   'sessions',jsonb_build_array(public.running_session_v2('T',0,595,40)||jsonb_build_object('date',wk+1),
    public.running_session_v2('E',0,595,30)||jsonb_build_object('date',wk+4))));
 result:=public.apply_adaptive_protocol_controls_v1(goal,wk,plan);
 if result#>>'{control_schedule,scheduled,0,date}' is distinct from (wk+4)::text
  or result#>>'{proposals,0,frequency}' is distinct from '1'
  or result#>>'{proposals,1,frequency}' is distinct from '1'
  or result#>>'{proposals,1,allocation_status}' is distinct from 'reduced'
  or jsonb_array_length(result#>'{proposals,1,exposure_doses}') is distinct from 1
  or result#>>'{proposals,2,frequency}' is distinct from '0'
  or result#>>'{proposals,2,allocation_status}' is distinct from 'not_scheduled'
  or result#>>'{pending,0,scheduled}' is distinct from '1' then
  raise exception 'Mover el control conserva la flexión obligatoria y concilia las exposiciones: %',result;
 end if;
 plan:=plan#-'{running,sessions,1}';
 result:=public.apply_adaptive_protocol_controls_v1(goal,wk,plan);
 if result#>'{control_schedule,scheduled}' is distinct from '[]'::jsonb
  or result->'sessions' is distinct from plan->'sessions' then
  raise exception 'Un apoyo opcional no sustituye la única exposición obligatoria';
 end if;
end $$;

create function pg_temp.coordination_publication(availability jsonb, missing_mark boolean) returns jsonb language plpgsql as $$
declare
 u uuid:=gen_random_uuid(); g uuid; a uuid; push_up_id uuid; plank_id uuid; objective record; delivered integer;
 wk date:=current_date-extract(isodow from current_date)::int+1;
 target date:=wk+31; p jsonb; next_plan jsonb; s record; es record; e uuid; preview jsonb; performed timestamptz;
 n int:=0; signed_offset int:=(12-extract(hour from now())::int)*60;
begin
 insert into auth.users(id,email) values(u,u||'@running-control-days.invalid');
 perform set_config('request.jwt.claim.sub',u::text,true);
 update public.profiles set fecha_nacimiento='1996-01-01' where id=u;
 insert into public.pro_access_grants(user_id,source,starts_at,ends_at,reason)
 values(u,'development_manual',now()-interval '1 day',now()+interval '1 day','Fixture de cobertura del plan combinado');
 insert into public.preparation_goals(user_id,program_id,target_date) values(u,'fas_periodic_assessment',target) returning id into g;
 if not missing_mark then
  insert into public.fas_periodic_assessments(user_id,preparation_goal_id,catalog_version,category,age_at_assessment,age_band,is_pre_effective_reference,completed_at)
  values(u,g,'es_def_15_2026_periodic_2027_v1','men',30,'26_30',true,now()-interval '14 days') returning id into a;
  insert into public.fas_periodic_marks values(a,'run_2000_m',595000);
  insert into public.running_reference_selections(preparation_goal_id,reference_source,reference_record_id) values(g,'fasPeriodicAssessment',a::text);
 end if;
 insert into public.running_intake_contexts(preparation_goal_id,context_version,available_minutes_by_weekday,
  reserved_strength_weekdays,running_days_last_four_weeks,running_minutes_last_four_weeks,recent_weeks_end_on,
  reports_pain,requires_professional_review,health_observed_at,comfortable_continuous_minutes,target_2k_seconds,goal_mode)
 values(g,'running_initial_context_v3',availability,'{}',array[4,4,4,4],array[160,160,160,160],
  wk-1,false,false,now(),60,500,'time');
 perform public.save_performance_context(availability,array['cones','measuring_tape','tennis_ball','chalk','bench','barbell','plates'],false,true);
 if missing_mark then
  perform public.save_adaptive_program_preferences(g,target,'{}','running');
  p:=public.preview_adaptive_program_activation(g,wk);
  if p->>'status' is distinct from 'needs_attention'
   or not exists(select 1 from jsonb_array_elements(p->'pending') item
    where item->>'status'='running_pending' and item->>'reason' like '%marca vigente de 2 km%')
   or exists(select 1 from jsonb_array_elements(p->'pending') item
    where item->>'status' in ('needs_running_frequency','needs_running_time')) then
   raise exception 'Una marca ausente con cuatro huecos no pide ampliar agenda: %',p->'pending';
  end if;
  return p->'pending';
 end if;
 push_up_id:=public.save_performance_reference(g,jsonb_build_object('goal_code','push_up_standard','goal_version',1,
    'goal_measurement','REPS_IN_TIME','program_objective_key','legacy:upper_body_push_ups_2_min',
    'task','{"exercise_code":"push_up_standard","exercise_version":1,"protocol_key":"floor_v1","protocol_version":1,"setup_key":"Suelo y recorrido completo","measurement":"REPS","load_mode":"bodyweight","target_value":7,"target_rir":3,"intent":"work"}'::jsonb,
    'reference_kind','repeated_work','targets','[7,6]'::jsonb,'observed_on',current_date,
    'current_capacity_confirmed',true,'reported_rir',3,'rest_seconds',120,'frequency',2));
 plank_id:=public.save_performance_reference(g,jsonb_build_object('goal_code','front_plank_forearms','goal_version',1,
      'goal_measurement','DURATION','program_objective_key','legacy:abdominal_plank',
      'task','{"exercise_code":"front_plank_forearms","exercise_version":1,"protocol_key":"def_15_2026_plank","protocol_version":1,"setup_key":"Suelo antideslizante y codos bajo hombros","measurement":"DURATION","load_mode":"bodyweight","target_value":50,"intent":"work"}'::jsonb,
      'reference_kind','repeated_work','targets','[50,45]'::jsonb,'observed_on',current_date,
      'current_capacity_confirmed',true,'reported_rpe',7,'rest_seconds',90,'frequency',2));
 perform public.save_performance_reference(g,jsonb_build_object('goal_code','slalom_ball_course_16m','goal_version',1,
    'goal_measurement','TIME_FOR_COURSE','program_objective_key','legacy:agility_speed_circuit','equipment_confirmed',true,
    'task','{"exercise_code":"slalom_ball_course_16m","exercise_version":1,"protocol_key":"def_15_2026_agility","protocol_version":1,"setup_key":"Siete conos y corredor medido de 16 por 2 metros","measurement":"TIME_FOR_COURSE","load_mode":"bodyweight","target_value":14.3,"intent":"practice"}'::jsonb,
    'reference_kind','repeated_work','targets','[14.3,14.5]'::jsonb,'observed_on',current_date,
    'current_capacity_confirmed',true,'rest_seconds',180,'frequency',1));

 perform public.save_adaptive_program_preferences(g,target,'{}','full');
 perform pg_temp.check_control_coverage(g,wk+7,push_up_id,plank_id);
 p:=public.preview_adaptive_program_activation(g,wk);
 if p->>'status' is distinct from 'ready' then raise exception 'No hay plan listo: % %',p->>'status',p->'pending'; end if;

 perform public.activate_adaptive_program(g,wk,p);
 for s in select sw.id from public.scheduled_workouts sw where sw.preparation_goal_id=g and sw.status='planned' order by sw.scheduled_date loop
  n:=n+1;
  preview:=public.get_scheduled_workout_preview(u,s.id);
  e:=public.start_reviewed_scheduled_workout(u,s.id,preview->>'revision');
  -- Simula cuatro inicios offline en la cuenta ficticia. El cierre pasa por el RPC habitual.
  performed:=now()-make_interval(days=>3-mod(n-1,4));
  update public.workout_executions set started_at=performed-interval '1 hour' where id=e and user_id=u;
  for es in select * from public.workout_execution_sets where execution_id=e order by block_order,item_order,set_order loop
   if es.block_format='running' then
    perform public.complete_workout_set_idempotent(gen_random_uuid(),es.id,
     p_actual_duration_seconds=>coalesce(es.target_duration_seconds,ceil(es.target_distance_meters*coalesce(es.target_pace_max_seconds_per_km,360)/1000.0)::int),
     p_actual_distance_meters=>coalesce(es.target_distance_meters,es.target_duration_seconds*1000.0/coalesce(es.target_pace_max_seconds_per_km,360)),
     p_actual_recovery_duration_seconds=>es.recovery_duration_seconds,p_actual_rpe=>case when es.target_rpe is not null then 4 end);
   elsif es.performance_prescription is null then
    perform public.complete_workout_set_idempotent(gen_random_uuid(),es.id,p_actual_duration_seconds=>es.target_duration_seconds);
   else
    perform public.complete_performance_set_idempotent(gen_random_uuid(),es.id,jsonb_build_object(
     'value',case when es.performance_prescription->>'measurement'<>'PASS_FAIL' then es.performance_prescription->'target_value' end,
     'succeeded',case when es.performance_prescription->>'measurement'='PASS_FAIL' then true end,
     'rir',case when es.performance_prescription->>'effort_mode'='rir' then 3 end,
     'rpe',case when es.performance_prescription->>'effort_mode'='rpe' then 6 end,'technique_valid',true,
     'conditions_confirmed',true,'tolerated',true,'stop_reason','none'));
   end if;
  end loop;
  perform public.finish_workout_observed_idempotent(gen_random_uuid(),e,4,performed,signed_offset);
 end loop;
 next_plan:=public.calculate_preparation_week(g,wk+7);
 if not (next_plan ? 'decision_id') then
  raise exception 'No se publicó automáticamente la siguiente semana: %',next_plan->>'status';
 end if;

 if not exists(select 1 from jsonb_array_elements(next_plan#>'{control_schedule,reviewed}') item
  where item->>'profile'='running_2000m_v1' and item#>>'{decision,action}'='control') then
  raise exception 'La regresión requiere un 2 km elegible en la semana siguiente';
 end if;
 if (select count(*) from jsonb_array_elements(next_plan->'proposals') where value->>'required_for_objective'='true')<>3 then
  raise exception 'La regresión requiere tres objetivos obligatorios en el plan combinado';
 end if;
 for objective in select value proposal from jsonb_array_elements(next_plan->'proposals')
  where value->>'required_for_objective'='true'
 loop
  select count(distinct (pw.scheduled_workout_id,pw.block_order)) into delivered
  from public.performance_week_work pw join public.preparation_week_decisions wd on wd.id=pw.decision_id
  where wd.preparation_goal_id=g and wd.week_start=wk+7 and pw.reference_id=(objective.proposal->>'reference_id')::uuid;
  if delivered=0 or delivered is distinct from (objective.proposal->>'frequency')::integer
   or delivered is distinct from jsonb_array_length(objective.proposal->'exposure_doses') then
   raise exception '%: % exposiciones materializadas, % informadas',
    objective.proposal->>'name',delivered,objective.proposal->>'frequency';
  end if;
 end loop;
 return next_plan#>'{control_schedule,scheduled}';
end $$;

select pg_temp.coordination_publication('{"1":70,"2":70,"3":70,"4":70,"5":70,"6":70,"7":70}',false) as published_control;
select pg_temp.coordination_publication('{"1":60,"3":75,"5":60,"6":75}',true) as missing_reference;
rollback;
