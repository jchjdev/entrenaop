"""Compone la reparación desde las últimas definiciones, sin tocar migraciones históricas.

Uso: python tools/build_adaptive_evidence_migration.py <migración creada por CLI>
Las sustituciones comprobadas fallan si cambia la fuente revisada.
"""
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]


def function(file, name):
    source = (ROOT / 'supabase/migrations' / file).read_text(encoding='utf-8-sig')
    match = re.search(r'create (?:or replace )?function public\.' + name + r'\(.*?end(?:;\s*| )\$\$;', source, re.S)
    if not match:
        raise ValueError(name)
    return re.sub(r'^create (?:or replace )?function', 'create or replace function', match[0])


def replace(source, old, new, count=1):
    assert source.count(old) == count, (old, source.count(old))
    return source.replace(old, new)


running = function('20261001008000_running_engine_response_v2.sql', 'running_evaluate_v2')
running = replace(running, "   if (seg ? 'meters'", "   -- La carga realizada cuenta aunque no complete la dosis prescrita.\n   total_seconds := total_seconds+(actual->>'seconds')::numeric;\n   total_meters := total_meters+coalesce((actual->>'meters')::numeric,0);\n   if (seg ? 'meters'")
running = replace(running, "   complete := complete+1;\n   total_seconds := total_seconds+(actual->>'seconds')::numeric;\n   total_meters := total_meters+coalesce((actual->>'meters')::numeric,0);", "   complete := complete+1;")
running = replace(running, " if p_execution->>'abandonment_reason' = 'too_difficult' then", " if p_execution->>'abandonment_reason' = 'lack_of_time' then\n   status := 'time'; reason := 'interrupted_lack_of_time';\n elsif p_execution->>'abandonment_reason' = 'too_difficult' then")
running = replace(running, "'objective_difficulty',complete<expected", "'objective_difficulty',status<>'time' and (complete<expected")
running = replace(running, "coalesce(variability,0)>0.08),", "coalesce(variability,0)>0.08)),")

validator = function('20261004003000_performance_stimulus_bank_v2.sql', 'valid_performance_prescription')
validator = replace(validator, "p->>'effort_mode'='rir' and (m not in ('REPS','LOAD_REPS')", "p->>'effort_mode'='rir' and (m not in ('REPS','LOAD_REPS','REPS_IN_TIME')")

core = function('20261006000000_performance_strategies_and_phases.sql', 'performance_task_v3_core')
core = replace(core, "if capacity<3 then return", "if capacity<3 or (kind in ('capacity_test','official_test') and capacity-v<3) then return")

abandon = function('20260920008000_workout_abandonment.sql', 'abandon_workout_execution')
abandon = replace(abandon, "    abandonment_reason = p_reason", "    abandonment_reason = p_reason,\n    abandoned_block_order = (select s.block_order from public.workout_execution_sets s\n      where s.execution_id=execution.id and s.status='pending'\n        and s.block_format not in ('warm_up','cool_down')\n      order by s.block_order,s.item_order,s.set_order limit 1)")

adapter = function('20261004012000_program_pause_and_training_scope.sql', 'calculate_running_week_constrained')
adapter = replace(adapter, "return result||jsonb_build_object('goal_id'", "return result||jsonb_build_object('evidence_policy_version','adaptive_evidence_v1','goal_id'")
adapter = replace(adapter, '-- La política deportiva v5 y su historial permanecen intactos.', '-- La selección deportiva sigue en v5; la evidencia usa la realización real.')
adapter = replace(adapter, "'date',sw.scheduled_date", "'date',coalesce(public.workout_performed_on_v1(e),sw.scheduled_date),'scheduled_date',sw.scheduled_date")
adapter = replace(adapter, "'status',sw.status", "'status',coalesce(public.workout_block_outcome_v1(e.id)->>'status',sw.status)")
adapter = replace(adapter, "'abandonment_reason',e.abandonment_reason", "'abandonment_reason',public.workout_block_outcome_v1(e.id)->>'abandonment_reason'")
adapter = replace(adapter, "order by sw.scheduled_date),'[]') into history", "order by coalesce(public.workout_performed_on_v1(e),sw.scheduled_date),e.id),'[]') into history")
adapter = replace(adapter, "and wd.week_start>=p_week_start-56\n   and wd.week_start<p_week_start", "and coalesce(public.workout_performed_on_v1(e),sw.scheduled_date)>=p_week_start-56\n   and coalesce(public.workout_performed_on_v1(e),sw.scheduled_date)<p_week_start")
# Reservas y recuperación utilizan el mismo día que la evidencia, no la cita
# original de una sesión que el deportista haya hecho otro día.
adapter = replace(adapter, 'extract(isodow from scheduled_date)', 'extract(isodow from public.workout_load_on_v1(scheduled_workouts))')
adapter = replace(adapter, 'scheduled_date between p_week_start and p_week_start+6', 'public.workout_load_on_v1(scheduled_workouts) between p_week_start and p_week_start+6')
adapter = replace(adapter, 'sw.scheduled_date-p_week_start+1', 'public.workout_load_on_v1(sw)-p_week_start+1')
adapter = replace(adapter, 'sw.scheduled_date between p_week_start-1 and p_week_start+7', 'public.workout_load_on_v1(sw) between p_week_start-1 and p_week_start+7')

