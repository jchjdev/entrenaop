-- Usuarios y concesiones sintéticos: toda la prueba termina en ROLLBACK.
begin;
set local statement_timeout='30s';
do $$
declare
  manager uuid:=gen_random_uuid(); editor uuid:=gen_random_uuid();
  a uuid:=gen_random_uuid(); b uuid:=gen_random_uuid(); x uuid:=gen_random_uuid();
  y uuid:=gen_random_uuid(); z uuid:=gen_random_uuid(); outsider uuid:=gen_random_uuid();
  first_invite uuid:=gen_random_uuid(); second_invite uuid:=gen_random_uuid();
  b_invite uuid:=gen_random_uuid(); canceled uuid:=gen_random_uuid();
  secret1 text:=encode(extensions.gen_random_bytes(32),'hex');
  secret2 text:=encode(extensions.gen_random_bytes(32),'hex');
  secret3 text:=encode(extensions.gen_random_bytes(32),'hex');
  secret4 text:=encode(extensions.gen_random_bytes(32),'hex');
  relation1 uuid; relation2 uuid; relation3 uuid; snapshot jsonb; preview jsonb; retry jsonb;
  own_exercise uuid; payload jsonb; quota_detail text;
begin
  -- El piloto real puede estar habilitado: el caso de denegación fija su propio
  -- estado dentro de esta transacción y ROLLBACK conserva la configuración real.
  update public.trainer_access_settings set manual_access_enabled=false where singleton;
  insert into auth.users(id,email) values
    (manager,manager||'@trainer-contract.invalid'),(editor,editor||'@trainer-contract.invalid'),
    (a,a||'@trainer-contract.invalid'),(b,b||'@trainer-contract.invalid'),
    (x,x||'@trainer-contract.invalid'),(y,y||'@trainer-contract.invalid'),
    (z,z||'@trainer-contract.invalid'),(outsider,outsider||'@trainer-contract.invalid');
  insert into auth.mfa_factors(id,user_id,factor_type,status,created_at,updated_at) values
    (gen_random_uuid(),a,'totp','verified',now(),now()),
    (gen_random_uuid(),b,'totp','verified',now(),now());
  insert into public.admin_permissions(user_id) values(manager),(editor);
  update public.commercial_access_settings set account_manager_user_id=manager where singleton;
  update public.profiles set full_name='Preparador de prueba' where id=a;

  if has_function_privilege('anon','public.accept_trainer_invitation(text)','execute')
    or has_schema_privilege('anon','trainer_private','usage')
    or has_table_privilege('anon','public.trainer_client_relations','select') then
    raise exception 'Permisos anónimos abiertos.';
  end if;
  if exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public' and p.proname in
      ('get_trainer_access','admin_set_trainer_access','create_trainer_invitation',
       'preview_trainer_invitation','accept_trainer_invitation','cancel_trainer_invitation','end_trainer_relation')
      and p.prosecdef) then raise exception 'RPC privilegiada en el esquema expuesto.'; end if;

  reset role;
  perform set_config('request.jwt.claim.sub',manager::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',manager,'role','authenticated','aal','aal1')::text,true);
  set local role authenticated;

  begin perform public.admin_set_trainer_access(a,1,true,0,'Piloto manual'); raise exception 'La configuración deshabilitada permite conceder acceso';
    exception when insufficient_privilege then null; end;

  reset role;
  update public.trainer_access_settings set manual_access_enabled=true where singleton;
  insert into public.admin_security_requirements(user_id) values(manager);
  reset role;
  perform set_config('request.jwt.claim.sub',manager::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',manager,'role','authenticated','aal','aal1')::text,true);
  set local role authenticated;

  begin perform public.admin_set_trainer_access(a,1,true,0,'Piloto manual'); raise exception 'Se elude el requisito MFA administrativo';
    exception when insufficient_privilege then null; end;

  reset role;
  delete from public.admin_security_requirements where user_id=manager;
  reset role;
  perform set_config('request.jwt.claim.sub',manager::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',manager,'role','authenticated','aal','aal1')::text,true);
  set local role authenticated;

  snapshot:=public.admin_set_trainer_access(a,1,true,0,'Piloto manual');
  retry:=public.admin_set_trainer_access(a,1,true,0,'Piloto manual');
  if snapshot<>retry or (snapshot->>'revision')::integer<>1 then raise exception 'El reintento duplica la concesión.'; end if;
  if (select count(*) from public.trainer_access_audit where trainer_id=a)<>1 then raise exception 'Auditoría duplicada.'; end if;
  perform public.admin_set_trainer_access(b,2,true,0,'Segundo preparador');
  begin perform public.admin_set_trainer_access(a,3,true,9,'Revisión obsoleta'); raise exception 'Se acepta una revisión de acceso obsoleta';
    exception when serialization_failure then null; end;

  begin perform public.admin_set_trainer_access(a,0,true,1,'Cupo inválido'); raise exception 'Se acepta un cupo inválido';
    exception when sqlstate '22023' then null; end;


  reset role;
  perform set_config('request.jwt.claim.sub',editor::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',editor,'role','authenticated','aal','aal1')::text,true);
  set local role authenticated;

  begin perform public.admin_set_trainer_access(a,99,true,1,'Solo editor'); raise exception 'Un editor administra el acceso profesional';
    exception when insufficient_privilege then null; end;

  reset role;
  perform set_config('request.jwt.claim.sub',a::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',a,'role','authenticated','aal','aal2')::text,true);
  set local role authenticated;

  begin perform public.admin_set_trainer_access(a,99,true,1,'Autoconcesión'); raise exception 'El preparador se concede capacidad';
    exception when insufficient_privilege then null; end;

  begin update public.trainer_access set client_limit=99 where trainer_id=a; raise exception 'Permite aumentar cupo directamente';
    exception when insufficient_privilege then null; end;

  begin insert into public.trainer_access(trainer_id,enabled,client_limit,last_reason) values(x,true,10,'Directo'); raise exception 'Permite crear acceso directamente';
    exception when insufficient_privilege then null; end;

  if not (public.get_trainer_access()->>'effective')::boolean then raise exception 'No reconoce el acceso propio.'; end if;
  begin perform public.get_trainer_access(b); raise exception 'Consulta acceso comercial ajeno';
    exception when insufficient_privilege then null; end;

  if exists(select 1 from public.trainer_access where trainer_id=b)
    or exists(select 1 from public.trainer_access_audit) then raise exception 'Filtra configuración o auditoría.'; end if;
  snapshot:=public.create_trainer_invitation(first_invite,secret1);
  retry:=public.create_trainer_invitation(first_invite,secret1);
  if snapshot<>retry then raise exception 'El reintento altera la invitación.'; end if;
  perform public.create_trainer_invitation(second_invite,secret2);
  if (public.get_trainer_access()->>'active_clients')::integer<>0 then raise exception 'Las invitaciones ocupan plaza.'; end if;
  begin perform secret_hash from public.trainer_invitations where id=first_invite; raise exception 'Expone hashes en la lectura del preparador';
    exception when insufficient_privilege then null; end;

  if exists(select 1 from public.profiles where id=x) then raise exception 'El preparador ve un perfil ajeno sin vínculo.'; end if;
  begin perform public.accept_trainer_invitation(secret1); raise exception 'Permite ser el propio cliente';
    exception when sqlstate '22023' then null; end;


  reset role;
  perform set_config('request.jwt.claim.sub',b::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',b,'role','authenticated','aal','aal2')::text,true);
  set local role authenticated;

  if exists(select 1 from public.trainer_invitations where id=first_invite) then raise exception 'Filtra invitaciones entre preparadores.'; end if;
  begin perform public.cancel_trainer_invitation(first_invite); raise exception 'Cancela invitación ajena';
    exception when insufficient_privilege then null; end;

  begin perform public.create_trainer_invitation(first_invite,secret1); raise exception 'Reutiliza identidad de una invitación ajena';
    exception when insufficient_privilege then null; end;

  perform public.create_trainer_invitation(b_invite,secret3);
  perform public.create_trainer_invitation(canceled,secret4);
  perform public.cancel_trainer_invitation(canceled);
  perform public.cancel_trainer_invitation(canceled);

  reset role;
  perform set_config('request.jwt.claim.sub',x::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',x,'role','authenticated','aal','aal1')::text,true);
  set local role authenticated;

  preview:=public.preview_trainer_invitation(secret1);
  if preview->>'trainer_name'<>'Preparador de prueba'
    or exists(select 1 from public.trainer_client_relations where client_id=x) then
    raise exception 'La vista previa acepta o identifica mal al preparador.'; end if;
  begin perform public.accept_trainer_invitation(secret4); raise exception 'Se acepta una invitación cancelada';
    exception when sqlstate '22023' then null; end;

  relation1:=public.accept_trainer_invitation(secret1);
  if public.accept_trainer_invitation(secret1)<>relation1 then raise exception 'El reintento crea otro vínculo.'; end if;
  -- El acceso del entrenador no transforma en ilimitada la creación del alumno.
  snapshot:=public.get_my_pro_access();
  if snapshot->>'tier'<>'free' or (snapshot->>'exercise_limit')::integer<>8
    or (snapshot->>'session_limit')::integer<>4 then raise exception 'El vínculo modifica las cuotas personales.'; end if;
  for i in 1..8 loop
    own_exercise:=public.create_personal_exercise('Ejercicio propio '||i,null,null,array['core'],'{}','inicial','repeticiones');
  end loop;
  begin
    perform public.create_personal_exercise('Noveno ejercicio vinculado',null,null,array['core'],'{}','inicial','repeticiones');
    raise exception 'La vinculación permite un noveno ejercicio propio.';
  exception when raise_exception then
    get stacked diagnostics quota_detail=pg_exception_detail;
    if quota_detail is distinct from 'free_exercise_limit' then raise; end if;
  end;
  payload:=jsonb_build_object('name','Sesión propia vinculada','blocks',jsonb_build_array(jsonb_build_object(
    'name','Principal','format','straight_sets','rounds',1,'rest_after_seconds',0,
    'exercises',jsonb_build_array(jsonb_build_object('exercise_id',own_exercise,
    'sets',jsonb_build_array(jsonb_build_object('target_reps',8,'rest_after_seconds',60)))))));
  for i in 1..4 loop perform public.create_personal_workout_template(payload); end loop;
  begin
    perform public.create_personal_workout_template(payload);
    raise exception 'La vinculación permite una quinta sesión propia.';
  exception when raise_exception then
    get stacked diagnostics quota_detail=pg_exception_detail;
    if quota_detail is distinct from 'free_session_limit' then raise; end if;
  end;
  begin perform public.accept_trainer_invitation(secret3); raise exception 'Un alumno tiene dos preparadores activos';
    exception when unique_violation then null; end;

  begin update public.trainer_client_relations set trainer_id=b where id=relation1; raise exception 'El alumno cambia el preparador sin aceptación';
    exception when insufficient_privilege then null; end;

  begin insert into public.trainer_client_relations(trainer_id,client_id) values(b,x); raise exception 'Crea un vínculo por escritura directa';
    exception when insufficient_privilege then null; end;

  if (select count(*) from public.trainer_client_relations where id=relation1)<>1 then raise exception 'El alumno no puede consultar su vínculo.'; end if;

  reset role;
  perform set_config('request.jwt.claim.sub',y::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',y,'role','authenticated','aal','aal1')::text,true);
  set local role authenticated;

  begin perform public.accept_trainer_invitation(secret1); raise exception 'Otro alumno reutiliza una invitación consumida';
    exception when sqlstate '22023' then null; end;

  begin perform public.accept_trainer_invitation(secret2); raise exception 'Se excede la última plaza';
    exception when check_violation then null; end;

  begin perform public.end_trainer_relation(relation1); raise exception 'Un tercero termina el vínculo';
    exception when insufficient_privilege then null; end;

  if exists(select 1 from public.trainer_client_relations where id=relation1) then raise exception 'Otro alumno lee el vínculo.'; end if;

  reset role;
  perform set_config('request.jwt.claim.sub',a::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',a,'role','authenticated','aal','aal2')::text,true);
  set local role authenticated;

  if (public.get_trainer_access()->>'active_clients')::integer<>1 then raise exception 'El cupo no refleja la aceptación.'; end if;
  if (select accepted_at from public.trainer_invitations where id=second_invite) is not null then raise exception 'El rechazo consume la invitación.'; end if;
  begin perform public.cancel_trainer_invitation(first_invite); raise exception 'Cancelar invitación termina un vínculo aceptado';
    exception when sqlstate '22023' then null; end;

  reset role;
  -- La restricción independiente de la RPC protege también la integridad.
  begin insert into public.trainer_client_relations(trainer_id,client_id) values(b,x); raise exception 'Falta la restricción de preparador único';
    exception when unique_violation then null; end;

  if public.has_pro_access(x) then raise exception 'El vínculo concede Pro al alumno.'; end if;
  reset role;
  perform set_config('request.jwt.claim.sub',manager::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',manager,'role','authenticated','aal','aal1')::text,true);
  set local role authenticated;

  if exists(select 1 from public.trainer_client_relations where id=relation1) then raise exception 'Gestionar cuentas revela relaciones privadas.'; end if;
  begin perform public.end_trainer_relation(relation1); raise exception 'El gestor termina relaciones ajenas';
    exception when insufficient_privilege then null; end;

  if (public.get_trainer_access(a)->>'active_clients')::integer<>1 then raise exception 'La gestión no puede consultar el cupo comercial.'; end if;

  reset role;
  perform set_config('request.jwt.claim.sub',x::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',x,'role','authenticated','aal','aal1')::text,true);
  set local role authenticated;

  perform public.end_trainer_relation(relation1);
  perform public.end_trainer_relation(relation1);
  begin perform public.accept_trainer_invitation(secret1); raise exception 'Un reintento resucita el vínculo finalizado';
    exception when sqlstate '22023' then null; end;

  reset role;
  perform set_config('request.jwt.claim.sub',y::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',y,'role','authenticated','aal','aal1')::text,true);
  set local role authenticated;

  relation2:=public.accept_trainer_invitation(secret2);
  if relation2=relation1 then raise exception 'Se reescribe el vínculo histórico.'; end if;
  reset role;
  perform set_config('request.jwt.claim.sub',a::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',a,'role','authenticated','aal','aal2')::text,true);
  set local role authenticated;

  perform public.end_trainer_relation(relation2);
  if (public.get_trainer_access()->>'active_clients')::integer<>0 then raise exception 'Terminar no libera plaza.'; end if;
  if (select count(*) from public.trainer_client_relations where trainer_id=a)<>2 then raise exception 'Se pierde historial de vínculos.'; end if;
  reset role;
  perform set_config('request.jwt.claim.sub',x::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',x,'role','authenticated','aal','aal1')::text,true);
  set local role authenticated;

  relation3:=public.accept_trainer_invitation(secret3);

  reset role;
  perform set_config('request.jwt.claim.sub',b::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',b,'role','authenticated','aal','aal2')::text,true);
  set local role authenticated;

  -- Recupera otra invitación válida sin alterar la ya cancelada.
  canceled:=gen_random_uuid();
  secret4:=encode(extensions.gen_random_bytes(32),'hex');
  perform public.create_trainer_invitation(canceled,secret4);
  reset role;
  perform set_config('request.jwt.claim.sub',y::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',y,'role','authenticated','aal','aal1')::text,true);
  set local role authenticated;

  relation2:=public.accept_trainer_invitation(secret4);
  reset role;
  perform set_config('request.jwt.claim.sub',manager::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',manager,'role','authenticated','aal','aal1')::text,true);
  set local role authenticated;

  begin perform public.admin_set_trainer_access(b,1,true,1,'Reducción con exceso'); raise exception 'Reduce cupo desactivando alumnos sin regla acordada';
    exception when check_violation then null; end;

  snapshot:=public.admin_set_trainer_access(b,2,false,1,'Acceso retirado');
  if (snapshot->>'active_clients')::integer<>2 or (snapshot->>'effective')::boolean then
    raise exception 'Deshabilitar borra vínculos o mantiene acceso efectivo.'; end if;
  reset role;
  perform set_config('request.jwt.claim.sub',b::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',b,'role','authenticated','aal','aal2')::text,true);
  set local role authenticated;

  begin perform public.create_trainer_invitation(gen_random_uuid(),secret2); raise exception 'Un acceso retirado crea invitaciones';
    exception when insufficient_privilege then null; end;

  reset role;
  perform set_config('request.jwt.claim.sub',x::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',x,'role','authenticated','aal','aal1')::text,true);
  set local role authenticated;

  if public.accept_trainer_invitation(secret3)<>relation3 then raise exception 'El reintento no reconoce la aceptación previa.'; end if;
  perform public.end_trainer_relation(relation3);
  reset role;
  perform set_config('request.jwt.claim.sub',manager::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',manager,'role','authenticated','aal','aal1')::text,true);
  set local role authenticated;

  perform public.admin_set_trainer_access(b,2,true,2,'Restaurar piloto');
  reset role;
  -- La RPC evalúa vigencia al inicio de la sentencia; el fixture usa ese mismo
  -- reloj aunque se ejecute dentro de una tanda transaccional larga.
  update public.trainer_access set valid_until=statement_timestamp()-interval '1 second' where trainer_id=b;
  reset role;
  perform set_config('request.jwt.claim.sub',b::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',b,'role','authenticated','aal','aal2')::text,true);
  set local role authenticated;

  if (public.get_trainer_access()->>'effective')::boolean then raise exception 'La vigencia caducada sigue activa.'; end if;
  begin perform public.create_trainer_invitation(gen_random_uuid(),secret2); raise exception 'Un acceso caducado crea invitaciones';
    exception when insufficient_privilege then null; end;

  perform public.end_trainer_relation(relation2);

  reset role;
  perform set_config('request.jwt.claim.sub',a::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',a,'role','authenticated','aal','aal2')::text,true);
  set local role authenticated;

  begin
    perform public.create_trainer_invitation(gen_random_uuid(),secret1||'00');
    raise exception 'No valida la longitud del secreto.';
  exception when sqlstate '22023' then null; end;
  canceled:=gen_random_uuid();
  secret4:=encode(extensions.gen_random_bytes(32),'hex');
  perform public.create_trainer_invitation(canceled,secret4);
  reset role;
  update public.trainer_invitations set created_at=clock_timestamp()-interval '2 days',
    expires_at=clock_timestamp()-interval '1 day' where id=canceled;
  perform set_config('request.jwt.claim.sub',z::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',z,'role','authenticated')::text,true);
  set local role authenticated;
  begin perform public.preview_trainer_invitation(secret4); raise exception 'Muestra invitación caducada.';
    exception when sqlstate '22023' then null; end;
  begin perform public.accept_trainer_invitation(secret4); raise exception 'Acepta invitación caducada.';
    exception when sqlstate '22023' then null; end;
  perform set_config('request.jwt.claims',jsonb_build_object('sub',z,'role','authenticated',
    'user_metadata',jsonb_build_object('role','admin'))::text,true);
  begin perform public.admin_set_trainer_access(z,100,true,0,'Metadata propia'); raise exception 'Autoriza metadata editable.';
    exception when insufficient_privilege then null; end;
  perform set_config('request.jwt.claims',jsonb_build_object('sub',z,'role','authenticated','is_anonymous',true)::text,true);
  begin perform public.preview_trainer_invitation(secret4); raise exception 'Usuario anónimo usa invitaciones.';
    exception when insufficient_privilege then null; end;
  reset role;
  set local role anon;
  begin perform public.get_trainer_access(); raise exception 'La API permite acceso sin sesión.';
    exception when insufficient_privilege then null; end;
end $$;

-- Nunca se altera el historial ni se dejan usuarios, invitaciones o concesiones de prueba.
select 'trainer_access_and_relations: OK' as result;
rollback;
