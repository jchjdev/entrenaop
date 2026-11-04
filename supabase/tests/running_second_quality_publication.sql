-- Tramo de historial sintético de la semana 39 del barrido anual.
-- Las recetas previas se preparan como fixture. Las ejecuciones se registran
-- por los RPC y la semana examinada se calcula y publica por los RPC de la app.
begin;
set local timezone='UTC';
set local statement_timeout='45s';

do $$
declare
 u uuid:=gen_random_uuid(); g uuid; a uuid; execution uuid;
 wk date:=current_date-extract(isodow from current_date)::int+1;
 availability jsonb:='{"1":60,"3":60,"5":60,"7":60}';
 sessions jsonb; base jsonb; proposal jsonb; published jsonb; actual jsonb;
 previous_week record; appointment record; es record; pace numeric; distances int[];
begin
 insert into auth.users(id,email) values(u,u||'@running-second-quality.invalid');
 perform set_config('request.jwt.claim.sub',u::text,true);
 update public.profiles set fecha_nacimiento='1996-01-01' where id=u;
 insert into public.pro_access_grants(user_id,source,starts_at,ends_at,reason)
 values(u,'development_manual',now()-interval '1 day',now()+interval '1 day','Fixture segunda calidad');
 insert into public.preparation_goals(user_id,program_id,target_date)
 values(u,'fas_periodic_assessment',wk+97) returning id into g;
 for i in 0..2 loop
  insert into public.fas_periodic_assessments(user_id,preparation_goal_id,catalog_version,category,age_at_assessment,age_band,is_pre_effective_reference,completed_at)
  values(u,g,'es_def_15_2026_periodic_2027_v1','men',30,'26_30',true,wk-71+i*28)
  returning id into a;
  insert into public.fas_periodic_marks values(a,'run_2000_m',538000);
 end loop;
 insert into public.running_reference_selections(preparation_goal_id,reference_source,reference_record_id)
 values(g,'fasPeriodicAssessment',a::text);
 insert into public.running_intake_contexts(preparation_goal_id,context_version,available_minutes_by_weekday,
  reserved_strength_weekdays,running_days_last_four_weeks,running_minutes_last_four_weeks,recent_weeks_end_on,
  reports_pain,requires_professional_review,health_observed_at,comfortable_continuous_minutes,target_2k_seconds,goal_mode)
 values(g,'running_initial_context_v3',availability,'{}',array[3,3,3,3],array[100,100,100,100],
  wk-1,false,false,now(),45,515,'time');
 perform public.save_performance_context(availability,'{}',false,true);
 perform public.save_adaptive_program_preferences(g,wk+97,'{}','running');

 base:=jsonb_build_object('policy_version','running_2k_v6','basis','recent','outcome','progress','mode','normal',
  'normal_budget',120,'anchor_seconds',538,'load_weeks',1,'rotation',20,
  'reference_source','fasPeriodicAssessment','reference_record_id',a);
 for previous_week in
  select date_trunc('week',wk+day)::date monday,
   jsonb_agg(public.running_session_v2(family,step,538,minutes)||jsonb_build_object('date',wk+day) order by day) items
  from (values
   (-56,'S',2,39),(-52,'E',0,38),(-50,'E',0,28),
   (-49,'T',0,35),(-45,'E',0,40),(-43,'E',0,35),
   (-42,'E',0,28),(-40,'E',0,28),(-38,'E',0,27),(-36,'E',0,27),
   (-35,'V',1,34),(-33,'E',0,31),(-31,'E',0,25),(-29,'E',0,25),
   (-28,'S',2,39),(-26,'E',0,31),(-24,'E',0,25),(-22,'E',0,25),
   (-21,'T',1,30),(-19,'E',0,30),(-17,'E',0,30),(-15,'E',0,30),
   (-14,'E',0,30),(-12,'E',0,30),(-10,'E',0,30),(-8,'E',0,30),
   (-7,'V',-1,34),(-5,'T',-1,30),(-3,'E',0,30),(-1,'E',0,26)
  ) v(day,family,step,minutes) group by 1 order by 1
 loop
  perform public.materialize_running_week_plan(g,previous_week.monday,
   base||jsonb_build_object('week_start',previous_week.monday,'sessions',previous_week.items));
 end loop;

 for appointment in
  select sw.id,sw.scheduled_date,rs.prescription
  from public.scheduled_workouts sw join public.running_week_sessions rs on rs.scheduled_workout_id=sw.id
  where sw.preparation_goal_id=g and sw.scheduled_date<wk order by sw.scheduled_date
 loop
  execution:=public.start_reviewed_scheduled_workout(u,appointment.id,public.get_scheduled_workout_preview(u,appointment.id)->>'revision');
  -- Desplazar solo el inicio de esta cuenta ficticia para registrar el cierre histórico.
  update public.workout_executions set started_at=appointment.scheduled_date+time '11:00'
  where id=execution and user_id=u;
  for es in select * from public.workout_execution_sets where execution_id=execution order by block_order,item_order,set_order loop
   pace:=coalesce((es.target_pace_min_seconds_per_km+es.target_pace_max_seconds_per_km)/2.0,360)
    /(1+mod(39+floor((appointment.scheduled_date-wk)/7.0)::int,4)*0.003);
   perform public.complete_workout_set_idempotent(gen_random_uuid(),es.id,
    p_actual_duration_seconds=>coalesce(es.target_duration_seconds,round(es.target_distance_meters*pace/1000)::int),
    p_actual_distance_meters=>coalesce(es.target_distance_meters,es.target_duration_seconds*1000.0/pace),
    p_actual_recovery_duration_seconds=>es.recovery_duration_seconds,
    p_actual_rpe=>case when es.target_rpe is not null then (appointment.prescription->>'rpe_ceiling')::int-1 end);
  end loop;
  perform public.finish_workout_observed_idempotent(gen_random_uuid(),execution,
   (appointment.prescription->>'rpe_ceiling')::int-1,appointment.scheduled_date+time '12:00',0);
 end loop;

 proposal:=public.calculate_preparation_week(g,wk);
 if proposal->>'status' is distinct from 'ready' then
  raise exception 'No se puede publicar la propuesta: %, %',proposal->>'status',proposal->'pending';
 end if;
 published:=public.publish_preparation_week(g,wk,proposal);
 select jsonb_agg(rs.prescription order by sw.scheduled_date) into sessions
 from public.running_week_sessions rs
 join public.scheduled_workouts sw on sw.id=rs.scheduled_workout_id
 join public.running_week_decisions d on d.id=rs.decision_id
 where sw.preparation_goal_id=g and d.week_start=wk and d.superseded_at is null;
 select value into actual from jsonb_array_elements(sessions) where value->>'family'='S';
 select array_agg((value->>'meters')::int) into distances
 from jsonb_array_elements(actual->'segments') where value->>'role'='work';
 if published->>'decision_id' is null or jsonb_array_length(sessions) is distinct from 4
   or actual->>'minutes' is distinct from '32' or distances is distinct from array_fill(400,array[5])
   or (select count(*) from jsonb_array_elements(sessions) where value->>'family' in ('T','V','S','R'))<>1 then
  raise exception 'Debe publicarse una sola calidad, 5×400 en 32 min: %',sessions;
 end if;
end $$;
select 'Se publica 5×400 y tres rodajes al descartar la segunda calidad' as result;
rollback;
