"""Aceptaciones simultáneas sobre PostgreSQL 17 local y desechable.

Usa libpq y binarios nativos, sin paquetes Python. Nunca conecta a Dev/producción.
Las pruebas SQL de Dev terminan en ROLLBACK. Este ensayo local necesita COMMIT
entre conexiones para observar al ganador y rechazar al perdedor; destruye solo
su clúster temporal propio al terminar. Cada conexión se cierra con ROLLBACK.
Ejemplo Windows: python tools/test_trainer_concurrency.py --pg-bin C:/.../bin
"""
import argparse
import concurrent.futures
import ctypes
import json
import os
from pathlib import Path
import subprocess
import tempfile
import time
import uuid

parser = argparse.ArgumentParser()
parser.add_argument("--pg-bin", required=True, type=Path)
args = parser.parse_args()
bin_dir = args.pg_bin.resolve()
root = Path(__file__).resolve().parents[1]
if os.name == "nt":
    dll_directory = os.add_dll_directory(str(bin_dir))
    lib = ctypes.CDLL(str(bin_dir / "libpq.dll"))
else:
    lib = ctypes.CDLL(str(bin_dir / "libpq.so"))
for name, restype, argtypes in [
    ("PQconnectdb", ctypes.c_void_p, [ctypes.c_char_p]),
    ("PQstatus", ctypes.c_int, [ctypes.c_void_p]),
    ("PQerrorMessage", ctypes.c_char_p, [ctypes.c_void_p]),
    ("PQexec", ctypes.c_void_p, [ctypes.c_void_p, ctypes.c_char_p]),
    ("PQresultStatus", ctypes.c_int, [ctypes.c_void_p]),
    ("PQresultErrorField", ctypes.c_char_p, [ctypes.c_void_p, ctypes.c_int]),
    ("PQresultErrorMessage", ctypes.c_char_p, [ctypes.c_void_p]),
    ("PQntuples", ctypes.c_int, [ctypes.c_void_p]),
    ("PQnfields", ctypes.c_int, [ctypes.c_void_p]),
    ("PQgetvalue", ctypes.c_char_p, [ctypes.c_void_p, ctypes.c_int, ctypes.c_int]),
    ("PQclear", None, [ctypes.c_void_p]),
    ("PQfinish", None, [ctypes.c_void_p]),
]:
    method = getattr(lib, name)
    method.restype, method.argtypes = restype, argtypes

class SqlError(Exception):
    def __init__(self, code, message):
        super().__init__(message)
        self.code = code

# Puerto local asignado por el SO; no acepta host/DSN externos.
import socket
with socket.socket() as sock:
    sock.bind(("127.0.0.1", 0))
    port = sock.getsockname()[1]

class DB:
    def __init__(self):
        self.conn = lib.PQconnectdb(f"host=127.0.0.1 port={port} user=postgres dbname=postgres connect_timeout=5".encode())
        if lib.PQstatus(self.conn) != 0:
            raise RuntimeError(lib.PQerrorMessage(self.conn).decode())
        self.query("set client_min_messages='error'; set statement_timeout='15s'")
    def query(self, sql):
        result = lib.PQexec(self.conn, sql.encode())
        try:
            if lib.PQresultStatus(result) not in (1, 2):
                code = lib.PQresultErrorField(result, ord("C"))
                raise SqlError(code.decode() if code else "", lib.PQresultErrorMessage(result).decode())
            return [[lib.PQgetvalue(result, r, c).decode() for c in range(lib.PQnfields(result))]
                    for r in range(lib.PQntuples(result))]
        finally:
            lib.PQclear(result)
    def close(self):
        self.query("ROLLBACK")
        lib.PQfinish(self.conn)

def identity(db, user, aal="aal1"):
    claims = json.dumps({"sub": user, "role": "authenticated", "aal": aal})
    db.query(f"set local role authenticated; select set_config('request.jwt.claim.sub','{user}',true); select set_config('request.jwt.claims','{claims}',true)")

def setup_case(db, limit=1):
    trainer, other, x, y = [str(uuid.uuid4()) for _ in range(4)]
    for user in (trainer, other, x, y):
        db.query(f"insert into auth.users values('{user}'); insert into public.profiles values('{user}','Fixture')")
    for user in (trainer, other):
        db.query(f"insert into auth.mfa_factors values('{user}','verified','totp'); insert into public.trainer_access(trainer_id,enabled,client_limit,last_reason) values('{user}',true,{limit},'Prueba local')")
    codes = [uuid.uuid4().hex + uuid.uuid4().hex for _ in range(3)]
    for user, code in [(trainer,codes[0]), (trainer,codes[1]), (other,codes[2])]:
        db.query("begin")
        identity(db, user, "aal2")
        db.query(f"select public.create_trainer_invitation('{uuid.uuid4()}','{code}')")
        db.query("commit")
    return trainer, other, x, y, codes

