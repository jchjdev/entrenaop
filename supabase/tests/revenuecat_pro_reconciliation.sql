-- Escritura de confianza, aislamiento de entorno, idempotencia y fuentes separadas.
begin;
do $$ declare u uuid:=gen_random_uuid(); o uuid:=gen_random_uuid(); begin
  insert into auth.users(id,email) values(u,'billing-fixture@example.invalid'),(o,'billing-other@example.invalid');
  perform set_config('test.billing_user',u::text,true);
  perform set_config('test.billing_other',o::text,true);
  perform set_config('request.jwt.claim.sub',u::text,true);
  if (select environment from public.revenuecat_access_settings where singleton) <> 'DISABLED' then
    raise exception 'La integración debe empezar deshabilitada';
  end if;
end $$;
set local role authenticated;
do $$ begin
  begin
    perform public.apply_revenuecat_pro_snapshot(auth.uid(),'SANDBOX',true,
      'entrenaop_pro_monthly','test_store',now()+interval '1 hour',now());
    raise exception 'Un usuario puede concederse una suscripción';
  exception when insufficient_privilege then null; end;
  begin
    update public.revenuecat_access_settings set environment='SANDBOX';
    raise exception 'Un usuario puede activar compras';
  exception when insufficient_privilege then null; end;
  begin
    perform public.claim_revenuecat_sync(auth.uid());
    raise exception 'Un usuario evita la verificación de servidor';
  exception when insufficient_privilege then null; end;
end $$;
reset role;
update public.revenuecat_access_settings set environment='SANDBOX';
set local role service_role;
do $$ declare u uuid:=current_setting('test.billing_user')::uuid;
  o uuid:=current_setting('test.billing_other')::uuid; result jsonb; observed timestamptz;
begin
  observed:=clock_timestamp();
  result:=public.apply_revenuecat_pro_snapshot(u,'SANDBOX',true,'entrenaop_pro_monthly',
    'test_store',observed+interval '1 hour',observed,'evt-1','INITIAL_PURCHASE');
  if result->>'tier'<>'pro' or result->>'source'<>'revenuecat' or
    result->>'billing_environment'<>'SANDBOX' then raise exception 'Compra no activa Pro: %',result; end if;
  -- El mismo evento para la misma cuenta no se vuelve a aplicar.
  result:=public.apply_revenuecat_pro_snapshot(u,'SANDBOX',false,null,null,null,
    clock_timestamp(),'evt-1','EXPIRATION');
  if result->>'tier'<>'pro' then raise exception 'Un evento repetido altera el acceso'; end if;
  result:=public.apply_revenuecat_pro_snapshot(u,'SANDBOX',false,null,null,null,
    observed-interval '1 second','evt-old','EXPIRATION');
  if result->>'tier'<>'pro' then raise exception 'Una respuesta antigua revoca una nueva'; end if;
  -- Una transferencia puede conciliar dos usuarios con el mismo identificador.
  result:=public.apply_revenuecat_pro_snapshot(o,'SANDBOX',true,'entrenaop_pro_annual',
    'test_store',clock_timestamp()+interval '1 hour',clock_timestamp(),'evt-1','TRANSFER');
  if result->>'tier'<>'pro' then raise exception 'La conciliación de otra cuenta queda bloqueada'; end if;
  begin
    perform public.apply_revenuecat_pro_snapshot(u,'PRODUCTION',true,'entrenaop_pro_monthly',
      'app_store',now()+interval '1 hour',clock_timestamp());
    raise exception 'Entornos distintos se mezclan';
  exception when insufficient_privilege then null; end;
  begin
    perform public.apply_revenuecat_pro_snapshot(u,'SANDBOX',true,'producto-inventado',
      'test_store',now()+interval '1 hour',clock_timestamp());
    raise exception 'Un producto no autorizado concede Pro';
  exception when invalid_parameter_value then null; end;
  result:=public.claim_revenuecat_sync(u);
  if (result->>'should_sync')::boolean is not true then raise exception 'Primera consulta rechazada'; end if;
  result:=public.claim_revenuecat_sync(u);
  if (result->>'should_sync')::boolean is not false or result->'access'->>'tier'<>'pro' then
    raise exception 'No se aplica el intervalo de conciliación'; end if;
end $$;
reset role;
set local role authenticated;
do $$ begin
  if (select count(*) from public.revenuecat_pro_state) <> 1 then raise exception 'RLS permite leer otra cuenta'; end if;
  if public.get_my_pro_access()->>'tier'<>'pro' then raise exception 'RPC del deportista no consulta compras'; end if;
end $$;
reset role;
do $$ declare u uuid:=current_setting('test.billing_user')::uuid; result jsonb; begin
  -- Cambiar el entorno no hace válidos los derechos de sandbox en producción.
  update public.revenuecat_access_settings set environment='PRODUCTION';
  if public.has_pro_access(u) then raise exception 'Sandbox habilita Pro en producción'; end if;
  update public.revenuecat_access_settings set environment='SANDBOX';
  insert into public.pro_access_grants(user_id,source,ends_at,reason)
    values(u,'development_manual',now()+interval '2 hours','Concesión de ensayo independiente');
  result:=public.apply_revenuecat_pro_snapshot(u,'SANDBOX',false,null,null,null,clock_timestamp());
  if result->>'tier'<>'pro' or result->>'source'<>'development_manual' then
    raise exception 'Caducar una compra retira la concesión manual'; end if;
  update public.pro_access_grants set revoked_at=clock_timestamp() where user_id=u;
  if public.has_pro_access(u) then raise exception 'Compra caducada conserva Pro'; end if;
  result:=public.apply_revenuecat_pro_snapshot(u,'SANDBOX',true,'entrenaop_pro_monthly','test_store',
    clock_timestamp()+interval '1 hour',clock_timestamp());
  if result->>'tier'<>'pro' then raise exception 'Restauración no recupera acceso'; end if;
  update public.pro_access_grants set revoked_at=clock_timestamp() where user_id=u;
  if not public.has_pro_access(u) then raise exception 'Retirar concesiones manuales cancela la compra'; end if;
end $$;
rollback;
