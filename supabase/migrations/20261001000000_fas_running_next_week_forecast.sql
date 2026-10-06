-- Previsión de lectura de la siguiente semana FAS a partir de sesiones cerradas.
begin;

create or replace function public.calculate_fas_running_week_core(
  p_goal_id uuid, p_week_start date, p_replay_initial boolean, p_preview_future boolean
) returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  v_goal record;
  v_ctx public.running_intake_contexts%rowtype;
  v_ref record;
  v_ref_age integer;
  v_last_sunday date := current_date - extract(isodow from current_date)::integer;
  v_days integer[] := '{}'::integer[];
  v_minutes integer[] := '{}'::integer[];
  v_kinds text[] := '{}'::text[];
  v_available integer;
  v_count integer;
  v_cap integer;
  v_day integer;
  v_index integer;
  v_remaining integer;
  v_assigned boolean;
  v_quality boolean;
  v_basis text;
  v_outcome text := 'initial';
  v_reason text := 'Entrada inicial revisada';
  v_previous public.running_week_decisions%rowtype;
  v_has_previous boolean;
  v_current public.running_week_decisions%rowtype;
  v_prior record;
  v_total integer;
  v_completed integer;
  v_bad integer;
  v_discomfort integer;
  v_sessions jsonb := '[]'::jsonb;
