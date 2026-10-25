begin;
set local statement_timeout='60s';
do $$
declare trainer uuid:=gen_random_uuid(); pupil uuid:=gen_random_uuid(); colleague uuid:=gen_random_uuid(); outsider uuid:=gen_random_uuid();
 second_pupil uuid:=gen_random_uuid(); relation uuid:=gen_random_uuid(); other_relation uuid:=gen_random_uuid(); second_relation uuid:=gen_random_uuid();
 operation uuid:=gen_random_uuid(); battery uuid; other_battery uuid; changed_battery uuid; p_run uuid; p_reps uuid; other_protocol uuid;
 delivery uuid:=gen_random_uuid(); template uuid; exercise uuid; assignment uuid; idx integer; j jsonb; payload jsonb; protocols jsonb; a jsonb; b jsonb;
 last_date date; last_id uuid; original_hash text;
begin
 insert into auth.users(id,email) values(trainer,trainer||'@client-goals.invalid'),(pupil,pupil||'@client-goals.invalid'),
  (colleague,colleague||'@client-goals.invalid'),(outsider,outsider||'@client-goals.invalid'),(second_pupil,second_pupil||'@client-goals.invalid');
 insert into auth.mfa_factors(id,user_id,factor_type,status,created_at,updated_at) values
  (gen_random_uuid(),trainer,'totp','verified',now(),now()),(gen_random_uuid(),colleague,'totp','verified',now(),now()),(gen_random_uuid(),outsider,'totp','verified',now(),now());
 insert into public.admin_permissions(user_id) values(outsider);
 insert into public.trainer_access(trainer_id,enabled,client_limit,last_reason) values(trainer,true,2,'Contrato objetivos'),(colleague,true,1,'Contrato aislamiento');
 insert into public.trainer_client_relations(id,trainer_id,client_id,accepted_at) values
  (relation,trainer,pupil,now()),(other_relation,colleague,pupil,now()),(second_relation,trainer,second_pupil,now());
 payload:='{"title":"Evaluación de acceso","tests":[{"id":"run","source":"custom","name":"Carrera medida","unit":"seconds","direction":"lower","resolution":0.01,"instructions":"Recorre 1000 metros en el trazado medido.","max_attempts":2,"retry_policy":"always"},{"id":"pull","source":"custom","name":"Dominadas estrictas","unit":"repetitions","direction":"higher","resolution":1,"instructions":"Completa las repeticiones con extensión completa.","max_attempts":1,"retry_policy":"none"}]}'::jsonb;
 perform set_config('request.jwt.claim.sub',trainer::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',trainer,'role','authenticated','aal','aal2')::text,true);
 set local role authenticated;
 if (public.get_trainer_client_goal(trainer,pupil)->>'revision')::integer<>0 then raise exception 'Objetivo inicial no vacío';end if;
 battery:=public.save_trainer_assessment(gen_random_uuid(),payload);
 protocols:=public.list_trainer_goal_protocols(trainer);
 select (x->>'protocol_id')::uuid into p_run from jsonb_array_elements(protocols) x where x->>'name'='Carrera medida';
 select (x->>'protocol_id')::uuid into p_reps from jsonb_array_elements(protocols) x where x->>'name'='Dominadas estrictas';
 if p_run is null or p_reps is null then raise exception 'No reutiliza protocolos guardados';end if;
 payload:=jsonb_build_object('title','Policía Nacional 2027','target_date','2027-04-25','targets',jsonb_build_array(
  jsonb_build_object('protocol_id',p_run,'value',90.12),jsonb_build_object('protocol_id',p_reps,'value',10)));
 if public.save_trainer_client_goal(trainer,operation,pupil,0,payload)<>1
  or public.save_trainer_client_goal(trainer,operation,pupil,0,payload)<>1 then raise exception 'Reintento duplica objetivo';end if;
 begin perform public.save_trainer_client_goal(trainer,operation,pupil,0,jsonb_set(payload,'{title}','"Otro objetivo"'));raise exception 'Permite cambiar contenido de operación';exception when invalid_parameter_value then null;end;
 begin perform public.save_trainer_client_goal(trainer,gen_random_uuid(),pupil,0,payload);raise exception 'Sobrescribe revisión anterior';exception when serialization_failure then null;end;
 begin perform public.save_trainer_client_goal(trainer,gen_random_uuid(),pupil,1,jsonb_set(payload,'{targets,0,value}','90.123'));raise exception 'Resolución decimal incorrecta';exception when invalid_parameter_value then null;end;
 begin perform public.save_trainer_client_goal(trainer,gen_random_uuid(),pupil,1,jsonb_set(payload,'{targets,1,value}','1.5'));raise exception 'Repeticiones fraccionadas';exception when invalid_parameter_value then null;end;
 begin perform public.save_trainer_client_goal(trainer,gen_random_uuid(),pupil,1,jsonb_set(payload,'{targets,0,unit}','"repetitions"'));raise exception 'Unidad manipulada';exception when invalid_parameter_value then null;end;
 begin perform public.save_trainer_client_goal(trainer,gen_random_uuid(),pupil,1,jsonb_set(payload,'{target_date}','"2027-02-30"'));raise exception 'Fecha inexistente';exception when invalid_parameter_value then null;end;
 begin perform public.save_trainer_client_goal(trainer,gen_random_uuid(),pupil,1,jsonb_set(payload,'{targets}',(payload->'targets')||jsonb_build_array(payload->'targets'->0)));raise exception 'Meta duplicada';exception when invalid_parameter_value then null;end;
 begin perform public.get_trainer_client_goal(colleague,pupil);raise exception 'Owner obsoleto';exception when insufficient_privilege then null;end;
 begin perform public.list_trainer_client_agenda(colleague,pupil,current_date,current_date);raise exception 'Agenda owner obsoleto';exception when insufficient_privilege then null;end;
 j:=public.get_trainer_client_goal(trainer,pupil);
 if j->'targets'->0->'best'<>'null'::jsonb then raise exception 'Fabrica una marca ausente';end if;
 original_hash:=j->'targets'->0->'protocol'->>'protocol_fingerprint';
 reset role;
 -- La marca más alta del colega y el entrenamiento de otro alumno nunca entran.
 insert into trainer_private.assessment_deliveries(id,trainer_id,client_id,relation_id,assessment_id,scheduled_date,status,started_at,completed_at,answers)
 values(delivery,trainer,pupil,relation,battery,current_date,'completed',now()-interval '1h',now(),'{"run":[{"valid":false},{"valid":true,"value":90.11}],"pull":[{"valid":true,"value":0}]}'::jsonb),
 (gen_random_uuid(),trainer,pupil,relation,battery,current_date,'completed',now()-interval '3 days',now()-interval '2 days','{"run":[{"valid":true,"value":88.22},{"valid":true,"value":89.5}],"pull":[{"valid":true,"value":12}]}'::jsonb),
 (gen_random_uuid(),trainer,pupil,relation,battery,current_date,'in_progress',now(),null,'{"run":[{"valid":true,"value":1}],"pull":[{"valid":true,"value":100}]}'::jsonb),
 (gen_random_uuid(),trainer,second_pupil,second_relation,battery,current_date,'completed',now()-interval '1h',now(),'{"run":[{"valid":true,"value":1}],"pull":[{"valid":true,"value":999}]}'::jsonb);
 perform set_config('request.jwt.claim.sub',colleague::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',colleague,'role','authenticated','aal','aal2')::text,true);
 set local role authenticated;
 if (public.get_trainer_client_goal(colleague,pupil)->>'revision')::integer<>0 then raise exception 'Colega lee objetivo del otro preparador';end if;
 other_battery:=public.save_trainer_assessment(gen_random_uuid(),'{"title":"Otra evaluación","tests":[{"id":"run","source":"custom","name":"Otra carrera","unit":"seconds","direction":"lower","resolution":0.01,"instructions":"Recorre 1000 metros en el trazado medido.","max_attempts":1,"retry_policy":"none"}]}'::jsonb);
 other_protocol:=(public.list_trainer_goal_protocols(colleague)->0->>'protocol_id')::uuid;
 reset role;
 insert into trainer_private.assessment_deliveries(id,trainer_id,client_id,relation_id,assessment_id,scheduled_date,status,started_at,completed_at,answers)
 values(gen_random_uuid(),colleague,pupil,other_relation,other_battery,current_date,'completed',now()-interval '1h',now(),'{"run":[{"valid":true,"value":1}]}'::jsonb);
 perform set_config('request.jwt.claim.sub',trainer::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',trainer,'role','authenticated','aal','aal2')::text,true);
 set local role authenticated;
 begin perform public.save_trainer_client_goal(trainer,gen_random_uuid(),pupil,1,jsonb_set(payload,'{targets,0,protocol_id}',to_jsonb(other_protocol)));raise exception 'Importa protocolo ajeno';exception when insufficient_privilege then null;end;
 j:=public.get_trainer_client_goal(trainer,pupil);
 if (j->'targets'->0->>'best')::numeric<>88.22 or (j->'targets'->1->>'best')::numeric<>12 or not (j->>'history_complete')::boolean
  or (j->>'evaluations_considered')::integer<>2 or (j->'targets'->0->>'latest')::numeric<>90.11
  or (j->'targets'->0->>'previous')::numeric<>88.22 or (j->'targets'->1->>'latest')::numeric<>0
  or (j->'targets'->1->>'previous')::numeric<>12 or (j->'targets'->0->>'latest_at')::timestamptz<>(select now()) then raise exception 'Última marca, anterior y récord se mezclan, inventan o amplían acceso';end if;
 reset role;
 insert into trainer_private.assessment_deliveries(id,trainer_id,client_id,relation_id,assessment_id,scheduled_date,status,started_at,completed_at,answers)
 values(gen_random_uuid(),trainer,pupil,relation,battery,current_date,'completed',now()-interval '1h',now()+interval '1 second','{"run":[{"valid":true,"value":92.21}],"pull":[{"valid":true,"value":8}]}'::jsonb);
 set local role authenticated;
 j:=public.get_trainer_client_goal(trainer,pupil);
 if (j->'targets'->0->>'best')::numeric<>88.22 or (j->'targets'->0->>'latest')::numeric<>92.21
  or (j->'targets'->0->>'previous')::numeric<>90.11 then raise exception 'Un récord antiguo sustituye la evolución más reciente';end if;
 -- Una revisión con condiciones diferentes ya no comparte huella.
 changed_battery:=public.save_trainer_assessment(gen_random_uuid(),'{"title":"Otro trazado","tests":[{"id":"run","source":"custom","name":"Carrera medida","unit":"seconds","direction":"lower","resolution":0.01,"instructions":"Recorre 2000 metros en un trazado distinto.","max_attempts":1,"retry_policy":"none"}]}'::jsonb,battery,1);
 reset role;
 insert into trainer_private.assessment_deliveries(id,trainer_id,client_id,relation_id,assessment_id,scheduled_date,status,started_at,completed_at,answers)
 values(gen_random_uuid(),trainer,pupil,relation,changed_battery,current_date,'completed',now()-interval '1h',now(),'{"run":[{"valid":true,"value":1}]}'::jsonb);
 select id into exercise from public.exercises where is_public and id<>'20000000-0000-4000-8000-000000000004' order by id limit 1;
 set local role authenticated;
 template:=public.save_trainer_workout(gen_random_uuid(),jsonb_build_object('name','Fuerza base','blocks',jsonb_build_array(jsonb_build_object(
  'name','Fuerza','format','straight_sets','rounds',1,'rest_after_seconds',0,'exercises',jsonb_build_array(jsonb_build_object('exercise_id',exercise,'sets',jsonb_build_array(jsonb_build_object('target_reps',8,'rest_after_seconds',90))))))));
 reset role;
 for idx in 1..55 loop
  assignment:=gen_random_uuid();
  insert into public.scheduled_workouts(id,user_id,template_id,template_name,template_version,scheduled_date,source)
   values(assignment,pupil,template,'Fuerza base',1,current_date,'coach');
  insert into public.trainer_assignments(scheduled_id,relation_id,trainer_id,client_id,note) values(assignment,relation,trainer,pupil,'Pauta propia');
 end loop;
 assignment:=gen_random_uuid();
 insert into public.scheduled_workouts(id,user_id,template_id,template_name,template_version,scheduled_date,source)
  values(assignment,second_pupil,template,'Otro alumno',1,current_date,'coach');
 insert into public.trainer_assignments(scheduled_id,relation_id,trainer_id,client_id,note) values(assignment,second_relation,trainer,second_pupil,'No compartir');
 set local role authenticated;
 a:=public.list_trainer_client_agenda(trainer,pupil,current_date,current_date);
 if jsonb_array_length(a->'items')<>50 or not (a->>'has_more')::boolean then raise exception 'Agenda no declara página parcial';end if;
 last_date:=(a->'items'->49->>'scheduled_date')::date;last_id:=(a->'items'->49->>'id')::uuid;
 b:=public.list_trainer_client_agenda(trainer,pupil,current_date,current_date,last_date,last_id);
 if jsonb_array_length(b->'items')<>5 or (b->>'has_more')::boolean
  or exists(select 1 from jsonb_array_elements(a->'items') x join jsonb_array_elements(b->'items') y on x->>'id'=y->>'id')
  or exists(select 1 from jsonb_array_elements(a->'items') x where x->>'note'<>'Pauta propia' or not(x?'planning_revision') or not(x?'result_revision')) then raise exception 'Agenda omite, duplica o amplía información';end if;
 begin perform public.list_trainer_client_agenda(trainer,pupil,current_date,current_date+62);raise exception 'Agenda ilimitada';exception when invalid_parameter_value then null;end;
 -- Más de200 entregas obliga a declarar el historial parcial, sin inventar
 -- un récord total. Se mantiene la meta fijada con la huella anterior.
 reset role;
 for idx in 1..201 loop
  insert into trainer_private.assessment_deliveries(id,trainer_id,client_id,relation_id,assessment_id,scheduled_date,status,started_at,completed_at,answers)
  values(gen_random_uuid(),trainer,pupil,relation,battery,current_date,'completed',now()-interval '1h',now()+interval '1 day'+idx*interval '1microsecond','{"run":[{"valid":false}],"pull":[{"valid":true,"value":0}]}'::jsonb);
 end loop;
 set local role authenticated;
 j:=public.get_trainer_client_goal(trainer,pupil);
 if (j->>'history_complete')::boolean or (j->>'evaluations_considered')::integer<>200
  or j->'targets'->0->'best'<>'null'::jsonb or (j->'targets'->1->>'best')::numeric<>0
  or j->'targets'->0->'latest'<>'null'::jsonb or j->'targets'->0->'latest_at'='null'::jsonb or j->'targets'->0->'previous'<>'null'::jsonb
  or j->'targets'->0->'protocol'->>'protocol_fingerprint'<>original_hash then raise exception 'No fija protocolo o presenta muestra como historial completo';end if;
 perform public.end_trainer_relation(relation);
 if (public.get_trainer_client_goal(trainer,pupil)->>'revision')::integer<>1 or (public.get_trainer_client_goal(trainer,pupil)->>'can_edit')::boolean then raise exception 'Baja pierde objetivo u ofrece edición';end if;
 if jsonb_array_length(public.list_trainer_client_agenda(trainer,pupil,current_date,current_date)->'items')<>50 then raise exception 'Baja pierde agenda histórica';end if;
 begin perform public.save_trainer_client_goal(trainer,gen_random_uuid(),pupil,1,payload);raise exception 'Edita sin vínculo activo';exception when insufficient_privilege then null;end;
 if public.save_trainer_client_goal(trainer,operation,pupil,0,payload)<>1 then raise exception 'No recupera recibo anterior tras baja';end if;
 reset role;
 update public.trainer_access set enabled=false where trainer_id=trainer;
 set local role authenticated;
 if (public.get_trainer_client_goal(trainer,pupil)->>'revision')::integer<>1 or (public.get_trainer_client_goal(trainer,pupil)->>'can_edit')::boolean or (public.get_trainer_client_goal(trainer,second_pupil)->>'can_edit')::boolean then raise exception 'Baja acceso pierde historial propio u ofrece edición';end if;
 begin perform public.save_trainer_client_goal(trainer,gen_random_uuid(),second_pupil,0,payload);raise exception 'Escribe sin acceso profesional';exception when insufficient_privilege then null;end;
 perform set_config('request.jwt.claim.sub',outsider::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',outsider,'role','authenticated','aal','aal2')::text,true);
 begin perform public.get_trainer_client_goal(outsider,pupil);raise exception 'ADMIN lee objetivos ajenos';exception when insufficient_privilege then null;end;
 begin perform public.list_trainer_client_agenda(outsider,pupil,current_date,current_date);raise exception 'ADMIN lee agenda ajena';exception when insufficient_privilege then null;end;
 perform set_config('request.jwt.claim.sub',pupil::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',pupil,'role','authenticated','aal','aal1')::text,true);
 begin perform public.get_trainer_client_goal(pupil,pupil);raise exception 'Alumno lee notas profesionales privadas';exception when insufficient_privilege then null;end;
 perform set_config('request.jwt.claim.sub',trainer::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',trainer,'role','authenticated','aal','aal1')::text,true);
 begin perform public.get_trainer_client_goal(trainer,pupil);raise exception 'Objetivo sin MFA';exception when insufficient_privilege then null;end;
 begin perform public.list_trainer_client_agenda(trainer,pupil,current_date,current_date);raise exception 'Agenda sin MFA';exception when insufficient_privilege then null;end;
 reset role;
 if has_table_privilege('authenticated','trainer_private.client_goal_versions','select')
  or has_function_privilege('anon','public.get_trainer_client_goal(uuid,uuid)','execute') then raise exception 'Grants amplían acceso';end if;
end $$;
select 'trainer_client_goals: OK' as result;
rollback;
