begin;

-- La librería ya contiene ejercicios por distancia. Extiende el validador
-- compartido por ADMIN, Trainer y la app sin reescribir ejercicios ni pautas.
do $migration$
declare
  definition text := pg_get_functiondef('public.normalize_exercise_draft(text,text,text,text[],text[],text,text)'::regprocedure);
  old_types text := $types$not in ('repeticiones', 'duración')$types$;
begin
  if strpos(definition,old_types)=0 then
    raise exception 'Revisar la validación de la medición habitual de ejercicios';
  end if;
  execute replace(definition,old_types,$types$not in ('repeticiones', 'duración', 'distancia')$types$);
end $migration$;

commit;
