-- Continuidad real de hijos/adaptaciones, sin datos persistentes de ensayo.
begin;
set local statement_timeout='90s';
do $$
declare owner uuid:=gen_random_uuid(); other uuid:=gen_random_uuid(); pupil uuid:=gen_random_uuid();
 parent uuid:=gen_random_uuid(); child uuid:=gen_random_uuid(); phase_id uuid:=gen_random_uuid(); position_id uuid:=gen_random_uuid();
 relation uuid:=gen_random_uuid(); assignment uuid:=gen_random_uuid(); coincidence uuid:=gen_random_uuid();
 adaptation uuid:=gen_random_uuid(); started_work uuid:=gen_random_uuid();
 exercise uuid; base uuid; child_result uuid; result uuid; adapted_template uuid;
 origin jsonb; adaptation_origin jsonb; raw jsonb; recipe jsonb; program jsonb; linked jsonb; receipt jsonb; preview jsonb; fresh jsonb;
begin
 insert into auth.users(id,email) values(owner,owner||'@context-work.invalid'),(other,other||'@context-work.invalid'),(pupil,pupil||'@context-work.invalid');
 insert into auth.mfa_factors(id,user_id,factor_type,status,created_at,updated_at)
  values(gen_random_uuid(),owner,'totp','verified',now(),now()),(gen_random_uuid(),other,'totp','verified',now(),now());
 insert into public.trainer_access(trainer_id,enabled,client_limit,last_reason) values(owner,true,3,'Contextos recuperables'),(other,true,3,'Aislamiento');
 insert into public.trainer_client_relations(id,trainer_id,client_id) values(relation,owner,pupil);
 select id into strict exercise from public.exercises where is_public order by id limit 1;
 recipe:=jsonb_build_object('name','Receta de prueba','blocks',jsonb_build_array(jsonb_build_object('name','Principal','format','straight_sets','rounds',1,'rest_after_seconds',0,
  'exercises',jsonb_build_array(jsonb_build_object('exercise_id',exercise,'sets',jsonb_build_array(jsonb_build_object('target_reps',8,'rest_after_seconds',60)))))));
 -- El contrato del snapshot admite campos incompletos; la intenci贸n se valida
 -- por el motor deportivo real al finalizar, igual que el editor existente.
 raw:='{"schema":1,"context":{},"editor":{"schema":1,"running":false,"nameText":"Borrador sin perder","descriptionText":"Texto privado  ","durationText":"pendiente","segments":[],"blocks":[]}}';
 origin:=jsonb_build_object('baseId',null,'programId',null,'parentWorkId',parent,'phaseId',phase_id,'positionId',position_id,'duplicate',false);
 program:=jsonb_build_object('schema',1,'name','Programa recuperado','description','','audience','','equipment','','mode','phased','categories','[]'::jsonb,'primary',null,
  'phases',jsonb_build_array(jsonb_build_object('phaseId',phase_id,'name','Fase','weeks','2','instructions','Dos semanas de pr醕tica','pending','[]'::jsonb,'sessions','[]'::jsonb,
   'sessionWorks',jsonb_build_object(child::text,origin))));
 perform set_config('request.jwt.claim.sub',owner::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',owner,'role','authenticated','aal','aal2')::text,true);
 set local role authenticated;
 perform public.save_trainer_program_work(owner,parent,0,program);
 receipt:=public.save_trainer_session_work(owner,child,0,origin,raw);
 if public.save_trainer_session_work(owner,child,0,origin,raw)<>receipt then raise exception 'Reintento duplica hijo'; end if;
 if public.get_trainer_session_work(owner,child)->'state'<>raw then raise exception 'Pierde campos incompletos del hijo'; end if;
 begin perform public.save_trainer_program_work(owner,parent,1,jsonb_set(program,'{phases,0,sessionWorks}','{}'));
  raise exception 'El padre olvida hijo abierto'; exception when serialization_failure then null; end;
 begin perform public.discard_trainer_program_work(owner,parent,1); raise exception 'Descarta padre con hijo abierto'; exception when serialization_failure then null; end;
 perform set_config('request.jwt.claim.sub',other::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',other,'role','authenticated','aal','aal2')::text,true);
 if public.get_trainer_session_work(other,child) is not null then raise exception 'Filtra hijo entre cuentas'; end if;
 begin perform public.save_trainer_session_work(other,child,0,origin,raw); raise exception 'Usa padre ajeno'; exception when serialization_failure then null; end;
 perform set_config('request.jwt.claim.sub',owner::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',owner,'role','authenticated','aal','aal2')::text,true);
 perform public.save_trainer_session_work(owner,child,1,origin,raw||jsonb_build_object('intent',recipe));
 child_result:=public.finalize_trainer_session_work(owner,child,2);
 if public.finalize_trainer_session_work(owner,child,2)<>child_result then raise exception 'Respuesta perdida crea otra sesi贸n'; end if;
 if public.get_trainer_session_work(owner,child)->>'result_id'<>child_result::text then raise exception 'Pierde recibo confirmado'; end if;
 begin perform public.save_trainer_workout(gen_random_uuid(),recipe,child_result); raise exception 'Retira receta pendiente de enlace'; exception when serialization_failure then null; end;
 begin perform public.finalize_trainer_program_work(owner,parent,1,'{}'); raise exception 'Finaliza padre sin confirmar enlace'; exception when invalid_parameter_value then null; end;
 linked:=jsonb_set(jsonb_set(program,'{phases,0,sessionWorks}','{}'),'{phases,0,sessions}',jsonb_build_array(jsonb_build_object(
  'id',child_result,'positionId',position_id,'name','Receta de prueba','warmup',null,'adjustable',false,'minimum','','maximum','')));
 perform public.save_trainer_program_work(owner,parent,1,linked);
 -- El enlace confirmado no impide reorganizar la composici贸n posteriormente.
 perform public.save_trainer_program_work(owner,parent,2,jsonb_set(linked,'{phases,0,sessions}','[]'));
 perform public.save_trainer_program_work(owner,parent,3,linked);
 result:=public.finalize_trainer_program_work(owner,parent,4,jsonb_build_object('name','Programa recuperado','mode','phased','description','','audience','','equipment','',
  'phases',jsonb_build_array(jsonb_build_object('name','Fase','duration_weeks',2,'instructions','Dos semanas de pr醕tica','sessions',jsonb_build_array(jsonb_build_object(
   'template_id',child_result,'name','Receta de prueba','warmup_id',null,'rest',jsonb_build_object('min_seconds',null,'max_seconds',null)))))));
 if result is null then raise exception 'No finaliza programa tras incorporar hijo'; end if;

 base:=public.save_trainer_workout(gen_random_uuid(),recipe);
 perform public.assign_trainer_workout(assignment,relation,base,current_date+1,'Pauta que se conserva');
 perform public.assign_trainer_workout(coincidence,relation,base,current_date+1,null);
 adaptation_origin:=jsonb_build_object('baseId',base,'programId',null,'parentWorkId',null,'phaseId',null,'positionId',null,'duplicate',false,
  'assignmentId',assignment,'planningRevision',0);
 perform public.save_trainer_session_work(owner,adaptation,0,adaptation_origin,raw);
 if (public.get_trainer_assignment(assignment)->>'template_id')::uuid is distinct from base then raise exception 'Autosave aplica adaptaci贸n'; end if;
 perform public.save_trainer_session_work(owner,adaptation,1,adaptation_origin,raw||jsonb_build_object('intent',jsonb_set(recipe,'{name}','"Adaptaci贸n confirmada"')));
 begin perform public.finalize_trainer_session_work(owner,adaptation,2); raise exception 'Evita revisi贸n de coincidencias'; exception when invalid_parameter_value then null; end;
 preview:=public.preview_trainer_assignment_session_work(owner,adaptation,2);
 if not(preview->>'has_date_coincidence')::boolean then raise exception 'Oculta coincidencia'; end if;
 perform public.cancel_trainer_assignment(coincidence);
 begin perform public.finalize_trainer_assignment_session_work(owner,adaptation,2,preview->>'fingerprint'); raise exception 'Confirma revisi贸n obsoleta'; exception when serialization_failure then null; end;
 fresh:=public.preview_trainer_assignment_session_work(owner,adaptation,2);
 if (fresh->>'has_date_coincidence')::boolean then raise exception 'No actualiza coincidencias'; end if;
 if public.finalize_trainer_assignment_session_work(owner,adaptation,2,fresh->>'fingerprint')<>assignment then raise exception 'Destino de recibo incorrecto'; end if;
 if public.finalize_trainer_assignment_session_work(owner,adaptation,2,fresh->>'fingerprint')<>assignment then raise exception 'Reintento vuelve a aplicar'; end if;
 adapted_template:=(public.get_trainer_assignment(assignment)->>'template_id')::uuid;
 if adapted_template is null or adapted_template=base or (select name from public.workout_templates where id=base) is distinct from 'Receta de prueba'
  or (public.get_trainer_assignment(assignment)->>'planning_revision')::int is distinct from 1 then raise exception 'Altera biblioteca o duplica revisi贸n'; end if;
 if public.get_trainer_session_work(owner,adaptation)->>'result_id'<>assignment::text then raise exception 'Pierde confirmaci贸n de pauta'; end if;
 adaptation_origin:=jsonb_set(jsonb_set(adaptation_origin,'{baseId}',to_jsonb(adapted_template)),'{planningRevision}','1');
 perform public.save_trainer_session_work(owner,started_work,0,adaptation_origin,raw||jsonb_build_object('intent',recipe));
 perform set_config('request.jwt.claim.sub',pupil::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',pupil,'role','authenticated','aal','aal1')::text,true);
 perform public.start_scheduled_workout(assignment);
 perform set_config('request.jwt.claim.sub',owner::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',owner,'role','authenticated','aal','aal2')::text,true);
 begin perform public.preview_trainer_assignment_session_work(owner,started_work,1); raise exception 'Adapta entrenamiento iniciado'; exception when serialization_failure then null; end;
 if public.get_trainer_session_work(owner,started_work)->'state'<>raw||jsonb_build_object('intent',recipe) then raise exception 'Pierde borrador al iniciar alumno'; end if;
 perform set_config('request.jwt.claims',jsonb_build_object('sub',owner,'role','authenticated','aal','aal1')::text,true);
 begin perform public.get_trainer_session_work(owner,child); raise exception 'Recupera sin MFA'; exception when insufficient_privilege then null; end;
 reset role;
end $$;
select 'trainer_contextual_session_recovery: OK' as result;
rollback;
