-- Reproduce el recorrido de la app con cuentas ficticias y sin alterar la agenda.
begin;
set local timezone='UTC';

create function pg_temp.same_day_adaptive_fixture(difficult_first boolean default null) returns jsonb language plpgsql as $$
declare
 u uuid:=gen_random_uuid(); g uuid; ref_id uuid;
 wk date:=current_date+1-extract(isodow from current_date)::int;
 p jsonb; preview jsonb; s record; es record; e uuid; n int:=0; ordinal int:=0; difficult boolean;
 observed timestamptz; local_offset int; completed_day date; prior_ids uuid[]:='{}'; initial_targets jsonb;
begin
 insert into auth.users(id,email) values(u,'adaptive-order-'||u||'@example.invalid');
 insert into public.pro_access_grants(user_id,source,ends_at,reason)
 values(u,'development_manual',now()+interval '1 day','Fixture SQL de orden de evidencia');
 perform set_config('request.jwt.claim.sub',u::text,true);
 update public.profiles set fecha_nacimiento='1996-01-01' where id=u;
 insert into public.preparation_goals(user_id,program_id,target_date)
 values(u,'fas_periodic_assessment',current_date+120) returning id into g;
 perform public.save_performance_context('{"1":60,"3":60,"5":60}',array['cones','measuring_tape','tennis_ball','chalk'],false,true);
 ref_id:=public.save_performance_reference(g,jsonb_build_object(
  'goal_code','push_up_standard','goal_version',1,'goal_measurement','REPS_IN_TIME',
  'program_objective_key','legacy:upper_body_push_ups_2_min',
  'task','{"exercise_code":"push_up_standard","exercise_version":1,"protocol_key":"floor_v1","protocol_version":1,"setup_key":"Suelo y recorrido completo","measurement":"REPS","load_mode":"bodyweight","target_value":8,"target_rir":3,"intent":"work"}'::jsonb,
  'reference_kind','repeated_work','targets','[55,55]'::jsonb,'observed_on',current_date,
  'current_capacity_confirmed',true,'reported_rir',3,'rest_seconds',120,'frequency',2));
 perform public.save_performance_reference(g,jsonb_build_object('goal_code','front_plank_forearms','goal_version',1,'goal_measurement','DURATION','program_objective_key','legacy:abdominal_plank',
 'task','{"exercise_code":"front_plank_forearms","exercise_version":1,"protocol_key":"def_15_2026_plank","protocol_version":1,"setup_key":"Suelo antideslizante y codos bajo hombros","measurement":"DURATION","load_mode":"bodyweight","target_value":50,"intent":"work"}'::jsonb,
 'reference_kind','repeated_work','targets','[50,45]'::jsonb,'observed_on',current_date,'current_capacity_confirmed',true,'reported_rpe',7,'rest_seconds',90,'frequency',1));
 perform public.save_performance_reference(g,jsonb_build_object('goal_code','slalom_ball_course_16m','goal_version',1,'goal_measurement','TIME_FOR_COURSE','program_objective_key','legacy:agility_speed_circuit','equipment_confirmed',true,
 'task','{"exercise_code":"slalom_ball_course_16m","exercise_version":1,"protocol_key":"def_15_2026_agility","protocol_version":1,"setup_key":"Siete conos y corredor medido de 16 por 2 metros","measurement":"TIME_FOR_COURSE","load_mode":"bodyweight","target_value":14.3,"intent":"practice"}'::jsonb,
 'reference_kind','repeated_work','targets','[14.3,14.5]'::jsonb,'observed_on',current_date,'current_capacity_confirmed',true,'rest_seconds',180,'frequency',1));
 perform public.save_adaptive_program_preferences(g,current_date+120,'{}','performance');
 p:=public.preview_adaptive_program_activation(g,wk);
 if p->>'status' is distinct from 'ready' then raise exception 'Propuesta no publicable: % %',p->>'status',p->'pending'; end if;
 select value->'dose'->'targets' into initial_targets from jsonb_array_elements(p->'proposals')
 where value->>'reference_id'=ref_id::text;
 if initial_targets is null then raise exception 'Falta la dosis inicial de flexiones'; end if;
 perform public.activate_adaptive_program(g,wk,p);

 -- Las citas son distintas, pero se realizan el mismo día. El reloj observado
 -- conserva su orden sin alterar fechas de agenda ni resultados persistidos.
 local_offset:=(12-extract(hour from now())::int)*60;
 completed_day:=((now() at time zone 'UTC')+make_interval(mins=>local_offset))::date;
 for s in
  select sw.id,sw.scheduled_date,pw.block_order
  from public.scheduled_workouts sw left join public.performance_week_work pw on pw.scheduled_workout_id=sw.id and pw.reference_id=ref_id
  where sw.preparation_goal_id=g and sw.status='planned' and sw.scheduled_date between wk and wk+6
  order by sw.scheduled_date
 loop
  ordinal:=ordinal+1;
  observed:=now()+ordinal*interval '1 millisecond';
  preview:=public.get_scheduled_workout_preview(u,s.id);
  e:=public.start_reviewed_scheduled_workout(u,s.id,preview->>'revision');
  difficult:=false;
  if s.block_order is not null then
   n:=n+1;
   difficult:=coalesce((n=1)=difficult_first,false);
   prior_ids:=array_append(prior_ids,e);
  end if;
  for es in select * from public.workout_execution_sets where execution_id=e order by block_order,item_order,set_order loop
   if es.performance_prescription is null then
    perform public.complete_workout_set_idempotent(gen_random_uuid(),es.id,p_actual_duration_seconds=>es.target_duration_seconds);
   elsif es.block_order=s.block_order and difficult then
    exit;
   else
    perform public.complete_performance_set_idempotent(gen_random_uuid(),es.id,
     jsonb_strip_nulls(jsonb_build_object('value',case when es.performance_prescription->>'measurement'<>'PASS_FAIL' then es.performance_prescription->'target_value' end,
       'succeeded',case when es.performance_prescription->>'measurement'='PASS_FAIL' then true end,
       'rir',case when es.performance_prescription->>'effort_mode'='rir' then 3 end,'rpe',case when es.performance_prescription->>'effort_mode'='rpe' then 6 end,
       'technique_valid',true,'conditions_confirmed',true,'tolerated',true,'stop_reason','none')));
   end if;
  end loop;
  if difficult then
   perform public.abandon_workout_observed_idempotent(gen_random_uuid(),e,'too_difficult',observed,local_offset);
   if public.workout_block_outcome_v1(e,s.block_order)->>'abandonment_reason' is distinct from 'too_difficult' then
    raise exception 'No se registró la dificultad en el bloque de rendimiento';
   end if;
  else
   perform public.finish_workout_observed_idempotent(gen_random_uuid(),e,5,observed,local_offset);
  end if;
  if (select public.workout_performed_on_v1(x) from public.workout_executions x where x.id=e) is distinct from completed_day then
   raise exception 'La ejecución no conserva el día realizado';
  end if;
 end loop;
 if n<>2 or (select count(distinct scheduled_date) from public.scheduled_workouts where execution_id=any(prior_ids))<>2 then
  raise exception 'Se necesitan dos citas publicadas en fechas distintas: %',n;
 end if;
 p:=public.calculate_preparation_week(g,wk+7);
 if p->>'decision_id' is null then raise exception 'No se publicó la continuación automática: %', p->>'status'; end if;
 select value into p from jsonb_array_elements(p->'proposals') where value->>'reference_id'=ref_id::text;
 if p is null then raise exception 'Falta la propuesta de flexiones'; end if;
 return jsonb_build_object('status',p->'status','outcome',p->'outcome','frequency',p->'frequency',
  'phase',p->'phase','frequency_reason',p->'frequency_reason',
  'recent_difficulty',p->'block'->'recent_difficulty',
  'comparable_tolerated_exposures',p->'block'->'comparable_tolerated_exposures',
  'dose',p->'dose','exposure_doses',p->'exposure_doses','initial_targets',initial_targets,
  'evidence',coalesce((select jsonb_agg(x->>'signal') from jsonb_array_elements(p->'evidence') x),'[]'));
