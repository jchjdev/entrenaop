"""Contenciones operacionales reproducibles en PostgreSQL17 local efímero.

Usa RPC/triggers reales con tablas mínimas para bloqueos. Las validaciones,
recetas, snapshots y RLS completas se verifican aparte en Dev con ROLLBACK.
Nunca accede a Dev/producción ni acepta DSN externos.
Ejemplo: python tools/test_trainer_operational_concurrency.py --pg-bin C:/.../bin
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

def install_operational_fixture(db):
    install_assignment_fixture(db)
    install_program_fixture(db)
    db.query("""
      alter table public.workout_templates add column created_at timestamptz default now();
      create table public.workout_executions(id uuid primary key,user_id uuid,status text,completed_at timestamptz,final_rpe int);
      create table public.workout_execution_sets(id uuid primary key,execution_id uuid,block_order int,item_order int,set_order int,actual_reps int);
      create table public.workout_amrap_results(execution_id uuid,block_order int);
    """)
    workout=(root/'supabase/migrations/20261021122051_trainer_private_workouts_and_assignments.sql').read_text(encoding='utf-8')
    program=(root/'supabase/migrations/20261021132641_trainer_private_programs.sql').read_text(encoding='utf-8')
    for name in ('list_trainer_workouts','list_trainer_assignments'):
        db.query(re.search(r'create function trainer_private\.'+name+r'\([\s\S]*?end \$\$;',workout).group())
    db.query(re.search(r'create or replace function trainer_private\.list_trainer_workouts\([\s\S]*?end \$\$;',program).group())
    db.query(re.search(r'create function trainer_private\.list_trainer_agenda\([\s\S]*?end \$\$;',program).group())
    db.query((root/'supabase/migrations/20261021151737_trainer_operational_workflow.sql').read_text(encoding='utf-8'))
    weekly=(root/'supabase/migrations/20260921004000_weekly_workout_schedule.sql').read_text(encoding='utf-8')
    db.query(re.search(r'create (?:or replace )?function public\.sync_scheduled_workout_status\([\s\S]*?\$\$;',weekly,re.I).group())
    db.query(re.search(r'create trigger sync_scheduled_workout_status[\s\S]*?;',weekly,re.I).group())

def operational_case(db):
    trainer,_,x,y,_=setup_case(db,limit=2)
    relations=[str(uuid.uuid4()),str(uuid.uuid4())]
    for relation,pupil in zip(relations,(x,y)):
        db.query(f"insert into public.trainer_client_relations(id,trainer_id,client_id) values('{relation}','{trainer}','{pupil}')")
    return trainer,x,y,relations

def message_limit_race(observer,pool,repeatable):
    trainer,x,y,relations=operational_case(observer)
    observer.query(f"insert into trainer_private.message_sender_versions values('{trainer}',99)")
    observer.query(f"insert into trainer_private.messages select gen_random_uuid(),'{relations[0]}',null,'{trainer}','Previo',now() from generate_series(1,99)")
    first,second=DB(),DB()
    try:
        first.query('begin');identity(first,trainer,'aal2')
        first.query(f"select public.send_trainer_message('{uuid.uuid4()}','{relations[0]}','Mensaje cien')")
        second.query('begin isolation level '+('repeatable read' if repeatable else 'read committed'))
        identity(second,trainer,'aal2');second.query('select count(*) from public.trainer_client_relations')
        pid=int(second.query('select pg_backend_pid()')[0][0])
        future=pool.submit(second.query,f"select public.send_trainer_message('{uuid.uuid4()}','{relations[1]}','Mensaje ciento uno')")
        wait_locked(observer,pid,future);first.query('commit')
        try:
            future.result(timeout=10)
            raise AssertionError('Se excede el límite global')
        except SqlError as error:
            assert error.code==('40001' if repeatable else '54000'),(error.code,str(error))
            second.query('rollback')
        assert observer.query(f"select count(*) from trainer_private.messages where sender_id='{trainer}'")==[['100']]
    finally:
        first.close();second.close()

def message_end_race(observer,pool,message_first,repeatable):
    trainer,pupil,_,relations=operational_case(observer)
    send=f"select public.send_trainer_message('{uuid.uuid4()}','{relations[0]}','Antes de la baja')"
    end=f"select public.end_trainer_relation('{relations[0]}')"
    first,second=DB(),DB()
    try:
        first.query('begin');identity(first,trainer,'aal2');first.query(send if message_first else end)
        second.query('begin isolation level '+('repeatable read' if repeatable else 'read committed'))
        identity(second,trainer,'aal2');second.query('select count(*) from public.trainer_client_relations')
        pid=int(second.query('select pg_backend_pid()')[0][0]);future=pool.submit(second.query,end if message_first else send)
        wait_locked(observer,pid,future);first.query('commit')
        expected=None if message_first else '40001' if repeatable else '42501'
        try:
            future.result(timeout=10);assert expected is None;second.query('commit')
        except SqlError as error:
            assert error.code==expected,(message_first,repeatable,error.code,str(error));second.query('rollback')
        assert observer.query(f"select count(*) from trainer_private.messages where relation_id='{relations[0]}'")==[['1' if message_first else '0']]
    finally:
        first.close();second.close()

def result_review_race(observer,pool,review_first,repeatable):
    trainer,pupil,_,relations=operational_case(observer)
    template,assignment,execution,set_id=[str(uuid.uuid4()) for _ in range(4)]
    observer.query(f"insert into public.workout_templates(id,owner_user_id,origin,status,name,version,estimated_duration_minutes) values('{template}','{trainer}','coach','published','Receta',1,30)")
    observer.query('begin');identity(observer,trainer,'aal2');observer.query(f"select public.assign_trainer_workout('{assignment}','{relations[0]}','{template}',current_date,null)");observer.query('commit')
    observer.query(f"insert into public.workout_executions values('{execution}','{pupil}','completed',now(),6); insert into public.workout_execution_sets values('{set_id}','{execution}',0,0,0,8); update public.scheduled_workouts set execution_id='{execution}',status='completed' where id='{assignment}'")
    seen=observer.query(f"select result_revision from public.trainer_assignments where scheduled_id='{assignment}'")[0][0]
    review=f"select public.mark_trainer_assignment_reviewed('{uuid.uuid4()}','{assignment}',{seen},'Revisado')"
    # La actualización real de serie dispara el trigger real de revisión. La RPC
    # completa de corrección y sus permisos se verifican en Dev con ROLLBACK.
    correction=f"update public.workout_execution_sets set actual_reps=9 where id='{set_id}'"
    first,second=DB(),DB()
    try:
        first.query('begin')
        if review_first: identity(first,trainer,'aal2')
        first.query(review if review_first else correction)
        second.query('begin isolation level '+('repeatable read' if repeatable else 'read committed'))
        if not review_first: identity(second,trainer,'aal2')
        second.query('select count(*) from public.trainer_client_relations')
        pid=int(second.query('select pg_backend_pid()')[0][0]);future=pool.submit(second.query,correction if review_first else review)
        wait_locked(observer,pid,future);first.query('commit')
        expected=None if review_first else '40001'
        try:
            future.result(timeout=10);assert expected is None;second.query('commit')
        except SqlError as error:
            assert error.code==expected,(review_first,repeatable,error.code,str(error));second.query('rollback')
            if review_first:
                second.query('begin');second.query(correction);second.query('commit')
        assert observer.query(f"select count(*) from public.trainer_assignments a left join trainer_private.assignment_reviews r on r.assignment_id=a.scheduled_id where a.scheduled_id='{assignment}' and r.result_revision is distinct from a.result_revision")==[['1']]
    finally:
        first.close();second.close()

with tempfile.TemporaryDirectory(prefix='entrenaop-operational-race-') as work:
    work=Path(work).resolve();data=work/'data'
    subprocess.run([str(bin_dir/'initdb'),'-D',str(data),'-U','postgres','-A','trust','--no-locale','-E','UTF8'],check=True,capture_output=True)
    started=False;observer=None
    try:
        subprocess.run([str(bin_dir/'pg_ctl'),'-D',str(data),'-l',str(work/'server.log'),'-o',f'-h 127.0.0.1 -p {port}','-w','start'],check=True,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
        started=True;observer=DB();observer.query(bootstrap)
        assert observer.query('show server_version')[0][0].startswith('17.')
        for filename in ['20261020072345_trainer_access_and_client_relations.sql','20261021074426_trainer_portal_summaries.sql','20261021075243_trainer_mfa_and_directory.sql','20261021115014_trainer_client_portfolio.sql']:
            observer.query((root/'supabase/migrations'/filename).read_text(encoding='utf-8'))
        install_operational_fixture(observer)
        with concurrent.futures.ThreadPoolExecutor(max_workers=1) as pool:
            for repeatable in (False,True):
                for _ in range(3): message_limit_race(observer,pool,repeatable)
                print(f'OK: límite global de emisor entre alumnos distintos, RR={repeatable} (3 contenciones)',flush=True)
            for first in (False,True):
                for repeatable in (False,True):
                    for _ in range(3): message_end_race(observer,pool,first,repeatable)
                    print(f'OK: envío/baja, envío primero={first}, RR={repeatable} (3 contenciones)',flush=True)
            for first in (False,True):
                for repeatable in (False,True):
                    for _ in range(3): result_review_race(observer,pool,first,repeatable)
                    print(f'OK: revisión/corrección, revisión primero={first}, RR={repeatable} (3 contenciones)',flush=True)
        print('OK: 30 contenciones operacionales locales con RPC/triggers reales y tablas mínimas; ningún acceso a Dev/producción.',flush=True)
    finally:
        if observer is not None: observer.close()
        if started: subprocess.run([str(bin_dir/'pg_ctl'),'-D',str(data),'-m','immediate','-w','stop'],check=True,capture_output=True)
