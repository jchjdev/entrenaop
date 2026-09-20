-- Historial versionado de evaluaciones físicas.
--
-- El cliente solo envía marcas sin procesar. PostgreSQL valida que el catálogo,
-- el hito y las cuatro pruebas formen un conjunto coherente antes de guardar la
-- evaluación. Esto evita confiar en un resultado `apto` calculado por Flutter.

begin;

create table public.assessment_catalogs (
  version text primary key,
  name text not null,
  source_url text not null,
  effective_from date not null,
  created_at timestamptz not null default now(),
  constraint assessment_catalogs_version_not_blank
    check (btrim(version) <> ''),
  constraint assessment_catalogs_name_not_blank
    check (btrim(name) <> '')
);

create table public.physical_test_definitions (
  id text primary key,
  name text not null,
  unit text not null,
  better_direction text not null,
  created_at timestamptz not null default now(),
  constraint physical_test_definitions_id_not_blank
    check (btrim(id) <> ''),
  constraint physical_test_definitions_name_not_blank
    check (btrim(name) <> ''),
  constraint physical_test_definitions_unit_check
    check (unit in ('repetitions', 'milliseconds')),
  constraint physical_test_definitions_direction_check
    check (better_direction in ('higher', 'lower'))
);

create table public.assessment_standards (
  catalog_version text not null
    references public.assessment_catalogs (version) on delete restrict,
  test_id text not null
    references public.physical_test_definitions (id) on delete restrict,
  category text not null,
  milestone text not null,
  threshold bigint not null,
  created_at timestamptz not null default now(),
  primary key (catalog_version, test_id, category, milestone),
  constraint assessment_standards_category_check
    check (category in ('men', 'women')),
  constraint assessment_standards_milestone_check
    check (
      milestone in (
        'entry',
        'end_of_general_military_training',
        'end_of_training'
      )
    ),
  constraint assessment_standards_threshold_nonnegative
    check (threshold >= 0)
);

create table public.physical_assessments (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null
    references public.profiles (id) on delete cascade,
  catalog_version text not null
    references public.assessment_catalogs (version) on delete restrict,
  category text not null,
  milestone text not null,
  completed_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  constraint physical_assessments_category_check
    check (category in ('men', 'women')),
  constraint physical_assessments_milestone_check
    check (
      milestone in (
        'entry',
        'end_of_general_military_training',
        'end_of_training'
      )
    )
);

create table public.physical_assessment_marks (
  assessment_id uuid not null
    references public.physical_assessments (id) on delete cascade,
  test_id text not null
    references public.physical_test_definitions (id) on delete restrict,
  value bigint not null,
  created_at timestamptz not null default now(),
  primary key (assessment_id, test_id),
  constraint physical_assessment_marks_value_nonnegative
    check (value >= 0)
);

create index physical_assessments_user_completed_at_idx
  on public.physical_assessments (user_id, completed_at desc);
create index physical_assessment_marks_test_id_idx
  on public.physical_assessment_marks (test_id);

-- Catálogo oficial inicial. Las magnitudes cronometradas se expresan siempre
-- en milisegundos, incluidas las décimas del circuito de agilidad.
insert into public.assessment_catalogs (
  version,
  name,
  source_url,
  effective_from
)
values (
  'es_def_15_2026_troop_v1',
  'Ingreso y formación de tropa y marinería (Orden DEF/15/2026)',
  'https://www.boe.es/eli/es/o/2026/01/13/def15',
  date '2026-01-22'
);

insert into public.physical_test_definitions (
  id,
  name,
  unit,
  better_direction
)
values
  (
    'upper_body_push_ups_2_min',
    'Flexo-extensiones de brazos (2 min)',
    'repetitions',
    'higher'
  ),
  (
    'abdominal_plank',
    'Plancha isométrica',
    'milliseconds',
    'higher'
  ),
  (
    'run_2000_m',
    'Carrera continua de 2.000 m',
    'milliseconds',
    'lower'
  ),
  (
    'agility_speed_circuit',
    'Circuito de agilidad-velocidad',
    'milliseconds',
    'lower'
  );

