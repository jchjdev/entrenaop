-- Identidades aisladas; RLS real, altas, revisión, duplicado y caducidad.
begin;
do $$
declare u uuid := gen_random_uuid(); a uuid := gen_random_uuid(); other_user uuid := gen_random_uuid(); goal uuid;
begin
  insert into auth.users(id,email) values
    (u,'pro-quota-fixture@example.invalid'),(a,'pro-admin-fixture@example.invalid'),
    (other_user,'pro-other-fixture@example.invalid');
  insert into public.admin_permissions(user_id,reason) values(a,'Administrador ficticio del ensayo');
  perform set_config('test.pro_user',u::text,true);
  perform set_config('test.pro_admin',a::text,true);
  perform set_config('test.pro_other',other_user::text,true);
  perform set_config('request.jwt.claim.sub',u::text,true);
  insert into public.preparation_goals(user_id,program_id,target_date)
    values(u,'fas_periodic_assessment',current_date+90) returning id into goal;
  perform set_config('test.pro_goal',goal::text,true);
  update public.commercial_access_settings set development_manual_access_enabled=false;
end $$;
set local role authenticated;
do $$
declare snapshot jsonb; exercise uuid; template uuid; revised uuid; payload jsonb; detail text; total integer; error_text text;
begin
  snapshot := public.get_my_pro_access();
  if snapshot->>'tier' <> 'free' or (snapshot->>'exercise_limit')::int <> 8
    or (snapshot->>'session_limit')::int <> 4 then raise exception 'Free inicial incorrecto: %',snapshot; end if;
  begin
    insert into public.pro_access_grants(user_id,source,ends_at,reason)
      values(auth.uid(),'development_manual',now()+interval '30 days','Autoasignación');
    raise exception 'El cliente puede concederse Pro';
  exception when insufficient_privilege then null; end;
  begin
    update public.profiles set role='premium' where id=auth.uid();
    raise exception 'El cliente altera role';
  exception when insufficient_privilege then null; end;
  begin
    perform public.admin_set_development_pro_access(auth.uid(),true,30,'Autoasignación');
    raise exception 'Un deportista usa el RPC administrativo';
  exception when insufficient_privilege then null; end;
  for i in 1..8 loop
    exercise := public.create_personal_exercise('Ejercicio '||i,null,null,array['core'],'{}','inicial','repeticiones');
  end loop;
  perform set_config('test.pro_exercise',exercise::text,true);
  begin
    perform public.create_personal_exercise('Noveno ejercicio',null,null,array['core'],'{}','inicial','repeticiones');
    raise exception 'Free permite el noveno ejercicio';
  exception when raise_exception then
    get stacked diagnostics detail = pg_exception_detail;
    if detail is distinct from 'free_exercise_limit' then raise; end if;
  end;
  -- La escritura directa tampoco evita la cuota.
  begin
    insert into public.exercises(name,muscle_groups,equipment,difficulty,exercise_type,is_public,created_by,origin)
      values('Noveno directo',array['core'],'{}','inicial','repeticiones',false,auth.uid(),'user');
    raise exception 'Insert directo evita la cuota';
  exception when raise_exception then
    get stacked diagnostics detail = pg_exception_detail;
    if detail is distinct from 'free_exercise_limit' then raise; end if;
  end;
  payload := jsonb_build_object('name','Sesión personal','blocks',jsonb_build_array(jsonb_build_object(
    'name','Principal','format','straight_sets','rounds',1,'rest_after_seconds',0,
    'exercises',jsonb_build_array(jsonb_build_object('exercise_id',exercise,
      'sets',jsonb_build_array(jsonb_build_object('target_reps',8,'rest_after_seconds',60)))))));
  perform set_config('test.pro_payload',payload::text,true);
  for i in 1..4 loop template := public.create_personal_workout_template(payload); end loop;
  perform set_config('test.pro_template',template::text,true);
  begin
    perform public.create_personal_workout_template(payload);
    raise exception 'Free permite la quinta plantilla';
  exception when raise_exception then
    get stacked diagnostics detail = pg_exception_detail;
    if detail is distinct from 'free_session_limit' then raise; end if;
  end;
  begin
    perform public.duplicate_personal_workout_template(template);
    raise exception 'Duplicar evita la cuota';
  exception when raise_exception then
    get stacked diagnostics detail = pg_exception_detail;
    if detail is distinct from 'free_session_limit' then raise; end if;
  end;
  revised := public.revise_personal_workout_template(template,payload);
  snapshot := public.get_my_pro_access();
  if (snapshot->>'personal_sessions')::int <> 4 then raise exception 'Revisar consume una plaza'; end if;
  perform set_config('test.pro_template',revised::text,true);
  begin
    perform public.revise_personal_workout_template(revised,'{}');
    raise exception 'Revisión inválida aceptada';
  exception when raise_exception then
    get stacked diagnostics error_text = message_text;
    if error_text = 'Revisión inválida aceptada' then raise; end if;
  end;
  if not exists(select 1 from public.workout_templates where id=revised and status <> 'archived') then
    raise exception 'Una revisión fallida archiva lo existente'; end if;
  perform public.update_personal_exercise(exercise,'Ejercicio revisado',null,null,array['core'],'{}','inicial','repeticiones');
  begin
    perform public.preview_adaptive_program_activation(current_setting('test.pro_goal')::uuid,current_date);
    raise exception 'Free accede al algoritmo';
  exception when raise_exception then
    get stacked diagnostics detail = pg_exception_detail;
    if detail is distinct from 'pro_required' then raise; end if;
  end;
  if has_function_privilege('authenticated','public.activate_adaptive_program_pro_base(uuid,date,jsonb)','execute')
    or has_function_privilege('authenticated','public.has_pro_access(uuid)','execute')
    or has_function_privilege('anon','public.get_my_pro_access()','execute') then
    raise exception 'Funciones internas expuestas'; end if;
  perform set_config('request.jwt.claim.sub',current_setting('test.pro_admin'),true);
  if public.get_my_pro_access()->>'tier' <> 'free' then raise exception 'Admin implica Pro'; end if;
  select id into exercise from public.exercises where origin='system' and is_public
    and exercise_type='repeticiones' limit 1;
  payload := jsonb_build_object('name','Sesión administrativa','blocks',jsonb_build_array(jsonb_build_object(
    'name','Principal','format','straight_sets','rounds',1,'rest_after_seconds',0,
    'exercises',jsonb_build_array(jsonb_build_object('exercise_id',exercise,
      'sets',jsonb_build_array(jsonb_build_object('target_reps',8,'rest_after_seconds',60)))))));
  for i in 1..4 loop template := public.create_personal_workout_template(payload); end loop;
  template := public.create_admin_workout_draft(null,payload);
  if not exists(select 1 from public.workout_templates where id=template
    and origin='system' and owner_user_id is null and status='draft') then raise exception 'El borrador oficial nace personal'; end if;
  if (public.get_my_pro_access()->>'personal_sessions')::int <> 4
    or public.get_my_pro_access()->>'tier' <> 'free' then raise exception 'Contenido oficial altera cuotas/derechos personales'; end if;
  begin
    perform public.create_personal_workout_template(payload);
    raise exception 'El contexto administrativo permite nuevas plazas personales';
  exception when raise_exception then
    get stacked diagnostics detail = pg_exception_detail;
    if detail is distinct from 'free_session_limit' then raise; end if;
  end;
  begin
    perform public.admin_find_development_account('pro-quota-fixture@example.invalid');
    raise exception 'Admin gestiona pruebas en un entorno deshabilitado';
  exception when insufficient_privilege then null; end;
