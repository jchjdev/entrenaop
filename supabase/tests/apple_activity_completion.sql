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
 perform trainer_private.assign_trainer_workout(scheduled,relation,template,current_date+1,null);
 perform trainer_private.assign_trainer_workout(second,relation,template,current_date+2,null);

 perform set_config('fixture.owner',pupil::text,true);perform set_config('fixture.session',ps::text,true);
 perform set_config('fixture.scheduled',scheduled::text,true);
end $$;


set local role authenticated;
do $$declare owner uuid:=current_setting('fixture.owner')::uuid; sid uuid:=current_setting('fixture.scheduled')::uuid;
 p jsonb; claim jsonb; obs jsonb; review jsonb; confirm_input jsonb; receipt jsonb; result_id uuid; execution uuid;
 started timestamptz:=now()-interval '3 minutes'; wid uuid:=gen_random_uuid();begin
 perform set_config('request.jwt.claim.sub',owner::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',owner,'role','authenticated','session_id',current_setting('fixture.session'),'aal','aal1')::text,true);
 p:=public.apple_training_command(owner,'preview',jsonb_build_object('scheduled_id',sid));
 claim:=public.apple_training_command(owner,'prepare',jsonb_build_object('scheduled_id',sid,'revision',p->>'revision','attempt_id',gen_random_uuid()));
 perform public.apple_training_command(owner,'record',jsonb_build_object('scheduled_id',sid,'revision',claim->>'revision','attempt_id',claim->>'attempt_id'));
 perform public.apple_results_command(owner,'enable','{"enabled":true}');
 obs:=jsonb_build_object('workout_id',wid,'plan_id',claim->>'plan_id','revision',claim->>'revision','matches_prescription',true,
  'started_at',started,'ended_at',started+interval '117.3 seconds','timer_seconds',117.3,'distance_meters',420,
  'effort_score',4.0,'offset_minutes',60,'intervals',jsonb_build_array(
   jsonb_build_object('id',gen_random_uuid(),'started_at',started,'ended_at',started+interval '87.3 seconds','timer_seconds',87.3,'distance_meters',400),
   jsonb_build_object('id',gen_random_uuid(),'started_at',started+interval '87.3 seconds','ended_at',started+interval '117.3 seconds','timer_seconds',30,'distance_meters',20)));
 perform public.apple_results_command(owner,'ingest',jsonb_build_object('observations',jsonb_build_array(obs)));
 result_id:=(public.apple_results_command(owner,'catalog')->'results'->0->>'id')::uuid;
 review:=public.apple_results_command(owner,'preview',jsonb_build_object('activity_id',result_id,'scheduled_id',sid));
 if jsonb_array_length(review->'activity'->'laps')<>2 or review->>'recorded_rpe'<>'4' then raise exception 'Pierde intervalos o esfuerzo observado';end if;
 confirm_input:=jsonb_build_object('operation_id',gen_random_uuid(),'activity_id',result_id,'scheduled_id',sid,
  'activity_revision',review->>'activity_revision','source_revision',review->>'source_revision','rpe',4,'utc_offset_minutes',60,
  'mapping',jsonb_build_array(jsonb_build_object('block_order',0,'item_order',0,'set_order',0,'skipped',false,'lap_indices','[0]'::jsonb,'recovery_lap_indices','[1]'::jsonb)));
 perform public.apple_results_command(owner,'classify',jsonb_build_object('id',result_id,'is_test',true));
 begin perform public.apple_results_command(owner,'confirm',confirm_input);raise exception 'Completa una prueba ficticia';exception when invalid_parameter_value then
  if sqlerrm<>'test_activity' then raise;end if;end;
 perform public.apple_results_command(owner,'classify',jsonb_build_object('id',result_id,'is_test',false));
 begin perform public.apple_results_command(owner,'confirm',confirm_input||'{"activity_revision":"old"}');raise exception 'Acepta revisión antigua';exception when serialization_failure then null;end;
 begin perform public.apple_results_command(owner,'confirm',confirm_input||jsonb_build_object('mapping',jsonb_build_array(
  jsonb_build_object('block_order',0,'item_order',0,'set_order',0,'skipped',true,'lap_indices','[]'::jsonb,'recovery_lap_indices','[]'::jsonb))));
  raise exception 'Completa sin medición alguna';exception when invalid_parameter_value then null;end;
 receipt:=public.apple_results_command(owner,'confirm',confirm_input);execution:=(receipt->>'execution_id')::uuid;
 if (public.apple_results_command(owner,'confirm',confirm_input)->>'execution_id')::uuid<>execution then raise exception 'Replay duplica ejecución';end if;
 begin perform public.apple_results_command(owner,'confirm',confirm_input||'{"rpe":5}');raise exception 'Reutiliza operación con otro contenido';exception when invalid_parameter_value then
  if sqlerrm<>'operation_reused' then raise;end if;end;
 if not exists(select 1 from public.workout_execution_sets where execution_id=execution and observed_duration_seconds=87.3
  and actual_duration_seconds=87 and actual_distance_meters=400 and actual_recovery_duration_seconds=30 and result_source='device') then raise exception 'Pierde precisión o datos por paso';end if;
 if not exists(select 1 from public.scheduled_workouts where id=sid and status='completed' and execution_id=execution) then raise exception 'No completa la semana';end if;
 if (public.apple_results_command(owner,'catalog')->'results'->0->>'execution_id')::uuid<>execution then raise exception 'Resumen no remite al historial';end if;
 perform set_config('fixture.apple.execution',execution::text,true);
end $$;
reset role;
do $$declare owner uuid:=current_setting('fixture.owner')::uuid; sid uuid:=current_setting('fixture.scheduled')::uuid; data jsonb;begin
 select observation into data from device_private.apple_activity_results where owner_id=owner limit 1;
 -- No se distribuye el total entre una carrera y su recuperación.
 data:=data||jsonb_build_object('intervals',jsonb_build_array(jsonb_build_object('id',gen_random_uuid(),
  'started_at',data->>'started_at','ended_at',data->>'ended_at','timer_seconds',data->'timer_seconds','distance_meters',data->'distance_meters')));
 if device_private.apple_measured_laps(data,(select snapshot from device_private.apple_training_deliveries where owner_id=owner and scheduled_id=sid))<>'[]'::jsonb then
  raise exception 'Un total global se presenta como una fase';end if;
end $$;
select 'Apple: intervalos, esfuerzo, cierre semanal, historial, precisión, replay y rechazo de pruebas verificados' as result;
rollback;
