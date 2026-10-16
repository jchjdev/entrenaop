begin;

-- Un control sustituye trabajo, pero no acredita la familia sustituida.
create function public.running_previous_evidence_v6(previous jsonb) returns jsonb
language plpgsql immutable set search_path='' as $$
begin
 if coalesce((previous->>'rotation_after_control_normalized')::boolean,false)
  or coalesce((previous->>'rotation')::int,0)=0 then return previous; end if;
 if exists(select 1 from jsonb_array_elements(coalesce(previous->'sessions','[]')) s
   where s->>'family'='C' and s->'control'->>'version'='adaptive_protocol_control_v1'
    and s->>'intention' in ('T','V','S'))
  and not exists(select 1 from jsonb_array_elements(previous->'sessions') s where s->>'family' in ('T','V','S'))
  and not exists(select 1 from jsonb_array_elements(coalesce(previous->'changes','[]')) x where x->>'dimension'='anchor_recalibration') then
  return previous||jsonb_build_object('rotation',(previous->>'rotation')::int-1,
   'rotation_after_control_normalized',true,'rotation_evidence_policy','running_control_evidence_v1');
 end if;
 return previous;
end $$;
revoke all on function public.running_previous_evidence_v6(jsonb) from public,anon,authenticated;


create or replace function public.calculate_running_week_constrained(
 p_goal_id uuid,p_week_start date,p_replay_initial boolean,p_preview_future boolean,p_constraints jsonb
) returns jsonb language plpgsql security definer set search_path = '' as $$
declare
 u uuid:=auth.uid(); g public.preparation_goals%rowtype;
 ctx public.running_intake_contexts%rowtype; ref record; age integer;
 revise boolean:=coalesce((p_constraints->>'revise_week')::boolean,false);
 excluded uuid[]:=array(select value::uuid from jsonb_array_elements_text(coalesce(p_constraints->'excluded_session_ids','[]')));
 last_sunday date:=current_date-extract(isodow from current_date)::integer;
 prev public.running_week_decisions%rowtype; existing public.running_week_decisions%rowtype;
 standard jsonb; controls jsonb; history jsonb; occupied jsonb; legs jsonb; input jsonb; result jsonb; previous jsonb; capacity_evidence jsonb;
