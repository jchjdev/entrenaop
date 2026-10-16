begin;
select set_config('request.jwt.claim.sub',(select user_id::text from public.admin_permissions limit 1),true);
create function pg_temp.movement_exposure(p jsonb,day date,effort int) returns jsonb language sql as $$
 select jsonb_build_object('completed_on',day,'status','completed','dose',p->'dose','sets',
  (select jsonb_agg(jsonb_build_object('status','completed','prescription',p->'dose'->'task',
   'result',jsonb_build_object('value',v,'technique_valid',true,'conditions_confirmed',true,'tolerated',true,
    'stop_reason','none','rir',case when p->'dose'->'task'->>'effort_mode'='rir' then effort end,
    'rpe',case when p->'dose'->'task'->>'effort_mode'='rpe' then effort end)))
   from jsonb_array_elements(p->'dose'->'targets') v))
$$;
do $$ declare wk date:=current_date-extract(isodow from current_date)::int+1;
 iso jsonb; profile jsonb; ref jsonb; p jsonb; q jsonb; h jsonb; coordinated jsonb; result jsonb;
begin
 select definition into iso from public.exercise_training_profiles where code='front_plank_forearms' and definition_version=1;
 ref:=jsonb_build_object('id','iso','reference_kind','repeated_work','observed_on',wk-35,
  'current_capacity_confirmed',true,'reported_rpe',6,'targets','[50,45]'::jsonb,'frequency',3,
  'task','{"exercise_code":"front_plank_forearms","exercise_version":1,"protocol_key":"fixture","protocol_version":1,"setup_key":"standard:fixture","measurement":"DURATION","load_mode":"bodyweight","intent":"work","target_value":50}'::jsonb);
 p:=public.performance_task_v5(ref||jsonb_build_object('observed_on',wk-8),iso,'[]',wk-7,wk+28,'{}',wk-35);
 p:=p||jsonb_build_object('reference_id','iso','phase','development','frequency',3,
  'dose',p->'dose'||jsonb_build_object('targets','[76,75]'::jsonb,'task',p->'dose'->'task'||'{"target_value":76}'));
 h:=jsonb_build_array(pg_temp.movement_exposure(p,wk-7,6),pg_temp.movement_exposure(p,wk-4,6));
 q:=public.performance_task_v5(ref,iso,h,wk,wk+28,p,wk-35);
 if q->>'phase'<>'specific' or q->>'frequency'<>'3' or q->'dose'->'targets'<>'[76,75]'::jsonb
  or q->'dose'->'task'->>'stimulus_code'<>'ISO-E02' then raise exception 'La fase pierde dosis/frecuencia: %',q; end if;
 -- Otro apoyo, carga, variante o protocolo no hereda segundos.
 q:=public.performance_task_v5(ref||jsonb_build_object('task',ref->'task'||'{"setup_key":"standard:otro"}'),iso,h,wk,wk+28,p,wk-35);
 if q->'dose'->'targets'='[76,75]'::jsonb then raise exception 'Transfiere segundos entre apoyos distintos'; end if;
 h:=jsonb_build_array(pg_temp.movement_exposure(p,wk-7,9),pg_temp.movement_exposure(p,wk-4,9));
 q:=public.performance_task_v5(ref,iso,h,wk,wk+28,p,wk-35);
 if q->>'outcome'<>'reduce' then raise exception 'La continuidad oculta dificultad'; end if;
 -- Dos movimientos comparten tronco, pero conservan incrementos ya acotados.
 coordinated:=public.performance_coordinate_progression_v3('[
  {"reference_id":"push","role":"support","required_for_objective":true,"outcome":"progress","body_regions":["upper_body","trunk"],"dose":{"targets":[7,6]},"comparison_dose":{"targets":[6,6]}},
  {"reference_id":"plank","role":"specific","required_for_objective":true,"outcome":"progress","body_regions":["upper_body","trunk"],"dose":{"targets":[50,48]},"comparison_dose":{"targets":[48,48]}}
 ]','{"outcome":"progress"}',wk);
 if (select count(*) from jsonb_array_elements(coordinated) x where x->>'outcome'='progress')<>2 then
  raise exception 'La región vuelve a congelar un movimiento'; end if;
 if exists(select 1 from jsonb_array_elements(public.performance_support_recipes_v2()) x where x->>'work'='dead_bug')
  or not exists(select 1 from jsonb_array_elements(public.performance_support_recipes_v1()) x where x->>'work'='dead_bug') then
  raise exception 'Reactiva dead bug o reescribe receta histórica'; end if;
 if public.performance_same_isometric_work_v1(p->'dose'->'task',p->'dose'->'task'||'{"exercise_code":"front_plank_high"}') then
  raise exception 'Declara equivalentes variantes de plancha'; end if;
 p:=p||jsonb_build_object('reference_id','a','objective_key','aaa','frequency',1,'outcome','maintain',
  'required_for_objective',true,'goal_priority',2,'dose',p->'dose'||jsonb_build_object('targets','[10]'::jsonb,'rest_seconds',0));
 p:=p||jsonb_build_object('exposure_doses',jsonb_build_array(p->'dose'),'comparison_exposure_doses',jsonb_build_array(p->'dose'));
 q:=p||'{"reference_id":"z","objective_key":"zzz","goal_priority":0}';
 result:=public.performance_place_v4(jsonb_build_array(p,q),'{"1":12}','[]','[]',0,wk,wk+180);
 if not exists(select 1 from jsonb_each(result->'days') d,jsonb_array_elements(d.value->'work') x where x->>'reference_id'='z') then
  raise exception 'La meta compatible no interviene en el desempate'; end if;
