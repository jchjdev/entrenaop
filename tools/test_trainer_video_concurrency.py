"""Reservas profesionales de vídeo contra PostgreSQL17 local desechable.

Reutiliza el cliente libpq y fixtures de acceso del runner previo sin ejecutarlo.
Las RPC y migraciones de vídeo son las reales; el catálogo y Auth son mínimos.
Los permisos completos se validan con el contrato SQL transaccional en Dev.
Ejemplo: python tools/test_trainer_video_concurrency.py --pg-bin C:/.../bin
"""
from pathlib import Path
import ast
source_path=Path(__file__).resolve().with_name("test_trainer_concurrency.py")
source=source_path.read_text(encoding="utf-8")
__file__=str(source_path)
exec(compile(source.split("bootstrap =",1)[0],str(source_path),"exec"),globals())
bootstrap=next(ast.literal_eval(n.value) for n in ast.parse(source).body if isinstance(n,ast.Assign) and any(isinstance(t,ast.Name) and t.id=="bootstrap" for t in n.targets))

def install_video_fixture(db):
    install_assignment_fixture(db)
    db.query("create role service_role; create function public.is_admin() returns boolean language sql stable as $$select false$$; create table public.exercises(id uuid primary key,origin text,created_by uuid,is_public boolean,video_url text); create table public.workout_executions(id uuid primary key,user_id uuid); create table public.workout_execution_sets(id uuid primary key,execution_id uuid,exercise_video_url text); create function trainer_private.can_read_exercise(uuid) returns boolean language sql stable as $$select false$$")
    for filename in ["20261018150520_bunny_exercise_videos.sql","20261018165149_bunny_video_duration_ten_seconds.sql","20261021151727_trainer_private_videos.sql"]:
        db.query((root/"supabase/migrations"/filename).read_text(encoding="utf-8"))

def video_race(observer,pool,technique,same_operation,repeatable):
    trainer,_,x,y,_=setup_case(observer,limit=2)
    scope="client_technique" if technique else "trainer_exercise"
    observer.query(f"insert into trainer_private.video_limits(trainer_id,scope,asset_limit,byte_limit) values('{trainer}','{scope}',100,104857600)")
    contexts=[]
    for pupil in [x,y]:
        relation,template,assignment,execution=[str(uuid.uuid4()) for _ in range(4)]
        observer.query(f"insert into public.trainer_client_relations(id,trainer_id,client_id) values('{relation}','{trainer}','{pupil}'); insert into public.workout_executions values('{execution}','{pupil}'); insert into public.scheduled_workouts(id,user_id,execution_id) values('{assignment}','{pupil}','{execution}'); insert into public.trainer_assignments(scheduled_id,relation_id,trainer_id,client_id) values('{assignment}','{relation}','{trainer}','{pupil}')")
        contexts.append((assignment,execution))
    op1=str(uuid.uuid4());op2=op1 if same_operation else str(uuid.uuid4())
    def query(op,index):
        context=contexts[index] if technique else None
        extra=f",'{context[0]}','{context[1]}',null" if context else ""
        return f"select public.reserve_exercise_video_upload('{scope}','{op}',42,'fixture.b-cdn.net',1{extra})"
    first,second=DB(),DB()
    index2=0 if same_operation else 1
    try:
        first.query('begin');identity(first,x if technique else trainer,'aal1' if technique else 'aal2')
        winner=first.query(query(op1,0))[0][0]
        second.query('begin isolation level '+('repeatable read' if repeatable else 'read committed'))
        identity(second,(x if same_operation else y) if technique else trainer,'aal1' if technique else 'aal2')
        second.query('select count(*) from public.trainer_access')
        pid=int(second.query('select pg_backend_pid()')[0][0]);future=pool.submit(second.query,query(op2,index2))
        wait_locked(observer,pid,future);first.query('commit')
        expected='40001' if repeatable else None if same_operation else '54000'
        try:
            result=future.result(timeout=10)[0][0]
            assert expected is None and result==winner,(expected,result,winner)
            second.query('commit')
        except SqlError as error:
            assert error.code==expected,(error.code,expected,str(error));second.query('rollback')
        assert observer.query(f"select count(*),sum(reserved_bytes) from public.exercise_video_assets where trainer_id='{trainer}' and scope='{scope}'")==[['1','104857600']]
        if repeatable and same_operation:
            second.query('begin');identity(second,x if technique else trainer,'aal1' if technique else 'aal2')
            assert second.query(query(op2,index2))[0][0]==winner
            second.query('commit')
    finally:
        first.close();second.close()

