-- Solo fixtures de evidencias: nunca se restaura Dev durante estas pruebas.
begin;
do $$
declare admin_id uuid; athlete uuid:=gen_random_uuid(); info jsonb; before_count integer;
begin
  select user_id into strict admin_id from public.admin_permissions limit 1;
  if has_function_privilege('anon','public.admin_recovery_diagnostics()','execute') or
    has_function_privilege('anon','public.report_admin_client_error(text,text,text)','execute') then
    raise exception 'Operaciones expuestas a anon.';
  end if;
  insert into auth.users(id,email) values(athlete,athlete||'@recovery.invalid');
  perform set_config('request.jwt.claim.sub',athlete::text,true);
  perform set_config('request.jwt.claims','{"aal":"aal2"}',true);
  set local role authenticated;
  begin perform public.admin_recovery_diagnostics(); raise exception 'Deportista consulta copias/errores.';
  exception when insufficient_privilege then null; end;
  begin perform public.report_admin_client_error('framework_error','admin','local'); raise exception 'Deportista envía eventos admin.';
  exception when insufficient_privilege then null; end;
  perform set_config('request.jwt.claim.sub',admin_id::text,true);
  begin perform 1 from admin_ops_private.backup_runs; raise exception 'Acceso directo a copias.';
  exception when insufficient_privilege then null; end;
  begin perform 1 from admin_ops_private.service_events; raise exception 'Acceso directo a errores.';
  exception when insufficient_privilege then null; end;
  begin perform 1 from admin_ops_private.log_collections; raise exception 'Acceso directo a recogida.';
  exception when insufficient_privilege then null; end;
  begin perform public.report_admin_client_error('password=secret','admin','local'); raise exception 'Acepta texto libre.';
  exception when invalid_parameter_value then null; end;
  begin perform public.report_admin_client_error('framework_error','private@example.com','local'); raise exception 'Acepta datos personales como contexto.';
  exception when invalid_parameter_value then null; end;
  reset role;
  -- Prueba el límite de manera aislada, sin depender de eventos reales previos.
  delete from admin_ops_private.service_events where source='admin';
  set local role authenticated;
  for i in 1..20 loop perform public.report_admin_client_error('framework_error','operations',repeat('a',40)); end loop;
  reset role;
  if (select count(*) from admin_ops_private.service_events where source='admin')<>10 then
    raise exception 'No aplica el límite de notificación.'; end if;
  insert into admin_ops_private.backup_runs(run_id,started_at,finished_at,status,artifact_id,artifact_name,
    archive_sha256,archive_bytes,storage_objects,restore_verified_at,expires_at)
    values('123456789-1',now(),now(),'verified',42,'fixture',repeat('a',64),128,1,now(),now()+interval '7 days');
  insert into admin_ops_private.log_collections values('fixture',now(),now()-interval '1 hour',now(),'success',false,0);
  set local role authenticated;
  info:=public.admin_recovery_diagnostics();
  if not exists(select 1 from jsonb_array_elements(info->'backups') b where b->>'run_id'='123456789-1') or
    (info->'collection'->>'status')<>'success' then raise exception 'No expone evidencia verificada.'; end if;
  if public.admin_operations_status()->>'backups'<>'verified' or public.admin_operations_status()->>'service_logs'<>'collected' then
    raise exception 'El resumen conserva estados ficticios.'; end if;
  reset role;
  if exists(select 1 from public.admin_security_requirements where user_id=admin_id) then
    perform set_config('request.jwt.claims','{"aal":"aal1"}',true);
    set local role authenticated;
    begin perform public.admin_recovery_diagnostics(); raise exception 'Evita MFA al consultar copias.';
    exception when insufficient_privilege then null; end;
    begin perform public.report_admin_client_error('framework_error','admin','local'); raise exception 'Evita MFA al informar.';
    exception when insufficient_privilege then null; end;
    reset role;
  end if;
end $$;
select 'dev_recovery_observability: OK' as result;
rollback;
