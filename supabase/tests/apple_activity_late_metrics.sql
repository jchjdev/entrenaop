begin;
set local statement_timeout='60s';
do $$
declare trainer uuid:=gen_random_uuid(); pupil uuid:=gen_random_uuid();
 relation uuid:=gen_random_uuid(); ps uuid:=gen_random_uuid(); ts uuid:=gen_random_uuid();
 template uuid; scheduled uuid:=gen_random_uuid(); recipe jsonb;
begin
 insert into auth.users(id,email) values(trainer,trainer||'@apple-return.invalid'),(pupil,pupil||'@apple-return.invalid');
 insert into auth.sessions(id,user_id,aal) values(ps,pupil,'aal1'),(ts,trainer,'aal2');
 insert into auth.mfa_factors(id,user_id,factor_type,status,created_at,updated_at) values(gen_random_uuid(),trainer,'totp','verified',now(),now());
 insert into public.trainer_access(trainer_id,enabled,client_limit,last_reason) values(trainer,true,5,'Fixture Apple con ROLLBACK');
 insert into public.trainer_client_relations(id,trainer_id,client_id,accepted_at) values(relation,trainer,pupil,now());
 perform set_config('request.jwt.claim.sub',trainer::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',trainer,'role','authenticated','aal','aal2')::text,true);
 recipe:=jsonb_build_object('name','Carrera sintética Apple','blocks',jsonb_build_array(jsonb_build_object(
  'name','Carrera','format','running','rounds',1,'rest_after_seconds',0,'exercises',jsonb_build_array(jsonb_build_object(
   'exercise_id','20000000-0000-4000-8000-000000000004','sets',jsonb_build_array(jsonb_build_object(
    'target_duration_seconds',120,'rest_after_seconds',0,'target_pace_min_seconds_per_km',300,'target_pace_max_seconds_per_km',360,
    'recovery_type','walking','recovery_duration_seconds',30)))))));
 template:=trainer_private.save_trainer_workout(gen_random_uuid(),recipe);
 perform trainer_private.assign_trainer_workout(scheduled,relation,template,current_date,null);

 perform set_config('fixture.owner',pupil::text,true);perform set_config('fixture.session',ps::text,true);
 perform set_config('fixture.scheduled',scheduled::text,true);
end $$;



set local role authenticated;
do $$declare owner uuid:=current_setting('fixture.owner')::uuid; sid uuid:=current_setting('fixture.scheduled')::uuid;
 p jsonb;claim jsonb;obs jsonb;answer jsonb;result_id uuid;execution uuid;
 started timestamptz:=now()-interval '3 minutes';wid uuid:=gen_random_uuid();begin
 perform set_config('request.jwt.claim.sub',owner::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',owner,'role','authenticated','session_id',current_setting('fixture.session'),'aal','aal1')::text,true);
 p:=public.apple_training_command(owner,'preview',jsonb_build_object('scheduled_id',sid));
 claim:=public.apple_training_command(owner,'prepare',jsonb_build_object('scheduled_id',sid,'revision',p->>'revision','attempt_id',gen_random_uuid()));
 perform public.apple_training_command(owner,'record',jsonb_build_object('scheduled_id',sid,'revision',claim->>'revision','attempt_id',claim->>'attempt_id'));
 perform public.apple_results_command(owner,'enable','{"enabled":true}');
 obs:=jsonb_build_object('workout_id',wid,'plan_id',claim->>'plan_id','revision',claim->>'revision','matches_prescription',true,
  'started_at',started,'ended_at',started+interval '117.3 seconds','timer_seconds',117.3,'distance_meters',420,
  'offset_minutes',60,'intervals',jsonb_build_array(
   jsonb_build_object('id',gen_random_uuid(),'started_at',started,'ended_at',started+interval '87.3 seconds','timer_seconds',87.3,'distance_meters',400),
   jsonb_build_object('id',gen_random_uuid(),'started_at',started+interval '87.3 seconds','ended_at',started+interval '117.3 seconds','timer_seconds',30,'distance_meters',20)));
 answer:=public.apple_results_command(owner,'ingest',jsonb_build_object('observations',jsonb_build_array(obs-'intervals'-'distance_meters')));
 if answer->'automatic'->0->>'state'<>'review' then raise exception 'Completa sin fases observadas';end if;
 answer:=public.apple_results_command(owner,'ingest',jsonb_build_object('observations',jsonb_build_array(jsonb_set(obs-'distance_meters','{intervals,1}',(obs->'intervals'->1)-'distance_meters'))));
 if answer->'automatic'->0->>'state'<>'completed' then raise exception 'No completa una actividad acreditada: %',answer;end if;
 execution:=(answer->'automatic'->0->>'execution_id')::uuid;
 if exists(select 1 from public.workout_executions where id=execution and final_rpe is not null) then
  raise exception 'Inventa esfuerzo ausente';end if;
 perform set_config('fixture.execution',execution::text,true);
 perform set_config('fixture.observation',obs::text,true);
end $$;
reset role;

set local role authenticated;
do $$declare owner uuid:=current_setting('fixture.owner')::uuid;e uuid:=current_setting('fixture.execution')::uuid;
 observation jsonb:=current_setting('fixture.observation')::jsonb;answer jsonb;begin
 -- Llega primero la cabecera, sin la distancia de la recuperación.
 perform public.apple_results_command(owner,'ingest',jsonb_build_object('observations',jsonb_build_array(observation-'intervals'||'{"average_heart_rate":150,"max_heart_rate":170}')));
 if not exists(select 1 from public.workout_executions where id=e and observed_distance_meters=420 and average_heart_rate_bpm=150 and max_heart_rate_bpm=170)
  then raise exception 'No incorpora métricas globales tardías';end if;
 if exists(select 1 from public.workout_execution_sets where execution_id=e and actual_recovery_distance_meters is not null) then raise exception 'Distribuye la distancia total entre fases';end if;
 perform public.apple_results_command(owner,'ingest',jsonb_build_object('observations',jsonb_build_array(observation)));
 if not exists(select 1 from public.workout_execution_sets where execution_id=e and actual_distance_meters=400 and actual_recovery_distance_meters=20 and observed_duration_seconds=87.3)
  then raise exception 'No incorpora distancias nativas de las fases';end if;
 perform public.add_device_workout_effort(owner,e,4);
 perform public.apple_results_command(owner,'ingest',jsonb_build_object('observations',jsonb_build_array(observation||'{"effort_score":6.0}')));
 if (select final_rpe from public.workout_executions where id=e)<>4 then raise exception 'Sobrescribe esfuerzo humano';end if;
end $$;
reset role;
do $$declare owner uuid:=current_setting('fixture.owner')::uuid;e uuid:=current_setting('fixture.execution')::uuid;
 observation jsonb:=current_setting('fixture.observation')::jsonb;saved_mapping jsonb;begin
 -- Una medida registrada se conserva aunque difiera de la observación.
 update public.workout_executions set average_heart_rate_bpm=151 where id=e;
 update public.workout_execution_sets set actual_recovery_distance_meters=25 where execution_id=e;
 perform public.apple_results_command(owner,'ingest',jsonb_build_object('observations',jsonb_build_array(observation)));
 if (select average_heart_rate_bpm from public.workout_executions where id=e)<>151 or
  exists(select 1 from public.workout_execution_sets where execution_id=e and actual_recovery_distance_meters<>25)
  then raise exception 'Sobrescribe una medida ya registrada';end if;
 -- El historial anterior puede enriquecer la cabecera, pero no inventar mappings.
 select mapping into saved_mapping from device_private.apple_activity_confirmations where owner_id=owner;
 update device_private.apple_activity_confirmations set mapping=null where owner_id=owner;
 update public.workout_executions set average_heart_rate_bpm=null where id=e;
 update public.workout_execution_sets set actual_recovery_distance_meters=null where execution_id=e;
 perform public.apple_results_command(owner,'ingest',jsonb_build_object('observations',jsonb_build_array(observation)));
 if (select average_heart_rate_bpm from public.workout_executions where id=e)<>150 or
  exists(select 1 from public.workout_execution_sets where execution_id=e and actual_recovery_distance_meters is not null)
  then raise exception 'Infiere una correspondencia histórica';end if;
 update device_private.apple_activity_confirmations set mapping=saved_mapping where owner_id=owner;
 -- Una corrección posterior mantiene su fuente y prevalece sobre el dato nativo.
 update public.workout_execution_sets set result_source='manual',actual_distance_meters=410 where execution_id=e;
 perform public.apple_results_command(owner,'ingest',jsonb_build_object('observations',jsonb_build_array(observation)));
 if not exists(select 1 from public.workout_execution_sets where execution_id=e and actual_distance_meters=410 and result_source='manual' and actual_recovery_distance_meters is null) then raise exception 'Pisa corrección';end if;
 if (select count(*) from device_private.apple_activity_confirmations where owner_id=owner)<>1 then raise exception 'Duplica recibo';end if;
 if (select count(*) from public.workout_executions where user_id=owner)<>1 then raise exception 'Duplica ejecución';end if;
 if has_function_privilege('authenticated','device_private.enrich_apple_execution(uuid,uuid)','EXECUTE') then raise exception 'Expone enriquecimiento';end if;
end $$;
select 'Apple: métricas tardías observadas sin repartos, sobrescrituras ni nuevo cierre verificadas' as result;
rollback;