def feedback_race(observer,pool,same_operation,repeatable):
    trainer,_,pupil,_,_=setup_case(observer)
    relation,assignment,execution,asset,provider=[str(uuid.uuid4()) for _ in range(5)]
    observer.query(f"insert into public.trainer_client_relations(id,trainer_id,client_id) values('{relation}','{trainer}','{pupil}'); insert into public.workout_executions values('{execution}','{pupil}'); insert into public.scheduled_workouts(id,user_id,execution_id) values('{assignment}','{pupil}','{execution}'); insert into public.trainer_assignments(scheduled_id,relation_id,trainer_id,client_id) values('{assignment}','{relation}','{trainer}','{pupil}')")
    observer.query(f"insert into trainer_private.video_limits(trainer_id,scope,feedback_limit) values('{trainer}','client_technique',1); insert into public.exercise_video_assets(id,created_by,scope,trainer_id,assignment_id,execution_id,library_id,cdn_host,source_bytes,source_limit,reserved_bytes,status,provider_video_id,playback_url,duration_seconds,playback_bytes,provider_storage_bytes,duration_limit,playback_limit) values('{asset}','{pupil}','client_technique','{trainer}','{assignment}','{execution}',42,'fixture.b-cdn.net',1,104857600,104857600,'ready','{provider}','https://fixture.b-cdn.net/{provider}/play_720p.mp4',120,1000,10000,180,52428800)")
    op1=str(uuid.uuid4());op2=op1 if same_operation else str(uuid.uuid4())
    def query(op):return f"select public.add_trainer_video_feedback('{op}','{asset}',1,'Controla la bajada')"
    first,second=DB(),DB()
    try:
        first.query('begin');identity(first,trainer,'aal2');winner=first.query(query(op1))[0][0]
        second.query('begin isolation level '+('repeatable read' if repeatable else 'read committed'));identity(second,trainer,'aal2')
        second.query('select count(*) from public.trainer_access')
        pid=int(second.query('select pg_backend_pid()')[0][0]);future=pool.submit(second.query,query(op2))
        wait_locked(observer,pid,future);first.query('commit')
        expected='40001' if repeatable else None if same_operation else '54000'
        try:
            result=future.result(timeout=10)[0][0]
            assert expected is None and result==winner,(expected,result,winner)
            second.query('commit')
        except SqlError as error:
            assert error.code==expected,(error.code,expected,str(error));second.query('rollback')
        assert observer.query(f"select count(*) from trainer_private.video_feedback where asset_id='{asset}'")==[['1']]
        if repeatable and same_operation:
            second.query('begin');identity(second,trainer,'aal2');assert second.query(query(op2))[0][0]==winner;second.query('commit')
    finally:first.close();second.close()

with tempfile.TemporaryDirectory(prefix="entrenaop-trainer-video-race-") as work:
    work=Path(work).resolve();data=work/"data"
    subprocess.run([str(bin_dir/"initdb"),"-D",str(data),"-U","postgres","-A","trust","--no-locale","-E","UTF8"],check=True,capture_output=True)
    started=False;observer=None
    try:
        subprocess.run([str(bin_dir/"pg_ctl"),"-D",str(data),"-l",str(work/"server.log"),"-o",f"-h 127.0.0.1 -p {port}","-w","start"],check=True,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
        started=True;observer=DB();assert observer.query('show server_version')[0][0].startswith('17.')
        observer.query(bootstrap)
        for filename in ["20261020072345_trainer_access_and_client_relations.sql","20261021074426_trainer_portal_summaries.sql","20261021075243_trainer_mfa_and_directory.sql","20261021115014_trainer_client_portfolio.sql"]:
            observer.query((root/"supabase/migrations"/filename).read_text(encoding="utf-8"))
        install_video_fixture(observer)
        with concurrent.futures.ThreadPoolExecutor(max_workers=1) as pool:
            for technique in (False,True):
                for same_operation in (False,True):
                    for repeatable in (False,True):
                        for _ in range(3):video_race(observer,pool,technique,same_operation,repeatable)
                        print(f'OK: tecnica={technique},mismo_envio={same_operation},RR={repeatable} (3 contenciones)',flush=True)
            for same_operation in (False,True):
                for repeatable in (False,True):
                    for _ in range(3):feedback_race(observer,pool,same_operation,repeatable)
                    print(f'OK: comentarios,mismo_envio={same_operation},RR={repeatable} (3 contenciones)',flush=True)
        print('OK: 36 contenciones de reservas y comentarios; cuotas y reintentos RC/RR; sin Dev ni produccion',flush=True)
    finally:
        if observer is not None:observer.close()
        if started:subprocess.run([str(bin_dir/"pg_ctl"),"-D",str(data),"-m","immediate","-w","stop"],check=True,capture_output=True)
