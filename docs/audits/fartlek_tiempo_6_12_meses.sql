-- Ensayo de laboratorio. Ejecutar en Dev con acceso al motor puro.
-- Cambiar entrenaop.fartlek_scenario entre constante, dificultad, pausa y
-- sin_marca. Cambiar entrenaop.fartlek_arm entre actual_gps, actual_reloj
-- fartlek_gps y fartlek_reloj. Solo se crean objetos temporales y se termina
-- con ROLLBACK.
begin;
set local statement_timeout='55s';
set local entrenaop.fartlek_scenario='constante';
set local entrenaop.fartlek_arm='fartlek_reloj';

create function pg_temp.fartlek_from_v0(original jsonb) returns jsonb
language sql immutable as $$
 select original||jsonb_build_object('variant_code','V_fartlek_8min_lab','name','Fartlek por tiempo',
  'pace_basis','effort_only_lab','segments',jsonb_build_array(original->'segments'->0)||
  (select jsonb_agg(jsonb_strip_nulls(jsonb_build_object('role','work','seconds',seconds,
    'recovery_seconds',case when idx<5 then 90 end)) order by idx)
   from (values (1,60),(2,120),(3,120),(4,120),(5,60)) work(idx,seconds))||
  jsonb_build_array(original->'segments'->-1))
$$;

create function pg_temp.fartlek_lab_execution(recipe jsonb,no_distance boolean,response text)
returns jsonb language sql immutable as $$
 select case when response='skipped' then '{"status":"skipped"}'::jsonb
  else jsonb_build_object('status','completed','rpe',
    case when response='hard' then 9 else (recipe->>'rpe_ceiling')::int-1 end,
    'sets',coalesce(jsonb_agg(jsonb_strip_nulls(jsonb_build_object('status','completed',
      'seconds',round(seconds*fraction),
      'meters',case when not no_distance then meters*fraction end,
      'recovery_seconds',s->'recovery_seconds')) order by idx),'[]'::jsonb)) end
 from jsonb_array_elements(recipe->'segments') with ordinality a(s,idx)
 cross join lateral (select coalesce(((s->>'pace_min')::numeric+(s->>'pace_max')::numeric)/2,
  case when recipe->>'variant_code'='V_fartlek_8min_lab' then (recipe->>'anchor_seconds')::numeric/2 end,360) pace) x
 cross join lateral (select coalesce((s->>'seconds')::numeric,round((s->>'meters')::numeric*pace/1000)) seconds) y
 cross join lateral (select coalesce((s->>'meters')::numeric,seconds*1000/pace) meters,
  case when response='hard' and s->>'role'='work' then 0.8 else 1 end fraction) z
$$;

create temp table fartlek_weeks (
 profile text, agenda text, legs boolean, horizon int, week_no int,
 date_start date, availability jsonb, mode text, needs_control boolean, phase text
) on commit drop;
create temp table fartlek_sessions (
 profile text, agenda text, legs boolean, horizon int, week_no int,
 recipe jsonb, evaluation jsonb, dose_check jsonb
) on commit drop;

do $lab$
declare
 arm text:=current_setting('entrenaop.fartlek_arm'); scenario text:=current_setting('entrenaop.fartlek_scenario');
 c record; i int; wk date; target date; last_control date; response text; plan jsonb;
 previous jsonb; history jsonb; controls jsonb; recipe jsonb; execution jsonb; session_index bigint;
 fartlek_added boolean; evaluation jsonb; dose_check jsonb; last_fartlek date;
