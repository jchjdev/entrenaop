-- Evaluación periódica FAS 2027 independiente del ingreso a Tropa.
-- Se guardan mediciones declaradas por el usuario, nunca aptitud oficial.
-- Solo usamos el umbral que alcanza al menos 20 puntos del anexo II; la
-- puntuación completa no se infiere de estos mínimos.
begin;

insert into public.assessment_catalogs (version, name, source_url, effective_from)
values ('es_def_15_2026_periodic_2027_v1', 'Evaluación periódica FAS 2027 · mínimos de 20 puntos',
  'https://www.boe.es/eli/es/o/2026/01/13/def15', date '2027-01-01');

insert into public.preparation_program_catalogs (program_id, catalog_version, is_current)
values ('fas_periodic_assessment', 'es_def_15_2026_periodic_2027_v1', true);

create table public.fas_periodic_standards (
  catalog_version text not null references public.assessment_catalogs(version) on delete restrict,
  test_id text not null references public.physical_test_definitions(id) on delete restrict,
  age_band text not null check (age_band in ('17_25','26_30','31_35','36_40','41_45','46_50','51_55','56_59','60_plus')),
  category text not null check (category in ('men','women')),
  threshold bigint not null check (threshold >= 0),
  primary key (catalog_version, test_id, age_band, category)
);

insert into public.fas_periodic_standards
  (catalog_version, test_id, age_band, category, threshold)
