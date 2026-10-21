begin;

create table trainer_private.program_work_limits (
 owner_id uuid primary key references public.profiles(id) on delete cascade,
 active_limit integer not null default 100 check(active_limit between 0 and 100),
 snapshot_limit integer not null default 524288 check(snapshot_limit between 1 and 524288),
 byte_limit bigint not null default 67108864 check(byte_limit between 4096 and 67108864),
 hourly_limit integer not null default 1200 check(hourly_limit between 0 and 1200),
 active_count integer not null default 0 check(active_count>=0),
 retained_bytes bigint not null default 4096 check(retained_bytes>=4096),
 write_revision bigint not null default 0 check(write_revision>=0)
);
create table trainer_private.program_work_bodies (
 owner_id uuid not null references trainer_private.program_work_limits(owner_id) on delete cascade,
 context text not null default 'trainer_private' check(context='trainer_private'),
 hash text not null check(hash~'^[0-9a-f]{64}$'),body jsonb not null,
 logical_bytes bigint not null default 0,primary key(owner_id,context,hash)
);
create table trainer_private.program_works (
 owner_id uuid not null references trainer_private.program_work_limits(owner_id) on delete cascade,
 context text not null default 'trainer_private' check(context='trainer_private'),
 id uuid not null,base_program_id uuid,schema_version integer not null check(schema_version=1),
 state_hash text not null,revision bigint not null check(revision between 1 and 2147483647),
 lifecycle text not null check(lifecycle in ('open','discarded','finalized')),
 finalized_program_id uuid,updated_at timestamptz not null,discarded_at timestamptz,
 logical_bytes bigint not null default 0,
 primary key(owner_id,context,id),
 foreign key(owner_id,context,state_hash) references trainer_private.program_work_bodies(owner_id,context,hash) deferrable initially deferred,
 check((lifecycle='open' and finalized_program_id is null and discarded_at is null)
  or (lifecycle='discarded' and finalized_program_id is null and discarded_at is not null)
  or (lifecycle='finalized' and finalized_program_id is not null and discarded_at is null))
);
create index trainer_program_work_open on trainer_private.program_works(owner_id,updated_at desc,id desc) where lifecycle='open';
create table trainer_private.program_work_operations (
 owner_id uuid not null references trainer_private.program_work_limits(owner_id) on delete cascade,
 context text not null default 'trainer_private' check(context='trainer_private'),work_id uuid not null,
 action text not null check(action in ('save','discard','finalize')),
 expected_revision bigint not null check(expected_revision between 0 and 2147483646),
 request_hash text not null check(request_hash~'^[0-9a-f]{64}$'),request_body_hash text not null,
 receipt jsonb not null,created_at timestamptz not null default clock_timestamp(),logical_bytes bigint not null default 0,
 primary key(owner_id,context,work_id,action,expected_revision),
 foreign key(owner_id,context,work_id) references trainer_private.program_works(owner_id,context,id) on delete cascade,
 foreign key(owner_id,context,request_body_hash) references trainer_private.program_work_bodies(owner_id,context,hash) deferrable initially deferred
);
create index trainer_program_work_rate on trainer_private.program_work_operations(owner_id,created_at);
do $$ declare tab text;begin
 foreach tab in array array['program_work_limits','program_work_bodies','program_works','program_work_operations'] loop
  execute format('alter table trainer_private.%I enable row level security',tab);
  execute format('revoke all on trainer_private.%I from public,anon,authenticated',tab);
 end loop;
end $$;

create function trainer_private.program_work_identity(p_expected_owner uuid) returns void
language plpgsql stable security definer set search_path='' as $$
begin
 -- expected_owner es solo una barrera contra cambiar headers A→B. Nunca es
 -- autoridad para elegir propietario: todas las consultas usan auth.uid().
 if p_expected_owner is null or auth.uid() is distinct from p_expected_owner
  or not trainer_private.has_trainer_mfa() then raise insufficient_privilege;end if;
end $$;

