-- Recorrido propio real: cupo, aislamiento, programa, ejecutor e historial.
begin;
set local statement_timeout='45s';
do $$
declare me uuid:=gen_random_uuid(); pupil uuid:=gen_random_uuid(); other uuid:=gen_random_uuid();
 coach2 uuid:=gen_random_uuid(); self_relation uuid; outsider_relation uuid; t uuid; program uuid;
 planned uuid:=gen_random_uuid(); done uuid:=gen_random_uuid(); execution uuid; result_id uuid;
 exercise uuid; payload jsonb; content jsonb; j jsonb; before_count integer; secret text:=repeat('ab',32);
begin
 insert into auth.users(id,email) values(me,me||'@self-training.invalid'),
  (pupil,pupil||'@self-training.invalid'),(other,other||'@self-training.invalid'),(coach2,coach2||'@self-training.invalid');
 insert into auth.mfa_factors(id,user_id,factor_type,status,created_at,updated_at)
  values(gen_random_uuid(),me,'totp','verified',now(),now()),(gen_random_uuid(),other,'totp','verified',now(),now());
 insert into public.trainer_access(trainer_id,enabled,client_limit,last_reason)
  values(me,true,1,'Fixture propio'),(other,true,1,'Fixture ajeno'),(coach2,true,1,'Fixture segundo');
 insert into public.trainer_client_relations(trainer_id,client_id) values(me,pupil);
 select id into exercise from public.exercises where is_public and id<>'20000000-0000-4000-8000-000000000004' order by id limit 1;
 payload:=jsonb_build_object('name','Mi sesión privada','blocks',jsonb_build_array(jsonb_build_object(
  'name','Fuerza','format','straight_sets','rounds',1,'rest_after_seconds',0,
  'exercises',jsonb_build_array(jsonb_build_object('exercise_id',exercise,'sets',jsonb_build_array(jsonb_build_object('target_reps',10,'rest_after_seconds',60)))))));
 perform set_config('request.jwt.claim.sub',me::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',me,'role','authenticated','aal','aal1')::text,true);
 set local role authenticated;
 begin perform public.ensure_trainer_self_client(me); raise exception 'Alta sin MFA'; exception when insufficient_privilege then null; end;
 perform set_config('request.jwt.claims',jsonb_build_object('sub',me,'role','authenticated','aal','aal2')::text,true);
 begin perform public.ensure_trainer_self_client(other); raise exception 'Alta para otra cuenta'; exception when insufficient_privilege then null; end;
 self_relation:=public.ensure_trainer_self_client(me);
 if public.ensure_trainer_self_client(me)<>self_relation then raise exception 'Alta no idempotente'; end if;
 if (public.get_trainer_access()->>'active_clients')::integer<>1 then raise exception 'La ficha propia consume cupo'; end if;
 if jsonb_array_length(public.list_trainer_clients())<>1 then raise exception 'Ficha propia mezclada en alumnos'; end if;
 j:=public.get_trainer_client_workspace(me);
 if j->'client'->>'person_name'<>'Para mí' or j->'client'->>'is_self'<>'true' then raise exception 'Ficha propia no identificada'; end if;
 if jsonb_array_length(public.list_my_trainer_relations(false))<>0 then raise exception 'Apareces como tu propio preparador'; end if;
 if jsonb_array_length(public.list_my_trainer_relations(true))<>2 then raise exception 'No aparece como destino de asignación'; end if;
 begin perform public.end_trainer_relation(self_relation); raise exception 'Finaliza la relación personal'; exception when invalid_parameter_value then null; end;
 begin perform public.archive_trainer_client(me,true); raise exception 'Archiva la ficha propia'; exception when invalid_parameter_value then null; end;
 begin perform public.send_trainer_message(gen_random_uuid(),self_relation,'Mensaje a mí mismo'); raise exception 'Mensaje propio admitido'; exception when insufficient_privilege then null; end;
 perform public.create_trainer_invitation(gen_random_uuid(),secret);
 begin perform public.accept_trainer_invitation(secret); raise exception 'Acepta invitación propia'; exception when invalid_parameter_value then null; end;
 exercise:=public.save_trainer_exercise(gen_random_uuid(),jsonb_build_object(
  'name','Mi dominada privada','description','Controla la bajada',
  'muscle_groups',jsonb_build_array('espalda'),'equipment',jsonb_build_array('barra'),
  'difficulty','intermedio','exercise_type','repeticiones'));
 payload:=jsonb_set(payload,'{blocks,0,exercises,0,exercise_id}',to_jsonb(exercise));
 t:=public.save_trainer_workout(gen_random_uuid(),payload);
 perform public.assign_trainer_workout(done,self_relation,t,current_date,'Para mí');
 perform public.assign_trainer_workout(done,self_relation,t,current_date,'Para mí');
 perform public.assign_trainer_workout(planned,self_relation,t,current_date+1,null);
 content:=jsonb_build_object('name','Mi programa','mode','phased','phases',jsonb_build_array(
  jsonb_build_object('name','Base','duration_weeks',1,'instructions','Ajustar según sensaciones','sessions',jsonb_build_array(jsonb_build_object('template_id',t,'name','Fuerza')))));
 program:=public.save_trainer_program(gen_random_uuid(),content);
 perform public.assign_trainer_program(gen_random_uuid(),self_relation,program,
  jsonb_build_array(jsonb_build_object('phase',0,'session',0,'date',current_date+2)),null);
 if jsonb_array_length(public.list_trainer_assignments(me))<>3 then raise exception 'No reúne sesiones y programa propios'; end if;
 j:=public.get_trainer_shared_calendar(me,me,current_date,current_date+3);
 if j->>'shared'<>'true' or jsonb_array_length(j->'items')<>3 then raise exception 'Calendario propio exige compartirse consigo mismo'; end if;
 reset role;
 if exists(select 1 from trainer_private.student_notices where owner_id=me) then raise exception 'Crea avisos de autoplanificación'; end if;
 -- Puede conservar dos preparadores externos, aparte de su ficha propia.
 insert into public.trainer_client_relations(trainer_id,client_id) values(other,me),(coach2,me);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',me,'role','authenticated','aal','aal1')::text,true);
 set local role authenticated;
 if (public.get_my_trainer_calendar_sharing(me)->>'active_trainers')::integer<>2 then raise exception 'Self cuenta como tercer preparador'; end if;
 if jsonb_array_length(public.list_my_trainer_relations(false))<>2 then raise exception 'No conserva otros preparadores'; end if;
 if not exists(select 1 from public.scheduled_workouts where id=done and user_id=me) then raise exception 'No aparece en agenda del deportista'; end if;
 if not exists(select 1 from public.exercises where id=exercise and origin='coach') then raise exception 'El ejecutor sin MFA pierde ejercicio propio asignado'; end if;
 if public.get_my_schedule_coaches(me,array[done])->0->>'is_self'<>'true' then raise exception 'No identifica origen propio'; end if;
 execution:=public.start_scheduled_workout(done);
 if public.start_scheduled_workout(done)<>execution then raise exception 'Inicio duplica ejecución'; end if;
 select id into result_id from public.workout_execution_sets where execution_id=execution;
 perform public.complete_workout_set(result_id,p_actual_reps=>8,p_actual_load_kg=>20);
 perform public.finish_workout_execution(execution,6,'Mi entrenamiento',null,null,'manual');
 perform set_config('request.jwt.claims',jsonb_build_object('sub',me,'role','authenticated','aal','aal2')::text,true);
 j:=public.get_trainer_assignment_result(done);
 if j->>'notes'<>'Mi entrenamiento' or (j->'workout_execution_sets'->0->>'actual_reps')::integer<>8 then raise exception 'No consulta resultado propio'; end if;
 perform public.cancel_trainer_assignment(planned);
 if not exists(select 1 from public.scheduled_workouts where id=planned and status='cancelled') then raise exception 'No retira pauta propia'; end if;
 perform set_config('request.jwt.claim.sub',other::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',other,'role','authenticated','aal','aal2')::text,true);
 begin perform public.assign_trainer_workout(gen_random_uuid(),self_relation,t,current_date,null); raise exception 'Otro usa relación propia'; exception when insufficient_privilege then null; end;
 begin perform public.get_trainer_assignment_result(done); raise exception 'Otro preparador lee resultado por compartir alumno'; exception when insufficient_privilege then null; end;
 j:=public.get_trainer_shared_calendar(other,me,current_date,current_date+3);
 if j->>'shared'<>'false' then raise exception 'Self concede calendario a otros sin consentimiento'; end if;
 reset role;
 perform set_config('request.jwt.claim.sub',me::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',me,'role','authenticated','aal','aal2')::text,true);
 set local role authenticated;
 perform public.set_my_trainer_calendar_sharing(me,true,0);
 for outsider_relation in select id from public.trainer_client_relations where client_id=me and trainer_id<>client_id and ended_at is null loop
  perform public.end_trainer_relation(outsider_relation);
 end loop;
 if public.get_my_trainer_calendar_sharing(me)->>'enabled'<>'false' then raise exception 'Self mantiene consentimiento sin destinatarios externos'; end if;
 reset role;
 update public.trainer_access set enabled=false where trainer_id=me;
 perform set_config('request.jwt.claim.sub',me::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',me,'role','authenticated','aal','aal2')::text,true);
 set local role authenticated;
 if public.ensure_trainer_self_client(me)<>self_relation then raise exception 'Pierde acceso histórico propio'; end if;
 begin perform public.assign_trainer_workout(gen_random_uuid(),self_relation,t,current_date,null); raise exception 'Asigna con acceso inactivo'; exception when insufficient_privilege then null; end;
 reset role;
 if has_function_privilege('anon','public.ensure_trainer_self_client(uuid)','execute') then raise exception 'Alta anónima'; end if;
end $$;
select 'trainer_self_training: OK' as result;
rollback;
