"""Compone frecuencia y contexto observado sobre funciones revisadas, sin tocar su historia."""
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
source = (ROOT / 'supabase/migrations/20261016124517_adaptive_evidence_and_shared_budget.sql').read_text(encoding='utf-8-sig')

def function(name):
    match = re.search(r'create or replace function public\.' + name + r'\(.*?end \$\$;', source, re.S)
    assert match, name
    return match[0]

def replace(source, old, new):
    assert source.count(old) == 1, (old, source.count(old))
    return source.replace(old, new)

coordinator = function('calculate_preparation_week_for_scope')
coordinator = replace(coordinator, 'public.performance_task_v3(ref.reference', 'public.performance_task_v4(ref.reference')
coordinator = replace(coordinator, "(case when frequency_limit=0 then public.performance_compact_proposal_v2(p) else p end)||jsonb_build_object('requested_frequency',p->'frequency','frequency',least(greatest(1,frequency_limit),(p->>'frequency')::int))", 'public.performance_frequency_candidate_v1(p,frequency_limit)')
coordinator = replace(coordinator, "   score:=(candidate->>'score')::int;", """   -- Una redistribución a medias no es una pauta: comparar la alternativa completa.
   if exists(select 1 from jsonb_array_elements(candidate->'missing') m
      join jsonb_array_elements(candidates) c on c->>'reference_id'=m->>'reference_id'
      where c->>'outcome'='redistribute') then continue; end if;
   score:=(candidate->>'score')::int;""")
coordinator = replace(coordinator, "'evidence_policy_version','adaptive_evidence_v1'", "'evidence_policy_version','adaptive_evidence_v1','frequency_policy_version','performance_frequency_v1'")
coordinator = replace(coordinator, ' coordinated:=public.performance_coordinate_progression_v2(coordinated,best_running,p_week_start);', """ -- Persistir exposiciones entregadas, no una frecuencia deseada que no cupo.
 select coalesce(jsonb_agg(p||jsonb_build_object('frequency',
   (select count(*) from jsonb_each(best->'days') d,jsonb_array_elements(d.value->'work') w
    where w->>'reference_id'=p->>'reference_id'))),'[]') into coordinated
 from jsonb_array_elements(coordinated) p;
 coordinated:=public.performance_coordinate_progression_v2(coordinated,best_running,p_week_start);""")
coordinator = replace(coordinator, 'Actualiza el cuestionario de carrera y sus cuatro semanas recientes.', 'Confirma tu contexto actual de carrera; recuperamos los entrenamientos que ya has registrado.')

adapter = function('calculate_running_week_constrained')
adapter = replace(adapter, ' if not found or ctx.updated_at', " if not found then raise exception 'Update the current running context'; end if;\n -- Solo cambia la proyección de carga; conserva las fechas de salud y el motor v5.\n ctx:=jsonb_populate_record(ctx,public.running_context_observed_v1(p_goal_id,current_date));\n if ctx.updated_at")

target = Path(sys.argv[1])
assert target.parent.resolve() == (ROOT / 'supabase/migrations').resolve()
assert target.name.endswith('_automatic_performance_frequency.sql')
target.write_text('\n\n'.join(['begin;',
    (ROOT / 'supabase/policies/performance_frequency_v1.sql').read_text(encoding='utf-8'),
    (ROOT / 'supabase/policies/running_observed_context_v1.sql').read_text(encoding='utf-8'),
    adapter, coordinator, 'commit;'])+'\n', encoding='utf-8')
print(target)
