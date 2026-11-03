-- Grabación sintética sin desplazamiento; no contiene datos de una persona.
begin;
set local statement_timeout='60s';
set local timezone='UTC';

do $$
declare
 trainer uuid:=gen_random_uuid(); pupil uuid:=gen_random_uuid(); ps uuid:=gen_random_uuid(); lease uuid:=gen_random_uuid();
 jid uuid:=gen_random_uuid(); observation jsonb; aid uuid; received jsonb; invalid jsonb;
begin
 insert into auth.users(id,email) values(pupil,pupil||'@zero-distance.invalid'),(trainer,trainer||'@zero-distance.invalid');
 insert into public.trainer_access(trainer_id,enabled,client_limit,last_reason) values(trainer,true,5,'Fixture con ROLLBACK');
 insert into public.trainer_client_relations(id,trainer_id,client_id,accepted_at) values(gen_random_uuid(),trainer,pupil,now());
 insert into auth.sessions(id,user_id,aal) values(ps,pupil,'aal1');
 perform set_config('request.jwt.claim.sub',pupil::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',pupil,'role','authenticated','session_id',ps)::text,true);
 perform public.garmin_account_command('begin',pupil,ps,jsonb_build_object('state_hash',repeat('a',64),'verifier_cipher','fixture'));
 perform public.garmin_account_command('claim',null,null,jsonb_build_object('state_hash',repeat('a',64),'claim_id',lease));
 perform public.garmin_account_command('complete',pupil,null,jsonb_build_object('generation',1,'claim_id',lease,
  'tokens_cipher','fixture-encrypted','access_expires_at',now()+interval '1 hour','refresh_expires_at',now()+interval '1 day',
  'garmin_user_id',pupil::text,'can_read',true,'can_send',true));
 perform public.garmin_activity_command('enqueue',null,null,jsonb_build_object('id',jid,'event_key',repeat('b',64),
  'provider_user_id',pupil::text,'callback_cipher','fixture-callback',
  'metadata',jsonb_build_object('activityId','123456','activityName','Prueba sin desplazamiento')));
 perform public.garmin_activity_command('claim',null,null,jsonb_build_object('id',jid,'lease_id',lease));
 observation:=jsonb_build_object('schemaVersion',1,'externalId','123456','name','Prueba sin desplazamiento',
  'startedAt',to_char(now()-interval '1 hour','YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'),
  'offsetSeconds',3600,'elapsedSeconds',45.25,'timerSeconds',45.25,'distanceMeters',0,'averageHeartRate',120,'maxHeartRate',140,
  'laps',jsonb_build_array(jsonb_build_object('index',0,
   'startedAt',to_char(now()-interval '1 hour','YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'),
   'elapsedSeconds',45.25,'timerSeconds',45.25,'distanceMeters',0,'intensity','active','workoutStepIndex',0)));
 perform public.garmin_activity_command('save',null,null,jsonb_build_object('id',jid,'lease_id',lease,'activity',observation));
 perform public.garmin_activity_command('release',null,null,jsonb_build_object('id',jid,'lease_id',lease));
 select id into aid from device_private.activity_observations where owner_id=pupil and external_id='123456';
 if aid is null then raise exception 'No conserva la grabación de cero metros'; end if;
 select a.observation into received from device_private.activity_observations a where a.id=aid;
 if received is distinct from observation then raise exception 'Altera los ceros o las mediciones'; end if;
 if exists(select 1 from public.workout_executions where user_id=pupil) then raise exception 'Completa por recibir una prueba'; end if;
 if not exists(select 1 from device_private.activity_return_jobs where id=jid and status='done' and callback_cipher is null) then
  raise exception 'No termina la recepción o conserva el callback consumido'; end if;
 if jsonb_array_length(public.garmin_activity_command('list',pupil,ps,'{}')->'activities')<>1 then
  raise exception 'No permite consultar la grabación recibida'; end if;
 for invalid in select value from jsonb_array_elements('[-1,1000001,null]'::jsonb) loop
  begin
   update device_private.activity_observations set observation=jsonb_set(received,'{distanceMeters}',invalid) where id=aid;
   raise exception 'Acepta distancia inválida: %',invalid;
  exception when check_violation then null; end;
 end loop;
 if has_table_privilege('authenticated','device_private.activity_observations','SELECT') then
  raise exception 'Expone evidencia privada'; end if;
end $$;

rollback;
