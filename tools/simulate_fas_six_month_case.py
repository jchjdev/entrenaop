"""Ensayo solicitado: cuatro pruebas, seis meses y cuatro días disponibles.

Ejecuta los RPC instalados de DESARROLLO dentro de una conexión/transacción
única y termina siempre con ROLLBACK. Las capacidades y los resultados son
ficciones explícitas, nunca predicciones del motor. No modifica su política.
Requiere psycopg 3 (solo herramienta de ensayo, no dependencia de Flutter).
Las credenciales efímeras del CLI permanecen en memoria y no se imprimen.
"""
from __future__ import annotations

import argparse
from datetime import date, timedelta
import json
import os
from pathlib import Path
import re
import shlex
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'build/simulation-python'))
import psycopg

AVAILABILITY = {'1': 60, '3': 75, '5': 60, '6': 75}
EQUIPMENT = ['cones', 'measuring_tape', 'tennis_ball', 'chalk', 'bench', 'barbell', 'plates']
# Trayectoria hipotética favorable, con dos mesetas. No se escribe como
# resultado de test semanal ni se utiliza para modificar prescripciones.
PUSH = [10,11,12,14,16,18,19,19,21,24,26,28,30,32,34,36,38,40,42,44,45,47,48,49,50,50]
PLANK = [80,86,92,100,108,118,126,126,138,148,158,166,176,185,192,200,208,215,222,228,232,236,238,240,240,240]


def connect(cli):
    ref = (ROOT / 'supabase/.temp/project-ref').read_text().strip()
    if ref != 'sxbxfjqgoddzhtcyhalw':
        raise RuntimeError('Este ensayo solo admite el proyecto de desarrollo comprobado.')
    result = subprocess.run([cli, 'db', 'dump', '--linked', '--dry-run'], cwd=ROOT,
                            capture_output=True, text=True, timeout=60)
    if result.returncode:
        raise RuntimeError('El CLI no pudo obtener una conexión temporal; salida omitida por seguridad.')
    values = {k: shlex.split(v)[0] for k, v in re.findall(r'^export (PG[A-Z_]+)=(.*)$', result.stdout, re.M)}
    return psycopg.connect(host=values['PGHOST'], port=values['PGPORT'], user=values['PGUSER'],
                          password=values['PGPASSWORD'], dbname=values['PGDATABASE'], sslmode='require',
                          connect_timeout=20, autocommit=False)


CLOCK = r"""
set local role postgres;
set local statement_timeout='120s';
set local lock_timeout='10s';
create temp table adaptive_clock(value timestamptz);
insert into adaptive_clock values('2026-10-19 08:00:00+00');
create function pg_temp.program_now() returns timestamptz language sql stable as $$ select value from adaptive_clock $$;
create function pg_temp.program_today() returns date language sql stable as $$ select pg_temp.program_now()::date $$;
do $$ declare f record; definition text; begin
 for f in select n.nspname,c.relname,a.attname from pg_attrdef d
   join pg_class c on c.oid=d.adrelid join pg_namespace n on n.oid=c.relnamespace
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
end $$;
"""

