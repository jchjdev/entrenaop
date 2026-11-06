-- Cuentas y recepciones sintéticas; ningún dato real ni efecto persistente.
begin;
set local statement_timeout='60s';
set local timezone='UTC';
do $$
declare
 effort numeric; expected integer; trainer uuid; pupil uuid; relation uuid; ps uuid; ts uuid;
 template uuid; scheduled uuid; lease uuid; jid uuid; execution uuid; recipe jsonb;
 observation jsonb; src jsonb; saved jsonb; input jsonb; receipt jsonb; newer uuid; newer_revision text;
begin
 foreach effort in array array[null,4,4.5,0,10]::numeric[] loop
  trainer:=gen_random_uuid();pupil:=gen_random_uuid();relation:=gen_random_uuid();
  ps:=gen_random_uuid();ts:=gen_random_uuid();scheduled:=gen_random_uuid();lease:=gen_random_uuid();jid:=gen_random_uuid();
  insert into auth.users(id,email) values(trainer,trainer||'@garmin-effort.invalid'),(pupil,pupil||'@garmin-effort.invalid');
  insert into auth.sessions(id,user_id,aal) values(ps,pupil,'aal1'),(ts,trainer,'aal2');
  insert into auth.mfa_factors(id,user_id,factor_type,status,created_at,updated_at)
   values(gen_random_uuid(),trainer,'totp','verified',now(),now());
  insert into public.trainer_access(trainer_id,enabled,client_limit,last_reason) values(trainer,true,5,'Fixture RPE con ROLLBACK');
  insert into public.trainer_client_relations(id,trainer_id,client_id,accepted_at) values(relation,trainer,pupil,now());
  perform set_config('request.jwt.claim.sub',trainer::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',trainer,'session_id',ts,'role','authenticated','aal','aal2')::text,true);
  recipe:=jsonb_build_object('name','RPE sintético','blocks',jsonb_build_array(jsonb_build_object(
   'name','Carrera','format','running','rounds',1,'rest_after_seconds',0,'exercises',jsonb_build_array(jsonb_build_object(
    'exercise_id','20000000-0000-4000-8000-000000000004','sets',jsonb_build_array(jsonb_build_object(
     'target_distance_meters',400,'rest_after_seconds',0)))))));
  template:=trainer_private.save_trainer_workout(gen_random_uuid(),recipe);
  perform trainer_private.assign_trainer_workout(scheduled,relation,template,current_date,null);
  perform public.garmin_account_command('begin',pupil,ps,
   jsonb_build_object('state_hash',device_private.history_hash(to_jsonb(pupil)),'verifier_cipher','fixture'));
  perform public.garmin_account_command('claim',null,null,
   jsonb_build_object('state_hash',device_private.history_hash(to_jsonb(pupil)),'claim_id',lease));
  perform public.garmin_account_command('complete',pupil,null,jsonb_build_object('generation',1,'claim_id',lease,
   'tokens_cipher','fixture-encrypted','access_expires_at',now()+interval '1 hour','refresh_expires_at',now()+interval '1 day',
   'garmin_user_id',pupil::text,'can_read',true,'can_send',true));
  perform public.garmin_activity_command('enqueue',null,null,jsonb_build_object('id',jid,
   'event_key',device_private.history_hash(jsonb_build_object('job',jid)),'provider_user_id',pupil::text,
   'callback_cipher','fixture-callback','metadata',jsonb_build_object('activityId','123456','activityName','Fixture RPE')));
  perform public.garmin_activity_command('claim',null,null,jsonb_build_object('id',jid,'lease_id',lease));
  observation:=jsonb_build_object('schemaVersion',1,'externalId','123456','name','Fixture RPE',
   'startedAt',to_char(now()-interval '1 hour','YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'),
   'offsetSeconds',0,'elapsedSeconds',120,'timerSeconds',120,'distanceMeters',400,'averageHeartRate',120,'maxHeartRate',145,
   'prescriptionReference','fixture-reference','laps',jsonb_build_array(jsonb_build_object('index',0,
    'timerSeconds',120,'elapsedSeconds',120,'distanceMeters',400)));
  if effort is not null then observation:=observation||jsonb_build_object('perceivedExertion',effort);end if;
  saved:=public.garmin_activity_command('save',null,null,jsonb_build_object('id',jid,'lease_id',lease,'activity',observation));
  src:=device_private.activity_source(pupil,pupil,scheduled);
  insert into device_private.training_deliveries(owner_id,scheduled_id,provider,adapter_version,connection_generation,revision,snapshot,status,workout_id,schedule_id)
   values(pupil,scheduled,'garmin',1,1,src->>'revision',src->'snapshot','sent',123,456);
  perform set_config('request.jwt.claim.sub','',true);
  perform set_config('request.jwt.claims','{"role":"service_role"}',true);
  input:=saved||jsonb_build_object('id',jid,'lease_id',lease,'scheduled_id',scheduled,'delivery_revision',src->>'revision',
   'mapping',jsonb_build_array(jsonb_build_object('block_order',0,'item_order',0,'set_order',0,
    'lap_indices',jsonb_build_array(0),'recovery_lap_indices','[]'::jsonb,'skipped',false)));
  -- Un rpe añadido por el transporte no sustituye el que consta en la evidencia.
  receipt:=public.garmin_activity_command('automatic.complete',pupil,null,input||'{"rpe":9}');
  execution:=(receipt->>'execution_id')::uuid;
  expected:=case when effort between 1 and 10 and trunc(effort)=effort then effort::integer end;
  if not exists(select 1 from public.workout_executions where id=execution and status='completed'
   and result_source='device' and final_rpe is not distinct from expected) then raise exception 'RPE observado incorrecto: %',effort;end if;
  if effort is null then
   -- Una segunda revisión puede aportar el RPE antes ausente, sin nueva ejecución.
   observation:=observation||'{"perceivedExertion":4,"prescriptionStepIndices":[0]}';
   newer_revision:=device_private.history_hash(observation);
   insert into device_private.activity_observations(owner_id,channel,external_id,revision,observation)
    values(pupil,'garmin','123456',newer_revision,observation) returning id into newer;
   input:=input||jsonb_build_object('activity_id',newer,'activity_revision',newer_revision);
   perform public.garmin_activity_command('automatic.context',pupil,null,input);
   if (select final_rpe from public.workout_executions where id=execution) is distinct from 4 then raise exception 'No incorpora RPE tardío';end if;
   observation:=observation||'{"perceivedExertion":6}';
   newer_revision:=device_private.history_hash(observation);
   insert into device_private.activity_observations(owner_id,channel,external_id,revision,observation)
    values(pupil,'garmin','123456',newer_revision,observation) returning id into newer;
   input:=input||jsonb_build_object('activity_id',newer,'activity_revision',newer_revision);
   perform public.garmin_activity_command('automatic.context',pupil,null,input);
   if (select final_rpe from public.workout_executions where id=execution) is distinct from 4 then raise exception 'Sobrescribe RPE existente';end if;
   -- Una evidencia deportiva distinta no puede enriquecer el resultado anterior.
   update public.workout_executions set final_rpe=null where id=execution;
   observation:=observation||'{"timerSeconds":121,"elapsedSeconds":121}';
   newer_revision:=device_private.history_hash(observation);
   insert into device_private.activity_observations(owner_id,channel,external_id,revision,observation)
    values(pupil,'garmin','123456',newer_revision,observation) returning id into newer;
   perform public.garmin_activity_command('automatic.context',pupil,null,
    input||jsonb_build_object('activity_id',newer,'activity_revision',newer_revision));
   if (select final_rpe from public.workout_executions where id=execution) is not null then raise exception 'Acepta otra evidencia deportiva';end if;
  end if;
  if (select count(*) from device_private.activity_confirmations where owner_id=pupil)<>1 then raise exception 'Duplica confirmación';end if;
  perform public.garmin_activity_command('release',pupil,null,jsonb_build_object('id',jid,'lease_id',lease));
 end loop;
 if device_private.garmin_recorded_effort('{"perceivedExertion":"4"}') is not null
  or device_private.garmin_recorded_effort('{"perceivedExertion":99}') is not null
  or device_private.garmin_recorded_effort('{}') is not null then raise exception 'Interpreta esfuerzo ausente o inválido';end if;
 if has_function_privilege('authenticated','device_private.garmin_recorded_effort(jsonb)','EXECUTE')
  or has_function_privilege('authenticated','device_private.enrich_garmin_execution_effort(uuid,uuid)','EXECUTE')
  or has_function_privilege('service_role','device_private.enrich_garmin_execution_effort(uuid,uuid)','EXECUTE')
  or has_function_privilege('anon','device_private.enrich_garmin_execution_effort(uuid,uuid)','EXECUTE')
  then raise exception 'Auxiliar privado expuesto';end if;
end $$;
select 'Garmin RPE: evidencia, ausencia, decimal, incorporación tardía, protección de correcciones y permisos verificados' as result;
rollback;
