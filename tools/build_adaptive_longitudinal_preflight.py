"""Programa combinado completo con funciones instaladas y reloj transaccional.

Las respuestas y controles son fixtures, no predicciones de mejora humana.
El reloj se cambia ANTES de iniciar/cerrar; no se retocan fechas tras disparar
la continuación. No se cargan motores históricos. Todo termina en ROLLBACK.
"""
import argparse
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument('--migration', type=Path)
parser.add_argument('--initial-frequency-one', action='store_true')
parser.add_argument('--expect-expanded-frequency', action='store_true')
parser.add_argument('--with-support', action='store_true')
parser.add_argument('--automatic-support', action='store_true')
parser.add_argument('--focus-push', action='store_true', help='Programa ficticio independiente: 2 km y flexiones')
parser.add_argument('--support-result', choices=['complete', 'unknown', 'skipped'], default='complete')
parser.add_argument('--months', type=int, choices=[1, 2, 3, 4, 6, 12], default=6)
args = parser.parse_args()
assert not (args.with_support and args.automatic_support), 'Elegir apoyo calibrado o entrada automática'
assert args.support_result == 'complete' or args.automatic_support
parts = ["begin;", "set local statement_timeout='240s';"]
if args.migration:
    source = args.migration.read_text(encoding='utf-8-sig')
    parts.append(re.sub(r'commit;\s*$', '', re.sub(r'(?m)^begin;\s*', '', source, count=1)))
parts.append(r"""
create temp table adaptive_clock(value timestamptz);
insert into adaptive_clock values('2026-10-05 08:00:00+00');
create function pg_temp.program_now() returns timestamptz language sql stable as $$ select value from adaptive_clock $$;
create function pg_temp.program_today() returns date language sql stable as $$ select pg_temp.program_now()::date $$;
alter table public.workout_executions alter column started_at set default pg_temp.program_now();
do $$ declare f record; definition text; u uuid:=gen_random_uuid(); begin
 -- También los DEFAULT participan del reloj: de lo contrario el primer alta
 -- tendría la fecha del servidor mientras los RPC simulan otro día.
 for f in select n.nspname,c.relname,a.attname,pg_get_expr(d.adbin,d.adrelid) expression
   from pg_attrdef d join pg_class c on c.oid=d.adrelid join pg_namespace n on n.oid=c.relnamespace
   join pg_attribute a on a.attrelid=c.oid and a.attnum=d.adnum
   where n.nspname='public' and pg_get_expr(d.adbin,d.adrelid)='now()' loop
  execute format('alter table %I.%I alter column %I set default pg_temp.program_now()',f.nspname,f.relname,f.attname);
 end loop;
 for f in select p.oid from pg_proc p join pg_namespace n on n.oid=p.pronamespace
   where n.nspname='public' and p.prokind='f' and (p.prosrc ilike '%current_date%' or p.prosrc like '%now()%') loop
  definition:=pg_get_functiondef(f.oid);
  definition:=regexp_replace(definition,'\mcurrent_date\M','pg_temp.program_today()','gi');
  definition:=regexp_replace(definition,'\mnow\(\)','pg_temp.program_now()','gi');
  execute definition;
 end loop;
 insert into auth.users(id,email) values(u,'adaptive-longitudinal@example.invalid');
 insert into public.admin_permissions(user_id,reason) values(u,'Fixture longitudinal transaccional');
 perform set_config('entrenaop.fixture_user',u::text,true);
end $$;
create temp table adaptive_trajectory(week_start date,status text,running_count int,performance_count int,reviewed boolean,maximum_frequency int);
""")
fixture = (ROOT / 'supabase/tests/adaptive_program_lifecycle.sql').read_text(encoding='utf-8-sig')
marker = ' for s in select sw.id,sw.scheduled_date'
prefix = fixture[:fixture.index(marker)]
prefix = re.sub(r'^begin;\s*', '', prefix)
prefix = prefix.replace('(select user_id::text from public.admin_permissions limit 1)', "current_setting('entrenaop.fixture_user')")
prefix = prefix.replace('p jsonb; again jsonb;', 'iteration int:=0; renewed boolean; renewed_count int:=0; p jsonb; again jsonb;')
prefix = prefix.replace('current_date+90', f"(current_date+interval '{args.months} months')::date")
prefix = prefix.replace("now()+interval '1 day'", "now()+interval '2 years'")
if args.focus_push:
    # Caso adicional, no sustituto de las baterías FAS: un programa propio
    # configurado con carrera y flexiones. Todo su catálogo se revierte al final.
    focus = """
do $$ declare program text; test uuid; begin
 program:=public.create_admin_preparation_program('Fixture: carrera y flexiones','access');
 perform public.save_admin_program_scoring_rule_v3(program,'lab_generic_v1','https://www.boe.es/',
  'Fuente ficticia de ensayo','pass_fail','none',1,0,0,'assessment_date',null,'Ingreso',null,null);
 test:=public.create_admin_program_assessment_test_v5(program,'run2k','Carrera 2 km','seconds','lower',
  'Carrera continua cronometrada en pista.','both','run2k',1,1,18,60,1,'none',2000,'run_2000m_v1');
 perform public.save_admin_program_pass_standard(test,null,'men',18,60,475);
 perform public.save_admin_program_pass_standard(test,null,'women',18,60,510);
 perform public.set_admin_program_training_module(test,'running_2000m_v1');
 perform public.publish_admin_program_assessment(program);
 insert into public.performance_legacy_objectives
  select (jsonb_populate_record(null::public.performance_legacy_objectives,to_jsonb(o)||
   jsonb_build_object('program_id',program))).* from public.performance_legacy_objectives o
  where program_id='fas_periodic_assessment' and objective_key='legacy:upper_body_push_ups_2_min';
 perform set_config('entrenaop.fixture_program',program,true);
 perform set_config('entrenaop.fixture_running_test',test::text,true);
end $$;
"""
    at = prefix.index('do $$')
    prefix = prefix[:at] + focus + prefix[at:]
    prefix = prefix.replace("values(auth.uid(),'fas_periodic_assessment'", "values(auth.uid(),current_setting('entrenaop.fixture_program')")
    prefix = re.sub(r" insert into public.fas_periodic_assessments.*?returning id into a;\s*insert into public.fas_periodic_marks.*?;\s*insert into public.running_reference_selections.*?;\n", " a:=public.save_program_assessment_attempt(g,'men','1996-01-01',current_date,jsonb_build_array(jsonb_build_object('test_id',current_setting('entrenaop.fixture_running_test'),'mark',478)));\n", prefix, flags=re.S)
    prefix = prefix.replace(" update public.running_reference_selections set reference_source='trainingControl',reference_record_id=control_id::text where preparation_goal_id=g;", " insert into public.running_reference_selections(preparation_goal_id,reference_source,reference_record_id) values(g,'trainingControl',control_id::text);")
    prefix = re.sub(r" perform public.save_performance_reference\(g,jsonb_build_object\('goal_code','(?:front_plank_forearms|slalom_ball_course_16m)'.*?\)\);\n", '', prefix, flags=re.S)
    prefix = prefix.replace("jsonb_array_length(p->'sessions')<>2", "jsonb_array_length(p->'sessions')<1")
    prefix = prefix.replace("jsonb_array_length(public.get_preparation_training_setup(g)->'objectives')<>3", "jsonb_array_length(public.get_preparation_training_setup(g)->'objectives')<>1")
    prefix = prefix.replace('No reconoce las tres pruebas FAS', 'No reconoce el objetivo único del programa ficticio')
