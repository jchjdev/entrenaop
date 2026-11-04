-- Contrasta la puerta técnica de COD del motor instalado en Dev.
-- Solo usa el perfil público y ejecuciones ficticias. No coloca ni publica sesiones.
begin read only;

with fixture as (
  select date '2026-10-19' as week_start, definition as profile,
    '{"id":"fixture-cod","role":"specific","reference_kind":"performed_set",
      "observed_on":"2026-09-01","current_capacity_confirmed":true,
      "targets":[15.5],"frequency":1,
      "task":{"exercise_code":"slalom_ball_course_16m","exercise_version":1,
        "protocol_key":"def_15_2026_agility","protocol_version":1,
        "setup_key":"standard:fixture","measurement":"TIME_FOR_COURSE",
        "load_mode":"bodyweight","target_value":15.5,"intent":"practice"}}'::jsonb as reference
  from public.exercise_training_profiles
  where code='slalom_ball_course_16m' and definition_version=1
), baseline as (
  select *, public.performance_task_v5(
    reference, profile, '[]', week_start-42, week_start+90
  ) as previous
  from fixture
), scenarios(position,scenario,tolerated_ages,difficult_age,exam_in_days,continued_development) as (
  values
    (1,'Desarrollo previo: una ejecución',array[3],null::int,90,true),
    (2,'Desarrollo previo: dos ejecuciones el mismo día',array[3,3],null,90,true),
    (3,'Desarrollo previo: dos días distintos',array[3,5],null,90,true),
    (4,'Desarrollo previo: un día reciente y otro hace treinta días',array[3,30],null,90,true),
    (5,'Desarrollo previo: dos días tolerados y dificultad el día más reciente',array[3,5],3,90,true),
    (6,'Base previa: dos ejecuciones el mismo día',array[3,3],null,90,false),
    (7,'Base previa: dos días distintos',array[3,5],null,90,false),
    (8,'Especificidad: dos ejecuciones el mismo día',array[3,3],null,20,true),
    (9,'Especificidad: dos días distintos',array[3,5],null,20,true)
), histories as (
  select b.*, s.*, h.history
  from baseline b cross join scenarios s
  cross join lateral (
    select jsonb_agg(jsonb_build_object(
      'execution_id','fixture-cod-'||sample.ordinal,
      'completed_on',b.week_start-sample.age,
      'status',case when sample.difficult then 'abandoned' else 'completed' end,
      'abandonment_reason',case when sample.difficult then 'too_difficult' end,
      'dose',b.previous->'dose',
      'sets',case when sample.difficult then '[]'::jsonb else (
        select jsonb_agg(jsonb_build_object(
          'status','completed','prescription',b.previous->'dose'->'task',
          'result',jsonb_build_object('value',target.value,'succeeded',true,
            'technique_valid',true,'conditions_confirmed',true,'tolerated',true,'stop_reason','none')
        ) order by target.ordinal)
        from jsonb_array_elements(b.previous->'dose'->'targets') with ordinality target(value,ordinal)
      ) end
    ) order by sample.ordinal) as history
    from (
      select age,ordinal,false as difficult
      from unnest(s.tolerated_ages) with ordinality tolerated(age,ordinal)
      union all
      select s.difficult_age,cardinality(s.tolerated_ages)+1,true
      where s.difficult_age is not null
    ) sample
  ) h
), decisions as (
  select position, scenario, previous->'dose'->'task'->>'stimulus_code' as initial_stimulus,
    public.performance_task_v5(reference,profile,history,week_start,week_start+exam_in_days,
      case when continued_development then previous||'{"phase":"development"}'::jsonb else previous end,
      week_start-42) as plan
  from histories
)
select scenario, initial_stimulus, plan->>'phase' as phase,
  plan->'block'->'comparable_tolerated_exposures' as tolerated_days,
  plan->'block'->'recent_difficulty' as recent_difficulty,
  plan->'dose'->'task'->>'stimulus_code' as selected_stimulus,
  plan->'dose'->'task'->>'exercise_code' as selected_exercise,
  plan->>'status' as status, plan->>'outcome' as outcome, plan->'frequency' as frequency
from decisions order by position;

rollback;
