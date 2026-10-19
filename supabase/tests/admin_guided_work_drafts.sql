begin;
do $$
declare admin_id uuid; other_id uuid:=gen_random_uuid(); athlete uuid:=gen_random_uuid();
  work uuid:=gen_random_uuid(); other_work uuid:=gen_random_uuid(); abandoned uuid:=gen_random_uuid();
  raw jsonb:='{"schema":1,"name":"Sin terminar","phases":[{"weeks":"abc","pending":["sesion-pendiente"]}]}'::jsonb;
  saved jsonb; retry jsonb; result uuid; session uuid; exercise uuid; content jsonb; revision uuid;
begin
  select user_id into strict admin_id from public.admin_permissions limit 1;
  insert into auth.users(id,email) values(other_id,other_id||'@draft.invalid'),(athlete,athlete||'@draft.invalid');
  insert into public.admin_permissions(user_id) values(other_id);
  if has_function_privilege('anon','public.save_admin_guided_work(uuid,bigint,jsonb,uuid)','execute')
    or has_table_privilege('anon','public.admin_guided_work_drafts','select') then
    raise exception 'Acceso anónimo a borradores.';
  end if;
  select id into exercise from public.exercises where is_public limit 1;
  perform set_config('request.jwt.claim.sub',admin_id::text,true);
  set local role authenticated;
  saved:=public.save_admin_guided_work(work,0,raw);
  retry:=public.save_admin_guided_work(work,0,raw);
  if saved<>retry or saved->'state'<>raw then raise exception 'Reintento duplicado o pérdida del texto incompleto.'; end if;
  saved:=public.save_admin_guided_work(work,1,jsonb_set(raw,'{name}','"Más trabajo"'));
  if saved->>'revision'<>'2' then raise exception 'No incrementa revisión.'; end if;
  begin
    perform public.save_admin_guided_work(work,1,raw); raise exception 'Una pestaña obsoleta sobrescribe.';
  exception when serialization_failure then null; end;
  begin
    update public.admin_guided_work_drafts set state='{}' where id=work; raise exception 'Escritura directa habilitada.';
  exception when insufficient_privilege then null; end;
  begin
    perform public.finalize_admin_guided_work(work,2,'{"name":"Incompleto","mode":"guide","phases":[]}', '{}');
    raise exception 'Permite finalizar sin sesiones.';
  exception when sqlstate '22023' then null; end;
  if (select finalized_program_id from public.admin_guided_work_drafts where id=work) is not null then
    raise exception 'El fallo dejó el borrador cerrado.';
  end if;

  session:=public.create_admin_workout_draft(null,jsonb_build_object('name','Sesión temporal de recuperación','blocks',jsonb_build_array(
    jsonb_build_object('name','Trabajo','format','straight_sets','rounds',1,'rest_after_seconds',0,'exercises',jsonb_build_array(
      jsonb_build_object('exercise_id',exercise,'sets',jsonb_build_array(jsonb_build_object('target_reps',8,'rest_after_seconds',90))))))));
  perform public.publish_admin_workout_draft(session);
  content:=jsonb_build_object('name','Programa temporal recuperable','mode','guide','phases',jsonb_build_array(
    jsonb_build_object('name','Trabajo','sessions',jsonb_build_array(jsonb_build_object('template_id',session,'name','Sesión','rest','{}'::jsonb)))));
  result:=public.finalize_admin_guided_work(work,2,content,'{}');
  if public.finalize_admin_guided_work(work,2,content,'{}')<>result then raise exception 'Duplica al reintentar finalización.'; end if;
  begin
    perform public.finalize_admin_guided_work(work,2,jsonb_set(content,'{name}','"Otra petición"'),'{}');
    raise exception 'Permite cambiar una operación cerrada.';
  exception when serialization_failure then null; end;
  perform public.set_guided_program_status(result,'published');
  saved:=public.save_admin_guided_work(other_work,0,raw,result);
  revision:=public.finalize_admin_guided_work(other_work,1,content,'{}');
  if revision=result or public.finalize_admin_guided_work(other_work,1,content,'{}')<>revision
    or (select count(*) from public.guided_programs where family_id=result)<>2 then
    raise exception 'El reintento de revisión duplica versiones.';
  end if;
  if (select status from public.guided_programs where id=result)<>'published' then raise exception 'Modifica publicación previa.'; end if;
  perform public.save_admin_guided_work(abandoned,0,raw);
  perform public.discard_admin_guided_work(abandoned,1);
  perform public.discard_admin_guided_work(abandoned,1);
  begin
    perform public.save_admin_guided_work(abandoned,1,raw); raise exception 'Reabre trabajo descartado.';
  exception when serialization_failure then null; end;

  -- Otro administrador no puede leer, guardar, finalizar ni descartar trabajo ajeno.
  perform set_config('request.jwt.claim.sub',other_id::text,true);
  if exists(select 1 from public.admin_guided_work_drafts where id=work) then raise exception 'Filtra trabajo entre administradores.'; end if;
  begin perform public.save_admin_guided_work(work,2,raw); raise exception 'Admin modifica trabajo ajeno.';
    exception when insufficient_privilege then null; end;
  begin perform public.finalize_admin_guided_work(work,2,content,'{}'); raise exception 'Admin finaliza trabajo ajeno.';
    exception when insufficient_privilege then null; end;
  begin perform public.discard_admin_guided_work(work,2); raise exception 'Admin descarta trabajo ajeno.';
    exception when insufficient_privilege then null; end;
  perform set_config('request.jwt.claim.sub',athlete::text,true);
  if exists(select 1 from public.admin_guided_work_drafts) then raise exception 'Deportista ve borradores privados.'; end if;
  begin perform public.save_admin_guided_work(gen_random_uuid(),0,raw); raise exception 'Deportista crea trabajo admin.';
    exception when insufficient_privilege then null; end;
  -- Retirar permisos revoca la lectura incluso manteniendo la identidad autenticada.
  reset role;
  delete from public.admin_permissions where user_id=other_id;
  perform set_config('request.jwt.claim.sub',other_id::text,true);
  set local role authenticated;
  begin perform public.save_admin_guided_work(gen_random_uuid(),0,raw); raise exception 'Permiso retirado sigue activo.';
    exception when insufficient_privilege then null; end;
end $$;
rollback;
