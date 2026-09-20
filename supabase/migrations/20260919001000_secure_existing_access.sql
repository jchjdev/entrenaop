-- Harden the recovered schema without deleting product data.

begin;

-- Administrative authority is separate from the legacy commercial role.
create table if not exists public.admin_permissions (
  user_id uuid primary key references auth.users (id) on delete cascade,
  granted_at timestamptz not null default now(),
  granted_by uuid references auth.users (id),
  reason text
);

alter table public.admin_permissions enable row level security;

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, full_name)
  values (new.id, new.raw_user_meta_data ->> 'full_name')
  on conflict (id) do nothing;
  return new;
end;
$$;

insert into public.admin_permissions (user_id, reason)
select id, 'Migrated from profiles.role during initial hardening'
from public.profiles
where role = 'admin'
on conflict (user_id) do nothing;

create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.admin_permissions
    where user_id = (select auth.uid())
  );
$$;

revoke all on function public.is_admin() from public;
grant execute on function public.is_admin() to authenticated;
revoke all on function public.handle_new_user() from public;

-- Remove the overlapping policies found in production.
drop policy if exists "Usuario edita su propio perfil" on public.profiles;
drop policy if exists "Usuario ve su propio perfil" on public.profiles;

drop policy if exists "Ejercicios públicos visibles para todos" on public.exercises;
drop policy if exists "Solo admin crea ejercicios" on public.exercises;
drop policy if exists "Solo admin edita ejercicios" on public.exercises;
drop policy if exists exercises_delete on public.exercises;
drop policy if exists exercises_insert on public.exercises;
drop policy if exists exercises_select on public.exercises;
drop policy if exists exercises_update on public.exercises;

drop policy if exists "Admin crea rutinas" on public.routines;
drop policy if exists "Usuario crea sus propias rutinas" on public.routines;
drop policy if exists "Ver rutinas propias o asignadas" on public.routines;
drop policy if exists "Ver rutinas públicas" on public.routines;
drop policy if exists routines_delete on public.routines;
drop policy if exists routines_insert on public.routines;
drop policy if exists routines_select on public.routines;
drop policy if exists routines_update on public.routines;

drop policy if exists "Ver ejercicios de rutinas accesibles" on public.routine_exercises;
drop policy if exists routine_exercises_select on public.routine_exercises;

drop policy if exists "Admin ve todos los logs" on public.session_logs;
drop policy if exists "Usuario registra sus sesiones" on public.session_logs;
drop policy if exists "Usuario ve su propio historial" on public.session_logs;
drop policy if exists session_logs_insert on public.session_logs;
drop policy if exists session_logs_select on public.session_logs;

-- RLS and grants are both required. Start from no client privileges.
revoke all on table public.profiles from anon, authenticated;
revoke all on table public.admin_permissions from anon, authenticated;
revoke all on table public.exercises from anon, authenticated;
revoke all on table public.routines from anon, authenticated;
revoke all on table public.routine_exercises from anon, authenticated;
revoke all on table public.session_logs from anon, authenticated;

grant select on table public.profiles to authenticated;
grant update (
  full_name,
  avatar_url,
  fecha_nacimiento,
  genero,
  peso_kg,
  altura_cm,
  updated_at
) on public.profiles to authenticated;

grant select on table public.exercises to anon, authenticated;
grant insert, update, delete on table public.exercises to authenticated;

grant select on table public.routines to anon, authenticated;
grant insert, update, delete on table public.routines to authenticated;

grant select, insert, update, delete
on table public.routine_exercises to authenticated;

grant select, insert on table public.session_logs to authenticated;

create policy profiles_select_own
on public.profiles
for select
to authenticated
using (id = (select auth.uid()) or (select public.is_admin()));

create policy profiles_update_own
on public.profiles
for update
to authenticated
using (id = (select auth.uid()))
with check (id = (select auth.uid()));

create policy exercises_select_public
on public.exercises
for select
to anon, authenticated
using (is_public is true);

create policy exercises_select_own
on public.exercises
for select
to authenticated
using (created_by = (select auth.uid()) or (select public.is_admin()));

create policy exercises_insert_own
on public.exercises
for insert
to authenticated
with check (
  (created_by = (select auth.uid()) and is_public is false)
  or (select public.is_admin())
);

create policy exercises_update_own
on public.exercises
for update
to authenticated
using (created_by = (select auth.uid()) or (select public.is_admin()))
with check (
  (created_by = (select auth.uid()) and is_public is false)
  or (select public.is_admin())
);

