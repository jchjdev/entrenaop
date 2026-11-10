begin;

do $$
<<expiry_test>>
declare
  owner_id uuid := gen_random_uuid();
  exercise_id uuid := gen_random_uuid();
  template_id uuid;
  block_id uuid;
  item_id uuid;
  schedule_id uuid;
  attempt_id uuid;
  next_id uuid;
  set_id uuid;
  closed_id uuid;
  cutoff timestamptz := statement_timestamp() - interval '24 hours';
begin
  insert into auth.users(id, email) values (owner_id, owner_id || '@expiry.example.invalid');
  insert into public.exercises(id, name, muscle_groups, equipment, difficulty, exercise_type, origin, is_public)
    values (exercise_id, 'Ejercicio de caducidad', array['core'], '{}', 'inicial', 'repeticiones', 'system', true);
  insert into public.workout_templates(name, origin, owner_user_id, visibility, status)
    values ('Caducidad de prueba', 'user', owner_id, 'private', 'published') returning id into template_id;
  insert into public.workout_blocks(template_id, order_index, name, format)
    values (template_id, 0, 'Bloque', 'straight_sets') returning id into block_id;
  insert into public.workout_items(block_id, exercise_id, order_index)
    values (block_id, exercise_id, 0) returning id into item_id;
  insert into public.workout_sets(item_id, order_index, target_reps, rest_after_seconds)
    values (item_id, 0, 8, 0);
  insert into public.scheduled_workouts(user_id, template_id, template_name, template_version, scheduled_date, source)
    values (owner_id, template_id, 'Caducidad de prueba', 1, current_date, 'user') returning id into schedule_id;

  perform set_config('request.jwt.claim.sub', owner_id::text, true);
  set local role authenticated;
  attempt_id := public.start_scheduled_workout(schedule_id);
  select s.id into set_id from public.workout_execution_sets s where s.execution_id = attempt_id;
  perform public.complete_workout_set_idempotent(gen_random_uuid(), set_id, p_actual_reps => 7);
  reset role;

  if workout_private.discard_execution(attempt_id, owner_id, cutoff) is not null then
    raise exception 'Descarta una sesión reciente';
  end if;
  update public.workout_executions set started_at = cutoff - interval '20 days' where id = attempt_id;
  if workout_private.discard_execution(attempt_id, owner_id, cutoff) is not null then
    raise exception 'Ignora una serie registrada recientemente';
  end if;
  update public.workout_execution_sets set completed_at = cutoff where id = set_id;
  insert into public.workout_set_corrections(execution_set_id, user_id, reason, previous_result, corrected_result)
    values (set_id, owner_id, 'Corrección reciente', '{}', '{}');
  if workout_private.discard_execution(attempt_id, owner_id, cutoff) is not null then
    raise exception 'Ignora una corrección registrada recientemente';
  end if;
  update public.workout_set_corrections set corrected_at = cutoff where execution_set_id = set_id;
  if workout_private.discard_execution(attempt_id, owner_id, cutoff) is null then
    raise exception 'La ejecución sigue abierta tras 24 horas de inactividad';
  end if;
  if exists(select 1 from public.workout_executions e where e.id = attempt_id)
    or exists(select 1 from public.workout_execution_sets s where s.id = set_id)
    or exists(select 1 from public.workout_set_corrections c where c.execution_set_id = set_id)
    or exists(select 1 from public.workout_mutation_receipts r where r.resource_id in (attempt_id, set_id)) then
    raise exception 'Conserva datos deportivos del intento caducado';
  end if;
  if workout_private.discard_execution(attempt_id, owner_id, cutoff) is not null then
    raise exception 'Vuelve a contar un descarte ya realizado';
  end if;
  if not exists(select 1 from public.scheduled_workouts s where s.id = schedule_id
    and s.status = 'planned' and s.execution_id is null and s.template_id = expiry_test.template_id) then
    raise exception 'No devuelve la cita original a pendiente';
  end if;

  set local role authenticated;
  if not public.get_discarded_workout_resource_ids(array[attempt_id, set_id]) @> array[attempt_id, set_id] then
    raise exception 'No permite limpiar una cola local antigua';
  end if;
  next_id := public.start_scheduled_workout(schedule_id);
  if next_id = attempt_id or not exists(select 1 from public.workout_execution_sets s
    where s.execution_id = next_id and s.status = 'pending' and s.actual_reps is null) then
    raise exception 'La siguiente ejecución hereda datos del intento caducado';
  end if;
  closed_id := next_id;
  reset role;
  update public.workout_executions set started_at = cutoff - interval '20 days',
    status = 'completed', completed_at = cutoff - interval '20 days' where id = closed_id;
  if workout_private.discard_execution(closed_id, owner_id, cutoff) is not null then
    raise exception 'Caduca una sesión del historial';
  end if;
  if has_schema_privilege('authenticated', 'workout_private', 'USAGE')
    or has_function_privilege('authenticated', 'workout_private.discard_execution(uuid,uuid,timestamptz)', 'EXECUTE')
    or has_function_privilege('authenticated', 'workout_private.expire_inactive_executions()', 'EXECUTE') then
    raise exception 'Expone el descarte automático al cliente';
  end if;
end $$;

select 'Caducidad, reinicio limpio, agenda y protección del historial: OK' as result;
rollback;
