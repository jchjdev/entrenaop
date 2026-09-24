-- Una evaluación pertenece al usuario. La preparación es contexto opcional y
-- nunca condiciona que el deportista pueda registrar una marca libre.
begin;

insert into public.assessment_catalogs (version, name, source_url, effective_from)
values (
  'es_def_15_2026_periodic_2027_v2_full_scores',
  'Puntuaciones completas de evaluación periódica FAS 2027',
  'https://www.boe.es/eli/es/o/2026/01/13/def15',
  date '2027-01-01'
)
on conflict (version) do nothing;

alter table public.fas_periodic_assessments
  alter column preparation_goal_id drop not null,
  add column scoring_version text not null
    default 'es_def_15_2026_periodic_2027_v2_full_scores'
    references public.assessment_catalogs(version) on delete restrict;

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
  if p_preparation_goal_id is not null and not exists (
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

create or replace view public.fas_periodic_results
with (security_invoker = true) as
select a.id as assessment_id, a.user_id, a.preparation_goal_id,
  a.catalog_version, a.category, a.age_at_assessment, a.age_band,
  a.completed_at, a.is_pre_effective_reference, m.test_id,
  t.name as test_name, t.unit, t.better_direction, m.value,
  s.threshold,
  case t.better_direction when 'higher' then m.value >= s.threshold
    when 'lower' then m.value <= s.threshold end as meets_minimum,
  a.scoring_version
from public.fas_periodic_assessments a
join public.fas_periodic_marks m on m.assessment_id = a.id
join public.fas_periodic_standards s
  on s.catalog_version = a.catalog_version and s.age_band = a.age_band
  and s.category = a.category and s.test_id = m.test_id
join public.physical_test_definitions t on t.id = m.test_id;

commit;
