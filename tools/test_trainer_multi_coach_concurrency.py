"""Admisión compartida real en PostgreSQL17 desechable, sin Dev/producción.

Reutiliza libpq y el servidor temporal del runner de acceso. Instala las RPC,
triggers e índices reales de admisión; el calendario solo aporta su contador.
Los contratos completos de datos y RLS se prueban en el SQL con ROLLBACK.
"""
from pathlib import Path
import ast
source_path=Path(__file__).resolve().with_name('test_trainer_concurrency.py')
source=source_path.read_text(encoding='utf-8')
__file__=str(source_path)
exec(compile(source.split('bootstrap =',1)[0],str(source_path),'exec'),globals())
bootstrap=next(ast.literal_eval(n.value) for n in ast.parse(source).body if isinstance(n,ast.Assign) and any(isinstance(t,ast.Name) and t.id=='bootstrap' for t in n.targets))

def accept_pair(observer,pool,*,repeatable=False,prior=False,duplicate=False,same_code=False):
    a,b,x,_,codes=setup_case(observer,limit=5)
    if prior:
        coach=str(uuid.uuid4())
        observer.query(f"insert into auth.users values('{coach}'); insert into public.profiles values('{coach}','Anterior'); insert into public.trainer_access(trainer_id,enabled,client_limit,last_reason) values('{coach}',true,5,'Fixture'); insert into public.trainer_client_relations(trainer_id,client_id) values('{coach}','{x}')")
    second_code=codes[0] if same_code else codes[1] if duplicate else codes[2]
    first,second=DB(),DB()
    try:
        first.query('begin');identity(first,x)
        relation=first.query(f"select public.accept_trainer_invitation('{codes[0]}')")[0][0]
        second.query('begin isolation level '+('repeatable read' if repeatable else 'read committed'));identity(second,x)
        second.query('select count(*) from public.trainer_client_relations')
        pid=int(second.query('select pg_backend_pid()')[0][0])
        future=pool.submit(second.query,f"select public.accept_trainer_invitation('{second_code}')")
        wait_locked(observer,pid,future);first.query('commit')
        expected='40001' if repeatable else None if same_code else '23505' if duplicate else '23514' if prior else None
        try:
            result=future.result(timeout=10)[0][0]
            assert expected is None,(expected,result)
            if same_code: assert result==relation
            second.query('commit')
        except SqlError as error:
            assert error.code==expected,(error.code,expected,str(error))
            second.query('rollback')
        if repeatable:
            # Un snapshot obsoleto debe reintentarse, y solo entonces decidir
            # con el conjunto de vínculos ya confirmado por el ganador.
            second.query('begin');identity(second,x)
            retry_error='23505' if duplicate else '23514' if prior else None
            try:
                retried=second.query(f"select public.accept_trainer_invitation('{second_code}')")[0][0]
                if same_code: assert retried==relation
                assert retry_error is None
                second.query('commit')
            except SqlError as error:
                assert error.code==retry_error,(error.code,retry_error)
                second.query('rollback')
        expected_count=2 if prior or not(duplicate or same_code) else 1
        assert observer.query(f"select count(*) from public.trainer_client_relations where client_id='{x}' and ended_at is null")==[[str(expected_count)]]
        assert observer.query(f"select count(*) from public.trainer_clients where trainer_id='{a}' and client_id='{x}'")==[['1']]
    finally:
        first.close();second.close()

def consent_end_race(observer,pool,*,end_first,repeatable):
    _,_,x,_,codes=setup_case(observer,limit=5)
    observer.query('begin');identity(observer,x)
    relation=observer.query(f"select public.accept_trainer_invitation('{codes[0]}')")[0][0]
    observer.query('commit')
    first,second=DB(),DB()
    enable=f"select public.set_my_trainer_calendar_sharing('{x}',true,0)"
    end=f"select public.end_trainer_relation('{relation}')"
    try:
        first.query('begin');identity(first,x);first.query(end if end_first else enable)
        second.query('begin isolation level '+('repeatable read' if repeatable else 'read committed'));identity(second,x)
        second.query('select count(*) from public.trainer_client_relations')
        pid=int(second.query('select pg_backend_pid()')[0][0])
        future=pool.submit(second.query,enable if end_first else end)
        wait_locked(observer,pid,future);first.query('commit')
        expected='40001' if repeatable else '23514' if end_first else None
        try:
            future.result(timeout=10);assert expected is None;second.query('commit')
        except SqlError as error:
            assert error.code==expected,(error.code,expected,str(error));second.query('rollback')
        if repeatable:
            second.query('begin');identity(second,x)
            try:
                second.query(enable if end_first else end)
                assert not end_first;second.query('commit')
            except SqlError as error:
                assert end_first and error.code=='23514';second.query('rollback')
        assert observer.query(f"select count(*) from trainer_private.calendar_sharing where client_id='{x}' and enabled")==[['0']]
        assert observer.query(f"select count(*) from public.trainer_client_relations where client_id='{x}' and ended_at is null")==[['0']]
    finally:
        first.close();second.close()

