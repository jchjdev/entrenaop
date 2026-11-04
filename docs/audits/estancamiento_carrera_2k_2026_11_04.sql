-- Escenarios ficticios. Comparamos señales con el mismo 2 km de referencia.
begin read only;

with profile as (
  select date '2026-10-19' as week_start, 595 as anchor, 500 as goal
), doses as (
  select *, public.running_session_v2('V',0,anchor,35) as interval_session,
    public.running_session_v2('E',0,anchor,30) as easy_session
  from profile
), scenarios as (
  select * from (values
    (1,'Mismo ritmo y esfuerzo'),
    (2,'Mismo ritmo, menos esfuerzo'),
    (3,'Mejor ritmo a igual esfuerzo'),
    (4,'Mismo ritmo, esfuerzo sin registrar'),
    (5,'Un día difícil con pausas prolongadas'),
    (6,'Dificultad de la misma pauta en dos semanas'),
    (7,'Última semana sin registros'),
    (8,'Última semana marcada como omitida'),
    (9,'Última calidad interrumpida por tiempo'),
    (10,'Dos sesiones completas con esfuerzo alto'),
    (11,'Mismo ritmo, un esfuerzo inferior aislado'),
    (12,'Mismo trabajo, cambia solo el pulso'),
    (13,'Mejor ritmo, último 2 km anterior a las dos mejoras'),
    (14,'Mejor ritmo, último 2 km entre las dos mejoras')
  ) cases(position,label)
), runs as (
  select s.position,s.label,d.week_start,trial.ordinal,trial.days_ago,trial.session,
    jsonb_strip_nulls(jsonb_build_object(
      'status',case when s.position=8 and trial.days_ago<=7 then 'skipped' else 'completed' end,
      'abandonment_reason',case when s.position=9 and trial.ordinal=4 then 'lack_of_time' end,
      'average_heart_rate_bpm',case when s.position=12 then case when trial.ordinal in (3,4) then 138 else 150 end end,
      'rpe',case when s.position=10 and trial.ordinal in (4,5) then 9
        when trial.ordinal > 4 then 4
        when s.position=4 and trial.ordinal>=3 then null
        when (s.position=2 and trial.ordinal>=3) or (s.position=11 and trial.ordinal=4) then 6 else 7 end,
      'sets',(select jsonb_agg(jsonb_build_object('status','completed',
          'seconds',coalesce((part->>'seconds')::numeric, (part->>'meters')::numeric*pace/1000),
          'meters',coalesce((part->>'meters')::numeric, (part->>'seconds')::numeric*1000/pace),
          'recovery_seconds',case when (s.position in (5,6) and trial.ordinal=4)
            or (s.position=6 and trial.ordinal=3) then (part->>'recovery_seconds')::numeric*2
            else (part->>'recovery_seconds')::numeric end) order by part_number)
        from jsonb_array_elements(trial.session->'segments') with ordinality as segments(part,part_number)
        cross join lateral (select coalesce(case
          when s.position in (3,13,14) and trial.ordinal>=3 and trial.ordinal<=4 then (part->>'pace_min')::numeric+1
          else (part->>'pace_max')::numeric-1 end,450) as pace) as p)
    )) as execution
  from doses d cross join scenarios s
  cross join lateral (values
    (1,28,d.interval_session),(2,21,d.interval_session),
    (3,14,d.interval_session),(4,7,d.interval_session),
    (5,5,d.easy_session),(6,3,d.easy_session)
  ) as trial(ordinal,days_ago,session)
  where s.position<>7 or trial.days_ago>7
), histories as (
  select position,label,jsonb_agg(jsonb_build_object('date',week_start-days_ago,
    'session',session,'execution',execution) order by ordinal) as history
  from runs group by position,label
), inputs as (
  select h.*,
    jsonb_build_object(
      'week_start',d.week_start,'target_date',d.week_start+70,'anchor_seconds',d.anchor,
      'anchor_age_days',case h.position when 13 then 15 when 14 then 10 else 2 end,
      'goal_seconds',d.goal,'availability','{"1":60,"3":60,"6":60}'::jsonb,
      'recent_days',array[case when h.position in (7,8) then 0 else 3 end,3,3,3],
      'recent_minutes',array[case when h.position in (7,8) then 0 else 95 end,95,95,95],'capacity_minutes',45,
      'previous',jsonb_build_object('week_start',d.week_start-7,'normal_budget',95,
        'anchor_seconds',d.anchor,'mode','normal','rotation',1,
        'sessions',jsonb_build_array(d.interval_session,d.easy_session,d.easy_session)),
      'controls',(select jsonb_agg(jsonb_build_object('date',d.week_start-days_ago,'seconds',d.anchor,
        'protocol','pista_2000') order by days_ago) from unnest(case h.position
          when 13 then array[43,29,15] when 14 then array[38,24,10] else array[30,16,2] end) as days(days_ago)),
      'history',h.history
    ) as input
  from histories h cross join doses d
), plans as (
  select *, public.running_plan_v6(input) as plan,
    -- Contrafactual de laboratorio. Mantiene la misma referencia y agenda,
    -- pero retira los controles para que no justifiquen un cambio de familia.
    case when position in (13,14) then public.running_plan_v6(input-'controls') end as plan_without_control_trend
  from inputs
), paired as (
  -- Lectura exploratoria de estas fixtures. Los cuatro ensayos usan la misma
  -- receta y ancla en fechas distintas. No es un umbral para el motor.
  select p.*, p.plan->'evidence' as evidence, q.* from plans p cross join lateral (
    select count(*) filter(where signal->>'status'='tolerated') as tolerated,
      count(*) as exposures,
      min((signal->>'rpe')::numeric) filter(where rn<=2) as early_rpe_min,
      max((signal->>'rpe')::numeric) filter(where rn>2) as late_rpe_max,
      avg((signal->>'pace_seconds_per_km')::numeric) filter(where rn<=2) as early_pace,
      avg((signal->>'pace_seconds_per_km')::numeric) filter(where rn>2) as late_pace
    from (select o->'signal' as signal,row_number() over(order by o->>'date') as rn
      from jsonb_array_elements(p.plan->'evidence'->'observations') o where o->'session'->>'family'='V') samples
  ) q
)
select label,evidence->'families'->'V' as interval_trend,
  plan->'control_review'->>'trend' as test_trend,plan->>'outcome' as decision,plan->>'mode' as mode,
  plan#>>'{control_review,controls,0,date}' as latest_control,
  (select item->>'variant_code' from jsonb_array_elements(plan_without_control_trend->'sessions') item
    where item->>'family' in ('T','V','S') limit 1) as quality_without_control_trend,
  case when exposures<>4 or tolerated<>4 then 'evidencia insuficiente para comparar esfuerzo'
    when abs(late_pace/nullif(early_pace,0)-1)>0.02 then 'ritmo distinto'
    when late_rpe_max<early_rpe_min then 'esfuerzo inferior repetido a ritmo similar'
    else 'sin descenso repetido del esfuerzo' end as effort_observation,
  case when position=12 then plan=(select plan from plans where position=1) end as same_plan_with_heart_rate,
  (select jsonb_agg(o->'signal'->>'status' order by o->>'date')
   from jsonb_array_elements(evidence->'observations') o
   where (o->>'date')::date>=(plan->>'week_start')::date-7) as recent_signals,
  (select jsonb_agg(jsonb_build_object('variant',item->>'variant_code',
    'work_seconds',(item->>'work_seconds')::int,
    'work_intervals',(select count(*) from jsonb_array_elements(item->'segments') segment
      where segment->>'role'='work')))
   from jsonb_array_elements(plan->'sessions') item
   where item->>'family' in ('T','V','S')) as quality,
  plan->>'reason' as reason
from paired order by position;

rollback;
