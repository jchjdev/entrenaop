begin;
set local statement_timeout='45s';
do $$
declare buyer uuid; other uuid:=gen_random_uuid(); order_id uuid; token uuid; offer commerce_private.offers;
 j jsonb; k jsonb; access public.trainer_access; n integer:=0;
begin
 if (select count(*) from commerce_private.offers where active and plan_key<>'legacy')<>20 then
   raise exception 'Falta un precio/cupo del catálogo de ensayo'; end if;
 if exists(select 1 from commerce_private.offers where plan_key<>'legacy' and
   (capacity not in(5,10,20,50,100) or interval<>'month' or currency<>'EUR')) then
   raise exception 'Catálogo fuera del contrato mensual'; end if;
 update commerce_private.settings set enabled=true;
 insert into auth.users(id,email,email_confirmed_at) values(other,other||'@commerce.invalid',now());
 insert into auth.mfa_factors(id,user_id,factor_type,status,created_at,updated_at)
 values(gen_random_uuid(),other,'totp','verified',now(),now());
 for offer in select * from commerce_private.offers where active and plan_key<>'legacy' order by id loop
  if position(chr(195) in offer.title)>0 then raise exception 'Etiqueta de oferta con codificacion incorrecta'; end if;
   buyer:=gen_random_uuid();
   insert into auth.users(id,email,email_confirmed_at) values(buyer,buyer||'@commerce.invalid',now());
   insert into auth.mfa_factors(id,user_id,factor_type,status,created_at,updated_at)
     values(gen_random_uuid(),buyer,'totp','verified',now(),now());
   perform set_config('request.jwt.claim.sub',buyer::text,true);
   perform set_config('request.jwt.claims',jsonb_build_object('sub',buyer,'role','authenticated','aal','aal2')::text,true);
   set local role authenticated;
   order_id:=public.prepare_trainer_subscription(buyer,offer.id);
   j:=public.get_my_trainer_subscription(buyer);
   if (j->'subscription'->>'offer_id') is distinct from offer.id::text then raise exception 'Se pierde la oferta elegida'; end if;
   if public.prepare_trainer_subscription(buyer,offer.id)<>order_id then raise exception 'Reintento no idempotente'; end if;
   begin perform public.prepare_trainer_subscription(buyer,(select (option.value->>'id')::uuid from jsonb_array_elements(j->'offers') as option(value) where option.value->>'id'<>offer.id::text limit 1));
     raise exception 'Cambia silenciosamente el plan de una compra pendiente';
     exception when unique_violation then null; end;
   begin perform 1 from commerce_private.offers; raise exception 'Cliente lee catálogo privado';
     exception when insufficient_privilege then null; end;
   reset role;
   if exists(select 1 from public.trainer_access where trainer_id=buyer and enabled) then
     raise exception 'Preparar una compra concede acceso'; end if;
   set local role service_role;
   j:=public.trainer_commerce_server('claim',jsonb_build_object('id',order_id));token:=(j->>'lease')::uuid;
   perform public.trainer_commerce_server('customer',jsonb_build_object('id',order_id,'lease',token,'customer_id','cus_'||replace(buyer::text,'-','')));
   perform public.trainer_commerce_server('checkout',jsonb_build_object('id',order_id,'lease',token,'session_id','cs_test_'||replace(buyer::text,'-','')));
   perform public.trainer_commerce_server('apply',jsonb_build_object('id',order_id,'lease',token,'subscription_id','sub_'||replace(buyer::text,'-',''),
     'state','active','invoice_id','in_'||replace(buyer::text,'-',''),'paid_until',now()+interval '30 days'));
   reset role;
   select * into access from public.trainer_access where trainer_id=buyer;
   if not access.enabled or access.client_limit<>offer.capacity or access.manual_enabled then
     raise exception 'No proyecta exactamente el cupo pagado'; end if;
   set local role authenticated;
   j:=public.list_published_workout_warmups(buyer);
   if jsonb_typeof(j->'items')<>'array' then raise exception 'Catálogo de calentamientos inválido'; end if;
   begin perform public.list_published_workout_warmups(other);raise exception 'Permite cambiar de identidad';
     exception when insufficient_privilege then null; end;
   perform set_config('request.jwt.claims',jsonb_build_object('sub',buyer,'role','authenticated','aal','aal1')::text,true);
   begin perform public.list_published_workout_warmups(buyer);raise exception 'Lee sin doble factor';
     exception when insufficient_privilege then null; end;
   reset role;
   for k in select value from jsonb_array_elements(j->'items') loop
     if not exists(select 1 from public.guided_warmups w join public.workout_templates t on t.id=w.template_id
       where t.id=(k->>'id')::uuid and w.status='published' and t.status='published' and t.origin='system') then
       raise exception 'Se filtra contenido ajeno/no publicado'; end if;
   end loop;
   n:=n+1;
 end loop;
 perform set_config('request.jwt.claim.sub',other::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',other,'role','authenticated','aal','aal2')::text,true);
 set local role authenticated;
 begin perform public.list_published_workout_warmups(other);raise exception 'Cuenta sin licencia lee catálogo profesional';
   exception when insufficient_privilege then null; end;
 reset role;
 set local role anon;
 begin perform public.list_published_workout_warmups(other);raise exception 'Anon consulta catálogo';
   exception when insufficient_privilege then null; end;
 reset role;
 if n<>20 then raise exception 'No se probaron todas las ofertas'; end if;
end $$;
rollback;
