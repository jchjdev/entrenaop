"""Genera correcciones localizadas desde las últimas definiciones verificadas."""
from pathlib import Path
import hashlib
import re
import sys

ROOT=Path(__file__).resolve().parents[1]


def function(path,name):
    source=(ROOT/path).read_text(encoding='utf-8-sig')
    found=re.search(r'create (?:or replace )?function public\.'+name+r'\(.*?as \$\$.*?\$\$;',source,re.S)
    assert found,name
    return re.sub(r'^create (?:or replace )?function','create or replace function',found[0])


def replace(source,old,new):
    assert source.count(old)==1,(old[:100],source.count(old))
    return source.replace(old,new)


core=function('supabase/migrations/20261016124517_adaptive_evidence_and_shared_budget.sql','performance_task_v3_core')
core=replace(core," dynamic boolean; power boolean:"," phase_bridge boolean:=false; dynamic boolean; power boolean:")
core=replace(core,' baseline:=dose; targets:=dose->\'targets\'; task:=dose->\'task\';',"""
 -- Cambiar el énfasis conservando gesto, protocolo, apoyos y esfuerzo no borra
 -- capacidad acreditada. El descanso nuevo es igual o mayor; no se transfiere
 -- esta dosis a otra variante ni se progresa el mismo día de la transición.
 if model='isometric' and phase='specific' and previous->>'phase'='development'
  and previous->>'reference_id'=reference->>'id'
  and public.performance_same_isometric_work_v1(dose->'task',previous->'dose'->'task')
  and (dose->>'rest_seconds')::int>=(previous->'dose'->>'rest_seconds')::int
  and last_on>=wk-14 and public.performance_exposure_signal_v2(
   (select h from jsonb_array_elements(history) h order by h->>'completed_on' desc limit 1),previous->'dose') in ('tolerated','difficulty') then
  phase_bridge:=true;
  dose:=dose||jsonb_build_object('targets',previous->'dose'->'targets',
   'task',(dose->'task')||jsonb_build_object('target_value',previous->'dose'->'targets'->0));
  selection_reason:=selection_reason||' Conservamos el trabajo reciente: el cambio de fase no reinicia la referencia.';
 end if;
 baseline:=dose; targets:=dose->'targets'; task:=dose->'task';""")
core=replace(core,"  signal:=public.performance_exposure_signal_v2(e,dose);", """  signal:=public.performance_exposure_signal_v2(e,dose);
  if phase_bridge and public.performance_same_isometric_work_v1(e->'dose'->'task',dose->'task')
    and (e->'dose'->>'rest_seconds')::int<=(dose->>'rest_seconds')::int then
   -- Una dificultad real no desaparece al cambiar de etiqueta. La tolerancia
   -- anterior conserva dosis, pero no acredita una subida con el nuevo énfasis.
   signal:=case public.performance_exposure_signal_v2(e,e->'dose')
    when 'difficulty' then 'difficulty' when 'pain' then 'pain' else 'different_dose' end;
  end if;""")

freq=function('supabase/migrations/20261016152408_strategy_adaptive_frequency.sql','performance_task_v5')
freq=replace(freq," changed:=previous->'dose' is not null and", " changed:=previous->'dose' is not null\n  and not (public.performance_same_isometric_work_v1(previous->'dose'->'task',baseline->'task')\n    and (baseline->>'rest_seconds')::int>=(previous->'dose'->>'rest_seconds')::int) and")