begin
  if v_user is null then raise exception 'Authentication required'; end if;
  if extract(isodow from p_week_start) <> 1
    or p_week_start < current_date - (extract(isodow from current_date)::integer - 1)
    or p_week_start > current_date + 28 then
    raise exception 'Choose a current or upcoming complete week';
  end if;
  select * into v_goal from public.preparation_goals
  where id = p_goal_id and user_id = v_user and status = 'active'
    and program_id = 'fas_periodic_assessment';
  if not found then raise exception 'Active FAS preparation not found'; end if;
  if not p_replay_initial then
    select * into v_current from public.running_week_decisions
    where preparation_goal_id = p_goal_id and week_start = p_week_start;
  end if;
  if not p_replay_initial and v_current.id is not null then
    return v_current.decision || jsonb_build_object(
      'decision_id', v_current.id, 'already_published', true);
  end if;

  if p_replay_initial then
    v_has_previous := false;
  else
    select * into v_previous from public.running_week_decisions
    where preparation_goal_id = p_goal_id and week_start = p_week_start - 7;
    v_has_previous := found;
  end if;
  select * into v_ctx from public.running_intake_contexts
  where preparation_goal_id = p_goal_id;
  if not found
    or (not v_has_previous and (
      v_ctx.recent_weeks_end_on <> v_last_sunday
      or v_ctx.updated_at::date < v_last_sunday
      or v_ctx.health_observed_at::date < v_last_sunday))
    or (v_has_previous and (
      v_ctx.updated_at::date < current_date - 30
      or v_ctx.health_observed_at::date < current_date - 30)) then
    raise exception 'Update the current running context';
  end if;
  if v_ctx.reports_pain or v_ctx.requires_professional_review then
    raise exception 'Health flag pauses the automatic proposal';
  end if;

  select s.reference_source, s.reference_record_id, s.continuity_confirmed_at,
    a.completed_at, m.value
  into v_ref
  from public.running_reference_selections s
  join public.fas_periodic_assessments a
    on a.id::text = s.reference_record_id
   and a.preparation_goal_id = p_goal_id and a.user_id = v_user
  join public.fas_periodic_marks m
    on m.assessment_id = a.id and m.test_id = 'run_2000_m'
  where s.preparation_goal_id = p_goal_id
    and s.reference_source = 'fasPeriodicAssessment'
    and m.value > 0;
  if not found then raise exception 'Choose a valid FAS 2 km mark'; end if;
  v_ref_age := current_date - v_ref.completed_at::date;
  if v_ref.completed_at > now() or v_ref_age not between 0 and 45 then
    raise exception 'The selected 2 km mark is outside the reuse window';
  end if;
  if v_ref_age > 30 and (
    v_ref.continuity_confirmed_at is null
    or v_ref.continuity_confirmed_at < v_ref.completed_at
    or v_ctx.recent_weeks_end_on <> v_last_sunday
    or 0 = any(v_ctx.running_days_last_four_weeks)
  ) then raise exception 'Confirm uninterrupted running before reuse'; end if;

  -- Un entrenamiento de cualquier preparación ocupa el día entero en v1.
  for v_day in 1..7 loop
    if v_ctx.available_minutes_by_weekday ? v_day::text
      and not v_day = any(v_ctx.reserved_strength_weekdays)
          and (v_ctx.available_minutes_by_weekday ->> v_day::text)::integer >= 25
      and not exists (select 1 from public.scheduled_workouts sw
        where sw.user_id = v_user
          and sw.scheduled_date = p_week_start + (v_day - 1)
          and sw.status not in ('cancelled', 'skipped')
          and (not p_replay_initial or sw.preparation_goal_id is distinct from p_goal_id
            or sw.source <> 'algorithm'))
      and (cardinality(v_days) = 0
        or v_day - v_days[cardinality(v_days)] >= 2) then
      v_days := array_append(v_days, v_day);
    end if;
  end loop;
  if cardinality(v_days) = 0 then
    raise exception 'No free day of at least 30 minutes';
  end if;

  if v_has_previous then

    if current_date < p_week_start - 1 and not p_preview_future then
      raise exception 'Close the previous week before adapting';
    end if;
    select count(*),
      count(*) filter (where sw.status = 'completed'),
      count(*) filter (where (sw.status = 'abandoned' and e.abandonment_reason = 'too_difficult')
        or (sw.status = 'completed' and (
          e.final_rpe >= 8 or coalesce(actual.seconds, 0) < rs.planned_minutes * 42
        ))),
      count(*) filter (where e.abandonment_reason = 'discomfort')
    into v_total, v_completed, v_bad, v_discomfort
    from public.running_week_sessions rs
    join public.scheduled_workouts sw on sw.id = rs.scheduled_workout_id
    left join public.workout_executions e on e.id = sw.execution_id
    left join lateral (
      select sum(coalesce(es.actual_duration_seconds, 0)
        + coalesce(es.actual_recovery_duration_seconds, 0)) as seconds
      from public.workout_execution_sets es
      where es.execution_id = e.id and es.status = 'completed'
    ) actual on true
    where rs.decision_id = v_previous.id;
    if v_discomfort > 0 then
      raise exception 'Update health status after discomfort';
    end if;
    if v_bad >= 2 then
      v_outcome := 'reduce';
      v_reason := 'Varias sesiones por debajo de lo pautado o con esfuerzo alto';
    elsif v_bad = 1 or v_completed < v_total then
      v_outcome := 'maintain';
      v_reason := 'Una sesión difícil o datos pendientes no cambian la carga';
    else
      v_outcome := 'progress';
      v_reason := 'Semana completa y tolerada: cambia una sola variable';
    end if;
    v_basis := v_previous.basis;
    for v_prior in
      select rs.kind, rs.planned_minutes
      from public.running_week_sessions rs
      join public.scheduled_workouts sw on sw.id = rs.scheduled_workout_id
      where rs.decision_id = v_previous.id order by sw.scheduled_date
    loop
      exit when cardinality(v_minutes) >= cardinality(v_days);
      v_minutes := array_append(v_minutes, v_prior.planned_minutes);
      v_kinds := array_append(v_kinds, v_prior.kind);
    end loop;
    -- La v1 podía comprimir dos días recientes en uno. Recuperar la frecuencia
    -- sin introducir calidad y respetando la carga semanal declarada.
    if v_previous.policy_version = 'fas_running_week_v1'
      and v_basis = 'recent' and cardinality(v_minutes) = 1
      and cardinality(v_days) >= 2
      and v_ctx.running_days_last_four_weeks[1] >= 2
      and least(v_ctx.running_minutes_last_four_weeks[1],
        (v_ctx.running_minutes_last_four_weeks[1]
         + v_ctx.running_minutes_last_four_weeks[2]
         + v_ctx.running_minutes_last_four_weeks[3]
         + v_ctx.running_minutes_last_four_weeks[4]) / 4) >= 50 then
      v_minutes := array[25, 25];
      v_kinds := array['easy', 'easy'];
      v_reason := v_reason || '; dos salidas cortas recuperan la frecuencia reciente';
    end if;
    if v_outcome = 'reduce' then
      for v_index in 1..cardinality(v_minutes) loop
        v_minutes[v_index] := greatest(25, floor(v_minutes[v_index] * 0.8)::integer);
        v_kinds[v_index] := 'easy';
      end loop;
      if cardinality(v_minutes) > 1
        and v_minutes[1] = 25 and v_minutes[2] = 25 then
        v_minutes := v_minutes[1:cardinality(v_minutes)-1];
        v_kinds := v_kinds[1:cardinality(v_kinds)-1];
      end if;
    elsif v_outcome = 'progress' then
      if v_basis = 'returning' and v_previous.outcome = 'progress'
        and cardinality(v_kinds) >= 2
        and v_minutes[1] >= 32 then
        v_kinds[1] := 'controlled_quality';
      else
        for v_index in 1..cardinality(v_minutes) loop
          if v_kinds[v_index] = 'easy' and
            v_minutes[v_index] + 5 <=
              (v_ctx.available_minutes_by_weekday ->> v_days[v_index]::text)::integer then
            v_minutes[v_index] := v_minutes[v_index] + 5;
            exit;
          end if;
        end loop;
      end if;
    end if;
  else
    v_cap := least(v_ctx.running_minutes_last_four_weeks[1],
      (v_ctx.running_minutes_last_four_weeks[1]
       + v_ctx.running_minutes_last_four_weeks[2]
       + v_ctx.running_minutes_last_four_weeks[3]
       + v_ctx.running_minutes_last_four_weeks[4]) / 4);
    if v_cap < 30 or v_ctx.running_days_last_four_weeks[1] = 0 then
      if v_ctx.comfortable_continuous_minutes is null
        or v_ctx.comfortable_continuous_minutes = 0
        or v_ctx.running_minutes_last_four_weeks <> array[0,0,0,0]::integer[] then
        raise exception 'Current running capacity or recent load needs review';
      end if;
      v_basis := case when v_ctx.comfortable_continuous_minutes >= 30
        then 'returning' else 'introductory' end;
      v_count := least(2, cardinality(v_days));
      for v_index in 1..v_count loop
        v_minutes := array_append(v_minutes,
          case when v_basis = 'introductory' then 30 else
            least(45, v_ctx.comfortable_continuous_minutes,
              (v_ctx.available_minutes_by_weekday ->> v_days[v_index]::text)::integer)
          end);
        v_kinds := array_append(v_kinds,
          case when v_basis = 'introductory' then 'walk_run' else 'easy' end);
      end loop;
    else
      v_basis := 'recent';
      -- Hasta diez minutos semanales adicionales permiten mantener dos
      -- salidas de 30 min en vez de comprimirlas en una de 45. Es una dosis
      -- piloto conservadora y se revisa con las ejecuciones posteriores.
      v_count := least(4, v_ctx.running_days_last_four_weeks[1],
        cardinality(v_days), (v_cap + 10) / 30);
      if v_count < 1 then raise exception 'Recent load needs review'; end if;
      v_quality := v_count >= 2 and
        (select bool_and(d >= 2) from unnest(v_ctx.running_days_last_four_weeks) d)
        and v_cap >= v_count * 30 + 2
        and (v_ctx.available_minutes_by_weekday ->> v_days[1]::text)::integer >= 32;
      for v_index in 1..v_count loop
        v_minutes := array_append(v_minutes,
          case when v_quality and v_index = 1 then 32 else 30 end);
        v_kinds := array_append(v_kinds,
          case when v_quality and v_index = 1
            then 'controlled_quality' else 'easy' end);
      end loop;
      v_remaining := greatest(0,
        v_cap - (select sum(m) from unnest(v_minutes) m));
      while v_remaining > 0 loop
        v_assigned := false;
        for v_index in 1..v_count loop
          if v_minutes[v_index] <
            (v_ctx.available_minutes_by_weekday ->> v_days[v_index]::text)::integer then
            v_minutes[v_index] := v_minutes[v_index] + 1;
            v_remaining := v_remaining - 1;
            v_assigned := true;
            exit when v_remaining = 0;
          end if;
        end loop;
        exit when not v_assigned;
      end loop;
    end if;
  end if;

  for v_index in 1..cardinality(v_minutes) loop
    v_available := (v_ctx.available_minutes_by_weekday ->> v_days[v_index]::text)::integer;
    v_minutes[v_index] := least(v_minutes[v_index], v_available);
    if v_kinds[v_index] <> 'walk_run'
      and v_ctx.comfortable_continuous_minutes is not null then
      if v_ctx.comfortable_continuous_minutes < 30 then
        raise exception 'Current running capacity needs review';
      end if;
      v_minutes[v_index] := least(v_minutes[v_index],
        v_ctx.comfortable_continuous_minutes);
    end if;
    if v_kinds[v_index] = 'controlled_quality' and v_minutes[v_index] < 32 then
      v_kinds[v_index] := 'easy';
    end if;
    v_sessions := v_sessions || jsonb_build_array(jsonb_build_object(
      'date', p_week_start + (v_days[v_index] - 1),
      'kind', v_kinds[v_index], 'minutes', v_minutes[v_index]
    ));
  end loop;
  return jsonb_build_object(
    'policy_version', 'fas_running_week_v2', 'goal_id', p_goal_id,
    'week_start', p_week_start, 'basis', v_basis, 'outcome', v_outcome,
    'reason', v_reason, 'reference_source', v_ref.reference_source,
    'reference_record_id', v_ref.reference_record_id,
    'reference_completed_at', v_ref.completed_at,
    'reference_2k_milliseconds', v_ref.value,
    'context_updated_at', v_ctx.updated_at,
    'comfortable_continuous_minutes', v_ctx.comfortable_continuous_minutes,
    'recent_days', v_ctx.running_days_last_four_weeks,
    'recent_minutes', v_ctx.running_minutes_last_four_weeks,
    'sessions', v_sessions
  );
