"""Archivo/borrado frente a Garmin y resultados en PostgreSQL17 local efímero.

Carga las funciones y triggers reales del bloque, con tablas mínimas. Los contratos
completos y permisos se ensayan en Dev con ROLLBACK. No admite DSN externos.
"""
from pathlib import Path
import ast

base_path=Path(__file__).with_name('test_trainer_concurrency.py').resolve()
base_source=base_path.read_text(encoding='utf-8');__file__=str(base_path)
exec(compile(base_source.split('bootstrap =',1)[0],str(base_path),'exec'),globals())
bootstrap=next(ast.literal_eval(n.value) for n in ast.parse(base_source).body if isinstance(n,ast.Assign) and any(isinstance(t,ast.Name) and t.id=='bootstrap' for t in n.targets))


def install(db):
    db.query(bootstrap)
    db.query("""create schema trainer_private;create schema device_private;
      grant usage on schema trainer_private to authenticated;
      create table public.scheduled_workouts(id uuid primary key,user_id uuid,status text,execution_id uuid);
      create table public.trainer_assignments(scheduled_id uuid primary key references public.scheduled_workouts on delete cascade,
        trainer_id uuid,client_id uuid,result_revision bigint default 0);
      create table trainer_private.assignment_reviews(assignment_id uuid references public.trainer_assignments on delete cascade);
      create table trainer_private.review_writes(assignment_id uuid references public.trainer_assignments on delete cascade);
      create table trainer_private.messages(assignment_id uuid references public.trainer_assignments on delete restrict);
      create table public.exercise_video_assets(assignment_id uuid references public.trainer_assignments on delete restrict);
      create table public.running_week_sessions(scheduled_workout_id uuid references public.scheduled_workouts on delete restrict);
      create table public.performance_week_work(scheduled_workout_id uuid references public.scheduled_workouts on delete restrict);
      create table device_private.training_deliveries(id uuid primary key default gen_random_uuid(),scheduled_id uuid,owner_id uuid,
        status text default 'sent',lease_id uuid,lease_until timestamptz,error_code text,workout_id bigint default 1,schedule_id bigint default 2);
      create table device_private.training_delivery_versions(delivery_id uuid references device_private.training_deliveries,workout_id bigint,schedule_id bigint);
      create table device_private.training_sync_jobs(id uuid primary key default gen_random_uuid(),scheduled_id uuid,owner_id uuid,state text default 'pending',lease_id uuid,lease_until timestamptz);
      create table device_private.activity_confirmations(scheduled_id uuid);
      create function trainer_private.has_trainer_mfa() returns boolean language sql stable as $$select auth.jwt()->>'aal'='aal2'$$;
      create function trainer_private.program_work_identity(uuid) returns void language plpgsql as $$begin
       if auth.uid() is distinct from $1 or not trainer_private.has_trainer_mfa() then raise insufficient_privilege;end if;end$$;
      create function trainer_private.require_authoring_access() returns void language plpgsql as $$begin
       if not trainer_private.has_trainer_mfa() then raise insufficient_privilege;end if;end$$;
      create function public.fixture_result(uuid) returns void language plpgsql security definer as $$begin
       update public.scheduled_workouts set execution_id=gen_random_uuid() where id=$1;
       if not found then raise foreign_key_violation;end if;
       update public.trainer_assignments set result_revision=result_revision+1 where scheduled_id=$1;end$$;""")
    operational=(root/'supabase/migrations/20261021151737_trainer_operational_workflow.sql').read_text(encoding='utf-8')
    db.query(re.search(r'create function trainer_private\.lock_assignment\([\s\S]*?end \$\$;',operational).group())
    lifecycle=(root/'supabase/migrations/20261025214951_trainer_assignment_archive_and_guarded_deletion.sql').read_text(encoding='utf-8')
    db.query(lifecycle.split('-- Filtrar ANTES',1)[0]+'commit;')
    confirmed=(root/'supabase/migrations/20261025222416_trainer_delete_after_confirmed_garmin_withdrawal.sql').read_text(encoding='utf-8')
    db.query(confirmed.split('-- Los recibos permanecen.',1)[0]+'commit;')


def fixture(db):
    coach,pupil,schedule=[str(uuid.uuid4()) for _ in range(3)]
    for user in (coach,pupil):db.query(f"insert into auth.users values('{user}');insert into public.profiles values('{user}','Fixture')")
    db.query(f"insert into public.scheduled_workouts values('{schedule}','{pupil}','cancelled',null);insert into public.trainer_assignments(scheduled_id,trainer_id,client_id) values('{schedule}','{coach}','{pupil}')")
    return dict(coach=coach,pupil=pupil,id=schedule)


def mutate(c,action='delete',revision=0,operation=None):
    return f"select public.change_trainer_assignment_lifecycle('{c['coach']}','{operation or uuid.uuid4()}','{c['id']}',{revision},'{action}')"


def transaction(db,user,sql):
    db.query('begin');identity(db,user,'aal2')
    try:result=db.query(sql);db.query('commit');return result
    except:db.query('rollback');raise


def race(db,pool,first_sql,second_sql,first_user,second_user,rr,expected):
    first,second=DB(),DB();pending=None
    try:
        first.query('begin')
        if first_user:identity(first,first_user,'aal2')
        winner=first.query(first_sql)
        second.query('begin isolation level '+('repeatable read' if rr else 'read committed'))
        if second_user:identity(second,second_user,'aal2')
        second.query('select count(*) from pg_catalog.pg_class')
        pid=int(second.query('select pg_backend_pid()')[0][0]);pending=pool.submit(second.query,second_sql)
        wait_locked(db,pid,pending);first.query('commit')
        try:
            result=pending.result(timeout=10)
            assert expected is None,('rechazo esperado',expected,result)
            second.query('commit')
        except SqlError as e:
            assert e.code==expected,(e.code,expected,str(e));second.query('rollback');result=None
        return winner,result
    finally:
        first.close()
        if pending is not None and not pending.done():
            try:pending.result(timeout=12)
            except Exception:pass
        second.close()


