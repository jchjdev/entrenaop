"""Prueba cambios y reinicio de ensayos sin alterar registros de desarrollo."""
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
    source = (root / 'supabase/migrations/20261004011000_program_updates_and_trial_reset.sql').read_text(encoding='utf-8-sig')
    source = re.sub(r'(?im)^begin;\s*', '', source, count=1)
    parts.append(re.sub(r'commit;\s*$', '', source))
parts.append('create temp table program_update_verification(test text);')
for name in ['program_updates_and_trial_reset', 'preparation_week_revisions', 'adaptive_program_lifecycle', 'adaptive_program_recovery']:
    source = (root / f'supabase/tests/{name}.sql').read_text(encoding='utf-8-sig')
    assert re.search(r'rollback;\s*$', source, re.I), name
    source = re.sub(r'(?im)^begin;\s*', '', source, count=1)
    source = re.sub(r'rollback;\s*$', '', source, flags=re.I)
    parts += ['savepoint fixture;', source, 'rollback to savepoint fixture;', f"insert into program_update_verification values ('{name}');"]
parts += ['select * from program_update_verification;', 'rollback;']
target = Path(tempfile.gettempdir()) / 'entrenaop-program-updates-preflight.sql'
target.write_text('\n'.join(parts), encoding='utf-8')
print(target)
