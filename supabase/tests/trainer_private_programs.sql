-- Composición versionada, entrega atómica, agenda y aislamiento profesional.
begin;
set local statement_timeout='45s';
do $$
declare trainer uuid:=gen_random_uuid(); pupil uuid:=gen_random_uuid(); other uuid:=gen_random_uuid();
 rel uuid:=gen_random_uuid(); op uuid:=gen_random_uuid(); delivery uuid:=gen_random_uuid();
 exercise uuid; t uuid; revised uuid; program uuid; revised_program uuid; scheduled uuid; execution uuid;
 payload jsonb; content jsonb; entries jsonb; j jsonb; before_count integer;
begin
 insert into auth.users(id,email) values(trainer,trainer||'@trainer-programs.invalid'),
  (pupil,pupil||'@trainer-programs.invalid'),(other,other||'@trainer-programs.invalid');
 insert into auth.mfa_factors(id,user_id,factor_type,status,created_at,updated_at)
  values(gen_random_uuid(),trainer,'totp','verified',now(),now()),(gen_random_uuid(),other,'totp','verified',now(),now());
 insert into public.admin_permissions(user_id) values(other);
 insert into public.trainer_access(trainer_id,enabled,client_limit,last_reason) values(trainer,true,1,'Fixture programas privados');
 insert into public.trainer_client_relations(id,trainer_id,client_id,accepted_at) values(rel,trainer,pupil,now());
 select id into exercise from public.exercises where is_public and id<>'20000000-0000-4000-8000-000000000004' order by id limit 1;
 if exercise is null then raise exception 'Se requiere catálogo público.'; end if;
 payload:=jsonb_build_object('name','Sesión del programa privado','blocks',jsonb_build_array(jsonb_build_object(
  'name','Fuerza','format','straight_sets','rounds',1,'rest_after_seconds',0,
  'exercises',jsonb_build_array(jsonb_build_object('exercise_id',exercise,'sets',jsonb_build_array(jsonb_build_object('target_reps',8,'rest_after_seconds',90)))))));
 perform set_config('request.jwt.claim.sub',trainer::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',trainer,'role','authenticated','aal','aal2')::text,true);
 set local role authenticated;
 t:=public.save_trainer_workout(gen_random_uuid(),payload);
 content:=jsonb_build_object('name','Preparación privada','mode','phased','description','Base y progresión',
  'phases',jsonb_build_array(jsonb_build_object('name','Base','duration_weeks',2,'instructions','Revisar RPE antes de avanzar',
   'sessions',jsonb_build_array(jsonb_build_object('template_id',t,'name','Fuerza A')))));
 program:=public.save_trainer_program(op,content);
 if public.save_trainer_program(op,content)<>program then raise exception 'Duplica programa al reintentar'; end if;
 begin perform public.save_trainer_program(op,jsonb_set(content,'{name}','"Otro programa"'));
  raise exception 'Reutiliza operación con contenido distinto'; exception when invalid_parameter_value then null; end;
 if has_table_privilege('authenticated','trainer_private.programs','SELECT') then raise exception 'Tabla privada expuesta'; end if;
 if has_function_privilege('authenticated','trainer_private.assign_trainer_workout_version(uuid,uuid,uuid,date,text,boolean)','EXECUTE') then raise exception 'Motor de versiones expuesto'; end if;
 if jsonb_array_length(public.list_trainer_programs())<>1 then raise exception 'Biblioteca profesional incorrecta'; end if;
 revised:=public.save_trainer_workout(gen_random_uuid(),jsonb_set(payload,'{name}','"Sesión revisada"'),t);
 -- Una versión de programa sigue fijando su receta anterior. La sesión suelta
 -- retirada continúa cerrada para nuevas asignaciones directas.
 begin perform public.assign_trainer_workout(gen_random_uuid(),rel,t,current_date,null);
  raise exception 'Permite asignar versión suelta retirada'; exception when insufficient_privilege then null; end;
 entries:=jsonb_build_array(jsonb_build_object('phase',0,'session',0,'date',current_date),
  jsonb_build_object('phase',0,'session',0,'date',current_date+2));
 perform public.assign_trainer_program(delivery,rel,program,entries,'Controla el descanso');
 perform public.assign_trainer_program(delivery,rel,program,entries,'Controla el descanso');
 if jsonb_array_length(public.list_trainer_assignments(pupil))<>2 then raise exception 'Entrega no idempotente'; end if;
 j:=public.list_trainer_agenda(current_date,current_date+7);
 if jsonb_array_length(j)<>2 or j->0->>'client_id'<>pupil::text or j->0->>'template_id'<>t::text
  or j->0->>'note'<>E'Preparación privada · Base\nControla el descanso' then raise exception 'Agenda o versión incorrecta'; end if;
 scheduled:=(j->0->>'id')::uuid;
 begin perform public.assign_trainer_program(delivery,rel,program,entries,'Otras indicaciones');
  raise exception 'Reintento cambia pauta'; exception when invalid_parameter_value then null; end;
 -- Un fallo a mitad de la tanda revierte todas las pautas del nuevo envío.
 begin perform public.assign_trainer_program(gen_random_uuid(),rel,program,
  entries||jsonb_build_array(jsonb_build_object('phase',99,'session',0,'date',current_date)),null);
  raise exception 'Entrega parcial aceptada'; exception when invalid_parameter_value then null; end;
 if jsonb_array_length(public.list_trainer_assignments(pupil))<>2 then raise exception 'Entrega parcial deja citas'; end if;
 begin perform public.assign_trainer_program(gen_random_uuid(),rel,program,jsonb_build_array(entries->0,entries->0),null);
  raise exception 'Permite duplicado mismo día'; exception when invalid_parameter_value then null; end;
 revised_program:=public.save_trainer_program(gen_random_uuid(),jsonb_set(content,'{name}','"Preparación revisada"'),program);
 if (public.get_trainer_program(revised_program)->>'version')::integer<>2
  or (public.get_trainer_program(program)->>'version')::integer<>1 then raise exception 'Reinterpreta programa'; end if;
 if jsonb_array_length(public.list_trainer_programs())<>1 then raise exception 'Lista versiones retiradas'; end if;

 perform set_config('request.jwt.claim.sub',other::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',other,'role','authenticated','aal','aal2')::text,true);
 if public.list_trainer_agenda(current_date,current_date+7)<>'[]'::jsonb or public.list_trainer_programs()<>'[]'::jsonb then raise exception 'ADMIN ajeno lee biblioteca/agenda'; end if;
 begin perform public.get_trainer_program(program);raise exception 'ADMIN abre programa ajeno';exception when insufficient_privilege then null;end;
 begin perform public.assign_trainer_program(gen_random_uuid(),rel,program,entries,null);raise exception 'Otro asigna programa ajeno';exception when insufficient_privilege then null;end;
 perform set_config('request.jwt.claim.sub',pupil::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',pupil,'role','authenticated','aal','aal1')::text,true);
 begin perform public.get_trainer_program(program);raise exception 'Alumno abre biblioteca profesional';exception when insufficient_privilege then null;end;
 execution:=public.start_scheduled_workout(scheduled);
 if not exists(select 1 from public.workout_execution_sets where execution_id=execution and target_reps=8) then raise exception 'Pierde receta fijada';end if;
 perform public.end_trainer_relation(rel);
 if public.start_scheduled_workout(scheduled)<>execution then raise exception 'Baja interrumpe iniciada';end if;
 perform set_config('request.jwt.claim.sub',trainer::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',trainer,'role','authenticated','aal','aal2')::text,true);
 if jsonb_array_length(public.list_trainer_agenda(current_date,current_date+7))<>2 then raise exception 'Pierde historial del programa';end if;
 begin perform public.assign_trainer_program(gen_random_uuid(),rel,program,entries,null);raise exception 'Asigna tras baja';exception when insufficient_privilege then null;end;
 perform set_config('request.jwt.claims',jsonb_build_object('sub',trainer,'role','authenticated','aal','aal1')::text,true);
 begin perform public.list_trainer_programs();raise exception 'Biblioteca sin MFA';exception when insufficient_privilege then null;end;
 begin perform public.list_trainer_agenda(current_date,current_date+7);raise exception 'Agenda sin MFA';exception when insufficient_privilege then null;end;
 reset role;
end $$;
select 'trainer_private_programs: OK' as result;
rollback;
