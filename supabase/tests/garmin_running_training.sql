-- Solo datos sintéticos. El mismo contrato sirve a alumno y preparador.
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

 if public.has_pro_access(pupil) or not device_private.garmin_access(pupil) then raise exception 'Alumno exige Pro adicional'; end if;
 if has_table_privilege('authenticated','device_private.training_deliveries','SELECT')
   or has_table_privilege('service_role','device_private.training_deliveries','UPDATE')
   or has_function_privilege('authenticated','public.garmin_training_command(text,uuid,uuid,uuid,jsonb)','EXECUTE')
   or has_function_privilege('anon','device_private.training_source(uuid,uuid,uuid)','EXECUTE') then raise exception 'Contrato privado expuesto'; end if;
 preview:=device_private.garmin_training_command('preview',pupil,pupil,ps,jsonb_build_object('scheduled_id',scheduled));
 if preview->'snapshot'->>'source'<>'coach' or jsonb_array_length(preview->'snapshot'->'blocks')<>1 then raise exception 'Snapshot incorrecto'; end if;
 if device_private.garmin_training_command('preview',trainer,pupil,ts,jsonb_build_object('scheduled_id',scheduled))<>preview then raise exception 'Preparador no comparte snapshot'; end if;
 begin perform device_private.garmin_training_command('preview',trainer,pupil,weak,jsonb_build_object('scheduled_id',scheduled));raise exception 'Preparador sin MFA';exception when insufficient_privilege then null;end;
 begin perform device_private.garmin_training_command('preview',stranger,pupil,ps,jsonb_build_object('scheduled_id',scheduled));raise exception 'Suplantación de sesión';exception when insufficient_privilege then null;end;
 update public.scheduled_workouts set source='library' where id=scheduled;
 begin perform device_private.garmin_training_command('preview',pupil,pupil,ps,jsonb_build_object('scheduled_id',scheduled));raise exception 'Sesión personal exportable';exception when insufficient_privilege then null;end;
 update public.scheduled_workouts set source='algorithm' where id=scheduled;
 begin perform device_private.garmin_training_command('preview',pupil,pupil,ps,jsonb_build_object('scheduled_id',scheduled));raise exception 'Origen algoritmo falsificado';exception when insufficient_privilege then null;end;
 update public.scheduled_workouts set source='coach' where id=scheduled;

 perform public.garmin_account_command('begin',pupil,ps,jsonb_build_object('state_hash',repeat('b',64),'verifier_cipher','fixture'));
 perform public.garmin_account_command('claim',null,null,jsonb_build_object('state_hash',repeat('b',64),'claim_id',lease));
 perform public.garmin_account_command('complete',pupil,null,jsonb_build_object('generation',1,'claim_id',lease,
  'tokens_cipher','fixture-encrypted','access_expires_at',now()+interval '1 hour','refresh_expires_at',now()+interval '1 day',
  'garmin_user_id',pupil::text,'can_read',true,'can_send',true));
 begin perform device_private.garmin_training_command('claim',pupil,pupil,ps,jsonb_build_object('scheduled_id',scheduled,'revision',repeat('0',64),'lease_id',lease));raise exception 'Revisión inventada';exception when serialization_failure then null;end;
 claim:=device_private.garmin_training_command('claim',pupil,pupil,ps,jsonb_build_object('scheduled_id',scheduled,'revision',preview->>'revision','lease_id',lease));
 jid:=(claim->>'id')::uuid;
 if claim->>'tokens_cipher'<>'fixture-encrypted' then raise exception 'Backend sin concesión'; end if;
 begin perform device_private.garmin_training_command('claim',pupil,pupil,ps,jsonb_build_object('scheduled_id',scheduled,'revision',preview->>'revision','lease_id',gen_random_uuid()));raise exception 'Dos workers';exception when serialization_failure then null;end;
 update public.scheduled_workouts set scheduled_date=scheduled_date+1 where id=scheduled;
 begin perform device_private.garmin_training_command('mark_creating',pupil,pupil,ps,jsonb_build_object('id',jid,'lease_id',lease));raise exception 'Fecha obsoleta enviada';exception when serialization_failure then null;end;
 update public.scheduled_workouts set scheduled_date=scheduled_date-1 where id=scheduled;
 perform device_private.garmin_training_command('mark_refreshing',pupil,pupil,ps,jsonb_build_object('id',jid,'lease_id',lease));
 perform public.garmin_account_command('disconnect',pupil,ps,jsonb_build_object('generation',1));
 if not(public.garmin_account_command('claim_revoke',pupil,null,jsonb_build_object('lease_id',gen_random_uuid()))->>'pending')::boolean then raise exception 'Revoca durante envío';end if;
 -- Una rotación ya devuelta se guarda incluso tras desconexión concurrente.
 perform device_private.garmin_training_command('rotate',pupil,pupil,ps,jsonb_build_object('id',jid,'lease_id',lease,
  'tokens_cipher','fixture-rotated','access_expires_at',now()+interval '1 hour','refresh_expires_at',now()+interval '1 day'));
 begin perform device_private.garmin_training_command('mark_creating',pupil,pupil,ps,jsonb_build_object('id',jid,'lease_id',lease));raise exception 'Envío tras desconectar';exception when serialization_failure then null;end;
 perform device_private.garmin_training_command('fail',pupil,pupil,ps,jsonb_build_object('id',jid,'lease_id',lease,'code','connection_changed','uncertain',false));
 -- El recibo y la liberación sobreviven a logout/fin de servicio a mitad de HTTP.
 delete from auth.sessions where id=ps;
 perform device_private.garmin_training_command('release',pupil,pupil,ps,jsonb_build_object('id',jid,'lease_id',lease));
 if public.garmin_account_command('claim_revoke',pupil,null,jsonb_build_object('lease_id',gen_random_uuid()))->>'tokens_cipher'<>'fixture-rotated' then raise exception 'Pierde refresh rotado';end if;
 insert into auth.sessions(id,user_id,aal) values(ps,pupil,'aal1');
 update device_private.garmin_connections set generation=2,status='connected',can_send=true,disconnect_lease=null,disconnect_lease_until=null where owner_id=pupil;
 update device_private.training_deliveries set last_attempt_at=now()-interval '1 minute' where id=jid;
 claim:=device_private.garmin_training_command('claim',trainer,pupil,ts,jsonb_build_object('scheduled_id',scheduled,'revision',preview->>'revision','lease_id',lease));
 if (claim->>'generation')::integer<>2 then raise exception 'No permite reconectar tras fallo sin efecto remoto';end if;
 perform device_private.garmin_training_command('permissions',trainer,pupil,ts,jsonb_build_object('id',jid,'lease_id',lease,'can_read',true,'can_send',true));
 perform device_private.garmin_training_command('mark_creating',trainer,pupil,ts,jsonb_build_object('id',jid,'lease_id',lease));
 perform device_private.garmin_training_command('save_workout',trainer,pupil,ts,jsonb_build_object('id',jid,'lease_id',lease,'workout_id',123));
 perform device_private.garmin_training_command('mark_scheduling',trainer,pupil,ts,jsonb_build_object('id',jid,'lease_id',lease));
 receipt:=device_private.garmin_training_command('save_schedule',trainer,pupil,ts,jsonb_build_object('id',jid,'lease_id',lease,'schedule_id',456));
 if receipt->>'status'<>'sent' or receipt::text like '%tokens_cipher%' or receipt::text like '%fixture-rotated%' then raise exception 'Recibo inválido o privado';end if;
 receipt:=device_private.garmin_training_command('fail',trainer,pupil,ts,jsonb_build_object('id',jid,'lease_id',lease,'code','garmin_unavailable','uncertain',true));
 if receipt->>'status'<>'sent' then raise exception 'Respuesta perdida borra recibo final confirmado';end if;
 perform device_private.garmin_training_command('release',trainer,pupil,ts,jsonb_build_object('id',jid,'lease_id',lease));
 claim:=device_private.garmin_training_command('claim',pupil,pupil,ps,jsonb_build_object('scheduled_id',scheduled,'revision',preview->>'revision','lease_id',gen_random_uuid()));
 if not(claim->>'done')::boolean or claim?'tokens_cipher' then raise exception 'Reintento reenvía';end if;
 update public.scheduled_workouts set scheduled_date=scheduled_date+1 where id=scheduled;
 preview:=device_private.garmin_training_command('preview',pupil,pupil,ps,jsonb_build_object('scheduled_id',scheduled));
 begin perform device_private.garmin_training_command('claim',pupil,pupil,ps,jsonb_build_object('scheduled_id',scheduled,'revision',preview->>'revision','lease_id',lease));raise exception 'Revisión duplica envío';exception when serialization_failure then null;end;

 preview:=device_private.garmin_training_command('preview',pupil,pupil,ps,jsonb_build_object('scheduled_id',second));
 claim:=device_private.garmin_training_command('claim',pupil,pupil,ps,jsonb_build_object('scheduled_id',second,'revision',preview->>'revision','lease_id',lease));jid:=(claim->>'id')::uuid;
 perform device_private.garmin_training_command('mark_creating',pupil,pupil,ps,jsonb_build_object('id',jid,'lease_id',lease));
 update device_private.training_deliveries set lease_until=now()-interval '1 second' where id=jid;
 update device_private.garmin_connections set training_lease_until=now()-interval '1 second' where owner_id=pupil;
 claim:=device_private.garmin_training_command('claim',pupil,pupil,ps,jsonb_build_object('scheduled_id',second,'revision',preview->>'revision','lease_id',gen_random_uuid()));
 if not(claim->>'done')::boolean or claim->'receipt'->>'status'<>'uncertain' or claim?'tokens_cipher' then raise exception 'Reintenta POST incierto';end if;
 begin perform device_private.garmin_training_command('save_workout',pupil,pupil,ps,jsonb_build_object('id',jid,'lease_id',lease,'workout_id',789));raise exception 'Worker caducado escribe';exception when serialization_failure then null;end;
end $$;
select 'garmin training contract passed' as result;
rollback;
