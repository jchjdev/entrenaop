-- Programas estables de preparación y objetivo activo del usuario.
--
-- Un programa no es necesariamente una oposición: también puede representar
-- una evaluación interna como PAEF o PAFA. Los baremos permanecen en catálogos
-- versionados y pueden evolucionar sin cambiar la identidad del programa.

begin;

create table public.preparation_programs (
  id text primary key,
  name text not null,
  kind text not null,
  enabled boolean not null default false,
  created_at timestamptz not null default now(),
  constraint preparation_programs_id_not_blank check (btrim(id) <> ''),
  constraint preparation_programs_name_not_blank check (btrim(name) <> ''),
  constraint preparation_programs_kind_check
    check (kind in ('access', 'internal_assessment'))
);

create table public.preparation_program_catalogs (
  program_id text not null
    references public.preparation_programs (id) on delete restrict,
  catalog_version text not null
    references public.assessment_catalogs (version) on delete restrict,
  is_current boolean not null default false,
  created_at timestamptz not null default now(),
  primary key (program_id, catalog_version)
);

create unique index preparation_program_catalogs_one_current_idx
on public.preparation_program_catalogs (program_id)
where is_current;

insert into public.preparation_programs (id, name, kind, enabled)
values (
  'armed_forces_troop_entry',
  'Ingreso · Tropa y marinería',
  'access',
  true
);

insert into public.preparation_program_catalogs (
  program_id,
  catalog_version,
  is_current
)
values (
  'armed_forces_troop_entry',
  'es_def_15_2026_troop_v1',
  true
);

alter table public.preparation_programs enable row level security;
alter table public.preparation_program_catalogs enable row level security;

revoke all on table public.preparation_programs from anon, authenticated;
revoke all on table public.preparation_program_catalogs from anon, authenticated;
grant select on table public.preparation_programs to anon, authenticated;
grant select on table public.preparation_program_catalogs to anon, authenticated;

create policy preparation_programs_select_enabled
on public.preparation_programs
for select
to anon, authenticated
using (enabled or (select public.is_admin()));

create policy preparation_program_catalogs_select_all
on public.preparation_program_catalogs
for select
to anon, authenticated
using (true);

create table public.preparation_goals (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null
    references public.profiles (id) on delete cascade,
  program_id text not null
    references public.preparation_programs (id) on delete restrict,
  target_date date,
  status text not null default 'active',
  archived_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint preparation_goals_status_check
    check (status in ('active', 'archived')),
  constraint preparation_goals_archive_consistency
    check (
      (status = 'active' and archived_at is null)
      or (status = 'archived' and archived_at is not null)
    )
);

create unique index preparation_goals_one_active_per_user_idx
on public.preparation_goals (user_id)
where status = 'active';

create index preparation_goals_user_created_at_idx
on public.preparation_goals (user_id, created_at desc);

alter table public.preparation_goals enable row level security;
revoke all on table public.preparation_goals from anon, authenticated;
grant select, insert, update on table public.preparation_goals to authenticated;

create policy preparation_goals_select_own
on public.preparation_goals
for select
to authenticated
using (user_id = (select auth.uid()));

create policy preparation_goals_insert_own
on public.preparation_goals
for insert
to authenticated
with check (
  user_id = (select auth.uid())
  and exists (
    select 1
    from public.preparation_programs
    where preparation_programs.id = preparation_goals.program_id
      and preparation_programs.enabled
  )
);

create policy preparation_goals_update_own
on public.preparation_goals
for update
to authenticated
using (user_id = (select auth.uid()))
with check (
  user_id = (select auth.uid())
  and exists (
    select 1
    from public.preparation_programs
    where preparation_programs.id = preparation_goals.program_id
      and preparation_programs.enabled
  )
);

create or replace function public.set_preparation_goals_updated_at()
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

revoke all on function public.set_preparation_goals_updated_at()
from public, anon, authenticated;

create trigger set_preparation_goals_updated_at
before update on public.preparation_goals
for each row
execute function public.set_preparation_goals_updated_at();

-- Conservamos la fecha anterior bajo un nombre explícitamente transitorio.
alter table public.training_preferences
rename column target_date to legacy_target_date;

-- El único catálogo existente pertenece al programa inicial. Los usuarios con
-- una evaluación ya guardada reciben ese objetivo sin alterar su historial.
insert into public.preparation_goals (user_id, program_id, target_date)
select distinct on (assessment.user_id)
  assessment.user_id,
  'armed_forces_troop_entry',
  preferences.legacy_target_date
from public.physical_assessments as assessment
left join public.training_preferences as preferences
  on preferences.user_id = assessment.user_id
where assessment.catalog_version = 'es_def_15_2026_troop_v1'
order by assessment.user_id, assessment.completed_at desc;

commit;
