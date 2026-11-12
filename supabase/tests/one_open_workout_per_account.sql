begin;

do $$
declare
  athlete uuid := gen_random_uuid();
  other uuid := gen_random_uuid();
  first_template uuid;
  next_template uuid;
  first_execution uuid;
  next_execution uuid;
  scheduled uuid;
  imported_execution uuid;
  exercise uuid;
  block uuid;
  item uuid;
  template uuid;
  detail text;
begin
  insert into auth.users(id, email) values
    (athlete, athlete || '@open-workout.invalid'), (other, other || '@open-workout.invalid');
  insert into public.workout_templates(name, origin, owner_user_id, visibility, status)
    values ('Sesión de ayer', 'user', athlete, 'private', 'published') returning id into first_template;
  insert into public.workout_templates(name, origin, owner_user_id, visibility, status)
    values ('Sesión nueva', 'user', athlete, 'private', 'published') returning id into next_template;
  insert into public.exercises(name, muscle_groups, equipment, difficulty, exercise_type, origin, is_public)
    values ('Ejercicio de sesión abierta', array['core'], '{}', 'inicial', 'repeticiones', 'system', true)
    returning id into exercise;
  foreach template in array array[first_template, next_template] loop
    insert into public.workout_blocks(template_id, order_index, name, format)
      values (template, 0, 'Bloque', 'straight_sets') returning id into block;
    insert into public.workout_items(block_id, exercise_id, order_index)
      values (block, exercise, 0) returning id into item;
    insert into public.workout_sets(item_id, order_index, target_reps, rest_after_seconds)
      values (item, 0, 8, 0);
  end loop;
  insert into public.scheduled_workouts(user_id, template_id, template_name, template_version, scheduled_date, source)
    values (athlete, next_template, 'Sesión nueva', 1, current_date, 'user')
    returning id into scheduled;

  perform set_config('request.jwt.claim.sub', athlete::text, true);
  set local role authenticated;
  first_execution := public.start_workout_execution(first_template);
  set constraints public.one_open_workout_per_account immediate;
  set constraints public.one_open_workout_per_account deferred;
  if public.start_workout_execution(first_template) <> first_execution then
    raise exception 'El reintento no recupera la misma ejecución';
  end if;
  begin
    perform public.start_workout_execution(next_template);
    set constraints public.one_open_workout_per_account immediate;
    raise exception 'Permite abrir dos sesiones';
  exception when sqlstate 'EO001' then
    get stacked diagnostics detail = pg_exception_detail;
    if detail::jsonb->>'id' <> first_execution::text
       or detail::jsonb->>'template_name' <> 'Sesión de ayer' then
      raise exception 'El conflicto no identifica la sesión abierta';
    end if;
  end;
  if (select array_agg(id) from public.get_my_open_workouts()) <> array[first_execution] then
    raise exception 'Inicio no devuelve la ejecución abierta fuera de agenda';
  end if;
  begin
    perform public.start_scheduled_workout(scheduled);
    set constraints public.one_open_workout_per_account immediate;
    raise exception 'La agenda permite abrir una segunda sesión';
  exception when sqlstate 'EO001' then null; end;
  if not exists (select 1 from public.scheduled_workouts s where s.id = scheduled
    and s.status = 'planned' and s.execution_id is null) then
    raise exception 'El conflicto modifica la cita que se intentó iniciar';
  end if;
  perform set_config('request.jwt.claim.sub', other::text, true);
  if exists(select 1 from public.get_my_open_workouts()) then
    raise exception 'Inicio devuelve ejecuciones de otra cuenta';
  end if;

  -- Una importación materializa y cierra el resultado en el mismo RPC.
  reset role;
  perform set_config('request.jwt.claim.sub', athlete::text, true);
  imported_execution := public.start_workout_execution(next_template);
  update public.workout_executions set status = 'completed', completed_at = now()
    where id = imported_execution;
  set constraints public.one_open_workout_per_account immediate;
  set constraints public.one_open_workout_per_account deferred;

  set local role authenticated;
  perform public.discard_workout_execution(first_execution, 'DESCARTAR');
  next_execution := public.start_workout_execution(next_template);
  set constraints public.one_open_workout_per_account immediate;
  if next_execution = imported_execution
     or (select array_agg(id) from public.get_my_open_workouts()) <> array[next_execution] then
    raise exception 'El descarte no libera el inicio siguiente';
  end if;
  reset role;
end $$;

select 'Una sesión abierta, aislamiento, descarte e importación cerrada: OK' as result;
rollback;
