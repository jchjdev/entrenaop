begin;

alter table trainer_private.calendar_sharing add column results_enabled boolean not null default false;
alter table trainer_private.calendar_sharing add constraint shared_results_require_calendar check(not results_enabled or enabled);

create function trainer_private.clear_results_with_calendar() returns trigger
language plpgsql set search_path='' as $$begin
 if not new.enabled then new.results_enabled:=false;end if;
 return new;
end $$;
revoke all on function trainer_private.clear_results_with_calendar() from public,anon,authenticated,service_role;
create trigger clear_results_with_calendar before insert or update of enabled,results_enabled on trainer_private.calendar_sharing
 for each row execute function trainer_private.clear_results_with_calendar();

do $$declare definition text;anchor text;begin
 definition:=pg_get_functiondef('trainer_private.my_calendar_sharing(uuid)'::regprocedure);
 anchor:='''enabled'',coalesce(v.enabled,false),';
 if strpos(definition,anchor)=0 then raise exception 'Revisar lectura del consentimiento';end if;
 execute replace(definition,anchor,anchor||'''results_enabled'',coalesce(v.results_enabled,false),');
end $$;

create function trainer_private.set_my_result_sharing(p_expected_owner uuid,p_enabled boolean,p_expected_revision bigint)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v trainer_private.calendar_sharing;begin
 perform trainer_private.my_calendar_sharing(p_expected_owner);
 if not exists(select 1 from auth.sessions where id=(auth.jwt()->>'session_id')::uuid and user_id=auth.uid()
  and (not_after is null or not_after>statement_timestamp())) then raise insufficient_privilege;end if;
 if p_enabled is null or p_expected_revision is null or p_expected_revision<0 then raise invalid_parameter_value;end if;
 perform pg_advisory_xact_lock(hashtextextended('trainer-client:'||auth.uid()::text,0));
 select * into v from trainer_private.calendar_sharing where client_id=auth.uid() for update;
 if v.revision=p_expected_revision+1 and v.results_enabled=p_enabled then return trainer_private.my_calendar_sharing(p_expected_owner);end if;
 if coalesce(v.revision,0)<>p_expected_revision then raise serialization_failure;end if;
 if p_enabled and (not coalesce(v.enabled,false) or not exists(select 1 from public.trainer_client_relations
  where client_id=auth.uid() and trainer_id<>client_id and ended_at is null)) then
  raise exception 'Activa el calendario compartido con un preparador vigente.' using errcode='23514';end if;
 if coalesce(v.results_enabled,false)=p_enabled then return trainer_private.my_calendar_sharing(p_expected_owner);end if;
 update trainer_private.calendar_sharing set results_enabled=p_enabled,revision=revision+1,updated_at=clock_timestamp() where client_id=auth.uid();
 insert into trainer_private.calendar_revisions(user_id,revision) values(auth.uid(),1)
  on conflict(user_id) do update set revision=trainer_private.calendar_revisions.revision+1;
 return trainer_private.my_calendar_sharing(p_expected_owner);
end $$;
create function public.set_my_trainer_result_sharing(p_expected_owner uuid,p_enabled boolean,p_expected_revision bigint)
returns jsonb language sql security invoker set search_path='' as $$
 select trainer_private.set_my_result_sharing(p_expected_owner,p_enabled,p_expected_revision)
$$;
revoke all on function trainer_private.set_my_result_sharing(uuid,boolean,bigint),public.set_my_trainer_result_sharing(uuid,boolean,bigint)
 from public,anon,authenticated,service_role;
grant execute on function trainer_private.set_my_result_sharing(uuid,boolean,bigint),public.set_my_trainer_result_sharing(uuid,boolean,bigint) to authenticated;

-- Lista positiva: nuevas columnas y claves JSON no quedan compartidas por
-- accidente. Se excluyen notas, instrucciones libres, revisiones y medios.
create function trainer_private.sport_fields(p_value jsonb,p_keys text[]) returns jsonb
language sql immutable set search_path='' as $$
 select coalesce(jsonb_object_agg(key,value),'{}'::jsonb) from jsonb_each(
  case when jsonb_typeof(p_value)='object' then p_value else '{}'::jsonb end) where key=any(p_keys)
$$;
revoke all on function trainer_private.sport_fields(jsonb,text[]) from public,anon,authenticated,service_role;

