begin;

alter table public.scheduled_workouts
  add column repeat_execution_id uuid,
  add constraint scheduled_workouts_repeat_open_check check (
    repeat_execution_id is null or (
      execution_id is not null and repeat_execution_id <> execution_id
      and status in ('completed', 'abandoned')
    )
  );
create unique index scheduled_workouts_repeat_execution_idx
  on public.scheduled_workouts(repeat_execution_id) where repeat_execution_id is not null;

-- Una repetición ya trae la prescripción de la ejecución cerrada. Los
-- inicios ordinarios siguen leyendo la plantilla como hasta ahora.
do $migration$
declare
  routine regprocedure;
  definition text;
  anchor constant text := E'\nbegin\n';
begin
  foreach routine in array array[
    'public.snapshot_performance_set()'::regprocedure,
    'public.snapshot_running_execution_set()'::regprocedure,
    'public.snapshot_running_step_v2()'::regprocedure,
    'public.snapshot_workout_item_instructions()'::regprocedure,
    'public.set_running_v0_manual_time()'::regprocedure,
    'trainer_private.freeze_exercise_media()'::regprocedure
  ] loop
    definition := replace(pg_get_functiondef(routine), chr(13), '');
    if strpos(definition, anchor) = 0 then
      raise exception 'Revisar el inicio del snapshot %', routine;
    end if;
    execute replace(definition, anchor, anchor ||
      E'  if tg_op = ''INSERT'' and exists (select 1 from public.scheduled_workouts s\n'
      || E'    where s.repeat_execution_id = new.execution_id) then return new; end if;\n');
  end loop;

  definition := pg_get_functiondef('public.snapshot_workout_execution_session_type()'::regprocedure);
  if strpos(definition, '    select coalesce(bool_or') = 0 then
    raise exception 'Revisar la clasificación al iniciar.';
  end if;
  execute replace(definition, '    select coalesce(bool_or',
    E'    if new.session_type_policy is not null then return new; end if;\n'
    || '    select coalesce(bool_or');

  definition := pg_get_functiondef('public.can_finish_workout_without_full_recording(uuid)'::regprocedure);
  if strpos(definition, 'where s.execution_id = e.id') = 0 then
    raise exception 'Revisar el permiso para el cierre sin registro.';
  end if;
  execute replace(definition, 'where s.execution_id = e.id',
    'where (s.execution_id = e.id or s.repeat_execution_id = e.id)');

  definition := pg_get_functiondef('trainer_private.start_workout_execution(uuid)'::regprocedure);
  if strpos(definition, '  if execution_id is not null then') = 0 then
    raise exception 'Revisar el retorno de las ejecuciones abiertas.';
  end if;
  execute replace(definition, '  if execution_id is not null then',
    E'  if execution_id is not null then\n'
    || E'    if execution_id in (select s.repeat_execution_id from public.scheduled_workouts s\n'
    || E'      where s.repeat_execution_id is not null and s.user_id = current_user_id) then\n'
    || E'      perform workout_private.raise_open_workout(execution_id);\n'
    || E'    end if;');
end
$migration$;

create function trainer_private.repeat_scheduled_workout(
  p_expected_owner uuid, p_scheduled_id uuid
) returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  scheduled public.scheduled_workouts;
  previous public.workout_executions;
  opened_id uuid;
  new_id uuid;
  has_running boolean;
  has_other_work boolean;