values
  ('es_def_15_2026_periodic_2027_v1', 'upper_body_push_ups_2_min', '17_25', 'men', 14),
  ('es_def_15_2026_periodic_2027_v1', 'upper_body_push_ups_2_min', '17_25', 'women', 8),
  ('es_def_15_2026_periodic_2027_v1', 'upper_body_push_ups_2_min', '26_30', 'men', 13),
  ('es_def_15_2026_periodic_2027_v1', 'upper_body_push_ups_2_min', '26_30', 'women', 7),
  ('es_def_15_2026_periodic_2027_v1', 'upper_body_push_ups_2_min', '31_35', 'men', 12),
  ('es_def_15_2026_periodic_2027_v1', 'upper_body_push_ups_2_min', '31_35', 'women', 6),
  ('es_def_15_2026_periodic_2027_v1', 'upper_body_push_ups_2_min', '36_40', 'men', 11),
  ('es_def_15_2026_periodic_2027_v1', 'upper_body_push_ups_2_min', '36_40', 'women', 5),
  ('es_def_15_2026_periodic_2027_v1', 'upper_body_push_ups_2_min', '41_45', 'men', 10),
  ('es_def_15_2026_periodic_2027_v1', 'upper_body_push_ups_2_min', '41_45', 'women', 4),
  ('es_def_15_2026_periodic_2027_v1', 'upper_body_push_ups_2_min', '46_50', 'men', 9),
  ('es_def_15_2026_periodic_2027_v1', 'upper_body_push_ups_2_min', '46_50', 'women', 3),
  ('es_def_15_2026_periodic_2027_v1', 'upper_body_push_ups_2_min', '51_55', 'men', 8),
  ('es_def_15_2026_periodic_2027_v1', 'upper_body_push_ups_2_min', '51_55', 'women', 3),
  ('es_def_15_2026_periodic_2027_v1', 'upper_body_push_ups_2_min', '56_59', 'men', 6),
  ('es_def_15_2026_periodic_2027_v1', 'upper_body_push_ups_2_min', '56_59', 'women', 3),
  ('es_def_15_2026_periodic_2027_v1', 'upper_body_push_ups_2_min', '60_plus', 'men', 5),
  ('es_def_15_2026_periodic_2027_v1', 'upper_body_push_ups_2_min', '60_plus', 'women', 2),
  ('es_def_15_2026_periodic_2027_v1', 'abdominal_plank', '17_25', 'men', 40000),
  ('es_def_15_2026_periodic_2027_v1', 'abdominal_plank', '17_25', 'women', 40000),
  ('es_def_15_2026_periodic_2027_v1', 'abdominal_plank', '26_30', 'men', 36000),
  ('es_def_15_2026_periodic_2027_v1', 'abdominal_plank', '26_30', 'women', 36000),
  ('es_def_15_2026_periodic_2027_v1', 'abdominal_plank', '31_35', 'men', 35000),
  ('es_def_15_2026_periodic_2027_v1', 'abdominal_plank', '31_35', 'women', 35000),
  ('es_def_15_2026_periodic_2027_v1', 'abdominal_plank', '36_40', 'men', 34000),
  ('es_def_15_2026_periodic_2027_v1', 'abdominal_plank', '36_40', 'women', 34000),
  ('es_def_15_2026_periodic_2027_v1', 'abdominal_plank', '41_45', 'men', 33000),
  ('es_def_15_2026_periodic_2027_v1', 'abdominal_plank', '41_45', 'women', 33000),
  ('es_def_15_2026_periodic_2027_v1', 'abdominal_plank', '46_50', 'men', 32000),
  ('es_def_15_2026_periodic_2027_v1', 'abdominal_plank', '46_50', 'women', 32000),
  ('es_def_15_2026_periodic_2027_v1', 'abdominal_plank', '51_55', 'men', 31000),
  ('es_def_15_2026_periodic_2027_v1', 'abdominal_plank', '51_55', 'women', 31000),
  ('es_def_15_2026_periodic_2027_v1', 'abdominal_plank', '56_59', 'men', 30000),
  ('es_def_15_2026_periodic_2027_v1', 'abdominal_plank', '56_59', 'women', 30000),
  ('es_def_15_2026_periodic_2027_v1', 'abdominal_plank', '60_plus', 'men', 28000),
  ('es_def_15_2026_periodic_2027_v1', 'abdominal_plank', '60_plus', 'women', 28000),
  ('es_def_15_2026_periodic_2027_v1', 'run_2000_m', '17_25', 'men', 706000),
  ('es_def_15_2026_periodic_2027_v1', 'run_2000_m', '17_25', 'women', 754000),
  ('es_def_15_2026_periodic_2027_v1', 'run_2000_m', '26_30', 'men', 714000),
  ('es_def_15_2026_periodic_2027_v1', 'run_2000_m', '26_30', 'women', 762000),
  ('es_def_15_2026_periodic_2027_v1', 'run_2000_m', '31_35', 'men', 722000),
  ('es_def_15_2026_periodic_2027_v1', 'run_2000_m', '31_35', 'women', 770000),
  ('es_def_15_2026_periodic_2027_v1', 'run_2000_m', '36_40', 'men', 730000),
  ('es_def_15_2026_periodic_2027_v1', 'run_2000_m', '36_40', 'women', 786000),
  ('es_def_15_2026_periodic_2027_v1', 'run_2000_m', '41_45', 'men', 738000),
  ('es_def_15_2026_periodic_2027_v1', 'run_2000_m', '41_45', 'women', 802000),
  ('es_def_15_2026_periodic_2027_v1', 'run_2000_m', '46_50', 'men', 754000),
  ('es_def_15_2026_periodic_2027_v1', 'run_2000_m', '46_50', 'women', 818000),
  ('es_def_15_2026_periodic_2027_v1', 'run_2000_m', '51_55', 'men', 794000),
  ('es_def_15_2026_periodic_2027_v1', 'run_2000_m', '51_55', 'women', 898000),
  ('es_def_15_2026_periodic_2027_v1', 'run_2000_m', '56_59', 'men', 826000),
  ('es_def_15_2026_periodic_2027_v1', 'run_2000_m', '56_59', 'women', 990000),
  ('es_def_15_2026_periodic_2027_v1', 'run_2000_m', '60_plus', 'men', 842000),
  ('es_def_15_2026_periodic_2027_v1', 'run_2000_m', '60_plus', 'women', 1006000),
  ('es_def_15_2026_periodic_2027_v1', 'agility_speed_circuit', '17_25', 'men', 15200),
  ('es_def_15_2026_periodic_2027_v1', 'agility_speed_circuit', '17_25', 'women', 16700),
  ('es_def_15_2026_periodic_2027_v1', 'agility_speed_circuit', '26_30', 'men', 15400),
  ('es_def_15_2026_periodic_2027_v1', 'agility_speed_circuit', '26_30', 'women', 16900),
  ('es_def_15_2026_periodic_2027_v1', 'agility_speed_circuit', '31_35', 'men', 15600),
  ('es_def_15_2026_periodic_2027_v1', 'agility_speed_circuit', '31_35', 'women', 17100),
  ('es_def_15_2026_periodic_2027_v1', 'agility_speed_circuit', '36_40', 'men', 15800),
  ('es_def_15_2026_periodic_2027_v1', 'agility_speed_circuit', '36_40', 'women', 17300),
  ('es_def_15_2026_periodic_2027_v1', 'agility_speed_circuit', '41_45', 'men', 16200),
  ('es_def_15_2026_periodic_2027_v1', 'agility_speed_circuit', '41_45', 'women', 17800);

