-- Cuota por seguimiento activo, pausa reversible y permisos reales; sin datos permanentes.
begin;
do $$
declare u uuid:=gen_random_uuid(); other_user uuid:=gen_random_uuid(); admin_id uuid:=gen_random_uuid();
  exercise uuid; session uuid; payload jsonb; phase jsonb; programs uuid[]:='{}'; p uuid;
  a uuid; b uuid; c uuid; repeated uuid; execution uuid; operation uuid:=gen_random_uuid();
  detail text; access jsonb; i integer; result_id uuid;
begin
  if has_function_privilege('anon','public.get_my_guided_program_access()','EXECUTE')
    or has_function_privilege('anon','public.set_guided_program_paused(uuid,boolean)','EXECUTE') then
    raise exception 'Acceso anónimo a las RPC de cuota o pausa';
  end if;
  insert into auth.users(id,email) values(u,u||'@guided-quota.example.invalid'),
    (other_user,other_user||'@guided-quota.example.invalid'),(admin_id,admin_id||'@guided-quota.example.invalid');
  insert into public.admin_permissions(user_id,reason) values(admin_id,'Autor de contenido del ensayo');
  perform set_config('request.jwt.claim.sub',admin_id::text,true);
  select id into exercise from public.exercises where is_public and id<>'20000000-0000-4000-8000-000000000004' limit 1;
  payload:=jsonb_build_object('name','Cuota temporal','blocks',jsonb_build_array(jsonb_build_object(
    'name','Trabajo','format','straight_sets','rounds',1,'rest_after_seconds',0,
    'exercises',jsonb_build_array(jsonb_build_object('exercise_id',exercise,'sets',jsonb_build_array(
      jsonb_build_object('target_reps',8,'rest_after_seconds',90)))))));
  set local role authenticated;
  session:=public.create_admin_workout_draft(null,payload); perform public.publish_admin_workout_draft(session);
  phase:=jsonb_build_object('name','Preparación','duration_weeks',2,'instructions','Confirma el avance.',
    'sessions',jsonb_build_array(jsonb_build_object('name','Sesión A','template_id',session)));
  for i in 1..4 loop
    p:=public.save_guided_program(jsonb_build_object('name','Cuota '||i,'mode','phased',
      'phases',jsonb_build_array(phase,phase||'{"name":"Desarrollo"}'::jsonb)));
    perform public.set_guided_program_status(p,'published'); programs:=array_append(programs,p);
  end loop;
  perform set_config('request.jwt.claim.sub',u::text,true);
  access:=public.get_my_guided_program_access();
  if access->>'active_limit'<>'1' or access->>'active_programs'<>'0' then raise exception 'Cuota Free inicial incorrecta'; end if;
  a:=public.follow_guided_program(programs[1]);
  if public.follow_guided_program(programs[1])<>a then raise exception 'Reintento ocupa otra plaza'; end if;
  begin perform public.follow_guided_program(programs[2]); raise exception 'Free inicia dos programas';
  exception when sqlstate 'P0001' then get stacked diagnostics detail=PG_EXCEPTION_DETAIL;
    if detail is distinct from 'free_guided_program_limit' then raise; end if; end;
  perform public.advance_guided_program(a,0);
  perform public.set_guided_program_paused(a,true); perform public.set_guided_program_paused(a,true);
  if public.get_my_guided_program_access()->>'active_programs'<>'0' then raise exception 'Pausar no libera plaza'; end if;
  if not exists(select 1 from public.get_guided_program_catalog(p_followed=>true) where id=programs[1]) then
    raise exception 'El pausado desaparece de Programas iniciados';
  end if;
  if exists(select 1 from public.guided_program_follows where id=a and paused_at is null) then
    raise exception 'El pausado permanece en la consulta de Inicio';
  end if;
  begin perform public.start_guided_program_session(programs[1],1,0,gen_random_uuid()); raise exception 'Entrena por URL estando pausado'; exception when invalid_parameter_value then null; end;
  begin perform public.advance_guided_program(a,1); raise exception 'Avanza estando pausado'; exception when invalid_parameter_value then null; end;
  b:=public.follow_guided_program(programs[2]);
  begin perform public.set_guided_program_paused(a,false); raise exception 'Retomar elude cuota';
  exception when sqlstate 'P0001' then get stacked diagnostics detail=PG_EXCEPTION_DETAIL;
    if detail is distinct from 'free_guided_program_limit' then raise; end if; end;
  begin perform public.follow_guided_program(programs[1]); raise exception 'API antigua elude cuota al retomar';
  exception when sqlstate 'P0001' then get stacked diagnostics detail=PG_EXCEPTION_DETAIL;
    if detail is distinct from 'free_guided_program_limit' then raise; end if; end;
  perform set_config('request.jwt.claim.sub',other_user::text,true);
  if public.get_my_guided_program_access()->>'active_programs'<>'0' then raise exception 'Recuento ajeno filtrado'; end if;
  begin perform public.set_guided_program_paused(a,false); raise exception 'Retoma programa ajeno'; exception when insufficient_privilege then null; end;
  begin update public.guided_program_follows set paused_at=null where id=a; raise exception 'Escritura directa permitida'; exception when insufficient_privilege then null; end;
  perform set_config('request.jwt.claim.sub',u::text,true);
  perform public.set_guided_program_paused(b,true);
  if public.follow_guided_program(programs[1])<>a then raise exception 'Retomar crea un seguimiento'; end if;
  if (select phase_index from public.guided_program_follows where id=a)<>1 then raise exception 'Se pierde la fase al retomar'; end if;
  execution:=public.start_guided_program_session(programs[1],1,0,operation);
  begin perform public.set_guided_program_paused(a,true); raise exception 'Pausa con sesión abierta'; exception when invalid_parameter_value then null; end;
  for result_id in select id from public.workout_execution_sets where execution_id=execution and status='pending' loop
    perform public.complete_workout_set_idempotent(gen_random_uuid(),result_id,p_actual_reps=>8,p_actual_load_kg=>40,p_actual_rpe=>7,p_actual_rir=>3);
  end loop;
  perform public.finish_workout_execution_idempotent(gen_random_uuid(),execution,7,null,null,null,'manual');
  perform public.set_guided_program_paused(a,true);
  if public.start_guided_program_session(programs[1],1,0,operation)<>execution then raise exception 'Reintento tardío pierde la ejecución'; end if;
  if not exists(select 1 from public.workout_executions where id=execution and status='completed') then raise exception 'Pausar pierde historial'; end if;
  perform public.set_guided_program_paused(a,false);
  reset role;
  insert into public.pro_access_grants(user_id,source,starts_at,ends_at,reason)
    values(u,'development_manual',now()-interval '2 days',now()+interval '1 day','Pro del ensayo de programas');
  set local role authenticated;
  perform public.set_guided_program_paused(b,false); c:=public.follow_guided_program(programs[3]);
  access:=public.get_my_guided_program_access();
  if access->>'active_limit' is not null or access->>'active_programs'<>'3' then raise exception 'Pro no permite varios programas'; end if;
  reset role;
  update public.pro_access_grants set ends_at=now()-interval '1 second' where user_id=u;
  set local role authenticated;
  if public.follow_guided_program(programs[1])<>a then raise exception 'La bajada de Pro bloquea los existentes'; end if;
  execution:=public.start_guided_program_session(programs[3],0,0,gen_random_uuid());
  for result_id in select id from public.workout_execution_sets where execution_id=execution and status='pending' loop
    perform public.complete_workout_set_idempotent(gen_random_uuid(),result_id,p_actual_reps=>8,p_actual_load_kg=>40,p_actual_rpe=>7,p_actual_rir=>3);
  end loop;
  perform public.finish_workout_execution_idempotent(gen_random_uuid(),execution,7,null,null,null,'manual');
  begin perform public.follow_guided_program(programs[4]); raise exception 'Tras caducar Pro se amplía la cuota';
  exception when sqlstate 'P0001' then get stacked diagnostics detail=PG_EXCEPTION_DETAIL;
    if detail is distinct from 'free_guided_program_limit' then raise; end if; end;
  perform public.set_guided_program_paused(b,true); perform public.set_guided_program_paused(c,true);
  perform public.set_guided_program_paused(a,true);
  perform public.abandon_guided_program(a);
  if not exists(select 1 from public.guided_program_follows where id=a and abandoned_at is not null and paused_at is null) then raise exception 'No permite dejar un programa pausado'; end if;
  repeated:=public.follow_guided_program(programs[1]);
  if repeated=a then raise exception 'Abandonar deja de significar reinicio'; end if;
  perform public.advance_guided_program(repeated,0); perform public.advance_guided_program(repeated,1);
  if public.get_my_guided_program_access()->>'active_programs'<>'0' then raise exception 'Completar no libera plaza'; end if;
  begin perform public.set_guided_program_paused(repeated,true); raise exception 'Pausa un seguimiento completado'; exception when invalid_parameter_value then null; end;
  begin perform public.set_guided_program_paused(a,false); raise exception 'Retoma un seguimiento abandonado'; exception when invalid_parameter_value then null; end;
  if public.get_my_pro_access()->>'personal_sessions'<>'0' then raise exception 'Sesiones guiadas consumen cuota personal'; end if;
  perform set_config('request.jwt.claim.sub','',true);
  begin perform public.get_my_guided_program_access(); raise exception 'Sin sesión consulta acceso'; exception when insufficient_privilege then null; end;
  reset role;
end $$;
select 'Programas Free/Pro, pausa, reanudación, continuidad y permisos: OK' as result;
rollback;