end $$;
reset role;
update public.commercial_access_settings set development_manual_access_enabled=true;
set local role authenticated;
do $$
declare snapshot jsonb; exercise uuid; template uuid; revised uuid; detail text;
begin
  snapshot := public.admin_find_development_account('pro-quota-fixture@example.invalid');
  snapshot := public.admin_set_development_pro_access(current_setting('test.pro_user')::uuid,true,30,'Ensayo Pro temporal');
  if snapshot->>'tier' <> 'pro' then raise exception 'Concesión administrativa fallida'; end if;
  perform set_config('request.jwt.claim.sub',current_setting('test.pro_user'),true);
  snapshot := public.get_my_pro_access();
  if snapshot->>'tier' <> 'pro' or snapshot->'exercise_limit' <> 'null'::jsonb then raise exception 'Pro incorrecto'; end if;
  exercise := public.create_personal_exercise('Noveno con Pro',null,null,array['core'],'{}','inicial','repeticiones');
  template := public.duplicate_personal_workout_template(current_setting('test.pro_template')::uuid);
  perform set_config('test.pro_extra_template',template::text,true);
  begin
    perform public.preview_adaptive_program_activation(gen_random_uuid(),current_date);
    raise exception 'Pro accede a una preparación ajena';
  exception when insufficient_privilege then null; end;
  begin
    update public.pro_access_grants set ends_at=now()+interval '365 days' where user_id=auth.uid();
    raise exception 'Pro amplía su vigencia';
  exception when insufficient_privilege then null; end;
  perform set_config('request.jwt.claim.sub',current_setting('test.pro_other'),true);
  if exists(select 1 from public.pro_access_grants) then raise exception 'RLS revela concesiones ajenas'; end if;
end $$;
reset role;
-- Caducidad real, sin cambiar estados comerciales en Flutter.
update public.pro_access_grants set starts_at=now()-interval '2 days', ends_at=now()-interval '1 day'
  where user_id=current_setting('test.pro_user')::uuid;
-- Un programa iniciado conserva la intención de continuidad y sus decisiones.
insert into public.adaptive_program_states(preparation_goal_id,auto_advance,status,continuation_code,message)
  values(current_setting('test.pro_goal')::uuid,true,'training','waiting_results','Programa iniciado');
