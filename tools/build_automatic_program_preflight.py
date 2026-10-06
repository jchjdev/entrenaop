"""Regresión del recorrido automático y reloj aislado, todo con ROLLBACK."""
from pathlib import Path
import argparse
import re
import tempfile

root = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument('--installed', action='store_true')
args = parser.parse_args()
parts = ['begin;']
if not args.installed:
    sql = (root/'supabase/migrations/20261004010000_automatic_program_follow_through.sql').read_text(encoding='utf-8-sig')
    parts.append(re.sub(r'commit;\s*$', '', re.sub(r'(?im)^begin;\s*', '', sql, count=1)))
parts.append('create temp table automatic_program_verification(test text);')
parts.append('create temp table automatic_program_trace(week_start date, state text, work jsonb);')
for name in ['adaptive_program_lifecycle', 'adaptive_program_recovery', 'preparation_week_integration', 'preparation_week_revisions']:
    sql = (root/f'supabase/tests/{name}.sql').read_text(encoding='utf-8-sig')
    sql = re.sub(r'rollback;\s*$', '', re.sub(r'(?im)^begin;\s*', '', sql, count=1), flags=re.I)
    parts += ['savepoint fixture;', sql, 'rollback to savepoint fixture;', f"insert into automatic_program_verification values ('{name}');"]

# Usa las funciones reales; solo sustituye el reloj durante esta transacción.
# No se crean flags, RPC de simulación ni fechas ficticias en la aplicación.
clock = '''
savepoint clock_fixture;
create function pg_temp.program_today() returns date language sql stable as $$
 select current_setting('test.program_now')::timestamptz::date
$$;
create function pg_temp.program_now() returns timestamptz language sql stable as $$
 select current_setting('test.program_now')::timestamptz
$$;
select set_config('test.program_now','2026-10-05 10:00:00+02',true);
do $$ declare f record; definition text; begin
 for f in select p.oid from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and p.prokind='f' and (p.prosrc ilike '%current_date%' or p.prosrc like '%now()%') loop
  definition:=pg_get_functiondef(f.oid);
  definition:=regexp_replace(definition,'\\mcurrent_date\\M','pg_temp.program_today()','gi');
  definition:=regexp_replace(definition,'\\mnow\\(\\)','pg_temp.program_now()','gi');
  execute definition;
 end loop;
end $$;
'''
fixture = (root/'supabase/tests/adaptive_program_lifecycle.sql').read_text(encoding='utf-8-sig')
start = fixture[:fixture.index(' for s in select sw.id,sw.scheduled_date')]
start = re.sub(r'^begin;\s*', '', start)
start = start.replace('p jsonb; again jsonb;', 'iteration int; initial_week date; p jsonb; again jsonb;')
loop = fixture[fixture.index(' for s in select sw.id,sw.scheduled_date'):fixture.index(' if (select count(*) from public.preparation_week_decisions where preparation_goal_id=g)<>2')]
loop = loop.replace("   if (select count(*) from public.preparation_week_decisions where preparation_goal_id=g)<>1 then raise exception 'Adapta antes de cerrar todas las sesiones'; end if;", "   perform set_config('test.program_now',(s.scheduled_date+time '12:00')::text,true);")
loop = loop.replace("   -- Fechas sintéticas separadas para comprobar dos exposiciones, no dos clics.\n   update public.workout_executions set completed_at=s.scheduled_date+time '12:00' where id=e;", '')
future_loop = loop.replace("   perform set_config('test.program_now',(s.scheduled_date+time '12:00')::text,true);", '')
longitudinal = start + '''
 initial_week:=wk;
 for iteration in 1..3 loop
  insert into automatic_program_trace select wk,'entrenamiento',
   (select jsonb_agg(jsonb_build_object('movement',x->>'name','outcome',x->>'outcome','targets',x->'dose'->'targets'))
    from jsonb_array_elements(decision->'proposals') x)
  from public.preparation_week_decisions where preparation_goal_id=g and week_start=wk and superseded_at is null;
''' + loop + '''
  if not exists(select 1 from public.preparation_week_decisions where preparation_goal_id=g and week_start=wk+7 and superseded_at is null) then
   raise exception 'Semana %: cerrar el entrenamiento no genera continuación: %',iteration,public.get_preparation_training_setup(g)->'program_state'; end if;
  perform public.refresh_adaptive_programs();
  perform public.refresh_adaptive_programs();
  if (select count(*) from public.preparation_week_decisions where preparation_goal_id=g and superseded_at is null)<>iteration+1 then
   raise exception 'La recuperación desde agenda duplica o pierde semanas'; end if;
  wk:=wk+7;
 end loop;
''' + future_loop + '''
 insert into automatic_program_trace select wk,continuation_code,jsonb_build_object('next_generation_on',next_generation_on)
 from public.adaptive_program_states where preparation_goal_id=g;
 if (select continuation_code from public.adaptive_program_states where preparation_goal_id=g)<>'waiting_date' then
  raise exception 'Completar por adelantado no explica la espera: %',public.get_preparation_training_setup(g)->'program_state'; end if;
 if exists(select 1 from public.preparation_week_decisions where preparation_goal_id=g and week_start=wk+7) then raise exception 'Encadena el futuro sin límite'; end if;
 perform set_config('test.program_now',(wk+time '10:00')::text,true);
 perform public.refresh_adaptive_programs();
 insert into automatic_program_trace select wk+7,continuation_code,jsonb_build_object('last_generated_week',last_generated_week)
 from public.adaptive_program_states where preparation_goal_id=g;
 if not exists(select 1 from public.preparation_week_decisions where preparation_goal_id=g and week_start=wk+7) then
  raise exception 'La agenda no recupera la generación al llegar la fecha: %',public.get_preparation_training_setup(g)->'program_state'; end if;
 -- La fecha real puede estar más allá de un año: no se inventa otra fecha.
 perform public.save_adaptive_program_preferences(g,'2029-03-12','{}');
 if (select target_date from public.preparation_goals where id=g)<>'2029-03-12'::date then raise exception 'Recorta el horizonte real'; end if;
 if has_function_privilege('anon','public.refresh_adaptive_programs()','execute') then raise exception 'Continuidad pública'; end if;
 perform set_config('request.jwt.claim.sub',gen_random_uuid()::text,true);
 if public.refresh_adaptive_programs()<>'[]'::jsonb then raise exception 'Expone programas ajenos'; end if;
end $$;
'''
longitudinal = re.sub(r'\bcurrent_date\b', 'pg_temp.program_today()', longitudinal, flags=re.I)
longitudinal = re.sub(r'\bnow\(\)', 'pg_temp.program_now()', longitudinal, flags=re.I)
parts += [clock, longitudinal,
          "insert into automatic_program_verification values ('tres semanas con reloj realista, adelanto, espera y recuperación desde agenda');",
          "select jsonb_build_object('tests',(select jsonb_agg(test) from automatic_program_verification),'trajectory',(select jsonb_agg(to_jsonb(t) order by week_start) from automatic_program_trace t)) as verification;",
          'rollback;']
target = Path(tempfile.gettempdir())/'entrenaop-automatic-program-preflight.sql'
target.write_text('\n'.join(parts), encoding='utf-8')
print(target)