create table public.fas_periodic_assessments (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  preparation_goal_id uuid not null references public.preparation_goals(id) on delete restrict,
  catalog_version text not null references public.assessment_catalogs(version) on delete restrict,
  category text not null check (category in ('men','women')),
  age_at_assessment integer not null check (age_at_assessment between 17 and 120),
  age_band text not null,
  completed_at timestamptz not null default now(),
  is_pre_effective_reference boolean not null,
  created_at timestamptz not null default now()
);

create table public.fas_periodic_marks (
  assessment_id uuid not null references public.fas_periodic_assessments(id) on delete cascade,
  test_id text not null references public.physical_test_definitions(id) on delete restrict,
  value bigint not null check (value >= 0),
  primary key (assessment_id, test_id)
);

create index fas_periodic_assessments_user_date_idx
  on public.fas_periodic_assessments(user_id, completed_at desc);
create index fas_periodic_assessments_goal_date_idx
  on public.fas_periodic_assessments(preparation_goal_id, completed_at desc);

alter table public.fas_periodic_standards enable row level security;
alter table public.fas_periodic_assessments enable row level security;
alter table public.fas_periodic_marks enable row level security;
revoke all on public.fas_periodic_standards from anon, authenticated;
revoke all on public.fas_periodic_assessments from anon, authenticated;
revoke all on public.fas_periodic_marks from anon, authenticated;
grant select on public.fas_periodic_standards to authenticated;
grant select on public.fas_periodic_assessments to authenticated;
grant select on public.fas_periodic_marks to authenticated;

create policy fas_periodic_standards_read on public.fas_periodic_standards
  for select to authenticated using (true);
create policy fas_periodic_assessments_read_own on public.fas_periodic_assessments
  for select to authenticated using (user_id = (select auth.uid()));
create policy fas_periodic_marks_read_own on public.fas_periodic_marks
  for select to authenticated using (exists (
    select 1 from public.fas_periodic_assessments a
    where a.id = assessment_id and a.user_id = (select auth.uid())
  ));

create or replace function public.record_fas_periodic_assessment(
  p_preparation_goal_id uuid,
  p_category text,
  p_age integer,
  p_marks jsonb,
  p_completed_at timestamptz default now()
) returns uuid
language plpgsql security definer set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_band text;
  v_expected integer;
  v_actual integer;
  v_distinct integer;
  v_valid boolean;
  v_id uuid;
  v_catalog constant text := 'es_def_15_2026_periodic_2027_v1';
