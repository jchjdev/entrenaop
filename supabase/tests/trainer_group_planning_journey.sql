begin;
set local statement_timeout='60s';
-- Todas las identidades y colas de ensayo desaparecen al terminar. No se
-- invoca al despachador de Firebase ni se confirma ningún trabajo push.
do $$
declare
 coach uuid:=gen_random_uuid();ana uuid:=gen_random_uuid();luis uuid:=gen_random_uuid();
 ra uuid:=gen_random_uuid();rl uuid:=gen_random_uuid();gid uuid:=gen_random_uuid();op uuid:=gen_random_uuid();
 exercise uuid;template uuid;program uuid;adapted uuid;assignment uuid;sibling uuid;execution uuid;result_id uuid;
 recipe jsonb;changed jsonb;recipients jsonb;entries jsonb;preview jsonb;receipt jsonb;row jsonb;context jsonb;
 groups jsonb;queue jsonb;review jsonb;fingerprint text;scheduled_date date;seen bigint;stamp timestamptz:=clock_timestamp();
begin
 insert into auth.users(id,email) values(coach,coach||'@group-journey.invalid'),(ana,ana||'@group-journey.invalid'),(luis,luis||'@group-journey.invalid');
 insert into auth.mfa_factors(id,user_id,factor_type,status,created_at,updated_at) values(gen_random_uuid(),coach,'totp','verified',now(),now());
 insert into public.trainer_access(trainer_id,enabled,client_limit,last_reason) values(coach,true,2,'Recorrido transaccional de grupo');
 insert into public.trainer_client_relations(id,trainer_id,client_id) values(ra,coach,ana),(rl,coach,luis);
 insert into push_private.installations(id,owner_id,secret_hash,binding_id,platform,token,token_hash)
 select gen_random_uuid(),p,repeat('a',64),gen_random_uuid(),'android',p::text,encode(sha256(convert_to(p::text,'UTF8')),'hex') from unnest(array[ana,luis]) p;
 insert into push_private.preferences(owner_id,quiet_enabled) values(ana,false),(luis,false);
 update push_private.settings set enabled=true,firebase_project_id='entrenaop-dev' where singleton;
 perform set_config('request.jwt.claim.sub',coach::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',coach,'role','authenticated','aal','aal2')::text,true);
 set local role authenticated;
 exercise:=public.save_trainer_exercise(gen_random_uuid(),'{"name":"Dominadas del grupo","description":"Contrato temporal","muscle_groups":["espalda"],"equipment":["barra"],"difficulty":"intermedio","exercise_type":"repeticiones"}');
 recipe:=jsonb_build_object('name','Fuerza de preparación','blocks',jsonb_build_array(jsonb_build_object('name','Dominadas','format','straight_sets','rounds',1,'rest_after_seconds',0,
  'exercises',jsonb_build_array(jsonb_build_object('exercise_id',exercise,'sets',jsonb_build_array(jsonb_build_object('target_reps',8,'rest_after_seconds',60)))))));
 template:=public.save_trainer_workout(gen_random_uuid(),recipe);
 perform public.save_trainer_group(gen_random_uuid(),gid,0,'Preparación conjunta',array[ana,luis]);
 -- Una pauta previa de Ana debe conservarse y señalarse antes de enviar.
 perform public.assign_trainer_workout(gen_random_uuid(),ra,template,current_date,null);
 program:=public.save_trainer_program(gen_random_uuid(),jsonb_build_object('name','Semana de preparación','mode','phased','phases',jsonb_build_array(jsonb_build_object(
  'name','Base','duration_weeks',1,'instructions','Revisar la dosis de cada alumno','sessions',jsonb_build_array(
   jsonb_build_object('template_id',template,'name','Fuerza A'),jsonb_build_object('template_id',template,'name','Fuerza B'),jsonb_build_object('template_id',template,'name','Fuerza C'))))));
 recipients:=jsonb_build_array(jsonb_build_object('client_id',ana,'relation_id',ra),jsonb_build_object('client_id',luis,'relation_id',rl));
 entries:=jsonb_build_array(jsonb_build_object('phase',0,'session',0,'date',current_date-4),jsonb_build_object('phase',0,'session',1,'date',current_date-2),jsonb_build_object('phase',0,'session',2,'date',current_date));
 preview:=public.preview_trainer_batch(recipients,p_program_id=>program,p_entries=>entries,p_group_id=>gid,p_group_revision=>1);
 if (preview->>'assignment_count')::int<>6 then raise exception 'No revisa las seis pautas';end if;
 select value into row from jsonb_array_elements(preview->'preview') p where p->>'client_id'=ana::text;
 if jsonb_array_length(row->'coincidences')<>1 or jsonb_array_length(row->'dates')<>3 then raise exception 'No informa de las fechas y coincidencia de Ana';end if;
 select value into row from jsonb_array_elements(preview->'preview') p where p->>'client_id'=luis::text;
 if row->'coincidences'<>'[]'::jsonb then raise exception 'Inventa coincidencias de Luis';end if;
 receipt:=public.deliver_trainer_batch_reviewed(op,recipients,preview->>'fingerprint',p_program_id=>program,p_entries=>entries,p_group_id=>gid,p_group_revision=>1);
 if public.deliver_trainer_batch_reviewed(op,recipients,preview->>'fingerprint',p_program_id=>program,p_entries=>entries,p_group_id=>gid,p_group_revision=>1)<>receipt then raise exception 'El reintento no recupera el mismo recibo';end if;
 select value into row from jsonb_array_elements(receipt->'recipients') r where r->>'client_id'=ana::text;
 assignment:=(row->'assignment_ids'->>0)::uuid;
 select value into row from jsonb_array_elements(receipt->'recipients') r where r->>'client_id'=luis::text;
 sibling:=(row->'assignment_ids'->>0)::uuid;
 if jsonb_array_length(public.list_trainer_assignments(ana))<>4 or jsonb_array_length(public.list_trainer_assignments(luis))<>3 then raise exception 'Duplica, sustituye o pierde pautas';end if;
 reset role;
 if (select count(*) from push_private.notice_jobs where owner_id in (ana,luis) and kind='assignment')<>2 then raise exception 'Crea una push por sesión';end if;
 if exists(select 1 from push_private.notice_jobs where owner_id in (ana,luis) and kind='assignment' and next_at<stamp+interval '4 minutes') then raise exception 'Ignora la espera de agrupación';end if;
 set local role authenticated;
 context:=public.get_trainer_assignment(assignment);scheduled_date:=(context->>'scheduled_date')::date;
 changed:=jsonb_set(recipe,'{blocks,0,exercises,0,sets,0,target_reps}','10');
 fingerprint:=public.preview_trainer_assignment_change(assignment,0,scheduled_date,'Dosis individual',changed)->>'fingerprint';
 context:=public.change_trainer_assignment_reviewed(gen_random_uuid(),assignment,0,scheduled_date,'Dosis individual',fingerprint,changed);
 adapted:=(context->>'template_id')::uuid;
 if adapted=template or public.get_trainer_assignment(sibling)->>'template_id'<>template::text then raise exception 'La adaptación altera a Luis o la receta común';end if;
 if (select target_reps from public.workout_sets s join public.workout_items e on e.id=s.item_id join public.workout_blocks b on b.id=e.block_id where b.template_id=template limit 1)<>8 then raise exception 'La adaptación cambia la biblioteca';end if;
 perform set_config('request.jwt.claim.sub',luis::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',luis,'role','authenticated','aal','aal1')::text,true);
 if exists(select 1 from public.workout_templates where id=adapted) then raise exception 'Luis ve la variante de Ana';end if;
 groups:=public.get_my_trainer_notice_groups(luis);
 if (groups->>'unread_count')::int<>1 or (groups->'items'->0->>'event_count')::int<>3 then raise exception 'Los avisos de Luis no resumen sus tres sesiones';end if;
 perform set_config('request.jwt.claim.sub',ana::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',ana,'role','authenticated','aal','aal1')::text,true);
 if not exists(select 1 from public.workout_templates where id=adapted) then raise exception 'Ana no puede consultar su adaptación';end if;
 execution:=public.start_scheduled_workout(assignment);
 select id into result_id from public.workout_execution_sets where execution_id=execution limit 1;
 perform public.complete_workout_set(result_id,p_actual_reps=>10);
 perform public.finish_workout_execution(execution,7,'Sesión del grupo realizada',null,null,'manual');
 perform set_config('request.jwt.claim.sub',coach::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',coach,'role','authenticated','aal','aal2')::text,true);
 queue:=public.list_trainer_review_queue();
 if jsonb_array_length(queue)<>1 or queue->0->>'id'<>assignment::text then raise exception 'El resultado no llega a revisión con su alumno';end if;
 seen:=(queue->0->>'result_revision')::bigint;
 perform public.mark_trainer_assignment_reviewed(gen_random_uuid(),assignment,seen,'Revisión individual interna');
 review:=public.get_trainer_assignment_result(assignment);
 if review->'review'->>'private_note'<>'Revisión individual interna' or jsonb_array_length(public.list_trainer_review_queue())<>0 then raise exception 'No conserva la revisión';end if;
 if public.get_trainer_assignment(sibling)->>'status'<>'planned' then raise exception 'Revisar a Ana afecta a Luis';end if;
 reset role;
end $$;
select 'trainer_group_planning_journey: OK' as result;
rollback;
