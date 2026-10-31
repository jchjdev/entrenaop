begin;
-- Salud puede incorporar muestras después de escribir la actividad. Añadir
-- una medición ausente o un intervalo cerrado no contradice los ya recibidos.
create function device_private.apple_enriched_intervals(previous jsonb,incoming jsonb,parent jsonb) returns jsonb
language plpgsql immutable set search_path='' as $$
declare part jsonb; prior jsonb; combined jsonb:='[]';begin
 if jsonb_typeof(previous) is distinct from 'array' or jsonb_typeof(incoming) is distinct from 'array' then return null;end if;
 if exists(select 1 from jsonb_array_elements(previous) p where not exists(
  select 1 from jsonb_array_elements(incoming) n where n->>'id'=p->>'id')) then return null;end if;
 for part in select value from jsonb_array_elements(incoming) loop
  select value into prior from jsonb_array_elements(previous) where value->>'id'=part->>'id';
  if found and exists(select 1 from jsonb_each(prior) e where part?e.key and part->e.key<>e.value) then return null;end if;
  combined:=combined||jsonb_build_array(coalesce(prior,'{}')||part);
 end loop;
 -- Se revalida la combinación: las muestras conservadas también cuentan en
 -- los límites de tiempo, distancia, orden y coherencia de pulsaciones.
 perform device_private.apple_interval_extension(jsonb_build_object('intervals',combined),parent);
 return combined;
exception when data_exception then return null;
end $$;
revoke all on function device_private.apple_enriched_intervals(jsonb,jsonb,jsonb) from public,anon,authenticated,service_role;

do $$declare definition text; anchor text;begin
 definition:=pg_get_functiondef('device_private.apple_results_command(uuid,text,jsonb)'::regprocedure);
 anchor:='extension:=device_private.apple_interval_extension(x,r.observation);';
 if strpos(definition,anchor)=0 then raise exception 'Revisar enriquecimiento de intervalos Apple';end if;
 definition:=replace(definition,anchor,anchor||'
   if r.observation?''intervals'' and extension?''intervals'' and
    device_private.apple_enriched_intervals(r.observation->''intervals'',extension->''intervals'',r.observation) is not null then
    extension:=jsonb_set(extension,''{intervals}'',device_private.apple_enriched_intervals(r.observation->''intervals'',extension->''intervals'',r.observation));
   end if;');
 anchor:='r.observation->e.key<>e.value';
 if strpos(definition,anchor)=0 then raise exception 'Revisar comparación de intervalos Apple';end if;
 definition:=replace(definition,anchor,anchor||' and not(e.key=''intervals'' and
    device_private.apple_enriched_intervals(r.observation->''intervals'',e.value,r.observation) is not null)');
 execute definition;
end $$;
commit;
