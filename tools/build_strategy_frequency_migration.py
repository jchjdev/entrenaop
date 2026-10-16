"""Amplía la frecuencia sobre las últimas definiciones verificadas, sin reescribirlas."""
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]

def function(file, name):
    source = (ROOT / file).read_text(encoding='utf-8-sig')
    m = re.search(r'create (?:or replace )?function public\.' + name + r'\(.*?as \$\$.*?\$\$;', source, re.S)
    assert m, name
    return re.sub(r'^create (?:or replace )?function', 'create or replace function', m[0])

def replace(source, old, new):
    assert source.count(old) == 1, (old, source.count(old))
    return source.replace(old, new)

place = function('supabase/migrations/20261006000000_performance_strategies_and_phases.sql', 'performance_place_v3')
place = replace(place, 'public.performance_place_v3(', 'public.performance_place_v4(')
place = replace(place, ' p jsonb; day jsonb;', ' p jsonb; root jsonb; day jsonb;')
place = replace(place, ' for rounds in 1..2 loop', " for rounds in 1..coalesce((select max((q->>'frequency')::int) from jsonb_array_elements(proposals) q where q->>'status'='ready'),0) loop")
place = place.replace(' for p in select value', ' for root in select value', 1)
place = replace(place, "  wanted:=(p->>'frequency')::int;", "  p:=public.performance_exposure_v2(root,rounds-1);\n  wanted:=(p->>'frequency')::int;")
place = replace(place, 'abs(ad-d)<=1 or abs(ad-d)=6', "abs(ad-d)<coalesce((p->>'recovery_days')::int,2)")
place = replace(place, "if abs((old->>'day')::int-d)=1 and", "if (old->>'day')::int<>d and abs((old->>'day')::int-d)<greatest(coalesce((p->>'recovery_days')::int,2),coalesce((old->>'recovery_days')::int,2)) and")
place = replace(place, "cost:=(p->>'work_minutes')::int", "cost:=coalesce((p->>'reservation_minutes')::int,(p->>'work_minutes')::int)")
place = replace(place, "'body_regions',p->'body_regions'))", "'body_regions',p->'body_regions','recovery_days',p->'recovery_days'))")
place = replace(place, "p->>'objective_key'=q->>'objective_key'", "(p->>'objective_key'=q->>'objective_key' or p->'covered_objective_keys' ? (q->>'objective_key') or q->'covered_objective_keys' ? (p->>'objective_key'))")
place = replace(place, "else 'Se pauta una exposición: la segunda no cabe respetando tiempo y recuperación.'", "else 'Se pautan '||assigned||' exposiciones; las demás no caben respetando tiempo y recuperación.'")
place += '\nrevoke all on function public.performance_place_v4(jsonb,jsonb,jsonb,jsonb,int,date,date) from public,anon,authenticated;'

select = function('supabase/policies/performance_strategy_v3.sql', 'performance_select_v3')
select = replace(select, 'public.performance_select_v3(', 'public.performance_select_v4(')
select = replace(select, "'frequency',case when n>1 then 1 else (p->>'frequency')::int end", "'frequency',(p->>'frequency')::int")
# Dentro de EXISTS, p sin calificar resolvía main.p y descartaba el apoyo real.
start = select.index('), selected as (')
end = select.index('  union all select p', start)
selected = select[start:end].replace('from ranked where', 'from ranked candidate where')
selected = re.sub(r'(?<![\w.])p(?=\s*(?:->|\|\|))', 'candidate.p', selected)
select = select[:start] + selected + select[end:]
select += '\nrevoke all on function public.performance_select_v4(jsonb) from public,anon,authenticated;'

save_reference = function('supabase/migrations/20261006000000_performance_strategies_and_phases.sql', 'save_performance_reference')
save_reference = replace(save_reference, 'q.goal_code=goal_code', "q.goal_code=(p_reference->>'goal_code')")
save_reference = replace(save_reference, "(p_reference->>'frequency')::int not between 1 and 2", "(p_reference->>'frequency')::int not between 1 and 7")
save_reference = replace(save_reference, 'Confirma descansos y frecuencia actual, de una o dos exposiciones.', 'Confirma los descansos y las sesiones por semana que ya toleras, entre una y siete.')

