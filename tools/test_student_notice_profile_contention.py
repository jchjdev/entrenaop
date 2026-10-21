"""Contención focal feedback/perfil con RPC y trigger reales en PG local.

Reutiliza el arnés operacional existente; no acepta DSN ni accede a Dev.
Las dos operaciones concurrentes terminan en ROLLBACK. El clúster efímero
contiene solo las tablas necesarias para conservar el orden real de sus FK.
"""
from pathlib import Path
import concurrent.futures
import re
import subprocess
import tempfile
import uuid

# Carga las utilidades, sin ejecutar la batería operacional de treinta casos.
ROOT = Path(__file__).resolve().parents[1]
runtime = ROOT / "tools/test_trainer_operational_concurrency.py"
namespace = {"__file__": str(runtime), "__name__": "student_notice_contention_harness"}
source = runtime.read_text(encoding="utf-8").split("with tempfile.TemporaryDirectory(prefix='entrenaop-operational-race-')")[0]
exec(compile(source, str(runtime), "exec"), namespace)
DB, SqlError = namespace["DB"], namespace["SqlError"]
bin_dir, port = namespace["bin_dir"], namespace["port"]


def install(db):
    db.query(namespace["bootstrap"])
    for name in ("20261020072345_trainer_access_and_client_relations.sql", "20261021074426_trainer_portal_summaries.sql",
                 "20261021075243_trainer_mfa_and_directory.sql", "20261021115014_trainer_client_portfolio.sql"):
        db.query((ROOT / "supabase/migrations" / name).read_text(encoding="utf-8"))
    namespace["install_operational_fixture"](db)
    db.query("""
      create table public.exercise_video_assets(
        id uuid primary key,created_by uuid references auth.users(id) on delete set null,
        trainer_id uuid references public.profiles(id) on delete restrict,
        assignment_id uuid references public.trainer_assignments(scheduled_id) on delete restrict,
        scope text,shared boolean,status text,duration_seconds numeric
      );
      create table trainer_private.video_limits(trainer_id uuid,scope text,feedback_limit integer);
    """)
    video = (ROOT / "supabase/migrations/20261021151727_trainer_private_videos.sql").read_text(encoding="utf-8")
    db.query(re.search(r"create table trainer_private.video_feedback\([\s\S]*?\n\);", video).group())
    db.query(re.search(r"create function trainer_private.add_video_feedback\([\s\S]*?end \$\$;", video).group())
    notices = (ROOT / "supabase/migrations/20261021201558_trainer_student_notices.sql").read_text(encoding="utf-8")
    db.query(re.search(r"create table trainer_private.student_notices \([\s\S]*?\n\);", notices).group())
    db.query(re.search(r"create function trainer_private.capture_student_notice\([\s\S]*?end \$\$;", notices).group())
    db.query(re.search(r"create trigger student_technique_notice[^;]*;", notices).group())
    db.query("grant execute on function trainer_private.add_video_feedback(uuid,uuid,numeric,text) to authenticated")


def race(db, pool, repeatable, feedback_first):
    trainer, pupil, _, relations = namespace["operational_case"](db)
    template, assignment, asset, feedback = (str(uuid.uuid4()) for _ in range(4))
    db.query(f"insert into public.workout_templates(id,owner_user_id,origin,status,name,version) values('{template}','{trainer}','coach','published','Fixture',1)")
    db.query(f"insert into public.scheduled_workouts(id,user_id,template_id,template_name,template_version,scheduled_date,source) values('{assignment}','{pupil}','{template}','Fixture',1,current_date,'coach')")
    db.query(f"insert into public.trainer_assignments(scheduled_id,relation_id,trainer_id,client_id) values('{assignment}','{relations[0]}','{trainer}','{pupil}')")
    db.query(f"insert into public.exercise_video_assets values('{asset}','{pupil}','{trainer}','{assignment}','client_technique',true,'ready',90)")
    action = f"select trainer_private.add_video_feedback('{feedback}','{asset}',1,'Comentario')"
    a, b = DB(), DB()
    try:
        a.query("begin; set local statement_timeout='4s'; set local deadlock_timeout='100ms'")
        b.query("begin isolation level " + ("repeatable read" if repeatable else "read committed"))
        b.query("set local statement_timeout='4s'; set local deadlock_timeout='100ms'")
        if feedback_first:
            namespace["identity"](a, trainer, "aal2")
            a.query(action)
            pid = int(b.query("select pg_backend_pid()")[0][0])
            pending = pool.submit(b.query, f"delete from public.profiles where id='{pupil}'")
            namespace["wait_locked"](db, pid, pending)
            a.query("rollback")
            try:
                pending.result(timeout=5)
                raise AssertionError("Borra perfil con historial protegido")
            except SqlError as error:
                assert error.code in ("23503", "40001"), (error.code, str(error))
            b.query("rollback")
        else:
            a.query(f"select 1 from public.profiles where id='{pupil}' for update")
            namespace["identity"](b, trainer, "aal2")
            pid = int(b.query("select pg_backend_pid()")[0][0])
            pending = pool.submit(b.query, action)
            namespace["wait_locked"](db, pid, pending)
            try:
                a.query(f"delete from public.profiles where id='{pupil}'")
                raise AssertionError("Borra perfil con historial protegido")
            except SqlError as error:
                assert error.code == "23503", (error.code, str(error))
            a.query("rollback")
            pending.result(timeout=5)
            b.query("rollback")
        assert db.query(f"select count(*) from trainer_private.student_notices where source_id='{feedback}'") == [["0"]]
        assert db.query(f"select count(*) from public.profiles where id='{pupil}'") == [["1"]]
    finally:
        a.close()
        b.close()


(ROOT / "build").mkdir(exist_ok=True)
with tempfile.TemporaryDirectory(prefix="student-notice-profile-", dir=ROOT / "build") as directory:
    work = Path(directory).resolve()
    assert work.parent == (ROOT / "build").resolve()
    data = work / "data"
    print("Inicializando clúster local efímero", flush=True)
    initialized = subprocess.run([str(bin_dir / "initdb"), "-D", str(data), "-U", "postgres", "-A", "trust", "--no-locale", "-E", "UTF8"], capture_output=True, timeout=30)
    if initialized.returncode:
        raise RuntimeError(initialized.stderr.decode(errors="replace"))
    started = False
    observer = None
    try:
        subprocess.run([str(bin_dir / "pg_ctl"), "-D", str(data), "-l", str(work / "server.log"), "-o", f"-h 127.0.0.1 -p {port}", "-w", "start"], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=20)
        started = True
        observer = DB()
        install(observer)
        with concurrent.futures.ThreadPoolExecutor(max_workers=1) as pool:
            for repeatable in (False, True):
                for feedback_first in (False, True):
                    race(observer, pool, repeatable, feedback_first)
                    print(f"OK feedback/perfil, RR={repeatable}, feedback primero={feedback_first}; ROLLBACK", flush=True)
        print("OK: cuatro contenciones locales, sin ciclo ni avisos residuales; ninguna conexión remota.", flush=True)
    finally:
        if observer is not None:
            observer.close()
        if started:
            subprocess.run([str(bin_dir / "pg_ctl"), "-D", str(data), "-m", "immediate", "-w", "stop"], check=True, capture_output=True)
