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
 lease uuid:=gen_random_uuid(); jid uuid:=gen_random_uuid(); aid uuid; e uuid;
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
    'target_duration_seconds',120,'rest_after_seconds',0,'recovery_type','walking','recovery_duration_seconds',30)))))));
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
  'offsetSeconds',7200,'elapsedSeconds',151.5,'timerSeconds',151.5,'distanceMeters',405.5,'averageHeartRate',121,'maxHeartRate',145,
  'laps',jsonb_build_array(
   jsonb_build_object('index',0,'timerSeconds',60.125,'elapsedSeconds',60.125,'distanceMeters',200.125),
   jsonb_build_object('index',1,'timerSeconds',61.125,'elapsedSeconds',61.125,'distanceMeters',200.125),
   jsonb_build_object('index',2,'timerSeconds',30.25,'elapsedSeconds',30.25,'distanceMeters',5.25)));
 perform public.garmin_activity_command('save',null,null,jsonb_build_object('id',jid,'lease_id',lease,'activity',observation));
 perform public.garmin_activity_command('release',null,null,jsonb_build_object('id',jid,'lease_id',lease));
 if exists(select 1 from device_private.activity_return_jobs where id=jid and callback_cipher is not null) then raise exception 'Conserva callback consumido'; end if;
 select id into aid from device_private.activity_observations where owner_id=pupil;
 if (select status from public.scheduled_workouts where id=scheduled)<>'planned' then raise exception 'Completa al recibir'; end if;
 begin perform public.garmin_activity_command('preview',stranger,ps,jsonb_build_object('activity_id',aid,'scheduled_id',scheduled)); raise exception 'Consulta ajena'; exception when insufficient_privilege then null; end;
 preview:=public.garmin_activity_command('preview',pupil,ps,jsonb_build_object('activity_id',aid,'scheduled_id',scheduled));
 begin
  update public.trainer_client_relations set ended_at=now() where id=relation;
  perform public.garmin_activity_command('preview',pupil,ps,jsonb_build_object('activity_id',aid,'scheduled_id',scheduled));
  raise exception 'Importación elude fin del servicio';
 exception when insufficient_privilege then null; end;
 -- La biblioteca puede editarse después de enviar: conservar la versión recibida.
 insert into device_private.training_deliveries(owner_id,scheduled_id,connection_generation,revision,snapshot,status,workout_id,schedule_id)
  values(pupil,scheduled,1,preview->>'source_revision',preview->'snapshot','sent',123,456);
 perform set_config('request.jwt.claim.sub',trainer::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',trainer,'role','authenticated','aal','aal2')::text,true);
 perform trainer_private.save_trainer_workout(gen_random_uuid(),recipe||'{"name":"Versión nueva"}',template);
 if (select status from public.workout_templates where id=template)<>'archived' then raise exception 'Fixture no archivó la versión previa'; end if;
 begin
  update device_private.training_deliveries set status='failed' where owner_id=pupil and scheduled_id=scheduled;
  perform public.garmin_activity_command('preview',pupil,ps,jsonb_build_object('activity_id',aid,'scheduled_id',scheduled));
  raise exception 'Versión archivada sin recibo enviada';
 exception when serialization_failure then null; end;
 begin
  update public.trainer_assignments set planning_revision=planning_revision+1 where scheduled_id=scheduled;
  perform public.garmin_activity_command('preview',pupil,ps,jsonb_build_object('activity_id',aid,'scheduled_id',scheduled));
  raise exception 'Revisión de asignación diferente';
 exception when serialization_failure then null; end;
 preview:=public.garmin_activity_command('preview',pupil,ps,jsonb_build_object('activity_id',aid,'scheduled_id',scheduled));
 input:=jsonb_build_object('operation_id',op,'activity_id',aid,'scheduled_id',scheduled,'activity_revision',preview->>'activity_revision',
  'source_revision',preview->>'source_revision','rpe',4,'mapping',jsonb_build_array(jsonb_build_object(
   'block_order',0,'item_order',0,'set_order',0,'lap_indices',jsonb_build_array(0,1),'recovery_lap_indices',jsonb_build_array(2))));
 begin perform public.garmin_activity_command('confirm',pupil,ps,input||jsonb_build_object('rpe',0)); raise exception 'RPE inválido'; exception when invalid_parameter_value then null; end;
 begin perform public.garmin_activity_command('confirm',pupil,ps,input||jsonb_build_object('source_revision',repeat('0',64))); raise exception 'Receta obsoleta'; exception when serialization_failure then null; end;
 begin perform public.garmin_activity_command('confirm',pupil,ps,jsonb_set(input,'{mapping,0,recovery_lap_indices}','[0]')); raise exception 'Reutiliza vuelta'; exception when invalid_parameter_value then null; end;
 if exists(select 1 from public.workout_executions where user_id=pupil) then raise exception 'Fallo deja ejecución parcial'; end if;
 receipt:=public.garmin_activity_command('confirm',pupil,ps,input); e:=(receipt->>'execution_id')::uuid;
 if (select status from public.scheduled_workouts where id=scheduled)<>'completed' then raise exception 'No completa semana'; end if;
 if not exists(select 1 from public.workout_execution_sets where execution_id=e and status='completed' and actual_duration_seconds=121
  and actual_distance_meters=400.25 and actual_recovery_duration_seconds=30 and actual_recovery_distance_meters=5.25 and result_source='device') then
  raise exception 'Cambia parciales o fuente'; end if;
 if not exists(select 1 from public.workout_executions where id=e and status='completed' and final_rpe=4 and performed_at is not null
   and observed_timer_seconds=151.5 and observed_elapsed_seconds=151.5 and observed_distance_meters=405.5) then
  raise exception 'Cierre sin valoración o reloj'; end if;
 if (select a.observation->'laps'->0->>'timerSeconds' from device_private.activity_observations a where a.id=aid)<>'60.125' then raise exception 'Pierde precisión de evidencia'; end if;
 if not(public.garmin_activity_command('confirm',pupil,ps,input)->>'replayed')::boolean then raise exception 'No recupera respuesta perdida'; end if;
 perform set_config('request.jwt.claim.sub',trainer::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',trainer,'role','authenticated','aal','aal2')::text,true);
 if public.get_trainer_assignment_result(scheduled)->>'observed_timer_seconds'<>'151.5'
  or public.get_trainer_assignment_result(scheduled)->>'status'<>'completed' then raise exception 'Trainer no recibe el mismo resultado'; end if;
 begin perform public.garmin_activity_command('confirm',pupil,ps,input||jsonb_build_object('rpe',5)); raise exception 'Reutiliza operación diferente'; exception when invalid_parameter_value then null; end;
 begin perform public.garmin_activity_command('confirm',pupil,ps,input||jsonb_build_object('operation_id',gen_random_uuid())); raise exception 'Duplica resultado'; exception when invalid_parameter_value then null; end;
 -- Una desconexión conserva el historial ya recibido.
 perform public.garmin_account_command('disconnect',pupil,ps,jsonb_build_object('generation',1));
 if jsonb_array_length(public.garmin_activity_command('list',pupil,ps,'{}')->'activities')<>1 then raise exception 'Desconexión borra historial'; end if;
 update device_private.activity_return_worker set enabled=true,token_hash=encode(sha256(convert_to('fixture-ticket','UTF8')),'hex'),
  ticket_used=false,ticket_expires_at=now()+interval '1 minute';
 if not(public.garmin_activity_command('authorize',null,null,'{"token":"fixture-ticket"}')->>'authorized')::boolean
   or (public.garmin_activity_command('authorize',null,null,'{"token":"fixture-ticket"}')->>'authorized')::boolean then
  raise exception 'Ticket reutilizable'; end if;
end $$;
select 'garmin activity return contract passed' as result;
rollback;
