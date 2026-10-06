"""Compone una migración auditable desde políticas nuevas y contratos vigentes.

Las fuentes v2 se conservan para historial/regresiones; el SQL resultante queda
guardado y revisable, sin reescritura dinámica de funciones en desarrollo.
"""
from pathlib import Path
import re

root = Path(__file__).resolve().parents[1]


def function(file, name):
    source = (root / file).read_text(encoding='utf-8-sig')
    match = re.search(r'create (?:or replace )?function public\.' + name + r'\(.*?end \$\$;', source, re.S)
    if not match:
        raise ValueError(name)
    return match.group()


core = function('supabase/migrations/20261004009000_need_based_performance_review.sql', 'performance_task_v2')
core = core.replace('create or replace function public.performance_task_v2(', 'create function public.performance_task_v3_core(')
core = core.replace("phase:=case when days_left<=7", "phase:=coalesce(reference->>'strategy_phase',case when days_left<=7")
core = core.replace("else 'development' end;", "else 'development' end);")
core = core.replace("'performance_v2'", "'performance_v3'")
# El contador histórico no programa controles ni altera el estímulo. Integrar
# el recorrido exige práctica técnica reciente, también cerca de la prueba.
core = core.replace("  if phase='development' and coalesce((previous->>'weeks_since_review')::int,0)>=3 then block_code:='COD-SP02'; end if;", '')
core = core.replace("  if phase='taper' then block_code:=", "  if phase='specific' and (select count(distinct (h->>'completed_on')::date) from jsonb_array_elements(coalesce(history,'[]')) h where (h->>'completed_on')::date between wk-21 and wk-1 and h->'dose'->'task'->>'stimulus_code' in ('COD-T01','COD-SP01') and public.performance_exposure_signal_v2(h,h->'dose')='tolerated')<2 then block_code:='COD-T01'; end if;\n  if phase='taper' then block_code:=")
core = core.replace("Fuera de la fase específica se revisa periódicamente.", "La integración se decide por la fase y la calidad reciente, sin un contador de tests.")

wrapper = function('supabase/migrations/20261004004000_preparation_objective_coverage.sql', 'performance_task_v2_1')
wrapper = wrapper.replace('public.performance_task_v2_1(', 'public.performance_task_v3(')
wrapper = wrapper.replace("previous jsonb default '{}'::jsonb)", "previous jsonb default '{}'::jsonb,started_on date default null)")
wrapper = wrapper.replace('p jsonb:=public.performance_task_v2(reference,profile,history,wk,target_date,previous);',
    "b jsonb:=public.performance_block_v3(reference,history,wk,target_date,coalesce(started_on,wk),previous);\n p jsonb:=public.performance_task_v3_core(reference||jsonb_build_object('strategy_phase',b->>'code'),profile,history,wk,target_date,previous);")
wrapper = wrapper.replace("begin\n if p->>'outcome'", "begin\n p:=p||jsonb_build_object('block',b);\n if p->>'outcome'")

coordinator = function('supabase/migrations/20261004012000_program_pause_and_training_scope.sql', 'calculate_preparation_week_for_scope')
coordinator = coordinator.replace('frequency_limit int;', 'started_on date; frequency_limit int;')
coordinator = coordinator.replace('started_on date; frequency_limit int;', 'started_on date; include_support boolean; frequency_limit int;')
coordinator = coordinator.replace(' for ref in select r.*,ep.definition',
    " select coalesce(min(week_start),p_week_start) into started_on from public.preparation_week_decisions where preparation_goal_id=p_goal_id and superseded_at is null;\n for ref in select r.*,ep.definition",1)
coordinator = coordinator.replace('public.performance_task_v2_1(ref.reference,', 'public.performance_task_v3(ref.reference,')
coordinator = coordinator.replace("end); end if;\n   -- Cualquier molestia", "end,started_on); end if;\n   -- Cualquier molestia",1)
coordinator = coordinator.replace(' -- Seleccionar específico accesible;',
    ' proposals:=public.performance_select_v3(proposals);\n -- Seleccionar específico accesible;',1)
