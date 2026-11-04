begin;
set local timezone='UTC';
set local statement_timeout='45s';

-- Solo crea usuarios ficticios y sus propias filas. Cada comparación termina con ROLLBACK.
create function pg_temp.audit_adaptive_mode(
  scenario text, scope text, availability jsonb, equipment_removed boolean default false,
  running_mark_missing boolean default false, plank_missing boolean default false
) returns jsonb language plpgsql as $$
declare
  u uuid:=gen_random_uuid(); g uuid; assessment uuid;
  wk date:=current_date+1-extract(isodow from current_date)::int;
  exam date:=wk+180; plan jsonb; publication jsonb; dates jsonb; results jsonb;
  scheduled integer:=0; published_before integer; published_after integer;
  kit text[]:=array['cones','measuring_tape','tennis_ball','chalk','bench','barbell','plates'];
begin
  insert into auth.users(id,email) values(u,'audit-adaptive-'||u||'@example.invalid');
  perform set_config('request.jwt.claim.sub',u::text,true);
  update public.profiles set fecha_nacimiento='1996-01-01' where id=u;
  insert into public.pro_access_grants(user_id,source,ends_at,reason)
  values(u,'development_manual',now()+interval '1 day','Auditoría transaccional de los tres modos');
  insert into public.preparation_goals(user_id,program_id,target_date)
  values(u,'fas_periodic_assessment',exam) returning id into g;
  if not running_mark_missing then
    insert into public.fas_periodic_assessments(user_id,preparation_goal_id,catalog_version,category,age_at_assessment,age_band,is_pre_effective_reference)
    values(u,g,'es_def_15_2026_periodic_2027_v1','men',30,'26_30',true) returning id into assessment;
    insert into public.fas_periodic_marks(assessment_id,test_id,value) values(assessment,'run_2000_m',595000);
    insert into public.running_reference_selections(preparation_goal_id,reference_source,reference_record_id)
    values(g,'fasPeriodicAssessment',assessment::text);
  end if;
  insert into public.running_intake_contexts(preparation_goal_id,context_version,available_minutes_by_weekday,
    reserved_strength_weekdays,running_days_last_four_weeks,running_minutes_last_four_weeks,recent_weeks_end_on,
    reports_pain,requires_professional_review,health_observed_at,comfortable_continuous_minutes,target_2k_seconds,goal_mode)
  values(g,'running_initial_context_v3',availability,'{}',array[2,2,2,2],array[50,55,60,60],
    wk-1,false,false,now(),30,500,'time');

  perform public.save_performance_context(availability,kit,false,true);
  perform public.save_performance_reference(g,jsonb_build_object('goal_code','push_up_standard','goal_version',1,
    'goal_measurement','REPS_IN_TIME','program_objective_key','legacy:upper_body_push_ups_2_min',
    'task','{"exercise_code":"push_up_standard","exercise_version":1,"protocol_key":"floor_v1","protocol_version":1,"setup_key":"Suelo y recorrido completo","measurement":"REPS","load_mode":"bodyweight","target_value":7,"target_rir":3,"intent":"work"}'::jsonb,
    'reference_kind','repeated_work','targets','[7,6]'::jsonb,'observed_on',current_date,
    'current_capacity_confirmed',true,'reported_rir',3,'rest_seconds',120,'frequency',2));
  if not plank_missing then
    perform public.save_performance_reference(g,jsonb_build_object('goal_code','front_plank_forearms','goal_version',1,
      'goal_measurement','DURATION','program_objective_key','legacy:abdominal_plank',
      'task','{"exercise_code":"front_plank_forearms","exercise_version":1,"protocol_key":"def_15_2026_plank","protocol_version":1,"setup_key":"Suelo antideslizante y codos bajo hombros","measurement":"DURATION","load_mode":"bodyweight","target_value":50,"intent":"work"}'::jsonb,
      'reference_kind','repeated_work','targets','[50,45]'::jsonb,'observed_on',current_date,
      'current_capacity_confirmed',true,'reported_rpe',7,'rest_seconds',90,'frequency',2));
  end if;
  perform public.save_performance_reference(g,jsonb_build_object('goal_code','slalom_ball_course_16m','goal_version',1,
    'goal_measurement','TIME_FOR_COURSE','program_objective_key','legacy:agility_speed_circuit','equipment_confirmed',true,
    'task','{"exercise_code":"slalom_ball_course_16m","exercise_version":1,"protocol_key":"def_15_2026_agility","protocol_version":1,"setup_key":"Siete conos y corredor medido de 16 por 2 metros","measurement":"TIME_FOR_COURSE","load_mode":"bodyweight","target_value":14.3,"intent":"practice"}'::jsonb,
    'reference_kind','repeated_work','targets','[14.3,14.5]'::jsonb,'observed_on',current_date,
    'current_capacity_confirmed',true,'rest_seconds',180,'frequency',1));
  if equipment_removed then
    perform public.save_performance_context(availability,array[]::text[],false,true);
  end if;
  perform public.save_adaptive_program_preferences(g,exam,
    '{"legacy:upper_body_push_ups_2_min":{"measurement":"REPS_IN_TIME","value":50},"legacy:abdominal_plank":{"measurement":"DURATION","value":240},"legacy:agility_speed_circuit":{"measurement":"TIME_FOR_COURSE","value":12.5}}',
    scope);
  plan:=public.preview_adaptive_program_activation(g,wk);
  select count(*) into published_before from public.preparation_week_decisions where preparation_goal_id=g;
  if published_before<>0 or exists(select 1 from public.scheduled_workouts where preparation_goal_id=g) then
    raise exception 'La propuesta anticipó la publicación en %/%',scenario,scope;
  end if;
  if plan->>'status'='ready' then
    publication:=public.activate_adaptive_program(g,wk,plan);
    if publication->>'decision_id' is null then raise exception 'No publica %/%',scenario,scope; end if;
    select count(*) into scheduled from public.scheduled_workouts where preparation_goal_id=g and status='planned';
  end if;
  select count(*) into published_after from public.preparation_week_decisions where preparation_goal_id=g;
  if published_after<>(case when plan->>'status'='ready' then 1 else 0 end) then
    raise exception 'Número de decisiones inesperado %/%',scenario,scope;
  end if;

  with slots as (
    select x->>'date' as day,(x->>'minutes')::int as minutes,x->>'variant_code' as running,'[]'::jsonb as movements
    from jsonb_array_elements(coalesce(nullif(plan->'running'->'sessions','null'::jsonb),'[]')) x
    union all
    select x->>'date',(x->>'minutes')::int,null,
      (select coalesce(jsonb_agg(w->>'exercise_code'),'[]') from jsonb_array_elements(x->'work') w)
    from jsonb_array_elements(coalesce(nullif(plan->'sessions','null'::jsonb),'[]')) x
  ), calendar as (
    select day,sum(minutes) as used,(availability->>extract(isodow from day::date)::int::text)::int as limit_minutes,
      max(running) as running,jsonb_agg(movements) filter(where movements<>'[]') as movements
    from slots group by day
  )
  select coalesce(jsonb_agg(to_jsonb(calendar) order by day),'[]') into dates from calendar;
  if exists(select 1 from jsonb_array_elements(dates) d
    where (d->>'used')::int>coalesce((d->>'limit_minutes')::int,0)) then
    raise exception 'Excede disponibilidad %/%: %',scenario,scope,dates;
  end if;
  if exists(select 1 from jsonb_array_elements(dates) d where
    (scope='running' and d->'movements'<>'null'::jsonb) or
    (scope='performance' and d->'running'<>'null'::jsonb)) then
    raise exception 'El cálculo cruza modalidades fuera del alcance %/%',scenario,scope;
  end if;
  if plan->>'status'='ready' and scheduled<>jsonb_array_length(dates) then
    raise exception 'El calendario publicado no coincide %/%: % frente a %',scenario,scope,scheduled,dates;
  end if;
  select coalesce(jsonb_agg(jsonb_strip_nulls(jsonb_build_object('objective',x->>'objective_key','exercise',x->>'exercise_code',
    'status',x->>'status','allocation',x->>'allocation_status','frequency',x->'frequency','targets',x->'dose'->'targets',
    'reason',x->>'allocation_reason')) order by x->>'objective_key'),'[]') into results
  from jsonb_array_elements(coalesce(plan->'proposals','[]')) x;

  return jsonb_build_object('scenario',scenario,'scope',scope,'status',plan->>'status','published',published_after,
    'physical_sessions',scheduled,'running_coverage',plan->'coverage','calendar',dates,'proposals',results,
    'pending',coalesce(plan->'pending','[]'),'running_reason',plan->'running'->>'reason');
