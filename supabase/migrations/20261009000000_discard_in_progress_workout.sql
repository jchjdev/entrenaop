-- Descartar una ejecución en curso es distinto de abandonarla conservando datos.
begin;

-- Solo identificadores: permiten reconocer reintentos y colas de otros dispositivos
-- después del borrado, sin conservar resultados deportivos descartados.
create table public.discarded_workout_executions (
  execution_id uuid primary key,
  user_id uuid not null references public.profiles(id) on delete cascade,
  set_ids uuid[] not null,
  discarded_at timestamptz not null default now()
);
create index discarded_workout_executions_user_idx
  on public.discarded_workout_executions(user_id);
alter table public.discarded_workout_executions enable row level security;
revoke all on public.discarded_workout_executions from public, anon, authenticated;

create or replace function public.discard_workout_execution(
  p_execution_id uuid,
  p_confirmation text
)
returns uuid[] language plpgsql security definer set search_path = '' as $$
declare
  u uuid := auth.uid();
  selected public.workout_executions%rowtype;
  discarded public.discarded_workout_executions%rowtype;
  resources uuid[];
begin
  if u is null then
    raise exception 'Inicia sesión para descartar el entrenamiento.' using errcode='42501';
  end if;
  if p_confirmation is distinct from 'DESCARTAR' then
    raise exception 'Confirma que quieres descartar esta sesión.' using errcode='22023';
  end if;
  -- El orden coincide con las operaciones de programa y de inicio desde agenda.
  perform 1 from public.profiles where id=u for update;
  select * into discarded from public.discarded_workout_executions
    where execution_id=p_execution_id and user_id=u;
  if found then return array[p_execution_id] || discarded.set_ids; end if;
  perform 1 from public.scheduled_workouts
    where execution_id=p_execution_id and user_id=u order by id for update;
  select * into selected from public.workout_executions
    where id=p_execution_id and user_id=u for update;
  if not found then
    raise exception 'La sesión no está disponible para esta cuenta.' using errcode='42501';
  end if;
  if selected.status <> 'in_progress' then
    raise exception 'Solo puedes descartar una sesión en curso. Su resultado ya está cerrado.' using errcode='22023';
  end if;
  perform 1 from public.workout_execution_sets
    where execution_id=p_execution_id order by id for update;
  select coalesce(array_agg(id), '{}'::uuid[]) into resources
    from public.workout_execution_sets where execution_id=p_execution_id;
  insert into public.discarded_workout_executions(execution_id,user_id,set_ids)
    values(p_execution_id,u,resources);
  -- Conserva cita, plantilla y pauta; volver a empezar generará otra ejecución.
  update public.scheduled_workouts set status='planned',execution_id=null
    where execution_id=p_execution_id and user_id=u;
  delete from public.workout_mutation_receipts where user_id=u and
    (resource_id=p_execution_id or resource_id=any(resources));
  -- Las series, correcciones y AMRAP dependen de esta ejecución con CASCADE.
  delete from public.workout_executions where id=p_execution_id and user_id=u;
  return array[p_execution_id] || resources;
end;
$$;

create or replace function public.get_discarded_workout_resource_ids(p_resource_ids uuid[])
returns uuid[] language sql stable security definer set search_path = '' as $$
  select coalesce(array_agg(distinct resource), '{}'::uuid[])
  from public.discarded_workout_executions discarded,
    lateral unnest(array[discarded.execution_id] || discarded.set_ids) resource
  where discarded.user_id=auth.uid() and resource=any(p_resource_ids);
$$;
revoke all on function public.discard_workout_execution(uuid,text) from public,anon,authenticated;
revoke all on function public.get_discarded_workout_resource_ids(uuid[]) from public,anon,authenticated;
grant execute on function public.discard_workout_execution(uuid,text) to authenticated;
grant execute on function public.get_discarded_workout_resource_ids(uuid[]) to authenticated;
commit;
