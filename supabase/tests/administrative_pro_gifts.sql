-- Permisos reales, regalos, fuentes simultáneas y auditoría, sin datos permanentes.
begin;
do $$
declare u uuid := gen_random_uuid(); a uuid := gen_random_uuid(); other_user uuid := gen_random_uuid();
begin
  insert into auth.users(id,email) values(u,'gift-fixture@example.invalid'),
    (a,'gift-admin-fixture@example.invalid'),(other_user,'gift-other-fixture@example.invalid');
  insert into public.admin_permissions(user_id,reason) values(a,'Administrador del ensayo de regalos');
  perform set_config('test.gift_user',u::text,true);
  perform set_config('test.gift_admin',a::text,true);
  perform set_config('test.gift_other',other_user::text,true);
  update public.commercial_access_settings set gift_management_enabled=false;
  update public.revenuecat_access_settings set environment='SANDBOX';
  perform set_config('request.jwt.claim.sub',u::text,true);
end $$;
set local role authenticated;
do $$
begin
  begin
    perform public.admin_find_pro_account('gift-fixture@example.invalid');
    raise exception 'Un deportista consulta cuentas administrativas';
  exception when insufficient_privilege then null; end;
  begin
    perform public.admin_set_free_pro_access(auth.uid(),true,null,'Autoasignación');
    raise exception 'Un deportista se concede un regalo';
  exception when insufficient_privilege then null; end;
  begin
    insert into public.pro_gift_grants(user_id,reason) values(auth.uid(),'Autoasignación');
    raise exception 'Escritura directa de un regalo';
  exception when insufficient_privilege then null; end;
  begin
    perform public.admin_pro_account_snapshot(auth.uid());
    raise exception 'Acceso directo al helper administrativo';
  exception when insufficient_privilege then null; end;
end $$;
reset role;
select set_config('request.jwt.claim.sub',current_setting('test.gift_admin'),true);
set local role authenticated;
do $$
declare s jsonb;
begin
  s:=public.admin_find_pro_account('GIFT-FIXTURE@example.invalid');
  if s->>'tier' <> 'free' or (s->>'gift_management_enabled')::boolean then
    raise exception 'Ficha inicial incorrecta'; end if;
  begin
    perform public.admin_set_free_pro_access(current_setting('test.gift_user')::uuid,true,null,'Familia');
    raise exception 'Se escribe con gestión deshabilitada';
  exception when insufficient_privilege then null; end;
end $$;
reset role;
update public.commercial_access_settings set gift_management_enabled=true;
set local role authenticated;
do $$
declare s jsonb; u uuid:=current_setting('test.gift_user')::uuid;
begin
  s:=public.admin_set_free_pro_access(u,true,null,'Familia sin vencimiento');
  if s->>'tier' <> 'pro' or s->>'source' <> 'administrative_gift'
    or s->>'valid_until' is not null or not (s->>'free_pro_active')::boolean
    or s->>'exercise_limit' is not null then raise exception 'Regalo indefinido incorrecto'; end if;
end $$;
reset role;
select set_config('request.jwt.claim.sub',current_setting('test.gift_user'),true);
-- El guard interno no es un RPC público; se ejecuta desde código de confianza.
do $$ begin perform public.require_pro_access(); end $$;
set local role authenticated;
do $$
declare s jsonb; u uuid:=current_setting('test.gift_user')::uuid;
begin
  s:=public.get_my_pro_access();
  if s->>'tier' <> 'pro' or s->>'valid_until' is not null then raise exception 'Deportista no lee regalo'; end if;
  perform set_config('request.jwt.claim.sub',current_setting('test.gift_other'),true);
  if public.get_my_pro_access()->>'tier' <> 'free' then raise exception 'Regalo filtrado a otra cuenta'; end if;
  perform set_config('request.jwt.claim.sub',current_setting('test.gift_admin'),true);
  s:=public.admin_set_free_pro_access(u,true,statement_timestamp()+interval '7 days','Beta temporal');
  if s->>'valid_until' is null then raise exception 'Regalo temporal incorrecto'; end if;
  begin
    perform public.admin_set_free_pro_access(u,true,statement_timestamp()-interval '1 day','Fecha pasada');
    raise exception 'Se concede un regalo vencido';
  exception when invalid_parameter_value then null; end;
  begin
    perform public.admin_set_free_pro_access(u,false,null,'x');
    raise exception 'Revocación sin motivo';
  exception when invalid_parameter_value then null; end;
  s:=public.admin_set_free_pro_access(u,false,null,'Retirada de beta');
  if s->>'tier' <> 'free' or (s->>'free_pro_active')::boolean then raise exception 'No retira regalo'; end if;
end $$;
reset role;
do $$
declare u uuid:=current_setting('test.gift_user')::uuid;
begin
  if (select count(*) from public.pro_gift_grants where user_id=u and revoked_at is not null
    and granted_by=current_setting('test.gift_admin')::uuid
    and revoked_by=current_setting('test.gift_admin')::uuid and revocation_reason is not null) <> 2
    then raise exception 'Auditoría incompleta'; end if;
  insert into public.pro_access_grants(user_id,source,ends_at,reason)
    values(u,'development_manual',now()+interval '30 days','Prueba anterior');
  insert into public.revenuecat_pro_state(user_id,environment,active,product_identifier,store,valid_until,observed_at)
    values(u,'SANDBOX',true,'entrenaop_pro_monthly','test_store',now()+interval '10 days',now());
end $$;
set local role authenticated;
do $$
declare s jsonb; u uuid:=current_setting('test.gift_user')::uuid;
begin
  s:=public.admin_set_free_pro_access(u,true,null,'Regalo con compra simultánea');
  if not (s->>'subscription_active')::boolean or not (s->>'free_pro_active')::boolean then
    raise exception 'La ficha oculta una fuente activa'; end if;
  s:=public.admin_set_free_pro_access(u,false,null,'Retirada sin cancelar compra');
  if s->>'tier' <> 'pro' or s->>'source' <> 'revenuecat' or (s->>'free_pro_active')::boolean
    then raise exception 'Retirar regalo cancela compra u omite el acceso Dev'; end if;
end $$;
reset role;
do $$
declare u uuid:=current_setting('test.gift_user')::uuid; s jsonb;
begin
  perform public.admin_set_free_pro_access(u,true,null,'Regalo que sobrevive a la caducidad de una compra');
  s:=public.apply_revenuecat_pro_snapshot(u,'SANDBOX',false,null,null,null,
    statement_timestamp()+interval '1 second');
  if s->>'tier' <> 'pro' or s->>'source' <> 'administrative_gift' then
    raise exception 'Caducar una compra elimina el regalo'; end if;
  perform public.admin_set_free_pro_access(u,false,null,'Retirada del regalo de ensayo');
  insert into public.pro_gift_grants(user_id,starts_at,ends_at,reason)
    values(u,now()-interval '2 days',now()-interval '1 day','Regalo ya caducado');
  if public.has_pro_access(u) then raise exception 'Regalo caducado concede acceso'; end if;
  if not exists(select 1 from public.revenuecat_pro_state where user_id=u) then
    raise exception 'Se borra el historial de compras'; end if;
end $$;
select 'Regalos, permisos, vigencia, fuentes y auditoría: OK' as result;
rollback;