if args.initial_frequency_one:
    prefix = prefix.replace("'rest_seconds',120,'frequency',2", "'rest_seconds',120,'frequency',1")
    prefix = prefix.replace("jsonb_array_length(p->'sessions')<>2", "jsonb_array_length(p->'sessions')<1")

if args.with_support:
    prefix = prefix.replace(' p:=public.calculate_preparation_week(g,wk);', """
 perform public.save_performance_reference(g,jsonb_build_object('goal_code','push_up_standard','goal_version',1,
  'goal_measurement','REPS_IN_TIME','program_objective_key','legacy:upper_body_push_ups_2_min',
  'task','{"exercise_code":"bench_press_barbell","exercise_version":1,"protocol_key":"bench_work","protocol_version":1,"setup_key":"standard:bench_work","measurement":"LOAD_REPS","load_mode":"external_load","external_load_kg":40,"target_value":8,"intent":"work"}'::jsonb,
  'reference_kind','repeated_work','targets','[8,8]'::jsonb,'observed_on',wk-1,'current_capacity_confirmed',true,
  'reported_rir',3,'rest_seconds',180,'frequency',1,'rep_min',4,'rep_max',6,'load_step_kg',2,'equipment_confirmed',true));
 p:=public.calculate_preparation_week(g,wk);""")

if args.automatic_support:
    prefix = prefix.replace(' p:=public.calculate_preparation_week(g,wk);', """
 update public.performance_training_contexts set equipment=equipment||array['bench','barbell','plates'] where user_id=auth.uid();
 p:=public.calculate_preparation_week(g,wk);""")

