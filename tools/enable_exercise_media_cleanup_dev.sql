-- Solo --linked --project-ref sxbxfjqgoddzhtcyhalw, después de desplegar
-- exercise-video y trainer-media-cleanup y verificar los contratos con ROLLBACK.
-- No barre bibliotecas: procesa únicamente solicitudes ya encoladas.
begin;
do $$
begin
 if not exists(select 1 from vault.decrypted_secrets where name='student_push_dev_public_jwt' and decrypted_secret is not null) then
  raise exception 'Falta la configuración pública del despachador Dev';
 end if;
 if to_regprocedure('public.claim_exercise_media_cleanup(integer,uuid,uuid,text)') is null then
  raise exception 'Falta aplicar la migración de limpieza protegida';
 end if;
end $$;
update trainer_private.media_cleanup_settings set enabled=true where singleton;
select cron.schedule('exercise-media-cleanup-dev','* * * * *',
 'select trainer_private.dispatch_media_cleanup_dev();') as job_id;
select trainer_private.dispatch_media_cleanup_dev() as request_id;
commit;