coordinator = function('supabase/migrations/20261016145005_automatic_performance_frequency.sql','calculate_preparation_week_for_scope')
coordinator = replace(coordinator, 'public.performance_task_v4(', 'public.performance_task_v5(')
coordinator = replace(coordinator, 'public.performance_select_v3(', 'public.performance_select_v4(')
coordinator = replace(coordinator, 'public.performance_frequency_candidate_v1(', 'public.performance_frequency_candidate_v2(')
coordinator = replace(coordinator, 'public.performance_place_v3(', 'public.performance_place_v4(')
coordinator = replace(coordinator, 'for frequency_limit in reverse 2..0 loop', "for frequency_limit in reverse coalesce((select max((p->>'frequency')::int) from jsonb_array_elements(proposals) p where p->>'status'='ready'),1)..0 loop")
coordinator = replace(coordinator, 'group by p->\'dose\'', "group by p->'dose',p->'exposure_doses',p->'frequency'")
coordinator = replace(coordinator, "'covered_reference_ids',jsonb_agg(p->'reference_id')", "'covered_reference_ids',jsonb_agg(p->'reference_id'),'covered_objective_keys',jsonb_agg(p->'objective_key')")
coordinator = replace(coordinator, "q->>'objective_key'=p->>'objective_key'\n   and (case", "(q->>'objective_key'=p->>'objective_key' or q->'covered_objective_keys' ? (p->>'objective_key') or p->'covered_objective_keys' ? (q->>'objective_key'))\n   and (case")
coordinator = replace(coordinator, "'body_regions',coalesce(ep.definition->'body_regions','[\"upper_body\",\"lower_body\",\"trunk\"]'))", """'body_regions',coalesce(ep.definition->'body_regions','["upper_body","lower_body","trunk"]'),
   'recovery_days',coalesce((select max((public.performance_frequency_strategy_v2(jsonb_build_object('dose',pw.dose))->>'recovery_days')::int)
     from public.performance_week_work pw where pw.scheduled_workout_id=sw.id),2))""")
coordinator = coordinator.replace('between p_week_start-1 and p_week_start+7', 'between p_week_start-7 and p_week_start+13')
coordinator = replace(coordinator, "from (select distinct w from jsonb_each(best->'days') d, jsonb_array_elements(d.value->'work') w) chosen", "from (select distinct on (w->>'reference_id') w from jsonb_each(best->'days') d, jsonb_array_elements(d.value->'work') w order by w->>'reference_id',(w->>'exposure_index')::int) chosen")
coordinator = replace(coordinator, "where w->>'reference_id'=p->>'reference_id')))", """where w->>'reference_id'=p->>'reference_id'),
   'exposure_doses',(select jsonb_agg(w->'dose' order by (w->>'exposure_index')::int) from jsonb_each(best->'days') d,
     jsonb_array_elements(d.value->'work') w where w->>'reference_id'=p->>'reference_id')))
""".rstrip())
coordinator = replace(coordinator, ' coordinated:=public.performance_coordinate_progression_v2(coordinated,best_running,p_week_start);', """ coordinated:=public.performance_coordinate_progression_v2(coordinated,best_running,p_week_start);
 select coalesce(jsonb_agg(public.performance_reconcile_exposures_v2(p)),'[]') into coordinated from jsonb_array_elements(coordinated) p;""")
coordinator = replace(coordinator, "join lateral(select value c from jsonb_array_elements(coordinated) c where c->>'reference_id'=w.value->>'reference_id')", "join lateral(select public.performance_exposure_v2(value,coalesce((w.value->>'exposure_index')::int,0)) c from jsonb_array_elements(coordinated) c where c->>'reference_id'=w.value->>'reference_id')")
coordinator = replace(coordinator, "'frequency_policy_version','performance_frequency_v1'", "'frequency_policy_version','performance_frequency_v2'")

target = Path(sys.argv[1])
assert target.parent.resolve() == (ROOT / 'supabase/migrations').resolve()
assert target.name.endswith('_strategy_adaptive_frequency.sql')
target.write_text('\n\n'.join(['begin;', (ROOT/'supabase/policies/performance_frequency_v2.sql').read_text(encoding='utf-8'), save_reference, select, place, coordinator, 'commit;'])+'\n', encoding='utf-8')
print(target)
