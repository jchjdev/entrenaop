-- Prueba repetible con cron activo: no cambia enabled ni confirma borrados.
begin;
set local statement_timeout='45s';
do $$
declare actor uuid:=gen_random_uuid();sid uuid:=gen_random_uuid();image_a uuid:=gen_random_uuid();image_b uuid:=gen_random_uuid();swap uuid;
 path_a text;path_b text;draft jsonb;operation_a uuid:=gen_random_uuid();first jsonb;second jsonb;third jsonb;fourth jsonb;job_a uuid;job_b uuid;
begin
 if image_a::text>image_b::text then swap:=image_a;image_a:=image_b;image_b:=swap;end if;
 insert into auth.users(id,email) values(actor,actor||'@media-sweep-progress.invalid');
 insert into auth.mfa_factors(id,user_id,factor_type,status,created_at,updated_at) values(gen_random_uuid(),actor,'totp','verified',now(),now());
 insert into auth.sessions(id,user_id,created_at,updated_at) values(sid,actor,now(),now());
 insert into public.trainer_access(trainer_id,enabled,client_limit,last_reason) values(actor,true,1,'Ensayo avance barrido');
 perform set_config('request.jwt.claim.sub',actor::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',actor,'session_id',sid,'aal','aal2','role','authenticated')::text,true);
 set local role authenticated;
 path_a:=public.reserve_trainer_exercise_image(image_a);path_b:=public.reserve_trainer_exercise_image(image_b);
 insert into storage.objects(bucket_id,name) values('trainer-exercise-images',path_a),('trainer-exercise-images',path_b);
 draft:=jsonb_build_object('name','Primera imagen protegida','description','','video_url',null,'image_path',path_a,
  'muscle_groups',jsonb_build_array('piernas'),'equipment',jsonb_build_array('ninguno'),'difficulty','inicial','exercise_type','repeticiones');
 perform public.save_trainer_exercise(gen_random_uuid(),draft);
 reset role;
 update trainer_private.exercise_images set created_at=clock_timestamp()-interval '3 days' where trainer_id=actor;
 set local role authenticated;
 first:=public.sweep_exercise_media_cleanup(operation_a,'trainer',1);
 if jsonb_array_length(first->'items')<>1 or first->'items'->0->>'state'<>'blocked' then raise exception 'No revisa primero el candidato protegido';end if;
 job_a:=(first->'items'->0->>'job_id')::uuid;
 if public.sweep_exercise_media_cleanup(operation_a,'trainer',1)<>first then raise exception 'El replay avanza a otro lote';end if;
 second:=public.sweep_exercise_media_cleanup(gen_random_uuid(),'trainer',1);job_b:=(second->'items'->0->>'job_id')::uuid;
 if jsonb_array_length(second->'items')<>1 or second->'items'->0->>'state'<>'queued' or job_b=job_a then raise exception 'El protegido impide llegar al siguiente huérfano';end if;
 third:=public.sweep_exercise_media_cleanup(gen_random_uuid(),'trainer',1);
 fourth:=public.sweep_exercise_media_cleanup(gen_random_uuid(),'trainer',1);
 if(third->'items'->0->>'job_id')::uuid<>job_a or(fourth->'items'->0->>'job_id')::uuid<>job_b then raise exception 'No rota por la revisión más antigua';end if;
 if(public.sweep_exercise_media_cleanup(operation_a,'trainer',1)->'items'->0->>'job_id')::uuid<>job_a then raise exception 'Reintento perdido recrea el barrido';end if;
 reset role;
 if(select image_used from trainer_private.exercise_limits where trainer_id=actor)<>2
  or exists(select 1 from trainer_private.exercise_images where trainer_id=actor and deleted_at is not null)
  or(select count(*) from storage.objects where bucket_id='trainer-exercise-images' and name in(path_a,path_b))<>2 then raise exception 'El barrido libera cuota o elimina archivos antes del ACK';end if;
 if not exists(select 1 from trainer_private.media_cleanup_jobs where id=job_a and path=path_a and state='blocked')
  or not exists(select 1 from trainer_private.media_cleanup_jobs where id=job_b and path=path_b and state='queued') then raise exception 'Se revisó un recurso distinto del solicitado';end if;
end $$;
rollback;
