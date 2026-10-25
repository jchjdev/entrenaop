"""Agrupación, acuses y preferencias: carreras RC/RR en PostgreSQL17 local.

Reutiliza el transporte libpq del ensayo push, sin ejecutarlo ni aceptar DSN
externos. Las tablas mínimas no sustituyen el contrato transaccional de Dev.
"""
from pathlib import Path

push_path = Path(__file__).with_name('test_student_push_concurrency.py').resolve()
push_source = push_path.read_text(encoding='utf-8')
__file__ = str(push_path)
exec(compile(push_source.split("with tempfile.TemporaryDirectory(prefix='entrenaop-student-push-race-')", 1)[0], str(push_path), 'exec'), globals())
base_install = install


def install(db):
    base_install(db)
    db.query("""grant usage on schema trainer_private to authenticated;
      alter table trainer_private.student_notices add kind text default 'message',
      add source_id uuid default gen_random_uuid(),add source_revision bigint default 0;
      create table public.scheduled_workouts(id uuid,user_id uuid,scheduled_date date,source text,status text,execution_id uuid);
      create table public.trainer_assignments(scheduled_id uuid,client_id uuid,relation_id uuid);
      create function trainer_private.student_notice_snapshot(uuid,timestamptz default null,uuid default null,text default null)
        returns jsonb language sql as $$select '{"resources":{}}'::jsonb$$;
      create function trainer_private.student_notice_target(uuid) returns jsonb language sql as $$select null::jsonb$$;""")
    db.query((root/'supabase/migrations/20261025204610_trainer_notification_groups_and_reminders.sql').read_text(encoding='utf-8'))


def quiet_off(db, c):
    db.query(f"insert into push_private.preferences(owner_id,quiet_enabled,timezone) values('{c['a']}',false,'UTC')")


def grouped_insert(db, pool, rr):
    c = fixture(db);quiet_off(db, c)
    event = notice(c)
    race(db, pool, event, event, None, None, rr, '40001' if rr else None)
    if rr: db.query(event)
    assert db.query(f"select generation from trainer_private.notice_groups where owner_id='{c['a']}'") == [['2']]
    assert scalar(db, f"select count(*) from trainer_private.student_notices where owner_id='{c['a']}'") == '2'
    assert scalar(db, f"select generation from push_private.notice_jobs where owner_id='{c['a']}'") == '2'


def preferences_cas(db, pool, rr):
    c = fixture(db)
    save = f"select public.save_my_trainer_notice_preferences('{c['a']}',0,'sameDay',540,'UTC',false,1320,480)"
    race(db, pool, save, save, c['a'], c['a'], rr, '40001')
    assert scalar(db, f"select revision from push_private.preferences where owner_id='{c['a']}'") == '1'


def read_watermark(db, pool, rr, event_first):
    c = fixture(db);quiet_off(db, c);db.query(notice(c))
    group = scalar(db, f"select id from trainer_private.notice_groups where owner_id='{c['a']}'")
    ack = f"select public.ack_my_trainer_notice_group('{c['a']}','{group}',1)"
    race(db, pool, notice(c) if event_first else ack, ack if event_first else notice(c),
         None if event_first else c['a'], c['a'] if event_first else None, rr, None, blocked=False)
    assert db.query(f"select group_generation from trainer_private.student_notices where owner_id='{c['a']}' and read_at is null") == [['2']]


def job_race(db, pool, rr, event_first):
    db.query("update push_private.notice_jobs set next_at='infinity'")
    c = fixture(db);quiet_off(db, c);db.query(notice(c))
    db.query(f"update push_private.notice_jobs set next_at=clock_timestamp()-interval '1 second' where owner_id='{c['a']}'")
    db.query('begin;set local role service_role')
    job = json.loads(scalar(db, 'select public.claim_student_notice_jobs(1)'))[0];db.query('commit')
    finish = f"select public.finish_student_notice_job('{job['job_id']}','{job['claim_id']}',{job['generation']},'{c['binding']}','sent')"
    race(db, pool, notice(c) if event_first else finish, finish if event_first else notice(c),
         None if event_first else 'worker', 'worker' if event_first else None, rr, '40001' if rr else None)
    if rr:
        if event_first: db.query('begin;set local role service_role');db.query(finish);db.query('commit')
        else: db.query(notice(c))
    assert db.query(f"select generation,delivered_generation,(next_at>clock_timestamp()+interval '4 minutes')::int from push_private.notice_jobs where id='{job['job_id']}'") == [['2','1','1']]


def claims(db, pool, rr):
    db.query("update push_private.notice_jobs set next_at='infinity'")
    c = fixture(db);quiet_off(db, c);db.query(notice(c))
    db.query(f"update push_private.notice_jobs set next_at=clock_timestamp()-interval '1 second' where owner_id='{c['a']}'")
    first, second = race(db, pool, 'select public.claim_student_notice_jobs(1)', 'select public.claim_student_notice_jobs(1)', 'worker', 'worker', rr, None, blocked=False)
    assert len(json.loads(first[0][0])) == 1 and json.loads(second[0][0]) == []


with tempfile.TemporaryDirectory(prefix='entrenaop-notice-policy-race-') as directory:
    directory = Path(directory).resolve();data = directory/'data';started = False;observer = None;count = 0
    subprocess.run([str(bin_dir/'initdb'), '-D', str(data), '-U', 'postgres', '-A', 'trust', '--no-locale', '-E', 'UTF8'], check=True, capture_output=True)
    try:
        subprocess.run([str(bin_dir/'pg_ctl'), '-D', str(data), '-l', str(directory/'server.log'), '-o', f'-h 127.0.0.1 -p {port}', '-w', 'start'], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        started = True;observer = DB();install(observer)
        with concurrent.futures.ThreadPoolExecutor(max_workers=1) as pool:
            for rr in (False, True):
                for case in (grouped_insert, preferences_cas, claims):
                    for _ in range(3): case(observer, pool, rr);count += 1
                    print(f'OK {case.__name__} RR={rr}', flush=True)
                for first in (False, True):
                    for case in (read_watermark, job_race):
                        for _ in range(3): case(observer, pool, rr, first);count += 1
                        print(f'OK {case.__name__} evento primero={first} RR={rr}', flush=True)
        print(f'OK: {count} carreras reales; sin Dev ni producción', flush=True)
    finally:
        if observer is not None: observer.close()
        if started: subprocess.run([str(bin_dir/'pg_ctl'), '-D', str(data), '-m', 'immediate', '-w', 'stop'], check=True, capture_output=True)
