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
    (4,'Mismo ritmo, esfuerzo sin registrar')
  ) cases(position,label)
), runs as (
  select s.position,s.label,d.week_start,trial.ordinal,trial.days_ago,trial.session,
    jsonb_strip_nulls(jsonb_build_object(
      'status','completed','rpe',
      case when trial.ordinal > 4 then 4
        when s.position=4 and trial.ordinal>=3 then null
        when s.position=2 and trial.ordinal>=3 then 6 else 7 end,
      'sets',(select jsonb_agg(jsonb_build_object('status','completed',
          'seconds',coalesce((part->>'seconds')::numeric, (part->>'meters')::numeric*pace/1000),
          'meters',coalesce((part->>'meters')::numeric, (part->>'seconds')::numeric*1000/pace),
          'recovery_seconds',part->'recovery_seconds') order by part_number)
        from jsonb_array_elements(trial.session->'segments') with ordinality as segments(part,part_number)
        cross join lateral (select coalesce(case
          when s.position=3 and trial.ordinal>=3 and trial.ordinal<=4 then (part->>'pace_min')::numeric+1
          else (part->>'pace_max')::numeric-1 end,450) as pace) as p)
    )) as execution
  from doses d cross join scenarios s
  cross join lateral (values
    (1,28,d.interval_session),(2,21,d.interval_session),
    (3,14,d.interval_session),(4,7,d.interval_session),
    (5,5,d.easy_session),(6,3,d.easy_session)
  ) as trial(ordinal,days_ago,session)
), histories as (
  select position,label,jsonb_agg(jsonb_build_object('date',week_start-days_ago,
    'session',session,'execution',execution) order by ordinal) as history
  from runs group by position,label
), plans as (
  select h.*, public.running_evidence_v2(h.history,d.week_start) as evidence,
    public.running_plan_v6(jsonb_build_object(
      'week_start',d.week_start,'target_date',d.week_start+70,'anchor_seconds',d.anchor,
      'anchor_age_days',2,'goal_seconds',d.goal,'availability','{"1":60,"3":60,"6":60}'::jsonb,
      'recent_days',array[3,3,3,3],'recent_minutes',array[95,95,95,95],'capacity_minutes',45,
      'previous',jsonb_build_object('week_start',d.week_start-7,'normal_budget',95,
        'anchor_seconds',d.anchor,'mode','normal','rotation',1,
        'sessions',jsonb_build_array(d.interval_session,d.easy_session,d.easy_session)),
      'controls',(select jsonb_agg(jsonb_build_object('date',d.week_start-days_ago,'seconds',d.anchor,
        'protocol','pista_2000')) from unnest(array[30,16,2]) as days(days_ago)),
      'history',h.history
    )) as plan
  from histories h cross join doses d
)
select label,evidence->'families'->'V' as interval_trend,
  plan->'control_review'->>'trend' as test_trend,plan->>'outcome' as decision,
  (select jsonb_agg(jsonb_build_object('variant',item->>'variant_code',
    'work_seconds',(item->>'work_seconds')::int,
    'work_intervals',(select count(*) from jsonb_array_elements(item->'segments') segment
      where segment->>'role'='work')))
   from jsonb_array_elements(plan->'sessions') item
   where item->>'family' in ('T','V','S')) as quality,
  plan->>'reason' as reason
from plans order by position;

rollback;
