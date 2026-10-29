-- Ejecutar en conexión A; B debe correr el companion _contender mientras duerme.
-- Todos los usuarios y la receta son sintéticos; la transacción se revierte.
begin;
set local statement_timeout='45s';
do $$
declare coach uuid:='6306f3ca-815c-41a3-8289-ce5d0ff092e1';pupil uuid:='fc67f657-9a04-4a8f-8bf2-439fc9311e46';
 relation uuid:='6116523b-3057-411e-a80b-ccfa5ed441ba';recipe uuid:='2b64f34c-e1c8-4826-8fd9-c58b16a2d8c5';
begin
 insert into auth.users(id,email) values(coach,coach||'@catalog-lock.invalid'),(pupil,pupil||'@catalog-lock.invalid');
 insert into auth.mfa_factors(id,user_id,factor_type,status,created_at,updated_at)
  values(gen_random_uuid(),coach,'totp','verified',now(),now());
 insert into public.trainer_access(trainer_id,enabled,client_limit,last_reason) values(coach,true,1,'Concurrencia de ensayo');
 insert into public.trainer_client_relations(id,trainer_id,client_id,accepted_at) values(relation,coach,pupil,now());
 perform set_config('request.jwt.claim.sub',coach::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',coach,'role','authenticated','aal','aal2')::text,true);
 -- Fixture de metadatos: las validaciones deportivas del creador tienen su
 -- cobertura propia; aquí interesa que asignar retenga el recurso compartido.
 perform set_config('entrenaop.creating_coach_template','true',true);
 insert into public.workout_templates(id,family_id,name,origin,owner_user_id)
  values(recipe,recipe,'Receta sintética de concurrencia','coach',coach);
 perform set_config('entrenaop.creating_coach_template','',true);
 set local role authenticated;
 perform public.assign_trainer_workout(gen_random_uuid(),relation,recipe,current_date,null);
 reset role;
 perform pg_sleep(25);
end $$;
rollback;
