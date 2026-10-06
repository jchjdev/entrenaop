"""Verifica alcance, pausa y fronteras existentes con una cuenta ficticia y ROLLBACK."""
from pathlib import Path
import argparse
import re

root = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument('--installed', action='store_true')
args = parser.parse_args()
parts = ['begin;']
if not args.installed:
    source = (root / 'supabase/migrations/20261004012000_program_pause_and_training_scope.sql').read_text(encoding='utf-8-sig')
    source = re.sub(r'(?im)^begin;\s*', '', source, count=1)
    parts.append(re.sub(r'commit;\s*$', '', source))
parts.append("""
do $$ declare u uuid; begin
 insert into auth.users(id,email) values(gen_random_uuid(),'program-modes-preflight@example.invalid') returning id into u;
 insert into public.admin_permissions(user_id,reason) values(u,'Fixture transaccional');
 perform set_config('entrenaop.fixture_user',u::text,true);
end $$;
create temp table program_mode_verification(test text);
""")
for name in ['program_pause_and_training_scope', 'program_scope_follow_through', 'program_updates_and_trial_reset',
             'preparation_week_revisions', 'adaptive_program_lifecycle', 'adaptive_program_recovery',
             'performance_v2_acceptance_examples', 'running_engine_v5_regressions', 'running_engine_v5_horizons']:
    source = (root / f'supabase/tests/{name}.sql').read_text(encoding='utf-8-sig')
    assert re.search(r'rollback;\s*$', source, re.I), name
    source = re.sub(r'(?im)^begin;\s*', '', source, count=1)
    source = re.sub(r'rollback;\s*$', '', source, flags=re.I)
    source = source.replace('(select user_id::text from public.admin_permissions limit 1)', "current_setting('entrenaop.fixture_user')")
    parts += ['savepoint fixture;', source, 'rollback to savepoint fixture;',
              f"insert into program_mode_verification values ('{name}');"]
parts += ['select * from program_mode_verification;', 'rollback;']
target = root / 'build/program-modes-regressions.sql'
target.parent.mkdir(exist_ok=True)
target.write_text('\n'.join(parts), encoding='utf-8')
print(target)
