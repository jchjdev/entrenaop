begin;

-- El titular no comparte consigo mismo. Se conserva la sesión profesional
-- viva, el propietario esperado y la lista positiva de datos deportivos.
do $migration$ declare definition text;anchor text;begin
 definition:=pg_get_functiondef('trainer_private.shared_workout_result(uuid,uuid,uuid)'::regprocedure);
 anchor:='if not own and not coalesce(';
 if strpos(definition,anchor)=0 then raise exception 'Revisar autorización de resultados compartidos';end if;
 execute replace(definition,anchor,'if not own and p_expected_owner is distinct from p_client_id and not coalesce(');

 definition:=pg_get_functiondef('trainer_private.shared_client_calendar(uuid,uuid,date,date,date,uuid)'::regprocedure);
 anchor:='shared:=coalesce((select results_enabled';
 if strpos(definition,anchor)=0 then raise exception 'Revisar disponibilidad de resultados propios';end if;
 execute replace(definition,anchor,'shared:=(p_expected_owner=p_client_id) or coalesce((select results_enabled');
end $migration$;

commit;
