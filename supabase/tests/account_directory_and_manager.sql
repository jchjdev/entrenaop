-- La enumeración y las concesiones se reservan al responsable, incluso frente a otro admin.
begin;
do $$
declare manager uuid:=gen_random_uuid(); editor uuid:=gen_random_uuid(); u uuid; i integer;
begin
  insert into auth.users(id,email) values(manager,'directory-manager-fixture@example.invalid'),
    (editor,'directory-editor-fixture@example.invalid');
  insert into public.admin_permissions(user_id,reason) values(manager,'Responsable del ensayo'),(editor,'Solo contenido');
  update public.commercial_access_settings set account_manager_user_id=manager,
    gift_management_enabled=true,development_manual_access_enabled=true;
  update public.revenuecat_access_settings set environment='SANDBOX';
  perform set_config('test.directory_manager',manager::text,true);
  perform set_config('test.directory_editor',editor::text,true);
  for i in 1..5 loop
    u:=gen_random_uuid();
    insert into auth.users(id,email,raw_user_meta_data) values(u,'directory-user-fixture-'||i||'@example.invalid','{"private":"no incluir en listado"}');
    if i in (2,4) then insert into public.pro_gift_grants(user_id,granted_by,reason) values(u,manager,'Regalo de ensayo'); end if;
    if i=5 then insert into public.pro_gift_grants(user_id,starts_at,ends_at,reason)
      values(u,now()-interval '2 days',now()-interval '1 day','Caducado'); end if;
    if i in (3,4) then insert into public.revenuecat_pro_state(user_id,environment,active,product_identifier,store,valid_until,observed_at)
      values(u,'SANDBOX',true,'entrenaop_pro_monthly','test_store',now()+interval '1 day',now()); end if;
    if i=1 then perform set_config('test.directory_free',u::text,true); end if;
  end loop;
  perform set_config('request.jwt.claim.sub',editor::text,true);
end $$;
set local role anon;
do $$ begin
  begin perform public.admin_list_pro_accounts(); raise exception 'Anon enumera cuentas';
  exception when insufficient_privilege then null; end;
end $$;
reset role;
set local role authenticated;
do $$ begin
  if not public.is_admin() or public.can_manage_pro_accounts() then raise exception 'Se mezclan contenido y cuentas'; end if;
  begin perform public.admin_list_pro_accounts(); raise exception 'Editor enumera cuentas'; exception when insufficient_privilege then null; end;
  begin perform public.admin_find_pro_account('directory-user-fixture-1@example.invalid'); raise exception 'Editor consulta ficha'; exception when insufficient_privilege then null; end;
  begin perform public.admin_set_free_pro_access(current_setting('test.directory_free')::uuid,true,null,'Autoasignación'); raise exception 'Editor concede regalo'; exception when insufficient_privilege then null; end;
  begin perform public.admin_find_development_account('directory-user-fixture-1@example.invalid'); raise exception 'Elusión por consulta antigua'; exception when insufficient_privilege then null; end;
  begin perform public.admin_set_development_pro_access(current_setting('test.directory_free')::uuid,true,30,'Autoasignación'); raise exception 'Elusión por regalo antiguo'; exception when insufficient_privilege then null; end;
  begin update public.commercial_access_settings set account_manager_user_id=auth.uid(); raise exception 'Editor se convierte en responsable'; exception when insufficient_privilege then null; end;
  perform set_config('request.jwt.claim.sub',current_setting('test.directory_free'),true);
  if public.can_manage_pro_accounts() then raise exception 'Deportista responsable'; end if;
  begin perform public.admin_list_pro_accounts(); raise exception 'Deportista enumera cuentas'; exception when insufficient_privilege then null; end;
  perform set_config('request.jwt.claim.sub',current_setting('test.directory_manager'),true);
end $$;
do $$
declare page jsonb; item jsonb; cursor uuid; ids uuid[]:='{}'; total integer:=0; loops integer:=0; expected integer; until_access jsonb;
begin
  if not public.can_manage_pro_accounts() then raise exception 'Responsable rechazado'; end if;
  loop
    page:=public.admin_list_pro_accounts('directory-user-fixture-',cursor,2);
    if jsonb_array_length(page->'accounts')>2 then raise exception 'Página ilimitada'; end if;
    for item in select value from jsonb_array_elements(page->'accounts') loop
      if (item->>'user_id')::uuid=any(ids) then raise exception 'Cursor duplica cuentas'; end if;
      ids:=array_append(ids,(item->>'user_id')::uuid); total:=total+1;
      if (select count(*) from jsonb_object_keys(item))<>6 then raise exception 'Se exponen datos innecesarios'; end if;
      expected:=split_part(split_part(item->>'email','@',1),'-',4)::integer;
      if (item->>'tier'='pro')<>(expected in (2,3,4))
        or (item->>'free_pro_active')::boolean<>(expected in (2,4))
        or (item->>'subscription_active')::boolean<>(expected in (3,4)) then raise exception 'Resumen de fuentes incorrecto: %',item; end if;
    end loop;
    loops:=loops+1; cursor:=(page->>'next_cursor')::uuid;
    exit when cursor is null;
    if loops>3 then raise exception 'Paginación no termina'; end if;
  end loop;
  if total<>5 or loops<>3 then raise exception 'Paginación incompleta'; end if;
  page:=public.admin_list_pro_accounts(' USER-FIXTURE-2@ ',null,25);
  if jsonb_array_length(page->'accounts')<>1 then raise exception 'Búsqueda parcial/caso/espacios incorrecta'; end if;
  if jsonb_array_length(public.admin_list_pro_accounts('%',null,25)->'accounts')<>0 then raise exception 'Búsqueda trata texto como wildcard'; end if;
  if jsonb_array_length(public.admin_list_pro_accounts('directory-user-fixture-',ids[5],25)->'accounts')<>0 then raise exception 'Fin de lista incorrecto'; end if;
  begin perform public.admin_list_pro_accounts('',null,51); raise exception 'Límite excesivo'; exception when invalid_parameter_value then null; end;
  begin perform public.admin_list_pro_accounts(null,null,25); raise exception 'Búsqueda nula'; exception when invalid_parameter_value then null; end;
  until_access:=public.admin_set_free_pro_access(current_setting('test.directory_free')::uuid,true,null,'Responsable concede');
  if until_access->>'tier'<>'pro' then raise exception 'Responsable no concede'; end if;
end $$;
reset role;
update public.commercial_access_settings set account_manager_user_id=null;
set local role authenticated;
do $$ begin
  if public.can_manage_pro_accounts() then raise exception 'Sin responsable asignado se permite gestionar'; end if;
  begin perform public.admin_list_pro_accounts(); raise exception 'Configuración sin responsable abierta'; exception when insufficient_privilege then null; end;
end $$;
select 'Directorio, permiso exclusivo, fuentes y paginación: OK' as result;
rollback;
