-- Las ejecuciones conservan el formato del bloque original. Carrera se añadió
-- después de crear esta restricción y debe admitirse también en la instantánea.

begin;

alter table public.workout_execution_sets
  drop constraint workout_execution_sets_block_format_check;

alter table public.workout_execution_sets
  add constraint workout_execution_sets_block_format_check
    check (
      block_format in (
        'straight_sets', 'superset', 'circuit', 'intervals', 'emom',
        'amrap', 'tabata', 'running', 'warm_up', 'cool_down'
      )
    );

commit;