coordinator = coordinator.replace('public.performance_place_v2_1(', 'public.performance_place_v3(')
# Comparar también la semana sin accesorios: no basta con decir que son
# opcionales si todas las candidatas consumen su tiempo y recuperación.
coordinator = coordinator.replace(' for frequency_limit in reverse 2..0 loop', ' for include_support in select unnest(array[true,false]) loop\n for frequency_limit in reverse 2..0 loop')
coordinator = coordinator.replace("into candidates from jsonb_array_elements(proposals) p;", "into candidates from jsonb_array_elements(proposals) p where include_support or p->>'optional' is distinct from 'true';")
coordinator = coordinator.replace(' -- El trabajo descartado no consume', ' end loop;\n -- El trabajo descartado no consume',1)
coordinator = coordinator.replace("select coordinated||coalesce(jsonb_agg(p),'[]') into coordinated", "select coordinated||coalesce(jsonb_agg(p||jsonb_build_object('allocation_status','not_scheduled','allocation_reason','Se conserva la referencia, pero esta semana tiene prioridad la cobertura específica, carrera y recuperación.')),'[]') into coordinated")
# El elegido como principal conserva la prioridad aunque su referencia UUID no
# sea la primera alfabéticamente (las variantes no son intercambiables).
coordinator = coordinator.replace("        q->>'reference_id') < (case p->>'role' when 'specific' then 0 when 'regression' then 1 else 2 end,p->>'reference_id')", "        coalesce((q->>'selection_rank')::int,1),q->>'reference_id') < (case p->>'role' when 'specific' then 0 when 'regression' then 1 else 2 end,coalesce((p->>'selection_rank')::int,1),p->>'reference_id')")
coordinator = coordinator.replace("'preparation_coordinator_v2_2'", "'preparation_coordinator_v3'")
coordinator = coordinator.replace("'proposals',proposals,'sessions',sessions,", "'program_path',public.performance_program_path_v3(started_on,g.target_date,p_week_start,proposals),'proposals',proposals,'sessions',sessions,")
coordinator = coordinator.replace(' -- Una misma sesión física comparte', " sessions:=public.performance_controls_v3(sessions,coalesce(previous.decision,'{}'));\n -- Una misma sesión física comparte",1)

placement = function('supabase/migrations/20261004004000_preparation_objective_coverage.sql', 'performance_place_v2_1')
placement = placement.replace('public.performance_place_v2_1(', 'public.performance_place_v3(')
# Una pareja principal + apoyo conocido permite composición, limitada a cuatro
# series de empuje/apoyo. No habilita dos apoyos ni dos principales del patrón.
placement = placement.replace("where q->'movement_patterns' ? pat)",
    "where q->'movement_patterns' ? pat) and not (p->>'objective_key'=q->>'objective_key' and (p->>'optional'='true') is distinct from (q->>'optional'='true') and jsonb_array_length(p->'dose'->'targets')+jsonb_array_length(q->'dose'->'targets')<=4)")
# Evitar que un apoyo de dos series bloquee una segunda exposición específica.
# Se mantienen las fronteras de recuperación ya aplicadas entre días.

setup = function('supabase/migrations/20261004012000_program_pause_and_training_scope.sql', 'get_preparation_training_setup')
setup = setup.replace('scope text; active_program jsonb;', 'scope text; active_program jsonb; latest jsonb; started_on date; path jsonb;')
setup = setup.replace(' return setup;', """ select decision into latest from public.preparation_week_decisions where preparation_goal_id=p_goal_id and superseded_at is null order by week_start desc limit 1;
 select min(week_start) into started_on from public.preparation_week_decisions where preparation_goal_id=p_goal_id and superseded_at is null;
 path:=latest->'program_path';
 if path is null and latest is not null and scope<>'running' then
   path:=public.performance_program_path_v3(started_on,(setup->>'target_date')::date,(latest->>'week_start')::date,latest->'proposals')
     ||jsonb_build_object('note','Esta semana conserva su pauta anterior. Las fechas orientativas no recalculan sesiones; la nueva estrategia se aplicará en la siguiente adaptación.');
 end if;
 setup:=setup||jsonb_build_object('program_path',coalesce(path,'{}'::jsonb),'calibration_options',case when scope='running' then '[]'::jsonb else public.performance_calibration_options_v3(p_goal_id) end);
 return setup;""")

