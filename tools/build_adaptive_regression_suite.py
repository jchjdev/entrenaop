"""Ensaya funciones instaladas o una migración pendiente; nunca deja datos.

No carga versiones antiguas por defecto. Cada fixture vive en su savepoint y
el SQL completo termina en ROLLBACK, incluidas las redefiniciones opcionales.
"""
import argparse
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument('--migration', type=Path)
parser.add_argument('--output', type=Path, default=ROOT / 'build/adaptive-regression-suite.sql')
parser.add_argument('tests', nargs='+')
args = parser.parse_args()


def body(source, end):
    source = re.sub(r'(?im)^begin;\s*', '', source, count=1)
    return re.sub(r'(?i)' + end + r';\s*$', '', source)


parts = ['begin;']
if args.migration:
    parts.append(body(args.migration.read_text(encoding='utf-8-sig'), 'commit'))
parts.append('create temp table adaptive_verification (test text);')
parts.append("""
do $$ declare u uuid:=gen_random_uuid(); begin
 insert into auth.users(id,email) values(u,'adaptive-regression@example.invalid');
 insert into public.admin_permissions(user_id,reason) values(u,'Fixture transaccional de evidencias');
 perform set_config('entrenaop.fixture_user',u::text,true);
end $$;
""")
for name in args.tests:
    assert re.fullmatch(r'[a-z0-9_]+', name), name
    source = (ROOT / f'supabase/tests/{name}.sql').read_text(encoding='utf-8-sig')
    source = source.replace('(select user_id::text from public.admin_permissions limit 1)',
                            "current_setting('entrenaop.fixture_user')")
    parts += ['savepoint fixture;', body(source, 'rollback'),
              'rollback to savepoint fixture;', f"insert into adaptive_verification values ('{name}');"]
parts += ['select jsonb_agg(test) passed from adaptive_verification;', 'rollback;']
args.output.parent.mkdir(parents=True, exist_ok=True)
args.output.write_text('\n\n'.join(parts) + '\n', encoding='utf-8')
print(args.output)
