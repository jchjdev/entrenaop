"""CAS, favoritos y selección contra PostgreSQL17 local desechable.

Reutiliza solamente libpq/fixtures mínimos del runner original, sin ejecutarlo.
Carga la migración real de preferencias y los guards MFA/acceso reales. El SQL
transaccional de Dev acredita por separado catálogo completo y aislamiento.
Nunca acepta DSN externos ni escribe en Dev/producción.
"""
from pathlib import Path
import ast

source_path=Path(__file__).resolve().with_name('test_trainer_concurrency.py')
source=source_path.read_text(encoding='utf-8')
__file__=str(source_path)
exec(compile(source.split('bootstrap =',1)[0],str(source_path),'exec'),globals())
bootstrap=next(ast.literal_eval(n.value) for n in ast.parse(source).body if isinstance(n,ast.Assign) and any(isinstance(t,ast.Name) and t.id=='bootstrap' for t in n.targets))


def install_preferences(db):
    db.query(bootstrap)
    db.query("""create schema trainer_private;
    create table public.trainer_access(trainer_id uuid primary key references public.profiles on delete cascade,enabled boolean,valid_until timestamptz);
    create table public.admin_permissions(user_id uuid primary key references public.profiles on delete cascade);
    create table public.admin_security_requirements(user_id uuid primary key);
    create table public.exercises(id uuid primary key,is_public boolean,origin text,created_by uuid);
    create table trainer_private.exercise_versions(exercise_id uuid primary key,trainer_id uuid,current boolean);
    """)
    for filename,pattern in [
        ('20261021075243_trainer_mfa_and_directory.sql',r'create function trainer_private\.has_trainer_mfa\(\)[\s\S]*?\$\$;'),
        ('20261021122051_trainer_private_workouts_and_assignments.sql',r'create function trainer_private\.require_authoring_access\(\)[\s\S]*?end \$\$;'),
        ('20261019084842_admin_web_mfa_access.sql',r'create or replace function public\.is_admin\(\)[\s\S]*?\$\$;'),
    ]:
        db.query(re.search(pattern,(root/'supabase/migrations'/filename).read_text(encoding='utf-8')).group())
    db.query((root/'supabase/migrations/20261021162903_trainer_editor_exercise_preferences.sql').read_text(encoding='utf-8'))


def fixture(db):
    owner=str(uuid.uuid4());ids=[str(uuid.uuid4()) for _ in range(24)]
    db.query(f"insert into auth.users values('{owner}');insert into profiles values('{owner}','Preferencias');insert into auth.mfa_factors values('{owner}','verified','totp');insert into trainer_access values('{owner}',true,null);insert into admin_permissions values('{owner}')")
    for exercise in ids:db.query(f"insert into exercises values('{exercise}',true,'system',null)")
    return owner,ids


def favorite(op,exercise,expected=0):
    return f"select public.set_editor_exercise_favorite('{op}','trainer_private','{exercise}',true,{expected})"


def selection(op,exercise):
    return f"select public.record_editor_exercise_selection('{op}','trainer_private','{exercise}')"


