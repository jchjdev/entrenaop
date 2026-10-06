"""Verifica el recorrido del programa en una transacción sin dejar datos."""
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
    for name in ['20261004007000_common_running_controls', '20261004008000_adaptive_program_lifecycle', '20261004009000_need_based_performance_review']:
        source = (root / f'supabase/migrations/{name}.sql').read_text(encoding='utf-8-sig')
        source = re.sub(r'(?im)^begin;\s*', '', source, count=1)
        parts.append(re.sub(r'commit;\s*$', '', source))
parts.append('create temp table program_verification(test text);')
for name in ['need_based_performance_review', 'adaptive_program_lifecycle', 'adaptive_program_recovery', 'preparation_week_integration', 'preparation_week_revisions']:
    source = (root / f'supabase/tests/{name}.sql').read_text(encoding='utf-8-sig')
    assert re.search(r'rollback;\s*$', source, re.I), name
    source = re.sub(r'(?im)^begin;\s*', '', source, count=1)
    source = re.sub(r'rollback;\s*$', '', source, flags=re.I)
    parts += ['savepoint fixture;', source, 'rollback to savepoint fixture;', f"insert into program_verification values ('{name}');"]
parts += ['select * from program_verification;', 'rollback;']
target = Path(tempfile.gettempdir()) / 'entrenaop-program-preflight.sql'
target.write_text('\n'.join(parts), encoding='utf-8')
print(target)
