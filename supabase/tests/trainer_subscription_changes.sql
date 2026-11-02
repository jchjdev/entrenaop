begin;
set local statement_timeout='30s';
do $$
declare owner uuid:=gen_random_uuid(); other uuid:=gen_random_uuid(); pupils uuid[]:='{}'; pupil uuid;
 order_id uuid:=gen_random_uuid(); original uuid; smaller uuid; larger uuid; j jsonb; change_id uuid;
 token uuid; args jsonb; period_end timestamptz:=now()+interval '30 days'; i integer; previous_count integer;
begin
 select id into original from commerce_private.offers where plan_key='basic' and not directory_option and capacity=20 and active;
 select id into smaller from commerce_private.offers where plan_key='basic' and not directory_option and capacity=5 and active;
 select id into larger from commerce_private.offers where plan_key='basic' and not directory_option and capacity=50 and active;
 insert into auth.users(id,email,email_confirmed_at) values(owner,owner||'@changes.invalid',now()),(other,other||'@changes.invalid',now());
 insert into auth.mfa_factors(id,user_id,factor_type,status,created_at,updated_at)
 values(gen_random_uuid(),owner,'totp','verified',now(),now());
 insert into commerce_private.customers(owner_id,customer_id) values(owner,'cus_ChangesFixture');
 insert into commerce_private.orders(id,owner_id,offer_id,state,paid_until,subscription_id,session_id)
 values(order_id,owner,original,'active',period_end,'sub_ChangesFixture','cs_test_ChangesFixture');
 perform commerce_private.refresh_access(owner);
 for i in 1..8 loop
  pupil:=gen_random_uuid();pupils:=array_append(pupils,pupil);
  insert into auth.users(id,email,email_confirmed_at) values(pupil,pupil||'@changes.invalid',now());
  insert into public.trainer_client_relations(trainer_id,client_id) values(owner,pupil);
 end loop;
 update commerce_private.settings set enabled=true;
 perform set_config('request.jwt.claim.sub',owner::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',owner,'role','authenticated','aal','aal1')::text,true);
 set local role authenticated;
 begin perform public.prepare_trainer_plan_change(owner,smaller);raise exception 'AAL1 modifica plan';exception when insufficient_privilege then null;end;
 perform set_config('request.jwt.claims',jsonb_build_object('sub',owner,'role','authenticated','aal','aal2')::text,true);
 begin perform public.prepare_trainer_plan_change(other,smaller);raise exception 'Modifica otra cuenta';exception when insufficient_privilege then null;end;
 begin perform public.trainer_commerce_server('change_apply','{}');raise exception 'El cliente acredita cambios';exception when insufficient_privilege then null;end;
 j:=public.prepare_trainer_plan_change(owner,smaller);change_id:=(j->>'change_id')::uuid;
 if public.prepare_trainer_plan_change(owner,smaller)<>j then raise exception 'Duplica intento';end if;
 reset role;
 if (select kind from commerce_private.plan_changes where id=change_id)<>'renewal' then raise exception 'Reduce inmediatamente';end if;
 if (select client_limit from public.trainer_access where trainer_id=owner)<>20 then raise exception 'Preparar reduce plazas';end if;
 set local role service_role;
 j:=public.trainer_commerce_server('claim',jsonb_build_object('id',order_id));token:=(j->>'lease')::uuid;
 args:=jsonb_build_object('id',order_id,'lease',token,'change_id',change_id);
 perform public.trainer_commerce_server('change_quote',args||jsonb_build_object('amount',0,'effective_at',period_end,
  'proration_at',extract(epoch from now())::bigint,'item_id','si_ChangesFixture'));
 perform public.trainer_commerce_server('change_start',args);
 perform public.trainer_commerce_server('change_schedule_id',args||jsonb_build_object('schedule_id','sub_sched_ChangesFixture'));
 perform public.trainer_commerce_server('change_scheduled',args);
 begin perform public.trainer_commerce_server('change_apply',args||jsonb_build_object('invoice_id','in_ChangesRenewal','paid_until',period_end+interval '30 days'));
 raise exception 'Reduce antes de renovar';exception when serialization_failure then null;end;
 perform public.trainer_commerce_server('release',args);
 reset role;
 -- Simula el paso del tiempo sin cambiar el reloj ni dejar datos del ensayo.
 update commerce_private.plan_changes set effective_at=now()-interval '1 second' where id=change_id;
 update commerce_private.orders set paid_until=now()-interval '1 second' where id=order_id;
 set local role service_role;
 j:=public.trainer_commerce_server('claim',jsonb_build_object('id',order_id));args:=args||jsonb_build_object('lease',j->>'lease');
 perform public.trainer_commerce_server('change_apply',args||jsonb_build_object('invoice_id','in_ChangesRenewal','paid_until',period_end));
 perform public.trainer_commerce_server('release',args);
 reset role;
 if (select client_limit from public.trainer_access where trainer_id=owner)<>5
  or (select count(*) from public.trainer_client_relations where trainer_id=owner and ended_at is null)<>8
  then raise exception 'No reduce cupo o expulsa alumnos';end if;
 if (select offer_id from commerce_private.orders where id=order_id)<>original then raise exception 'Reescribe compra original';end if;
 set local role authenticated;
 j:=public.get_trainer_access();
 if not (j->>'over_limit')::boolean then raise exception 'Oculta exceso de alumnos';end if;
 if public.get_my_trainer_subscription(owner)#>>'{subscription,offer_id}' is distinct from smaller::text then raise exception 'El selector sigue identificando la oferta inicial';end if;
 -- Las invitaciones pendientes no reservan plaza: el límite se impone al aceptar.
 perform public.create_trainer_invitation(gen_random_uuid(),repeat('a',64));
 perform set_config('request.jwt.claim.sub',other::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',other,'role','authenticated','aal','aal1')::text,true);
 begin perform public.accept_trainer_invitation(repeat('a',64));raise exception 'Incorpora por encima del cupo';exception when check_violation then null;end;
 perform set_config('request.jwt.claim.sub',owner::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',owner,'role','authenticated','aal','aal2')::text,true);
 -- La siguiente ampliación fija una nueva intención sin regalar plazas al preparar.
 j:=public.prepare_trainer_plan_change(owner,larger);change_id:=(j->>'change_id')::uuid;
 reset role;
 if (select kind from commerce_private.plan_changes where id=change_id)<>'immediate' then raise exception 'No amplía al pagar';end if;
 set local role service_role;
 j:=public.trainer_commerce_server('claim',jsonb_build_object('id',order_id));token:=(j->>'lease')::uuid;
 args:=jsonb_build_object('id',order_id,'lease',token,'change_id',change_id);
 perform public.trainer_commerce_server('change_quote',args||jsonb_build_object('amount',100,'effective_at',period_end,
  'proration_at',extract(epoch from now())::bigint,'item_id','si_ChangesFixture'));
 perform public.trainer_commerce_server('change_start',args);
 perform public.trainer_commerce_server('change_invoice',args||jsonb_build_object('invoice_id','in_ChangesUpgrade'));
 reset role;
 if (select client_limit from public.trainer_access where trainer_id=owner)<>5 then raise exception 'Pago pendiente concede plazas';end if;
 -- Incluso un pago válido no levanta la suspensión administrativa.
 update public.trainer_access set suspended=true,suspended_at=clock_timestamp(),suspension_reason='Ensayo aislado' where trainer_id=owner;
 set local role service_role;
 perform public.trainer_commerce_server('change_apply',args||jsonb_build_object('invoice_id','in_ChangesUpgrade','paid_until',period_end));
 perform public.trainer_commerce_server('change_apply',args||jsonb_build_object('invoice_id','in_ChangesUpgrade','paid_until',period_end));
 perform public.trainer_commerce_server('release',args);
 reset role;
 if not exists(select 1 from public.trainer_access where trainer_id=owner and suspended and not enabled and client_limit=50)
 then raise exception 'La ampliación levanta suspensión';end if;
 if (select count(*) from commerce_private.receipts where invoice_id='in_ChangesUpgrade')<>1 then raise exception 'Duplica recibo';end if;
 if (select offer_revision from commerce_private.orders where id=order_id)<>2 then raise exception 'Duplica versión efectiva';end if;
 update public.trainer_access set suspended=false,suspended_at=null,suspension_reason=null,manual_enabled=true,manual_client_limit=100 where trainer_id=owner;
 perform commerce_private.refresh_access(owner);
 if (select client_limit from public.trainer_access where trainer_id=owner)<>100 then raise exception 'Cambio borra concesión manual';end if;
 if (select count(*) from public.trainer_client_relations where trainer_id=owner and ended_at is null)<>8 then raise exception 'Altera alumnos';end if;
 -- Subir de Básico con extra a Profesional conserva el directorio incluido.
 update commerce_private.orders set current_offer_id=(select id from commerce_private.offers where plan_key='basic' and directory_option and capacity=5 and active) where id=order_id;
 select id into larger from commerce_private.offers where plan_key='professional' and capacity=5 and active;
 set local role authenticated;
 j:=public.prepare_trainer_plan_change(owner,larger);
 reset role;
 if (select kind from commerce_private.plan_changes where id=(j->>'change_id')::uuid)<>'immediate' then raise exception 'Confunde directorio incluido con pérdida de cobertura';end if;
 if has_table_privilege('authenticated','commerce_private.plan_changes','select') or
  has_function_privilege('anon','public.prepare_trainer_plan_change(uuid,uuid)','execute') then raise exception 'Expone contratos privados';end if;
end $$;
rollback;
