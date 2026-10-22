-- Datos exclusivamente sintéticos. Admite esquema Dev real o fixture local.
begin;
select set_config('test.garmin_a',gen_random_uuid()::text,true);
select set_config('test.garmin_b',gen_random_uuid()::text,true);
select set_config('test.garmin_t',gen_random_uuid()::text,true);
select set_config('test.garmin_s',gen_random_uuid()::text,true);
select set_config('test.garmin_sa',gen_random_uuid()::text,true);
select set_config('test.garmin_sb',gen_random_uuid()::text,true);
insert into auth.users(id,email) select current_setting(k)::uuid,current_setting(k)||'@garmin.invalid'
 from unnest(array['test.garmin_a','test.garmin_b','test.garmin_t','test.garmin_s']) k;
insert into auth.sessions(id,user_id) values
 (current_setting('test.garmin_sa')::uuid,current_setting('test.garmin_a')::uuid),
 (current_setting('test.garmin_sb')::uuid,current_setting('test.garmin_b')::uuid);
insert into public.pro_gift_grants(user_id,reason)
 values(current_setting('test.garmin_b')::uuid,'Fixture Garmin con ROLLBACK');
insert into public.trainer_access(trainer_id,enabled,client_limit,last_reason)
 values(current_setting('test.garmin_t')::uuid,true,5,'Fixture Garmin con ROLLBACK');
insert into public.trainer_client_relations(trainer_id,client_id)
 values(current_setting('test.garmin_t')::uuid,current_setting('test.garmin_s')::uuid);

do $$
declare a uuid:=current_setting('test.garmin_a')::uuid; b uuid:=current_setting('test.garmin_b')::uuid;
 sa uuid:=current_setting('test.garmin_sa')::uuid; sb uuid:=current_setting('test.garmin_sb')::uuid;
 t uuid:=current_setting('test.garmin_t')::uuid; s uuid:=current_setting('test.garmin_s')::uuid;
 claim uuid:=gen_random_uuid(); lease uuid:=gen_random_uuid(); old_lease uuid; r jsonb; generation bigint; secret jsonb;