begin
 for c in select * from (values
   ('inicio',660,620,2,55,30),('intermedio',550,515,3,100,45),('entrenado',470,450,4,140,60)
  ) a(profile,anchor,goal,frequency,volume,capacity) cross join (values
   ('dos_30','{"1":30,"4":30}'::jsonb),('tres_45','{"1":45,"3":45,"6":45}'::jsonb),
   ('cuatro_60','{"1":60,"3":60,"5":60,"7":60}'::jsonb)
  ) t(agenda,availability) cross join (values (false),(true)) l(legs)
  cross join (values (26),(52)) w(horizon) loop
   previous:='{}'; history:='[]'; controls:='[]'; last_fartlek:=null;
   target:=date '2026-10-05'+c.horizon*7-1;
   for i in 1..c.horizon loop
    wk:=date '2026-10-05'+(i-1)*7;
    -- Marca externa fija. Su renovación nunca depende del formato pautado.
    if i=1 or (scenario<>'sin_marca' and mod(i-1,4)=0 and target-wk>14) then
     last_control:=wk-1;
     controls:=controls||jsonb_build_array(jsonb_build_object('date',last_control,'seconds',c.anchor,'protocol','track_2k_v1'));
    end if;
    plan:=public.running_plan_v6(jsonb_build_object('week_start',wk,'target_date',target,
     'anchor_seconds',c.anchor,'anchor_age_days',wk-last_control,'goal_seconds',c.goal,
     'controls',controls,'availability',c.availability,
     'leg_load_days',case when c.legs then '[2,5]'::jsonb else '[]'::jsonb end,
     'recent_days',array[c.frequency,c.frequency,c.frequency,c.frequency],
     'recent_minutes',array[c.volume,c.volume,c.volume,c.volume],'capacity_minutes',c.capacity,
     'previous',previous,'history',history));
    insert into fartlek_weeks values(c.profile,c.agenda,c.legs,c.horizon,i,wk,c.availability,
      plan->>'mode',coalesce((plan->>'needs_control')::boolean,false),plan->>'phase');
    fartlek_added:=false;
    for recipe,session_index in
      select value,ordinality from jsonb_array_elements(plan->'sessions') with ordinality
    loop
     if arm in ('fartlek_gps','fartlek_reloj') and not fartlek_added and recipe->>'variant_code'='V_0_v1'
       and plan->>'mode'='normal' and plan->>'phase' in ('general','build') and target-wk>28
       and not coalesce((plan->>'needs_control')::boolean,false)
       and (last_fartlek is null or (recipe->>'date')::date-last_fartlek>=14)
       and (select count(distinct (o->>'date')::date) from jsonb_array_elements(plan#>'{evidence,observations}') o
         where o#>>'{session,family}'='E' and o#>>'{signal,status}'='tolerated'
          and (o->>'date')::date>=wk-28)>=2
       and not exists(select 1 from jsonb_array_elements(plan#>'{evidence,observations}') o
         where o#>>'{signal,status}' in ('pain','struggle','off_intent','missing')
          and (o->>'date')::date>=wk-7)
     then
      recipe:=pg_temp.fartlek_from_v0(recipe);
      plan:=jsonb_set(plan,array['sessions',(session_index-1)::text],recipe);
      fartlek_added:=true;
      last_fartlek:=(recipe->>'date')::date;
     end if;
     response:=case when scenario='pausa' and i between 8 and 10 then 'skipped'
      when scenario='dificultad' and i between 5 and 6 then 'hard' else 'ok' end;
     execution:=pg_temp.fartlek_lab_execution(recipe,
       arm in ('actual_reloj','fartlek_reloj') and recipe->>'variant_code' in ('V_0_v1','V_fartlek_8min_lab'),response);
     evaluation:=public.running_evaluate_v2(recipe,execution);
     dose_check:=null;
     if recipe->>'variant_code'='V_fartlek_8min_lab' then
      dose_check:=public.running_evaluate_v2(public.running_session_v2('V',0,c.anchor,180),execution);
     end if;
     insert into fartlek_sessions values(c.profile,c.agenda,c.legs,c.horizon,i,recipe,evaluation,dose_check);
     history:=history||jsonb_build_array(jsonb_build_object('date',recipe->'date','session',recipe,
       'execution',execution||jsonb_build_object('performed_at_epoch',extract(epoch from (recipe->>'date')::date+time '12:00'))));
    end loop;
    select coalesce(jsonb_agg(o),'[]') into history from jsonb_array_elements(history) o
     where (o->>'date')::date>=wk-56;
    previous:=plan-'evidence'-'input_snapshot';
   end loop;
 end loop;
end $lab$;

with runs as (
 select s.*, (recipe->>'date')::date as run_date, recipe->>'family' as family,
  recipe->>'variant_code' as variant, (recipe->>'minutes')::int as minutes,
  (select max((w->>'meters')::int) from jsonb_array_elements(recipe->'segments') w where w->>'role'='work') as meters
 from fartlek_sessions s
), ordered as (
 select r.*,lag(run_date) over(partition by profile,agenda,legs,horizon order by run_date) as prior_date
 from runs r where family in ('T','V','S','R')
), checks as (
 select r.*,wk.mode,wk.needs_control,wk.phase,wk.availability,
  (select sum((t->>'seconds')::int) from jsonb_array_elements(r.recipe->'segments') t where t->>'role'='work') as work_seconds,
  (select sum((t->>'recovery_seconds')::int) from jsonb_array_elements(r.recipe->'segments') t) as rest_seconds,
  (select sum(coalesce((t->>'seconds')::int,0)+coalesce((t->>'recovery_seconds')::int,0))
   from jsonb_array_elements(r.recipe->'segments') t) as total_seconds
 from runs r join fartlek_weeks wk using(profile,agenda,legs,horizon,week_no)
)
select current_setting('entrenaop.fartlek_arm') as arm,current_setting('entrenaop.fartlek_scenario') as scenario,
 h as weeks_per_plan,
 (select count(*) from fartlek_weeks where horizon=h) as weeks,
 (select count(*) from fartlek_weeks where horizon=h and week_no=h) as trajectories,
 (select count(*) from fartlek_weeks where horizon=h and mode='reentry') as reentry_weeks,
 (select count(*) from fartlek_weeks where horizon=h and mode='global_deload') as global_deload_weeks,
 (select count(*) from runs where horizon=h and family='T') as tempo,
 (select count(*) from runs where horizon=h and family='V') as aerobic_total,
 (select count(*) from runs where horizon=h and family='S') as specific,
 (select coalesce(jsonb_object_agg(meters,n),'{}') from
  (select meters,count(*) as n from runs where horizon=h and family='S' and meters is not null group by meters) q) as distances,
 (select count(*) from runs where horizon=h and variant='V_0_v1' and evaluation->>'status'='unknown') as v0_unknown,
 (select count(*) from runs where horizon=h and variant='V_fartlek_8min_lab') as fartlek,
 (select count(*) from runs where horizon=h and variant='V_fartlek_8min_lab' and evaluation->>'status'='tolerated') as fartlek_tolerated,
 (select count(*) from runs where horizon=h and variant='V_fartlek_8min_lab' and dose_check->>'status'='tolerated') as false_v0_credit,
 (select count(*) from checks where horizon=h and variant='V_fartlek_8min_lab' and
   (work_seconds<>480 or rest_seconds<>360 or total_seconds<>minutes*60 or mode<>'normal'
    or phase not in ('general','build') or needs_control
    or (legs and extract(isodow from run_date) in (1,2,3,4,5,6)))) as invalid_fartlek,
 (select count(*) from checks where horizon=h and minutes>coalesce((availability->>extract(isodow from run_date)::int::text)::int,0)) as over_slot,
 (select count(*) from ordered where horizon=h and run_date-prior_date=1) as adjacent_quality
from (values (26),(52)) horizons(h) order by h;

rollback;
