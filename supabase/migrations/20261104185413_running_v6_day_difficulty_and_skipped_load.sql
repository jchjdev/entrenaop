begin;

do $migration$
declare
 change record;
 definition text;
begin
 for change in select * from (values
  -- Una recuperación difícil en dos citas del mismo día acredita un solo día adverso.
  ('public.running_plan_v6(jsonb)'::regprocedure,1,
   $old$select count(*) into objective_bad from jsonb_array_elements(obs) o$old$,
   $new$select count(distinct (o->>'date')::date) into objective_bad from jsonb_array_elements(obs) o$new$),
  ('public.running_plan_v6(jsonb)'::regprocedure,1,
   $old$elsif objective_bad>=2 or (objective_bad>0 and (select count(*) from jsonb_array_elements(obs) o$old$,
   $new$elsif objective_bad>=2 or (objective_bad>0 and (select count(distinct (o->>'date')::date) from jsonb_array_elements(obs) o$new$),
  ('public.running_plan_v6(jsonb)'::regprocedure,1,
   $old$elsif bad=1 then reason:='Un día difícil: consolidar, sin concluir pérdida de forma';$old$,
   $new$elsif bad=1 or objective_bad=1 then reason:='Un día difícil: consolidar, sin concluir pérdida de forma';$new$),
  -- La omisión explícita no supone carga. Una cita sin confirmar conserva la cautela.
  ('public.running_plan_v6(jsonb)'::regprocedure,3,
   $old$(o->>'date')::date=wk+d-2 and o->'session'->>'family' in ('T','V','S','R'))$old$,
   $new$(o->>'date')::date=wk+d-2 and o->'session'->>'family' in ('T','V','S','R')
       and o->'signal'->>'reason' is distinct from 'not_performed')$new$),
  ('public.running_plan_v6(jsonb)'::regprocedure,1,
   $old$(o->>'date')::date=wk+future_day-2 and o->'session'->>'family' in ('T','V','S','R'))$old$,
   $new$(o->>'date')::date=wk+future_day-2 and o->'session'->>'family' in ('T','V','S','R')
            and o->'signal'->>'reason' is distinct from 'not_performed')$new$),
  ('public.running_second_quality_v6(jsonb,jsonb,jsonb,integer)'::regprocedure,2,
   $old$and (o->>'date')::date=(sessions->(j-1)->>'date')::date-1)$old$,
   $new$and (o->>'date')::date=(sessions->(j-1)->>'date')::date-1
       and o->'signal'->>'reason' is distinct from 'not_performed')$new$)
 ) as changes(signature,expected_matches,old_sql,new_sql) loop
  definition:=pg_get_functiondef(change.signature);
  if length(definition)-length(replace(definition,change.old_sql,''))<>length(change.old_sql)*change.expected_matches then
   raise exception 'Revisar el contrato de % antes de corregir la carga de carrera por día.',change.signature;
  end if;
  execute replace(definition,change.old_sql,change.new_sql);
 end loop;
end;
$migration$;

commit;
