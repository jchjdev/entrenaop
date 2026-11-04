-- Auditoría del 04/11/2026. Ejecutar solo contra desarrollo identificado.
-- Cuatro citas publicadas en días distintos se realizan en el mismo día local.
-- La consulta muestra el número real de días, el cómputo de la política y si
-- el control llega a materializarse. La colocación depende de la agenda.
-- Se usa el reloj vigente para no redefinir funciones ni alterar fechas de
-- citas o ejecuciones. Solo cuentas ficticias y ROLLBACK.
begin;
set local timezone='UTC';
set local statement_timeout='45s';
create function pg_temp.audit_running_control_days(declared_minutes int) returns jsonb language plpgsql as $$
declare
 u uuid:=gen_random_uuid(); g uuid; a uuid; wk date:=current_date-extract(isodow from current_date)::int+1;
 target date:=wk+31; p jsonb; next_plan jsonb; s record; es record; e uuid; preview jsonb;
 n int:=0; signed_offset int:=(12-extract(hour from now())::int)*60;
 availability jsonb:='{"1":60,"2":60,"3":60,"4":60,"5":60,"6":60,"7":60}';
begin
 insert into auth.users(id,email) values(u,u||'@audit-run-days-live.invalid');
 perform set_config('request.jwt.claim.sub',u::text,true);
 update public.profiles set fecha_nacimiento='1996-01-01' where id=u;
 insert into public.pro_access_grants(user_id,source,starts_at,ends_at,reason)
 values(u,'development_manual',now()-interval '1 day',now()+interval '1 day','Auditoría de días de práctica');
 insert into public.preparation_goals(user_id,program_id,target_date) values(u,'fas_periodic_assessment',target) returning id into g;
 insert into public.fas_periodic_assessments(user_id,preparation_goal_id,catalog_version,category,age_at_assessment,age_band,is_pre_effective_reference,completed_at)
 values(u,g,'es_def_15_2026_periodic_2027_v1','men',30,'26_30',true,now()-interval '14 days') returning id into a;
 insert into public.fas_periodic_marks values(a,'run_2000_m',595000);
 insert into public.running_reference_selections(preparation_goal_id,reference_source,reference_record_id) values(g,'fasPeriodicAssessment',a::text);
 insert into public.running_intake_contexts(preparation_goal_id,context_version,available_minutes_by_weekday,
  reserved_strength_weekdays,running_days_last_four_weeks,running_minutes_last_four_weeks,recent_weeks_end_on,
  reports_pain,requires_professional_review,health_observed_at,comfortable_continuous_minutes,target_2k_seconds,goal_mode)
 values(g,'running_initial_context_v3',availability,'{}',array[4,4,4,4],array[declared_minutes,declared_minutes,declared_minutes,declared_minutes],
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
  for es in select * from public.workout_execution_sets where execution_id=e order by block_order,item_order,set_order loop
   perform public.complete_workout_set_idempotent(gen_random_uuid(),es.id,
    p_actual_duration_seconds=>coalesce(es.target_duration_seconds,ceil(es.target_distance_meters*coalesce(es.target_pace_max_seconds_per_km,360)/1000.0)::int),
    p_actual_distance_meters=>coalesce(es.target_distance_meters,es.target_duration_seconds*1000.0/coalesce(es.target_pace_max_seconds_per_km,360)),
    p_actual_recovery_duration_seconds=>es.recovery_duration_seconds,p_actual_rpe=>case when es.target_rpe is not null then 4 end);
  end loop;
  perform public.finish_workout_observed_idempotent(gen_random_uuid(),e,4,now()+n*interval '1 millisecond',signed_offset);
 end loop;
 next_plan:=public.calculate_preparation_week(g,wk+7);
 if not (next_plan ? 'decision_id') then
  raise exception 'No se publicó automáticamente la siguiente semana: %',next_plan->>'status';
 end if;
 return jsonb_build_object(
  'initial_phase',p->'running'->'phase',
  'initial_scheduled_days',(select count(distinct sw.scheduled_date) from public.scheduled_workouts sw
    where sw.preparation_goal_id=g and sw.scheduled_date between wk and wk+6),
  'next_phase',next_plan->'running'->'phase',
  'next_observed',(select jsonb_agg(jsonb_build_object('date',o->'date','status',o->'signal'->'status'))
    from jsonb_array_elements(next_plan->'running'->'evidence'->'observations') o),
  'distinct_tolerated_days',(select count(distinct o->>'date')
    from jsonb_array_elements(next_plan->'running'->'evidence'->'observations') o where o->'signal'->>'status'='tolerated'),
  'control_facts',next_plan#>'{control_schedule,reviewed,0,facts}',
  'control_decision',next_plan#>'{control_schedule,reviewed,0,decision}',
  'control_scheduled',next_plan#>'{control_schedule,scheduled}',
  'materialized_control_count',(select count(*)
    from public.running_week_sessions rs join public.scheduled_workouts sw on sw.id=rs.scheduled_workout_id
    where sw.preparation_goal_id=g and sw.scheduled_date between wk+7 and wk+13 and rs.prescription ? 'control')
 );
end $$;
select declared_minutes,pg_temp.audit_running_control_days(declared_minutes) result
from (values (140),(160)) fixture(declared_minutes);
rollback;
