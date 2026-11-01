begin;
set local statement_timeout='60s';
do $$
declare trainer uuid:=gen_random_uuid(); pupil uuid:=gen_random_uuid(); stranger uuid:=gen_random_uuid();
 relation uuid:=gen_random_uuid(); ps uuid:=gen_random_uuid(); ts uuid:=gen_random_uuid(); weak uuid:=gen_random_uuid();
 template uuid; scheduled uuid:=gen_random_uuid(); second uuid:=gen_random_uuid(); recipe jsonb;
 preview jsonb; claim jsonb; receipt jsonb; lease uuid:=gen_random_uuid(); jid uuid; code text; bs uuid:=gen_random_uuid(); bw uuid:=gen_random_uuid();
begin
 insert into auth.users(id,email) values(trainer,trainer||'@garmin-training.invalid'),(pupil,pupil||'@garmin-training.invalid'),(stranger,stranger||'@garmin-training.invalid');
 insert into auth.sessions(id,user_id,aal) values(ps,pupil,'aal1'),(ts,trainer,'aal2'),(weak,trainer,'aal1');
 insert into auth.mfa_factors(id,user_id,factor_type,status,created_at,updated_at) values(gen_random_uuid(),trainer,'totp','verified',now(),now());
 insert into public.trainer_access(trainer_id,enabled,client_limit,last_reason) values(trainer,true,5,'Fixture Garmin con ROLLBACK');
 insert into public.trainer_client_relations(id,trainer_id,client_id,accepted_at) values(relation,trainer,pupil,now());
 perform set_config('request.jwt.claim.sub',trainer::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',trainer,'role','authenticated','aal','aal2')::text,true);
 recipe:=jsonb_build_object('name','Carrera sintética Garmin','blocks',jsonb_build_array(jsonb_build_object(
  'name','Carrera','format','running','rounds',1,'rest_after_seconds',0,'exercises',jsonb_build_array(jsonb_build_object(
   'exercise_id','20000000-0000-4000-8000-000000000004','notes','PRIVATE_ITEM_INSTRUCTIONS','sets',jsonb_build_array(jsonb_build_object(
    'target_duration_seconds',120,'rest_after_seconds',0,'target_pace_min_seconds_per_km',300,'target_pace_max_seconds_per_km',360,
    'recovery_type','walking','recovery_duration_seconds',30)))))));
 template:=trainer_private.save_trainer_workout(gen_random_uuid(),recipe);
 perform trainer_private.assign_trainer_workout(scheduled,relation,template,current_date,null);
 perform trainer_private.assign_trainer_workout(second,relation,template,current_date+2,null);

 perform set_config('fixture.owner',pupil::text,true);perform set_config('fixture.session',ps::text,true);
 perform set_config('fixture.scheduled',scheduled::text,true);
 perform set_config('fixture.pending',second::text,true);
 perform set_config('fixture.stranger',stranger::text,true);
 insert into auth.sessions(id,user_id,aal) values(bs,stranger,'aal2'),(bw,stranger,'aal1');
 insert into auth.mfa_factors(id,user_id,factor_type,status,created_at,updated_at) values(gen_random_uuid(),stranger,'totp','verified',now(),now());
 insert into public.trainer_access(trainer_id,enabled,client_limit,last_reason) values(stranger,true,5,'Fixture de resultados compartidos');
 insert into public.trainer_client_relations(trainer_id,client_id,accepted_at) values(stranger,pupil,now());
 perform set_config('fixture.trainer_a',trainer::text,true);perform set_config('fixture.session_a',ts::text,true);
 perform set_config('fixture.trainer_b',stranger::text,true);perform set_config('fixture.session_b',bs::text,true);
 perform set_config('fixture.weak_b',bw::text,true);perform set_config('fixture.relation_a',relation::text,true);

end $$;



set local role authenticated;
do $$declare owner uuid:=current_setting('fixture.owner')::uuid; sid uuid:=current_setting('fixture.scheduled')::uuid;
 p jsonb;claim jsonb;obs jsonb;answer jsonb;result_id uuid;execution uuid;
 started timestamptz:=now()-interval '3 minutes';wid uuid:=gen_random_uuid();begin
 perform set_config('request.jwt.claim.sub',owner::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',owner,'role','authenticated','session_id',current_setting('fixture.session'),'aal','aal1')::text,true);
 p:=public.apple_training_command(owner,'preview',jsonb_build_object('scheduled_id',sid));
 claim:=public.apple_training_command(owner,'prepare',jsonb_build_object('scheduled_id',sid,'revision',p->>'revision','attempt_id',gen_random_uuid()));
 perform public.apple_training_command(owner,'record',jsonb_build_object('scheduled_id',sid,'revision',claim->>'revision','attempt_id',claim->>'attempt_id'));
 perform public.apple_results_command(owner,'enable','{"enabled":true}');
 obs:=jsonb_build_object('workout_id',wid,'plan_id',claim->>'plan_id','revision',claim->>'revision','matches_prescription',true,
  'started_at',started,'ended_at',started+interval '117.3 seconds','timer_seconds',117.3,'distance_meters',420,
  'offset_minutes',60,'intervals',jsonb_build_array(
   jsonb_build_object('id',gen_random_uuid(),'started_at',started,'ended_at',started+interval '87.3 seconds','timer_seconds',87.3,'distance_meters',400),
   jsonb_build_object('id',gen_random_uuid(),'started_at',started+interval '87.3 seconds','ended_at',started+interval '117.3 seconds','timer_seconds',30,'distance_meters',20)));
 answer:=public.apple_results_command(owner,'ingest',jsonb_build_object('observations',jsonb_build_array(obs-'intervals')));
 if answer->'automatic'->0->>'state'<>'review' then raise exception 'Completa sin fases observadas';end if;
 answer:=public.apple_results_command(owner,'ingest',jsonb_build_object('observations',jsonb_build_array(obs)));
 if answer->'automatic'->0->>'state'<>'completed' then raise exception 'No completa una actividad acreditada: %',answer;end if;
 execution:=(answer->'automatic'->0->>'execution_id')::uuid;
 if exists(select 1 from public.workout_executions where id=execution and final_rpe is not null) then
  raise exception 'Inventa esfuerzo ausente';end if;
 perform set_config('fixture.execution',execution::text,true);
 perform set_config('fixture.observation',obs::text,true);
end $$;
reset role;

update public.workout_executions set notes='PRIVATE_SESSION_NOTE'
 where id=current_setting('fixture.execution')::uuid;
create function pg_temp.result_identity(p_user uuid,p_session uuid,p_aal text default 'aal2') returns void language plpgsql as $$begin
 perform set_config('request.jwt.claim.sub',p_user::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',p_user,'role','authenticated','session_id',p_session,'aal',p_aal)::text,true);
end $$;
do $$begin execute format('grant usage on schema %I to authenticated',(select nspname from pg_namespace where oid=pg_my_temp_schema()));end $$;
set local role authenticated;
do $$declare
 owner uuid:=current_setting('fixture.owner')::uuid; sid uuid:=current_setting('fixture.scheduled')::uuid;
 a uuid:=current_setting('fixture.trainer_a')::uuid; b uuid:=current_setting('fixture.trainer_b')::uuid;
 prefs jsonb; result jsonb; calendar jsonb; revision bigint;
begin
 perform pg_temp.result_identity(owner,current_setting('fixture.session')::uuid,'aal1');
 prefs:=public.get_my_trainer_calendar_sharing(owner);
 if (prefs->>'results_enabled')::boolean then raise exception 'Activa resultados por defecto';end if;
 begin
  perform public.set_my_trainer_result_sharing(owner,true,(prefs->>'revision')::bigint);
  raise exception 'Comparte sin calendario';exception when check_violation then null;end;
 prefs:=public.set_my_trainer_calendar_sharing(owner,true,(prefs->>'revision')::bigint);
 revision:=(prefs->>'revision')::bigint;
 perform pg_temp.result_identity(b,current_setting('fixture.session_b')::uuid);
 begin
  perform public.get_trainer_shared_workout_result(b,owner,sid);
  raise exception 'El calendario abre resultados sin consentimiento';exception when insufficient_privilege then null;end;
 begin
  perform public.set_my_trainer_result_sharing(owner,true,revision);
  raise exception 'El preparador se concede el permiso';exception when insufficient_privilege then null;end;
 perform pg_temp.result_identity(a,current_setting('fixture.session_a')::uuid);
 if public.get_trainer_shared_workout_result(a,owner,sid)->>'id'<>current_setting('fixture.execution') then raise exception 'Pierde acceso habitual del autor';end if;
 perform pg_temp.result_identity(owner,current_setting('fixture.session')::uuid,'aal1');
 prefs:=public.set_my_trainer_result_sharing(owner,true,revision);
 if not (prefs->>'results_enabled')::boolean then raise exception 'No registra consentimiento';end if;
 if public.set_my_trainer_result_sharing(owner,true,revision)<>prefs then raise exception 'Replay cambia revisión';end if;
 begin
  perform public.set_my_trainer_result_sharing(owner,true,0);
  raise exception 'Acepta consentimiento desfasado';exception when serialization_failure then null;end;
 revision:=(prefs->>'revision')::bigint;
 perform pg_temp.result_identity(b,current_setting('fixture.session_b')::uuid);
 result:=public.get_trainer_shared_workout_result(b,owner,sid);
 if public.get_trainer_shared_workout_result(b,owner,current_setting('fixture.pending')::uuid) is not null then
  raise exception 'Comparte una sesión todavía no completada';end if;
 if result->>'id'<>current_setting('fixture.execution') or result->>'status'<>'completed'
  or result->'workout_execution_sets'->0->>'observed_duration_seconds'<>'87.3'
  or result->'final_rpe'<>'null'::jsonb then raise exception 'Pierde precisión o inventa esfuerzo: %',result;end if;
 if result ?| array['notes','review','user_id','workout_technique_videos'] or
  result->'workout_execution_sets'->0 ?| array['item_instructions','exercise_description','exercise_video_url'] or
  result::text like '%PRIVATE_%' then raise exception 'Filtra información privada';end if;
 calendar:=public.get_trainer_shared_calendar(b,owner,current_date,current_date+6);
 if not exists(select 1 from jsonb_array_elements(calendar->'items') x where x->>'id'=sid::text and (x->>'has_result')::boolean)
  then raise exception 'No ofrece acceso al resultado autorizado';end if;
 begin
  perform public.get_trainer_shared_workout_result(b,gen_random_uuid(),sid);
  raise exception 'Consulta otro alumno';exception when insufficient_privilege then null;end;
 begin
  perform public.get_trainer_shared_workout_result(a,owner,sid);
  raise exception 'Acepta otra identidad';exception when insufficient_privilege then null;end;
 -- El JWT no sustituye el estado MFA de la sesión vigente.
 perform pg_temp.result_identity(b,current_setting('fixture.weak_b')::uuid);
 begin
  perform public.get_trainer_shared_workout_result(b,owner,sid);
  raise exception 'Acepta sesión aal1 con claim elevado';exception when insufficient_privilege then null;end;
 perform pg_temp.result_identity(b,gen_random_uuid());
 begin
  perform public.get_trainer_shared_workout_result(b,owner,sid);
  raise exception 'Acepta sesión revocada';exception when insufficient_privilege then null;end;
 perform pg_temp.result_identity(owner,current_setting('fixture.session')::uuid,'aal1');
 prefs:=public.set_my_trainer_result_sharing(owner,false,revision);
 revision:=(prefs->>'revision')::bigint;
 perform pg_temp.result_identity(b,current_setting('fixture.session_b')::uuid);
 begin
  perform public.get_trainer_shared_workout_result(b,owner,sid);
  raise exception 'Sigue leyendo tras revocación';exception when insufficient_privilege then null;end;
 perform pg_temp.result_identity(owner,current_setting('fixture.session')::uuid,'aal1');
 prefs:=public.set_my_trainer_result_sharing(owner,true,revision);
 prefs:=public.set_my_trainer_calendar_sharing(owner,false,(prefs->>'revision')::bigint);
 if (prefs->>'results_enabled')::boolean then raise exception 'Apagar calendario conserva resultados';end if;
 prefs:=public.set_my_trainer_calendar_sharing(owner,true,(prefs->>'revision')::bigint);
 if (prefs->>'results_enabled')::boolean then raise exception 'Reactivar calendario restaura consentimiento';end if;
 prefs:=public.set_my_trainer_result_sharing(owner,true,(prefs->>'revision')::bigint);
 perform public.end_trainer_relation(current_setting('fixture.relation_a')::uuid);
 perform pg_temp.result_identity(a,current_setting('fixture.session_a')::uuid);
 begin
  perform public.get_trainer_shared_workout_result(a,owner,sid);
  raise exception 'Sigue leyendo con vínculo finalizado';exception when insufficient_privilege then null;end;
 perform pg_temp.result_identity(b,current_setting('fixture.session_b')::uuid);
 if public.get_trainer_shared_workout_result(b,owner,sid) is null then raise exception 'Pierde resultado histórico compartido';end if;
end $$;
reset role;
do $$declare owner uuid:=current_setting('fixture.owner')::uuid; relation_b uuid;begin
 select id into relation_b from public.trainer_client_relations where client_id=owner and trainer_id=current_setting('fixture.trainer_b')::uuid;
 perform pg_temp.result_identity(owner,current_setting('fixture.session')::uuid,'aal1');
 perform public.end_trainer_relation(relation_b);
 if (public.get_my_trainer_calendar_sharing(owner)->>'results_enabled')::boolean then raise exception 'El último vínculo deja consentimiento';end if;
 if has_function_privilege('anon','public.get_trainer_shared_workout_result(uuid,uuid,uuid)','EXECUTE')
  or has_function_privilege('authenticated','trainer_private.sport_fields(jsonb,text[])','EXECUTE')
  or has_table_privilege('authenticated','trainer_private.calendar_sharing','UPDATE') then raise exception 'Privilegios excesivos';end if;
end $$;
select 'Resultados compartidos: opt-in, dos preparadores, MFA vivo, revocación y exclusión de notas/medios verificados' as result;
rollback;
