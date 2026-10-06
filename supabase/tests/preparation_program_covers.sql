-- Prueba transaccional: no conserva usuarios, portadas ni objetos ficticios.
begin;
-- Solo metadatos ficticios y ROLLBACK: habilita la prueba de DELETE bajo RLS.
-- El producto elimina los archivos reales mediante la API de Storage.
select set_config('storage.allow_delete_query', 'true', true);
select set_config('request.jwt.claim.sub', (select user_id::text from public.admin_permissions limit 1), true);
do $$ begin
  if not coalesce(public.is_admin(), false) then raise exception 'La prueba necesita un admin de desarrollo'; end if;
end $$;
insert into public.preparation_programs(id,name,kind,enabled) values
  ('cover_test_public','Portada pública de prueba','access',true),
  ('cover_test_draft','Portada borrador de prueba','access',false);
set local role authenticated;
insert into storage.objects(bucket_id,name,metadata) values
  ('program-covers-public','official/cover_test_public/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa/card.jpg','{"mimetype":"image/jpeg"}'),
  ('program-covers-public','official/cover_test_public/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa/header.jpg','{"mimetype":"image/jpeg"}'),
  ('program-covers-public','official/cover_test_draft/bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb/card.jpg','{"mimetype":"image/jpeg"}'),
  ('program-covers-public','official/cover_test_draft/bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb/header.jpg','{"mimetype":"image/jpeg"}');
do $$
declare result jsonb; affected integer;
begin
  result := public.set_admin_program_cover('cover_test_public',
    'official/cover_test_public/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa/card.jpg',
    'official/cover_test_public/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa/header.jpg',0.8,0.3,0);
  if (result->'cover'->>'revision')::integer <> 1 then raise exception 'Revisión inicial incorrecta'; end if;
  perform public.set_admin_program_cover('cover_test_draft',
    'official/cover_test_draft/bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb/card.jpg',
    'official/cover_test_draft/bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb/header.jpg',0.5,0.5,0);
  if (select count(*) from public.preparation_program_covers where program_id like 'cover_test_%') <> 2
    then raise exception 'Admin no ve borradores'; end if;
  begin
    perform public.set_admin_program_cover('cover_test_public',null,null,0.5,0.5,0);
    raise exception 'Permite sobrescribir una edición posterior';
  exception when serialization_failure then null; end;
  begin
    perform public.set_admin_program_cover('cover_test_public',null,null,'NaN'::double precision,0.5,1);
    raise exception 'Permite foco NaN';
  exception when invalid_parameter_value then null; end;
  begin
    perform public.set_admin_program_cover('cover_test_public',null,null,1.1,0.5,1);
    raise exception 'Permite foco fuera de la imagen';
  exception when invalid_parameter_value then null; end;
  begin
    perform public.set_admin_program_cover('cover_test_public',
      'official/cover_test_draft/bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb/card.jpg',
      'official/cover_test_draft/bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb/header.jpg',0.5,0.5,1);
    raise exception 'Permite reutilizar archivos de otra preparación';
  exception when invalid_parameter_value then null; end;
  begin
    perform public.set_admin_program_cover('cover_test_public',
      'official/cover_test_public/cccccccccccccccccccccccccccccccc/card.jpg',
      'official/cover_test_public/cccccccccccccccccccccccccccccccc/header.jpg',0.5,0.5,1);
    raise exception 'Permite archivos sin subir';
  exception when invalid_parameter_value then null; end;
  begin
    update public.preparation_program_covers set focal_x=0.1 where program_id='cover_test_public';
    raise exception 'Permite escritura sin RPC';
  exception when insufficient_privilege then null; end;
  delete from storage.objects where bucket_id='program-covers-public' and name like 'official/cover_test_public/%';
  get diagnostics affected = row_count;
  if affected <> 0 then raise exception 'La limpieza borra archivos vigentes'; end if;
  update storage.objects set metadata='{}' where bucket_id='program-covers-public' and name like 'official/cover_test_public/%';
  get diagnostics affected = row_count;
  if affected <> 0 then raise exception 'Permite sobrescribir imágenes inmutables'; end if;
end $$;
select set_config('request.jwt.claim.sub', gen_random_uuid()::text, true);
do $$ begin
  if (select count(*) from public.preparation_program_covers where program_id like 'cover_test_%') <> 1
    then raise exception 'El deportista no ve catálogo público o ve borradores'; end if;
  begin
    perform public.set_admin_program_cover('cover_test_public',null,null,0.5,0.5,1);
    raise exception 'Un deportista puede modificar portadas';
  exception when insufficient_privilege then null; end;
  begin
    insert into storage.objects(bucket_id,name,metadata) values ('program-covers-public',
      'official/cover_test_public/dddddddddddddddddddddddddddddddd/card.jpg','{"mimetype":"image/jpeg"}');
    raise exception 'Un deportista puede subir portadas';
  exception when insufficient_privilege then null; end;
end $$;
reset role;
select set_config('request.jwt.claim.sub', (select user_id::text from public.admin_permissions limit 1), true);
set local role authenticated;
do $$ declare result jsonb; affected integer; begin
  result := public.set_admin_program_cover('cover_test_public',null,null,0.5,0.5,1);
  if result->'cover'->>'card_image_path' is not null or (result->'cover'->>'revision')::integer <> 2
    then raise exception 'Retirada incorrecta'; end if;
  delete from storage.objects where bucket_id='program-covers-public' and name like 'official/cover_test_public/%';
  get diagnostics affected = row_count;
  if affected <> 2 then raise exception 'No permite limpiar archivos retirados'; end if;
  if has_function_privilege('anon','public.set_admin_program_cover(text,text,text,double precision,double precision,integer)','execute')
    then raise exception 'RPC accesible sin autenticación'; end if;
end $$;
reset role;
select 'Portadas: RLS, Storage, revisión, validaciones y retirada OK' as result;
rollback;
