"""Genera migraciones nuevas del programa adaptativo; no conecta a Supabase."""
from pathlib import Path
import re

root = Path(__file__).resolve().parents[1]
migrations = root / 'supabase/migrations'

def function(file, name):
    source = (migrations / file).read_text(encoding='utf-8-sig')
    match = re.search(r'create (?:or replace )?function public\.' + name + r'\([\s\S]*?end\s*;?\s*\$\$;', source)
    assert match, name
    return match.group().replace('create function', 'create or replace function', 1)

resolve = function('20261001009000_running_program_adapter.sql', 'resolve_program_running_reference')
resolve = resolve.replace("elsif g.program_id='armed_forces_troop_entry' and sel.reference_source='troopControl' then", "elsif sel.reference_source='trainingControl' or (g.program_id='armed_forces_troop_entry' and sel.reference_source='troopControl') then\n   if g.program_id not in ('fas_periodic_assessment','armed_forces_troop_entry') and not exists(select 1 from public.program_training_modules where program_id=g.program_id and module_key='running_2000m_v1') then raise exception 'Este programa no tiene preparación de 2 km.'; end if;")
(migrations/'20261004007000_common_running_controls.sql').write_text("""-- Un control medido conserva su fuente; no se convierte en evaluación oficial.
begin;
alter table public.running_reference_selections drop constraint running_reference_source_check;
alter table public.running_reference_selections add constraint running_reference_source_check
 check(reference_source in ('troopControl','trainingControl','troopOfficialAssessment','fasPeriodicAssessment','programAssessment'));
""" + resolve + '\ncommit;\n', encoding='utf-8')

publish = function('20261004003000_performance_stimulus_bank_v2.sql', 'publish_preparation_week')
publish = publish.replace("and current_date<p_week_start-1 then", "and current_date<p_week_start-1 and not public.preparation_can_advance(p_goal_id,p_week_start) then")
publish = publish.replace(" plan:=public.calculate_preparation_week(p_goal_id,p_week_start);", """ if exists(select 1 from public.adaptive_program_states where preparation_goal_id=p_goal_id and auto_advance)
  and exists(select 1 from public.preparation_week_decisions d where d.preparation_goal_id=p_goal_id and d.week_start<p_week_start and d.superseded_at is null
    and not public.preparation_week_closed(p_goal_id,d.week_start)) then
  raise exception 'Resuelve las sesiones pendientes antes de continuar el programa.' using errcode='22023'; end if;
 plan:=public.calculate_preparation_week(p_goal_id,p_week_start);""")
publish = publish.replace("jsonb_build_object(\n   'context'", "jsonb_build_object(\n   'program',(select to_jsonb(a) from public.adaptive_program_states a where a.preparation_goal_id=p_goal_id),\n   'target_date',(select target_date from public.preparation_goals where id=p_goal_id),\n   'context'")
(root/'supabase/policies/program_publication.sql').write_text(publish, encoding='utf-8')

setup = function('20261004001000_preparation_week_revisions.sql', 'get_preparation_training_setup')
# El contrato vigente incluye filtros de aplicabilidad; se conserva íntegro.
assert 'published_weeks' in setup
(root/'supabase/policies/program_setup_base.sql').write_text(setup, encoding='utf-8')

setup = setup.replace("where program_id=g.program_id)", "where program_id=g.program_id and module_key='running_2000m_v1')")
setup = setup.replace("'goal_id',g.id", "'program_state',coalesce((select to_jsonb(a)-'last_error_code' from public.adaptive_program_states a where a.preparation_goal_id=g.id),'{}'::jsonb),'goal_id',g.id")
setup = setup.replace("'goal_id',g.id", "'pending_sessions',coalesce((select jsonb_agg(jsonb_build_object('id',sw.id,'date',sw.scheduled_date,'name',sw.template_name,'status',sw.status) order by sw.scheduled_date) from public.scheduled_workouts sw where sw.preparation_goal_id=g.id and sw.status in ('planned','in_progress') and sw.scheduled_date<=current_date),'[]'::jsonb),'goal_id',g.id")
lifecycle = (root/'supabase/policies/adaptive_program_lifecycle.sql').read_text(encoding='utf-8')
(migrations/'20261004008000_adaptive_program_lifecycle.sql').write_text(
    'begin;\n'+lifecycle+'\n'+publish+'\n'+setup+'\ncommit;\n', encoding='utf-8')

# Revisar no equivale a convocar un test. La revisión responde a una señal o
# transición, y nunca cambia por sí misma el esfuerzo prescrito.
review = function('20261004006000_technical_practice_guidance.sql', 'performance_task_v2')
review = review.replace("'review_due',coalesce((previous->>'weeks_since_review')::int,0)>=3,", """'review_due',bad>0 or (previous->>'phase' is not null and previous->>'phase'<>phase),
  'review_reason',case when bad>0 then 'La respuesta reciente requiere revisar recuperación y dosis. No añadir un test máximo.'
    when previous->>'phase' is not null and previous->>'phase'<>phase then 'Cambia el énfasis del programa: revisa la respuesta y si falta información relevante. No exige un test.' end,
  'review_policy','need_based_v1',""")
assert "'review_policy','need_based_v1'" in review
(migrations/'20261004009000_need_based_performance_review.sql').write_text('begin;\n'+review+'\ncommit;\n', encoding='utf-8')
