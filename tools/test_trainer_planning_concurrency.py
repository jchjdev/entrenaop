"""Concurrencia de planificación profesional en PostgreSQL17 local efímero.

Ejecuta RPC y triggers reales extraídos de las migraciones del repositorio.
El catálogo y el motor de ejecución son mínimos: aquí se prueban bloqueos,
recibos e integridad temporal, no RLS ni recetas deportivas completas.
Los stubs de inicio/cita personal/corrección quedan marcados en install_context.
Nunca conecta a Dev/producción ni admite DSN externos.
Ejemplo: python tools/test_trainer_planning_concurrency.py --pg-bin C:/.../bin
"""
import argparse
import concurrent.futures
import ctypes
import json
import os
import re
from pathlib import Path
import subprocess
import sys
import tempfile
import time
import uuid

sys.stdout.reconfigure(encoding="utf-8")

parser = argparse.ArgumentParser()
parser.add_argument("--pg-bin", required=True, type=Path)
parser.add_argument("--case-filter", default="", help="Filtro de etiquetas; el cierre usa el runner completo sin filtro")
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
            raise AssertionError("La segunda operación terminó sin esperar el bloqueo")
        rows = observer.query(f"select wait_event_type from pg_stat_activity where pid={pid}")
        if rows and rows[0][0] == "Lock":
            return
        time.sleep(0.01)
    raise AssertionError("No se observa contención real entre conexiones")

