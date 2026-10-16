begin;
select set_config('request.jwt.claim.sub',(select user_id::text from public.admin_permissions limit 1),true);

do $$ declare f jsonb:='{"supported":true,"healthy":true,"adverse":false,"phase":"development","days_left":100,"tolerated_days":8,"recent_days":3,"new_days":6,"growth":1,"has_mark":true}';
 task jsonb; result jsonb; source text;
begin
 if public.adaptive_control_decision_v1(f)->>'action'<>'none' then raise exception 'El paso del tiempo pauta un test sin necesidad'; end if;
 if public.adaptive_control_decision_v1(f||'{"growth":1.25}')->>'action'<>'control' then raise exception 'No revisa transferencia tras cambiar trabajo'; end if;
 if public.adaptive_control_decision_v1(f||'{"growth":1.25,"adverse":true}')->>'action'<>'defer' then raise exception 'Test con dificultad'; end if;
 if public.adaptive_control_decision_v1(f||'{"growth":1.25,"healthy":false}')->>'action'<>'defer' then raise exception 'Test sin salud vigente'; end if;
 if public.adaptive_control_decision_v1(f||'{"growth":1.25,"days_left":7}')->>'action'<>'none' then raise exception 'Test máximo durante puesta a punto'; end if;
 if public.adaptive_control_decision_v1(f||'{"growth":1.25,"target_met":true}')->>'action'<>'none' then raise exception 'Agota al usuario para acreditar otra vez una meta conseguida'; end if;
 if public.adaptive_control_decision_v1(f||'{"phase":"specific","attempt_phase":"development"}')->>'reason'<>'phase_transfer' then raise exception 'No atiende la transición'; end if;
 if public.adaptive_control_decision_v1(f||'{"phase":"specific","attempt_phase":"specific","new_days":1}')->>'action'<>'none' then raise exception 'Repite sin trabajo nuevo'; end if;
 if public.adaptive_control_decision_v1(f||'{"plateau":true,"signature_tried":true}')->>'action'<>'none' then raise exception 'Repite test de la misma meseta'; end if;
 task:='{"policy_version":"adaptive_protocol_control_v1","intent":"control","measurement":"REPS_IN_TIME","fixed_duration_seconds":120}';
 result:='{"value":30,"actual_duration_seconds":120,"technique_valid":true,"conditions_confirmed":true,"tolerated":true,"stop_reason":"none"}';
 if not public.adaptive_control_result_valid_v1(task,result) then raise exception 'Rechaza ventana completa real'; end if;
 if public.adaptive_control_result_valid_v1(task,result||'{"actual_duration_seconds":60}') then raise exception 'Escala una ventana parcial'; end if;
 if public.adaptive_control_result_valid_v1(task,result||'{"technique_valid":false}') then raise exception 'Acredita intento nulo'; end if;
 if public.adaptive_control_result_valid_v1(task,result||'{"stop_reason":"discomfort"}') then raise exception 'Acredita control con molestias'; end if;
 if public.adaptive_control_result_valid_v1(task,result||'{"stop_reason":"time"}') then raise exception 'Una interrupción por disponibilidad se convierte en máximo'; end if;
 if public.adaptive_control_result_valid_v1(task||'{"intent":"work"}',result) then raise exception 'Infiere un máximo desde una serie'; end if;
 if has_function_privilege('authenticated','public.apply_adaptive_protocol_controls_v1(uuid,date,jsonb)','execute')
  or has_function_privilege('anon','public.sync_automatic_running_controls_v1(uuid)','execute') then raise exception 'Expone helpers internos'; end if;
end $$;

-- Publicación, ejecución y reutilización de un control de carrera. Se conserva
-- el registro ordinario estricto y no se insertan puntuaciones/baremos.
do $$ declare u uuid:=auth.uid(); g uuid; a uuid; plan jsonb; p jsonb; task jsonb; e uuid; es record;
 sid uuid; source_set uuid; test_id uuid; before_tests int; wk date:=current_date-extract(isodow from current_date)::int+1;
