"""Contrato real de historial en PostgreSQL17 local desechable, sin DSN externo.

Instala solo la migración de dispositivos y un contexto Auth mínimo sintético.
La prueba SQL transaccional puede ejecutarse también contra Dev con ROLLBACK.
No acredita el resto de productos ni la integración con un iPhone.
"""
import argparse
import concurrent.futures
import ctypes
import json
import os
from pathlib import Path
import shutil
import socket
import subprocess
import sys
import tempfile
import time
import uuid

sys.stdout.reconfigure(encoding='utf-8')

parser = argparse.ArgumentParser()
parser.add_argument('--pg-bin', required=True, type=Path)
args = parser.parse_args()
root = Path(__file__).resolve().parents[1]
bin_dir = args.pg_bin.resolve()
if os.name == 'nt':
    dll_directory = os.add_dll_directory(str(bin_dir))
lib = ctypes.CDLL(str(bin_dir / ('libpq.dll' if os.name == 'nt' else 'libpq.so')))
for name, restype, argtypes in [
    ('PQconnectdb', ctypes.c_void_p, [ctypes.c_char_p]),
    ('PQstatus', ctypes.c_int, [ctypes.c_void_p]),
    ('PQerrorMessage', ctypes.c_char_p, [ctypes.c_void_p]),
    ('PQexec', ctypes.c_void_p, [ctypes.c_void_p, ctypes.c_char_p]),
    ('PQresultStatus', ctypes.c_int, [ctypes.c_void_p]),
    ('PQresultErrorField', ctypes.c_char_p, [ctypes.c_void_p, ctypes.c_int]),
    ('PQresultErrorMessage', ctypes.c_char_p, [ctypes.c_void_p]),
    ('PQntuples', ctypes.c_int, [ctypes.c_void_p]),
    ('PQnfields', ctypes.c_int, [ctypes.c_void_p]),
    ('PQgetvalue', ctypes.c_char_p, [ctypes.c_void_p, ctypes.c_int, ctypes.c_int]),
    ('PQclear', None, [ctypes.c_void_p]),
    ('PQfinish', None, [ctypes.c_void_p]),
]:
    method = getattr(lib, name)
    method.restype, method.argtypes = restype, argtypes

with socket.socket() as sock:
    sock.bind(('127.0.0.1', 0))
    port = sock.getsockname()[1]

class SqlError(Exception):
    def __init__(self, code, message):
        super().__init__(message)
        self.code = code

class DB:
    def __init__(self):
        self.conn = lib.PQconnectdb(f'host=127.0.0.1 port={port} user=postgres dbname=postgres connect_timeout=5'.encode())
        if lib.PQstatus(self.conn) != 0:
            raise RuntimeError(lib.PQerrorMessage(self.conn).decode())
        self.query("set client_min_messages='error'; set statement_timeout='15s'")
    def query(self, sql):
        result = lib.PQexec(self.conn, sql.encode())
        try:
            if lib.PQresultStatus(result) not in (1, 2):
                code = lib.PQresultErrorField(result, ord('C'))
                raise SqlError(code.decode() if code else '', lib.PQresultErrorMessage(result).decode())
            return [[lib.PQgetvalue(result, r, c).decode() for c in range(lib.PQnfields(result))]
                    for r in range(lib.PQntuples(result))]
        finally:
            lib.PQclear(result)
    def actor(self, owner):
        self.query(f"set role authenticated; select set_config('request.jwt.claim.sub','{owner}',false)")
    def close(self):
        lib.PQfinish(self.conn)

fixture_root = (root / '.dart_tool').resolve()
fixture_root.mkdir(exist_ok=True)
workspace = Path(tempfile.mkdtemp(prefix='running-history-pg-', dir=fixture_root)).resolve()
assert workspace.is_relative_to(fixture_root) and workspace != fixture_root
data = workspace / 'data'
flags = subprocess.CREATE_NO_WINDOW if os.name == 'nt' else 0
def command(name, *arguments):
    subprocess.run([str(bin_dir / name), *map(str, arguments)], check=True,
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, creationflags=flags)

