begin;
set local statement_timeout='45s';
do $$
declare n integer; plan text; directory boolean; expected integer; base integer;
 rates integer[]; f commerce_private.offers; owner uuid:=gen_random_uuid(); other uuid:=gen_random_uuid();
 old_offer uuid:='1f4d2397-470c-5d41-84e9-e0cdddf1c8e1'; order_id uuid:=gen_random_uuid(); j jsonb;
begin
 if (select count(*) from commerce_private.offers where active and plan_key<>'legacy')<>384 then
  raise exception 'El catálogo no contiene las 384 combinaciones';end if;
 foreach plan in array array['basic','professional','complete','basic_directory'] loop
  base:=case plan when 'basic' then 1290 when 'professional' then 1990 when 'complete' then 2490 else 1780 end;
  rates:=case plan when 'professional' then array[120,100,70,50,45,35]
   when 'complete' then array[140,120,90,70,55,45] else array[100,80,60,40,35,25] end;
  directory:=plan<>'basic';
  for n in 5..100 loop
   expected:=base+greatest(least(n,10)-5,0)*rates[1]+greatest(least(n,20)-10,0)*rates[2]
    +greatest(least(n,35)-20,0)*rates[3]+greatest(least(n,50)-35,0)*rates[4]
    +greatest(least(n,75)-50,0)*rates[5]+greatest(n-75,0)*rates[6];
   select * into strict f from commerce_private.offers where active and capacity=n
    and plan_key=case when plan='basic_directory' then 'basic' else plan end and directory_option=directory;
   if f.amount<>expected or f.currency<>'EUR' or f.interval<>'month'
    or f.version<>(case when n=5 then 1 else 3 end) then raise exception 'Tarifa incoherente para %/%',plan,n;end if;
  end loop;
 end loop;
 -- Las ofertas antiguas siguen existiendo para acreditar compras y renovaciones.
 if not exists(select 1 from commerce_private.offers where id=old_offer and not active and amount=2990) then
  raise exception 'Se pierde o repricia la oferta histórica';end if;
 update commerce_private.settings set enabled=true;
 insert into auth.users(id,email,email_confirmed_at) values(owner,owner||'@unit-catalog.invalid',now()),(other,other||'@unit-catalog.invalid',now());
 insert into auth.mfa_factors(id,user_id,factor_type,status,created_at,updated_at)
 values(gen_random_uuid(),owner,'totp','verified',now(),now()),(gen_random_uuid(),other,'totp','verified',now(),now());
 insert into commerce_private.customers(owner_id) values(owner);
 insert into commerce_private.orders(id,owner_id,offer_id,state) values(order_id,owner,old_offer,'prepared');
 perform set_config('request.jwt.claim.sub',owner::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',owner,'role','authenticated','aal','aal2')::text,true);
 set local role authenticated;
 if public.prepare_trainer_subscription(owner,old_offer)<>order_id then raise exception 'No se retoma el pedido propio';end if;
 j:=public.get_my_trainer_subscription(owner);
 if (j->'subscription'->>'amount')::integer<>2990 or (j->'subscription'->>'capacity')::integer<>20 then
  raise exception 'El pedido pendiente toma las nuevas condiciones';end if;
 begin perform public.get_my_trainer_subscription(other);raise exception 'Se consulta la compra de otro usuario';
  exception when insufficient_privilege then null;end;
 reset role;
 update commerce_private.orders set state='active',paid_until=now()+interval '30 days' where id=order_id;
 perform commerce_private.refresh_access(owner);
 if not exists(select 1 from public.trainer_access where trainer_id=owner and enabled and client_limit=20) then
  raise exception 'Se altera el cupo ya pagado';end if;
 perform set_config('request.jwt.claim.sub',other::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',other,'role','authenticated','aal','aal2')::text,true);
 set local role authenticated;
 begin perform public.prepare_trainer_subscription(other,old_offer);raise exception 'Una nueva cuenta compra una tarifa retirada';
  exception when invalid_parameter_value then null;end;
 reset role;
end $$;
rollback;