create function trainer_private.lock_program_work_owner(p_expected_owner uuid) returns void
language plpgsql security definer set search_path='' as $$
begin
 perform trainer_private.program_work_identity(p_expected_owner);
 perform 1 from public.profiles where id=auth.uid() for key share;
 if not found then raise insufficient_privilege;end if;
 perform trainer_private.require_authoring_access();
 -- Serializa también dos trabajos distintos y la ausencia inicial de la fila
 -- de presupuesto. El UPDATE invalida snapshots RR anteriores al ganador.
 insert into trainer_private.program_work_limits(owner_id,write_revision) values(auth.uid(),1)
  on conflict(owner_id) do update set write_revision=trainer_private.program_work_limits.write_revision+1;
end $$;

create function trainer_private.program_work_charge() returns trigger
language plpgsql security definer set search_path='' set timezone='UTC' as $$
begin
 -- La envoltura JSON completa contabiliza IDs, contexto, fechas y hashes.
 -- 64 bytes adicionales cubren el propio contador, sin prometer tamaño físico.
 new.logical_bytes:=octet_length((to_jsonb(new)-'logical_bytes')::text)+64;
 return new;
end $$;
create function trainer_private.program_work_account() returns trigger
language plpgsql security definer set search_path='' as $$
declare owner uuid;delta bigint;active_delta integer:=0;
begin
 owner:=case when tg_op='DELETE' then old.owner_id else new.owner_id end;
 delta:=case when tg_op='INSERT' then new.logical_bytes when tg_op='DELETE' then -old.logical_bytes else new.logical_bytes-old.logical_bytes end;
 if tg_table_name='program_works' then
  if tg_op<>'DELETE' and new.lifecycle='open' then active_delta:=active_delta+1;end if;
  if tg_op<>'INSERT' and old.lifecycle='open' then active_delta:=active_delta-1;end if;
 end if;
 update trainer_private.program_work_limits set retained_bytes=retained_bytes+delta,active_count=active_count+active_delta
  where owner_id=owner and retained_bytes+delta between 4096 and byte_limit
   and active_count+active_delta>=0 and (active_delta<=0 or active_count+active_delta<=active_limit);
 if not found and exists(select 1 from trainer_private.program_work_limits where owner_id=owner) then
  raise exception 'Has alcanzado el presupuesto técnico de trabajos de programas.' using errcode='54000';end if;
 -- En el CASCADE del propietario el presupuesto ya no existe; no reconstruirlo.
 if tg_op='DELETE' then return old;end if;return new;
end $$;
create function trainer_private.program_work_immutable() returns trigger
language plpgsql security definer set search_path='' as $$
begin
 if tg_table_name<>'program_works' then raise exception 'El recibo y su cuerpo son inmutables.' using errcode='22023';end if;
 if new.owner_id is distinct from old.owner_id or new.context is distinct from old.context or new.id is distinct from old.id
  or new.base_program_id is distinct from old.base_program_id or new.schema_version is distinct from old.schema_version then raise invalid_parameter_value;end if;
 if old.lifecycle<>'open' or new.revision<>old.revision+1 then raise serialization_failure;end if;
 return new;
end $$;
create function trainer_private.program_work_rate() returns trigger
language plpgsql security definer set search_path='' as $$
declare lim integer;
begin
 select hourly_limit into lim from trainer_private.program_work_limits where owner_id=new.owner_id;
 if (select count(*) from trainer_private.program_work_operations where owner_id=new.owner_id and created_at>clock_timestamp()-interval '1 hour')>=lim then
  raise exception 'Has alcanzado el límite técnico de escrituras de trabajos por hora.' using errcode='54000';end if;
 return new;
end $$;
do $$ declare tab text;begin
 foreach tab in array array['program_work_bodies','program_works','program_work_operations'] loop
  execute format('create trigger aa_program_work_immutable before update on trainer_private.%I for each row execute function trainer_private.program_work_immutable()',tab);
  execute format('create trigger zz_program_work_charge before insert or update on trainer_private.%I for each row execute function trainer_private.program_work_charge()',tab);
  execute format('create trigger program_work_account after insert or update or delete on trainer_private.%I for each row execute function trainer_private.program_work_account()',tab);
 end loop;
