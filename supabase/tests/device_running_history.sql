-- Solo datos sintéticos y permisos temporales; ejecutar contra Dev y terminar con ROLLBACK.
begin;
select set_config('test.history_a',gen_random_uuid()::text,true);
select set_config('test.history_b',gen_random_uuid()::text,true);
select set_config('test.history_admin',gen_random_uuid()::text,true);
insert into auth.users(id,email) select current_setting(k)::uuid,current_setting(k)||'@history.invalid'
 from unnest(array['test.history_a','test.history_b','test.history_admin']) k;
insert into public.admin_permissions(user_id,reason)
 values(current_setting('test.history_admin')::uuid,'Fixture transaccional de aislamiento de salud');
-- Se abre SELECT solo dentro de esta transacción para contrastar las políticas RLS.
grant usage on schema device_private to authenticated;
grant select on all tables in schema device_private to authenticated;
set local role authenticated;

do $$
declare
 a uuid:=current_setting('test.history_a')::uuid; b uuid:=current_setting('test.history_b')::uuid;
 adm uuid:=current_setting('test.history_admin')::uuid; c uuid; cb uuid; ch uuid; op uuid:=gen_random_uuid();
 fresh_op uuid:=gen_random_uuid(); clear_op uuid:=gen_random_uuid(); r jsonb; first_receipt jsonb;
 base jsonb; newer jsonb; batch jsonb; head_a text; head_b text; initial_bytes bigint; initial_receipts integer;
 next_generation integer; v_limit bigint; row_count integer;