begin
 insert into public.pro_access_grants(user_id,source,starts_at,ends_at,reason)
 values(u,'development_manual',now()-interval '1 day',now()+interval '1 year','Fixture controles');
 insert into public.preparation_goals(user_id,program_id,target_date) values(u,'fas_periodic_assessment',wk+180) returning id into g;
 if public.running_continuity_observed_v1(g,current_date) then raise exception 'Inventa cuatro semanas de continuidad'; end if;
 update public.profiles set fecha_nacimiento='1996-01-01' where id=u;
 insert into public.fas_periodic_assessments(user_id,preparation_goal_id,catalog_version,category,age_at_assessment,age_band,is_pre_effective_reference,completed_at)
 values(u,g,'es_def_15_2026_periodic_2027_v1','men',30,'26_30',true,now()-interval '7 days') returning id into a;
 insert into public.fas_periodic_marks values(a,'run_2000_m',595000);
 insert into public.running_reference_selections(preparation_goal_id,reference_source,reference_record_id) values(g,'fasPeriodicAssessment',a::text);
 task:='{"schema_version":1,"exercise_code":"running_2000m_v1","exercise_version":1,"protocol_key":"run_2000m_v1","protocol_version":1,"setup_key":"standard:measured_2000m","measurement":"TIME_FOR_DISTANCE","load_mode":"bodyweight","policy_version":"adaptive_protocol_control_v1","target_value":595,"fixed_distance_meters":2000,"intent":"control","effort_mode":"rpe","target_rpe":10}';
 plan:=jsonb_build_object('policy_version','running_2k_v5','basis','recent','outcome','maintain',
  'reference_source','fasPeriodicAssessment','reference_record_id',a,'input_snapshot','{}'::jsonb,'sessions',jsonb_build_array(
   jsonb_build_object('date',wk,'name','Control de 2 km','description','Control con distancia medida','kind','controlled_quality','family','C',
    'minutes',30,'variant_code','CONTROL_2000_v1','control','{"objective_key":"running_2000m_v1","kind":"protocol_test"}'::jsonb,
    'segments',jsonb_build_array(jsonb_build_object('role','warmup','seconds',600),
     jsonb_build_object('role','work','meters',2000,'performance_prescription',task),jsonb_build_object('role','cooldown','seconds',360)))));
 perform public.materialize_running_week_plan(g,wk,plan);
 select rs.scheduled_workout_id into sid from public.running_week_sessions rs join public.scheduled_workouts sw on sw.id=rs.scheduled_workout_id where sw.preparation_goal_id=g;
 e:=public.start_scheduled_workout(sid);
 select id into source_set from public.workout_execution_sets where execution_id=e and performance_prescription is not null;
 for es in select * from public.workout_execution_sets where execution_id=e order by set_order loop
  if es.id=source_set then
   perform public.complete_performance_set_idempotent(gen_random_uuid(),es.id,
    '{"value":570,"rpe":8,"technique_valid":true,"conditions_confirmed":true,"tolerated":true,"stop_reason":"none"}');
  else
   begin
    perform public.complete_workout_set(es.id,p_actual_duration_seconds=>es.target_duration_seconds);
    raise exception 'Un tramo normal acepta distancia desconocida';
   exception when raise_exception then if sqlerrm='Un tramo normal acepta distancia desconocida' then raise; end if; end;
   perform public.complete_workout_set(es.id,p_actual_duration_seconds=>es.target_duration_seconds,p_actual_distance_meters=>1000,p_actual_rpe=>3);
  end if;
 end loop;
 perform public.sync_automatic_running_controls_v1(g);
 if exists(select 1 from public.preparation_running_tests where preparation_goal_id=g) then raise exception 'Reutiliza control antes de cerrar'; end if;
 perform public.finish_workout_observed_idempotent(gen_random_uuid(),e,8,now(),0);
 perform public.sync_automatic_running_controls_v1(g);
 perform public.sync_automatic_running_controls_v1(g);
 select id into test_id from public.preparation_running_tests where source_execution_set_id=source_set;
 if test_id is null or (select count(*) from public.preparation_running_tests where preparation_goal_id=g)<>1 then raise exception 'No guarda control o duplica reintento'; end if;
 p:=public.resolve_program_running_reference(g);
 if p->>'reference_source'<>'trainingControl' or (p->>'value')::numeric<>570000 then raise exception 'No usa el control automático: %',p; end if;
 perform public.correct_performance_set_result(source_set,'Corrijo el cronometraje',
  '{"value":565,"rpe":8,"technique_valid":true,"conditions_confirmed":true,"tolerated":true,"stop_reason":"none"}');
 perform public.sync_automatic_running_controls_v1(g);
 if (public.resolve_program_running_reference(g)->>'value')::numeric<>565000 then raise exception 'No incorpora corrección'; end if;
 perform public.correct_performance_set_result(source_set,'La distancia no era la correcta',
  '{"value":565,"rpe":8,"technique_valid":true,"conditions_confirmed":false,"tolerated":true,"stop_reason":"none"}');
 begin perform public.resolve_program_running_reference(g); raise exception 'Sigue usando control invalidado';
 exception when raise_exception then if sqlerrm='Sigue usando control invalidado' then raise; end if; end;
 perform set_config('request.jwt.claim.sub',gen_random_uuid()::text,true);
 begin perform public.sync_automatic_running_controls_v1(g); raise exception 'Lee preparación ajena'; exception when insufficient_privilege then null; end;
 if public.adaptive_protocol_observations_v1(g)<>'[]'::jsonb then raise exception 'Lee controles ajenos'; end if;
 perform set_config('request.jwt.claim.sub',u::text,true);
end $$;
select 'Decisión por necesidad, protocolo real, carga, registro, referencia, corrección y permisos: OK' result;
rollback;
