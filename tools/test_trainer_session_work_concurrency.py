"""Recuperación de sesiones en PostgreSQL 17 efímero, sin DSN externos.

Carga MFA, motor real save_trainer_workout y migración real de recuperación.
El constructor deportivo público se sustituye por un catálogo mínimo local:
este ensayo acredita transacciones/locks, no toda la validación deportiva.
El contrato SQL se ejecuta también aquí y puede repetirse sobre Dev con ROLLBACK.
"""
from pathlib import Path
import ast

source_path = Path(__file__).resolve().with_name('test_trainer_concurrency.py')
source = source_path.read_text(encoding='utf-8')
__file__ = str(source_path)
exec(compile(source.split('bootstrap =', 1)[0], str(source_path), 'exec'), globals())
bootstrap = next(ast.literal_eval(n.value) for n in ast.parse(source).body
                 if isinstance(n, ast.Assign) and any(isinstance(t, ast.Name) and t.id == 'bootstrap' for t in n.targets))


def quoted(value):
    return "'" + json.dumps(value, ensure_ascii=False, separators=(',', ':')).replace("'", "''") + "'::jsonb"


ORIGIN = dict(baseId=None, programId=None, parentWorkId=None, phaseId=None, positionId=None, duplicate=False)
EXERCISE = '10000000-0000-4000-8000-000000000099'
RECIPE = {'name': 'Sesión', 'blocks': [{'name': 'Fuerza', 'format': 'straight_sets', 'rounds': 1,
          'rest_after_seconds': 0, 'exercises': [{'exercise_id': EXERCISE,
          'sets': [{'target_reps': 8, 'rest_after_seconds': 60}]}]}]}
RAW = {'schema': 1, 'context': {}, 'editor': {'schema': 1, 'running': False, 'nameText': 'Sin terminar',
       'descriptionText': '', 'durationText': 'pendiente', 'segments': [], 'blocks': []}}


def install(db):
    db.query(bootstrap)
    db.query("""alter table auth.users add column email text;
    alter table auth.mfa_factors add column id uuid default gen_random_uuid(),add column created_at timestamptz,add column updated_at timestamptz;
    create function public.fixture_profile() returns trigger language plpgsql as $$begin insert into profiles values(new.id,'Fixture');return new;end$$;
    create trigger fixture_profile after insert on auth.users for each row execute function public.fixture_profile();
    create schema trainer_private;grant usage on schema trainer_private to authenticated;
    create table public.admin_permissions(user_id uuid primary key);
    create table public.trainer_access(trainer_id uuid primary key references public.profiles on delete cascade,enabled boolean,valid_until timestamptz,client_limit integer,last_reason text);
    create table public.workout_templates(id uuid primary key,owner_user_id uuid references public.profiles on delete cascade,origin text,status text,
      family_id uuid,previous_version_id uuid,version integer default 1,show_in_library boolean default false);
    create table public.exercises(id uuid primary key,is_public boolean,origin text,created_by uuid);
    create table public.workout_blocks(id uuid primary key,template_id uuid references workout_templates on delete cascade);
    create table public.workout_items(id uuid primary key,block_id uuid references workout_blocks on delete cascade,exercise_id uuid references exercises);
    create function public.create_personal_workout_template(p jsonb) returns uuid language plpgsql set search_path='public' as $$
    declare result uuid:=gen_random_uuid();block_id uuid;block jsonb;exercise jsonb;
    begin
      if jsonb_typeof(p->'name') is distinct from 'string' or length(p->>'name')=0 then raise invalid_parameter_value;end if;
      if jsonb_typeof(p->'blocks') is distinct from 'array' or jsonb_array_length(p->'blocks') not between 1 and 10 then
        raise exception 'Workout must contain between 1 and 10 blocks';end if;
      insert into workout_templates values(result,auth.uid(),'coach','published',result,null,1,false);
      for block in select value from jsonb_array_elements(p->'blocks') loop
        block_id:=gen_random_uuid();insert into workout_blocks values(block_id,result);
        for exercise in select value from jsonb_array_elements(block->'exercises') loop
          insert into workout_items values(gen_random_uuid(),block_id,(exercise->>'exercise_id')::uuid);
        end loop;
      end loop;
      return result;
    end $$;""")
    db.query(f"insert into exercises values('{EXERCISE}',true,'system',null)")
    mfa = (root / 'supabase/migrations/20261021075243_trainer_mfa_and_directory.sql').read_text(encoding='utf-8')
    db.query(re.search(r'create function trainer_private\.has_trainer_mfa\(\)[\s\S]*?\$\$;', mfa).group())
    workouts = (root / 'supabase/migrations/20261021122051_trainer_private_workouts_and_assignments.sql').read_text(encoding='utf-8')
    for pattern in (r'create table trainer_private\.workout_writes \([\s\S]*?\n\);',
                    r'create function trainer_private\.require_authoring_access\(\)[\s\S]*?end \$\$;'):
        db.query(re.search(pattern, workouts).group())
    engine = re.search(r'create function trainer_private\.save_trainer_workout\([\s\S]*?end \$\$;', workouts).group()
    # Misma ampliación vigente del motor para ejercicios privados propios.
    engine = engine.replace('where b.template_id=result and not e.is_public',
                            "where b.template_id=result and not e.is_public and not (e.origin='coach' and e.created_by=auth.uid())")
    db.query(engine)
    db.query(re.search(r'create function public\.save_trainer_workout\([\s\S]*?\$\$;', workouts).group())
    db.query('grant execute on function public.save_trainer_workout(uuid,jsonb,uuid),trainer_private.save_trainer_workout(uuid,jsonb,uuid) to authenticated')
    db.query((root / 'supabase/migrations/20261021201803_trainer_session_work_recovery.sql').read_text(encoding='utf-8'))


