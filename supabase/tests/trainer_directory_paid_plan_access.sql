begin;
set local statement_timeout='30s';

do $$
declare
  coach uuid:=gen_random_uuid(); other uuid:=gen_random_uuid();
  original uuid; addon uuid; professional uuid; complete uuid;
  order_id uuid:=gen_random_uuid(); change_id uuid:=gen_random_uuid(); j jsonb;
begin
  select id into original from commerce_private.offers
    where active and plan_key='basic' and not directory_option and capacity=5;
  select id into addon from commerce_private.offers
    where active and plan_key='basic' and directory_option and capacity=5;
  select id into professional from commerce_private.offers
    where active and plan_key='professional' and capacity=5;
  select id into complete from commerce_private.offers
    where active and plan_key='complete' and capacity=5;
  if original is null or addon is null or professional is null or complete is null then
    raise exception 'Falta el catálogo del ensayo';
  end if;
  if exists(select 1 from commerce_private.offers
    where plan_key in ('basic','professional','complete')
      and directory_enabled is distinct from
        (plan_key in ('professional','complete') or (plan_key='basic' and directory_option))) then
    raise exception 'El derecho de ficha no coincide con el nivel contratado';
  end if;
  if has_function_privilege('authenticated','directory_private.commercial_eligible(uuid)','EXECUTE')
    or has_table_privilege('authenticated','commerce_private.offers','UPDATE') then
    raise exception 'El cliente puede concederse la prestación';
  end if;

  insert into auth.users(id,email,email_confirmed_at)
    values(coach,coach||'@directory-paid.invalid',now()),(other,other||'@directory-paid.invalid',now());
  insert into auth.mfa_factors(id,user_id,factor_type,status,created_at,updated_at)
    values(gen_random_uuid(),coach,'totp','verified',now(),now());
  insert into commerce_private.customers(owner_id) values(coach);
  insert into commerce_private.orders(id,owner_id,offer_id,state,paid_until)
    values(order_id,coach,original,'active',now()+interval '30 days');
  perform commerce_private.refresh_access(coach);
  perform set_config('request.jwt.claim.sub',coach::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',coach,'role','authenticated','aal','aal2')::text,true);
  set local role authenticated;
  j:=public.directory_own(coach);
  if (j->>'eligible')::boolean then raise exception 'Básico sin extra puede publicar';end if;
  j:=public.get_my_trainer_subscription(coach);
  if not exists(select 1 from jsonb_array_elements(j->'offers') f
    where f->>'id'=complete::text and (f->>'directory_enabled')::boolean) then
    raise exception 'El portal no recibe la prestación habilitada';
  end if;
  begin
    perform public.directory_own(other);
    raise exception 'Consulta el editor de otro preparador';
  exception when insufficient_privilege then null;
  end;
  reset role;

  -- Preparar o dejar pendiente de pago una mejora no concede el derecho.
  insert into commerce_private.plan_changes(id,order_id,from_offer_id,offer_id,expected_revision,kind,state)
    values(change_id,order_id,original,complete,0,'immediate','payment_pending');
  if directory_private.commercial_eligible(coach) then raise exception 'Activa ficha antes de acreditar la mejora';end if;

  -- Solo la oferta vigente acreditada cambia la elegibilidad, no la compra inicial.
  update commerce_private.plan_changes set state='applied' where id=change_id;
  update commerce_private.orders set current_offer_id=complete,offer_revision=1 where id=order_id;
  perform commerce_private.refresh_access(coach);
  set local role authenticated;
  j:=public.directory_own(coach);
  if not (j->>'eligible')::boolean then raise exception 'Completo pagado no puede preparar su publicación';end if;
  if coalesce((j->>'published')::boolean,false) then raise exception 'La compra publica sin consentimiento';end if;
  reset role;

  insert into commerce_private.plan_changes(order_id,from_offer_id,offer_id,expected_revision,kind,state,effective_at)
    values(order_id,complete,original,1,'renewal','scheduled',now()+interval '30 days');
  if not directory_private.commercial_eligible(coach) then raise exception 'Una bajada futura retira el periodo pagado';end if;
  update commerce_private.orders set current_offer_id=original,offer_revision=2 where id=order_id;
  if directory_private.commercial_eligible(coach) then raise exception 'La compra inicial o mejora antigua mantienen un derecho retirado';end if;

  update commerce_private.orders set current_offer_id=addon where id=order_id;
  if not directory_private.commercial_eligible(coach) then raise exception 'Básico con extra pagado no puede publicar';end if;
  update commerce_private.orders set current_offer_id=professional where id=order_id;
  if not directory_private.commercial_eligible(coach) then raise exception 'Profesional pagado no puede publicar';end if;
  update public.trainer_access set suspended=true,suspended_at=clock_timestamp(),
    suspension_reason='Suspensión transaccional del preparador' where trainer_id=coach;
  if directory_private.commercial_eligible(coach) then raise exception 'Un acceso deshabilitado anuncia';end if;
  update public.trainer_access set suspended=false,suspended_at=null,suspension_reason=null where trainer_id=coach;
  perform commerce_private.refresh_access(coach);
  update commerce_private.orders set paid_until=now()-interval '1 second' where id=order_id;
  if directory_private.commercial_eligible(coach) then raise exception 'La ficha sigue elegible tras acabar la cobertura';end if;

  -- Tener solo herramientas regaladas no añade publicidad comercial.
  insert into public.trainer_access(trainer_id,enabled,client_limit,manual_enabled,manual_client_limit,last_reason)
    values(other,true,5,true,5,'Contrato transaccional de acceso regalado sin publicidad');
  if directory_private.commercial_eligible(other) then raise exception 'Un regalo de herramientas incluye publicidad';end if;
  insert into commerce_private.customers(owner_id) values(other);
  insert into commerce_private.orders(owner_id,offer_id,current_offer_id,state,paid_until)
    values(other,complete,original,'active',now()+interval '30 days');
  perform commerce_private.refresh_access(other);
  if directory_private.commercial_eligible(other) then
    raise exception 'Completo en la compra inicial conserva publicidad tras bajar a Básico';
  end if;
end $$;

rollback;