def wait_locked(observer, pid, pending):
    deadline = time.monotonic() + 5
    while time.monotonic() < deadline:
        if pending.done():
            raise AssertionError("La segunda aceptación terminó sin esperar el bloqueo")
        rows = observer.query(f"select wait_event_type from pg_stat_activity where pid={pid}")
        if rows and rows[0][0] == "Lock":
            return
        time.sleep(0.01)
    raise AssertionError("No se observa contención real entre conexiones")

def race(observer, pool, *, same_client=False, same_code=False, repeatable=False):
    trainer, other, x, y, codes = setup_case(observer)
    first, second = DB(), DB()
    try:
        first.query("begin")
        identity(first, x)
        winner = first.query(f"select public.accept_trainer_invitation('{codes[0]}')")[0][0]
        second.query("begin isolation level " + ("repeatable read" if repeatable else "read committed"))
        identity(second, x if same_client else y)
        # Establece el snapshot antes del COMMIT del ganador.
        second.query("select count(*) from public.trainer_client_relations")
        pid = int(second.query("select pg_backend_pid()")[0][0])
        code = codes[0] if same_code else codes[2] if same_client else codes[1]
        future = pool.submit(second.query, f"select public.accept_trainer_invitation('{code}')")
        wait_locked(observer, pid, future)
        first.query("commit")
        expected = None if same_client and same_code else "40001" if repeatable else "23505" if same_client else "22023" if same_code else "23514"
        try:
            result = future.result(timeout=10)[0][0]
            assert expected is None and result == winner, (expected, result, winner)
            second.query("commit")
        except SqlError as error:
            assert error.code == expected, (error.code, expected, str(error))
            second.query("rollback")
        rows = observer.query(f"select count(*) from public.trainer_client_relations where trainer_id='{trainer}' and ended_at is null")
        assert rows[0][0] == "1", rows
        if repeatable:
            second.query("begin")
            identity(second, y)
            try:
                second.query(f"select public.accept_trainer_invitation('{codes[1]}')")
                raise AssertionError("Reintento RR excede cupo")
            except SqlError as error:
                assert error.code == "23514"
                second.query("rollback")
    finally:
        first.close()
        second.close()

bootstrap = """
create role anon;
create role authenticated;
create schema auth;
create schema extensions;
create extension pgcrypto with schema extensions;
create table auth.users(id uuid primary key);
create table public.profiles(id uuid primary key references auth.users on delete cascade,full_name text);
create table auth.mfa_factors(user_id uuid,status text,factor_type text);
create function auth.uid() returns uuid language sql stable as
  $$ select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid $$;
create function auth.jwt() returns jsonb language sql stable as
  $$ select coalesce(nullif(current_setting('request.jwt.claims',true),''),'{}')::jsonb $$;
grant usage on schema auth to authenticated;
create function public.can_manage_pro_accounts() returns boolean language sql stable as $$ select false $$;
"""
with tempfile.TemporaryDirectory(prefix="entrenaop-trainer-race-") as work:
    work = Path(work).resolve()
    data = work / "data"
    subprocess.run([str(bin_dir / "initdb"), "-D", str(data), "-U", "postgres", "-A", "trust", "--no-locale", "-E", "UTF8"],
                   check=True, capture_output=True)
    started = False
    observer = None
    try:
        subprocess.run([str(bin_dir / "pg_ctl"), "-D", str(data), "-l", str(work / "server.log"),
                        "-o", f"-h 127.0.0.1 -p {port}", "-w", "start"], check=True,
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        started = True
        observer = DB()
        assert observer.query("show server_version")[0][0].startswith("17."), "Usar PostgreSQL 17 como Dev"
        observer.query(bootstrap)
        for filename in ["20261020072345_trainer_access_and_client_relations.sql",
                         "20261021074426_trainer_portal_summaries.sql",
                         "20261021075243_trainer_mfa_and_directory.sql"]:
            observer.query((root / "supabase/migrations" / filename).read_text(encoding="utf-8"))
        with concurrent.futures.ThreadPoolExecutor(max_workers=1) as pool:
            cases = [
                ("última plaza READ COMMITTED", {}),
                ("última plaza REPEATABLE READ y reintento", {"repeatable":True}),
                ("mismo alumno, preparadores distintos", {"same_client":True}),
                ("mismo código y alumno, reintento idempotente", {"same_client":True,"same_code":True}),
                ("mismo código, alumnos distintos", {"same_code":True}),
            ]
            for name, options in cases:
                for _ in range(3):
                    race(observer, pool, **options)
                print(f"OK: {name} (3 contenciones observadas)", flush=True)
        print("OK: 15 carreras reales; migraciones originales; ningún acceso a Dev/producción.", flush=True)
    finally:
        if observer is not None:
            observer.close()
        if started:
            subprocess.run([str(bin_dir / "pg_ctl"), "-D", str(data), "-m", "immediate", "-w", "stop"],
                           check=True, capture_output=True)