def fixture(db):
    owner, work = str(uuid.uuid4()), str(uuid.uuid4())
    db.query(f"insert into auth.users(id) values('{owner}');insert into auth.mfa_factors(user_id,status,factor_type) values('{owner}','verified','totp');insert into trainer_access(trainer_id,enabled) values('{owner}',true)")
    state = json.loads(json.dumps(RAW))
    return owner, work, state, {**state, 'intent': RECIPE}


def save(owner, work, revision, state, origin=ORIGIN):
    return f"select public.save_trainer_session_work('{owner}','{work}',{revision},{quoted(origin)},{quoted(state)})"


def finish(owner, work, revision):
    return f"select public.finalize_trainer_session_work('{owner}','{work}',{revision})"


def reopen(owner, work, revision):
    return f"select public.reopen_trainer_session_work('{owner}','{work}',{revision})"


def authenticated(db, owner, sql):
    db.query('begin');identity(db, owner, 'aal2')
    try:
        value = db.query(sql);db.query('commit');return value
    except Exception:
        db.query('rollback');raise


def race_pair(observer, pool, owner, first_sql, second_sql, rr, expected,
              first_identity=True, second_identity=True):
    first, second = DB(), DB()
    try:
        first.query('begin')
        if first_identity:identity(first, owner, 'aal2')
        winner = first.query(first_sql)
        second.query('begin isolation level ' + ('repeatable read' if rr else 'read committed'))
        if second_identity:identity(second, owner, 'aal2')
        second.query(f"select public.list_trainer_session_work('{owner}')" if second_identity else 'select count(*) from profiles')
        pid = int(second.query('select pg_backend_pid()')[0][0])
        pending = pool.submit(second.query, second_sql)
        wait_locked(observer, pid, pending);first.query('commit')
        try:
            result = pending.result(timeout=10)
            assert expected is None, ('Se esperaba conflicto', expected, result)
            second.query('commit');return winner, result
        except SqlError as error:
            assert error.code == expected, (error.code, expected, str(error))
            second.query('rollback');return winner, None
    finally:
        first.close();second.close()


def changed(state, name):
    return {**state, 'editor': {**state['editor'], 'nameText': name}}


