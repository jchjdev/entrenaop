-- Repite la publicación automática con trabajo completo o recortado.
begin;
set local timezone='UTC';
set local statement_timeout='55s';

create function pg_temp.flexion_control_fixture(shortened boolean) returns jsonb language plpgsql as $$
declare
 athlete uuid:=gen_random_uuid(); goal uuid; flexion uuid; execution uuid; cloned_id uuid;
 wk date:=current_date+1-extract(isodow from current_date)::int;
 latest_day date:=least(current_date,wk+3); recorded_on timestamptz;
 proposal jsonb; candidate jsonb; appointment record; exercise_set record; template_source record;
 performed_flexions int:=0;
begin
 insert into auth.users(id,email) values(athlete,athlete||'@flexion-control-dose.invalid');
 insert into public.pro_access_grants(user_id,source,ends_at,reason)
 values(athlete,'development_manual',now()+interval '1 day','Fixture de dosis para control');
 perform set_config('request.jwt.claim.sub',athlete::text,true);
 update public.profiles set fecha_nacimiento='1996-01-01' where id=athlete;
 insert into public.preparation_goals(user_id,program_id,target_date)
 values(athlete,'fas_periodic_assessment',current_date+120) returning id into goal;
 perform public.save_performance_context('{"1":60,"3":60,"5":60}',array['cones','measuring_tape','tennis_ball','chalk'],false,true);
 flexion:=public.save_performance_reference(goal,jsonb_build_object(
  'goal_code','push_up_standard','goal_version',1,'goal_measurement','REPS_IN_TIME',
  'program_objective_key','legacy:upper_body_push_ups_2_min',
  'task','{"exercise_code":"push_up_standard","exercise_version":1,"protocol_key":"floor_v1","protocol_version":1,"setup_key":"Suelo y recorrido completo","measurement":"REPS","load_mode":"bodyweight","target_value":8,"target_rir":3,"intent":"work"}'::jsonb,
  'reference_kind','repeated_work','targets','[55,55]'::jsonb,'observed_on',current_date-13,
  'current_capacity_confirmed',true,'reported_rir',3,'rest_seconds',120,'frequency',2));
 perform public.save_performance_reference(goal,jsonb_build_object(
  'goal_code','front_plank_forearms','goal_version',1,'goal_measurement','DURATION','program_objective_key','legacy:abdominal_plank',
  'task','{"exercise_code":"front_plank_forearms","exercise_version":1,"protocol_key":"def_15_2026_plank","protocol_version":1,"setup_key":"Suelo antideslizante y codos bajo hombros","measurement":"DURATION","load_mode":"bodyweight","target_value":50,"intent":"work"}'::jsonb,
  'reference_kind','repeated_work','targets','[50,45]'::jsonb,'observed_on',current_date,'current_capacity_confirmed',true,'reported_rpe',7,'rest_seconds',90,'frequency',1));
 perform public.save_performance_reference(goal,jsonb_build_object(
  'goal_code','slalom_ball_course_16m','goal_version',1,'goal_measurement','TIME_FOR_COURSE','program_objective_key','legacy:agility_speed_circuit','equipment_confirmed',true,
  'task','{"exercise_code":"slalom_ball_course_16m","exercise_version":1,"protocol_key":"def_15_2026_agility","protocol_version":1,"setup_key":"Siete conos y corredor medido de 16 por 2 metros","measurement":"TIME_FOR_COURSE","load_mode":"bodyweight","target_value":14.3,"intent":"practice"}'::jsonb,
  'reference_kind','repeated_work','targets','[14.3,14.5]'::jsonb,'observed_on',current_date,'current_capacity_confirmed',true,'rest_seconds',180,'frequency',1));
 perform public.save_adaptive_program_preferences(goal,current_date+120,'{}','performance');
 proposal:=public.preview_adaptive_program_activation(goal,wk);
 perform public.activate_adaptive_program(goal,wk,proposal);

 -- Las citas históricas son copias de las recetas publicadas. El ejecutor y
 -- el cierre siguen usando sus RPC, con cuatro fechas de realización reales de la fixture.
 for template_source in
  select sw.*,pw.decision_id,pw.block_order,pw.dose from public.scheduled_workouts sw
  join public.performance_week_work pw on pw.scheduled_workout_id=sw.id
  where pw.reference_id=flexion order by sw.scheduled_date
 loop
  insert into public.scheduled_workouts(user_id,template_id,template_name,template_version,estimated_duration_minutes,
   preparation_goal_id,scheduled_date,order_index,source,status)
  values(athlete,template_source.template_id,template_source.template_name,template_source.template_version,
   template_source.estimated_duration_minutes,goal,template_source.scheduled_date-14,template_source.order_index,template_source.source,'planned')
  returning id into cloned_id;
  insert into public.performance_week_work(decision_id,scheduled_workout_id,reference_id,block_order,dose)
  values(template_source.decision_id,cloned_id,flexion,template_source.block_order,template_source.dose);
 end loop;

 for appointment in
  select sw.id,sw.scheduled_date,pw.block_order from public.scheduled_workouts sw
  left join public.performance_week_work pw on pw.scheduled_workout_id=sw.id and pw.reference_id=flexion
  where sw.preparation_goal_id=goal and sw.status='planned' and sw.scheduled_date between wk-14 and wk+6
  order by sw.scheduled_date
 loop
  recorded_on:=now();
  if appointment.block_order is not null then
   performed_flexions:=performed_flexions+1;
   recorded_on:=(latest_day-(array[8,7,1,0])[performed_flexions])+time '00:00';
  end if;
  execution:=public.start_reviewed_scheduled_workout(athlete,appointment.id,
    public.get_scheduled_workout_preview(athlete,appointment.id)->>'revision');
  update public.workout_executions set started_at=least(started_at,recorded_on-interval '1 minute')
  where id=execution and user_id=athlete;
  for exercise_set in select * from public.workout_execution_sets where execution_id=execution order by block_order,item_order,set_order loop
   if exercise_set.performance_prescription is null then
    perform public.complete_workout_set_idempotent(gen_random_uuid(),exercise_set.id,p_actual_duration_seconds=>exercise_set.target_duration_seconds);
   else
    perform public.complete_performance_set_idempotent(gen_random_uuid(),exercise_set.id,
     jsonb_strip_nulls(jsonb_build_object('value',case when exercise_set.performance_prescription->>'measurement'<>'PASS_FAIL' then
       case when shortened and appointment.scheduled_date<wk and exercise_set.block_order=appointment.block_order then 1
       else (exercise_set.performance_prescription->>'target_value')::numeric end end,
       'succeeded',case when exercise_set.performance_prescription->>'measurement'='PASS_FAIL' then true end,
       'rir',case when exercise_set.performance_prescription->>'effort_mode'='rir' then 3 end,
       'rpe',case when exercise_set.performance_prescription->>'effort_mode'='rpe' then 6 end,
       'technique_valid',true,'conditions_confirmed',true,'tolerated',true,'stop_reason','none')));
   end if;
  end loop;
  perform public.finish_workout_observed_idempotent(gen_random_uuid(),execution,5,recorded_on,0);
 end loop;
 if performed_flexions<>4 then raise exception 'Se necesitan cuatro prácticas de flexiones: %',performed_flexions; end if;

 proposal:=public.calculate_preparation_week(goal,wk+7);
 if proposal->>'decision_id' is null then raise exception 'Falta la semana publicada: %',proposal->>'status'; end if;
 select value into strict candidate from jsonb_array_elements(public.adaptive_control_candidates_v1(goal,wk+7,proposal))
 where value->>'reference_id'=flexion::text;
 return jsonb_build_object('candidate',candidate,'scheduled',coalesce((select jsonb_agg(c)
  from jsonb_array_elements(proposal#>'{control_schedule,scheduled}') c where c->>'reference_id'=flexion::text),'[]'));
end $$;

do $$
declare partial jsonb:=pg_temp.flexion_control_fixture(true); complete jsonb;
begin
 if partial#>>'{candidate,facts,tolerated_days}' is distinct from '2'
   or partial#>>'{candidate,facts,new_days}' is distinct from '2'
   or partial#>>'{candidate,decision,action}'='control' or partial->'scheduled' is distinct from '[]'::jsonb then
  raise exception 'Dos dosis recortadas no acreditan cuatro días ni justifican un control: %',partial;
 end if;
 complete:=pg_temp.flexion_control_fixture(false);
 if complete#>>'{candidate,facts,tolerated_days}' is distinct from '4'
   or complete#>>'{candidate,facts,new_days}' is distinct from '4'
   or complete#>>'{candidate,decision,action}' is distinct from 'control'
   or jsonb_array_length(complete->'scheduled')<>1 then
  raise exception 'Cuatro dosis completas deben conservar la elegibilidad del control: %',complete;
 end if;
end $$;

select 'Flexiones: se acredita la dosis completa antes de programar el control de dos minutos' as result;
rollback;