end $$;
create trigger program_work_rate before insert on trainer_private.program_work_operations for each row execute function trainer_private.program_work_rate();

create function trainer_private.program_work_hash(p_body jsonb) returns text
language sql immutable set search_path='' as $$select encode(extensions.digest(p_body::text,'sha256'),'hex')$$;
create function trainer_private.program_work_store_body(p_body jsonb) returns text
language plpgsql security definer set search_path='' as $$
declare v_hash text:=trainer_private.program_work_hash(p_body);stored jsonb;
begin
 select body into stored from trainer_private.program_work_bodies where owner_id=auth.uid() and context='trainer_private' and program_work_bodies.hash=v_hash;
 if found then
  if stored is distinct from p_body then raise exception 'Conflicto de cuerpo inmutable.' using errcode='22023';end if;
 else
  insert into trainer_private.program_work_bodies(owner_id,hash,body) values(auth.uid(),v_hash,p_body);
 end if;return v_hash;
end $$;

create function trainer_private.program_work_json(p_work trainer_private.program_works) returns jsonb
language sql stable security definer set search_path='' as $$
 select jsonb_build_object('id',p_work.id,'context',p_work.context,'state',b.body,'revision',p_work.revision,
  'base_program_id',p_work.base_program_id,'finalized_program_id',p_work.finalized_program_id,
  'updated_at',p_work.updated_at,'discarded_at',p_work.discarded_at,'lifecycle',p_work.lifecycle)
 from trainer_private.program_work_bodies b where b.owner_id=p_work.owner_id and b.context=p_work.context and b.hash=p_work.state_hash;
$$;
-- El recibo conserva la metadata histórica y el hash de estado; el cuerpo se
-- almacena una sola vez y no se sustituye por el HEAD de otra pestaña.
create function trainer_private.program_work_receipt(p_work trainer_private.program_works) returns jsonb
language sql stable set search_path='' as $$select to_jsonb(p_work)-'logical_bytes'$$;
create function trainer_private.program_work_envelope(p_receipt jsonb,p_current trainer_private.program_works) returns jsonb
language sql stable security definer set search_path='' as $$
 select jsonb_build_object('receipt',jsonb_build_object('work',jsonb_build_object(
  'id',p_receipt->'id','context',p_receipt->'context','state',b.body,'revision',p_receipt->'revision',
  'base_program_id',p_receipt->'base_program_id','finalized_program_id',p_receipt->'finalized_program_id',
  'updated_at',p_receipt->'updated_at','discarded_at',p_receipt->'discarded_at','lifecycle',p_receipt->'lifecycle')),
  'current_revision',p_current.revision,'current_lifecycle',p_current.lifecycle)
 from trainer_private.program_work_bodies b where b.owner_id=auth.uid() and b.context='trainer_private' and b.hash=p_receipt->>'state_hash';
$$;

-- Incluye el White_Space de Dart y BOM. int.tryParse de dart2js usa la misma
-- lista salvo U+0085; el texto del formulario se conserva sin recortar.
create function trainer_private.program_work_trim(p_text text,p_integer boolean default false) returns text
language sql immutable set search_path='' as $$
 select btrim(p_text,chr(9)||chr(10)||chr(11)||chr(12)||chr(13)||chr(32)
  ||case when p_integer then '' else chr(133) end||chr(160)||chr(5760)
  ||chr(8192)||chr(8193)||chr(8194)||chr(8195)||chr(8196)||chr(8197)||chr(8198)||chr(8199)||chr(8200)||chr(8201)||chr(8202)
  ||chr(8232)||chr(8233)||chr(8239)||chr(8287)||chr(12288)||chr(65279));