begin
 if device_private.garmin_access(a) or not device_private.garmin_access(b)
  or not device_private.garmin_access(s) then raise exception 'Acceso comercial incorrecto'; end if;
 update public.trainer_access set enabled=false where trainer_id=t;
 if device_private.garmin_access(s) then raise exception 'Acepta entrenador sin acceso'; end if;
 update public.trainer_access set enabled=true where trainer_id=t;
 update public.trainer_client_relations set ended_at=clock_timestamp() where client_id=s;
 if device_private.garmin_access(s) then raise exception 'Acepta vínculo terminado'; end if;

 if has_function_privilege('authenticated','public.garmin_account_command(text,uuid,uuid,jsonb)','EXECUTE') or
  has_function_privilege('anon','device_private.garmin_account_command(text,uuid,uuid,jsonb)','EXECUTE') or
  has_table_privilege('service_role','device_private.garmin_connections','SELECT') or
  not has_function_privilege('service_role','public.garmin_account_command(text,uuid,uuid,jsonb)','EXECUTE') then
  raise exception 'Privilegios incorrectos'; end if;
 if not (select relrowsecurity from pg_class where oid='device_private.garmin_connections'::regclass) then raise exception 'Falta RLS'; end if;
 begin
  perform public.garmin_account_command('begin',a,sa,jsonb_build_object('state_hash',repeat('a',64),'verifier_cipher','fixture'));
  raise exception 'Free puede iniciar Garmin';
 exception when insufficient_privilege then if sqlerrm<>'access_required' then raise; end if; end;
 begin
  perform public.garmin_account_command('status',b,sa,'{}');
  raise exception 'Acepta sesión de otra cuenta';
 exception when insufficient_privilege then if sqlerrm<>'account_changed' then raise; end if; end;

 r:=public.garmin_account_command('begin',b,sb,jsonb_build_object('state_hash',repeat('b',64),'verifier_cipher','cipher-fixture'));
 generation:=(r->>'generation')::bigint;
 if r->>'status'<>'authorizing' or r ? 'verifier_cipher' or r ? 'attempt_hash' or r ? 'tokens_cipher' then raise exception 'Filtra secretos'; end if;
 begin
  perform public.garmin_account_command('begin',b,sb,jsonb_build_object('state_hash',repeat('c',64),'verifier_cipher','fixture'));
  raise exception 'No aplica límite de intentos';
 exception when program_limit_exceeded then null; end;
 r:=public.garmin_account_command('claim',null,null,jsonb_build_object('state_hash',repeat('b',64),'claim_id',claim));
 if r->>'verifier_cipher'<>'cipher-fixture' or r->>'owner_id'<>b::text then raise exception 'No resuelve intento'; end if;
 begin
  perform public.garmin_account_command('claim',null,null,jsonb_build_object('state_hash',repeat('b',64),'claim_id',gen_random_uuid()));
  raise exception 'Replay permitido';
 exception when insufficient_privilege then null; end;

 secret:=jsonb_build_object('generation',generation,'claim_id',claim,'tokens_cipher','tokens-cipher-fixture',
  'access_expires_at',clock_timestamp()+interval '1 hour','refresh_expires_at',clock_timestamp()+interval '1 day',
  'garmin_user_id','fixture-'||b,'can_read',true,'can_send',false);
 perform public.garmin_account_command('stash_grant',b,null,secret);
 r:=public.garmin_account_command('complete',b,null,secret);
 if r->>'status'<>'connected' or r->>'can_send'<>'false' or r ? 'tokens_cipher' or r ? 'garmin_user_id' then raise exception 'Conexión o permisos incorrectos'; end if;
 -- La baja comercial impide conectar, pero nunca impide desconectar.
 update public.pro_gift_grants set ends_at=clock_timestamp()-interval '1 second',starts_at=clock_timestamp()-interval '1 day' where user_id=b;
 r:=public.garmin_account_command('disconnect',b,sb,jsonb_build_object('generation',generation));
 if r->>'status'<>'disconnecting' or r->>'allowed'<>'false' or r->>'can_read'<>'false' then raise exception 'No detiene conector'; end if;
 begin
  perform public.garmin_account_command('complete',b,null,secret);
  raise exception 'Callback vuelve a conectar';
 exception when serialization_failure then null; end;
 r:=public.garmin_account_command('claim_revoke',b,null,jsonb_build_object('lease_id',lease));
 if r->>'tokens_cipher'<>'tokens-cipher-fixture' then raise exception 'No entrega tokens al worker'; end if;
 if public.garmin_account_command('claim_revoke',b,null,jsonb_build_object('lease_id',gen_random_uuid()))->>'pending'<>'true' then raise exception 'Dos workers revocan'; end if;
 begin
  perform public.garmin_account_command('finish_revoke',b,null,jsonb_build_object('generation',generation,'lease_id',gen_random_uuid()));
  raise exception 'Worker ajeno confirma';
 exception when serialization_failure then null; end;
 perform public.garmin_account_command('rotate_revoke',b,null,secret||jsonb_build_object('lease_id',lease,'tokens_cipher','rotated-fixture'));
 perform public.garmin_account_command('fail_revoke',b,null,jsonb_build_object('generation',generation,'lease_id',lease));
 if (public.garmin_account_command('status',b,sb,'{}')->>'status')<>'revocation_pending' then raise exception 'Finge revocación confirmada'; end if;
 lease:=gen_random_uuid();
 perform public.garmin_account_command('claim_revoke',b,null,jsonb_build_object('lease_id',lease));
 old_lease:=lease;
 update device_private.garmin_connections set disconnect_lease_until=clock_timestamp()-interval '1 second' where owner_id=b;
 lease:=gen_random_uuid();
 perform public.garmin_account_command('claim_revoke',b,null,jsonb_build_object('lease_id',lease));
 begin
  perform public.garmin_account_command('finish_revoke',b,null,jsonb_build_object('generation',generation,'lease_id',old_lease));
  raise exception 'Worker vencido confirma';
 exception when serialization_failure then null; end;
 r:=public.garmin_account_command('finish_revoke',b,null,jsonb_build_object('generation',generation,'lease_id',lease));
 if r->>'status'<>'disconnected' or exists(select 1 from device_private.garmin_connections where owner_id=b and
  (tokens_cipher is not null or garmin_user_id is not null or claim_id is not null)) then raise exception 'No limpia secretos'; end if;

 update public.pro_gift_grants set ends_at=null where user_id=b;
 update device_private.garmin_connections set updated_at=clock_timestamp()-interval '1 minute' where owner_id=b;
 r:=public.garmin_account_command('begin',b,sb,jsonb_build_object('state_hash',repeat('c',64),'verifier_cipher','fixture'));
 if (r->>'generation')::bigint<>generation+1 then raise exception 'Reutiliza generación'; end if;
 -- Cancelar antes del canje invalida el callback sin llamar al proveedor.
 r:=public.garmin_account_command('disconnect',b,sb,jsonb_build_object('generation',generation+1));
 if r->>'status'<>'disconnected' then raise exception 'No cancela intento sin grant'; end if;
 begin
  perform public.garmin_account_command('claim',null,null,jsonb_build_object('state_hash',repeat('c',64),'claim_id',gen_random_uuid()));
  raise exception 'Autoriza callback cancelado';
 exception when insufficient_privilege then null; end;

 update device_private.garmin_connections set updated_at=clock_timestamp()-interval '1 minute' where owner_id=b;
 perform public.garmin_account_command('begin',b,sb,jsonb_build_object('state_hash',repeat('d',64),'verifier_cipher','fixture'));
 update device_private.garmin_connections set attempt_deadline=clock_timestamp()-interval '1 second' where owner_id=b;
 begin
  perform public.garmin_account_command('claim',null,null,jsonb_build_object('state_hash',repeat('d',64),'claim_id',gen_random_uuid()));
  raise exception 'Acepta intento caducado';
 exception when insufficient_privilege then null; end;
 update device_private.garmin_connections set attempt_deadline=clock_timestamp()+interval '1 minute' where owner_id=b;
 delete from auth.sessions where id=sb;
 begin
  perform public.garmin_account_command('claim',null,null,jsonb_build_object('state_hash',repeat('d',64),'claim_id',gen_random_uuid()));
  raise exception 'Acepta sesión cerrada';
 exception when insufficient_privilege then null; end;
 delete from auth.users where id=b;
 if exists(select 1 from device_private.garmin_connections where owner_id=b) then raise exception 'Secretos sobreviven al borrado'; end if;
end $$;
rollback;
