"""Integra el módulo de controles sin cambiar el motor ni catálogo de carrera."""
from pathlib import Path
import re
import sys

ROOT=Path(__file__).resolve().parents[1]

def definition(path,name):
    s=(ROOT/path).read_text(encoding='utf-8-sig')
    match=re.search(r'create (?:or replace )?function public\.'+name+r'\(.*?as \$\$.*?\$\$;',s,re.S)
    assert match,name
    return re.sub(r'^create (?:or replace )?function','create or replace function',match[0])

def change(s,a,b):
    assert s.count(a)==1,(a[:100],s.count(a))
    return s.replace(a,b)

previous='supabase/migrations/20261016182512_adaptive_movement_continuity.sql'
baseline=definition(previous,'calculate_preparation_week_for_scope').replace(
    'function public.calculate_preparation_week_for_scope(', 'function public.calculate_preparation_week_training_v4(')
baseline=change(baseline,'where pw.reference_id=ref.id and public.workout_performed_on_v1(e)<p_week_start',
 'where pw.reference_id=ref.id and not pw.dose ? \'control\' and public.workout_performed_on_v1(e)<p_week_start')
coordinator='''create or replace function public.calculate_preparation_week_for_scope(
 p_goal_id uuid,p_week_start date,p_revision boolean,p_scope text,p_excluded uuid[]) returns jsonb
language plpgsql security definer set search_path='' as $$
declare plan jsonb;
begin
 plan:=public.calculate_preparation_week_training_v4(p_goal_id,p_week_start,p_revision,p_scope,p_excluded);
 return public.apply_adaptive_protocol_controls_v1(p_goal_id,p_week_start,plan);
end $$;'''
materialize=definition('supabase/migrations/20261004001000_preparation_week_revisions.sql','materialize_running_week_plan')
materialize=change(materialize,'recovery_type,recovery_duration_seconds)', 'recovery_type,recovery_duration_seconds,performance_prescription)')
materialize=change(materialize,"end,(segment->>'recovery_seconds')::integer);", "end,(segment->>'recovery_seconds')::integer,segment->'performance_prescription');")
advance=definition('supabase/migrations/20261010000000_pro_access_and_free_quotas.sql','advance_adaptive_program')
advance=change(advance,' select * into a from public.adaptive_program_states',
  ' perform public.sync_automatic_running_controls_v1(p_goal_id);\n select * into a from public.adaptive_program_states')
running=definition(previous,'calculate_running_week_constrained')
running=change(running,'if age>30 and age<=45 and (ref.continuity_confirmed_at is null',
 'if age>30 and age<=45 and not public.running_continuity_observed_v1(p_goal_id,current_date) and (ref.continuity_confirmed_at is null')
running=change(running,"and coalesce(public.workout_performed_on_v1(e),sw.scheduled_date)>=p_week_start-56", "and not coalesce(rs.prescription,'{}'::jsonb) ? 'control'\n   and coalesce(public.workout_performed_on_v1(e),sw.scheduled_date)>=p_week_start-56")
resolve=definition('supabase/migrations/20261004007000_common_running_controls.sql','resolve_program_running_reference')
resolve=change(resolve," if r.completed_at is null or r.seconds is null", """ if sel.reference_source='trainingControl' and exists(
  select 1 from public.preparation_running_tests t left join public.workout_execution_sets es on es.id=t.source_execution_set_id
  where t.id::text=sel.reference_record_id and t.source_execution_set_id is not null
   and (es.status<>'completed' or not public.adaptive_control_result_valid_v1(es.performance_prescription,es.performance_result))) then
  raise exception 'Choose a compatible 2 km mark: the automatic control was corrected or invalidated';
 end if;
 if r.completed_at is null or r.seconds is null""")
reviews=definition(previous,'performance_goal_reviews_v1')
reviews=change(reviews,' fresh boolean; met boolean;', ' fresh boolean; met boolean; automatic jsonb;')
reviews=change(reviews,'  fresh:=mark is not null', """  select value into automatic from jsonb_array_elements(public.adaptive_protocol_observations_v1(goal))
   where value->>'objective_key'=item.key and value->>'measurement'=item.value->>'measurement'
    and (value->>'observed_on')::date<=least(wk+6,current_date) order by value->>'observed_on' desc limit 1;
  if automatic is not null and (measured is null or (automatic->>'observed_on')::date>=measured) then
   mark:=(automatic->>'value')::numeric; measured:=(automatic->>'observed_on')::date; source_id:=automatic->>'id';
  else automatic:=null; end if;
  fresh:=mark is not null""")
reviews=change(reviews,"'control_kind','submaximal_work','updates','work_capacity_only',", "'control_kind','adaptive_protocol','updates','training_protocol_mark','official_assessment',false,\n   'lower_bound',coalesce((automatic->>'lower_bound')::boolean,false),")
reviews=change(reviews,"and r.reference->'task'->>'measurement'='REPS_IN_TIME') then", "and r.reference->'task'->>'measurement'='REPS_IN_TIME') and automatic is null then")
snapshot=definition('supabase/migrations/20261003004000_performance_execution_contract.sql','snapshot_performance_set')
snapshot=change(snapshot,"    new.actual_rir := (new.performance_result->>'rir')::numeric;", """    new.actual_rir := (new.performance_result->>'rir')::numeric;
    if new.performance_prescription->>'policy_version'='adaptive_protocol_control_v1'
      and new.performance_prescription->>'measurement'='TIME_FOR_DISTANCE' then
     -- Solo una confirmación explícita del protocolo acredita la distancia fija.
     -- Un intento parcial/nulo conserva sus datos sin fabricar los 2 km.
     new.actual_distance_meters:=case when new.performance_result->>'conditions_confirmed'='true'
      then (new.performance_prescription->>'fixed_distance_meters')::numeric end;
     new.actual_rpe:=(new.performance_result->>'rpe')::numeric;
    end if;""")

target=ROOT/sys.argv[1]
assert target.exists(),'Crear antes mediante supabase migration new'
target.write_text('\n\n'.join(['begin;',
 (ROOT/'supabase/policies/adaptive_protocol_controls_v1.sql').read_text(encoding='utf8'),
 baseline,coordinator,materialize,advance,running,resolve,reviews,snapshot,
 """alter table public.workout_execution_sets drop constraint workout_execution_sets_running_result_complete;
alter table public.workout_execution_sets add constraint workout_execution_sets_running_result_complete check (
 status<>'completed' or block_format is distinct from 'running'
 or (actual_duration_seconds is not null and actual_distance_meters is not null)
 or coalesce((performance_prescription->>'policy_version'='adaptive_protocol_control_v1'
   and performance_prescription->>'measurement'='TIME_FOR_DISTANCE'
   and performance_prescription->>'protocol_key'='run_2000m_v1'
   and performance_prescription->>'intent'='control' and performance_result is not null),false)
);""",
 'revoke all on function public.calculate_preparation_week_training_v4(uuid,date,boolean,text,uuid[]) from public,anon,authenticated;',
 'commit;'])+'\n',encoding='utf8')
print(target)
