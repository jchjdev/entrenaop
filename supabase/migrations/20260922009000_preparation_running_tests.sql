-- Los controles de carrera pertenecen a una preparación, no al perfil global.
-- El protocolo queda versionado para que el futuro motor no reinterprete marcas.
begin;

create table public.preparation_running_tests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  preparation_goal_id uuid not null references public.preparation_goals (id) on delete cascade,
  protocol_version text not null default 'run_2000m_v1',
  completed_at timestamptz not null default now(),
  duration_seconds integer not null,
  rpe integer not null,
  average_hr_bpm integer,
  max_hr_bpm integer,
  notes text,
  splits_seconds integer[],
  created_at timestamptz not null default now(),
  constraint running_tests_protocol_check check (protocol_version = 'run_2000m_v1'),
  constraint running_tests_duration_check check (duration_seconds between 120 and 7200),
  constraint running_tests_rpe_check check (rpe between 1 and 10),
  constraint running_tests_average_hr_check check (average_hr_bpm is null or average_hr_bpm between 30 and 250),
  constraint running_tests_max_hr_check check (max_hr_bpm is null or max_hr_bpm between 30 and 250),
  constraint running_tests_hr_order_check check (average_hr_bpm is null or max_hr_bpm is null or average_hr_bpm <= max_hr_bpm),
  constraint running_tests_notes_check check (notes is null or char_length(notes) <= 1000),
  constraint running_tests_splits_check check (
    splits_seconds is null or (
      coalesce(array_ndims(splits_seconds) = 1, false)
      and coalesce(array_length(splits_seconds, 1) = 5, false)
      and array_position(splits_seconds, null) is null
      and splits_seconds[1] > 0 and splits_seconds[2] > 0
      and splits_seconds[3] > 0 and splits_seconds[4] > 0
      and splits_seconds[5] > 0
      and splits_seconds[1] + splits_seconds[2] + splits_seconds[3]
        + splits_seconds[4] + splits_seconds[5] = duration_seconds
    )
  )
);

create index preparation_running_tests_goal_date_idx
on public.preparation_running_tests (preparation_goal_id, completed_at desc);

alter table public.preparation_running_tests enable row level security;
revoke all on table public.preparation_running_tests from anon, authenticated;
grant select, insert on table public.preparation_running_tests to authenticated;

create policy running_tests_select_own
on public.preparation_running_tests for select to authenticated
using (user_id = (select auth.uid()));

create policy running_tests_insert_own_goal
on public.preparation_running_tests for insert to authenticated
with check (
  user_id = (select auth.uid())
  and exists (
    select 1 from public.preparation_goals as goal
    where goal.id = preparation_goal_id
      and goal.user_id = (select auth.uid())
      and goal.status = 'active'
  )
);

commit;