loop = fixture[fixture.index(marker):fixture.index(' if (select count(*) from public.preparation_week_decisions where preparation_goal_id=g)<>2')]
loop = loop.replace("   if (select count(*) from public.preparation_week_decisions where preparation_goal_id=g)<>1 then raise exception 'Adapta antes de cerrar todas las sesiones'; end if;", "   update adaptive_clock set value=s.scheduled_date+time '12:00';")
loop = loop.replace("   perform public.finish_workout_execution(e,6,null,null,null,'manual');", "   perform public.finish_workout_observed_idempotent(gen_random_uuid(),e,6,now(),0);")
loop = loop.replace("r:=jsonb_build_object('value'", "r:=jsonb_build_object('load_kg',es.performance_prescription->'external_load_kg','body_mass_kg',es.performance_prescription->'body_mass_kg','value'")
if args.automatic_support:
    # Cuarenta kilos es un resultado declarado por ESTA fixture. No se añade
    # como carga prescrita ni como regla de entrada en el motor.
    loop = loop.replace("'load_kg',es.performance_prescription->'external_load_kg'", "'load_kg',case when es.performance_prescription->>'policy_version'='support_familiarization_v1' and es.performance_prescription->>'load_mode'='external_load' then '40'::jsonb else es.performance_prescription->'external_load_kg' end")
    if args.support_result == 'unknown':
        loop = loop.replace('       perform public.complete_performance_set_idempotent(gen_random_uuid(),es.id,r);',
            "       if es.performance_prescription->>'policy_version'='support_familiarization_v1' then r:=r-'rir'-'load_kg'; end if;\n       perform public.complete_performance_set_idempotent(gen_random_uuid(),es.id,r);")
    elif args.support_result == 'skipped':
        loop = loop.replace('       perform public.complete_performance_set_idempotent(gen_random_uuid(),es.id,r);',
            "       if es.performance_prescription->>'policy_version'='support_familiarization_v1' then perform public.skip_workout_set(es.id);\n       else perform public.complete_performance_set_idempotent(gen_random_uuid(),es.id,r); end if;")
