"""Continuidad de padres y adaptaciones en PostgreSQL17 local efímero.

Reutiliza los motores de planificación y checkpoints reales. El catálogo y el
constructor deportivo son mínimos; recetas y RLS se verifican además en Dev con
ROLLBACK. No admite DSN externos ni modifica Dev/producción.
"""
from pathlib import Path

source_path = Path(__file__).with_name('test_trainer_planning_concurrency.py').resolve()
source = source_path.read_text(encoding='utf-8')
__file__ = str(source_path)
exec(compile(source.split('with tempfile.TemporaryDirectory(', 1)[0], str(source_path), 'exec'), globals())


def quoted(value):
    return "'" + json.dumps(value, ensure_ascii=False).replace("'", "''") + "'::jsonb"


RAW = dict(schema=1, context={}, editor=dict(schema=1, running=False,
    nameText='Pendiente', descriptionText='', durationText='pendiente', segments=[], blocks=[]))
ORIGIN = dict(baseId=None, programId=None, parentWorkId=None, phaseId=None, positionId=None, duplicate=False)
RECIPE = {'name': 'Receta recuperada', 'blocks': []}


def install(db):
    db.query(bootstrap)
    for name in ('20261020072345_trainer_access_and_client_relations.sql',
                 '20261021074426_trainer_portal_summaries.sql',
                 '20261021075243_trainer_mfa_and_directory.sql',
                 '20261021115014_trainer_client_portfolio.sql'):
        db.query((root/'supabase/migrations'/name).read_text(encoding='utf-8'))
    install_context(db)
    db.query('create table public.admin_permissions(user_id uuid primary key)')
    program = (root/'supabase/migrations/20261021132641_trainer_private_programs.sql').read_text(encoding='utf-8')
    db.query(re.search(r'create function trainer_private\.save_trainer_program\([\s\S]*?end \$\$;', program).group())
    db.query(re.search(r'create function public\.save_trainer_program\([\s\S]*?\$\$;', program).group())
    for name in ('20261021172219_trainer_program_work_drafts.sql',
                 '20261021201803_trainer_session_work_recovery.sql',
                 '20261024192459_trainer_contextual_session_recovery.sql'):
        db.query((root/'supabase/migrations'/name).read_text(encoding='utf-8'))


def parent_case(db, pool, rr, action):
    case = planning_case(db)
    owner, parent, child, phase, position = [case['trainer']] + [str(uuid.uuid4()) for _ in range(4)]
    origin = {**ORIGIN, 'parentWorkId': parent, 'phaseId': phase, 'positionId': position}
    state = dict(schema=1, name='Programa', description='', audience='', equipment='',
        mode='guide', categories=[], primary=None, phases=[dict(phaseId=phase, name='Fase',
        weeks='', instructions='', pending=[], sessions=[], sessionWorks={child: origin})])
    save_parent = lambda rev, raw: f"select public.save_trainer_program_work('{owner}','{parent}',{rev},{quoted(raw)})"
    save_child = f"select public.save_trainer_session_work('{owner}','{child}',0,{quoted(origin)},{quoted(RAW)})"
    as_trainer(db, case, save_parent(0, state))
    if action == 'create_parent_first':
        removed = {**state, 'phases': [{**state['phases'][0], 'sessionWorks': {}}]}
        race_pair(db, pool, case, save_parent(1, removed), save_child, repeatable=rr, expected='40001')
        assert scalar(db, f"select count(*) from trainer_private.session_works where id='{child}'") == '0'
        return
    as_trainer(db, case, save_child)
    if action == 'discard_child_first':
        removed = {**state, 'phases': [{**state['phases'][0], 'sessionWorks': {}}]}
        first = f"select public.discard_trainer_session_work('{owner}','{child}',1)"
        second = save_parent(1, removed)
    else:
        as_trainer(db, case, f"select public.save_trainer_session_work('{owner}','{child}',1,{quoted(origin)},{quoted({**RAW, 'intent': RECIPE})})")
        first = f"select public.finalize_trainer_session_work('{owner}','{child}',2)"
        second = save_parent(1, state)
    race_pair(db, pool, case, first, second, repeatable=rr, expected='40001' if rr else None)
    if action != 'discard_child_first':
        assert scalar(db, f"select count(*) from trainer_private.workout_writes where trainer_id='{owner}'") == '1'


def adaptation_case(db, pool, rr, operation, work_first):
    case = planning_case(db, source_count=1)
    owner, assignment, work = case['trainer'], case['ids'][0], str(uuid.uuid4())
    origin = {**ORIGIN, 'baseId': case['template'], 'assignmentId': assignment, 'planningRevision': 0}
    as_trainer(db, case, f"select public.save_trainer_session_work('{owner}','{work}',0,{quoted(origin)},{quoted({**RAW, 'intent': RECIPE})})")
    preview = json.loads(as_trainer(db, case, f"select public.preview_trainer_assignment_session_work('{owner}','{work}',1)")[0][0])
    finish = f"select public.finalize_trainer_assignment_session_work('{owner}','{work}',1,'{preview['fingerprint']}')"
    other = (f"select public.start_scheduled_workout('{assignment}')" if operation == 'start'
        else f"select public.end_trainer_relation('{case['relations'][0]}')" if operation == 'end'
        else finish)
    pupil = case['pupils'][0] if operation == 'start' else None
    expected = '40001' if rr or (not work_first and operation != 'same') else None
    race_pair(db, pool, case, finish if work_first else other, other if work_first else finish,
        first_user=None if work_first else pupil, second_user=pupil if work_first else None,
        repeatable=rr, expected=expected)
    finalized = work_first or operation == 'same'
    assert scalar(db, f"select lifecycle from trainer_private.session_works where id='{work}'") == ('finalized' if finalized else 'open')
    assert scalar(db, f"select planning_revision from trainer_assignments where scheduled_id='{assignment}'") == ('1' if finalized else '0')


with tempfile.TemporaryDirectory(prefix='entrenaop-context-work-race-') as directory:
    directory = Path(directory).resolve(); data = directory/'data'; started = False; observer = None
    subprocess.run([str(bin_dir/'initdb'), '-D', str(data), '-U', 'postgres', '-A', 'trust', '--no-locale', '-E', 'UTF8'], check=True, capture_output=True)
    try:
        subprocess.run([str(bin_dir/'pg_ctl'), '-D', str(data), '-l', str(directory/'server.log'), '-o', f'-h 127.0.0.1 -p {port}', '-w', 'start'], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        started = True; observer = DB(); install(observer); count = 0
        with concurrent.futures.ThreadPoolExecutor(max_workers=1) as pool:
            for rr in (False, True):
                for action in ('create_parent_first', 'discard_child_first', 'final_child_first'):
                    for _ in range(3): parent_case(observer, pool, rr, action); count += 1
                    print(f'OK parent/{action} RR={rr}: 3 contenciones', flush=True)
                for operation in ('same', 'start', 'end'):
                    for work_first in ((True,) if operation == 'same' else (False, True)):
                        for _ in range(3): adaptation_case(observer, pool, rr, operation, work_first); count += 1
                        print(f'OK adapt/{operation} primero={work_first} RR={rr}: 3 contenciones', flush=True)
        print(f'OK: {count} contenciones reales; sin Dev/producción', flush=True)
    finally:
        if observer is not None: observer.close()
        if started: subprocess.run([str(bin_dir/'pg_ctl'), '-D', str(data), '-m', 'immediate', '-w', 'stop'], check=True, capture_output=True)
