begin;
set local statement_timeout='60s';
do $$
declare trainer uuid:=gen_random_uuid(); pupil uuid:=gen_random_uuid(); stranger uuid:=gen_random_uuid();
 relation uuid:=gen_random_uuid(); ps uuid:=gen_random_uuid(); ts uuid:=gen_random_uuid(); weak uuid:=gen_random_uuid();
 template uuid; scheduled uuid:=gen_random_uuid(); second uuid:=gen_random_uuid(); recipe jsonb;
 preview jsonb; claim jsonb; receipt jsonb; lease uuid:=gen_random_uuid(); jid uuid; code text;
begin
 insert into auth.users(id,email) values(trainer,trainer||'@garmin-training.invalid'),(pupil,pupil||'@garmin-training.invalid'),(stranger,stranger||'@garmin-training.invalid');
 insert into auth.sessions(id,user_id,aal) values(ps,pupil,'aal1'),(ts,trainer,'aal2'),(weak,trainer,'aal1');
 insert into auth.mfa_factors(id,user_id,factor_type,status,created_at,updated_at) values(gen_random_uuid(),trainer,'totp','verified',now(),now());
 insert into public.trainer_access(trainer_id,enabled,client_limit,last_reason) values(trainer,true,5,'Fixture Garmin con ROLLBACK');
 insert into public.trainer_client_relations(id,trainer_id,client_id,accepted_at) values(relation,trainer,pupil,now());
 perform set_config('request.jwt.claim.sub',trainer::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',trainer,'role','authenticated','aal','aal2')::text,true);
 recipe:=jsonb_build_object('name','Carrera sintética Garmin','blocks',jsonb_build_array(jsonb_build_object(
  'name','Carrera','format','running','rounds',1,'rest_after_seconds',0,'exercises',jsonb_build_array(jsonb_build_object(
   'exercise_id','20000000-0000-4000-8000-000000000004','sets',jsonb_build_array(jsonb_build_object(
    'target_duration_seconds',120,'rest_after_seconds',0,'target_pace_min_seconds_per_km',300,'target_pace_max_seconds_per_km',360,
    'recovery_type','walking','recovery_duration_seconds',30)))))));
 template:=trainer_private.save_trainer_workout(gen_random_uuid(),recipe);
 perform trainer_private.assign_trainer_workout(scheduled,relation,template,current_date,null);
 perform trainer_private.assign_trainer_workout(second,relation,template,current_date+2,null);

 perform set_config('fixture.owner',pupil::text,true);perform set_config('fixture.session',ps::text,true);
 perform set_config('fixture.scheduled',scheduled::text,true);
 perform set_config('fixture.stranger',stranger::text,true);
end $$;



set local role authenticated;
do $$declare owner uuid:=current_setting('fixture.owner')::uuid; sid uuid:=current_setting('fixture.scheduled')::uuid;
 p jsonb;claim jsonb;obs jsonb;answer jsonb;result_id uuid;execution uuid;
 started timestamptz:=now()-interval '3 minutes';wid uuid:=gen_random_uuid();begin
 perform set_config('request.jwt.claim.sub',owner::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',owner,'role','authenticated','session_id',current_setting('fixture.session'),'aal','aal1')::text,true);
 p:=public.apple_training_command(owner,'preview',jsonb_build_object('scheduled_id',sid));
 claim:=public.apple_training_command(owner,'prepare',jsonb_build_object('scheduled_id',sid,'revision',p->>'revision','attempt_id',gen_random_uuid()));
 perform public.apple_training_command(owner,'record',jsonb_build_object('scheduled_id',sid,'revision',claim->>'revision','attempt_id',claim->>'attempt_id'));
 perform public.apple_results_command(owner,'enable','{"enabled":true}');
 obs:=jsonb_build_object('workout_id',wid,'plan_id',claim->>'plan_id','revision',claim->>'revision','matches_prescription',true,
  'started_at',started,'ended_at',started+interval '117.3 seconds','timer_seconds',117.3,'distance_meters',420,
  'offset_minutes',60,'intervals',jsonb_build_array(
   jsonb_build_object('id',gen_random_uuid(),'started_at',started,'ended_at',started+interval '87.3 seconds','timer_seconds',87.3,'distance_meters',400),
   jsonb_build_object('id',gen_random_uuid(),'started_at',started+interval '87.3 seconds','ended_at',started+interval '117.3 seconds','timer_seconds',30,'distance_meters',20)));
 answer:=public.apple_results_command(owner,'ingest',jsonb_build_object('observations',jsonb_build_array(obs-'intervals')));
 if answer->'automatic'->0->>'state'<>'review' then raise exception 'Completa sin fases observadas';end if;
 answer:=public.apple_results_command(owner,'ingest',jsonb_build_object('observations',jsonb_build_array(obs)));
 if answer->'automatic'->0->>'state'<>'completed' then raise exception 'No completa una actividad acreditada: %',answer;end if;
 execution:=(answer->'automatic'->0->>'execution_id')::uuid;
 if exists(select 1 from public.workout_executions where id=execution and final_rpe is not null) then
  raise exception 'Inventa esfuerzo ausente';end if;
 perform set_config('fixture.execution',execution::text,true);
 perform set_config('fixture.observation',obs::text,true);
 -- Releer Salud y repetir la petición no crean otro cierre.
 answer:=public.apple_results_command(owner,'ingest',jsonb_build_object('observations',jsonb_build_array(obs)));
 if (answer->'automatic'->0->>'execution_id')::uuid<>execution then raise exception 'Repite la ejecución';end if;
 begin
  perform public.add_device_workout_effort(current_setting('fixture.stranger')::uuid,execution,4);
  raise exception 'Acepta identidad distinta';
 exception when insufficient_privilege then null;end;
 begin
  perform public.add_device_workout_effort(owner,execution,0);
  raise exception 'Acepta RPE cero';
 exception when invalid_parameter_value then null;end;
 perform public.add_device_workout_effort(owner,execution,4);
 perform public.add_device_workout_effort(owner,execution,4);
 begin
  perform public.add_device_workout_effort(owner,execution,6);
  raise exception 'Sobrescribe esfuerzo registrado';
 exception when invalid_parameter_value then
  if sqlerrm<>'effort_already_recorded' then raise;end if;end;
 -- Un esfuerzo posterior del reloj se conserva sin pisar la valoración humana.
 perform public.apple_results_command(owner,'ingest',jsonb_build_object('observations',jsonb_build_array(obs||'{"effort_score":6.0}')));
end $$;
reset role;
do $$declare execution uuid:=current_setting('fixture.execution')::uuid;owner uuid:=current_setting('fixture.owner')::uuid;
 e public.workout_executions;begin
 select * into e from public.workout_executions where id=execution;
 if e.status<>'completed' or e.final_rpe<>4 or e.observed_timer_seconds<>117.3 or e.observed_distance_meters<>420 then
  raise exception 'Pierde datos medidos o la valoración humana';end if;
 if (select status from public.scheduled_workouts where id=current_setting('fixture.scheduled')::uuid)<>'completed' then
  raise exception 'No completa la semana';end if;
 if (select count(*) from device_private.apple_activity_confirmations where owner_id=owner)<>1 then raise exception 'Duplica confirmación';end if;
 if not device_private.activity_in_completion_window('2026-11-08T23:30:00Z',0,'2026-11-01') or
  device_private.activity_in_completion_window('2026-11-09T00:00:00Z',0,'2026-11-01') or
  device_private.activity_in_completion_window('2026-10-31T12:00:00Z',0,'2026-11-01') or
  device_private.activity_in_completion_window('2026-11-01T12:00:00Z',null,'2026-11-01') then raise exception 'Ventana incorrecta';end if;
 if has_function_privilege('anon','public.add_device_workout_effort(uuid,uuid,integer)','EXECUTE') or
  has_function_privilege('authenticated','device_private.complete_apple_result_automatically(uuid,uuid)','EXECUTE') then raise exception 'Privilegios excesivos';end if;
end $$;
select 'Retorno Apple autónomo, ventana, replay y RPE diferido verificados' as result;
rollback;
