begin;

do $migration$
declare
  definition text := pg_get_functiondef('public.adaptive_control_candidates_v1(uuid,date,jsonb)'::regprocedure);
  old_sql constant text := $old$     and es.performance_result->>'stop_reason'='none'
     and case es.performance_prescription->>'effort_mode'$old$;
  new_sql constant text := $new$     and es.performance_result->>'stop_reason'='none'
     -- Técnica válida y margen de esfuerzo no acreditan una dosis recortada.
     and (ref.target_profile_code<>'push_up_standard' or case es.performance_prescription->>'measurement'
       when 'REPS' then coalesce((es.performance_result->>'value')::numeric>=(es.performance_prescription->>'target_value')::numeric,false)
       when 'REPS_IN_TIME' then coalesce(
         (es.performance_result->>'value')::numeric>=(es.performance_prescription->>'target_value')::numeric
         and (es.performance_result->>'actual_duration_seconds')::numeric=(es.performance_prescription->>'fixed_duration_seconds')::numeric,false)
       else false end)
     and case es.performance_prescription->>'effort_mode'$new$;
begin
  definition := replace(definition,E'\r\n',E'\n');
  if length(definition)-length(replace(definition,old_sql,''))<>length(old_sql) then
    raise exception 'Revisar la lectura de dosis del selector de controles de rendimiento antes de migrar.';
  end if;
  execute replace(definition,old_sql,new_sql);
end;
$migration$;

commit;
