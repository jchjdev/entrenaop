begin;
set local statement_timeout='30s';
do $$
declare
  first_coach uuid:=gen_random_uuid(); second_coach uuid:=gen_random_uuid();
  excluded_coach uuid:=gen_random_uuid(); pupil uuid:=gen_random_uuid();
  offer uuid:=gen_random_uuid(); trial uuid:=gen_random_uuid();
  first_profile uuid; second_profile uuid; j jsonb; data jsonb;
  first_revision integer; second_revision integer; n integer;
begin
  update directory_private.settings set enabled=false;
  insert into auth.users(id,email,email_confirmed_at)
    select u,u||'@pilot.invalid',now() from unnest(array[first_coach,second_coach,excluded_coach,pupil]) u;
  insert into auth.mfa_factors(id,user_id,factor_type,status,created_at,updated_at)
    select gen_random_uuid(),u,'totp','verified',now(),now()
    from unnest(array[first_coach,second_coach,excluded_coach]) u;
  insert into public.trainer_access(trainer_id,enabled,client_limit,manual_enabled,manual_client_limit,last_reason)
    select u,true,5,true,5,'Contrato transaccional piloto directorio'
    from unnest(array[first_coach,second_coach,excluded_coach]) u;
  insert into commerce_private.offers(id,version,title,price_id,amount,currency,interval,capacity,directory_enabled)
    values(offer,1,'Contrato piloto SQL','price_directoryPilot',100,'EUR','month',5,false);
  insert into commerce_private.customers(owner_id) values(first_coach);
  insert into commerce_private.orders(id,owner_id,offer_id,state,paid_until)
    values(trial,first_coach,offer,'active',now()+interval '3 days');
  insert into directory_private.dev_pilot_members(trainer_id,source_order_id,valid_until,reason)
    values(first_coach,trial,now()+interval '2 days','Piloto SQL, primer preparador'),
      (second_coach,trial,now()+interval '2 days','Piloto SQL, segundo preparador');
  insert into storage.objects(bucket_id,name)
    select 'trainer-directory',u||'/11111111-1111-4111-8111-111111111111.jpg'
    from unnest(array[first_coach,second_coach]) u;
  data:=jsonb_build_object('name','Preparador piloto','description','Carrera y fuerza',
    'specialties',jsonb_build_array('Carrera'),'services',jsonb_build_array('Seguimiento'),
    'mode','ambas','city','Zaragoza','visibility','app',
    'photo_path',first_coach||'/11111111-1111-4111-8111-111111111111.jpg',
    'email','coach@example.test','website','','whatsapp','','price','','accepting',true);
  perform set_config('storage.operation','object.get_authenticated',true);
  perform set_config('request.jwt.claim.sub',first_coach::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',first_coach,'role','authenticated','aal','aal2',
    'iss','https://sxbxfjqgoddzhtcyhalw.supabase.co/auth/v1')::text,true);
  set local role authenticated;
  j:=public.directory_save(first_coach,0,data,false,false);
  first_profile:=(j->'profile'->>'id')::uuid;first_revision:=(j->>'revision')::integer;
  if j->>'eligible'<>'true' or j->>'web_allowed'<>'false' or j->>'pilot_until' is null then
    raise exception 'No describe el permiso individual del piloto';end if;
  begin perform public.directory_save(first_coach,first_revision,data,true,true);
    raise exception 'Aceptó publicación sin versión nueva';exception when insufficient_privilege then null;end;
  data:=data||'{"consent_version":2}'::jsonb;
  begin perform public.directory_save(first_coach,first_revision,data,true,true);
    raise exception 'Publicó con directorio apagado';exception when insufficient_privilege then null;end;
  reset role;
  update directory_private.settings set enabled=true;
  set local role authenticated;
  begin perform public.directory_save(first_coach,first_revision,data,true,false);
    raise exception 'Publicó sin aceptar';exception when insufficient_privilege then null;end;
  begin perform public.directory_save(first_coach,first_revision,data||'{"visibility":"web"}'::jsonb,true,true);
    raise exception 'El piloto publica en web';exception when insufficient_privilege then null;end;
  j:=public.directory_save(first_coach,first_revision,data,true,true);
  first_revision:=(j->>'revision')::integer;
  begin insert into directory_private.dev_pilot_members(trainer_id,source_order_id,valid_until,reason)
    values(excluded_coach,trial,now()+interval '1 day','Autoconcesión prohibida');
    raise exception 'El cliente se concede permisos';exception when insufficient_privilege then null;end;
  reset role;
  perform set_config('request.jwt.claim.sub',second_coach::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',second_coach,'role','authenticated','aal','aal2',
    'iss','https://sxbxfjqgoddzhtcyhalw.supabase.co/auth/v1')::text,true);
  set local role authenticated;
  data:=data||jsonb_build_object('city','Huesca','photo_path',second_coach||'/11111111-1111-4111-8111-111111111111.jpg');
  j:=public.directory_save(second_coach,0,data,true,true);
  second_profile:=(j->'profile'->>'id')::uuid;second_revision:=(j->>'revision')::integer;
  reset role;
  if (select count(*) from directory_private.publication_acceptances where profile_id in(first_profile,second_profile))<>2 then
    raise exception 'No registró ambas aceptaciones';end if;
  perform set_config('request.jwt.claim.sub',excluded_coach::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',excluded_coach,'role','authenticated','aal','aal2',
    'iss','https://sxbxfjqgoddzhtcyhalw.supabase.co/auth/v1')::text,true);
  set local role authenticated;
  if public.directory_own(excluded_coach)->>'eligible'<>'false' then
    raise exception 'Habilitó a otros preparadores de la misma oferta';end if;
  begin perform public.directory_save(first_coach,first_revision,data,false,false);
    raise exception 'Suplantó al primer preparador';exception when insufficient_privilege then null;end;
  reset role;
  perform set_config('request.jwt.claim.sub',pupil::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',pupil,'role','authenticated','aal','aal1',
    'iss','https://sxbxfjqgoddzhtcyhalw.supabase.co/auth/v1')::text,true);
  set local role authenticated;
  if jsonb_array_length(public.directory_search(p_query=>'Preparador piloto',p_web_only=>false)->'items')<>2 then
    raise exception 'El alumno no puede comparar dos preparadores';end if;
  j:=public.directory_search(p_query=>'Preparador piloto',p_city=>'zArAg',p_web_only=>false);
  if jsonb_array_length(j->'items')<>1 or j->'items'->0->>'city'<>'Zaragoza' then
    raise exception 'No filtra por localidad parcial y sin distinguir mayúsculas';end if;
  if jsonb_array_length(public.directory_search(p_query=>'Preparador piloto',p_city=>'Huesca',p_web_only=>false)->'items')<>1 then
    raise exception 'No distingue la segunda localidad';end if;
  perform public.directory_favorite(pupil,first_profile,true);
  if public.directory_profile(first_profile,false)->>'city'<>'Zaragoza' then raise exception 'No abre la ficha';end if;
  perform set_config('storage.operation','object.sign',true);
  if exists(select 1 from storage.objects where bucket_id='trainer-directory' and name like first_coach||'/%') then
    raise exception 'El alumno firma una foto';end if;
  reset role;
  perform set_config('request.jwt.claim.sub',first_coach::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',first_coach,'role','authenticated','aal','aal2',
    'iss','https://sxbxfjqgoddzhtcyhalw.supabase.co/auth/v1')::text,true);
  set local role authenticated;
  if exists(select 1 from storage.objects where bucket_id='trainer-directory' and name like first_coach||'/%') then
    raise exception 'El propietario firma una foto';end if;
  j:=public.directory_save(first_coach,first_revision,data||jsonb_build_object('city','Zaragoza',
    'photo_path',first_coach||'/11111111-1111-4111-8111-111111111111.jpg'),false,false);
  first_revision:=(j->>'revision')::integer;
  reset role;
  if (select count(*) from directory_private.publication_acceptances where profile_id=first_profile)<>1 then
    raise exception 'Pausar elimina la evidencia de aceptación';end if;
  perform set_config('request.jwt.claim.sub',pupil::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',pupil,'role','authenticated','aal','aal1',
    'iss','https://sxbxfjqgoddzhtcyhalw.supabase.co/auth/v1')::text,true);
  set local role authenticated;
  if jsonb_array_length(public.directory_search(p_favorites=>true,p_web_only=>false)->'items')<>0 then
    raise exception 'Favorito conserva ficha retirada';end if;
  reset role;
  update directory_private.dev_pilot_members set enabled=false where trainer_id=second_coach;
  set local role authenticated;
  begin perform public.directory_profile(second_profile,false);raise exception 'Permiso revocado mantiene ficha';
    exception when insufficient_privilege then null;end;
  reset role;
  update directory_private.dev_pilot_members set enabled=true where trainer_id=second_coach;
  update directory_private.dev_pilot_members set created_at=now()-interval '2 days',valid_until=now()-interval '1 day'
    where trainer_id=second_coach;
  set local role authenticated;
  begin perform public.directory_profile(second_profile,false);raise exception 'Permiso temporal caducado mantiene ficha';
    exception when insufficient_privilege then null;end;
  reset role;
  update directory_private.dev_pilot_members set valid_until=now()+interval '2 days' where trainer_id=second_coach;
  update commerce_private.orders set paid_until=now()-interval '1 second' where id=trial;
  set local role authenticated;
  begin perform public.directory_profile(second_profile,false);raise exception 'Ensayo caducado mantiene ficha';
    exception when insufficient_privilege then null;end;
  reset role;
  update commerce_private.orders set paid_until=now()+interval '3 days' where id=trial;
  update public.trainer_access set enabled=false where trainer_id=second_coach;
  set local role authenticated;
  begin perform public.directory_profile(second_profile,false);raise exception 'Acceso profesional retirado mantiene ficha';
    exception when insufficient_privilege then null;end;
  reset role;
  update public.trainer_access set enabled=true where trainer_id=second_coach;
  perform set_config('storage.operation','object.get_authenticated',true);
  update auth.users set email_confirmed_at=null where id=pupil;
  set local role authenticated;
  begin perform public.directory_profile(second_profile,false);raise exception 'Correo sin confirmar abre ficha';
    exception when insufficient_privilege then null;end;
  reset role;
  update auth.users set email_confirmed_at=now() where id=pupil;
  perform set_config('request.jwt.claim.sub',second_coach::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',second_coach,'role','authenticated','aal','aal1',
    'iss','https://sxbxfjqgoddzhtcyhalw.supabase.co/auth/v1')::text,true);
  set local role authenticated;
  begin perform public.directory_save(second_coach,second_revision,data,true,true);raise exception 'Edita sin MFA';
    exception when insufficient_privilege then null;end;
  reset role;
  perform set_config('request.jwt.claim.sub',pupil::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',pupil,'role','authenticated','aal','aal1','iss','https://other.invalid/auth/v1')::text,true);
  set local role authenticated;
  begin perform public.directory_profile(second_profile,false);raise exception 'El piloto opera en otro proyecto';
    exception when insufficient_privilege then null;end;
  reset role;
  perform set_config('request.jwt.claim.sub','',true);perform set_config('request.jwt.claims','{"role":"anon"}',true);
  set local role anon;
  begin perform public.directory_profile(second_profile,false);raise exception 'Anon ve el piloto';
    exception when insufficient_privilege then null;end;
  reset role;
end $$;
rollback;
