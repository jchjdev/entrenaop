-- Edición, revisión y conversación reales. Todos los datos y DDL del ensayo
-- se ejecutan dentro de una transacción que termina siempre con ROLLBACK.
begin;
set local statement_timeout='60s';
do $$
declare
 trainer uuid:=gen_random_uuid(); pupil uuid:=gen_random_uuid(); second_pupil uuid:=gen_random_uuid(); outsider uuid:=gen_random_uuid();
 relation uuid:=gen_random_uuid(); second_relation uuid:=gen_random_uuid();
 exercise uuid; template uuid; variant uuid; personal uuid; personal_schedule uuid;
 assignment uuid:=gen_random_uuid(); second_assignment uuid:=gen_random_uuid();
 move_operation uuid:=gen_random_uuid(); adapt_operation uuid:=gen_random_uuid(); review_operation uuid:=gen_random_uuid();
 message uuid:=gen_random_uuid(); pupil_message uuid:=gen_random_uuid();
 recipe jsonb; changed_recipe jsonb; response jsonb; replay jsonb; page jsonb; page2 jsonb; preview jsonb;
 execution uuid; result_id uuid; seen bigint; after_start bigint; after_set bigint; cursor_at timestamptz; cursor_id uuid;
 move_fingerprint text; adapt_fingerprint text;