with tempfile.TemporaryDirectory(prefix='entrenaop-multi-coach-') as work:
    work=Path(work).resolve();data=work/'data';started=False;observer=None
    subprocess.run([str(bin_dir/'initdb'),'-D',str(data),'-U','postgres','-A','trust','--no-locale','-E','UTF8'],check=True,capture_output=True)
    try:
        subprocess.run([str(bin_dir/'pg_ctl'),'-D',str(data),'-l',str(work/'server.log'),'-o',f'-h 127.0.0.1 -p {port}','-w','start'],check=True,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL);started=True
        observer=DB();assert observer.query('show server_version')[0][0].startswith('17.')
        observer.query(bootstrap)
        for filename in ['20261020072345_trainer_access_and_client_relations.sql','20261021074426_trainer_portal_summaries.sql','20261021075243_trainer_mfa_and_directory.sql','20261021115014_trainer_client_portfolio.sql']:
            observer.query((root/'supabase/migrations'/filename).read_text(encoding='utf-8'))
        observer.query('create table trainer_private.calendar_revisions(user_id uuid primary key,revision bigint not null)')
        migration=(root/'supabase/migrations/20261024175746_trainer_multi_coach_calendar.sql').read_text(encoding='utf-8')
        observer.query(migration.split('create function trainer_private.my_calendar_sharing',1)[0]+'commit;')
        for name in ['my_calendar_sharing','set_my_calendar_sharing']:
            observer.query(re.search(r'create function trainer_private\.'+name+r'\([\s\S]*?end \$\$;',migration).group())
        for name in ['get_my_trainer_calendar_sharing','set_my_trainer_calendar_sharing']:
            observer.query(re.search(r'create function public\.'+name+r'\([\s\S]*?\$\$;',migration).group())
        observer.query('grant execute on function trainer_private.my_calendar_sharing(uuid),trainer_private.set_my_calendar_sharing(uuid,boolean,bigint),public.get_my_trainer_calendar_sharing(uuid),public.set_my_trainer_calendar_sharing(uuid,boolean,bigint) to authenticated')
        observer.query((root/'supabase/migrations/20261024183546_trainer_calendar_consent_membership_guard.sql').read_text(encoding='utf-8'))
        with concurrent.futures.ThreadPoolExecutor(max_workers=1) as pool:
            for repeatable in (False,True):
                for label,options in [('dos preparadores',{}),('ultima plaza de preparador',{'prior':True}),('pareja duplicada',{'duplicate':True}),('mismo codigo idempotente',{'same_code':True})]:
                    for _ in range(3):accept_pair(observer,pool,repeatable=repeatable,**options)
                    print(f'OK: {label}, RR={repeatable} (3 contenciones)',flush=True)
            # También conserva la última plaza comercial del mismo preparador.
            for repeatable in (False,True):
                for _ in range(3):race(observer,pool,repeatable=repeatable)
            for repeatable in (False,True):
                for end_first in (False,True):
                    for _ in range(3):consent_end_race(observer,pool,end_first=end_first,repeatable=repeatable)
                    print(f'OK: consentimiento/baja, baja primero={end_first}, RR={repeatable} (3 contenciones)',flush=True)
        print('OK: 42 contenciones reales; cupos, pareja, consentimiento/baja y reintentos RC/RR',flush=True)
    finally:
        if observer is not None:observer.close()
        if started:subprocess.run([str(bin_dir/'pg_ctl'),'-D',str(data),'-m','immediate','-w','stop'],check=True,capture_output=True)
