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
-- Contract shared with isolated PostgreSQL concurrency fixture.
do $$
declare owner uuid:=current_setting('fixture.owner')::uuid; session uuid:=current_setting('fixture.session')::uuid;
 scheduled uuid:=current_setting('fixture.scheduled')::uuid; job jsonb; input jsonb; src jsonb; claim jsonb; delivery uuid;
begin
 if device_private.training_sync_enabled(owner) then raise exception 'Automático activado sin autorización';end if;
 if has_function_privilege('authenticated','public.garmin_training_sync_command(text,jsonb)','EXECUTE')
 or has_function_privilege('anon','public.garmin_training_sync_preferences(uuid,uuid,boolean)','EXECUTE')
 or has_table_privilege('service_role','device_private.training_sync_jobs','UPDATE') then raise exception 'Cola pública';end if;
 begin perform public.garmin_training_sync_preferences(owner,gen_random_uuid(),true);raise exception 'Preferencia sin sesión';exception when insufficient_privilege then null;end;
 perform public.garmin_training_sync_preferences(owner,session,true);
 perform public.garmin_training_sync_command('scan','{}');
 job:=public.garmin_training_sync_command('take','{}');
 if job->'target'->>'mode'<>'sync' or job->>'operation'<>'create' then raise exception 'No publica cita profesional: %',job;end if;
 -- Otra toma no debe obtener la misma orden mientras dura el lease.
 if public.garmin_training_sync_command('take','{}')->>'id'=job->>'id' then raise exception 'Doble toma';end if;
 input:=jsonb_build_object('auto_job',job->>'id','auto_lease',job->>'lease');
 src:=device_private.garmin_training_command('preview',owner,owner,null,input||jsonb_build_object('scheduled_id',job->>'scheduled'));
 claim:=device_private.garmin_training_command('claim',owner,owner,null,input||jsonb_build_object('scheduled_id',job->>'scheduled','revision',src->>'revision','lease_id',job->>'lease'));
 delivery:=(claim->>'id')::uuid;
 input:=input||jsonb_build_object('id',delivery,'lease_id',job->>'lease');
 perform device_private.garmin_training_command('mark_creating',owner,owner,null,input);
 perform device_private.garmin_training_command('save_workout',owner,owner,null,input||'{"workout_id":123}');
 perform device_private.garmin_training_command('mark_scheduling',owner,owner,null,input);
 perform device_private.garmin_training_command('save_schedule',owner,owner,null,input||'{"schedule_id":456}');
 perform device_private.garmin_training_command('release',owner,owner,null,input);
 input:=jsonb_build_object('job_id',job->>'id','job_lease',job->>'lease');
 perform public.garmin_training_sync_command('finish',input||'{"outcome":"done"}');
 scheduled:=(job->>'scheduled')::uuid;
 -- Revisión/fecha reutiliza los IDs del recibo confirmado, sin nuevo POST.
 update public.scheduled_workouts set scheduled_date=scheduled_date+1 where id=scheduled;
 update device_private.training_sync_preferences set next_scan_at=now()-interval '1 second' where owner_id=owner;
 perform public.garmin_training_sync_command('scan','{}');
 -- Aislar esta orden de la segunda cita del constructor profesional.
 update device_private.training_sync_jobs set state='done' where owner_id=owner and scheduled_id<>scheduled;
 job:=public.garmin_training_sync_command('take','{}');
 input:=jsonb_build_object('job_id',job->>'id','job_lease',job->>'lease');
 claim:=public.garmin_training_sync_command('claim_change',input);
 if claim->>'workout_id'<>'123' or claim->>'schedule_id'<>'456' then raise exception 'Cambio pierde IDs';end if;
 perform public.garmin_training_sync_command('before_write',input);
 -- Cambio durante HTTP: frenar la siguiente escritura, conservar el hecho.
 update public.scheduled_workouts set scheduled_date=scheduled_date+1 where id=scheduled;
 begin perform public.garmin_training_sync_command('before_write',input);raise exception 'Escribe revisión obsoleta';exception when serialization_failure then null;end;
 perform public.garmin_training_sync_preferences(owner,session,false);
 begin perform public.garmin_training_sync_command('before_write',input);raise exception 'Escribe sin preferencia';exception when serialization_failure then null;end;
 perform public.garmin_training_sync_command('save_change',input);
 perform public.garmin_training_sync_command('finish',input||'{"outcome":"done"}');
 perform public.garmin_training_sync_command('release_change',input);
 perform public.garmin_training_sync_preferences(owner,session,true);
 if not exists(select 1 from device_private.training_delivery_versions where delivery_id=delivery) then raise exception 'No conserva versión';end if;
 -- Cancelar y retirar son acciones idempotentes sobre referencias propias.
 update public.scheduled_workouts set status='cancelled' where id=scheduled;
 update device_private.training_sync_preferences set next_scan_at=now()-interval '1 second' where owner_id=owner;
 perform public.garmin_training_sync_command('scan','{}');
 job:=public.garmin_training_sync_command('take','{}');input:=jsonb_build_object('job_id',job->>'id','job_lease',job->>'lease');
 if job->'target'->>'mode'<>'cancel' then raise exception 'Cancelación no observada';end if;
 perform public.garmin_training_sync_command('claim_change',input);
 perform public.garmin_training_sync_command('before_write',input);
 perform public.garmin_training_sync_command('save_change',input);
 perform public.garmin_training_sync_command('finish',input||'{"outcome":"done"}');
 perform public.garmin_training_sync_command('release_change',input);
 if (select status from device_private.training_deliveries where id=delivery)<>'cancelled' then raise exception 'Retirada no guardada';end if;
 -- El historial del recibo permanece al borrar la cita; no vuelve a retirar.
 delete from public.scheduled_workouts where id=scheduled;
 if device_private.training_sync_target(owner,scheduled)->>'mode'<>'hold' then raise exception 'Repite retirada';end if;
 perform public.garmin_training_sync_preferences(owner,session,false);
 if device_private.training_sync_enabled(owner) then raise exception 'No desactiva';end if;
 perform public.garmin_training_sync_preferences(owner,session,true);
 update device_private.garmin_connections set generation=generation+1 where owner_id=owner;
 if device_private.training_sync_enabled(owner) then raise exception 'Otra cuenta hereda autorización';end if;
