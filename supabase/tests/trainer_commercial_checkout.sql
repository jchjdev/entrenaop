begin;
set local statement_timeout='30s';
do $$
declare owner uuid:=gen_random_uuid();other uuid:=gen_random_uuid();pupil uuid:=gen_random_uuid();
 offer uuid:='9d50b521-de26-48b0-8da7-d1fd3e85a660';order_id uuid;again uuid;j jsonb;token uuid;
begin
 insert into auth.users(id,email,email_confirmed_at) values(owner,owner||'@commerce.invalid',now()),(other,other||'@commerce.invalid',now()),(pupil,pupil||'@commerce.invalid',now());
 insert into auth.mfa_factors(id,user_id,factor_type,status,created_at,updated_at)
 values(gen_random_uuid(),owner,'totp','verified',now(),now());
 update commerce_private.settings set enabled=true;
 perform set_config('request.jwt.claim.sub',owner::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',owner,'role','authenticated','aal','aal1')::text,true);
 set local role authenticated;
 j:=public.get_my_trainer_subscription(owner);
 if j->'subscription'<>'null'::jsonb or jsonb_array_length(j->'offers')<>1 then raise exception 'Estado de cuenta nueva incorrecto';end if;
 begin perform public.prepare_trainer_subscription(owner,offer);raise exception 'AAL1 compra';exception when insufficient_privilege then null;end;
 begin perform public.get_my_trainer_subscription(other);raise exception 'Lee compra ajena';exception when insufficient_privilege then null;end;
 begin perform public.trainer_commerce_server('claim','{}');raise exception 'El cliente usa RPC privilegiada';exception when insufficient_privilege then null;end;
 begin perform 1 from commerce_private.orders;raise exception 'Lee pedidos privados';exception when insufficient_privilege then null;end;
 perform set_config('request.jwt.claims',jsonb_build_object('sub',owner,'role','authenticated','aal','aal2')::text,true);
 order_id:=public.prepare_trainer_subscription(owner,offer);
 again:=public.prepare_trainer_subscription(owner,offer);
 if order_id<>again then raise exception 'Duplica pedido al reintentar';end if;
 if (public.get_my_trainer_account_status(owner)->>'enabled')::boolean then raise exception 'Preparar pedido concede acceso';end if;
 reset role;
 set local role service_role;
 begin perform public.trainer_commerce_server('release',jsonb_build_object('id',order_id));raise exception 'Acepta operación sin adquirir lease';exception when serialization_failure then null;end;
 j:=public.trainer_commerce_server('claim',jsonb_build_object('id',order_id));token:=(j->>'lease')::uuid;
 begin perform public.trainer_commerce_server('claim',jsonb_build_object('id',order_id));raise exception 'Acepta conciliaciones simultáneas';exception when lock_not_available then null;end;
 begin perform public.trainer_commerce_server('release',jsonb_build_object('id',order_id,'lease',gen_random_uuid()));raise exception 'Libera lease ajena';exception when serialization_failure then null;end;
 perform public.trainer_commerce_server('customer',jsonb_build_object('id',order_id,'lease',token,'customer_id','cus_CommercialFixture'));
 perform public.trainer_commerce_server('checkout',jsonb_build_object('id',order_id,'lease',token,'session_id','cs_test_CommercialFixture'));
 reset role;
 if exists(select 1 from public.trainer_access where trainer_id=owner and enabled) then raise exception 'Checkout abierto habilita';end if;
 set local role service_role;
 perform public.trainer_commerce_server('apply',jsonb_build_object('id',order_id,'lease',token,'subscription_id','sub_CommercialFixture','state','active',
  'invoice_id','in_CommercialFixture','paid_until',now()+interval '30 days'));
 perform public.trainer_commerce_server('apply',jsonb_build_object('id',order_id,'lease',token,'subscription_id','sub_CommercialFixture','state','active',
  'invoice_id','in_CommercialFixture','paid_until',now()+interval '30 days','cancel_at_period_end',true));
 reset role;
 if not exists(select 1 from public.trainer_access where trainer_id=owner and enabled and client_limit=5 and not manual_enabled)
 then raise exception 'Pago confirmado no activa cinco plazas';end if;
 if not exists(select 1 from commerce_private.receipts where invoice_id='in_CommercialFixture') then raise exception 'No registra recibo';end if;
 -- Un regalo más amplio sobrevive a la cancelación comercial y su caducidad.
 update public.trainer_access set manual_enabled=true,manual_client_limit=8,manual_valid_until=null where trainer_id=owner;
 update commerce_private.orders set paid_until=now()-interval '1 second',state='canceled' where id=order_id;
 perform commerce_private.refresh_access(owner);
 if not exists(select 1 from public.trainer_access where trainer_id=owner and enabled and client_limit=8 and valid_until is null)
 then raise exception 'La cancelación borra el regalo';end if;
 update public.trainer_access set manual_enabled=false where trainer_id=owner;
 if exists(select 1 from public.trainer_access where trainer_id=owner and enabled and (valid_until is null or valid_until>statement_timestamp())) then raise exception 'Mantiene acceso sin fuentes';end if;
 -- Reducir cupo no termina vínculos ni borra historial.
 insert into public.trainer_client_relations(trainer_id,client_id) values(owner,pupil),(owner,other);
 update commerce_private.orders set paid_until=now()+interval '30 days',state='active' where id=order_id;
 perform commerce_private.refresh_access(owner);
 update commerce_private.offers set capacity=1 where id=offer;
 perform commerce_private.refresh_access(owner);
 if not exists(select 1 from public.trainer_client_relations where trainer_id=owner and client_id=pupil and ended_at is null)
 then raise exception 'Expulsa alumno al recalcular cupo';end if;
 -- Si vence la fuente más amplia se cierra primero y se recalcula la inferior.
 update public.trainer_access set manual_enabled=true,manual_client_limit=8,manual_valid_until=now()+interval '1 hour' where trainer_id=owner;
 update public.trainer_access set manual_valid_until=now()-interval '1 second' where trainer_id=owner;
 if not exists(select 1 from public.trainer_access where trainer_id=owner and enabled and client_limit=1) then raise exception 'No recupera la fuente pagada';end if;
 set local role anon;
 begin perform public.get_my_trainer_subscription(owner);raise exception 'Anon consulta contratación';exception when insufficient_privilege then null;end;
 reset role;
end $$;
rollback;
