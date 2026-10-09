-- Solo cuentas y sesiones ficticias. No deja datos ni descarta sesiones reales.
begin;
do $$
<<discard_test>>
declare
  owner_id uuid := gen_random_uuid();
  stranger_id uuid := gen_random_uuid();
  exercise_id uuid := gen_random_uuid();
  template_id uuid; block_id uuid; item_id uuid; schedule_id uuid;
  execution_id uuid; next_execution uuid; completed_id uuid; abandoned_id uuid;
  first_set uuid; second_set uuid; operation_id uuid := gen_random_uuid();
  resources uuid[]; retry_resources uuid[];
  goal_id uuid; source_kind text;
begin
  insert into auth.users(id,email) values
    (owner_id,owner_id||'@discard.example.invalid'),
    (stranger_id,stranger_id||'@discard.example.invalid');
  insert into public.exercises(id,name,muscle_groups,equipment,difficulty,exercise_type,origin,is_public)
    values(exercise_id,'Ejercicio de descarte',array['core'],'{}','inicial','repeticiones','system',true);
  insert into public.workout_templates(name,origin,owner_user_id,visibility,status)
    values('Sesión de descarte','user',owner_id,'private','published') returning id into template_id;
  insert into public.workout_blocks(template_id,order_index,name,format)
    values(template_id,0,'Bloque de prueba','straight_sets') returning id into block_id;
  insert into public.workout_items(block_id,exercise_id,order_index)
    values(block_id,exercise_id,0) returning id into item_id;
  insert into public.workout_sets(item_id,order_index,target_reps,rest_after_seconds)
    values(item_id,0,8,0),(item_id,1,8,0);
  insert into public.scheduled_workouts(user_id,template_id,template_name,template_version,scheduled_date,source)
    values(owner_id,template_id,'Sesión de descarte',1,current_date,'user') returning id into schedule_id;
  perform set_config('request.jwt.claim.sub',owner_id::text,true);
  set local role authenticated;
  execution_id := public.start_scheduled_workout(schedule_id);
  select id into first_set from public.workout_execution_sets where workout_execution_sets.execution_id=discard_test.execution_id order by set_order limit 1;
  select id into second_set from public.workout_execution_sets where workout_execution_sets.execution_id=discard_test.execution_id order by set_order desc limit 1;
  perform public.complete_workout_set_idempotent(operation_id,first_set,p_actual_reps=>7);
  perform public.skip_workout_set(second_set);
  reset role;
  -- Comprueba también el borrado en cascada de registros dependientes.
  insert into public.workout_set_corrections(execution_set_id,user_id,reason,previous_result,corrected_result)
    values(first_set,owner_id,'Corrección de prueba','{}','{}');
  insert into public.workout_amrap_results(execution_id,block_order,completed_rounds)
    values(execution_id,0,1);
  set local role authenticated;
  begin
    perform public.discard_workout_execution(execution_id,'');
    raise exception 'Acepta descartar sin confirmación';
  exception when invalid_parameter_value then null; end;
  perform set_config('request.jwt.claim.sub',stranger_id::text,true);
  begin
    perform public.discard_workout_execution(execution_id,'DESCARTAR');
    raise exception 'Descarta una sesión ajena';
  exception when insufficient_privilege then null; end;
  perform set_config('request.jwt.claim.sub',owner_id::text,true);
  resources := public.discard_workout_execution(execution_id,'DESCARTAR');
  retry_resources := public.discard_workout_execution(execution_id,'DESCARTAR');
  if resources is distinct from retry_resources or not (resources @> array[execution_id,first_set,second_set]) then
    raise exception 'No reconoce los reintentos ni todas las series';
  end if;
  if exists(select 1 from public.workout_executions e where e.id=execution_id)
    or exists(select 1 from public.workout_execution_sets s where s.id=any(resources))
    or exists(select 1 from public.workout_set_corrections c where c.execution_set_id=first_set)
    or exists(select 1 from public.workout_amrap_results a where a.execution_id=discard_test.execution_id)
    or exists(select 1 from public.workout_mutation_receipts r where r.resource_id=any(resources)) then
    raise exception 'Conserva resultados descartados';
  end if;
  if not exists(select 1 from public.scheduled_workouts s where s.id=schedule_id and s.status='planned'
      and s.execution_id is null and s.template_id=discard_test.template_id and s.scheduled_date=current_date) then
    raise exception 'Pierde la cita o no vuelve a pendiente';
  end if;
  if not (public.get_discarded_workout_resource_ids(array[first_set,second_set,execution_id,gen_random_uuid()]) @> resources) then
    raise exception 'No reconoce la cola tardía propia';
  end if;
  -- El antiguo recibo no debe convertir un resultado descartado en éxito.
  begin
    perform public.complete_workout_set_idempotent(operation_id,first_set,p_actual_reps=>8);
    raise exception 'Resucita o acepta un resultado descartado';
  exception when others then
    if sqlerrm='Resucita o acepta un resultado descartado' then raise; end if;
  end;
  perform set_config('request.jwt.claim.sub',stranger_id::text,true);
  if cardinality(public.get_discarded_workout_resource_ids(resources))<>0 then
    raise exception 'Expone identificadores descartados de otra cuenta';
  end if;
  begin
    perform public.discard_workout_execution(execution_id,'DESCARTAR');
    raise exception 'Un reintento ajeno obtiene el recibo';
  exception when insufficient_privilege then null; end;
  perform set_config('request.jwt.claim.sub',owner_id::text,true);
  begin
    perform 1 from public.discarded_workout_executions;
    raise exception 'El cliente lee la tabla de descartes';
  exception when insufficient_privilege then null; end;
  next_execution := public.start_scheduled_workout(schedule_id);
  if next_execution=execution_id or (select count(*) from public.workout_execution_sets where workout_execution_sets.execution_id=next_execution and status='pending' and target_reps=8)<>2 then
    raise exception 'No permite reiniciar con la pauta original';
  end if;
  -- Una sesión vacía también se descarta; el calendario se conserva.
  perform public.discard_workout_execution(next_execution,'DESCARTAR');
  completed_id := public.start_workout_execution(template_id);
  reset role;
  update public.workout_executions set status='completed',completed_at=now() where id=completed_id;
  set local role authenticated;
  abandoned_id := public.start_workout_execution(template_id);
  reset role;
  update public.workout_executions set status='abandoned',completed_at=now() where id=abandoned_id;
  set local role authenticated;
  begin
    perform public.discard_workout_execution(completed_id,'DESCARTAR');
    raise exception 'Elimina historial completado';
  exception when invalid_parameter_value then null; end;
  begin
    perform public.discard_workout_execution(abandoned_id,'DESCARTAR');
    raise exception 'Elimina historial abandonado';
  exception when invalid_parameter_value then null; end;
  reset role;
  insert into public.preparation_goals(user_id,program_id,target_date)
    values(owner_id,'armed_forces_troop_entry',current_date+90) returning id into goal_id;
  foreach source_kind in array array['library','preparation','algorithm'] loop
    insert into public.scheduled_workouts(user_id,template_id,template_name,template_version,scheduled_date,source,preparation_goal_id)
      values(owner_id,template_id,'Sesión de descarte',1,current_date+1,source_kind,goal_id) returning id into schedule_id;
    set local role authenticated;
    next_execution := public.start_scheduled_workout(schedule_id);
    perform public.discard_workout_execution(next_execution,'DESCARTAR');
    if not exists(select 1 from public.scheduled_workouts s where s.id=schedule_id and s.status='planned'
      and s.execution_id is null and s.preparation_goal_id=goal_id and s.source=source_kind and s.template_id=discard_test.template_id) then
      raise exception 'Pierde preparación o pauta de una sesión %',source_kind;
    end if;
    reset role;
  end loop;
  set local role authenticated;
  perform set_config('request.jwt.claim.sub','',true);
  begin
    perform public.discard_workout_execution(completed_id,'DESCARTAR');
    raise exception 'Descarta sin identidad';
  exception when insufficient_privilege then null; end;
  reset role;
  if has_function_privilege('anon','public.discard_workout_execution(uuid,text)','execute')
    or has_function_privilege('anon','public.get_discarded_workout_resource_ids(uuid[])','execute')
    or has_table_privilege('authenticated','public.discarded_workout_executions','SELECT')
    or has_table_privilege('authenticated','public.discarded_workout_executions','INSERT')
    or has_table_privilege('authenticated','public.workout_executions','DELETE') then
    raise exception 'Amplía permisos directos del cliente';
  end if;
end $$;
select 'Descarte propio, confirmación, cascadas, agenda, historial protegido y reintentos: OK' as result;
rollback;
