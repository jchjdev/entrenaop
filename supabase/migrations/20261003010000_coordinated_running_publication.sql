-- Materialización interna de una decisión de carrera ya coordinada.
begin;
create or replace function public.materialize_running_week_plan(p_goal_id uuid,p_week_start date,p_plan jsonb)
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
 plan:=p_plan;
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
revoke all on function public.materialize_running_week_plan(uuid,date,jsonb) from public,anon,authenticated;
commit;

