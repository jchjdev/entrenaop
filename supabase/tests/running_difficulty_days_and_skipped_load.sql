-- Publicación de preparaciones ficticias con fechas reales de ejecución y omisión por RPC.
begin;
set local timezone='UTC';
set local statement_timeout='55s';

create function pg_temp.running_day_load_fixture(scenario text) returns jsonb language plpgsql as $$
declare
 wk date:=current_date-extract(isodow from current_date)::int+1;
 calendar_case boolean:=scenario like 'calendar_%';
 availability jsonb:=case when calendar_case then '{"1":60,"3":25,"5":25}' else '{"1":60,"3":60,"6":60}' end;
 omitted_age int:=case when scenario='calendar_skipped_saturday' then 2 else 1 end;
 athlete uuid:=gen_random_uuid(); goal uuid; mark uuid; execution uuid;
 reference jsonb; previous_week record; appointment record; result_set record;
 performed_day date; difficult boolean; pace numeric;
 proposal jsonb; receipt jsonb; decision jsonb;
begin
 insert into auth.users(id,email) values(athlete,athlete||'@running-day-load.invalid');
 perform set_config('request.jwt.claim.sub',athlete::text,true);
 update public.profiles set fecha_nacimiento='1996-01-01' where id=athlete;
 insert into public.pro_access_grants(user_id,source,starts_at,ends_at,reason)
 values(athlete,'development_manual',now()-interval '1 day',now()+interval '1 day','Fixture carga por día de carrera');
 insert into public.preparation_goals(user_id,program_id,target_date)
 values(athlete,'fas_periodic_assessment',wk+70) returning id into goal;
 insert into public.fas_periodic_assessments(user_id,preparation_goal_id,catalog_version,category,age_at_assessment,age_band,is_pre_effective_reference,completed_at)
 values(athlete,goal,'es_def_15_2026_periodic_2027_v1','men',30,'26_30',true,wk-2) returning id into mark;
 insert into public.fas_periodic_marks values(mark,'run_2000_m',595000);
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
  from (values (-28,'V',35),(-21,'V',35),(-14,'V',35),
   (-7,case when calendar_case then 'E' else 'V' end,case when calendar_case then 30 else 35 end),
   (case when calendar_case then -4 else -5 end,case when calendar_case then 'E' else 'V' end,case when calendar_case then 30 else 35 end),
   (case when calendar_case then -omitted_age else -3 end,case when calendar_case then 'V' else 'E' end,case when calendar_case then 35 else 30 end)
  ) v(day,family,minutes) group by 1 order by 1
 loop
  perform public.materialize_running_week_plan(goal,previous_week.monday,
   reference||jsonb_build_object('week_start',previous_week.monday,'sessions',previous_week.sessions));
 end loop;

 for appointment in
  select sw.id,sw.scheduled_date,rs.prescription from public.scheduled_workouts sw
  join public.running_week_sessions rs on rs.scheduled_workout_id=sw.id
  where sw.preparation_goal_id=goal order by sw.scheduled_date
 loop
  if calendar_case and appointment.scheduled_date=wk-omitted_age then
   if scenario in ('calendar_skipped_saturday','calendar_skipped_sunday') then
    perform public.skip_preparation_session(appointment.id);
    continue;
   elsif scenario='calendar_pending_sunday' then
    continue;
   end if;
  end if;
  performed_day:=case
   when scenario='difficulty_same_day' and appointment.scheduled_date=wk-5 then wk-7
   when scenario='difficulty_two_weeks' and appointment.scheduled_date=wk-14 then wk-10
   else appointment.scheduled_date end;
  difficult:=not calendar_case and (appointment.scheduled_date=wk-7
   or scenario in ('difficulty_same_day','difficulty_two_days') and appointment.scheduled_date=wk-5
   or scenario='difficulty_two_weeks' and appointment.scheduled_date=wk-14);
  execution:=public.start_reviewed_scheduled_workout(athlete,appointment.id,public.get_scheduled_workout_preview(athlete,appointment.id)->>'revision');
  -- Solo en la cuenta ficticia. El cierre normal recibe la hora observada.
  update public.workout_executions set started_at=performed_day+time '11:00' where id=execution and user_id=athlete;
  for result_set in select * from public.workout_execution_sets where execution_id=execution order by block_order,item_order,set_order loop
   pace:=coalesce(result_set.target_pace_max_seconds_per_km-1,450);
   perform public.complete_workout_set_idempotent(gen_random_uuid(),result_set.id,
    p_actual_duration_seconds=>coalesce(result_set.target_duration_seconds,round(result_set.target_distance_meters*pace/1000)::int),
    p_actual_distance_meters=>coalesce(result_set.target_distance_meters,result_set.target_duration_seconds*1000.0/pace),
    p_actual_recovery_duration_seconds=>result_set.recovery_duration_seconds*case when difficult then 2 else 1 end);
  end loop;
  perform public.finish_workout_observed_idempotent(gen_random_uuid(),execution,
   case when appointment.prescription->>'family'='V' then 7 else 4 end,performed_day+time '12:00',0);
 end loop;

 proposal:=public.calculate_preparation_week(goal,wk);
 if proposal->>'status' is distinct from 'ready' then raise exception 'Propuesta no publicable: %',proposal->'pending'; end if;
 receipt:=public.publish_preparation_week(goal,wk,proposal);
 if receipt->>'decision_id' is null then raise exception 'No se publicó la semana de %',scenario; end if;
 select d.decision into strict decision from public.running_week_decisions d
 where d.preparation_goal_id=goal and d.week_start=wk and d.superseded_at is null;
 return decision||jsonb_build_object('published_quality',(
  select jsonb_agg(jsonb_build_object('variant',rs.prescription->>'variant_code','date',sw.scheduled_date) order by sw.scheduled_date)
  from public.running_week_sessions rs join public.scheduled_workouts sw on sw.id=rs.scheduled_workout_id
  join public.running_week_decisions d on d.id=rs.decision_id
  where d.preparation_goal_id=goal and d.week_start=wk and d.superseded_at is null
   and rs.prescription->>'family' in ('T','V','S')));