insert into public.running_week_decisions(user_id,preparation_goal_id,week_start,policy_version,basis,outcome,
  reference_source,reference_record_id,input_snapshot,decision)
  values(current_setting('test.pro_user')::uuid,current_setting('test.pro_goal')::uuid,
    current_date-extract(isodow from current_date)::int+1,'fixture','recent','initial','fixture','fixture','{}','{}');
select set_config('request.jwt.claim.sub',current_setting('test.pro_user'),true);
set local role authenticated;
do $$
declare snapshot jsonb; revised uuid; detail text; previous_state jsonb; summary jsonb;
begin
  snapshot := public.get_my_pro_access();
  if snapshot->>'tier' <> 'free' or (snapshot->>'personal_exercises')::int <> 9
    or (snapshot->>'personal_sessions')::int <> 5 then raise exception 'Caducar destruye recursos o mantiene Pro'; end if;
  select to_jsonb(a) into previous_state from public.adaptive_program_states a
    where preparation_goal_id=current_setting('test.pro_goal')::uuid;
  perform public.advance_adaptive_program(current_setting('test.pro_goal')::uuid);
  summary := public.refresh_adaptive_programs();
  if summary->0->>'status' <> 'paused' or summary->0->>'continuation_code' <> 'pro_required' then
    raise exception 'La continuidad caducada no explica el acceso Pro'; end if;
  if previous_state is distinct from (select to_jsonb(a) from public.adaptive_program_states a
    where preparation_goal_id=current_setting('test.pro_goal')::uuid)
    or (select count(*) from public.running_week_decisions
      where preparation_goal_id=current_setting('test.pro_goal')::uuid) <> 1 then
    raise exception 'Caducar modifica el programa o genera decisiones'; end if;
  revised := public.revise_personal_workout_template(current_setting('test.pro_extra_template')::uuid,current_setting('test.pro_payload')::jsonb);
  if (public.get_my_pro_access()->>'personal_sessions')::int <> 5 then raise exception 'Revisión tras caducar altera plazas'; end if;
  perform public.start_workout_execution(revised);
  begin
    perform public.duplicate_personal_workout_template(revised);
    raise exception 'Caducado crea otra plaza';
  exception when raise_exception then
    get stacked diagnostics detail = pg_exception_detail;
    if detail is distinct from 'free_session_limit' then raise; end if;
  end;
  perform public.archive_personal_workout_template(revised);
  perform public.archive_personal_workout_template(current_setting('test.pro_template')::uuid);
  perform public.create_personal_workout_template(current_setting('test.pro_payload')::jsonb);
  if (public.get_my_pro_access()->>'personal_sessions')::int <> 4 then raise exception 'Archivar no libera una plaza'; end if;
  perform set_config('request.jwt.claim.sub',current_setting('test.pro_admin'),true);
  perform public.admin_set_development_pro_access(current_setting('test.pro_user')::uuid,true,7,'Segundo ensayo');
  perform set_config('request.jwt.claim.sub',current_setting('test.pro_user'),true);
  summary := public.refresh_adaptive_programs();
  if summary->0->>'status' <> 'training' or not exists(select 1 from public.adaptive_program_states
    where preparation_goal_id=current_setting('test.pro_goal')::uuid and auto_advance) then
    raise exception 'Recuperar Pro pierde la continuidad anterior'; end if;
  perform set_config('request.jwt.claim.sub',current_setting('test.pro_admin'),true);
  snapshot := public.admin_set_development_pro_access(current_setting('test.pro_user')::uuid,false,7,'Retirada de ensayo');
  if snapshot->>'tier' <> 'free' then raise exception 'Retirar mantiene Pro'; end if;
end $$;
reset role;
update public.adaptive_program_states set auto_advance=false,status='complete',continuation_code='complete'
  where preparation_goal_id=current_setting('test.pro_goal')::uuid;
select set_config('request.jwt.claim.sub',current_setting('test.pro_user'),true);
set local role authenticated;
do $$ begin
  if public.refresh_adaptive_programs()->0->>'status' <> 'complete' then
    raise exception 'Free convierte un programa terminado en pausado'; end if;
end $$;
reset role;
update public.adaptive_program_states set status='paused',continuation_code='paused',message='Pausa elegida por el usuario'
  where preparation_goal_id=current_setting('test.pro_goal')::uuid;
set local role authenticated;
do $$ declare summary jsonb := public.refresh_adaptive_programs(); begin
  if summary->0->>'continuation_code' <> 'paused' or summary->0->>'message' <> 'Pausa elegida por el usuario' then
    raise exception 'Free sustituye el motivo de una pausa voluntaria'; end if;
end $$;
reset role;
select 'Derechos, RLS, Free 8/4, Pro, revisión, caducidad y administración: OK' as result;
rollback;
