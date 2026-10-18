begin;
do $$
declare admin_id uuid; owner_id uuid:=gen_random_uuid(); suffix text:=left(gen_random_uuid()::text,12);
  category_a uuid; category_b uuid; missing_category uuid:=gen_random_uuid(); exercise uuid; session uuid; program_a uuid; program_b uuid; draft uuid;
  payload jsonb; content jsonb; before_content jsonb; first_page uuid; second_page uuid; total integer;
begin
  if has_function_privilege('anon','public.save_guided_program_category(text,uuid,boolean,integer)','EXECUTE')
    or has_function_privilege('anon','public.get_guided_program_catalog(text,text,integer,integer,boolean,uuid)','EXECUTE') then
    raise exception 'Una RPC nueva permite acceso anónimo.';
  end if;
  if public.library_search_text('  GLÚTEO__Tirón  ')<>'gluteo tiron'
    or public.library_search_text(U&'glu\0301teo')<>'gluteo'
    or public.library_search_text(null)<>'' then raise exception 'Normalización inconsistente.'; end if;
  insert into auth.users(id,email) values(owner_id,owner_id||'@guided-categories.example.invalid');
  select user_id into admin_id from public.admin_permissions limit 1;
  perform set_config('request.jwt.claim.sub',admin_id::text,true);
  select id into exercise from public.exercises where is_public and id<>'20000000-0000-4000-8000-000000000004' limit 1;
  set local role authenticated;
  category_a:=public.save_guided_program_category('Rehabilitación '||suffix);
  category_b:=public.save_guided_program_category('Fuerza '||suffix);
  begin
    perform public.save_guided_program_category('  REHABILITACION '||suffix||'  ');
    raise exception 'Acepta categorías duplicadas por tildes, espacios o mayúsculas.';
  exception when unique_violation then null; end;
  begin
    perform public.save_guided_program_category(''); raise exception 'Acepta nombre vacío.';
  exception when sqlstate '22023' then null; end;

  payload:=jsonb_build_object('name','Sesión de categorías temporal','blocks',jsonb_build_array(jsonb_build_object(
    'name','Trabajo','format','straight_sets','rounds',1,'rest_after_seconds',0,
    'exercises',jsonb_build_array(jsonb_build_object('exercise_id',exercise,'sets',jsonb_build_array(
      jsonb_build_object('target_reps',8,'rest_after_seconds',90)))))));
  session:=public.create_admin_workout_draft(null,payload);
  perform public.publish_admin_workout_draft(session);
  content:=jsonb_build_object('name','Categorías temporal glúteo A','mode','guide','description','Práctica de técnica',
    'phases',jsonb_build_array(jsonb_build_object('name','Trabajo','sessions',jsonb_build_array(
      jsonb_build_object('template_id',session,'name','Sesión A','rest','{}'::jsonb)))));
  program_a:=public.save_guided_program(content,null,array[category_a,category_b],category_a);
  perform public.set_guided_program_status(program_a,'published');
  before_content:=content;
  content:=jsonb_set(content,'{name}','"Categorías temporal glúteo B"'::jsonb);
  program_b:=public.save_guided_program(content,null,array[category_a],category_a);
  perform public.set_guided_program_status(program_b,'published');
  begin
    perform public.save_guided_program(content,null,array[category_a],category_b);
    raise exception 'Permite una principal no seleccionada.';
  exception when sqlstate '22023' then null; end;
  begin
    perform public.save_guided_program(content,null,array[category_a,category_a],category_a);
    raise exception 'Permite categorías repetidas.';
  exception when sqlstate '22023' then null; end;
  begin
    perform public.save_guided_program(content,null,'{}'::uuid[],category_a);
    raise exception 'Permite principal sin categorías.';
  exception when sqlstate '22023' then null; end;
  begin
    perform public.save_guided_program(content,null,array[missing_category],missing_category);
    raise exception 'Permite referencias inexistentes.';
  exception when sqlstate '22023' then null; end;
  if (select count(*) from public.guided_programs p where p.content->>'name' like 'Categorías temporal%')<>2 then
    raise exception 'Un fallo de categorías dejó un borrador parcial.';
  end if;
  -- Las llamadas anteriores a esta ampliación mantienen las asignaciones.
  draft:=public.save_guided_program(before_content,program_a);
  if draft=program_a or (select count(*) from public.guided_program_category_links where program_id=draft)<>2 then
    raise exception 'Una revisión con el contrato antiguo pierde categorías.';
  end if;
  begin
    perform public.save_guided_program(content,draft,array[missing_category],missing_category);
    raise exception 'Un guardado inválido sobrescribe el borrador.';
  exception when sqlstate '22023' then null; end;
  if (select p.content from public.guided_programs p where p.id=draft)<>before_content
    or (select count(*) from public.guided_program_category_links where program_id=draft)<>2 then
    raise exception 'Un fallo perdió campos o categorías ya guardadas.';
  end if;
  if (select p.content from public.guided_programs p where p.id=program_a)<>before_content then
    raise exception 'La clasificación modifica una publicación anterior.';
  end if;

  perform set_config('request.jwt.claim.sub',owner_id::text,true);
  if exists(select 1 from public.guided_program_category_links where program_id=draft) then
    raise exception 'Se filtra la clasificación de un borrador.';
  end if;
  begin
    perform public.save_guided_program_category('Intruso'); raise exception 'Un deportista crea categorías.';
  exception when insufficient_privilege then null; end;
  begin
    update public.guided_program_categories set name='Intruso' where id=category_a;
    raise exception 'Permite escritura directa del cliente.';
  exception when insufficient_privilege then null; end;
  select count(*) into total from public.get_guided_program_catalog('GLUTEO categorias temporal');
  if total<>2 or (select count(*) from public.get_guided_program_catalog('glúteo categorías temporal'))<>2 then
    raise exception 'Buscar con y sin tildes devuelve resultados distintos.';
  end if;
  if (select count(*) from public.get_guided_program_catalog('temporal tecnica rehabilitacion'))<>2 then
    raise exception 'No combina palabras de descripción y categorías.';
  end if;
  if (select count(*) from public.get_guided_program_catalog(p_query=>'categorias temporal',p_category_id=>category_b))<>1 then
    raise exception 'El filtro por categoría no se aplica.';
  end if;
  select id into first_page from public.get_guided_program_catalog('categorias temporal',p_limit=>1,p_category_id=>category_a);
  select id into second_page from public.get_guided_program_catalog('categorias temporal',p_offset=>1,p_limit=>1,p_category_id=>category_a);
  if first_page is null or second_page is null or first_page=second_page then raise exception 'La clasificación se filtra después de paginar.'; end if;
  if exists(select 1 from public.get_guided_program_catalog('%categorias%temporal%')) then
    raise exception 'El texto de búsqueda actúa como comodín SQL.';
  end if;

  perform set_config('request.jwt.claim.sub',admin_id::text,true);
  perform public.save_guided_program_category('Recuperación '||suffix,category_a,true,1);
  begin
    perform public.save_guided_program_category('Edición antigua',category_a,true,1);
    raise exception 'Una edición antigua sobrescribe el nombre.';
  exception when serialization_failure then null; end;
  perform public.save_guided_program_category('Recuperación '||suffix,category_a,false,2);
  if not exists(select 1 from public.guided_program_category_links where program_id=program_a and category_id=category_a and is_primary) then
    raise exception 'Desactivar destruye asignaciones o su principal.';
  end if;
  begin
    perform public.save_guided_program(content,null,array[category_a],category_a);
    raise exception 'Asigna una categoría desactivada a un programa nuevo.';
  exception when sqlstate '22023' then null; end;
  perform public.save_guided_program(before_content,draft);
  perform set_config('request.jwt.claim.sub',owner_id::text,true);
  if (select count(*) from public.get_guided_program_catalog('temporal recuperacion'))<>2 then
    raise exception 'Renombrar o desactivar impide encontrar los programas existentes.';
  end if;
  if (select count(*) from public.guided_program_category_links where program_id=program_a)<>2 then
    raise exception 'El propietario del catálogo no puede leer todas sus categorías.';
  end if;
end $$;
rollback;