def save_race(db, pool, kind, rr, initial=False):
    owner, work, state, _ = fixture(db)
    revision = 0 if initial else 1
    if not initial:authenticated(db, owner, save(owner, work, 0, state))
    other = str(uuid.uuid4()) if kind == 'independent' else work
    next_state = changed(state, 'Siguiente')
    first = save(owner, work, revision, next_state)
    second = save(owner, other, 0 if initial or kind == 'old_receipt' else 1,
                  state if kind == 'old_receipt' else changed(state, 'Otra') if kind == 'different' else next_state)
    expected = '40001' if rr else '22023' if kind == 'different' else None
    winner, result = race_pair(db, pool, owner, first, second, rr, expected)
    if rr and kind != 'different':result = authenticated(db, owner, second)
    if kind == 'same':assert winner == result
    if kind == 'old_receipt':
        envelope = json.loads(result[0][0])
        assert envelope['receipt']['work']['state'] == state and envelope['current_revision'] == 2


def budget_race(db, pool, kind, rr):
    owner, work, state, _ = fixture(db);other = str(uuid.uuid4())
    db.query(f"insert into trainer_private.session_work_limits(owner_id) values('{owner}')")
    if kind == 'active':db.query(f"update trainer_private.session_work_limits set active_limit=1 where owner_id='{owner}'")
    if kind == 'rate':db.query(f"update trainer_private.session_work_limits set hourly_limit=1 where owner_id='{owner}'")
    if kind == 'bytes':
        db.query('begin');identity(db, owner, 'aal2');db.query(save(owner, work, 0, state));db.query('reset role')
        used = int(db.query(f"select retained_bytes from trainer_private.session_work_limits where owner_id='{owner}'")[0][0]);db.query('rollback')
        db.query(f"update trainer_private.session_work_limits set byte_limit={used + 64} where owner_id='{owner}'")
    race_pair(db, pool, owner, save(owner, work, 0, state), save(owner, other, 0, state), rr, '40001' if rr else '54000')
    assert db.query(f"select count(*) from trainer_private.session_works where owner_id='{owner}'") == [['1']]
    assert db.query(f"select count(*) from trainer_private.session_work_operations where owner_id='{owner}'") == [['1']]


def close_race(db, pool, kind, rr):
    owner, work, _, intent = fixture(db);authenticated(db, owner, save(owner, work, 0, intent))
    final, opening = finish(owner, work, 1), reopen(owner, work, 1)
    first, second = (final, final) if kind == 'same' else (final, opening) if kind == 'final_first' else (opening, final)
    winner, result = race_pair(db, pool, owner, first, second, rr, '40001' if rr or kind == 'reopen_first' else None)
    if kind == 'same':
        if rr:result = authenticated(db, owner, second)
        assert result == winner
    if kind == 'reopen_first':
        assert db.query(f"select count(*) from trainer_private.workout_writes where trainer_id='{owner}'") == [['0']]
        assert db.query(f"select lifecycle,revision from trainer_private.session_works where owner_id='{owner}'") == [['open', '2']]
    else:
        assert db.query(f"select count(*) from trainer_private.workout_writes where trainer_id='{owner}'") == [['1']]
        assert db.query(f"select lifecycle,revision from trainer_private.session_works where owner_id='{owner}'") == [['finalized', '2']]


def same_base(db, pool, rr):
    owner, work, _, intent = fixture(db);other = str(uuid.uuid4())
    base = authenticated(db, owner, f"select public.save_trainer_workout('{uuid.uuid4()}',{quoted(RECIPE)})")[0][0]
    origin = {**ORIGIN, 'baseId': base}
    for current in (work, other):authenticated(db, owner, save(owner, current, 0, intent, origin))
    race_pair(db, pool, owner, finish(owner, work, 1), finish(owner, other, 1), rr, '40001')
    assert db.query(f"select count(*) from workout_templates where owner_user_id='{owner}'") == [['2']]
    assert db.query(f"select lifecycle from trainer_private.session_works where owner_id='{owner}' and id='{other}'") == [['open']]