coordinator = function('20261006000000_performance_strategies_and_phases.sql', 'calculate_preparation_week_for_scope')
coordinator = replace(coordinator, 'running_error text; best_error text;', "running_cache jsonb:='{}'; running_constraints jsonb; cache_key text; running_error text; best_error text;")
coordinator = replace(coordinator, 'rotation int; score int;', 'shared_credit int; rotation int; score int;')
coordinator = replace(coordinator, '   running:=null; running_error:=null;', '   -- Ensayar reservas sin ahorro, con activación compartida y con cierre.\n   -- Cada alternativa pasa el coste exacto antes de puntuar.\n   for shared_credit in select unnest(array[0,4,7]) loop\n   running:=null; running_error:=null;')
coordinator = replace(coordinator, ' -- El trabajo descartado no consume', ' end loop;\n -- El trabajo descartado no consume')
coordinator = replace(coordinator, "'completed_on',e.completed_at::date", "'completed_on',public.workout_performed_on_v1(e),'scheduled_date',sw.scheduled_date")
coordinator = replace(coordinator, "'status',e.status,'abandonment_reason',e.abandonment_reason", "'status',public.workout_block_outcome_v1(e.id,pw.block_order)->>'status',\n     'abandonment_reason',public.workout_block_outcome_v1(e.id,pw.block_order)->>'abandonment_reason'")
coordinator = replace(coordinator, "order by e.completed_at),'[]') into history", "order by coalesce(e.performed_at,e.completed_at),e.id),'[]') into history")
coordinator = replace(coordinator, "e.completed_at::date<p_week_start and e.completed_at::date>=p_week_start-56", "public.workout_performed_on_v1(e)<p_week_start and public.workout_performed_on_v1(e)>=p_week_start-56")
coordinator = replace(coordinator, 'extract(isodow from scheduled_date)', 'extract(isodow from public.workout_load_on_v1(scheduled_workouts))')
coordinator = replace(coordinator, 'scheduled_date between p_week_start and p_week_start+6', 'public.workout_load_on_v1(scheduled_workouts) between p_week_start and p_week_start+6')
coordinator = replace(coordinator, 'sw.scheduled_date-p_week_start+1', 'public.workout_load_on_v1(sw)-p_week_start+1', 2)
coordinator = replace(coordinator, 'sw.scheduled_date between p_week_start-1 and p_week_start+7', 'public.workout_load_on_v1(sw) between p_week_start-1 and p_week_start+7', 2)
coordinator = replace(coordinator, "'availability',candidate->'remaining'", "'availability',public.preparation_running_budget_v1(candidate,ctx.availability,shared_credit)")
coordinator = replace(coordinator, "       running:=public.calculate_running_week_constrained(p_goal_id,p_week_start,false,true,\n         jsonb_build_object('revise_week',p_revision,'excluded_session_ids',to_jsonb(p_excluded),'availability',public.preparation_running_budget_v1(candidate,ctx.availability,shared_credit),'strength_days','[]'::jsonb,'leg_load_days',candidate->'lower_days'));", """       running_constraints:=jsonb_build_object('revise_week',p_revision,'excluded_session_ids',to_jsonb(p_excluded),
         'availability',public.preparation_running_budget_v1(candidate,ctx.availability,shared_credit),'strength_days','[]'::jsonb,'leg_load_days',candidate->'lower_days');
       cache_key:=running_constraints::text;
       -- Las alternativas repetidas no vuelven a leer y evaluar el historial.
       -- Caché local a esta llamada; el coste conjunto se valida siempre abajo.
       if running_cache ? cache_key then running:=running_cache->cache_key;
       else
        running:=public.calculate_running_week_constrained(p_goal_id,p_week_start,false,true,running_constraints);
        running_cache:=running_cache||jsonb_build_object(cache_key,running);
       end if;""")
coordinator = replace(coordinator, "(rs->>'minutes')::int>coalesce((candidate->'remaining'->>extract(isodow from (rs->>'date')::date)::int::text)::int,0)", "(case when coalesce((candidate->'days'->extract(isodow from (rs->>'date')::date)::int::text->>'minutes')::int,0)>0\n           then public.preparation_shared_minutes_v2(candidate->'days'->extract(isodow from (rs->>'date')::date)::int::text,rs)\n           else (rs->>'minutes')::int end)>coalesce((ctx.availability->>extract(isodow from (rs->>'date')::date)::int::text)::int,0)")
coordinator = replace(coordinator, "'policy_version','preparation_coordinator_v3'", "'policy_version','preparation_coordinator_v3','evidence_policy_version','adaptive_evidence_v1'")

target = Path(sys.argv[1])
assert target.parent.resolve() == (ROOT / 'supabase/migrations').resolve()
assert target.name.endswith('_adaptive_evidence_and_shared_budget.sql')
target.write_text('\n\n'.join([
    '-- Reparación de evidencias y encaje; conserva decisiones publicadas y motores v3/v5.\nbegin;',
    (ROOT / 'supabase/policies/adaptive_evidence_v1.sql').read_text(encoding='utf-8'),
    abandon, running, validator, core, adapter, coordinator, 'commit;',
]) + '\n', encoding='utf-8')
print(target)
