-- Diagnóstico de políticas instaladas con entradas ficticias y fecha fija.
begin read only;

with base as (
  select '{"supported":true,"phase":"development","days_left":80,"healthy":true,
    "adverse":false,"tolerated_days":6,"recent_days":2,"new_days":6,
    "growth":1,"plateau":true,"signature_tried":false,"has_mark":true}'::jsonb as facts
)
select case_name, public.adaptive_control_decision_v1(facts || change::jsonb) as result
from base cross join (values
  (1,'Dosis repetida sin comprobar transferencia','{}'),
  (2,'Misma firma ya comprobada','{"signature_tried":true}'),
  (3,'Pocos días nuevos','{"new_days":3}'),
  (4,'Respuesta adversa reciente','{"adverse":true}'),
  (5,'Objetivo ya acreditado','{"target_met":true}'),
  (6,'Examen cercano','{"days_left":14}')
) scenarios(position,case_name,change)
order by position;

with inputs(position,case_name,marks) as (
  values
    (1,'Dos marcas iguales',array[478,478]),
    (2,'Tres marcas iguales',array[478,478,478]),
    (3,'Seis segundos de mejora',array[478,476,472]),
    (4,'Exactamente 1 % de mejora',array[500,500,495]),
    (5,'Tres iguales con protocolo intermedio distinto',array[478,478,478])
), controls as (
  select position,case_name,jsonb_agg(jsonb_build_object(
    'date',date '2026-10-19' - (cardinality(marks)-ordinal::int)*14-1,
    'seconds',seconds,'protocol',case when position=5 and ordinal=2 then 'otro' else 'pista' end
  ) order by ordinal) as samples
  from inputs cross join lateral unnest(marks) with ordinality marks(seconds,ordinal)
  group by position,case_name
), plans as (
  select position,case_name,public.running_plan_v6(jsonb_build_object(
    'week_start','2026-10-19','target_date','2027-02-01','anchor_seconds',samples->-1->'seconds',
    'anchor_age_days',1,'goal_seconds',465,'controls',samples,
    'availability','{"1":45,"3":45,"6":45}'::jsonb,
    'recent_days',array[3,3,3,3],'recent_minutes',array[110,110,110,110],'capacity_minutes',60
  )) as p from controls
)
select case_name,p->'control_review'->>'trend' as trend,
  p->'control_review'->'samples' as samples,p->>'mode' as mode,
  p->>'outcome' as outcome,p->>'reason' as reason
from plans order by position;

with seed as (
  select date '2026-10-19' as wk, definition as profile,
    '{"id":"fixture","role":"specific","reference_kind":"repeated_work","observed_on":"2026-10-11",
      "current_capacity_confirmed":true,"reported_rir":3,"targets":[24,24],"frequency":2,
      "task":{"exercise_code":"push_up_standard","exercise_version":1,"protocol_key":"suelo",
      "protocol_version":1,"setup_key":"suelo","measurement":"REPS","load_mode":"bodyweight",
      "target_value":24,"intent":"work"}}'::jsonb as ref
  from public.exercise_training_profiles
  where code='push_up_standard' and definition_version=1
), prepared as (
  select *,public.performance_task_v5(ref,profile,'[]',wk-7,wk+120) as previous from seed
), samples as (
  select position,case_name,wk,profile,ref,previous,
    jsonb_agg(jsonb_build_object('completed_on',wk-days_ago,
      'status',case when abandonment is null then 'completed' else 'abandoned' end,
      'abandonment_reason',abandonment,'dose',previous->'dose',
      'sets',(select jsonb_agg(jsonb_build_object('status','completed',
        'prescription',(previous->'dose'->'task')||jsonb_build_object('target_value',quantity),
        'result',jsonb_strip_nulls(jsonb_build_object('value',quantity,'succeeded',true,
          'rir',effort,'technique_valid',true,'tolerated',true,'conditions_confirmed',true,'stop_reason','none'))
        )) from jsonb_array_elements(previous->'dose'->'targets') with ordinality as prescribed(quantity,ordinal)
        where abandonment is null or ordinal=1)
    ) order by days_ago desc) as history
  from prepared cross join (values
    (1,'Misma dosis tolerada',4,null::text),
    (2,'Misma dosis con esfuerzo sin registrar',null,null),
    (3,'Dificultad',3,'too_difficult'),
    (4,'Falta de tiempo',3,'lack_of_time')
  ) scenarios(position,case_name,effort,abandonment)
  cross join (values (5),(3)) as days(days_ago)
  group by position,case_name,wk,profile,ref,previous
), plans as (
  select position,case_name,public.performance_task_v5(ref,profile,history,wk,wk+120,previous,wk-7) as p
  from samples
)
select case_name,p->>'outcome' as outcome,p->'dose'->'targets' as targets,p->'frequency' as frequency,
  (select jsonb_agg(item->>'signal') from jsonb_array_elements(p->'evidence') item) as evidence
from plans order by position;

rollback;
