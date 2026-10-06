"""Contrato v3 y fronteras de carrera/ciclo, con usuarios ficticios y ROLLBACK."""
from pathlib import Path
import argparse
import re

root = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument('--installed', action='store_true')
args = parser.parse_args()

def body(source):
    return re.sub(r'(?:commit|rollback);\s*$', '', re.sub(r'(?im)^begin;\s*', '', source, count=1), flags=re.I)

parts = ['begin;', "create temp table running_v5_before as select oid,md5(pg_get_functiondef(oid)) fingerprint from pg_proc where pronamespace='public'::regnamespace and proname in ('running_plan_v5','calculate_running_week_constrained');"]
if not args.installed:
    parts.append(body((root/'supabase/migrations/20261006000000_performance_strategies_and_phases.sql').read_text(encoding='utf-8-sig')))
parts.append("""
do $$ declare u uuid; begin
 insert into auth.users(id,email) values(gen_random_uuid(),'performance-v3-preflight@example.invalid') returning id into u;
 insert into public.admin_permissions(user_id,reason) values(u,'Fixture transaccional');
 perform set_config('entrenaop.fixture_user',u::text,true);
end $$;
create temp table performance_v3_verification(test text);
""")
for name in ['performance_strategies_v3', 'performance_warm_up_neutrality_v3', 'program_pause_and_training_scope', 'program_scope_follow_through',
             'adaptive_program_lifecycle', 'adaptive_program_recovery', 'preparation_week_revisions',
             'program_updates_and_trial_reset', 'need_based_performance_review',
             'performance_v2_acceptance_examples', 'running_engine_v5_regressions', 'running_engine_v5_horizons']:
    source = body((root/f'supabase/tests/{name}.sql').read_text(encoding='utf-8-sig'))
    source = source.replace('(select user_id::text from public.admin_permissions limit 1)', "current_setting('entrenaop.fixture_user')")
    parts += ['savepoint fixture;', source, 'rollback to savepoint fixture;', f"insert into performance_v3_verification values ('{name}');"]
parts += ["""do $$ begin
 if exists(select 1 from running_v5_before where fingerprint<>md5(pg_get_functiondef(oid))) then raise exception 'Modifica carrera v5 o su adaptador'; end if;
end $$;""", 'select * from performance_v3_verification;', 'rollback;']
target = root/'build/performance-v3-regressions.sql'
target.parent.mkdir(exist_ok=True)
target.write_text('\n'.join(parts), encoding='utf-8')
print(target)
