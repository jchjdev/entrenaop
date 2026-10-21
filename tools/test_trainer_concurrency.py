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
import re
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
        assert observer.query(f"select count(*) from public.trainer_clients where trainer_id='{trainer}' and client_id='{x}' and archived_at is null")[0][0] == "1"
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

def portfolio_race(observer, pool, archive_first):
    trainer, _, pupil, _, codes = setup_case(observer)
    # Etapa previa terminada, con la ficha aún en cartera.
    observer.query(f"insert into public.trainer_client_relations(trainer_id,client_id,ended_at) values('{trainer}','{pupil}',clock_timestamp())")
    first, second = DB(), DB()
    try:
        first.query("begin")
        identity(first, trainer if archive_first else pupil, "aal2" if archive_first else "aal1")
        first.query(f"select public.archive_trainer_client('{pupil}',true)" if archive_first else f"select public.accept_trainer_invitation('{codes[0]}')")
        second.query("begin")
        identity(second, pupil if archive_first else trainer, "aal1" if archive_first else "aal2")
        pid = int(second.query("select pg_backend_pid()")[0][0])
        future = pool.submit(second.query, f"select public.accept_trainer_invitation('{codes[0]}')" if archive_first else f"select public.archive_trainer_client('{pupil}',true)")
        wait_locked(observer, pid, future)
        first.query("commit")
        try:
            future.result(timeout=10)
            assert archive_first, "Archiva una ficha con servicio recién aceptado"
            second.query("commit")
        except SqlError as error:
            assert not archive_first and error.code == "22023", (archive_first,error.code,str(error))
            second.query("rollback")
        assert observer.query(f"select count(*) from public.trainer_clients where trainer_id='{trainer}' and client_id='{pupil}' and archived_at is null")[0][0] == "1"
        assert observer.query(f"select count(*) from public.trainer_client_relations where trainer_id='{trainer}' and client_id='{pupil}'")[0][0] == "2"
    finally:
        first.close()
        second.close()

def install_assignment_fixture(db):
    # El catálogo mínimo solo permite ensayar los bloqueos de las RPC reales.
    # Receta, snapshots, RLS y resultados completos se comprueban en Dev.
    db.query("""
    create table public.workout_templates(id uuid primary key,owner_user_id uuid,origin text,status text,name text,version integer,estimated_duration_minutes integer);
    create table public.scheduled_workouts(id uuid primary key,user_id uuid,template_id uuid,template_name text,template_version integer,estimated_duration_minutes integer,scheduled_date date,source text,status text default 'planned',execution_id uuid);
    """)
    migration=(root/'supabase/migrations/20261021122051_trainer_private_workouts_and_assignments.sql').read_text(encoding='utf-8')
    db.query(re.search(r'create table public.trainer_assignments \([\s\S]*?\n\);',migration).group())
    for name in ('require_authoring_access','assign_trainer_workout','withdraw_ended_assignments'):
        db.query(re.search(r'create function trainer_private\.'+name+r'\([\s\S]*?end \$\$;',migration).group())
    db.query(re.search(r'create function public.assign_trainer_workout\([\s\S]*?\$\$;',migration).group())
    db.query("grant execute on function trainer_private.assign_trainer_workout(uuid,uuid,uuid,date,text),public.assign_trainer_workout(uuid,uuid,uuid,date,text) to authenticated")
    db.query(re.search(r'create trigger withdraw_trainer_assignments[\s\S]*?;',migration).group())

def install_program_fixture(db):
    migration=(root/'supabase/migrations/20261021132641_trainer_private_programs.sql').read_text(encoding='utf-8')
    for name in ('programs','program_sessions','program_writes','program_deliveries'):
        db.query(re.search(r'create table trainer_private\.'+name+r' \([\s\S]*?\n\);',migration).group())
    db.query(re.search(r'alter table public.trainer_assignments add column[\s\S]*?;',migration).group())
    db.query(re.search(r'do \$migration\$[\s\S]*?end \$migration\$;',migration).group())
    db.query(re.search(r'create or replace function trainer_private.assign_trainer_workout\([\s\S]*?\$\$;',migration).group())
    db.query(re.search(r'create function trainer_private.assign_trainer_program\([\s\S]*?end \$\$;',migration).group())
    db.query(re.search(r'create function public.assign_trainer_program\([\s\S]*?\$\$;',migration).group())
    db.query('revoke all on function trainer_private.assign_trainer_workout_version(uuid,uuid,uuid,date,text,boolean) from public,anon,authenticated')
    db.query('grant execute on function trainer_private.assign_trainer_program(uuid,uuid,uuid,jsonb,text),public.assign_trainer_program(uuid,uuid,uuid,jsonb,text) to authenticated')

