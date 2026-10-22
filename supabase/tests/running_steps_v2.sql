-- Solo fixtures sintéticos. No se conservan usuarios, recetas o ejecuciones.
begin;
set local statement_timeout='90s';
do $$
declare u uuid:=gen_random_uuid(); coach uuid:=gen_random_uuid(); pupil uuid:=gen_random_uuid();
 relation uuid:=gen_random_uuid(); schedule uuid:=gen_random_uuid(); tid uuid; copy_id uuid; eid uuid;
 coach_template uuid; admin_template uuid; raw jsonb; recipe jsonb; sets jsonb; snapshot jsonb; origin jsonb;
 s jsonb; sid uuid; n integer; bad jsonb;
begin
 insert into auth.users(id,email) values(u,u||'@running-v2.invalid'),(coach,coach||'@running-v2.invalid'),(pupil,pupil||'@running-v2.invalid');
 insert into public.admin_permissions(user_id) values(coach);
 insert into auth.mfa_factors(id,user_id,factor_type,status,created_at,updated_at) values(gen_random_uuid(),coach,'totp','verified',now(),now());
 insert into public.trainer_access(trainer_id,enabled,client_limit,last_reason) values(coach,true,2,'Fixture carrera V2');
 insert into public.trainer_client_relations(id,trainer_id,client_id,accepted_at) values(relation,coach,pupil,now());
 sets:='[{"running_step":{"schema_version":2,"kind":"warmup","completion":"manual"},"rest_after_seconds":0}]';
 for n in 1..5 loop
  sets:=sets||jsonb_build_array(jsonb_build_object('running_step',jsonb_build_object('schema_version',2,'kind','run','completion','distance'),
   'target_distance_meters',400,'target_pace_min_seconds_per_km',240,'target_pace_max_seconds_per_km',270,
   'recovery_type','passive','recovery_duration_seconds',90,'rest_after_seconds',0));
 end loop;
 sets:=sets||'[{"running_step":{"schema_version":2,"kind":"cooldown","completion":"manual"},"rest_after_seconds":0}]'::jsonb;
 recipe:=jsonb_build_object('name','Carrera V2 sintética','blocks',jsonb_build_array(jsonb_build_object('name','Carrera','format','running',
  'rounds',1,'rest_after_seconds',0,'exercises',jsonb_build_array(jsonb_build_object('exercise_id','20000000-0000-4000-8000-000000000004','sets',sets)))));
 perform set_config('request.jwt.claim.sub',u::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',u,'role','authenticated','aal','aal1')::text,true);
 tid:=public.create_personal_workout_template(recipe);
 select count(*) into n from public.workout_sets s join public.workout_items i on i.id=s.item_id join public.workout_blocks b on b.id=i.block_id
  where b.template_id=tid and s.running_step is not null;
 if n<>7 then raise exception 'Se pierden pasos V2 al guardar';end if;
 copy_id:=public.duplicate_personal_workout_template(tid);
 if (select count(*) from public.workout_sets s join public.workout_items i on i.id=s.item_id join public.workout_blocks b on b.id=i.block_id
  where b.template_id=copy_id and s.running_step->>'completion'='manual')<>2 then raise exception 'La copia pierde avance manual';end if;
 eid:=public.start_workout_execution(tid);
 if (select count(*) from public.workout_execution_sets where execution_id=eid and running_step is not null)<>7 then raise exception 'Se pierde snapshot V2';end if;
 select id into sid from public.workout_execution_sets where execution_id=eid and running_step->>'kind'='warmup';
 begin update public.workout_execution_sets set running_step=jsonb_set(running_step,'{kind}','"run"') where id=sid;
  raise exception 'Permite alterar snapshot';exception when invalid_parameter_value then null;end;
 if (select target_duration_seconds is not null or target_distance_meters is not null from public.workout_execution_sets where id=sid)
  then raise exception 'Inventó una medida manual';end if;
 -- Rechazo atómico: una receta manual nunca acepta una duración simultánea.
 bad:=jsonb_set(recipe,'{blocks,0,exercises,0,sets,0,target_duration_seconds}','60');
 begin perform public.create_personal_workout_template(bad);raise exception 'Acepta duración manual ficticia';exception when raise_exception then
  if SQLERRM='Acepta duración manual ficticia' then raise;end if;end;
 if public.valid_running_step_v2('{"schema_version":3,"kind":"run","completion":"manual"}',null,null)
  or public.valid_running_step_v2('{"schema_version":2,"kind":"desconocido","completion":"manual"}',null,null)
  or public.valid_running_step_v2('{"schema_version":2,"kind":"rest","completion":"distance"}',null,400)
  then raise exception 'Validador admite metadatos incompatibles';end if;
 -- Los dos portales conservan sus entradas y autoridades de autoría existentes.
 perform set_config('request.jwt.claim.sub',coach::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',coach,'role','authenticated','aal','aal2')::text,true);
 coach_template:=trainer_private.save_trainer_workout(gen_random_uuid(),recipe);
 admin_template:=public.create_admin_workout_draft(null,recipe);
 perform trainer_private.assign_trainer_workout(schedule,relation,coach_template,current_date+1,null);
 snapshot:=device_private.training_source(pupil,pupil,schedule)->'snapshot';
 if snapshot->'blocks'->0->'items'->0->'sets'->0->'running_step'->>'completion'<>'manual'
  then raise exception 'La fuente de envío pierde la receta';end if;
 origin:='{"baseId":null,"programId":null,"parentWorkId":null,"phaseId":null,"positionId":null,"duplicate":false}';
 raw:=jsonb_build_object('schema',1,'context','{}'::jsonb,'editor',jsonb_build_object('schema',1,'running',true,'nameText','Incompleta',
  'descriptionText','','durationText','','blocks','[]'::jsonb,'segments',
  '[{"stepKind":"warmup","manual":true,"countText":"1","targetText":"pendiente","paceText":"","paceMaxText":"","recoveryTimeText":"","byDistance":false,"recoveryByDistance":false,"recoveryType":null}]'::jsonb));
 perform trainer_private.validate_session_work_state(raw);
 perform public.save_trainer_session_work(coach,gen_random_uuid(),0,origin,raw);
 perform public.save_admin_session_work(coach,gen_random_uuid(),0,origin,jsonb_set(raw,'{context}','{"showInLibrary":false}'));
 recipe:=jsonb_set(recipe,'{blocks,0,exercises,0,sets}','[{"target_duration_seconds":600,"rest_after_seconds":0}]');
 begin perform trainer_private.save_trainer_workout(gen_random_uuid(),recipe,coach_template);
  raise exception 'El editor antiguo elimina V2';exception when invalid_parameter_value then null;end;
 coach_template:=trainer_private.save_trainer_workout(gen_random_uuid(),recipe);
 schedule:=gen_random_uuid();
 perform trainer_private.assign_trainer_workout(schedule,relation,coach_template,current_date+2,null);
 snapshot:=device_private.training_source(pupil,pupil,schedule)->'snapshot';
 if snapshot->'blocks'->0->'items'->0->'sets'->0 ? 'running_step' then raise exception 'Cambia el hash de una receta antigua';end if;
 -- Carrera V1 permanece válida, sin convertir automáticamente su historial.
 if not public.valid_running_step_v2(null,600,null) then raise exception 'Invalida carrera V1';end if;
end $$;
rollback;
