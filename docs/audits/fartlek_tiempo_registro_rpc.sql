-- Comprueba el límite del RPC de registro manual con una receta temporal.
-- Cuenta ficticia y ROLLBACK. Ejecutar en Dev, separado del barrido.
begin;
set local statement_timeout='55s';

create function pg_temp.fartlek_from_v0(original jsonb) returns jsonb
language sql immutable as $$
 select original||jsonb_build_object('variant_code','V_fartlek_8min_lab','name','Fartlek por tiempo',
  'pace_basis','effort_only_lab','segments',jsonb_build_array(original->'segments'->0)||
  (select jsonb_agg(jsonb_strip_nulls(jsonb_build_object('role','work','seconds',seconds,
    'recovery_seconds',case when idx<5 then 90 end)) order by idx)
   from (values (1,60),(2,120),(3,120),(4,120),(5,60)) work(idx,seconds))||
  jsonb_build_array(original->'segments'->-1))
$$;


create temp table rpc_probe(stage text, result text) on commit drop;
do $$
declare
 u uuid:=gen_random_uuid(); g uuid; mark uuid; execution uuid; set_id uuid; sid uuid; seconds int; error text;
 wk date:=current_date-extract(isodow from current_date)::int+1;
 recipe jsonb:=pg_temp.fartlek_from_v0(public.running_session_v2('V',0,550,30));
begin
 insert into auth.users(id,email) values(u,u||'@fartlek-lab.invalid');
 perform set_config('request.jwt.claim.sub',u::text,true);
 update public.profiles set fecha_nacimiento='1996-01-01' where id=u;
 insert into public.pro_access_grants(user_id,source,starts_at,ends_at,reason)
 values(u,'development_manual',now()-interval '1 day',now()+interval '1 day','Fixture fartlek');
 insert into public.preparation_goals(user_id,program_id,target_date)
 values(u,'fas_periodic_assessment',wk+100) returning id into g;
 insert into public.fas_periodic_assessments(user_id,preparation_goal_id,catalog_version,category,age_at_assessment,age_band,is_pre_effective_reference,completed_at)
 values(u,g,'es_def_15_2026_periodic_2027_v1','men',30,'26_30',true,now()-interval '5 days') returning id into mark;
 insert into public.fas_periodic_marks values(mark,'run_2000_m',550000);
 perform public.materialize_running_week_plan(g,wk,jsonb_build_object('policy_version','running_2k_v6',
  'basis','recent','outcome','maintain','reference_source','fasPeriodicAssessment','reference_record_id',mark,
  'sessions',jsonb_build_array(recipe||jsonb_build_object('date',current_date))));
 select id into strict sid from public.scheduled_workouts where preparation_goal_id=g and user_id=u;
 execution:=public.start_reviewed_scheduled_workout(u,sid,public.get_scheduled_workout_preview(u,sid)->>'revision');
 insert into rpc_probe values('start_reviewed_scheduled_workout','ok');
 select id,target_duration_seconds into set_id,seconds from public.workout_execution_sets
  where execution_id=execution order by block_order,item_order,set_order limit 1;
 begin
  perform public.complete_workout_set_idempotent(gen_random_uuid(),set_id,
   p_actual_duration_seconds=>seconds,p_actual_distance_meters=>null);
  insert into rpc_probe values('complete_workout_set_idempotent','accepted');
 exception when others then
  get stacked diagnostics error=message_text;
  insert into rpc_probe values('complete_workout_set_idempotent',sqlstate||' '||error);
 end;
end $$;
select * from rpc_probe;
rollback;
