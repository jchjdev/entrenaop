begin;
do $$
begin
 if has_table_privilege('authenticated','device_private.training_sync_worker','SELECT')
  or has_table_privilege('authenticated','vault.decrypted_secrets','SELECT')
  or has_function_privilege('service_role','device_private.dispatch_training_sync_dev()','EXECUTE') then
  raise exception 'Cola o secreto del trabajador expuestos';end if;
 update device_private.training_sync_worker set enabled=false;
 if device_private.dispatch_training_sync_dev() is not null then raise exception 'Trabajador desactivado emite HTTP';end if;
 if coalesce((public.garmin_training_sync_command('authorize','{"token":"fixture"}')->>'authorized')::boolean,true) then
  raise exception 'Bearer falso autorizado';end if;
 insert into device_private.training_sync_worker(singleton,enabled,token_hash,ticket_expires_at,ticket_used)
 values(true,true,encode(sha256(convert_to('fixture','UTF8')),'hex'),now()+interval '1 minute',false)
 on conflict(singleton) do update set enabled=true,token_hash=excluded.token_hash,ticket_expires_at=excluded.ticket_expires_at,ticket_used=false;
 if not (public.garmin_training_sync_command('authorize','{"token":"fixture"}')->>'authorized')::boolean then raise exception 'Ticket válido rechazado';end if;
 if (public.garmin_training_sync_command('authorize','{"token":"fixture"}')->>'authorized')::boolean then raise exception 'Ticket reutilizado';end if;
 update device_private.training_sync_worker set ticket_used=false,ticket_expires_at=now()-interval '1 minute';
 if (public.garmin_training_sync_command('authorize','{"token":"fixture"}')->>'authorized')::boolean then raise exception 'Ticket caducado';end if;
end $$;
select 'dispatch permissions passed' as result;
rollback;
