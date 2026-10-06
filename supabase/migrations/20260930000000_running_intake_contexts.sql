-- Contexto declarado por el deportista para la preparación de carrera.
-- No contiene marcas oficiales, puntos ni sesiones prescritas.
begin;

create function public.valid_running_intake_context(
  p_availability jsonb,
  p_strength_days smallint[],
  p_running_days smallint[],
  p_running_minutes integer[]
) returns boolean
language plpgsql immutable
set search_path = ''
as $$
declare
  v_item record;
  v_day smallint;
  v_index integer;
begin
  if jsonb_typeof(p_availability) <> 'object'
    or p_availability = '{}'::jsonb
    or cardinality(p_running_days) <> 4
    or cardinality(p_running_minutes) <> 4 then
    return false;
  end if;

  for v_item in select key, value from pg_catalog.jsonb_each_text(p_availability) loop
    if v_item.key !~ '^[1-7]$'
      or v_item.value !~ '^[0-9]+$'
      or v_item.value::integer not between 20 and 240 then
      return false;
    end if;
  end loop;

  foreach v_day in array p_strength_days loop
    if v_day not between 1 and 7
      or not p_availability ? v_day::text then
      return false;
    end if;
  end loop;

  for v_index in 1..4 loop
    if p_running_days[v_index] is null
      or p_running_minutes[v_index] is null
      or p_running_days[v_index] not between 0 and 7
      or p_running_minutes[v_index] not between 0 and 1200
      or (p_running_days[v_index] = 0) <> (p_running_minutes[v_index] = 0)
      then return false;
    end if;
  end loop;
  return true;
exception when others then
  return false;
end;
$$;

create table public.running_intake_contexts (
  preparation_goal_id uuid primary key
    references public.preparation_goals (id) on delete cascade,
  context_version text not null default 'running_initial_context_v1',
  available_minutes_by_weekday jsonb not null,
  reserved_strength_weekdays smallint[] not null default '{}',
  running_days_last_four_weeks smallint[] not null,
  running_minutes_last_four_weeks integer[] not null,
  recent_weeks_end_on date not null,
  reports_pain boolean not null,
  health_observed_at timestamptz not null,
  updated_at timestamptz not null default now(),
  constraint running_intake_context_version_check
    check (context_version = 'running_initial_context_v1'),
  constraint running_intake_context_valid_check
    check (public.valid_running_intake_context(
      available_minutes_by_weekday,
      reserved_strength_weekdays,
      running_days_last_four_weeks,
      running_minutes_last_four_weeks
    ))
);

alter table public.running_intake_contexts enable row level security;
revoke all on public.running_intake_contexts from anon, authenticated;
grant select, insert, update on public.running_intake_contexts to authenticated;

create policy running_intake_select_own
on public.running_intake_contexts for select to authenticated
using (exists (
  select 1 from public.preparation_goals g
  where g.id = preparation_goal_id and g.user_id = (select auth.uid())
));

create policy running_intake_insert_active_own
on public.running_intake_contexts for insert to authenticated
with check (exists (
  select 1 from public.preparation_goals g
  where g.id = preparation_goal_id and g.user_id = (select auth.uid())
    and g.status = 'active'
));

create policy running_intake_update_active_own
on public.running_intake_contexts for update to authenticated
using (exists (
  select 1 from public.preparation_goals g
  where g.id = preparation_goal_id and g.user_id = (select auth.uid())
    and g.status = 'active'
))
with check (exists (
  select 1 from public.preparation_goals g
  where g.id = preparation_goal_id and g.user_id = (select auth.uid())
    and g.status = 'active'
));

commit;
