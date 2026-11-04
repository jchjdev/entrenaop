-- Reproduce una semana real con resultados manuales y calcula la siguiente.
begin;
set local statement_timeout='55s';

create function pg_temp.check_v0_week(omit_one boolean, effort int, expected text)
returns void language plpgsql as $$
declare
 u uuid:=gen_random_uuid(); g uuid; mark uuid; execution uuid; wk date;
 v jsonb:=public.running_session_v2('V',0,550,30);
 easy jsonb:=public.running_session_v2('E',0,550,30);
 s jsonb:=public.running_session_v2('S',0,550,30);
 availability jsonb:='{"1":45,"3":45,"6":45}';
 proposal jsonb; signal jsonb; appointment record; es record; receipt uuid; measured_meters numeric;
 first_work uuid; measured_work uuid;
begin
 wk:=current_date-extract(isodow from current_date)::int+1;
 insert into auth.users(id,email) values(u,u||'@running-time-test.invalid');
 perform set_config('request.jwt.claim.sub',u::text,true);
 update public.profiles set fecha_nacimiento='1996-01-01' where id=u;
 insert into public.pro_access_grants(user_id,source,starts_at,ends_at,reason)
 values(u,'development_manual',now()-interval '1 day',now()+interval '1 day','Fixture carrera por tiempo');
 insert into public.preparation_goals(user_id,program_id,target_date)
 values(u,'fas_periodic_assessment',wk+100) returning id into g;
 insert into public.fas_periodic_assessments(user_id,preparation_goal_id,catalog_version,category,age_at_assessment,age_band,is_pre_effective_reference,completed_at)
 values(u,g,'es_def_15_2026_periodic_2027_v1','men',30,'26_30',true,now()-interval '5 days') returning id into mark;
 insert into public.fas_periodic_marks values(mark,'run_2000_m',550000);
 insert into public.running_reference_selections(preparation_goal_id,reference_source,reference_record_id)
 values(g,'fasPeriodicAssessment',mark::text);
 insert into public.running_intake_contexts(preparation_goal_id,context_version,available_minutes_by_weekday,
  reserved_strength_weekdays,running_days_last_four_weeks,running_minutes_last_four_weeks,recent_weeks_end_on,
  reports_pain,requires_professional_review,health_observed_at,comfortable_continuous_minutes,target_2k_seconds,goal_mode)
 values(g,'running_initial_context_v3',availability,'{}',array[3,3,3,3],array[90,90,90,90],wk-1,false,false,now(),45,520,'time');
 perform public.save_performance_context(availability,'{}',false,true);
 perform public.save_adaptive_program_preferences(g,wk+100,'{}','running');
 perform public.materialize_running_week_plan(g,wk-7,jsonb_build_object('policy_version','running_2k_v6',
  'basis','recent','mode','normal','outcome','maintain','normal_budget',90,'anchor_seconds',550,
  'week_start',wk-7,'load_weeks',0,'rotation',1,'reference_source','fasPeriodicAssessment','reference_record_id',mark,
  'sessions',jsonb_build_array(v||jsonb_build_object('date',wk-7),s||jsonb_build_object('date',wk-5),
    easy||jsonb_build_object('date',wk-2))));
 for appointment in select sw.id,sw.scheduled_date,rs.variant_code from public.scheduled_workouts sw
  join public.running_week_sessions rs on rs.scheduled_workout_id=sw.id
  where sw.user_id=u and sw.preparation_goal_id=g order by sw.scheduled_date loop
  execution:=public.start_reviewed_scheduled_workout(u,appointment.id,public.get_scheduled_workout_preview(u,appointment.id)->>'revision');
  update public.workout_executions set started_at=appointment.scheduled_date+time '09:00' where id=execution and user_id=u;
  for es in select * from public.workout_execution_sets where execution_id=execution order by block_order,item_order,set_order loop
   if es.manual_distance_optional is distinct from (appointment.variant_code='V_0_v1') then
    raise exception 'La distancia opcional solo corresponde a los tramos del 4×2';
   end if;
   if appointment.variant_code='V_0_v1' and omit_one and es.set_order=2 then
    perform public.skip_workout_set_idempotent(gen_random_uuid(),es.id);
    continue;
   end if;
   if es.target_distance_meters is not null then
    begin
     perform public.complete_workout_set_idempotent(gen_random_uuid(),es.id,p_actual_duration_seconds=>60,
       p_actual_recovery_duration_seconds=>es.recovery_duration_seconds);
     raise exception 'Se admitió una serie por distancia sin metros';
    exception when raise_exception then
     if sqlerrm<>'Actual distance is required' then raise; end if;
    end;
   end if;
   measured_meters:=case when appointment.variant_code<>'V_0_v1'
    then coalesce(es.target_distance_meters,es.target_duration_seconds*1000.0/coalesce(es.target_pace_max_seconds_per_km,360)) end;
   if appointment.variant_code='V_0_v1' and es.set_order=4 then
    measured_work:=es.id;
    measured_meters:=es.target_duration_seconds*1000.0/es.target_pace_max_seconds_per_km;
   end if;
   receipt:=gen_random_uuid();
   perform public.complete_workout_set_idempotent(receipt,es.id,
    p_actual_duration_seconds=>case when es.target_duration_seconds is null
     then round(es.target_distance_meters*es.target_pace_max_seconds_per_km/1000.0)::int
     when appointment.variant_code='V_0_v1' and es.set_order=1 then 119
     else es.target_duration_seconds end,
    p_actual_distance_meters=>measured_meters,
    p_actual_recovery_duration_seconds=>es.recovery_duration_seconds+
      case when appointment.variant_code='V_0_v1' then 1 else 0 end);
   if appointment.variant_code='V_0_v1' and es.set_order=1 then
    first_work:=es.id;
    perform public.complete_workout_set_idempotent(receipt,es.id,
     p_actual_duration_seconds=>119,p_actual_recovery_duration_seconds=>121);
    perform public.correct_workout_set_result(es.id,'Revisión manual del tiempo',
     p_actual_duration_seconds=>119,p_actual_recovery_duration_seconds=>121);
   end if;
  end loop;
  perform public.finish_workout_observed_idempotent(gen_random_uuid(),execution,
   case when appointment.variant_code='V_0_v1' then effort when appointment.variant_code='E_0_v1' then 4 else 6 end,
   appointment.scheduled_date+time '10:00',0);
 end loop;
 if not exists(select 1 from public.workout_execution_sets where id=first_work and status='completed'
    and actual_duration_seconds=119 and actual_distance_meters is null and actual_recovery_duration_seconds=121) then
  raise exception 'Se perdió el tiempo real, la pausa o la distancia ausente';
 end if;
 if not exists(select 1 from public.workout_execution_sets where id=measured_work and actual_distance_meters>0) then
  raise exception 'Los metros siguen disponibles cuando el deportista los registra';
 end if;
 proposal:=public.calculate_preparation_week(g,wk);
 select o->'signal' into signal from jsonb_array_elements(proposal#>'{running,evidence,observations}') o
  where o#>>'{session,variant_code}'='V_0_v1';
 if proposal->>'status' is distinct from 'ready' or signal->>'status' is distinct from expected
   or signal->>'pace_seconds_per_km' is not null
   or proposal#>>'{running,mode}' is distinct from 'normal'
   or proposal#>>'{running,outcome}' is distinct from 'maintain'
   or exists(select 1 from jsonb_array_elements(proposal#>'{running,changes}') c where c->>'dimension' in ('dose_step','speed')) then
  raise exception 'La semana siguiente no distingue %: señal %, pauta %',expected,signal,proposal#>'{running,reason}';
 end if;
 if expected in ('tolerated_time','partial_time') and
   proposal#>>'{running,reason}' not like 'Intervalos registrados%' then
  raise exception 'Falta el reconocimiento del trabajo en la decisión';
 end if;
end $$;

do $$
declare
 wk date:='2026-11-02'; recipe jsonb:=public.running_session_v2('V',0,550,30);
 measured jsonb; timed jsonb; partial jsonb; evidence jsonb;
begin
 perform pg_temp.check_v0_week(false,7,'tolerated_time');
 perform pg_temp.check_v0_week(true,7,'partial_time');
 perform pg_temp.check_v0_week(false,9,'struggle');
 select jsonb_build_object('status','completed','rpe',7,'sets',
  jsonb_agg(jsonb_build_object('status','completed','seconds',seg->'seconds',
   'meters',(seg->>'seconds')::numeric*1000/coalesce((seg->>'pace_max')::numeric,360),
   'recovery_seconds',seg->'recovery_seconds') order by ord))
 into measured from jsonb_array_elements(recipe->'segments') with ordinality a(seg,ord);
 select jsonb_set(measured,'{sets}',jsonb_agg(s-'meters' order by ord)) into timed
 from jsonb_array_elements(measured->'sets') with ordinality a(s,ord);
 evidence:=public.running_dose_evidence_v6(jsonb_build_array(
  jsonb_build_object('date',wk-14,'session',recipe,'execution',measured),
  jsonb_build_object('date',wk-7,'session',recipe,'execution',timed)),wk,'V',0,550,1);
 if evidence->>'compatible_successes' is distinct from '1'
   or evidence#>>'{samples,0,date}' is distinct from (wk-14)::text then
  raise exception 'El registro por tiempo debe conservar el parcial previo y no acreditar otro: %',evidence;
 end if;
 partial:=jsonb_set(timed-'rpe','{sets,4}','{"status":"skipped"}');
 if public.running_evaluate_manual_time_v1(recipe,partial)->>'status' is distinct from 'partial_time' then
  raise exception 'La última repetición omitida cuenta como parcial aunque ahí se pidiera el esfuerzo';
 end if;
end $$;

select 'La semana distingue tolerancia por tiempo, trabajo parcial y esfuerzo alto' as result;
rollback;