end $$;

do $$ declare g uuid; a uuid; wid uuid; sid uuid; e uuid; es record; snap jsonb; reviews jsonb; plan jsonb;
 wk date:=current_date-extract(isodow from current_date)::int+1; user_before uuid:=auth.uid(); stored_health timestamptz:=now();
 input jsonb; rid uuid; observation jsonb; derived jsonb;
begin
 insert into public.pro_access_grants(user_id,source,starts_at,ends_at,reason)
 values(auth.uid(),'development_manual',now()-interval '1 day',now()+interval '1 year','Fixture de continuidad');
 insert into public.preparation_goals(user_id,program_id,target_date) values(auth.uid(),'fas_periodic_assessment',wk+180) returning id into g;
 insert into public.running_intake_contexts(preparation_goal_id,context_version,available_minutes_by_weekday,
  reserved_strength_weekdays,running_days_last_four_weeks,running_minutes_last_four_weeks,recent_weeks_end_on,
  reports_pain,requires_professional_review,health_observed_at,comfortable_continuous_minutes,goal_mode)
 values(g,'running_initial_context_v3','{"1":60,"3":75,"5":60,"6":75}','{}',array[2,2,2,2],array[60,60,60,60],
  wk-1,false,false,stored_health,30,'improve');
 snap:=public.running_capacity_observed_v1(g,wk);
 if snap->>'trial_minutes'<>'30' then raise exception 'Amplía capacidad sin registros'; end if;
 plan:=jsonb_build_object('policy_version','running_2k_v5','basis','recent','outcome','initial',
  'reference_source','trainingControl','reference_record_id',gen_random_uuid(),'input_snapshot','{}'::jsonb,
  'sessions',jsonb_build_array(public.running_session_v1('E',0,595,30,1)||jsonb_build_object('date',wk-7),
   public.running_session_v1('E',0,595,30,1)||jsonb_build_object('date',wk-4)));
 perform public.materialize_running_week_plan(g,wk-7,plan);
 for sid in select scheduled_workout_id from public.running_week_sessions rs join public.scheduled_workouts sw on sw.id=rs.scheduled_workout_id
  where sw.preparation_goal_id=g order by sw.scheduled_date loop
  e:=public.start_scheduled_workout(sid);
  -- La hora real se fija ANTES de registrar/cerrar (simula una subida offline).
  update public.workout_executions set started_at=(select scheduled_date+time '10:00' from public.scheduled_workouts where id=sid) where id=e;
  for es in select id from public.workout_execution_sets where execution_id=e loop
   perform public.complete_workout_set(es.id,p_actual_duration_seconds=>1800,p_actual_distance_meters=>4000,p_actual_rpe=>4);
  end loop;
  perform public.finish_workout_observed_idempotent(gen_random_uuid(),e,4,
   (select scheduled_date+time '10:30' from public.scheduled_workouts where id=sid),0);
 end loop;
 snap:=public.running_capacity_observed_v1(g,wk);
 if snap->>'observed_continuous_minutes'<>'30' or snap->>'trial_minutes'<>'35' then
  raise exception 'No propone ensayo prudente desde dos rodajes: %',snap; end if;
 if (select comfortable_continuous_minutes<>30 or health_observed_at<>stored_health from public.running_intake_contexts where preparation_goal_id=g) then
  raise exception 'Sobrescribe capacidad declarada o salud'; end if;
 update public.workout_execution_sets set actual_rpe=6 where execution_id=e;
 snap:=public.running_capacity_observed_v1(g,wk);
 if snap->>'trial_minutes'<>'30' then raise exception 'Amplía pese a esfuerzo alto'; end if;
 update public.workout_execution_sets set actual_rpe=null where execution_id=e;
 update public.workout_executions set final_rpe=null where id=e;
 snap:=public.running_capacity_observed_v1(g,wk);
 if snap->>'trial_minutes'<>'30' then raise exception 'Ausencia de esfuerzo se considera tolerancia'; end if;
 update public.profiles set fecha_nacimiento='1996-01-01' where id=auth.uid();
 insert into public.fas_periodic_assessments(user_id,preparation_goal_id,catalog_version,category,age_at_assessment,age_band,is_pre_effective_reference)
 values(auth.uid(),g,'es_def_15_2026_periodic_2027_v1','men',30,'26_30',true) returning id into a;
 insert into public.fas_periodic_marks values(a,'upper_body_push_ups_2_min',10),(a,'abdominal_plank',80000),(a,'agility_speed_circuit',14000);
 update public.profiles set fecha_nacimiento='1996-01-01' where id=auth.uid();
 perform public.save_adaptive_program_preferences(g,wk+180,'{"legacy:upper_body_push_ups_2_min":{"measurement":"REPS_IN_TIME","value":50},"legacy:abdominal_plank":{"measurement":"DURATION","value":240},"legacy:agility_speed_circuit":{"measurement":"TIME_FOR_COURSE","value":12.5}}');
 reviews:=public.performance_goal_reviews_v1(g,wk);
 if not exists(select 1 from jsonb_array_elements(reviews) x where x->>'measurement'='DURATION' and (x->>'last_protocol_mark')::numeric=80) then
  raise exception 'Confunde milisegundos de marca con segundos de trabajo: %',reviews; end if;
 if not exists(select 1 from jsonb_array_elements(reviews) x where x->>'measurement'='REPS_IN_TIME'
   and x->>'priority'='0' and (x->>'last_protocol_mark')::numeric=10 and x->>'target'='50') then raise exception 'No usa meta compatible'; end if;
 update public.fas_periodic_marks set value=50 where assessment_id=a and test_id='upper_body_push_ups_2_min';
 if not exists(select 1 from jsonb_array_elements(public.performance_goal_reviews_v1(g,wk)) x
   where x->>'measurement'='REPS_IN_TIME' and x->>'priority'='2') then raise exception 'No distingue meta ya acreditada'; end if;
 input:=jsonb_build_object('goal_code','front_plank_forearms','goal_version',1,'goal_measurement','DURATION',
  'reference_kind','performed_set','observed_on',current_date,'current_capacity_confirmed',true,'targets','[15]'::jsonb,'frequency',1,
  'task','{"exercise_code":"front_plank_high","exercise_version":1,"protocol_key":"support_work_v2:front_plank_high","protocol_version":1,"setup_key":"standard:support_v2:front_plank_high","measurement":"DURATION","load_mode":"bodyweight","target_value":15,"intent":"work"}'::jsonb);
 rid:=public.save_performance_reference(g,input);
 if public.performance_support_observed_v2('front_plank_high',1,'DURATION','bodyweight',wk) is not null then raise exception 'Inventa esfuerzo de sujeción'; end if;
 rid:=public.save_performance_reference(g,input||'{"reported_rpe":6}');
 observation:=public.performance_support_observed_v2('front_plank_high',1,'DURATION','bodyweight',wk);
 if observation->'result'->>'rpe' is distinct from '6' or observation->'result' ? 'rir' then raise exception 'Confunde RIR con esfuerzo de sujeción'; end if;
 derived:=jsonb_build_object('task',observation->'task','targets','[15]'::jsonb,'reported_rpe',6,
  'automatic_support',jsonb_build_object('observation',observation-'task'-'result'));
 if not public.performance_support_source_valid_v2(derived) then raise exception 'Pierde origen de apoyo isométrico'; end if;
 update public.performance_training_references set reference=reference||'{"reported_rpe":8}' where id=rid;
 if public.performance_support_source_valid_v2(derived) then raise exception 'Origen corregido sigue acreditando capacidad'; end if;
 perform set_config('request.jwt.claim.sub',gen_random_uuid()::text,true);
 begin perform public.running_capacity_observed_v1(g,wk); raise exception 'Lee capacidad ajena'; exception when insufficient_privilege then null; end;
 begin perform public.performance_goal_reviews_v1(g,wk); raise exception 'Lee metas ajenas'; exception when insufficient_privilege then null; end;
 perform set_config('request.jwt.claim.sub',user_before::text,true);
 if has_function_privilege('authenticated','public.running_capacity_observed_v1(uuid,date)','execute')
  or has_function_privilege('authenticated','public.performance_goal_reviews_v1(uuid,date)','execute') then raise exception 'Expone lectores internos'; end if;
end $$;
select 'Progresiones independientes, continuidad isométrica, capacidad observada, metas compatibles y permisos: OK' result;
rollback;
