-- ADM-003: papelera de familias y trabajo privado, sin DELETE ni datos persistentes.
begin;
do $$
declare admin_id uuid; athlete uuid:=gen_random_uuid(); stranger uuid:=gen_random_uuid(); exercise uuid;
  template uuid; first_program uuid; next_version uuid; other_program uuid; following uuid; execution uuid;
  work uuid:=gen_random_uuid(); solo uuid:=gen_random_uuid(); content jsonb; payload jsonb; state jsonb;
  stamp timestamptz; new_stamp timestamptz; result jsonb; before_template jsonb; before_links jsonb; before_state jsonb;
begin
  if has_function_privilege('anon','public.list_admin_guided_program_trash()','execute')
    or has_function_privilege('anon','public.trash_admin_guided_program(uuid)','execute')
    or has_function_privilege('anon','public.restore_admin_guided_program(uuid,timestamptz)','execute')
    or has_function_privilege('anon','public.restore_admin_guided_work(uuid,bigint)','execute')
    or has_table_privilege('authenticated','public.guided_programs','delete') then
    raise exception 'La papelera permite acceso anónimo o borrado directo.';
  end if;
  select user_id into strict admin_id from public.admin_permissions limit 1;
  select id into strict exercise from public.exercises where is_public limit 1;
  insert into auth.users(id,email) values(athlete,athlete||'@trash.invalid'),(stranger,stranger||'@trash.invalid');
  perform set_config('request.jwt.claim.sub',admin_id::text,true);
  perform set_config('request.jwt.claims','{"aal":"aal2"}',true);
  set local role authenticated;
  payload:=jsonb_build_object('name','Sesión compartida papelera','show_in_library',true,
    'blocks',jsonb_build_array(jsonb_build_object('name','Trabajo','format','straight_sets','rounds',1,
      'exercises',jsonb_build_array(jsonb_build_object('exercise_id',exercise,
        'sets',jsonb_build_array(jsonb_build_object('target_reps',10,'rest_after_seconds',60)))))));
  template:=public.create_admin_workout_draft(null,payload);
  content:=jsonb_build_object('name','Programa de prueba papelera','mode','guide','phases',
    jsonb_build_array(jsonb_build_object('name','Secuencia','sessions',jsonb_build_array(
      jsonb_build_object('template_id',template,'name','Compartida')))));
  first_program:=public.save_guided_program(content);
  perform public.set_guided_program_status(first_program,'published');
  next_version:=public.save_guided_program(content||'{"name":"Revisión borrador papelera"}',first_program);
  other_program:=public.save_guided_program(content||'{"name":"Otro programa compartido"}');
  perform public.set_guided_program_status(other_program,'published');
  state:=jsonb_build_object('schema',1,'name','Trabajo vinculado','phases',jsonb_build_array());
  perform public.save_admin_guided_work(work,0,state,first_program);
  perform public.save_admin_guided_work(solo,0,state||'{"name":"Trabajo independiente"}');
  select to_jsonb(t) into before_template from public.workout_templates t where id=template;
  select jsonb_agg(to_jsonb(l) order by program_id,phase_index,session_index) into before_links
    from public.guided_program_links l where template_id=template;
  select w.state into before_state from public.admin_guided_work_drafts w where id=work;
  perform set_config('request.jwt.claim.sub',athlete::text,true);
  perform set_config('request.jwt.claims','{"aal":"aal1"}',true);
  following:=public.follow_guided_program(first_program);
  perform set_config('request.jwt.claim.sub',admin_id::text,true);
  perform set_config('request.jwt.claims','{"aal":"aal2"}',true);
  perform public.trash_admin_guided_program(next_version);
  select trashed_at into stamp from public.guided_programs where id=first_program;
  perform public.trash_admin_guided_program(first_program);
  if stamp is null or (select count(*) from public.guided_programs where family_id=first_program and trashed_at=stamp)<>2
    or (select status from public.guided_programs where id=first_program)<>'archived'
    or (select status from public.guided_programs where id=next_version)<>'draft'
    or (select status from public.guided_programs where id=other_program)<>'published'
    or (select to_jsonb(t) from public.workout_templates t where id=template)<>before_template
    or (select jsonb_agg(to_jsonb(l) order by program_id,phase_index,session_index)
      from public.guided_program_links l where template_id=template)<>before_links
    or (select w.state from public.admin_guided_work_drafts w where id=work)<>before_state then
    raise exception 'La papelera cambia la familia incorrecta, sus sesiones, enlaces o trabajo.';
  end if;
  result:=public.list_admin_guided_program_trash();
  if not exists(select 1 from jsonb_array_elements(result) r
    where r->>'id'=first_program::text and r->>'versions'='2' and r->>'work_count'='1') then
    raise exception 'La papelera no agrupa las versiones y su trabajo.';
  end if;
  if exists(select 1 from jsonb_array_elements(public.admin_catalog_quality()) r where r->>'resource_id'=next_version::text) then
    raise exception 'Calidad sigue proponiendo editar un programa en papelera.';
  end if;
  begin perform public.set_guided_program_status(next_version,'published');
    raise exception 'Publicó desde una pestaña antigua.';
  exception when sqlstate '22023' then null; end;
  begin perform public.save_guided_program(content,first_program);
    raise exception 'Creó otra versión de una familia en papelera.';
  exception when sqlstate '22023' then null; end;
  begin perform public.save_admin_guided_work(work,1,state||'{"name":"Cambio tardío"}',first_program);
    raise exception 'Editó un trabajo de un programa en papelera.';
  exception when sqlstate '22023' then null; end;
  begin perform public.finalize_admin_guided_work(work,1,content,null,null);
    raise exception 'Finalizó un trabajo desde una pestaña antigua.';
  exception when sqlstate '22023' then null; end;
  begin perform public.set_admin_guided_program_cover(first_program,null,null,0.5,0.5,0.5,0.5,0);
    raise exception 'Cambió la portada de una familia en papelera.';
  exception when sqlstate '22023' then null; end;
  begin perform public.restore_admin_guided_program(first_program,stamp-interval '1 second');
    raise exception 'Recuperó otra generación de papelera.';
  exception when sqlstate '40001' then null; end;
  perform set_config('request.jwt.claim.sub',stranger::text,true);
  perform set_config('request.jwt.claims','{"aal":"aal1"}',true);
  if exists(select 1 from public.guided_programs where id=first_program)
    or not exists(select 1 from public.guided_programs where id=other_program) then
    raise exception 'La retirada no conserva el aislamiento del catálogo.';
  end if;
  begin perform public.list_admin_guided_program_trash(); raise exception 'Lee papelera sin ser admin.';
  exception when insufficient_privilege then null; end;
  begin perform public.restore_admin_guided_program(first_program,stamp); raise exception 'Recupera sin ser admin.';
  exception when insufficient_privilege then null; end;
  begin perform public.trash_admin_guided_program(other_program); raise exception 'Retira sin ser admin.';
  exception when insufficient_privilege then null; end;
  begin perform public.restore_admin_guided_work(solo,1); raise exception 'Recupera trabajo ajeno.';
  exception when insufficient_privilege then null; end;
  begin perform public.follow_guided_program(first_program); raise exception 'Inicia seguimiento desde papelera.';
  exception when sqlstate '22023' then null; end;
  perform set_config('request.jwt.claim.sub',athlete::text,true);
  if not exists(select 1 from public.guided_program_follows where id=following)
    or not exists(select 1 from public.guided_programs where id=first_program) then
    raise exception 'Se ha perdido el seguimiento o su versión histórica.';
  end if;
  execution:=public.start_guided_program_session(first_program,0,0,gen_random_uuid());
  if execution is null then raise exception 'La papelera rompe los seguimientos existentes.'; end if;
  perform set_config('request.jwt.claim.sub',admin_id::text,true);
  begin perform public.list_admin_guided_program_trash(); raise exception 'La papelera no exige MFA.';
  exception when insufficient_privilege then null; end;
  perform set_config('request.jwt.claims','{"aal":"aal2"}',true);
  perform public.restore_admin_guided_program(first_program,stamp);
  perform public.restore_admin_guided_program(first_program,stamp);
  if exists(select 1 from public.guided_programs where family_id=first_program and (trashed_at is not null or status='published'))
    or (select count(*) from public.guided_programs where family_id=first_program)<>2 then
    raise exception 'Recuperar publica o duplica versiones.';
  end if;
  perform public.trash_admin_guided_program(first_program);
  select trashed_at into new_stamp from public.guided_programs where id=first_program;
  begin perform public.restore_admin_guided_program(first_program,stamp); raise exception 'Una respuesta vieja resucita un borrado posterior.';
  exception when sqlstate '40001' then null; end;
  perform public.restore_admin_guided_program(first_program,new_stamp);
  perform public.discard_admin_guided_work(solo,1);
  perform public.discard_admin_guided_work(solo,1);
  result:=public.list_admin_guided_program_trash();
  if not exists(select 1 from jsonb_array_elements(result) r where r->>'id'=solo::text and r->>'revision'='2') then
    raise exception 'No conserva el trabajo independiente en papelera.';
  end if;
  reset role;
  insert into public.admin_permissions(user_id) values(stranger);
  set local role authenticated;
  perform set_config('request.jwt.claim.sub',stranger::text,true);
  if exists(select 1 from jsonb_array_elements(public.list_admin_guided_program_trash()) r where r->>'id'=solo::text) then
    raise exception 'La papelera filtra trabajo privado entre administradores.';
  end if;
  begin perform public.restore_admin_guided_work(solo,2); raise exception 'Otro administrador recupera trabajo ajeno.';
  exception when insufficient_privilege then null; end;
  perform set_config('request.jwt.claim.sub',admin_id::text,true);
  perform public.restore_admin_guided_work(solo,2);
  perform public.restore_admin_guided_work(solo,2);
  begin perform public.save_admin_guided_work(solo,1,state); raise exception 'Una pestaña previa sobrescribe el trabajo restaurado.';
  exception when sqlstate '40001' then null; end;
  if (select discarded_at is not null or revision<>3 from public.admin_guided_work_drafts where id=solo) then
    raise exception 'Recuperar trabajo altera su estado o revisión.';
  end if;
end $$;
rollback;
