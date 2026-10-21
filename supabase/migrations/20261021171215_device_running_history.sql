begin;

create schema device_private;
revoke all on schema device_private from public, anon, authenticated;

-- Cuotas técnicas por cuenta, independientes de permisos comerciales.
create table device_private.history_limits (
 owner_id uuid primary key references auth.users(id) on delete cascade,
 max_activities integer not null default 20000 check(max_activities>0),
 max_revisions integer not null default 32 check(max_revisions>0),
 max_receipts integer not null default 50000 check(max_receipts>0),
 max_logical_bytes bigint not null default 52428800 check(max_logical_bytes>=512),
 max_batch integer not null default 200 check(max_batch between 1 and 200),
 max_request_bytes integer not null default 524288 check(max_request_bytes between 1024 and 1048576),
 activity_count integer not null default 0 check(activity_count>=0),
 receipt_count integer not null default 0 check(receipt_count>=0),
 logical_bytes bigint not null default 0 check(logical_bytes>=0)
);
create table device_private.health_connections (
 id uuid primary key default gen_random_uuid(),
 owner_id uuid not null references auth.users(id) on delete cascade,
 channel text not null check(channel in ('apple_health','health_connect')),
 generation integer not null default 0 check(generation>=0),
 last_clear_operation uuid, last_clear_hash text,
 unique(owner_id,channel), unique(id,owner_id),
 check((last_clear_operation is null and last_clear_hash is null) or
  (last_clear_operation is not null and last_clear_hash is not null and last_clear_hash ~ '^[0-9a-f]{64}$'))
);
create table device_private.running_snapshots (
 id uuid primary key default gen_random_uuid(), owner_id uuid not null,
 connection_id uuid not null, external_id text not null check(length(external_id) between 1 and 200),
 source_revision text not null check(length(btrim(source_revision))>0 and length(source_revision)<=200),
 normalizer_version integer not null check(normalizer_version=1),
 snapshot_hash text not null check(snapshot_hash ~ '^[0-9a-f]{64}$'),
 started_at timestamptz not null, ended_at timestamptz not null,
 elapsed_micros bigint, timer_micros bigint, distance_meters double precision,
 source_modified_at timestamptz, start_offset_seconds integer, end_offset_seconds integer,
 time_zone_id text, device_brand text, writer_application text,
 is_current boolean not null default true,
 first_received_at timestamptz not null default clock_timestamp(),
 accepted_at timestamptz not null default clock_timestamp(),
 logical_bytes integer not null check(logical_bytes>0),
 foreign key(connection_id,owner_id) references device_private.health_connections(id,owner_id) on delete cascade,
 unique(connection_id,external_id,normalizer_version,source_revision),
 check(isfinite(started_at) and isfinite(ended_at) and started_at>=timestamptz '1970-01-01 00:00:00+00'
  and ended_at>=started_at and ended_at-started_at<=interval '7 days'),
 check(elapsed_micros is null or (elapsed_micros>=0 and elapsed_micros=(extract(epoch from ended_at-started_at)*1000000)::bigint)),
 check(timer_micros is null or timer_micros>=0),
 check(distance_meters is null or (distance_meters>=0 and distance_meters<'Infinity'::double precision)),
 check(source_modified_at is null or isfinite(source_modified_at)),
 check(start_offset_seconds is null or start_offset_seconds between -86399 and 86399),
 check(end_offset_seconds is null or end_offset_seconds between -86399 and 86399),
 check(time_zone_id is null or (length(btrim(time_zone_id))>0 and length(time_zone_id)<=128)),
 check(device_brand is null or (length(btrim(device_brand))>0 and length(device_brand)<=128)),
 check(writer_application is null or (length(btrim(writer_application))>0 and length(writer_application)<=256))
);
create unique index running_snapshot_current on device_private.running_snapshots(connection_id,external_id) where is_current;
create index running_snapshot_history on device_private.running_snapshots(owner_id,connection_id,started_at desc,id desc) where is_current;
create index running_snapshot_owner on device_private.running_snapshots(owner_id);
create table device_private.history_receipts (
 owner_id uuid not null, connection_id uuid not null, operation_id uuid not null,
 request_hash text not null check(request_hash ~ '^[0-9a-f]{64}$'),
 result jsonb not null check(jsonb_typeof(result)='object' and octet_length(result::text)<=1024),
 logical_bytes integer not null check(logical_bytes>0),
 primary key(connection_id,operation_id),
 foreign key(connection_id,owner_id) references device_private.health_connections(id,owner_id) on delete cascade
);
create index history_receipts_owner on device_private.history_receipts(owner_id);

