begin;
select set_config('request.jwt.claim.sub',(select user_id::text from public.admin_permissions limit 1),true);

do $$
declare session jsonb:='{"family":"E","segments":[{"role":"work","seconds":1200}]}';
 execution jsonb:='{"status":"abandoned","abandonment_reason":"lack_of_time","rpe":4,"sets":[{"status":"completed","seconds":600}]}';
 signal jsonb; p jsonb; ref jsonb; profile jsonb; wk date:=current_date+8-extract(isodow from current_date)::int;
begin
 signal:=public.running_evaluate_v2(session,execution);
 if signal->>'status'<>'time' or signal->>'objective_difficulty'<>'false' or signal->>'work_seconds'<>'600'
   or signal->>'completed_work'<>'0' then raise exception 'Confunde tiempo, carga o dosis: %',signal; end if;
 signal:=public.running_evaluate_v2(session,execution||'{"abandonment_reason":"too_difficult"}');
 if signal->>'status'<>'struggle' then raise exception 'Oculta dificultad real'; end if;
 signal:=public.running_evaluate_v2(session,execution||'{"discomfort":true}');
 if signal->>'status'<>'pain' then raise exception 'Oculta molestias'; end if;
 p:='{"schema_version":1,"exercise_code":"push_up_standard","exercise_version":1,"protocol_key":"floor_v1","protocol_version":1,"setup_key":"Suelo","measurement":"REPS_IN_TIME","fixed_duration_seconds":60,"load_mode":"bodyweight","policy_version":"fixture","target_value":8,"target_rir":3,"intent":"work","effort_mode":"rir"}';
 if not public.valid_performance_prescription(p) then raise exception 'SQL discrepa de RIR dinámico temporal'; end if;
 if public.valid_performance_prescription(p||'{"measurement":"DURATION"}')
   or public.valid_performance_prescription(p||'{"intent":"control"}')
   or public.valid_performance_prescription(p||'{"intent":"practice"}') then raise exception 'RIR fuera de tarea'; end if;
 select definition into profile from public.exercise_training_profiles where code='bench_press_barbell' and definition_version=1;
 ref:=jsonb_build_object('reference_kind','capacity_test','observed_on',current_date,'current_capacity_confirmed',true,
  'targets','[3]'::jsonb,'rest_seconds',120,'frequency',1,
  'task',p||'{"exercise_code":"bench_press_barbell","measurement":"LOAD_REPS","load_mode":"external_load","external_load_kg":50}');
 p:=public.performance_task_v3(ref,profile,'[]',wk,wk+90);
 if p->>'status'<>'needs_calibration' then raise exception 'Capacidad máxima 3 con RIR3 imposible: %',p; end if;
 p:=public.performance_task_v3(ref||'{"targets":[4]}',profile,'[]',wk,wk+90);
 if p->>'status'<>'needs_calibration' then raise exception 'Capacidad máxima 4 con RIR3 imposible: %',p; end if;
 p:=public.performance_task_v3(ref||'{"targets":[6]}',profile,'[]',wk,wk+90);
 if p->>'status'<>'ready' then raise exception 'Bloquea una carga practicable: %',p; end if;
 if public.preparation_shared_minutes_v2('{"minutes":13}','{"minutes":25,"segments":[{"role":"warmup"},{"role":"cooldown"}]}')<>31
   or public.preparation_running_budget_v1('{"days":{"1":{"minutes":13}}}','{"1":35}')->>'1'<>'29' then
   raise exception 'No reconoce el tiempo compartido en búsqueda'; end if;
end $$;

-- Sesión física persistida: correr bien, terminar un bloque de fuerza y
-- abandonar el siguiente no degrada los dos bloques ya realizados.
do $$
declare t uuid; b uuid; i uuid; e uuid; op uuid:=gen_random_uuid(); ex uuid; s record;
 p jsonb:='{"schema_version":1,"exercise_code":"push_up_standard","exercise_version":1,"protocol_key":"floor_v1","protocol_version":1,"setup_key":"Suelo","measurement":"REPS","load_mode":"bodyweight","policy_version":"fixture","target_value":8,"target_rir":3,"intent":"work","effort_mode":"rir"}';
 clock_at timestamptz:=date_trunc('day',now())-interval '30 minutes'; clock_offset int:=120;
 saved public.workout_executions%rowtype; before_clock timestamptz; original_user uuid:=auth.uid(); agenda public.scheduled_workouts%rowtype;
