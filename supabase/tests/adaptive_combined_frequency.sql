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
declare g uuid; a uuid; ref_id uuid; minutes int; day_count int; wk date:=current_date+8-extract(isodow from current_date)::int;
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
 values(g,'running_initial_context_v2','{"1":60,"3":60,"5":60}','{}',array[0,0,0,0],array[0,0,0,0],
 current_date-extract(isodow from current_date)::int,false,false,now(),60,465,'time');
 perform public.save_performance_context('{"1":60,"3":60,"5":60}','{}',false,true);
 ref_id:=public.save_performance_reference(g,jsonb_build_object('goal_code','push_up_standard','goal_version',1,'goal_measurement','REPS_IN_TIME','program_objective_key','legacy:upper_body_push_ups_2_min',
   'task','{"exercise_code":"push_up_standard","exercise_version":1,"protocol_key":"floor_v1","protocol_version":1,"setup_key":"Suelo y recorrido completo","measurement":"REPS","load_mode":"bodyweight","target_value":8,"target_rir":3,"intent":"work"}'::jsonb,
   'reference_kind','repeated_work','targets','[55,55]'::jsonb,'observed_on',current_date,'current_capacity_confirmed',true,
   'reported_rir',3,'rest_seconds',120,'frequency',1));
 perform public.save_performance_reference(g,jsonb_build_object('goal_code','front_plank_forearms','goal_version',1,'goal_measurement','DURATION','program_objective_key','legacy:abdominal_plank',
   'task','{"exercise_code":"front_plank_forearms","exercise_version":1,"protocol_key":"def_15_2026_plank","protocol_version":1,"setup_key":"Suelo antideslizante y codos bajo hombros","measurement":"DURATION","load_mode":"bodyweight","target_value":20,"intent":"work"}'::jsonb,
   'reference_kind','repeated_work','targets','[240,240]'::jsonb,'observed_on',current_date,'current_capacity_confirmed',true,'rest_seconds',90,'frequency',1));
 perform public.save_performance_reference(g,jsonb_build_object('goal_code','slalom_ball_course_16m','goal_version',1,'goal_measurement','TIME_FOR_COURSE','program_objective_key','legacy:agility_speed_circuit','equipment_confirmed',true,
   'task','{"exercise_code":"slalom_ball_course_16m","exercise_version":1,"protocol_key":"def_15_2026_agility","protocol_version":1,"setup_key":"Siete conos y corredor medido de 16 por 2 metros","measurement":"TIME_FOR_COURSE","load_mode":"bodyweight","target_value":15.5,"intent":"practice"}'::jsonb,
   'reference_kind','repeated_work','targets','[15.5,15.6]'::jsonb,'observed_on',current_date,'current_capacity_confirmed',true,'rest_seconds',180,'frequency',1));

 -- Caso de Javier: cinco huecos, cero carrera reciente y una exposición de
 -- cada objetivo de rendimiento. Más disponibilidad no acredita más tolerancia.
 for minutes in select unnest(array[60,90]) loop
  perform public.save_performance_context(jsonb_build_object('1',minutes,'2',minutes,'3',minutes,'4',minutes,'5',minutes),
   array['cones','tennis_ball','chalk','measuring_tape'],false,true);
  p:=public.calculate_preparation_week(g,wk);
  select count(distinct value->>'date') into day_count from jsonb_array_elements(
   coalesce(p->'sessions','[]')||coalesce(p->'running'->'sessions','[]'));
  if p->>'status'<>'ready' or p->'coverage'->>'running_expected'<>'2' or p->'coverage'->>'running_scheduled'<>'2'
   or day_count not between 2 and 5 then raise exception 'Falla 5x%: %',minutes,p; end if;
  if not exists(select 1 from jsonb_array_elements(p->'sessions') ses,jsonb_array_elements(ses->'work') w
    where w->>'exercise_code'='push_up_standard') then raise exception 'Pierde fuerza'; end if;
  for s in select key,value from jsonb_each(p->'availability') loop
   if coalesce((select sum((x->>'minutes')::int) from jsonb_array_elements(p->'sessions') x
     where extract(isodow from (x->>'date')::date)::int=s.key::int),0)
     +coalesce((select sum((x->>'minutes')::int) from jsonb_array_elements(p->'running'->'sessions') x
     where extract(isodow from (x->>'date')::date)::int=s.key::int),0)>(s.value::text)::int then
      raise exception 'Excede el tiempo real 5x%',minutes; end if;
  end loop;
 end loop;
 -- Una persona que ya sostiene cinco salidas no queda limitada a dos.
 update public.running_intake_contexts set running_days_last_four_weeks=array[5,5,5,5],
  running_minutes_last_four_weeks=array[150,150,150,150] where preparation_goal_id=g;
 p:=public.calculate_preparation_week(g,wk);
 if (p->'coverage'->>'running_expected')::int<=2 or (p->'coverage'->>'running_scheduled')::int<=2 then
  raise exception 'Existe un tope artificial de dos días: %',p; end if;
 -- Encaje estrecho: solo dos huecos de 35 minutos. Las otras pruebas quedan
 -- explícitamente pendientes; no se inventan referencias para resolverlas.
 update public.performance_training_references set active=false where preparation_goal_id=g and id<>ref_id;
 update public.performance_training_references set reference=reference||'{"targets":[8,8],"rest_seconds":90,"frequency":2}' where id=ref_id;
 update public.running_intake_contexts set running_days_last_four_weeks=array[0,0,0,0],running_minutes_last_four_weeks=array[0,0,0,0] where preparation_goal_id=g;
 perform public.save_performance_context('{"1":35,"4":35}','{}',false,true);
 p:=public.calculate_preparation_week(g,wk);
 if jsonb_array_length(p->'running'->'sessions')<>2 or not exists(
   select 1 from jsonb_array_elements(p->'sessions') ses where ses->>'combined'='true') then
  raise exception 'Descarta un encaje compartido viable: %',p->'coverage'; end if;
 if exists(select 1 from jsonb_array_elements(p->'sessions') ses where (ses->>'shared_total_minutes')::int>35) then
  raise exception 'El ahorro anticipado acepta un total imposible'; end if;
 -- La evidencia atraviesa los adaptadores con la fecha real: se realiza hoy
 -- una cita de la semana próxima y se consulta una adaptación posterior.
 update public.performance_training_references set active=true where preparation_goal_id=g;
 perform public.save_performance_context('{"1":90,"2":90,"3":90,"4":90,"5":90}',array['cones','tennis_ball','chalk','measuring_tape'],false,true);
 p:=public.calculate_preparation_week(g,wk);
 if p->>'status'<>'ready' then raise exception 'Fixture de fecha no publicable: %',p->'pending'; end if;
 p:=public.publish_preparation_week(g,wk,p);
 select sw.id,sw.scheduled_date into s from public.scheduled_workouts sw
  join public.performance_week_work pw on pw.scheduled_workout_id=sw.id
  join public.running_week_sessions rs on rs.scheduled_workout_id=sw.id
  where sw.preparation_goal_id=g and sw.status='planned' order by sw.scheduled_date limit 1;
 if s.id is null then raise exception 'Falta una sesión compartida en la prueba de fechas'; end if;
 e:=public.start_scheduled_workout(s.id);
 for es in select * from public.workout_execution_sets where execution_id=e order by block_order,set_order loop
  if es.block_format='running' then
   perform public.complete_workout_set(es.id,p_actual_duration_seconds=>coalesce(es.target_duration_seconds,ceil(es.target_distance_meters*es.target_pace_max_seconds_per_km/1000.0)::int),
    p_actual_distance_meters=>coalesce(es.target_distance_meters,es.target_duration_seconds*1000.0/coalesce(es.target_pace_max_seconds_per_km,360)),
    p_actual_recovery_duration_seconds=>es.recovery_duration_seconds,p_actual_rpe=>case when es.target_rpe is not null then 5 end);
  elsif es.performance_prescription is null then perform public.complete_workout_set(es.id,p_actual_duration_seconds=>es.target_duration_seconds);
  else
   r:=jsonb_build_object('value',case when es.performance_prescription->>'measurement'<>'PASS_FAIL' then es.performance_prescription->'target_value' end,
    'succeeded',case when es.performance_prescription->>'measurement'='PASS_FAIL' then true end,
    'rir',case when es.performance_prescription->>'effort_mode'='rir' then 3 end,
    'rpe',case when es.performance_prescription->>'effort_mode'='rpe' then 6 end,'technique_valid',true,'conditions_confirmed',true,'tolerated',true,'stop_reason','none');
   perform public.complete_performance_set_idempotent(gen_random_uuid(),es.id,r);
  end if;
 end loop;
 perform public.finish_workout_observed_idempotent(gen_random_uuid(),e,5,now(),0);
 next_plan:=public.calculate_preparation_week(g,wk+7);
 if not exists(select 1 from jsonb_array_elements(next_plan->'running'->'evidence'->'observations') obs
   where obs->>'date'=current_date::text and obs->>'date'<>s.scheduled_date::text) then raise exception 'Carrera adapta por fecha de agenda'; end if;
 if not exists(select 1 from jsonb_array_elements(next_plan->'proposals') pr,jsonb_array_elements(pr->'evidence') ev
   where ev->'exposure'->>'execution_id'=e::text and ev->>'date'=current_date::text) then raise exception 'Rendimiento pierde el día de realización'; end if;
end $$;
select 'Caso combinado 5x60/5x90, inicio sin carga y continuidad de corredor: OK' result;
rollback;
