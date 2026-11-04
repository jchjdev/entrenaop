begin;

do $migration$
declare
 change record;
 definition text;
begin
 for change in select * from (values
  ('public.running_evidence_v6(jsonb,date)'::regprocedure,
   $old$f text; recent jsonb; old jsonb; trend text; samples integer;$old$,
   $new$f text; recent jsonb; old jsonb; trend text; samples integer; latest_sample_date date;$new$),
  ('public.running_evidence_v6(jsonb,date)'::regprocedure,
   $old$'last',avg(pace) filter(where rn in (1,2))) into samples,old$old$,
   $new$'last',avg(pace) filter(where rn in (1,2))),max(observed_on) into samples,old,latest_sample_date$new$),
  ('public.running_evidence_v6(jsonb,date)'::regprocedure,
   $old$select (o->'signal'->>'pace_seconds_per_km')::numeric pace,$old$,
   $new$select (o->'signal'->>'pace_seconds_per_km')::numeric pace,(o->>'date')::date observed_on,$new$),
  ('public.running_evidence_v6(jsonb,date)'::regprocedure,
   $old$jsonb_build_object('trend',trend,'samples',samples)$old$,
   $new$jsonb_build_object('trend',trend,'samples',samples,'latest_sample_date',latest_sample_date)$new$),
  ('public.running_plan_v6(jsonb)'::regprocedure,
   $old$if ev->'families'->'V'->>'trend'='improving' and tests->>'trend' in ('stable','worsening') then$old$,
   $new$-- Un control del mismo día no acredita el orden: la referencia solo conserva la fecha.
 if ev->'families'->'V'->>'trend'='improving' and tests->>'trend' in ('stable','worsening')
   and (tests#>>'{controls,0,date}')::date>(ev#>>'{families,V,latest_sample_date}')::date then$new$)
 ) as changes(signature,old_sql,new_sql) loop
  definition:=pg_get_functiondef(change.signature);
  if length(definition)-length(replace(definition,change.old_sql,''))<>length(change.old_sql) then
   raise exception 'Revisar el contrato de % antes de corregir la cronología del control.',change.signature;
  end if;
  execute replace(definition,change.old_sql,change.new_sql);
 end loop;
end;
$migration$;

commit;