def assignment_race(observer,pool,assign_first,repeatable,program=False):
    trainer,_,pupil,_,_=setup_case(observer)
    relation,template,assignment=[str(uuid.uuid4()) for _ in range(3)]
    observer.query(f"insert into public.trainer_client_relations(id,trainer_id,client_id) values('{relation}','{trainer}','{pupil}')")
    observer.query(f"insert into public.workout_templates values('{template}','{trainer}','coach','published','Fixture',1,30)")
    assign=f"select public.assign_trainer_workout('{assignment}','{relation}','{template}',current_date,null)"
    if program:
        program_id=str(uuid.uuid4())
        content=json.dumps({'name':'Programa fijado','phases':[{'name':'Base'}]})
        observer.query(f"insert into trainer_private.programs(id,trainer_id,family_id,version,content) values('{program_id}','{trainer}','{program_id}',1,'{content}'); insert into trainer_private.program_sessions values('{program_id}',0,0,'{template}')")
        assign=f"select public.assign_trainer_program('{assignment}','{relation}','{program_id}',jsonb_build_array(jsonb_build_object('phase',0,'session',0,'date',current_date),jsonb_build_object('phase',0,'session',0,'date',current_date+2)),null)"
    end=f"select public.end_trainer_relation('{relation}')"
    first,second=DB(),DB()
    try:
        first.query('begin');identity(first,trainer,'aal2')
        first.query(assign if assign_first else end)
        second.query('begin isolation level '+('repeatable read' if repeatable else 'read committed'))
        identity(second,trainer,'aal2')
        second.query('select count(*) from public.trainer_client_relations')
        pid=int(second.query('select pg_backend_pid()')[0][0])
        future=pool.submit(second.query,end if assign_first else assign)
        wait_locked(observer,pid,future)
        first.query('commit')
        expected='40001' if repeatable else None if assign_first else '42501'
        try:
            future.result(timeout=10)
            assert expected is None,expected
            second.query('commit')
        except SqlError as error:
            assert error.code==expected,(error.code,expected,str(error))
            second.query('rollback')
            if assign_first and repeatable:
                second.query('begin');identity(second,trainer,'aal2');second.query(end);second.query('commit')
        rows=observer.query(f"select s.status from public.scheduled_workouts s join public.trainer_assignments a on a.scheduled_id=s.id where "+
            (f"a.program_delivery_id='{assignment}'" if program else f"s.id='{assignment}'"))
        assert rows==[['cancelled']]*(2 if program else 1) if assign_first else rows==[],rows
        assert observer.query(f"select count(*) from public.trainer_client_relations where id='{relation}' and ended_at is not null")[0][0]=='1'
    finally:
        first.close();second.close()

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
                         "20261021075243_trainer_mfa_and_directory.sql",
                         "20261021115014_trainer_client_portfolio.sql"]:
            observer.query((root / "supabase/migrations" / filename).read_text(encoding="utf-8"))
        install_assignment_fixture(observer)
        install_program_fixture(observer)
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
            for archive_first in (True, False):
                for _ in range(3):
                    portfolio_race(observer,pool,archive_first)
                print(f"OK: archivo y vuelta, archivo primero={archive_first} (3 contenciones observadas)",flush=True)
            for assign_first in (True,False):
                for repeatable in (False,True):
                    for _ in range(3): assignment_race(observer,pool,assign_first,repeatable)
                    print(f'OK: asignación/baja, asigna primero={assign_first}, RR={repeatable} (3 contenciones observadas)',flush=True)
            for assign_first in (True,False):
                for repeatable in (False,True):
                    for _ in range(3): assignment_race(observer,pool,assign_first,repeatable,program=True)
                    print(f'OK: programa/baja, asigna primero={assign_first}, RR={repeatable} (3 contenciones observadas)',flush=True)
        print("OK: 45 carreras reales; acceso/cartera, sesión/baja y programa/baja; ningún acceso a Dev/producción.", flush=True)
    finally:
        if observer is not None:
            observer.close()
        if started:
            subprocess.run([str(bin_dir / "pg_ctl"), "-D", str(data), "-m", "immediate", "-w", "stop"],
                           check=True, capture_output=True)
