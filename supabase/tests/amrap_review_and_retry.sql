-- Datos ficticios dentro de una transacción; nunca modifica sesiones reales.
begin;
do $$
<<amrap_test>>
declare
  v_owner uuid := gen_random_uuid();
  v_other uuid := gen_random_uuid();
  v_exercise uuid := gen_random_uuid();
  v_template uuid;
  v_block uuid;
  v_item uuid;
  v_execution uuid;
  v_operation uuid;
  v_result public.workout_amrap_results%rowtype;
  v_index integer;
  v_scenario integer;
  v_partial_order integer;
  v_partial_reps integer;
begin
  insert into auth.users(id,email) values
    (v_owner,v_owner||'@amrap.example.invalid'),
    (v_other,v_other||'@amrap.example.invalid');
  insert into public.exercises(id,name,muscle_groups,equipment,difficulty,exercise_type,origin,is_public)
    values(v_exercise,'Movimiento AMRAP de prueba',array['core'],'{}','inicial','repeticiones','system',true);
  insert into public.workout_templates(name,origin,owner_user_id,visibility,status)
    values('Prueba AMRAP','user',v_owner,'private','published') returning id into v_template;
  insert into public.workout_blocks(template_id,order_index,name,format,time_cap_seconds)
    values(v_template,0,'Principal','amrap',600) returning id into v_block;
  for v_index in 0..2 loop
    insert into public.workout_items(block_id,exercise_id,order_index)
      values(v_block,v_exercise,v_index) returning id into v_item;
    insert into public.workout_sets(item_id,order_index,target_reps,rest_after_seconds)
      values(v_item,0,case when v_index=1 then 30 else 10 end,0);
  end loop;

  for v_scenario in 0..3 loop
    perform set_config('request.jwt.claim.sub',v_owner::text,true);
    set local role authenticated;
    v_execution := public.start_workout_execution(v_template);
    -- Un parcial igual al objetivo y otro ejercicio ajeno se rechazan sin
    -- completar ni insertar el bloque. También se validan nulos explícitos.
    begin
      perform public.complete_amrap_block_idempotent(gen_random_uuid(),v_execution,0,5,2,10);
      raise exception 'Acepta un parcial completo';
    exception when invalid_parameter_value then null; end;
    begin
      perform public.complete_amrap_block_idempotent(gen_random_uuid(),v_execution,0,5,99,4);
      raise exception 'Acepta un movimiento inexistente';
    exception when invalid_parameter_value then null; end;
    begin
      perform public.complete_amrap_block_idempotent(gen_random_uuid(),v_execution,0,null,null,0);
      raise exception 'Acepta vueltas nulas';
    exception when invalid_parameter_value then null; end;
    if exists(select 1 from public.workout_amrap_results a where a.execution_id=v_execution) then
      raise exception 'Un error ha dejado un resultado parcial';
    end if;
    if (select count(*) from public.workout_execution_sets s
        where s.execution_id=v_execution and s.status='pending')<>3
      or exists(select 1 from public.workout_mutation_receipts r where r.resource_id=v_execution) then
      raise exception 'Un rechazo ha completado filas o creado recibos';
    end if;
    perform set_config('request.jwt.claim.sub',v_other::text,true);
    begin
      perform public.complete_amrap_block_idempotent(gen_random_uuid(),v_execution,0,5,2,4);
      raise exception 'Permite guardar en otra cuenta';
    exception when insufficient_privilege then null; end;
    perform set_config('request.jwt.claim.sub',v_owner::text,true);
    v_operation := gen_random_uuid();
    -- El cuarto caso reproduce la captura del iPhone: segundo ejercicio, 13/30.
    v_partial_order := case when v_scenario=2 then 0 when v_scenario=3 then 1 else 2 end;
    v_partial_reps := case when v_scenario=0 then 4 when v_scenario=3 then 13 else 0 end;
    perform public.complete_amrap_block_idempotent(v_operation,v_execution,0,5,
      v_partial_order,v_partial_reps);
    -- Reintento con el mismo recibo y con otro tras una respuesta perdida.
    perform public.complete_amrap_block_idempotent(v_operation,v_execution,0,5,
      v_partial_order,v_partial_reps);
    perform public.complete_amrap_block_idempotent(gen_random_uuid(),v_execution,0,5,
      v_partial_order,v_partial_reps);
    select a.* into v_result from public.workout_amrap_results a where a.execution_id=v_execution;
    if v_result.completed_rounds<>5 or v_result.partial_reps<>v_partial_reps
      or v_result.partial_item_order is distinct from (case when v_scenario=2 then null else v_partial_order end)
      or (select count(*) from public.workout_amrap_results a where a.execution_id=v_execution)<>1
      or (select count(*) from public.workout_execution_sets s where s.execution_id=v_execution and s.status='completed')<>3 then
      raise exception 'Resultado, parcial o reintento incorrectos';
    end if;
    -- AMRAP resuelve el bloque mediante un agregado manual. Marcar sus filas
    -- como completadas exige la fuente, pero no inventa marcas individuales.
    if exists(select 1 from public.workout_execution_sets s where s.execution_id=v_execution
      and (s.result_source is distinct from 'manual' or s.actual_reps is not null
        or s.actual_duration_seconds is not null or s.actual_distance_meters is not null
        or s.actual_load_kg is not null or s.actual_rpe is not null or s.actual_rir is not null)) then
      raise exception 'Fuente incorrecta o resultados individuales inventados';
    end if;
    begin
      perform public.complete_amrap_block_idempotent(gen_random_uuid(),v_execution,0,6,null,0);
      raise exception 'Sobrescribe un agregado confirmado';
    exception when invalid_parameter_value then null; end;
    begin
      update public.workout_amrap_results set completed_rounds=99 where execution_id=v_execution;
      raise exception 'El cliente puede editar el agregado directamente';
    exception when insufficient_privilege then null; end;
    reset role;
    -- Deja espacio para otra ejecución ficticia de la misma plantilla.
    update public.workout_executions set status='completed',completed_at=now(),final_rpe=5
      where id=v_execution;
  end loop;
end;
$$;
rollback;
