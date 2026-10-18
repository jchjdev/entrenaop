-- Metadatos ficticios, sin subir archivos reales ni conservar usuarios o entrenamientos.
begin;
select set_config('storage.allow_delete_query','true',true);
do $$
declare admin_id uuid; owner_id uuid:=gen_random_uuid(); root uuid; revision_id uuid; other_program uuid;
  exercise uuid; session_id uuid; payload jsonb; content jsonb; response jsonb; paths text[];
  card_path text; header_path text; affected integer;
begin
  select user_id into admin_id from public.admin_permissions limit 1;
  insert into auth.users(id,email) values(owner_id,owner_id||'@guided-covers.example.invalid');
  perform set_config('request.jwt.claim.sub',admin_id::text,true);
  set local role authenticated;
  select id into strict exercise from public.exercises where is_public and training_profile_code='push_up_standard';
  payload:=jsonb_build_object('name','Portada transaccional','blocks',jsonb_build_array(jsonb_build_object(
    'name','Trabajo','format','straight_sets','rounds',1,'rest_after_seconds',0,
    'exercises',jsonb_build_array(jsonb_build_object('exercise_id',exercise,'sets',jsonb_build_array(
      jsonb_build_object('target_reps',8,'rest_after_seconds',90)))))));
  session_id:=public.create_admin_workout_draft(null,payload);
  perform public.publish_admin_workout_draft(session_id);
  content:=jsonb_build_object('name','Programa con portada temporal','mode','guide','phases',jsonb_build_array(
    jsonb_build_object('name','Rutina','sessions',jsonb_build_array(jsonb_build_object('name','Sesión','template_id',session_id)))));
  root:=public.save_guided_program(content);
  other_program:=public.save_guided_program(content||'{"name":"Otra familia temporal"}'::jsonb);
  card_path:='guided/'||root||'/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa/card.jpg';
  header_path:=replace(card_path,'card.jpg','header.jpg');
  insert into storage.objects(bucket_id,name,metadata) values
    ('program-covers-public',card_path,'{"mimetype":"image/jpeg"}'),
    ('program-covers-public',header_path,'{"mimetype":"image/jpeg"}');
  begin
    insert into storage.objects(bucket_id,name,metadata) values('program-covers-public',
      'guided/'||gen_random_uuid()||'/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa/card.jpg','{"mimetype":"image/jpeg"}');
    raise exception 'Permite subir a una familia inexistente.';
  exception when insufficient_privilege then null; end;
  response:=public.set_admin_guided_program_cover(root,card_path,header_path,0.8,0.2,0.3,0.7,0);
  if (response->'cover'->>'revision')::int<>1 or (response->'cover'->>'header_focal_x')::float<>0.3 then
    raise exception 'No conserva revisión o encuadres separados.'; end if;
  begin
    perform public.set_admin_guided_program_cover(root,null,null,0.5,0.5,0.5,0.5,0);
    raise exception 'Una edición antigua pisa la portada.';
  exception when serialization_failure then null; end;
  begin
    perform public.set_admin_guided_program_cover(root,null,null,'NaN'::float,0.5,0.5,0.5,1);
    raise exception 'Aceptó foco inválido.';
  exception when invalid_parameter_value then null; end;
  begin
    perform public.set_admin_guided_program_cover(other_program,card_path,header_path,0.5,0.5,0.5,0.5,0);
    raise exception 'Aceptó archivos de otra familia.';
  exception when invalid_parameter_value then null; end;
  begin
    perform public.set_admin_guided_program_cover(root,replace(card_path,'aaaaaaaa','bbbbbbbb'),header_path,0.5,0.5,0.5,0.5,1);
    raise exception 'Aceptó archivos ausentes o pareja incoherente.';
  exception when invalid_parameter_value then null; end;
  delete from storage.objects where bucket_id='program-covers-public' and name in (card_path,header_path);
  get diagnostics affected=row_count;
  if affected<>0 then raise exception 'La limpieza elimina una portada vigente.'; end if;

  perform set_config('request.jwt.claim.sub',owner_id::text,true);
  if exists(select 1 from public.guided_program_covers where program_id=root) then
    raise exception 'Un deportista ve la portada de un borrador.'; end if;
  begin
    perform public.set_admin_guided_program_cover(root,null,null,0.5,0.5,0.5,0.5,1);
    raise exception 'Un deportista modifica portadas.';
  exception when insufficient_privilege then null; end;
  begin
    update public.guided_program_covers set focal_x=0 where program_id=root;
    raise exception 'Se permite escribir sin RPC.';
  exception when insufficient_privilege then null; end;
  begin
    insert into storage.objects(bucket_id,name,metadata) values('program-covers-public',
      'guided/'||root||'/bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb/card.jpg','{"mimetype":"image/jpeg"}');
    raise exception 'Un deportista sube fotografías oficiales.';
  exception when insufficient_privilege then null; end;

  perform set_config('request.jwt.claim.sub',admin_id::text,true);
  perform public.set_guided_program_status(root,'published');
  revision_id:=public.save_guided_program(content,root);
  response:=public.set_admin_guided_program_cover(revision_id,card_path,header_path,0.6,0.2,0.3,0.9,1);
  if (response->'cover'->>'program_id')::uuid<>root or
    (select count(*) from public.guided_program_covers where program_id in(root,revision_id))<>1 or
    (select p.content from public.guided_programs p where p.id=root)<>content then
    raise exception 'La portada no es común o ha alterado el entrenamiento publicado.'; end if;
  perform set_config('request.jwt.claim.sub',owner_id::text,true);
  if not exists(select 1 from public.guided_program_covers where program_id=root) then
    raise exception 'El catálogo no muestra la portada publicada.'; end if;
  perform public.follow_guided_program(root);
  perform set_config('request.jwt.claim.sub',admin_id::text,true);
  perform public.set_guided_program_status(root,'archived');
  perform set_config('request.jwt.claim.sub',owner_id::text,true);
  if not exists(select 1 from public.guided_program_covers where program_id=root) then
    raise exception 'Pierde la portada de la versión seguida al retirarla.'; end if;
  perform set_config('request.jwt.claim.sub',gen_random_uuid()::text,true);
  if exists(select 1 from public.guided_program_covers where program_id=root) then
    raise exception 'Se expone la portada retirada a otra cuenta.'; end if;

  perform set_config('request.jwt.claim.sub',admin_id::text,true);
  perform public.set_admin_guided_program_cover(root,null,null,0.5,0.5,0.5,0.5,2);
  delete from storage.objects where bucket_id='program-covers-public' and name in(card_path,header_path);
  get diagnostics affected=row_count;
  if affected<>2 then raise exception 'No permite limpiar archivos ya desvinculados.'; end if;
  reset role;
end $$;
select 'Portadas por familia: autoría, encuadres, CAS, archivos, RLS, retirada y limpieza correctos.' as result;
rollback;