begin
 insert into auth.users(id,email) values
  (trainer,trainer||'@trainer-operations.invalid'),(pupil,pupil||'@trainer-operations.invalid'),
  (second_pupil,second_pupil||'@trainer-operations.invalid'),(outsider,outsider||'@trainer-operations.invalid');
 insert into auth.mfa_factors(id,user_id,factor_type,status,created_at,updated_at) values
  (gen_random_uuid(),trainer,'totp','verified',now(),now()),(gen_random_uuid(),outsider,'totp','verified',now(),now());
 insert into public.admin_permissions(user_id) values(outsider);
 insert into public.trainer_access(trainer_id,enabled,client_limit,last_reason) values(trainer,true,2,'Fixture operacional');
 insert into public.trainer_client_relations(id,trainer_id,client_id,accepted_at) values
  (relation,trainer,pupil,now()),(second_relation,trainer,second_pupil,now());
 select id into exercise from public.exercises where is_public and id<>'20000000-0000-4000-8000-000000000004' order by id limit 1;
 if exercise is null then raise exception 'Se requiere catálogo público.'; end if;
 recipe:=jsonb_build_object('name','Biblioteca del preparador','blocks',jsonb_build_array(jsonb_build_object(
  'name','Fuerza','format','straight_sets','rounds',1,'rest_after_seconds',0,
  'exercises',jsonb_build_array(jsonb_build_object('exercise_id',exercise,'sets',jsonb_build_array(jsonb_build_object('target_reps',10,'rest_after_seconds',60)))))));
 changed_recipe:=jsonb_set(recipe,'{name}','"Adaptación para un alumno"');
 perform set_config('request.jwt.claim.sub',trainer::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',trainer,'role','authenticated','aal','aal2')::text,true);
 set local role authenticated;
 template:=public.save_trainer_workout(gen_random_uuid(),recipe);
 perform public.assign_trainer_workout(assignment,relation,template,current_date+1,'Nota original');
 perform public.assign_trainer_workout(second_assignment,second_relation,template,current_date+1,null);
 if (public.get_trainer_conversation(relation)->>'can_send')::boolean is distinct from true then
  raise exception 'Conversación activa no permite preparar envío'; end if;

 move_fingerprint:=public.preview_trainer_assignment_change(assignment,0,current_date+4,'Nota editada')->>'fingerprint';
 response:=public.change_trainer_assignment_reviewed(move_operation,assignment,0,current_date+4,'Nota editada',move_fingerprint);
 if (response->>'planning_revision')::bigint<>1 then raise exception 'Mover no avanza revisión'; end if;
 replay:=public.change_trainer_assignment_reviewed(move_operation,assignment,0,current_date+4,'Nota editada',move_fingerprint);
 if replay<>response then raise exception 'Reintento de movimiento no devuelve recibo original'; end if;
 begin perform public.change_trainer_assignment_reviewed(move_operation,assignment,0,current_date+5,'Nota editada',move_fingerprint);
  raise exception 'Una orden admite otro contenido'; exception when invalid_parameter_value then null; end;
 begin perform public.change_trainer_assignment_reviewed(gen_random_uuid(),assignment,0,current_date+5,'Nota editada',move_fingerprint);
  raise exception 'Una revisión obsoleta modifica la pauta'; exception when serialization_failure then null; end;
 if public.assign_trainer_workout(assignment,relation,template,current_date+1,'Nota original')<>assignment then
  raise exception 'Mover rompe el reintento original de entrega'; end if;
 begin perform public.assign_trainer_workout(assignment,relation,template,current_date+4,'Nota editada');
  raise exception 'El reintento compara datos vivos en vez del ledger'; exception when invalid_parameter_value then null; end;

 adapt_fingerprint:=public.preview_trainer_assignment_change(assignment,1,current_date+4,'Adaptada',changed_recipe)->>'fingerprint';
 response:=public.change_trainer_assignment_reviewed(adapt_operation,assignment,1,current_date+4,'Adaptada',adapt_fingerprint,changed_recipe);
 variant:=(response->>'template_id')::uuid;
 if variant=template or (response->>'planning_revision')::bigint<>2 then raise exception 'Adaptar no crea receta independiente'; end if;
 if public.change_trainer_assignment_reviewed(adapt_operation,assignment,1,current_date+4,'Adaptada',adapt_fingerprint,changed_recipe)<>response then
  raise exception 'Reintento duplica adaptación'; end if;
 if public.list_trainer_assignments(second_pupil)->0->>'template_id'<>template::text
  or not exists(select 1 from public.workout_templates where id=template and name='Biblioteca del preparador') then
  raise exception 'Adaptar modifica la biblioteca u otro alumno'; end if;
 page:=public.list_trainer_workouts();
 if jsonb_array_length(page)<>1 or page->0->>'id'<>template::text then raise exception 'Una adaptación aparece como nueva plantilla en biblioteca'; end if;
 if public.assign_trainer_workout(assignment,relation,template,current_date+1,'Nota original')<>assignment then
  raise exception 'Adaptar rompe el recibo de entrega'; end if;
 page:=public.list_trainer_assignments(pupil);
 if (page->0->>'planning_revision')::bigint<>2 or not(page->0 ? 'result_revision') then raise exception 'Listado no publica revisiones'; end if;
 page:=public.list_trainer_agenda(current_date,current_date+10);
 if not(page->0 ? 'planning_revision') then raise exception 'Agenda no publica revisión'; end if;
 response:=public.get_trainer_assignment(assignment);
 if response->>'client_id'<>pupil::text or response->>'relation_id'<>relation::text
  or response->>'template_id'<>variant::text or (response->>'planning_revision')::bigint<>2
  or not(response ? 'client_name') or response ? 'private_note' or response ? 'review' then
  raise exception 'Detalle de pauta incorrecto o revela notas internas'; end if;

 -- La previsualización devuelve presencia por fecha, nunca la receta personal.
 perform set_config('request.jwt.claim.sub',pupil::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',pupil,'role','authenticated','aal','aal1')::text,true);
 personal:=public.create_personal_workout_template(jsonb_set(recipe,'{name}','"Nombre personal secreto"'));
 personal_schedule:=public.schedule_workout(personal,current_date+3);
 if not exists(select 1 from public.workout_templates where id=variant) then raise exception 'Alumno no recibe adaptación'; end if;
 begin perform public.change_trainer_assignment_reviewed(gen_random_uuid(),assignment,2,current_date+7,null,adapt_fingerprint);
  raise exception 'Alumno modifica pauta profesional'; exception when insufficient_privilege then null; end;
 begin perform public.get_trainer_assignment(assignment); raise exception 'Alumno lee detalle profesional'; exception when insufficient_privilege then null; end;
 perform set_config('request.jwt.claim.sub',second_pupil::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',second_pupil,'role','authenticated','aal','aal1')::text,true);
 if exists(select 1 from public.workout_templates where id=variant) then raise exception 'Otro alumno lee adaptación ajena'; end if;
 perform set_config('request.jwt.claim.sub',trainer::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',trainer,'role','authenticated','aal','aal2')::text,true);
 preview:=public.preview_trainer_schedule(pupil,current_date,current_date+10);
 if jsonb_array_length(preview)<>1 or preview->0<>jsonb_build_object('date',current_date+3,'has_other_workout',true) then
  raise exception 'Previsualización revela más que presencia/fecha o incluye pauta propia'; end if;
 begin perform public.preview_trainer_schedule(pupil,current_date,current_date+367);
  raise exception 'Previsualización admite rango ilimitado'; exception when invalid_parameter_value then null; end;

 -- Deshabilitar el acceso conserva el vínculo y las lecturas propias, pero no
 -- autoriza señales nuevas de una planificación personal ajena al servicio.
 reset role;
 update public.trainer_access set enabled=false where trainer_id=trainer;
 set local role authenticated;
 begin perform public.preview_trainer_schedule(pupil,current_date,current_date+10);
  raise exception 'Acceso deshabilitado consulta presencia de agenda personal'; exception when insufficient_privilege then null; end;
 if public.get_trainer_assignment(assignment)->>'id'<>assignment::text
  or jsonb_array_length(public.list_trainer_agenda(current_date,current_date+10))<>2 then
  raise exception 'Deshabilitar acceso elimina consulta propia del servicio'; end if;
 if has_function_privilege('authenticated','trainer_private.has_professional_read_access()','EXECUTE') then
  raise exception 'Helper de lectura profesional expuesto directamente'; end if;
 reset role;
 update public.trainer_access set enabled=true,valid_until=statement_timestamp()-interval '1 second' where trainer_id=trainer;
 set local role authenticated;
 begin perform public.preview_trainer_schedule(pupil,current_date,current_date+10);
  raise exception 'Acceso caducado consulta presencia de agenda personal'; exception when insufficient_privilege then null; end;
 reset role;
 update public.trainer_access set valid_until=null where trainer_id=trainer;
 set local role authenticated;

 -- El inicio, las series y las correcciones invalidan la revisión anterior.
 perform set_config('request.jwt.claim.sub',pupil::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',pupil,'role','authenticated','aal','aal1')::text,true);
 execution:=public.start_scheduled_workout(assignment);
 select result_revision into after_start from public.trainer_assignments where scheduled_id=assignment;
 if after_start<1 then raise exception 'Inicio no avanza revisión de resultado'; end if;
 select id into result_id from public.workout_execution_sets where execution_id=execution limit 1;
 perform public.complete_workout_set(result_id,p_actual_reps=>8,p_actual_load_kg=>20);
 select result_revision into after_set from public.trainer_assignments where scheduled_id=assignment;
 if after_set<=after_start then raise exception 'Serie no avanza revisión'; end if;
 perform public.finish_workout_execution(execution,6,'Resultado real',null,null,'manual');
 perform set_config('request.jwt.claim.sub',trainer::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',trainer,'role','authenticated','aal','aal2')::text,true);
 begin perform public.change_trainer_assignment_reviewed(gen_random_uuid(),assignment,2,current_date+8,null,adapt_fingerprint);
  raise exception 'Edita una pauta iniciada'; exception when serialization_failure then null; end;
 page:=public.list_trainer_review_queue();
 if jsonb_array_length(page)<>1 or page->0->>'id'<>assignment::text then raise exception 'Resultado no llega a revisión'; end if;
 seen:=(page->0->>'result_revision')::bigint;
 if seen<=after_set then raise exception 'Finalización no avanza revisión'; end if;
 perform public.mark_trainer_assignment_reviewed(review_operation,assignment,seen,'Nota interna del preparador');
 perform public.mark_trainer_assignment_reviewed(review_operation,assignment,seen,'Nota interna del preparador');
 if jsonb_array_length(public.list_trainer_review_queue())<>0 then raise exception 'La revisión no retira el resultado de la bandeja'; end if;
 response:=public.get_trainer_assignment_result(assignment);
 if response->'review'->>'private_note'<>'Nota interna del preparador' then raise exception 'No conserva nota interna'; end if;
 begin perform public.mark_trainer_assignment_reviewed(review_operation,assignment,seen,'Otra nota');
  raise exception 'Reintento cambia revisión'; exception when invalid_parameter_value then null; end;
 perform set_config('request.jwt.claim.sub',pupil::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',pupil,'role','authenticated','aal','aal1')::text,true);
 perform public.correct_workout_set_result(result_id,'Corrección real',p_actual_reps=>9,p_actual_load_kg=>20);
 perform set_config('request.jwt.claim.sub',trainer::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',trainer,'role','authenticated','aal','aal2')::text,true);
 if jsonb_array_length(public.list_trainer_review_queue())<>1 then raise exception 'La corrección no vuelve a revisión'; end if;
 begin perform public.mark_trainer_assignment_reviewed(gen_random_uuid(),assignment,seen,null);
  raise exception 'Se revisa un resultado que cambió'; exception when serialization_failure then null; end;
 -- Reintentar una revisión vieja acredita la orden vieja, no la nueva revisión.
 perform public.mark_trainer_assignment_reviewed(review_operation,assignment,seen,'Nota interna del preparador');
 if jsonb_array_length(public.list_trainer_review_queue())<>1 then raise exception 'Reintentar da por vista una corrección no consultada'; end if;
 begin perform public.list_trainer_review_queue(now(),null);
  raise exception 'Cursor parcial en revisión'; exception when invalid_parameter_value then null; end;

 -- Participantes, MFA, notas privadas y límites globales de mensajería.
 perform public.send_trainer_message(message,relation,'  Revisa estas indicaciones  ',assignment);
 if public.send_trainer_message(message,relation,'Revisa estas indicaciones',assignment)<>message then raise exception 'Reintento duplica mensaje'; end if;
 begin perform public.send_trainer_message(message,relation,null,assignment);
  raise exception 'Reintento admite cuerpo NULL'; exception when invalid_parameter_value then null; end;
 begin perform public.send_trainer_message(gen_random_uuid(),relation,'Otro vínculo',second_assignment);
  raise exception 'Asocia mensaje a pauta ajena al vínculo'; exception when insufficient_privilege then null; end;
 begin perform public.send_trainer_message(gen_random_uuid(),relation,'   ');
  raise exception 'Permite mensaje vacío'; exception when invalid_parameter_value then null; end;
 for i in 1..99 loop
  perform public.send_trainer_message(gen_random_uuid(),case when i=99 then second_relation else relation end,'Mensaje de ensayo '||i);
 end loop;
 begin perform public.send_trainer_message(gen_random_uuid(),second_relation,'Supera límite global');
  raise exception 'El emisor evade límite cambiando de alumno'; exception when program_limit_exceeded then null; end;
 if public.send_trainer_message(message,relation,'Revisa estas indicaciones',assignment)<>message then raise exception 'Límite impide reintento original'; end if;
 page:=public.list_trainer_messages(relation);
 if jsonb_array_length(page)<>50 then raise exception 'No pagina mensajes a cincuenta'; end if;
 cursor_at:=(page->49->>'created_at')::timestamptz; cursor_id:=(page->49->>'id')::uuid;
 page2:=public.list_trainer_messages(relation,cursor_at,cursor_id);
 if jsonb_array_length(page2)<>49 then raise exception 'Paginación de mensajes pierde o repite registros'; end if;
 if exists(select 1 from jsonb_array_elements(page) x join jsonb_array_elements(page2) y on x->>'id'=y->>'id') then raise exception 'Mensaje repetido entre páginas'; end if;
 begin perform public.list_trainer_messages(relation,now(),null);
  raise exception 'Cursor parcial en mensajes'; exception when invalid_parameter_value then null; end;

 perform set_config('request.jwt.claims',jsonb_build_object('sub',trainer,'role','authenticated','aal','aal1')::text,true);
 begin perform public.list_trainer_messages(relation); raise exception 'Preparador lee mensajes sin MFA'; exception when insufficient_privilege then null; end;
 begin perform public.list_trainer_review_queue(); raise exception 'Preparador revisa sin MFA'; exception when insufficient_privilege then null; end;
 begin perform public.get_trainer_assignment(assignment); raise exception 'Preparador lee detalle sin MFA'; exception when insufficient_privilege then null; end;
 begin perform public.preview_trainer_schedule(pupil,current_date,current_date); raise exception 'Previsualiza sin MFA'; exception when insufficient_privilege then null; end;
 begin perform public.send_trainer_message(gen_random_uuid(),relation,'Sin MFA'); raise exception 'Envía sin MFA'; exception when insufficient_privilege then null; end;
 perform set_config('request.jwt.claim.sub',outsider::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',outsider,'role','authenticated','aal','aal2')::text,true);
 if jsonb_array_length(public.list_trainer_review_queue())<>0 then raise exception 'ADMIN ve revisión ajena'; end if;
 begin perform public.list_trainer_messages(relation); raise exception 'ADMIN lee conversación ajena'; exception when insufficient_privilege then null; end;
 begin perform public.get_trainer_conversation(relation); raise exception 'ADMIN lee contexto ajeno'; exception when insufficient_privilege then null; end;
 begin perform public.send_trainer_message(gen_random_uuid(),relation,'ADMIN intruso'); raise exception 'ADMIN escribe conversación ajena'; exception when insufficient_privilege then null; end;
 begin perform public.change_trainer_assignment_reviewed(gen_random_uuid(),assignment,2,current_date,null,adapt_fingerprint); raise exception 'ADMIN altera pauta ajena'; exception when insufficient_privilege then null; end;
 begin perform public.get_trainer_assignment(assignment); raise exception 'ADMIN lee detalle ajeno'; exception when insufficient_privilege then null; end;
 begin perform public.preview_trainer_schedule(pupil,current_date,current_date); raise exception 'ADMIN previsualiza agenda ajena'; exception when insufficient_privilege then null; end;
 begin perform 1 from trainer_private.messages; raise exception 'Cliente lee tabla privada'; exception when insufficient_privilege then null; end;
 begin perform 1 from trainer_private.message_sender_versions; raise exception 'Cliente modifica contador privado'; exception when insufficient_privilege then null; end;
 if has_function_privilege('authenticated','trainer_private.lock_assignment(uuid)','EXECUTE')
  or has_function_privilege('anon','public.send_trainer_message(uuid,uuid,text,uuid)','EXECUTE') then raise exception 'Permisos internos o anónimos abiertos'; end if;

 perform set_config('request.jwt.claim.sub',pupil::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',pupil,'role','authenticated','aal','aal1')::text,true);
 perform public.send_trainer_message(pupil_message,relation,'Respuesta del alumno',assignment);
 if jsonb_array_length(public.list_trainer_messages(relation))<>50 then raise exception 'Alumno no consulta conversación'; end if;
 begin perform public.list_trainer_messages(second_relation); raise exception 'Alumno lee conversación ajena'; exception when insufficient_privilege then null; end;
 begin perform public.get_trainer_assignment_result(assignment); raise exception 'Alumno recibe notas privadas del preparador'; exception when insufficient_privilege then null; end;
 perform public.end_trainer_relation(relation);
 if (public.get_trainer_conversation(relation)->>'can_send')::boolean is distinct from false then
  raise exception 'Conversación finalizada ofrece nuevos envíos'; end if;
 if jsonb_array_length(public.list_trainer_messages(relation))<>50 then raise exception 'Baja borra conversación'; end if;
 if public.send_trainer_message(pupil_message,relation,'Respuesta del alumno',assignment)<>pupil_message then raise exception 'Baja rompe recibo del mensaje previo'; end if;
 begin perform public.send_trainer_message(gen_random_uuid(),relation,'Mensaje nuevo tras baja'); raise exception 'Baja admite escritura nueva'; exception when insufficient_privilege then null; end;
 perform set_config('request.jwt.claim.sub',trainer::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',trainer,'role','authenticated','aal','aal2')::text,true);
 if jsonb_array_length(public.list_trainer_messages(relation))<>50 then raise exception 'Preparador pierde consulta tras baja'; end if;
 if jsonb_array_length(public.list_trainer_review_queue())<>1 then raise exception 'Baja pierde resultados pendientes de revisión'; end if;
 begin perform public.preview_trainer_schedule(pupil,current_date,current_date); raise exception 'Baja permite consultar agenda personal futura'; exception when insufficient_privilege then null; end;
 reset role;
end $$;
select 'trainer_operational_workflow: OK' as result;
rollback;
