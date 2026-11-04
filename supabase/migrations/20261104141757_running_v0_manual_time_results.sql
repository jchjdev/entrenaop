begin;

alter table public.workout_execution_sets
 add column manual_distance_optional boolean not null default false;

-- Cada cita del motor tiene su propia plantilla. El inicio copia los tramos
-- antes de enlazar execution_id en la agenda, por eso se comprueba la plantilla.
create function public.running_v0_manual_time_eligible(p_execution uuid)
returns boolean language sql stable set search_path='' as $$
 select exists (
  select 1 from public.workout_executions e
  join public.scheduled_workouts sw on sw.template_id=e.template_id and sw.user_id=e.user_id
  join public.running_week_sessions rs on rs.scheduled_workout_id=sw.id
  join public.running_week_decisions d on d.id=rs.decision_id
  where e.id=p_execution and sw.source='algorithm' and rs.variant_code='V_0_v1'
   and d.policy_version='running_2k_v6'
 )
$$;

create function public.set_running_v0_manual_time() returns trigger
language plpgsql security definer set search_path='' as $$
begin
 new.manual_distance_optional:=coalesce(new.block_format='running',false)
  and new.target_duration_seconds is not null and new.target_distance_meters is null
  and new.performance_prescription is null and public.running_v0_manual_time_eligible(new.execution_id);
 return new;
end $$;

create trigger set_running_v0_manual_time before insert on public.workout_execution_sets
 for each row execute function public.set_running_v0_manual_time();

update public.workout_execution_sets s set manual_distance_optional=true
where s.block_format='running' and s.target_duration_seconds is not null
 and s.target_distance_meters is null and s.performance_prescription is null
 and public.running_v0_manual_time_eligible(s.execution_id);

alter table public.workout_execution_sets drop constraint workout_execution_sets_running_result_complete;
alter table public.workout_execution_sets add constraint workout_execution_sets_running_result_complete check (
 status<>'completed' or block_format is distinct from 'running'
 or (actual_duration_seconds is not null and actual_distance_meters is not null)
 or (manual_distance_optional and result_source is not distinct from 'manual'
   and coalesce(actual_duration_seconds,0)>0 and target_duration_seconds is not null
   and target_distance_meters is null and performance_prescription is null)
 or coalesce((performance_prescription->>'policy_version'='adaptive_protocol_control_v1'
   and performance_prescription->>'measurement'='TIME_FOR_DISTANCE'
   and performance_prescription->>'protocol_key'='run_2000m_v1'
   and performance_prescription->>'intent'='control' and performance_result is not null),false)
);

create function public.running_evaluate_manual_time_v1(session jsonb, execution jsonb)
returns jsonb language plpgsql immutable set search_path='' as $$
declare
 result jsonb; timed boolean; skipped int; segments jsonb; time_sets jsonb; long_recovery boolean;
begin
 if session->>'variant_code' is distinct from 'V_0_v1'
   or coalesce((session->>'taper')::boolean,false)
   or execution->>'status' is distinct from 'completed' then
  return public.running_evaluate_v2(session,execution);
 end if;
 select count(*) filter(where execution->'sets'->(ord::int-1)->>'status'='skipped'),
  coalesce(bool_or(execution->'sets'->(ord::int-1)->>'status'='completed'
    and execution->'sets'->(ord::int-1)->>'meters' is null),false),
  coalesce(bool_or(execution->'sets'->(ord::int-1)->>'status'='completed'
    and (execution->'sets'->(ord::int-1)->>'recovery_seconds')::numeric>
      (seg->>'recovery_seconds')::numeric*(1+(public.running_policy_v1()->>'recovery_extension')::numeric)),false)
 into skipped,timed,long_recovery
 from jsonb_array_elements(session->'segments') with ordinality s(seg,ord)
 where seg->>'role'='work';
 if timed then
  select jsonb_agg(seg-array['pace_min','pace_max'] order by ord) into segments
  from jsonb_array_elements(session->'segments') with ordinality s(seg,ord);
  select jsonb_agg(s-'meters' order by ord) into time_sets
  from jsonb_array_elements(execution->'sets') with ordinality a(s,ord);
  result:=public.running_evaluate_v2(jsonb_set(session,'{segments}',segments),jsonb_set(execution,'{sets}',time_sets))
    ||jsonb_build_object('pace_seconds_per_km',null,'fade',null,'max_deviation_from_median',null,
      'confidence','time_only');
 else
  result:=public.running_evaluate_v2(session,execution);
 end if;
 -- En una sesión combinada se puede omitir el último tramo, donde se pide
 -- el esfuerzo del bloque. Los tres tramos realizados siguen siendo visibles.
 if timed and skipped=1 and not long_recovery
   and result->>'completed_work'='3' and result->>'expected_work'='4'
   and result->>'missing'='0'
   and ((result->>'reason'='dose_or_effort_not_tolerated' and result->>'effort_review'='false')
     or (result->>'status'='unknown' and result->>'rpe' is null)) then
  return result||'{"status":"partial_time","reason":"one_interval_skipped","objective_difficulty":false}'::jsonb;
 end if;
 if timed and result->>'status'='tolerated' then
  return result||'{"status":"tolerated_time","reason":"duration_recovery_and_effort_tolerated"}'::jsonb;
 end if;
 return result;