end $$;

do $$
declare sample record; decision jsonb; expected_day date;
begin
 for sample in select * from (values
  ('difficulty_one','normal',1,1),('difficulty_same_day','normal',2,1),
  ('difficulty_two_days','global_deload',2,2),('difficulty_two_weeks','global_deload',2,2)
 ) x(scenario,expected_mode,adverse_executions,adverse_days) loop
  decision:=pg_temp.running_day_load_fixture(sample.scenario);
  if not exists(select 1 from jsonb_array_elements(decision#>'{evidence,observations}') o
   where o->'signal'->>'status'='struggle' and (o->'signal'->>'objective_difficulty')::boolean
   having count(*)=sample.adverse_executions and count(distinct o->>'date')=sample.adverse_days) then
   raise exception 'Faltan las ejecuciones y fechas adversas de %',sample.scenario;
  end if;
  if decision->>'mode' is distinct from sample.expected_mode then
   raise exception '% debe publicar %, obtuvo %: %',sample.scenario,sample.expected_mode,decision->>'mode',decision->>'reason';
  end if;
 end loop;

 for sample in select * from (values
  ('calendar_skipped_saturday','missing','V_0_v1'),('calendar_skipped_sunday','missing','V_0_v1'),
  ('calendar_pending_sunday','unknown',null),('calendar_run_sunday','tolerated',null)
 ) x(scenario,expected_signal,expected_quality) loop
  decision:=pg_temp.running_day_load_fixture(sample.scenario);
  expected_day:=(decision->>'week_start')::date-case when sample.scenario='calendar_skipped_saturday' then 2 else 1 end;
  if not exists(select 1 from jsonb_array_elements(decision#>'{evidence,observations}') o
   where (o->>'date')::date=expected_day and o->'session'->>'family'='V' and o->'signal'->>'status'=sample.expected_signal) then
   raise exception 'Falta la observación de %',sample.scenario;
  end if;
  if decision#>>'{published_quality,0,variant}' is distinct from sample.expected_quality
   or (sample.expected_quality is not null and (decision#>>'{published_quality,0,date}')::date is distinct from (decision->>'week_start')::date) then
   raise exception '% debe publicar % el lunes, obtuvo %',sample.scenario,sample.expected_quality,decision->'published_quality';
  end if;
 end loop;
end $$;

-- El colocador de la segunda calidad aplica la misma regla en el borde semanal.
do $$
declare
 wk date:='2026-10-19';
 input jsonb:=jsonb_build_object('week_start',wk,'anchor_seconds',595,'availability','{"1":60,"3":60}'::jsonb);
 sessions jsonb:=jsonb_build_array(public.running_session_v2('E',0,595,35)||jsonb_build_object('date',wk),
  public.running_session_v2('V',0,595,35)||jsonb_build_object('date',wk+2));
 observations jsonb:=jsonb_build_array(
  jsonb_build_object('date',wk-14,'session','{"family":"V"}'::jsonb,'signal','{"status":"tolerated"}'::jsonb),
  jsonb_build_object('date',wk-10,'session','{"family":"T"}'::jsonb,'signal','{"status":"tolerated"}'::jsonb),
  jsonb_build_object('date',wk-1,'session','{"family":"V"}'::jsonb,'signal','{"status":"missing","reason":"not_performed"}'::jsonb));
begin
 if public.running_second_quality_v6(sessions,observations,input,2000)#>>'{sessions,0,family}' is distinct from 'T'
  or public.running_second_quality_v6(sessions,jsonb_set(observations,'{2,signal}',
    '{"status":"unknown","reason":"unconfirmed_execution"}'),input,2000) is not null then
  raise exception 'La segunda calidad debe distinguir omisión de carga incierta';
 end if;
end $$;

select 'La semana publicada distingue días adversos y sesiones omitidas' as result;
rollback;
