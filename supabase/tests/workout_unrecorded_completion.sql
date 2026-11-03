-- Contrato de cierre declarado: propietario, ámbito, ausencia de resultados,
-- reintentos y conservación del cierre estricto. No deja usuarios ni sesiones.
begin;
do $$
declare
  owner_id uuid := gen_random_uuid(); outsider uuid := gen_random_uuid(); admin_id uuid;
  exercise uuid; template uuid; personal uuid; guide uuid; phased uuid;
  payload jsonb; slot jsonb; phase jsonb; execution uuid; phased_execution uuid;
  result_id uuid; op uuid := gen_random_uuid(); before_sets jsonb; after_sets jsonb;
  closed_at timestamptz; closed_clock timestamptz; effective_template uuid;
begin
  if has_function_privilege('anon', 'public.finish_workout_without_full_recording_idempotent(uuid,uuid,timestamptz,integer)', 'execute')
    or has_function_privilege('anon', 'public.can_finish_workout_without_full_recording(uuid)', 'execute') then
    raise exception 'El cierre está expuesto a anónimos.';
  end if;
  insert into auth.users(id,email) values
    (owner_id, owner_id||'@unrecorded.example.invalid'),
    (outsider, outsider||'@unrecorded.example.invalid');
  insert into public.pro_access_grants(user_id,source,starts_at,ends_at,reason)
    values(owner_id,'development_manual',now(),now()+interval '1 hour','Ensayo de cierres sin registro');
  select user_id into admin_id from public.admin_permissions limit 1;
  select id into exercise from public.exercises where is_public limit 1;
  payload := jsonb_build_object('name','Sesión temporal sin registro','blocks',jsonb_build_array(jsonb_build_object(
    'name','Trabajo','format','straight_sets','rounds',1,'rest_after_seconds',0,
    'exercises',jsonb_build_array(jsonb_build_object('exercise_id',exercise,'sets',jsonb_build_array(
      jsonb_build_object('target_reps',8,'rest_after_seconds',0),
      jsonb_build_object('target_reps',8,'rest_after_seconds',0)
    )))
  )));
  perform set_config('request.jwt.claim.sub',admin_id::text,true);
  perform set_config('request.jwt.claims','{"aal":"aal2"}',true);
  set local role authenticated;
  template := public.create_admin_workout_draft(null,payload);
  perform public.publish_admin_workout_draft(template);
  slot := jsonb_build_object('name','Sesión','template_id',template,'rest','{}'::jsonb);
  phase := jsonb_build_object('name','Trabajo','sessions',jsonb_build_array(slot));
  guide := public.save_guided_program(jsonb_build_object('name','Rutina temporal','mode','guide','phases',jsonb_build_array(phase)));
  perform public.set_guided_program_status(guide,'published');
  phased := public.save_guided_program(jsonb_build_object('name','Fases temporales','mode','phased','phases',
    jsonb_build_array(phase||'{"duration_weeks":2,"instructions":"Confirmar avance"}'::jsonb)));
  perform public.set_guided_program_status(phased,'published');

  perform set_config('request.jwt.claim.sub',owner_id::text,true);
  perform set_config('request.jwt.claims','{"aal":"aal1"}',true);
  perform public.follow_guided_program(guide);
  execution := public.start_guided_program_session(guide,0,0,gen_random_uuid());
  if not public.can_finish_workout_without_full_recording(execution) then raise exception 'No permite la rutina.'; end if;
  select id into result_id from public.workout_execution_sets where execution_id=execution order by set_order limit 1;
  perform public.complete_workout_set(result_id,p_actual_reps=>6);
  select jsonb_agg(to_jsonb(s) order by s.id) into before_sets from public.workout_execution_sets s where s.execution_id=execution;

  perform set_config('request.jwt.claim.sub',outsider::text,true);
  if public.can_finish_workout_without_full_recording(execution) then raise exception 'Se filtra el acceso ajeno.'; end if;
  begin
    perform public.finish_workout_without_full_recording_idempotent(op,execution,now(),60);
    raise exception 'Permitió terminar la sesión ajena.';
  exception when insufficient_privilege then null; end;
  perform set_config('request.jwt.claim.sub','',true);
  begin
    perform public.finish_workout_without_full_recording_idempotent(op,execution,now(),60);
    raise exception 'Permitió terminar sin identidad.';
  exception when insufficient_privilege then null; end;

  perform set_config('request.jwt.claim.sub',owner_id::text,true);
  perform public.finish_workout_without_full_recording_idempotent(op,execution,now(),60);
  perform public.finish_workout_without_full_recording_idempotent(op,execution,now()+interval '1 minute',120);
  if not exists(select 1 from public.workout_executions e where e.id=execution and status='completed'
    and completed_without_full_recording and final_rpe is null and abandonment_reason is null and result_source='manual') then
    raise exception 'El cierre fabrica esfuerzo o abandono.';
  end if;
  select jsonb_agg(to_jsonb(s) order by s.id) into after_sets from public.workout_execution_sets s where s.execution_id=execution;
  if before_sets is distinct from after_sets then raise exception 'El cierre altera resultados o convierte pendientes en realizadas.'; end if;
  select completed_at,performed_at into closed_at,closed_clock from public.workout_executions where id=execution;
  perform public.finish_workout_without_full_recording_idempotent(gen_random_uuid(),execution,now(),120);
  if not exists(select 1 from public.workout_executions e where e.id=execution and completed_at=closed_at and performed_at=closed_clock) then
    raise exception 'Un segundo toque refecha el historial.';
  end if;
  begin
    update public.workout_executions set completed_without_full_recording=false where id=execution;
    raise exception 'El cliente puede alterar el modo de cierre directamente.';
  exception when insufficient_privilege then null; end;

  -- Una repetición nueva sin ningún registro también se puede cerrar.
  execution := public.start_guided_program_session(guide,0,0,gen_random_uuid());
  begin
    perform public.finish_workout_execution(execution,5);
    raise exception 'El cierre normal admitió series pendientes.';
  exception when sqlstate 'P0001' then
    if sqlerrm <> 'Workout execution still has pending sets' then raise; end if;
  end;
  perform public.finish_workout_without_full_recording_idempotent(gen_random_uuid(),execution,now(),60);
  if exists(select 1 from public.workout_execution_sets s where s.execution_id=execution
    and (status<>'pending' or actual_reps is not null or actual_rpe is not null or completed_at is not null)) then
    raise exception 'Inventó datos en una sesión sin registros.';
  end if;
  begin
    perform public.finish_workout_without_full_recording_idempotent(op,execution,now(),60);
    raise exception 'Reutilizó la operación para otra sesión.';
  exception when invalid_parameter_value then null; end;

  -- La misma interfaz distingue plantilla pública, personal, fases y algoritmo.
  execution := public.start_workout_execution(template);
  if not public.can_finish_workout_without_full_recording(execution) then raise exception 'No permite la sesión suelta del catálogo.'; end if;
  select id into result_id from public.workout_execution_sets where execution_id=execution order by set_order limit 1;
  perform public.skip_workout_set(result_id);
  perform public.finish_workout_without_full_recording_idempotent(gen_random_uuid(),execution,now(),60);
  if (select count(*) from public.workout_execution_sets s where s.execution_id=execution and status='skipped')<>1
    or (select count(*) from public.workout_execution_sets s where s.execution_id=execution and status='pending')<>1 then
    raise exception 'Confunde una serie omitida con otra sin registrar.';
  end if;
  personal := public.create_personal_workout_template(payload);
  execution := public.start_workout_execution(personal);
  if not public.can_finish_workout_without_full_recording(execution) then raise exception 'No permite la sesión personal.'; end if;
  perform public.finish_workout_without_full_recording_idempotent(gen_random_uuid(),execution,now(),60);

  perform public.follow_guided_program(phased);
  phased_execution := public.start_guided_program_session(phased,0,0,gen_random_uuid());
  if public.can_finish_workout_without_full_recording(phased_execution) then raise exception 'Permite cerrar sin registros un programa por fases.'; end if;
  begin
    perform public.finish_workout_without_full_recording_idempotent(gen_random_uuid(),phased_execution,now(),60);
    raise exception 'El servidor admitió el programa por fases.';
  exception when insufficient_privilege then null; end;
  perform public.abandon_workout_execution(phased_execution,'other');

  execution := public.start_guided_program_session(guide,0,0,gen_random_uuid());
  select template_id into effective_template from public.workout_executions where id=execution;
  perform public.abandon_workout_execution(execution,'other');
  execution := public.start_workout_execution(effective_template);
  if public.can_finish_workout_without_full_recording(execution) then raise exception 'El origen algorithm sin programa obtiene el permiso.'; end if;
  begin
    perform public.finish_workout_without_full_recording_idempotent(gen_random_uuid(),execution,now(),60);
    raise exception 'El servidor admitió la ejecución algorithm sin programa.';
  exception when insufficient_privilege then null; end;
  perform public.abandon_workout_execution(execution,'other');

  -- Una pauta protegida mantiene su contrato aunque reutilizase una plantilla pública.
  execution := public.start_workout_execution(template);
  reset role;
  insert into public.scheduled_workouts(user_id,template_id,template_name,template_version,scheduled_date,source,execution_id,status)
    values(owner_id,template,'Ensayo protegido',1,current_date,'coach',execution,'in_progress');
  set local role authenticated;
  if public.can_finish_workout_without_full_recording(execution) then raise exception 'La pauta del preparador obtiene el permiso.'; end if;
  begin
    perform public.finish_workout_without_full_recording_idempotent(gen_random_uuid(),execution,now(),60);
    raise exception 'El servidor admitió una pauta protegida.';
  exception when insufficient_privilege then null; end;

  -- Una cuenta Free puede cerrar su sesión personal sin consumir derechos Pro.
  perform set_config('request.jwt.claim.sub',outsider::text,true);
  personal := public.create_personal_workout_template(payload);
  execution := public.start_workout_execution(personal);
  perform public.finish_workout_without_full_recording_idempotent(gen_random_uuid(),execution,now(),60);
  if not exists(select 1 from public.workout_executions e where e.id=execution and status='completed'
    and completed_without_full_recording and final_rpe is null) then
    raise exception 'No permite el cierre personal de Free.';
  end if;
  perform public.follow_guided_program(guide);
  execution := public.start_guided_program_session(guide,0,0,gen_random_uuid());
  perform public.finish_workout_without_full_recording_idempotent(gen_random_uuid(),execution,now(),60);
  if has_table_privilege('authenticated','trainer_private.guided_workout_start_contexts','insert')
    or has_table_privilege('authenticated','trainer_private.guided_workout_start_contexts','select') then
    raise exception 'El cliente puede fabricar o leer el contexto de inicio.';
  end if;
  select template_id into effective_template from public.workout_executions where id=execution;
  begin
    perform public.start_workout_execution(effective_template);
    raise exception 'Una copia antigua de programa elude Pro mediante el inicio directo.';
  exception when sqlstate 'P0001' then
    if sqlerrm <> 'Los programas adaptativos requieren Pro.' then raise; end if;
  end;
  reset role;
  if exists(select 1 from trainer_private.guided_workout_start_contexts) then
    raise exception 'El RPC dejó un contexto de inicio persistente.';
  end if;
end $$;
rollback;
