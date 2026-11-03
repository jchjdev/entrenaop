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
 p jsonb; claim jsonb; observation jsonb; answer jsonb; wid uuid:=gen_random_uuid(); rid uuid;begin
 perform set_config('request.jwt.claim.sub',owner::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',owner,'role','authenticated','session_id',current_setting('fixture.session'),'aal','aal1')::text,true);
 if has_table_privilege('authenticated','device_private.apple_activity_results','SELECT') then raise exception 'Resultados privados expuestos';end if;
 begin perform public.apple_results_command(gen_random_uuid(),'catalog');raise exception 'Cuenta ajena admitida';exception when insufficient_privilege then null;end;
 if (public.apple_results_command(owner,'catalog')->>'enabled')::boolean then raise exception 'Activación implícita';end if;
 p:=public.apple_training_command(owner,'preview',jsonb_build_object('scheduled_id',sid));
 claim:=public.apple_training_command(owner,'prepare',jsonb_build_object('scheduled_id',sid,'revision',p->>'revision','attempt_id',gen_random_uuid()));
 perform public.apple_training_command(owner,'record',jsonb_build_object('scheduled_id',sid,'revision',claim->>'revision','attempt_id',claim->>'attempt_id'));
 observation:=jsonb_build_object('workout_id',wid,'plan_id',claim->>'plan_id','revision',claim->>'revision','matches_prescription',true,
  'started_at',to_char(now()-interval '3 minutes','YYYY-MM-DD"T"HH24:MI:SS.US"Z"'),
  'ended_at',to_char(now()-interval '1 minute','YYYY-MM-DD"T"HH24:MI:SS.US"Z"'),'timer_seconds',120,'distance_meters',400);
 begin perform public.apple_results_command(owner,'ingest',jsonb_build_object('observations',jsonb_build_array(observation)));
  raise exception 'Importación sin consentimiento';exception when insufficient_privilege then null;end;
 perform public.apple_results_command(owner,'enable','{"enabled":true}');
 answer:=public.apple_results_command(owner,'ingest',jsonb_build_object('observations',jsonb_build_array(observation)));
 if answer->>'inserted'<>'1' then raise exception 'No importa la actividad';end if;
 answer:=public.apple_results_command(owner,'ingest',jsonb_build_object('observations',jsonb_build_array(observation)));
 if answer->>'inserted'<>'0' then raise exception 'Duplicado de HealthKit';end if;
 answer:=public.apple_results_command(owner,'catalog');
 if jsonb_array_length(answer->'results')<>1 or answer->'results'->0->>'state'<>'associated' then raise exception 'No asocia receta exacta';end if;
 if answer->'results'->0 ? 'average_heart_rate' then raise exception 'Inventa FC ausente';end if;
 rid:=(answer->'results'->0->>'id')::uuid;
 perform set_config('fixture.apple.result',rid::text,true);
 if (public.my_apple_workout_results(owner,array[sid])->sid::text->0->>'id')::uuid<>rid then raise exception 'El alumno no ve los datos en su cita';end if;
 observation:=observation||'{"average_heart_rate":120,"max_heart_rate":150}';
 perform public.apple_results_command(owner,'ingest',jsonb_build_object('observations',jsonb_build_array(observation)));
 if public.apple_results_command(owner,'catalog')->'results'->0->>'average_heart_rate'<>'120' then raise exception 'No incorpora medición tardía';end if;
 observation:=observation||'{"distance_meters":999}';
 perform public.apple_results_command(owner,'ingest',jsonb_build_object('observations',jsonb_build_array(observation)));
 answer:=public.apple_results_command(owner,'catalog')->'results'->0;
 if answer->>'state'<>'review' or answer->>'distance_meters'<>'400' then raise exception 'Sobrescritura silenciosa de resultado';end if;
 perform public.apple_results_command(owner,'classify',jsonb_build_object('id',rid,'is_test',true));
 if public.apple_results_command(owner,'catalog')->'results'->0->>'state'<>'test' then raise exception 'Prueba no separada';end if;
 begin perform public.apple_results_command(owner,'ingest',jsonb_build_object('observations',jsonb_build_array(
  observation||jsonb_build_object('plan_id',gen_random_uuid()))));raise exception 'Acepta pauta ajena';exception when insufficient_privilege then null;end;
 perform public.apple_results_command(owner,'enable','{"enabled":false}');
 begin perform public.apple_results_command(owner,'ingest',jsonb_build_object('observations',jsonb_build_array(observation)));
  raise exception 'Guarda después de retirar consentimiento';exception when insufficient_privilege then null;end;
 perform set_config('request.jwt.claims',jsonb_build_object('sub',owner,'role','authenticated','session_id',gen_random_uuid(),'aal','aal1')::text,true);
 begin perform public.apple_results_command(owner,'catalog');raise exception 'Sesión revocada admitida';exception when insufficient_privilege then null;end;
end $$;
reset role;
do $$declare owner uuid:=current_setting('fixture.owner')::uuid; sid uuid:=current_setting('fixture.scheduled')::uuid;
 coach uuid; stranger uuid:=gen_random_uuid(); projection jsonb; agenda jsonb; observation jsonb;
 garmin uuid:=gen_random_uuid(); other_session uuid:=gen_random_uuid(); coach_session uuid;
 inbox jsonb; alternate_schedule uuid; alternate_job uuid:=gen_random_uuid();
begin
 select trainer_id into coach from public.trainer_assignments where scheduled_id=sid;
 select id into coach_session from auth.sessions where user_id=coach and aal='aal2' limit 1;
 -- Evidencia Garmin sintética recibida y vinculada por el trabajador, sin cierre.
 observation:=jsonb_build_object('schemaVersion',1,'externalId','10001','name','Carrera sintética',
  'startedAt','2026-10-20T08:00:00Z','offsetSeconds',3600,'timerSeconds',125.25,'elapsedSeconds',125.25,
  'distanceMeters',450,'averageHeartRate',120,'maxHeartRate',145,
  'laps',jsonb_build_array(jsonb_build_object('index',0,'startedAt','2026-10-20T08:00:00Z',
   'timerSeconds',125.25,'elapsedSeconds',125.25,'distanceMeters',450,'intensity','active','workoutStepIndex',0)));
 insert into device_private.activity_observations(id,owner_id,channel,external_id,revision,observation)
 values(garmin,owner,'garmin','10001',device_private.history_hash(observation),observation);
 -- Otra actividad privada del mismo deportista, sin vínculo con esta pauta.
 insert into device_private.activity_observations(owner_id,channel,external_id,revision,observation)
 values(owner,'garmin','10002',device_private.history_hash(observation||'{"externalId":"10002"}'),
  observation||'{"externalId":"10002"}');
 insert into device_private.activity_return_jobs(owner_id,id,event_key,generation,metadata,status,phase,
  completion_state,completion_code,matched_schedule_id,matched_delivery_revision)
 values(owner,gen_random_uuid(),repeat('a',64),1,'{"activityId":"10001","activityName":"Carrera sintética"}',
  'done','stored','review','intervals_require_review',sid,repeat('b',64));
 perform set_config('request.jwt.claim.sub',owner::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',owner,'role','authenticated','aal','aal1',
  'session_id',current_setting('fixture.session'))::text,true);
 if jsonb_array_length(public.my_scheduled_device_results(owner,array[sid])->sid::text)<>2 then
  raise exception 'El titular no ve ambos proveedores';end if;
 inbox:=public.my_unassigned_device_activities(owner);
 if not exists(select 1 from jsonb_array_elements(inbox) r where r->>'id'=garmin::text
  and r->>'state'='review' and r->>'scheduled_id'=sid::text
  and r->>'scheduled_name'=(select template_name from public.scheduled_workouts where id=sid)) then
  raise exception 'La bandeja presenta como no asociada una pauta identificada';end if;
 if not exists(select 1 from jsonb_array_elements(inbox) r where r->>'id'<>garmin::text
  and r->>'state'='unassigned' and r->>'scheduled_id' is null and r->>'scheduled_name' is null) then
  raise exception 'La bandeja inventa pauta para una actividad sin vínculo';end if;
 -- Un trabajo no finalizado no acredita vínculo; dos pautas distintas exigen elegir.
 select id into strict alternate_schedule from public.scheduled_workouts where user_id=owner and id<>sid;
 insert into device_private.activity_return_jobs(owner_id,id,event_key,generation,metadata,status,phase,
  matched_schedule_id,matched_delivery_revision)
 values(owner,alternate_job,repeat('c',64),1,'{"activityId":"10001"}',
  'pending','pending',alternate_schedule,repeat('d',64));
 if not exists(select 1 from jsonb_array_elements(public.my_unassigned_device_activities(owner)) r
  where r->>'id'=garmin::text and r->>'state'='review' and r->>'scheduled_id'=sid::text) then
  raise exception 'Un trabajo pendiente altera la pauta identificada';end if;
 update device_private.activity_return_jobs set status='done',phase='stored' where id=alternate_job;
 if not exists(select 1 from jsonb_array_elements(public.my_unassigned_device_activities(owner)) r
  where r->>'id'=garmin::text and r->>'state'='unassigned' and r->>'scheduled_id' is null) then
  raise exception 'La bandeja escoge entre pautas ambiguas';end if;
 update device_private.activity_return_jobs set status='pending',phase='pending' where id=alternate_job;
 perform set_config('request.jwt.claim.sub',coach::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',coach,'role','authenticated','aal','aal2',
  'session_id',coach_session)::text,true);
 projection:=device_private.apple_results_for_schedule(coach,owner,sid);
 if jsonb_array_length(projection)<>1 then raise exception 'El preparador no recibe datos';end if;
 agenda:=public.list_trainer_client_agenda_filtered('current',coach,owner,current_date,current_date+2);
 if not exists(select 1 from jsonb_array_elements(agenda->'items') entry
  where entry->>'id'=sid::text and entry->'device_training'->'apple_results'->0->>'id'=current_setting('fixture.apple.result')) then
  raise exception 'La agenda real de Trainer no incluye los datos';end if;
 projection:=device_private.results_for_schedule(coach,owner,sid);
 if jsonb_array_length(projection)<>2 or not exists(select 1 from jsonb_array_elements(projection) r
  where r->>'id'=garmin::text and r->>'provider'='garmin' and r->>'state'='review' and r->>'timer_seconds'='125.25') then
  raise exception 'El preparador no ve Garmin sin completar';end if;
 if not exists(select 1 from jsonb_array_elements(agenda->'items') entry
  where entry->>'id'=sid::text and jsonb_array_length(entry->'device_training'->'device_results')=2
   and entry->'device_training'->>'results_confirmed'='false') then
  raise exception 'La agenda no usa la proyección común';end if;
 if public.get_trainer_assignment_result(sid) is not null then raise exception 'La lectura inventa ejecución';end if;
 if exists(select 1 from jsonb_array_elements(projection) r where r ?| array[
  'external_id','observation','prescriptionReference','metadata','callback','tokens','positions','latitude','longitude']) then
  raise exception 'Expone detalles privados del proveedor';end if;
 if has_function_privilege('authenticated','device_private.results_for_schedule(uuid,uuid,uuid)','EXECUTE')
  or has_function_privilege('anon','device_private.results_for_schedule(uuid,uuid,uuid)','EXECUTE') then
  raise exception 'Expone lector privado';end if;
 -- Otro preparador vigente del mismo alumno sigue sin leer una pauta ajena.
 insert into auth.users(id,email) values(stranger,stranger||'@received-results.invalid');
 insert into auth.sessions(id,user_id,aal) values(other_session,stranger,'aal2');
 insert into auth.mfa_factors(id,user_id,factor_type,status,created_at,updated_at)
  values(gen_random_uuid(),stranger,'totp','verified',now(),now());
 insert into public.trainer_access(trainer_id,enabled,client_limit,last_reason) values(stranger,true,5,'Fixture con ROLLBACK');
 insert into public.trainer_client_relations(id,trainer_id,client_id,accepted_at) values(gen_random_uuid(),stranger,owner,now());
 perform set_config('request.jwt.claim.sub',stranger::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',stranger,'role','authenticated','aal','aal2',
  'session_id',other_session)::text,true);
 if not trainer_private.has_professional_read_access() then raise exception 'Fixture sin acceso profesional';end if;
 if device_private.results_for_schedule(stranger,owner,sid)<>'[]'::jsonb
  or device_private.results_for_schedule(coach,owner,sid)<>'[]'::jsonb then
  raise exception 'Otro preparador lee o suplanta al autor';end if;
 perform set_config('request.jwt.claim.sub',coach::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',coach,'role','authenticated','aal','aal2',
  'session_id',gen_random_uuid())::text,true);
 if device_private.results_for_schedule(coach,owner,sid)<>'[]'::jsonb then raise exception 'Sesión revocada conserva mediciones';end if;
 projection:=device_private.training_progress(coach,owner,sid);
 if projection->'device_results'<>'[]'::jsonb or projection->'apple_results'<>'[]'::jsonb then
  raise exception 'El campo anterior elude la comprobación de sesión viva';end if;
 perform set_config('request.jwt.claims',jsonb_build_object('sub',coach,'role','authenticated','aal','aal2',
  'session_id',coach_session)::text,true);
 if device_private.apple_results_for_schedule(stranger,owner,sid)<>'[]'::jsonb then raise exception 'Comparte con otro preparador';end if;
 if (select execution_id from public.scheduled_workouts where id=sid) is not null then raise exception 'Prueba crea ejecución ficticia';end if;
 update public.trainer_client_relations set ended_at=now() where trainer_id=coach and client_id=owner;
 if device_private.apple_results_for_schedule(coach,owner,sid)<>'[]'::jsonb then raise exception 'Relación retirada mantiene acceso';end if;
 if device_private.results_for_schedule(coach,owner,sid)<>'[]'::jsonb then raise exception 'Relación retirada mantiene Garmin';end if;
end $$;
select 'Apple/Garmin: consentimiento, sesión viva, asociación, replay, privacidad y lectura profesional común verificados' as result;
rollback;
