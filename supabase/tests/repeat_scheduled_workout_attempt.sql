begin;

do $test$
declare
  athlete uuid := gen_random_uuid();
  outsider uuid := gen_random_uuid();
  template uuid;
  scheduled uuid;
  another_scheduled uuid;
  original uuid;
  repeat_attempt uuid;
  initial_set uuid;
  initial_source_set uuid;
  closing_set record;
  repetitions integer;
  grant_id uuid;
  access_error text;
begin
  insert into auth.users(id, email) values
    (athlete, athlete || '@repeat-workout.invalid'),
    (outsider, outsider || '@repeat-workout.invalid');
  perform set_config('request.jwt.claim.sub', athlete::text, true);
  set local role authenticated;
  template := public.create_personal_workout_template('{
    "name": "Rodaje de ensayo",
    "blocks": [{"name": "Carrera", "format": "running", "rounds": 1,
      "exercises": [{"exercise_id": "20000000-0000-4000-8000-000000000004",
        "sets": [
          {"target_duration_seconds": 180, "target_pace_min_seconds_per_km": 300,
           "target_pace_max_seconds_per_km": 420,
           "running_step": {"schema_version": 2, "kind": "run", "completion": "time"}},
          {"target_duration_seconds": 120}]}]}]
  }'::jsonb);
  scheduled := public.schedule_workout(template, current_date);
  another_scheduled := public.schedule_workout(template, current_date + 1);
  original := public.start_scheduled_workout(scheduled);
  select id, source_set_id into strict initial_set, initial_source_set
  from public.workout_execution_sets where execution_id = original and set_order = 0;
  perform public.complete_workout_set(initial_set,
    p_actual_duration_seconds => 174, p_actual_distance_meters => 450);
  perform public.abandon_workout_execution(original, 'other');

  reset role;
  update public.workout_sets set target_duration_seconds = 240,
    target_pace_max_seconds_per_km = 480 where id = initial_source_set;
  set local role authenticated;
  perform set_config('request.jwt.claim.sub', outsider::text, true);
  begin
    perform public.repeat_scheduled_workout(athlete, scheduled);
    raise exception 'La repetición aceptó otra cuenta como titular';
  exception when insufficient_privilege then null; end;
  begin
    perform public.repeat_scheduled_workout(outsider, scheduled);
    raise exception 'La repetición aceptó una pauta ajena';
  exception when insufficient_privilege then null; end;
  perform set_config('request.jwt.claim.sub', athlete::text, true);

  begin
    perform public.repeat_scheduled_workout(athlete, another_scheduled);
    raise exception 'Se repitió una pauta sin resultado';
  exception when insufficient_privilege then null; end;
  repeat_attempt := public.repeat_scheduled_workout(athlete, scheduled);
  set constraints public.one_open_workout_per_account immediate;
  if repeat_attempt = original or repeat_attempt <> public.repeat_scheduled_workout(athlete, scheduled) then
    raise exception 'La cita no conserva un único intento abierto nuevo';
  end if;
  if not exists (select 1 from public.scheduled_workouts s where s.id = scheduled
      and s.status = 'abandoned' and s.execution_id = original and s.repeat_execution_id = repeat_attempt) then
    raise exception 'El resultado anterior desaparece durante la repetición';
  end if;
  select count(*) into repetitions from public.workout_execution_sets
  where execution_id = repeat_attempt and status = 'pending' and actual_duration_seconds is null;
  if repetitions <> 2 or not exists (select 1 from public.workout_execution_sets
      where execution_id = repeat_attempt and source_set_id = initial_source_set
      and target_duration_seconds = 180 and target_pace_max_seconds_per_km = 420) then
    raise exception 'Se copiaron resultados reales o se leyó la plantilla editada';
  end if;

  begin
    perform public.start_scheduled_workout(another_scheduled);
    raise exception 'Se asignó el intento a una segunda cita';
  exception when sqlstate 'EO001' then null; end;
  perform public.discard_workout_execution(repeat_attempt, 'DESCARTAR');
  if not exists (select 1 from public.scheduled_workouts s where s.id = scheduled
      and s.status = 'abandoned' and s.execution_id = original and s.repeat_execution_id is null) then
    raise exception 'El descarte de la repetición modificó el resultado anterior';
  end if;

  repeat_attempt := public.repeat_scheduled_workout(athlete, scheduled);
  perform public.abandon_workout_execution(repeat_attempt, 'other');
  if not exists (select 1 from public.scheduled_workouts s where s.id = scheduled
      and s.status = 'abandoned' and s.execution_id = original and s.repeat_execution_id is null)
    or not exists (select 1 from public.workout_executions e where e.id = repeat_attempt and e.status = 'abandoned') then
    raise exception 'El abandono no conserva los dos intentos';
  end if;

  repeat_attempt := public.repeat_scheduled_workout(athlete, scheduled);
  for closing_set in select id, target_duration_seconds
    from public.workout_execution_sets where execution_id = repeat_attempt order by set_order
  loop
    perform public.complete_workout_set(closing_set.id,
      p_actual_duration_seconds => closing_set.target_duration_seconds, p_actual_distance_meters => 450);
  end loop;
  perform public.finish_workout_execution(repeat_attempt, 5, 'Repetición', null, null, 'manual');
  if not exists (select 1 from public.scheduled_workouts s where s.id = scheduled
      and s.status = 'completed' and s.execution_id = repeat_attempt and s.repeat_execution_id is null)
    or not exists (select 1 from public.workout_executions e where e.id = original and e.status = 'abandoned')
    or not exists (select 1 from public.workout_execution_sets where id = initial_set and actual_duration_seconds = 174)
    or exists (select 1 from public.scheduled_workouts where id = another_scheduled and execution_id is not null) then
    raise exception 'El cierre de la repetición no conserva el historial o duplica la pauta';
  end if;

  -- Simula la misma pauta cerrada en el ámbito adaptativo y un cambio de plan.
  reset role;
  update public.workout_templates set origin = 'algorithm' where id = template;
  update public.scheduled_workouts set source = 'algorithm' where id = scheduled;
  insert into public.pro_access_grants(user_id, source, starts_at, ends_at, reason)
    values(athlete, 'development_manual', now()-interval '1 day', now()+interval '1 day', 'Ensayo de repetición')
    returning id into grant_id;
  set local role authenticated;
  repeat_attempt := public.repeat_scheduled_workout(athlete, scheduled);
  reset role;
  update public.pro_access_grants set revoked_at = now() where id = grant_id;
  set local role authenticated;
  if repeat_attempt <> public.repeat_scheduled_workout(athlete, scheduled) then
    raise exception 'Al perder Pro se impide retomar lo ya iniciado';
  end if;
  perform public.discard_workout_execution(repeat_attempt, 'DESCARTAR');
  begin
    perform public.repeat_scheduled_workout(athlete, scheduled);
    raise exception 'Se inició otra repetición adaptativa tras perder Pro';
  exception when raise_exception then
    get stacked diagnostics access_error = pg_exception_detail;
    if access_error is distinct from 'pro_required' then raise; end if;
  end;
  reset role;
  if has_function_privilege('anon', 'public.repeat_scheduled_workout(uuid,uuid)', 'execute')
    or has_table_privilege('authenticated', 'public.scheduled_workouts', 'update') then
    raise exception 'El marcador de repetición admite una operación no autorizada';
  end if;
end
$test$;

select 'Repetición de pauta, prescripción histórica, propiedad, reintento, descarte y cierre: OK' as result;
rollback;