insert into public.assessment_standards (
  catalog_version,
  test_id,
  category,
  milestone,
  threshold
)
values
  ('es_def_15_2026_troop_v1', 'upper_body_push_ups_2_min', 'men', 'entry', 9),
  ('es_def_15_2026_troop_v1', 'upper_body_push_ups_2_min', 'men', 'end_of_general_military_training', 13),
  ('es_def_15_2026_troop_v1', 'upper_body_push_ups_2_min', 'men', 'end_of_training', 15),
  ('es_def_15_2026_troop_v1', 'upper_body_push_ups_2_min', 'women', 'entry', 5),
  ('es_def_15_2026_troop_v1', 'upper_body_push_ups_2_min', 'women', 'end_of_general_military_training', 7),
  ('es_def_15_2026_troop_v1', 'upper_body_push_ups_2_min', 'women', 'end_of_training', 8),
  ('es_def_15_2026_troop_v1', 'abdominal_plank', 'men', 'entry', 40000),
  ('es_def_15_2026_troop_v1', 'abdominal_plank', 'men', 'end_of_general_military_training', 44000),
  ('es_def_15_2026_troop_v1', 'abdominal_plank', 'men', 'end_of_training', 48000),
  ('es_def_15_2026_troop_v1', 'abdominal_plank', 'women', 'entry', 40000),
  ('es_def_15_2026_troop_v1', 'abdominal_plank', 'women', 'end_of_general_military_training', 44000),
  ('es_def_15_2026_troop_v1', 'abdominal_plank', 'women', 'end_of_training', 48000),
  ('es_def_15_2026_troop_v1', 'run_2000_m', 'men', 'entry', 714000),
  ('es_def_15_2026_troop_v1', 'run_2000_m', 'men', 'end_of_general_military_training', 706000),
  ('es_def_15_2026_troop_v1', 'run_2000_m', 'men', 'end_of_training', 690000),
  ('es_def_15_2026_troop_v1', 'run_2000_m', 'women', 'entry', 778000),
  ('es_def_15_2026_troop_v1', 'run_2000_m', 'women', 'end_of_general_military_training', 762000),
  ('es_def_15_2026_troop_v1', 'run_2000_m', 'women', 'end_of_training', 754000),
  ('es_def_15_2026_troop_v1', 'agility_speed_circuit', 'men', 'entry', 15400),
  ('es_def_15_2026_troop_v1', 'agility_speed_circuit', 'men', 'end_of_general_military_training', 15200),
  ('es_def_15_2026_troop_v1', 'agility_speed_circuit', 'men', 'end_of_training', 15000),
  ('es_def_15_2026_troop_v1', 'agility_speed_circuit', 'women', 'entry', 17100),
  ('es_def_15_2026_troop_v1', 'agility_speed_circuit', 'women', 'end_of_general_military_training', 16900),
  ('es_def_15_2026_troop_v1', 'agility_speed_circuit', 'women', 'end_of_training', 16700);

alter table public.assessment_catalogs enable row level security;
alter table public.physical_test_definitions enable row level security;
alter table public.assessment_standards enable row level security;
alter table public.physical_assessments enable row level security;
alter table public.physical_assessment_marks enable row level security;

revoke all on table public.assessment_catalogs from anon, authenticated;
revoke all on table public.physical_test_definitions from anon, authenticated;
revoke all on table public.assessment_standards from anon, authenticated;
revoke all on table public.physical_assessments from anon, authenticated;
revoke all on table public.physical_assessment_marks from anon, authenticated;

grant select on table public.assessment_catalogs to anon, authenticated;
grant select on table public.physical_test_definitions to anon, authenticated;
grant select on table public.assessment_standards to anon, authenticated;
grant select on table public.physical_assessments to authenticated;
grant select on table public.physical_assessment_marks to authenticated;

create policy assessment_catalogs_select_all
on public.assessment_catalogs
for select
to anon, authenticated
using (true);

create policy physical_test_definitions_select_all
on public.physical_test_definitions
for select
to anon, authenticated
using (true);

create policy assessment_standards_select_all
on public.assessment_standards
for select
to anon, authenticated
using (true);

create policy physical_assessments_select_own
on public.physical_assessments
for select
to authenticated
using (user_id = (select auth.uid()) or (select public.is_admin()));

create policy physical_assessment_marks_select_own
on public.physical_assessment_marks
for select
to authenticated
using (
  exists (
    select 1
    from public.physical_assessments
    where physical_assessments.id = physical_assessment_marks.assessment_id
      and (
        physical_assessments.user_id = (select auth.uid())
        or (select public.is_admin())
      )
  )
);

