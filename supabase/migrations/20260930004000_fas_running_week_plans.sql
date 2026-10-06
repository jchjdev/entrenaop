-- Publicación atómica de una semana de carrera del piloto FAS.
-- El cliente solo solicita semana y preparación; PostgreSQL resuelve entradas,
-- decide sesiones, conserva la decisión y crea agenda versionada.
begin;

create table public.running_week_decisions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  preparation_goal_id uuid not null references public.preparation_goals(id)
    on delete cascade,
  week_start date not null,
  policy_version text not null,
  basis text not null check (basis in ('recent', 'returning', 'introductory')),
  outcome text not null check (outcome in ('initial', 'maintain', 'reduce', 'progress')),
  reference_source text not null,
  reference_record_id text not null,
  input_snapshot jsonb not null,
  decision jsonb not null,
  created_at timestamptz not null default now(),
  unique (preparation_goal_id, week_start)
);

create table public.running_week_sessions (
  decision_id uuid not null references public.running_week_decisions(id)
    on delete cascade,
  scheduled_workout_id uuid not null unique
    references public.scheduled_workouts(id) on delete restrict,
  kind text not null check (kind in ('easy', 'controlled_quality', 'walk_run')),
  planned_minutes integer not null check (planned_minutes between 30 and 180),
  primary key (decision_id, scheduled_workout_id)
);

alter table public.running_week_decisions enable row level security;
alter table public.running_week_sessions enable row level security;
revoke all on public.running_week_decisions from public, anon, authenticated;
revoke all on public.running_week_sessions from public, anon, authenticated;
grant select on public.running_week_decisions to authenticated;
grant select on public.running_week_sessions to authenticated;
create policy running_week_decisions_read_own
  on public.running_week_decisions for select to authenticated
  using (user_id = (select auth.uid()));
create policy running_week_sessions_read_own
  on public.running_week_sessions for select to authenticated
  using (exists (
    select 1 from public.running_week_decisions d
    where d.id = decision_id and d.user_id = (select auth.uid())
  ));

-- Una plantilla automática pertenece al usuario para lectura, pero no para
-- edición desde las políticas de rutinas personales.
drop policy workout_templates_delete_owned on public.workout_templates;
create policy workout_templates_delete_owned on public.workout_templates
  for delete to authenticated
  using ((origin = 'user' and owner_user_id = (select auth.uid()))
    or (select public.is_admin()));

drop policy workout_templates_update_owned on public.workout_templates;
create policy workout_templates_update_owned on public.workout_templates
  for update to authenticated
  using ((origin = 'user' and owner_user_id = (select auth.uid()))
    or (select public.is_admin()))
  with check ((origin = 'user' and owner_user_id = (select auth.uid())
    and visibility = 'private') or (select public.is_admin()));

drop policy workout_blocks_write_owned on public.workout_blocks;
create policy workout_blocks_write_owned on public.workout_blocks
  for all to authenticated
  using (exists (select 1 from public.workout_templates t
    where t.id = template_id and
      ((t.origin = 'user' and t.owner_user_id = (select auth.uid()))
       or (select public.is_admin()))))
  with check (exists (select 1 from public.workout_templates t
    where t.id = template_id and
      ((t.origin = 'user' and t.owner_user_id = (select auth.uid()))
       or (select public.is_admin()))));

drop policy workout_items_write_owned on public.workout_items;
create policy workout_items_write_owned on public.workout_items
  for all to authenticated
  using (exists (select 1 from public.workout_blocks b
    join public.workout_templates t on t.id = b.template_id
    where b.id = block_id and
      ((t.origin = 'user' and t.owner_user_id = (select auth.uid()))
       or (select public.is_admin()))))
  with check (exists (select 1 from public.workout_blocks b
    join public.workout_templates t on t.id = b.template_id
    where b.id = block_id and
      ((t.origin = 'user' and t.owner_user_id = (select auth.uid()))
       or (select public.is_admin()))));

drop policy workout_sets_write_owned on public.workout_sets;
create policy workout_sets_write_owned on public.workout_sets
  for all to authenticated
  using (exists (select 1 from public.workout_items i
    join public.workout_blocks b on b.id = i.block_id
    join public.workout_templates t on t.id = b.template_id
    where i.id = item_id and
      ((t.origin = 'user' and t.owner_user_id = (select auth.uid()))
       or (select public.is_admin()))))
  with check (exists (select 1 from public.workout_items i
    join public.workout_blocks b on b.id = i.block_id
    join public.workout_templates t on t.id = b.template_id
    where i.id = item_id and
      ((t.origin = 'user' and t.owner_user_id = (select auth.uid()))
       or (select public.is_admin()))));