end $$;

with scenarios(position,scenario,availability,equipment_removed,running_mark_missing,plank_missing) as (
  values
    (1,'base','{"1":60,"3":75,"5":60,"6":75}'::jsonb,false,false,false),
    (2,'dos_huecos','{"1":35,"4":35}'::jsonb,false,false,false),
    (3,'sin_minutos_carrera','{"1":24,"4":24}'::jsonb,false,false,false),
    (4,'sin_material','{"1":60,"3":75,"5":60,"6":75}'::jsonb,true,false,false),
    (5,'sin_marca_2km','{"1":60,"3":75,"5":60,"6":75}'::jsonb,false,true,false),
    (6,'sin_referencia_plancha','{"1":60,"3":75,"5":60,"6":75}'::jsonb,false,false,true),
    (7,'dos_huecos_40','{"1":40,"4":40}'::jsonb,false,false,false),
    (8,'dos_huecos_45','{"1":45,"4":45}'::jsonb,false,false,false),
    (9,'dos_huecos_50','{"1":50,"4":50}'::jsonb,false,false,false)
)
select pg_temp.audit_adaptive_mode(s.scenario,m.scope,s.availability,s.equipment_removed,
    s.running_mark_missing,s.plank_missing) as result
from scenarios s cross join (values (1,'running'),(2,'performance'),(3,'full')) m(position,scope)
order by s.position,m.position;

rollback;
