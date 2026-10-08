-- Prueba del contrato histórico y sus permisos. Todos los datos se revierten.
begin;
do $$
<<session_type_test>>
declare
  owner_id uuid := gen_random_uuid();
  stranger_id uuid := gen_random_uuid();
  exercise_id uuid := gen_random_uuid();
  template_id uuid; block_id uuid; item_id uuid; execution_id uuid;
  expected text; format text; formats text[]; position integer;
  saved_name text; saved_version integer; saved_type text; saved_policy text;
begin
  insert into auth.users(id, email) values
    (owner_id, owner_id || '@session-type.example.invalid'),
    (stranger_id, stranger_id || '@session-type.example.invalid');
  insert into public.exercises(id, name, muscle_groups, equipment, difficulty,
    exercise_type, origin, is_public) values
    (exercise_id, 'Ejercicio de clasificación', array['core'], '{}', 'inicial',
      'duración', 'system', true);
  perform set_config('request.jwt.claim.sub', owner_id::text, true);

  foreach expected in array array['running', 'strength', 'mixed'] loop
    insert into public.workout_templates(name, origin, owner_user_id, visibility, status)
      values('Sesión de clasificación', 'user', owner_id, 'private', 'published')
      returning id into template_id;
    formats := case expected
      when 'running' then array['warm_up', 'running', 'cool_down']
      when 'strength' then array['warm_up', 'straight_sets', 'cool_down']
      else array['warm_up', 'running', 'straight_sets', 'cool_down'] end;
    position := 0;
    foreach format in array formats loop
      insert into public.workout_blocks(template_id, order_index, name, format)
        values(template_id, position, 'Bloque', format) returning id into block_id;
      insert into public.workout_items(block_id, exercise_id, order_index)
        values(block_id, exercise_id, 0) returning id into item_id;
      insert into public.workout_sets(item_id, order_index, target_duration_seconds, rest_after_seconds)
        values(item_id, 0, 30, 0);
      position := position + 1;
    end loop;

    set local role authenticated;
    execution_id := public.start_workout_execution(template_id);
    if public.start_workout_execution(template_id) <> execution_id then
      raise exception 'Reanudar duplica la ejecución';
    end if;
    select e.template_name, e.template_version, e.session_type, e.session_type_policy
      into saved_name, saved_version, saved_type, saved_policy
      from public.workout_executions e where e.id = execution_id;
    if saved_type is distinct from expected or saved_policy is distinct from 'block_format_v1' then
      raise exception 'No conserva la clasificación esperada %', expected;
    end if;
    begin
      update public.workout_executions set session_type = 'mixed' where id = execution_id;
      raise exception 'El cliente puede escribir el historial';
    exception when insufficient_privilege then null; end;
    reset role;

    -- Las ediciones actuales no alteran la identidad ni el tipo ya copiados.
    update public.workout_templates set name = 'Otra sesión', version = version + 1
      where id = template_id;
    update public.workout_blocks set format = 'straight_sets'
      where workout_blocks.template_id = session_type_test.template_id;
    if not exists(select 1 from public.workout_executions e where e.id = execution_id
      and e.template_name = saved_name and e.template_version = saved_version
      and e.session_type = expected and e.session_type_policy = 'block_format_v1') then
      raise exception 'La plantilla reinterpreta el historial';
    end if;
    begin
      update public.workout_executions set session_type = null, session_type_policy = null
        where id = execution_id;
      raise exception 'Permite borrar la clasificación';
    exception when others then
      if sqlerrm <> 'El tipo histórico de una ejecución es inmutable.' then raise; end if;
    end;
    begin
      update public.workout_executions set session_type_policy = 'changed' where id = execution_id;
      raise exception 'Permite reescribir la política';
    exception when others then
      if sqlerrm <> 'El tipo histórico de una ejecución es inmutable.' then raise; end if;
    end;
    update public.workout_executions set status = 'abandoned', completed_at = now()
      where id = execution_id;
    set local role authenticated;
    if not exists(select 1 from public.workout_executions e where e.user_id = owner_id
      and e.status <> 'in_progress' and e.session_type = expected and e.id = execution_id) then
      raise exception 'El propietario no puede consultar su tipo';
    end if;
    perform set_config('request.jwt.claim.sub', stranger_id::text, true);
    if exists(select 1 from public.workout_executions e where e.id = execution_id) then
      raise exception 'El tipo expone sesiones ajenas';
    end if;
    begin
      perform public.start_workout_execution(template_id);
      raise exception 'Puede iniciar una plantilla privada ajena';
    exception when others then
      if sqlerrm <> 'Workout template is not accessible' then raise; end if;
    end;
    perform set_config('request.jwt.claim.sub', owner_id::text, true);
    reset role;
    -- Una nueva ejecución usa la definición nueva, sin cambiar la anterior.
    set local role authenticated;
    execution_id := public.start_workout_execution(template_id);
    if (select session_type from public.workout_executions where id = execution_id) <> 'strength' then
      raise exception 'Una sesión nueva no usa los bloques actuales';
    end if;
    reset role;
  end loop;
  if has_function_privilege('anon', 'public.snapshot_workout_execution_session_type()', 'execute')
    or has_function_privilege('authenticated', 'public.snapshot_workout_execution_session_type()', 'execute')
    or has_table_privilege('authenticated', 'public.workout_executions', 'INSERT')
    or has_table_privilege('authenticated', 'public.workout_executions', 'UPDATE') then
    raise exception 'Se amplían permisos del cliente';
  end if;
end $$;
select 'Tipos históricos, reanudación, edición, política inmutable y RLS: OK' as result;
rollback;
