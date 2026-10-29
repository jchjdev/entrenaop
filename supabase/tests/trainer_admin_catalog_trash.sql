-- Ensayo sintético; no elimina contenido real ni conserva datos.
begin;
set local statement_timeout='90s';
set local lock_timeout='5s';

do $$
declare coach uuid:=gen_random_uuid();other uuid:=gen_random_uuid();pupil uuid:=gen_random_uuid();rel uuid:=gen_random_uuid();
 exercise uuid;exercise2 uuid;official uuid;session uuid;session2 uuid;program uuid;unused_program uuid;scheduled uuid;execution uuid;
 op uuid:=gen_random_uuid();op2 uuid:=gen_random_uuid();purge_op uuid:=gen_random_uuid();
 trash_op uuid:=gen_random_uuid();restore_op uuid:=gen_random_uuid();draft_id uuid:=gen_random_uuid();
 draft jsonb;recipe jsonb;program_body jsonb;raw jsonb;answer jsonb;again jsonb;stamp timestamptz;stamp2 timestamptz;page jsonb;
 count_before integer;refs record;pending jsonb;session_work uuid:=gen_random_uuid();program_work uuid:=gen_random_uuid();origin jsonb;content jsonb;
 image_path text;image_count integer;
begin
 insert into auth.users(id,email) values(coach,coach||'@catalog-trash.invalid'),(other,other||'@catalog-trash.invalid'),(pupil,pupil||'@catalog-trash.invalid');
 insert into auth.mfa_factors(id,user_id,factor_type,status,created_at,updated_at)
  values(gen_random_uuid(),coach,'totp','verified',now(),now()),(gen_random_uuid(),other,'totp','verified',now(),now());
 insert into public.admin_permissions(user_id) values(coach);
 insert into public.trainer_access(trainer_id,enabled,client_limit,last_reason) values(coach,true,1,'Ensayo papelera'),(other,true,1,'Aislamiento papelera');
 insert into public.trainer_client_relations(id,trainer_id,client_id,accepted_at) values(rel,coach,pupil,now());
 perform set_config('request.jwt.claim.sub',coach::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',coach,'role','authenticated','aal','aal2')::text,true);
 set local role authenticated;
 image_path:=public.reserve_trainer_exercise_image(gen_random_uuid());
 insert into storage.objects(bucket_id,name) values('trainer-exercise-images',image_path);
 image_count:=(public.get_trainer_exercise_usage()->>'image_used')::integer;
 draft:=jsonb_build_object('name','Ejercicio temporal','description','Conservación de versiones','video_url',null,
  'muscle_groups',jsonb_build_array('piernas'),'equipment',jsonb_build_array('ninguno'),'difficulty','inicial','exercise_type','repeticiones','image_path',image_path);
 exercise:=public.save_trainer_exercise(op,draft);
 exercise2:=public.save_trainer_exercise(op2,draft||jsonb_build_object('name','Ejercicio revisado'),exercise);
 count_before:=(public.get_trainer_exercise_usage()->>'exercise_used')::integer;
 answer:=public.trash_trainer_catalog_item(trash_op,'exercise',exercise2);
 stamp:=(answer->>'trashed_at')::timestamptz;
 if public.trash_trainer_catalog_item(trash_op,'exercise',exercise2)<>answer then raise exception 'El reintento de papelera cambió'; end if;
 if exists(select 1 from jsonb_array_elements(public.list_trainer_exercises()) x where (x->>'id')::uuid in (exercise,exercise2)) then raise exception 'Una versión retirada sigue seleccionable'; end if;
 if not exists(select 1 from public.exercises where id=exercise) then raise exception 'Retirar destruyó lectura retenida'; end if;
 if public.save_trainer_exercise(op,draft)<>exercise then raise exception 'El reintento de autoría existente falla al retirar'; end if;
 begin perform public.restore_trainer_catalog_item(gen_random_uuid(),'exercise',exercise2,stamp-interval '1 second'); raise exception 'Acepta sello obsoleto'; exception when serialization_failure then null; end;
 answer:=public.restore_trainer_catalog_item(restore_op,'exercise',exercise2,stamp);
 if public.restore_trainer_catalog_item(restore_op,'exercise',exercise2,stamp)<>answer then raise exception 'Restaurar no es idempotente'; end if;
 if not exists(select 1 from jsonb_array_elements(public.list_trainer_exercises()) x where (x->>'id')::uuid=exercise2 and (x->>'current')::boolean) then raise exception 'No restaura versión vigente'; end if;
 answer:=public.trash_trainer_catalog_item(gen_random_uuid(),'exercise',exercise2);stamp2:=(answer->>'trashed_at')::timestamptz;
 begin perform public.purge_trainer_catalog_item(gen_random_uuid(),'exercise',exercise2,stamp);raise exception 'Purga otro lote';exception when serialization_failure then null;end;
 answer:=public.purge_trainer_catalog_item(purge_op,'exercise',exercise2,stamp2);
 if public.purge_trainer_catalog_item(purge_op,'exercise',exercise2,stamp2)<>answer then raise exception 'Purga no conserva recibo';end if;
 if (public.get_trainer_exercise_usage()->>'exercise_used')::integer<>count_before-2 then raise exception 'Cuota no libera todas las versiones purgadas';end if;
 if (public.get_trainer_exercise_usage()->>'image_used')::integer<>image_count then raise exception 'Purga libera reservas de medios sin borrar el objeto remoto';end if;
 reset role;
 if not exists(select 1 from storage.objects where bucket_id='trainer-exercise-images' and name=image_path)
  or not exists(select 1 from trainer_private.exercise_images where path=image_path) then raise exception 'Purga borra imagen o reserva';end if;
 set local role authenticated;
 begin perform public.save_trainer_exercise(op,draft);raise exception 'Resucita autoría purgada';exception when raise_exception then if sqlerrm='Resucita autoría purgada' then raise;end if;end;

 -- Una familia de sesiones sin usos se puede purgar; los recibos no se pierden.
 official:=public.create_admin_exercise('Oficial de ensayo de papelera',p_muscle_groups=>array['piernas'],p_equipment=>array['ninguno']);
 begin perform public.trash_admin_exercise(gen_random_uuid(),'20000000-0000-4000-8000-000000000004');raise exception 'Retira ejercicio técnico de carrera';exception when invalid_parameter_value then null;end;
 begin perform public.purge_admin_exercise(gen_random_uuid(),'20000000-0000-4000-8000-000000000004',clock_timestamp());raise exception 'Purga ejercicio técnico de carrera';exception when invalid_parameter_value then null;end;
 begin perform trainer_private.change_catalog_trash('admin',null,gen_random_uuid(),'exercise',official,null);raise exception 'Acepta acción NULL';exception when invalid_parameter_value then null;end;
 recipe:=jsonb_build_object('name','Sesión temporal','blocks',jsonb_build_array(jsonb_build_object('name','Fuerza','format','straight_sets','rounds',1,'rest_after_seconds',0,
  'exercises',jsonb_build_array(jsonb_build_object('exercise_id',official,'sets',jsonb_build_array(jsonb_build_object('target_reps',8,'rest_after_seconds',60)))))));
 op:=gen_random_uuid();session:=public.save_trainer_workout(op,recipe);
 session2:=public.save_trainer_workout(gen_random_uuid(),recipe||jsonb_build_object('name','Sesión revisada'),session);
 answer:=public.trash_trainer_catalog_item(gen_random_uuid(),'session',session2);stamp:=(answer->>'trashed_at')::timestamptz;
 if exists(select 1 from jsonb_array_elements(public.list_trainer_workouts()) x where (x->>'id')::uuid in (session,session2)) then raise exception 'Sesión retirada seleccionable';end if;
 perform public.purge_trainer_catalog_item(gen_random_uuid(),'session',session2,stamp);
 begin perform public.save_trainer_workout(op,recipe);raise exception 'Resucita sesión purgada';exception when raise_exception then if sqlerrm='Resucita sesión purgada' then raise;end if;end;

 -- Programa usado bloquea purga, pero su pauta e historial siguen funcionando.
 session:=public.save_trainer_workout(gen_random_uuid(),recipe);
 program_body:=jsonb_build_object('name','Programa temporal','mode','phased','phases',jsonb_build_array(jsonb_build_object('name','Base','duration_weeks',1,
  'instructions','Ensayo','sessions',jsonb_build_array(jsonb_build_object('template_id',session,'name','Día A')))));
 op:=gen_random_uuid();unused_program:=public.save_trainer_program(op,program_body);
 answer:=public.trash_trainer_catalog_item(gen_random_uuid(),'program',unused_program);stamp:=(answer->>'trashed_at')::timestamptz;
 perform public.purge_trainer_catalog_item(gen_random_uuid(),'program',unused_program,stamp);
 begin perform public.save_trainer_program(op,program_body);raise exception 'Resucita programa purgado';exception when raise_exception then if sqlerrm='Resucita programa purgado' then raise;end if;end;
 program:=public.save_trainer_program(gen_random_uuid(),program_body);
 perform public.assign_trainer_program(gen_random_uuid(),rel,program,jsonb_build_array(jsonb_build_object('phase',0,'session',0,'date',current_date)),null);
 scheduled:=(public.list_trainer_assignments(pupil)->0->>'id')::uuid;
 answer:=public.trash_trainer_catalog_item(gen_random_uuid(),'session',session);stamp:=(answer->>'trashed_at')::timestamptz;
 if (public.list_trainer_catalog_trash('session')->0->>'delete_block_reason') is null then raise exception 'No informa referencias';end if;
 begin perform public.purge_trainer_catalog_item(gen_random_uuid(),'session',session,stamp);raise exception 'Elimina sesión usada';exception when raise_exception then if sqlerrm='Elimina sesión usada' then raise;end if;end;
 begin perform public.assign_trainer_workout(gen_random_uuid(),rel,session,current_date,null);raise exception 'Asigna sesión retirada';exception when invalid_parameter_value then null;end;
 answer:=public.trash_trainer_catalog_item(gen_random_uuid(),'program',program);stamp:=(answer->>'trashed_at')::timestamptz;
 begin perform public.purge_trainer_catalog_item(gen_random_uuid(),'program',program,stamp);raise exception 'Elimina programa entregado';exception when raise_exception then if sqlerrm='Elimina programa entregado' then raise;end if;end;
 if public.get_trainer_program(program)->>'id' is null then raise exception 'No permite lectura retenida de programa';end if;

 -- MFA, aislamiento entre entrenadores y ADMIN, permisos SQL de las tablas privadas.
 perform set_config('request.jwt.claim.sub',other::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',other,'role','authenticated','aal','aal2')::text,true);
 if public.list_trainer_catalog_trash()<>'[]'::jsonb then raise exception 'Filtra cartera ajena';end if;
 begin perform public.trash_trainer_catalog_item(gen_random_uuid(),'session',session);raise exception 'Retira recurso ajeno';exception when insufficient_privilege then null;end;
 begin perform public.trash_admin_exercise(gen_random_uuid(),official);raise exception 'Entrenador administra oficiales';exception when insufficient_privilege then null;end;
 begin perform 1 from trainer_private.catalog_trash;raise exception 'Lee tabla privada';exception when insufficient_privilege then null;end;
 perform set_config('request.jwt.claim.sub',coach::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',coach,'role','authenticated','aal','aal1')::text,true);
 begin perform public.list_trainer_catalog_trash();raise exception 'Lee sin MFA';exception when insufficient_privilege then null;end;
 begin perform public.trash_admin_exercise(gen_random_uuid(),official);raise exception 'ADMIN escribe sin MFA';exception when insufficient_privilege then null;end;
 perform set_config('request.jwt.claims',jsonb_build_object('sub',coach,'role','authenticated','aal','aal2')::text,true);

 -- Retirada oficial conserva ejercicio dentro de la pauta del alumno.
 answer:=public.trash_admin_exercise(gen_random_uuid(),official);stamp:=(answer->>'trashed_at')::timestamptz;
 if public.list_admin_exercise_trash()->0->>'delete_block_reason' is null then raise exception 'No bloquea oficial usado';end if;
 begin perform public.purge_admin_exercise(gen_random_uuid(),official,stamp);raise exception 'Borra oficial utilizado';exception when raise_exception then if sqlerrm='Borra oficial utilizado' then raise;end if;end;
 perform set_config('request.jwt.claim.sub',other::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',other,'role','authenticated','aal','aal2')::text,true);
 if exists(select 1 from public.exercises where id=official) then raise exception 'Un tercero sin receta ve el ejercicio oficial retirado';end if;
 perform set_config('request.jwt.claim.sub',pupil::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',pupil,'role','authenticated','aal','aal1')::text,true);
 if not exists(select 1 from public.exercises where id=official) then raise exception 'Retirada oficial rompe lectura asignada';end if;
 execution:=public.start_scheduled_workout(scheduled);
 if execution is null or not exists(select 1 from public.workout_execution_sets where execution_id=execution and exercise_id=official) then raise exception 'Retirar receta rompe ejecución pendiente';end if;
 perform set_config('request.jwt.claim.sub',coach::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',coach,'role','authenticated','aal','aal2')::text,true);
 perform public.restore_admin_exercise(gen_random_uuid(),official,stamp);
 if (select is_public from public.exercises where id=official) then raise exception 'Restauración republica oficial automáticamente';end if;
 perform public.update_admin_exercise(official,'Oficial restablecido de ensayo',p_muscle_groups=>array['piernas'],p_equipment=>array['ninguno']);

 -- Creadores reales: sus recibos cerrados no hacen imposible la purga.
 origin:='{"baseId":null,"programId":null,"parentWorkId":null,"phaseId":null,"positionId":null,"duplicate":false}';
 raw:=jsonb_build_object('schema',1,'context','{}'::jsonb,'editor',jsonb_build_object('schema',1,'running',false,
  'nameText','Sesión temporal','descriptionText','','durationText','', 'segments','[]'::jsonb,
  'blocks',jsonb_build_array(jsonb_build_object('nameText','Fuerza','format','straightSets','roundsText','1','restText','0','capText','',
   'exercises',jsonb_build_array(jsonb_build_object('exerciseId',official,'targetType','repetitions','automaticSlot',false,'customSets',false,
    'countText','1','targetText','8','restText','60','loadText','','rirText','','amrapRepetitionsText','','amrapRirText','','variations','[]'::jsonb))))), 'intent',recipe);
 perform public.save_trainer_session_work(coach,session_work,0,origin,raw);
 session2:=public.finalize_trainer_session_work(coach,session_work,1);
 answer:=public.trash_trainer_catalog_item(gen_random_uuid(),'session',session2);stamp:=(answer->>'trashed_at')::timestamptz;
 perform public.purge_trainer_catalog_item(gen_random_uuid(),'session',session2,stamp);
 begin perform public.finalize_trainer_session_work(coach,session_work,1);raise exception 'Recibo de creador devuelve sesión borrada';exception when raise_exception then if sqlerrm='Recibo de creador devuelve sesión borrada' then raise;end if;end;
 begin perform public.reopen_trainer_session_work(coach,session_work,1);raise exception 'Reconciliación de sesión resucita receta borrada';exception when raise_exception then if sqlerrm='Reconciliación de sesión resucita receta borrada' then raise;end if;end;
 session2:=public.save_trainer_workout(gen_random_uuid(),recipe);
 raw:=jsonb_build_object('schema',1,'name','Programa de creador','description','','audience','','equipment','','mode','guide','categories','[]'::jsonb,'primary',null,
  'phases',jsonb_build_array(jsonb_build_object('name','Entrenamiento','weeks','','instructions','','pending','[]'::jsonb,'replacements','{}'::jsonb,'replacementPositions','{}'::jsonb,
   'sessions',jsonb_build_array(jsonb_build_object('id',session2,'name','Fuerza','positionId',gen_random_uuid(),'warmup',null,'adjustable',false,'minimum','','maximum','')))));
 content:=jsonb_build_object('name','Programa de creador','description','','audience','','equipment','','mode','guide',
  'phases',jsonb_build_array(jsonb_build_object('name','Entrenamiento','duration_weeks',null,'instructions','','sessions',jsonb_build_array(jsonb_build_object(
   'template_id',session2,'name','Fuerza','warmup_id',null,'rest',jsonb_build_object('min_seconds',null,'max_seconds',null))))));
 perform public.save_trainer_program_work(coach,program_work,0,raw);
 unused_program:=public.finalize_trainer_program_work(coach,program_work,1,content);
 answer:=public.trash_trainer_catalog_item(gen_random_uuid(),'program',unused_program);stamp:=(answer->>'trashed_at')::timestamptz;
 perform public.purge_trainer_catalog_item(gen_random_uuid(),'program',unused_program,stamp);
 begin perform public.finalize_trainer_program_work(coach,program_work,1,content);raise exception 'Recibo de creador devuelve programa borrado';exception when raise_exception then if sqlerrm='Recibo de creador devuelve programa borrado' then raise;end if;end;

 -- JSON abierto impide borrar una sesión aunque no haya FK.
 session2:=public.save_trainer_workout(gen_random_uuid(),recipe);
 raw:=jsonb_set(jsonb_set(raw,'{name}','"Trabajo incompleto"'),'{phases,0,sessions,0,id}',to_jsonb(session2));
 perform public.save_trainer_program_work(coach,draft_id,0,raw);
 answer:=public.trash_trainer_catalog_item(gen_random_uuid(),'session',session2);stamp:=(answer->>'trashed_at')::timestamptz;
 begin perform public.purge_trainer_catalog_item(gen_random_uuid(),'session',session2,stamp);raise exception 'Ignora referencia JSON';exception when raise_exception then if sqlerrm='Ignora referencia JSON' then raise;end if;end;
 perform public.discard_trainer_program_work(coach,draft_id,1);
 perform public.purge_trainer_catalog_item(gen_random_uuid(),'session',session2,stamp);

 -- Paginación por sello e ID, sin saltos o duplicados al pedir una entrada.
 official:=public.create_admin_exercise('Oficial prescindible A',p_muscle_groups=>array['piernas'],p_equipment=>array['ninguno']);
 perform public.trash_admin_exercise(gen_random_uuid(),official);
 exercise:=public.create_admin_exercise('Oficial prescindible B',p_muscle_groups=>array['piernas'],p_equipment=>array['ninguno']);
 perform public.trash_admin_exercise(gen_random_uuid(),exercise);
 page:=public.list_admin_exercise_trash(p_limit=>1);
 if jsonb_array_length(page)<>1 then raise exception 'Ignora tamaño de página';end if;
 again:=public.list_admin_exercise_trash((page->0->>'trashed_at')::timestamptz,(page->0->>'id')::uuid,1);
 if jsonb_array_length(again)<>1 or again->0->>'id'=page->0->>'id' then raise exception 'Cursor duplica entrada';end if;
 answer:=public.purge_admin_exercise(gen_random_uuid(),(page->0->>'id')::uuid,(page->0->>'trashed_at')::timestamptz);
 if answer->>'status'<>'purged' then raise exception 'No purga oficial sin usos';end if;
 reset role;
 raise notice 'TRN-045 OK: familias, recibos, cuotas, aislamiento, MFA, historial, JSON, ADMIN y cursores';
end $$;
do $$ begin
 if has_function_privilege('anon','public.list_trainer_catalog_trash(text,timestamptz,uuid,integer)','execute')
  or has_function_privilege('anon','public.purge_admin_exercise(uuid,uuid,timestamptz)','execute')
  or has_function_privilege('authenticated','trainer_private.catalog_delete_block_reason(text,uuid[])','execute')
  or has_table_privilege('authenticated','trainer_private.catalog_operations','select') then
  raise exception 'El contrato expone funciones o recibos privados';
 end if;
end $$;
rollback;
