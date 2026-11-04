begin;

do $migration$
declare
  definition text := replace(pg_get_functiondef('public.performance_task_v3_core(jsonb,jsonb,jsonb,date,date,jsonb)'::regprocedure), E'\r\n', E'\n');
  old_sql constant text := $old$  -- Consolidar la tarea técnica antes de cambiarla; el calendario no demuestra dominio.
  if phase='development' and (select count(*) from jsonb_array_elements(coalesce(history,'[]')) h
    where h->'dose'->'task'->>'stimulus_code' in ('COD-T01','COD-SP01') and public.performance_exposure_signal_v2(h,h->'dose')='tolerated')<2 then block_code:='COD-T01'; end if;
  -- Familiarización periódica del recorrido ya medido, sin convertirla en un máximo.

  if phase='specific' and (select count(distinct (h->>'completed_on')::date) from jsonb_array_elements(coalesce(history,'[]')) h where (h->>'completed_on')::date between wk-21 and wk-1 and h->'dose'->'task'->>'stimulus_code' in ('COD-T01','COD-SP01') and public.performance_exposure_signal_v2(h,h->'dose')='tolerated')<2 then block_code:='COD-T01'; end if;$old$;
  new_sql constant text := $new$  -- Acreditar las dos últimas fechas de práctica técnica, con la misma
  -- ventana de la fase. Un día adverso no acredita tolerancia.
  if phase in ('development','specific') and (select count(*) filter(where day.signal='tolerated') from (
    select distinct on (practice.performed_on) practice.performed_on,practice.signal
    from (
      select (h->>'completed_on')::date performed_on,h->'dose'->'task'->>'stimulus_code' stimulus,
        public.performance_exposure_signal_v2(h,h->'dose') signal
      from jsonb_array_elements(coalesce(history,'[]')) h
      where (h->>'completed_on')::date between greatest(observed,wk-21) and wk-1
        and h->'dose'->'task'->>'stimulus_code' in ('COD-T01','COD-SP01','COD-SP02')
    ) practice
    where practice.stimulus in ('COD-T01','COD-SP01') or practice.signal in ('pain','difficulty')
    order by practice.performed_on desc,public.performance_day_signal_priority_v1(practice.signal),practice.signal
    limit 2
  ) day)<2 then block_code:='COD-T01'; end if;$new$;
begin
  if length(definition)-length(replace(definition,old_sql,''))<>length(old_sql) then
    raise exception 'Revisar la puerta vigente de práctica técnica de agilidad antes de migrar.';
  end if;
  execute replace(definition,old_sql,new_sql);
end;
$migration$;

commit;