def legacy(db, pool, rr, different):
    owner, work, _, intent = fixture(db);authenticated(db, owner, save(owner, work, 0, intent))
    recipe = {**RECIPE, 'name': 'Legacy distinto'} if different else RECIPE
    before = db.query(f"select retained_bytes from trainer_private.session_work_limits where owner_id='{owner}'")
    race_pair(db, pool, owner, f"select public.save_trainer_workout('{work}',{quoted(recipe)})", finish(owner, work, 1), rr, '40001' if rr else '22023')
    assert db.query(f"select retained_bytes from trainer_private.session_work_limits where owner_id='{owner}'") == before
    assert db.query(f"select lifecycle,revision from trainer_private.session_works where owner_id='{owner}'") == [['open', '1']]
    assert db.query(f"select count(*) from workout_templates where owner_user_id='{owner}'") == [['1']]


def revocation(db, pool, rr):
    owner, work, state, _ = fixture(db)
    race_pair(db, pool, owner, f"update trainer_access set enabled=false where trainer_id='{owner}'", save(owner, work, 0, state), rr,
              '40001' if rr else '42501', first_identity=False)
    assert db.query(f"select count(*) from trainer_private.session_works where owner_id='{owner}'") == [['0']]


def deletion(db, pool, rr, write_first):
    owner, work, state, _ = fixture(db)
    write, delete = save(owner, work, 0, state), f"delete from profiles where id='{owner}'"
    race_pair(db, pool, owner, write if write_first else delete, delete if write_first else write, rr,
              '40001' if rr else None if write_first else '42501', first_identity=write_first, second_identity=not write_first)
    if rr and write_first:db.query(delete)
    for table in ('session_work_limits', 'session_works', 'session_work_bodies', 'session_work_operations'):
        assert db.query(f"select count(*) from trainer_private.{table} where owner_id='{owner}'") == [['0']]


with tempfile.TemporaryDirectory(prefix='entrenaop-session-work-race-') as directory:
    directory = Path(directory).resolve();data = directory / 'data';started = False;observer = None
    subprocess.run([str(bin_dir / 'initdb'), '-D', str(data), '-U', 'postgres', '-A', 'trust', '--no-locale', '-E', 'UTF8'], check=True, capture_output=True)
    try:
        subprocess.run([str(bin_dir / 'pg_ctl'), '-D', str(data), '-l', str(directory / 'server.log'), '-o', f'-h 127.0.0.1 -p {port}', '-w', 'start'], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        started = True;observer = DB();assert observer.query('show server_version')[0][0].startswith('17.');install(observer)
        observer.query((root / 'supabase/tests/trainer_session_work_recovery.sql').read_text(encoding='utf-8'))
        print('OK: contrato SQL transaccional con ROLLBACK; constructor deportivo mínimo local', flush=True)
        count = 0
        with concurrent.futures.ThreadPoolExecutor(max_workers=1) as pool:
            for rr in (False, True):
                cases = [(f'save/{kind}', lambda kind=kind: save_race(observer, pool, kind, rr)) for kind in ('same', 'different', 'old_receipt')]
                cases += [(f'initial/{kind}', lambda kind=kind: save_race(observer, pool, kind, rr, True)) for kind in ('same', 'different', 'independent')]
                cases += [(f'budget/{kind}', lambda kind=kind: budget_race(observer, pool, kind, rr)) for kind in ('active', 'bytes', 'rate')]
                cases += [(f'close/{kind}', lambda kind=kind: close_race(observer, pool, kind, rr)) for kind in ('same', 'final_first', 'reopen_first')]
                cases += [('same_base', lambda: same_base(observer, pool, rr)), ('revocation', lambda: revocation(observer, pool, rr))]
                cases += [(f'legacy/different={different}', lambda different=different: legacy(observer, pool, rr, different)) for different in (False, True)]
                cases += [(f'delete/write_first={first}', lambda first=first: deletion(observer, pool, rr, first)) for first in (False, True)]
                for label, run in cases:
                    for _ in range(3):run();count += 1
                    print(f'OK: {label}, RR={rr} (3 contenciones observadas)', flush=True)
        print(f'OK: {count} contenciones; sin Dev ni producción', flush=True)
    finally:
        if observer is not None:observer.close()
        if started:subprocess.run([str(bin_dir / 'pg_ctl'), '-D', str(data), '-m', 'immediate', '-w', 'stop'], check=True, capture_output=True)