end $$;

do $$
declare
 tolerated_first jsonb:=pg_temp.same_day_adaptive_fixture(false);
 difficult_first jsonb:=pg_temp.same_day_adaptive_fixture(true);
 both_tolerated jsonb;
begin
 if tolerated_first-'evidence' is distinct from difficult_first-'evidence' then
  raise exception 'Cambiar el orden altera la decisión: tolerada primero % %, dificultad primero % %',
   tolerated_first->>'outcome',tolerated_first->'dose'->'targets',
   difficult_first->>'outcome',difficult_first->'dose'->'targets';
 end if;
 if tolerated_first->>'status' is distinct from 'ready' or tolerated_first->>'outcome' is distinct from 'reduce'
   or tolerated_first->>'frequency' is distinct from '2'
   or tolerated_first->>'recent_difficulty' is distinct from 'true'
   or tolerated_first->>'comparable_tolerated_exposures' is distinct from '0'
   or not (tolerated_first->'evidence' ? 'difficulty' and difficult_first->'evidence' ? 'difficulty')
   or (select sum(v::int) from jsonb_array_elements_text(tolerated_first->'dose'->'targets') v)
      >=(select sum(v::int) from jsonb_array_elements_text(tolerated_first->'initial_targets') v) then
  raise exception 'La dificultad del día no conserva la reducción: %',tolerated_first;
 end if;
 both_tolerated:=pg_temp.same_day_adaptive_fixture();
 if both_tolerated->>'status' is distinct from 'ready' or both_tolerated->>'outcome' is distinct from 'maintain'
   or both_tolerated->>'frequency' is distinct from '2'
   or both_tolerated->>'recent_difficulty' is distinct from 'false'
   or both_tolerated->>'comparable_tolerated_exposures' is distinct from '1'
   or both_tolerated->'dose'->'targets' is distinct from both_tolerated->'initial_targets' then
  raise exception 'Dos exposiciones toleradas el mismo día no acreditan dos días: %',both_tolerated;
 end if;
end $$;
select 'Orden de cierres del mismo día: misma reducción y sin duplicar días tolerados' as result;
rollback;