end;
$$;

-- El contrato anterior sigue en su sitio; producción y publicación
-- conservan la espera hasta cerrar la semana.
create or replace function public.calculate_fas_running_week_core(
  p_goal_id uuid, p_week_start date, p_replay_initial boolean
) returns jsonb
language sql security definer set search_path = ''
as $$ select public.calculate_fas_running_week_core($1, $2, $3, false) $$;

-- Ensayo de la semana posterior al último plan publicado. Usa el mismo
-- cálculo y las ejecuciones guardadas, sin mover el reloj ni escribir agenda.
create function public.preview_fas_running_next_week(p_goal_id uuid)
returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  v_last_week date;
  v_next_week date;
  v_result jsonb;
begin
  if v_user is null then raise exception 'Authentication required'; end if;
  if not exists (
    select 1 from public.preparation_goals g
    where g.id = p_goal_id and g.user_id = v_user
      and g.status = 'active'
      and g.program_id = 'fas_periodic_assessment'
  ) then raise exception 'Active FAS preparation not found'; end if;
  select max(d.week_start) into v_last_week
  from public.running_week_decisions d
  where d.preparation_goal_id = p_goal_id and d.user_id = v_user;
  if v_last_week is null then
    raise exception 'Publish a week before previewing its successor';
  end if;
  if exists (
    select 1 from public.running_week_decisions d
    join public.running_week_sessions rs on rs.decision_id = d.id
    join public.scheduled_workouts sw on sw.id = rs.scheduled_workout_id
    where d.preparation_goal_id = p_goal_id and d.week_start = v_last_week
      and sw.status in ('planned', 'in_progress')
  ) then
    raise exception 'Finish or skip the published sessions before forecasting';
  end if;
  v_next_week := v_last_week + 7;
  if exists (
    select 1 from public.running_week_decisions d
    where d.preparation_goal_id = p_goal_id and d.week_start = v_next_week
  ) then
    raise exception 'The next week is already published';
  end if;
  v_result := public.calculate_fas_running_week_core(
    p_goal_id, v_next_week, false, true);
  return v_result || jsonb_build_object(
    'simulation', true, 'forecast', true, 'source_week', v_last_week);
end;
$$;

revoke all on function public.calculate_fas_running_week_core(
  uuid, date, boolean, boolean) from public, anon, authenticated;
revoke all on function public.preview_fas_running_next_week(uuid)
  from public, anon, authenticated;
grant execute on function public.preview_fas_running_next_week(uuid)
  to authenticated;

commit;