def race(observer,pool,kind,repeatable,selection_first=False):
    owner,ids=fixture(observer);first_op=str(uuid.uuid4());second_op=str(uuid.uuid4())
    if kind=='same':second_op=first_op
    if kind=='quota':
        observer.query(f"insert into editor_private.exercise_preference_owners values('{owner}','trainer_private',0);insert into editor_private.exercise_preferences(user_id,context,exercise_id,favorite,favorite_revision) select '{owner}','trainer_private',gen_random_uuid(),true,1 from generate_series(1,499)")
    if kind=='recents':
        observer.query(f"insert into editor_private.exercise_preference_owners values('{owner}','trainer_private',0)")
        for exercise in ids[:20]:observer.query(f"insert into editor_private.exercise_preferences values('{owner}','trainer_private','{exercise}',false,7,clock_timestamp()-interval '1 second')")
        first_sql=selection(first_op,ids[20]);second_sql=selection(second_op,ids[21])
    elif kind=='mixed':
        first_sql=selection(first_op,ids[0]) if selection_first else favorite(first_op,ids[0])
        second_sql=favorite(second_op,ids[0]) if selection_first else selection(second_op,ids[0])
    else:
        first_sql=favorite(first_op,ids[0]);second_sql=favorite(second_op,ids[1] if kind=='quota' else ids[0])
    first,second=DB(),DB()
    try:
        first.query('begin');identity(first,owner,'aal2');confirmed=first.query(first_sql)
        second.query('begin isolation level '+('repeatable read' if repeatable else 'read committed'));identity(second,owner,'aal2')
        second.query('select public.get_editor_exercise_preferences(\'trainer_private\')')
        pid=int(second.query('select pg_backend_pid()')[0][0]);future=pool.submit(second.query,second_sql)
        wait_locked(observer,pid,future);first.query('commit')
        expected='40001' if repeatable or kind=='cas' else '54000' if kind=='quota' else None
        try:
            result=future.result(timeout=10)
            assert expected is None,(kind,repeatable,expected,result)
            if kind=='same':assert result==confirmed
            second.query('commit')
        except SqlError as error:
            assert error.code==expected,(kind,repeatable,error.code,expected,str(error));second.query('rollback')
        if repeatable and kind in ('same','mixed','recents'):
            second.query('begin');identity(second,owner,'aal2');result=second.query(second_sql);second.query('commit')
            if kind=='same':assert result==confirmed
        if repeatable and kind=='quota':
            second.query('begin');identity(second,owner,'aal2')
            try:second.query(second_sql);raise AssertionError('Reintento supera cuota500')
            except SqlError as error:assert error.code=='54000';second.query('rollback')
        if kind in ('cas','same'):
            assert observer.query(f"select favorite,favorite_revision from editor_private.exercise_preferences where user_id='{owner}' and context='trainer_private' and exercise_id='{ids[0]}'")==[['t','1']]
            assert observer.query(f"select count(*) from editor_private.exercise_preference_writes where user_id='{owner}'")==[['1']]
        if kind=='mixed':
            assert observer.query(f"select favorite,favorite_revision,(last_selected_at is not null)::int from editor_private.exercise_preferences where user_id='{owner}' and exercise_id='{ids[0]}'")==[['t','1','1']]
        if kind=='quota':
            assert observer.query(f"select count(*) from editor_private.exercise_preferences where user_id='{owner}' and favorite")==[['500']]
        if kind=='recents':
            assert observer.query(f"select count(*) from editor_private.exercise_preferences where user_id='{owner}' and last_selected_at is not null")==[['20']]
            assert observer.query(f"select min(favorite_revision) from editor_private.exercise_preferences where user_id='{owner}' and exercise_id in ('{ids[0]}','{ids[1]}')")==[['7']]
    finally:first.close();second.close()


with tempfile.TemporaryDirectory(prefix='entrenaop-editor-preferences-race-') as work:
    work=Path(work).resolve();data=work/'data';started=False;observer=None
    subprocess.run([str(bin_dir/'initdb'),'-D',str(data),'-U','postgres','-A','trust','--no-locale','-E','UTF8'],check=True,capture_output=True)
    try:
        subprocess.run([str(bin_dir/'pg_ctl'),'-D',str(data),'-l',str(work/'server.log'),'-o',f'-h 127.0.0.1 -p {port}','-w','start'],check=True,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
        started=True;observer=DB();assert observer.query('show server_version')[0][0].startswith('17.')
        install_preferences(observer)
        with concurrent.futures.ThreadPoolExecutor(max_workers=1) as pool:
            for kind,selection_first in [('cas',False),('same',False),('mixed',False),('mixed',True),('quota',False),('recents',False)]:
                for repeatable in (False,True):
                    for _ in range(3):race(observer,pool,kind,repeatable,selection_first)
                    print(f'OK: {kind},seleccion_primero={selection_first},RR={repeatable} (3 contenciones observadas)',flush=True)
        print('OK: 36 contenciones CAS/recibos/seleccion/cuota/recencia; sin Dev ni produccion',flush=True)
    finally:
        if observer is not None:observer.close()
        if started:subprocess.run([str(bin_dir/'pg_ctl'),'-D',str(data),'-m','immediate','-w','stop'],check=True,capture_output=True)
