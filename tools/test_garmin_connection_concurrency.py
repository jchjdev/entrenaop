"""Concurrencia real Garmin: PostgreSQL local sintético, sin datos ni DSN externos."""
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
workspace = Path(tempfile.mkdtemp(prefix='garmin-account-pg-', dir=fixture_root)).resolve()
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
      create role anon nologin; create role authenticated nologin; create role service_role nologin;
      create schema auth; create schema device_private;
      create table auth.users(id uuid primary key,email text);
      create table auth.sessions(id uuid primary key,user_id uuid references auth.users(id) on delete cascade,not_after timestamptz);
      create table public.pro_gift_grants(user_id uuid references auth.users(id) on delete cascade,starts_at timestamptz default now(),ends_at timestamptz,reason text);
      create function public.has_pro_access(p_user uuid) returns boolean language sql stable as
      $$select exists(select 1 from public.pro_gift_grants where user_id=p_user and starts_at<=statement_timestamp() and (ends_at is null or ends_at>statement_timestamp()))$$;
      create table public.trainer_access(trainer_id uuid primary key references auth.users(id) on delete cascade,enabled boolean,client_limit integer,last_reason text,valid_until timestamptz);
      create table public.trainer_client_relations(trainer_id uuid references auth.users(id) on delete cascade,client_id uuid references auth.users(id) on delete cascade,accepted_at timestamptz default clock_timestamp(),ended_at timestamptz);
    """)
    db.query((root/'supabase/migrations/20261022113416_garmin_account_connection.sql').read_text(encoding='utf-8'))
    db.query((root/'supabase/tests/garmin_account_connection.sql').read_text(encoding='utf-8'))
    print('Correcto: migración real y contrato SQL con ROLLBACK.')

    def actor():
        owner,session=str(uuid.uuid4()),str(uuid.uuid4())
        db.query(f"insert into auth.users values('{owner}','fixture.invalid'); insert into auth.sessions(id,user_id) values('{session}','{owner}'); insert into public.pro_gift_grants(user_id) values('{owner}')")
        return owner,session
    def rpc(conn,action,owner=None,session=None,body=None):
        payload=json.dumps(body or {}).replace("'","''")
        o="null" if owner is None else f"'{owner}'"
        s="null" if session is None else f"'{session}'"
        return json.loads(conn.query(f"select public.garmin_account_command('{action}',{o},{s},'{payload}'::jsonb)")[0][0])
    def prepare():
        owner,session=actor(); state=uuid.uuid4().hex*2; claim=str(uuid.uuid4())
        snap=rpc(db,'begin',owner,session,dict(state_hash=state,verifier_cipher='fixture'))
        return owner,session,state,claim,snap['generation']
    def secret(generation,claim,identity=None):
        return dict(generation=generation,claim_id=claim,tokens_cipher='fixture-encrypted',
          access_expires_at='2099-01-01T00:00:00Z',refresh_expires_at='2099-02-01T00:00:00Z',
          garmin_user_id=identity or str(uuid.uuid4()),can_read=True,can_send=True)

    owner,session,state,claim,generation=prepare()
    def claim_once():
        conn=DB()
        try:
            try: rpc(conn,'claim',body=dict(state_hash=state,claim_id=str(uuid.uuid4()))); return True
            except SqlError as error:
                assert error.code=='42501',str(error); return False
        finally: conn.close()
    with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
        assert sum(pool.map(lambda _:claim_once(),range(2)))==1
    print('Correcto: dos callbacks concurrentes consumen exactamente un intento.')

    for isolation in ('read committed','repeatable read'):
        for disconnect_first in (False,True):
            owner,session,state,claim,generation=prepare()
            rpc(db,'claim',body=dict(state_hash=state,claim_id=claim))
            body=secret(generation,claim)
            rpc(db,'stash_grant',owner,body=body)
            first,second=DB(),DB()
            def finish_second():
                try:
                    if disconnect_first: rpc(second,'complete',owner,body=body)
                    else: rpc(second,'disconnect',owner,session,dict(generation=generation))
                    second.query('commit'); return True
                except SqlError as error:
                    second.query('rollback'); assert error.code=='40001',(isolation,str(error)); return False
            try:
                first.query(f'begin isolation level {isolation}')
                second.query(f'begin isolation level {isolation}')
                if disconnect_first: rpc(first,'disconnect',owner,session,dict(generation=generation))
                else: rpc(first,'complete',owner,body=body)
                with concurrent.futures.ThreadPoolExecutor(max_workers=1) as pool:
                    pending=pool.submit(finish_second)
                    time.sleep(0.1)
                    assert not pending.done(),'No observa bloqueo real de la fila'
                    first.query('commit')
                    finished=pending.result(timeout=10)
                if not finished:
                    if disconnect_first: rpc(db,'complete',owner,body=body)
                    else: rpc(db,'disconnect',owner,session,dict(generation=generation))
                assert rpc(db,'status',owner,session)['status']!='connected'
            finally:
                first.close();second.close()
    print('Correcto: callback/desconexión en ambos órdenes RC/RR; no resucita conexión.')

    identities=[prepare(),prepare()]
    for owner,session,state,claim,generation in identities:
        rpc(db,'claim',body=dict(state_hash=state,claim_id=claim))
        rpc(db,'stash_grant',owner,body=secret(generation,claim))
    shared_identity=str(uuid.uuid4())
    def bind_identity(entry):
        owner,session,state,claim,generation=entry;conn=DB()
        try:
            try: rpc(conn,'complete',owner,body=secret(generation,claim,shared_identity));return True
            except SqlError as error:
                assert error.code=='23505' and 'provider_account_in_use' in str(error),str(error);return False
        finally:conn.close()
    with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
        assert sum(pool.map(bind_identity,identities))==1
    print('Correcto: una identidad Garmin no queda asociada a dos cuentas concurrentes.')

    owner,session,state,claim,generation=identities[0]
    if rpc(db,'status',owner,session)['status']=='connected':
        rpc(db,'disconnect',owner,session,dict(generation=generation))
        def lease_once():
            conn=DB()
            try: return rpc(conn,'claim_revoke',owner,body=dict(lease_id=str(uuid.uuid4())))
            finally:conn.close()
        with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
            results=list(pool.map(lambda _:lease_once(),range(2)))
        assert sum('tokens_cipher' in result for result in results)==1
        print('Correcto: dos workers no reciben simultáneamente credenciales de revocación.')
finally:
    if db is not None:db.close()
    try:
        if started:command('pg_ctl','-D',data,'-m','immediate','-w','stop')
    finally:
        if workspace.is_relative_to(fixture_root) and workspace!=fixture_root and not workspace.is_symlink():
            shutil.rmtree(workspace)
