-- Datos exclusivamente sintéticos. La prueba completa revierte con ROLLBACK.
begin;
set local statement_timeout='60s';
set local timezone='UTC';
do $$
declare trainer uuid:=gen_random_uuid(); pupil uuid:=gen_random_uuid(); relation uuid:=gen_random_uuid();
 ps uuid:=gen_random_uuid(); ts uuid:=gen_random_uuid(); template uuid; scheduled uuid:=gen_random_uuid();
 ex uuid; recipe jsonb; observation jsonb; preview jsonb; input jsonb; receipt jsonb;
 lease uuid:=gen_random_uuid(); jid uuid:=gen_random_uuid(); aid uuid; e uuid; i integer; started timestamptz:=now()-interval '1 hour';
begin
 insert into auth.users(id,email) values(trainer,trainer||'@strength-return.invalid'),(pupil,pupil||'@strength-return.invalid');
 insert into auth.sessions(id,user_id,aal) values(ps,pupil,'aal1'),(ts,trainer,'aal2');
 insert into auth.mfa_factors(id,user_id,factor_type,status,created_at,updated_at) values(gen_random_uuid(),trainer,'totp','verified',now(),now());
 insert into public.trainer_access(trainer_id,enabled,client_limit,last_reason) values(trainer,true,5,'Fixture con ROLLBACK');
 insert into public.trainer_client_relations(id,trainer_id,client_id,accepted_at) values(relation,trainer,pupil,now());
 select id into ex from public.exercises where training_profile_code='bench_press_barbell' and training_profile_version=1 and is_public order by id limit 1;
 if ex is null then raise exception 'Falta el ejercicio de catálogo'; end if;
 perform set_config('request.jwt.claim.sub',trainer::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',trainer,'role','authenticated','aal','aal2')::text,true);
 recipe:=jsonb_build_object('name','Fuerza sintética','blocks',jsonb_build_array(jsonb_build_object('name','Banca','format','straight_sets','rounds',1,'rest_after_seconds',0,
  'exercises',jsonb_build_array(jsonb_build_object('exercise_id',ex,'sets',jsonb_build_array(
   jsonb_build_object('target_reps',10,'target_load_kg',20,'rest_after_seconds',30),
   jsonb_build_object('target_reps',10,'target_load_kg',20,'rest_after_seconds',30),
   jsonb_build_object('target_reps',10,'target_load_kg',20,'rest_after_seconds',30)))))));
 template:=trainer_private.save_trainer_workout(gen_random_uuid(),recipe);
 perform trainer_private.assign_trainer_workout(scheduled,relation,template,current_date,null);
 perform public.garmin_account_command('begin',pupil,ps,jsonb_build_object('state_hash',repeat('a',64),'verifier_cipher','fixture'));
 perform public.garmin_account_command('claim',null,null,jsonb_build_object('state_hash',repeat('a',64),'claim_id',lease));
 perform public.garmin_account_command('complete',pupil,null,jsonb_build_object('generation',1,'claim_id',lease,
  'tokens_cipher','fixture','access_expires_at',now()+interval '1 hour','refresh_expires_at',now()+interval '1 day',
  'garmin_user_id',pupil::text,'can_read',true,'can_send',true));
 preview:=public.garmin_training_command('preview',pupil,pupil,ps,jsonb_build_object('scheduled_id',scheduled));
 if preview->'snapshot'->>'sport'<>'strength' or preview->'snapshot'->'blocks'->0->'items'->0->>'exercise_code'<>'bench_press_barbell' then
  raise exception 'No proyecta el catálogo propio'; end if;
 if device_private.training_sync_target(pupil,scheduled)->>'mode'<>'sync' then raise exception 'Fuerza no entra en el ciclo común'; end if;
 perform public.garmin_activity_command('enqueue',null,null,jsonb_build_object('id',jid,'event_key',repeat('b',64),'provider_user_id',pupil::text,
  'callback_cipher','fixture','metadata','{}'::jsonb));
 perform public.garmin_activity_command('claim',null,null,jsonb_build_object('id',jid,'lease_id',lease));
 observation:=jsonb_build_object('schemaVersion',2,'sport','strength','externalId','987654','name','Fuerza sintética',
  'startedAt',to_char(started,'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'),'offsetSeconds',7200,'elapsedSeconds',180,'timerSeconds',180,
  'distanceMeters',null,'averageHeartRate',110,'maxHeartRate',140,'sets','[]'::jsonb);
 for i in 0..5 loop
  observation:=jsonb_set(observation,'{sets}',observation->'sets'||jsonb_build_array(jsonb_build_object('index',i,
   'startedAt',to_char(started+make_interval(secs=>30*i),'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'),'seconds',30,
   'kind',case when i%2=0 then 'active' else 'rest' end,'workoutStepIndex',i,
   'exerciseCode',case when i%2=0 then 'bench_press_barbell' else null end,
   'repetitions',case i when 0 then 10 when 2 then 9 when 4 then 8 else null end,
   'loadKg',case i when 0 then 20 when 2 then 22.5 else null end)));
 end loop;
 if device_private.strength_observation_valid(jsonb_set(observation,'{sets,0,loadKg}','-2')) then raise exception 'Admite carga negativa'; end if;
 perform public.garmin_activity_command('save',null,null,jsonb_build_object('id',jid,'lease_id',lease,'activity',observation));
 perform public.garmin_activity_command('release',null,null,jsonb_build_object('id',jid,'lease_id',lease));
 select id into aid from device_private.activity_observations where owner_id=pupil;
 preview:=public.garmin_activity_command('preview',pupil,ps,jsonb_build_object('activity_id',aid,'scheduled_id',scheduled));
 input:=jsonb_build_object('operation_id',gen_random_uuid(),'activity_id',aid,'activity_revision',preview->>'activity_revision',
  'source_revision',preview->>'source_revision','scheduled_id',scheduled,'rpe',5,'mapping',jsonb_build_array(
   jsonb_build_object('block_order',0,'item_order',0,'set_order',0,'lap_indices',jsonb_build_array(0),'recovery_lap_indices','[]'::jsonb),
   jsonb_build_object('block_order',0,'item_order',0,'set_order',1,'lap_indices',jsonb_build_array(2),'recovery_lap_indices','[]'::jsonb),
   jsonb_build_object('block_order',0,'item_order',0,'set_order',2,'lap_indices',jsonb_build_array(4),'recovery_lap_indices','[]'::jsonb)));
 begin
  perform public.garmin_activity_command('confirm',pupil,ps,jsonb_set(input,'{mapping,1,lap_indices}','[0]'));
  raise exception 'Duplica una serie'; exception when invalid_parameter_value then null;
 end;
 begin
  perform public.garmin_activity_command('confirm',pupil,ps,jsonb_set(input,'{mapping,1,lap_indices}','[1]'));
  raise exception 'Descanso convertido en trabajo'; exception when invalid_parameter_value then null;
 end;
 if (select status from public.scheduled_workouts where id=scheduled)<>'planned' then raise exception 'Fallo dejó cierre parcial'; end if;
 begin
  update device_private.activity_observations a set observation=jsonb_set(a.observation,'{sets,0,repetitions}','null') where id=aid;
  perform public.garmin_activity_command('confirm',pupil,ps,input);
  raise exception 'Rellena repeticiones ausentes'; exception when invalid_parameter_value then null;
 end;
 begin
  update device_private.activity_observations set observation=jsonb_build_object('schemaVersion',1,'externalId','987654','name','Fixture carrera',
    'startedAt',to_char(started,'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'),'offsetSeconds',7200,'timerSeconds',180,'elapsedSeconds',180,
    'distanceMeters',1000,'laps','[]'::jsonb) where id=aid;
  perform public.garmin_activity_command('confirm',pupil,ps,input);
  raise exception 'Carrera cierra fuerza'; exception when invalid_parameter_value then null;
 end;
 receipt:=public.garmin_activity_command('confirm',pupil,ps,input); e:=(receipt->>'execution_id')::uuid;
 if public.garmin_activity_command('confirm',pupil,ps,input)->>'execution_id'<>e::text then raise exception 'Duplica reintento'; end if;
 if (select status from public.scheduled_workouts where id=scheduled)<>'completed'
  or (select count(*) from public.workout_execution_sets where execution_id=e and status='completed')<>3 then raise exception 'Semana/series sin completar'; end if;
 if not exists(select 1 from public.workout_execution_sets where execution_id=e and set_order=1 and actual_reps=9 and actual_load_kg=22.5 and result_source='device')
  or not exists(select 1 from public.workout_execution_sets where execution_id=e and set_order=2 and actual_reps=8 and actual_load_kg is null)
  or not exists(select 1 from public.workout_executions where id=e and final_rpe=5 and observed_timer_seconds=180 and observed_distance_meters is null) then
  raise exception 'Sustituye observación por pauta o inventa distancia/carga'; end if;
 if has_function_privilege('authenticated','device_private.apply_strength_mapping(uuid,jsonb,jsonb)','EXECUTE')
  or has_table_privilege('authenticated','device_private.activity_observations','SELECT') then raise exception 'Frontera privada expuesta'; end if;
 perform set_config('request.jwt.claim.sub',trainer::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',trainer,'role','authenticated','aal','aal2')::text,true);
 recipe:=public.get_trainer_assignment_result(scheduled);
 if recipe->>'status'<>'completed' or not exists(select 1 from jsonb_array_elements(recipe->'workout_execution_sets') s
   where s->>'set_order'='1' and s->>'actual_reps'='9' and (s->>'actual_load_kg')::numeric=22.5) then raise exception 'Trainer no recibe las series observadas'; end if;
end $$;
select 'garmin strength roundtrip contract passed' as result;
rollback;