SETUP = r"""
do $$ declare u uuid:=gen_random_uuid(); g uuid; a uuid; ref uuid; p jsonb; begin
 insert into auth.users(id,email) values(u,'fas-six-month-request@example.invalid');
 perform set_config('request.jwt.claim.sub',u::text,true);
 perform set_config('entrenaop.fixture_user',u::text,true);
 update public.profiles set fecha_nacimiento='1996-01-01' where id=u;
 insert into public.pro_access_grants(user_id,source,starts_at,ends_at,reason)
 values(u,'development_manual','2026-01-01','2028-01-01','Ensayo ficticio con ROLLBACK');
 insert into public.preparation_goals(user_id,program_id,target_date)
 values(u,'fas_periodic_assessment','2027-04-19') returning id into g;
 perform set_config('entrenaop.fixture_goal',g::text,true);
 insert into public.fas_periodic_assessments(user_id,preparation_goal_id,catalog_version,category,age_at_assessment,age_band,is_pre_effective_reference)
 values(u,g,'es_def_15_2026_periodic_2027_v1','men',30,'26_30',true) returning id into a;
 insert into public.fas_periodic_marks(assessment_id,test_id,value) values(a,'run_2000_m',595000);
 insert into public.running_reference_selections(preparation_goal_id,reference_source,reference_record_id)
 values(g,'fasPeriodicAssessment',a::text);
 insert into public.running_intake_contexts(preparation_goal_id,context_version,available_minutes_by_weekday,
  reserved_strength_weekdays,running_days_last_four_weeks,running_minutes_last_four_weeks,recent_weeks_end_on,
  reports_pain,requires_professional_review,health_observed_at,comfortable_continuous_minutes,target_2k_seconds,goal_mode)
 values(g,'running_initial_context_v3','{"1":60,"3":75,"5":60,"6":75}','{}',array[2,2,2,2],array[50,55,60,60],
  '2026-10-18',false,false,pg_temp.program_now(),30,500,'time');
 perform public.save_performance_context('{"1":60,"3":75,"5":60,"6":75}',
  array['cones','measuring_tape','tennis_ball','chalk','bench','barbell','plates'],false,true);
 ref:=public.save_performance_reference(g,jsonb_build_object('goal_code','push_up_standard','goal_version',1,
  'goal_measurement','REPS_IN_TIME','program_objective_key','legacy:upper_body_push_ups_2_min',
  'task','{"exercise_code":"push_up_standard","exercise_version":1,"protocol_key":"floor_v1","protocol_version":1,"setup_key":"Suelo y recorrido completo","measurement":"REPS","load_mode":"bodyweight","target_value":7,"target_rir":3,"intent":"work"}'::jsonb,
  'reference_kind','repeated_work','targets','[7,6]'::jsonb,'observed_on','2026-10-18','current_capacity_confirmed',true,
  'reported_rir',3,'rest_seconds',120,'frequency',2));
 perform public.save_performance_reference(g,jsonb_build_object('goal_code','front_plank_forearms','goal_version',1,
  'goal_measurement','DURATION','program_objective_key','legacy:abdominal_plank',
  'task','{"exercise_code":"front_plank_forearms","exercise_version":1,"protocol_key":"def_15_2026_plank","protocol_version":1,"setup_key":"Suelo antideslizante y codos bajo hombros","measurement":"DURATION","load_mode":"bodyweight","target_value":50,"intent":"work"}'::jsonb,
  'reference_kind','repeated_work','targets','[50,45]'::jsonb,'observed_on','2026-10-18','current_capacity_confirmed',true,
  'reported_rpe',7,'rest_seconds',90,'frequency',2));
 perform public.save_performance_reference(g,jsonb_build_object('goal_code','slalom_ball_course_16m','goal_version',1,
  'goal_measurement','TIME_FOR_COURSE','program_objective_key','legacy:agility_speed_circuit','equipment_confirmed',true,
  'task','{"exercise_code":"slalom_ball_course_16m","exercise_version":1,"protocol_key":"def_15_2026_agility","protocol_version":1,"setup_key":"Siete conos y corredor medido de 16 por 2 metros","measurement":"TIME_FOR_COURSE","load_mode":"bodyweight","target_value":14.3,"intent":"practice"}'::jsonb,
  'reference_kind','repeated_work','targets','[14.3,14.5]'::jsonb,'observed_on','2026-10-18','current_capacity_confirmed',true,
  'rest_seconds',180,'frequency',1));
 perform public.save_adaptive_program_preferences(g,'2027-04-19',
  '{"legacy:upper_body_push_ups_2_min":{"measurement":"REPS_IN_TIME","value":50},"legacy:abdominal_plank":{"measurement":"DURATION","value":240},"legacy:agility_speed_circuit":{"measurement":"TIME_FOR_COURSE","value":12.5}}');
end $$;
"""