do $$declare t text;begin
 foreach t in array array['history_limits','health_connections','running_snapshots','history_receipts'] loop
  execute format('alter table device_private.%I enable row level security',t);
  execute format('revoke all on device_private.%I from public,anon,authenticated',t);
  execute format('create policy owner_read on device_private.%I for select to authenticated using ((select auth.uid())=owner_id)',t);
 end loop;
end $$;

create function device_private.require_history_owner(p_expected_owner uuid) returns uuid
language plpgsql stable set search_path='' as $$
declare v_owner uuid:=auth.uid();
begin
 if v_owner is null or p_expected_owner is distinct from v_owner or
  not exists(select 1 from auth.users where id=v_owner) then
  raise exception using errcode='42501',message='account_changed';
 end if;
 return v_owner;
end $$;

-- Mismo orden que el borrado Auth: usuario -> cuota -> conexión.
-- EXISTS MVCC no basta para evitar un ciclo entre FK y CASCADE.
create function device_private.lock_history_owner(p_expected_owner uuid) returns uuid
language plpgsql volatile set search_path='' as $$
declare v_owner uuid:=device_private.require_history_owner(p_expected_owner);
begin
 perform 1 from auth.users where id=v_owner for key share;
 if not found then raise exception using errcode='42501',message='account_changed'; end if;
 return v_owner;
end $$;

create function device_private.history_hash(p_value jsonb) returns text
language sql immutable set search_path='' as $$
 select encode(sha256(convert_to(p_value::text,'UTF8')),'hex');
$$;

create function device_private.history_optional_text(p_row jsonb,p_key text,p_max integer) returns text
language plpgsql immutable set search_path='' as $$
declare v text;
begin
 if p_row->p_key is null or p_row->p_key='null'::jsonb then return null; end if;
 if jsonb_typeof(p_row->p_key)<>'string' then
  raise exception using errcode='22023',message='invalid_running_history';
 end if;
 v:=p_row->>p_key;
 if length(v)>p_max or length(btrim(v))=0 then
  raise exception using errcode='22023',message='invalid_running_history';
 end if;
 return v;
end $$;

create function device_private.normalize_running_selection(p_row jsonb,p_channel text) returns jsonb
language plpgsql set search_path='' as $$
declare
 v_id text; v_revision text; v_expected text; v_start timestamptz; v_end timestamptz;
 v_modified timestamptz; v_elapsed bigint; v_timer bigint; v_distance double precision;
 v_start_offset integer; v_end_offset integer; v_key text; v_snapshot jsonb;