def install_assignment_fixture(db):
    # El catálogo mínimo solo permite ensayar los bloqueos de las RPC reales.
    # Receta, snapshots, RLS y resultados completos se comprueban en Dev.
    db.query("""
    create table public.workout_templates(id uuid primary key,owner_user_id uuid references public.profiles(id) on delete cascade,origin text,status text,name text,version integer,estimated_duration_minutes integer,family_id uuid,previous_version_id uuid,show_in_library boolean default true);
    create table public.scheduled_workouts(id uuid primary key,user_id uuid references public.profiles(id) on delete cascade,template_id uuid references public.workout_templates(id) on delete restrict,template_name text,template_version integer,estimated_duration_minutes integer,scheduled_date date,source text,status text default 'planned',execution_id uuid);
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

def install_operational_fixture(db):
    install_assignment_fixture(db)
    install_program_fixture(db)
    db.query("""
      alter table public.workout_templates add column created_at timestamptz default now();
      create table public.workout_executions(id uuid primary key,user_id uuid,status text,completed_at timestamptz,final_rpe int);
      create table public.workout_execution_sets(id uuid primary key,execution_id uuid references public.workout_executions(id) on delete cascade,block_order int,item_order int,set_order int,actual_reps int);
      create table public.workout_amrap_results(execution_id uuid references public.workout_executions(id) on delete cascade,block_order int);
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



def install_context(db):
    install_operational_fixture(db)
    for filename in ('20261021153508_trainer_groups_and_week_copy.sql','20261021155333_trainer_finite_recurrence.sql','20261021161302_trainer_calendar_snapshot_guards.sql','20261021162516_trainer_reviewed_assignment_changes.sql'):
        db.query((root/'supabase/migrations'/filename).read_text(encoding='utf-8'))
    db.query("""
    create schema harness;
    grant usage on schema harness to authenticated;
    -- Stub exclusivamente deportivo: crea registros mínimos. La autorización,
    -- el lock del alumno, estado de cita y asociación usan el inicio RPC real.
    create function trainer_private.start_workout_execution(p_template uuid) returns uuid
    language plpgsql security definer set search_path='' as $$
    declare execution uuid:=gen_random_uuid();
    begin
      insert into public.workout_executions values(execution,auth.uid(),'in_progress',null,null);
      insert into public.workout_execution_sets values(gen_random_uuid(),execution,0,0,0,0);
      return execution;
    end $$;
    revoke all on function trainer_private.start_workout_execution(uuid) from public,anon,authenticated;
    -- El RPC personal completo no se instala. Este INSERT deliberadamente NO
    -- toma advisory del alumno: el contador real debe proteger la señal también
    -- frente a escritores personales que no usan el circuito profesional.
    create function harness.personal_slot(p_id uuid,p_date date) returns uuid
    language plpgsql security definer set search_path='' as $$
    begin
      if auth.uid() is null then raise insufficient_privilege; end if;
      insert into public.scheduled_workouts(id,user_id,scheduled_date,source) values(p_id,auth.uid(),p_date,'user');
      return p_id;
    end $$;
    -- Stub de corrección: el UPDATE dispara la revisión real de resultados.
    -- La RPC completa, ventana24h, autoría y auditoría se verifican en Dev.
    create function harness.correct_set(p_id uuid) returns void
    language sql security definer set search_path='' as $$
      update public.workout_execution_sets es set actual_reps=actual_reps+1
      from public.workout_executions e where es.id=p_id and es.execution_id=e.id and e.user_id=auth.uid()
    $$;
    grant execute on function harness.personal_slot(uuid,date),harness.correct_set(uuid) to authenticated;
    -- Operaciones de perfil mínimas para observar el orden real FK/perfil/cita.
    -- No representan ni amplían una API de borrado de cuentas del producto.
    create function harness.lock_own_profile() returns void language sql security definer set search_path='' as $$
      select 1 from public.profiles where id=auth.uid() for update
    $$;
    create function harness.delete_own_profile() returns void language sql security definer set search_path='' as $$
      delete from auth.users where id=auth.uid()
    $$;
    create function harness.move_own_slot(p_id uuid) returns void language sql security definer set search_path='' as $$
      update public.scheduled_workouts set scheduled_date=scheduled_date+1 where id=p_id and user_id=auth.uid()
    $$;
    create function harness.rename_own_profile() returns void language sql security definer set search_path='' as $$
      update public.profiles set full_name=full_name||' revisado' where id=auth.uid()
    $$;
    grant execute on function harness.lock_own_profile(),harness.delete_own_profile(),harness.move_own_slot(uuid),harness.rename_own_profile() to authenticated;
    -- Construcción deportiva mínima; controlador de adaptación, ledger y
    -- ocultación de variantes son reales. Recetas completas se validan en Dev.
    create table public.workout_blocks(id uuid,template_id uuid);
    create table public.workout_items(block_id uuid,exercise_id uuid);
    create table public.exercises(id uuid,is_public boolean);
    create function public.create_personal_workout_template(p_payload jsonb) returns uuid
    language plpgsql security definer set search_path='' as $$
    declare result uuid:=gen_random_uuid();
    begin
      insert into public.workout_templates(id,owner_user_id,origin,status,name,version,family_id)
       values(result,auth.uid(),'coach','published',p_payload->>'name',1,result);
      return result;
    end $$;
    """)
    original=(root/'supabase/migrations/20261021122051_trainer_private_workouts_and_assignments.sql').read_text(encoding='utf-8')
    db.query(re.search(r'create table trainer_private\.workout_writes \([\s\S]*?\n\);',original).group())
    db.query(re.search(r'create function trainer_private\.save_trainer_workout\([\s\S]*?end \$\$;',original).group())
    db.query(re.search(r'create function public\.save_trainer_workout\([\s\S]*?\$\$;',original).group())
    db.query('grant execute on function trainer_private.save_trainer_workout(uuid,jsonb,uuid),public.save_trainer_workout(uuid,jsonb,uuid) to authenticated')
    for schema in ('trainer_private','public'):
        pattern=r'create (?:or replace )?function '+schema+r'\.start_scheduled_workout\([\s\S]*?'+(r'end \$\$;' if schema=='trainer_private' else r'\$\$;')
        db.query(re.search(pattern,original).group())
    db.query('grant execute on function trainer_private.start_scheduled_workout(uuid),public.start_scheduled_workout(uuid) to authenticated')
    db.query('create table public.workout_mutation_receipts(user_id uuid,resource_id uuid)')
    db.query((root/'supabase/migrations/20261009000000_discard_in_progress_workout.sql').read_text(encoding='utf-8'))


def scalar(db,sql):
    return db.query(sql)[0][0]


def planning_case(db,source_count=0):
    trainer,x,y,relations=operational_case(db)
    template=str(uuid.uuid4())
    db.query(f"insert into public.workout_templates(id,owner_user_id,origin,status,name,version,estimated_duration_minutes,family_id) values('{template}','{trainer}','coach','published','Receta fijada',1,30,'{template}')")
    monday=scalar(db,"select (current_date-(extract(isodow from current_date)::integer-1)+14)::text")
    recipients=json.dumps([{'client_id':x,'relation_id':relations[0]},{'client_id':y,'relation_id':relations[1]}])
    ids=[]
    if source_count:
        db.query('begin');identity(db,trainer,'aal2')
        for i in range(source_count):
            assignment=str(uuid.uuid4());ids.append(assignment)
            # El caso101 acredita que no se toma solo la página visible.
            pupil_index=0 if source_count>2 else i%2
            db.query(f"select public.assign_trainer_workout('{assignment}','{relations[pupil_index]}','{template}',date '{monday}'+{i%7},'Original')")
        db.query('commit')
    return dict(trainer=trainer,pupils=(x,y),relations=relations,template=template,monday=monday,recipients=recipients,ids=ids)


def as_trainer(db,case,sql):
    db.query('begin');identity(db,case['trainer'],'aal2')
    try:
        result=db.query(sql);db.query('commit');return result
    except:
        db.query('rollback');raise


def race_pair(observer,pool,case,first_sql,second_sql,*,first_user=None,second_user=None,first_aal=None,second_aal=None,repeatable=False,expected=None,blocked=True,retry=False,after_wait_sql=None,after_wait_error=None,after_second_sql=None,after_second_error=None):
    first,second=DB(),DB();pending=None
    try:
        first.query('begin');identity(first,first_user or case['trainer'],first_aal or ('aal1' if first_user else 'aal2'))
        winner=first.query(first_sql)
        second.query('begin isolation level '+('repeatable read' if repeatable else 'read committed'))
        identity(second,second_user or case['trainer'],second_aal or ('aal1' if second_user else 'aal2'))
        second.query('select count(*) from public.trainer_client_relations')
        pid=int(scalar(second,'select pg_backend_pid()'))
        pending=pool.submit(second.query,second_sql)
        if blocked:
            wait_locked(observer,pid,pending)
            first_aborted=False
            if after_wait_sql is not None:
                try:first.query(after_wait_sql)
                except SqlError as error:
                    assert error.code==after_wait_error,(error.code,after_wait_error,str(error))
                    first.query('rollback');first_aborted=True
            if not first_aborted:first.query('commit')
            try:
                loser=pending.result(timeout=15)
                assert expected is None,('se esperaba rechazo',expected,loser)
                second.query('commit')
            except SqlError as error:
                assert error.code in (expected if isinstance(expected,tuple) else (expected,)),(error.code,expected,str(error))
                second.query('rollback')
                loser=None
                if retry:
                    second.query('begin');identity(second,second_user or case['trainer'],second_aal or ('aal1' if second_user else 'aal2'))
                    loser=second.query(second_sql);second.query('commit')
        else:
            # Son recursos independientes: la operación debe poder terminar sin
            # esperar COMMIT del primero y sin generar un ciclo entre filas.
            loser=pending.result(timeout=17)
            assert expected is None
            second.query('commit')
            if after_second_sql is not None:
                try:first.query(after_second_sql)
                except SqlError as error:
                    assert error.code in (after_second_error if isinstance(after_second_error,tuple) else (after_second_error,)),(error.code,after_second_error,str(error))
                    first.query('rollback')
                else:raise AssertionError('Se esperaba denegación del borrado con historial')
            else:first.query('commit')
        return winner,loser
    finally:
        first.close()
        if pending is not None and not pending.done():
            try:pending.result(timeout=17)
            except Exception:pass
        second.close()


def group_delivery_race(observer,pool,edit_first,repeatable):
    case=planning_case(observer);group=str(uuid.uuid4())
    as_trainer(observer,case,f"select public.save_trainer_group('{uuid.uuid4()}','{group}',0,'Grupo',array['{case['pupils'][0]}'::uuid,'{case['pupils'][1]}'::uuid])")
    edit=f"select public.save_trainer_group('{uuid.uuid4()}','{group}',1,'Grupo revisado',array['{case['pupils'][0]}'::uuid])"
    preview=json.loads(as_trainer(observer,case,f"select public.preview_trainer_batch('{case['recipients']}',p_template_id=>'{case['template']}',p_date=>date '{case['monday']}',p_group_id=>'{group}',p_group_revision=>1)")[0][0])
    send=f"select public.deliver_trainer_batch_reviewed('{uuid.uuid4()}','{case['recipients']}','{preview['fingerprint']}',p_template_id=>'{case['template']}',p_date=>date '{case['monday']}',p_group_id=>'{group}',p_group_revision=>1)"
    expected='40001' if edit_first or repeatable else None
    winner,loser=race_pair(observer,pool,case,edit if edit_first else send,send if edit_first else edit,repeatable=repeatable,expected=expected,retry=not edit_first and repeatable)
    count=int(scalar(observer,f"select count(*) from public.trainer_assignments where trainer_id='{case['trainer']}'"))
    assert count==(0 if edit_first else 2),count
    assert scalar(observer,f"select revision from trainer_private.client_groups where id='{group}'")=='2'
    if not edit_first:
        receipt=json.loads(winner[0][0]);assert receipt['assignment_count']==2 and len(receipt['recipients'])==2,receipt
        assert len({id for recipient in receipt['recipients'] for id in recipient['assignment_ids']})==2


def copy_plan(observer,case):
    return json.loads(as_trainer(observer,case,f"select public.preview_trainer_week(date '{case['monday']}',7)")[0][0])


def copy_change_race(observer,pool,copy_first,repeatable,personal=False):
    case=planning_case(observer,source_count=2);plan=copy_plan(observer,case)
    copy=f"select public.copy_trainer_week('{uuid.uuid4()}',date '{case['monday']}',7,'{plan['fingerprint']}')"
    change=(f"select harness.personal_slot('{uuid.uuid4()}',date '{case['monday']}'+7)" if personal else f"select public.start_scheduled_workout('{case['ids'][0]}')")
    expected='40001' if not copy_first or repeatable else None
    winner,loser=race_pair(observer,pool,case,copy if copy_first else change,change if copy_first else copy,first_user=None if copy_first else case['pupils'][0],second_user=case['pupils'][0] if copy_first else None,repeatable=repeatable,expected=expected,retry=copy_first and repeatable)
    destinations=int(scalar(observer,f"select count(*) from public.trainer_assignments a join public.scheduled_workouts s on s.id=a.scheduled_id where a.trainer_id='{case['trainer']}' and s.scheduled_date between date '{case['monday']}'+7 and date '{case['monday']}'+13"))
    assert destinations==(2 if copy_first else 0),destinations
    if copy_first:
        receipt=json.loads(winner[0][0]);assert receipt['assignment_count']==2
        if not personal:assert scalar(observer,f"select status from public.scheduled_workouts where id='{case['ids'][0]}'")=='in_progress'
    else:
        # El rechazo de una vista previa obsoleta nunca conserva un recibo parcial.
        assert scalar(observer,f"select count(*) from trainer_private.bulk_writes where trainer_id='{case['trainer']}' and payload->>'kind'='copy_week'")=='0'


def copy_retry_race(observer,pool,repeatable):
    case=planning_case(observer,source_count=101);plan=copy_plan(observer,case)
    operation=str(uuid.uuid4())
    copy=f"select public.copy_trainer_week('{operation}',date '{case['monday']}',7,'{plan['fingerprint']}')"
    winner,loser=race_pair(observer,pool,case,copy,copy,repeatable=repeatable,expected='40001' if repeatable else None,retry=repeatable)
    a,b=json.loads(winner[0][0]),json.loads(loser[0][0]);assert a==b
    assert a['assignment_count']==101 and len(a['assignments'])==101,a
    assert len({row['assignment_id'] for row in a['assignments']})==101
    assert scalar(observer,f"select count(*) from public.trainer_assignments where trainer_id='{case['trainer']}'")=='202'


def recurrence_case(observer):
    case=planning_case(observer)
    # Agenda completamente nueva: todavía no existe ninguna fila de revisión.
    assert scalar(observer,f"select count(*) from trainer_private.calendar_revisions where user_id in ('{case['pupils'][0]}','{case['pupils'][1]}')")=='0'
    args=f"'{case['recipients']}','{case['template']}',date '{case['monday']}',1,array[1,3],null"
    plan=json.loads(as_trainer(observer,case,f"select public.preview_trainer_recurrence({args})")[0][0])
    operation=str(uuid.uuid4());create=f"select public.create_trainer_recurrence('{operation}',{args},'{plan['fingerprint']}')"
    case.update(recurrence_sql=create,recurrence_operation=operation)
    return case


def recurrence_retry_race(observer,pool,repeatable):
    case=recurrence_case(observer)
    winner,loser=race_pair(observer,pool,case,case['recurrence_sql'],case['recurrence_sql'],repeatable=repeatable,expected='40001' if repeatable else None,retry=repeatable)
    a,b=json.loads(winner[0][0]),json.loads(loser[0][0]);assert a==b
    ids=[id for row in a['recipients'] for id in row['assignment_ids']]
    assert len(ids)==len(set(ids))==a['assignment_count']==4
    assert scalar(observer,f"select count(*) from trainer_private.recurrences where trainer_id='{case['trainer']}'")=='1'
    assert scalar(observer,f"select count(*) from public.trainer_assignments where trainer_id='{case['trainer']}'")=='4'


def recurrence_coincidence_race(observer,pool,series_first,repeatable):
    case=recurrence_case(observer)
    personal=f"select harness.personal_slot('{uuid.uuid4()}',date '{case['monday']}')"
    winner,loser=race_pair(observer,pool,case,
        case['recurrence_sql'] if series_first else personal,
        personal if series_first else case['recurrence_sql'],
        first_user=None if series_first else case['pupils'][0],
        second_user=case['pupils'][0] if series_first else None,
        repeatable=repeatable,expected='40001' if not series_first or repeatable else None,retry=series_first and repeatable)
    assert scalar(observer,f"select count(*) from public.trainer_assignments where trainer_id='{case['trainer']}'")==('4' if series_first else '0')
    assert scalar(observer,f"select count(*) from trainer_private.recurrences where trainer_id='{case['trainer']}'")==('1' if series_first else '0')
    if series_first:
        assert json.loads(winner[0][0])['assignment_count']==4
    else:
        assert scalar(observer,f"select count(*) from trainer_private.bulk_writes where trainer_id='{case['trainer']}' and payload->>'kind'='recurrence'")=='0'


def batch_coincidence_race(observer,pool,batch_first,repeatable):
    case=planning_case(observer)
    plan=json.loads(as_trainer(observer,case,f"select public.preview_trainer_batch('{case['recipients']}',p_template_id=>'{case['template']}',p_date=>date '{case['monday']}')")[0][0])
    operation=str(uuid.uuid4())
    send=f"select public.deliver_trainer_batch_reviewed('{operation}','{case['recipients']}','{plan['fingerprint']}',p_template_id=>'{case['template']}',p_date=>date '{case['monday']}')"
    personal=f"select harness.personal_slot('{uuid.uuid4()}',date '{case['monday']}')"
    winner,loser=race_pair(observer,pool,case,send if batch_first else personal,personal if batch_first else send,
        first_user=None if batch_first else case['pupils'][0],second_user=case['pupils'][0] if batch_first else None,
        repeatable=repeatable,expected='40001' if not batch_first or repeatable else None,retry=batch_first and repeatable)
    assert scalar(observer,f"select count(*) from public.trainer_assignments where trainer_id='{case['trainer']}'")==('2' if batch_first else '0')
    if batch_first:
        assert as_trainer(observer,case,send)==winner
    else:
        assert scalar(observer,f"select count(*) from trainer_private.bulk_writes where trainer_id='{case['trainer']}' and operation_id='{operation}'")=='0'


def profile_lock_race(observer,pool,series_first,repeatable):
    case=recurrence_case(observer);personal_id=str(uuid.uuid4())
    observer.query('begin');identity(observer,case['pupils'][0])
    observer.query(f"select harness.personal_slot('{personal_id}',date '{case['monday']}'+20)");observer.query('commit')
    profile="select harness.lock_own_profile()"
    move=f"select harness.move_own_slot('{personal_id}')"
    # El UPDATE de una cita antigua se realiza mientras el otro actor espera.
    # Si éste conservara calendar esperando profile se produciría un deadlock.
    race_pair(observer,pool,case,case['recurrence_sql'] if series_first else profile,
        profile+'; '+move if series_first else case['recurrence_sql'],
        first_user=None if series_first else case['pupils'][0],second_user=case['pupils'][0] if series_first else None,
        repeatable=repeatable,expected='40001' if repeatable else None,retry=repeatable,
        after_wait_sql=None if series_first else move)
    assert scalar(observer,f"select count(*) from public.trainer_assignments where trainer_id='{case['trainer']}'")=='4'
    assert scalar(observer,f"select (scheduled_date=date '{case['monday']}'+21)::int from public.scheduled_workouts where id='{personal_id}'")=='1'


def profile_delete_race(observer,pool,series_first,repeatable):
    case=recurrence_case(observer)
    delete="select harness.delete_own_profile()"
    expected=('40001' if repeatable else '23503') if series_first else ('40001' if repeatable else '42501')
    race_pair(observer,pool,case,case['recurrence_sql'] if series_first else delete,delete if series_first else case['recurrence_sql'],
        first_user=None if series_first else case['pupils'][0],second_user=case['pupils'][0] if series_first else None,
        repeatable=repeatable,expected=expected)
    assert scalar(observer,f"select count(*) from public.trainer_assignments where trainer_id='{case['trainer']}'")==('4' if series_first else '0')
    assert scalar(observer,"select count(*) from trainer_private.calendar_revisions c where not exists(select 1 from public.profiles p where p.id=c.user_id)")=='0'


def change_case(observer,adapt=False):
    case=planning_case(observer,source_count=1)
    recipe=json.dumps({'name':'Adaptación fixture'}) if adapt else None
    recipe_sql="'"+recipe+"'::jsonb" if recipe else 'null'
    args=f"'{case['ids'][0]}',0,date '{case['monday']}'+7,'Cambio revisado',{recipe_sql}"
    plan=json.loads(as_trainer(observer,case,f"select public.preview_trainer_assignment_change({args})")[0][0])
    operation=str(uuid.uuid4())
    case.update(change=f"select public.change_trainer_assignment_reviewed('{operation}','{case['ids'][0]}',0,date '{case['monday']}'+7,'Cambio revisado','{plan['fingerprint']}',{recipe_sql})",change_operation=operation,adapt=adapt)
    return case


def assignment_change_race(observer,pool,change_first,repeatable,adapt=False,start=False):
    case=change_case(observer,adapt)
    other=(f"select public.start_scheduled_workout('{case['ids'][0]}')" if start else f"select harness.personal_slot('{uuid.uuid4()}',date '{case['monday']}'+7)")
    winner,loser=race_pair(observer,pool,case,case['change'] if change_first else other,other if change_first else case['change'],
        first_user=None if change_first else case['pupils'][0],second_user=case['pupils'][0] if change_first else None,
        repeatable=repeatable,expected='40001' if not change_first or repeatable else None,retry=change_first and repeatable)
    assert scalar(observer,f"select planning_revision from public.trainer_assignments where scheduled_id='{case['ids'][0]}'")==('1' if change_first else '0')
    assert scalar(observer,f"select count(*) from trainer_private.planning_writes where trainer_id='{case['trainer']}' and operation_id='{case['change_operation']}'")==('1' if change_first else '0')
    assert scalar(observer,f"select count(*) from trainer_private.assignment_variants where assignment_id='{case['ids'][0]}'")==('1' if adapt and change_first else '0')
    if start:assert scalar(observer,f"select status from public.scheduled_workouts where id='{case['ids'][0]}'")=='in_progress'
    if change_first:assert as_trainer(observer,case,case['change'])==winner


def change_coach_profile_race(observer,pool,change_first,repeatable,adapt=False):
    case=change_case(observer,adapt)
    lock="select harness.lock_own_profile()"
    rename="select harness.rename_own_profile()"
    race_pair(observer,pool,case,case['change'] if change_first else lock,
        lock+'; '+rename if change_first else case['change'],repeatable=repeatable,
        expected='40001' if not change_first and repeatable else None,retry=not change_first and repeatable,
        after_wait_sql=None if change_first else rename)
    assert scalar(observer,f"select planning_revision from public.trainer_assignments where scheduled_id='{case['ids'][0]}'")=='1'
    assert scalar(observer,f"select count(*) from public.workout_templates where owner_user_id='{case['trainer']}'")==('2' if adapt else '1')


def change_discard_race(observer,pool,change_first,repeatable,adapt=False):
    case=change_case(observer,adapt)
    if change_first:
        discard=f"do $$ declare e uuid; begin e:=public.start_scheduled_workout('{case['ids'][0]}'); perform public.discard_workout_execution(e,'DESCARTAR'); end $$"
    else:
        observer.query('begin');identity(observer,case['pupils'][0])
        execution=scalar(observer,f"select public.start_scheduled_workout('{case['ids'][0]}')");observer.query('commit')
        discard=f"select public.discard_workout_execution('{execution}','DESCARTAR')"
    race_pair(observer,pool,case,case['change'] if change_first else discard,discard if change_first else case['change'],
        first_user=None if change_first else case['pupils'][0],second_user=case['pupils'][0] if change_first else None,
        repeatable=repeatable,expected='40001' if repeatable else None,retry=repeatable)
    assert scalar(observer,f"select planning_revision from public.trainer_assignments where scheduled_id='{case['ids'][0]}'")=='1'
    assert scalar(observer,f"select status||':'||(execution_id is null)::text from public.scheduled_workouts where id='{case['ids'][0]}'")=='planned:true'
    assert scalar(observer,f"select count(*) from public.discarded_workout_executions where user_id='{case['pupils'][0]}'")=='1'
    assert scalar(observer,f"select count(*) from public.workout_execution_sets s join public.workout_executions e on e.id=s.execution_id where e.user_id='{case['pupils'][0]}'")=='0'


def change_publish_race(observer,pool,change_first,repeatable,adapt=False):
    case=change_case(observer,adapt)
    publish=f"select public.save_trainer_workout('{uuid.uuid4()}','{{\"name\":\"Biblioteca revisada\"}}','{case['template']}')"
    race_pair(observer,pool,case,case['change'] if change_first else publish,publish if change_first else case['change'],
        repeatable=repeatable,expected='40001' if change_first and repeatable else None,retry=change_first and repeatable)
    assert scalar(observer,f"select status from public.workout_templates where id='{case['template']}'")=='archived'
    assert scalar(observer,f"select planning_revision from public.trainer_assignments where scheduled_id='{case['ids'][0]}'")=='1'
    assert scalar(observer,f"select count(*) from public.workout_templates where owner_user_id='{case['trainer']}'")==('3' if adapt else '2')


def change_profile_delete_race(observer,pool,change_first,repeatable,adapt=False,coach=False):
    case=change_case(observer,adapt)
    actor=case['trainer'] if coach else case['pupils'][0]
    aal='aal2' if coach else 'aal1'
    delete='select harness.delete_own_profile()'
    lock='select harness.lock_own_profile()'
    denied=('23503','40001') if repeatable else '23503'
    if change_first:
        race_pair(observer,pool,case,case['change'],delete,second_user=actor,second_aal=aal,repeatable=repeatable,expected=denied)
    elif coach:
        # El borrado del propietario se intenta mientras reviewed espera su
        # perfil, ANTES de acceso/cita/calendar. Historial impide borrar; al
        # revertir, reviewed puede continuar sin ciclo ni cambio parcial.
        race_pair(observer,pool,case,lock,case['change'],first_user=actor,first_aal=aal,repeatable=repeatable,
            after_wait_sql=delete,after_wait_error='23503')
    else:
        # Borrar al alumno con historial está protegido por FK existentes. Su
        # perfil bloqueado no debe bloquear reviewed de una cita vieja, que no
        # pide KeyShare de ese perfil tras adquirir scheduled.
        race_pair(observer,pool,case,lock,case['change'],first_user=actor,first_aal=aal,repeatable=repeatable,blocked=False,
            after_second_sql=delete,after_second_error=denied)
    assert scalar(observer,f"select planning_revision from public.trainer_assignments where scheduled_id='{case['ids'][0]}'")=='1'
    assert scalar(observer,f"select count(*) from public.profiles where id='{actor}'")=='1'
    assert scalar(observer,"select count(*) from trainer_private.calendar_revisions c where not exists(select 1 from public.profiles p where p.id=c.user_id)")=='0'


def independent_coaches_race(observer,pool,repeatable):
    first,second=recurrence_case(observer),recurrence_case(observer)
    winner,other=race_pair(observer,pool,first,first['recurrence_sql'],second['recurrence_sql'],
        second_user=second['trainer'],second_aal='aal2',repeatable=repeatable,blocked=False)
    assert json.loads(winner[0][0])['assignment_count']==json.loads(other[0][0])['assignment_count']==4
    for case in (first,second):
        assert scalar(observer,f"select count(*) from public.trainer_assignments where trainer_id='{case['trainer']}'")=='4'


def active_recurrence(observer):
    case=recurrence_case(observer)
    receipt=json.loads(as_trainer(observer,case,case['recurrence_sql'])[0][0]);case['series']=receipt['series_id']
    case['source']=next(row for row in receipt['recipients'] if row['client_id']==case['pupils'][0])['assignment_ids'][0]
    return case


def withdrawal_sql(observer,case):
    plan=json.loads(as_trainer(observer,case,f"select public.preview_trainer_recurrence_withdrawal('{case['series']}',date '{case['monday']}')")[0][0])
    return f"select public.withdraw_trainer_recurrence('{uuid.uuid4()}','{case['series']}',date '{case['monday']}','{plan['fingerprint']}')"


def withdraw_start_race(observer,pool,withdraw_first,repeatable):
    case=active_recurrence(observer)
    withdraw=withdrawal_sql(observer,case);start=f"select public.start_scheduled_workout('{case['source']}')"
    expected=('40001' if repeatable else '42501') if withdraw_first else '40001'
    winner,loser=race_pair(observer,pool,case,withdraw if withdraw_first else start,start if withdraw_first else withdraw,first_user=None if withdraw_first else case['pupils'][0],second_user=case['pupils'][0] if withdraw_first else None,repeatable=repeatable,expected=expected)
    cancelled=scalar(observer,f"select count(*) from trainer_private.recurrence_assignments a join public.scheduled_workouts s on s.id=a.scheduled_id where a.recurrence_id='{case['series']}' and s.status='cancelled'")
    assert cancelled==('4' if withdraw_first else '0'),cancelled
    status=scalar(observer,f"select status from public.scheduled_workouts where id='{case['source']}'")
    assert status==('cancelled' if withdraw_first else 'in_progress'),status


def withdraw_end_race(observer,pool,withdraw_first,repeatable):
    case=active_recurrence(observer)
    withdraw=withdrawal_sql(observer,case);end=f"select public.end_trainer_relation('{case['relations'][0]}')"
    expected=('40001' if repeatable else None) if withdraw_first else '40001'
    race_pair(observer,pool,case,withdraw if withdraw_first else end,end if withdraw_first else withdraw,repeatable=repeatable,expected=expected,retry=withdraw_first and repeatable)
    cancelled=int(scalar(observer,f"select count(*) from trainer_private.recurrence_assignments a join public.scheduled_workouts s on s.id=a.scheduled_id where a.recurrence_id='{case['series']}' and s.status='cancelled'"))
    assert cancelled==(4 if withdraw_first else 2),cancelled
    assert scalar(observer,f"select count(*) from public.trainer_client_relations where id='{case['relations'][0]}' and ended_at is not null")=='1'


def withdraw_correction_race(observer,pool,withdraw_first,repeatable):
    case=active_recurrence(observer)
    observer.query('begin');identity(observer,case['pupils'][0])
    execution=scalar(observer,f"select public.start_scheduled_workout('{case['source']}')");observer.query('commit')
    set_id=scalar(observer,f"select id from public.workout_execution_sets where execution_id='{execution}'")
    withdraw=withdrawal_sql(observer,case);correct=f"select harness.correct_set('{set_id}')"
    race_pair(observer,pool,case,withdraw if withdraw_first else correct,correct if withdraw_first else withdraw,first_user=None if withdraw_first else case['pupils'][0],second_user=case['pupils'][0] if withdraw_first else None,repeatable=repeatable,blocked=False)
    assert scalar(observer,f"select actual_reps from public.workout_execution_sets where id='{set_id}'")=='1'
    assert scalar(observer,f"select status from public.scheduled_workouts where id='{case['source']}'")=='in_progress'
    assert scalar(observer,f"select count(*) from trainer_private.recurrence_assignments a join public.scheduled_workouts s on s.id=a.scheduled_id where a.recurrence_id='{case['series']}' and s.status='cancelled'")=='3'


with tempfile.TemporaryDirectory(prefix='entrenaop-planning-race-') as work:
    work=Path(work).resolve();data=work/'data'
    subprocess.run([str(bin_dir/'initdb'),'-D',str(data),'-U','postgres','-A','trust','--no-locale','-E','UTF8'],check=True,capture_output=True)
    started=False;observer=None;failures=[];blocked_count=0;independent_count=0
    try:
        subprocess.run([str(bin_dir/'pg_ctl'),'-D',str(data),'-l',str(work/'server.log'),'-o',f'-h 127.0.0.1 -p {port}','-w','start'],check=True,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
        started=True;observer=DB();observer.query(bootstrap)
        assert scalar(observer,'show server_version').startswith('17.')
        for filename in ('20261020072345_trainer_access_and_client_relations.sql','20261021074426_trainer_portal_summaries.sql','20261021075243_trainer_mfa_and_directory.sql','20261021115014_trainer_client_portfolio.sql'):
            observer.query((root/'supabase/migrations'/filename).read_text(encoding='utf-8'))
        install_context(observer)
        cases=[]
        for first in (False,True):
            for rr in (False,True):
                cases += [
                    (f'grupo/entrega edición primero={first} RR={rr}',lambda first=first,rr=rr:group_delivery_race(observer,pool,first,rr),True),
                    (f'copia/inicio copia primero={first} RR={rr}',lambda first=first,rr=rr:copy_change_race(observer,pool,first,rr),True),
                    (f'copia/coincidencia copia primero={first} RR={rr}',lambda first=first,rr=rr:copy_change_race(observer,pool,first,rr,personal=True),True),
                    (f'serie/coincidencia serie primero={first} RR={rr}',lambda first=first,rr=rr:recurrence_coincidence_race(observer,pool,first,rr),True),
                    (f'tanda/coincidencia tanda primero={first} RR={rr}',lambda first=first,rr=rr:batch_coincidence_race(observer,pool,first,rr),True),
                    (f'perfil FOR UPDATE/cita antigua serie primero={first} RR={rr}',lambda first=first,rr=rr:profile_lock_race(observer,pool,first,rr),True),
                    (f'borrado perfil/serie serie primero={first} RR={rr}',lambda first=first,rr=rr:profile_delete_race(observer,pool,first,rr),True),
                    (f'retirada/inicio retirada primero={first} RR={rr}',lambda first=first,rr=rr:withdraw_start_race(observer,pool,first,rr),True),
                    (f'retirada/baja retirada primero={first} RR={rr}',lambda first=first,rr=rr:withdraw_end_race(observer,pool,first,rr),True),
                    (f'retirada/corrección independiente retirada primero={first} RR={rr}',lambda first=first,rr=rr:withdraw_correction_race(observer,pool,first,rr),False),
                ]
        for rr in (False,True):
            cases += [
                (f'creación serie mismo UUID RR={rr}',lambda rr=rr:recurrence_retry_race(observer,pool,rr),True),
                (f'copia101 mismo UUID RR={rr}',lambda rr=rr:copy_retry_race(observer,pool,rr),True),
                (f'preparadores independientes RR={rr}',lambda rr=rr:independent_coaches_race(observer,pool,rr),False),
            ]
        for first in (False,True):
            for rr in (False,True):
                for adapt in (False,True):
                    label='adaptar' if adapt else 'mover'
                    cases += [
                        (f'{label}/personal cambio primero={first} RR={rr}',lambda first=first,rr=rr,adapt=adapt:assignment_change_race(observer,pool,first,rr,adapt),True),
                        (f'{label}/inicio cambio primero={first} RR={rr}',lambda first=first,rr=rr,adapt=adapt:assignment_change_race(observer,pool,first,rr,adapt,start=True),True),
                        (f'{label}/coach FOR UPDATE cambio primero={first} RR={rr}',lambda first=first,rr=rr,adapt=adapt:change_coach_profile_race(observer,pool,first,rr,adapt),True),
                        (f'{label}/publicar biblioteca cambio primero={first} RR={rr}',lambda first=first,rr=rr,adapt=adapt:change_publish_race(observer,pool,first,rr,adapt),True),
                        (f'{label}/descartar cambio primero={first} RR={rr}',lambda first=first,rr=rr,adapt=adapt:change_discard_race(observer,pool,first,rr,adapt),True),
                        (f'{label}/borrar coach cambio primero={first} RR={rr}',lambda first=first,rr=rr,adapt=adapt:change_profile_delete_race(observer,pool,first,rr,adapt,coach=True),True),
                        (f'{label}/borrar alumno cambio primero={first} RR={rr}',lambda first=first,rr=rr,adapt=adapt:change_profile_delete_race(observer,pool,first,rr,adapt),first),
                    ]
        if args.case_filter:
            cases=[case for case in cases if args.case_filter in case[0]]
            if not cases:raise ValueError('El filtro no selecciona ningún caso')
        with concurrent.futures.ThreadPoolExecutor(max_workers=1) as pool:
            for label,run,blocked in cases:
                passed=0
                for iteration in range(3):
                    try:
                        run();passed+=1
                        if blocked:blocked_count+=1
                        else:independent_count+=1
                    except Exception as error:
                        failures.append((label,iteration,type(error).__name__,str(error)))
                        print('FAIL:',label,'repetición',iteration+1,repr(error),flush=True)
                        break
                if passed==3:print('OK:',label,'(3 contenciones)' if blocked else '(3 concurrencias sin bloqueo esperado)',flush=True)
        print(json.dumps({'blocked_passed':blocked_count,'independent_passed':independent_count,'failures':failures},ensure_ascii=True),flush=True)
        if failures:raise AssertionError('Hay contratos de planificación concurrente incumplidos; el runner no modifica archivos SQL ni conecta a Dev.')
    finally:
        if observer is not None:observer.close()
        if started:subprocess.run([str(bin_dir/'pg_ctl'),'-D',str(data),'-m','immediate','-w','stop'],check=True,capture_output=True)
