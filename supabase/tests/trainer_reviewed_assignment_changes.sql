begin;
set local statement_timeout='60s';
do $$
declare trainer uuid:=gen_random_uuid(); pupil uuid:=gen_random_uuid(); outsider uuid:=gen_random_uuid(); relation uuid:=gen_random_uuid();
 assignment uuid:=gen_random_uuid(); adaptive uuid:=gen_random_uuid(); operation uuid:=gen_random_uuid(); exercise uuid; template uuid; personal uuid; execution uuid;
 recipe jsonb; adapted jsonb; preview jsonb; refreshed jsonb; receipt jsonb; response jsonb; fingerprint text;
 target date:=current_date+14;
begin
 insert into auth.users(id,email) values(trainer,trainer||'@reviewed-change.invalid'),(pupil,pupil||'@reviewed-change.invalid'),(outsider,outsider||'@reviewed-change.invalid');
 insert into auth.mfa_factors(id,user_id,factor_type,status,created_at,updated_at) values
  (gen_random_uuid(),trainer,'totp','verified',now(),now()),(gen_random_uuid(),outsider,'totp','verified',now(),now());
 insert into public.admin_permissions(user_id) values(outsider);
 insert into public.trainer_access(trainer_id,enabled,client_limit,last_reason) values(trainer,true,1,'Fixture edición revisada');
 insert into public.trainer_client_relations(id,trainer_id,client_id,accepted_at) values(relation,trainer,pupil,now());
 if has_function_privilege('authenticated','public.change_trainer_assignment(uuid,uuid,bigint,date,text,jsonb)','EXECUTE')
  or has_function_privilege('authenticated','trainer_private.change_assignment(uuid,uuid,bigint,date,text,jsonb)','EXECUTE')
  or has_function_privilege('authenticated','trainer_private.lock_calendar_revisions(uuid[],boolean)','EXECUTE') then raise exception 'Bypass o helper expuesto'; end if;
 select id into exercise from public.exercises where is_public and id<>'20000000-0000-4000-8000-000000000004' order by id limit 1;
 recipe:=jsonb_build_object('name','Receta del preparador','blocks',jsonb_build_array(jsonb_build_object('name','Fuerza','format','straight_sets','rounds',1,'rest_after_seconds',0,
  'exercises',jsonb_build_array(jsonb_build_object('exercise_id',exercise,'sets',jsonb_build_array(jsonb_build_object('target_reps',8,'rest_after_seconds',60)))))));
 adapted:=jsonb_set(recipe,'{name}','"Adaptación individual"');
 perform set_config('request.jwt.claim.sub',trainer::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',trainer,'role','authenticated','aal','aal2')::text,true);
 set local role authenticated;
 template:=public.save_trainer_workout(gen_random_uuid(),recipe);
 perform public.assign_trainer_workout(assignment,relation,template,target-7,'Origen');
 perform public.assign_trainer_workout(adaptive,relation,template,target-6,'Origen de adaptación');
 begin perform public.change_trainer_assignment(gen_random_uuid(),assignment,0,target,'Mover');raise exception 'Bypass público legacy';exception when insufficient_privilege then null;end;
 begin perform trainer_private.lock_calendar_revisions(array[pupil],false);raise exception 'Helper false accesible';exception when insufficient_privilege then null;end;
 preview:=public.preview_trainer_assignment_change(assignment,0,target,'Mover');
 fingerprint:=preview->>'fingerprint';
 if fingerprint !~ '^[0-9a-f]{64}$' or (preview->>'has_date_coincidence')::boolean
  or preview->>'id'<>assignment::text or preview->>'client_id'<>pupil::text or preview->>'relation_id'<>relation::text
  or preview->>'date'<>target::text or (preview->>'planning_revision')::bigint<>0
  or (select count(*) from jsonb_object_keys(preview))<>7 then raise exception 'Preview incompleto o con datos extra'; end if;
 begin perform public.preview_trainer_assignment_change(assignment,1,target,'Mover');raise exception 'Preview acepta revisión ajena';exception when serialization_failure then null;end;
 begin perform public.change_trainer_assignment_reviewed(operation,assignment,0,target,'Otra nota',fingerprint);raise exception 'Huella no liga nota';exception when serialization_failure then null;end;
 begin perform public.change_trainer_assignment_reviewed(operation,assignment,0,target,'Mover',null);raise exception 'Confirma sin huella';exception when invalid_parameter_value then null;end;
 perform set_config('request.jwt.claim.sub',pupil::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',pupil,'role','authenticated','aal','aal1')::text,true);
 personal:=public.create_personal_workout_template(jsonb_set(recipe,'{name}','"Secreto que no debe ver el preparador"'));
 perform public.schedule_workout(personal,target);
 begin perform public.preview_trainer_assignment_change(assignment,0,target,'Mover');raise exception 'Alumno consulta preview profesional';exception when insufficient_privilege then null;end;
 perform set_config('request.jwt.claim.sub',trainer::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',trainer,'role','authenticated','aal','aal2')::text,true);
 begin perform public.change_trainer_assignment_reviewed(operation,assignment,0,target,'Mover',fingerprint);raise exception 'Confirma coincidencia nueva';exception when serialization_failure then null;end;
 if (public.get_trainer_assignment(assignment)->>'planning_revision')::bigint<>0 then raise exception 'Rechazo deja edición parcial'; end if;
 refreshed:=public.preview_trainer_assignment_change(assignment,0,target,'Mover');
 if not(refreshed->>'has_date_coincidence')::boolean or refreshed::text like '%Secreto que no debe%' or refreshed->>'fingerprint'=fingerprint then raise exception 'Señal incorrecta o privada'; end if;
 fingerprint:=refreshed->>'fingerprint';
 receipt:=public.change_trainer_assignment_reviewed(operation,assignment,0,target,'Mover',fingerprint);
 if (receipt->>'planning_revision')::bigint<>1 then raise exception 'No avanza revisión'; end if;
 if public.change_trainer_assignment_reviewed(operation,assignment,0,target,'Mover',fingerprint)<>receipt then raise exception 'Duplica movimiento'; end if;
 begin perform public.change_trainer_assignment_reviewed(operation,assignment,0,target+1,'Mover',fingerprint);raise exception 'Orden cambia fecha';exception when invalid_parameter_value then null;end;

 preview:=public.preview_trainer_assignment_change(adaptive,0,target+1,'Adaptar',adapted);
 begin perform public.change_trainer_assignment_reviewed(gen_random_uuid(),adaptive,0,target+1,'Adaptar',preview->>'fingerprint',recipe);raise exception 'Huella no liga receta';exception when serialization_failure then null;end;
 response:=public.change_trainer_assignment_reviewed(gen_random_uuid(),adaptive,0,target+1,'Adaptar',preview->>'fingerprint',adapted);
 if response->>'template_id'=template::text or (response->>'planning_revision')::bigint<>1 then raise exception 'Adaptación no usa variante'; end if;
 perform set_config('request.jwt.claim.sub',pupil::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',pupil,'role','authenticated','aal','aal1')::text,true);
 execution:=public.start_scheduled_workout(assignment);
 perform set_config('request.jwt.claim.sub',trainer::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',trainer,'role','authenticated','aal','aal2')::text,true);
 if public.change_trainer_assignment_reviewed(operation,assignment,0,target,'Mover',fingerprint)<>receipt then raise exception 'Inicio invalida recibo original'; end if;
 begin perform public.change_trainer_assignment_reviewed(gen_random_uuid(),assignment,1,target+2,'Mover',fingerprint);raise exception 'Edita iniciada';exception when serialization_failure then null;end;
 perform set_config('request.jwt.claims',jsonb_build_object('sub',trainer,'role','authenticated','aal','aal1')::text,true);
 begin perform public.preview_trainer_assignment_change(adaptive,1,target+2,'Mover');raise exception 'Preview sin MFA';exception when insufficient_privilege then null;end;
 perform set_config('request.jwt.claim.sub',outsider::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',outsider,'role','authenticated','aal','aal2')::text,true);
 begin perform public.preview_trainer_assignment_change(adaptive,1,target+2,'Mover');raise exception 'ADMIN consulta preview ajeno';exception when insufficient_privilege then null;end;
 begin perform public.change_trainer_assignment_reviewed(gen_random_uuid(),adaptive,1,target+2,'Mover',fingerprint);raise exception 'ADMIN modifica pauta ajena';exception when insufficient_privilege then null;end;
end $$;
select 'trainer_reviewed_assignment_changes: OK' as result;
rollback;
