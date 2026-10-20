-- Historial, recuperación idempotente y permisos: todas las fixtures se revierten.
begin;
do $$
declare admin_id uuid; athlete uuid:=gen_random_uuid(); exercise uuid; original uuid; restored uuid;
  result uuid; program uuid; event_id bigint; program_event bigint; request uuid:=gen_random_uuid();
  payload jsonb; content jsonb; snapshot jsonb;
begin
  select user_id into strict admin_id from public.admin_permissions limit 1;
  select id into strict exercise from public.exercises where origin='system' and is_public limit 1;
  if has_function_privilege('anon','public.admin_editorial_history(text,bigint)','execute')
    or has_function_privilege('anon','public.admin_catalog_quality()','execute')
    or has_function_privilege('anon','public.admin_account_support(uuid)','execute')
    or has_function_privilege('anon','public.restore_admin_editorial_event(bigint,uuid,boolean)','execute') then
    raise exception 'Operaciones expuestas a anon.';
  end if;
  insert into auth.users(id,email) values(athlete,athlete||'@operations.invalid');
  perform set_config('request.jwt.claim.sub',athlete::text,true);
  perform set_config('request.jwt.claims','{"aal":"aal2"}',true);
  set local role authenticated;
  begin perform public.admin_catalog_quality(); raise exception 'Acepta deportista.';
  exception when insufficient_privilege then null; end;
  begin perform public.admin_editorial_history(); raise exception 'Expone historial a deportista.';
  exception when insufficient_privilege then null; end;
  begin perform public.admin_account_support(admin_id); raise exception 'Expone soporte a deportista.';
  exception when insufficient_privilege then null; end;
  begin perform public.admin_operations_status(); raise exception 'Expone operaciones a deportista.';
  exception when insufficient_privilege then null; end;
  reset role;
  perform set_config('request.jwt.claim.sub',admin_id::text,true);
  set local role authenticated;
  begin perform 1 from admin_ops_private.editorial_events; raise exception 'Expone tabla de auditoría.';
  exception when insufficient_privilege then null; end;
  payload:=jsonb_build_object('name','Fixture historial','blocks',jsonb_build_array(jsonb_build_object(
    'name','Fuerza','format','straight_sets','rounds',1,'rest_after_seconds',0,
    'exercises',jsonb_build_array(jsonb_build_object('exercise_id',exercise,'sets',jsonb_build_array(
      jsonb_build_object('target_reps',12,'target_rir',2,'rest_after_seconds',60)))))));
  original:=public.create_admin_workout_draft(null,payload);
  set constraints all immediate;
  reset role;
  -- Aísla el cambio respecto a la creación de la fixture en esta transacción.
  delete from admin_ops_private.editorial_events where resource_id=original;
  set local role authenticated;
  result:=public.revise_admin_workout(original,jsonb_set(payload,'{blocks,0,exercises,0,sets,0,target_reps}','15'));
  if result<>original then raise exception 'La auditoría rompe la edición del borrador.'; end if;
  reset role;
  select id into strict event_id from admin_ops_private.editorial_events where resource_id=original;
  if (select before_data#>>'{payload,blocks,0,exercises,0,sets,0,target_reps}' from admin_ops_private.editorial_events where id=event_id)<>'12'
    or (select after_data#>>'{payload,blocks,0,exercises,0,sets,0,target_reps}' from admin_ops_private.editorial_events where id=event_id)<>'15' then
    raise exception 'La auditoría no conserva receta anterior y posterior.';
  end if;
  set local role authenticated;
  snapshot:=public.admin_editorial_event(event_id);
  if snapshot->>'resource_type'<>'session' then raise exception 'Detalle de historial inválido.'; end if;
  restored:=public.restore_admin_editorial_event(event_id,request,true);
  if restored=original or public.restore_admin_editorial_event(event_id,request,true)<>restored then
    raise exception 'La recuperación duplica o sobrescribe la fuente.';
  end if;
  begin perform public.restore_admin_editorial_event(event_id,request,false); raise exception 'Acepta otra petición con igual clave.';
  exception when sqlstate '22023' then null; end;
  content:=jsonb_build_object('name','Fixture programa histórico','mode','guide','phases',jsonb_build_array(
    jsonb_build_object('name','Base','sessions',jsonb_build_array(jsonb_build_object('template_id',original,'name','Sesión')))));
  program:=public.save_guided_program(content);
  reset role;
  select id into strict program_event from admin_ops_private.editorial_events where resource_id=program;
  set local role authenticated;
  result:=public.restore_admin_editorial_event(program_event,gen_random_uuid(),false);
  if result=program then raise exception 'Recuperar programa modifica el original.'; end if;
  if (public.admin_operations_status()->>'database')<>'reachable' or
    (public.admin_operations_status()->>'backups') not in ('unverified','verified') then raise exception 'Estado operativo inválido.'; end if;
  if jsonb_typeof(public.admin_catalog_quality())<>'array' then raise exception 'Calidad inválida.'; end if;
  reset role;
  if (select status from public.workout_templates where id=restored)<>'draft' or
    (select s.target_reps from public.workout_sets s join public.workout_items i on i.id=s.item_id
      join public.workout_blocks b on b.id=i.block_id where b.template_id=restored limit 1)<>12 then
    raise exception 'La recuperación no reconstruye un borrador de la receta anterior.';
  end if;
  if (select s.target_reps from public.workout_sets s join public.workout_items i on i.id=s.item_id
      join public.workout_blocks b on b.id=i.block_id where b.template_id=original limit 1)<>15 then
    raise exception 'La recuperación ha cambiado la fuente.';
  end if;
  update public.workout_templates set status='archived' where id=original;
  set local role authenticated;
  if not exists(select 1 from jsonb_array_elements(public.admin_catalog_quality()) q
      where q->>'resource_id'=program::text and q->>'code'='unavailable_session') then
    raise exception 'No detecta la referencia retirada.';
  end if;
  reset role;
end $$;
do $$
declare manager uuid:=gen_random_uuid(); editor uuid:=gen_random_uuid(); private_id uuid:=gen_random_uuid();
  admin_id uuid; official uuid; exercise uuid; data jsonb;
begin
  select user_id into strict admin_id from public.admin_permissions limit 1;
  insert into auth.users(id,email) values(manager,manager||'@ops-manager.invalid'),(editor,editor||'@ops-editor.invalid');
  insert into public.admin_permissions(user_id,reason) values(manager,'Fixture responsable'),(editor,'Fixture contenido');
  update public.commercial_access_settings set account_manager_user_id=manager;
  perform set_config('request.jwt.claim.sub',editor::text,true);
  set local role authenticated;
  if not public.is_admin() or public.can_manage_pro_accounts() then raise exception 'Fixture de permisos incorrecta.'; end if;
  begin perform public.admin_account_support(manager); raise exception 'Editor de contenido accede a soporte.';
  exception when insufficient_privilege then null; end;
  perform set_config('request.jwt.claim.sub',manager::text,true);
  data:=public.admin_account_support(editor);
  if jsonb_typeof(data->'programs')<>'array' or not(data?'checked_at') then raise exception 'Diagnóstico de responsable incorrecto.'; end if;
  reset role;
  -- El historial no debe contener recetas personales del deportista.
  insert into public.workout_templates(id,name,origin,owner_user_id,visibility,status,version,family_id)
    values(private_id,'Fixture privada','user',editor,'private','draft',1,private_id);
  if exists(select 1 from admin_ops_private.editorial_events where resource_id=private_id) then
    raise exception 'Se ha auditado contenido personal.';
  end if;
  -- La captura diferida incluye los bloques creados después de la plantilla.
  set constraints all deferred;
  perform set_config('request.jwt.claim.sub',manager::text,true);
  select id into strict exercise from public.exercises where origin='system' and is_public limit 1;
  set local role authenticated;
  official:=public.create_admin_workout_draft(null,jsonb_build_object('name','Fixture diferida','blocks',jsonb_build_array(
    jsonb_build_object('name','Trabajo','format','straight_sets','exercises',jsonb_build_array(
      jsonb_build_object('exercise_id',exercise,'sets',jsonb_build_array(jsonb_build_object('target_reps',8,'rest_after_seconds',60))))))));
  set constraints all immediate;
  reset role;
  if (select after_data#>>'{payload,blocks,0,exercises,0,sets,0,target_reps}' from admin_ops_private.editorial_events
      where resource_id=official)<>'8' then raise exception 'La captura diferida pierde la receta.'; end if;
  if exists(select 1 from public.admin_security_requirements where user_id=admin_id) then
    perform set_config('request.jwt.claim.sub',admin_id::text,true);
    perform set_config('request.jwt.claims','{"aal":"aal1"}',true);
    set local role authenticated;
    begin perform public.admin_editorial_history(); raise exception 'El historial evita el segundo factor.';
    exception when insufficient_privilege then null; end;
    reset role;
  end if;
end $$;
do $$
declare admin_id uuid; exercise uuid; session_id uuid; root uuid; revision_id uuid; v_event_id bigint;
  payload jsonb; content jsonb; special jsonb; fixture_snapshot jsonb;
begin
  select user_id into strict admin_id from public.admin_permissions limit 1;
  select id into strict exercise from public.exercises where origin='system' and is_public limit 1;
  perform set_config('request.jwt.claim.sub',admin_id::text,true);
  perform set_config('request.jwt.claims','{"aal":"aal2"}',true);
  set local role authenticated;
  payload:=jsonb_build_object('name','Fixture portada heredada','blocks',jsonb_build_array(jsonb_build_object(
    'name','Trabajo','format','straight_sets','exercises',jsonb_build_array(jsonb_build_object(
      'exercise_id',exercise,'sets',jsonb_build_array(jsonb_build_object('target_reps',8,'rest_after_seconds',60)))))));
  session_id:=public.create_admin_workout_draft(null,payload);
  content:=jsonb_build_object('name','Fixture familia con portada','mode','guide','phases',jsonb_build_array(
    jsonb_build_object('name','Rutina','sessions',jsonb_build_array(jsonb_build_object('name','Trabajo','template_id',session_id)))));
  root:=public.save_guided_program(content);
  perform public.set_guided_program_status(root,'published');
  revision_id:=public.save_guided_program(content,root);
  reset role;
  insert into public.guided_program_covers(program_id,card_image_path,header_image_path,revision)
    values(root,'guided/'||root||'/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa/card.jpg',
      'guided/'||root||'/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa/header.jpg',1);
  set local role authenticated;
  if exists(select 1 from jsonb_array_elements(public.admin_catalog_quality()) q
      where q->>'resource_id' in (root::text,revision_id::text) and q->>'code'='missing_cover') then
    raise exception 'La revisión pierde la portada compartida de su familia.';
  end if;
  reset role;
  -- Las recetas históricas con campos no soportados no deben perderlos en silencio.
  fixture_snapshot:=admin_ops_private.snapshot('session',session_id);
  foreach special in array array[
    jsonb_set(fixture_snapshot,'{payload,blocks,0,exercises,0,notes}','"Indicaciones históricas"'),
    jsonb_set(fixture_snapshot,'{payload,blocks,0,exercises,0,sets,0,target_rpe}','7'),
    jsonb_set(fixture_snapshot,'{payload,blocks,0,exercises,0,sets,0,performance_prescription}','{"kind":"fixture"}')
  ] loop
    insert into admin_ops_private.editorial_events(transaction_id,resource_type,resource_id,after_data,finalized)
      values(txid_current(),'session',gen_random_uuid(),special,true) returning id into v_event_id;
    set local role authenticated;
    begin
      perform public.restore_admin_editorial_event(v_event_id,gen_random_uuid(),false);
      raise exception 'La recuperación pierde campos especiales.';
    exception when sqlstate '22023' then null; end;
    reset role;
    if exists(select 1 from admin_ops_private.restorations r where r.event_id=v_event_id) then
      raise exception 'La recuperación rechazada deja una operación parcial.';
    end if;
  end loop;
end $$;
select 'admin_editorial_operations: OK' result;
rollback;
