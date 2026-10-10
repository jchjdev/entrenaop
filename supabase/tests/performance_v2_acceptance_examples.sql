begin;
-- El ensayo deportivo necesita derechos Pro explícitos, siempre con ROLLBACK.
insert into public.pro_access_grants(user_id,source,ends_at,reason)
select candidate.id,'development_manual',now()+interval '1 day','Fixture SQL de programa adaptativo'
from public.profiles candidate where not public.has_pro_access(candidate.id);

select set_config('request.jwt.claim.sub',(select user_id::text from public.admin_permissions limit 1),true);
update public.profiles set fecha_nacimiento='1996-01-01' where id=auth.uid();
update public.preparation_goals set status='archived',archived_at=now() where user_id=auth.uid() and status='active';
update public.scheduled_workouts set scheduled_date=scheduled_date-365 where user_id=auth.uid() and scheduled_date>=current_date-2;

create temp table examples(minutes int, plan jsonb);
do $$
declare g uuid; a uuid; ref_id uuid; wk date:=current_date+8-extract(isodow from current_date)::int; p jsonb; minutes int; avail jsonb; r jsonb; q jsonb;
begin
foreach minutes in array array[25,35,60] loop
 insert into public.preparation_goals(user_id,program_id,target_date)
 values(auth.uid(),'fas_periodic_assessment',current_date+90) returning id into g;
 insert into public.fas_periodic_assessments(user_id,preparation_goal_id,catalog_version,category,age_at_assessment,age_band,is_pre_effective_reference)
 values(auth.uid(),g,'es_def_15_2026_periodic_2027_v1','men',30,'26_30',true) returning id into a;
 insert into public.fas_periodic_marks(assessment_id,test_id,value) values(a,'run_2000_m',478000);
 insert into public.running_reference_selections(preparation_goal_id,reference_source,reference_record_id) values(g,'fasPeriodicAssessment',a::text);
 insert into public.running_intake_contexts(preparation_goal_id,context_version,available_minutes_by_weekday,
 reserved_strength_weekdays,running_days_last_four_weeks,running_minutes_last_four_weeks,recent_weeks_end_on,
 reports_pain,requires_professional_review,health_observed_at,comfortable_continuous_minutes,target_2k_seconds,goal_mode)
 values(g,'running_initial_context_v2','{"1":60,"3":60,"5":60}','{}',array[3,3,3,3],array[110,110,110,110],
 current_date-extract(isodow from current_date)::int,false,false,now(),60,465,'time');
 perform public.save_performance_context('{"1":60,"3":60,"5":60}','{}',false,true);
 ref_id:=public.save_performance_reference(g,jsonb_build_object('goal_code','push_up_standard','goal_version',1,'goal_measurement','REPS_IN_TIME','program_objective_key','legacy:upper_body_push_ups_2_min',
   'task','{"exercise_code":"push_up_standard","exercise_version":1,"protocol_key":"floor_v1","protocol_version":1,"setup_key":"Suelo y recorrido completo","measurement":"REPS","load_mode":"bodyweight","target_value":55,"target_rir":3,"intent":"work"}'::jsonb,
   'reference_kind','performed_set','targets','[55]'::jsonb,'observed_on',current_date,'current_capacity_confirmed',true,
   'reported_rir',3,'rest_seconds',120,'frequency',2));
 perform public.save_performance_reference(g,jsonb_build_object('goal_code','front_plank_forearms','goal_version',1,'goal_measurement','DURATION','program_objective_key','legacy:abdominal_plank',
   'task','{"exercise_code":"front_plank_forearms","exercise_version":1,"protocol_key":"def_15_2026_plank","protocol_version":1,"setup_key":"Suelo antideslizante y codos bajo hombros","measurement":"DURATION","load_mode":"bodyweight","target_value":55,"intent":"work"}'::jsonb,
   'reference_kind','capacity_test','targets','[55]'::jsonb,'observed_on',current_date,'current_capacity_confirmed',true,'rest_seconds',90,'frequency',1));
 perform public.save_performance_reference(g,jsonb_build_object('goal_code','slalom_ball_course_16m','goal_version',1,'goal_measurement','TIME_FOR_COURSE','program_objective_key','legacy:agility_speed_circuit','equipment_confirmed',true,
   'task','{"exercise_code":"slalom_ball_course_16m","exercise_version":1,"protocol_key":"def_15_2026_agility","protocol_version":1,"setup_key":"Siete conos y corredor medido de 16 por 2 metros","measurement":"TIME_FOR_COURSE","load_mode":"bodyweight","target_value":15.5,"intent":"practice"}'::jsonb,
   'reference_kind','performed_set','targets','[13]'::jsonb,'observed_on',current_date,'current_capacity_confirmed',true,'rest_seconds',180,'frequency',1));
 if jsonb_array_length(public.get_preparation_training_setup(g)->'objectives')<>3 then raise exception 'No reconoce las tres pruebas FAS'; end if;

avail:=jsonb_build_object('1',minutes,'3',minutes,'5',minutes);
update public.running_intake_contexts set available_minutes_by_weekday=avail where preparation_goal_id=g;
perform public.save_performance_context(avail,array['cones','measuring_tape','tennis_ball','chalk'],false,true);
p:=public.calculate_preparation_week(g,wk);
if p->>'status'<>'ready' or (p->'coverage'->>'running_scheduled')::int<2 then raise exception 'Pierde cobertura con % minutos: %',minutes,p; end if;
if minutes<60 and not exists(select 1 from jsonb_array_elements(p->'pending') x where x->>'status'='reduced_running_coverage') then raise exception 'Reduce carrera sin explicarlo'; end if;
if minutes=25 and not exists(select 1 from jsonb_array_elements(p->'proposals') x where x->>'compact'='true') then raise exception 'No usa un formato corto explícito'; end if;
if exists(select 1 from (select value->>'date' as training_date,(value->>'minutes')::int as amount from jsonb_array_elements(p->'sessions') union all
 select value->>'date',(value->>'minutes')::int from jsonb_array_elements(p->'running'->'sessions')) days group by training_date having sum(amount)>minutes) then raise exception 'Supera la disponibilidad real'; end if;
insert into examples values(minutes,p);
if minutes=60 then
 select reference into r from public.performance_training_references where id=ref_id;
 perform public.save_performance_reference(g,(r-'id'-'reference_kind')||'{"goal_version":1}');
 q:=public.calculate_preparation_week(g,wk);
 if q->>'status'<>'needs_attention' then raise exception 'Oculta la única referencia ambigua de un objetivo porque era apoyo'; end if;
end if;
update public.preparation_goals set status='archived',archived_at=now() where id=g;
end loop;
end $$;
select minutes,plan from examples;
rollback;
