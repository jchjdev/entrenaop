begin;

do $migration$
declare
 definition text;
 assignment constant text:='first_pace := coalesce(first_pace,pace); last_pace := pace;';
 fade_check constant text:=$old$coalesce(fade,0)>(cfg->>'fade_max')::numeric$old$;
 new_fade_check constant text:=$new$(coalesce(fade,0)>(cfg->>'fade_max')::numeric
     and (last_pace_max is null or last_pace>last_pace_max*(1+(cfg->>'pace_tolerance')::numeric)))$new$;
begin
 definition:=pg_get_functiondef('public.running_evaluate_v2(jsonb,jsonb)'::regprocedure);
 if strpos(definition,assignment)=0
   or length(definition)-length(replace(definition,fade_check,''))<>2*length(fade_check) then
  raise exception 'Revisar la regla de desaceleración del motor de carrera.';
 end if;
 -- Una caída relativa dentro del margen de la receta orienta el ritmo,
 -- pero no convierte por sí sola una serie válida en dificultad.
 definition:=replace(definition,'public.running_evaluate_v2(','public.running_evaluate_v6(');
 definition:=replace(definition,'last_pace numeric;','last_pace numeric; last_pace_max numeric;');
 definition:=replace(definition,assignment,assignment||E'\n   last_pace_max := (seg->>''pace_max'')::numeric;');
 execute replace(definition,fade_check,new_fade_check);

 definition:=pg_get_functiondef('public.running_evaluate_manual_time_v1(jsonb,jsonb)'::regprocedure);
 if length(definition)-length(replace(definition,'public.running_evaluate_v2(',''))<>3*length('public.running_evaluate_v2(') then
  raise exception 'Revisar las llamadas al evaluador de carrera.';
 end if;
 execute replace(definition,'public.running_evaluate_v2(','public.running_evaluate_v6(');

 definition:=pg_get_functiondef('public.running_dose_evidence_v6(jsonb,date,text,integer,numeric,numeric)'::regprocedure);
 if strpos(definition,'compatible:=public.running_evaluate_v2(prescription,h->''execution'');')=0 then
  raise exception 'Revisar la compatibilidad de parciales de carrera.';
 end if;
 execute replace(definition,'compatible:=public.running_evaluate_v2(','compatible:=public.running_evaluate_v6(');
end;
$migration$;

revoke all on function public.running_evaluate_v6(jsonb,jsonb) from public,anon,authenticated;

commit;
