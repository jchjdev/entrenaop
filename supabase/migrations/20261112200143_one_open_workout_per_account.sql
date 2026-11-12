begin;

create function public.get_my_open_workouts()
returns table (id uuid, template_name text, started_at timestamptz)
language sql stable security invoker set search_path = '' as $$
  select e.id, e.template_name, e.started_at
  from public.workout_executions e
  where e.user_id = auth.uid() and e.status = 'in_progress'
  order by e.started_at desc, e.id;
$$;

revoke all on function public.get_my_open_workouts() from public, anon;
grant execute on function public.get_my_open_workouts() to authenticated;

create table workout_private.open_workout_guards (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  checked_at timestamptz not null
);
alter table workout_private.open_workout_guards enable row level security;
revoke all on table workout_private.open_workout_guards
  from public, anon, authenticated, service_role;

create function workout_private.raise_open_workout(p_execution_id uuid)
returns void language plpgsql set search_path = '' as $$
begin
  raise exception 'Ya tienes una sesión en curso.'
    using errcode = 'EO001', detail = (
      select jsonb_build_object('id', e.id, 'template_name', e.template_name)::text
      from public.workout_executions e where e.id = p_execution_id
    );
end;
$$;

-- La restricción se comprueba al confirmar la transacción. Una importación
-- que crea y cierra la ejecución en el mismo RPC no deja otra sesión abierta.
create function workout_private.check_one_open_workout()
returns trigger language plpgsql security definer set search_path = '' as $$
declare conflicting_id uuid;
begin
  if not exists (select 1 from public.workout_executions e
    where e.id = new.id and e.user_id = new.user_id and e.status = 'in_progress') then
    return null;
  end if;
  -- La escritura por titular serializa comprobaciones concurrentes, también
  -- si el cliente emplea un aislamiento con una instantánea fija.
  insert into workout_private.open_workout_guards(user_id, checked_at)
    values (new.user_id, clock_timestamp())
    on conflict (user_id) do update set checked_at = excluded.checked_at;
  select e.id into conflicting_id
  from public.workout_executions e
  where e.user_id = new.user_id and e.status = 'in_progress' and e.id <> new.id
  order by e.started_at desc, e.id
  limit 1;
  if found then perform workout_private.raise_open_workout(conflicting_id); end if;
  return null;
end;
$$;

create constraint trigger one_open_workout_per_account
  after insert or update of status, user_id on public.workout_executions
  deferrable initially deferred for each row
  when (new.status = 'in_progress')
  execute function workout_private.check_one_open_workout();

-- Si el motor ya ha encontrado una ejecución de la misma plantilla o del
-- mismo programa, los conflictos de cita o de sesión usan el mismo aviso.
do $migration$
declare definition text;
  previous text;
begin
  definition := pg_get_functiondef('trainer_private.start_scheduled_workout(uuid)'::regprocedure);
  previous := 'raise exception ''La sesión ya tiene otra ejecución en curso.'' using errcode=''22023'';';
  if strpos(definition, previous) = 0 then raise exception 'Revisar el conflicto de agenda.'; end if;
  execute replace(definition, previous, 'perform workout_private.raise_open_workout(execution);');

  definition := pg_get_functiondef('public.start_guided_program_session(uuid,integer,integer,uuid,boolean,integer)'::regprocedure);
  previous := 'raise exception ''Retoma o resuelve primero la otra sesión de este programa.'' using errcode=''22023'';';
  if strpos(definition, previous) = 0 then raise exception 'Revisar el conflicto de programas guiados.'; end if;
  execute replace(definition, previous, 'perform workout_private.raise_open_workout(r.execution_id);');
end;
$migration$;

-- El acceso al vídeo de técnica se decide por la pauta, propietario y
-- entrenador. Descartar la ejecución solo desvincula esas dos referencias.
alter table public.exercise_video_assets
  drop constraint exercise_video_scope_context,
  add constraint exercise_video_scope_context check (
    (scope = 'official' and trainer_id is null and assignment_id is null and execution_id is null and execution_set_id is null)
    or (scope = 'trainer_exercise' and trainer_id is not null and assignment_id is null and execution_id is null and execution_set_id is null and created_by = trainer_id)
    or (scope = 'client_technique' and trainer_id is not null and assignment_id is not null and created_by is not null
      and (execution_id is not null or execution_set_id is null))
  );

create function workout_private.detach_open_workout_videos()
returns trigger language plpgsql set search_path = '' as $$
begin
  -- Ambas claves se sueltan antes de que se eliminen las series en cascada.
  update public.exercise_video_assets
  set execution_id = null, execution_set_id = null
  where execution_id = old.id and scope = 'client_technique';
  return old;
end;
$$;

create trigger detach_open_workout_videos
  before delete on public.workout_executions for each row
  when (old.status = 'in_progress')
  execute function workout_private.detach_open_workout_videos();

do $migration$
declare definition text;
  anchor text := ' if tg_table_name=''exercise_images'' then';
  transition_anchor text := ' if old.status in(';
  detached_video text := E' if tg_op = ''UPDATE'' and tg_table_name = ''exercise_video_assets''\n'
    || E'   and pg_trigger_depth() > 1 and old.execution_id is not null\n'
    || E'   and new.execution_id is null and new.execution_set_id is null\n'
    || E'   and to_jsonb(new) - array[''execution_id'', ''execution_set_id'']\n'
    || E'       = to_jsonb(old) - array[''execution_id'', ''execution_set_id''] then return new; end if;\n';
  exclusion text := 'and not exists (
        select 1 from public.exercise_video_assets v where v.execution_id = e.id
      )';
begin
  definition := pg_get_functiondef('trainer_private.media_asset_guard()'::regprocedure);
  if strpos(definition, anchor) = 0 then raise exception 'Revisar la guarda de medios.'; end if;
  execute replace(definition, anchor, detached_video || anchor);

  definition := pg_get_functiondef('trainer_private.guard_video_transition()'::regprocedure);
  if strpos(definition, transition_anchor) = 0 then raise exception 'Revisar la guarda de transiciones de vídeo.'; end if;
  execute replace(definition, transition_anchor, detached_video || transition_anchor);

  definition := pg_get_functiondef('workout_private.expire_inactive_executions()'::regprocedure);
  if strpos(definition, exclusion) = 0 then raise exception 'Revisar la caducidad de sesiones con vídeo.'; end if;
  execute replace(definition, exclusion, '');
end;
$migration$;

revoke all on function workout_private.raise_open_workout(uuid),
  workout_private.check_one_open_workout(), workout_private.detach_open_workout_videos()
  from public, anon, authenticated, service_role;

commit;