loop = re.sub(r'   -- Fechas sintéticas.*?where id=e;\n', '', loop, flags=re.S)
tail = """
  -- El mismo lector que usa Flutter recupera cuatro semanas sin reescribirlas.
  if iteration>=5 and (public.get_running_intake_context_observed(g)->'recent_load_sources') ? 'unknown' then
    raise exception 'Pierde semanas registradas y vuelve a pedirlas'; end if;
  if exists(select 1 from public.preparation_week_decisions wd,
    jsonb_array_elements(wd.decision->'proposals') prop
    where wd.preparation_goal_id=g and wd.week_start=wk and prop->>'status'='ready'
      and prop->>'allocation_status' is distinct from 'not_scheduled'
      and (prop->>'frequency')::int<>(select count(*) from jsonb_array_elements(wd.decision->'sessions') ss,
        jsonb_array_elements(ss->'work') work where work->>'reference_id'=prop->>'reference_id')) then
    raise exception 'Conserva una frecuencia que no se ha entregado'; end if;
  if exists(select 1 from public.preparation_week_decisions wd,
    jsonb_array_elements(wd.decision->'sessions') ss,jsonb_array_elements(ss->'work') work
    where wd.preparation_goal_id=g and wd.week_start=wk and work->>'outcome'='redistribute'
    group by work->>'reference_id' having count(*)<>max((work->>'frequency')::int)) then raise exception 'Publica media redistribución'; end if;
  if exists(select 1 from public.preparation_week_decisions wd,
    jsonb_array_elements(wd.decision->'sessions') ss,jsonb_array_elements(ss->'work') work,
    jsonb_array_elements(wd.decision->'proposals') prop
    where wd.preparation_goal_id=g and wd.week_start=wk and prop->>'reference_id'=work->>'reference_id'
      and prop ? 'exposure_doses'
      and work->'dose' is distinct from prop->'exposure_doses'->((work->>'exposure_index')::int)) then
    raise exception 'Pierde la dosis propia de cada exposición'; end if;
  renewed:=false;
  -- Se conserva la caducidad y se comprueba su salida de revisión. Solo este
  -- deportista simulado confirma explícitamente el contexto o aporta un control.
  if (select status='needs_review' from public.adaptive_program_states where preparation_goal_id=g) then
   if (select observed_at<now()-interval '30 days' from public.performance_training_contexts where user_id=auth.uid())
     or (select updated_at::date<current_date-30 or health_observed_at::date<current_date-30 from public.running_intake_contexts where preparation_goal_id=g) then
    perform public.save_performance_context('{"1":60,"3":60,"5":60}',(select equipment from public.performance_training_contexts where user_id=auth.uid()),false,true);
    -- Solo confirma situación actual; la carga se recupera desde registros.
    update public.running_intake_contexts set updated_at=now(),health_observed_at=now() where preparation_goal_id=g;
    renewed:=true; renewed_count:=renewed_count+1;
   end if;
   if (select now()-completed_at>interval '28 days' from public.preparation_running_tests where id=control_id) then
    insert into public.preparation_running_tests(user_id,preparation_goal_id,completed_at,duration_seconds,rpe)
     values(auth.uid(),g,now(),478,8) returning id into control_id;
    update public.running_reference_selections set reference_source='trainingControl',reference_record_id=control_id::text where preparation_goal_id=g;
    renewed:=true;
   end if;
   perform public.advance_adaptive_program(g);
  end if;
  insert into adaptive_trajectory select wk,ps.status,jsonb_array_length(wd.decision->'running'->'sessions'),jsonb_array_length(wd.decision->'sessions'),renewed,
   (select max((select count(*) from jsonb_array_elements(wd.decision->'sessions') ss,
     jsonb_array_elements(ss->'work') work where work->>'reference_id'=prop->>'reference_id'))
    from jsonb_array_elements(wd.decision->'proposals') prop where prop->>'status'='ready')
   from public.preparation_week_decisions wd join public.adaptive_program_states ps on ps.preparation_goal_id=wd.preparation_goal_id
   where wd.preparation_goal_id=g and wd.week_start=wk and wd.superseded_at is null;
  exit when (select status='complete' from public.adaptive_program_states where preparation_goal_id=g);
  if not exists(select 1 from public.preparation_week_decisions where preparation_goal_id=g and week_start=wk+7 and superseded_at is null) then
   raise exception 'Sin continuación en semana %: %',iteration,public.get_preparation_training_setup(g)->'program_state'; end if;
  if iteration>54 then raise exception 'Encadena semanas sin alcanzar el objetivo'; end if;
  wk:=wk+7;
 end loop;
 if iteration<4 then raise exception 'Trayectoria demasiado corta'; end if;
 if (select target_date-pg_temp.program_today()>7 from public.preparation_goals where id=g) then raise exception 'Termina antes de la prueba'; end if;
 if iteration>6 and renewed_count=0 then raise exception 'No comprueba la caducidad del contexto'; end if;
 if exists(select 1 from public.scheduled_workouts where preparation_goal_id=g and status<>'cancelled' group by scheduled_date having count(*)>1) then raise exception 'Duplica sesiones'; end if;
end $$;
select max(maximum_frequency) maximum_observed_frequency,count(*) weeks,count(*) filter(where reviewed) reviewed_weeks,max(running_count) maximum_runs,max(performance_count) maximum_performance_days from adaptive_trajectory;
rollback;
"""
if args.initial_frequency_one:
    tail = tail.replace(' if iteration<4', " if not exists(select 1 from adaptive_trajectory where maximum_frequency=2) then raise exception 'Nunca aumenta frecuencia desde uno'; end if;\n if iteration<4")
if args.expect_expanded_frequency:
    tail = tail.replace(' if iteration<4', " if not exists(select 1 from adaptive_trajectory where maximum_frequency>2) then raise exception 'Persiste techo de dos'; end if;\n if iteration<4")
if args.with_support:
    tail = tail.replace(' if iteration<4', " if not exists(select 1 from public.performance_week_work pw join public.preparation_week_decisions wd on wd.id=pw.decision_id where wd.preparation_goal_id=g and pw.dose->'task'->>'exercise_code'='bench_press_barbell') then raise exception 'Nunca publica apoyo calibrado'; end if;\n if iteration<4")
    tail = tail.replace(' if iteration<4', """ if not exists(select 1 from public.performance_week_work pw
      join public.scheduled_workouts sw on sw.id=pw.scheduled_workout_id
      join public.workout_executions closed_execution on closed_execution.id=sw.execution_id
      join public.workout_execution_sets observed_set on observed_set.execution_id=closed_execution.id and observed_set.block_order=pw.block_order
      where sw.preparation_goal_id=g and closed_execution.status='completed' and observed_set.status='completed'
        and pw.dose->'task'->>'exercise_code'='bench_press_barbell'
        and observed_set.performance_result->'load_kg'=pw.dose->'task'->'external_load_kg') then
      raise exception 'Apoyo publicado sin ejecución con carga registrada'; end if;
 if iteration<4""")