$$;
create function trainer_private.program_work_integer(p_raw text) returns integer
language plpgsql immutable set search_path='' as $$
declare raw text:=trainer_private.program_work_trim(p_raw,true);negative boolean:=false;digits text;result bigint:=0;i integer;radix integer:=10;digit integer;
begin
 if raw is null or raw!~'^[+-]?(0[xX][0-9A-Fa-f]+|[0-9]+)$' then return null;end if;
 if left(raw,1) in ('+','-') then negative:=left(raw,1)='-';raw:=substr(raw,2);end if;
 if left(lower(raw),2)='0x' then radix:=16;raw:=substr(raw,3);end if;
 digits:=regexp_replace(lower(raw),'^0+','');
 if digits='' then return 0;end if;
 -- Cualquier valor mayor que este rango técnico también falla los dominios
 -- activos (1..104 semanas, 0..3600 s), sin emular double/Infinity de JavaScript.
 if length(digits)>(case when radix=16 then 8 else 10 end) then return null;end if;
 for i in 1..length(digits) loop
  digit:=strpos('0123456789abcdef',substr(digits,i,1))-1;result:=result*radix+digit;
  if result>2147483647 then return null;end if;
 end loop;
 return case when negative then -result else result end;
end $$;

create function trainer_private.validate_program_work_state(p_state jsonb) returns void
language plpgsql immutable set search_path='' as $$
declare phase jsonb;session jsonb;pair record;item jsonb;key text;total integer:=0;
begin
 if p_state is null or jsonb_typeof(p_state)<>'object' or octet_length(p_state::text)>524288
  or p_state->'schema' is distinct from '1'::jsonb
  or not(p_state ?& array['schema','name','description','audience','equipment','mode','categories','primary','phases'])
  or exists(select 1 from jsonb_object_keys(p_state) k where k not in ('schema','name','description','audience','equipment','mode','categories','primary','phases'))
  or p_state->>'mode' not in ('guide','phased') or jsonb_typeof(p_state->'mode') is distinct from 'string'
  or p_state->'categories' is distinct from '[]'::jsonb or p_state->'primary' is distinct from 'null'::jsonb
  or jsonb_typeof(p_state->'phases') is distinct from 'array' then raise invalid_parameter_value;end if;
 foreach key in array array['name','description','audience','equipment'] loop
  if jsonb_typeof(p_state->key) is distinct from 'string' or length(p_state->>key)>65536 then raise invalid_parameter_value;end if;
 end loop;
 if jsonb_array_length(p_state->'phases')>64 then raise invalid_parameter_value;end if;
 for phase in select value from jsonb_array_elements(p_state->'phases') loop
  if jsonb_typeof(phase)<>'object' or not(phase ?& array['name','weeks','instructions','pending','sessions'])
   or exists(select 1 from jsonb_object_keys(phase) k where k not in ('name','weeks','instructions','pending','replacements','sessions','replacementPositions'))
   or jsonb_typeof(phase->'pending') is distinct from 'array' or jsonb_typeof(phase->'sessions') is distinct from 'array'
   or jsonb_array_length(phase->'pending')>256 or jsonb_array_length(phase->'sessions')>256 then raise invalid_parameter_value;end if;
  total:=total+jsonb_array_length(phase->'pending')+jsonb_array_length(phase->'sessions');
  if total>4096 then raise invalid_parameter_value;end if;
  foreach key in array array['name','weeks','instructions'] loop
   if jsonb_typeof(phase->key) is distinct from 'string' or length(phase->>key)>65536 then raise invalid_parameter_value;end if;
  end loop;
  for item in select value from jsonb_array_elements(phase->'pending') loop
   if jsonb_typeof(item)<>'string' or length(item#>>'{}') not between 1 and 128 then raise invalid_parameter_value;end if;
  end loop;
  foreach key in array array['replacements','replacementPositions'] loop
   if phase ? key then
    if jsonb_typeof(phase->key)<>'object' or (select count(*) from jsonb_object_keys(phase->key))>256 then raise invalid_parameter_value;end if;
    for pair in select * from jsonb_each(phase->key) loop
     if length(pair.key) not between 1 and 128 or jsonb_typeof(pair.value)<>'string' or length(pair.value#>>'{}') not between 1 and 128 then raise invalid_parameter_value;end if;
    end loop;
   end if;
  end loop;
  for session in select value from jsonb_array_elements(phase->'sessions') loop
   if jsonb_typeof(session)<>'object' or not(session ?& array['id','name','warmup','adjustable','minimum','maximum'])
    or exists(select 1 from jsonb_object_keys(session) k where k not in ('id','name','warmup','adjustable','minimum','maximum','positionId'))
    or jsonb_typeof(session->'adjustable') is distinct from 'boolean' then raise invalid_parameter_value;end if;
   foreach key in array array['id','name','minimum','maximum'] loop
    if jsonb_typeof(session->key) is distinct from 'string' or length(session->>key)>65536 then raise invalid_parameter_value;end if;
   end loop;
   if length(session->>'id') not between 1 and 128 or (session->'warmup'<>'null'::jsonb and (jsonb_typeof(session->'warmup')<>'string' or length(session->>'warmup') not between 1 and 128)) then raise invalid_parameter_value;end if;
   foreach key in array array['positionId'] loop
    if session ? key and (jsonb_typeof(session->key)<>'string' or length(session->>key) not between 1 and 128) then raise invalid_parameter_value;end if;
   end loop;
  end loop;
 end loop;
end $$;

create function trainer_private.program_work_projection(p_state jsonb) returns jsonb
language plpgsql immutable set search_path='' as $$
declare phase jsonb;session jsonb;phases jsonb:='[]';sessions jsonb;minimum integer;maximum integer;key text;
begin
 perform trainer_private.validate_program_work_state(p_state);
 for phase in select value from jsonb_array_elements(p_state->'phases') loop
  if jsonb_array_length(phase->'pending')>0 then raise exception 'Hay sesiones pendientes de incorporar.' using errcode='22023';end if;
  foreach key in array array['replacements','replacementPositions'] loop
   if coalesce(phase->key,'{}'::jsonb)<>'{}'::jsonb then raise exception 'Hay sustituciones pendientes de incorporar.' using errcode='22023';end if;
  end loop;
  sessions:='[]';
  for session in select value from jsonb_array_elements(phase->'sessions') loop
   minimum:=null;maximum:=null;
   if (session->>'adjustable')::boolean then
    minimum:=trainer_private.program_work_integer(session->>'minimum');maximum:=trainer_private.program_work_integer(session->>'maximum');
    if minimum is null or maximum is null then raise invalid_parameter_value;end if;
   end if;
   sessions:=sessions||jsonb_build_array(jsonb_build_object('template_id',session->'id','name',trainer_private.program_work_trim(session->>'name'),
    'warmup_id',session->'warmup','rest',jsonb_build_object('min_seconds',minimum,'max_seconds',maximum)));
  end loop;
  phases:=phases||jsonb_build_array(jsonb_build_object('name',case when p_state->>'mode'='guide' then 'Entrenamiento' else trainer_private.program_work_trim(phase->>'name') end,
   'duration_weeks',case when p_state->>'mode'='guide' then null else trainer_private.program_work_integer(phase->>'weeks') end,
   'instructions',trainer_private.program_work_trim(phase->>'instructions'),'sessions',sessions));
 end loop;
 return jsonb_build_object('name',trainer_private.program_work_trim(p_state->>'name'),'mode',p_state->'mode',
  'description',trainer_private.program_work_trim(p_state->>'description'),'audience',trainer_private.program_work_trim(p_state->>'audience'),
  'equipment',trainer_private.program_work_trim(p_state->>'equipment'),'phases',phases);
end $$;

create function trainer_private.check_program_work_request(p_operation trainer_private.program_work_operations,p_request jsonb,p_body jsonb) returns void
language plpgsql stable security definer set search_path='' as $$
declare stored jsonb;
begin
 select body into stored from trainer_private.program_work_bodies where owner_id=auth.uid() and context='trainer_private' and hash=p_operation.request_body_hash;
 if stored is distinct from p_body or p_operation.request_hash is distinct from trainer_private.program_work_hash(p_request) then
  raise exception 'El reintento no coincide con la petición de trabajo original.' using errcode='22023';end if;
end $$;

create function trainer_private.list_trainer_program_work(p_expected_owner uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
begin
 perform trainer_private.program_work_identity(p_expected_owner);
 -- El listado es un índice de recuperación; no transporta hasta 50 MiB de
 -- checkpoints ni debe poder utilizarse como estado completo para guardar.
 return(select coalesce(jsonb_agg(jsonb_build_object('id',w.id,'context',w.context,
  'state',jsonb_build_object('name',left(b.body->>'name',160)),'revision',w.revision,
  'base_program_id',w.base_program_id,'finalized_program_id',w.finalized_program_id,
  'updated_at',w.updated_at,'discarded_at',w.discarded_at,'lifecycle',w.lifecycle)
  order by w.updated_at desc,w.id desc),'[]') from
  (select * from trainer_private.program_works where owner_id=auth.uid() and context='trainer_private' and lifecycle='open' order by updated_at desc,id desc limit 100) w
  join trainer_private.program_work_bodies b on b.owner_id=w.owner_id and b.context=w.context and b.hash=w.state_hash);
end $$;
create function trainer_private.get_trainer_program_work(p_expected_owner uuid,p_id uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare work trainer_private.program_works;
begin
 perform trainer_private.program_work_identity(p_expected_owner);
 if p_id is null then raise invalid_parameter_value;end if;
 select * into work from trainer_private.program_works where owner_id=auth.uid() and context='trainer_private' and id=p_id;
 if not found then return null;end if;return trainer_private.program_work_json(work);
end $$;
create function trainer_private.save_trainer_program_work(p_expected_owner uuid,p_id uuid,p_revision bigint,p_state jsonb,p_base_program_id uuid default null) returns jsonb
language plpgsql security definer set search_path='' as $$
declare work trainer_private.program_works;prior trainer_private.program_work_operations;request jsonb;hash text;lim integer;receipt jsonb;
begin
 perform trainer_private.program_work_identity(p_expected_owner);
 if p_id is null or p_revision is null or p_revision not between 0 and 2147483646 then raise invalid_parameter_value;end if;
 perform trainer_private.validate_program_work_state(p_state);
 perform trainer_private.lock_program_work_owner(p_expected_owner);
 select * into work from trainer_private.program_works where owner_id=auth.uid() and context='trainer_private' and id=p_id for update;
 if found and (work.base_program_id is distinct from p_base_program_id or work.schema_version<>1) then raise invalid_parameter_value;end if;
 request:=jsonb_build_object('state',p_state,'base_program_id',p_base_program_id,'schema',1);
 select * into prior from trainer_private.program_work_operations where owner_id=auth.uid() and context='trainer_private' and work_id=p_id and action='save' and expected_revision=p_revision;
 if found then
  perform trainer_private.check_program_work_request(prior,request,p_state);
  return trainer_private.program_work_envelope(prior.receipt,work);
 end if;
 select snapshot_limit into lim from trainer_private.program_work_limits where owner_id=auth.uid();
 if octet_length(p_state::text)>lim then raise exception 'El estado supera el límite técnico por trabajo.' using errcode='54000';end if;
 if work.id is null then
  if p_revision<>0 then raise serialization_failure;end if;
  if p_base_program_id is not null then
   perform 1 from trainer_private.programs where id=p_base_program_id and trainer_id=auth.uid() and status='published' for share;
   if not found then raise insufficient_privilege;end if;
  end if;
  hash:=trainer_private.program_work_store_body(p_state);
  insert into trainer_private.program_works(owner_id,id,base_program_id,schema_version,state_hash,revision,lifecycle,updated_at)
   values(auth.uid(),p_id,p_base_program_id,1,hash,1,'open',clock_timestamp()) returning * into work;
 else
  if work.lifecycle<>'open' or work.revision<>p_revision then raise serialization_failure;end if;
  hash:=trainer_private.program_work_store_body(p_state);
  update trainer_private.program_works set state_hash=hash,revision=revision+1,updated_at=clock_timestamp()
   where owner_id=auth.uid() and context='trainer_private' and id=p_id returning * into work;
 end if;
 receipt:=trainer_private.program_work_receipt(work);
 insert into trainer_private.program_work_operations(owner_id,work_id,action,expected_revision,request_hash,request_body_hash,receipt)
  values(auth.uid(),p_id,'save',p_revision,trainer_private.program_work_hash(request),hash,receipt);
 return trainer_private.program_work_envelope(receipt,work);
end $$;

create function trainer_private.discard_trainer_program_work(p_expected_owner uuid,p_id uuid,p_revision bigint) returns jsonb
language plpgsql security definer set search_path='' as $$
declare work trainer_private.program_works;prior trainer_private.program_work_operations;request jsonb;hash text;receipt jsonb;
begin
 perform trainer_private.program_work_identity(p_expected_owner);
 if p_id is null or p_revision is null or p_revision not between 0 and 2147483646 then raise invalid_parameter_value;end if;
 perform trainer_private.lock_program_work_owner(p_expected_owner);
 select * into work from trainer_private.program_works where owner_id=auth.uid() and context='trainer_private' and id=p_id for update;
 if not found then raise insufficient_privilege;end if;
 request:=jsonb_build_object('action','discard','base_program_id',work.base_program_id,'schema',work.schema_version);
 select * into prior from trainer_private.program_work_operations where owner_id=auth.uid() and context='trainer_private' and work_id=p_id and action='discard' and expected_revision=p_revision;
 if found then
  perform trainer_private.check_program_work_request(prior,request,'{}');
  return trainer_private.program_work_envelope(prior.receipt,work);
 end if;
 if work.lifecycle<>'open' or work.revision<>p_revision then raise serialization_failure;end if;
 hash:=trainer_private.program_work_store_body('{}');
 update trainer_private.program_works set lifecycle='discarded',discarded_at=clock_timestamp(),revision=revision+1,updated_at=clock_timestamp()
  where owner_id=auth.uid() and context='trainer_private' and id=p_id returning * into work;
 receipt:=trainer_private.program_work_receipt(work);
 insert into trainer_private.program_work_operations(owner_id,work_id,action,expected_revision,request_hash,request_body_hash,receipt)
  values(auth.uid(),p_id,'discard',p_revision,trainer_private.program_work_hash(request),hash,receipt);
 return trainer_private.program_work_envelope(receipt,work);
end $$;

create function trainer_private.finalize_trainer_program_work(p_expected_owner uuid,p_id uuid,p_revision bigint,p_content jsonb) returns uuid
language plpgsql security definer set search_path='' as $$
declare work trainer_private.program_works;prior trainer_private.program_work_operations;request jsonb;state jsonb;projected jsonb;hash text;receipt jsonb;result uuid;
begin
 perform trainer_private.program_work_identity(p_expected_owner);
 if p_id is null or p_revision is null or p_revision not between 0 and 2147483646 or p_content is null
  or jsonb_typeof(p_content)<>'object' or octet_length(p_content::text)>524288 then raise invalid_parameter_value;end if;
 select * into work from trainer_private.program_works where owner_id=auth.uid() and context='trainer_private' and id=p_id;
 if not found then raise insufficient_privilege;end if;
 request:=jsonb_build_object('content',p_content,'base_program_id',work.base_program_id,'schema',work.schema_version);
 -- Un recibo final propio no depende del acceso vigente ni de que su propia
 -- finalización haya archivado ya la base. No llama otra vez al motor legacy.
 select * into prior from trainer_private.program_work_operations where owner_id=auth.uid() and context='trainer_private' and work_id=p_id and action='finalize' and expected_revision=p_revision;
 if found then
  perform trainer_private.check_program_work_request(prior,request,p_content);
  return (prior.receipt->>'finalized_program_id')::uuid;
 end if;
 if work.lifecycle<>'open' then raise serialization_failure;end if;
 perform trainer_private.lock_program_work_owner(p_expected_owner);
 select * into work from trainer_private.program_works where owner_id=auth.uid() and context='trainer_private' and id=p_id for update;
 select * into prior from trainer_private.program_work_operations where owner_id=auth.uid() and context='trainer_private' and work_id=p_id and action='finalize' and expected_revision=p_revision;
 if found then
  perform trainer_private.check_program_work_request(prior,request,p_content);
  return (prior.receipt->>'finalized_program_id')::uuid;
 end if;
 if work.lifecycle<>'open' or work.revision<>p_revision then raise serialization_failure;end if;
 if exists(select 1 from trainer_private.program_writes where trainer_id=auth.uid() and operation_id=p_id) then
  raise exception 'El ID de este trabajo ya identifica otra operación de programa. Conserva el trabajo y revisa el conflicto.' using errcode='22023';end if;
 select body into state from trainer_private.program_work_bodies where owner_id=auth.uid() and context='trainer_private' and program_work_bodies.hash=work.state_hash;
 projected:=trainer_private.program_work_projection(state);
 if projected is distinct from p_content then raise exception 'El programa final no coincide con el estado guardado.' using errcode='22023';end if;
 hash:=trainer_private.program_work_store_body(p_content);
 begin
  result:=trainer_private.save_trainer_program(p_id,p_content,work.base_program_id);
 exception when unique_violation then
  -- Un ledger legacy confirmado después del snapshot RR no es nuestro recibo.
  -- La subtransacción revierte cualquier versión/archivo provisional del motor.
  raise exception 'Otra operación ha utilizado este ID o revisado la base. Conserva el trabajo y recarga.' using errcode='40001';
 end;
 update trainer_private.program_works set lifecycle='finalized',finalized_program_id=result,revision=revision+1,updated_at=clock_timestamp()
  where owner_id=auth.uid() and context='trainer_private' and id=p_id returning * into work;
 receipt:=trainer_private.program_work_receipt(work);
 insert into trainer_private.program_work_operations(owner_id,work_id,action,expected_revision,request_hash,request_body_hash,receipt)
  values(auth.uid(),p_id,'finalize',p_revision,trainer_private.program_work_hash(request),hash,receipt);
 return result;
end $$;

do $$ declare f record;begin
 for f in select p.oid::regprocedure signature from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='trainer_private'
  and (p.proname like 'program_work_%' or p.proname in ('lock_program_work_owner','validate_program_work_state','check_program_work_request',
   'list_trainer_program_work','get_trainer_program_work','save_trainer_program_work','discard_trainer_program_work','finalize_trainer_program_work')) loop
  execute format('revoke all on function %s from public,anon,authenticated',f.signature);
 end loop;
end $$;
create function public.list_trainer_program_work(p_expected_owner uuid) returns jsonb
language sql stable security invoker set search_path='' as $$select trainer_private.list_trainer_program_work(p_expected_owner)$$;
create function public.get_trainer_program_work(p_expected_owner uuid,p_id uuid) returns jsonb
language sql stable security invoker set search_path='' as $$select trainer_private.get_trainer_program_work(p_expected_owner,p_id)$$;
create function public.save_trainer_program_work(p_expected_owner uuid,p_id uuid,p_revision bigint,p_state jsonb,p_base_program_id uuid default null) returns jsonb
language sql security invoker set search_path='' as $$select trainer_private.save_trainer_program_work(p_expected_owner,p_id,p_revision,p_state,p_base_program_id)$$;
create function public.discard_trainer_program_work(p_expected_owner uuid,p_id uuid,p_revision bigint) returns jsonb
language sql security invoker set search_path='' as $$select trainer_private.discard_trainer_program_work(p_expected_owner,p_id,p_revision)$$;
create function public.finalize_trainer_program_work(p_expected_owner uuid,p_id uuid,p_revision bigint,p_content jsonb) returns uuid
language sql security invoker set search_path='' as $$select trainer_private.finalize_trainer_program_work(p_expected_owner,p_id,p_revision,p_content)$$;
do $$ declare f record;begin
 for f in select p.oid::regprocedure signature from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname in ('public','trainer_private')
  and p.proname in ('list_trainer_program_work','get_trainer_program_work','save_trainer_program_work','discard_trainer_program_work','finalize_trainer_program_work') loop
  execute format('revoke all on function %s from public,anon,authenticated',f.signature);
  execute format('grant execute on function %s to authenticated',f.signature);
 end loop;
end $$;

commit;
