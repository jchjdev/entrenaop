begin;
set local statement_timeout='60s';
do $$
declare coach uuid:=gen_random_uuid();owner uuid:=gen_random_uuid();relation uuid:=gen_random_uuid();
 session uuid:=gen_random_uuid();coach_session uuid:=gen_random_uuid();sid uuid:=gen_random_uuid();
 template uuid;recipe jsonb;preview jsonb;claim jsonb;obs jsonb;answer jsonb;execution uuid;result uuid;
 started timestamptz:=now()-interval '3 minutes';details jsonb;mode text;extra uuid;
begin
 insert into auth.users(id,email) values(coach,coach||'@partial-apple.invalid'),(owner,owner||'@partial-apple.invalid');
 insert into auth.sessions(id,user_id,aal) values(session,owner,'aal1'),(coach_session,coach,'aal2');
 insert into auth.mfa_factors(id,user_id,factor_type,status,created_at,updated_at) values(gen_random_uuid(),coach,'totp','verified',now(),now());
 insert into public.trainer_access(trainer_id,enabled,client_limit,last_reason) values(coach,true,5,'Prueba transaccional Apple');
 insert into public.trainer_client_relations(id,trainer_id,client_id,accepted_at) values(relation,coach,owner,now());
 perform set_config('request.jwt.claim.sub',coach::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',coach,'role','authenticated','aal','aal2','session_id',coach_session)::text,true);
 recipe:=jsonb_build_object('name','Intervalos parciales sintéticos','blocks',jsonb_build_array(jsonb_build_object(
  'name','Carrera','format','running','rounds',1,'rest_after_seconds',0,'exercises',jsonb_build_array(jsonb_build_object(
   'exercise_id','20000000-0000-4000-8000-000000000004','sets',jsonb_build_array(
    jsonb_build_object('target_distance_meters',400,'rest_after_seconds',0,'recovery_type','walking','recovery_duration_seconds',30),
    jsonb_build_object('target_distance_meters',400,'rest_after_seconds',0)))))));
 template:=trainer_private.save_trainer_workout(gen_random_uuid(),recipe);
 perform trainer_private.assign_trainer_workout(sid,relation,template,current_date,null);
 perform set_config('request.jwt.claim.sub',owner::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',owner,'role','authenticated','aal','aal1','session_id',session)::text,true);
 preview:=public.apple_training_command(owner,'preview',jsonb_build_object('scheduled_id',sid));
 claim:=public.apple_training_command(owner,'prepare',jsonb_build_object('scheduled_id',sid,'revision',preview->>'revision','attempt_id',gen_random_uuid()));
 perform public.apple_training_command(owner,'record',jsonb_build_object('scheduled_id',sid,'revision',claim->>'revision','attempt_id',claim->>'attempt_id'));
 perform public.apple_results_command(owner,'enable','{"enabled":true}');
 obs:=jsonb_build_object('workout_id',gen_random_uuid(),'plan_id',claim->>'plan_id','revision',claim->>'revision','matches_prescription',true,
  'started_at',started,'ended_at',started+interval '105 seconds','timer_seconds',105,'distance_meters',390,'offset_minutes',60,
  'intervals',jsonb_build_array(
   jsonb_build_object('id',gen_random_uuid(),'started_at',started,'ended_at',started+interval '90 seconds','timer_seconds',90,'distance_meters',390),
   jsonb_build_object('id',gen_random_uuid(),'started_at',started+interval '90 seconds','ended_at',started+interval '105 seconds','timer_seconds',15)));
 -- Una actividad global sin fases no completa una receta con varias fases.
 answer:=public.apple_results_command(owner,'ingest',jsonb_build_object('observations',jsonb_build_array(obs-'intervals')));
 if answer->'automatic'->0->>'state'<>'review' then raise exception 'Cierra sin desglose nativo';end if;
 answer:=public.apple_results_command(owner,'ingest',jsonb_build_object('observations',jsonb_build_array(obs)));
 if answer->'automatic'->0->>'state'<>'completed' then raise exception 'Bloquea una sesión parcial acreditada: %',answer;end if;
 execution:=(answer->'automatic'->0->>'execution_id')::uuid;
 if (select status from public.scheduled_workouts where id=sid)<>'completed' then raise exception 'No cierra semana';end if;
 if exists(select 1 from public.workout_execution_sets where execution_id=execution and
   (status<>'pending' or actual_distance_meters is not null or actual_duration_seconds is not null)) then
  raise exception 'Inventa series completadas u omitidas';end if;
 if not exists(select 1 from public.workout_executions where id=execution and status='completed' and
  final_rpe is null and observed_distance_meters=390 and observed_timer_seconds=105) then raise exception 'Pierde totales o inventa RPE';end if;
 details:=public.my_execution_device_details(owner,execution);
 if details->>'device_details_incomplete'<>'true' or jsonb_array_length(details->'device_results'->0->'intervals')<>2 or
   details->'device_results'->0->'intervals'->1 ? 'distance_meters' then raise exception 'Oculta intervalos o inventa distancia';end if;
 if details::text ~ 'workout_id|plan_id|source_snapshot|latitude|longitude' then raise exception 'Expone datos privados';end if;
 answer:=public.apple_results_command(owner,'ingest',jsonb_build_object('observations',jsonb_build_array(obs)));
 if (answer->'automatic'->0->>'execution_id')::uuid<>execution then raise exception 'Duplica cierre';end if;
 if (select count(*) from device_private.apple_activity_confirmations where owner_id=owner)<>1 then raise exception 'Duplica recibo';end if;
 -- La relectura no transforma las mediciones pendientes en valores cero.
 perform set_config('request.jwt.claim.sub',coach::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',coach,'role','authenticated','aal','aal2','session_id',coach_session)::text,true);
 details:=public.get_trainer_assignment_result(sid);
 if details->>'device_details_incomplete'<>'true' or jsonb_array_length(details->'device_results'->0->'intervals')<>2 then raise exception 'El autor no recibe el desglose';end if;
 begin perform public.my_execution_device_details(owner,execution);raise exception 'Suplanta titular';exception when insufficient_privilege then null;end;
 -- La nueva salida parcial no elude revisión de fuente, pruebas o fechas.
 foreach mode in array array['test','late','cancelled','mismatch'] loop
  extra:=gen_random_uuid();
  perform trainer_private.assign_trainer_workout(extra,relation,template,current_date,null);
  perform set_config('request.jwt.claim.sub',owner::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',owner,'role','authenticated','aal','aal1','session_id',session)::text,true);
  preview:=public.apple_training_command(owner,'preview',jsonb_build_object('scheduled_id',extra));
  claim:=public.apple_training_command(owner,'prepare',jsonb_build_object('scheduled_id',extra,'revision',preview->>'revision','attempt_id',gen_random_uuid()));
  perform public.apple_training_command(owner,'record',jsonb_build_object('scheduled_id',extra,'revision',claim->>'revision','attempt_id',claim->>'attempt_id'));
  obs:=obs||jsonb_build_object('workout_id',gen_random_uuid(),'plan_id',claim->>'plan_id','revision',claim->>'revision','matches_prescription',mode<>'mismatch');
  answer:=public.apple_results_command(owner,'ingest',jsonb_build_object('observations',jsonb_build_array(obs-'intervals')));
  select id into result from device_private.apple_activity_results where owner_id=owner and workout_id=(obs->>'workout_id')::uuid;
  if mode='test' then perform public.apple_results_command(owner,'classify',jsonb_build_object('id',result,'is_test',true));
  elsif mode='cancelled' then update public.scheduled_workouts set status='cancelled' where id=extra;
  elsif mode='late' then
   -- El origen conserva una fecha de pauta anterior al margen acordado.
   update device_private.apple_activity_results set source_snapshot=jsonb_set(source_snapshot,'{date}',to_jsonb((current_date-8)::text)) where id=result;
  end if;
  answer:=public.apple_results_command(owner,'ingest',jsonb_build_object('observations',jsonb_build_array(obs)));
  if answer->'automatic'->0->>'state'<>'review' or (select execution_id from public.scheduled_workouts where id=extra) is not null then
   raise exception 'Cierra una fuente bloqueada: % / %',mode,answer;end if;
  perform set_config('request.jwt.claim.sub',coach::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',coach,'role','authenticated','aal','aal2','session_id',coach_session)::text,true);
 end loop;
 -- Todas las fases presentes tampoco permiten inventar la distancia de un
 -- tramo por tiempo, ni forzar ceros de recuperación en campos incompatibles.
 recipe:=jsonb_set(recipe,'{blocks,0,exercises,0,sets}',jsonb_build_array(
  jsonb_build_object('target_duration_seconds',90,'rest_after_seconds',0,'recovery_type','walking','recovery_duration_seconds',10),
  jsonb_build_object('target_duration_seconds',5,'rest_after_seconds',0)));
 template:=trainer_private.save_trainer_workout(gen_random_uuid(),recipe);
 foreach mode in array array['missing_distance','zero_recovery','short_recovery'] loop
  extra:=gen_random_uuid();
  perform trainer_private.assign_trainer_workout(extra,relation,template,current_date,null);
  perform set_config('request.jwt.claim.sub',owner::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',owner,'role','authenticated','aal','aal1','session_id',session)::text,true);
  preview:=public.apple_training_command(owner,'preview',jsonb_build_object('scheduled_id',extra));
  claim:=public.apple_training_command(owner,'prepare',jsonb_build_object('scheduled_id',extra,'revision',preview->>'revision','attempt_id',gen_random_uuid()));
  perform public.apple_training_command(owner,'record',jsonb_build_object('scheduled_id',extra,'revision',claim->>'revision','attempt_id',claim->>'attempt_id'));
  obs:=obs||jsonb_build_object('workout_id',gen_random_uuid(),'plan_id',claim->>'plan_id','revision',claim->>'revision','matches_prescription',true,
   'timer_seconds',case when mode='short_recovery' then 95.1 else 105 end,'intervals',jsonb_build_array(
    jsonb_build_object('id',gen_random_uuid(),'started_at',started,'ended_at',started+interval '90 seconds','timer_seconds',90,'distance_meters',390),
    jsonb_strip_nulls(jsonb_build_object('id',gen_random_uuid(),'started_at',started+interval '90 seconds','ended_at',started+interval '100 seconds',
     'timer_seconds',case when mode='short_recovery' then 0.1 else 10 end,'distance_meters',case when mode='zero_recovery' then 0 when mode='short_recovery' then 1 end)),
    jsonb_strip_nulls(jsonb_build_object('id',gen_random_uuid(),'started_at',started+interval '100 seconds','ended_at',started+interval '105 seconds','timer_seconds',5,
     'distance_meters',case when mode<>'missing_distance' then 0 end))));
  answer:=public.apple_results_command(owner,'ingest',jsonb_build_object('observations',jsonb_build_array(obs)));
  if answer->'automatic'->0->>'state'<>'completed' or answer->'automatic'->0->>'details_incomplete'<>'true' then raise exception 'Bloquea %: %',mode,answer;end if;
  perform set_config('request.jwt.claim.sub',coach::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',coach,'role','authenticated','aal','aal2','session_id',coach_session)::text,true);
 end loop;
 extra:=gen_random_uuid();
 perform trainer_private.assign_trainer_workout(extra,relation,template,current_date,null);
 perform set_config('request.jwt.claim.sub',owner::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',owner,'role','authenticated','aal','aal1','session_id',session)::text,true);
 execution:=public.start_scheduled_workout(extra);
 begin
  perform public.finish_workout_execution(execution,4,null,null,null,'device');
  raise exception 'Un cliente cierra series pendientes sin recibo privado';
 exception when others then
  if sqlerrm<>'Workout execution still has pending sets' then raise;end if;
 end;
 if has_function_privilege('authenticated','device_private.complete_apple_partial_result(uuid,uuid)','EXECUTE') or
   has_function_privilege('authenticated','device_private.execution_device_details(uuid,uuid)','EXECUTE') or
   has_function_privilege('anon','public.my_execution_device_details(uuid,uuid)','EXECUTE') then raise exception 'Concede privilegios privados';end if;
end $$;
select 'Apple parcial: cierre, mediciones ausentes, lectura profesional, privacidad e idempotencia verificados' as result;
rollback;
