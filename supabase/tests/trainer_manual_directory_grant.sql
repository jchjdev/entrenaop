-- Acceso regalado y ficha opcional: permiso explícito, compatible y auditable.
begin;
set local statement_timeout='30s';
do $$
declare
  manager uuid:=gen_random_uuid(); coach uuid:=gen_random_uuid(); other uuid:=gen_random_uuid();
  until_at timestamptz:=now()+interval '30 days'; j jsonb; retry jsonb;
  revision bigint; audit_count integer; profile_id uuid; profile_revision integer;
  data jsonb; paid_offer uuid; paid_order uuid;
begin
  insert into auth.users(id,email,email_confirmed_at) values
    (manager,manager||'@manual-directory.invalid',now()),
    (coach,coach||'@manual-directory.invalid',now()),
    (other,other||'@manual-directory.invalid',now());
  insert into auth.mfa_factors(id,user_id,factor_type,status,created_at,updated_at)
    values(gen_random_uuid(),manager,'totp','verified',now(),now()),
      (gen_random_uuid(),coach,'totp','verified',now(),now());
  insert into public.admin_permissions(user_id) values(manager);
  insert into public.admin_security_requirements(user_id) values(manager);
  update public.commercial_access_settings set account_manager_user_id=manager where singleton;
  update public.trainer_access_settings set manual_access_enabled=true where singleton;
  update directory_private.settings set enabled=true;

  -- El propio entrenador, aun con doble factor, no puede concederse el regalo.
  perform set_config('request.jwt.claim.sub',coach::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',coach,'role','authenticated','aal','aal2')::text,true);
  set local role authenticated;
  begin
    perform public.admin_set_trainer_access_with_directory(coach,5,true,0,'Intento no autorizado',until_at,true);
    raise exception 'El entrenador se concede publicidad';
  exception when insufficient_privilege then null;end;
  reset role;
  perform set_config('request.jwt.claim.sub',manager::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',manager,'role','authenticated','aal','aal1')::text,true);
  set local role authenticated;
  begin
    perform public.admin_set_trainer_access_with_directory(coach,5,true,0,'Falta doble factor',until_at,true);
    raise exception 'ADMIN sin MFA concede publicidad';
  exception when insufficient_privilege then null;end;
  perform set_config('request.jwt.claims',jsonb_build_object('sub',manager,'role','authenticated','aal','aal2',
    'iss','https://sxbxfjqgoddzhtcyhalw.supabase.co/auth/v1')::text,true);

  j:=public.admin_set_trainer_access_with_directory(coach,5,true,0,'Solo las herramientas',until_at,false);
  revision:=(j->>'revision')::bigint;
  j:=public.get_trainer_management_status(coach);
  if (j->>'manual_directory_enabled')::boolean or j->>'directory_source' is not null then
    raise exception 'Regalar herramientas añade ficha sin elegirla';end if;
  j:=public.admin_set_trainer_access_with_directory(coach,5,true,revision,'Incluir ficha en la app',until_at,true);
  retry:=public.admin_set_trainer_access_with_directory(coach,5,true,revision,'Incluir ficha en la app',until_at,true);
  if retry<>j then raise exception 'El reintento altera el resultado';end if;
  begin
    perform public.admin_set_trainer_access_with_directory(coach,5,true,revision,'Incluir ficha en la app',until_at,false);
    raise exception 'Misma revisión admite otra elección de ficha';
  exception when serialization_failure then null;end;
  revision:=(j->>'revision')::bigint;
  reset role;
  select count(*) into audit_count from public.trainer_access_audit where trainer_id=coach;
  if audit_count<>2 or not exists(select 1 from public.trainer_access_audit a
    where a.trainer_id=coach and a.revision=(j->>'revision')::bigint and a.new_access->>'manual_directory_enabled'='true') then
    raise exception 'Falta la elección en auditoría o se duplica el reintento';end if;
  if not directory_private.manual_eligible(coach) then raise exception 'No activa la ficha regalada';end if;

  -- Una petición del ADMIN anterior conserva el permiso elegido explícitamente.
  set local role authenticated;
  j:=public.admin_set_trainer_access(coach,5,true,revision,'Conservar regalo con cliente anterior',until_at);
  revision:=(j->>'revision')::bigint;
  j:=public.get_trainer_management_status(coach);
  if j->>'directory_source'<>'manual' or not (j->>'manual_directory_enabled')::boolean then
    raise exception 'El cliente anterior pierde la ficha elegida';end if;
  reset role;

  insert into storage.objects(bucket_id,name)
    values('trainer-directory',coach||'/11111111-1111-4111-8111-111111111111.jpg');
  data:=jsonb_build_object('name','Preparador del contrato','description','Seguimiento de fuerza y carrera',
    'specialties',jsonb_build_array('Carrera'),'services',jsonb_build_array('Seguimiento'),
    'mode','online','city','','visibility','app',
    'photo_path',coach||'/11111111-1111-4111-8111-111111111111.jpg',
    'email','coach@manual-directory.invalid','website','','whatsapp','','price','','accepting',true,'consent_version',2);
  perform set_config('request.jwt.claim.sub',coach::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',coach,'role','authenticated','aal','aal2')::text,true);
  set local role authenticated;
  j:=public.directory_own(coach);
  if not (j->>'eligible')::boolean or (j->>'published')::boolean or (j->>'web_allowed')::boolean then
    raise exception 'El regalo publica automáticamente o permite publicidad web';end if;
  begin
    perform public.directory_save(coach,0,data,true,false);
    raise exception 'El regalo omite el consentimiento';
  exception when insufficient_privilege then null;end;
  j:=public.directory_save(coach,0,data,true,true);
  profile_id:=(j->'profile'->>'id')::uuid;profile_revision:=(j->>'revision')::integer;
  begin
    perform public.directory_save(coach,profile_revision,data||'{"visibility":"web"}'::jsonb,true,true);
    raise exception 'El regalo de ficha en app publica en web';
  exception when insufficient_privilege then null;end;
  reset role;

  -- La misma fuente caduca y se somete a la suspensión administrativa.
  update public.trainer_access set manual_valid_until=now()-interval '1 second' where trainer_id=coach;
  if directory_private.eligible(coach) then raise exception 'La ficha sobrevive al regalo vencido';end if;
  update public.trainer_access set manual_valid_until=until_at where trainer_id=coach;
  update public.trainer_access set suspended=true,suspended_at=clock_timestamp(),
    suspension_reason='Suspensión transaccional del preparador' where trainer_id=coach;
  if directory_private.eligible(coach) then raise exception 'El regalo ignora la suspensión';end if;
  update public.trainer_access set suspended=false,suspended_at=null,suspension_reason=null where trainer_id=coach;
  if not directory_private.eligible(coach) then raise exception 'La reactivación pierde el regalo vigente';end if;
  update public.trainer_access_settings set manual_access_enabled=false where singleton;
  if directory_private.manual_eligible(coach) then raise exception 'La fuente manual deshabilitada concede ficha';end if;
  update public.trainer_access_settings set manual_access_enabled=true where singleton;

  perform set_config('request.jwt.claim.sub',manager::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',manager,'role','authenticated','aal','aal2',
    'iss','https://sxbxfjqgoddzhtcyhalw.supabase.co/auth/v1')::text,true);
  select a.revision into revision from public.trainer_access a where trainer_id=coach;
  set local role authenticated;
  j:=public.admin_set_trainer_access_with_directory(coach,5,true,revision,'Retirar solo la ficha del regalo',until_at,false);
  if not (j->>'effective')::boolean then raise exception 'Retirar ficha elimina las herramientas';end if;
  reset role;
  if directory_private.eligible(coach) or not exists(select 1 from directory_private.profiles
    where id=profile_id and published) then raise exception 'No retira elegibilidad o borra la ficha guardada';end if;

  -- La compra pagada y el piloto conservan sus permisos independientes.
  select id into paid_offer from commerce_private.offers
    where active and plan_key='professional' and capacity=5 limit 1;
  insert into commerce_private.customers(owner_id) values(coach);
  insert into commerce_private.orders(owner_id,offer_id,state,paid_until)
    values(coach,paid_offer,'active',until_at) returning id into paid_order;
  perform commerce_private.refresh_access(coach);
  select a.revision into revision from public.trainer_access a where trainer_id=coach;
  set local role authenticated;
  j:=public.admin_set_trainer_access_with_directory(coach,5,false,revision,'Retirar regalo conservando pago',until_at,false);
  if not (j->>'effective')::boolean then raise exception 'Retirar regalo elimina el acceso pagado';end if;
  j:=public.get_trainer_management_status(coach);
  if j->>'directory_source'<>'paid' then raise exception 'Retirar regalo elimina la ficha pagada';end if;
  j:=public.admin_set_trainer_access(other,5,true,0,'Herramientas del piloto',until_at);
  reset role;
  insert into directory_private.dev_pilot_members(trainer_id,source_order_id,valid_until,reason)
    values(other,paid_order,until_at,'Permiso independiente del piloto de pruebas');
  set local role authenticated;
  j:=public.get_trainer_management_status(other);
  if j->>'directory_source'<>'pilot' or (j->>'manual_directory_enabled')::boolean then
    raise exception 'El piloto se elimina o se transforma en regalo de ficha';end if;
  reset role;
end $$;
rollback;