EXECUTE_WEEK = r"""
do $$ declare s record; es record; e uuid; r jsonb; v numeric; rir int; cap numeric;
 g uuid:=current_setting('entrenaop.fixture_goal')::uuid;
 wk date:=current_setting('entrenaop.case_week')::date;
 i int:=current_setting('entrenaop.case_index')::int;
 push_cap int:=current_setting('entrenaop.push_cap')::int;
 plank_cap int:=current_setting('entrenaop.plank_cap')::int;
begin
 for s in select sw.id,sw.scheduled_date,rs.prescription->>'family' running_family
   from public.scheduled_workouts sw left join public.running_week_sessions rs on rs.scheduled_workout_id=sw.id
   where sw.preparation_goal_id=g and sw.scheduled_date between wk and wk+6 and sw.status='planned'
   order by sw.scheduled_date loop
  update adaptive_clock set value=s.scheduled_date+time '12:00';
  e:=public.start_scheduled_workout(s.id);
  for es in select * from public.workout_execution_sets where execution_id=e order by block_order,set_order loop
   if es.block_format='running' then
    perform public.complete_workout_set(es.id,
     p_actual_duration_seconds=>coalesce(es.target_duration_seconds,ceil(es.target_distance_meters*es.target_pace_max_seconds_per_km/1000.0)::int),
     p_actual_distance_meters=>coalesce(es.target_distance_meters,es.target_duration_seconds*1000.0/coalesce(es.target_pace_max_seconds_per_km,420)),
     p_actual_recovery_duration_seconds=>es.recovery_duration_seconds,
     p_actual_rpe=>case when es.target_pace_max_seconds_per_km is null then 3
       when s.running_family='E' then case when i=7 then 6 else 4 end else 6 end);
   elsif es.performance_prescription is null then
    perform public.complete_workout_set(es.id,p_actual_duration_seconds=>es.target_duration_seconds);
   else
    v:=(es.performance_prescription->>'target_value')::numeric;
    rir:=3;
    if es.performance_prescription->>'exercise_code'='push_up_standard' then
     -- No se registran cincuenta repeticiones porque esa sea la meta: cada
     -- serie sigue su pauta y está limitada por la capacidad ficticia del día.
     v:=least(v,greatest(1,push_cap-3-greatest(0,es.set_order-1)));
     rir:=least(10,greatest(0,push_cap-v-greatest(0,es.set_order-1)));
    elsif es.performance_prescription->>'exercise_code'='front_plank_forearms' then
     v:=least(v,floor(plank_cap*0.75));
    elsif es.performance_prescription->>'exercise_code'='slalom_ball_course_16m'
       and es.performance_prescription->>'measurement'='TIME_FOR_COURSE' then
     v:=greatest(14.0-1.5*i/25.0,coalesce(v,14.3)*0.99);
    end if;
    r:=jsonb_build_object('value',case when es.performance_prescription->>'measurement'<>'PASS_FAIL' then v end,
     'succeeded',case when es.performance_prescription->>'measurement'='PASS_FAIL' then true end,
     'load_kg',case when es.performance_prescription->>'policy_version'='support_familiarization_v1'
       and es.performance_prescription->>'load_mode'='external_load' then '20'::jsonb else es.performance_prescription->'external_load_kg' end,
     'body_mass_kg',es.performance_prescription->'body_mass_kg',
     'rir',case when es.performance_prescription->>'effort_mode'='rir' then rir end,
     'rpe',case when es.performance_prescription->>'effort_mode'='rpe' then
       case when es.performance_prescription->>'exercise_code'='front_plank_forearms'
         then greatest(3,least(8,round(v/plank_cap*10)::int)) else 6 end end,
     'technique_valid',true,'conditions_confirmed',true,'tolerated',true,'stop_reason','none');
    perform public.complete_performance_set_idempotent(gen_random_uuid(),es.id,r);
   end if;
  end loop;
  -- El esfuerzo fácil sigue siendo fácil también en una sesión sin fuerza;
  -- no utilizar el RPE global 6 para todos los rodajes del deportista ficticio.
  update adaptive_clock set value=s.scheduled_date+time '13:00';
  perform public.finish_workout_observed_idempotent(gen_random_uuid(),e,
    case when s.running_family='E' then 4 else 6 end,pg_temp.program_now(),0);
 end loop;
end $$;
"""