started = False
db = None
try:
    command('initdb', '-D', data, '-U', 'postgres', '-A', 'trust', '--no-locale', '-E', 'UTF8')
    command('pg_ctl', '-D', data, '-l', workspace / 'postgres.log', '-w', 'start',
            '-o', f'-h 127.0.0.1 -p {port} -c max_connections=20')
    started = True
    db = DB()
    db.query("""
      create role anon nologin; create role authenticated nologin;
      create schema auth; create table auth.users(id uuid primary key,email text);
      create function auth.uid() returns uuid language sql stable as
      $$ select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid $$;
      grant usage on schema auth to authenticated,anon;
      grant execute on function auth.uid() to authenticated,anon;
      create table public.admin_permissions(user_id uuid primary key references auth.users(id) on delete cascade,reason text);
    """)
    db.query((root / 'supabase/migrations/20261021171215_device_running_history.sql').read_text(encoding='utf-8'))
    print('Correcto: migración real instalada en PostgreSQL local aislado.')
    smoke = root / 'supabase/tests/device_running_history.sql'
    if smoke.exists():
        db.query(smoke.read_text(encoding='utf-8'))
        print('Correcto: contrato SQL transaccional, permisos y regresiones.')

    # Dos conexiones SQL distintas compiten por el mismo namespace.
    owner = str(uuid.uuid4())
    db.query(f"insert into auth.users(id,email) values('{owner}','local-history.invalid')")
    def open_connection():
        worker = DB()
        try:
            worker.actor(owner)
            return json.loads(worker.query(f"select public.open_running_health_connection('{owner}','apple_health')")[0][0])
        finally:
            worker.close()
    with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
        connections = list(pool.map(lambda _: open_connection(), range(2)))
    assert connections[0]['id'] == connections[1]['id']
    print('Correcto: creación concurrente devuelve una conexión estable.')

    connection = connections[0]['id']
    base = dict(external_id=str(uuid.uuid4()), source_revision='synthetic-A',
                normalizer_version=1, started_at='2026-01-07T11:30:00.000000Z',
                ended_at='2026-01-07T12:00:00.000000Z', elapsed_micros=1800000000,
                timer_micros=1700000000, distance_meters=5000.125,
                expected_snapshot_hash=None)

    def save_sql(item, operation, channel_connection=connection):
        # Todos los identificadores y valores son fixtures generadas aquí.
        body = json.dumps([item]).replace("'", "''")
        return (f"select public.save_running_health_history('{owner}',"
                f"'{channel_connection}',0,'{operation}','{body}'::jsonb)")

    def contend(queries, repeatable=False, lock_parent=False):
        workers = [DB() for _ in queries]
        try:
            for worker in workers:
                worker.actor(owner)
                if repeatable:
                    worker.query('begin isolation level repeatable read')
                    worker.query('select txid_current_snapshot()')
            pids = [worker.query('select pg_backend_pid()')[0][0] for worker in workers]
            lock_table = 'auth.users' if lock_parent else 'device_private.history_limits'
            lock_column = 'id' if lock_parent else 'owner_id'
            db.query(f"begin; select 1 from {lock_table} where {lock_column}='{owner}' for update")
            with concurrent.futures.ThreadPoolExecutor(max_workers=len(workers)) as pool:
                def run(worker, query):
                    try:
                        rows = worker.query(query)
                        if repeatable:
                            worker.query('commit')
                        return rows
                    except SqlError:
                        worker.query('rollback')
                        raise
                futures = [pool.submit(run, worker, query) for worker, query in zip(workers, queries)]
                # Comprobar bloqueo real de ambas sesiones antes de soltar la cuota común.
                deadline = time.monotonic() + 5
                while True:
                    waiting = int(db.query(f"select count(*) from pg_stat_activity where pid in ({','.join(pids)}) and wait_event_type='Lock'")[0][0])
                    if waiting == len(workers):
                        break
                    if time.monotonic() > deadline:
                        db.query('rollback')
                        raise AssertionError('No se observó la contención esperada')
                    time.sleep(0.01)
                    db.query('select pg_stat_clear_snapshot()')
                db.query('commit')
                outcomes = []
                for future in futures:
                    try:
                        outcomes.append(json.loads(future.result()[0][0]))
                    except SqlError as error:
                        outcomes.append((error.code, str(error).strip()))
                return outcomes
        finally:
            db.query('rollback')
            for worker in workers:
                worker.close()

    operation = str(uuid.uuid4())
    outcomes = contend([save_sql(base, operation)] * 2)
    assert outcomes == [dict(inserted=1, updated=0, unchanged=0)] * 2, outcomes
    assert db.query(f"select activity_count,receipt_count from device_private.history_limits where owner_id='{owner}'")[0] == ['1', '1']
    print('Correcto: doble guardado concurrente con la misma orden no duplica ni consume cuota dos veces.')

    old_hash = db.query(f"select snapshot_hash from device_private.running_snapshots where connection_id='{connection}' and is_current")[0][0]
    candidates = [dict(base, source_revision=revision, distance_meters=distance,
                       expected_snapshot_hash=old_hash)
                  for revision, distance in [('synthetic-B', 5100.125), ('synthetic-C', 5200.125)]]
    outcomes = contend([save_sql(candidate, str(uuid.uuid4())) for candidate in candidates])
    assert sum(isinstance(outcome, dict) for outcome in outcomes) == 1, outcomes
    assert any(isinstance(outcome, tuple) and outcome[0] == '40001' and 'history_conflict' in outcome[1] for outcome in outcomes), outcomes
    assert db.query(f"select count(*),count(*) filter(where is_current) from device_private.running_snapshots where connection_id='{connection}'")[0] == ['2', '1']
    print('Correcto: dos revisiones compitiendo por el mismo head producen un éxito y un conflicto CAS.')

    db.actor(owner)
    other = json.loads(db.query(f"select public.open_running_health_connection('{owner}','health_connect')")[0][0])['id']
    db.query('reset role')
    extra = dict(base, external_id=str(uuid.uuid4()))
    encoded = json.dumps(extra).replace("'", "''")
    cost = int(db.query(f"""select octet_length((device_private.normalize_running_selection('{encoded}'::jsonb,'apple_health')->'snapshot')::text)
      +octet_length(jsonb_build_object('operation',gen_random_uuid(),'hash',repeat('a',64),
       'result',jsonb_build_object('inserted',1,'updated',0,'unchanged',0))::text)""")[0][0])
    db.query(f"update device_private.history_limits set max_logical_bytes=logical_bytes+{cost} where owner_id='{owner}'")
    outcomes = contend([save_sql(extra, str(uuid.uuid4()), current) for current in (connection, other)])
    assert sum(isinstance(outcome, dict) for outcome in outcomes) == 1, outcomes
    assert any(isinstance(outcome, tuple) and outcome[0] == 'P0001' and 'history_limit' in outcome[1] for outcome in outcomes), outcomes
    assert db.query(f"select logical_bytes=max_logical_bytes from device_private.history_limits where owner_id='{owner}'")[0][0] == 't'
    assert db.query(f"""select logical_bytes=1024+
      (select coalesce(sum(logical_bytes),0) from device_private.running_snapshots where owner_id='{owner}')+
      (select coalesce(sum(logical_bytes),0) from device_private.history_receipts where owner_id='{owner}')
      from device_private.history_limits where owner_id='{owner}'""")[0][0] == 't'
    print('Correcto: dos canales concurrentes comparten el presupuesto del propietario sin sobrepasarlo.')

    # RR tiene snapshot fijo: el perdedor recibe 40001 y debe repetir una nueva transacción.
    # El replay posterior sigue comprobando el recibo y nunca rehace efectos.
    owner = str(uuid.uuid4())
    db.query(f"insert into auth.users(id) values('{owner}')")
    query = f"select public.open_running_health_connection('{owner}','apple_health')"
    outcomes = contend([query, query], repeatable=True, lock_parent=True)
    assert sum(isinstance(item, dict) for item in outcomes) == 1, outcomes
    assert any(isinstance(item, tuple) and item[0] == '40001' for item in outcomes), outcomes
    connection = next(item['id'] for item in outcomes if isinstance(item, dict))
    assert open_connection()['id'] == connection
    assert db.query(f"select logical_bytes from device_private.history_limits where owner_id='{owner}'")[0][0] == '512'
    print('Correcto: namespace RR concurrente rechaza snapshot antiguo con 40001 y retry devuelve el único namespace.')
    db.actor(owner)
    other = json.loads(db.query(f"select public.open_running_health_connection('{owner}','health_connect')")[0][0])['id']
    db.query('reset role')
    operation = str(uuid.uuid4())
    queries = [save_sql(base, operation, connection)] * 2
    outcomes = contend(queries, repeatable=True)
    assert sum(isinstance(item, dict) for item in outcomes) == 1, outcomes
    assert any(isinstance(item, tuple) and item[0] == '40001' for item in outcomes), outcomes
    db.actor(owner)
    assert json.loads(db.query(queries[0])[0][0]) == dict(inserted=1, updated=0, unchanged=0)
    db.query('reset role')
    old_hash = db.query(f"select snapshot_hash from device_private.running_snapshots where connection_id='{connection}'")[0][0]
    queries = [save_sql(dict(candidate, expected_snapshot_hash=old_hash), str(uuid.uuid4()), connection) for candidate in candidates]
    outcomes = contend(queries, repeatable=True)
    assert sum(isinstance(item, dict) for item in outcomes) == 1, outcomes
    loser = next(i for i, item in enumerate(outcomes) if isinstance(item, tuple))
    assert outcomes[loser][0] == '40001', outcomes
    db.actor(owner)
    try:
        db.query(queries[loser])
        raise AssertionError('RR reintento perdió el CAS')
    except SqlError as error:
        assert error.code == '40001' and 'history_conflict' in str(error), str(error)
    db.query('reset role')
    db.query(f"update device_private.history_limits set max_logical_bytes=logical_bytes+{cost} where owner_id='{owner}'")
    queries = [save_sql(extra, str(uuid.uuid4()), current) for current in (connection, other)]
    outcomes = contend(queries, repeatable=True)
    assert sum(isinstance(item, dict) for item in outcomes) == 1, outcomes
    loser = next(i for i, item in enumerate(outcomes) if isinstance(item, tuple))
    assert outcomes[loser][0] == '40001', outcomes
    db.actor(owner)
    try:
        db.query(queries[loser])
        raise AssertionError('RR reintento rebasó cuota')
    except SqlError as error:
        assert error.code == 'P0001' and 'history_limit' in str(error), str(error)
    db.query('reset role')
    print('Correcto: RR rechaza snapshots obsoletos; reintentar conserva replay, CAS y presupuesto.')

    def wait_on_lock(pid):
        deadline = time.monotonic() + 5
        while db.query(f"select wait_event_type='Lock' from pg_stat_activity where pid={pid}")[0][0] != 't':
            if time.monotonic() > deadline:
                raise AssertionError('No se observó contención Auth')
            time.sleep(0.01)

    for isolation in ('read committed', 'repeatable read'):
        for delete_first in (False, True):
            victim = str(uuid.uuid4())
            db.query(f"insert into auth.users(id) values('{victim}')")
            opener, deleter = DB(), DB()
            try:
                opener.actor(victim)
                opener.query(f"select public.open_running_health_connection('{victim}','apple_health')")
                opener.query(f'begin isolation level {isolation}')
                # Fija snapshot RR anterior al borrado sin obtener aún el KEY SHARE.
                opener.query('select txid_current_snapshot()')
                deleter.query(f'begin isolation level {isolation}')
                open_query = f"select public.open_running_health_connection('{victim}','health_connect')"
                delete_query = f"delete from auth.users where id='{victim}'"
                first, second = (deleter, opener) if delete_first else (opener, deleter)
                first.query(delete_query if delete_first else open_query)
                second_pid = second.query('select pg_backend_pid()')[0][0]
                with concurrent.futures.ThreadPoolExecutor(max_workers=1) as pool:
                    pending = pool.submit(second.query, open_query if delete_first else delete_query)
                    try:
                        wait_on_lock(second_pid)
                    finally:
                        first.query('commit')
                    try:
                        pending.result()
                        assert not delete_first, 'Abrir recreó una cuenta ya borrada'
                        second.query('commit')
                    except SqlError as error:
                        second.query('rollback')
                        assert error.code in ('40001', '42501'), (isolation, delete_first, error.code, str(error))
                        # Un borrado RR también puede perder ante nuevas filas CASCADE: se reintenta.
                        if not delete_first:
                            deleter.query(delete_query)
                assert db.query(f"select count(*) from auth.users where id='{victim}'")[0][0] == '0'
                assert db.query(f"select count(*) from device_private.health_connections where owner_id='{victim}'")[0][0] == '0'
                assert db.query(f"select count(*) from device_private.history_limits where owner_id='{victim}'")[0][0] == '0'
            finally:
                opener.query('rollback')
                deleter.query('rollback')
                opener.close()
                deleter.close()
    print('Correcto: abrir segundo canal frente a borrado Auth, ambos órdenes RC/RR, sin deadlock ni resurrección.')

finally:
    if db is not None:
        db.close()
    try:
        if started:
            command('pg_ctl', '-D', data, '-m', 'immediate', '-w', 'stop')
    finally:
        # Ruta absoluta comprobada dentro de .dart_tool, exclusivamente creada por este ensayo.
        if workspace.is_relative_to(fixture_root) and workspace != fixture_root and not workspace.is_symlink():
            shutil.rmtree(workspace)
