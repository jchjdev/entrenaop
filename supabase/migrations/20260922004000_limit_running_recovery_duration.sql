-- Alinea la duración máxima de recuperación con el contrato del dominio.

begin;

alter table public.workout_sets
  add constraint workout_sets_recovery_duration_limit
    check (
      recovery_duration_seconds is null
      or recovery_duration_seconds <= 3600
    );

alter table public.workout_execution_sets
  add constraint workout_execution_sets_recovery_duration_limit
    check (
      recovery_duration_seconds is null
      or recovery_duration_seconds <= 3600
    );

commit;
