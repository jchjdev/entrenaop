"""Construye una migración nueva desde contratos existentes, sin editar los aplicados."""
from pathlib import Path
import json
import re

ROOT = Path(__file__).resolve().parents[1]
M = ROOT / 'supabase/migrations'

def function(file, name):
    source = (M / file).read_text(encoding='utf-8')
    match = re.search(r'create (?:or replace )?function public\.' + name + r'\([\s\S]*?end\s*;?\s*\$\$;', source)
    if not match:
        raise ValueError(name)
    return match.group().replace('create function ', 'create or replace function ', 1)

parts = ['-- Referencias explícitas, estímulos y coordinación deportiva v2.\nbegin;']

# Se amplía el contrato opcional: las instantáneas v1 siguen siendo válidas.
prescription = function('20261004002000_session_guidance_and_protocol_fields.sql', 'valid_performance_prescription')
prescription = prescription.replace("'records_stimulus_responses','records_penalty_seconds']))", "'records_stimulus_responses','records_penalty_seconds','effort_mode','target_rpe','stimulus_code']))")
prescription = prescription.replace("  return true;", """  if p ? 'effort_mode' and coalesce(p->>'effort_mode','') not in ('none','rir','rpe') then return false; end if;
  if p->>'effort_mode'='rir' and (m not in ('REPS','LOAD_REPS') or p->>'intent'<>'work') then return false; end if;
  if p->>'target_rpe' is not null and (jsonb_typeof(p->'target_rpe')<>'number'
    or (p->>'target_rpe')::numeric not between 1 and 10 or p->>'effort_mode' is distinct from 'rpe') then return false; end if;
  if p ? 'stimulus_code' and (jsonb_typeof(p->'stimulus_code')<>'string' or length(p->>'stimulus_code') not between 1 and 80) then return false; end if;
  return true;""")
# Bandas pueden declarar ayuda sin fingir kilogramos.
prescription = prescription.replace("p->>'load_mode' <> 'bodyweight'", "p->>'load_mode' in ('external_load','bodyweight_plus_external')")
parts.append(prescription)
result = function('20261003005000_performance_measurement_semantics.sql', 'valid_performance_result')
result = result.replace("'value','technique_valid','conditions_confirmed','tolerated','rir','load_kg'", "'value','technique_valid','conditions_confirmed','tolerated','rir','rpe','load_kg'")
result = result.replace("array['value','rir','load_kg'", "array['value','rir','rpe','load_kg'")
result = result.replace("  if r->>'body_mass_kg'", "  if r->>'rpe' is not null and ((r->>'rpe')::numeric not between 1 and 10 or p->>'effort_mode' is distinct from 'rpe') then return false; end if;\n  if r->>'body_mass_kg'", 1)
result=result.replace('  return true;', "  if r->>'rir' is not null and p ? 'effort_mode' and p->>'effort_mode'<>'rir' then return false; end if;\n  return true;")
parts.append(result)

save = function('20261004000000_single_series_reference.sql', 'save_performance_reference')
save = save.replace('  observed date;', "  kind text:=coalesce(p_reference->>'reference_kind','legacy_work'); effort numeric;\n  observed date;")
save = save.replace("  task:=task||jsonb_build_object('schema_version',1,'policy_version','performance_v1');", """  if kind not in ('legacy_work','performed_set','repeated_work','capacity_test','official_test') then
    raise exception 'Indica qué dato estás registrando.' using errcode='22023'; end if;
  task:=task||jsonb_build_object('schema_version',1,'policy_version','reference_v2');
  -- Las marcas no tienen un RIR prescrito ni una dosis deportiva implícita.
  if kind in ('capacity_test','official_test') then task:=(task-'target_rir'-'target_rpe'-'effort_mode')||'{"intent":"control"}'::jsonb; end if;""")
save = save.replace("  n:=(p_reference->>'reported_rir')::numeric;", """  if kind in ('performed_set','capacity_test','official_test') and jsonb_array_length(p_reference->'targets')<>1 then
    raise exception 'Para este tipo registra una sola serie o marca. Usa trabajo repetido para varias series.' using errcode='22023'; end if;
  if kind='repeated_work' and jsonb_array_length(p_reference->'targets')<2 then
    raise exception 'El trabajo repetido necesita al menos dos series realmente realizadas.' using errcode='22023'; end if;
  if kind='official_test' and (role<>'specific' or task->>'measurement'<>goal_mode) then
    raise exception 'Una marca oficial requiere el gesto y protocolo de la prueba.' using errcode='22023'; end if;
  n:=case when kind in ('capacity_test','official_test') then null else (p_reference->>'reported_rir')::numeric end;
  effort:=(p_reference->>'reported_rpe')::numeric;
  if n is not null and (n not between 0 and 10 or task->>'measurement' not in ('REPS','LOAD_REPS','REPS_IN_TIME')) then
    raise exception 'Revisa el margen de repeticiones declarado.' using errcode='22023'; end if;
  if effort is not null and (effort not between 1 and 10 or task->>'measurement'<>'DURATION') then
    raise exception 'Revisa el esfuerzo declarado para esta sujeción.' using errcode='22023'; end if;""")