begin
 if jsonb_typeof(p_row) is distinct from 'object' then
  raise exception using errcode='22023',message='invalid_running_history';
 end if;
 if exists(select 1 from jsonb_object_keys(p_row) k where k not in
  ('external_id','source_revision','normalizer_version','started_at','ended_at','elapsed_micros',
   'timer_micros','distance_meters','source_modified_at','start_offset_seconds','end_offset_seconds',
   'time_zone_id','device_brand','writer_application','expected_snapshot_hash')) then
  raise exception using errcode='22023',message='invalid_running_history';
 end if;
 v_id:=device_private.history_optional_text(p_row,'external_id',200);
 v_revision:=device_private.history_optional_text(p_row,'source_revision',200);
 v_expected:=device_private.history_optional_text(p_row,'expected_snapshot_hash',64);
 if v_id is null or v_revision is null or
  (v_expected is not null and v_expected !~ '^[0-9a-f]{64}$') or
  p_row->'normalizer_version' is distinct from '1'::jsonb then
  raise exception using errcode='22023',message='invalid_running_history';
 end if;
 if p_channel='apple_health' then
  if v_id !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then
   raise exception using errcode='22023',message='invalid_running_history';
  end if;
  v_id:=(v_id::uuid)::text;
 end if;
 foreach v_key in array array['started_at','ended_at','source_modified_at'] loop
  if v_key='source_modified_at' and coalesce(p_row->v_key,'null'::jsonb)='null'::jsonb then continue; end if;
  if jsonb_typeof(p_row->v_key) is distinct from 'string' or
   p_row->>v_key !~ '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d{1,6})?Z$' then
   raise exception using errcode='22023',message='invalid_running_history';
  end if;
 end loop;
 v_start:=(p_row->>'started_at')::timestamptz;
 v_end:=(p_row->>'ended_at')::timestamptz;
 v_modified:=(p_row->>'source_modified_at')::timestamptz;
 if not isfinite(v_start) or not isfinite(v_end) or v_start<timestamptz '1970-01-01 00:00:00+00' or
  v_end<v_start or v_end-v_start>interval '7 days' or (v_modified is not null and not isfinite(v_modified)) then
  raise exception using errcode='22023',message='invalid_running_history';
 end if;
 foreach v_key in array array['elapsed_micros','timer_micros','start_offset_seconds','end_offset_seconds'] loop
  if coalesce(p_row->v_key,'null'::jsonb)='null'::jsonb then continue; end if;
  if jsonb_typeof(p_row->v_key)<>'number' or p_row->>v_key !~ '^-?[0-9]+$' then
   raise exception using errcode='22023',message='invalid_running_history';
  end if;
 end loop;
 v_elapsed:=(p_row->>'elapsed_micros')::bigint; v_timer:=(p_row->>'timer_micros')::bigint;
 v_start_offset:=(p_row->>'start_offset_seconds')::integer;
 v_end_offset:=(p_row->>'end_offset_seconds')::integer;
 if (v_elapsed is not null and (v_elapsed<0 or v_elapsed<>(extract(epoch from v_end-v_start)*1000000)::bigint)) or
  (v_timer is not null and v_timer<0) or (v_start_offset is not null and abs(v_start_offset::bigint)>=86400) or
  (v_end_offset is not null and abs(v_end_offset::bigint)>=86400) then
  raise exception using errcode='22023',message='invalid_running_history';
 end if;
 if coalesce(p_row->'distance_meters','null'::jsonb)<>'null'::jsonb then
  if jsonb_typeof(p_row->'distance_meters')<>'number' then
   raise exception using errcode='22023',message='invalid_running_history';
  end if;
  v_distance:=(p_row->>'distance_meters')::double precision;
  if not (v_distance>=0 and v_distance<'Infinity'::double precision) then
   raise exception using errcode='22023',message='invalid_running_history';
  end if;
 end if;
 -- UTC canónico explícito: la zona de la conexión SQL no cambia la huella.
 v_snapshot:=jsonb_build_object(
  'external_id',v_id,'source_revision',v_revision,'normalizer_version',1,
  'started_at',to_char(v_start at time zone 'UTC','YYYY-MM-DD"T"HH24:MI:SS.US"Z"'),
  'ended_at',to_char(v_end at time zone 'UTC','YYYY-MM-DD"T"HH24:MI:SS.US"Z"'),
  'elapsed_micros',v_elapsed,'timer_micros',v_timer,'distance_meters',v_distance,
  'source_modified_at',case when v_modified is null then null else to_char(v_modified at time zone 'UTC','YYYY-MM-DD"T"HH24:MI:SS.US"Z"') end,
  'start_offset_seconds',v_start_offset,'end_offset_seconds',v_end_offset,
  'time_zone_id',device_private.history_optional_text(p_row,'time_zone_id',128),
  'device_brand',device_private.history_optional_text(p_row,'device_brand',128),
  'writer_application',device_private.history_optional_text(p_row,'writer_application',256));
 return jsonb_build_object('snapshot',v_snapshot,'expected_snapshot_hash',v_expected);