def external_race(db,pool,rr,external_first,table):
    c=fixture(db);link=f"insert into device_private.{table}(scheduled_id) values('{c['id']}')";delete=mutate(c)
    race(db,pool,link if external_first else delete,delete if external_first else link,
      None if external_first else c['coach'],c['coach'] if external_first else None,rr,
      '40001' if rr else '22023' if external_first else '23503')
    present=db.query(f"select id from public.scheduled_workouts where id='{c['id']}'")
    assert bool(present)==external_first
    if external_first:
        try:transaction(db,c['coach'],mutate(c));raise AssertionError('Borra referencia externa tras reintento')
        except SqlError as e:assert e.code=='22023'
    else:
        try:db.query(link);raise AssertionError('Enlace tardío tras borrado')
        except SqlError as e:assert e.code=='23503'


def idempotent(db,pool,rr):
    c=fixture(db);sql=mutate(c,action='archive',operation=str(uuid.uuid4()))
    first,second=race(db,pool,sql,sql,c['coach'],c['coach'],rr,'40001' if rr else None)
    retry=transaction(db,c['coach'],sql)
    assert first==retry
    if not rr:assert first==second
    assert db.query(f"select revision from trainer_private.assignment_lifecycle where assignment_id='{c['id']}'")==[['1']]


def stale_archive(db,pool,rr):
    c=fixture(db)
    race(db,pool,mutate(c,'archive'),mutate(c,'restore'),c['coach'],c['coach'],rr,'40001')
    assert db.query(f"select (archived_at is not null)::int from trainer_private.assignment_lifecycle where assignment_id='{c['id']}'")==[['1']]


def result_race(db,pool,rr,result_first):
    c=fixture(db);result=f"select public.fixture_result('{c['id']}')";delete=mutate(c)
    race(db,pool,result if result_first else delete,delete if result_first else result,
      None if result_first else c['coach'],c['coach'] if result_first else None,rr,
      '40001' if rr else '22023' if result_first else '23503')
    assert bool(db.query(f"select id from public.scheduled_workouts where id='{c['id']}'"))==result_first


def confirmed_reopen_race(db,pool,rr,reopen_first,table):
    c=fixture(db)
    db.query(f"insert into device_private.training_deliveries(scheduled_id,owner_id,status) values('{c['id']}','{c['pupil']}','cancelled')")
    db.query(f"insert into device_private.training_sync_jobs(scheduled_id,owner_id,state) values('{c['id']}','{c['pupil']}','done')")
    assert db.query(f"select trainer_private.assignment_delete_block('{c['id']}')")==[['']]
    change="status='cancelling'" if table=='training_deliveries' else "state='pending'"
    reopen=f"update device_private.{table} set {change} where scheduled_id='{c['id']}'"
    delete=mutate(c)
    race(db,pool,reopen if reopen_first else delete,delete if reopen_first else reopen,
      None if reopen_first else c['coach'],c['coach'] if reopen_first else None,rr,
      '40001' if rr else '22023' if reopen_first else '23503')
    assert bool(db.query(f"select id from public.scheduled_workouts where id='{c['id']}'"))==reopen_first
    if not reopen_first:
        assert db.query(f"select status from device_private.training_deliveries where scheduled_id='{c['id']}'")==[['cancelled']]
        assert db.query(f"select state from device_private.training_sync_jobs where scheduled_id='{c['id']}'")==[['done']]


with tempfile.TemporaryDirectory(prefix='entrenaop-assignment-lifecycle-race-') as directory:
    directory=Path(directory).resolve();data=directory/'data';started=False;observer=None;count=0
    subprocess.run([str(bin_dir/'initdb'),'-D',str(data),'-U','postgres','-A','trust','--no-locale','-E','UTF8'],check=True,capture_output=True)
    try:
        subprocess.run([str(bin_dir/'pg_ctl'),'-D',str(data),'-l',str(directory/'server.log'),'-o',f'-h 127.0.0.1 -p {port}','-w','start'],check=True,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
        started=True;observer=DB();install(observer)
        with concurrent.futures.ThreadPoolExecutor(max_workers=1) as pool:
            for rr in (False,True):
                for first in (False,True):
                    for table in ('training_deliveries','training_sync_jobs','activity_confirmations'):
                        for _ in range(3):external_race(observer,pool,rr,first,table);count+=1
                        print(f'OK {table} referencia primero={first} RR={rr}',flush=True)
                    for _ in range(3):result_race(observer,pool,rr,first);count+=1
                    print(f'OK resultado primero={first} RR={rr}',flush=True)
                for first in (False,True):
                    for table in ('training_deliveries','training_sync_jobs'):
                        for _ in range(3):confirmed_reopen_race(observer,pool,rr,first,table);count+=1
                        print(f'OK confirmada/{table} reapertura primero={first} RR={rr}',flush=True)
                for test in (idempotent,stale_archive):
                    for _ in range(3):test(observer,pool,rr);count+=1
                    print(f'OK {test.__name__} RR={rr}',flush=True)
        print(f'OK: {count} carreras; sin Dev ni producción',flush=True)
    finally:
        if observer is not None:observer.close()
        if started:subprocess.run([str(bin_dir/'pg_ctl'),'-D',str(data),'-m','immediate','-w','stop'],check=True,capture_output=True)