-- Una sola llamada crea la cabecera y todas las marcas. Si cualquier
-- validación o inserción falla, PostgreSQL revierte la operación completa.
create or replace function public.record_physical_assessment(
  p_catalog_version text,
  p_category text,
  p_milestone text,
  p_marks jsonb,
  p_completed_at timestamptz default now()
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_assessment_id uuid;
  v_expected_count integer;
  v_mark_count integer;
  v_distinct_mark_count integer;
  v_all_values_valid boolean;
begin
  if v_user_id is null then
    raise exception 'Authentication is required.' using errcode = '42501';
  end if;

  if p_category not in ('men', 'women') then
    raise exception 'Unknown assessment category.' using errcode = '22023';
  end if;

  if p_milestone not in (
    'entry',
    'end_of_general_military_training',
    'end_of_training'
  ) then
    raise exception 'Unknown assessment milestone.' using errcode = '22023';
  end if;

  if jsonb_typeof(p_marks) is distinct from 'array' then
    raise exception 'Marks must be a JSON array.' using errcode = '22023';
  end if;

  if p_completed_at > now() + interval '5 minutes' then
    raise exception 'Completion time cannot be in the future.'
      using errcode = '22023';
  end if;

  select count(*)
  into v_expected_count
  from public.assessment_standards
  where catalog_version = p_catalog_version
    and category = p_category
    and milestone = p_milestone;

  if v_expected_count = 0 then
    raise exception 'No standards exist for this assessment.'
      using errcode = '22023';
  end if;

  select
    count(*),
    count(distinct input.test_id),
    coalesce(bool_and(input.value >= 0), false)
  into v_mark_count, v_distinct_mark_count, v_all_values_valid
  from jsonb_to_recordset(p_marks) as input(test_id text, value bigint);

  if v_mark_count <> v_expected_count
    or v_distinct_mark_count <> v_expected_count
    or not v_all_values_valid
  then
    raise exception 'A unique nonnegative mark is required for every test.'
      using errcode = '22023';
  end if;

  if exists (
    select 1
    from jsonb_to_recordset(p_marks) as input(test_id text, value bigint)
    left join public.assessment_standards as standard
      on standard.catalog_version = p_catalog_version
      and standard.category = p_category
      and standard.milestone = p_milestone
      and standard.test_id = input.test_id
    where standard.test_id is null
  ) then
    raise exception 'At least one mark does not belong to this assessment.'
      using errcode = '22023';
  end if;

  insert into public.physical_assessments (
    user_id,
    catalog_version,
    category,
    milestone,
    completed_at
  )
  values (
    v_user_id,
    p_catalog_version,
    p_category,
    p_milestone,
    p_completed_at
  )
  returning id into v_assessment_id;

  insert into public.physical_assessment_marks (
    assessment_id,
    test_id,
    value
  )
  select v_assessment_id, input.test_id, input.value
  from jsonb_to_recordset(p_marks) as input(test_id text, value bigint);

  return v_assessment_id;
end;
$$;

revoke all on function public.record_physical_assessment(
  text,
  text,
  text,
  jsonb,
  timestamptz
) from public, anon;
grant execute on function public.record_physical_assessment(
  text,
  text,
  text,
  jsonb,
  timestamptz
) to authenticated;

-- La vista calcula el resultado desde las marcas y estándares persistidos. Al
-- ser security_invoker conserva las políticas RLS de las tablas subyacentes.
create view public.physical_assessment_results
with (security_invoker = true)
as
select
  assessment.id as assessment_id,
  assessment.user_id,
  assessment.catalog_version,
  assessment.category,
  assessment.milestone,
  assessment.completed_at,
  mark.test_id,
  test.name as test_name,
  test.unit,
  test.better_direction,
  mark.value,
  standard.threshold,
  case test.better_direction
    when 'higher' then mark.value >= standard.threshold
    when 'lower' then mark.value <= standard.threshold
  end as passed
from public.physical_assessments as assessment
join public.physical_assessment_marks as mark
  on mark.assessment_id = assessment.id
join public.assessment_standards as standard
  on standard.catalog_version = assessment.catalog_version
  and standard.category = assessment.category
  and standard.milestone = assessment.milestone
  and standard.test_id = mark.test_id
join public.physical_test_definitions as test
  on test.id = mark.test_id;

revoke all on table public.physical_assessment_results from anon, authenticated;
grant select on table public.physical_assessment_results to authenticated;

commit;
