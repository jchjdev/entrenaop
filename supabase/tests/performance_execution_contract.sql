begin;
select set_config('request.jwt.claim.sub',(select user_id::text from public.admin_permissions limit 1),true);

do $$
declare t uuid; b uuid; i uuid; ex uuid; e uuid; s record; p jsonb; r jsonb;
  op uuid; n integer := 0; before_count integer;
begin
  insert into public.workout_templates(name,origin,owner_user_id,visibility,status,version)
    values('Prueba transaccional de mediciones','user',auth.uid(),'private','published',1) returning id into t;
  insert into public.workout_blocks(template_id,order_index,name,format)
    values(t,0,'Mediciones','straight_sets') returning id into b;
  for p in select value from jsonb_array_elements('[
    {"exercise_code":"push_up_standard","measurement":"REPS","target_value":8},
    {"exercise_code":"push_up_standard","measurement":"REPS_IN_TIME","target_value":12,"fixed_duration_seconds":60},
    {"exercise_code":"bench_press_barbell","measurement":"LOAD_REPS","target_value":5,"load_mode":"external_load","external_load_kg":40},
    {"exercise_code":"bench_press_barbell","measurement":"MAX_LOAD","target_value":60,"load_mode":"external_load","external_load_kg":60,"intent":"control"},
    {"exercise_code":"pull_up_pronated","measurement":"REPS","target_value":8,"intent":"control"},
    {"exercise_code":"pull_up_weighted","measurement":"LOAD_REPS","target_value":5,"load_mode":"bodyweight_plus_external","external_load_kg":10,"body_mass_kg":75},
    {"exercise_code":"front_plank_forearms","measurement":"DURATION","target_value":20},
    {"exercise_code":"supinated_flexed_arm_hang","measurement":"DURATION","target_value":15},
    {"exercise_code":"rope_climb","measurement":"TIME_FOR_DISTANCE","target_value":12.25,"fixed_distance_meters":6},
    {"exercise_code":"standing_broad_jump","measurement":"DISTANCE","target_value":2.25},
    {"exercise_code":"countermovement_jump","measurement":"HEIGHT","target_value":0.35},
    {"exercise_code":"shuttle_5_10_5","measurement":"TIME_FOR_COURSE","target_value":9.75}
  ]') loop
    p := jsonb_build_object('schema_version',1,'exercise_version',1,'protocol_key','fixture',
      'protocol_version',1,'setup_key','Montaje de prueba','policy_version','fixture_v1',
      'load_mode','bodyweight','intent','work') || p;
    if not public.valid_performance_prescription(p) then raise exception 'Prescripción inválida %',p; end if;
    select id into ex from public.exercises where training_profile_code=p->>'exercise_code' limit 1;
    insert into public.workout_items(block_id,exercise_id,order_index) values(b,ex,n) returning id into i;
    insert into public.workout_sets(item_id,order_index,performance_prescription)
      values(i,0,p);
    n:=n+1;
  end loop;
  e:=public.start_workout_execution(t);
  if (select count(*) from public.workout_execution_sets where execution_id=e and performance_prescription is not null)<>12 then
    raise exception 'Se pierde la identidad al iniciar'; end if;
  for s in select * from public.workout_execution_sets where execution_id=e loop
    r:=jsonb_build_object('value',(s.performance_prescription->>'target_value')::numeric,
      'technique_valid',true,'conditions_confirmed',true,'tolerated',true,'stop_reason','none');
    op:=gen_random_uuid();
    perform public.complete_performance_set_idempotent(op,s.id,r);
    perform public.complete_performance_set_idempotent(op,s.id,r);
    if (select actual_rir from public.workout_execution_sets where id=s.id) is not null then
      raise exception 'Se ha inventado esfuerzo'; end if;
    perform public.correct_performance_set_result(s.id,'Corrección de prueba',r||'{"technique_valid":false}');
    if not exists(select 1 from public.workout_set_corrections where execution_set_id=s.id
      and previous_result->'performance_result'->>'technique_valid'='true') then raise exception 'Falta auditoría'; end if;
    begin
      update public.workout_execution_sets set performance_prescription=jsonb_set(performance_prescription,'{setup_key}','"Otro"') where id=s.id;
      raise exception 'Acepta modificar la instantánea';
    exception when others then if sqlerrm<>'La tarea de una ejecución es inmutable.' then raise; end if; end;
  end loop;
  select * into s from public.workout_execution_sets where execution_id=e and performance_prescription->>'measurement'='DURATION' limit 1;
  if public.valid_performance_result('{"value":20,"rir":3}',s.performance_prescription) then raise exception 'Acepta RIR isométrico'; end if;
  if public.valid_performance_prescription(s.performance_prescription||'{"measurement":null}') then raise exception 'Acepta modo nulo'; end if;
  if public.valid_performance_result('{"value":"20"}',s.performance_prescription) then raise exception 'Acepta número como texto'; end if;
  if public.valid_performance_result('{"value":20,"technique_valid":"true"}',s.performance_prescription) then raise exception 'Acepta técnica como texto'; end if;
  perform set_config('request.jwt.claim.sub',gen_random_uuid()::text,true);
  begin
    perform public.correct_performance_set_result(s.id,'Intento ajeno','{}');
    raise exception 'Acepta un resultado ajeno';
  exception when insufficient_privilege then null; end;
  if has_function_privilege('anon','public.complete_performance_set_idempotent(uuid,uuid,jsonb)','execute') then
    raise exception 'RPC accesible anónimamente'; end if;
end $$;
select 'Doce mediciones, instantánea, esfuerzo ausente, corrección, reintento y permisos: OK' as result;
rollback;