exception when invalid_text_representation or datetime_field_overflow or numeric_value_out_of_range then
 raise exception using errcode='22023',message='invalid_running_history';
end $$;

create function device_private.open_running_health_connection(p_expected_owner uuid,p_channel text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare v_owner uuid:=device_private.lock_history_owner(p_expected_owner);
 v_limits device_private.history_limits; v_conn device_private.health_connections;
begin
 if p_channel is null or p_channel not in ('apple_health','health_connect') then
  raise exception using errcode='22023',message='invalid_running_history';
 end if;
 insert into device_private.history_limits(owner_id) values(v_owner) on conflict do nothing;
 select * into v_limits from device_private.history_limits where owner_id=v_owner for update;
 if not found then raise exception using errcode='40001',message='history_conflict'; end if;
 select * into v_conn from device_private.health_connections where owner_id=v_owner and channel=p_channel;
 if not found then
  -- Slot acotado para el último recibo de borrado: nunca consume nuevas cuotas al borrar.
  if v_limits.logical_bytes+512>v_limits.max_logical_bytes then
   raise exception using errcode='P0001',message='history_limit';
  end if;
  insert into device_private.health_connections(owner_id,channel) values(v_owner,p_channel) returning * into v_conn;
  update device_private.history_limits set logical_bytes=logical_bytes+512 where owner_id=v_owner;
 end if;
 return jsonb_build_object('id',v_conn.id,'owner_id',v_owner,'channel',v_conn.channel,'generation',v_conn.generation);
end $$;

create function device_private.list_running_health_history(p_expected_owner uuid,p_connection_id uuid,
 p_before_started_at timestamptz default null,p_before_id uuid default null,p_limit integer default 50) returns jsonb
language plpgsql security definer set search_path='' as $$
declare v_owner uuid:=device_private.require_history_owner(p_expected_owner);
 v_conn device_private.health_connections; v_rows jsonb; v_more boolean;
begin
 if p_limit is null or p_limit not between 1 and 100 or
  ((p_before_started_at is null)<>(p_before_id is null)) or
  (p_before_started_at is not null and not isfinite(p_before_started_at)) then
  raise exception using errcode='22023',message='invalid_running_history';
 end if;
 select * into v_conn from device_private.health_connections where id=p_connection_id and owner_id=v_owner for share;
 if not found then raise exception using errcode='42501',message='account_changed'; end if;
 select coalesce(jsonb_agg(to_jsonb(r) order by r.started_at desc,r.id desc),'[]'::jsonb),count(*)>p_limit
 into v_rows,v_more from (
  select s.* from device_private.running_snapshots s
  where s.owner_id=v_owner and s.connection_id=v_conn.id and s.is_current and
   (p_before_id is null or (s.started_at,s.id)<(p_before_started_at,p_before_id))
  order by s.started_at desc,s.id desc limit p_limit+1
 ) r;
 if v_more then v_rows:=v_rows-p_limit; end if;
 return jsonb_build_object('connection',jsonb_build_object('id',v_conn.id,'owner_id',v_owner,
  'channel',v_conn.channel,'generation',v_conn.generation),'items',v_rows,'has_more',v_more);
end $$;

create function device_private.save_running_health_history(p_expected_owner uuid,p_connection_id uuid,
 p_expected_generation integer,p_operation_id uuid,p_items jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare
 v_owner uuid:=device_private.lock_history_owner(p_expected_owner);
 v_limits device_private.history_limits; v_conn device_private.health_connections;
 v_receipt device_private.history_receipts; v_previous device_private.running_snapshots;
 v_known device_private.running_snapshots; v_row jsonb; v_norm jsonb; v_normalized jsonb:='[]';
 v_snapshot jsonb; v_hash text; v_request_hash text; v_expected text; v_external text;
 v_source_revision text; v_result jsonb; v_seen text[]:='{}'; v_snapshot_bytes integer;
 v_byte_delta bigint:=0; v_identity_delta integer:=0; v_receipt_bytes integer;
 v_inserted integer:=0; v_updated integer:=0; v_unchanged integer:=0; v_count integer;
begin
 if p_operation_id is null or p_expected_generation is null or p_expected_generation<0 or
  jsonb_typeof(p_items) is distinct from 'array' then
  raise exception using errcode='22023',message='invalid_running_history';
 end if;
 select * into v_limits from device_private.history_limits where owner_id=v_owner for update;
 if not found then raise exception using errcode='42501',message='account_changed'; end if;
 select * into v_conn from device_private.health_connections where id=p_connection_id and owner_id=v_owner for update;
 if not found then raise exception using errcode='42501',message='account_changed'; end if;
 if jsonb_array_length(p_items) not between 1 and v_limits.max_batch or
  octet_length(p_items::text)>v_limits.max_request_bytes then
  raise exception using errcode='P0001',message='history_limit';
 end if;
 for v_row in select value from jsonb_array_elements(p_items) loop
  v_norm:=device_private.normalize_running_selection(v_row,v_conn.channel);
  v_external:=v_norm->'snapshot'->>'external_id';
  if v_external=any(v_seen) then raise exception using errcode='22023',message='invalid_running_history'; end if;
  v_seen:=array_append(v_seen,v_external); v_normalized:=v_normalized||jsonb_build_array(v_norm);
 end loop;
 select jsonb_agg(value order by value->'snapshot'->>'external_id') into v_normalized from jsonb_array_elements(v_normalized);
 v_request_hash:=device_private.history_hash(jsonb_build_object('kind','save','connection',v_conn.id,
  'generation',p_expected_generation,'selections',v_normalized));
 if v_conn.last_clear_operation=p_operation_id then
  raise exception using errcode='22023',message='operation_reused';
 end if;
 select * into v_receipt from device_private.history_receipts where connection_id=v_conn.id and operation_id=p_operation_id;
 if found then
  if v_receipt.request_hash<>v_request_hash then raise exception using errcode='22023',message='operation_reused'; end if;
  return v_receipt.result;
 end if;
 if p_expected_generation<>v_conn.generation then raise exception using errcode='40001',message='stale_generation'; end if;
 for v_norm in select value from jsonb_array_elements(v_normalized) loop
  v_snapshot:=v_norm->'snapshot'; v_external:=v_snapshot->>'external_id';
  v_source_revision:=v_snapshot->>'source_revision'; v_expected:=v_norm->>'expected_snapshot_hash';
  v_hash:=device_private.history_hash(v_snapshot);
  select * into v_known from device_private.running_snapshots
   where connection_id=v_conn.id and external_id=v_external and source_revision=v_source_revision and normalizer_version=1;
  if found and v_known.snapshot_hash<>v_hash then raise exception using errcode='22023',message='revision_collision'; end if;
  if v_known.id is not null and not v_known.is_current then
   raise exception using errcode='40001',message='historical_revision';
  end if;
  select * into v_previous from device_private.running_snapshots
   where connection_id=v_conn.id and external_id=v_external and is_current;
  if found and v_previous.snapshot_hash=v_hash then v_unchanged:=v_unchanged+1; continue; end if;
  if v_expected is distinct from v_previous.snapshot_hash then raise exception using errcode='40001',message='history_conflict'; end if;
  select count(*) into v_count from device_private.running_snapshots where connection_id=v_conn.id and external_id=v_external;
  if v_count>=v_limits.max_revisions then raise exception using errcode='P0001',message='history_limit'; end if;
  v_snapshot_bytes:=octet_length(v_snapshot::text);
  v_byte_delta:=v_byte_delta+v_snapshot_bytes;
  if v_previous.id is null then
   v_identity_delta:=v_identity_delta+1; v_inserted:=v_inserted+1;
  else
   -- Solo cambia el head: el contenido de la revisión anterior permanece inmutable.
   update device_private.running_snapshots set is_current=false where id=v_previous.id;
   v_updated:=v_updated+1;
  end if;
  insert into device_private.running_snapshots(owner_id,connection_id,external_id,source_revision,normalizer_version,
   snapshot_hash,started_at,ended_at,elapsed_micros,timer_micros,distance_meters,source_modified_at,
   start_offset_seconds,end_offset_seconds,time_zone_id,device_brand,writer_application,logical_bytes)
  values(v_owner,v_conn.id,v_external,v_source_revision,1,v_hash,
   (v_snapshot->>'started_at')::timestamptz,(v_snapshot->>'ended_at')::timestamptz,
   (v_snapshot->>'elapsed_micros')::bigint,(v_snapshot->>'timer_micros')::bigint,
   (v_snapshot->>'distance_meters')::double precision,(v_snapshot->>'source_modified_at')::timestamptz,
   (v_snapshot->>'start_offset_seconds')::integer,(v_snapshot->>'end_offset_seconds')::integer,
   v_snapshot->>'time_zone_id',v_snapshot->>'device_brand',v_snapshot->>'writer_application',v_snapshot_bytes);
 end loop;
 v_result:=jsonb_build_object('inserted',v_inserted,'updated',v_updated,'unchanged',v_unchanged);
 v_receipt_bytes:=octet_length(jsonb_build_object('operation',p_operation_id,'hash',v_request_hash,'result',v_result)::text);
 if v_limits.activity_count+v_identity_delta>v_limits.max_activities or
  v_limits.receipt_count+1>v_limits.max_receipts or
  v_limits.logical_bytes+v_byte_delta+v_receipt_bytes>v_limits.max_logical_bytes then
  raise exception using errcode='P0001',message='history_limit';
 end if;
 insert into device_private.history_receipts(owner_id,connection_id,operation_id,request_hash,result,logical_bytes)
  values(v_owner,v_conn.id,p_operation_id,v_request_hash,v_result,v_receipt_bytes);
 update device_private.history_limits set activity_count=activity_count+v_identity_delta,
  receipt_count=receipt_count+1,logical_bytes=logical_bytes+v_byte_delta+v_receipt_bytes where owner_id=v_owner;
 return v_result;
end $$;

create function device_private.clear_running_health_history(p_expected_owner uuid,p_connection_id uuid,
 p_expected_generation integer,p_operation_id uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare
 v_owner uuid:=device_private.lock_history_owner(p_expected_owner);
 v_conn device_private.health_connections; v_hash text; v_identity_count integer;
 v_snapshot_bytes bigint; v_receipt_bytes bigint; v_receipt_count integer;
begin
 if p_operation_id is null or p_expected_generation is null or p_expected_generation<0 then
  raise exception using errcode='22023',message='invalid_running_history';
 end if;
 perform 1 from device_private.history_limits where owner_id=v_owner for update;
 select * into v_conn from device_private.health_connections where id=p_connection_id and owner_id=v_owner for update;
 if not found then raise exception using errcode='42501',message='account_changed'; end if;
 v_hash:=device_private.history_hash(jsonb_build_object('kind','clear','connection',v_conn.id,'generation',p_expected_generation));
 if v_conn.last_clear_operation=p_operation_id then
  if v_conn.last_clear_hash<>v_hash then raise exception using errcode='22023',message='operation_reused'; end if;
  return jsonb_build_object('cleared',true);
 end if;
 if exists(select 1 from device_private.history_receipts where connection_id=v_conn.id and operation_id=p_operation_id) then
  raise exception using errcode='22023',message='operation_reused';
 end if;
 if p_expected_generation<>v_conn.generation then raise exception using errcode='40001',message='stale_generation'; end if;
 select count(*) filter(where is_current),coalesce(sum(logical_bytes),0)
  into v_identity_count,v_snapshot_bytes from device_private.running_snapshots where connection_id=v_conn.id;
 select count(*),coalesce(sum(logical_bytes),0) into v_receipt_count,v_receipt_bytes
  from device_private.history_receipts where connection_id=v_conn.id;
 delete from device_private.running_snapshots where connection_id=v_conn.id;
 delete from device_private.history_receipts where connection_id=v_conn.id;
 update device_private.health_connections set generation=generation+1,
  last_clear_operation=p_operation_id,last_clear_hash=v_hash where id=v_conn.id;
 update device_private.history_limits set activity_count=activity_count-v_identity_count,
  receipt_count=receipt_count-v_receipt_count,logical_bytes=logical_bytes-v_snapshot_bytes-v_receipt_bytes where owner_id=v_owner;
 return jsonb_build_object('cleared',true);
end $$;

revoke all on all functions in schema device_private from public,anon,authenticated;
-- La API pública no eleva privilegios; las cuatro entradas privadas repiten titularidad.
-- No se conceden tablas ni los helpers de normalización, hashing o locks.
grant usage on schema device_private to authenticated;
grant execute on function device_private.open_running_health_connection(uuid,text),
 device_private.list_running_health_history(uuid,uuid,timestamptz,uuid,integer),
 device_private.save_running_health_history(uuid,uuid,integer,uuid,jsonb),
 device_private.clear_running_health_history(uuid,uuid,integer,uuid) to authenticated;

create function public.open_running_health_connection(p_expected_owner uuid,p_channel text) returns jsonb
language sql security invoker set search_path='' as $$
 select device_private.open_running_health_connection(p_expected_owner,p_channel);
$$;
create function public.list_running_health_history(p_expected_owner uuid,p_connection_id uuid,
 p_before_started_at timestamptz default null,p_before_id uuid default null,p_limit integer default 50) returns jsonb
language sql security invoker set search_path='' as $$
 select device_private.list_running_health_history(p_expected_owner,p_connection_id,p_before_started_at,p_before_id,p_limit);
$$;
create function public.save_running_health_history(p_expected_owner uuid,p_connection_id uuid,
 p_expected_generation integer,p_operation_id uuid,p_items jsonb) returns jsonb
language sql security invoker set search_path='' as $$
 select device_private.save_running_health_history(p_expected_owner,p_connection_id,p_expected_generation,p_operation_id,p_items);
$$;
create function public.clear_running_health_history(p_expected_owner uuid,p_connection_id uuid,
 p_expected_generation integer,p_operation_id uuid) returns jsonb
language sql security invoker set search_path='' as $$
 select device_private.clear_running_health_history(p_expected_owner,p_connection_id,p_expected_generation,p_operation_id);
$$;
revoke all on function public.open_running_health_connection(uuid,text) from public,anon;
revoke all on function public.list_running_health_history(uuid,uuid,timestamptz,uuid,integer) from public,anon;
revoke all on function public.save_running_health_history(uuid,uuid,integer,uuid,jsonb) from public,anon;
revoke all on function public.clear_running_health_history(uuid,uuid,integer,uuid) from public,anon;
grant execute on function public.open_running_health_connection(uuid,text),
 public.list_running_health_history(uuid,uuid,timestamptz,uuid,integer),
 public.save_running_health_history(uuid,uuid,integer,uuid,jsonb),
 public.clear_running_health_history(uuid,uuid,integer,uuid) to authenticated;

commit;
