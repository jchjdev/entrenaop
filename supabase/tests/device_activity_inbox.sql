-- Evidencia sintética. No restaura pautas ni deja registros del ensayo.
begin;
set local statement_timeout='30s';
do $$
declare own uuid:=gen_random_uuid(); other_user uuid:=gen_random_uuid(); result jsonb;
 latest uuid:=gen_random_uuid(); first_id uuid:=gen_random_uuid(); activity jsonb;
begin
 insert into auth.users(id,email) values
  (own,own::text||'@device-inbox.invalid'),(other_user,other_user::text||'@device-inbox.invalid');
 activity:=jsonb_build_object('schemaVersion',1,'externalId','100','name','Carrera sintética',
  'startedAt','2026-10-20T08:00:00Z','elapsedSeconds',121.5,'timerSeconds',120.5,
  'distanceMeters',420.25,'averageHeartRate',null,'maxHeartRate',null,'laps','[]'::jsonb);
 insert into device_private.activity_observations(id,owner_id,channel,external_id,revision,observation,created_at) values
  (first_id,own,'garmin','100',repeat('a',64),activity,now()-interval '1 minute'),
  (latest,own,'garmin','100',repeat('b',64),activity||'{"timerSeconds":121.25}',now()),
  (gen_random_uuid(),other_user,'garmin','100',repeat('c',64),activity,now());
 perform set_config('request.jwt.claims',jsonb_build_object('sub',own,'role','authenticated')::text,true);
 execute 'set local role authenticated';
 result:=public.my_unassigned_device_activities(own);
 if jsonb_array_length(result)<>1 or result->0->>'id'<>latest::text or
  result->0->>'scheduled_id' is not null or result->0->>'state'<>'unassigned' or
  result->0->>'provider'<>'garmin' or (result->0->>'timer_seconds')::numeric<>121.25 or
  result->0->>'average_heart_rate' is not null or result->0 ?| array['external_id','owner_id','revision','observation','tokens'] then
  raise exception 'Bandeja propia incorrecta o campos privados expuestos';
 end if;
 begin
  perform public.my_unassigned_device_activities(other_user);
  raise exception 'Se permitió consultar a otra cuenta';
 exception when insufficient_privilege then null;end;
 execute 'reset role';
 -- Una confirmación previa retira la actividad de esta bandeja, no del historial.
 insert into device_private.activity_confirmations(id,owner_id,activity_id,external_id,scheduled_id,execution_id,
  source_revision,input_hash,mapping) values(gen_random_uuid(),own,latest,'100',gen_random_uuid(),gen_random_uuid(),
  'synthetic',repeat('d',64),'[]');
 if public.my_unassigned_device_activities(own)<>'[]'::jsonb then raise exception 'Confirmación ignorada';end if;
 perform set_config('request.jwt.claims','{}',true);
 begin
  perform public.my_unassigned_device_activities(own);
  raise exception 'Se permitió lectura sin identidad';
 exception when insufficient_privilege then null;end;
 if has_function_privilege('anon','public.my_unassigned_device_activities(uuid)','EXECUTE') or
  has_function_privilege('anon','device_private.my_unassigned_device_activities(uuid)','EXECUTE') then
  raise exception 'Lectura anónima concedida';end if;
end $$;
select 'device activity inbox contract passed' as result;
rollback;
