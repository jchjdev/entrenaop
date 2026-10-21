-- Recorrido profesional real, ejecutor existente y derechos tras la baja.
begin;
set local statement_timeout='45s';
do $$
declare
 trainer uuid:=gen_random_uuid(); pupil uuid:=gen_random_uuid(); outsider uuid:=gen_random_uuid();
 rel uuid:=gen_random_uuid(); exercise uuid; t uuid; revised uuid; op uuid:=gen_random_uuid();
 planned uuid:=gen_random_uuid(); done uuid:=gen_random_uuid(); continuing uuid:=gen_random_uuid();
 payload jsonb; execution uuid; result_id uuid; j jsonb; affected integer;
begin
 insert into auth.users(id,email) values(trainer,trainer||'@trainer-workouts.invalid'),
  (pupil,pupil||'@trainer-workouts.invalid'),(outsider,outsider||'@trainer-workouts.invalid');
 insert into auth.mfa_factors(id,user_id,factor_type,status,created_at,updated_at)
  values(gen_random_uuid(),trainer,'totp','verified',now(),now()),(gen_random_uuid(),outsider,'totp','verified',now(),now());
 insert into public.admin_permissions(user_id) values(outsider);
 insert into public.trainer_access(trainer_id,enabled,client_limit,last_reason) values(trainer,true,1,'Fixture privado');
 insert into public.trainer_client_relations(id,trainer_id,client_id,accepted_at) values(rel,trainer,pupil,now());
 select id into exercise from public.exercises where is_public and id<>'20000000-0000-4000-8000-000000000004' order by id limit 1;
 if exercise is null then raise exception 'Se requiere catálogo público.'; end if;
 payload:=jsonb_build_object('name','Sesión privada probada','blocks',jsonb_build_array(jsonb_build_object(
  'name','Bloque de fuerza','format','straight_sets','rounds',1,'rest_after_seconds',0,
  'exercises',jsonb_build_array(jsonb_build_object('exercise_id',exercise,'sets',jsonb_build_array(jsonb_build_object('target_reps',10,'rest_after_seconds',60)))))));
 perform set_config('request.jwt.claim.sub',trainer::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',trainer,'role','authenticated','aal','aal2')::text,true);
 set local role authenticated;
 -- Ni el entrenador ni el alumno requieren Pro individual para este circuito.
 for i in 1..4 loop perform public.create_personal_workout_template(payload); end loop;
 t:=public.save_trainer_workout(op,payload);
 if public.save_trainer_workout(op,payload)<>t then raise exception 'Reintento duplica sesión'; end if;
 begin perform public.save_trainer_workout(op,jsonb_set(payload,'{name}','"Otra receta"'));
  raise exception 'Permite reutilizar operación con otro contenido'; exception when invalid_parameter_value then null; end;
 if not exists(select 1 from public.workout_templates where id=t and origin='coach' and visibility='private' and not show_in_library) then raise exception 'Identidad privada incorrecta'; end if;
 if has_function_privilege('authenticated','trainer_private.start_workout_execution(uuid)','EXECUTE') then raise exception 'Motor interno expuesto'; end if;
 update public.workout_templates set name='Escritura directa' where id=t;
 get diagnostics affected=row_count;
 if affected<>0 then raise exception 'Autoría directa abierta'; end if;
 perform public.assign_trainer_workout(planned,rel,t,current_date+1,'Pauta pendiente');
 perform public.assign_trainer_workout(planned,rel,t,current_date+1,'Pauta pendiente');
 perform public.assign_trainer_workout(done,rel,t,current_date,'Pauta ejecutada');
 perform public.assign_trainer_workout(continuing,rel,t,current_date+2,null);
 revised:=public.save_trainer_workout(gen_random_uuid(),jsonb_set(payload,'{name}','"Nueva versión privada"'),t);
 if not exists(select 1 from public.workout_templates where id=revised and version=2 and previous_version_id=t) then raise exception 'Versión no conservada'; end if;
 if jsonb_array_length(public.list_trainer_workouts())<>1 then raise exception 'Lista no muestra solo versión vigente'; end if;
 begin perform public.start_workout_execution(t); raise exception 'Entrenador inicia plantilla suelta'; exception when insufficient_privilege then null; end;

 perform set_config('request.jwt.claim.sub',outsider::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',outsider,'role','authenticated','aal','aal2')::text,true);
 if exists(select 1 from public.workout_templates where id=t) or exists(select 1 from public.scheduled_workouts where id=done) then raise exception 'ADMIN ajeno lee pauta privada'; end if;
 begin perform public.get_trainer_assignment_result(done); raise exception 'ADMIN consulta resultado ajeno'; exception when insufficient_privilege then null; end;
 begin perform public.assign_trainer_workout(gen_random_uuid(),rel,t,current_date,null); raise exception 'Asigna vínculo ajeno'; exception when insufficient_privilege then null; end;

 perform set_config('request.jwt.claim.sub',pupil::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',pupil,'role','authenticated','aal','aal1')::text,true);
 for i in 1..4 loop perform public.create_personal_workout_template(payload); end loop;
 begin
  perform public.create_personal_workout_template(payload);
  raise exception 'Vínculo amplía cuota personal';
 exception when raise_exception then
  if sqlerrm='Vínculo amplía cuota personal' then raise; end if;
 end;
 if not exists(select 1 from public.workout_templates where id=t) then raise exception 'Alumno no ve receta asignada'; end if;
 if exists(select 1 from public.workout_templates where id=revised) then raise exception 'Alumno ve biblioteca privada sin asignar'; end if;
 begin perform public.start_workout_execution(t); raise exception 'Alumno repite receta sin cita'; exception when insufficient_privilege then null; end;
 begin perform public.schedule_workout(t,current_date); raise exception 'Alumno programa receta privada'; exception when others then
  if sqlerrm='Alumno programa receta privada' then raise; end if; end;
 begin perform public.reschedule_workout(done,current_date+1); raise exception 'Alumno altera pauta'; exception when others then
  if sqlerrm='Alumno altera pauta' then raise; end if; end;
 execution:=public.start_scheduled_workout(done);
 if public.start_scheduled_workout(done)<>execution then raise exception 'Inicio no idempotente'; end if;
 select id into result_id from public.workout_execution_sets where execution_id=execution;
 perform public.complete_workout_set(result_id,p_actual_reps=>8,p_actual_load_kg=>20);
 perform public.finish_workout_execution(execution,6,'Sensaciones de ensayo',null,null,'manual');
 if not exists(select 1 from public.scheduled_workouts where id=done and status='completed') then raise exception 'No sincroniza cita'; end if;
 execution:=public.start_scheduled_workout(continuing);
 perform public.end_trainer_relation(rel);
 if exists(select 1 from public.scheduled_workouts where id=planned and status<>'cancelled') then raise exception 'Baja conserva pauta pendiente'; end if;
 if public.start_scheduled_workout(continuing)<>execution then raise exception 'Baja interrumpe ejecución existente'; end if;
 begin perform public.start_scheduled_workout(planned); raise exception 'Baja permite nuevo inicio'; exception when insufficient_privilege then null; end;
 if not exists(select 1 from public.workout_templates where id=t) then raise exception 'Pierde consulta histórica'; end if;
 begin perform public.start_workout_execution(t); raise exception 'Repite después de baja'; exception when insufficient_privilege then null; end;
 -- Descartar no resucita una pauta de una etapa terminada.
 perform public.discard_workout_execution(execution,'DESCARTAR');
 if not exists(select 1 from public.scheduled_workouts where id=continuing and status='cancelled' and execution_id is null) then raise exception 'Descarte reabre servicio terminado'; end if;

 perform set_config('request.jwt.claim.sub',trainer::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',trainer,'role','authenticated','aal','aal2')::text,true);
 j:=public.get_trainer_assignment_result(done);
 if j->>'notes'<>'Sensaciones de ensayo' or (j->>'final_rpe')::integer<>6
  or (j->'workout_execution_sets'->0->>'actual_reps')::integer<>8 then raise exception 'No conserva resultado propio tras baja'; end if;
 if (j->>'template_version')::integer<>1 or (j->'workout_execution_sets'->0->>'target_reps')::integer<>10 then raise exception 'La revisión reinterpreta la pauta antigua'; end if;
 if jsonb_array_length(public.list_trainer_assignments(pupil))<>3 then raise exception 'No conserva las pautas'; end if;
 begin perform public.assign_trainer_workout(gen_random_uuid(),rel,revised,current_date,null); raise exception 'Asigna servicio terminado'; exception when insufficient_privilege then null; end;
 perform set_config('request.jwt.claims',jsonb_build_object('sub',trainer,'role','authenticated','aal','aal1')::text,true);
 begin perform public.get_trainer_assignment_result(done); raise exception 'Consulta sin MFA'; exception when insufficient_privilege then null; end;
 begin perform public.save_trainer_workout(gen_random_uuid(),payload); raise exception 'Crea sin MFA'; exception when insufficient_privilege then null; end;
 reset role;
end $$;
select 'trainer_private_workouts: OK' as result;
rollback;
