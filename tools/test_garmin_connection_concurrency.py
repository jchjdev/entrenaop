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
parser.add_argument('--training', action='store_true', help='Añadir fronteras y concurrencia del envío común de carrera.')
parser.add_argument('--automatic', action='store_true')
parser.add_argument('--activity', action='store_true', help='Concurrencia de recepción y confirmación; cierres deportivos probados aparte en Dev con ROLLBACK.')
args = parser.parse_args()
if args.automatic and not args.training:
    parser.error('--automatic necesita --training')
if args.activity and not args.training:
    parser.error('--activity necesita --training')
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
    if args.training:
        # Solo la forma mínima de las fronteras reales; no sustituye el contrato
        # transaccional completo contra Dev ni los constructores profesionales.
        db.query("""
          alter table auth.sessions add column aal text default 'aal1';
          alter table public.trainer_client_relations add column id uuid default gen_random_uuid();
          create table public.preparation_goals(id uuid primary key,user_id uuid,status text);
          create table public.workout_templates(id uuid primary key,status text,version integer,origin text,owner_user_id uuid,description text);
          create table public.scheduled_workouts(id uuid primary key,user_id uuid,template_id uuid,template_name text,template_version integer,
            status text,execution_id uuid,source text,scheduled_date date,order_index integer default 0,preparation_goal_id uuid);
          create table public.trainer_assignments(scheduled_id uuid primary key,client_id uuid,trainer_id uuid,relation_id uuid,planning_revision bigint default 0);
          create table public.running_week_decisions(id uuid primary key,user_id uuid,preparation_goal_id uuid,policy_version text);
          create table public.running_week_sessions(scheduled_workout_id uuid,decision_id uuid);
          create table public.workout_blocks(id uuid primary key,template_id uuid,order_index integer,name text,format text,rounds integer,rest_after_seconds integer,time_cap_seconds integer);
          create table public.workout_items(id uuid primary key,block_id uuid,order_index integer,exercise_id uuid,notes text);
          create table public.workout_sets(item_id uuid,order_index integer,target_duration_seconds integer,rest_after_seconds integer);
        """)
        db.query((root/'supabase/migrations/20261022132601_garmin_running_training_delivery.sql').read_text(encoding='utf-8'))
        owner,session,state,claim,generation=prepare()
        rpc(db,'claim',body=dict(state_hash=state,claim_id=claim))
        rpc(db,'complete',owner,body=secret(generation,claim))
        trainer,_=actor()
        relation,template,scheduled,block,item=[str(uuid.uuid4()) for _ in range(5)]
        db.query(f"""
          insert into public.trainer_access(trainer_id,enabled) values('{trainer}',true);
          insert into public.trainer_client_relations(id,trainer_id,client_id) values('{relation}','{trainer}','{owner}');
          insert into public.workout_templates values('{template}','published',1,'coach','{trainer}',null);
          insert into public.scheduled_workouts(id,user_id,template_id,template_name,template_version,status,source,scheduled_date)
            values('{scheduled}','{owner}','{template}','Carrera sintética',1,'planned','coach',current_date+1);
          insert into public.trainer_assignments values('{scheduled}','{owner}','{trainer}','{relation}',0);
          insert into public.workout_blocks values('{block}','{template}',0,'Carrera','running',1,0,null);
          insert into public.workout_items values('{item}','{block}',0,'20000000-0000-4000-8000-000000000004',null);
          insert into public.workout_sets values('{item}',0,120,0);
        """)
        def training(conn,action,body):
            payload=json.dumps(body).replace("'","''")
            return json.loads(conn.query(f"select public.garmin_training_command('{action}','{owner}','{owner}','{session}','{payload}'::jsonb)")[0][0])
        preview=training(db,'preview',dict(scheduled_id=scheduled))
        def delivery_once(_):
            conn=DB()
            try:
                try:return training(conn,'claim',dict(scheduled_id=scheduled,revision=preview['revision'],lease_id=str(uuid.uuid4())))
                except SqlError as error:
                    assert error.code=='40001',str(error)
                    return None
            finally:conn.close()
        with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
            deliveries=list(pool.map(delivery_once,range(2)))
        assert sum(result is not None for result in deliveries)==1
        delivered=next(result for result in deliveries if result is not None)
        jid=delivered['id']
        lease=db.query(f"select lease_id from device_private.training_deliveries where id='{jid}'")[0][0]
        fields=dict(id=jid,lease_id=lease)
        training(db,'mark_creating',fields)
        rpc(db,'disconnect',owner,session,dict(generation=generation))
        assert rpc(db,'claim_revoke',owner,body=dict(lease_id=str(uuid.uuid4())))['pending']
        training(db,'save_workout',dict(**fields,workout_id=123))
        try:
            training(db,'mark_scheduling',fields)
            raise AssertionError('Un envío desconectado agenda otra operación')
        except SqlError as error:
            assert error.code=='40001',str(error)
        training(db,'fail',dict(**fields,code='connection_changed',uncertain=False))
        training(db,'release',fields)
        assert 'tokens_cipher' in rpc(db,'claim_revoke',owner,body=dict(lease_id=str(uuid.uuid4())))
        db.query(f"delete from public.scheduled_workouts where id='{scheduled}'")
        assert db.query(f"select workout_id from device_private.training_deliveries where id='{jid}'")[0][0]=='123'
        print('Correcto: un solo worker de envío, desconexión concurrente, revocación diferida y recibo conservado tras borrar agenda.')
        if args.automatic:
            db.query("alter table public.running_week_decisions add column superseded_at timestamptz")
            db.query((root/'supabase/migrations/20261022194351_garmin_automatic_training_sync.sql').read_text(encoding='utf-8'))
            scheduled=str(uuid.uuid4())
            db.query(f"""update device_private.garmin_connections set status='connected',can_send=true,training_lease=null,training_lease_until=null,disconnect_lease=null,disconnect_lease_until=null where owner_id='{owner}';
              delete from device_private.training_deliveries where owner_id='{owner}';
              insert into public.scheduled_workouts(id,user_id,template_id,template_name,template_version,status,source,scheduled_date)
              values('{scheduled}','{owner}','{template}','Carrera sintética',1,'planned','coach',current_date+1);
              insert into public.trainer_assignments values('{scheduled}','{owner}','{trainer}','{relation}',0);
              select set_config('fixture.owner','{owner}',false),set_config('fixture.session','{session}',false),set_config('fixture.scheduled','{scheduled}',false)""")
            db.query(f"select device_private.training_source('{owner}','{owner}','{scheduled}')")
            contract=(root/'supabase/tests/garmin_automatic_training.sql').read_text(encoding='utf-8').split('-- Contract shared with isolated PostgreSQL concurrency fixture.')[1]
            db.query('begin;'+contract.split('-- Publicación real del algoritmo')[0]+'rollback;')
            print('Correcto: contrato automático, revisiones, cancelaciones, autorización persistente y conservación del historial.')
            db.query(f"select public.garmin_training_sync_preferences('{owner}','{session}',true);select public.garmin_training_sync_command('scan','{{}}')")
            def take_once(_):
                conn=DB()
                try:return json.loads(conn.query("select public.garmin_training_sync_command('take','{}')")[0][0])
                finally:conn.close()
            with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
                jobs=list(pool.map(take_once,range(2)))
            assert sum(bool(value.get('id')) for value in jobs)==1
            job=next(value for value in jobs if value.get('id'))
            def compete(auto):
                conn=DB()
                try:
                    body=dict(scheduled_id=scheduled,revision=job['target']['revision'],lease_id=str(uuid.uuid4()))
                    if auto:body.update(auto_job=job['id'],auto_lease=job['lease'])
                    payload=json.dumps(body).replace("'","''")
                    actor_session='null' if auto else f"'{session}'"
                    try:return json.loads(conn.query(f"select public.garmin_training_command('claim','{owner}','{owner}',{actor_session},'{payload}')")[0][0])
                    except SqlError as error:
                        assert error.code=='40001',str(error)
                        return None
                finally:conn.close()
            with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
                winners=list(pool.map(compete,[False,True]))
            assert sum(value is not None for value in winners)==1
            print('Correcto: una sola toma automática y exclusión real entre envío manual y automático.')
    if args.activity:
        # Fronteras mínimas para probar los bloqueos reales del nuevo contrato.
        # La receta, cierre y triggers reales se prueban en garmin_activity_return.sql.
        db.query("""
          create table public.workout_executions(id uuid primary key,user_id uuid,status text,started_at timestamptz);
          create table public.workout_execution_sets(id uuid primary key,execution_id uuid,block_order integer,item_order integer,set_order integer,block_format text,recovery_type text);
          create function public.start_scheduled_workout(p_id uuid) returns uuid language plpgsql as $$
          declare e uuid:=gen_random_uuid(); s public.scheduled_workouts;
          begin select * into s from public.scheduled_workouts where id=p_id;
            insert into public.workout_executions values(e,s.user_id,'in_progress',now());
            insert into public.workout_execution_sets values(gen_random_uuid(),e,0,0,0,'running',null);
            update public.scheduled_workouts set execution_id=e,status='in_progress' where id=p_id; return e; end $$;
          create function public.skip_workout_set(uuid) returns void language sql as $$select$$;
          create function public.complete_workout_set(uuid,p_actual_duration_seconds integer,p_actual_distance_meters numeric,
            p_actual_recovery_duration_seconds integer,p_actual_recovery_distance_meters numeric,p_result_source text)
            returns void language sql as $$select$$;
          create function public.finish_workout_observed_idempotent(uuid,uuid,integer,timestamptz,integer,text,integer,integer,text)
            returns void language sql as $$ update public.workout_executions set status='completed' where id=$2;
            update public.scheduled_workouts set status='completed' where execution_id=$2; $$;
        """)
        db.query((root/'supabase/migrations/20261023091748_garmin_activity_return.sql').read_text(encoding='utf-8'))
        db.query((root/'supabase/migrations/20261023102552_garmin_activity_lap_groups.sql').read_text(encoding='utf-8'))
        db.query('alter table public.workout_sets add column running_step jsonb')
        db.query((root/'supabase/migrations/20261023103429_garmin_activity_prescribed_version.sql').read_text(encoding='utf-8'))
        def activity(conn, action, owner=None, session=None, body=None):
            payload=json.dumps(body or {}).replace("'","''")
            o='null' if owner is None else f"'{owner}'"
            s='null' if session is None else f"'{session}'"
            return json.loads(conn.query(f"select public.garmin_activity_command('{action}',{o},{s},'{payload}')")[0][0])
        owner,session,state,claim,generation=prepare()
        rpc(db,'claim',body=dict(state_hash=state,claim_id=claim))
        identity=str(uuid.uuid4())
        rpc(db,'complete',owner,body=secret(generation,claim,identity))
        job=str(uuid.uuid4())
        activity(db,'enqueue',body=dict(id=job,event_key='a'*64,provider_user_id=identity,callback_cipher='fixture',metadata={}))
        def claim_activity(_):
            conn=DB()
            try:return activity(conn,'claim',body=dict(id=job,lease_id=str(uuid.uuid4())))
            finally:conn.close()
        with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
            jobs=list(pool.map(claim_activity,range(2)))
        winner=next(value for value in jobs if value.get('tokens'))
        assert sum(bool(value.get('tokens')) for value in jobs)==1
        fields=dict(id=job,lease_id=winner['lease'])
        observation=dict(schemaVersion=1,externalId='12345',name='Fixture',startedAt='2026-01-01T08:00:00Z',
          offsetSeconds=0,timerSeconds=100,elapsedSeconds=100,distanceMeters=400,averageHeartRate=None,maxHeartRate=None,
          laps=[dict(index=0,timerSeconds=100,distanceMeters=400)])
        activity(db,'save',body=dict(**fields,activity=observation));activity(db,'release',body=fields)
        scheduled=str(uuid.uuid4())
        db.query(f"""insert into public.scheduled_workouts(id,user_id,template_id,template_name,template_version,status,source,scheduled_date)
          values('{scheduled}','{owner}','{template}','Carrera sintética',1,'planned','coach',current_date);
          insert into public.trainer_client_relations(id,trainer_id,client_id) values(gen_random_uuid(),'{trainer}','{owner}');
          insert into public.trainer_assignments(scheduled_id,client_id,trainer_id,relation_id)
          select '{scheduled}','{owner}','{trainer}',id from public.trainer_client_relations where client_id='{owner}' limit 1;""")
        aid=db.query(f"select id from device_private.activity_observations where owner_id='{owner}'")[0][0]
        preview=activity(db,'preview',owner,session,dict(activity_id=aid,scheduled_id=scheduled))
        confirmation=dict(operation_id=str(uuid.uuid4()),activity_id=aid,scheduled_id=scheduled,
          activity_revision=preview['activity_revision'],source_revision=preview['source_revision'],rpe=4,
          mapping=[dict(block_order=0,item_order=0,set_order=0,lap_index=0)])
        def confirm_activity(_):
            conn=DB()
            try:return activity(conn,'confirm',owner,session,confirmation)
            finally:conn.close()
        with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
            receipts=list(pool.map(confirm_activity,range(2)))
        assert receipts[0]['execution_id']==receipts[1]['execution_id']
        assert sum(value['replayed'] for value in receipts)==1
        assert db.query(f"select count(*) from public.workout_executions where user_id='{owner}'")[0][0]=='1'
        print('Correcto: una sola descarga concurrente y una única ejecución ante dos confirmaciones simultáneas de la misma operación.')
finally:
    if db is not None:db.close()
    try:
        if started:command('pg_ctl','-D',data,'-m','immediate','-w','stop')
    finally:
        if workspace.is_relative_to(fixture_root) and workspace!=fixture_root and not workspace.is_symlink():
            shutil.rmtree(workspace)