create function public.calculate_fas_running_week(
  p_goal_id uuid, p_week_start date
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
  select * into v_current from public.running_week_decisions
  where preparation_goal_id = p_goal_id and week_start = p_week_start;
  if found then
    return v_current.decision || jsonb_build_object(
      'decision_id', v_current.id, 'already_published', true);
  end if;

  select * into v_ctx from public.running_intake_contexts
  where preparation_goal_id = p_goal_id;
  if not found or v_ctx.recent_weeks_end_on <> v_last_sunday
    or v_ctx.updated_at::date < v_last_sunday
    or v_ctx.health_observed_at::date < v_last_sunday then
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
    or 0 = any(v_ctx.running_days_last_four_weeks)
  ) then raise exception 'Confirm uninterrupted running before reuse'; end if;

  -- Un entrenamiento de cualquier preparación ocupa el día entero en v1.
  for v_day in 1..7 loop
    if v_ctx.available_minutes_by_weekday ? v_day::text
      and not v_day = any(v_ctx.reserved_strength_weekdays)
      and (v_ctx.available_minutes_by_weekday ->> v_day::text)::integer >= 30
      and not exists (select 1 from public.scheduled_workouts sw
        where sw.user_id = v_user
          and sw.scheduled_date = p_week_start + (v_day - 1)
          and sw.status not in ('cancelled', 'skipped'))
      and (cardinality(v_days) = 0
        or v_day - v_days[cardinality(v_days)] >= 2) then
      v_days := array_append(v_days, v_day);
    end if;
  end loop;
  if cardinality(v_days) = 0 then
    raise exception 'No free day of at least 30 minutes';
  end if;

  select * into v_previous from public.running_week_decisions
  where preparation_goal_id = p_goal_id and week_start = p_week_start - 7;
  if found then
    if current_date < p_week_start - 1 then
      raise exception 'Close the previous week before adapting';
    end if;
    select count(*),
      count(*) filter (where sw.status = 'completed'),
      count(*) filter (where sw.status = 'abandoned'
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
    if v_outcome = 'reduce' then
      for v_index in 1..cardinality(v_minutes) loop
        v_minutes[v_index] := greatest(30, floor(v_minutes[v_index] * 0.8)::integer);
        v_kinds[v_index] := 'easy';
      end loop;
      if cardinality(v_minutes) > 1
        and v_minutes[1] = 30 and v_minutes[2] = 30 then
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
      v_count := least(4, v_ctx.running_days_last_four_weeks[1],
        cardinality(v_days), v_cap / 30);
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
      v_remaining := v_cap - (select sum(m) from unnest(v_minutes) m);
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
    if v_kinds[v_index] = 'controlled_quality' and v_minutes[v_index] < 32 then
      v_kinds[v_index] := 'easy';
    end if;
    v_sessions := v_sessions || jsonb_build_array(jsonb_build_object(
      'date', p_week_start + (v_days[v_index] - 1),
      'kind', v_kinds[v_index], 'minutes', v_minutes[v_index]
    ));
  end loop;
  return jsonb_build_object(
    'policy_version', 'fas_running_week_v1', 'goal_id', p_goal_id,
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

revoke all on function public.calculate_fas_running_week(uuid, date)
  from public, anon, authenticated;
grant execute on function public.calculate_fas_running_week(uuid, date)
  to authenticated;

create function public.publish_fas_running_week(
  p_goal_id uuid, p_week_start date
) returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  v_goal uuid;
  v_existing public.running_week_decisions%rowtype;
  v_plan jsonb;
  v_decision_id uuid;
  v_session jsonb;
  v_kind text;
  v_minutes integer;
  v_date date;
  v_name text;
  v_description text;
  v_template_id uuid;
  v_block_id uuid;
  v_item_id uuid;
  v_schedule_id uuid;
  v_order integer;
begin
  if v_user is null then raise exception 'Authentication required'; end if;
  -- Serializa las publicaciones de la misma preparación y hace el reintento
  -- idempotente incluso si dos dispositivos solicitan la misma semana.
  select id into v_goal from public.preparation_goals
  where id = p_goal_id and user_id = v_user and status = 'active'
    and program_id = 'fas_periodic_assessment' for update;
  if not found then raise exception 'Active FAS preparation not found'; end if;
  select * into v_existing from public.running_week_decisions
  where preparation_goal_id = p_goal_id and week_start = p_week_start;
  if found then
    return v_existing.decision || jsonb_build_object(
      'decision_id', v_existing.id, 'already_published', true);
  end if;

  v_plan := public.calculate_fas_running_week(p_goal_id, p_week_start);
  insert into public.running_week_decisions (
    user_id, preparation_goal_id, week_start, policy_version, basis,
    outcome, reference_source, reference_record_id, input_snapshot, decision
  ) values (
    v_user, p_goal_id, p_week_start, v_plan ->> 'policy_version',
    v_plan ->> 'basis', v_plan ->> 'outcome',
    v_plan ->> 'reference_source', v_plan ->> 'reference_record_id',
    v_plan - 'sessions', v_plan
  ) returning id into v_decision_id;

  for v_session in select value from jsonb_array_elements(v_plan -> 'sessions') loop
    v_kind := v_session ->> 'kind';
    v_minutes := (v_session ->> 'minutes')::integer;
    v_date := (v_session ->> 'date')::date;
    v_name := case v_kind
      when 'controlled_quality' then 'Carrera · calidad controlada'
      when 'walk_run' then 'Carrera · caminar y trotar'
      else 'Carrera · fácil' end;
    v_description := case v_kind
      when 'controlled_quality' then
        '10 min fáciles, 4 × 2 min vivos pero controlados con 2 min de trote suave entre repeticiones, y vuelta a la calma fácil. Intensidad por sensación; el 2 km no fija el ritmo.'
      when 'walk_run' then
        '5 min andando, 8 × (1 min trote cómodo + 1 min 30 s andando), 5 min andando.'
      else 'Carrera cómoda a ritmo que permita conversar.' end;
    insert into public.workout_templates (
      name, description, origin, owner_user_id, visibility, status,
      estimated_duration_minutes, version
    ) values (
      v_name, v_description, 'algorithm', v_user, 'private', 'published',
      v_minutes, 1
    ) returning id into v_template_id;
    insert into public.workout_blocks (
      template_id, order_index, name, format
    ) values (v_template_id, 0, v_name, 'running')
      returning id into v_block_id;
    insert into public.workout_items (
      block_id, exercise_id, order_index, notes
    ) values (
      v_block_id, '20000000-0000-4000-8000-000000000004', 0,
      v_description
    ) returning id into v_item_id;

    if v_kind = 'easy' then
      insert into public.workout_sets (
        item_id, order_index, target_duration_seconds
      ) values (v_item_id, 0, v_minutes * 60);
    elsif v_kind = 'walk_run' then
      insert into public.workout_sets (
        item_id, order_index, target_duration_seconds
      ) values (v_item_id, 0, 300);
      for v_order in 1..8 loop
        insert into public.workout_sets (
          item_id, order_index, target_duration_seconds,
          recovery_type, recovery_duration_seconds
        ) values (v_item_id, v_order, 60, 'walking', 90);
      end loop;
      insert into public.workout_sets (
        item_id, order_index, target_duration_seconds
      ) values (v_item_id, 9, 300);
    else
      insert into public.workout_sets (
        item_id, order_index, target_duration_seconds
      ) values (v_item_id, 0, 600);
      for v_order in 1..4 loop
        insert into public.workout_sets (
          item_id, order_index, target_duration_seconds,
          recovery_type, recovery_duration_seconds
        ) values (
          v_item_id, v_order, 120,
          case when v_order < 4 then 'jogging' else null end,
          case when v_order < 4 then 120 else null end
        );
      end loop;
      insert into public.workout_sets (
        item_id, order_index, target_duration_seconds
      ) values (v_item_id, 5, (v_minutes - 28) * 60);
    end if;

    insert into public.scheduled_workouts (
      user_id, template_id, template_name, template_version,
      estimated_duration_minutes, preparation_goal_id, scheduled_date,
      source, status
    ) values (
      v_user, v_template_id, v_name, 1, v_minutes,
      p_goal_id, v_date, 'algorithm', 'planned'
    ) returning id into v_schedule_id;
    insert into public.running_week_sessions (
      decision_id, scheduled_workout_id, kind, planned_minutes
    ) values (v_decision_id, v_schedule_id, v_kind, v_minutes);
  end loop;
  return v_plan || jsonb_build_object(
    'decision_id', v_decision_id, 'already_published', false);
end;
$$;

revoke all on function public.publish_fas_running_week(uuid, date)
  from public, anon, authenticated;
grant execute on function public.publish_fas_running_week(uuid, date)
  to authenticated;

commit;
