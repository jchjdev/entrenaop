-- Ejercicio privado → sesión/programa → alumno → resultado e historial.
begin;
set local statement_timeout='45s';
do $$
declare trainer uuid:=gen_random_uuid(); pupil uuid:=gen_random_uuid(); other uuid:=gen_random_uuid();
 rel uuid:=gen_random_uuid(); op uuid:=gen_random_uuid(); image_op uuid:=gen_random_uuid();
 exercise uuid; revised uuid; hidden uuid; t uuid; program uuid; scheduled uuid; execution uuid;
 path text; draft jsonb; payload jsonb; changed integer; personal uuid; ownblock uuid;
begin
 insert into auth.users(id,email) values(trainer,trainer||'@trainer-exercises.invalid'),
  (pupil,pupil||'@trainer-exercises.invalid'),(other,other||'@trainer-exercises.invalid');
 insert into auth.mfa_factors(id,user_id,factor_type,status,created_at,updated_at)
  values(gen_random_uuid(),trainer,'totp','verified',now(),now()),(gen_random_uuid(),other,'totp','verified',now(),now());
 insert into public.admin_permissions(user_id) values(trainer),(other);
 insert into public.trainer_access(trainer_id,enabled,client_limit,last_reason) values(trainer,true,1,'Ejercicios de ensayo'),(other,true,1,'Aislamiento');
 insert into public.trainer_client_relations(id,trainer_id,client_id,accepted_at) values(rel,trainer,pupil,now());
 perform set_config('request.jwt.claim.sub',trainer::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',trainer,'role','authenticated','aal','aal2')::text,true);
 set local role authenticated;
 path:=public.reserve_trainer_exercise_image(image_op);
 if path<>public.reserve_trainer_exercise_image(image_op) or (public.get_trainer_exercise_usage()->>'image_used')::int<>1 then raise exception 'Reserva no idempotente'; end if;
 insert into storage.objects(bucket_id,name) values('trainer-exercise-images',path);
 draft:=jsonb_build_object('name','Dominada privada','description','Controla la bajada','video_url','https://example.invalid/tecnica',
  'muscle_groups',jsonb_build_array('espalda'),'equipment',jsonb_build_array('barra'),'difficulty','intermedio','exercise_type','repeticiones','image_path',path);
 exercise:=public.save_trainer_exercise(op,draft);
 if public.save_trainer_exercise(op,draft)<>exercise or (public.get_trainer_exercise_usage()->>'exercise_used')::int<>1 then raise exception 'Duplica ejercicio al reintentar'; end if;
 begin perform public.save_trainer_exercise(op,jsonb_set(draft,'{name}','"Otro"')); raise exception 'Cambia reintento'; exception when invalid_parameter_value then null; end;
 update public.exercises set name='Modificado directamente' where id=exercise;
 get diagnostics changed=row_count; if changed<>0 then raise exception 'ADMIN cambia receta privada directamente'; end if;
 begin
  delete from storage.objects where bucket_id='trainer-exercise-images' and name=path;
  get diagnostics changed=row_count; if changed<>0 then raise exception 'Borra imagen histórica'; end if;
 exception when insufficient_privilege then null; end;
 payload:=jsonb_build_object('name','Sesión con ejercicio propio','blocks',jsonb_build_array(jsonb_build_object(
  'name','Fuerza','format','straight_sets','rounds',1,'rest_after_seconds',0,'exercises',jsonb_build_array(jsonb_build_object(
  'exercise_id',exercise,'sets',jsonb_build_array(jsonb_build_object('target_reps',8,'rest_after_seconds',60)))))));
 begin perform public.create_personal_workout_template(payload); raise exception 'Copia ejercicio profesional al catálogo personal';
 exception when others then if sqlerrm='Copia ejercicio profesional al catálogo personal' then raise; end if; end;
 t:=public.save_trainer_workout(gen_random_uuid(),payload);
 program:=public.save_trainer_program(gen_random_uuid(),jsonb_build_object('name','Programa de ejercicio propio','mode','phased',
  'phases',jsonb_build_array(jsonb_build_object('name','Base','duration_weeks',1,'instructions','Controla el esfuerzo','sessions',jsonb_build_array(jsonb_build_object('template_id',t,'name','Día A'))))));
 perform public.assign_trainer_program(gen_random_uuid(),rel,program,jsonb_build_array(jsonb_build_object('phase',0,'session',0,'date',current_date)),null);
 scheduled:=(public.list_trainer_assignments(pupil)->0->>'id')::uuid;
 revised:=public.save_trainer_exercise(gen_random_uuid(),jsonb_set(draft,'{description}','"Instrucción nueva"'),exercise);
 begin perform public.save_trainer_exercise(gen_random_uuid(),draft||jsonb_build_object('extra',repeat('x',10000)));
  raise exception 'Conserva payload sin límite'; exception when check_violation then null; end;
 hidden:=public.save_trainer_exercise(gen_random_uuid(),jsonb_set(draft,'{name}','"Nunca pautado"'));
 if jsonb_array_length(public.list_trainer_exercises())<>3 then raise exception 'No conserva versiones'; end if;
 -- La misma cuenta conserva las ocho plazas personales aunque sea preparador.
 for i in 1..8 loop perform public.create_personal_exercise('Personal '||i,null,null,array['espalda'],'{}','inicial','repeticiones'); end loop;
 begin perform public.create_personal_exercise('Personal extra',null,null,array['espalda'],'{}','inicial','repeticiones');
  raise exception 'Cuota personal ampliada'; exception when raise_exception then if sqlerrm='Cuota personal ampliada' then raise; end if; end;
 reset role;
 update trainer_private.exercise_limits set exercise_limit=3,image_limit=1 where trainer_id=trainer;
 set local role authenticated;
 begin perform public.save_trainer_exercise(gen_random_uuid(),draft); raise exception 'Sin límite de ejercicios'; exception when invalid_parameter_value then null; end;
 begin perform public.reserve_trainer_exercise_image(gen_random_uuid()); raise exception 'Sin límite de imágenes'; exception when invalid_parameter_value then null; end;
 if (public.get_trainer_exercise_usage()->>'exercise_used')::int<>3 or (public.get_trainer_exercise_usage()->>'image_used')::int<>1 then raise exception 'Cuenta fallos de cuota'; end if;

 perform set_config('request.jwt.claim.sub',other::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',other,'role','authenticated','aal','aal2')::text,true);
 if exists(select 1 from public.exercises where id in(exercise,revised,hidden)) or exists(select 1 from storage.objects where name=path and bucket_id='trainer-exercise-images') then raise exception 'ADMIN ajeno lee contenido privado'; end if;
 if public.list_trainer_exercises()<>'[]'::jsonb then raise exception 'Catálogo cruza cuentas'; end if;
 begin insert into storage.objects(bucket_id,name) values('trainer-exercise-images',other::text||'/sin-reserva.jpg');
  raise exception 'Sube imagen sin reserva'; exception when insufficient_privilege then null; end;
 begin perform public.save_trainer_exercise(gen_random_uuid(),draft); raise exception 'Usa imagen de otro preparador'; exception when invalid_parameter_value then null; end;
 begin perform public.save_trainer_workout(gen_random_uuid(),payload); raise exception 'Usa ejercicio ajeno'; exception when others then if sqlerrm='Usa ejercicio ajeno' then raise; end if; end;
 begin perform public.save_trainer_exercise(gen_random_uuid(),draft,exercise); raise exception 'Revisa ejercicio ajeno'; exception when serialization_failure then null; end;
 -- El trigger impide inyectar un ID privado mediante escrituras heredadas.
 select id into personal from public.exercises where is_public and id<>'20000000-0000-4000-8000-000000000004' limit 1;
 personal:=public.create_personal_workout_template(jsonb_set(payload,'{blocks,0,exercises,0,exercise_id}',to_jsonb(personal)));
 select id into ownblock from public.workout_blocks where template_id=personal limit 1;
 begin update public.workout_items set exercise_id=exercise where block_id=ownblock; raise exception 'Inyecta ID privado'; exception when insufficient_privilege then null; end;

 perform set_config('request.jwt.claim.sub',pupil::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',pupil,'role','authenticated','aal','aal1')::text,true);
 if not exists(select 1 from public.exercises where id=exercise) or exists(select 1 from public.exercises where id in(revised,hidden)) then raise exception 'Alumno no ve solo lo asignado'; end if;
 if not exists(select 1 from storage.objects where bucket_id='trainer-exercise-images' and name=path) then raise exception 'Alumno no accede a la foto pautada'; end if;
 execution:=public.start_scheduled_workout(scheduled);
 if not exists(select 1 from public.workout_execution_sets where execution_id=execution and exercise_id=exercise and exercise_description='Controla la bajada') then raise exception 'Revisión altera receta recibida'; end if;
 perform public.complete_workout_set((select id from public.workout_execution_sets where execution_id=execution limit 1),p_actual_reps=>8);
 perform public.finish_workout_execution(execution,6,'Ensayo privado',null,null,'manual');
 perform public.end_trainer_relation(rel);
 if not exists(select 1 from public.exercises where id=exercise) then raise exception 'Baja pierde técnica histórica'; end if;
 perform set_config('request.jwt.claim.sub',trainer::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',trainer,'role','authenticated','aal','aal1')::text,true);
 if exists(select 1 from public.exercises where id=exercise) then raise exception 'Preparador lee sin MFA'; end if;
 if exists(select 1 from storage.objects where bucket_id='trainer-exercise-images' and name=path) then raise exception 'Firma foto profesional sin MFA'; end if;
 begin perform public.list_trainer_exercises(); raise exception 'Lista sin MFA'; exception when insufficient_privilege then null; end;
 begin perform public.save_trainer_exercise(gen_random_uuid(),draft); raise exception 'Crea sin MFA'; exception when insufficient_privilege then null; end;
 reset role;
end $$;
select 'trainer_private_exercises: OK' as result;
rollback;
