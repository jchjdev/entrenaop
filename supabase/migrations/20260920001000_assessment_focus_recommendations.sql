-- Primera recomendación explicable basada en la evaluación física.
--
-- El margen relativo se guarda en puntos básicos: 100 equivale a 1 %. Un
-- valor negativo indica distancia pendiente al mínimo; uno positivo, colchón.

begin;

create table public.assessment_focus_recommendations (
  assessment_id uuid primary key
    references public.physical_assessments (id) on delete cascade,
  algorithm_version text not null,
  focus_test_id text not null
    references public.physical_test_definitions (id) on delete restrict,
  relative_margin_bps integer not null,
  reason text not null,
  created_at timestamptz not null default now(),
  constraint assessment_focus_algorithm_version_not_blank
    check (btrim(algorithm_version) <> ''),
  constraint assessment_focus_reason_check
    check (reason in ('below_minimum', 'smallest_safety_margin'))
);

alter table public.assessment_focus_recommendations enable row level security;

revoke all on table public.assessment_focus_recommendations
from anon, authenticated;
grant select on table public.assessment_focus_recommendations to authenticated;

create policy assessment_focus_recommendations_select_own
on public.assessment_focus_recommendations
for select
to authenticated
using (
  exists (
    select 1
    from public.physical_assessments
    where physical_assessments.id = assessment_focus_recommendations.assessment_id
      and (
        physical_assessments.user_id = (select auth.uid())
        or (select public.is_admin())
      )
  )
);

-- El trigger es diferido hasta el final de la transacción. De ese modo ve las
-- cuatro marcas juntas y genera una única recomendación, aunque sea un trigger
-- por fila. Los conflictos posteriores no modifican la decisión histórica.
create or replace function public.create_assessment_focus_recommendation()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_focus_test_id text;
  v_relative_margin_bps integer;
begin
  select
    candidate.test_id,
    candidate.relative_margin_bps
  into v_focus_test_id, v_relative_margin_bps
  from (
    select
      mark.test_id,
      round(
        (
          case test.better_direction
            when 'higher' then mark.value - standard.threshold
            when 'lower' then standard.threshold - mark.value
          end
        )::numeric * 10000 / nullif(standard.threshold, 0)
      )::integer as relative_margin_bps
    from public.physical_assessment_marks as mark
    join public.physical_assessments as assessment
      on assessment.id = mark.assessment_id
    join public.assessment_standards as standard
      on standard.catalog_version = assessment.catalog_version
      and standard.category = assessment.category
      and standard.milestone = assessment.milestone
      and standard.test_id = mark.test_id
    join public.physical_test_definitions as test
      on test.id = mark.test_id
    where mark.assessment_id = new.assessment_id
      and standard.threshold > 0
  ) as candidate
  order by candidate.relative_margin_bps, candidate.test_id
  limit 1;

  if v_focus_test_id is null then
    raise exception 'A focus recommendation requires assessment marks.'
      using errcode = '22023';
  end if;

  insert into public.assessment_focus_recommendations (
    assessment_id,
    algorithm_version,
    focus_test_id,
    relative_margin_bps,
    reason
  )
  values (
    new.assessment_id,
    'assessment_focus_v1',
    v_focus_test_id,
    v_relative_margin_bps,
    case
      when v_relative_margin_bps < 0 then 'below_minimum'
      else 'smallest_safety_margin'
    end
  )
  on conflict (assessment_id) do nothing;

  return null;
end;
$$;

revoke all on function public.create_assessment_focus_recommendation()
from public, anon, authenticated;

create constraint trigger create_assessment_focus_recommendation_after_marks
after insert on public.physical_assessment_marks
deferrable initially deferred
for each row
execute function public.create_assessment_focus_recommendation();

-- Las evaluaciones creadas antes de esta versión reciben la misma decisión que
-- habría producido v1 en el momento de guardarlas.
insert into public.assessment_focus_recommendations (
  assessment_id,
  algorithm_version,
  focus_test_id,
  relative_margin_bps,
  reason,
  created_at
)
select
  assessment.id,
  'assessment_focus_v1',
  focus.test_id,
  focus.relative_margin_bps,
  case
    when focus.relative_margin_bps < 0 then 'below_minimum'
    else 'smallest_safety_margin'
  end,
  assessment.created_at
from public.physical_assessments as assessment
cross join lateral (
  select
    mark.test_id,
    round(
      (
        case test.better_direction
          when 'higher' then mark.value - standard.threshold
          when 'lower' then standard.threshold - mark.value
        end
      )::numeric * 10000 / nullif(standard.threshold, 0)
    )::integer as relative_margin_bps
  from public.physical_assessment_marks as mark
  join public.assessment_standards as standard
    on standard.catalog_version = assessment.catalog_version
    and standard.category = assessment.category
    and standard.milestone = assessment.milestone
    and standard.test_id = mark.test_id
  join public.physical_test_definitions as test
    on test.id = mark.test_id
  where mark.assessment_id = assessment.id
    and standard.threshold > 0
  order by relative_margin_bps, mark.test_id
  limit 1
) as focus
on conflict (assessment_id) do nothing;

create or replace view public.physical_assessment_results
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
  end as passed,
  recommendation.algorithm_version as recommendation_algorithm_version,
  recommendation.focus_test_id as recommendation_focus_test_id,
  recommendation.relative_margin_bps as recommendation_relative_margin_bps,
  recommendation.reason as recommendation_reason
from public.physical_assessments as assessment
join public.physical_assessment_marks as mark
  on mark.assessment_id = assessment.id
join public.assessment_standards as standard
  on standard.catalog_version = assessment.catalog_version
  and standard.category = assessment.category
  and standard.milestone = assessment.milestone
  and standard.test_id = mark.test_id
join public.physical_test_definitions as test
  on test.id = mark.test_id
left join public.assessment_focus_recommendations as recommendation
  on recommendation.assessment_id = assessment.id;

revoke all on table public.physical_assessment_results from anon, authenticated;
grant select on table public.physical_assessment_results to authenticated;

commit;