end $$;
select 'automatic training contract passed' as result;
-- Publicación real del algoritmo y reset, sin modificar una cuenta existente.
do $$
declare owner uuid:=current_setting('fixture.owner')::uuid; g uuid; a uuid; published jsonb; s uuid; src jsonb; gen bigint;
begin
 insert into public.pro_access_grants(user_id,source,starts_at,ends_at,reason)
 values(owner,'development_manual',now()-interval '1 hour',now()+interval '1 day','Fixture automática con ROLLBACK');
 perform set_config('request.jwt.claim.sub',owner::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',owner,'role','authenticated','aal','aal1')::text,true);
 update public.profiles set fecha_nacimiento=date '1996-01-01' where id=owner;
 insert into public.preparation_goals(user_id,program_id,target_date) values(owner,'fas_periodic_assessment',current_date+90) returning id into g;
 insert into public.fas_periodic_assessments(user_id,preparation_goal_id,catalog_version,category,age_at_assessment,age_band,is_pre_effective_reference)
 values(owner,g,'es_def_15_2026_periodic_2027_v1','men',30,'26_30',true) returning id into a;
 insert into public.fas_periodic_marks(assessment_id,test_id,value) values(a,'run_2000_m',478000);
 insert into public.running_reference_selections(preparation_goal_id,reference_source,reference_record_id) values(g,'fasPeriodicAssessment',a::text);
 insert into public.running_intake_contexts(preparation_goal_id,context_version,available_minutes_by_weekday,reserved_strength_weekdays,
  running_days_last_four_weeks,running_minutes_last_four_weeks,recent_weeks_end_on,reports_pain,requires_professional_review,
  health_observed_at,comfortable_continuous_minutes,target_2k_seconds,goal_mode)
 values(g,'running_initial_context_v2','{"1":45,"3":45,"6":45}','{}',array[3,3,3,3],array[110,110,110,110],
  current_date-extract(isodow from current_date)::integer,false,false,now(),60,465,'time');
 published:=public.publish_fas_running_week(g,current_date+8-extract(isodow from current_date)::integer);
 select rs.scheduled_workout_id into s from public.running_week_sessions rs where rs.decision_id=(published->>'decision_id')::uuid limit 1;
 src:=device_private.training_sync_target(owner,s);
 if src->>'mode'<>'sync' or src->'snapshot'->>'source'<>'algorithm' then raise exception 'Algoritmo publicado no exportable';end if;
 select generation into gen from device_private.garmin_connections where owner_id=owner;
 insert into device_private.training_deliveries(owner_id,scheduled_id,connection_generation,revision,snapshot,status,workout_id,schedule_id)
 values(owner,s,gen,src->>'revision',src->'snapshot','sent',789,987);
 perform public.reset_running_plan(g);
 if device_private.training_sync_target(owner,s)->>'mode'<>'cancel' then raise exception 'Reset no retira la cita automática';end if;
end $$;
select 'algorithm publication and reset passed' as result;
rollback;
