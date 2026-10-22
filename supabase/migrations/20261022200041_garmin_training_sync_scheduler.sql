begin;
create extension if not exists pg_cron;
create extension if not exists pg_net;

-- Sin trabajo programado ni secreto por defecto. La activación operacional se
-- ejecuta aparte, con el proyecto Dev explícito y después de desplegar Edge.
create function device_private.dispatch_training_sync_dev() returns bigint
language plpgsql security definer set search_path='' as $$
declare token text;
begin
 if not exists(select 1 from device_private.training_sync_worker where enabled) then return null;end if;
 select decrypted_secret into token from vault.decrypted_secrets where name='garmin_training_sync_dev_bearer';
 if token is null then return null;end if;
 return net.http_post(url:='https://sxbxfjqgoddzhtcyhalw.supabase.co/functions/v1/garmin-training-sync',
  headers:=jsonb_build_object('Content-Type','application/json','Authorization','Bearer '||token),
  body:='{}'::jsonb,timeout_milliseconds:=55000);
end $$;
revoke all on function device_private.dispatch_training_sync_dev() from public,anon,authenticated,service_role;
commit;
