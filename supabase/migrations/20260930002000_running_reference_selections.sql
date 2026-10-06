-- Elección explícita de un intento de carrera dentro de una preparación.
-- El intento se vuelve a resolver desde su fuente antes de pautar; esta fila
-- nunca contiene una marca ni una puntuación que el cliente pueda inventar.
begin;

create table public.running_reference_selections (
  preparation_goal_id uuid primary key
    references public.preparation_goals(id) on delete cascade,
  reference_source text not null,
  reference_record_id text not null,
  selected_at timestamptz not null default now(),
  continuity_confirmed_at timestamptz,
  constraint running_reference_source_check check (
    reference_source in (
      'troopControl', 'troopOfficialAssessment',
      'fasPeriodicAssessment', 'programAssessment'
    )
  ),
  constraint running_reference_record_nonempty_check
    check (length(trim(reference_record_id)) > 0),
  constraint running_reference_confirmation_time_check
    check (continuity_confirmed_at is null or
           continuity_confirmed_at <= selected_at)
);

alter table public.running_reference_selections enable row level security;
revoke all on public.running_reference_selections from anon, authenticated;
grant select, insert, update, delete
  on public.running_reference_selections to authenticated;

create policy running_reference_select_own
on public.running_reference_selections for select to authenticated
using (exists (
  select 1 from public.preparation_goals g
  where g.id = preparation_goal_id and g.user_id = (select auth.uid())
));

create policy running_reference_insert_active_own
on public.running_reference_selections for insert to authenticated
with check (exists (
  select 1 from public.preparation_goals g
  where g.id = preparation_goal_id and g.user_id = (select auth.uid())
    and g.status = 'active'
));

create policy running_reference_update_active_own
on public.running_reference_selections for update to authenticated
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

create policy running_reference_delete_active_own
on public.running_reference_selections for delete to authenticated
using (exists (
  select 1 from public.preparation_goals g
  where g.id = preparation_goal_id and g.user_id = (select auth.uid())
    and g.status = 'active'
));

commit;
