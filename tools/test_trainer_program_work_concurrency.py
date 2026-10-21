"""Trabajos de programas: carreras reales contra PostgreSQL17 local efímero.

Carga guards y motores reales con catálogo mínimo. No acepta DSN externos ni
accede a Dev/producción. Permisos y recetas completas se ensayan aparte con SQL
transaccional y ROLLBACK. Los COMMIT locales solo coordinan los dos escritores.
"""
from pathlib import Path
import ast

source_path=Path(__file__).resolve().with_name('test_trainer_concurrency.py')
source=source_path.read_text(encoding='utf-8')
__file__=str(source_path)
exec(compile(source.split('bootstrap =',1)[0],str(source_path),'exec'),globals())
bootstrap=next(ast.literal_eval(n.value) for n in ast.parse(source).body if isinstance(n,ast.Assign) and any(isinstance(t,ast.Name) and t.id=='bootstrap' for t in n.targets))


def quoted(value):
    return "'"+json.dumps(value,ensure_ascii=False,separators=(',',':')).replace("'","''")+"'::jsonb"


def install_work_fixture(db):
    db.query(bootstrap)
    db.query("""create schema trainer_private;
    create table public.trainer_access(trainer_id uuid primary key references public.profiles on delete cascade,enabled boolean,valid_until timestamptz);
    create table public.workout_templates(id uuid primary key,owner_user_id uuid references public.profiles on delete cascade,origin text,status text);
    """)
    mfa=(root/'supabase/migrations/20261021075243_trainer_mfa_and_directory.sql').read_text(encoding='utf-8')
    db.query(re.search(r'create function trainer_private\.has_trainer_mfa\(\)[\s\S]*?\$\$;',mfa).group())
    workouts=(root/'supabase/migrations/20261021122051_trainer_private_workouts_and_assignments.sql').read_text(encoding='utf-8')
    db.query(re.search(r'create function trainer_private\.require_authoring_access\(\)[\s\S]*?end \$\$;',workouts).group())
    programs=(root/'supabase/migrations/20261021132641_trainer_private_programs.sql').read_text(encoding='utf-8')
    for name in ('programs','program_sessions','program_writes'):
        db.query(re.search(r'create table trainer_private\.'+name+r' \([\s\S]*?\n\);',programs).group())
    db.query(re.search(r'create function trainer_private\.save_trainer_program\([\s\S]*?end \$\$;',programs).group())
    db.query(re.search(r'create function public\.save_trainer_program\([\s\S]*?\$\$;',programs).group())
    db.query('grant usage on schema trainer_private to authenticated;grant execute on function public.save_trainer_program(uuid,jsonb,uuid),trainer_private.save_trainer_program(uuid,jsonb,uuid) to authenticated')
    db.query((root/'supabase/migrations/20261021172219_trainer_program_work_drafts.sql').read_text(encoding='utf-8'))


def fixture(db):
    owner,work,template=[str(uuid.uuid4()) for _ in range(3)]
    db.query(f"insert into auth.users values('{owner}');insert into profiles values('{owner}','Trabajo');insert into auth.mfa_factors values('{owner}','verified','totp');insert into trainer_access values('{owner}',true,null);insert into workout_templates values('{template}','{owner}','coach','published')")
    state={'schema':1,'name':'Programa','description':'','audience':'','equipment':'','mode':'guide','categories':[],'primary':None,
        'phases':[{'name':'Campo oculto','weeks':'incorrecto','instructions':'Condiciones','pending':[],'replacements':{},'sessions':[
            {'id':template,'name':'Sesión','warmup':None,'adjustable':False,'minimum':'-','maximum':'incorrecto'}]}]}
    content={'name':'Programa','description':'','audience':'','equipment':'','mode':'guide','phases':[
        {'name':'Entrenamiento','duration_weeks':None,'instructions':'Condiciones','sessions':[
            {'template_id':template,'name':'Sesión','warmup_id':None,'rest':{'min_seconds':None,'max_seconds':None}}]}]}
    return owner,work,state,content