create function trainer_private.shared_workout_result(p_expected_owner uuid,p_client_id uuid,p_scheduled_id uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare answer jsonb;own boolean;begin
 if not trainer_private.shared_calendar_access(p_expected_owner,p_client_id) or not exists(
  select 1 from auth.sessions where id=(auth.jwt()->>'session_id')::uuid and user_id=auth.uid() and aal='aal2'
  and (not_after is null or not_after>statement_timestamp())) then raise insufficient_privilege;end if;
 select exists(select 1 from public.trainer_assignments where scheduled_id=p_scheduled_id and client_id=p_client_id and trainer_id=auth.uid()) into own;
 if not own and not coalesce((select results_enabled from trainer_private.calendar_sharing where client_id=p_client_id and enabled),false)
  then raise insufficient_privilege;end if;
 if not exists(select 1 from public.scheduled_workouts where id=p_scheduled_id and user_id=p_client_id) then raise insufficient_privilege;end if;
 select trainer_private.sport_fields(to_jsonb(e),array[
  'id','template_id','template_name','template_version','status','started_at','completed_at','performed_at','performed_utc_offset_minutes',
  'final_rpe','average_heart_rate_bpm','max_heart_rate_bpm','result_source','session_type','session_type_policy',
  'observed_timer_seconds','observed_elapsed_seconds','observed_distance_meters'])||jsonb_build_object(
   'shared_read_only',true,
   'workout_execution_sets',coalesce((select jsonb_agg(
    trainer_private.sport_fields(to_jsonb(w),array[
     'id','block_order','block_name','item_order','exercise_id','exercise_name','set_order','block_format','block_time_cap_seconds',
     'target_reps','target_duration_seconds','target_distance_meters','target_load_kg','target_rpe','target_rir',
     'target_pace_min_seconds_per_km','target_pace_max_seconds_per_km','rest_after_seconds','status','actual_reps','actual_duration_seconds',
     'actual_distance_meters','actual_load_kg','actual_rpe','actual_rir','completed_at','recovery_type','recovery_duration_seconds',
     'recovery_distance_meters','actual_recovery_duration_seconds','actual_recovery_distance_meters','result_source',
     'observed_duration_seconds','observed_recovery_duration_seconds'])||jsonb_build_object(
      'running_step',case when jsonb_typeof(w.running_step) is distinct from 'object' then null else trainer_private.sport_fields(w.running_step,array['schema_version','kind','completion']) end,
      'performance_prescription',case when jsonb_typeof(w.performance_prescription) is distinct from 'object' then null else trainer_private.sport_fields(w.performance_prescription,array[
       'schema_version','exercise_code','exercise_version','protocol_key','protocol_version','setup_key','measurement','load_mode','policy_version',
       'target_value','intent','fixed_duration_seconds','fixed_distance_meters','external_load_kg','body_mass_kg','target_rir','effort_mode',
       'target_rpe','stimulus_code','records_stimulus_responses','records_penalty_seconds']) end,
      'performance_result',case when jsonb_typeof(w.performance_result) is distinct from 'object' then null else trainer_private.sport_fields(w.performance_result,array[
       'value','technique_valid','conditions_confirmed','tolerated','rir','rpe','load_kg','body_mass_kg','penalty_seconds',
       'correct_responses','total_responses','succeeded','actual_duration_seconds','jump_height_meters','measurement_method','stop_reason']) end)
    order by w.block_order,w.item_order,w.set_order) from public.workout_execution_sets w where w.execution_id=e.id),'[]'::jsonb),
   'workout_amrap_results',coalesce((select jsonb_agg(trainer_private.sport_fields(to_jsonb(a),array[
    'block_order','completed_rounds','partial_item_order','partial_reps','completed_at']) order by a.block_order)
     from public.workout_amrap_results a where a.execution_id=e.id),'[]'::jsonb)) into answer
  from public.scheduled_workouts s join public.workout_executions e on e.id=s.execution_id and e.user_id=p_client_id
  where s.id=p_scheduled_id and s.user_id=p_client_id and s.status='completed' and e.status='completed';
 return answer;
end $$;
create function public.get_trainer_shared_workout_result(p_expected_owner uuid,p_client_id uuid,p_scheduled_id uuid)
returns jsonb language sql stable security invoker set search_path='' as $$
 select trainer_private.shared_workout_result(p_expected_owner,p_client_id,p_scheduled_id)
$$;
revoke all on function trainer_private.shared_workout_result(uuid,uuid,uuid),public.get_trainer_shared_workout_result(uuid,uuid,uuid)
 from public,anon,authenticated,service_role;
grant execute on function trainer_private.shared_workout_result(uuid,uuid,uuid),public.get_trainer_shared_workout_result(uuid,uuid,uuid) to authenticated;

do $$declare definition text;begin
 definition:=pg_get_functiondef('trainer_private.shared_client_calendar(uuid,uuid,date,date,date,uuid)'::regprocedure);
 execute replace(definition,'trainer_private.shared_client_calendar(', 'trainer_private.shared_client_calendar_plan_v1(');
end $$;
revoke all on function trainer_private.shared_client_calendar_plan_v1(uuid,uuid,date,date,date,uuid) from public,anon,authenticated,service_role;

create or replace function trainer_private.shared_client_calendar(p_expected_owner uuid,p_client_id uuid,p_from date,p_to date,
 p_after_date date default null,p_after_id uuid default null) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare answer jsonb;shared boolean;items jsonb;begin
 answer:=trainer_private.shared_client_calendar_plan_v1(p_expected_owner,p_client_id,p_from,p_to,p_after_date,p_after_id);
 if answer->>'shared'<>'true' then return answer;end if;
 shared:=coalesce((select results_enabled from trainer_private.calendar_sharing where client_id=p_client_id and enabled),false);
 select coalesce(jsonb_agg(item||jsonb_build_object('has_result',
   (shared or coalesce((item->>'is_own')::boolean,false)) and exists(select 1 from public.scheduled_workouts s
    join public.workout_executions e on e.id=s.execution_id and e.user_id=p_client_id
    where s.id=(item->>'id')::uuid and s.user_id=p_client_id and s.status='completed' and e.status='completed')) order by ordinal),'[]'::jsonb)
  into items from jsonb_array_elements(answer->'items') with ordinality as x(item,ordinal);
 return answer||jsonb_build_object('results_shared',shared,'items',items);
end $$;

commit;
