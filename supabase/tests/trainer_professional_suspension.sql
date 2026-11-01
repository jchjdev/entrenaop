-- Contrato de suspensión y concesiones independientes. No deja datos.
begin;
set local statement_timeout='30s';
do $$
declare manager uuid:=gen_random_uuid(); coach uuid:=gen_random_uuid(); pupil uuid:=gen_random_uuid();
 other uuid:=gen_random_uuid(); relation_id uuid; own_relation uuid; invite_id uuid:=gen_random_uuid();
 secret text:=encode(extensions.gen_random_bytes(32),'hex'); j jsonb; retry jsonb; revision bigint;
 offer uuid:='9d50b521-de26-48b0-8da7-d1fd3e85a660'; order_id uuid:=gen_random_uuid(); audits integer;
begin
 insert into auth.users(id,email,email_confirmed_at) values
 (manager,manager||'@suspension.invalid',now()),(coach,coach||'@suspension.invalid',now()),
 (pupil,pupil||'@suspension.invalid',now()),(other,other||'@suspension.invalid',now());
 insert into auth.mfa_factors(id,user_id,factor_type,status,created_at,updated_at)
 values(gen_random_uuid(),manager,'totp','verified',now(),now()),(gen_random_uuid(),coach,'totp','verified',now(),now());
 insert into public.admin_permissions(user_id) values(manager);
 insert into public.admin_security_requirements(user_id) values(manager);
 update public.commercial_access_settings set account_manager_user_id=manager where singleton;
 update public.trainer_access_settings set manual_access_enabled=true where singleton;
 insert into commerce_private.customers(owner_id) values(coach);
 insert into commerce_private.orders(id,owner_id,offer_id,state,paid_until,subscription_id)
 values(order_id,coach,offer,'active',now()+interval '30 days','sub_SuspensionFixture');
 perform commerce_private.refresh_access(coach);
 insert into public.trainer_client_relations(trainer_id,client_id) values(coach,pupil) returning id into relation_id;
 insert into public.trainer_client_relations(trainer_id,client_id) values(other,coach) returning id into own_relation;
 -- Regalar y retirar no revoca el pago ni copia sus cinco plazas al regalo.
 perform set_config('request.jwt.claim.sub',manager::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',manager,'role','authenticated','aal','aal2')::text,true);
 set local role authenticated;
 j:=public.get_trainer_management_status(coach);
 j:=public.admin_set_trainer_access(coach,8,true,(j->'access'->>'revision')::bigint,'Regalo de ensayo');
 j:=public.admin_set_trainer_access(coach,8,false,(j->>'revision')::bigint,'Retirar solo regalo');
 if (j->>'client_limit')::integer<>5 or not (j->>'effective')::boolean then raise exception 'Retirar regalo elimina pago';end if;
 revision:=(j->>'revision')::bigint;
 reset role;
 if (select manual_enabled from public.trainer_access where trainer_id=coach) then raise exception 'Regalo no retirado';end if;
 -- La operación administrativa requiere MFA, permiso de cuentas y motivo.
 perform set_config('request.jwt.claims',jsonb_build_object('sub',manager,'role','authenticated','aal','aal1')::text,true);
 set local role authenticated;
 begin perform public.admin_set_trainer_suspension(coach,true,revision,'Bloqueo');raise exception 'Suspende sin MFA';exception when insufficient_privilege then null;end;
 perform set_config('request.jwt.claim.sub',coach::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',coach,'role','authenticated','aal','aal2')::text,true);
 begin perform public.admin_set_trainer_suspension(coach,false,revision,'Auto permiso');raise exception 'Se auto reactiva';exception when insufficient_privilege then null;end;
 perform public.create_trainer_invitation(invite_id,secret);
 perform set_config('request.jwt.claim.sub',manager::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',manager,'role','authenticated','aal','aal2')::text,true);
 begin perform public.admin_set_trainer_suspension(coach,true,revision,' ');raise exception 'Acepta motivo vacío';exception when invalid_parameter_value then null;end;
 j:=public.admin_set_trainer_suspension(coach,true,revision,'Incumplimiento de normas');
 retry:=public.admin_set_trainer_suspension(coach,true,revision,'Incumplimiento de normas');
 if j<>retry or not (j->>'suspended')::boolean or (j->>'effective')::boolean then raise exception 'Suspensión o reintento incorrectos';end if;
 begin perform public.admin_set_trainer_suspension(coach,false,revision,'Revisión desfasada');raise exception 'Acepta revisión obsoleta';exception when serialization_failure then null;end;
 revision:=(j->>'revision')::bigint;
 reset role;
 select count(*) into audits from public.trainer_access_audit where trainer_id=coach;
 if audits<>3 then raise exception 'El reintento duplica auditoría';end if;
 -- Ni un regalo posterior ni la conciliación de otro periodo levantan el bloqueo.
 update commerce_private.orders set paid_until=now()+interval '60 days' where id=order_id;
 perform commerce_private.refresh_access(coach);
 if not exists(select 1 from public.trainer_access where trainer_id=coach and suspended and not enabled and not manual_enabled) then raise exception 'Renovación levanta bloqueo o modifica regalo';end if;
 perform set_config('request.jwt.claim.sub',coach::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',coach,'role','authenticated','aal','aal2')::text,true);
 set local role authenticated;
 if not public.get_trainer_security_status() or trainer_private.has_professional_session() then raise exception 'Confunde MFA con suspensión';end if;
 if not (public.get_trainer_access()->>'suspended')::boolean then raise exception 'Oculta estado al suspendido';end if;
 if not (public.get_my_trainer_account_status(coach)->>'suspended')::boolean
  or (public.get_my_trainer_account_status(coach)->>'enabled')::boolean then raise exception 'Entrada web no detecta suspensión';end if;
 if not (public.get_my_trainer_subscription(coach)->>'suspended')::boolean then raise exception 'Oculta bloqueo en facturación';end if;
 begin perform public.prepare_trainer_subscription(coach,offer);raise exception 'Puede comprar para eludir suspensión';exception when insufficient_privilege then null;end;
 begin perform public.save_trainer_workout(gen_random_uuid(),'{}');raise exception 'Puede escribir';exception when insufficient_privilege then null;end;
 begin perform public.list_trainer_clients();raise exception 'Consulta cartera';exception when insufficient_privilege then null;end;
 begin perform public.list_trainer_messages(relation_id);raise exception 'Consulta chat profesional';exception when insufficient_privilege then null;end;
 begin perform public.create_trainer_invitation(gen_random_uuid(),repeat('a',64));raise exception 'Invita suspendido';exception when insufficient_privilege then null;end;
 if exists(select 1 from public.trainer_client_relations where id=relation_id) then raise exception 'RLS abre datos de sus alumnos';end if;
 if not exists(select 1 from public.trainer_client_relations where id=own_relation) then raise exception 'Pierde su acceso de deportista';end if;
 j:=public.list_my_trainer_relations(false);
 if jsonb_array_length(j)<>1 then raise exception 'Se bloquea el preparador que lo entrena';end if;
 -- Los alumnos conservan su vínculo y su consulta; no se borran etapas.
 perform set_config('request.jwt.claim.sub',pupil::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',pupil,'role','authenticated','aal','aal1')::text,true);
 perform public.list_trainer_messages(relation_id);
 if not exists(select 1 from public.trainer_client_relations where id=relation_id and ended_at is null) then raise exception 'Borra vínculo';end if;
 reset role;
 -- Un regalo no reactiva; levantar la suspensión recalcula las fuentes vigentes.
 perform set_config('request.jwt.claim.sub',manager::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',manager,'role','authenticated','aal','aal2')::text,true);
 set local role authenticated;
 j:=public.admin_set_trainer_access(coach,8,true,revision,'Regalo sin reactivar');
 if (j->>'effective')::boolean or not (j->>'suspended')::boolean then raise exception 'Regalo levanta bloqueo';end if;
 j:=public.admin_set_trainer_suspension(coach,false,(j->>'revision')::bigint,'Revisión resuelta');
 if not (j->>'effective')::boolean or (j->>'suspended')::boolean or (j->>'client_limit')::integer<>8 then raise exception 'No restaura fuentes';end if;
 revision:=(j->>'revision')::bigint;
 -- Sin ninguna cobertura vigente, reactivar no regala ni prorroga el servicio.
 j:=public.admin_set_trainer_access(coach,8,false,revision,'Retirar último regalo');
 j:=public.admin_set_trainer_suspension(coach,true,(j->>'revision')::bigint,'Bloqueo de ensayo');
 reset role;
 update commerce_private.orders set paid_until=now()-interval '1 second',state='canceled' where id=order_id;
 perform commerce_private.refresh_access(coach);
 set local role authenticated;
 j:=public.admin_set_trainer_suspension(coach,false,(j->>'revision')::bigint,'Levantar sin cobertura');
 if (j->>'effective')::boolean then raise exception 'Reactivar regala cobertura';end if;
 reset role;
 if has_function_privilege('anon','public.admin_set_trainer_suspension(uuid,boolean,bigint,text)','execute')
 or has_table_privilege('authenticated','public.trainer_access','update') then raise exception 'Permisos abiertos';end if;
 if (select count(*) from public.trainer_client_relations where id in (relation_id,own_relation))<>2 then raise exception 'Historial alterado';end if;
end $$;
rollback;