coordinator=function('supabase/migrations/20261016170709_automatic_support_familiarization.sql','calculate_preparation_week_for_scope')
coordinator=replace(coordinator,"and r.active and coalesce(r.reference->>'reference_kind','')<>'guided_pending'", "and r.active and not (r.target_profile_code='front_plank_forearms' and r.reference->'task'->>'exercise_code'='dead_bug')\n    and coalesce(r.reference->>'reference_kind','')<>'guided_pending'")
coordinator=coordinator.replace('performance_support_source_valid_v1','performance_support_source_valid_v2').replace('performance_support_candidates_v1','performance_support_candidates_v2')
coordinator=replace(coordinator,'performance_coordinate_progression_v2(coordinated,best_running,p_week_start)','performance_coordinate_progression_v3(coordinated,best_running,p_week_start)')
coordinator=replace(coordinator,"'policy_version','preparation_coordinator_v3'","'policy_version','preparation_coordinator_v4'")
coordinator=replace(coordinator,"'support_policy_version','support_v1'","'support_policy_version','support_v2'")
coordinator=replace(coordinator," proposals:=public.performance_select_v4(proposals);", """
 select coalesce(jsonb_agg(p||jsonb_build_object('goal_review',review,'goal_priority',coalesce((review->>'priority')::int,1))),'[]')
  into proposals from jsonb_array_elements(proposals) p left join lateral(
   select value review from jsonb_array_elements(public.performance_goal_reviews_v1(p_goal_id,p_week_start))
    where value->>'objective_key'=p->>'objective_key') r on true;
 proposals:=public.performance_select_v4(proposals);""")
coordinator=replace(coordinator,"'covered_reference_ids',jsonb_agg(p->'reference_id')", "'goal_priority',min(coalesce((p->>'goal_priority')::int,1)),\n     'covered_reference_ids',jsonb_agg(p->'reference_id')")
coordinator=replace(coordinator,"'program_path',public.performance_program_path_v3", "'goal_reviews',case when p_scope='running' then '[]'::jsonb else public.performance_goal_reviews_v1(p_goal_id,p_week_start) end,'program_path',public.performance_program_path_v3")

selector=function('supabase/migrations/20261016170709_automatic_support_familiarization.sql','performance_select_v4')
selector=selector.replace("candidate.p->>'exercise_code'='dead_bug'","candidate.p->>'exercise_code'='front_plank_high'")
placement=function('supabase/migrations/20261016152408_strategy_adaptive_frequency.sql','performance_place_v4')
placement=replace(placement,"   value->>'objective_key',value->>'reference_id' loop", "   coalesce((value->>'goal_priority')::int,1),value->>'objective_key',value->>'reference_id' loop")

running=function('supabase/migrations/20261016145005_automatic_performance_frequency.sql','calculate_running_week_constrained')
running=replace(running,' input jsonb; result jsonb; previous jsonb;', ' input jsonb; result jsonb; previous jsonb; capacity_evidence jsonb;')
running=replace(running,"   'recent_minutes',ctx.running_minutes_last_four_weeks,'declared_prior_quality_weeks',ctx.quality_weeks_last_four,'capacity_minutes',ctx.comfortable_continuous_minutes,", "   'recent_minutes',ctx.running_minutes_last_four_weeks,'declared_prior_quality_weeks',ctx.quality_weeks_last_four,\n   'capacity_minutes',capacity_evidence->'trial_minutes','capacity_evidence',capacity_evidence,")
running=replace(running," input:=jsonb_build_object("," capacity_evidence:=public.running_capacity_observed_v1(p_goal_id,p_week_start);\n input:=jsonb_build_object(")
running=replace(running," return result||jsonb_build_object("," return result||jsonb_build_object('capacity_evidence',capacity_evidence,")

support=function('supabase/policies/performance_support_v1.sql','performance_support_candidates_v1')
support=support.replace('function public.performance_support_candidates_v1','function public.performance_support_candidates_v2')
support=support.replace('performance_support_recipes_v1()','performance_support_recipes_v2()').replace('performance_support_observed_v1(','performance_support_observed_v2(')
support=replace(support,"'policy_version','support_familiarization_v1','target_value',8,'effort_mode','rir','target_rir',3,\n    'stimulus_code','SUPPORT-F01','instructions',recipe->>'instructions');", """'policy_version',case when recipe->>'measurement'='DURATION' then 'support_familiarization_v2' else 'support_familiarization_v1' end,
    'target_value',case when recipe->>'measurement'='DURATION' then 15 else 8 end,
    'effort_mode',case when recipe->>'measurement'='DURATION' then 'rpe' else 'rir' end,
    'stimulus_code',case when recipe->>'measurement'='DURATION' then 'SUPPORT-ISO-F01' else 'SUPPORT-F01' end,
    'instructions',recipe->>'instructions');
  if recipe->>'measurement'='DURATION' then
   task:=task||jsonb_build_object('protocol_key','support_work_v2:'||(recipe->>'work'),
    'setup_key','standard:support_v2:'||(recipe->>'work'),'target_rpe',6);
  else task:=task||'{"target_rir":3}'::jsonb; end if;""")
