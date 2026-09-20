-- Contexto mínimo necesario para construir una planificación realista.
-- No contiene diagnósticos ni concede derechos comerciales.

begin;

create table public.training_preferences (
  user_id uuid primary key
    references public.profiles (id) on delete cascade,
  available_days_per_week smallint not null,
  session_duration_minutes smallint not null,
  target_date date,
  experience_level text not null,
  equipment text[] not null,
  requires_professional_review boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint training_preferences_available_days_check
    check (available_days_per_week between 1 and 7),
  constraint training_preferences_session_duration_check
    check (session_duration_minutes between 15 and 180),
  constraint training_preferences_experience_check
    check (experience_level in ('starting', 'occasional', 'consistent')),
  constraint training_preferences_equipment_not_empty
    check (cardinality(equipment) > 0),
  constraint training_preferences_equipment_values
    check (
      equipment <@ array[
        'none',
        'pull_up_bar',
        'free_weights',
        'gym',
        'running_track'
      ]::text[]
    ),
  constraint training_preferences_none_is_exclusive
    check (not ('none' = any(equipment) and cardinality(equipment) > 1))
);

alter table public.training_preferences enable row level security;

revoke all on table public.training_preferences from anon, authenticated;
grant select, insert, update on table public.training_preferences
to authenticated;

create policy training_preferences_select_own
on public.training_preferences
for select
to authenticated
using (user_id = (select auth.uid()));

create policy training_preferences_insert_own
on public.training_preferences
for insert
to authenticated
with check (user_id = (select auth.uid()));

create policy training_preferences_update_own
on public.training_preferences
for update
to authenticated
using (user_id = (select auth.uid()))
with check (user_id = (select auth.uid()));

create or replace function public.set_training_preferences_updated_at()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

revoke all on function public.set_training_preferences_updated_at()
from public, anon, authenticated;

create trigger set_training_preferences_updated_at
before update on public.training_preferences
for each row
execute function public.set_training_preferences_updated_at();

commit;
