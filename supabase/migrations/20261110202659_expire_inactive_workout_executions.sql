begin;

create schema workout_private;
revoke all on schema workout_private from public, anon, authenticated, service_role;

create index workout_executions_open_started_idx
  on public.workout_executions (started_at, id) where status = 'in_progress';

create function workout_private.has_recent_workout_activity(
  p_execution_id uuid, p_cutoff timestamptz
) returns boolean
language sql set search_path = '' as $$
  select exists (
    select 1 from public.workout_execution_sets s
    where s.execution_id = p_execution_id
      and (s.completed_at > p_cutoff or exists (
        select 1 from public.workout_set_corrections c
        where c.execution_set_id = s.id and c.corrected_at > p_cutoff
      ))
  ) or exists (
    select 1 from public.workout_amrap_results a
    where a.execution_id = p_execution_id and a.completed_at > p_cutoff
  );
$$;

-- El descarte manual y la caducidad comparten limpieza y orden de bloqueos.
-- Un corte nulo indica el descarte explícito, ya autorizado por el cliente.
create function workout_private.discard_execution(
  p_execution_id uuid, p_owner uuid, p_cutoff timestamptz
) returns uuid[]
language plpgsql set search_path = '' as $$
declare
  selected public.workout_executions%rowtype;
  discarded public.discarded_workout_executions%rowtype;
  resources uuid[];
begin
  perform 1 from public.profiles where id = p_owner for update;
  select * into discarded from public.discarded_workout_executions
    where execution_id = p_execution_id and user_id = p_owner;
  if found then
    if p_cutoff is not null then return null; end if;
    return array[p_execution_id] || discarded.set_ids;
  end if;
  perform 1 from public.scheduled_workouts
    where execution_id = p_execution_id and user_id = p_owner order by id for update;
  select * into selected from public.workout_executions
    where id = p_execution_id and user_id = p_owner for update;
  if not found then
    if p_cutoff is not null then return null; end if;
    raise exception 'La sesión no está disponible para esta cuenta.' using errcode = '42501';
  end if;
  if selected.status <> 'in_progress' then
    if p_cutoff is not null then return null; end if;
    raise exception 'Solo puedes descartar una sesión en curso. Su resultado ya está cerrado.' using errcode = '22023';
  end if;
  perform 1 from public.workout_execution_sets
    where execution_id = p_execution_id order by id for update;
  -- Una serie o corrección guardada después de seleccionar el lote renueva el plazo.
  if p_cutoff is not null and (selected.started_at > p_cutoff
    or workout_private.has_recent_workout_activity(p_execution_id, p_cutoff)) then
    return null;
  end if;
  select coalesce(array_agg(id), '{}'::uuid[]) into resources
    from public.workout_execution_sets where execution_id = p_execution_id;
  insert into public.discarded_workout_executions(execution_id, user_id, set_ids)
    values (p_execution_id, p_owner, resources);
  update public.scheduled_workouts set status = 'planned', execution_id = null
    where execution_id = p_execution_id and user_id = p_owner;
  delete from public.workout_mutation_receipts where user_id = p_owner
    and (resource_id = p_execution_id or resource_id = any(resources));
  delete from public.workout_executions where id = p_execution_id and user_id = p_owner;
  return array[p_execution_id] || resources;
end;
$$;

create or replace function public.discard_workout_execution(
  p_execution_id uuid, p_confirmation text
) returns uuid[]
language plpgsql security definer set search_path = '' as $$
declare
  u uuid := auth.uid();
begin
  if u is null then
    raise exception 'Inicia sesión para descartar el entrenamiento.' using errcode = '42501';
  end if;
  if p_confirmation is distinct from 'DESCARTAR' then
    raise exception 'Confirma que quieres descartar esta sesión.' using errcode = '22023';
  end if;
  return workout_private.discard_execution(p_execution_id, u, null);
end;
$$;

create function workout_private.expire_inactive_executions() returns integer
language plpgsql set search_path = '' set lock_timeout = '250ms' as $$
declare
  cutoff timestamptz := statement_timestamp() - interval '24 hours';
  candidate record;
  discarded_count integer := 0;
begin
  for candidate in
    select e.id, e.user_id from public.workout_executions e
    where e.status = 'in_progress' and e.started_at <= cutoff
      and not workout_private.has_recent_workout_activity(e.id, cutoff)
      and not exists (
        select 1 from public.exercise_video_assets v where v.execution_id = e.id
      )
    order by e.started_at, e.id
    limit 100
  loop
    begin
      if workout_private.discard_execution(candidate.id, candidate.user_id, cutoff) is not null then
        discarded_count := discarded_count + 1;
      end if;
    exception when lock_not_available or deadlock_detected or foreign_key_violation then
      -- Una actividad concurrente o un recurso protegido no detienen el lote.
      continue;
    end;
  end loop;
  return discarded_count;
end;
$$;

revoke all on all functions in schema workout_private
  from public, anon, authenticated, service_role;

-- La activación del trabajo programado se realiza aparte por entorno.
commit;
