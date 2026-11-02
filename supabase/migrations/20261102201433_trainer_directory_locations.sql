begin;

-- Códigos provinciales INE; se añaden nombres habituales para la búsqueda.
-- La Graciosa se ofrece como isla de Las Palmas, sin inventarle un código INE.
create function directory_private.location_catalog() returns jsonb
language sql immutable security invoker set search_path='' as $catalog$
 select '{"15": {"name": "A Coruña", "islands": [], "aliases": "La Coruña"}, "01": {"name": "Álava / Araba", "islands": []}, "02": {"name": "Albacete", "islands": []}, "03": {"name": "Alicante / Alacant", "islands": []}, "04": {"name": "Almería", "islands": []}, "33": {"name": "Asturias", "islands": []}, "05": {"name": "Ávila", "islands": []}, "06": {"name": "Badajoz", "islands": []}, "07": {"name": "Illes Balears / Baleares", "islands": ["Formentera", "Ibiza", "Mallorca", "Menorca"], "aliases": "Islas Baleares"}, "08": {"name": "Barcelona", "islands": []}, "48": {"name": "Bizkaia", "islands": [], "aliases": "Vizcaya"}, "09": {"name": "Burgos", "islands": []}, "10": {"name": "Cáceres", "islands": []}, "11": {"name": "Cádiz", "islands": []}, "39": {"name": "Cantabria", "islands": []}, "12": {"name": "Castellón / Castelló", "islands": []}, "51": {"name": "Ceuta", "islands": []}, "13": {"name": "Ciudad Real", "islands": []}, "14": {"name": "Córdoba", "islands": []}, "16": {"name": "Cuenca", "islands": []}, "20": {"name": "Gipuzkoa", "islands": [], "aliases": "Guipúzcoa"}, "17": {"name": "Girona", "islands": [], "aliases": "Gerona"}, "18": {"name": "Granada", "islands": []}, "19": {"name": "Guadalajara", "islands": []}, "21": {"name": "Huelva", "islands": []}, "22": {"name": "Huesca", "islands": []}, "23": {"name": "Jaén", "islands": []}, "26": {"name": "La Rioja", "islands": []}, "35": {"name": "Las Palmas", "islands": ["Fuerteventura", "Gran Canaria", "Lanzarote", "La Graciosa"], "aliases": "Canarias Islas Canarias"}, "24": {"name": "León", "islands": []}, "25": {"name": "Lleida", "islands": [], "aliases": "Lérida"}, "27": {"name": "Lugo", "islands": []}, "28": {"name": "Madrid", "islands": []}, "29": {"name": "Málaga", "islands": []}, "52": {"name": "Melilla", "islands": []}, "30": {"name": "Murcia", "islands": []}, "31": {"name": "Navarra", "islands": []}, "32": {"name": "Ourense", "islands": [], "aliases": "Orense"}, "34": {"name": "Palencia", "islands": []}, "36": {"name": "Pontevedra", "islands": []}, "37": {"name": "Salamanca", "islands": []}, "38": {"name": "Santa Cruz de Tenerife", "islands": ["La Gomera", "El Hierro", "La Palma", "Tenerife"], "aliases": "Canarias Islas Canarias"}, "40": {"name": "Segovia", "islands": []}, "41": {"name": "Sevilla", "islands": []}, "42": {"name": "Soria", "islands": []}, "43": {"name": "Tarragona", "islands": []}, "44": {"name": "Teruel", "islands": []}, "45": {"name": "Toledo", "islands": []}, "46": {"name": "Valencia / València", "islands": []}, "47": {"name": "Valladolid", "islands": []}, "49": {"name": "Zamora", "islands": []}, "50": {"name": "Zaragoza", "islands": []}}'::jsonb
$catalog$;
revoke all on function directory_private.location_catalog() from public,anon,authenticated,service_role;

alter table directory_private.profiles
 add column province_code text,
 add column island text not null default '',
 add constraint directory_province_valid check(province_code is null or directory_private.location_catalog() ? province_code),
 add constraint directory_island_valid check(island='' or (province_code is not null
   and (directory_private.location_catalog()->province_code->'islands') ? island));

-- Localidad libre y opcional: en presencial basta con la provincia. Los datos
-- antiguos se conservan, sin inferir una provincia a partir de un texto ambiguo.
alter table directory_private.profiles drop constraint profiles_check;
alter table directory_private.profiles add constraint directory_presential_location
 check(mode='online' or length(btrim(city))>0 or province_code is not null);

