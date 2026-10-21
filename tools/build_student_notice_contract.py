"""Prepara avisos + backfill + contrato en una transacción sin dejar datos.

No se conecta a ninguna base. El SQL generado termina en ROLLBACK y solo debe
ejecutarse contra Dev, después de contrastar el historial. No carga migraciones
ADMIN pendientes ni registra la migración de avisos como aplicada.
"""
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
PRELUDE = r"""
create temporary table notice_backfill_fixture(owner_id uuid) on commit drop;
do $$
declare trainer uuid:=gen_random_uuid(); pupil uuid:=gen_random_uuid();
 relation uuid:=gen_random_uuid(); ended uuid:=gen_random_uuid();
 form_id uuid:=gen_random_uuid(); battery uuid:=gen_random_uuid();
begin
 insert into auth.users(id,email) values(trainer,trainer||'@notice-backfill.invalid'),(pupil,pupil||'@notice-backfill.invalid');
 insert into public.trainer_access(trainer_id,enabled,client_limit,last_reason) values(trainer,true,1,'Fixture backfill');
 insert into public.trainer_client_relations(id,trainer_id,client_id,accepted_at)
  values(relation,trainer,pupil,now()-interval '1 day');
 insert into public.trainer_client_relations(id,trainer_id,client_id,accepted_at,ended_at)
  values(ended,trainer,pupil,now()-interval '3 days',now()-interval '2 days');
 insert into trainer_private.messages(id,relation_id,sender_id,body)
  values(gen_random_uuid(),relation,trainer,'Mensaje antiguo'),(gen_random_uuid(),relation,pupil,'Respuesta propia');
 insert into trainer_private.forms(id,trainer_id,family_id,version,content) values(form_id,trainer,gen_random_uuid(),1,'{}');
 insert into trainer_private.form_assignments(id,trainer_id,client_id,relation_id,form_id,due_date)
  values(gen_random_uuid(),trainer,pupil,relation,form_id,current_date),(gen_random_uuid(),trainer,pupil,ended,form_id,current_date);
 insert into trainer_private.form_assignments(id,trainer_id,client_id,relation_id,form_id,due_date,submitted_at,submission_operation_id,answers)
  values(gen_random_uuid(),trainer,pupil,relation,form_id,current_date,now(),gen_random_uuid(),'{}');
 insert into trainer_private.assessments(id,trainer_id,family_id,version,content)
  values(battery,trainer,gen_random_uuid(),1,'{}');
 insert into trainer_private.assessment_deliveries(id,trainer_id,client_id,relation_id,assessment_id,scheduled_date,status)
  values(gen_random_uuid(),trainer,pupil,relation,battery,current_date,'planned'),(gen_random_uuid(),trainer,pupil,ended,battery,current_date,'withdrawn');
 insert into trainer_private.assessment_deliveries(id,trainer_id,client_id,relation_id,assessment_id,scheduled_date,status,started_at)
  values(gen_random_uuid(),trainer,pupil,relation,battery,current_date,'in_progress',now());
 insert into trainer_private.assessment_deliveries(id,trainer_id,client_id,relation_id,assessment_id,scheduled_date,status,started_at,completed_at)
  values(gen_random_uuid(),trainer,pupil,relation,battery,current_date,'completed',now(),now());
 insert into notice_backfill_fixture values(pupil);
end $$;
"""
VERIFY_BACKFILL = r"""
do $$
declare pupil uuid; j jsonb;
begin
 select owner_id into pupil from notice_backfill_fixture;
 if (select count(*) from trainer_private.student_notices where owner_id=pupil)<>8
  or (select count(*) from trainer_private.student_notices where owner_id=pupil and read_at is null)<>3 then
  raise exception 'Backfill pierde histórico o inventa lecturas pendientes'; end if;
 if exists(select 1 from trainer_private.student_notices where owner_id=pupil and kind='message' and read_at is null) then
  raise exception 'Mensaje antiguo se presenta como nuevo'; end if;
 perform set_config('request.jwt.claim.sub',pupil::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',pupil,'role','authenticated','aal','aal1')::text,true);
 set local role authenticated;
 j:=public.get_my_trainer_notices(pupil);
 if (j->>'unread_count')::integer<>3 then raise exception 'Backfill no refleja pendientes en API'; end if;
 reset role;
end $$;
"""


def body(path: Path) -> str:
    return re.sub(r"(?im)^\s*(begin|commit|rollback);\s*$", "", path.read_text(encoding="utf-8"))


def main() -> None:
    migration = ROOT / "supabase/migrations/20261021201558_trainer_student_notices.sql"
    contract = ROOT / "supabase/tests/trainer_student_notices.sql"
    statements = ["begin;", PRELUDE, body(migration), VERIFY_BACKFILL,
                  body(contract), "select 'student_notices backfill and contracts OK' as result;", "rollback;"]
    output = ROOT / "build/student-notices-contract-rollback.sql"
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text("\n".join(statements) + "\n", encoding="utf-8")
    print(output)


if __name__ == "__main__":
    main()
