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
parser.add_argument('--months', type=int, choices=[1, 2, 3, 4, 6, 12], default=6)
args = parser.parse_args()
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
create temp table adaptive_trajectory(week_start date,status text,running_count int,performance_count int,reviewed boolean);
""")
fixture = (ROOT / 'supabase/tests/adaptive_program_lifecycle.sql').read_text(encoding='utf-8-sig')
marker = ' for s in select sw.id,sw.scheduled_date'
prefix = fixture[:fixture.index(marker)]
prefix = re.sub(r'^begin;\s*', '', prefix)
prefix = prefix.replace('(select user_id::text from public.admin_permissions limit 1)', "current_setting('entrenaop.fixture_user')")
prefix = prefix.replace('p jsonb; again jsonb;', 'iteration int:=0; renewed boolean; renewed_count int:=0; p jsonb; again jsonb;')
prefix = prefix.replace('current_date+90', f"(current_date+interval '{args.months} months')::date")
prefix = prefix.replace("now()+interval '1 day'", "now()+interval '2 years'")
loop = fixture[fixture.index(marker):fixture.index(' if (select count(*) from public.preparation_week_decisions where preparation_goal_id=g)<>2')]
loop = loop.replace("   if (select count(*) from public.preparation_week_decisions where preparation_goal_id=g)<>1 then raise exception 'Adapta antes de cerrar todas las sesiones'; end if;", "   update adaptive_clock set value=s.scheduled_date+time '12:00';")
loop = loop.replace("   perform public.finish_workout_execution(e,6,null,null,null,'manual');", "   perform public.finish_workout_observed_idempotent(gen_random_uuid(),e,6,now(),0);")
loop = re.sub(r'   -- Fechas sintéticas.*?where id=e;\n', '', loop, flags=re.S)
tail = """
  renewed:=false;
  -- Se conserva la caducidad y se comprueba su salida de revisión. Solo este
  -- deportista simulado confirma explícitamente el contexto o aporta un control.
  if (select status='needs_review' from public.adaptive_program_states where preparation_goal_id=g) then
   if (select observed_at<now()-interval '30 days' from public.performance_training_contexts where user_id=auth.uid())
     or (select updated_at::date<current_date-30 or health_observed_at::date<current_date-30 from public.running_intake_contexts where preparation_goal_id=g) then
    perform public.save_performance_context('{"1":60,"3":60,"5":60}',array['cones','tennis_ball','chalk','measuring_tape'],false,true);
    update public.running_intake_contexts set updated_at=now(),health_observed_at=now(),recent_weeks_end_on=current_date-extract(isodow from current_date)::int,
     running_days_last_four_weeks=array(select (select count(distinct public.workout_performed_on_v1(exe))::int
       from public.workout_executions exe where exe.user_id=auth.uid() and exe.status='completed'
         and public.workout_performed_on_v1(exe) between current_date-extract(isodow from current_date)::int-6-n*7 and current_date-extract(isodow from current_date)::int-n*7
         and exists(select 1 from public.workout_execution_sets rs where rs.execution_id=exe.id and rs.block_format='running' and rs.status='completed'))
       from generate_series(0,3) n order by n),
     running_minutes_last_four_weeks=array(select (select coalesce(ceil(sum(rs.actual_duration_seconds+coalesce(rs.actual_recovery_duration_seconds,0))/60.0),0)::int
       from public.workout_executions exe join public.workout_execution_sets rs on rs.execution_id=exe.id
       where exe.user_id=auth.uid() and exe.status='completed' and rs.block_format='running' and rs.status='completed'
         and public.workout_performed_on_v1(exe) between current_date-extract(isodow from current_date)::int-6-n*7 and current_date-extract(isodow from current_date)::int-n*7)
       from generate_series(0,3) n order by n) where preparation_goal_id=g;
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
  insert into adaptive_trajectory select wk,ps.status,jsonb_array_length(wd.decision->'running'->'sessions'),jsonb_array_length(wd.decision->'sessions'),renewed
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
select count(*) weeks,count(*) filter(where reviewed) reviewed_weeks,max(running_count) maximum_runs,max(performance_count) maximum_performance_days from adaptive_trajectory;
rollback;
"""
longitudinal = prefix + '\n loop\n iteration:=iteration+1;\n' + loop + tail
longitudinal = re.sub(r'\bcurrent_date\b', 'pg_temp.program_today()', longitudinal, flags=re.I)
longitudinal = re.sub(r'\bnow\(\)', 'pg_temp.program_now()', longitudinal, flags=re.I)
parts.append(longitudinal)
target = ROOT / f'build/adaptive-longitudinal-{args.months}.sql'
target.parent.mkdir(parents=True, exist_ok=True)
target.write_text('\n\n'.join(parts), encoding='utf-8')
print(target)
