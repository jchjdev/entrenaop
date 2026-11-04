-- Datos ficticios. Las semanas se publican por los RPC de la app.
begin;
set local timezone='UTC';
set local statement_timeout='55s';

do $$
declare
 wk date:=current_date-extract(isodow from current_date)::int+1;
 availability jsonb:='{"1":60,"3":60,"6":60}';
 last_control_age int; athlete uuid; goal uuid; mark uuid; execution uuid; expected text;
 reference jsonb; previous_week record; appointment record; result_set record;
 pace numeric; proposal jsonb; receipt jsonb; quality text; decision jsonb;
begin
 foreach last_control_age in array array[15,10,7,2] loop
  expected:=case when last_control_age<7 then 'T_0_v1' else 'V_1_v1' end;
  athlete:=gen_random_uuid();
  insert into auth.users(id,email) values(athlete,athlete||'@running-control-chronology.invalid');
  perform set_config('request.jwt.claim.sub',athlete::text,true);
  update public.profiles set fecha_nacimiento='1996-01-01' where id=athlete;
  insert into public.pro_access_grants(user_id,source,starts_at,ends_at,reason)
  values(athlete,'development_manual',now()-interval '1 day',now()+interval '1 day','Fixture cronología carrera');
  insert into public.preparation_goals(user_id,program_id,target_date)
  values(athlete,'fas_periodic_assessment',wk+70) returning id into goal;
  for offset_days in reverse 2..0 loop
   insert into public.fas_periodic_assessments(user_id,preparation_goal_id,catalog_version,category,age_at_assessment,age_band,is_pre_effective_reference,completed_at)
   values(athlete,goal,'es_def_15_2026_periodic_2027_v1','men',30,'26_30',true,wk-last_control_age-14*offset_days)
   returning id into mark;
   insert into public.fas_periodic_marks values(mark,'run_2000_m',595000);
  end loop;
  insert into public.running_reference_selections(preparation_goal_id,reference_source,reference_record_id)
  values(goal,'fasPeriodicAssessment',mark::text);
  insert into public.running_intake_contexts(preparation_goal_id,context_version,available_minutes_by_weekday,
   reserved_strength_weekdays,running_days_last_four_weeks,running_minutes_last_four_weeks,recent_weeks_end_on,
   reports_pain,requires_professional_review,health_observed_at,comfortable_continuous_minutes,target_2k_seconds,goal_mode)
  values(goal,'running_initial_context_v3',availability,'{}',array[3,3,3,3],array[95,95,95,95],wk-1,false,false,now(),45,500,'time');
  perform public.save_performance_context(availability,'{}',false,true);
  perform public.save_adaptive_program_preferences(goal,wk+70,'{}','running');
  reference:=jsonb_build_object('policy_version','running_2k_v6','basis','recent','outcome','maintain','mode','normal',
    'normal_budget',95,'anchor_seconds',595,'load_weeks',0,'rotation',1,
    'reference_source','fasPeriodicAssessment','reference_record_id',mark);
  for previous_week in
   select date_trunc('week',wk+day)::date monday,
    jsonb_agg(public.running_session_v2(family,0,595,minutes)||jsonb_build_object('date',wk+day) order by day) sessions
   from (values (-28,'V',35),(-21,'V',35),(-14,'V',35),(-7,'V',35),(-5,'E',30),(-3,'E',30)) v(day,family,minutes)
   group by 1 order by 1
  loop
   perform public.materialize_running_week_plan(goal,previous_week.monday,
    reference||jsonb_build_object('week_start',previous_week.monday,'sessions',previous_week.sessions));
  end loop;

  for appointment in
   select sw.id,sw.scheduled_date,rs.prescription from public.scheduled_workouts sw
   join public.running_week_sessions rs on rs.scheduled_workout_id=sw.id
   where sw.preparation_goal_id=goal order by sw.scheduled_date
  loop
   execution:=public.start_reviewed_scheduled_workout(athlete,appointment.id,public.get_scheduled_workout_preview(athlete,appointment.id)->>'revision');
   update public.workout_executions set started_at=appointment.scheduled_date+time '11:00' where id=execution and user_id=athlete;
   for result_set in select * from public.workout_execution_sets where execution_id=execution order by block_order,item_order,set_order loop
    pace:=coalesce(case when appointment.prescription->>'family'='V' and appointment.scheduled_date>=wk-14
      then result_set.target_pace_min_seconds_per_km+1 else result_set.target_pace_max_seconds_per_km-1 end,450);
    perform public.complete_workout_set_idempotent(gen_random_uuid(),result_set.id,
     p_actual_duration_seconds=>coalesce(result_set.target_duration_seconds,round(result_set.target_distance_meters*pace/1000)::int),
     p_actual_distance_meters=>coalesce(result_set.target_distance_meters,result_set.target_duration_seconds*1000.0/pace),
     p_actual_recovery_duration_seconds=>result_set.recovery_duration_seconds);
   end loop;
   perform public.finish_workout_observed_idempotent(gen_random_uuid(),execution,
    case when appointment.prescription->>'family'='V' then 7 else 4 end,appointment.scheduled_date+time '12:00',0);
  end loop;

  proposal:=public.calculate_preparation_week(goal,wk);
  if proposal->>'status' is distinct from 'ready' then raise exception 'Propuesta no publicable: %',proposal; end if;
  receipt:=public.publish_preparation_week(goal,wk,proposal);
  select d.decision into strict decision from public.running_week_decisions d
  where d.preparation_goal_id=goal and d.week_start=wk and d.superseded_at is null;
  select string_agg(rs.prescription->>'variant_code',', ' order by sw.scheduled_date) into quality
  from public.running_week_sessions rs join public.scheduled_workouts sw on sw.id=rs.scheduled_workout_id
  join public.running_week_decisions d on d.id=rs.decision_id
  where sw.preparation_goal_id=goal and d.week_start=wk and d.superseded_at is null
   and rs.prescription->>'family' in ('T','V','S');
  if receipt->>'decision_id' is null or quality is distinct from expected
   or (decision#>>'{control_review,controls,0,date}')::date is distinct from wk-last_control_age
   or decision#>>'{evidence,families,V,trend}' is distinct from 'improving'
   or (strpos(coalesce(decision->>'reason',''),'series mejoran sin transferencia al 2 km')>0) is distinct from (last_control_age<7) then
   raise exception 'Control de hace % días: se esperaba % y se publicó %, motivo %',last_control_age,expected,quality,decision->>'reason';
  end if;
 end loop;
end $$;

select 'Solo el control posterior a las series mejoradas justifica el cambio de 5 × 2 min a 2 × 5 min' as result;
rollback;