begin
 if u is null then raise exception 'Authentication required'; end if;
 if extract(isodow from p_week_start)<>1 or p_week_start<last_sunday-6 or p_week_start>current_date+28 then
   raise exception 'Choose a current or upcoming complete week'; end if;
 select * into g from public.preparation_goals where id=p_goal_id and user_id=u
   and status='active';
 if not found then raise exception 'Active running preparation not found'; end if;
 if not p_replay_initial then
   select * into existing from public.running_week_decisions where preparation_goal_id=p_goal_id and week_start=p_week_start and superseded_at is null;
   if found and not revise then return existing.decision||jsonb_build_object('decision_id',existing.id,'already_published',true); end if;
   select * into prev from public.running_week_decisions where preparation_goal_id=p_goal_id and week_start<p_week_start and superseded_at is null order by week_start desc limit 1;
 end if;
 if prev.id is not null and current_date<p_week_start-1 and not p_preview_future then
   raise exception 'Close the previous week before adapting'; end if;
 select * into ctx from public.running_intake_contexts where preparation_goal_id=p_goal_id;
 if not found then raise exception 'Update the current running context'; end if;
 -- Solo cambia la proyección de carga; conserva las fechas de salud y el motor v5.
 ctx:=jsonb_populate_record(ctx,public.running_context_observed_v1(p_goal_id,current_date));
 if ctx.updated_at::date<current_date-30 or ctx.health_observed_at::date<current_date-30
   or (prev.id is null and ctx.recent_weeks_end_on<>last_sunday) then
   raise exception 'Update the current running context'; end if;
 if ctx.reports_pain or ctx.requires_professional_review then raise exception 'Health flag pauses the automatic proposal'; end if;
 select * into ref from jsonb_to_record(public.resolve_program_running_reference(p_goal_id))
   as x(reference_source text,reference_record_id text,continuity_confirmed_at timestamptz,completed_at timestamptz,value numeric,standard jsonb,controls jsonb);
 standard:=ref.standard; controls:=ref.controls;
 age:=current_date-ref.completed_at::date;
 if age<0 or ref.completed_at>now() then raise exception 'The selected 2 km mark is outside the reuse window'; end if;
 if age>30 and age<=45 and not public.running_continuity_observed_v1(p_goal_id,current_date) and (ref.continuity_confirmed_at is null
   or ctx.recent_weeks_end_on<>last_sunday or 0=any(ctx.running_days_last_four_weeks)) then
   raise exception 'Confirm uninterrupted running before reuse'; end if;
 -- Fuera de ventana no se derivan ritmos. La semana fácil de mantenimiento
 -- solicita un control nuevo; no inventa una mejora ni perpetúa un ancla vieja.
 select coalesce(jsonb_agg(extract(isodow from public.workout_load_on_v1(scheduled_workouts))::integer),'[]') into occupied
 from public.scheduled_workouts where user_id=u and public.workout_load_on_v1(scheduled_workouts) between p_week_start and p_week_start+6
   and status not in ('cancelled','skipped') and not scheduled_workouts.id=any(excluded)
   and (not revise or scheduled_workouts.id not in (select public.preparation_revision_session_ids(p_goal_id,p_week_start)))
   and (not p_replay_initial or preparation_goal_id is distinct from p_goal_id or source<>'algorithm');
 select coalesce(jsonb_agg(jsonb_build_object('date',coalesce(public.workout_performed_on_v1(e),sw.scheduled_date),'scheduled_date',sw.scheduled_date,
   'session',coalesce(rs.prescription,case when rs.kind='easy' then jsonb_build_object('family','E','step',0,
     'variant_code','legacy_easy','minutes',rs.planned_minutes,'rpe_ceiling',5,
     'pace_basis','effort_only_legacy','segments',jsonb_build_array(jsonb_build_object('role','work','seconds',rs.planned_minutes*60)))
     else jsonb_build_object('family','legacy','segments','[]'::jsonb) end),
   'execution',jsonb_build_object('id',e.id,'completed_at',e.completed_at,
     'status',coalesce(public.workout_block_outcome_v1(e.id)->>'status',sw.status),'rpe',case when exists(select 1 from public.performance_week_work pw where pw.scheduled_workout_id=sw.id)
   then (select max(r.actual_rpe) from public.workout_execution_sets r where r.execution_id=e.id and r.block_format='running') else e.final_rpe end,'abandonment_reason',public.workout_block_outcome_v1(e.id)->>'abandonment_reason',
     'discomfort',coalesce(e.abandonment_reason='discomfort' and e.completed_at>=ctx.health_observed_at,false),
     'sets',coalesce(sets.items,'[]'::jsonb))) order by coalesce(public.workout_performed_on_v1(e),sw.scheduled_date),e.id),'[]') into history
 from public.running_week_decisions wd join public.running_week_sessions rs on rs.decision_id=wd.id
 join public.scheduled_workouts sw on sw.id=rs.scheduled_workout_id
 left join public.workout_executions e on e.id=sw.execution_id
 left join lateral (select jsonb_agg(jsonb_build_object('status',es.status,
   'seconds',es.actual_duration_seconds,'meters',es.actual_distance_meters,
   'recovery_seconds',es.actual_recovery_duration_seconds,'rpe',es.actual_rpe)
   order by es.block_order,es.item_order,es.set_order) items
   from public.workout_execution_sets es where es.execution_id=e.id and es.block_format='running') sets on true
 where sw.user_id=u and sw.status not in ('cancelled') and wd.policy_version in ('running_2k_v1','running_2k_v2','running_2k_v3','running_2k_v4','running_2k_v5','running_2k_v6') and not coalesce(rs.prescription,'{}'::jsonb) ? 'control'
   and coalesce(public.workout_performed_on_v1(e),sw.scheduled_date)>=p_week_start-56
   and coalesce(public.workout_performed_on_v1(e),sw.scheduled_date)<p_week_start and not p_replay_initial;
 previous:=coalesce(prev.decision,'{}');
 select coalesce(jsonb_agg(public.workout_load_on_v1(sw)-p_week_start+1),'[]') into legs
 from public.scheduled_workouts sw where sw.user_id=u and public.workout_load_on_v1(sw) between p_week_start-1 and p_week_start+7
   and sw.status not in ('cancelled','skipped') and not sw.id=any(excluded)
   and (not revise or sw.id not in (select public.preparation_revision_session_ids(p_goal_id,p_week_start))) and exists(select 1 from public.workout_blocks b
     where b.template_id=sw.template_id and b.format not in ('running','warm_up','cool_down')
       and exists(select 1 from public.workout_items wi join public.exercises ex on ex.id=wi.exercise_id
         left join public.exercise_training_profiles ep on ep.code=ex.training_profile_code and ep.definition_version=ex.training_profile_version
         where wi.block_id=b.id and (ep.code is null or ep.definition->'body_regions' ? 'lower_body')));
 if prev.id is not null and prev.policy_version not in ('running_2k_v1','running_2k_v2','running_2k_v3','running_2k_v4','running_2k_v5','running_2k_v6') then
   previous:=previous||jsonb_build_object('normal_budget',
     (select sum(planned_minutes) from public.running_week_sessions where decision_id=prev.id),
     'load_weeks',0,'rotation',0);
 end if;
 capacity_evidence:=public.running_capacity_observed_v1(p_goal_id,p_week_start);
 input:=jsonb_build_object('week_start',p_week_start,'target_date',g.target_date,
   'anchor_seconds',ref.value/1000.0,'anchor_age_days',age,'goal_seconds',ctx.target_2k_seconds,
   'goal_mode',ctx.goal_mode,'official_margin_seconds',ctx.official_margin_seconds,
   'official_standard',standard,'controls',controls,
   'availability',ctx.available_minutes_by_weekday,'strength_days',ctx.reserved_strength_weekdays,
   'occupied_days',occupied,'leg_load_days',legs,'recent_days',ctx.running_days_last_four_weeks,
   'recent_minutes',ctx.running_minutes_last_four_weeks,'declared_prior_quality_weeks',ctx.quality_weeks_last_four,
   'capacity_minutes',capacity_evidence->'trial_minutes','capacity_evidence',capacity_evidence,
   'pain',false,'previous',previous-'evidence'-'input_snapshot','history',history);
 -- El coordinador puede solicitar otra propuesta con el tiempo restante.
 -- La selección deportiva usa v6; la evidencia usa la realización real.
 if p_constraints ? 'availability' then input:=jsonb_set(input,'{availability}',p_constraints->'availability'); end if;
 if p_constraints ? 'strength_days' then input:=jsonb_set(input,'{strength_days}',p_constraints->'strength_days'); end if;
 if p_constraints ? 'leg_load_days' then input:=jsonb_set(input,'{leg_load_days}',legs||(p_constraints->'leg_load_days')); end if;
 input:=jsonb_set(input,'{previous}',public.running_previous_evidence_v6(input->'previous'));
 result:=public.running_plan_v6(input);
 return result||jsonb_build_object('coordination_evidence_policy_version','running_control_evidence_v1','capacity_evidence',capacity_evidence,'evidence_policy_version','adaptive_evidence_v1','goal_id',p_goal_id,'reference_source',ref.reference_source,
   'reference_record_id',ref.reference_record_id,'reference_completed_at',ref.completed_at,
   'reference_2k_milliseconds',ref.value,'context_updated_at',ctx.updated_at,'declared_prior_quality_weeks',ctx.quality_weeks_last_four);
end $$;

commit;