if args.automatic_support:
    tail = tail.replace(' if iteration<4', """
 if not exists(select 1 from public.performance_week_work pw join public.preparation_week_decisions wd on wd.id=pw.decision_id
   where wd.preparation_goal_id=g and pw.dose->'task'->>'exercise_code'='bench_press_barbell'
    and pw.dose->'task'->>'policy_version'='support_familiarization_v1'
    and not pw.dose->'task' ? 'external_load_kg') then raise exception 'No publica familiarización sin inventar kilos'; end if;
 if not exists(select 1 from public.performance_week_work pw join public.preparation_week_decisions wd on wd.id=pw.decision_id
   where wd.preparation_goal_id=g and pw.dose->'task'->>'exercise_code'='bench_press_barbell'
    and pw.dose->'task'->>'policy_version'='performance_v3'
    and pw.dose->'task'->>'external_load_kg'='40') then raise exception 'No transforma registro guiado en apoyo personalizado'; end if;
 if not exists(select 1 from public.performance_training_references ref where ref.preparation_goal_id=g
   and ref.reference->'task'->>'exercise_code'='bench_press_barbell' and ref.reference->>'reference_kind'='performed_set'
   and ref.reference->'automatic_support'->'observation'->>'source'='execution') then raise exception 'Pierde origen real del apoyo'; end if;
 if exists(select 1 from public.performance_week_work pw join public.preparation_week_decisions wd on wd.id=pw.decision_id
   join public.performance_week_work prior_work on prior_work.reference_id=pw.reference_id
   join public.scheduled_workouts prior_schedule on prior_schedule.id=prior_work.scheduled_workout_id
   join public.workout_executions prior_execution on prior_execution.id=prior_schedule.execution_id
   join public.workout_execution_sets prior_set on prior_set.execution_id=prior_execution.id and prior_set.block_order=prior_work.block_order
   where wd.preparation_goal_id=g and pw.dose->'task'->>'policy_version'='support_familiarization_v1'
    and public.workout_performed_on_v1(prior_execution) between wd.week_start-14 and wd.week_start-1
    and prior_set.status='completed' and prior_set.performance_result->>'technique_valid'='true'
    and prior_set.performance_result->>'conditions_confirmed'='true' and prior_set.performance_result->>'tolerated'='true'
    and prior_set.performance_result->>'stop_reason'='none' and (prior_set.performance_result->>'rir')::numeric>=2
    and (prior_set.performance_result->>'load_kg')::numeric>0) then raise exception 'Repite práctica teniendo datos recientes'; end if;
 if iteration<4""")
    if args.support_result != 'complete':
        start = tail.index(" if not exists(select 1 from public.performance_week_work pw", tail.index("No publica familiarización"))
        end = tail.index(' if iteration<4', start)
        tail = tail[:start] + """
 if exists(select 1 from public.performance_training_references ref where ref.preparation_goal_id=g
   and ref.reference ? 'automatic_support' and ref.reference->>'reference_kind'='performed_set') then raise exception 'Inventa capacidad desde omisión o datos incompletos'; end if;
 if exists(select 1 from public.performance_week_work first_work join public.preparation_week_decisions first_week on first_week.id=first_work.decision_id
   join public.performance_week_work other_work on first_work.reference_id=other_work.reference_id
   join public.preparation_week_decisions other_week on other_week.id=other_work.decision_id
   where first_week.preparation_goal_id=g and first_work.dose->'task'->>'policy_version'='support_familiarization_v1'
    and other_work.dose->'task'->>'policy_version'='support_familiarization_v1' and other_week.week_start>first_week.week_start
    and other_week.week_start-first_week.week_start<21) then raise exception 'Repite práctica pendiente cada semana'; end if;
""" + tail[end:]
longitudinal = prefix + '\n loop\n iteration:=iteration+1;\n' + loop + tail
longitudinal = re.sub(r'\bcurrent_date\b', 'pg_temp.program_today()', longitudinal, flags=re.I)
longitudinal = re.sub(r'\bnow\(\)', 'pg_temp.program_now()', longitudinal, flags=re.I)
parts.append(longitudinal)
target = ROOT / f'build/adaptive-longitudinal-{args.months}{"-frequency-one" if args.initial_frequency_one else ""}{"-expanded" if args.expect_expanded_frequency else ""}{"-support" if args.with_support else ""}{"-automatic-support" if args.automatic_support else ""}{"-" + args.support_result if args.support_result != "complete" else ""}{"-focus-push" if args.focus_push else ""}.sql'
target.parent.mkdir(parents=True, exist_ok=True)
target.write_text('\n\n'.join(parts), encoding='utf-8')
print(target)
