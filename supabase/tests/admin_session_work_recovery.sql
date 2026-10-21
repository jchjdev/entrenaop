begin;
set local statement_timeout='60s';
do $$
declare owner uuid:=gen_random_uuid(); other uuid:=gen_random_uuid(); athlete uuid:=gen_random_uuid();
  work_id uuid:=gen_random_uuid(); child_id uuid:=gen_random_uuid(); parent_id uuid:=gen_random_uuid();
  phase_id uuid:=gen_random_uuid(); position_id uuid:=gen_random_uuid(); exercise uuid;
  rejected_work uuid:=gen_random_uuid(); source_work uuid:=gen_random_uuid(); source_origin jsonb;
  origin jsonb; raw jsonb; recipe jsonb; parent_state jsonb; saved jsonb; result uuid;
begin
  insert into auth.users(id,email) values(owner,owner||'@session.invalid'),(other,other||'@session.invalid'),(athlete,athlete||'@session.invalid');
  insert into public.admin_permissions(user_id) values(owner),(other);
  insert into auth.mfa_factors(id,user_id,factor_type,status,created_at,updated_at) values
    (gen_random_uuid(),owner,'totp','verified',now(),now()),(gen_random_uuid(),other,'totp','verified',now(),now());
  select id into exercise from public.exercises where is_public and id<>'20000000-0000-4000-8000-000000000004' limit 1;
  origin:='{"baseId":null,"programId":null,"parentWorkId":null,"phaseId":null,"positionId":null,"duplicate":false}';
  raw:='{"schema":1,"editor":{"schema":1,"nameText":"  Sesión incompleta  ","running":false,"segments":[],"blocks":[]},"context":{"showInLibrary":false}}';
  recipe:=jsonb_build_object('name','Sesión de prueba','blocks',jsonb_build_array(jsonb_build_object('name','Fuerza','format','straight_sets','rounds',1,'rest_after_seconds',0,
    'exercises',jsonb_build_array(jsonb_build_object('exercise_id',exercise,'sets',jsonb_build_array(jsonb_build_object('target_reps',10,'target_rir',2,'rest_after_seconds',60)))))));
  if has_function_privilege('anon','public.list_admin_session_work(uuid)','execute')
    or has_table_privilege('authenticated','admin_work_private.session_work','select') then
    raise exception 'Exposición directa de trabajos'; end if;
  perform set_config('request.jwt.claim.sub',owner::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',owner,'role','authenticated','aal','aal1')::text,true);
  set local role authenticated;
  begin perform public.list_admin_session_work(owner); raise exception 'Acepta AAL1'; exception when insufficient_privilege then null; end;
  perform set_config('request.jwt.claims',jsonb_build_object('sub',owner,'role','authenticated','aal','aal2')::text,true);
  saved:=public.save_admin_session_work(owner,work_id,0,origin,raw);
  if saved->'state'<>raw or public.save_admin_session_work(owner,work_id,0,origin,raw)<>saved then
    raise exception 'Pierde raw o duplica el primer guardado'; end if;
  saved:=public.save_admin_session_work(owner,work_id,1,origin,jsonb_set(raw,'{editor,nameText}','"Segunda edición"'));
  begin perform public.save_admin_session_work(owner,work_id,1,origin,raw); raise exception 'CAS obsoleto sobrescribe'; exception when serialization_failure then null; end;
  saved:=public.save_admin_session_work(owner,work_id,2,origin,raw||jsonb_build_object('intent',recipe));
  begin perform public.save_admin_session_work(owner,work_id,3,origin,raw); raise exception 'Borra intención incierta'; exception when serialization_failure then null; end;
  result:=public.finalize_admin_session_work(owner,work_id,3);
  if public.finalize_admin_session_work(owner,work_id,3)<>result then raise exception 'Duplica al reintentar finalización'; end if;
  if (public.get_admin_session_work(owner,work_id)->>'result_id')::uuid<>result then raise exception 'No recupera recibo tras reinicio'; end if;
  if (select show_in_library from public.workout_templates where id=result) then raise exception 'Pierde visibilidad'; end if;
  begin perform public.reopen_admin_session_work(owner,work_id,3); raise exception 'Reabre resultado confirmado'; exception when serialization_failure then null; end;
  source_origin:=origin||jsonb_build_object('baseId',result);
  perform public.save_admin_session_work(owner,source_work,0,source_origin,raw);
  reset role;
  begin delete from public.workout_templates where id=result; raise exception 'Borra origen con trabajo abierto'; exception when invalid_parameter_value then null; end;
  set local role authenticated;
  perform public.discard_admin_session_work(owner,source_work,1);
  perform public.discard_admin_session_work(owner,source_work,1);
  perform public.save_admin_session_work(owner,rejected_work,0,origin,raw||'{"intent":{"name":"","blocks":[]}}'::jsonb);
  begin perform public.finalize_admin_session_work(owner,rejected_work,1); raise exception 'Finaliza receta inválida'; exception when invalid_parameter_value then null; end;
  saved:=public.reopen_admin_session_work(owner,rejected_work,1);
  if saved->'state' ? 'intent' or saved->>'revision'<>'2' or public.reopen_admin_session_work(owner,rejected_work,1)<>saved then
    raise exception 'No recupera edición tras rechazo definitivo'; end if;
  perform public.discard_admin_session_work(owner,rejected_work,2);

  parent_state:=jsonb_build_object('schema',1,'name','Programa incompleto','phases',jsonb_build_array(
    jsonb_build_object('phaseId',phase_id,'sessions','[]'::jsonb,'sessionWorks','{}'::jsonb)));
  perform public.save_admin_guided_work(parent_id,0,parent_state);
  origin:=origin||jsonb_build_object('parentWorkId',parent_id,'phaseId',phase_id,'positionId',position_id);
  parent_state:=jsonb_set(parent_state,array['phases','0','sessionWorks',child_id::text],origin);
  perform public.save_admin_guided_work(parent_id,1,parent_state);
  perform public.save_admin_session_work(owner,child_id,0,origin,raw);
  reset role;
  begin delete from public.admin_guided_work_drafts where id=parent_id; raise exception 'Borra padre con hijo abierto'; exception when invalid_parameter_value then null; end;
  set local role authenticated;
  begin
    perform public.save_admin_guided_work(parent_id,2,jsonb_set(parent_state,'{phases,0,sessionWorks}','{}'));
    raise exception 'Editor viejo elimina la referencia del hijo';
  exception when serialization_failure then null; end;
  perform public.save_admin_session_work(owner,child_id,1,origin,raw||jsonb_build_object('intent',recipe));
  result:=public.finalize_admin_session_work(owner,child_id,2);
  begin
    perform public.save_admin_guided_work(parent_id,2,jsonb_set(parent_state,'{phases,0,sessionWorks}','{}'));
    raise exception 'Pierde hijo finalizado sin enlace';
  exception when serialization_failure then null; end;
  parent_state:=jsonb_set(parent_state,'{phases,0,sessions}',jsonb_build_array(jsonb_build_object('id',result,'positionId',position_id)));
  parent_state:=jsonb_set(parent_state,'{phases,0,sessionWorks}','{}');
  perform public.save_admin_guided_work(parent_id,2,parent_state);
  if exists(select 1 from jsonb_array_elements(public.list_admin_session_work(owner)) w where w->>'id'=child_id::text) then
    raise exception 'Recibo enlazado sigue pendiente'; end if;

  perform set_config('request.jwt.claim.sub',other::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',other,'role','authenticated','aal','aal2')::text,true);
  if public.get_admin_session_work(other,work_id) is not null then raise exception 'Otro ADMIN lee trabajo ajeno'; end if;
  begin perform public.get_admin_session_work(owner,work_id); raise exception 'Ignora propietario esperado'; exception when insufficient_privilege then null; end;
  begin perform public.finalize_admin_session_work(other,work_id,3); raise exception 'Otro ADMIN finaliza ajeno'; exception when insufficient_privilege then null; end;
  perform set_config('request.jwt.claim.sub',athlete::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',athlete,'role','authenticated','aal','aal2')::text,true);
  begin perform public.list_admin_session_work(athlete); raise exception 'Deportista lee ADMIN'; exception when insufficient_privilege then null; end;
end $$;
rollback;