begin
 perform set_config('request.jwt.claim.sub',a::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',a,'role','authenticated')::text,true);
 r:=public.open_running_health_connection(a,'apple_health'); c:=(r->>'id')::uuid;
 if (public.open_running_health_connection(a,'apple_health')->>'id')::uuid<>c then raise exception 'Namespace inestable'; end if;
 base:=jsonb_build_object('external_id','AAAAAAAA-0000-0000-0000-000000000001','source_revision','fixture-A',
  'normalizer_version',1,'started_at','2026-01-07T11:29:59.999877Z','ended_at','2026-01-07T12:00:00.000000Z',
  'elapsed_micros',1800000123,'timer_micros',1700812345,'distance_meters',5000.125,
  'writer_application','com.garmin.connect.fixture','expected_snapshot_hash',null);
 first_receipt:=public.save_running_health_history(a,c,0,op,jsonb_build_array(base));
 if first_receipt->>'inserted'<>'1' then raise exception 'No inserta'; end if;
 select logical_bytes,receipt_count into initial_bytes,initial_receipts from device_private.history_limits where owner_id=a;
 if public.save_running_health_history(a,c,0,op,jsonb_build_array(base))<>first_receipt then raise exception 'Replay distinto'; end if;
 if exists(select 1 from device_private.history_limits where owner_id=a and
  (logical_bytes<>initial_bytes or receipt_count<>initial_receipts)) then raise exception 'Replay consume cuota'; end if;
 r:=public.list_running_health_history(a,c); head_a:=r->'items'->0->>'snapshot_hash';
 if r->'items'->0->>'external_id'<>'aaaaaaaa-0000-0000-0000-000000000001' or
  r->'items'->0->>'elapsed_micros'<>'1800000123' or r->'items'->0->>'timer_micros'<>'1700812345' or
  (r->'items'->0->>'distance_meters')::double precision<>5000.125 or
  r->'items'->0->'time_zone_id'<>'null'::jsonb then raise exception 'Pierde precisión/ausencia'; end if;
 perform set_config('TimeZone','Europe/Madrid',true);
 r:=public.save_running_health_history(a,c,0,gen_random_uuid(),jsonb_build_array(base));
 if r->>'unchanged'<>'1' then raise exception 'La zona SQL cambia la huella'; end if;
 perform set_config('TimeZone','UTC',true);
 begin
  perform public.save_running_health_history(a,c,0,op,jsonb_build_array(base||jsonb_build_object('distance_meters',5100)));
  raise exception 'Acepta operationId distinto';
 exception when invalid_parameter_value then if sqlerrm<>'operation_reused' then raise; end if; end;
 begin
  perform public.save_running_health_history(a,c,0,gen_random_uuid(),jsonb_build_array(base||jsonb_build_object('distance_meters',5100)));
  raise exception 'Acepta colisión de revisión';
 exception when invalid_parameter_value then if sqlerrm<>'revision_collision' then raise; end if; end;
 newer:=base||jsonb_build_object('source_revision','fixture-B','distance_meters',5200.5,'expected_snapshot_hash',head_a);
 r:=public.save_running_health_history(a,c,0,gen_random_uuid(),jsonb_build_array(newer));
 if r->>'updated'<>'1' then raise exception 'No actualiza por revisión explícita'; end if;
 r:=public.list_running_health_history(a,c); head_b:=r->'items'->0->>'snapshot_hash';
 if head_b=head_a or (select count(*) from device_private.running_snapshots where owner_id=a)<>2 then raise exception 'No conserva revisión'; end if;
 if public.save_running_health_history(a,c,0,op,jsonb_build_array(base))<>first_receipt or
  public.list_running_health_history(a,c)->'items'->0->>'snapshot_hash'<>head_b then raise exception 'Replay rebaja head'; end if;
 begin
  perform public.save_running_health_history(a,c,0,gen_random_uuid(),jsonb_build_array(base||jsonb_build_object('expected_snapshot_hash',head_b)));
  raise exception 'Relectura A restaura histórico tras B';
 exception when serialization_failure then if sqlerrm<>'historical_revision' then raise; end if; end;
 begin
  perform public.save_running_health_history(a,c,0,gen_random_uuid(),jsonb_build_array(newer||jsonb_build_object('source_revision','fixture-C','distance_meters',5300)));
  raise exception 'No verifica expected head';
 exception when serialization_failure then if sqlerrm<>'history_conflict' then raise; end if; end;
 -- Un registro válido seguido de otro inválido no deja un guardado parcial.
 begin
  perform public.save_running_health_history(a,c,0,gen_random_uuid(),jsonb_build_array(
   base||jsonb_build_object('external_id','aaaaaaaa-0000-0000-0000-000000000002'),base||jsonb_build_object('gps','no permitido')));
  raise exception 'Acepta campo no permitido';
 exception when invalid_parameter_value then if sqlerrm<>'invalid_running_history' then raise; end if; end;
 if (select count(*) from device_private.running_snapshots where owner_id=a)<>2 then raise exception 'Lote parcial'; end if;
 foreach batch in array array[
  jsonb_build_array(base||jsonb_build_object('elapsed_micros','1800000123')),
  jsonb_build_array(base||jsonb_build_object('timer_micros',-1)),
  jsonb_build_array(base||jsonb_build_object('distance_meters','NaN')),
  jsonb_build_array(base||jsonb_build_object('start_offset_seconds',86400)),
  jsonb_build_array(base||jsonb_build_object('writer_application',repeat('x',257))),
  jsonb_build_array(base||jsonb_build_object('owner_id',b)),
  jsonb_build_array(base,base||jsonb_build_object('external_id','aaaaaaaa-0000-0000-0000-000000000001'))
 ] loop
  begin
   perform public.save_running_health_history(a,c,0,gen_random_uuid(),batch);
   raise exception 'Acepta tipos o sobre inválidos';
  exception when invalid_parameter_value then if sqlerrm<>'invalid_running_history' then raise; end if; end;
 end loop;
 select jsonb_agg(base) into batch from generate_series(1,201);
 begin
  perform public.save_running_health_history(a,c,0,gen_random_uuid(),batch);raise exception 'Acepta más de 200';
 exception when raise_exception then if sqlerrm<>'history_limit' then raise; end if; end;
 -- Cuenta B y administrador carecen de acceso a conexiones/registros de A.
 perform set_config('request.jwt.claim.sub',b::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',b,'role','authenticated')::text,true);
 cb:=(public.open_running_health_connection(b,'apple_health')->>'id')::uuid;
 if cb=c then raise exception 'Mezcla cuentas'; end if;
 perform public.save_running_health_history(b,cb,0,gen_random_uuid(),jsonb_build_array(base));
 if (select count(*) from device_private.running_snapshots where owner_id=a)<>0 then raise exception 'RLS filtra mal'; end if;
 begin
  perform public.list_running_health_history(b,c);raise exception 'B ve A';
 exception when insufficient_privilege then null; end;
 perform set_config('request.jwt.claim.sub',adm::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',adm,'role','authenticated','aal','aal2')::text,true);
 if exists(select 1 from device_private.running_snapshots) then raise exception 'Admin hereda lectura'; end if;
 begin
  perform public.list_running_health_history(adm,c);raise exception 'Admin ve A';
 exception when insufficient_privilege then null; end;
 begin
  perform public.open_running_health_connection(a,'apple_health');raise exception 'Confía en owner del cliente';
 exception when insufficient_privilege then null; end;
 if has_table_privilege('authenticated','device_private.running_snapshots','INSERT') or
  has_table_privilege('authenticated','device_private.history_limits','UPDATE') then raise exception 'Escrituras directas abiertas'; end if;
 if has_function_privilege('authenticated','device_private.lock_history_owner(uuid)','EXECUTE') or
  has_function_privilege('authenticated','device_private.normalize_running_selection(jsonb,text)','EXECUTE') or
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public'
   and p.proname in ('open_running_health_connection','list_running_health_history','save_running_health_history','clear_running_health_history') and p.prosecdef) then
  raise exception 'Fachada pública elevada o helpers abiertos';
 end if;
 execute 'set local role anon';
 begin
  perform public.open_running_health_connection(a,'apple_health');raise exception 'Anon ejecuta contrato';
 exception when insufficient_privilege then null; end;
 execute 'set local role authenticated';
 perform set_config('request.jwt.claim.sub',a::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',a,'role','authenticated')::text,true);
 -- Borrado explícito, generación y replay seguro incluso tras importaciones nuevas.
 perform public.clear_running_health_history(a,c,0,clear_op);
 r:=public.open_running_health_connection(a,'apple_health'); next_generation:=(r->>'generation')::integer;
 if (r->>'id')::uuid<>c or next_generation<>1 or jsonb_array_length(public.list_running_health_history(a,c)->'items')<>0 then raise exception 'Borrado o namespace incorrectos'; end if;
 begin
  perform public.save_running_health_history(a,c,0,op,jsonb_build_array(base));raise exception 'Resucita orden pre-borrado';
 exception when serialization_failure then if sqlerrm<>'stale_generation' then raise; end if; end;
 perform public.save_running_health_history(a,c,1,fresh_op,jsonb_build_array(base));
 perform public.clear_running_health_history(a,c,0,clear_op);
 if jsonb_array_length(public.list_running_health_history(a,c)->'items')<>1 then raise exception 'Replay borrado elimina nuevas'; end if;
 -- Presupuesto y conteos se reducen en datos sintéticos, sin purgas automáticas.
 execute 'reset role';
 update device_private.history_limits set max_activities=1,max_revisions=1 where owner_id=a;
 execute 'set local role authenticated';
 begin
  perform public.save_running_health_history(a,c,1,gen_random_uuid(),jsonb_build_array(base||jsonb_build_object('external_id',gen_random_uuid()::text)));
  raise exception 'No limita identidades';
 exception when raise_exception then if sqlerrm<>'history_limit' then raise; end if; end;
 r:=public.list_running_health_history(a,c);
 begin
  perform public.save_running_health_history(a,c,1,gen_random_uuid(),jsonb_build_array(newer||jsonb_build_object('expected_snapshot_hash',r->'items'->0->>'snapshot_hash')));
  raise exception 'No limita revisiones';
 exception when raise_exception then if sqlerrm<>'history_limit' then raise; end if; end;
 execute 'reset role';
 update device_private.history_limits set max_receipts=receipt_count,max_logical_bytes=logical_bytes where owner_id=a;
 execute 'set local role authenticated';
 begin
  perform public.save_running_health_history(a,c,1,gen_random_uuid(),jsonb_build_array(base));raise exception 'No limita recibos';
 exception when raise_exception then if sqlerrm<>'history_limit' then raise; end if; end;
 perform public.save_running_health_history(a,c,1,fresh_op,jsonb_build_array(base));
 execute 'reset role';
 update device_private.history_limits set max_receipts=50000,max_logical_bytes=logical_bytes+512 where owner_id=a;
 execute 'set local role authenticated';
 ch:=(public.open_running_health_connection(a,'health_connect')->>'id')::uuid;
 begin
  perform public.save_running_health_history(a,ch,0,gen_random_uuid(),jsonb_build_array(base));raise exception 'Cuota de bytes no agrega canales';
 exception when raise_exception then if sqlerrm<>'history_limit' then raise; end if; end;
 if exists(select 1 from device_private.history_limits l where l.owner_id=a and l.logical_bytes<>
  512*(select count(*) from device_private.health_connections x where x.owner_id=a)+
  coalesce((select sum(s.logical_bytes) from device_private.running_snapshots s where s.owner_id=a),0)+
  coalesce((select sum(w.logical_bytes) from device_private.history_receipts w where w.owner_id=a),0)) then
  raise exception 'Contador de bytes inconsistente';
 end if;
 perform public.clear_running_health_history(a,c,1,gen_random_uuid());
 if (select activity_count from device_private.history_limits where owner_id=a)<>0 then raise exception 'Borrar no libera cupo'; end if;
end $$;

reset role;
-- Borrado de cuenta sintética: la cascada no afecta a ninguna cuenta real.
delete from auth.users where id=current_setting('test.history_b')::uuid;
do $$begin
 if exists(select 1 from device_private.health_connections where owner_id=current_setting('test.history_b')::uuid) or
  exists(select 1 from device_private.running_snapshots where owner_id=current_setting('test.history_b')::uuid) then
  raise exception 'Cuenta eliminada deja historial';
 end if;
end $$;
rollback;
