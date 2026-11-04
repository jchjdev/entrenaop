-- Auditoría de carrera en Dev. Todos los resultados son sintéticos.
-- La fecha de cada sesión es la fecha real que consume el motor.
-- No se crean cuentas, funciones, planes ni registros.
begin read only;

-- Mismas dos ejecuciones de específico con fecha wk-14. Una tolerada y
-- otra abandonada por dificultad. Solo cambia el orden de esos elementos.
with dose_input as (select date '2026-10-19' as wk, 577 as anchor),
dose_sessions as (
 select d.*, public.running_session_v2('S',0,anchor,40) as s, public.running_session_v2('E',0,anchor,30) as e from dose_input d
), dose_records as (
 select s.*, z.label,z.ord,z.session,z.day,
   jsonb_strip_nulls(jsonb_build_object('status',case when z.bad then 'abandoned' else 'completed' end,
      'abandonment_reason',case when z.bad then 'too_difficult' end,'rpe',case when z.session=s.e then 4 else 6 end,
      'sets',(select jsonb_agg(jsonb_build_object('status','completed','seconds',coalesce((p->>'seconds')::numeric,(p->>'meters')::numeric*pace/1000),'meters',coalesce((p->>'meters')::numeric,(p->>'seconds')::numeric*1000/pace),'recovery_seconds',p->'recovery_seconds') order by ix)
       from jsonb_array_elements(z.session->'segments') with ordinality a(p,ix)
       cross join lateral (select coalesce((p->>'pace_max')::numeric-1,450) as pace) g))) as execution
 from dose_sessions s cross join (values ('favorable'),('adversa')) which(label)
 cross join lateral (values
   (which.label,case when which.label='favorable' then 1 else 2 end,s.s,s.wk-14,false),
   (which.label,case when which.label='favorable' then 2 else 1 end,s.s,s.wk-14,true),
   (which.label,3,s.s,s.wk-7,false),(which.label,4,s.e,s.wk-5,false),(which.label,5,s.e,s.wk-3,false)
 ) z(label,ord,session,day,bad)
), dose_histories as (
 select label,wk,anchor,s,e,jsonb_agg(jsonb_build_object('date',day,'session',session,'execution',execution) order by ord) h
 from dose_records group by label,wk,anchor,s,e
), dose_decisions as (
 select label,public.running_dose_evidence_v6(h,wk,'S',0,anchor,1) ev,
  public.running_plan_v6(jsonb_build_object('week_start',wk,'target_date',wk+21,'anchor_seconds',anchor,'anchor_age_days',7,
    'goal_seconds',500,'recent_days',array[3,3,3,3],'recent_minutes',array[90,90,90,90],'capacity_minutes',60,
    'availability','{"1":60,"3":60,"6":60}'::jsonb,
    'previous',jsonb_build_object('week_start',wk-7,'normal_budget',90,'anchor_seconds',anchor,'load_weeks',0,'rotation',1,
      'mode','normal','sessions',jsonb_build_array(s,e,e)), 'history',h)) p
 from dose_histories
),
dose_results as (
 select label,ev->>'compatible_successes' as compatible,p->>'outcome' as outcome,p->>'priority' as priority,
   (select jsonb_agg(concat(x->>'family',':',x->>'step','/',x->>'minutes')) from jsonb_array_elements(p->'sessions') x) as sessions,
   p->'changes' changes
 from dose_decisions order by label
),
-- Cuatro sesiones V comparables. Las dos del centro comparten fecha.
base as (
 select date '2026-10-19' as wk, 595 as anchor, public.running_session_v2('V',0,595,35) as v,
  public.running_session_v2('E',0,595,30) as e
), records as (
 select b.*, z.label,z.ord,z.session,z.day,
   jsonb_build_object('status','completed','rpe',case when z.session=b.e then 4 else 7 end,
      'sets',(select jsonb_agg(jsonb_build_object('status','completed','seconds',coalesce((p->>'seconds')::numeric,(p->>'meters')::numeric*pace/1000),'meters',coalesce((p->>'meters')::numeric,(p->>'seconds')::numeric*1000/pace),'recovery_seconds',p->'recovery_seconds') order by ix)
       from jsonb_array_elements(z.session->'segments') with ordinality a(p,ix)
       cross join lateral (select coalesce(case z.speed when 'fast' then (p->>'pace_min')::numeric+1 when 'slow' then (p->>'pace_max')::numeric-1
         else ((p->>'pace_max')::numeric+(p->>'pace_min')::numeric)/2 end,450) as pace) g)) as execution
 from base b cross join (values ('rapida'),('lenta')) which(label)
 cross join lateral (values
   (which.label,1,b.v,b.wk-21,'middle'),
   (which.label,case when which.label='rapida' then 2 else 3 end,b.v,b.wk-14,'fast'),
   (which.label,case when which.label='rapida' then 3 else 2 end,b.v,b.wk-14,'slow'),
   (which.label,4,b.v,b.wk-7,'middle'),(which.label,5,b.e,b.wk-5,'middle'),(which.label,6,b.e,b.wk-3,'middle')
 ) z(label,ord,session,day,speed)
), histories as (
 select label,wk,anchor,v,e,jsonb_agg(jsonb_build_object('date',day,'session',session,'execution',execution) order by ord) h
 from records group by label,wk,anchor,v,e
), decisions as (
 select label,public.running_evidence_v2(h,wk) ev,
  public.running_plan_v6(jsonb_build_object('week_start',wk,'target_date',wk+70,'anchor_seconds',anchor,'anchor_age_days',2,
    'goal_seconds',500,'recent_days',array[3,3,3,3],'recent_minutes',array[95,95,95,95],'capacity_minutes',45,
    'availability','{"1":60,"3":60,"6":60}'::jsonb,
    'previous',jsonb_build_object('week_start',wk-7,'normal_budget',95,'anchor_seconds',anchor,'load_weeks',0,'rotation',1,
      'mode','normal','sessions',jsonb_build_array(v,e,e)),
    'controls',(select jsonb_agg(jsonb_build_object('date',wk-days_ago,'seconds',anchor,'protocol','pista_2000')) from unnest(array[30,16,2]) as days(days_ago)), 'history',h)) p
 from histories
),
trend_results as (
 select label,ev->'families'->'V' as v_trend,
   (select jsonb_agg(round((x->'signal'->>'pace_seconds_per_km')::numeric,2)) from jsonb_array_elements(ev->'observations') x where x->'session'->>'family'='V') as paces,
   p->>'priority' as priority,(select jsonb_agg(concat(x->>'family',':',x->>'step')) from jsonb_array_elements(p->'sessions') x) as sessions
 from decisions order by label
),
-- Guardas del plan semanal con el mismo historial en cada comparación.
scenarios as (
 select * from (values
   ('normal',27,'{"1":60,"3":60,"6":60}'::jsonb,'[]'::jsonb),
   ('control próximo',28,'{"1":60,"3":60,"6":60}'::jsonb,'[]'::jsonb),
   ('vigencia límite',45,'{"1":60,"3":60,"6":60}'::jsonb,'[]'::jsonb),
   ('ancla caducada',46,'{"1":60,"3":60,"6":60}'::jsonb,'[]'::jsonb),
   ('agenda corta',27,'{"1":25,"3":25,"6":25}'::jsonb,'[]'::jsonb),
   ('carga de piernas',27,'{"1":60,"3":60,"6":60}'::jsonb,'[2,5,7]'::jsonb)
 ) z(scenario,age,availability,legs)
), plans as (
 select scenario,age,availability,legs,
  public.running_plan_v6(jsonb_build_object('week_start',wk,'target_date',wk+70,'anchor_seconds',anchor,'anchor_age_days',age,
    'goal_seconds',500,'recent_days',array[3,3,3,3],'recent_minutes',array[95,95,95,95],'capacity_minutes',45,
    'availability',availability,'leg_load_days',legs,
    'previous',jsonb_build_object('week_start',wk-7,'normal_budget',95,'anchor_seconds',anchor,'load_weeks',0,'rotation',1,
      'mode','normal','sessions',jsonb_build_array(v,e,e)),
    'controls',(select jsonb_agg(jsonb_build_object('date',wk-days_ago,'seconds',anchor,'protocol','pista_2000')) from unnest(array[70,55,age]) as days(days_ago)), 'history',h)) p
 from histories cross join scenarios where label='lenta'
),
limit_results as (
 select scenario,age,p->'control_due' as control_due,p->'needs_control' as needs_control,
  p->>'outcome' as outcome,
  (select jsonb_agg(jsonb_build_object('family',x->>'family','step',x->'step','minutes',x->'minutes','basis',x->>'pace_basis','date',x->'date')) from jsonb_array_elements(p->'sessions') x) as sessions,
  p->'recommendations' as recommendations, p->'changes' as changes
 from plans order by scenario
)
select jsonb_build_object(
 'dosis_al_invertir_el_mismo_dia', (select jsonb_agg(to_jsonb(r) order by r.label) from dose_results r),
 'tendencia_al_invertir_el_mismo_dia', (select jsonb_agg(to_jsonb(r) order by r.label) from trend_results r),
 'limites_de_agenda_y_vigencia', (select jsonb_agg(to_jsonb(r) order by r.scenario) from limit_results r)
) as running_audit;

rollback;
