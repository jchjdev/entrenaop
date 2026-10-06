-- Adaptadores de fuentes, no algoritmos por programa. Todas las fuentes se
-- resuelven dentro de la preparación propia y llaman al mismo motor de 2 km.
begin;
create function public.resolve_program_running_reference(p_goal_id uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare u uuid:=auth.uid(); g public.preparation_goals%rowtype;
 sel public.running_reference_selections%rowtype; r record; selected_test uuid;
 standard jsonb; controls jsonb:='[]'; n int;
begin
 select * into g from public.preparation_goals where id=p_goal_id and user_id=u and status='active';
 if not found then raise exception 'Active running preparation not found'; end if;
 select * into sel from public.running_reference_selections where preparation_goal_id=g.id;
 if not found then raise exception 'Choose a compatible 2 km mark in this preparation'; end if;
 if g.program_id='fas_periodic_assessment' and sel.reference_source='fasPeriodicAssessment' then
   select a.completed_at,m.value/1000.0 seconds into r from public.fas_periodic_assessments a
   join public.fas_periodic_marks m on m.assessment_id=a.id and m.test_id='run_2000_m'
   where a.id::text=sel.reference_record_id and a.user_id=u and a.preparation_goal_id=g.id;
   select jsonb_build_object('seconds',s.threshold/1000.0,'catalog_version',a.catalog_version,
     'category',a.category,'age_band',a.age_band,'scope','minimum_20_points_not_global_pass') into standard
   from public.fas_periodic_assessments a join public.fas_periodic_standards s
     on s.catalog_version=a.catalog_version and s.category=a.category and s.age_band=a.age_band and s.test_id='run_2000_m'
   where a.id::text=sel.reference_record_id and a.user_id=u and a.preparation_goal_id=g.id;
   select coalesce(jsonb_agg(jsonb_build_object('date',a.completed_at::date,'seconds',m.value/1000.0,
     'protocol',a.catalog_version||':run_2000_m') order by a.completed_at),'[]') into controls
   from public.fas_periodic_assessments a join public.fas_periodic_marks m on m.assessment_id=a.id and m.test_id='run_2000_m'
   where a.preparation_goal_id=g.id and a.user_id=u and a.completed_at<=r.completed_at and a.completed_at<=now();
 elsif g.program_id='armed_forces_troop_entry' and sel.reference_source='troopOfficialAssessment' then
   select a.completed_at,m.value/1000.0 seconds into r from public.physical_assessments a
   join public.physical_assessment_marks m on m.assessment_id=a.id and m.test_id='run_2000_m'
   where a.id::text=sel.reference_record_id and a.user_id=u and a.preparation_goal_id=g.id;
   select jsonb_build_object('seconds',s.threshold/1000.0,'catalog_version',a.catalog_version,
     'category',a.category,'scope','test_minimum_not_global_pass') into standard
   from public.physical_assessments a join public.assessment_standards s
   on s.catalog_version=a.catalog_version and s.category=a.category and s.milestone=a.milestone and s.test_id='run_2000_m'
   where a.id::text=sel.reference_record_id and a.user_id=u and a.preparation_goal_id=g.id;
   select coalesce(jsonb_agg(jsonb_build_object('date',a.completed_at::date,'seconds',m.value/1000.0,
     'protocol',a.catalog_version||':run_2000_m') order by a.completed_at),'[]') into controls
   from public.physical_assessments a join public.physical_assessment_marks m on m.assessment_id=a.id and m.test_id='run_2000_m'
   where a.preparation_goal_id=g.id and a.user_id=u and a.completed_at<=r.completed_at and a.completed_at<=now();
 elsif g.program_id='armed_forces_troop_entry' and sel.reference_source='troopControl' then
   select t.completed_at,t.duration_seconds::numeric seconds into r from public.preparation_running_tests t
   where t.id::text=sel.reference_record_id and t.user_id=u and t.preparation_goal_id=g.id and t.protocol_version='run_2000m_v1';
   select coalesce(jsonb_agg(jsonb_build_object('date',t.completed_at::date,'seconds',t.duration_seconds,
     'protocol',t.protocol_version) order by t.completed_at),'[]') into controls
   from public.preparation_running_tests t where t.user_id=u and t.preparation_goal_id=g.id
     and t.completed_at<=r.completed_at and t.completed_at<=now();
   -- Un control sin evaluación no inventa categoría ni umbral oficial.
 elsif sel.reference_source='programAssessment' then
   select count(*) into n from public.program_assessment_attempts a
   cross join lateral jsonb_array_elements(a.result->'details') d
   join public.program_training_modules tm on tm.test_id::text=d->>'test_id' and tm.program_id=g.program_id and tm.module_key='running_2000m_v1'
   join public.preparation_programs pp on pp.id=tm.program_id and pp.enabled
   where a.id::text=sel.reference_record_id and a.user_id=u and a.preparation_goal_id=g.id and a.program_id=g.program_id
     and (d->>'mark')::numeric>0 and not coalesce((d->>'invalid')::boolean,false);
   if n<>1 then raise exception 'Choose one unambiguous module-linked 2 km result'; end if;
   select a.assessed_on::timestamptz completed_at,(d->>'mark')::numeric seconds,
     (d->>'test_id')::uuid test_id,jsonb_build_object('seconds',(d->>'minimum_mark')::numeric,
       'catalog_version',a.scoring_version,'category',a.category,'age',a.result->'age',
       'scope','test_minimum_not_global_pass') official into r
   from public.program_assessment_attempts a cross join lateral jsonb_array_elements(a.result->'details') d
   join public.program_training_modules tm on tm.test_id::text=d->>'test_id' and tm.program_id=g.program_id and tm.module_key='running_2000m_v1'
   where a.id::text=sel.reference_record_id and a.user_id=u and a.preparation_goal_id=g.id and a.program_id=g.program_id
     and (d->>'mark')::numeric>0 and not coalesce((d->>'invalid')::boolean,false);
   selected_test:=r.test_id; standard:=r.official;
   select coalesce(jsonb_agg(jsonb_build_object('date',a.assessed_on,'seconds',(d->>'mark')::numeric,
     'protocol','run_2000m_v1:'||selected_test::text) order by a.assessed_on),'[]') into controls
   from public.program_assessment_attempts a cross join lateral jsonb_array_elements(a.result->'details') d
   where a.user_id=u and a.preparation_goal_id=g.id and a.program_id=g.program_id and d->>'test_id'=selected_test::text
     and a.assessed_on<=r.completed_at::date and a.assessed_on<=current_date
     and (d->>'mark')::numeric>0 and not coalesce((d->>'invalid')::boolean,false);
 else raise exception 'Reference source does not belong to this running program'; end if;
 if r.completed_at is null or r.seconds is null or r.seconds not between 240 and 1800 then
   raise exception 'Choose a compatible 2 km mark in this preparation'; end if;
 return jsonb_build_object('reference_source',sel.reference_source,'reference_record_id',sel.reference_record_id,
   'continuity_confirmed_at',sel.continuity_confirmed_at,'completed_at',r.completed_at,'value',r.seconds*1000,
   'standard',standard,'controls',controls);
end $$;

create or replace function public.calculate_running_week_core(
 p_goal_id uuid,p_week_start date,p_replay_initial boolean,p_preview_future boolean
) returns jsonb language plpgsql security definer set search_path = '' as $$
declare
 u uuid:=auth.uid(); g public.preparation_goals%rowtype;
 ctx public.running_intake_contexts%rowtype; ref record; age integer;
 last_sunday date:=current_date-extract(isodow from current_date)::integer;
 prev public.running_week_decisions%rowtype; existing public.running_week_decisions%rowtype;
 standard jsonb; controls jsonb; history jsonb; occupied jsonb; legs jsonb; input jsonb; result jsonb; previous jsonb;
begin
 if u is null then raise exception 'Authentication required'; end if;
 if extract(isodow from p_week_start)<>1 or p_week_start<last_sunday-6 or p_week_start>current_date+28 then
   raise exception 'Choose a current or upcoming complete week'; end if;
 select * into g from public.preparation_goals where id=p_goal_id and user_id=u
   and status='active';
 if not found then raise exception 'Active running preparation not found'; end if;
 if not p_replay_initial then
   select * into existing from public.running_week_decisions where preparation_goal_id=p_goal_id and week_start=p_week_start;
   if found then return existing.decision||jsonb_build_object('decision_id',existing.id,'already_published',true); end if;
   select * into prev from public.running_week_decisions where preparation_goal_id=p_goal_id and week_start<p_week_start order by week_start desc limit 1;
 end if;
 if prev.id is not null and current_date<p_week_start-1 and not p_preview_future then
   raise exception 'Close the previous week before adapting'; end if;
 select * into ctx from public.running_intake_contexts where preparation_goal_id=p_goal_id;
 if not found or ctx.updated_at::date<current_date-30 or ctx.health_observed_at::date<current_date-30
   or (prev.id is null and ctx.recent_weeks_end_on<>last_sunday) then
   raise exception 'Update the current running context'; end if;
 if ctx.reports_pain or ctx.requires_professional_review then raise exception 'Health flag pauses the automatic proposal'; end if;
 select * into ref from jsonb_to_record(public.resolve_program_running_reference(p_goal_id))
   as x(reference_source text,reference_record_id text,continuity_confirmed_at timestamptz,completed_at timestamptz,value numeric,standard jsonb,controls jsonb);
 standard:=ref.standard; controls:=ref.controls;
 age:=current_date-ref.completed_at::date;
 if age<0 or ref.completed_at>now() then raise exception 'The selected 2 km mark is outside the reuse window'; end if;
 if age>30 and age<=45 and (ref.continuity_confirmed_at is null
   or ctx.recent_weeks_end_on<>last_sunday or 0=any(ctx.running_days_last_four_weeks)) then
   raise exception 'Confirm uninterrupted running before reuse'; end if;
 -- Fuera de ventana no se derivan ritmos. La semana fácil de mantenimiento
 -- solicita un control nuevo; no inventa una mejora ni perpetúa un ancla vieja.
 select coalesce(jsonb_agg(extract(isodow from scheduled_date)::integer),'[]') into occupied
 from public.scheduled_workouts where user_id=u and scheduled_date between p_week_start and p_week_start+6
   and status not in ('cancelled','skipped')
   and (not p_replay_initial or preparation_goal_id is distinct from p_goal_id or source<>'algorithm');
 select coalesce(jsonb_agg(jsonb_build_object('date',sw.scheduled_date,
   'session',coalesce(rs.prescription,case when rs.kind='easy' then jsonb_build_object('family','E','step',0,
     'variant_code','legacy_easy','minutes',rs.planned_minutes,'rpe_ceiling',5,
     'pace_basis','effort_only_legacy','segments',jsonb_build_array(jsonb_build_object('role','work','seconds',rs.planned_minutes*60)))
     else jsonb_build_object('family','legacy','segments','[]'::jsonb) end),
   'execution',jsonb_build_object('id',e.id,'completed_at',e.completed_at,
     'status',sw.status,'rpe',e.final_rpe,'abandonment_reason',e.abandonment_reason,
     'discomfort',coalesce(e.abandonment_reason='discomfort' and e.completed_at>=ctx.health_observed_at,false),
     'sets',coalesce(sets.items,'[]'::jsonb))) order by sw.scheduled_date),'[]') into history
 from public.running_week_decisions wd join public.running_week_sessions rs on rs.decision_id=wd.id
 join public.scheduled_workouts sw on sw.id=rs.scheduled_workout_id
 left join public.workout_executions e on e.id=sw.execution_id
 left join lateral (select jsonb_agg(jsonb_build_object('status',es.status,
   'seconds',es.actual_duration_seconds,'meters',es.actual_distance_meters,
   'recovery_seconds',es.actual_recovery_duration_seconds,'rpe',es.actual_rpe)
   order by es.block_order,es.item_order,es.set_order) items
   from public.workout_execution_sets es where es.execution_id=e.id) sets on true
 where wd.preparation_goal_id=p_goal_id and wd.week_start>=p_week_start-56
   and wd.week_start<p_week_start and not p_replay_initial;
 previous:=coalesce(prev.decision,'{}');
 select coalesce(jsonb_agg(sw.scheduled_date-p_week_start+1),'[]') into legs
 from public.scheduled_workouts sw where sw.user_id=u and sw.scheduled_date between p_week_start-1 and p_week_start+7
   and sw.status not in ('cancelled','skipped') and exists(select 1 from public.workout_blocks b
     where b.template_id=sw.template_id and b.format not in ('running','warm_up','cool_down'));
 if prev.id is not null and prev.policy_version not in ('running_2k_v1','running_2k_v2') then
   previous:=previous||jsonb_build_object('normal_budget',
     (select sum(planned_minutes) from public.running_week_sessions where decision_id=prev.id),
     'load_weeks',0,'rotation',0);
 end if;
 input:=jsonb_build_object('week_start',p_week_start,'target_date',g.target_date,
   'anchor_seconds',ref.value/1000.0,'anchor_age_days',age,'goal_seconds',ctx.target_2k_seconds,
   'goal_mode',ctx.goal_mode,'official_margin_seconds',ctx.official_margin_seconds,
   'official_standard',standard,'controls',controls,
   'availability',ctx.available_minutes_by_weekday,'strength_days',ctx.reserved_strength_weekdays,
   'occupied_days',occupied,'leg_load_days',legs,'recent_days',ctx.running_days_last_four_weeks,
   'recent_minutes',ctx.running_minutes_last_four_weeks,'capacity_minutes',ctx.comfortable_continuous_minutes,
   'pain',false,'previous',previous-'evidence'-'input_snapshot','history',history);
 result:=public.running_plan_v2(input);
 return result||jsonb_build_object('goal_id',p_goal_id,'reference_source',ref.reference_source,
   'reference_record_id',ref.reference_record_id,'reference_completed_at',ref.completed_at,
   'reference_2k_milliseconds',ref.value,'context_updated_at',ctx.updated_at);
end $$;


create or replace function public.publish_running_week(p_goal_id uuid,p_week_start date)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
 u uuid:=auth.uid(); gid uuid; existing public.running_week_decisions%rowtype;
 plan jsonb; s jsonb; segment jsonb; decision_id uuid; template_id uuid;
 block_id uuid; item_id uuid; schedule_id uuid; idx integer;
begin
 if u is null then raise exception 'Authentication required'; end if;
 select id into gid from public.preparation_goals where id=p_goal_id and user_id=u
   and status='active' for update;
 if not found then raise exception 'Active running preparation not found'; end if;
 select * into existing from public.running_week_decisions where preparation_goal_id=p_goal_id and week_start=p_week_start;
 if found then return existing.decision||jsonb_build_object('decision_id',existing.id,'already_published',true); end if;
 plan:=public.calculate_running_week_core(p_goal_id,p_week_start,false,false);
 insert into public.running_week_decisions(user_id,preparation_goal_id,week_start,policy_version,basis,
   outcome,reference_source,reference_record_id,input_snapshot,decision)
 values(u,p_goal_id,p_week_start,plan->>'policy_version',plan->>'basis',plan->>'outcome',
   plan->>'reference_source',plan->>'reference_record_id',plan-'sessions',plan) returning id into decision_id;
 for s in select value from jsonb_array_elements(plan->'sessions') loop
   insert into public.workout_templates(name,description,origin,owner_user_id,visibility,status,estimated_duration_minutes,version)
   values(s->>'name',s->>'description','algorithm',u,'private','published',(s->>'minutes')::integer,1) returning id into template_id;
   insert into public.workout_blocks(template_id,order_index,name,format)
   values(template_id,0,s->>'name','running') returning id into block_id;
   insert into public.workout_items(block_id,exercise_id,order_index,notes)
   values(block_id,'20000000-0000-4000-8000-000000000004',0,
     (s->>'description')||' Esfuerzo orientativo máximo: '||(s->>'rpe_ceiling')||'/10.') returning id into item_id;
   idx:=0;
   for segment in select value from jsonb_array_elements(s->'segments') loop
     insert into public.workout_sets(item_id,order_index,target_duration_seconds,target_distance_meters,
       target_pace_min_seconds_per_km,target_pace_max_seconds_per_km,recovery_type,recovery_duration_seconds)
     values(item_id,idx,(segment->>'seconds')::integer,(segment->>'meters')::numeric,
       (segment->>'pace_min')::integer,(segment->>'pace_max')::integer,
       case when segment ? 'recovery_seconds' then coalesce(segment->>'recovery_type','jogging') end,(segment->>'recovery_seconds')::integer);
     idx:=idx+1;
   end loop;
   insert into public.scheduled_workouts(user_id,template_id,template_name,template_version,
     estimated_duration_minutes,preparation_goal_id,scheduled_date,source,status)
   values(u,template_id,s->>'name',1,(s->>'minutes')::integer,p_goal_id,(s->>'date')::date,'algorithm','planned') returning id into schedule_id;
   insert into public.running_week_sessions(decision_id,scheduled_workout_id,kind,planned_minutes,variant_code,prescription)
   values(decision_id,schedule_id,s->>'kind',(s->>'minutes')::integer,s->>'variant_code',s);
 end loop;
 return plan||jsonb_build_object('decision_id',decision_id,'already_published',false);
end $$;
create function public.preview_running_next_week(p_goal_id uuid)
returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  v_last_week date;
  v_next_week date;
  v_result jsonb;
begin
  if v_user is null then raise exception 'Authentication required'; end if;
  if not exists (
    select 1 from public.preparation_goals g
    where g.id = p_goal_id and g.user_id = v_user
      and g.status = 'active'

  ) then raise exception 'Active running preparation not found'; end if;
  select max(d.week_start) into v_last_week
  from public.running_week_decisions d
  where d.preparation_goal_id = p_goal_id and d.user_id = v_user;
  if v_last_week is null then
    raise exception 'Publish a week before previewing its successor';
  end if;
  if exists (
    select 1 from public.running_week_decisions d
    join public.running_week_sessions rs on rs.decision_id = d.id
    join public.scheduled_workouts sw on sw.id = rs.scheduled_workout_id
    where d.preparation_goal_id = p_goal_id and d.week_start = v_last_week
      and sw.status in ('planned', 'in_progress')
  ) then
    raise exception 'Finish or skip the published sessions before forecasting';
  end if;
  v_next_week := v_last_week + 7;
  if exists (
    select 1 from public.running_week_decisions d
    where d.preparation_goal_id = p_goal_id and d.week_start = v_next_week
  ) then
    raise exception 'The next week is already published';
  end if;
  v_result := public.calculate_running_week_core(
    p_goal_id, v_next_week, false, true);
  return v_result || jsonb_build_object(
    'simulation', true, 'forecast', true, 'source_week', v_last_week);
end;
$$;


create function public.calculate_running_week(p_goal_id uuid,p_week_start date) returns jsonb language sql security definer set search_path='' as $$
 select public.calculate_running_week_core($1,$2,false,false) $$;
create function public.preview_running_initial_week(p_goal_id uuid,p_week_start date) returns jsonb language sql security definer set search_path='' as $$
 select public.calculate_running_week_core($1,$2,true,false)||jsonb_build_object('simulation',true) $$;
-- Alias de compatibilidad de clientes anteriores: no conservan otro decisor.
create or replace function public.calculate_fas_running_week_core(p_goal_id uuid,p_week_start date,p_replay_initial boolean,p_preview_future boolean)
 returns jsonb language sql security definer set search_path='' as $$
 select public.calculate_running_week_core($1,$2,$3,$4) $$;
create or replace function public.publish_fas_running_week(p_goal_id uuid,p_week_start date) returns jsonb
 language sql security definer set search_path='' as $$ select public.publish_running_week($1,$2) $$;
create or replace function public.preview_fas_running_next_week(p_goal_id uuid) returns jsonb
 language sql security definer set search_path='' as $$ select public.preview_running_next_week($1) $$;
revoke all on function public.resolve_program_running_reference(uuid),public.calculate_running_week_core(uuid,date,boolean,boolean)
 from public,anon,authenticated;
revoke all on function public.calculate_running_week(uuid,date),public.preview_running_initial_week(uuid,date),
 public.preview_running_next_week(uuid),public.publish_running_week(uuid,date) from public,anon;
grant execute on function public.calculate_running_week(uuid,date),public.preview_running_initial_week(uuid,date),
 public.preview_running_next_week(uuid),public.publish_running_week(uuid,date) to authenticated;


commit;
