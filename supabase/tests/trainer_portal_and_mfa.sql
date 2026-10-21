-- Contrato de resúmenes, directorio, MFA y convivencia de permisos. Sin datos persistentes.
begin;
set local statement_timeout='30s';
do $$
declare
  manager uuid:=gen_random_uuid(); trainer uuid:=gen_random_uuid();
  pupil uuid:=gen_random_uuid(); outsider uuid:=gen_random_uuid();
  invite uuid:=gen_random_uuid(); secret text:=repeat('a',64);
  relation uuid; j jsonb; internal_function record;
begin
  -- Fija el estado del caso dentro de la prueba; ROLLBACK conserva el piloto real.
  update public.trainer_access_settings set manual_access_enabled=false where singleton;
  for internal_function in
    select p.oid from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='trainer_private' and p.proname like '%\_without\_mfa'
  loop
    if has_function_privilege('authenticated',internal_function.oid,'execute')
      or has_function_privilege('anon',internal_function.oid,'execute') then
      raise exception 'Una implementación interna conserva ejecución de cliente';
    end if;
  end loop;
  insert into auth.users(id,email) values
    (manager,manager||'@trainer-portal.invalid'),(trainer,trainer||'@trainer-portal.invalid'),
    (pupil,pupil||'@trainer-portal.invalid'),(outsider,outsider||'@trainer-portal.invalid');
  update public.profiles set full_name='Preparador visible' where id=trainer;
  update public.profiles set full_name='Alumno visible' where id=pupil;
  insert into public.admin_permissions(user_id) values(manager);
  update public.commercial_access_settings set account_manager_user_id=manager where singleton;
  insert into auth.mfa_factors(id,user_id,factor_type,status,created_at,updated_at) values
    (gen_random_uuid(),manager,'totp','verified',now(),now()),
    (gen_random_uuid(),trainer,'totp','verified',now(),now());
  insert into public.trainer_access(trainer_id,enabled,client_limit,last_reason)
    values(trainer,true,3,'Fixture profesional'),(manager,true,2,'Fixture multidimensión');
  perform set_config('request.jwt.claim.sub',trainer::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',trainer,'role','authenticated','aal','aal1')::text,true);
  set local role authenticated;
  if public.get_trainer_security_status() then raise exception 'AAL1 se considera asegurado'; end if;
  if exists(select 1 from public.trainer_access) then raise exception 'AAL1 lee acceso profesional'; end if;
  begin perform public.get_trainer_access(); raise exception 'AAL1 consulta acceso por RPC';
    exception when insufficient_privilege then null; end;
  begin perform public.list_my_trainer_relations(true); raise exception 'AAL1 lista clientes';
    exception when insufficient_privilege then null; end;
  begin perform public.create_trainer_invitation(invite,secret); raise exception 'AAL1 crea invitación';
    exception when insufficient_privilege then null; end;
  begin perform trainer_private.create_trainer_invitation_without_mfa(invite,secret); raise exception 'Se elude el adaptador MFA';
    exception when insufficient_privilege then null; end;
  perform set_config('request.jwt.claims',jsonb_build_object('sub',trainer,'role','authenticated','aal','aal2')::text,true);
  if not public.get_trainer_security_status() then raise exception 'No reconoce TOTP verificado'; end if;
  perform public.create_trainer_invitation(invite,secret);
  begin perform public.get_trainer_management_status(trainer); raise exception 'Preparador accede a gestión comercial';
    exception when insufficient_privilege then null; end;
  begin perform public.list_managed_trainers(); raise exception 'Preparador lee directorio comercial';
    exception when insufficient_privilege then null; end;
  reset role;
  perform set_config('request.jwt.claim.sub',pupil::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',pupil,'role','authenticated','aal','aal1')::text,true);
  set local role authenticated;
  -- El alumno conserva su autenticación normal; MFA no condiciona aceptar.
  relation:=public.accept_trainer_invitation(secret);
  j:=public.list_my_trainer_relations(false);
  if jsonb_array_length(j)<>1 or j->0->>'person_name'<>'Preparador visible'
    or (j->0->>'person_id')::uuid<>trainer or j->0 ? 'email' then raise exception 'Resumen de preparador incorrecto'; end if;
  if jsonb_array_length(public.list_my_trainer_relations(false,true))<>0 then raise exception 'Mezcla estados'; end if;
  begin perform public.list_my_trainer_relations(false,false,now(),null); raise exception 'Admite cursor parcial';
    exception when sqlstate '22023' then null; end;
  -- Una declaración AAL2 sin factor verificado no sirve.
  perform set_config('request.jwt.claims',jsonb_build_object('sub',pupil,'role','authenticated','aal','aal2')::text,true);
  if public.get_trainer_security_status() then raise exception 'AAL2 sin factor válido'; end if;
  reset role;
  perform set_config('request.jwt.claim.sub',trainer::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',trainer,'role','authenticated','aal','aal2')::text,true);
  set local role authenticated;
  j:=public.list_my_trainer_relations(true);
  if jsonb_array_length(j)<>1 or j->0->>'person_name'<>'Alumno visible' then raise exception 'Resumen de alumno incorrecto'; end if;
  if jsonb_array_length(public.list_my_trainer_relations(true,false,(j->0->>'accepted_at')::timestamptz,(j->0->>'id')::uuid))<>0
    then raise exception 'Cursor repite el último elemento'; end if;
  if exists(select 1 from public.profiles where id=pupil) then raise exception 'Amplía RLS de perfiles'; end if;
  perform set_config('request.jwt.claims',jsonb_build_object('sub',trainer,'role','authenticated','aal','aal1')::text,true);
  if exists(select 1 from public.trainer_client_relations) or exists(select 1 from public.trainer_invitations)
    then raise exception 'Se leen datos profesionales sin MFA'; end if;
  begin perform public.cancel_trainer_invitation(invite); raise exception 'AAL1 cancela invitación';
    exception when insufficient_privilege then null; end;
  begin perform public.end_trainer_relation(relation); raise exception 'AAL1 finaliza como profesional';
    exception when insufficient_privilege then null; end;
  reset role;
  perform set_config('request.jwt.claim.sub',outsider::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',outsider,'role','authenticated','aal','aal1')::text,true);
  set local role authenticated;
  if jsonb_array_length(public.list_my_trainer_relations(false))<>0 then raise exception 'Filtra vínculo ajeno'; end if;
  begin perform public.end_trainer_relation(relation); raise exception 'Tercero termina vínculo';
    exception when insufficient_privilege then null; end;
  reset role;
  perform set_config('request.jwt.claim.sub',manager::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',manager,'role','authenticated','aal','aal2')::text,true);
  set local role authenticated;
  j:=public.list_managed_trainers();
  if not exists(select 1 from jsonb_array_elements(j) t where (t->>'trainer_id')::uuid=trainer) then raise exception 'Falta entrenador en directorio'; end if;
  j:=public.get_trainer_management_status(trainer);
  if (j->>'manual_access_enabled')::boolean then raise exception 'Se habilita el piloto'; end if;
  if jsonb_array_length(public.list_my_trainer_relations(true))<>0 then raise exception 'Admin obtiene alumnos privados de otro preparador'; end if;
  -- La misma identidad administradora invita y es entrenada por otra persona.
  perform public.create_trainer_invitation(gen_random_uuid(),repeat('b',64));
  reset role;
  perform set_config('request.jwt.claim.sub',trainer::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',trainer,'role','authenticated','aal','aal2')::text,true);
  set local role authenticated;
  perform public.create_trainer_invitation(gen_random_uuid(),repeat('c',64));
  reset role;
  perform set_config('request.jwt.claim.sub',manager::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',manager,'role','authenticated','aal','aal2')::text,true);
  set local role authenticated;
  perform public.accept_trainer_invitation(repeat('c',64));
  if not public.is_admin() or not (public.get_trainer_access()->>'effective')::boolean
    or jsonb_array_length(public.list_my_trainer_relations(false))<>1 then raise exception 'Las dimensiones se excluyen'; end if;
  reset role;
  perform set_config('request.jwt.claim.sub',pupil::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',pupil,'role','authenticated','aal','aal1')::text,true);
  set local role authenticated;
  perform public.end_trainer_relation(relation);
  if jsonb_array_length(public.list_my_trainer_relations(false,true))<>1 then raise exception 'Pierde el cierre en histórico'; end if;
  reset role;
  set local role anon;
  begin perform public.list_my_trainer_relations(false); raise exception 'Anon consulta resumen';
    exception when insufficient_privilege then null; end;
end $$;
select 'trainer_portal_and_mfa: OK' as result;
rollback;
