-- Reproduce por los RPC vigentes la adaptación de la semana de carrera.
-- Los planes anteriores son fixtures acotadas. Las fechas de realización
-- se registran con los RPC habituales, aparte de la recepción en servidor.
begin;
set local timezone='UTC';
set local statement_timeout='45s';

create function pg_temp.finish_running_order_fixture(
 owner uuid, execution uuid, performed timestamptz, difficult boolean, effort int
) returns void language plpgsql as $$
declare es record; pace numeric;
begin
 -- Solo los inicios de esta cuenta ficticia se sitúan antes del registro offline.
 update public.workout_executions set started_at=performed-interval '1 hour'
 where id=execution and user_id=owner;
 if not found then raise exception 'No se reconoce la ejecución de la fixture'; end if;
 if difficult then
  perform public.abandon_workout_observed_idempotent(gen_random_uuid(),execution,'too_difficult',performed,0);
 else
  for es in select * from public.workout_execution_sets where execution_id=execution order by block_order,item_order,set_order loop
   pace:=coalesce(es.target_pace_max_seconds_per_km-1,450);
   perform public.complete_workout_set_idempotent(gen_random_uuid(),es.id,
    p_actual_duration_seconds=>coalesce(es.target_duration_seconds,ceil(es.target_distance_meters*pace/1000.0)::int),
    p_actual_distance_meters=>coalesce(es.target_distance_meters,es.target_duration_seconds*1000.0/pace),
    p_actual_recovery_duration_seconds=>es.recovery_duration_seconds,
    p_actual_rpe=>case when es.target_rpe is not null then effort end);
  end loop;
  perform public.finish_workout_observed_idempotent(gen_random_uuid(),execution,effort,performed,0);
 end if;
 if not exists(select 1 from public.workout_executions x where x.id=execution and x.user_id=owner
   and x.performed_at=performed and x.completed_at>performed) then
  raise exception 'La fixture debe conservar la realización y recibirla después';
 end if;
end $$;

create function pg_temp.run_running_order_fixture(difficult_lower_uuid boolean, difficult_later boolean default true) returns jsonb language plpgsql as $$
declare
 u uuid:=gen_random_uuid(); g uuid; a uuid;
 wk date:=current_date-extract(isodow from current_date)::int+8;
 s jsonb:=public.running_session_v2('S',0,577,40); easy jsonb:=public.running_session_v2('E',0,577,30);
 availability jsonb:='{"1":60,"3":60,"6":60}'; p jsonb; previous jsonb; base jsonb;
 pair uuid[]; good_id uuid; difficult_id uuid; attempt int; appointment record; execution uuid;
 received_ok boolean:=false;
