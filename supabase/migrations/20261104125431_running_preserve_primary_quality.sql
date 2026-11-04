begin;

do $migration$
declare
 definition text;
 reconstruction constant text:=$old$     second_s:=public.running_session_v1(secondary,0,anchor,180);$old$;
 pairing_call constant text:='public.running_second_quality_v4(sessions,obs,p_input,work_cap)';
begin
 definition:=pg_get_functiondef('public.running_second_quality_v4(jsonb,jsonb,jsonb,integer)'::regprocedure);
 if length(definition)-length(replace(definition,reconstruction,''))<>length(reconstruction) then
   raise exception 'Revisar la reconstrucción de la primera sesión de calidad.';
 end if;
 -- Un escalón inferior puede durar más por sus pausas. Si no cabe, se
 -- abandona este reparto y v6 conserva la primera receta ya encajada.
 execute replace(replace(definition,'public.running_second_quality_v4(','public.running_second_quality_v6('),
   reconstruction,E'     if first_s is null then return null; end if;\n'||reconstruction);

 definition:=pg_get_functiondef('public.running_plan_v6(jsonb)'::regprocedure);
 if length(definition)-length(replace(definition,pairing_call,''))<>length(pairing_call) then
   raise exception 'Revisar la llamada a la segunda calidad del motor v6.';
 end if;
 execute replace(definition,pairing_call,'public.running_second_quality_v6(sessions,obs,p_input,work_cap)');
end;
$migration$;

revoke all on function public.running_second_quality_v6(jsonb,jsonb,jsonb,integer)
 from public,anon,authenticated;

commit;
