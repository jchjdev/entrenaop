-- Regresión por los RPC de la app, con cuentas ficticias y ROLLBACK.
-- La continuidad distingue el número de salidas de los días de práctica.
begin;
set local timezone='UTC';
set local statement_timeout='45s';
create function pg_temp.running_control_distinct_days(separate_days boolean) returns jsonb language plpgsql as $$
declare
 u uuid:=gen_random_uuid(); g uuid; a uuid; wk date:=current_date-extract(isodow from current_date)::int+1;
 target date:=wk+31; p jsonb; next_plan jsonb; s record; es record; e uuid; preview jsonb; performed timestamptz;
 n int:=0; signed_offset int:=(12-extract(hour from now())::int)*60;
 availability jsonb:='{"1":60,"2":60,"3":60,"4":60,"5":60,"6":60,"7":60}';
begin
 insert into auth.users(id,email) values(u,u||'@running-control-days.invalid');
 perform set_config('request.jwt.claim.sub',u::text,true);
 update public.profiles set fecha_nacimiento='1996-01-01' where id=u;
 insert into public.pro_access_grants(user_id,source,starts_at,ends_at,reason)
 values(u,'development_manual',now()-interval '1 day',now()+interval '1 day','Fixture SQL de días de práctica de carrera');
 insert into public.preparation_goals(user_id,program_id,target_date) values(u,'fas_periodic_assessment',target) returning id into g;
 insert into public.fas_periodic_assessments(user_id,preparation_goal_id,catalog_version,category,age_at_assessment,age_band,is_pre_effective_reference,completed_at)
 values(u,g,'es_def_15_2026_periodic_2027_v1','men',30,'26_30',true,now()-interval '14 days') returning id into a;
 insert into public.fas_periodic_marks values(a,'run_2000_m',595000);
 insert into public.running_reference_selections(preparation_goal_id,reference_source,reference_record_id) values(g,'fasPeriodicAssessment',a::text);
 insert into public.running_intake_contexts(preparation_goal_id,context_version,available_minutes_by_weekday,
  reserved_strength_weekdays,running_days_last_four_weeks,running_minutes_last_four_weeks,recent_weeks_end_on,
  reports_pain,requires_professional_review,health_observed_at,comfortable_continuous_minutes,target_2k_seconds,goal_mode)
 values(g,'running_initial_context_v3',availability,'{}',array[4,4,4,4],array[160,160,160,160],
  wk-1,false,false,now(),60,500,'time');
 perform public.save_performance_context(availability,'{}',false,true);
 perform public.save_adaptive_program_preferences(g,target,'{}','running');
 p:=public.preview_adaptive_program_activation(g,wk);
 if p->>'status' is distinct from 'ready' then raise exception 'No hay plan listo: % %',p->>'status',p->'pending'; end if;
 if jsonb_array_length(p->'running'->'sessions')<>4 then raise exception 'No pauta cuatro salidas: %',p->'running'->'sessions'; end if;
 perform public.activate_adaptive_program(g,wk,p);
 for s in select sw.id from public.scheduled_workouts sw where sw.preparation_goal_id=g and sw.status='planned' order by sw.scheduled_date loop
  n:=n+1;
  preview:=public.get_scheduled_workout_preview(u,s.id);
  e:=public.start_reviewed_scheduled_workout(u,s.id,preview->>'revision');
  performed:=now()+n*interval '1 millisecond';
  if separate_days then
   -- Simula cuatro inicios offline en la cuenta ficticia. El día lo guarda
   -- el RPC habitual de cierre observado, con el reloj de Dev intacto.
   performed:=now()-make_interval(days=>4-n);
   update public.workout_executions set started_at=performed-interval '1 hour' where id=e and user_id=u;
  end if;
  for es in select * from public.workout_execution_sets where execution_id=e order by block_order,item_order,set_order loop
   perform public.complete_workout_set_idempotent(gen_random_uuid(),es.id,
    p_actual_duration_seconds=>coalesce(es.target_duration_seconds,ceil(es.target_distance_meters*coalesce(es.target_pace_max_seconds_per_km,360)/1000.0)::int),
    p_actual_distance_meters=>coalesce(es.target_distance_meters,es.target_duration_seconds*1000.0/coalesce(es.target_pace_max_seconds_per_km,360)),
    p_actual_recovery_duration_seconds=>es.recovery_duration_seconds,p_actual_rpe=>case when es.target_rpe is not null then 4 end);
  end loop;
  perform public.finish_workout_observed_idempotent(gen_random_uuid(),e,4,performed,signed_offset);
 end loop;
 next_plan:=public.calculate_preparation_week(g,wk+7);
 if not (next_plan ? 'decision_id') then
  raise exception 'No se publicó automáticamente la siguiente semana: %',next_plan->>'status';
 end if;
 if n<>4 or (select count(distinct scheduled_date) from public.scheduled_workouts
  where preparation_goal_id=g and scheduled_date between wk and wk+6)<>4 then
  raise exception 'La prueba requiere cuatro citas publicadas en días distintos';
 end if;
 if (select count(*) from jsonb_array_elements(next_plan->'running'->'evidence'->'observations') o
     where o->'signal'->>'status'='tolerated')<>4 then
  raise exception 'La prueba requiere cuatro salidas toleradas en la decisión publicada';
 end if;
 return jsonb_build_object(
  'distinct_tolerated_days',(select count(distinct o->>'date')
    from jsonb_array_elements(next_plan->'running'->'evidence'->'observations') o where o->'signal'->>'status'='tolerated'),
  'facts',next_plan#>'{control_schedule,reviewed,0,facts}',
  'decision',next_plan#>'{control_schedule,reviewed,0,decision}',
  'scheduled_controls',next_plan#>'{control_schedule,scheduled}',
  'materialized_control_count',(select count(*)
    from public.running_week_sessions rs join public.scheduled_workouts sw on sw.id=rs.scheduled_workout_id
    where sw.preparation_goal_id=g and sw.scheduled_date between wk+7 and wk+13 and rs.prescription ? 'control')
 );
end $$;
do $$
declare
 separate_days jsonb:=pg_temp.running_control_distinct_days(true);
 same_day jsonb:=pg_temp.running_control_distinct_days(false);
begin
 if separate_days->>'distinct_tolerated_days' is distinct from '4'
   or separate_days#>>'{facts,tolerated_days}' is distinct from '4'
   or separate_days#>>'{facts,recent_days}' is distinct from '4'
   or separate_days#>>'{facts,new_days}' is distinct from '4'
   or separate_days#>>'{decision,action}' is distinct from 'control'
   or separate_days#>>'{decision,reason}' is distinct from 'phase_transfer' then
  raise exception 'Cuatro días de práctica deben conservar la elegibilidad del control: %',separate_days;
 end if;
 if same_day->>'distinct_tolerated_days' is distinct from '1'
   or same_day#>>'{facts,tolerated_days}' is distinct from '1'
   or same_day#>>'{facts,recent_days}' is distinct from '1'
   or same_day#>>'{facts,new_days}' is distinct from '1'
   or same_day#>>'{decision,action}' is distinct from 'none'
   or same_day#>>'{decision,reason}' is distinct from 'observe_ordinary_work_first'
   or same_day->'scheduled_controls' is distinct from '[]'::jsonb
   or same_day->>'materialized_control_count' is distinct from '0' then
  raise exception 'Cuatro salidas el mismo día solo acreditan un día y no un control: %',same_day;
 end if;
end $$;
select 'Control de carrera: cuatro salidas en un día no habilitan un control; cuatro días mantienen su elegibilidad' as result;
rollback;
