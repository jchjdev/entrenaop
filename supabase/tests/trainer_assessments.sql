begin;
set local statement_timeout='45s';
do $$
declare trainer uuid:=gen_random_uuid();pupil uuid:=gen_random_uuid();other uuid:=gen_random_uuid();rel uuid:=gen_random_uuid();
 operation uuid:=gen_random_uuid();delivery uuid:=gen_random_uuid();pending uuid:=gen_random_uuid();start_op uuid:=gen_random_uuid();finish_op uuid:=gen_random_uuid();
 battery uuid;revised uuid;payload jsonb;answers jsonb;j jsonb;old_hash text;before_workouts integer;
 official uuid:=gen_random_uuid();incompatible uuid:=gen_random_uuid();draft uuid:=gen_random_uuid();
 official_battery uuid;official_payload jsonb;program text:='assessment_fixture_'||replace(gen_random_uuid()::text,'-','');
begin
 insert into auth.users(id,email) values(trainer,trainer||'@trainer-assessments.invalid'),(pupil,pupil||'@trainer-assessments.invalid'),(other,other||'@trainer-assessments.invalid');
 insert into auth.mfa_factors(id,user_id,factor_type,status,created_at,updated_at) values(gen_random_uuid(),trainer,'totp','verified',now(),now()),(gen_random_uuid(),other,'totp','verified',now(),now());
 insert into public.admin_permissions(user_id) values(other);
 insert into public.trainer_access(trainer_id,enabled,client_limit,last_reason) values(trainer,true,1,'Fixture pruebas privadas');
 insert into public.trainer_client_relations(id,trainer_id,client_id,accepted_at) values(rel,trainer,pupil,now());
 insert into public.preparation_programs(id,name,kind,enabled) values(program,'Fixture protocolo oficial','internal_assessment',false),
  (program||'_draft','Fixture borrador','internal_assessment',false);
 insert into public.program_assessment_tests(id,program_id,code,group_code,name,unit,better_direction,protocol_notes,category,min_age,max_age,
  mark_step,max_attempts,retry_policy,distance_meters,measurement_protocol) values
  (official,program,'fixture_run','fixture_run','Recorrido oficial de prueba','seconds','lower','Recorre 2000 metros sobre el trazado medido.',
   'both',0,120,0.01,2,'invalid_only',2000,'run_2000m_v1'),
  (incompatible,program,'fixture_age','fixture_age','Protocolo condicionado por edad','seconds','lower','Protocolo exclusivo para este tramo de edad.',
   'both',18,29,0.01,1,'none',null,null),
  (draft,program||'_draft','fixture_draft','fixture_draft','Prueba no publicada','seconds','lower','Protocolo de borrador todavía sin publicar.',
   'both',0,120,0.01,1,'none',null,null);
 update public.preparation_programs set enabled=true where id=program;
 select count(*) into before_workouts from public.workout_executions where user_id=pupil;
 payload:='{"title":"Simulacro privado","tests":[{"id":"run","source":"custom","name":"Recorrido privado","unit":"seconds","direction":"lower","resolution":0.01,"instructions":"Recorre el trazado indicado y registra la marca real.","max_attempts":2,"retry_policy":"invalid_only"}]}'::jsonb;
 answers:='{"run":[{"valid":false},{"valid":true,"value":0}]}'::jsonb;
 perform set_config('request.jwt.claim.sub',trainer::text,true);perform set_config('request.jwt.claims',jsonb_build_object('sub',trainer,'role','authenticated','aal','aal2')::text,true);
 set local role authenticated;
 j:=public.list_trainer_assessment_catalog();
 if not exists(select 1 from jsonb_array_elements(j) t where t->>'official_test_id'=official::text)
  or exists(select 1 from jsonb_array_elements(j) t where t->>'official_test_id' in(incompatible::text,draft::text)) then raise exception 'Catálogo no filtra publicación/contexto';end if;
 official_payload:=jsonb_build_object('title','Batería oficial sin puntuación','tests',jsonb_build_array(
  jsonb_build_object('id','official','source','official','official_test_id',official)));
 official_battery:=public.save_trainer_assessment(gen_random_uuid(),official_payload);
 j:=public.get_trainer_assessment(official_battery)->'content'->'tests'->0;
 if j->>'measurement_protocol'<>'run_2000m_v1' or (j->>'distance_meters')::integer<>2000
  or (j->>'max_attempts')::integer<>2 or j->>'retry_policy'<>'invalid_only'
  or j->'scoring_available'<>'false'::jsonb or j->>'protocol_fingerprint' is null then raise exception 'Snapshot oficial incompleto';end if;
 begin perform public.save_trainer_assessment(gen_random_uuid(),jsonb_set(official_payload,'{tests,0,official_test_id}',to_jsonb(draft)));
  raise exception 'Importa borrador';exception when invalid_parameter_value then null;end;
 begin perform public.save_trainer_assessment(gen_random_uuid(),jsonb_set(official_payload,'{tests,0,official_test_id}',to_jsonb(incompatible)));
  raise exception 'Importa contexto personal sin contrato';exception when invalid_parameter_value then null;end;
 begin perform public.save_trainer_assessment(gen_random_uuid(),jsonb_set(official_payload,'{tests,0,max_attempts}','1'));
  raise exception 'Cliente manipula protocolo oficial';exception when invalid_parameter_value then null;end;
 begin perform public.save_trainer_assessment(gen_random_uuid(),jsonb_set(official_payload,'{tests}',(official_payload->'tests')||jsonb_build_array(
  jsonb_build_object('id','duplicate','source','official','official_test_id',official))));
  raise exception 'Duplica fuente oficial bajo otro ID y multiplica intentos';exception when invalid_parameter_value then null;end;
 battery:=public.save_trainer_assessment(operation,payload);
 if public.save_trainer_assessment(operation,payload)<>battery then raise exception 'Duplica batería en reintento';end if;
 begin perform public.save_trainer_assessment(operation,jsonb_set(payload,'{title}','"Otra"'));raise exception 'Cambia payload';exception when invalid_parameter_value then null;end;
 begin perform public.save_trainer_assessment(gen_random_uuid(),jsonb_set(payload,'{tests,0,max_attempts}','11'));raise exception 'Más de diez intentos';exception when invalid_parameter_value then null;end;
 begin perform public.save_trainer_assessment(gen_random_uuid(),jsonb_set(payload,'{tests,0,resolution}','0'));raise exception 'Resolución cero';exception when invalid_parameter_value then null;end;
 begin perform public.save_trainer_assessment(gen_random_uuid(),payload||'{"trainer_id":"forged"}'::jsonb);raise exception 'Acepta propiedad fabricada';exception when invalid_parameter_value then null;end;
 j:=public.get_trainer_assessment(battery);old_hash:=j->'content'->'tests'->0->>'protocol_fingerprint';
 if old_hash is null or (j->'content'->'tests'->0->>'protocol_version')::integer<>1 then raise exception 'No fija protocolo';end if;
 perform public.assign_trainer_assessment(delivery,rel,battery,current_date);
 perform public.assign_trainer_assessment(delivery,rel,battery,current_date);
 revised:=public.save_trainer_assessment(gen_random_uuid(),jsonb_set(payload,'{tests,0,instructions}','"Otro trazado diferente con nuevas condiciones."'),battery,1);
 if public.get_trainer_assessment(revised)->'content'->'tests'->0->>'protocol_fingerprint'=old_hash then raise exception 'Mismo protocolo tras cambiar condiciones';end if;
 if public.get_trainer_assessment_delivery(delivery)->'battery'->'content'->'tests'->0->>'protocol_fingerprint'<>old_hash then raise exception 'Reinterpreta entrega anterior';end if;
 begin perform public.save_trainer_assessment(gen_random_uuid(),payload,battery,1);raise exception 'Revisa versión obsoleta';exception when serialization_failure then null;end;
 perform public.assign_trainer_assessment(pending,rel,revised,current_date+1);
 j:=public.list_trainer_assessment_events(current_date,current_date+2);
 if jsonb_array_length(j)<>2 or j->0->>'kind'<>'assessment' then raise exception 'Eventos tipados incorrectos';end if;
 perform set_config('request.jwt.claim.sub',other::text,true);perform set_config('request.jwt.claims',jsonb_build_object('sub',other,'role','authenticated','aal','aal2')::text,true);
 if public.list_trainer_assessments()<>'[]'::jsonb then raise exception 'ADMIN lee baterías ajenas';end if;
 begin perform public.get_trainer_assessment_delivery(delivery);raise exception 'ADMIN lee entrega ajena';exception when insufficient_privilege then null;end;
 begin perform public.assign_trainer_assessment(gen_random_uuid(),rel,revised,current_date);raise exception 'Otro asigna';exception when insufficient_privilege then null;end;
 perform set_config('request.jwt.claim.sub',pupil::text,true);perform set_config('request.jwt.claims',jsonb_build_object('sub',pupil,'role','authenticated','aal','aal1')::text,true);
 if jsonb_array_length(public.list_trainer_assessment_deliveries())<>2 then raise exception 'Alumno no recibe entregas';end if;
 begin perform public.write_trainer_assessment(gen_random_uuid(),delivery,0,'start','{"protocols_confirmed":false}');raise exception 'Empieza sin confirmar protocolo';exception when insufficient_privilege then null;end;
 j:=public.write_trainer_assessment(start_op,delivery,0,'start','{"protocols_confirmed":true}');
 if j->>'status'<>'in_progress' or (j->>'revision')::integer<>1 then raise exception 'No inicia circuito';end if;
 perform public.write_trainer_assessment(start_op,delivery,0,'start','{"protocols_confirmed":true}');
 begin perform public.write_trainer_assessment(gen_random_uuid(),delivery,0,'save',answers);raise exception 'Revisión obsoleta';exception when serialization_failure then null;end;
 begin perform public.write_trainer_assessment(gen_random_uuid(),delivery,1,'finish','{}');raise exception 'Cierra incompleto';exception when invalid_parameter_value then null;end;
 begin perform public.write_trainer_assessment(gen_random_uuid(),delivery,1,'save','{"run":[{"valid":false,"value":0}]}');raise exception 'Nulo inventa cero';exception when invalid_parameter_value then null;end;
 begin perform public.write_trainer_assessment(gen_random_uuid(),delivery,1,'save','{"run":[{"valid":true,"value":10},{"valid":false}]}');raise exception 'Repite tras válido';exception when invalid_parameter_value then null;end;
 begin perform public.write_trainer_assessment(gen_random_uuid(),delivery,1,'save','{"run":[{"valid":true,"value":1.001}]}');raise exception 'Redondea resolución';exception when invalid_parameter_value then null;end;
 begin perform public.write_trainer_assessment(gen_random_uuid(),delivery,1,'save','{"other":[{"valid":true,"value":10}]}');raise exception 'Acepta prueba ajena';exception when invalid_parameter_value then null;end;
 perform public.end_trainer_relation(rel);
 if public.get_trainer_assessment_delivery(pending)->>'status'<>'withdrawn' then raise exception 'Baja no retira pendiente';end if;
 begin perform public.write_trainer_assessment(gen_random_uuid(),pending,1,'start','{"protocols_confirmed":true}');raise exception 'Empieza tras baja';exception when insufficient_privilege then null;end;
 j:=public.write_trainer_assessment(finish_op,delivery,1,'finish',answers);
 if j->>'status'<>'completed' then raise exception 'Baja interrumpe prueba iniciada';end if;
 perform public.write_trainer_assessment(finish_op,delivery,1,'finish',answers);
 begin perform public.write_trainer_assessment(gen_random_uuid(),delivery,2,'save',answers);raise exception 'Reescribe prueba cerrada';exception when insufficient_privilege then null;end;
 j:=public.get_trainer_assessment_delivery(delivery);
 if j->'answers'->'run'->0->'value' is not null or j->'answers'->'run'->1->'value'<>'0'::jsonb then raise exception 'Confunde nulo y cero';end if;
 perform set_config('request.jwt.claim.sub',trainer::text,true);perform set_config('request.jwt.claims',jsonb_build_object('sub',trainer,'role','authenticated','aal','aal2')::text,true);
 if public.get_trainer_assessment_delivery(delivery)->>'status'<>'completed' then raise exception 'Baja pierde consulta propia';end if;
 perform set_config('request.jwt.claims',jsonb_build_object('sub',trainer,'role','authenticated','aal','aal1')::text,true);
 begin perform public.list_trainer_assessments();raise exception 'Biblioteca sin MFA';exception when insufficient_privilege then null;end;
 reset role;
 update trainer_private.assessment_limits set version_limit=(select count(*) from trainer_private.assessments where trainer_id=trainer) where trainer_id=trainer;
 perform set_config('request.jwt.claims',jsonb_build_object('sub',trainer,'role','authenticated','aal','aal2')::text,true);
 set local role authenticated;
 begin perform public.save_trainer_assessment(gen_random_uuid(),payload);raise exception 'Ignora cuota configurada de versiones';exception when invalid_parameter_value then null;end;
 if public.save_trainer_assessment(operation,payload)<>battery then raise exception 'Cuota bloquea reintento confirmado';end if;
 reset role;
 if has_table_privilege('authenticated','trainer_private.assessment_deliveries','SELECT')
  or has_table_privilege('authenticated','trainer_private.assessment_protocols','INSERT')
  or has_function_privilege('authenticated','trainer_private.assessment_snapshot(jsonb)','EXECUTE')
  or has_function_privilege('anon','public.list_trainer_assessments()','EXECUTE') then raise exception 'Grants amplían contrato privado';end if;
 if (select count(*) from public.workout_executions where user_id=pupil)<>before_workouts then raise exception 'Crea ejecuciones de entrenamiento ficticias';end if;
 if (select count(*) from trainer_private.assessment_result_revisions where delivery_id=delivery)<>2 then raise exception 'Pierde revisiones de resultados o duplica reintentos';end if;
end $$;
select 'trainer_assessments: OK' as result;
rollback;
