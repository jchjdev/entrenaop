begin;
do $$
<<guided_follow_test>>
declare owner_id uuid:=gen_random_uuid(); outsider uuid:=gen_random_uuid(); admin_id uuid;
  payload jsonb; content jsonb; slot jsonb; phase jsonb; exercise uuid; session uuid; warmup uuid;
  program uuid; follow_id uuid; execution uuid; op uuid:=gen_random_uuid(); second uuid; effective uuid;
  repeated uuid; timed_session uuid; timed_program uuid; timed_execution uuid; result_id uuid;
  timed_operation uuid:=gen_random_uuid(); finish_operation uuid:=gen_random_uuid();
  amrap_session uuid; amrap_program uuid; amrap_execution uuid; running_session uuid; running_program uuid; running_execution uuid;
begin
  insert into auth.users(id,email) values(owner_id,owner_id||'@guided.example.invalid'),(outsider,outsider||'@guided.example.invalid');
  -- Este ensayo combina programas para comprobar sus recetas; la cuota Free se prueba por separado.
  insert into public.pro_access_grants(user_id,source,starts_at,ends_at,reason)
    values(owner_id,'development_manual',now(),now()+interval '1 hour','Recetas guiadas del ensayo transaccional');
  select user_id into admin_id from public.admin_permissions limit 1;
  perform set_config('request.jwt.claim.sub',admin_id::text,true);
  select id into exercise from public.exercises where is_public and id<>'20000000-0000-4000-8000-000000000004' limit 1;
  payload:=jsonb_build_object('name','Sesión guiada temporal','blocks',jsonb_build_array(jsonb_build_object(
    'name','Trabajo','format','straight_sets','rounds',1,'rest_after_seconds',0,
    'exercises',jsonb_build_array(jsonb_build_object('exercise_id',exercise,'sets',jsonb_build_array(
      jsonb_build_object('target_reps',8,'rest_after_seconds',90),jsonb_build_object('target_reps',8,'rest_after_seconds',90)
    )))
  )));
  set local role authenticated;
  session:=public.create_admin_workout_draft(null,payload);perform public.publish_admin_workout_draft(session);
  warmup:=public.save_guided_warmup(payload);
  slot:=jsonb_build_object('name','Sesión A','template_id',session,'warmup_id',warmup,
    'rest',jsonb_build_object('min_seconds',60,'max_seconds',180));
  phase:=jsonb_build_object('name','Preparación','duration_weeks',2,'instructions','Revisa tu trabajo y confirma el avance.',
    'sessions',jsonb_build_array(slot));
  content:=jsonb_build_object('name','Programa de prueba','mode','phased','phases',jsonb_build_array(phase,phase||'{"name":"Desarrollo"}'::jsonb));
  program:=public.save_guided_program(content);perform public.set_guided_program_status(program,'published');
  perform set_config('request.jwt.claim.sub',owner_id::text,true);
  follow_id:=public.follow_guided_program(program);
  if public.follow_guided_program(program)<>follow_id then raise exception 'Seguir duplica el seguimiento.'; end if;
  begin
    perform public.start_guided_program_session(program,1,0,gen_random_uuid());raise exception 'Entrenó una fase futura.';
  exception when sqlstate '22023' then null; end;
  begin
    perform public.start_guided_program_session(program,0,0,gen_random_uuid(),false,300);raise exception 'Aceptó un descanso fuera de límites.';
  exception when sqlstate '22023' then null; end;
  execution:=public.start_guided_program_session(program,0,0,op,true,120);
  if public.start_guided_program_session(program,0,0,op,true,120)<>execution then raise exception 'Un reintento creó otra ejecución.'; end if;
  if public.start_guided_program_session(program,0,0,gen_random_uuid(),false,null)<>execution then raise exception 'Otra pestaña no retomó la sesión.'; end if;
  begin
    perform public.start_guided_program_session(program,0,0,op,false,120);raise exception 'Un reintento cambió los ajustes.';
  exception when sqlstate '22023' then null; end;
  select r.template_id into effective from public.guided_program_runs r where r.execution_id=execution;
  if (select count(*) from public.workout_execution_sets e where e.execution_id=execution and e.block_format='warm_up' and e.status='skipped')<>2 then
    raise exception 'No omite el calentamiento separado.';
  end if;
  if (select count(*) from public.workout_execution_sets e where e.execution_id=execution and e.block_format='straight_sets' and e.rest_after_seconds=120 and e.status='pending')<>2 then
    raise exception 'No conserva el trabajo con el ajuste.';
  end if;
  if exists(select 1 from public.workout_blocks b join public.workout_items i on i.block_id=b.id join public.workout_sets s on s.item_id=i.id
    where b.template_id=session and s.rest_after_seconds<>90) then raise exception 'Modificó la pauta pública.'; end if;
  begin
    perform public.advance_guided_program(follow_id,0);raise exception 'Avanzó con una sesión en curso.';
  exception when sqlstate '22023' then null; end;
  perform set_config('request.jwt.claim.sub',outsider::text,true);
  if exists(select 1 from public.guided_program_follows f where f.id=follow_id) then raise exception 'Se filtra el seguimiento ajeno.'; end if;
  if exists(select 1 from public.guided_program_runs r where r.execution_id=execution) then raise exception 'Se filtran ejecuciones ajenas.'; end if;
  begin
    perform public.advance_guided_program(follow_id,0);raise exception 'Un tercero pudo avanzar.';
  exception when insufficient_privilege then null; end;
  perform set_config('request.jwt.claim.sub',owner_id::text,true);
  for result_id in select e.id from public.workout_execution_sets e where e.execution_id=execution and e.status='pending' loop
    perform public.complete_workout_set_idempotent(gen_random_uuid(),result_id,p_actual_reps=>8,p_actual_load_kg=>40,p_actual_rpe=>7,p_actual_rir=>3);
  end loop;
  perform public.finish_workout_execution_idempotent(finish_operation,execution,7,null,null,null,'manual');
  perform public.finish_workout_execution_idempotent(finish_operation,execution,7,null,null,null,'manual');
  if not exists(select 1 from public.workout_executions e where e.id=execution and e.status='completed' and e.session_type='strength') then
    raise exception 'No termina en el historial habitual del ejecutor.';
  end if;
  perform public.advance_guided_program(follow_id,0);
  perform public.advance_guided_program(follow_id,0);
  if (select f.phase_index from public.guided_program_follows f where f.id=follow_id)<>1 then raise exception 'Confirmar dos veces consumió otra fase.'; end if;
  second:=public.start_guided_program_session(program,1,0,gen_random_uuid(),false,null);
  if second=execution then raise exception 'La siguiente fase reutilizó la ejecución cerrada.'; end if;
  if not exists(select 1 from public.workout_execution_sets e where e.execution_id=second and e.block_format='warm_up' and e.status='pending') then
    raise exception 'No conserva el calentamiento elegido.';
  end if;
  perform public.abandon_workout_execution(second,'other');
  perform public.advance_guided_program(follow_id,1);
  repeated:=public.follow_guided_program(program);
  if repeated=follow_id or not exists(select 1 from public.guided_program_follows f where f.id=follow_id and f.completed_at is not null) then
    raise exception 'Repetir pierde el seguimiento anterior.';
  end if;
  if (select count(*) from public.guided_program_runs r where r.follow_id=guided_follow_test.follow_id)<>2 then
    raise exception 'Repetir pierde ejecuciones anteriores.';
  end if;
  perform set_config('request.jwt.claim.sub',admin_id::text,true);
  payload:=jsonb_set(payload,'{blocks,0,format}','"emom"');
  payload:=jsonb_set(payload,'{blocks,0,rest_after_seconds}','60');
  payload:=jsonb_set(payload,'{blocks,0,exercises,0,sets}',jsonb_build_array(jsonb_build_object('target_reps',8,'rest_after_seconds',0)));
  timed_session:=public.create_admin_workout_draft(null,payload);perform public.publish_admin_workout_draft(timed_session);
  slot:=jsonb_build_object('name','EMOM','template_id',timed_session,'rest','{}'::jsonb);
  content:=jsonb_build_object('name','Guía EMOM temporal','mode','guide','phases',jsonb_build_array(
    jsonb_build_object('name','Trabajo','sessions',jsonb_build_array(slot))));
  timed_program:=public.save_guided_program(content);perform public.set_guided_program_status(timed_program,'published');
  perform set_config('request.jwt.claim.sub',owner_id::text,true);
  perform public.follow_guided_program(timed_program);
  begin
    perform public.start_guided_program_session(timed_program,0,0,gen_random_uuid(),false,120);raise exception 'Un ajuste genérico cambió el EMOM.';
  exception when sqlstate '22023' then null; end;
  timed_execution:=public.start_guided_program_session(timed_program,0,0,timed_operation,false,null);
  if not exists(select 1 from public.workout_execution_sets e where e.execution_id=timed_execution and e.block_format='emom' and e.rest_after_seconds=60 and e.target_reps=8) then
    raise exception 'No conserva el contrato del EMOM.';
  end if;
  perform public.discard_workout_execution(timed_execution,'DESCARTAR');
  begin
    perform public.start_guided_program_session(timed_program,0,0,timed_operation,false,null);raise exception 'Revivió una ejecución descartada con la misma operación.';
  exception when sqlstate '22023' then null; end;
  if public.start_guided_program_session(timed_program,0,0,gen_random_uuid(),false,null)=timed_execution then
    raise exception 'Una sesión descartada no permite empezar de nuevo.';
  end if;
  perform set_config('request.jwt.claim.sub',admin_id::text,true);
  payload:=jsonb_set(payload,'{blocks,0,format}','"amrap"');
  payload:=jsonb_set(payload,'{blocks,0,rest_after_seconds}','0');
  payload:=jsonb_set(payload,'{blocks,0,time_cap_seconds}','120');
  amrap_session:=public.create_admin_workout_draft(null,payload);perform public.publish_admin_workout_draft(amrap_session);
  slot:=jsonb_build_object('name','AMRAP','template_id',amrap_session,'rest','{}'::jsonb);
  content:=jsonb_build_object('name','Guía AMRAP temporal','mode','guide','phases',jsonb_build_array(jsonb_build_object('name','Trabajo','sessions',jsonb_build_array(slot))));
  amrap_program:=public.save_guided_program(content);perform public.set_guided_program_status(amrap_program,'published');
  perform set_config('request.jwt.claim.sub',owner_id::text,true);
  perform public.follow_guided_program(amrap_program);
  amrap_execution:=public.start_guided_program_session(amrap_program,0,0,gen_random_uuid(),false,null);
  perform public.complete_amrap_block_idempotent(gen_random_uuid(),amrap_execution,0,3,null,0);
  perform public.finish_workout_execution(amrap_execution,7,null,null,null,'manual');
  if not exists(select 1 from public.workout_execution_sets e where e.execution_id=amrap_execution and e.block_time_cap_seconds=120) then
    raise exception 'Se perdió el límite temporal AMRAP.';
  end if;
  perform set_config('request.jwt.claim.sub',admin_id::text,true);
  payload:=jsonb_build_object('name','Carrera guiada temporal','blocks',jsonb_build_array(jsonb_build_object(
    'name','Rodaje','format','running','rounds',1,'rest_after_seconds',0,'exercises',jsonb_build_array(jsonb_build_object(
      'exercise_id','20000000-0000-4000-8000-000000000004','sets',jsonb_build_array(jsonb_build_object(
        'target_duration_seconds',300,'target_pace_min_seconds_per_km',360,'target_pace_max_seconds_per_km',400,'rest_after_seconds',0
      ))
    ))
  )));
  running_session:=public.create_admin_workout_draft(null,payload);perform public.publish_admin_workout_draft(running_session);
  slot:=jsonb_build_object('name','Carrera','template_id',running_session,'rest','{}'::jsonb);
  content:=jsonb_build_object('name','Guía carrera temporal','mode','guide','phases',jsonb_build_array(jsonb_build_object('name','Trabajo','sessions',jsonb_build_array(slot))));
  running_program:=public.save_guided_program(content);perform public.set_guided_program_status(running_program,'published');
  perform set_config('request.jwt.claim.sub',owner_id::text,true);
  perform public.follow_guided_program(running_program);
  running_execution:=public.start_guided_program_session(running_program,0,0,gen_random_uuid(),false,null);
  if not exists(select 1 from public.workout_execution_sets e where e.execution_id=running_execution and e.block_format='running'
    and e.target_duration_seconds=300 and e.target_pace_min_seconds_per_km=360 and e.target_pace_max_seconds_per_km=400) then
    raise exception 'La preparación perdió los tramos de carrera.';
  end if;
  if exists(select 1 from public.workout_templates t where t.owner_user_id=owner_id and t.origin='user') then
    raise exception 'La prescripción oficial consume una plaza personal.';
  end if;
  perform set_config('request.jwt.claim.sub',admin_id::text,true);
  perform public.set_guided_program_status(program,'archived');
  perform set_config('request.jwt.claim.sub',owner_id::text,true);
  if not exists(select 1 from public.guided_programs p where p.id=program) then raise exception 'Retirar borra el programa seguido.'; end if;
  reset role;
end $$;
rollback;
