begin;
do $$
declare owner_id uuid:=gen_random_uuid(); outsider uuid:=gen_random_uuid(); admin_id uuid;
  exercise uuid; session uuid; program uuid; guide uuid; first_follow uuid; repeated uuid;
  execution uuid; result_id uuid; operation uuid:=gen_random_uuid(); abandoned_time timestamptz;
  payload jsonb; phase jsonb; content jsonb;
begin
  if has_function_privilege('anon','public.abandon_guided_program(uuid)','EXECUTE')
    or not has_function_privilege('authenticated','public.abandon_guided_program(uuid)','EXECUTE') then
    raise exception 'Permisos de abandono incorrectos.';
  end if;
  if has_table_privilege('authenticated','public.guided_program_follows','UPDATE') then
    raise exception 'El cliente puede modificar directamente el seguimiento.';
  end if;
  insert into auth.users(id,email) values(owner_id,owner_id||'@guided-abandon.example.invalid'),
    (outsider,outsider||'@guided-abandon.example.invalid');
  select user_id into admin_id from public.admin_permissions limit 1;
  perform set_config('request.jwt.claim.sub',admin_id::text,true);
  select id into exercise from public.exercises where is_public
    and id<>'20000000-0000-4000-8000-000000000004' limit 1;
  payload:=jsonb_build_object('name','Abandono temporal','blocks',jsonb_build_array(jsonb_build_object(
    'name','Trabajo','format','straight_sets','rounds',1,'rest_after_seconds',0,
    'exercises',jsonb_build_array(jsonb_build_object('exercise_id',exercise,'sets',jsonb_build_array(
      jsonb_build_object('target_reps',8,'rest_after_seconds',90)
    )))
  )));
  set local role authenticated;
  session:=public.create_admin_workout_draft(null,payload);
  perform public.publish_admin_workout_draft(session);
  phase:=jsonb_build_object('name','Base','duration_weeks',2,'instructions','Confirma el avance.',
    'sessions',jsonb_build_array(jsonb_build_object('name','Trabajo','template_id',session,'rest','{}'::jsonb)));
  content:=jsonb_build_object('name','Fases temporales para abandono','mode','phased',
    'phases',jsonb_build_array(phase,phase||'{"name":"Progreso"}'::jsonb));
  program:=public.save_guided_program(content);
  perform public.set_guided_program_status(program,'published');
  content:=jsonb_build_object('name','Rutina temporal para abandono','mode','guide',
    'phases',jsonb_build_array(phase-'duration_weeks'));
  guide:=public.save_guided_program(content);
  perform public.set_guided_program_status(guide,'published');

  perform set_config('request.jwt.claim.sub',owner_id::text,true);
  first_follow:=public.follow_guided_program(program);
  execution:=public.start_guided_program_session(program,0,0,operation);
  begin
    perform public.abandon_guided_program(first_follow);
    raise exception 'Dejó un programa con ejecución abierta.';
  exception when sqlstate '22023' then null; end;
  if exists(select 1 from public.guided_program_follows where id=first_follow and abandoned_at is not null) then
    raise exception 'El fallo cambió el seguimiento.';
  end if;
  perform set_config('request.jwt.claim.sub',outsider::text,true);
  begin
    perform public.abandon_guided_program(first_follow);
    raise exception 'Un tercero abandonó el programa.';
  exception when insufficient_privilege then null; end;
  perform set_config('request.jwt.claim.sub','',true);
  begin
    perform public.abandon_guided_program(first_follow);
    raise exception 'Se abandonó sin usuario.';
  exception when insufficient_privilege then null; end;
  perform set_config('request.jwt.claim.sub',owner_id::text,true);
  for result_id in select id from public.workout_execution_sets where execution_id=execution loop
    perform public.complete_workout_set_idempotent(gen_random_uuid(),result_id,
      p_actual_reps=>8,p_actual_load_kg=>40,p_actual_rpe=>7,p_actual_rir=>3);
  end loop;
  perform public.finish_workout_execution_idempotent(gen_random_uuid(),execution,7,null,null,null,'manual');
  perform public.advance_guided_program(first_follow,0);
  perform public.abandon_guided_program(first_follow);
  select abandoned_at into abandoned_time from public.guided_program_follows
    where id=first_follow and completed_at is null and phase_index=1;
  if abandoned_time is null then raise exception 'Abandono confundido con completar o perdió fase.'; end if;
  perform public.abandon_guided_program(first_follow);
  if (select abandoned_at from public.guided_program_follows where id=first_follow)<>abandoned_time then
    raise exception 'El reintento cambió la fecha de abandono.';
  end if;
  if not exists(select 1 from public.guided_program_runs r join public.workout_execution_sets s
    on s.execution_id=r.execution_id where r.follow_id=first_follow and s.actual_reps=8 and s.actual_load_kg=40) then
    raise exception 'Perdió los resultados del seguimiento abandonado.';
  end if;
  if exists(select 1 from public.get_guided_program_catalog(p_followed=>true) where id=program)
    or exists(select 1 from public.guided_program_follows
      where user_id=owner_id and program_id=program and completed_at is null and abandoned_at is null) then
    raise exception 'El programa abandonado sigue apareciendo como iniciado.';
  end if;
  begin
    perform public.advance_guided_program(first_follow,1);
    raise exception 'Avanzó un seguimiento abandonado.';
  exception when sqlstate '22023' then null; end;
  begin
    perform public.start_guided_program_session(program,1,0,gen_random_uuid());
    raise exception 'Entrenó sin seguimiento activo.';
  exception when insufficient_privilege then null; end;
  if public.start_guided_program_session(program,0,0,operation)<>execution then
    raise exception 'Un reintento histórico creó otra ejecución.';
  end if;

  repeated:=public.follow_guided_program(program);
  if repeated=first_follow or (select phase_index from public.guided_program_follows where id=repeated)<>0 then
    raise exception 'Reiniciar reutilizó el seguimiento abandonado.';
  end if;
  if public.follow_guided_program(program)<>repeated then raise exception 'Reiniciar duplicó el seguimiento activo.'; end if;
  perform public.abandon_guided_program(first_follow);
  if not exists(select 1 from public.guided_program_follows where id=repeated and abandoned_at is null) then
    raise exception 'Un reintento tardío abandonó el seguimiento nuevo.';
  end if;
  execution:=public.start_guided_program_session(program,0,0,gen_random_uuid());
  if not exists(select 1 from public.guided_program_runs where follow_id=repeated and execution_id=execution) then
    raise exception 'El reinicio entrenó sobre un seguimiento antiguo.';
  end if;
  perform public.abandon_workout_execution(execution,'other');
  perform public.advance_guided_program(repeated,0);
  perform public.advance_guided_program(repeated,1);
  if exists(select 1 from public.get_guided_program_catalog(p_followed=>true) where id=program) then
    raise exception 'Un seguimiento completado sigue en la colección activa.';
  end if;
  perform public.abandon_guided_program(repeated);
  if not exists(select 1 from public.guided_program_follows where id=repeated and completed_at is not null and abandoned_at is null) then
    raise exception 'Abandonar convirtió un programa completado en abandonado.';
  end if;
  -- También funciona repetir tras completar aunque existan varios seguimientos históricos.
  repeated:=public.follow_guided_program(program);
  execution:=public.start_guided_program_session(program,0,0,gen_random_uuid());
  if not exists(select 1 from public.guided_program_runs where follow_id=repeated and execution_id=execution) then
    raise exception 'Repetir un completado eligió el seguimiento antiguo.';
  end if;
  perform public.abandon_workout_execution(execution,'other');
  perform public.abandon_guided_program(repeated);

  if exists(select 1 from public.get_guided_program_catalog(p_followed=>true) where id=program) then
    raise exception 'Un seguimiento completado anterior mantiene visible el nuevo abandono.';
  end if;

  -- Una versión retirada sigue siendo legible para su propietario, pero no se reinicia.
  perform set_config('request.jwt.claim.sub',admin_id::text,true);
  perform public.set_guided_program_status(program,'archived');
  perform set_config('request.jwt.claim.sub',owner_id::text,true);
  if not exists(select 1 from public.guided_programs where id=program) then raise exception 'Perdió la versión histórica.'; end if;
  begin
    perform public.follow_guided_program(program); raise exception 'Reinició una versión retirada.';
  exception when sqlstate '22023' then null; end;

  first_follow:=public.follow_guided_program(guide);
  perform public.abandon_guided_program(first_follow);
  if not exists(select 1 from public.guided_program_follows where id=first_follow and abandoned_at is not null) then
    raise exception 'No permite dejar una rutina sin entrenamientos.';
  end if;
  perform set_config('request.jwt.claim.sub',outsider::text,true);
  if exists(select 1 from public.guided_program_follows where user_id=owner_id) then
    raise exception 'Un tercero accede al historial de abandonos.';
  end if;
end $$;
rollback;
