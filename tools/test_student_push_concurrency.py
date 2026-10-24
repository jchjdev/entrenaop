"""Instalaciones, cuentas y leases en PostgreSQL17 local desechable.

Carga la migración push y el guard de identidad reales con tablas mínimas de
avisos. No simula FCM ni acredita RLS deportiva; el contrato SQL usa Dev real
con ROLLBACK. No acepta DSN externos ni accede a Dev/producción.
"""
from pathlib import Path
import ast

source_path=Path(__file__).with_name('test_trainer_concurrency.py').resolve()
source=source_path.read_text(encoding='utf-8');__file__=str(source_path)
exec(compile(source.split('bootstrap =',1)[0],str(source_path),'exec'),globals())
bootstrap=next(ast.literal_eval(n.value) for n in ast.parse(source).body if isinstance(n,ast.Assign) and any(isinstance(t,ast.Name) and t.id=='bootstrap' for t in n.targets))

SECRET='a'*64
def install(db):
    db.query(bootstrap)
    db.query("""create role service_role;create schema trainer_private;
    create table public.trainer_access(trainer_id uuid primary key,enabled boolean,valid_until timestamptz);
    create table public.trainer_client_relations(id uuid primary key,trainer_id uuid,client_id uuid,ended_at timestamptz);
    create table trainer_private.student_notices(id uuid primary key default gen_random_uuid(),owner_id uuid references public.profiles on delete cascade,
     relation_id uuid references public.trainer_client_relations,read_at timestamptz,created_at timestamptz default now());""")
    notices=(root/'supabase/migrations/20261021201558_trainer_student_notices.sql').read_text(encoding='utf-8')
    db.query(re.search(r'create function trainer_private\.require_student_notice_owner\([\s\S]*?end \$\$;',notices).group())
    db.query((root/'supabase/migrations/20261024201618_student_push_delivery.sql').read_text(encoding='utf-8'))
    db.query("update push_private.settings set enabled=true,firebase_project_id='push-fixture'")

def as_user(db,user,sql):
    db.query('begin');identity(db,user)
    try:result=db.query(sql);db.query('commit');return result
    except:db.query('rollback');raise

def scalar(db,sql):return db.query(sql)[0][0]

def register(user,device,binding,previous=None,token=None):
    token=token or device.replace('-','')
    return f"select public.register_my_push_device('{user}','{device}','{SECRET}','{binding}',{repr(previous) if previous else 'null'},'{token}','ios')"

def fixture(db):
    a,b,coach,device,binding,relation=[str(uuid.uuid4()) for _ in range(6)]
    for user in (a,b,coach):db.query(f"insert into auth.users values('{user}');insert into public.profiles values('{user}','Push fixture')")
    db.query(f"insert into public.trainer_access values('{coach}',true,null);insert into public.trainer_client_relations values('{relation}','{coach}','{a}',null)")
    as_user(db,a,register(a,device,binding))
    return dict(a=a,b=b,coach=coach,device=device,binding=binding,relation=relation)

def notice(case):return f"insert into trainer_private.student_notices(owner_id,relation_id) values('{case['a']}','{case['relation']}')"
def unregister(case):return f"select public.unregister_my_push_device('{case['a']}','{case['device']}','{SECRET}','{case['binding']}')"

def race(db,pool,first_sql,second_sql,first_user,second_user,rr,expected,blocked=True):
    first,second=DB(),DB();pending=None
    try:
        first.query('begin')
        if first_user=='worker':first.query('set local role service_role')
        elif first_user:identity(first,first_user)
        winner=first.query(first_sql)
        second.query('begin isolation level '+('repeatable read' if rr else 'read committed'))
        if second_user=='worker':second.query('set local role service_role');second.query('select public.get_student_push_worker_configuration()')
        elif second_user:identity(second,second_user);second.query(f"select public.get_my_push_configuration('{second_user}')")
        else:second.query('select count(*) from public.profiles')
        pid=int(scalar(second,'select pg_backend_pid()'));pending=pool.submit(second.query,second_sql)
        if blocked:wait_locked(db,pid,pending);first.query('commit')
        try:
            result=pending.result(timeout=10)
            assert expected is None,('se esperaba rechazo',expected,result)
            second.query('commit')
        except SqlError as error:
            assert error.code==expected,(error.code,expected,str(error));second.query('rollback');result=None
        if not blocked:first.query('commit')
        return winner,result
    finally:
        first.close()
        if pending is not None and not pending.done():
            try:pending.result(timeout=12)
            except Exception:pass
        second.close()

