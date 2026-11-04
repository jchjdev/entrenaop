begin;

-- Acreditar días de práctica por fecha local de realización. Se conserva la
-- lectura de cada observación adversa, aunque coincida con una tolerada.
do $migration$
declare
  definition text := pg_get_functiondef('public.adaptive_control_candidates_v1(uuid,date,jsonb)'::regprocedure);
  old_sql constant text := $old$count(*) filter(where o->'signal'->>'status'='tolerated'),count(*) filter(where o->'signal'->>'status'='tolerated' and (o->>'date')::date>=wk-14),count(*) filter(where o->'signal'->>'status'='tolerated' and (o->>'date')::date>since_on),$old$;
  new_sql constant text := $new$count(distinct (o->>'date')::date) filter(where o->'signal'->>'status'='tolerated'),
   count(distinct (o->>'date')::date) filter(where o->'signal'->>'status'='tolerated' and (o->>'date')::date>=wk-14),
   count(distinct (o->>'date')::date) filter(where o->'signal'->>'status'='tolerated' and (o->>'date')::date>since_on),$new$;
begin
  if length(definition) - length(replace(definition, old_sql, '')) <> length(old_sql) then
    raise exception 'Revisar los contadores vigentes del control de carrera antes de aplicar la migración.';
  end if;
  execute replace(definition, old_sql, new_sql);
end;
$migration$;

commit;