materializer = function('supabase/migrations/20261004012000_program_pause_and_training_scope.sql', 'materialize_preparation_week_scoped')
materializer = materializer.replace('s jsonb; w jsonb;', 's jsonb; warm_step jsonb; warm_idx int; w jsonb;')
old_warm = """   insert into public.workout_items(block_id,exercise_id,order_index,notes)
     values(b_id,'21000000-0000-4000-8000-000000000001',0,
       coalesce(s->>'warm_up_instructions',public.performance_warm_up_instructions_v1(s))) returning id into i_id;
   insert into public.workout_sets(item_id,order_index,target_duration_seconds,rest_after_seconds)
     values(i_id,0,420,0);"""
new_warm = """   warm_idx:=0;
   for warm_step in select value from jsonb_array_elements(public.performance_warm_up_steps_v3(s)) loop
    insert into public.workout_items(block_id,exercise_id,order_index,notes)
     values(b_id,'21000000-0000-4000-8000-000000000001',warm_idx,warm_step->>'name'||E'\\n'||(warm_step->>'instructions')) returning id into i_id;
    insert into public.workout_sets(item_id,order_index,target_duration_seconds,rest_after_seconds)
     values(i_id,0,(warm_step->>'seconds')::int,0);
    warm_idx:=warm_idx+1;
   end loop;"""
assert old_warm in materializer
materializer = materializer.replace(old_warm, new_warm).replace('public.materialize_shared_preparation_day_v2(', 'public.materialize_shared_preparation_day_v3(')

shared = function('supabase/migrations/20261004003000_performance_stimulus_bank_v2.sql', 'materialize_shared_preparation_day_v2')
shared = shared.replace('public.materialize_shared_preparation_day_v2(', 'public.materialize_shared_preparation_day_v3(')
# La plantilla v3 ya contiene los pasos de 3:00 o 7:00; no convertir cada paso
# en tres minutos al unirlo con carrera. Sus segmentos siguen idénticos.
shared = re.sub(r"case when phase='force_warm' and \(run_first or has_warm\) then\s*'Ya has realizado.*?else item.notes end", 'item.notes', shared, flags=re.S)
shared = shared.replace("case when phase='force_warm' and (run_first or has_warm) then 180 else ws.target_duration_seconds end", 'ws.target_duration_seconds')

save_reference = function('supabase/migrations/20261004005000_separate_observed_reps_from_work_range.sql', 'save_performance_reference')
old_identity = "and objective_key=key and reference->'task'->>'exercise_code'=work.code and active;"
assert old_identity in save_reference
save_reference = save_reference.replace(old_identity, "and objective_key=key and reference->'task'->>'exercise_code'=work.code and reference->'task'->>'measurement'=task->>'measurement' and active;")
reference_identity = """-- Recalibrar sustituye solo la misma medición. Una serie libre y una marca
-- temporal conservan referencias propias y no se convierten entre sí.
drop index public.performance_reference_active;
create unique index performance_reference_active on public.performance_training_references
 (preparation_goal_id,objective_key,(reference->'task'->>'exercise_code'),(reference->'task'->>'measurement')) where active;"""

parts = ['-- Estrategias por objetivo y fases visibles. Carrera v5 no se redefine.\nbegin;',
 reference_identity,save_reference,(root/'supabase/policies/performance_strategy_v3.sql').read_text(encoding='utf-8'),core,wrapper,placement,coordinator,setup,shared,materializer,
 "revoke all on function public.performance_task_v3_core(jsonb,jsonb,jsonb,date,date,jsonb),public.performance_task_v3(jsonb,jsonb,jsonb,date,date,jsonb,date),public.performance_place_v3(jsonb,jsonb,jsonb,jsonb,integer,date,date) from public,anon,authenticated;",
 'revoke all on function public.materialize_shared_preparation_day_v3(uuid,uuid,jsonb,jsonb) from public,anon,authenticated;',
 'commit;']
target = root/'supabase/migrations/20261006000000_performance_strategies_and_phases.sql'
target.write_text('\n\n'.join(parts)+'\n',encoding='utf-8')
print(target)
