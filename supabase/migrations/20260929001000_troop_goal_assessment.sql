-- Las evaluaciones nuevas de Tropa pueden pertenecer explícitamente a una
-- preparación. Los registros generales anteriores conservan el vínculo nulo.
begin;

alter table public.physical_assessments
  add column preparation_goal_id uuid
    references public.preparation_goals (id) on delete set null;

create index physical_assessments_goal_completed_idx
on public.physical_assessments (preparation_goal_id, completed_at desc)
where preparation_goal_id is not null;

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
  recommendation.reason as recommendation_reason,
  assessment.preparation_goal_id
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

create function public.record_troop_goal_assessment(
  p_goal_id uuid,
  p_catalog_version text,
  p_category text,
  p_marks jsonb,
  p_completed_at timestamptz default now()
) returns uuid language plpgsql security definer set search_path = ''
as $$
declare
  v_goal public.preparation_goals%rowtype;
  v_assessment_id uuid;
begin
  if (select auth.uid()) is null then
    raise exception 'Inicia sesión para guardar la evaluación.'
      using errcode = '42501';
  end if;
  select * into v_goal from public.preparation_goals
  where id = p_goal_id and user_id = (select auth.uid())
    and program_id = 'armed_forces_troop_entry' and status = 'active'
  for share;
  if not found then
    raise exception 'La preparación de Tropa no está disponible.'
      using errcode = '42501';
  end if;
  if not exists (
    select 1 from public.preparation_program_catalogs
    where program_id = v_goal.program_id
      and catalog_version = p_catalog_version and is_current
  ) then
    raise exception 'El catálogo no corresponde a esta preparación.'
      using errcode = '22023';
  end if;
  v_assessment_id := public.record_physical_assessment(
    p_catalog_version, p_category, 'entry', p_marks, p_completed_at);
  update public.physical_assessments
  set preparation_goal_id = p_goal_id
  where id = v_assessment_id;
  return v_assessment_id;
end;
$$;

revoke all on function public.record_troop_goal_assessment(
  uuid,text,text,jsonb,timestamptz) from public,anon;
grant execute on function public.record_troop_goal_assessment(
  uuid,text,text,jsonb,timestamptz) to authenticated;

commit;
