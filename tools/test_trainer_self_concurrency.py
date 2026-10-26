"""Alta personal y admisión de alumnos simultáneas, solo en PostgreSQL17 local.

Reutiliza el clúster desechable de admisión; las funciones de cupo y alta propia
son las de la migración real. No conecta a Dev ni a producción.
"""
from pathlib import Path
source_path=Path(__file__).resolve().with_name('test_trainer_multi_coach_concurrency.py')
source=source_path.read_text(encoding='utf-8')
__file__=str(source_path)
exec(compile(source.split('with tempfile.TemporaryDirectory',1)[0],str(source_path),'exec'),globals())

def scenario(observer,pool,*,self_first,repeatable,duplicate=False):
    a,_,x,_,codes=setup_case(observer,limit=1)
    own=f"select public.ensure_trainer_self_client('{a}')"
    accept=f"select public.accept_trainer_invitation('{codes[0]}')"
    one,two=DB(),DB()
    try:
        one.query('begin');identity(one,a if self_first or duplicate else x,'aal2')
        first=one.query(own if self_first or duplicate else accept)[0][0]
        two.query('begin isolation level '+('repeatable read' if repeatable else 'read committed'))
        identity(two,a if not self_first or duplicate else x,'aal2')
        two.query('select count(*) from public.trainer_client_relations')
        pid=int(two.query('select pg_backend_pid()')[0][0])
        command=own if not self_first or duplicate else accept
        future=pool.submit(two.query,command)
        wait_locked(observer,pid,future);one.query('commit')
        try:
            result=future.result(timeout=10)[0][0]
            assert not repeatable
            if duplicate: assert result==first
            two.query('commit')
        except SqlError as error:
            assert repeatable and error.code=='40001',(error.code,str(error))
            two.query('rollback');two.query('begin')
            identity(two,a if not self_first or duplicate else x,'aal2')
            retried=two.query(command)[0][0]
            if duplicate: assert retried==first
            two.query('commit')
        assert observer.query(f"select count(*) from public.trainer_client_relations where trainer_id='{a}' and trainer_id=client_id")==[['1']]
        assert observer.query(f"select count(*) from public.trainer_client_relations where trainer_id='{a}' and trainer_id<>client_id")==[['0' if duplicate else '1']]
        observer.query('begin');identity(observer,a,'aal2')
        used=json.loads(observer.query('select public.get_trainer_access()')[0][0])['active_clients']
        assert used==(0 if duplicate else 1)
        observer.query('rollback')
    finally:
        one.close();two.close()

with tempfile.TemporaryDirectory(prefix='entrenaop-self-') as work:
    work=Path(work).resolve();data=work/'data';started=False;observer=None
    subprocess.run([str(bin_dir/'initdb'),'-D',str(data),'-U','postgres','-A','trust','--no-locale','-E','UTF8'],check=True,capture_output=True)
    try:
        subprocess.run([str(bin_dir/'pg_ctl'),'-D',str(data),'-l',str(work/'server.log'),'-o',f'-h 127.0.0.1 -p {port}','-w','start'],check=True,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL);started=True
        observer=DB();assert observer.query('show server_version')[0][0].startswith('17.')
        observer.query(bootstrap)
        for filename in ['20261020072345_trainer_access_and_client_relations.sql','20261021074426_trainer_portal_summaries.sql','20261021075243_trainer_mfa_and_directory.sql','20261021115014_trainer_client_portfolio.sql']:
            observer.query((root/'supabase/migrations'/filename).read_text(encoding='utf-8'))
        observer.query('create table trainer_private.calendar_revisions(user_id uuid primary key,revision bigint not null)')
        multi=(root/'supabase/migrations/20261024175746_trainer_multi_coach_calendar.sql').read_text(encoding='utf-8')
        observer.query(multi.split('create function trainer_private.my_calendar_sharing',1)[0]+'commit;')
        base=(root/'supabase/migrations/20261021122051_trainer_private_workouts_and_assignments.sql').read_text(encoding='utf-8')
        observer.query(re.search(r'create function trainer_private.require_authoring_access\([\s\S]*?end \$\$;',base).group())
        self_sql=(root/'supabase/migrations/20261026060150_trainer_self_training.sql').read_text(encoding='utf-8')
        # En esta frontera solo hacen falta vínculos/cupo y sus restricciones.
        observer.query(self_sql.split('CREATE OR REPLACE FUNCTION',1)[0].replace('alter table public.trainer_assignments drop constraint trainer_assignments_check;','')+'commit;')
        for name in ['get_trainer_access_without_mfa','admin_set_trainer_access','accept_trainer_invitation','guard_relation_membership']:
            observer.query(re.search(r'CREATE OR REPLACE FUNCTION trainer_private\.'+name+r'\([\s\S]*?end \$function\$;',self_sql).group())
        observer.query(self_sql[self_sql.index('create function trainer_private.ensure_self_client'):])
        with concurrent.futures.ThreadPoolExecutor(max_workers=1) as pool:
            for repeatable in (False,True):
                for label,options in [('dos altas propias',{'duplicate':True,'self_first':True}),('alta propia antes de alumno',{'self_first':True}),('alumno antes de alta propia',{'self_first':False})]:
                    for _ in range(3):scenario(observer,pool,repeatable=repeatable,**options)
                    print(f'OK: {label}, RR={repeatable} (3 contenciones)',flush=True)
        print('OK: 18 contenciones reales; alta propia idempotente y última plaza independiente RC/RR',flush=True)
    finally:
        if observer is not None:observer.close()
        if started:subprocess.run([str(bin_dir/'pg_ctl'),'-D',str(data),'-m','immediate','-w','stop'],check=True,capture_output=True)