begin
 insert into auth.users(id,email) values(u,u||'@running-order-audit.invalid');
 perform set_config('request.jwt.claim.sub',u::text,true);
 update public.profiles set fecha_nacimiento='1996-01-01' where id=u;
 insert into public.pro_access_grants(user_id,source,starts_at,ends_at,reason)
 values(u,'development_manual',now()-interval '1 day',now()+interval '1 day','Fixture SQL de orden de carrera');
 insert into public.preparation_goals(user_id,program_id,target_date)
 values(u,'fas_periodic_assessment',wk+21) returning id into g;
 insert into public.fas_periodic_assessments(user_id,preparation_goal_id,catalog_version,category,age_at_assessment,age_band,is_pre_effective_reference,completed_at)
 values(u,g,'es_def_15_2026_periodic_2027_v1','men',30,'26_30',true,now()-interval '7 days') returning id into a;
 insert into public.fas_periodic_marks values(a,'run_2000_m',577000);
 insert into public.running_reference_selections(preparation_goal_id,reference_source,reference_record_id)
 values(g,'fasPeriodicAssessment',a::text);
 insert into public.running_intake_contexts(preparation_goal_id,context_version,available_minutes_by_weekday,
  reserved_strength_weekdays,running_days_last_four_weeks,running_minutes_last_four_weeks,recent_weeks_end_on,
  reports_pain,requires_professional_review,health_observed_at,comfortable_continuous_minutes,target_2k_seconds,goal_mode)
 values(g,'running_initial_context_v3',availability,'{}',array[3,3,3,3],array[90,90,90,90],
  wk-8,false,false,now(),60,500,'time');
 perform public.save_performance_context(availability,'{}',false,true);
 perform public.save_adaptive_program_preferences(g,wk+21,'{}','running');

 -- Se prepara el historial ficticio de S:0 y sus recetas iniciales. La semana
 -- examinada la calcula y publica el recorrido de producción al cerrar las citas.
 base:=jsonb_build_object('policy_version','running_2k_v6','basis','recent','outcome','maintain','mode','normal',
  'normal_budget',90,'anchor_seconds',577,'load_weeks',0,'rotation',1,
  'reference_source','fasPeriodicAssessment','reference_record_id',a);
 perform public.materialize_running_week_plan(g,wk-14,base||jsonb_build_object('week_start',wk-14,'sessions',
  jsonb_build_array(s||jsonb_build_object('date',wk-14),s||jsonb_build_object('date',wk-9))));
 select array_agg(id order by scheduled_date) into pair from public.scheduled_workouts
 where preparation_goal_id=g and scheduled_date between wk-14 and wk-8;
 if cardinality(pair) is distinct from 2 then raise exception 'Faltan las dos citas de específico'; end if;
 -- El UUID lo asigna el RPC. Se reintenta dentro de un savepoint hasta fijar
 -- el orden opuesto sin alterar las citas, el resultado ni el instante realizado.
 for attempt in 1..64 loop
  begin
   good_id:=public.start_reviewed_scheduled_workout(u,pair[1],public.get_scheduled_workout_preview(u,pair[1])->>'revision');
   difficult_id:=public.start_reviewed_scheduled_workout(u,pair[2],public.get_scheduled_workout_preview(u,pair[2])->>'revision');
   if (difficult_id<good_id) is distinct from difficult_lower_uuid then raise sqlstate 'P0123'; end if;
   received_ok:=true;
   exit;
  exception when sqlstate 'P0123' then
   null;
  end;
 end loop;
 if not received_ok then raise exception 'No se pudo fijar el orden relativo de UUID de la fixture'; end if;
 -- El resultado difícil se recibe primero aunque haya ocurrido más tarde.
 -- Invertir solo la ocurrencia es el control positivo de que sí importa.
 perform pg_temp.finish_running_order_fixture(u,difficult_id,
  wk-14+case when difficult_later then time '18:00' else time '09:00' end,true,6);
 perform pg_temp.finish_running_order_fixture(u,good_id,
  wk-14+case when difficult_later then time '09:00' else time '18:00' end,false,6);
 if public.workout_block_outcome_v1(difficult_id)->>'abandonment_reason' is distinct from 'too_difficult' then
  raise exception 'La sesión real no conserva la dificultad del bloque';
 end if;

 previous:=base||jsonb_build_object('week_start',wk-7,'sessions',jsonb_build_array(
  s||jsonb_build_object('date',wk-7),easy||jsonb_build_object('date',wk-5),easy||jsonb_build_object('date',wk-2)));
 perform public.materialize_running_week_plan(g,wk-7,previous);
 update public.adaptive_program_states set auto_advance=true,status='training',continuation_code='waiting_results',
  started_week=wk-14,last_generated_week=wk-7 where preparation_goal_id=g and user_id=u;
 for appointment in select sw.id,sw.scheduled_date from public.scheduled_workouts sw
  where sw.preparation_goal_id=g and sw.scheduled_date between wk-7 and wk-1 and sw.status='planned' order by sw.scheduled_date loop
  execution:=public.start_reviewed_scheduled_workout(u,appointment.id,public.get_scheduled_workout_preview(u,appointment.id)->>'revision');
  perform pg_temp.finish_running_order_fixture(u,execution,
   least(appointment.scheduled_date+time '12:00',now()-interval '1 second'),false,case when appointment.scheduled_date=wk-7 then 6 else 4 end);
 end loop;
 p:=public.calculate_preparation_week(g,wk);
 if p->>'decision_id' is null then raise exception 'No se publicó la continuación automática: % %',p->>'status',p->'pending'; end if;
 return jsonb_build_object(
  'outcome',p->'running'->'outcome',
  'mode',p->'running'->'mode',
  'phase',p->'running'->'phase',
  'observations',(select count(*) from jsonb_array_elements(p->'running'->'evidence'->'observations') o),
  'prescriptions',(select jsonb_agg(rs.prescription order by sw.scheduled_date) from public.running_week_sessions rs
   join public.scheduled_workouts sw on sw.id=rs.scheduled_workout_id
   join public.running_week_decisions d on d.id=rs.decision_id
   where sw.preparation_goal_id=g and d.week_start=wk and d.superseded_at is null),
  'changes',p->'running'->'changes'
 );
end $$;

do $$
declare
 difficult_first_uuid jsonb:=pg_temp.run_running_order_fixture(true);
 tolerated_first_uuid jsonb:=pg_temp.run_running_order_fixture(false);
 tolerated_later jsonb;
begin
 if difficult_first_uuid->>'observations' is distinct from '5' or tolerated_first_uuid->>'observations' is distinct from '5'
   or jsonb_array_length(difficult_first_uuid->'prescriptions') is distinct from 3
   or jsonb_array_length(tolerated_first_uuid->'prescriptions') is distinct from 3 then
  raise exception 'Faltan observaciones o recetas publicadas para comparar el orden';
 end if;
 if difficult_first_uuid is distinct from tolerated_first_uuid then
  raise exception 'El UUID cambia la prescripción: adversa primero S:%; tolerada primero S:%',
   difficult_first_uuid#>>'{prescriptions,0,step}',tolerated_first_uuid#>>'{prescriptions,0,step}';
 end if;
 if not exists(select 1 from jsonb_array_elements(difficult_first_uuid->'prescriptions') p
    where p->>'family'='S' and p->>'step'='0') then
  raise exception 'Una dificultad posterior en el día debe conservar S:0';
 end if;
 tolerated_later:=pg_temp.run_running_order_fixture(true,false);
 if tolerated_later is distinct from pg_temp.run_running_order_fixture(false,false) then
  raise exception 'El UUID cambia la publicación cuando la tolerancia fue posterior';
 end if;
 if not exists(select 1 from jsonb_array_elements(tolerated_later->'prescriptions') p
    where p->>'family'='S' and p->>'step'='1') then
  raise exception 'Al invertir la realización, la tolerancia posterior y la de la semana siguiente deben habilitar S:1';
 end if;
end $$;
select 'El orden de realización decide la dosis específica; cambiar solo el UUID no cambia la semana publicada' as result;
rollback;