support=replace(support,"'reported_rir',observed->'result'->'rir','rest_seconds',0", "'reported_rir',observed->'result'->'rir','reported_rpe',observed->'result'->'rpe','rest_seconds',0")
support=replace(support,"'targets','[8]'::jsonb", "'targets',jsonb_build_array(task->'target_value')")
support=replace(support,"then 'load_repetitions' else 'repetitions' end,'stimulus_code','SUPPORT-F01'", "then 'load_repetitions' when recipe->>'measurement'='DURATION' then 'isometric' else 'repetitions' end,'stimulus_code',task->>'stimulus_code'")
support=replace(support,"'body_regions',profile->'body_regions'", "'body_regions',case when recipe->>'work'='front_plank_high' then profile->'body_regions'||'\"upper_body\"'::jsonb else profile->'body_regions' end")
support=replace(support,"and pw.dose->'task'->>'policy_version'='support_familiarization_v1'", "and pw.dose->'task'->>'policy_version' in ('support_familiarization_v1','support_familiarization_v2')")

persist=function('supabase/policies/performance_support_v1.sql','persist_automatic_support_v1')
persist=persist.replace('performance_support_recipes_v1()','performance_support_recipes_v2()')
setup=function('supabase/migrations/20261016170709_automatic_support_familiarization.sql','get_preparation_training_setup')
setup=setup.replace('performance_support_source_valid_v1','performance_support_source_valid_v2')
calibration=function('supabase/policies/performance_strategy_v3.sql','performance_calibration_options_v3')
calibration=calibration.replace("rel.work_code='dead_bug'","rel.work_code='front_plank_high'")
cost=function('supabase/migrations/20261016170709_automatic_support_familiarization.sql','performance_work_seconds_v2')
cost=replace(cost,"if public.is_support_familiarization_v1(dose->'task') then", "if public.is_support_familiarization_v1(dose->'task') or public.is_support_familiarization_v2(dose->'task') then")

parts=['begin;', (ROOT/'supabase/policies/adaptive_movement_continuity_v1.sql').read_text(encoding='utf-8'),
 "insert into public.performance_exercise_relations(policy_version,goal_code,work_code,role,rationale) values ('performance_v1','front_plank_forearms','front_plank_high','support','Apoyo isométrico con manos y referencia propia; no convertir sus segundos en plancha de antebrazos.') on conflict do nothing;",
 core,freq,selector,placement,support,persist,cost,running,coordinator,setup,calibration,
 'revoke all on function public.performance_support_candidates_v2(uuid,date,jsonb) from public,anon,authenticated;',
 'commit;']
target=ROOT/sys.argv[1]
assert target.exists(),'Crear antes con supabase migration new'
target.write_text('\n\n'.join(parts)+'\n',encoding='utf-8')
print(target)

source=target.read_text(encoding='utf-8')+'\n'+function('supabase/migrations/20261001012000_running_engine_easy_volume_v5.sql','running_plan_v5')
digests={m[1]:hashlib.md5(m[2].replace('\r','').encode()).hexdigest() for m in re.finditer(
 r'create (?:or replace )?function public\.(\w+)\(.*?as \$\$(.*?)\$\$;',source,re.S)}
values=',\n'.join(f"('{name}','{digest}')" for name,digest in digests.items())
audit=f"""do $$ declare mismatch text; begin
 select string_agg(expected.name,', ') into mismatch from (values {values}) expected(name,digest)
 left join pg_proc p on p.proname=expected.name and p.pronamespace='public'::regnamespace
 where p.oid is null or md5(replace(p.prosrc,chr(13),''))<>expected.digest;
 if mismatch is not null then raise exception 'Definiciones distintas: %',mismatch; end if;
end $$;
select '{len(digests)} definiciones instaladas coincidentes, incluida carrera v5 original' result;
"""
(ROOT/'build/movement-installed-audit.sql').write_text(audit,encoding='utf-8')