end $$;

revoke all on function public.running_v0_manual_time_eligible(uuid),
 public.set_running_v0_manual_time(),public.running_evaluate_manual_time_v1(jsonb,jsonb)
 from public,anon,authenticated;

do $migration$
declare change record; definition text;
begin
 for change in select * from (values
  ('public.complete_workout_set(uuid,integer,integer,numeric,numeric,numeric,numeric,integer,numeric,text)'::regprocedure,
   'if p_actual_duration_seconds is null or p_actual_distance_meters is null then',
   'if p_actual_duration_seconds is null or (p_actual_distance_meters is null and not (prescribed_result.manual_distance_optional and p_result_source=''manual'')) then'),
  ('public.correct_workout_set_result(uuid,text,integer,integer,numeric,numeric,numeric,numeric,integer,numeric,text)'::regprocedure,
   'if p_actual_duration_seconds is null or p_actual_distance_meters is null then',
   'if p_actual_duration_seconds is null or (p_actual_distance_meters is null and not (selected_result.manual_distance_optional and p_result_source=''manual'')) then'),
  ('public.running_evidence_v6(jsonb,date)'::regprocedure,
   $old$signal:=public.running_evaluate_v2(h->'session',h->'execution');$old$,
   $new$signal:=public.running_evaluate_manual_time_v1(h->'session',h->'execution');$new$),
  ('public.running_dose_evidence_v6(jsonb,date,text,integer,numeric,numeric)'::regprocedure,
   $old$original:=public.running_evaluate_v2(h->'session',h->'execution');$old$,
   $new$original:=public.running_evaluate_manual_time_v1(h->'session',h->'execution');
  -- El registro por tiempo conserva la evidencia anterior sin acreditar ritmo.
  if original->>'status' in ('tolerated_time','partial_time') then continue; end if;$new$),
  ('public.running_plan_v6(jsonb)'::regprocedure,
   $old$   elsif n<previous_count then reason:='Faltan registros de la semana: mantener sin asumir que no entrenaste';$old$,
   $new$   elsif bad=0 and exists(select 1 from jsonb_array_elements(obs) o where (o->>'date')::date>=wk-7
     and o->'signal'->>'status' in ('tolerated_time','partial_time')) then
     reason:='Intervalos registrados por tiempo o parcialmente. Se reconoce el trabajo realizado y se consolida la pauta.';
   elsif n<previous_count then reason:='Faltan registros de la semana: mantener sin asumir que no entrenaste';$new$)
 ) as changes(signature,old_sql,new_sql) loop
  definition:=pg_get_functiondef(change.signature);
  if length(definition)-length(replace(definition,change.old_sql,''))<>length(change.old_sql) then
   raise exception 'Revisar el contrato de % para el registro por tiempo.',change.signature;
  end if;
  execute replace(definition,change.old_sql,change.new_sql);
 end loop;
end;
$migration$;

commit;