save = save.replace("  if task->>'measurement' in ('REPS','LOAD_REPS','REPS_IN_TIME') and task->>'intent'='work'", "  if kind='legacy_work' and task->>'measurement' in ('REPS','LOAD_REPS','REPS_IN_TIME') and task->>'intent'='work'")
save = save.replace("'observed_on',observed,'current_capacity_confirmed',true,'reported_rir',n,", "'observed_on',observed,'current_capacity_confirmed',true,'reported_rir',n,'reported_rpe',effort,'reference_kind',kind,")
parts.append(save)

profiles = []
for code, name, notes in [
 ('cod_braking_10m','Aceleración suave y frenada en 10 m','Marca 10 metros y deja espacio libre para detenerte. Acelera a velocidad cómoda y frena progresivamente con pasos cortos, tronco estable y rodillas orientadas con los pies. Vuelve andando. Cada intento termina al quedar estable; no busques velocidad máxima.'),
 ('cod_turn_90_5m','Cambio de dirección de 90 grados','Coloca tres conos formando una L con tramos de 5 metros. Acércate a velocidad cómoda, frena antes del cono y cambia de dirección manteniendo el equilibrio. Alterna derecha e izquierda entre intentos; empieza por el lado contrario en la siguiente sesión.'),
 ('cod_turn_180_5m','Ida y vuelta técnica de 5 metros','Marca dos líneas separadas 5 metros. Avanza a velocidad cómoda, frena antes de la línea, gira y vuelve. Alterna el lado de giro entre intentos; no conviertas la práctica en una carrera al máximo.'),
 ('slalom_ball_course_sector','Sector de eslalon y recogida de pelota','Usa los últimos tres conos del circuito de 16 m ya medido. Practica el eslalon, la recogida de pelota y los primeros pasos de retorno. Empieza a velocidad cómoda; termina estable y con control de la pelota. Registra si completaste el sector sin desplazar conos ni perderla.')]:
    profiles.append(dict(code=code,name=name,family='cod_practice',movement_patterns=['change_of_direction'],movement_modes=['locomotor'],body_regions=['lower_body'],laterality='bilateral',technical_level='initial',required_equipment=['cones','measuring_tape']+(['tennis_ball'] if code=='slalom_ball_course_sector' else []),optional_equipment=[],primary_muscles=['quadriceps','gluteals'],secondary_muscles=['hamstrings','trunk_stabilizers'],measurement_options=[dict(mode='PASS_FAIL',load_modes=['bodyweight'])],progression_axes=['technique','specificity'],notes=notes))
parts.append("""-- Perfiles y ejercicios reales: nunca sustituir un circuito por otro nombre.
do $$ declare p jsonb; begin
 for p in select value from jsonb_array_elements($profiles$%s$profiles$::jsonb) loop
  insert into public.exercise_training_profiles(code,definition_version,catalog_version,definition) values(p->>'code',1,3,p);
  insert into public.exercises(name,description,muscle_groups,equipment,difficulty,exercise_type,is_public,created_by,origin,training_profile_code,training_profile_version)
  values(p->>'name',p->>'notes',array['cuádriceps','glúteos'],case when p->>'code'='slalom_ball_course_sector' then array['conos','cinta métrica','pelota de tenis'] else array['conos','cinta métrica'] end,
    'inicial','duración',true,null,'system',p->>'code',1);
 end loop;
end $$;""" % json.dumps(profiles,ensure_ascii=False))

parts.append((ROOT/'supabase/policies/performance_v2.sql').read_text(encoding='utf-8'))
parts.append((ROOT/'supabase/policies/performance_shared_session_v2.sql').read_text(encoding='utf-8'))
running_set_guard=function('20260922003000_running_workouts_v1.sql','validate_running_workout_set')
running_set_guard=running_set_guard.replace('      or new.target_rpe is not null\n', '')
parts.append(running_set_guard)

# El adaptador filtra resultados de carrera dentro de una ejecución mixta.
# running_plan_v5 y sus reglas deportivas no cambian.
adapter=function('20261004001000_preparation_week_revisions.sql','calculate_running_week_constrained')
adapter=adapter.replace("'rpe',e.final_rpe", """'rpe',case when exists(select 1 from public.performance_week_work pw where pw.scheduled_workout_id=sw.id)
   then (select max(r.actual_rpe) from public.workout_execution_sets r where r.execution_id=e.id and r.block_format='running') else e.final_rpe end""")
adapter=adapter.replace("where es.execution_id=e.id) sets", "where es.execution_id=e.id and es.block_format='running') sets")
parts.append(adapter)

