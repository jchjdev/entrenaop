-- Configuración operativa exclusiva de Dev, posterior a la migración de tickets.
-- Ejecutar con --linked --project-ref sxbxfjqgoddzhtcyhalw.
-- El comando no contiene secretos; pg_net recibe solo JWT público y ticket efímero.
begin;
do $$begin
 if not exists(select 1 from push_private.settings where singleton and enabled
   and firebase_project_id='entrenaop-dev') then
   raise exception 'Falta la activación de Firebase Dev.';
 end if;
 if not exists(select 1 from vault.secrets where name='student_push_dev_public_jwt') then
   raise exception 'Falta el JWT público del programador Dev.';
 end if;
end $$;
select cron.schedule('entrenaop-student-push-dev','* * * * *',
  'select push_private.dispatch_due_dev();');
select cron.alter_job(jobid,active:=true) from cron.job where jobname='entrenaop-student-push-dev';
commit;
