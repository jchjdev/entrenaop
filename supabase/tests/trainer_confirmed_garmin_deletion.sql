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

 perform public.garmin_account_command('begin',pupil,ps,jsonb_build_object('state_hash',repeat('c',64),'verifier_cipher','fixture'));
 perform public.garmin_account_command('claim',null,null,jsonb_build_object('state_hash',repeat('c',64),'claim_id',lease));
 perform public.garmin_account_command('complete',pupil,null,jsonb_build_object('generation',1,'claim_id',lease,
  'tokens_cipher','fixture-encrypted','access_expires_at',now()+interval '1 hour','refresh_expires_at',now()+interval '1 day',
  'garmin_user_id',pupil::text,'can_read',true,'can_send',true));
 perform set_config('fixture.owner',pupil::text,true);perform set_config('fixture.session',ps::text,true);
 perform set_config('fixture.scheduled',scheduled::text,true);
end $$;

-- El recibo se confirma por las mismas transiciones de servicio que el worker.
do $$
declare owner uuid:=current_setting('fixture.owner')::uuid; session uuid:=current_setting('fixture.session')::uuid;
 scheduled uuid:=current_setting('fixture.scheduled')::uuid; coach uuid:=auth.uid();
 src jsonb;delivery uuid;job uuid;lease uuid:=gen_random_uuid();input jsonb;response jsonb;op uuid:=gen_random_uuid();
 versions bigint;history jsonb;epoch_before bigint;
begin
 update device_private.training_sync_preferences set enabled=false where owner_id<>owner;
 src:=device_private.training_source(coach,owner,scheduled);
 insert into device_private.training_deliveries(owner_id,scheduled_id,connection_generation,revision,snapshot,status,workout_id,schedule_id)
 values(owner,scheduled,1,src->>'revision',src->'snapshot','sent',123,456) returning id into delivery;
 perform public.cancel_trainer_assignment(scheduled);
 if trainer_private.assignment_delete_block(scheduled)<>'garmin' then raise exception 'Permite borrar antes de retirar de Garmin';end if;
 perform public.garmin_training_sync_preferences(owner,session,true);
 insert into device_private.training_sync_jobs(owner_id,scheduled_id,state,lease_id,lease_until,claimed_epoch,target)
 values(owner,scheduled,'running',lease,clock_timestamp()+interval '3 minutes',1,device_private.training_sync_target(owner,scheduled)) returning id into job;
 input:=jsonb_build_object('job_id',job,'job_lease',lease);
 set local role service_role;
 perform public.garmin_training_sync_command('claim_change',input);
 perform public.garmin_training_sync_command('save_change',input);
 reset role;
 if (select status from device_private.training_deliveries where id=delivery)<>'cancelled' then raise exception 'No guarda retirada confirmada';end if;
 if trainer_private.assignment_delete_block(scheduled)<>'garmin' then raise exception 'Borra antes de terminar operación';end if;
 set local role service_role;
 perform public.garmin_training_sync_command('finish',input||'{"outcome":"done"}'::jsonb);
 reset role;
 if trainer_private.assignment_delete_block(scheduled)<>'garmin' then raise exception 'Ignora lease por liberar';end if;
 set local role service_role;
 perform public.garmin_training_sync_command('release_change',input);
 reset role;
 if trainer_private.assignment_delete_block(scheduled) is not null then raise exception 'Bloquea retirada confirmada sin resultados ni operaciones';end if;
 -- Se conserva el bloqueo de estados no confirmados y nuevas operaciones.
 update device_private.training_deliveries set status='uncertain' where id=delivery;
 if trainer_private.assignment_delete_block(scheduled)<>'garmin' then raise exception 'Permite entrega incierta';end if;
 update device_private.training_deliveries set status='cancelled' where id=delivery;
 update device_private.training_sync_jobs set state='review' where id=job;
 if trainer_private.assignment_delete_block(scheduled)<>'garmin' then raise exception 'Permite cola en revisión';end if;
 update device_private.training_sync_jobs set state='done' where id=job;
 update device_private.training_delivery_versions set workout_id=999 where delivery_id=delivery;
 if trainer_private.assignment_delete_block(scheduled)<>'garmin' then raise exception 'Olvida otro ID remoto histórico';end if;
 update device_private.training_delivery_versions set workout_id=123 where delivery_id=delivery;
 select count(*) into versions from device_private.training_delivery_versions where delivery_id=delivery;
 if versions<1 then raise exception 'No guarda versiones anteriores';end if;
 select to_jsonb(d) into history from device_private.training_deliveries d where id=delivery;
 select epoch into epoch_before from device_private.training_sync_jobs where id=job;
 set local role authenticated;
 response:=public.list_trainer_client_agenda_filtered('withdrawn',coach,owner,current_date,current_date+5);
 if not exists(select 1 from jsonb_array_elements(response->'items') x where x->>'id'=scheduled::text and x->'delete_block_reason'='null'::jsonb) then raise exception 'La ficha sigue bloqueando borrado seguro';end if;
 response:=public.change_trainer_assignment_lifecycle(coach,op,scheduled,0,'delete');
 if public.change_trainer_assignment_lifecycle(coach,op,scheduled,0,'delete')<>response then raise exception 'Reintento no idempotente';end if;
 begin perform public.garmin_training_sync_command('save_change',input);raise exception 'Alumno/preparador simula confirmación Garmin';exception when insufficient_privilege then null;end;
 reset role;
 if exists(select 1 from public.scheduled_workouts where id=scheduled) then raise exception 'No elimina cita';end if;
 if (select to_jsonb(d) from device_private.training_deliveries d where id=delivery) is distinct from history or
 (select count(*) from device_private.training_delivery_versions where delivery_id=delivery)<>versions then raise exception 'Borrado destruye evidencia Garmin';end if;
 -- El escaneo conserva el recibo, pero no crea ni reclama trabajo para su tombstone.
 update device_private.training_sync_preferences set next_scan_at=clock_timestamp()-interval '1 second' where owner_id=owner;
 set local role service_role;
 perform public.garmin_training_sync_command('scan','{}');
 response:=public.garmin_training_sync_command('take','{}');
 reset role;
 if response->>'scheduled'=scheduled::text or exists(select 1 from device_private.training_sync_jobs where id=job and (state<>'done' or epoch<>epoch_before or lease_id is not null)) then raise exception 'Sincronizador resucita cita borrada';end if;
 begin update device_private.training_sync_jobs set state='pending' where id=job;raise exception 'Reabre trabajo después de borrar';exception when foreign_key_violation then null;end;
 begin update device_private.training_deliveries set status='sent' where id=delivery;raise exception 'Reabre entrega después de borrar';exception when foreign_key_violation then null;end;
end $$;
select 'trainer_confirmed_garmin_deletion: OK' as result;
rollback;
