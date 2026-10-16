"""Ensaya funciones instaladas o una migración pendiente; nunca deja datos.

No carga versiones antiguas por defecto. Cada fixture vive en su savepoint y
el SQL completo termina en ROLLBACK, incluidas las redefiniciones opcionales.
"""
import argparse
import ast
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument('--migration', type=Path)
parser.add_argument('--additional-running-v6-horizons', action='store_true',
                    help='Repetir también los mismos oráculos longitudinales de v5 con v6')
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
    prefix=[]
    if '-- fixture-clock: adaptive_clock' in source:
        # Reutilizar el reloj del ensayo completo sin importar psycopg ni abrir
        # otra conexión. La fixture debe avanzar por fechas reales de ejecución.
        module=ast.parse((ROOT/'tools/simulate_fas_six_month_case.py').read_text(encoding='utf8'))
        clock=next(ast.literal_eval(n.value) for n in module.body if isinstance(n,ast.Assign)
                   and any(isinstance(t,ast.Name) and t.id=='CLOCK' for t in n.targets))
        source=re.sub(r'\bcurrent_date\b','pg_temp.program_today()',source,flags=re.I)
        source=re.sub(r'\bnow\(\)', 'pg_temp.program_now()',source,flags=re.I)
        prefix=[clock,'grant select,update on adaptive_clock to authenticated;']
    parts += ['savepoint fixture;', *prefix, body(source, 'rollback'),
              'rollback to savepoint fixture;', f"insert into adaptive_verification values ('{name}');"]
if args.additional_running_v6_horizons:
    source = (ROOT / 'supabase/tests/running_engine_v5_horizons.sql').read_text(encoding='utf-8-sig')
    assert 'public.running_plan_v5(' in source
    source = source.replace('public.running_plan_v5(', 'public.running_plan_v6(')
    parts += ['savepoint fixture;', body(source, 'rollback'),
              'rollback to savepoint fixture;',
              "insert into adaptive_verification values ('running_engine_v6_horizons');"]
parts += ['select jsonb_agg(test) passed from adaptive_verification;', 'rollback;']
args.output.parent.mkdir(parents=True, exist_ok=True)
args.output.write_text('\n\n'.join(parts) + '\n', encoding='utf-8')
print(args.output)