begin
  if auth.uid() is null or auth.uid() is distinct from p_expected_owner then
    raise insufficient_privilege;
  end if;
  -- El mismo orden de bloqueos que el descarte y el inicio revisado.
  perform 1 from public.profiles where id = p_expected_owner for update;
  perform pg_advisory_xact_lock(hashtextextended('trainer-client:' || p_expected_owner::text, 0));
  select * into scheduled from public.scheduled_workouts
  where id = p_scheduled_id and user_id = p_expected_owner
    and status in ('completed', 'abandoned') and execution_id is not null
  for update;
  if not found then raise insufficient_privilege; end if;
  if scheduled.repeat_execution_id is not null then return scheduled.repeat_execution_id; end if;

  perform trainer_private.get_scheduled_workout_preview(p_expected_owner, scheduled.id);
  if scheduled.source = 'coach' and not exists (
    select 1 from public.trainer_assignments a
    join public.trainer_client_relations r on r.id = a.relation_id
    where a.scheduled_id = scheduled.id and a.client_id = p_expected_owner
      and r.client_id = a.client_id and r.trainer_id = a.trainer_id and r.ended_at is null
  ) then
    raise exception 'La pauta ya no está activa con tu preparador.' using errcode = '42501';
  end if;
  if scheduled.source = 'algorithm' or exists (
    select 1 from public.workout_templates t where t.id = scheduled.template_id and t.origin = 'algorithm'
  ) then
    perform public.require_pro_access();
  end if;
  select e.id into opened_id from public.workout_executions e
  where e.user_id = p_expected_owner and e.status = 'in_progress'
  order by e.started_at desc, e.id limit 1;
  if found then perform workout_private.raise_open_workout(opened_id); end if;

  select * into previous from public.workout_executions e
    where e.id = scheduled.execution_id and e.user_id = p_expected_owner
      and e.template_id = scheduled.template_id and e.template_version = scheduled.template_version
      and e.status in ('completed', 'abandoned');
  if not found then raise insufficient_privilege; end if;

  select coalesce(bool_or(s.block_format = 'running'), false),
    coalesce(bool_or(s.block_format not in ('running', 'warm_up', 'cool_down')), false)
  into has_running, has_other_work
  from public.workout_execution_sets s where s.execution_id = previous.id;
  if not exists (select 1 from public.workout_execution_sets s where s.execution_id = previous.id) then
    raise exception 'No hay una prescripción guardada para repetir este entrenamiento.' using errcode = '22023';
  end if;
  insert into public.workout_executions (
    user_id, template_id, template_name, template_version, session_type, session_type_policy
  ) values (
    p_expected_owner, previous.template_id, previous.template_name, previous.template_version,
    coalesce(previous.session_type, case
      when has_running and has_other_work then 'mixed'
      when has_running then 'running' else 'strength' end),
    'block_format_v1'
  ) returning id into new_id;
  update public.scheduled_workouts set repeat_execution_id = new_id where id = scheduled.id;
  insert into public.workout_execution_sets (
    execution_id, source_set_id, block_order, block_name, block_format, block_time_cap_seconds,
    item_order, exercise_id, exercise_name, set_order, target_reps, target_duration_seconds,
    target_distance_meters, target_load_kg, target_rpe, target_rir, rest_after_seconds,
    target_pace_min_seconds_per_km, target_pace_max_seconds_per_km, recovery_type,
    recovery_duration_seconds, recovery_distance_meters, performance_prescription,
    item_instructions, running_step, manual_distance_optional, exercise_description,
    exercise_video_url, exercise_media_frozen, exercise_image_path, official_exercise_image
  )
  select new_id, s.source_set_id, s.block_order, s.block_name, s.block_format, s.block_time_cap_seconds,
    s.item_order, s.exercise_id, s.exercise_name, s.set_order, s.target_reps, s.target_duration_seconds,
    s.target_distance_meters, s.target_load_kg, s.target_rpe, s.target_rir, s.rest_after_seconds,
    s.target_pace_min_seconds_per_km, s.target_pace_max_seconds_per_km, s.recovery_type,
    s.recovery_duration_seconds, s.recovery_distance_meters, s.performance_prescription,
    s.item_instructions, s.running_step, s.manual_distance_optional, s.exercise_description,
    s.exercise_video_url, s.exercise_media_frozen, s.exercise_image_path, s.official_exercise_image
  from public.workout_execution_sets s where s.execution_id = previous.id;
  return new_id;
end
$$;

create function public.repeat_scheduled_workout(p_expected_owner uuid, p_scheduled_id uuid)
returns uuid language sql volatile security invoker set search_path = '' as $$
  select trainer_private.repeat_scheduled_workout(p_expected_owner, p_scheduled_id);
$$;
revoke all on function trainer_private.repeat_scheduled_workout(uuid, uuid),
  public.repeat_scheduled_workout(uuid, uuid) from public, anon, authenticated, service_role;
grant execute on function trainer_private.repeat_scheduled_workout(uuid, uuid),
  public.repeat_scheduled_workout(uuid, uuid) to authenticated;

-- La limpieza forma parte del descarte y de la caducidad. Mantener una única
-- FK pública entre las dos tablas conserva los embeds de los clientes antiguos.
create function workout_private.close_scheduled_workout_repeat()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if tg_op = 'DELETE' then
    update public.scheduled_workouts set repeat_execution_id = null
    where repeat_execution_id = old.id and user_id = old.user_id;
    return old;
  end if;
  if old.status <> 'in_progress' or new.status not in ('completed', 'abandoned') then
    return new;
  end if;
  if new.status = 'completed' and not new.completed_without_full_recording then
    update public.scheduled_workouts set execution_id = new.id,
      status = 'completed', repeat_execution_id = null
    where repeat_execution_id = new.id and user_id = new.user_id;
  else
    update public.scheduled_workouts set repeat_execution_id = null
    where repeat_execution_id = new.id and user_id = new.user_id;
  end if;
  return new;
end
$$;
revoke all on function workout_private.close_scheduled_workout_repeat()
  from public, anon, authenticated, service_role;
create trigger close_scheduled_workout_repeat after update of status or delete on public.workout_executions
for each row
execute function workout_private.close_scheduled_workout_repeat();

commit;
