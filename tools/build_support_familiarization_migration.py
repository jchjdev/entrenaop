"""Entrada de apoyos sobre las últimas funciones verificadas; no toca carrera."""
from pathlib import Path
import hashlib
import re
import sys

ROOT = Path(__file__).resolve().parents[1]


def function(file, name):
    source = (ROOT / file).read_text(encoding='utf-8-sig')
    found = re.search(r'create (?:or replace )?function public\.' + name + r'\(.*?as \$\$.*?\$\$;', source, re.S)
    assert found, name
    return re.sub(r'^create (?:or replace )?function', 'create or replace function', found[0])


def replace(source, old, new):
    assert source.count(old) == 1, (old, source.count(old))
    return source.replace(old, new)


coordinator = function('supabase/migrations/20261016152408_strategy_adaptive_frequency.sql',
                       'calculate_preparation_week_for_scope')
coordinator = replace(coordinator, 'and r.active and public.performance_reference_applies',
    "and r.active and coalesce(r.reference->>'reference_kind','')<>'guided_pending'\n    and (not r.reference ? 'automatic_support' or public.performance_support_source_valid_v1(r.reference)) and public.performance_reference_applies")
coordinator = replace(coordinator, ' proposals:=public.performance_select_v4(proposals);',
    " if p_scope<>'running' then proposals:=public.performance_support_candidates_v1(p_goal_id,p_week_start,proposals); end if;\n proposals:=public.performance_select_v4(proposals);")
coordinator = replace(coordinator, "'covered_reference_ids',jsonb_agg(p->'reference_id'),'covered_objective_keys'",
    "'automatic_references',coalesce(jsonb_agg(p->'automatic_reference') filter(where p ? 'automatic_reference'),'[]'),\n     'covered_reference_ids',jsonb_agg(p->'reference_id'),'covered_objective_keys'")
coordinator = replace(coordinator, "'frequency_policy_version','performance_frequency_v2','training_scope'",
    "'frequency_policy_version','performance_frequency_v2','support_policy_version','support_v1','training_scope'")

publisher = function('supabase/migrations/20261006000000_performance_strategies_and_phases.sql',
                     'materialize_preparation_week_scoped')
publisher = replace(publisher, "   for w in select value from jsonb_array_elements(s->'work') loop\n     p:=w->'dose'->'task';",
    "   for w in select value from jsonb_array_elements(s->'work') loop\n     perform public.persist_automatic_support_v1(p_goal_id,w);\n     p:=w->'dose'->'task';")

selector = function('supabase/migrations/20261016152408_strategy_adaptive_frequency.sql', 'performance_select_v4')
selector = replace(selector, "and candidate.p->>'model'='load_repetitions'",
    "and (candidate.p->>'model'='load_repetitions' or candidate.p->>'exercise_code'='split_squat')")

setup = function('supabase/migrations/20261006000000_performance_strategies_and_phases.sql', 'get_preparation_training_setup')
setup = replace(setup, ' setup:=public.get_preparation_training_setup_base(p_goal_id);',
    " setup:=public.get_preparation_training_setup_base(p_goal_id);\n -- Una primera práctica pendiente o un origen corregido no son capacidad acreditada.\n setup:=jsonb_set(setup,'{references}',coalesce((select jsonb_agg(r) from jsonb_array_elements(setup->'references') r\n   where r->'reference'->>'reference_kind' is distinct from 'guided_pending'\n    and (not (r->'reference') ? 'automatic_support' or public.performance_support_source_valid_v1(r->'reference'))),'[]'));" )

valid = function('supabase/migrations/20261016124517_adaptive_evidence_and_shared_budget.sql',
                 'valid_performance_prescription')
valid = replace(valid,
    "if p->>'load_mode' in ('external_load','bodyweight_plus_external') and coalesce((p->>'external_load_kg')::numeric,0) <= 0 then return false; end if;",
    "if p->>'load_mode' in ('external_load','bodyweight_plus_external')\n    and ((p->>'external_load_kg' is null and not public.is_support_familiarization_v1(p))\n      or (p->>'external_load_kg')::numeric<=0) then return false; end if;")
valid = replace(valid,
    "if p->>'load_mode' = 'bodyweight_plus_external' and coalesce((p->>'body_mass_kg')::numeric,0) <= 0 then return false; end if;",
    "if p->>'load_mode' = 'bodyweight_plus_external'\n    and ((p->>'body_mass_kg' is null and not public.is_support_familiarization_v1(p))\n      or (p->>'body_mass_kg')::numeric<=0) then return false; end if;")

cost = function('supabase/policies/performance_v2.sql', 'performance_work_seconds_v2')
cost = replace(cost, 'begin\n select sum(case',
    "begin\n if public.is_support_familiarization_v1(dose->'task') then return 360; end if;\n select sum(case")

parts = ["begin;", (ROOT / 'supabase/policies/performance_support_v1.sql').read_text(encoding='utf-8'),
         valid, cost, selector, coordinator, publisher, setup, "commit;"]
target = ROOT / sys.argv[1]
assert target.exists(), 'Crear primero con supabase migration new'
target.write_text('\n\n'.join(parts) + '\n', encoding='utf-8')
print(target)

# Contrastar lo instalado también protege de redefiniciones accidentales de
# carrera; normalizamos únicamente los finales de línea del transporte CLI.
source = target.read_text(encoding='utf-8')
for later in sorted((ROOT / 'supabase/migrations').glob('*.sql')):
    if later.name > target.name:
        source += '\n' + later.read_text(encoding='utf-8-sig')
source += '\n' + (ROOT / 'supabase/migrations/20261001012000_running_engine_easy_volume_v5.sql').read_text(encoding='utf-8-sig')
digests = {}
wanted = set(re.findall(r'function public\.(\w+)\(', target.read_text(encoding='utf-8')))
for match in re.finditer(r'create (?:or replace )?function public\.(\w+)\(.*?as \$\$(.*?)\$\$;', source, re.S):
    if match[1] == 'running_plan_v5' or match[1] in wanted:
        digests[match[1]] = hashlib.md5(match[2].replace('\r', '').encode()).hexdigest()
values = ',\n'.join(f"('{name}','{digest}')" for name, digest in digests.items())
audit = f"""do $$ declare mismatch text; begin
 select string_agg(expected.name,', ') into mismatch from (values {values}) expected(name,digest)
 left join pg_proc p on p.proname=expected.name and p.pronamespace='public'::regnamespace
 where p.oid is null or md5(replace(p.prosrc,chr(13),''))<>expected.digest;
 if mismatch is not null then raise exception 'Definiciones instaladas distintas: %',mismatch; end if;
end $$;
select '{len(digests)} definiciones instaladas coincidentes, incluida carrera v5 original' result;
"""
audit_target = ROOT / 'build/support-installed-policy-audit.sql'
audit_target.parent.mkdir(parents=True, exist_ok=True)
audit_target.write_text(audit, encoding='utf-8')
