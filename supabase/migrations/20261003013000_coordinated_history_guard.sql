begin;
create or replace function public.reset_running_plan(p_goal_id uuid)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_user uuid := auth.uid();
  v_schedules uuid[] := '{}';
  v_executions uuid[] := '{}';
  v_templates uuid[] := '{}';
  v_decisions integer := 0;
begin
  if v_user is null then raise exception 'Authentication required'; end if;
  -- Publicar una semana bloquea esta misma fila: no puede intercalarse con el reinicio.
  perform 1 from public.preparation_goals g
  where g.id=p_goal_id and g.user_id=v_user and g.status='active' for update;
  if not found then raise exception 'Active running preparation not found'; end if;

  if exists(select 1 from public.preparation_week_decisions where preparation_goal_id=p_goal_id) then
    raise exception 'Esta preparación tiene semanas coordinadas. Conserva su historial y actualiza contexto o referencias para adaptar las siguientes semanas.' using errcode='22023';
  end if;
  -- Bloquear también las entradas de agenda antes de comprobar su estado.
  perform 1 from public.scheduled_workouts sw
  join public.running_week_sessions rs on rs.scheduled_workout_id=sw.id
  join public.running_week_decisions d on d.id=rs.decision_id
  where d.preparation_goal_id=p_goal_id and d.user_id=v_user
    and sw.user_id=v_user and sw.source='algorithm'
  for update of sw;
  if exists (
    select 1 from public.scheduled_workouts sw
    join public.running_week_sessions rs on rs.scheduled_workout_id=sw.id
    join public.running_week_decisions d on d.id=rs.decision_id
    where d.preparation_goal_id=p_goal_id and d.user_id=v_user
      and sw.status='in_progress'
  ) then raise exception 'Finish or abandon the active session before resetting'; end if;
  if exists (
    select 1 from public.running_week_sessions rs
    join public.running_week_decisions d on d.id=rs.decision_id
    join public.scheduled_workouts sw on sw.id=rs.scheduled_workout_id
    where d.preparation_goal_id=p_goal_id and d.user_id=v_user
      and (sw.user_id<>v_user or sw.source<>'algorithm'
        or sw.preparation_goal_id is distinct from p_goal_id)
  ) then raise exception 'Running plan contains an unexpected session'; end if;

  select count(*) into v_decisions from public.running_week_decisions
    where preparation_goal_id=p_goal_id and user_id=v_user;
  select coalesce(array_agg(sw.id),'{}'::uuid[]),
         coalesce(array_agg(sw.execution_id) filter(where sw.execution_id is not null),'{}'::uuid[]),
         coalesce(array_agg(sw.template_id),'{}'::uuid[])
    into v_schedules,v_executions,v_templates
  from public.scheduled_workouts sw
  join public.running_week_sessions rs on rs.scheduled_workout_id=sw.id
  join public.running_week_decisions d on d.id=rs.decision_id
  where d.preparation_goal_id=p_goal_id and d.user_id=v_user;

  -- Los recibos idempotentes de estas ejecuciones dejan de tener recurso.
  delete from public.workout_mutation_receipts r
  where r.user_id=v_user and (r.resource_id=any(v_executions)
    or r.resource_id in (select es.id from public.workout_execution_sets es
      where es.execution_id=any(v_executions)));
  delete from public.running_week_sessions rs where rs.scheduled_workout_id=any(v_schedules);
  delete from public.scheduled_workouts sw where sw.id=any(v_schedules) and sw.user_id=v_user;
  delete from public.workout_executions e where e.id=any(v_executions) and e.user_id=v_user;
  delete from public.running_week_decisions d
    where d.preparation_goal_id=p_goal_id and d.user_id=v_user;
  delete from public.workout_templates t
    where t.id=any(v_templates) and t.owner_user_id=v_user and t.origin='algorithm';

  return jsonb_build_object('decisions',v_decisions,'sessions',cardinality(v_schedules),
    'executions',cardinality(v_executions));
end $$;

commit;