def save(owner,work,revision,state,base=None):
    tail=f",'{base}'" if base else ''
    return f"select public.save_trainer_program_work('{owner}','{work}',{revision},{quoted(state)}{tail})"


def finalize(owner,work,revision,content):
    return f"select public.finalize_trainer_program_work('{owner}','{work}',{revision},{quoted(content)})"


def authenticated(db,owner,sql):
    db.query('begin');identity(db,owner,'aal2')
    try:
        result=db.query(sql);db.query('commit');return result
    except Exception:db.query('rollback');raise


def race_pair(observer,pool,owner,first_sql,second_sql,repeatable,expected,second_owner=None,first_identity=True,second_identity=True):
    first,second=DB(),DB()
    try:
        first.query('begin')
        if first_identity:identity(first,owner,'aal2')
        winner=first.query(first_sql)
        second.query('begin isolation level '+('repeatable read' if repeatable else 'read committed'))
        if second_identity:identity(second,second_owner or owner,'aal2')
        second.query(f"select public.list_trainer_program_work('{second_owner or owner}')" if second_identity else 'select count(*) from public.profiles')
        pid=int(second.query('select pg_backend_pid()')[0][0]);future=pool.submit(second.query,second_sql)
        wait_locked(observer,pid,future);first.query('commit')
        try:
            result=future.result(timeout=10)
            assert expected is None,('Se esperaba conflicto',expected,result)
            second.query('commit');return winner,result
        except SqlError as error:
            assert error.code==expected,(error.code,expected,str(error));second.query('rollback');return winner,None
    finally:first.close();second.close()


def save_race(observer,pool,kind,rr):
    owner,work,state,content=fixture(observer)
    authenticated(observer,owner,save(owner,work,0,state))
    next_state={**state,'name':'Segunda revisión'}
    first_sql=save(owner,work,1,next_state)
    second_sql=save(owner,work,0,state) if kind=='old_receipt' else save(owner,work,1,next_state if kind=='same' else {**state,'name':'Otra pestaña'})
    expected='40001' if rr else '22023' if kind=='different' else None
    winner,result=race_pair(observer,pool,owner,first_sql,second_sql,rr,expected)
    if rr and kind!='different':result=authenticated(observer,owner,second_sql)
    if kind=='same':assert result==winner
    if kind=='old_receipt':
        envelope=json.loads(result[0][0]);assert envelope['receipt']['work']['state']==state and envelope['receipt']['work']['revision']==1 and envelope['current_revision']==2
    assert observer.query(f"select revision from trainer_private.program_works where owner_id='{owner}' and id='{work}'")==[['2']]


def initial_race(observer,pool,kind,rr):
    # También compiten la ausencia inicial del presupuesto y la revisión cero;
    # no basta probar filas ya creadas por otra llamada anterior.
    owner,work,state,content=fixture(observer)
    second_work=str(uuid.uuid4()) if kind=='independent' else work
    second_state={**state,'name':'Otra pestaña inicial'} if kind=='different' else state
    second_sql=save(owner,second_work,0,second_state)
    winner,result=race_pair(observer,pool,owner,save(owner,work,0,state),second_sql,rr,
        '40001' if rr else '22023' if kind=='different' else None)
    if rr:
        if kind=='different':
            try:authenticated(observer,owner,second_sql);raise AssertionError('Revisión cero distinta toma recibo confirmado')
            except SqlError as error:assert error.code=='22023'
        else:result=authenticated(observer,owner,second_sql)
    if kind=='same':assert result==winner
    count='2' if kind=='independent' else '1'
    assert observer.query(f"select count(*),min(revision),max(revision) from trainer_private.program_works where owner_id='{owner}'")==[[count,'1','1']]
    assert observer.query(f"select active_count from trainer_private.program_work_limits where owner_id='{owner}'")==[[count]]


