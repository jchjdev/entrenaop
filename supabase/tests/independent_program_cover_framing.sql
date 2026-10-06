-- Contrato editorial y compatibilidad; no conserva portadas ni cambia reglas.
begin;
select set_config('request.jwt.claim.sub', (select user_id::text from public.admin_permissions limit 1), true);
insert into public.preparation_programs(id,name,kind,enabled)
  values ('cover_framing_test','Encuadres de prueba','access',false);
set local role authenticated;
do $$ declare result jsonb; begin
  result := public.set_admin_program_cover('cover_framing_test',null,null,0.8,0.2,0);
  if (result->'cover'->>'header_focal_x')::double precision <> 0.8
    or (result->'cover'->>'header_focal_y')::double precision <> 0.2
    then raise exception 'Un alta antigua no replica el encuadre inicial'; end if;
  result := public.set_admin_program_cover_v2('cover_framing_test',null,null,0.8,0.2,0.6,0.7,1);
  if (result->'cover'->>'focal_x')::double precision <> 0.8
    or (result->'cover'->>'focal_y')::double precision <> 0.2
    or (result->'cover'->>'header_focal_x')::double precision <> 0.6
    or (result->'cover'->>'header_focal_y')::double precision <> 0.7
    then raise exception 'Los encuadres no se guardan separados'; end if;
  result := public.set_admin_program_cover('cover_framing_test',null,null,0.1,0.9,2);
  if (result->'cover'->>'header_focal_x')::double precision <> 0.6
    or (result->'cover'->>'header_focal_y')::double precision <> 0.7
    then raise exception 'Un editor antiguo modifica la cabecera independiente'; end if;
  begin
    perform public.set_admin_program_cover_v2('cover_framing_test',null,null,0.8,0.2,0.6,0.7,2);
    raise exception 'La nueva RPC sobrescribe una edición posterior';
  exception when serialization_failure then null; end;
  begin
    perform public.set_admin_program_cover_v2('cover_framing_test',null,null,0.8,0.2,'NaN'::double precision,0.7,3);
    raise exception 'Permite foco NaN en la cabecera';
  exception when invalid_parameter_value then null; end;
  begin
    perform public.set_admin_program_cover_v2('cover_framing_test',null,null,0.8,0.2,0.6,1.1,3);
    raise exception 'Permite foco de cabecera fuera de rango';
  exception when invalid_parameter_value then null; end;
  if has_function_privilege('anon','public.set_admin_program_cover_v2(text,text,text,double precision,double precision,double precision,double precision,integer)','execute')
    then raise exception 'RPC accesible sin autenticación'; end if;
end $$;
select set_config('request.jwt.claim.sub',gen_random_uuid()::text,true);
do $$ begin
  begin
    perform public.set_admin_program_cover_v2('cover_framing_test',null,null,0.8,0.2,0.6,0.7,3);
    raise exception 'El deportista modifica los encuadres';
  exception when insufficient_privilege then null; end;
end $$;
reset role;
select 'Encuadres independientes, compatibilidad, permisos y revisión: OK' as result;
rollback;