create policy exercises_delete_own
on public.exercises
for delete
to authenticated
using (created_by = (select auth.uid()) or (select public.is_admin()));

create policy routines_select_accessible
on public.routines
for select
to authenticated
using (
  is_public is true
  or created_by = (select auth.uid())
  or assigned_to = (select auth.uid())
  or (select public.is_admin())
);

create policy routines_select_public
on public.routines
for select
to anon
using (is_public is true);

create policy routines_insert_own
on public.routines
for insert
to authenticated
with check (
  (
    created_by = (select auth.uid())
    and is_public is false
    and assigned_to is null
  )
  or (select public.is_admin())
);

create policy routines_update_own
on public.routines
for update
to authenticated
using (created_by = (select auth.uid()) or (select public.is_admin()))
with check (
  (
    created_by = (select auth.uid())
    and is_public is false
    and assigned_to is null
  )
  or (select public.is_admin())
);

create policy routines_delete_own
on public.routines
for delete
to authenticated
using (created_by = (select auth.uid()) or (select public.is_admin()));

create policy routine_exercises_select_accessible
on public.routine_exercises
for select
to authenticated
using (
  exists (
    select 1
    from public.routines
    where routines.id = routine_exercises.routine_id
  )
);

create policy routine_exercises_write_owned
on public.routine_exercises
for all
to authenticated
using (
  exists (
    select 1
    from public.routines
    where routines.id = routine_exercises.routine_id
      and (
        routines.created_by = (select auth.uid())
        or (select public.is_admin())
      )
  )
)
with check (
  exists (
    select 1
    from public.routines
    where routines.id = routine_exercises.routine_id
      and (
        routines.created_by = (select auth.uid())
        or (select public.is_admin())
      )
  )
);

create policy session_logs_select_own
on public.session_logs
for select
to authenticated
using (user_id = (select auth.uid()) or (select public.is_admin()));

create policy session_logs_insert_own
on public.session_logs
for insert
to authenticated
with check (user_id = (select auth.uid()));

-- Integrity improvements that are compatible with the audited production data.
alter table public.exercises alter column is_public set not null;
alter table public.exercises alter column created_by set not null;
alter table public.exercises alter column created_at set not null;
alter table public.routines alter column is_public set not null;
alter table public.routines alter column requires_premium set not null;
alter table public.routines alter column created_by set not null;
alter table public.routines alter column created_at set not null;
alter table public.routine_exercises alter column routine_id set not null;
alter table public.routine_exercises alter column exercise_id set not null;
alter table public.session_logs alter column user_id set not null;
alter table public.session_logs alter column completed_at set not null;
alter table public.session_logs alter column completed set not null;

alter table public.profiles
  add constraint profiles_weight_positive
  check (peso_kg is null or peso_kg > 0),
  add constraint profiles_height_positive
  check (altura_cm is null or altura_cm > 0);

alter table public.routines
  add constraint routines_duration_positive
  check (estimated_duration_min is null or estimated_duration_min > 0);

alter table public.routine_exercises
  add constraint routine_exercises_order_nonnegative
  check (order_index >= 0),
  add constraint routine_exercises_sets_positive
  check (sets is null or sets > 0),
  add constraint routine_exercises_reps_nonnegative
  check (reps is null or reps >= 0),
  add constraint routine_exercises_duration_positive
  check (duration_seconds is null or duration_seconds > 0),
  add constraint routine_exercises_weight_nonnegative
  check (weight_kg is null or weight_kg >= 0),
  add constraint routine_exercises_rest_nonnegative
  check (rest_seconds is null or rest_seconds >= 0),
  add constraint routine_exercises_routine_order_unique
  unique (routine_id, order_index);

alter table public.session_logs
  add constraint session_logs_duration_nonnegative
  check (duration_min is null or duration_min >= 0);

create index if not exists exercises_created_by_idx
  on public.exercises (created_by);
create index if not exists routines_created_by_idx
  on public.routines (created_by);
create index if not exists routines_assigned_to_idx
  on public.routines (assigned_to);
create index if not exists routine_exercises_exercise_id_idx
  on public.routine_exercises (exercise_id);
create index if not exists session_logs_user_completed_at_idx
  on public.session_logs (user_id, completed_at desc);
create index if not exists session_logs_routine_id_idx
  on public.session_logs (routine_id);

commit;
