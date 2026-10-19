begin;
do $$
declare admin_id uuid:=gen_random_uuid(); athlete uuid:=gen_random_uuid(); factor uuid:=gen_random_uuid();
  work uuid:=gen_random_uuid(); status jsonb;
begin
  insert into auth.users(id,email) values(admin_id,admin_id||'@mfa-test.invalid'),(athlete,athlete||'@mfa-test.invalid');
  insert into public.admin_permissions(user_id,reason) values(admin_id,'Fixture MFA transaccional');
  if has_function_privilege('anon','public.get_admin_security_status()','execute')
    or has_function_privilege('anon','public.enable_admin_mfa_requirement()','execute') then
    raise exception 'RPC de seguridad accesible anónimamente.';
  end if;
  perform set_config('request.jwt.claim.sub',admin_id::text,true);
  perform set_config('request.jwt.claims','{"aal":"aal1"}',true);
  set local role authenticated;
  status:=public.get_admin_security_status();
  if not(status->>'eligible')::boolean or (status->>'mfa_required')::boolean then raise exception 'Estado inicial incorrecto.'; end if;
  begin perform public.enable_admin_mfa_requirement(); raise exception 'Activa MFA sin verificar factor.';
    exception when insufficient_privilege then null; end;
  begin insert into public.admin_security_requirements(user_id) values(admin_id); raise exception 'Cliente cambia su requisito.';
    exception when insufficient_privilege then null; end;
  perform set_config('request.jwt.claims','{"aal":"aal2"}',true);
  begin perform public.enable_admin_mfa_requirement(); raise exception 'Activa protección sin factor verificado.';
    exception when insufficient_privilege then null; end;
  reset role;
  -- Datos sintéticos locales a la transacción; nunca se consulta un secreto real.
  insert into auth.mfa_factors(id,user_id,friendly_name,factor_type,status,secret,created_at,updated_at)
    values(factor,admin_id,'Fixture sin autenticador real','totp','verified','fixture-only-not-a-real-secret',now(),now());
  set local role authenticated;
  perform public.enable_admin_mfa_requirement();
  perform public.enable_admin_mfa_requirement();
  if public.is_admin() is distinct from true then raise exception 'Rechaza sesión admin con MFA.'; end if;
  perform public.save_admin_guided_work(work,0,'{"schema":1,"name":"Trabajo privado MFA"}');
  perform set_config('request.jwt.claims','{"aal":"aal1","user_metadata":{"role":"admin","mfa_required":false}}',true);
  if public.is_admin() is distinct from false then raise exception 'AAL1 conserva autoridad administrativa.'; end if;
  if public.can_manage_pro_accounts() is distinct from false then raise exception 'Cuentas no exige MFA.'; end if;
  if exists(select 1 from public.admin_guided_work_drafts where id=work) then raise exception 'RLS permite leer trabajo con AAL1.'; end if;
  begin perform public.save_admin_guided_work(work,1,'{"schema":1,"name":"Intruso"}'); raise exception 'RPC permite escribir con AAL1.';
    exception when insufficient_privilege then null; end;
  begin perform public.reset_adaptive_program_trial(gen_random_uuid(),'REINICIAR'); raise exception 'Reinicio elude MFA.';
    exception when insufficient_privilege then null; end;
  perform set_config('request.jwt.claims','{}',true);
  if public.is_admin() is distinct from false then raise exception 'Una claim ausente devuelve NULL o permite acceso.'; end if;
  begin perform public.save_admin_guided_work(work,1,'{"schema":1}'); raise exception 'RPC acepta AAL ausente.';
    exception when insufficient_privilege then null; end;
  perform set_config('request.jwt.claims','{"aal":"aal2"}',true);
  if not exists(select 1 from public.admin_guided_work_drafts where id=work) then raise exception 'No recupera acceso verificado.'; end if;
  begin select to_jsonb(r) into status from public.admin_security_requirements r; raise exception 'Cliente lee requisitos internos.';
    exception when insufficient_privilege then null; end;
  reset role;
  update auth.mfa_factors set status='unverified' where id=factor;
  set local role authenticated;
  if public.is_admin() is distinct from false then raise exception 'AAL2 antiguo sigue válido sin factor verificado.'; end if;
  status:=public.get_admin_security_status();
  if not(status->>'mfa_required')::boolean or (status->>'assured')::boolean then raise exception 'Retirar factor debilita el requisito.'; end if;
  perform set_config('request.jwt.claim.sub',athlete::text,true);
  if (public.get_admin_security_status()->>'eligible')::boolean or public.is_admin() then raise exception 'Concede admin a deportista.'; end if;
  begin perform public.enable_admin_mfa_requirement(); raise exception 'Deportista se concede acceso.';
    exception when insufficient_privilege then null; end;
end $$;
rollback;
