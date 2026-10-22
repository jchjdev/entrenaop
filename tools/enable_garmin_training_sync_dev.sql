-- Solo --linked --project-ref sxbxfjqgoddzhtcyhalw. No crea permisos de cuentas.
-- Cada tick genera un ticket efímero; ningún secreto se devuelve o copia.
begin;
insert into device_private.training_sync_worker(singleton,enabled,token_hash,ticket_used)
 values(true,true,encode(sha256(extensions.gen_random_bytes(32)),'hex'),true)
 on conflict(singleton) do update set enabled=true,ticket_used=true;
select cron.schedule('garmin-training-sync-dev','* * * * *','select device_private.dispatch_training_sync_dev();') as job_id;
select device_private.dispatch_training_sync_dev() as request_id;
commit;
