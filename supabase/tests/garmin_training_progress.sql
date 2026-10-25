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

do $$
declare owner uuid:=current_setting('fixture.owner')::uuid; session uuid:=current_setting('fixture.session')::uuid;
 scheduled uuid:=current_setting('fixture.scheduled')::uuid; teacher uuid:=auth.uid();
 state jsonb; src jsonb; catalog jsonb; delivery uuid; preview jsonb;
begin
 if has_function_privilege('authenticated','device_private.training_progress(uuid,uuid,uuid)','EXECUTE')
 or has_function_privilege('service_role','device_private.training_progress_list(uuid,uuid)','EXECUTE') then raise exception 'Proyección expuesta';end if;
 state:=device_private.training_progress(owner,owner,scheduled);
 if state->>'state' is distinct from 'not_sent' or state->>'reason' is distinct from 'auto_disabled' then raise exception 'Automático apagado confundido con envío: %',state;end if;
 if device_private.training_progress(gen_random_uuid(),owner,scheduled) is not null then raise exception 'Pauta ajena expuesta';end if;
 if device_private.training_progress(teacher,owner,scheduled) is null then raise exception 'Preparador no ve su pauta';end if;
 catalog:=public.garmin_training_command('list',owner,owner,session,'{}');
 if jsonb_array_length(catalog->'progress')<>2 or catalog::text like '%tokens_cipher%' or catalog::text like '%workout_id%' then raise exception 'Listado de progreso incorrecto';end if;
 catalog:=public.list_trainer_client_agenda(teacher,owner,current_date,current_date+5);
 if catalog->'items'->0->'device_training'->>'state' is distinct from 'not_sent' then raise exception 'Agenda no recibe estado propio';end if;
 perform public.garmin_training_sync_preferences(owner,session,true);
 state:=device_private.training_progress(owner,owner,scheduled);
 if state->>'state' is distinct from 'pending' then raise exception 'No explica cola pendiente: %',state;end if;
 src:=device_private.training_source(owner,owner,scheduled);
 insert into device_private.training_deliveries(owner_id,scheduled_id,connection_generation,revision,snapshot,status,workout_id,schedule_id)
 values(owner,scheduled,1,src->>'revision',src->'snapshot','sent',123,456) returning id into delivery;
 if device_private.training_progress(owner,owner,scheduled)->>'state' is distinct from 'sent' then raise exception 'No acredita envío confirmado';end if;
 -- Cambio real mediante el contrato profesional revisado, no edición directa.
 preview:=public.preview_trainer_assignment_change(scheduled,0,current_date+3,null);
 perform public.change_trainer_assignment_reviewed(gen_random_uuid(),scheduled,0,current_date+3,null,preview->>'fingerprint');
 if device_private.training_progress(owner,owner,scheduled)->>'state' is distinct from 'change_pending' then raise exception 'Cambio anunciado como enviado';end if;
 perform public.cancel_trainer_assignment(scheduled);
 if device_private.training_progress(owner,owner,scheduled)->>'state' is distinct from 'cancellation_pending' then raise exception 'Retirada anunciada antes de Garmin';end if;
 update device_private.training_deliveries set status='cancelled' where id=delivery;
 if device_private.training_progress(owner,owner,scheduled)->>'state' is distinct from 'cancelled' then raise exception 'Retirada no reflejada';end if;
 -- Un POST incierto no se transforma en no enviado al retirar la pauta.
 update device_private.training_deliveries set status='uncertain',workout_id=null,schedule_id=null,error_code='delivery_uncertain' where id=delivery;
 if device_private.training_progress(owner,owner,scheduled)->>'state' is distinct from 'review' then raise exception 'Se pierde la incertidumbre al retirar';end if;
 update device_private.training_deliveries set status='failed',error_code='provider_rejected' where id=delivery;
 -- Fechas fuera de ventana y compatibilidad siguen sin producir efectos externos.
 state:=device_private.training_progress(owner,owner,scheduled);
 if state->>'state' is distinct from 'not_sent' or state->>'reason' is distinct from 'appointment_cancelled' then raise exception 'Cita nunca enviada se declara retirada remota';end if;
end $$;
select 'garmin progress, scope and lifecycle passed' as result;
rollback;