begin
 insert into public.workout_templates(name,origin,owner_user_id,visibility,status,version)
 values('Fixture evidencia combinada','user',auth.uid(),'private','published',1) returning id into t;
 insert into public.workout_blocks(template_id,order_index,name,format) values(t,0,'Carrera','running') returning id into b;
 insert into public.workout_items(block_id,exercise_id,order_index) values(b,'20000000-0000-4000-8000-000000000004',0) returning id into i;
 insert into public.workout_sets(item_id,order_index,target_duration_seconds,target_rpe,rest_after_seconds) values(i,0,1200,4,0);
 select id into ex from public.exercises where training_profile_code='push_up_standard' limit 1;
 for n in 1..2 loop
  insert into public.workout_blocks(template_id,order_index,name,format) values(t,n,'Fuerza '||n,'straight_sets') returning id into b;
  insert into public.workout_items(block_id,exercise_id,order_index) values(b,ex,0) returning id into i;
  insert into public.workout_sets(item_id,order_index,performance_prescription) values(i,0,p);
 end loop;
 e:=public.start_workout_execution(t);
 -- El inicio ocurrió antes de perder conexión. El recibo se recibe hoy.
 update public.workout_executions set started_at=clock_at-interval '1 hour' where id=e;
 for s in select * from public.workout_execution_sets where execution_id=e and block_order<2 loop
  if s.block_format='running' then perform public.complete_workout_set(s.id,p_actual_duration_seconds=>1200,p_actual_distance_meters=>3000,p_actual_rpe=>4);
  else perform public.complete_performance_set_idempotent(gen_random_uuid(),s.id,
   '{"value":8,"rir":3,"technique_valid":true,"conditions_confirmed":true,"tolerated":true,"stop_reason":"none"}'); end if;
 end loop;
 perform public.abandon_workout_observed_idempotent(op,e,'too_difficult',clock_at,clock_offset);
 perform public.abandon_workout_observed_idempotent(op,e,'too_difficult',now(),0);
 select * into saved from public.workout_executions where id=e;
 if saved.performed_at<>clock_at or saved.completed_at<>now() or saved.abandoned_block_order<>2
   or public.workout_performed_on_v1(saved)<>(clock_at at time zone 'UTC'+interval '2 hours')::date then
   raise exception 'Pierde reloj local, recepción o idempotencia'; end if;
 if public.workout_block_outcome_v1(e)->>'status'<>'completed'
   or public.workout_block_outcome_v1(e)->>'abandonment_reason' is not null
   or public.workout_block_outcome_v1(e,1)->>'status'<>'completed'
   or public.workout_block_outcome_v1(e,2)->>'abandonment_reason'<>'too_difficult' then raise exception 'Contaminación entre bloques'; end if;
 begin
  perform set_config('request.jwt.claim.sub',gen_random_uuid()::text,true);
  perform public.abandon_workout_observed_idempotent(op,e,'other',clock_at,clock_offset);
  raise exception 'Acepta cierre ajeno';
 exception when raise_exception then if sqlerrm<>'Active workout execution not found' then raise; end if; end;
 perform set_config('request.jwt.claim.sub',original_user::text,true);
 e:=public.start_workout_execution(t);
 before_clock:=now();
 begin
  perform public.abandon_workout_observed_idempotent(gen_random_uuid(),e,'other',now()+interval '1 day',0);
  raise exception 'Acepta reloj futuro';
 exception when invalid_parameter_value then null; end;
 if (select performed_at from public.workout_executions where id=e) is not null then raise exception 'Deja un reloj inválido persistido'; end if;
 -- Molestias conservadoras aunque carrera estuviera terminada.
 perform public.abandon_workout_observed_idempotent(gen_random_uuid(),e,'discomfort',before_clock,0);
 if public.workout_block_outcome_v1(e)->>'abandonment_reason'<>'discomfort' then raise exception 'Localiza indebidamente dolor'; end if;
 -- Cierre normal offline recibido después, con cambio de día y zona local.
 e:=public.start_workout_execution(t);
 update public.workout_executions set started_at=clock_at-interval '1 hour' where id=e;
 for s in select * from public.workout_execution_sets where execution_id=e loop
  if s.block_format='running' then perform public.complete_workout_set(s.id,p_actual_duration_seconds=>1200,p_actual_distance_meters=>3000,p_actual_rpe=>4);
  else perform public.complete_performance_set_idempotent(gen_random_uuid(),s.id,
   '{"value":8,"rir":3,"technique_valid":true,"conditions_confirmed":true,"tolerated":true,"stop_reason":"none"}'); end if;
 end loop;
 op:=gen_random_uuid();
 perform public.finish_workout_observed_idempotent(op,e,4,clock_at,clock_offset);
 perform public.finish_workout_observed_idempotent(op,e,4,now(),0);
 select * into saved from public.workout_executions where id=e;
 if saved.status<>'completed' or saved.performed_at<>clock_at or saved.completed_at<>now() then raise exception 'Cierre normal cambia el reloj al reintentar'; end if;
 insert into public.scheduled_workouts(user_id,template_id,template_name,template_version,scheduled_date,source,status,execution_id)
 values(auth.uid(),t,'Fixture fecha distinta',1,current_date+7,'user','completed',e) returning * into agenda;
 if public.workout_load_on_v1(agenda)=agenda.scheduled_date or public.workout_load_on_v1(agenda)<>public.workout_performed_on_v1(saved) then
  raise exception 'La agenda sustituye el día realmente realizado'; end if;
 -- Una serie resuelta con media dosis sigue siendo parcial: no perder el
 -- motivo temporal al proyectarla, aunque el siguiente bloque esté pendiente.
 e:=public.start_workout_execution(t);
 for s in select * from public.workout_execution_sets where execution_id=e and block_order<2 loop
  if s.block_format='running' then perform public.complete_workout_set(s.id,p_actual_duration_seconds=>600,p_actual_distance_meters=>1500,p_actual_rpe=>4);
  else perform public.complete_performance_set_idempotent(gen_random_uuid(),s.id,
   '{"value":4,"rir":3,"technique_valid":true,"conditions_confirmed":true,"tolerated":true,"stop_reason":"none"}'); end if;
 end loop;
 perform public.abandon_workout_observed_idempotent(gen_random_uuid(),e,'lack_of_time',now(),0);
 if public.workout_block_outcome_v1(e)->>'abandonment_reason'<>'lack_of_time'
   or public.workout_block_outcome_v1(e,1)->>'abandonment_reason'<>'lack_of_time' then raise exception 'Confunde series resueltas con dosis completa'; end if;
 if has_function_privilege('anon','public.finish_workout_observed_idempotent(uuid,uuid,integer,timestamptz,integer,text,integer,integer,text)','execute')
   or has_function_privilege('authenticated','public.set_workout_performed_clock_v1(uuid,timestamptz,integer)','execute') then raise exception 'Auxiliar expuesto'; end if;
end $$;
select 'Evidencia temporal, abandono por bloque, reloj offline, reintentos, carga y RIR: OK' result;
rollback;
