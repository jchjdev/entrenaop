"""Contenciones de evaluaciones profesionales reproducibles en PostgreSQL17 local efímero.

Usa RPC/triggers reales con tablas mínimas para bloqueos. Las validaciones,
recetas, snapshots y RLS completas se verifican aparte en Dev con ROLLBACK.
Nunca accede a Dev/producción ni acepta DSN externos.
Ejemplo: python tools/test_trainer_assessment_concurrency.py --pg-bin C:/.../bin
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

def install_assessment_fixture(db):
    # El catálogo mínimo permite crear todas las funciones SQL reales. Estos
    # casos usan protocolos privados; el catálogo oficial/RLS íntegros se
    # verifican adicionalmente en Dev con el test transaccional y ROLLBACK.
    db.query("""
      create table public.preparation_programs(id text primary key,enabled boolean);
      create table public.program_assessment_tests(
        id uuid primary key,program_id text,code text,name text,definition_version int,
        unit text,better_direction text,mark_step numeric,protocol_notes text,
        max_attempts int,retry_policy text,category text,min_age int,max_age int,
        distance_meters int,measurement_protocol text,display_order int);
    """)
    migration=(root/'supabase/migrations/20261021122051_trainer_private_workouts_and_assignments.sql').read_text(encoding='utf-8')
    db.query(re.search(r'create function trainer_private\.require_authoring_access\([\s\S]*?end \$\$;',migration).group())
    forms=(root/'supabase/migrations/20261021151928_trainer_followup_forms.sql').read_text(encoding='utf-8')
    db.query(re.search(r'create function trainer_private\.form_text_valid\([\s\S]*?\$\$;',forms).group())
    db.query((root/'supabase/migrations/20261021160327_trainer_assessments.sql').read_text(encoding='utf-8'))

def json_sql(value):
    return "'"+json.dumps(value,separators=(',',':')).replace("'","''")+"'::jsonb"

def authenticated(db,user,sql,aal='aal1'):
    db.query('begin');identity(db,user,aal)
    try:
        rows=db.query(sql);db.query('commit');return rows
    except Exception:
        db.query('rollback');raise

def setup_case(db,started=False):
    trainer,pupil,relation,delivery=[str(uuid.uuid4()) for _ in range(4)]
    for user in (trainer,pupil):
        db.query(f"insert into auth.users values('{user}');insert into public.profiles values('{user}','Fixture')")
    db.query(f"insert into auth.mfa_factors values('{trainer}','verified','totp');insert into public.trainer_access(trainer_id,enabled,client_limit,last_reason) values('{trainer}',true,1,'Prueba local')")
    db.query(f"insert into public.trainer_client_relations(id,trainer_id,client_id) values('{relation}','{trainer}','{pupil}')")
    payload={'title':'Control privado','tests':[{'id':'run','source':'custom','name':'Recorrido',
        'unit':'seconds','direction':'lower','resolution':0.01,
        'instructions':'Recorre el trazado y registra la marca real.',
        'max_attempts':1,'retry_policy':'none'}]}
    battery=authenticated(db,trainer,f"select public.save_trainer_assessment('{uuid.uuid4()}',{json_sql(payload)})",'aal2')[0][0]
    authenticated(db,trainer,f"select public.assign_trainer_assessment('{delivery}','{relation}','{battery}',current_date)",'aal2')
    if started:
        authenticated(db,pupil,write(delivery,str(uuid.uuid4()),0,'start',{'protocols_confirmed':True}))
    return trainer,pupil,relation,delivery

def write(delivery,op,revision,action,payload):
    return f"select public.write_trainer_assessment('{op}','{delivery}',{revision},'{action}',{json_sql(payload)})"

def wait_locked(observer,pid,pending):
    deadline=time.monotonic()+5
    while time.monotonic()<deadline:
        if pending.done():raise AssertionError('La segunda operación no esperó un bloqueo real')
        rows=observer.query(f'select wait_event_type from pg_stat_activity where pid={pid}')
        if rows and rows[0][0]=='Lock':return
        time.sleep(0.01)
    raise AssertionError('No se observó contención entre conexiones independientes')

def begin_second(db,pupil,repeatable):
    db.query('begin isolation level '+('repeatable read' if repeatable else 'read committed'))
    identity(db,pupil)
    # Fija una instantánea anterior al commit competidor en REPEATABLE READ.
    db.query('select count(*) from public.trainer_client_relations')
    return int(db.query('select pg_backend_pid()')[0][0])

def expect_error(future,db,code):
    try:
        future.result(timeout=10)
        raise AssertionError('La operación debía fallar con '+code)
    except SqlError as error:
        assert error.code==code,(error.code,str(error))
        db.query('rollback')

def start_end_race(observer,pool,start_first,repeatable):
    trainer,pupil,relation,delivery=setup_case(observer)
    start=write(delivery,str(uuid.uuid4()),0,'start',{'protocols_confirmed':True})
    end=f"select public.end_trainer_relation('{relation}')"
    first,second=DB(),DB()
    try:
        first.query('begin');identity(first,pupil if start_first else trainer,'aal1' if start_first else 'aal2')
        first.query(start if start_first else end)
        pid=begin_second(second,trainer if start_first else pupil,repeatable)
        # La baja permite a ambos participantes; el actor preparador usa MFA.
        if start_first:identity(second,trainer,'aal2')
        future=pool.submit(second.query,end if start_first else start)
        wait_locked(observer,pid,future);first.query('commit')
        if start_first and not repeatable:
            future.result(timeout=10);second.query('commit')
        else:
            expect_error(future,second,'40001')
            if start_first:authenticated(second,trainer,end,'aal2')
        state=observer.query(f"select status,revision from trainer_private.assessment_deliveries where id='{delivery}'")
        assert state==[['in_progress' if start_first else 'withdrawn','1']],state
        assert observer.query(f"select count(*) from trainer_private.assessment_result_revisions where delivery_id='{delivery}'")==[['1' if start_first else '0']]
        assert observer.query(f"select ended_at is not null from public.trainer_client_relations where id='{relation}'")==[['t']]
    finally:first.close();second.close()

def save_finish_race(observer,pool,save_first,repeatable):
    _,pupil,_,delivery=setup_case(observer,started=True)
    save=write(delivery,str(uuid.uuid4()),1,'save',{'run':[{'valid':True,'value':12}]})
    finish=write(delivery,str(uuid.uuid4()),1,'finish',{'run':[{'valid':True,'value':10}]})
    first,second=DB(),DB()
    try:
        first.query('begin');identity(first,pupil);first.query(save if save_first else finish)
        pid=begin_second(second,pupil,repeatable)
        future=pool.submit(second.query,finish if save_first else save)
        wait_locked(observer,pid,future);first.query('commit')
        expect_error(future,second,'40001')
        state=observer.query(f"select status,revision,answers->'run'->0->>'value' from trainer_private.assessment_deliveries where id='{delivery}'")
        assert state==[['in_progress' if save_first else 'completed','2','12' if save_first else '10']],state
        assert observer.query(f"select count(*) from trainer_private.assessment_result_revisions where delivery_id='{delivery}'")==[['2']]
    finally:first.close();second.close()

def retry_race(observer,pool,changed_payload,repeatable):
    _,pupil,_,delivery=setup_case(observer,started=True)
    op=str(uuid.uuid4())
    save=write(delivery,op,1,'save',{'run':[{'valid':True,'value':12}]})
    retry=write(delivery,op,1,'save',{'run':[{'valid':True,'value':10 if changed_payload else 12}]})
    first,second=DB(),DB()
    try:
        first.query('begin');identity(first,pupil);receipt=first.query(save)
        pid=begin_second(second,pupil,repeatable)
        future=pool.submit(second.query,retry)
        wait_locked(observer,pid,future);first.query('commit')
        if repeatable:
            expect_error(future,second,'40001')
            if changed_payload:
                try:authenticated(second,pupil,retry);raise AssertionError('Mismo op con otro payload')
                except SqlError as error:assert error.code=='22023',(error.code,str(error))
            else:assert authenticated(second,pupil,retry)==receipt
        elif changed_payload:expect_error(future,second,'22023')
        else:
            assert future.result(timeout=10)==receipt;second.query('commit')
        assert observer.query(f"select revision,answers->'run'->0->>'value' from trainer_private.assessment_deliveries where id='{delivery}'")==[['2','12']]
        assert observer.query(f"select count(*) from trainer_private.assessment_result_revisions where delivery_id='{delivery}'")==[['2']]
    finally:first.close();second.close()

with tempfile.TemporaryDirectory(prefix='entrenaop-assessment-race-') as work:
    work=Path(work).resolve();data=work/'data'
    subprocess.run([str(bin_dir/'initdb'),'-D',str(data),'-U','postgres','-A','trust','--no-locale','-E','UTF8'],check=True,capture_output=True)
    started=False;observer=None
    try:
        subprocess.run([str(bin_dir/'pg_ctl'),'-D',str(data),'-l',str(work/'server.log'),'-o',f'-h 127.0.0.1 -p {port}','-w','start'],check=True,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
        started=True;observer=DB();observer.query(bootstrap)
        assert observer.query('show server_version')[0][0].startswith('17.')
        for filename in ['20261020072345_trainer_access_and_client_relations.sql','20261021074426_trainer_portal_summaries.sql','20261021075243_trainer_mfa_and_directory.sql','20261021115014_trainer_client_portfolio.sql']:
            observer.query((root/'supabase/migrations'/filename).read_text(encoding='utf-8'))
        install_assessment_fixture(observer)
        with concurrent.futures.ThreadPoolExecutor(max_workers=1) as pool:
            for repeatable in (False,True):
                for first in (False,True):
                    for _ in range(3):start_end_race(observer,pool,first,repeatable)
                    print(f'OK: inicio/baja, inicio primero={first}, RR={repeatable} (3 contenciones)',flush=True)
                for first in (False,True):
                    for _ in range(3):save_finish_race(observer,pool,first,repeatable)
                    print(f'OK: guardado/cierre misma revisión, guardado primero={first}, RR={repeatable} (3 contenciones)',flush=True)
                for changed in (False,True):
                    for _ in range(3):retry_race(observer,pool,changed,repeatable)
                    print(f'OK: reintento mismo op, payload cambiado={changed}, RR={repeatable} (3 contenciones)',flush=True)
        print('OK: 36 contenciones de evaluación en PostgreSQL17 local efímero; ningún acceso a Dev/producción.',flush=True)
    finally:
        if observer is not None:observer.close()
        if started:subprocess.run([str(bin_dir/'pg_ctl'),'-D',str(data),'-m','immediate','-w','stop'],check=True,capture_output=True)