def budget_race(observer,pool,kind,rr):
    owner,work,state,content=fixture(observer);other_work=str(uuid.uuid4())
    observer.query(f"insert into trainer_private.program_work_limits(owner_id) values('{owner}')")
    if kind=='active':observer.query(f"update trainer_private.program_work_limits set active_limit=1 where owner_id='{owner}'")
    if kind=='rate':observer.query(f"update trainer_private.program_work_limits set hourly_limit=1 where owner_id='{owner}'")
    if kind=='bytes':
        observer.query('begin');identity(observer,owner,'aal2');observer.query(save(owner,work,0,state));observer.query('reset role')
        used=int(observer.query(f"select retained_bytes from trainer_private.program_work_limits where owner_id='{owner}'")[0][0]);observer.query('rollback')
        observer.query(f"update trainer_private.program_work_limits set byte_limit={used+256} where owner_id='{owner}'")
    second_sql=save(owner,other_work,0,state)
    race_pair(observer,pool,owner,save(owner,work,0,state),second_sql,rr,'40001' if rr else '54000')
    if rr:
        try:authenticated(observer,owner,second_sql);raise AssertionError('El reintento excede presupuesto')
        except SqlError as error:assert error.code=='54000'
    assert observer.query(f"select count(*) from trainer_private.program_works where owner_id='{owner}'")==[['1']]
    assert observer.query(f"select count(*) from trainer_private.program_work_operations where owner_id='{owner}'")==[['1']]
    assert observer.query(f"select (retained_bytes<=byte_limit)::int,active_count from trainer_private.program_work_limits where owner_id='{owner}'")==[['1','1']]


def close_race(observer,pool,kind,rr):
    owner,work,state,content=fixture(observer);authenticated(observer,owner,save(owner,work,0,state))
    close=finalize(owner,work,1,content);discard=f"select public.discard_trainer_program_work('{owner}','{work}',1)"
    if kind=='final_same':first_sql=second_sql=close
    elif kind=='final_first':first_sql,second_sql=close,discard
    else:first_sql,second_sql=discard,close
    winner,result=race_pair(observer,pool,owner,first_sql,second_sql,rr,'40001' if rr or kind!='final_same' else None)
    if kind=='final_same':
        if rr:result=authenticated(observer,owner,second_sql)
        assert result==winner
    expected='discarded' if kind=='discard_first' else 'finalized'
    assert observer.query(f"select lifecycle,revision from trainer_private.program_works where owner_id='{owner}' and id='{work}'")==[[expected,'2']]
    assert observer.query(f"select count(*) from trainer_private.programs where trainer_id='{owner}'")==[['0' if expected=='discarded' else '1']]


def same_base_race(observer,pool,rr):
    owner,work,state,content=fixture(observer);second_work=str(uuid.uuid4())
    base=authenticated(observer,owner,f"select public.save_trainer_program('{uuid.uuid4()}',{quoted(content)})")[0][0]
    for current in (work,second_work):authenticated(observer,owner,save(owner,current,0,state,base))
    race_pair(observer,pool,owner,finalize(owner,work,1,content),finalize(owner,second_work,1,content),rr,'40001')
    assert observer.query(f"select count(*) from trainer_private.programs where trainer_id='{owner}'")==[['2']]
    assert observer.query(f"select lifecycle,revision from trainer_private.program_works where owner_id='{owner}' and id='{second_work}'")==[['open','1']]