# Mantener autenticación, revisión, permisos y publicación transaccional existentes.
core=function('20261004002000_session_guidance_and_protocol_fields.sql','calculate_preparation_week_core')
core=core.replace("best_score int:=-1", "best_score int:=-2147483647")
core=core.replace("public.performance_task_v1(ref.reference,ref.definition,history,p_week_start,g.target_date,", "public.performance_task_v2(ref.reference,ref.definition,history,p_week_start,g.target_date,")
core=core.replace("'name',ref.definition->>'name'", "'name',coalesce(proposal->>'name',ref.definition->>'name')")
core=core.replace("'exercise_code',ref.definition->>'code'", "'exercise_code',coalesce(proposal->'dose'->'task'->>'exercise_code',ref.definition->>'code')")
core=core.replace("public.performance_place_v1(", "public.performance_place_v2(")
core=core.replace("public.performance_coordinate_progression_v1(", "public.performance_coordinate_progression_v2(")
core=core.replace("coordinated:=public.performance_coordinate_progression_v2(proposals,best_running,p_week_start);", """-- El trabajo descartado no consume el permiso de progresar de lo publicado.
 select coalesce(jsonb_agg(p),'[]') into coordinated from jsonb_array_elements(proposals) p
 where exists(select 1 from jsonb_each(best->'days') d, jsonb_array_elements(d.value->'work') w where w->>'reference_id'=p->>'reference_id');
 coordinated:=public.performance_coordinate_progression_v2(coordinated,best_running,p_week_start);
 select coordinated||coalesce(jsonb_agg(p),'[]') into coordinated from jsonb_array_elements(proposals) p
 where not exists(select 1 from jsonb_array_elements(coordinated) c where c->>'reference_id'=p->>'reference_id');""")
core=core.replace("if running is not null then score:=score+1000+coalesce((select sum((s->>'minutes')::int) from jsonb_array_elements(running->'sessions') s),0); end if;", """-- Cobertura antes que minutos: evita premiar accesorios por desplazar carrera.
   score:=score - 10000*(select count(*) from jsonb_array_elements(candidate->'missing') q where q->>'role'<>'support' and (q->>'scheduled')::int=0);
   if running is not null then score:=score+1000+300*jsonb_array_length(running->'sessions')
     +100*(select count(*) from jsonb_array_elements(running->'sessions') q where q->>'kind'<>'easy'); end if;""")
core=core.replace("'policy_version','preparation_coordinator_v1'", "'policy_version','preparation_coordinator_v2'")
core=core.replace(" required_missing:=", """ -- Una misma sesión física comparte preparación general y vuelta a la calma.
 select coalesce(jsonb_agg(case when r.item is null then f else f||jsonb_build_object(
   'combined',true,'standalone_minutes',f->'minutes',
   'minutes',public.preparation_shared_minutes_v2(f,r.item)-(r.item->>'minutes')::int,
   'shared_total_minutes',public.preparation_shared_minutes_v2(f,r.item),
   'warm_up_instructions',case when f->>'session_order'='running_first' or exists(select 1 from jsonb_array_elements(r.item->'segments') seg where seg->>'role'='warmup')
    then 'La activación general se comparte con carrera. Después: 1:00 de movilidad de las articulaciones que usarás y 2:00 de ensayo fácil de los movimientos pautados. Sin máximos.' else f->>'warm_up_instructions' end,
   'warm_up_seconds',case when f->>'session_order'='running_first' or exists(select 1 from jsonb_array_elements(r.item->'segments') seg where seg->>'role'='warmup') then 180 else 420 end
 ) end),'[]') into sessions from jsonb_array_elements(sessions) f
 left join lateral(select value item from jsonb_array_elements(coalesce(best_running->'sessions','[]')) q where q->>'date'=f->>'date') r on true;
 required_missing:=""")
parts.append(core)

publish=function('20261004002000_session_guidance_and_protocol_fields.sql','publish_preparation_week')
publish=publish.replace('  p jsonb; idx int;', '  run_session jsonb; run_schedule uuid; p jsonb; idx int;')
publish=publish.replace(" end loop;\n update public.preparation_week_decisions", """   if s->>'combined'='true' then
     select value into run_session from jsonb_array_elements(plan->'running'->'sessions') r where r->>'date'=s->>'date';
     select rs.scheduled_workout_id into run_schedule from public.running_week_sessions rs join public.scheduled_workouts sw on sw.id=rs.scheduled_workout_id
       where rs.decision_id=(running_result->>'decision_id')::uuid and sw.scheduled_date=(s->>'date')::date and sw.status='planned';
     perform public.materialize_shared_preparation_day_v2(sw_id,run_schedule,s,run_session);
   end if;
 end loop;
 update public.preparation_week_decisions""")
parts.append(publish)
parts.append('commit;')
output=M/'20261004003000_performance_stimulus_bank_v2.sql'
output.write_text('\n\n'.join(parts)+'\n',encoding='utf-8')
print(output.name)
