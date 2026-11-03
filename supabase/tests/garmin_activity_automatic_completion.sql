-- Fixtures sintéticas: nunca una reconstrucción de la carrera de una persona.
begin;
set local statement_timeout='60s';
set local timezone='UTC';
do $$
declare
 trainer uuid:=gen_random_uuid(); pupil uuid:=gen_random_uuid(); stranger uuid:=gen_random_uuid();
 relation uuid:=gen_random_uuid(); ps uuid:=gen_random_uuid(); ts uuid:=gen_random_uuid();
 template uuid; scheduled uuid:=gen_random_uuid(); recipe jsonb; observation jsonb;
 preview jsonb; claim jsonb; receipt jsonb; input jsonb; op uuid:=gen_random_uuid();
 lease uuid:=gen_random_uuid(); jid uuid:=gen_random_uuid(); aid uuid; e uuid; src jsonb; original_context jsonb;
begin
 insert into auth.users(id,email) values(trainer,trainer||'@activity-return.invalid'),(pupil,pupil||'@activity-return.invalid'),(stranger,stranger||'@activity-return.invalid');
 insert into auth.sessions(id,user_id,aal) values(ps,pupil,'aal1'),(ts,trainer,'aal2');
 insert into auth.mfa_factors(id,user_id,factor_type,status,created_at,updated_at) values(gen_random_uuid(),trainer,'totp','verified',now(),now());
 insert into public.trainer_access(trainer_id,enabled,client_limit,last_reason) values(trainer,true,5,'Fixture con ROLLBACK');
 insert into public.trainer_client_relations(id,trainer_id,client_id,accepted_at) values(relation,trainer,pupil,now());
 perform set_config('request.jwt.claim.sub',trainer::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',trainer,'role','authenticated','aal','aal2')::text,true);
 recipe:=jsonb_build_object('name','Retorno sintético','blocks',jsonb_build_array(jsonb_build_object(
  'name','Carrera','format','running','rounds',1,'rest_after_seconds',0,'exercises',jsonb_build_array(jsonb_build_object(
   'exercise_id','20000000-0000-4000-8000-000000000004','sets',jsonb_build_array(jsonb_build_object(
    'target_distance_meters',400,'rest_after_seconds',0,'recovery_type','walking','recovery_duration_seconds',30)))))));
 template:=trainer_private.save_trainer_workout(gen_random_uuid(),recipe);
 perform trainer_private.assign_trainer_workout(scheduled,relation,template,current_date,null);
 if has_table_privilege('authenticated','device_private.activity_observations','SELECT')
  or has_table_privilege('service_role','device_private.activity_observations','INSERT')
  or has_function_privilege('authenticated','public.garmin_activity_command(text,uuid,uuid,jsonb)','EXECUTE') then
  raise exception 'Evidencia privada expuesta'; end if;
 if has_function_privilege('authenticated','device_private.apply_activity_mapping(uuid,jsonb,jsonb)','EXECUTE')
  or has_function_privilege('service_role','device_private.activity_source(uuid,uuid,uuid)','EXECUTE') then
  raise exception 'Proyección privada expuesta'; end if;
 begin perform public.garmin_activity_command('list',stranger,ps,'{}'); raise exception 'Suplantación de sesión'; exception when insufficient_privilege then null; end;
 perform public.garmin_account_command('begin',pupil,ps,jsonb_build_object('state_hash',repeat('d',64),'verifier_cipher','fixture'));
 perform public.garmin_account_command('claim',null,null,jsonb_build_object('state_hash',repeat('d',64),'claim_id',lease));
 perform public.garmin_account_command('complete',pupil,null,jsonb_build_object('generation',1,'claim_id',lease,
  'tokens_cipher','fixture-encrypted','access_expires_at',now()+interval '1 hour','refresh_expires_at',now()+interval '1 day',
  'garmin_user_id',pupil::text,'can_read',true,'can_send',true));
 input:=jsonb_build_object('id',jid,'event_key',repeat('e',64),'provider_user_id',pupil::text,'callback_cipher','fixture-callback',
  'metadata',jsonb_build_object('activityId','123456','activityName','Fixture'));
 if not(public.garmin_activity_command('enqueue',null,null,input||jsonb_build_object('provider_user_id','unknown'))->>'ignored')::boolean then
  raise exception 'Acepta identidad desconocida'; end if;
 perform public.garmin_activity_command('enqueue',null,null,input);
 perform public.garmin_activity_command('enqueue',null,null,input||jsonb_build_object('id',gen_random_uuid()));
 if (select count(*) from device_private.activity_return_jobs where owner_id=pupil)<>1 then raise exception 'Duplica notificación'; end if;
 update device_private.garmin_connections set training_lease=lease,training_lease_until=now()+interval '1 minute' where owner_id=pupil;
 if not(public.garmin_activity_command('claim',null,null,jsonb_build_object('id',jid,'lease_id',gen_random_uuid()))->>'busy')::boolean then
  raise exception 'Colisiona con renovación de salida'; end if;
 update device_private.garmin_connections set training_lease=null,training_lease_until=null where owner_id=pupil;
 claim:=public.garmin_activity_command('claim',null,null,jsonb_build_object('id',jid,'lease_id',lease));
 if claim->>'tokens'<>'fixture-encrypted' then raise exception 'No devuelve concesión al adaptador'; end if;
 observation:=jsonb_build_object('schemaVersion',1,'externalId','123456','name','Fixture',
  'startedAt',to_char(now()-interval '1 hour','YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'),
  'offsetSeconds',7200,'elapsedSeconds',151.5,'timerSeconds',151.5,'distanceMeters',12.5,'averageHeartRate',121,'maxHeartRate',145,
  'laps',jsonb_build_array(
   jsonb_build_object('index',0,'timerSeconds',60.125,'elapsedSeconds',60.125,'distanceMeters',4.125),
   jsonb_build_object('index',1,'timerSeconds',61.125,'elapsedSeconds',61.125,'distanceMeters',3.125),
   jsonb_build_object('index',2,'timerSeconds',30.25,'elapsedSeconds',30.25,'distanceMeters',5.25)));
 observation:=observation||jsonb_build_object('prescriptionReference','fixture-complete-reference');
 receipt:=public.garmin_activity_command('save',null,null,jsonb_build_object('id',jid,'lease_id',lease,'activity',observation));
 -- La recepción ya está almacenada; la conciliación no depende de sesión móvil.
 delete from auth.sessions where user_id=pupil;
 src:=device_private.activity_source(pupil,pupil,scheduled);
 insert into device_private.training_deliveries(owner_id,scheduled_id,provider,adapter_version,connection_generation,revision,snapshot,status,workout_id,schedule_id)
 values(pupil,scheduled,'garmin',1,1,src->>'revision',src->'snapshot','sent',123,456);
 perform set_config('request.jwt.claim.sub','',true);
 perform set_config('request.jwt.claims','{"role":"service_role"}',true);
 -- Una relectura posterior del mismo identificador no cambia la evidencia que
 -- está conciliando este trabajador.
 insert into device_private.activity_observations(owner_id,channel,external_id,revision,observation)
 values(pupil,'garmin','123456',device_private.history_hash(observation||'{"name":"Relectura posterior"}'),observation||'{"name":"Relectura posterior"}');
 input:=jsonb_build_object('id',jid,'lease_id',lease)||receipt;
 original_context:=public.garmin_activity_command('automatic.context',pupil,null,input);
 if original_context->>'activity_id'<>receipt->>'activity_id' then raise exception 'Conciliación sobre otra revisión';end if;
 if jsonb_array_length(original_context->'candidates')<>1 then raise exception 'No encuentra la versión enviada';end if;
 begin
  perform public.garmin_activity_command('automatic.context',pupil,null,input||jsonb_build_object('lease_id',gen_random_uuid()));
  raise exception 'Acepta lease ajeno';
 exception when serialization_failure then null;end;
 begin
  perform public.garmin_activity_command('automatic.context',pupil,ps,input);
  raise exception 'Expone acciones del trabajador a sesión móvil';
 exception when insufficient_privilege then null;end;
 input:=input||jsonb_build_object('activity_id',original_context->>'activity_id','activity_revision',original_context->>'activity_revision',
  'scheduled_id',scheduled,'delivery_revision',src->>'revision','mapping',jsonb_build_array(jsonb_build_object(
  'block_order',0,'item_order',0,'set_order',0,'lap_indices',jsonb_build_array(0,1),'recovery_lap_indices',jsonb_build_array(2),'skipped',false)));
 -- La recepción inequívoca debe verse incluso antes de completar intervalos.
 perform public.garmin_activity_command('automatic.review',pupil,null,input||'{"code":"intervals_require_review"}');
 if (select matched_schedule_id from device_private.activity_return_jobs where id=jid) is distinct from scheduled
   or exists(select 1 from public.workout_executions where user_id=pupil) then
  raise exception 'Recibir y vincular no debe completar';end if;
 insert into auth.sessions(id,user_id,aal) values(ps,pupil,'aal1');
 perform set_config('request.jwt.claim.sub',pupil::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',pupil,'session_id',ps,'role','authenticated','aal','aal1')::text,true);
 preview:=public.my_scheduled_device_results(pupil,array[scheduled]);
 if jsonb_array_length(preview->scheduled::text)<>1 or preview->scheduled::text->0->>'provider'<>'garmin'
  or preview->scheduled::text->0->>'state'<>'review' then raise exception 'No muestra recepción: %',preview;end if;
 begin
  perform public.my_scheduled_device_results(stranger,array[scheduled]);
  raise exception 'Lee agenda ajena';exception when insufficient_privilege then null;end;
 if has_table_privilege('authenticated','device_private.activity_return_jobs','SELECT') or
  has_function_privilege('anon','public.my_scheduled_device_results(uuid,uuid[])','EXECUTE') then
   raise exception 'Expone evidencia privada';end if;
 delete from auth.sessions where id=ps;
 perform set_config('request.jwt.claim.sub','',true);
 perform set_config('request.jwt.claims','{"role":"service_role"}',true);
 begin
  perform public.garmin_activity_command('automatic.complete',pupil,null,input||jsonb_build_object('delivery_revision',repeat('f',64)));
  raise exception 'Acepta versión distinta';
 exception when serialization_failure then null;end;
 begin
  update device_private.training_deliveries set status='cancelled' where owner_id=pupil;
  perform public.garmin_activity_command('automatic.complete',pupil,null,input);
  raise exception 'Completa una versión retirada';
 exception when serialization_failure then null;end;
 begin
  update device_private.activity_observations ao set observation=jsonb_set(ao.observation,'{startedAt}',to_jsonb((now()+interval '8 days')::text)) where owner_id=pupil;
  perform public.garmin_activity_command('automatic.complete',pupil,null,input);
  raise exception 'Completa fuera de siete días';
 exception when serialization_failure then null;end;
 begin
  update device_private.activity_observations ao set observation=jsonb_set(ao.observation,'{startedAt}',to_jsonb((now()+interval '1 day')::text)) where owner_id=pupil;
  perform public.garmin_activity_command('automatic.complete',pupil,null,input);
  raise exception 'Acepta reloj futuro';
 exception when invalid_parameter_value then
  if sqlerrm<>'invalid_activity_clock' then raise;end if;end;
 begin
  perform public.garmin_activity_command('automatic.complete',pupil,null,input||jsonb_build_object('mapping','[]'::jsonb));
  raise exception 'Completa sin correspondencias';
 exception when invalid_parameter_value then null;end;
 begin
  update device_private.garmin_connections set can_read=false where owner_id=pupil;
  perform public.garmin_activity_command('automatic.complete',pupil,null,input);
  raise exception 'Completa sin lectura autorizada';
 exception when insufficient_privilege then null;end;
 begin
  perform public.garmin_activity_command('automatic.complete',pupil,null,
   jsonb_set(input,'{mapping,0,set_order}','99'));
  raise exception 'Acepta una fila inexistente';
 exception when invalid_parameter_value then null;end;
 if auth.uid() is not null or auth.jwt()->>'role'<>'service_role' then raise exception 'Filtra identidad tras error';end if;
 if exists(select 1 from public.workout_executions where user_id=pupil) then raise exception 'Deja ejecuciones parciales';end if;
 receipt:=public.garmin_activity_command('automatic.complete',pupil,null,input);
 if receipt->>'completed'<>'true' then raise exception 'No completa automáticamente: %',receipt;end if;
 e:=(receipt->>'execution_id')::uuid;
 if auth.uid() is not null or auth.jwt()->>'role'<>'service_role' then raise exception 'Filtra identidad al trabajador';end if;
 if (select status from public.scheduled_workouts where id=scheduled)<>'completed' or
  not exists(select 1 from public.workout_executions where id=e and final_rpe is null and result_source='device'
   and observed_timer_seconds=151.5 and observed_distance_meters=12.5) then raise exception 'Pierde datos o inventa esfuerzo';end if;
 -- La pauta sigue siendo 400 m; haber registrado menos no altera la receta
 -- ni convierte una serie recortada en la dosis completa.
 if not exists(select 1 from public.workout_execution_sets where execution_id=e
  and target_distance_meters=400 and actual_distance_meters=7.25 and status='completed') then
  raise exception 'La serie recortada no conserva lo pautado frente a lo realizado';end if;
 if (select observed_duration_seconds from public.workout_execution_sets where execution_id=e)<>121.25 then raise exception 'Redondea evidencia original';end if;
 if (public.garmin_activity_command('automatic.complete',pupil,null,input)->>'execution_id')::uuid<>e then raise exception 'No es idempotente';end if;
 if (select count(*) from device_private.activity_confirmations where owner_id=pupil)<>1 then raise exception 'Duplica cierre';end if;
 perform public.garmin_activity_command('release',pupil,null,jsonb_build_object('id',jid,'lease_id',lease));
 perform set_config('request.jwt.claim.sub',trainer::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',trainer,'session_id',ts,'role','authenticated','aal','aal2')::text,true);
 preview:=public.get_trainer_assignment_result(scheduled);
 if preview->>'status'<>'completed' or preview->>'observed_distance_meters'<>'12.5' then
  raise exception 'El preparador no recibe la sesión recortada completada';end if;
 if has_function_privilege('authenticated','device_private.garmin_automatic_result(text,uuid,jsonb)','EXECUTE') or
  has_function_privilege('anon','public.garmin_activity_command(text,uuid,uuid,jsonb)','EXECUTE') then raise exception 'Privilegios excesivos';end if;
end $$;
select 'Garmin automático: lease, ventana, retirada, precisión, RPE pendiente y replay verificados' as result;
rollback;