def one(c, query, params=()):
    return c.execute(query, params).fetchone()[0]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--cli', default=os.environ.get('SUPABASE_CLI', 'supabase'))
    parser.add_argument('--output', type=Path, default=ROOT / 'build/fas-six-month-case.json')
    parser.add_argument('--weeks', type=int, default=26)
    parser.add_argument('--migration',type=Path,help='Ensayar una migración pendiente sin aplicarla permanentemente')
    args = parser.parse_args()
    if not 1 <= args.weeks <= 26:
        parser.error('--weeks debe estar entre 1 y 26')
    output = {'scenario': {'initial': {'run_seconds':595,'push_ups':10,'plank_seconds':80,'agility_seconds':14},
                          'target': {'run_seconds':500,'push_ups':50,'plank_seconds':240,'agility_seconds':12.5},
                          'availability':AVAILABILITY,'equipment_assumed':EQUIPMENT,
                          'start':'2026-10-19','exam':'2027-04-19',
                          'fictional_capacity_push':PUSH,'fictional_capacity_plank':PLANK},
              'weeks': [], 'events': [], 'rolled_back':False}
    c = connect(args.cli)
    original = one(c, "select md5(string_agg(p.oid::text||p.prosrc,'' order by p.oid)) from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.prokind='f'")
    try:
        if args.migration:
            c.execute('set local role postgres')
            source=args.migration.read_text(encoding='utf-8-sig')
            source=re.sub(r'(?im)^begin;\s*','',source,count=1)
            source=re.sub(r'(?i)commit;\s*$','',source)
            c.execute(source)
        c.execute(CLOCK)
        c.execute(SETUP)
        g = one(c, "select current_setting('entrenaop.fixture_goal')::uuid")
        output['setup'] = one(c, 'select public.get_preparation_training_setup(%s)', (g,))
        p = one(c, "select public.calculate_preparation_week(%s,'2026-10-19')", (g,))
        output['initial_preview'] = p
        if p['status'] != 'ready':
            output['blocked'] = p
            raise RuntimeError('La configuración inicial no se puede activar; revisar el JSON del ensayo.')
        c.execute("select public.activate_adaptive_program(%s,'2026-10-19',%s::jsonb)", (g,json.dumps(p)))
        for i in range(args.weeks):
            started = time.monotonic()
            wk = date(2026,10,19)+timedelta(days=7*i)
            p = one(c, 'select decision from public.preparation_week_decisions where preparation_goal_id=%s and week_start=%s and superseded_at is null', (g,wk))
            schedules = one(c, "select coalesce(jsonb_agg(to_jsonb(sw) order by scheduled_date),'[]') from public.scheduled_workouts sw where preparation_goal_id=%s and scheduled_date between %s and %s and status<>'cancelled'", (g,wk,wk+timedelta(days=6)))
            if not schedules:
                raise RuntimeError(f'Semana {i+1} sin entrenamientos')
            for s in schedules:
                assert str(date.fromisoformat(s['scheduled_date']).isoweekday()) in AVAILABILITY
            assert len(schedules)<=4
            c.execute("select set_config('entrenaop.case_week',%s,true),set_config('entrenaop.case_index',%s,true),set_config('entrenaop.push_cap',%s,true),set_config('entrenaop.plank_cap',%s,true)", (str(wk),str(i),str(PUSH[i]),str(PLANK[i])))
            c.execute(EXECUTE_WEEK)
            state = one(c, 'select to_jsonb(a) from public.adaptive_program_states a where preparation_goal_id=%s', (g,))
            if state['status']=='needs_review':
                output['events'].append({'week':i+1,'before':state})
                # Confirmación ficticia de salud/contexto. No modifica la carga
                # histórica: la siguiente pauta debe leer los registros reales.
                c.execute('select public.save_performance_context(%s::jsonb,%s,false,true)', (json.dumps(AVAILABILITY),EQUIPMENT))
                c.execute('update public.running_intake_contexts set updated_at=pg_temp.program_now(),health_observed_at=pg_temp.program_now() where preparation_goal_id=%s', (g,))
                running_age = one(c, "select (public.resolve_program_running_reference(%s)->>'completed_at')::timestamptz::date", (g,))
                # Al superar la ventana de revisión de 28 días, esta fixture
                # aporta un control. No implica bloqueo obligatorio a los 28
                # días ni se presenta como un test pautado por el motor.
                current = one(c, 'select pg_temp.program_today()')
                if running_age is None or (current-running_age).days>28:
                    mark = round(595-95*min(1,(i+1)/26))
                    control = one(c, 'insert into public.preparation_running_tests(user_id,preparation_goal_id,completed_at,duration_seconds,rpe) values(auth.uid(),%s,pg_temp.program_now(),%s,8) returning id', (g,mark))
                    c.execute("update public.running_reference_selections set reference_source='trainingControl',reference_record_id=%s where preparation_goal_id=%s", (str(control),g))
                    output['events'][-1]['manual_running_control_seconds']=mark
                c.execute('select public.advance_adaptive_program(%s)', (g,))
                state = one(c, 'select to_jsonb(a) from public.adaptive_program_states a where preparation_goal_id=%s', (g,))
                output['events'][-1]['after']=state
            executed = one(c, "select coalesce(jsonb_agg(jsonb_build_object('date',sw.scheduled_date,'block_order',es.block_order,'set_order',es.set_order,'format',es.block_format,'prescription',es.performance_prescription,'target_duration',es.target_duration_seconds,'target_distance',es.target_distance_meters,'target_pace_min',es.target_pace_min_seconds_per_km,'target_pace_max',es.target_pace_max_seconds_per_km,'actual_duration',es.actual_duration_seconds,'actual_distance',es.actual_distance_meters,'actual_rpe',es.actual_rpe,'result',es.performance_result) order by sw.scheduled_date,es.block_order,es.set_order),'[]') from public.scheduled_workouts sw join public.workout_execution_sets es on es.execution_id=sw.execution_id where sw.preparation_goal_id=%s and sw.scheduled_date between %s and %s", (g,wk,wk+timedelta(days=6)))
            output['weeks'].append({'number':i+1,'week_start':str(wk),'decision':p,'schedules':schedules,'executed':executed,'state_after':state,'seconds':round(time.monotonic()-started,2)})
            args.output.parent.mkdir(parents=True,exist_ok=True)
            args.output.write_text(json.dumps(output,ensure_ascii=False,indent=2,default=str),encoding='utf-8')
            print(f'Semana {i+1:02d}: {len(schedules)} días; {len(executed)} registros; estado {state["status"]}; {time.monotonic()-started:.1f}s',flush=True)
            if state['status']=='needs_review':
                output['blocked']=state
                break
        output['final_setup'] = one(c, 'select public.get_preparation_training_setup(%s)', (g,))
    except Exception as error:
        # El error SQL no contiene credenciales: las conexiones se abren fuera
        # de las sentencias y no se guarda la salida del CLI.
        output['error']=str(error)
        raise
    finally:
        c.rollback()
        output['rolled_back']=True
        restored = one(c, "select md5(string_agg(p.oid::text||p.prosrc,'' order by p.oid)) from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.prokind='f'")
        output['function_source_restored']=restored==original
        c.rollback()
        c.close()
        args.output.parent.mkdir(parents=True,exist_ok=True)
        args.output.write_text(json.dumps(output,ensure_ascii=False,indent=2,default=str),encoding='utf-8')


if __name__=='__main__':
    main()
