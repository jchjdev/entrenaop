begin;

create function public.performance_day_signal_priority_v1(signal text) returns integer
language sql immutable set search_path = '' as $$
  -- Un día cuenta una vez. Una respuesta adversa o inconclusa no acredita
  -- tolerancia aunque ese mismo día también haya una ejecución favorable.
  select case signal
    when 'pain' then 0
    when 'difficulty' then 1
    when 'tolerated' then 3
    when 'different_dose' then 4
    else 2
  end;
$$;

revoke all on function public.performance_day_signal_priority_v1(text) from public, anon, authenticated;

-- Cambiamos únicamente la lectura de evidencia de rendimiento. Cada función
-- conserva su comparación, ventana y límite de días, y las semanas publicadas
-- conservan su propuesta original.
do $migration$
declare
  change record;
  definition text;
  old_sql text;
  new_sql text;
  match_count integer;
begin
  for change in select * from (values
    ('public.performance_block_v3(jsonb,jsonb,date,date,date,jsonb)'::regprocedure, 1,
     $old$   order by value->>'completed_on' desc loop$old$,
     $new$   order by (value->>'completed_on')::date desc,
     public.performance_day_signal_priority_v1(public.performance_exposure_signal_v2(value,value->'dose')),
     value loop$new$),
    ('public.performance_task_v3_core(jsonb,jsonb,jsonb,date,date,jsonb)'::regprocedure, 2,
     $old$order by h->>'completed_on' desc limit 1$old$,
     $new$order by (h->>'completed_on')::date desc nulls last, h->>'scheduled_date' desc nulls last, h limit 1$new$),
    ('public.performance_task_v3_core(jsonb,jsonb,jsonb,date,date,jsonb)'::regprocedure, 1,
     $old$ for e in select value from jsonb_array_elements(coalesce(history,'[]'))
  where (value->>'completed_on')::date between greatest(observed,wk-21) and wk-1 order by value->>'completed_on' desc loop
  if (e->>'completed_on')::date=any(last_dates) then continue; end if;
  signal:=public.performance_exposure_signal_v2(e,dose);
  if phase_bridge and public.performance_same_isometric_work_v1(e->'dose'->'task',dose->'task')
    and (e->'dose'->>'rest_seconds')::int<=(dose->>'rest_seconds')::int then
   -- Una dificultad real no desaparece al cambiar de etiqueta. La tolerancia
   -- anterior conserva dosis, pero no acredita una subida con el nuevo énfasis.
   signal:=case public.performance_exposure_signal_v2(e,e->'dose')
    when 'difficulty' then 'difficulty' when 'pain' then 'pain' else 'different_dose' end;
  end if;$old$,
     $new$ for e,signal in
  select h.value, response.signal
  from jsonb_array_elements(coalesce(history,'[]')) h(value)
  cross join lateral (select case
    -- El puente conserva la dosis y la dificultad del mismo trabajo; la
    -- tolerancia de la fase anterior no autoriza una subida en la nueva.
    when phase_bridge and public.performance_same_isometric_work_v1(h.value->'dose'->'task',dose->'task')
      and (h.value->'dose'->>'rest_seconds')::int<=(dose->>'rest_seconds')::int
    then case public.performance_exposure_signal_v2(h.value,h.value->'dose')
      when 'difficulty' then 'difficulty' when 'pain' then 'pain' else 'different_dose' end
    else public.performance_exposure_signal_v2(h.value,dose)
  end as signal) response
  where (h.value->>'completed_on')::date between greatest(observed,wk-21) and wk-1
  order by (h.value->>'completed_on')::date desc,
    public.performance_day_signal_priority_v1(response.signal), h.value loop
  if (e->>'completed_on')::date=any(last_dates) then continue; end if;$new$),
    ('public.performance_task_v5(jsonb,jsonb,jsonb,date,date,jsonb,date)'::regprocedure, 1,
     $old$     order by value->>'completed_on' desc loop$old$,
     $new$     order by (value->>'completed_on')::date desc,
       public.performance_day_signal_priority_v1(public.performance_exposure_signal_v2(value,value->'dose')),
       value loop$new$),
    ('public.performance_task_v5(jsonb,jsonb,jsonb,date,date,jsonb,date)'::regprocedure, 2,
     $old$'frequency_policy_version','performance_frequency_v2','rep_min'$old$,
     $new$'frequency_policy_version','performance_frequency_v2',
       'same_day_evidence_policy_version','performance_same_day_evidence_v1','rep_min'$new$)
  ) as changes(signature, expected_matches, old_sql, new_sql) loop
    definition := replace(pg_get_functiondef(change.signature), E'\r\n', E'\n');
    old_sql := replace(change.old_sql, E'\r\n', E'\n');
    new_sql := replace(change.new_sql, E'\r\n', E'\n');
    match_count := (length(definition) - length(replace(definition, old_sql, ''))) / length(old_sql);
    if match_count <> change.expected_matches then
      raise exception 'Revisar el contrato de % antes de aplicar la evidencia del mismo día.', change.signature;
    end if;
    execute replace(definition, old_sql, new_sql);
  end loop;
end;
$migration$;

commit;
