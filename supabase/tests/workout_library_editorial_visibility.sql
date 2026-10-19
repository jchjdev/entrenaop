-- Integración de descubrimiento, reutilización y permisos. No deja contenido.
begin;
do $$
declare admin_id uuid; owner_id uuid:=gen_random_uuid(); ex uuid; session_id uuid; revision_id uuid;
  program_a uuid; program_b uuid; draft_program uuid; newer_program uuid; default_session uuid; empty_category uuid; used_category uuid; draft_category uuid;
  execution_id uuid; original_content jsonb; payload jsonb; content jsonb; suffix text:=left(gen_random_uuid()::text,10);
begin
  if has_function_privilege('anon','public.set_admin_workout_library_visibility(uuid,boolean,boolean)','EXECUTE')
    or has_function_privilege('anon','public.get_guided_program_catalog_categories()','EXECUTE') then
    raise exception 'Una RPC editorial permite acceso anónimo.';
  end if;
  insert into auth.users(id,email) values(owner_id,owner_id||'@editorial.example.invalid');
  select user_id into admin_id from public.admin_permissions limit 1;
  select id into ex from public.exercises where is_public and id<>'20000000-0000-4000-8000-000000000004' limit 1;
  perform set_config('request.jwt.claim.sub',admin_id::text,true);
  perform set_config('request.jwt.claims','{"aal":"aal2"}',true);
  set local role authenticated;
  payload:=jsonb_build_object('name','Sesión editorial '||suffix,'show_in_library',false,'blocks',jsonb_build_array(jsonb_build_object(
    'name','Trabajo','format','straight_sets','rounds',1,'rest_after_seconds',0,'exercises',jsonb_build_array(jsonb_build_object(
      'exercise_id',ex,'sets',jsonb_build_array(jsonb_build_object('target_reps',8,'rest_after_seconds',90)))))));
  session_id:=public.create_admin_workout_draft(null,payload);
  perform public.publish_admin_workout_draft(session_id);
  if not exists(select 1 from public.workout_templates where id=session_id and status='published' and visibility='public' and not show_in_library) then
    raise exception 'Ocultar una sesión la despublica o pierde la elección.';
  end if;
  empty_category:=public.save_guided_program_category('Vacía editorial '||suffix);
  used_category:=public.save_guided_program_category('Usada editorial '||suffix);
  draft_category:=public.save_guided_program_category('Borrador editorial '||suffix);
  content:=jsonb_build_object('name','Programa editorial A '||suffix,'mode','guide','phases',jsonb_build_array(jsonb_build_object(
    'name','Trabajo','sessions',jsonb_build_array(jsonb_build_object('name','Sesión compartida','template_id',session_id,'rest','{}'::jsonb)))));
  program_a:=public.save_guided_program(content,null,array[used_category],used_category);
  perform public.set_guided_program_status(program_a,'published');
  original_content:=content;
  content:=jsonb_set(content,'{name}',to_jsonb('Programa editorial B '||suffix));
  program_b:=public.save_guided_program(content,null,array[used_category],used_category);
  perform public.set_guided_program_status(program_b,'published');
  draft_program:=public.save_guided_program(content,null,array[draft_category],draft_category);
  if (select count(*) from public.guided_program_links where template_id=session_id and program_id in(program_a,program_b))<>2 then
    raise exception 'La sesión no se reutiliza en ambos programas.';
  end if;
  if exists(select 1 from public.get_guided_program_catalog_categories() where id in(empty_category,draft_category))
    or not exists(select 1 from public.get_guided_program_catalog_categories() where id=used_category) then
    raise exception 'Se muestran categorías vacías o solo de borradores.';
  end if;
  perform public.set_guided_program_status(draft_program,'published');
  if not exists(select 1 from public.get_guided_program_catalog_categories() where id=draft_category) then
    raise exception 'La categoría no aparece al publicar su primer programa.';
  end if;
  newer_program:=public.save_guided_program(content,draft_program,array[used_category],used_category);
  perform public.set_guided_program_status(newer_program,'published');
  if exists(select 1 from public.get_guided_program_catalog_categories() where id=draft_category) then
    raise exception 'Una versión publicada superada mantiene una categoría vacía.';
  end if;
  default_session:=public.create_admin_workout_draft(null,payload-'show_in_library');
  if not (select show_in_library from public.workout_templates where id=default_session) then
    raise exception 'El contrato anterior cambia su elección editorial por defecto.';
  end if;
  revision_id:=public.revise_admin_workout(session_id,payload-'show_in_library');
  if (select show_in_library from public.workout_templates where id=revision_id) then
    raise exception 'Revisar una sesión pierde su visibilidad editorial.';
  end if;
  perform public.set_admin_workout_library_visibility(session_id,true,false);
  if not exists(select 1 from public.workout_templates where id=session_id and visibility='public' and status='published' and show_in_library) then
    raise exception 'No se puede ofrecer como sesión suelta sin cambiar la publicación.';
  end if;
  begin
    perform public.set_admin_workout_library_visibility(session_id,false,false);
    raise exception 'Acepta una edición editorial obsoleta.';
  exception when sqlstate '40001' then null; end;
  perform public.set_admin_workout_library_visibility(session_id,false,true);
  if (select p.content from public.guided_programs p where p.id=program_a)<>original_content
    or (select count(*) from public.guided_program_links where template_id=session_id and program_id in(program_a,program_b))<>2 then
    raise exception 'Cambiar visibilidad alteró las recetas o sus referencias.';
  end if;
  perform set_config('request.jwt.claim.sub',owner_id::text,true);
  perform set_config('request.jwt.claims','{"aal":"aal1"}',true);
  begin
    perform public.set_admin_workout_library_visibility(session_id,true,false);
    raise exception 'Un deportista cambia la visibilidad oficial.';
  exception when sqlstate '42501' then null; end;
  update public.workout_templates set show_in_library=true where id=session_id;
  if (select show_in_library from public.workout_templates where id=session_id) then
    raise exception 'El deportista modifica la marca con una escritura directa.';
  end if;
  if not exists(select 1 from public.workout_templates where id=session_id) then
    raise exception 'La sesión fuera del listado no se puede leer desde un programa.';
  end if;
  if not exists(select 1 from public.get_guided_program_catalog_categories() where id=used_category) then
    raise exception 'La cuenta de deportista no recibe las categorías con contenido.';
  end if;
  perform public.follow_guided_program(program_a);
  execution_id:=public.start_guided_program_session(program_a,0,0,gen_random_uuid());
  if not exists(select 1 from public.workout_executions where id=execution_id and status='in_progress') then
    raise exception 'La sesión fuera del listado no inicia con el ejecutor guiado.';
  end if;
  perform set_config('request.jwt.claim.sub',admin_id::text,true);
  perform set_config('request.jwt.claims','{"aal":"aal2"}',true);
  perform public.set_admin_workout_library_visibility(session_id,true,false);
  if not exists(select 1 from public.workout_executions where id=execution_id and status='in_progress') then
    raise exception 'Cambiar visibilidad altera el entrenamiento existente.';
  end if;
  reset role;
end $$;
rollback;