def legacy_collision_race(observer,pool,rr,different):
    owner,work,state,content=fixture(observer)
    base=authenticated(observer,owner,f"select public.save_trainer_program('{uuid.uuid4()}',{quoted(content)})")[0][0]
    authenticated(observer,owner,save(owner,work,0,state,base))
    before=observer.query(f"select retained_bytes from trainer_private.program_work_limits where owner_id='{owner}'")
    legacy={**content,'name':'Otro payload legacy'} if different else content
    race_pair(observer,pool,owner,f"select public.save_trainer_program('{work}',{quoted(legacy)})",finalize(owner,work,1,content),rr,'40001' if rr else '22023')
    assert observer.query(f"select count(*) from trainer_private.programs where trainer_id='{owner}'")==[['2']]
    assert observer.query(f"select status from trainer_private.programs where id='{base}'")==[['published']]
    assert observer.query(f"select lifecycle,revision from trainer_private.program_works where owner_id='{owner}' and id='{work}'")==[['open','1']]
    assert observer.query(f"select retained_bytes from trainer_private.program_work_limits where owner_id='{owner}'")==before


def revoke_race(observer,pool,rr):
    owner,work,state,content=fixture(observer)
    race_pair(observer,pool,owner,f"update public.trainer_access set enabled=false where trainer_id='{owner}'",save(owner,work,0,state),rr,'40001' if rr else '42501',first_identity=False)
    assert observer.query(f"select count(*) from trainer_private.program_works where owner_id='{owner}'")==[['0']]


def delete_race(observer,pool,rr,write_first):
    owner,work,state,content=fixture(observer)
    write=save(owner,work,0,state);delete=f"delete from public.profiles where id='{owner}'"
    race_pair(observer,pool,owner,write if write_first else delete,delete if write_first else write,rr,
        '40001' if rr else None if write_first else '42501',first_identity=write_first,second_identity=not write_first)
    if rr and write_first:observer.query(delete)
    for table in ('program_work_limits','program_works','program_work_bodies','program_work_operations'):
        assert observer.query(f"select count(*) from trainer_private.{table} where owner_id='{owner}'")==[['0']]


with tempfile.TemporaryDirectory(prefix='entrenaop-program-work-race-') as workdir:
    workdir=Path(workdir).resolve();data=workdir/'data';started=False;observer=None
    subprocess.run([str(bin_dir/'initdb'),'-D',str(data),'-U','postgres','-A','trust','--no-locale','-E','UTF8'],check=True,capture_output=True)
    try:
        subprocess.run([str(bin_dir/'pg_ctl'),'-D',str(data),'-l',str(workdir/'server.log'),'-o',f'-h 127.0.0.1 -p {port}','-w','start'],check=True,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
        started=True;observer=DB();assert observer.query('show server_version')[0][0].startswith('17.');install_work_fixture(observer)
        count=0
        with concurrent.futures.ThreadPoolExecutor(max_workers=1) as pool:
            for rr in (False,True):
                cases=[(f'save/{kind}',lambda kind=kind:save_race(observer,pool,kind,rr)) for kind in ('same','different','old_receipt')]
                cases += [(f'initial/{kind}',lambda kind=kind:initial_race(observer,pool,kind,rr)) for kind in ('same','different','independent')]
                cases += [(f'budget/{kind}',lambda kind=kind:budget_race(observer,pool,kind,rr)) for kind in ('active','bytes','rate')]
                cases += [(f'close/{kind}',lambda kind=kind:close_race(observer,pool,kind,rr)) for kind in ('final_same','final_first','discard_first')]
                cases += [('same_base',lambda:same_base_race(observer,pool,rr)),('revoke',lambda:revoke_race(observer,pool,rr))]
                cases += [(f'legacy/different={different}',lambda different=different:legacy_collision_race(observer,pool,rr,different)) for different in (False,True)]
                cases += [(f'delete/write_first={first}',lambda first=first:delete_race(observer,pool,rr,first)) for first in (False,True)]
                for label,run in cases:
                    for _ in range(3):run();count+=1
                    print(f'OK: {label}, RR={rr} (3 contenciones observadas)',flush=True)
        print(f'OK: {count} contenciones de trabajos/CAS/cuotas/finalización; sin Dev ni producción',flush=True)
    finally:
        if observer is not None:observer.close()
        if started:subprocess.run([str(bin_dir/'pg_ctl'),'-D',str(data),'-m','immediate','-w','stop'],check=True,capture_output=True)