begin
  if v_user_id is null then
    raise exception 'Authentication is required.' using errcode = '42501';
  end if;
  if not exists (
    select 1 from public.preparation_goals g
    where g.id = p_preparation_goal_id and g.user_id = v_user_id
      and g.program_id = 'fas_periodic_assessment' and g.status = 'active'
  ) then
    raise exception 'Preparación FAS no disponible.' using errcode = '42501';
  end if;
  if p_category is null or p_category not in ('men','women')
      or p_age is null or p_age not between 17 and 120
      or p_completed_at is null or p_completed_at > now() + interval '5 minutes'
      or p_completed_at < date '2026-01-21' then
    raise exception 'Datos de evaluación no válidos.' using errcode = '22023';
  end if;
  if jsonb_typeof(p_marks) is distinct from 'array' then
    raise exception 'Las marcas deben ser una lista.' using errcode = '22023';
  end if;

  v_band := case
    when p_age <= 25 then '17_25'
    when p_age <= 30 then '26_30'
    when p_age <= 35 then '31_35'
    when p_age <= 40 then '36_40'
    when p_age <= 45 then '41_45'
    when p_age <= 50 then '46_50'
    when p_age <= 55 then '51_55'
    when p_age <= 59 then '56_59'
    else '60_plus'
  end;
  select count(*) into v_expected
  from public.fas_periodic_standards s
  where s.catalog_version = v_catalog and s.age_band = v_band
    and s.category = p_category
    and (p_age < 45 or s.test_id <> 'agility_speed_circuit');
  select count(*), count(distinct x.test_id),
    coalesce(bool_and(x.value is not null and x.value >= 0), false)
  into v_actual, v_distinct, v_valid
  from jsonb_to_recordset(p_marks) as x(test_id text, value bigint);
  if v_actual <> v_expected or v_distinct <> v_expected or not v_valid
      or exists (
        select 1 from jsonb_to_recordset(p_marks) as x(test_id text, value bigint)
        left join public.fas_periodic_standards s
          on s.catalog_version = v_catalog and s.age_band = v_band
          and s.category = p_category and s.test_id = x.test_id
        where s.test_id is null
          or (p_age >= 45 and x.test_id = 'agility_speed_circuit')
      ) then
    raise exception 'Marcas incompletas o ajenas al baremo.' using errcode = '22023';
  end if;

  insert into public.fas_periodic_assessments
    (user_id, preparation_goal_id, catalog_version, category,
     age_at_assessment, age_band, completed_at, is_pre_effective_reference)
  values (v_user_id, p_preparation_goal_id, v_catalog, p_category,
    p_age, v_band, p_completed_at, p_completed_at::date < date '2027-01-01')
  returning id into v_id;
  insert into public.fas_periodic_marks (assessment_id, test_id, value)
  select v_id, x.test_id, x.value
  from jsonb_to_recordset(p_marks) as x(test_id text, value bigint);
  return v_id;
end;
$$;

revoke all on function public.record_fas_periodic_assessment(uuid,text,integer,jsonb,timestamptz)
  from public, anon;
grant execute on function public.record_fas_periodic_assessment(uuid,text,integer,jsonb,timestamptz)
  to authenticated;

create view public.fas_periodic_results with (security_invoker = true) as
select a.id as assessment_id, a.user_id, a.preparation_goal_id,
  a.catalog_version, a.category, a.age_at_assessment, a.age_band,
  a.completed_at, a.is_pre_effective_reference, m.test_id,
  t.name as test_name, t.unit, t.better_direction, m.value,
  s.threshold,
  case t.better_direction when 'higher' then m.value >= s.threshold
    when 'lower' then m.value <= s.threshold end as meets_minimum
from public.fas_periodic_assessments a
join public.fas_periodic_marks m on m.assessment_id = a.id
join public.fas_periodic_standards s
  on s.catalog_version = a.catalog_version and s.age_band = a.age_band
  and s.category = a.category and s.test_id = m.test_id
join public.physical_test_definitions t on t.id = m.test_id;
revoke all on public.fas_periodic_results from anon, authenticated;
grant select on public.fas_periodic_results to authenticated;

-- Solo ahora que hay validación y lectura separadas se publica el programa.
update public.preparation_programs set enabled = true
where id = 'fas_periodic_assessment' and kind = 'internal_assessment';
commit;