-- Conserva todas las puertas vigentes de identidad/MFA, comercio, moderación,
-- consentimiento, concurrencia y contacto. Las pestañas antiguas no borran los
-- campos nuevos cuando guardan una ficha sin enviarlos.
do $migration$
declare definition text; original text;
begin
 original:=pg_get_functiondef('directory_private.save(uuid,integer,jsonb,boolean,boolean)'::regprocedure);
 if strpos(original,'mode,city,visibility')=0
   or strpos(original,'btrim(p_data->>''city''),v_visibility')=0
   or strpos(original,'mode=excluded.mode,city=excluded.city,visibility=')=0 then
   raise exception 'Revisar contrato de guardado del directorio';
 end if;
 definition:=replace(original,'mode,city,visibility','mode,city,province_code,island,visibility');
 definition:=replace(definition,'btrim(p_data->>''city''),v_visibility',
   $patch$btrim(p_data->>'city'),
   case when p_data ? 'province_code' then nullif(btrim(p_data->>'province_code'),'') else p.province_code end,
   case when p_data ? 'island' then coalesce(btrim(p_data->>'island'),'') else coalesce(p.island,'') end,v_visibility$patch$);
 definition:=replace(definition,'mode=excluded.mode,city=excluded.city,visibility=',
   'mode=excluded.mode,city=excluded.city,province_code=excluded.province_code,island=excluded.island,visibility=');
 execute definition;
 original:=pg_get_functiondef('directory_private.profile_json(directory_private.profiles)'::regprocedure);
 if strpos(original,'''city'',p.city')=0 then raise exception 'Revisar contrato JSON del directorio';end if;
 execute replace(original,'''city'',p.city','''city'',p.city,''province_code'',p.province_code,''island'',p.island');
end $migration$;

-- Coincidencias parciales literales por palabra, en cualquier orden, sin tildes
-- ni mayúsculas. % y _ no se interpretan como comodines aportados por el usuario.
create function directory_private.normalized_location(p_text text) returns text
language sql immutable security invoker set search_path='' as $$
 select translate(lower(coalesce(p_text,'')),
   'áàäâãéèëêíìïîóòöôõúùüûñç','aaaaaeeeeiiiiooooouuuunc')
$$;
create function directory_private.matches_words(p_text text,p_query text) returns boolean
language sql immutable security invoker set search_path='' as $$
 select not exists(select 1
   from regexp_split_to_table(btrim(directory_private.normalized_location(p_query)),'[[:space:]]+') word
   where word<>'' and strpos(directory_private.normalized_location(p_text),word)=0)
$$;
create function directory_private.location_text(p directory_private.profiles) returns text
language sql immutable security invoker set search_path='' as $$
 select concat_ws(' ',p.city,p.island,
   directory_private.location_catalog()->p.province_code->>'name',
   directory_private.location_catalog()->p.province_code->>'aliases')
$$;
revoke all on function directory_private.normalized_location(text),directory_private.matches_words(text,text),
 directory_private.location_text(directory_private.profiles) from public,anon,authenticated,service_role;

create or replace function directory_private.search(p_query text,p_mode text,p_city text,p_favorites boolean,p_after uuid,p_web_only boolean) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare items jsonb; more boolean; last_id uuid;
begin
 if p_query is null or length(p_query)>120 or p_city is null or length(p_city)>80
 or (p_mode is not null and p_mode not in ('online','presencial','ambas')) then raise invalid_parameter_value; end if;
 if p_favorites and not directory_private.member() then raise insufficient_privilege;end if;
 with candidates as (
 select p.* from directory_private.profiles p where directory_private.can_read(p.id,p_web_only)
 and (p_after is null or p.id>p_after)
 and (p_mode is null or p.mode=p_mode or p.mode='ambas')
 and directory_private.matches_words(directory_private.location_text(p),p_city)
 and directory_private.matches_words(concat_ws(' ',p.name,p.description,
   array_to_string(p.specialties,' '),array_to_string(p.services,' '),directory_private.location_text(p)),p_query)
 and (not p_favorites or exists(select 1 from directory_private.favorites f where f.owner_id=auth.uid() and f.profile_id=p.id))
 order by p.id limit 21), page as(select * from candidates order by id limit 20)
 select coalesce((select jsonb_agg(directory_private.profile_json(p) order by p.id) from page join directory_private.profiles p on p.id=page.id),'[]'::jsonb),
 (select count(*)>20 from candidates),(select id from page order by id desc limit 1) into items,more,last_id;
 return jsonb_build_object('items',items,'next',case when more then last_id else null end);
end $$;

commit;
