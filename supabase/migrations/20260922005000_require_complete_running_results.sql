-- Una ejecución de carrera completada conserva tiempo y distancia reales; el
-- ritmo se deriva de ambos y no puede quedar incompleto tras una corrección.

begin;

alter table public.workout_execution_sets
  add constraint workout_execution_sets_running_result_complete
    check (
      block_format <> 'running'
      or status <> 'completed'
      or (
        actual_duration_seconds is not null
        and actual_distance_meters is not null
      )
    );

commit;
