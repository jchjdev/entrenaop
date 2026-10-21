begin;
set local statement_timeout='45s';
do $$
declare trainer uuid:=gen_random_uuid(); pupil uuid:=gen_random_uuid(); other uuid:=gen_random_uuid();
 rel uuid:=gen_random_uuid(); op uuid:=gen_random_uuid(); delivery uuid:=gen_random_uuid();
 t uuid; exercise uuid; execution uuid; unlinked uuid:=gen_random_uuid(); generated uuid; i integer;
 payload jsonb; j jsonb; first_page jsonb; second_page jsonb; cursor_date date; cursor_id text; fingerprint text;
begin
 insert into auth.users(id,email) values(trainer,trainer||'@trainer-workspace.invalid'),
  (pupil,pupil||'@trainer-workspace.invalid'),(other,other||'@trainer-workspace.invalid');
 update public.profiles set full_name='Alumno original' where id=pupil;
 insert into auth.mfa_factors(id,user_id,factor_type,status,created_at,updated_at)
  values(gen_random_uuid(),trainer,'totp','verified',now(),now()),(gen_random_uuid(),other,'totp','verified',now(),now());
 insert into public.admin_permissions(user_id) values(other);
 insert into public.trainer_access(trainer_id,enabled,client_limit,last_reason) values(trainer,true,1,'Fixture ficha profesional');
 insert into public.trainer_client_relations(id,trainer_id,client_id,accepted_at) values(rel,trainer,pupil,now());
 select id into exercise from public.exercises where is_public and id<>'20000000-0000-4000-8000-000000000004' order by id limit 1;
 payload:=jsonb_build_object('name','Sesión de ficha','blocks',jsonb_build_array(jsonb_build_object(
  'name','Fuerza','format','straight_sets','rounds',1,'rest_after_seconds',0,
  'exercises',jsonb_build_array(jsonb_build_object('exercise_id',exercise,'sets',jsonb_build_array(jsonb_build_object('target_reps',8,'rest_after_seconds',90)))))));
 perform set_config('request.jwt.claim.sub',trainer::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',trainer,'role','authenticated','aal','aal2')::text,true);
 set local role authenticated;
 j:=public.get_trainer_client_workspace(pupil);
 if j->'client'->>'person_name'<>'Alumno original' or (j->'notes'->>'revision')::integer<>0
  or j->'client'->>'active_relation_id'<>rel::text then raise exception 'Metadata de cartera incompleta'; end if;
 if public.save_trainer_client_notes(op,pupil,0,'Nota interna','Objetivo interno')<>1
  or public.save_trainer_client_notes(op,pupil,0,'Nota interna','Objetivo interno')<>1 then raise exception 'Notas no idempotentes'; end if;
 begin perform public.save_trainer_client_notes(op,pupil,0,'Otra nota','Objetivo interno'); raise exception 'Cambia payload de notas'; exception when invalid_parameter_value then null; end;
 begin perform public.save_trainer_client_notes(gen_random_uuid(),pupil,0,'Cambio obsoleto',''); raise exception 'Sobrescribe revisión ajena'; exception when serialization_failure then null; end;
 begin perform public.save_trainer_client_notes(gen_random_uuid(),pupil,1,repeat('x',2001),''); raise exception 'Supera longitud de notas'; exception when invalid_parameter_value then null; end;
 if public.save_trainer_client_notes(gen_random_uuid(),pupil,1,'Nota revisada','Objetivo interno')<>2 then raise exception 'Revisión de notas incorrecta'; end if;
 t:=public.save_trainer_workout(gen_random_uuid(),payload);
 perform public.assign_trainer_workout(delivery,rel,t,current_date,null);
 perform set_config('request.jwt.claim.sub',pupil::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',pupil,'role','authenticated','aal','aal1')::text,true);
 execution:=public.start_scheduled_workout(delivery);
 begin perform public.get_trainer_client_workspace(pupil); raise exception 'Alumno lee notas privadas'; exception when insufficient_privilege then null; end;
 reset role;
 update public.workout_executions set started_at='2026-10-20T23:30:00Z' where id=execution;
 update public.workout_execution_sets set status='completed',actual_reps=0,actual_load_kg=0,actual_rpe=null,result_source='manual',completed_at='2026-10-21T01:00:00Z' where execution_id=execution;
 update public.scheduled_workouts set scheduled_date=date '2026-10-20' where id=delivery;
 -- Una ejecución sin pauta de este servicio no se incorpora por compartir alumno.
 insert into public.workout_executions(id,user_id,template_id,template_name,template_version,status,started_at,completed_at)
  values(unlinked,pupil,t,'Entrenamiento personal ajeno al servicio',1,'completed','2026-10-20T10:00:00Z','2026-10-20T11:00:00Z');
 insert into public.workout_execution_sets select copy.* from jsonb_populate_record(null::public.workout_execution_sets,
  (select to_jsonb(es) from public.workout_execution_sets es where execution_id=execution limit 1)
  ||jsonb_build_object('id',gen_random_uuid(),'execution_id',unlinked,'actual_reps',999)) copy;
 for i in 1..205 loop
  generated:=gen_random_uuid();
  insert into public.scheduled_workouts(id,user_id,template_id,template_name,template_version,scheduled_date,source)
   values(generated,pupil,t,'Pauta histórica',1,date '2026-10-20','coach');
  insert into public.trainer_assignments(scheduled_id,relation_id,trainer_id,client_id) values(generated,rel,trainer,pupil);
 end loop;
 perform set_config('request.jwt.claim.sub',trainer::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',trainer,'role','authenticated','aal','aal2')::text,true);
 set local role authenticated;
 j:=public.get_trainer_client_progress(pupil,date '2026-10-20',date '2026-10-21','sets');
 if (j->>'total')::integer<>1 or j->'items'->0->>'execution_id'<>execution::text
  or j->'items'->0->'actual_reps'<>'0'::jsonb or j->'items'->0->'actual_rpe'<>'null'::jsonb
  or j->>'date_basis'<>'execution_started_at_utc' then raise exception 'Resultados amplían acceso, alteran fecha o fabrican valores'; end if;
 fingerprint:=j->>'fingerprint';
 reset role;
 update public.workout_execution_sets set actual_reps=1 where execution_id=execution;
 set local role authenticated;
 j:=public.get_trainer_client_progress(pupil,date '2026-10-20',date '2026-10-21','sets');
 if j->>'fingerprint'=fingerprint or (j->>'total')::integer<>1 then raise exception 'Cambio de valores con mismo recuento no cambia huella'; end if;
 reset role;
 update public.scheduled_workouts set scheduled_date=date '2026-10-19' where id=delivery;
 set local role authenticated;
 fingerprint:=public.get_trainer_client_progress(pupil,date '2026-10-20',date '2026-10-21','sets')->>'fingerprint';
 reset role;
 update public.workout_executions set started_at='2026-10-22T10:00:00Z' where id=execution;
 set local role authenticated;
 j:=public.get_trainer_client_progress(pupil,date '2026-10-20',date '2026-10-21','sets');
 if j->>'fingerprint'=fingerprint or (j->>'total')::integer<>0 then raise exception 'Cambiar inicio no renueva cohorte y huella'; end if;
 reset role;
 update public.workout_executions set started_at='2026-10-20T23:30:00Z' where id=execution;
 update public.scheduled_workouts set scheduled_date=date '2026-10-20' where id=delivery;
 set local role authenticated;
 first_page:=public.get_trainer_client_progress(pupil,date '2026-10-20',date '2026-10-21','assignments');
 if (first_page->>'total')::integer<>206 or jsonb_array_length(first_page->'items')<>200 or not (first_page->>'has_more')::boolean then raise exception 'Paginación no declara parcialidad'; end if;
 cursor_date:=(first_page->'items'->199->>'record_date')::date; cursor_id:=first_page->'items'->199->>'id';
 second_page:=public.get_trainer_client_progress(pupil,date '2026-10-20',date '2026-10-21','assignments',cursor_date,cursor_id);
 if jsonb_array_length(second_page->'items')<>6 or (second_page->>'has_more')::boolean or first_page->>'fingerprint'<>second_page->>'fingerprint'
  or exists(select 1 from jsonb_array_elements(first_page->'items') a join jsonb_array_elements(second_page->'items') b on a->>'id'=b->>'id') then raise exception 'Página duplicada o incompleta'; end if;
 begin perform public.get_trainer_client_progress(pupil,date '2020-01-01',date '2026-10-21','sets'); raise exception 'Periodo ilimitado'; exception when invalid_parameter_value then null; end;
 perform public.end_trainer_relation(rel);
 if (public.get_trainer_client_workspace(pupil)->'notes'->>'revision')::integer<>2 then raise exception 'Baja pierde notas'; end if;
 if (public.get_trainer_client_progress(pupil,date '2026-10-20',date '2026-10-21','sets')->>'total')::integer<>1 then raise exception 'Baja pierde historial propio'; end if;
 reset role;
 update public.profiles set full_name='Perfil posterior privado' where id=pupil;
 update public.trainer_access set enabled=false where trainer_id=trainer;
 set local role authenticated;
 if public.get_trainer_client_workspace(pupil)->'client'->>'person_name'<>'Alumno original' then raise exception 'Lee perfil nuevo después de baja'; end if;
 begin perform public.save_trainer_client_notes(gen_random_uuid(),pupil,2,'Nueva',''); raise exception 'Escribe sin acceso profesional'; exception when insufficient_privilege then null; end;
 perform set_config('request.jwt.claim.sub',other::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',other,'role','authenticated','aal','aal2')::text,true);
 begin perform public.get_trainer_client_workspace(pupil); raise exception 'ADMIN lee ficha ajena'; exception when insufficient_privilege then null; end;
 begin perform public.get_trainer_client_progress(pupil,date '2026-10-20',date '2026-10-21','sets'); raise exception 'ADMIN lee progreso ajeno'; exception when insufficient_privilege then null; end;
 perform set_config('request.jwt.claim.sub',trainer::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',trainer,'role','authenticated','aal','aal1')::text,true);
 begin perform public.get_trainer_client_workspace(pupil); raise exception 'Lee ficha sin MFA'; exception when insufficient_privilege then null; end;
 reset role;
 if (select count(*) from trainer_private.client_note_versions where trainer_id=trainer and client_id=pupil)<>2 then raise exception 'Reescribe historial de notas'; end if;
end $$;
select 'trainer_client_workspace: OK' as result;
rollback;
