begin;

-- Descartar o caducar una ejecución devuelve la cita a pendiente. La
-- revisión de resultados registra ese cambio aunque ya no quede ejecución.
do $migration$
declare
  definition text := pg_get_functiondef('trainer_private.program_update_candidates(uuid,uuid[])'::regprocedure);
  previous text := 'when s.execution_id is not null or a.result_revision > 0 then ''started''';
begin
  if strpos(definition,previous)=0 then
    raise exception 'Revisar el criterio de sesiones iniciadas antes de migrar.';
  end if;
  execute replace(definition,previous,
    'when s.status=''in_progress'' or (s.status=''planned'' and s.execution_id is not null) then ''started''');
end $migration$;

commit;