def transfer_case(db,pool,rr,reverse,kind):
    c=fixture(db);new=str(uuid.uuid4())
    transfer=register(c['b'],c['device'],new,c['binding'])
    if kind=='register':other=register(c['a'],c['device'],str(uuid.uuid4()),c['binding'],'Y'+c['device'].replace('-',''))
    elif kind=='logout':other=unregister(c)
    elif kind=='delete':other=f"delete from public.profiles where id='{c['a']}'"
    else:other=notice(c)
    first,second=(other,transfer) if reverse else (transfer,other)
    first_user=(c['a'] if kind in ('register','logout') else None) if reverse else c['b']
    second_user=c['b'] if reverse else c['a'] if kind in ('register','logout') else None
    expected=('40001' if rr else None)
    if kind=='register':expected='40001'
    if kind=='logout' and not reverse:expected='40001' if rr else '42501'
    if kind=='delete' and reverse:expected='40001'
    _,result=race(db,pool,first,second,first_user,second_user,rr,expected)
    if kind=='delete' and not reverse and rr:db.query(other)
    if kind=='notice' and reverse and rr:as_user(db,c['b'],transfer)
    if kind=='logout' and reverse and rr:as_user(db,c['b'],transfer)
    row=db.query(f"select owner_id,active::int from push_private.installations where id='{c['device']}'")
    if kind=='delete' and reverse:assert row==[]
    elif kind=='register' and reverse:assert row==[[c['a'],'1']]
    else:assert row==[[c['b'],'1']],(kind,reverse,rr,row)
    if row:
        assert scalar(db,f"select owner_id from push_private.outbox where installation_id='{c['device']}'")==row[0][0]

def delivery_case(db,pool,rr,notice_first):
    c=fixture(db);db.query(notice(c));db.query(f"update push_private.outbox set next_at=clock_timestamp()-interval '1 second' where installation_id='{c['device']}'")
    db.query('begin;set local role service_role');job=json.loads(scalar(db,'select public.claim_student_push_jobs(5)'))[0];db.query('commit')
    finish=f"select public.finish_student_push_job('{c['device']}','{job['claim_id']}',{job['generation']},'{c['binding']}','sent')"
    event=notice(c)
    race(db,pool,event if notice_first else finish,finish if notice_first else event,None if notice_first else 'worker','worker' if notice_first else None,rr,'40001' if rr else None)
    if rr:
        if notice_first:db.query('begin;set local role service_role');db.query(finish);db.query('commit')
        else:db.query(event)
    assert db.query(f"select (generation>delivered_generation)::int from push_private.outbox where installation_id='{c['device']}'")==[['1']]

def skip_locked_case(db,pool,rr):
    # Aislar esta elección para que una reclamación no tome trabajos de casos
    # anteriores, sin borrar sus fixtures ni modificar el SQL productivo.
    db.query("update push_private.outbox set next_at=clock_timestamp()+interval '1 day'")
    c=fixture(db);db.query(notice(c));db.query(f"update push_private.outbox set next_at=clock_timestamp()-interval '1 second' where installation_id='{c['device']}'")
    winner,second=race(db,pool,'select public.claim_student_push_jobs(1)','select public.claim_student_push_jobs(1)','worker','worker',rr,None,blocked=False)
    assert len(json.loads(winner[0][0]))==1 and json.loads(second[0][0])==[]

with tempfile.TemporaryDirectory(prefix='entrenaop-student-push-race-') as directory:
    directory=Path(directory).resolve();data=directory/'data';started=False;observer=None;count=0
    subprocess.run([str(bin_dir/'initdb'),'-D',str(data),'-U','postgres','-A','trust','--no-locale','-E','UTF8'],check=True,capture_output=True)
    try:
        subprocess.run([str(bin_dir/'pg_ctl'),'-D',str(data),'-l',str(directory/'server.log'),'-o',f'-h 127.0.0.1 -p {port}','-w','start'],check=True,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
        started=True;observer=DB();install(observer)
        with concurrent.futures.ThreadPoolExecutor(max_workers=1) as pool:
            for rr in (False,True):
                for kind in ('register','logout','delete','notice'):
                    for reverse in (False,True):
                        for _ in range(3):transfer_case(observer,pool,rr,reverse,kind);count+=1
                        print(f'OK {kind} inverso={reverse} RR={rr}: 3 contenciones',flush=True)
                for first in (False,True):
                    for _ in range(3):delivery_case(observer,pool,rr,first);count+=1
                    print(f'OK entrega/aviso primero={first} RR={rr}: 3 contenciones',flush=True)
                for _ in range(3):skip_locked_case(observer,pool,rr);count+=1
                print(f'OK SKIP LOCKED RR={rr}: 3 reclamaciones concurrentes',flush=True)
        print(f'OK: {count} carreras reales; sin Dev ni producción',flush=True)
    finally:
        if observer is not None:observer.close()
        if started:subprocess.run([str(bin_dir/'pg_ctl'),'-D',str(data),'-m','immediate','-w','stop'],check=True,capture_output=True)
