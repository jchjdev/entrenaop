-- UI-062: borradores enlazados, publicación atómica, reutilización y permisos.
begin;
do $$
declare admin_id uuid; athlete uuid:=gen_random_uuid(); exercise uuid;
  ids uuid[]:='{}'; edited uuid; unavailable uuid; program uuid; second_program uuid; changed_program uuid;
  payload jsonb; content jsonb; slots jsonb:='[]'; i integer;
begin
  if has_function_privilege('anon','public.save_guided_program(jsonb,uuid,uuid[],uuid)','execute')
    or has_function_privilege('anon','public.set_guided_program_status(uuid,text)','execute') then
    raise exception 'La autoría conjunta permite ejecución anónima.';
  end if;
  select user_id into strict admin_id from public.admin_permissions limit 1;
  select id into strict exercise from public.exercises where is_public limit 1;
  insert into auth.users(id,email) values(athlete,athlete||'@bundle.invalid');
  perform set_config('request.jwt.claim.sub',admin_id::text,true);
  perform set_config('request.jwt.claims','{"aal":"aal2"}',true);
  set local role authenticated;
  for i in 1..4 loop
    payload:=jsonb_build_object('name','Conjunto temporal '||i,'show_in_library',false,
      'blocks',jsonb_build_array(jsonb_build_object('name','Trabajo','format','straight_sets',
      'rounds',1,'rest_after_seconds',0,'exercises',jsonb_build_array(jsonb_build_object(
      'exercise_id',exercise,'sets',jsonb_build_array(jsonb_build_object('target_reps',10,'rest_after_seconds',60)))))));
    ids:=array_append(ids,public.create_admin_workout_draft(null,payload));
    slots:=slots||jsonb_build_array(jsonb_build_object('template_id',ids[i],'name','Sesión '||i,
      'rest',jsonb_build_object('min_seconds',null,'max_seconds',null)));
  end loop;
  -- La misma versión repetida se publica una vez, no se clona.
  slots:=slots||jsonb_build_array(slots->0);
  content:=jsonb_build_object('name','Conjunto temporal','mode','guide','phases',
    jsonb_build_array(jsonb_build_object('name','Entrenamiento','sessions',slots)));
  program:=public.save_guided_program(content);
  second_program:=public.save_guided_program(content||'{"name":"Otro montaje privado"}');
  if (select count(*) from public.workout_templates where id=any(ids) and status='draft' and visibility='private')<>4 then
    raise exception 'Guardar el programa ha publicado sesiones.';
  end if;
  edited:=public.revise_admin_workout(ids[1],payload||'{"name":"Corrección enlazada"}');
  if edited<>ids[1] or (select name from public.workout_templates where id=ids[1])<>'Corrección enlazada'
    or (select count(*) from public.guided_program_links where template_id=ids[1])<>4 then
    raise exception 'Editar rompe la identidad o los enlaces de programas en borrador.';
  end if;
  select x into unavailable from unnest(ids) x order by x desc limit 1;
  reset role;
  update public.workout_templates set status='archived' where id=unavailable;
  set local role authenticated;
  begin
    perform public.set_guided_program_status(program,'published');
    raise exception 'Aceptó una sesión retirada.';
  exception when sqlstate '22023' then null; end;
  if exists(select 1 from public.workout_templates where id=any(ids) and (status='published' or visibility='public'))
    or (select status from public.guided_programs where id=program)<>'draft' then
    raise exception 'La publicación fallida deja parte del conjunto publicado.';
  end if;
  reset role;
  update public.workout_templates set status='draft' where id=unavailable;
  set local role authenticated;
  perform public.set_guided_program_status(program,'published');
  if (select status from public.guided_programs where id=program)<>'published'
    or (select count(*) from public.workout_templates where id=any(ids) and status='published' and visibility='public' and not show_in_library)<>4
    or (select status from public.guided_programs where id=second_program)<>'draft' then
    raise exception 'La publicación conjunta no conserva visibilidad o separación de programas.';
  end if;
  edited:=public.revise_admin_workout(ids[1],payload||'{"name":"Nueva versión privada"}');
  if edited=ids[1] or (select status from public.workout_templates where id=ids[1])<>'published'
    or (select version from public.workout_templates where id=edited)<>2 then
    raise exception 'Editar una publicación altera su versión histórica.';
  end if;
  content:=jsonb_set(content,'{phases,0,sessions}',jsonb_build_array(
    jsonb_build_object('template_id',edited,'name','Receta editable','rest',
      jsonb_build_object('min_seconds',60,'max_seconds',120))));
  changed_program:=public.save_guided_program(content);
  payload:=jsonb_set(payload,'{blocks,0,format}','"emom"');
  payload:=jsonb_set(payload,'{blocks,0,rest_after_seconds}','60');
  perform public.revise_admin_workout(edited,payload);
  begin
    perform public.set_guided_program_status(changed_program,'published');
    raise exception 'Publicó descansos incompatibles tras editar el formato.';
  exception when sqlstate '22023' then null; end;
  if (select status from public.workout_templates where id=edited)<>'draft'
    or (select status from public.guided_programs where id=changed_program)<>'draft' then
    raise exception 'El fallo de integridad no revierte la publicación de la receta.';
  end if;
  perform set_config('request.jwt.claim.sub',athlete::text,true);
  perform set_config('request.jwt.claims','{"aal":"aal1"}',true);
  if exists(select 1 from public.guided_programs where id=second_program)
    or exists(select 1 from public.workout_templates where id=edited) then
    raise exception 'El deportista puede leer borradores.';
  end if;
  begin
    perform public.set_guided_program_status(second_program,'published');
    raise exception 'El deportista pudo publicar el conjunto.';
  exception when insufficient_privilege then null; end;
  begin
    perform public.save_guided_program(content);
    raise exception 'El deportista pudo guardar contenido oficial.';
  exception when insufficient_privilege then null; end;
end $$;
rollback;
