begin;
set local statement_timeout='30s';

do $$
declare
 coach uuid:=gen_random_uuid(); pupil uuid:=gen_random_uuid(); offer uuid;
 data jsonb; result jsonb; revision integer; profile_id uuid;
 marker text:='UbicacionSQL-'||gen_random_uuid()::text;
 needle text;
begin
 if (select count(*) from jsonb_object_keys(directory_private.location_catalog()))<>52 then
   raise exception 'Catálogo provincial incompleto';end if;
 select id into strict offer from commerce_private.offers
 where active and plan_key='professional' and capacity=5;
 insert into auth.users(id,email,email_confirmed_at)
 values(coach,coach||'@locations.invalid',now()),(pupil,pupil||'@locations.invalid',now());
 insert into auth.mfa_factors(id,user_id,factor_type,status,created_at,updated_at)
 values(gen_random_uuid(),coach,'totp','verified',now(),now());
 insert into commerce_private.customers(owner_id) values(coach);
 insert into commerce_private.orders(owner_id,offer_id,state,paid_until)
 values(coach,offer,'active',now()+interval '3 days');
 perform commerce_private.refresh_access(coach);
 insert into storage.objects(bucket_id,name)
 values('trainer-directory',coach||'/11111111-1111-4111-8111-111111111111.jpg');
 update directory_private.settings set enabled=true;
 data:=jsonb_build_object('name',marker,'description','Carrera',
 'specialties',jsonb_build_array('Carrera'),'services',jsonb_build_array('Seguimiento'),
 'mode','presencial','city','Telde','province_code','35','island','Gran Canaria',
 'visibility','app','photo_path',coach||'/11111111-1111-4111-8111-111111111111.jpg',
 'email','coach@example.test','website','','whatsapp','','price','','accepting',true,'consent_version',2);
 perform set_config('request.jwt.claim.sub',coach::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',coach,'role','authenticated','aal','aal2')::text,true);
 set local role authenticated;
 result:=public.directory_save(coach,0,data,true,true);
 revision:=(result->>'revision')::integer;profile_id:=(result->'profile'->>'id')::uuid;
 if result->'profile'->>'province_code'<>'35' or result->'profile'->>'island'<>'Gran Canaria' then
   raise exception 'No guarda o serializa la ubicación';end if;
 -- Un cliente anterior omite las claves nuevas: conserva ambos datos.
 result:=public.directory_save(coach,revision,data-'province_code'-'island',true,true);
 revision:=(result->>'revision')::integer;
 if result->'profile'->>'province_code'<>'35' or result->'profile'->>'island'<>'Gran Canaria' then
   raise exception 'Cliente anterior borró la ubicación';end if;
 begin
   perform public.directory_save(coach,revision,data||'{"province_code":"99"}',true,true);
   raise exception 'Admite provincia inexistente';exception when check_violation then null;
 end;
 begin
   perform public.directory_save(coach,revision,data||'{"province_code":"28"}',true,true);
   raise exception 'Admite isla fuera de provincia';exception when check_violation then null;
 end;
 reset role;
 perform set_config('request.jwt.claim.sub',pupil::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',pupil,'role','authenticated','aal','aal1')::text,true);
 set local role authenticated;
 foreach needle in array array['tEL','grAn CANARIA','Las Palmas','Canarias','palmas telde','  gran   canaria  '] loop
   result:=public.directory_search(p_query=>marker,p_city=>needle,p_web_only=>false);
   if jsonb_array_length(result->'items')<>1 then raise exception 'No encuentra por %',needle;end if;
 end loop;
 if jsonb_array_length(public.directory_search(p_query=>'Gran Canaria '||marker,p_web_only=>false)->'items')<>1 then
   raise exception 'La búsqueda general ignora ubicación';end if;
 foreach needle in array array['Tenerife','Madrid','%','_'] loop
   if jsonb_array_length(public.directory_search(p_query=>marker,p_city=>needle,p_web_only=>false)->'items')<>0 then
     raise exception 'Resultado incorrecto por %',needle;end if;
 end loop;
 if jsonb_array_length(public.directory_search(p_query=>marker,p_city=>'Las Palmas',p_after=>profile_id,p_web_only=>false)->'items')<>0 then
   raise exception 'La ubicación ignora el cursor de paginación';end if;
 if jsonb_array_length(public.directory_search(p_query=>marker,p_city=>'Telde',p_mode=>'online',p_web_only=>false)->'items')<>0 then
   raise exception 'La ubicación ignora la modalidad';end if;
 perform public.directory_favorite(pupil,profile_id,true);
 if jsonb_array_length(public.directory_search(p_query=>marker,p_city=>'Gran Canaria',p_favorites=>true,p_web_only=>false)->'items')<>1 then
   raise exception 'Ubicación pierde favoritos';end if;
 begin
   perform public.directory_save(coach,revision,data,false,false);
   raise exception 'Alumno cambia ubicación ajena';exception when insufficient_privilege then null;
 end;
 reset role;
 -- Sin localidad basta la provincia, incluso en presencial.
 perform set_config('request.jwt.claim.sub',coach::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',coach,'role','authenticated','aal','aal2')::text,true);
 set local role authenticated;
 result:=public.directory_save(coach,revision,data||'{"city":"","province_code":"07","island":""}',true,true);
 revision:=(result->>'revision')::integer;
 if result->'profile'->>'city'<>'' then raise exception 'Inventa una localidad';end if;
 if jsonb_array_length(public.directory_search(p_query=>marker,p_city=>'baleares',p_web_only=>false)->'items')<>1 then
   raise exception 'No encuentra provincia sin localidad';end if;
 result:=public.directory_save(coach,revision,data||'{"city":"Ávila","province_code":"05","island":""}',true,true);
 if jsonb_array_length(public.directory_search(p_query=>marker,p_city=>'AVILA',p_web_only=>false)->'items')<>1 then
   raise exception 'No normaliza las tildes';end if;
 reset role;
 -- Los filtros amplios mantienen las mismas puertas de visibilidad.
 perform set_config('request.jwt.claim.sub','',true);
 perform set_config('request.jwt.claims','{"role":"anon"}',true);
 set local role anon;
 if jsonb_array_length(public.directory_search(p_query=>marker,p_city=>'avila',p_web_only=>false)->'items')<>0 then
   raise exception 'Anon descubre una ubicación solo app';end if;
 reset role;
 update directory_private.profiles set visibility='web' where id=profile_id;
 set local role anon;
 if jsonb_array_length(public.directory_search(p_query=>marker,p_city=>'avila')->'items')<>1 then
   raise exception 'La búsqueda pública pierde ubicación';end if;
 reset role;
 update directory_private.profiles set suspended=true where id=profile_id;
 set local role anon;
 if jsonb_array_length(public.directory_search(p_query=>marker,p_city=>'avila')->'items')<>0 then
   raise exception 'Ubicación elude moderación';end if;
 reset role;
 if has_table_privilege('authenticated','directory_private.profiles','UPDATE')
   or has_function_privilege('anon','directory_private.location_catalog()','EXECUTE') then
   raise exception 'Amplía privilegios directos';end if;
end $$;
rollback;
