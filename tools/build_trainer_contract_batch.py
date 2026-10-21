"""Prepara el ensayo conjunto profesional sin conectarse a ninguna base.

Cada contrato usa su propio savepoint y los cambios de esquema terminan en
ROLLBACK. Ejecutar el archivo generado únicamente contra el proyecto Dev
previamente contrastado mediante `supabase migration list --linked`.
"""
from pathlib import Path
import argparse
import re

ROOT = Path(__file__).resolve().parents[1]
MIGRATIONS = [
    "20261021151727_trainer_private_videos.sql",
    "20261021151737_trainer_operational_workflow.sql",
    "20261021151928_trainer_followup_forms.sql",
    "20261021153508_trainer_groups_and_week_copy.sql",
    "20261021153743_trainer_client_workspace.sql",
    "20261021155333_trainer_finite_recurrence.sql",
    "20261021160327_trainer_assessments.sql",
    "20261021161302_trainer_calendar_snapshot_guards.sql",
    "20261021162516_trainer_reviewed_assignment_changes.sql",
    "20261021162903_trainer_editor_exercise_preferences.sql",
]
CONTRACTS = [
    "trainer_access_and_relations", "trainer_client_portfolio", "trainer_portal_and_mfa",
    "trainer_private_workouts", "trainer_private_programs", "trainer_private_exercises",
    "trainer_private_videos", "trainer_operational_workflow", "trainer_followup_forms",
    "trainer_groups_and_week_copy", "trainer_client_workspace", "trainer_finite_recurrence",
    "bunny_exercise_videos", "pro_access_and_free_quotas", "exercise_creator_security_smoke",
    "exercise_images_security_smoke", "discard_workout_execution", "amrap_review_and_retry",
    "workout_execution_session_type", "guided_program_authoring",
    "trainer_assessments", "trainer_calendar_snapshot_guards",
    "trainer_reviewed_assignment_changes",
    "trainer_editor_exercise_preferences",
]


def transaction_body(path: Path) -> str:
    sql = path.read_text(encoding="utf-8")
    return re.sub(r"(?im)^\s*(begin|commit|rollback);\s*$", "", sql)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--contracts-only", action="store_true", help="Ensayar las RPC ya migradas sin repetir DDL")
    parser.add_argument("--with-program-work", action="store_true", help="Incluir recuperación privada de programas")
    parser.add_argument("--with-device-history", action="store_true", help="Incluir historial personal de Salud")
    args = parser.parse_args()
    migration_names = list(MIGRATIONS)
    contracts = list(CONTRACTS)
    if args.with_program_work:
        migration_names.append("20261021172219_trainer_program_work_drafts.sql")
        contracts.append("trainer_program_work_drafts")
    if args.with_device_history:
        migration_names.append("20261021171215_device_running_history.sql")
        contracts.append("device_running_history")
    migrations = [] if args.contracts_only else sorted(migration_names)
    statements = ["begin;"]
    for name in migrations:
        statements.append(transaction_body(ROOT / "supabase/migrations" / name))
    for index, name in enumerate(contracts):
        statements.extend([
            f"savepoint contract_{index};",
            f"-- Contrato {name}: todos sus actores se retiran antes del siguiente.",
            transaction_body(ROOT / "supabase/tests" / f"{name}.sql"),
            f"rollback to savepoint contract_{index};",
            f"release savepoint contract_{index};",
        ])
    statements.extend([
        f"select 'trainer_professional_integration: {len(migrations)} migrations and {len(contracts)} contracts OK' as result;",
        "rollback;",
    ])
    output = ROOT / ("build/trainer-professional-contracts-rollback.sql" if args.contracts_only else "build/trainer-professional-integration-rollback.sql")
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text("\n".join(statements) + "\n", encoding="utf-8")
    print(f"{len(migrations)} migraciones, {len(contracts)} contratos; {output}")


if __name__ == "__main__":
    main()
