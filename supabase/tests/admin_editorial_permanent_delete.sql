-- ADM-004: borrado manual, referencias protegidas y sesiones recuperables.
-- Todos los recursos y borrados de este ensayo se revierten.
begin;
do $$
declare a uuid; outsider uuid:=gen_random_uuid(); athlete uuid:=gen_random_uuid(); e uuid;
  t uuid; standalone uuid; historical uuid; personal uuid; p uuid; v uuid; other uuid; followed uuid;
  work uuid:=gen_random_uuid(); solo uuid:=gen_random_uuid(); json_work uuid:=gen_random_uuid();
  payload jsonb; content jsonb; state jsonb; stamp timestamptz; before_session jsonb;
  event_id bigint; follow_id uuid; execution_id uuid; x jsonb;
begin
  if has_function_privilege('anon','public.purge_admin_trash(text,uuid,timestamptz,bigint)','execute')
    or has_function_privilege('anon','public.trash_admin_session(uuid)','execute')
    or has_function_privilege('anon','public.load_admin_guided_work(uuid)','execute')
    or has_function_privilege('anon','public.list_admin_session_trash()','execute')
    or has_table_privilege('authenticated','admin_ops_private.deleted_resources','select') then
    raise exception 'Se permiten accesos directos o anónimos.';
  end if;
  select user_id into strict a from public.admin_permissions limit 1;
  select id into strict e from public.exercises where is_public limit 1;
  insert into auth.users(id,email) values(outsider,outsider||'@purge.invalid'),(athlete,athlete||'@purge.invalid');
  insert into public.admin_permissions(user_id) values(outsider);
  perform set_config('request.jwt.claim.sub',a::text,true);
  perform set_config('request.jwt.claims','{"aal":"aal2"}',true);
  set local role authenticated;
  payload:=jsonb_build_object('name','Receta ensayo borrado','blocks',jsonb_build_array(
    jsonb_build_object('name','Trabajo','format','straight_sets','rounds',1,'exercises',jsonb_build_array(
      jsonb_build_object('exercise_id',e,'sets',jsonb_build_array(jsonb_build_object('target_reps',10,'rest_after_seconds',60)))))));
  t:=public.create_admin_workout_draft(null,payload);
  delete from public.workout_templates where id=t;
  if not exists(select 1 from public.workout_templates where id=t) then raise exception 'DELETE directo elude la papelera.'; end if;
  content:=jsonb_build_object('name','Familia purgable','mode','guide','phases',jsonb_build_array(
    jsonb_build_object('name','Secuencia','sessions',jsonb_build_array(jsonb_build_object('template_id',t,'name','Compartida')))));
  p:=public.save_guided_program(content);
  perform public.set_guided_program_status(p,'published');
  v:=public.save_guided_program(content,p);
  other:=public.save_guided_program(content||'{"name":"Otro programa"}');
  state:=jsonb_build_object('schema',1,'name','Trabajo conservado','phases',jsonb_build_array());
  perform public.save_admin_guided_work(work,0,state,p);
  perform public.save_admin_guided_work(solo,0,state);
  begin perform public.purge_admin_trash('program',p,now()); raise exception 'Borra sin pasar por papelera.';
  exception when sqlstate '40001' then null; end;
  begin perform public.trash_admin_session(t); raise exception 'Retira una sesión de programas activos.';
  exception when sqlstate 'P0001' then
    if SQLERRM not like 'La sesión sigue enlazada%' then raise; end if;
  end;
  perform public.trash_admin_guided_program(v);
  select trashed_at into stamp from public.guided_programs where id=p;
  begin perform public.purge_admin_trash('program',p,stamp-interval '1 second'); raise exception 'Acepta un lote antiguo.';
  exception when sqlstate '40001' then null; end;
  select to_jsonb(s) into before_session from public.workout_templates s where id=t;
  perform public.purge_admin_trash('program',p,stamp);
  perform public.purge_admin_trash('program',p,stamp);
  if exists(select 1 from public.guided_programs where id in (p,v))
    or exists(select 1 from public.admin_guided_work_drafts where id=work)
    or not exists(select 1 from public.guided_program_links where program_id=other and template_id=t)
    or (select to_jsonb(s) from public.workout_templates s where id=t) is distinct from before_session then
    raise exception 'El borrado de familia no conserva sesiones/otros programas o deja versiones/trabajos.';
  end if;
  x:=public.load_admin_guided_work(work);
  if x->>'permanently_deleted'<>'true' then raise exception 'La URL purgada se confunde con trabajo nuevo.'; end if;
  begin perform public.save_admin_guided_work(work,0,state); raise exception 'Resucita un ID purgado.';
  exception when sqlstate '22023' then null; end;
  perform public.restore_admin_guided_program(p,stamp);
  if exists(select 1 from public.guided_programs where family_id=p) then raise exception 'Recupera familia purgada.'; end if;
  -- El historial se conserva para auditoría, sin recuperación del recurso purgado.
  reset role;
  select id into strict event_id from admin_ops_private.editorial_events
    where resource_type='program' and resource_id=p and transaction_id=txid_current();
  set local role authenticated;
  begin perform public.restore_admin_editorial_event(event_id,gen_random_uuid()); raise exception 'Resucita desde historial.';
  exception when sqlstate '22023' then null; end;

  -- El trabajo privado exige propietario, lote y revisión vigentes.
  perform public.discard_admin_guided_work(solo,1);
  select discarded_at into stamp from public.admin_guided_work_drafts where id=solo;
  perform set_config('request.jwt.claim.sub',outsider::text,true);
  begin perform public.purge_admin_trash('work',solo,stamp,2); raise exception 'Borra trabajo ajeno.';
  exception when insufficient_privilege then null; end;
  begin perform public.load_admin_guided_work(solo); raise exception 'Carga trabajo ajeno.';
  exception when insufficient_privilege then null; end;
  perform set_config('request.jwt.claim.sub',a::text,true);
  begin perform public.purge_admin_trash('work',solo,stamp,1); raise exception 'Borra una revisión vieja.';
  exception when sqlstate '40001' then null; end;
  perform public.purge_admin_trash('work',solo,stamp,2);
  if public.load_admin_guided_work(solo)->>'permanently_deleted'<>'true' then raise exception 'No cierra el trabajo purgado.'; end if;

  -- Un seguimiento mantiene su programa y su acceso a entrenar, incluso en papelera.
  followed:=public.save_guided_program(content||'{"name":"Programa con historial"}');
  perform public.set_guided_program_status(followed,'published');
  perform set_config('request.jwt.claim.sub',athlete::text,true);
  perform set_config('request.jwt.claims','{"aal":"aal1"}',true);
  follow_id:=public.follow_guided_program(followed);
  perform set_config('request.jwt.claim.sub',a::text,true);
  perform set_config('request.jwt.claims','{"aal":"aal2"}',true);
  perform public.trash_admin_guided_program(followed);
  select trashed_at into stamp from public.guided_programs where id=followed;
  begin perform public.purge_admin_trash('program',followed,stamp); raise exception 'Borra un seguimiento.';
  exception when sqlstate 'P0001' then
    if SQLERRM not like 'Este programa tiene seguimientos%' then raise; end if;
  end;
  perform set_config('request.jwt.claim.sub',athlete::text,true);
  perform set_config('request.jwt.claims','{"aal":"aal1"}',true);
  execution_id:=public.start_guided_program_session(followed,0,0,gen_random_uuid());
  if execution_id is null then raise exception 'La denegación rompió el seguimiento.'; end if;
  perform set_config('request.jwt.claim.sub',a::text,true);
  perform set_config('request.jwt.claims','{"aal":"aal2"}',true);
  begin perform public.trash_admin_session(t); raise exception 'Retira sesión de programa en papelera.';
  exception when sqlstate 'P0001' then
    if SQLERRM not like 'La sesión sigue enlazada%' then raise; end if;
  end;

  -- Mismo ID al recuperar borradores; publicadas vuelven retiradas, nunca públicas.
  standalone:=public.create_admin_workout_draft(null,payload);
  perform public.remove_admin_workout(standalone);
  select trashed_at into stamp from public.workout_templates where id=standalone;
  if stamp is null or not exists(select 1 from jsonb_array_elements(public.list_admin_session_trash()) r
    where r->>'id'=standalone::text and r->>'kind'='session') then raise exception 'El borrador no está en papelera.'; end if;
  begin perform public.revise_admin_workout(standalone,payload); raise exception 'Edita la papelera.';
  exception when sqlstate '22023' then null; end;
  begin perform public.restore_admin_session(standalone,stamp-interval '1 second'); raise exception 'Recupera lote antiguo.';
  exception when sqlstate '40001' then null; end;
  perform public.restore_admin_session(standalone,stamp);
  if (select status<>'draft' or trashed_at is not null from public.workout_templates where id=standalone) then
    raise exception 'Recuperar borrador cambia su estado o ID.'; end if;
  perform public.publish_admin_workout_draft(standalone);
  perform public.trash_admin_session(standalone);
  select trashed_at into stamp from public.workout_templates where id=standalone;
  perform public.restore_admin_session(standalone,stamp);
  if (select status<>'archived' or visibility<>'private' from public.workout_templates where id=standalone) then
    raise exception 'Recuperar vuelve a publicar una sesión.'; end if;
  perform public.trash_admin_session(standalone);
  select trashed_at into stamp from public.workout_templates where id=standalone;
  begin perform public.purge_admin_trash('session',standalone,stamp-interval '1 second'); raise exception 'Purga sesión de lote antiguo.';
  exception when sqlstate '40001' then null; end;
  -- Las referencias JSON del creador también cuentan, aunque no tengan FK.
  perform public.save_admin_guided_work(json_work,0,state||jsonb_build_object('sessions',jsonb_build_array(standalone)));
  begin perform public.purge_admin_trash('session',standalone,stamp); raise exception 'Borra una referencia JSON.';
  exception when sqlstate 'P0001' then
    if SQLERRM not like 'La sesión está usada en un trabajo%' then raise; end if;
  end;
  perform public.save_admin_guided_work(json_work,1,state);
  perform public.purge_admin_trash('session',standalone,stamp);
  perform public.purge_admin_trash('session',standalone,stamp);
  if exists(select 1 from public.workout_templates where id=standalone)
    or exists(select 1 from public.program_workout_templates where template_id=standalone)
    or exists(select 1 from public.workout_blocks where template_id=standalone) then
    raise exception 'La receta purgada dejó contenido o catálogo.'; end if;
  begin perform public.save_admin_guided_work(json_work,2,state||jsonb_build_object('sessions',jsonb_build_array(standalone)));
    raise exception 'Guarda una referencia a sesión purgada.';
  exception when sqlstate '22023' then null; end;

  -- El historial de entrenamientos nunca se elimina al purgar una receta.
  historical:=public.create_admin_workout_draft(null,payload);
  perform public.publish_admin_workout_draft(historical);
  perform set_config('request.jwt.claim.sub',athlete::text,true);
  perform set_config('request.jwt.claims','{"aal":"aal1"}',true);
  execution_id:=public.start_workout_execution(historical);
  perform set_config('request.jwt.claim.sub',a::text,true);
  perform set_config('request.jwt.claims','{"aal":"aal2"}',true);
  perform public.trash_admin_session(historical);
  select trashed_at into stamp from public.workout_templates where id=historical;
  begin perform public.purge_admin_trash('session',historical,stamp); raise exception 'Borra una ejecución.';
  exception when sqlstate 'P0001' then
    if SQLERRM not like 'La sesión tiene entrenamientos%' then raise; end if;
  end;
  if not exists(select 1 from public.workout_executions where id=execution_id and template_id=historical) then
    raise exception 'Se perdió el entrenamiento.'; end if;
  perform set_config('request.jwt.claims','{"aal":"aal1"}',true);
  begin perform public.list_admin_session_trash(); raise exception 'La papelera no exige MFA.';
  exception when insufficient_privilege then null; end;
  begin perform public.purge_admin_trash('session',historical,stamp); raise exception 'Purga sin MFA.';
  exception when insufficient_privilege then null; end;
  perform set_config('request.jwt.claim.sub',athlete::text,true);
  perform set_config('request.jwt.claims','{"aal":"aal2"}',true);
  -- La nueva política conserva el borrado de recetas personales propias.
  insert into public.workout_templates(name,origin,owner_user_id)
    values('Personal temporal','user',athlete) returning id into personal;
  delete from public.workout_templates where id=personal;
  if exists(select 1 from public.workout_templates where id=personal) then
    raise exception 'La protección oficial impide borrar una receta personal propia.'; end if;
  begin perform public.restore_admin_session(historical,stamp); raise exception 'Deportista recupera una sesión oficial.';
  exception when insufficient_privilege then null; end;
end $$;
rollback;
