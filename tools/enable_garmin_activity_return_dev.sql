-- Aplicar solo tras validar receptor y migraciones de sxbxfjqgoddzhtcyhalw.
begin;
update device_private.activity_return_worker set enabled=true,ticket_used=true;
select cron.schedule('garmin-activity-return-dev','* * * * *','select device_private.dispatch_activity_return_dev();') as job_id;
select device_private.dispatch_activity_return_dev() as request_id;
commit;
