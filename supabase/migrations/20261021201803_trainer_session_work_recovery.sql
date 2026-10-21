begin;

create table trainer_private.session_work_limits (
 owner_id uuid primary key references public.profiles(id) on delete cascade,
 active_limit integer not null default 100 check(active_limit between 0 and 100),
 snapshot_limit integer not null default 524288 check(snapshot_limit between 1 and 524288),
 byte_limit bigint not null default 67108864 check(byte_limit between 4096 and 67108864),
 hourly_limit integer not null default 1200 check(hourly_limit between 0 and 1200),
 active_count integer not null default 0 check(active_count>=0),
 retained_bytes bigint not null default 4096 check(retained_bytes>=4096),
 write_revision bigint not null default 0 check(write_revision>=0)
);
create table trainer_private.session_work_bodies (
 owner_id uuid not null references trainer_private.session_work_limits(owner_id) on delete cascade,
 context text not null default 'trainer_private' check(context='trainer_private'),
 hash text not null check(hash~'^[0-9a-f]{64}$'),body jsonb not null,
 logical_bytes bigint not null default 0,primary key(owner_id,context,hash)
);
create table trainer_private.session_works (
 owner_id uuid not null references trainer_private.session_work_limits(owner_id) on delete cascade,
 context text not null default 'trainer_private' check(context='trainer_private'),
 id uuid not null,origin jsonb not null,schema_version integer not null check(schema_version=1),
 state_hash text not null,revision bigint not null check(revision between 1 and 2147483647),
 lifecycle text not null check(lifecycle in ('open','discarded','finalized')),
 result_id uuid,updated_at timestamptz not null,discarded_at timestamptz,
 logical_bytes bigint not null default 0,
 primary key(owner_id,context,id),
 foreign key(owner_id,context,state_hash) references trainer_private.session_work_bodies(owner_id,context,hash) deferrable initially deferred,
 check((lifecycle='open' and result_id is null and discarded_at is null)
  or (lifecycle='discarded' and result_id is null and discarded_at is not null)
  or (lifecycle='finalized' and result_id is not null and discarded_at is null))
);
create index trainer_session_work_open on trainer_private.session_works(owner_id,updated_at desc,id desc) where lifecycle='open';
create table trainer_private.session_work_operations (
 owner_id uuid not null references trainer_private.session_work_limits(owner_id) on delete cascade,
 context text not null default 'trainer_private' check(context='trainer_private'),work_id uuid not null,
 action text not null check(action in ('save','discard','reopen','finalize')),
 expected_revision bigint not null check(expected_revision between 0 and 2147483646),
 request_hash text not null check(request_hash~'^[0-9a-f]{64}$'),request_body_hash text not null,
 receipt jsonb not null,created_at timestamptz not null default clock_timestamp(),logical_bytes bigint not null default 0,
 primary key(owner_id,context,work_id,action,expected_revision),
 foreign key(owner_id,context,work_id) references trainer_private.session_works(owner_id,context,id) on delete cascade,
 foreign key(owner_id,context,request_body_hash) references trainer_private.session_work_bodies(owner_id,context,hash) deferrable initially deferred
);
create index trainer_session_work_rate on trainer_private.session_work_operations(owner_id,created_at);
do $$ declare tab text;begin
 foreach tab in array array['session_work_limits','session_work_bodies','session_works','session_work_operations'] loop
  execute format('alter table trainer_private.%I enable row level security',tab);
  execute format('revoke all on trainer_private.%I from public,anon,authenticated',tab);
 end loop;
end $$;

create function trainer_private.session_work_identity(p_expected_owner uuid) returns void
language plpgsql stable security definer set search_path='' as $$
begin
 -- expected_owner es solo una barrera contra cambiar headers A→B. Nunca es
 -- autoridad para elegir propietario: todas las consultas usan auth.uid().
 if p_expected_owner is null or auth.uid() is distinct from p_expected_owner
  or not trainer_private.has_trainer_mfa() then raise insufficient_privilege;end if;
end $$;

create function trainer_private.lock_session_work_owner(p_expected_owner uuid) returns void
language plpgsql security definer set search_path='' as $$
begin
 perform trainer_private.session_work_identity(p_expected_owner);
 perform 1 from public.profiles where id=auth.uid() for key share;
 if not found then raise insufficient_privilege;end if;
 perform trainer_private.require_authoring_access();
 -- Serializa también dos trabajos distintos y la ausencia inicial de la fila
 -- de presupuesto. El UPDATE invalida snapshots RR anteriores al ganador.
 insert into trainer_private.session_work_limits(owner_id,write_revision) values(auth.uid(),1)
  on conflict(owner_id) do update set write_revision=trainer_private.session_work_limits.write_revision+1;
end $$;

create function trainer_private.session_work_charge() returns trigger
language plpgsql security definer set search_path='' set timezone='UTC' as $$
begin
 -- La envoltura JSON completa contabiliza IDs, contexto, fechas y hashes.
 -- 64 bytes adicionales cubren el propio contador, sin prometer tamaño físico.
 new.logical_bytes:=octet_length((to_jsonb(new)-'logical_bytes')::text)+64;
 return new;
end $$;
create function trainer_private.session_work_account() returns trigger
language plpgsql security definer set search_path='' as $$
declare owner uuid;delta bigint;active_delta integer:=0;
begin
 owner:=case when tg_op='DELETE' then old.owner_id else new.owner_id end;
 delta:=case when tg_op='INSERT' then new.logical_bytes when tg_op='DELETE' then -old.logical_bytes else new.logical_bytes-old.logical_bytes end;
 if tg_table_name='session_works' then
  if tg_op<>'DELETE' and new.lifecycle='open' then active_delta:=active_delta+1;end if;
  if tg_op<>'INSERT' and old.lifecycle='open' then active_delta:=active_delta-1;end if;
 end if;
 update trainer_private.session_work_limits set retained_bytes=retained_bytes+delta,active_count=active_count+active_delta
  where owner_id=owner and retained_bytes+delta between 4096 and byte_limit
   and active_count+active_delta>=0 and (active_delta<=0 or active_count+active_delta<=active_limit);
 if not found and exists(select 1 from trainer_private.session_work_limits where owner_id=owner) then
  raise exception 'Has alcanzado el presupuesto técnico de trabajos de sesiones.' using errcode='54000';end if;
 -- En el CASCADE del propietario el presupuesto ya no existe; no reconstruirlo.
 if tg_op='DELETE' then return old;end if;return new;
end $$;
create function trainer_private.session_work_immutable() returns trigger
language plpgsql security definer set search_path='' as $$
begin
 if tg_table_name<>'session_works' then raise exception 'El recibo y su cuerpo son inmutables.' using errcode='22023';end if;
 if new.owner_id is distinct from old.owner_id or new.context is distinct from old.context or new.id is distinct from old.id
  or new.origin is distinct from old.origin or new.schema_version is distinct from old.schema_version then raise invalid_parameter_value;end if;
 if old.lifecycle<>'open' or new.revision<>old.revision+1 then raise serialization_failure;end if;
 return new;
end $$;
create function trainer_private.session_work_rate() returns trigger
language plpgsql security definer set search_path='' as $$
declare lim integer;
begin
 select hourly_limit into lim from trainer_private.session_work_limits where owner_id=new.owner_id;
 if (select count(*) from trainer_private.session_work_operations where owner_id=new.owner_id and created_at>clock_timestamp()-interval '1 hour')>=lim then
  raise exception 'Has alcanzado el límite técnico de escrituras de trabajos por hora.' using errcode='54000';end if;
 return new;
end $$;
do $$ declare tab text;begin
 foreach tab in array array['session_work_bodies','session_works','session_work_operations'] loop
  execute format('create trigger aa_session_work_immutable before update on trainer_private.%I for each row execute function trainer_private.session_work_immutable()',tab);
  execute format('create trigger zz_session_work_charge before insert or update on trainer_private.%I for each row execute function trainer_private.session_work_charge()',tab);
  execute format('create trigger session_work_account after insert or update or delete on trainer_private.%I for each row execute function trainer_private.session_work_account()',tab);
 end loop;
end $$;
create trigger session_work_rate before insert on trainer_private.session_work_operations for each row execute function trainer_private.session_work_rate();

create function trainer_private.session_work_hash(p_body jsonb) returns text
language sql immutable set search_path='' as $$select encode(extensions.digest(p_body::text,'sha256'),'hex')$$;
create function trainer_private.session_work_store_body(p_body jsonb) returns text
language plpgsql security definer set search_path='' as $$
declare v_hash text:=trainer_private.session_work_hash(p_body);stored jsonb;
begin
 select body into stored from trainer_private.session_work_bodies where owner_id=auth.uid() and context='trainer_private' and session_work_bodies.hash=v_hash;
 if found then
  if stored is distinct from p_body then raise exception 'Conflicto de cuerpo inmutable.' using errcode='22023';end if;
 else
  insert into trainer_private.session_work_bodies(owner_id,hash,body) values(auth.uid(),v_hash,p_body);
 end if;return v_hash;
end $$;

create function trainer_private.session_work_json(p_work trainer_private.session_works) returns jsonb
language sql stable security definer set search_path='' as $$
 select jsonb_build_object('id',p_work.id,'context',p_work.context,'state',b.body,'revision',p_work.revision,
  'origin',p_work.origin,'result_id',p_work.result_id,
  'updated_at',p_work.updated_at,'discarded_at',p_work.discarded_at,'lifecycle',p_work.lifecycle)
 from trainer_private.session_work_bodies b where b.owner_id=p_work.owner_id and b.context=p_work.context and b.hash=p_work.state_hash;
$$;
-- El recibo conserva la metadata histórica y el hash de estado; el cuerpo se
-- almacena una sola vez y no se sustituye por el HEAD de otra pestaña.
create function trainer_private.session_work_receipt(p_work trainer_private.session_works) returns jsonb
language sql stable set search_path='' as $$select to_jsonb(p_work)-'logical_bytes'$$;
create function trainer_private.session_work_envelope(p_receipt jsonb,p_current trainer_private.session_works) returns jsonb
language sql stable security definer set search_path='' as $$
 select jsonb_build_object('receipt',jsonb_build_object('work',jsonb_build_object(
  'id',p_receipt->'id','context',p_receipt->'context','state',b.body,'revision',p_receipt->'revision',
  'origin',p_receipt->'origin','result_id',p_receipt->'result_id',
  'updated_at',p_receipt->'updated_at','discarded_at',p_receipt->'discarded_at','lifecycle',p_receipt->'lifecycle')),
  'current_revision',p_current.revision,'current_lifecycle',p_current.lifecycle)
 from trainer_private.session_work_bodies b where b.owner_id=auth.uid() and b.context='trainer_private' and b.hash=p_receipt->>'state_hash';
$$;

-- Contrato de formulario, no un segundo algoritmo de conversión deportiva.
-- La intención es la receta validada por el motor existente; ambos cuerpos
-- quedan congelados y auditables aunque un autor envíe raw e intent distintos.
create function trainer_private.session_work_fields(p_row jsonb,p_required text[],p_optional text[],p_texts text[]) returns void
language plpgsql immutable set search_path='' as $$
declare key text;
begin
 if p_row is null or jsonb_typeof(p_row)<>'object' or not(p_row ?& p_required)
  or (p_row-(p_required||p_optional))<>'{}'::jsonb then raise invalid_parameter_value;end if;
 foreach key in array p_texts loop
  if jsonb_typeof(p_row->key) is distinct from 'string' or length(p_row->>key)>10000 then raise invalid_parameter_value;end if;
 end loop;
end $$;

create function trainer_private.validate_session_work_origin(p_origin jsonb) returns void
language plpgsql immutable set search_path='' as $$
declare base uuid;
begin
 perform trainer_private.session_work_fields(p_origin,
  array['baseId','programId','parentWorkId','phaseId','positionId','duplicate'],'{}','{}');
 if octet_length(p_origin::text)>4096 or jsonb_typeof(p_origin->'duplicate') is distinct from 'boolean'
  or p_origin->'programId' is distinct from 'null'::jsonb or p_origin->'parentWorkId' is distinct from 'null'::jsonb
  or p_origin->'phaseId' is distinct from 'null'::jsonb or p_origin->'positionId' is distinct from 'null'::jsonb then
  raise exception 'Este contexto solo admite trabajos de biblioteca profesional.' using errcode='22023';end if;
 if p_origin->'baseId'<>'null'::jsonb then
  if jsonb_typeof(p_origin->'baseId')<>'string' then raise invalid_parameter_value;end if;
  begin base:=(p_origin->>'baseId')::uuid;exception when invalid_text_representation then raise invalid_parameter_value;end;
 end if;
 if (p_origin->>'duplicate')::boolean and base is null then raise invalid_parameter_value;end if;
end $$;

create function trainer_private.validate_session_work_state(p_state jsonb) returns void
language plpgsql immutable set search_path='' as $$
declare editor jsonb;segment jsonb;block jsonb;exercise jsonb;variation jsonb;indices integer[];idx integer;total integer:=0;
begin
 perform trainer_private.session_work_fields(p_state,array['schema','editor','context'],array['intent'],'{}');
 if p_state->'schema' is distinct from '1'::jsonb or p_state->'context' is distinct from '{}'::jsonb
  or octet_length(p_state::text)>524288
  or (p_state ? 'intent' and jsonb_typeof(p_state->'intent')<>'object') then raise invalid_parameter_value;end if;
 editor:=p_state->'editor';
 perform trainer_private.session_work_fields(editor,
  array['schema','running','nameText','descriptionText','durationText','segments','blocks'],'{}',
  array['nameText','descriptionText','durationText']);
 if editor->'schema' is distinct from '1'::jsonb or jsonb_typeof(editor->'running') is distinct from 'boolean'
  or jsonb_typeof(editor->'segments') is distinct from 'array' or jsonb_typeof(editor->'blocks') is distinct from 'array'
  or jsonb_array_length(editor->'segments')>40 or jsonb_array_length(editor->'blocks')>100 then raise invalid_parameter_value;end if;
 for segment in select value from jsonb_array_elements(editor->'segments') loop
  perform trainer_private.session_work_fields(segment,
   array['countText','targetText','paceText','paceMaxText','recoveryTimeText','byDistance','recoveryByDistance','recoveryType'],'{}',
   array['countText','targetText','paceText','paceMaxText','recoveryTimeText']);
  if jsonb_typeof(segment->'byDistance') is distinct from 'boolean' or jsonb_typeof(segment->'recoveryByDistance') is distinct from 'boolean'
   or (segment->'recoveryType'<>'null'::jsonb and (jsonb_typeof(segment->'recoveryType')<>'string'
    or segment->>'recoveryType' not in ('passive','walking','jogging'))) then raise invalid_parameter_value;end if;
 end loop;
 for block in select value from jsonb_array_elements(editor->'blocks') loop
  perform trainer_private.session_work_fields(block,array['nameText','format','roundsText','restText','capText','exercises'],'{}',
   array['nameText','roundsText','restText','capText']);
  if jsonb_typeof(block->'format') is distinct from 'string' or block->>'format' not in
   ('straightSets','circuit','superset','intervals','emom','amrap','tabata','running','warmUp','coolDown')
   or jsonb_typeof(block->'exercises') is distinct from 'array' or jsonb_array_length(block->'exercises')>100 then raise invalid_parameter_value;end if;
  for exercise in select value from jsonb_array_elements(block->'exercises') loop
   total:=total+1;if total>4096 then raise invalid_parameter_value;end if;
   perform trainer_private.session_work_fields(exercise,
    array['exerciseId','targetType','automaticSlot','customSets','countText','targetText','restText','loadText','rirText','amrapRepetitionsText','amrapRirText','variations'],'{}',
    array['countText','targetText','restText','loadText','rirText','amrapRepetitionsText','amrapRirText']);
   if (exercise->'exerciseId'<>'null'::jsonb and (jsonb_typeof(exercise->'exerciseId')<>'string' or length(exercise->>'exerciseId')>128))
    or jsonb_typeof(exercise->'targetType') is distinct from 'string' or exercise->>'targetType' not in ('repetitions','duration','distance')
    or jsonb_typeof(exercise->'automaticSlot') is distinct from 'boolean' or jsonb_typeof(exercise->'customSets') is distinct from 'boolean'
    or jsonb_typeof(exercise->'variations') is distinct from 'array' or jsonb_array_length(exercise->'variations')>20 then raise invalid_parameter_value;end if;
   indices:='{}';
   for variation in select value from jsonb_array_elements(exercise->'variations') loop
    perform trainer_private.session_work_fields(variation,array['setIndex','targetText','restText','loadText','rirText'],'{}',
     array['targetText','restText','loadText','rirText']);
    if jsonb_typeof(variation->'setIndex') is distinct from 'number' or variation->>'setIndex' !~ '^[0-9]{1,2}$' then raise invalid_parameter_value;end if;
    idx:=(variation->>'setIndex')::integer;
    if idx>=20 or idx=any(indices) then raise invalid_parameter_value;end if;
    indices:=array_append(indices,idx);
   end loop;
  end loop;
 end loop;
end $$;

create function trainer_private.check_session_work_request(p_prior trainer_private.session_work_operations,p_request jsonb) returns void
language plpgsql stable security definer set search_path='' as $$
declare stored jsonb;
begin
 select body into stored from trainer_private.session_work_bodies where owner_id=auth.uid() and context='trainer_private' and hash=p_prior.request_body_hash;
 if stored is distinct from p_request or p_prior.request_hash is distinct from trainer_private.session_work_hash(p_request) then
  raise exception 'El reintento no coincide con la petición de trabajo original.' using errcode='22023';end if;
end $$;

create function trainer_private.list_trainer_session_work(p_expected_owner uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
begin
 perform trainer_private.session_work_identity(p_expected_owner);
 return coalesce((select jsonb_agg(jsonb_build_object('id',w.id,'context',w.context,'origin',w.origin,
  'state',jsonb_build_object('editor',jsonb_build_object('nameText',left(b.body->'editor'->>'nameText',160)))
    ||case when b.body ? 'intent' then '{"intent":true}'::jsonb else '{}'::jsonb end,
  'revision',w.revision,'result_id',w.result_id,'lifecycle',w.lifecycle,'updated_at',w.updated_at,'discarded_at',w.discarded_at)
  order by w.updated_at desc,w.id desc)
  from (select * from trainer_private.session_works where owner_id=auth.uid() and context='trainer_private' and lifecycle='open'
   order by updated_at desc,id desc limit 100) w
  join trainer_private.session_work_bodies b on b.owner_id=w.owner_id and b.context=w.context and b.hash=w.state_hash),'[]'::jsonb);
end $$;

create function trainer_private.get_trainer_session_work(p_expected_owner uuid,p_id uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare work trainer_private.session_works;
begin
 perform trainer_private.session_work_identity(p_expected_owner);
 if p_id is null then raise invalid_parameter_value;end if;
 select * into work from trainer_private.session_works where owner_id=auth.uid() and context='trainer_private' and id=p_id;
 if not found then return null;end if;return trainer_private.session_work_json(work);
end $$;

create function trainer_private.save_trainer_session_work(p_expected_owner uuid,p_id uuid,p_revision bigint,p_origin jsonb,p_state jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare work trainer_private.session_works;prior trainer_private.session_work_operations;request jsonb;state jsonb;next_hash text;request_hash text;lim integer;receipt jsonb;
begin
 perform trainer_private.session_work_identity(p_expected_owner);
 if p_id is null or p_revision is null or p_revision not between 0 and 2147483646 then raise invalid_parameter_value;end if;
 perform trainer_private.validate_session_work_origin(p_origin);perform trainer_private.validate_session_work_state(p_state);
 perform trainer_private.lock_session_work_owner(p_expected_owner);
 select * into work from trainer_private.session_works where owner_id=auth.uid() and context='trainer_private' and id=p_id for update;
 if found and (work.origin is distinct from p_origin or work.schema_version<>1) then raise invalid_parameter_value;end if;
 request:=jsonb_build_object('state',p_state,'origin',p_origin,'schema',1);
 select * into prior from trainer_private.session_work_operations where owner_id=auth.uid() and context='trainer_private' and work_id=p_id and action='save' and expected_revision=p_revision;
 if found then perform trainer_private.check_session_work_request(prior,request);return trainer_private.session_work_envelope(prior.receipt,work);end if;
 select snapshot_limit into lim from trainer_private.session_work_limits where owner_id=auth.uid();
 if octet_length(p_state::text)>lim then raise exception 'El estado supera el límite técnico por trabajo.' using errcode='54000';end if;
 if work.id is null then
  if p_revision<>0 then raise serialization_failure;end if;
  if p_origin->'baseId'<>'null'::jsonb then
   perform 1 from public.workout_templates where id=(p_origin->>'baseId')::uuid and owner_user_id=auth.uid() and origin='coach' and status='published' for share;
   if not found then raise insufficient_privilege;end if;
  end if;
  next_hash:=trainer_private.session_work_store_body(p_state);
  insert into trainer_private.session_works(owner_id,id,origin,schema_version,state_hash,revision,lifecycle,updated_at)
   values(auth.uid(),p_id,p_origin,1,next_hash,1,'open',clock_timestamp()) returning * into work;
 else
  if work.lifecycle<>'open' or work.revision<>p_revision then raise serialization_failure;end if;
  select body into state from trainer_private.session_work_bodies where owner_id=auth.uid() and context='trainer_private' and session_work_bodies.hash=work.state_hash;
  if state ? 'intent' and state is distinct from p_state then
   raise exception 'Confirma o reabre la intención antes de editar.' using errcode='40001';end if;
  next_hash:=trainer_private.session_work_store_body(p_state);
  update trainer_private.session_works set state_hash=next_hash,revision=revision+1,updated_at=clock_timestamp()
   where owner_id=auth.uid() and context='trainer_private' and id=p_id returning * into work;
 end if;
 request_hash:=trainer_private.session_work_store_body(request);receipt:=trainer_private.session_work_receipt(work);
 insert into trainer_private.session_work_operations(owner_id,work_id,action,expected_revision,request_hash,request_body_hash,receipt)
  values(auth.uid(),p_id,'save',p_revision,trainer_private.session_work_hash(request),request_hash,receipt);
 return trainer_private.session_work_envelope(receipt,work);
end $$;

create function trainer_private.discard_trainer_session_work(p_expected_owner uuid,p_id uuid,p_revision bigint) returns jsonb
language plpgsql security definer set search_path='' as $$
declare work trainer_private.session_works;prior trainer_private.session_work_operations;request jsonb;hash text;receipt jsonb;state jsonb;
begin
 perform trainer_private.session_work_identity(p_expected_owner);
 if p_id is null or p_revision is null or p_revision not between 0 and 2147483646 then raise invalid_parameter_value;end if;
 perform trainer_private.lock_session_work_owner(p_expected_owner);
 select * into work from trainer_private.session_works where owner_id=auth.uid() and context='trainer_private' and id=p_id for update;
 if not found then raise insufficient_privilege;end if;
 request:=jsonb_build_object('action','discard','origin',work.origin,'schema',work.schema_version);
 select * into prior from trainer_private.session_work_operations where owner_id=auth.uid() and context='trainer_private' and work_id=p_id and action='discard' and expected_revision=p_revision;
 if found then perform trainer_private.check_session_work_request(prior,request);return trainer_private.session_work_envelope(prior.receipt,work);end if;
 if work.lifecycle<>'open' or work.revision<>p_revision then raise serialization_failure;end if;
 select body into state from trainer_private.session_work_bodies where owner_id=auth.uid() and context='trainer_private' and session_work_bodies.hash=work.state_hash;
 -- Una intención enviada puede estar esperando su confirmación en otra pestaña.
 if state ? 'intent' then raise exception 'Confirma o reabre el envío antes de descartar.' using errcode='40001';end if;
 hash:=trainer_private.session_work_store_body(request);
 update trainer_private.session_works set lifecycle='discarded',discarded_at=clock_timestamp(),revision=revision+1,updated_at=clock_timestamp()
  where owner_id=auth.uid() and context='trainer_private' and id=p_id returning * into work;
 receipt:=trainer_private.session_work_receipt(work);
 insert into trainer_private.session_work_operations(owner_id,work_id,action,expected_revision,request_hash,request_body_hash,receipt)
  values(auth.uid(),p_id,'discard',p_revision,trainer_private.session_work_hash(request),hash,receipt);
 return trainer_private.session_work_envelope(receipt,work);
end $$;

create function trainer_private.finalize_trainer_session_work(p_expected_owner uuid,p_id uuid,p_revision bigint) returns uuid
language plpgsql security definer set search_path='' as $$
declare work trainer_private.session_works;prior trainer_private.session_work_operations;request jsonb;state jsonb;hash text;receipt jsonb;result uuid;previous uuid;
begin
 perform trainer_private.session_work_identity(p_expected_owner);
 if p_id is null or p_revision is null or p_revision not between 0 and 2147483646 then raise invalid_parameter_value;end if;
 select * into work from trainer_private.session_works where owner_id=auth.uid() and context='trainer_private' and id=p_id;
 if not found then raise insufficient_privilege;end if;
 request:=jsonb_build_object('action','finalize','origin',work.origin,'schema',work.schema_version);
 -- Solo este recibo demuestra la operación propia; no se adopta workout_writes.
 select * into prior from trainer_private.session_work_operations where owner_id=auth.uid() and context='trainer_private' and work_id=p_id and action='finalize' and expected_revision=p_revision;
 if found then perform trainer_private.check_session_work_request(prior,request);return (prior.receipt->>'result_id')::uuid;end if;
 if work.lifecycle<>'open' then raise serialization_failure;end if;
 perform trainer_private.lock_session_work_owner(p_expected_owner);
 select * into work from trainer_private.session_works where owner_id=auth.uid() and context='trainer_private' and id=p_id for update;
 select * into prior from trainer_private.session_work_operations where owner_id=auth.uid() and context='trainer_private' and work_id=p_id and action='finalize' and expected_revision=p_revision;
 if found then perform trainer_private.check_session_work_request(prior,request);return (prior.receipt->>'result_id')::uuid;end if;
 if work.lifecycle<>'open' or work.revision<>p_revision then raise serialization_failure;end if;
 select body into state from trainer_private.session_work_bodies where owner_id=auth.uid() and context='trainer_private' and session_work_bodies.hash=work.state_hash;
 if not(state ? 'intent') then raise exception 'Guarda la intención antes de finalizar.' using errcode='22023';end if;
 if exists(select 1 from trainer_private.workout_writes where trainer_id=auth.uid() and operation_id=p_id) then
  raise exception 'El ID de este trabajo ya identifica otra operación de sesión. Conserva el trabajo y revisa el conflicto.' using errcode='22023';end if;
 previous:=case when (work.origin->>'duplicate')::boolean then null else (work.origin->>'baseId')::uuid end;
 hash:=trainer_private.session_work_store_body(request);
 begin
  result:=trainer_private.save_trainer_workout(p_id,state->'intent',previous);
 exception when unique_violation then
  raise exception 'Otra operación ha utilizado este ID o revisado la base. Conserva el trabajo y recarga.' using errcode='40001';
 end;
 update trainer_private.session_works set lifecycle='finalized',result_id=result,revision=revision+1,updated_at=clock_timestamp()
  where owner_id=auth.uid() and context='trainer_private' and id=p_id returning * into work;
 receipt:=trainer_private.session_work_receipt(work);
 insert into trainer_private.session_work_operations(owner_id,work_id,action,expected_revision,request_hash,request_body_hash,receipt)
  values(auth.uid(),p_id,'finalize',p_revision,trainer_private.session_work_hash(request),hash,receipt);
 return result;
end $$;

create function trainer_private.reopen_trainer_session_work(p_expected_owner uuid,p_id uuid,p_revision bigint) returns jsonb
language plpgsql security definer set search_path='' as $$
declare work trainer_private.session_works;prior trainer_private.session_work_operations;request jsonb;state jsonb;hash text;receipt jsonb;next_hash text;
begin
 perform trainer_private.session_work_identity(p_expected_owner);
 if p_id is null or p_revision is null or p_revision not between 0 and 2147483646 then raise invalid_parameter_value;end if;
 select * into work from trainer_private.session_works where owner_id=auth.uid() and context='trainer_private' and id=p_id;
 if not found then raise insufficient_privilege;end if;
 -- Un cierre ya confirmado solo se reconcilia: nunca se elimina su intención.
 -- En el camino abierto se mantiene perfil→acceso→presupuesto→trabajo.
 if work.lifecycle='finalized' then
  select * into work from trainer_private.session_works where owner_id=auth.uid() and context='trainer_private' and id=p_id for update;
 else
  perform trainer_private.lock_session_work_owner(p_expected_owner);
  select * into work from trainer_private.session_works where owner_id=auth.uid() and context='trainer_private' and id=p_id for update;
 end if;
 if work.lifecycle='finalized' then
  select * into prior from trainer_private.session_work_operations where owner_id=auth.uid() and context='trainer_private' and work_id=p_id and action='finalize' and expected_revision=p_revision;
  if not found then raise serialization_failure;end if;
  return trainer_private.session_work_envelope(prior.receipt,work);
 end if;
 request:=jsonb_build_object('action','reopen','origin',work.origin,'schema',work.schema_version);
 select * into prior from trainer_private.session_work_operations where owner_id=auth.uid() and context='trainer_private' and work_id=p_id and action='reopen' and expected_revision=p_revision;
 if found then perform trainer_private.check_session_work_request(prior,request);return trainer_private.session_work_envelope(prior.receipt,work);end if;
 if work.lifecycle<>'open' or work.revision<>p_revision then raise serialization_failure;end if;
 select body into state from trainer_private.session_work_bodies where owner_id=auth.uid() and context='trainer_private' and session_work_bodies.hash=work.state_hash;
 if not(state ? 'intent') then raise exception 'No existe una intención que reabrir.' using errcode='22023';end if;
 next_hash:=trainer_private.session_work_store_body(state-'intent');hash:=trainer_private.session_work_store_body(request);
 update trainer_private.session_works set state_hash=next_hash,revision=revision+1,updated_at=clock_timestamp()
  where owner_id=auth.uid() and context='trainer_private' and id=p_id returning * into work;
 receipt:=trainer_private.session_work_receipt(work);
 insert into trainer_private.session_work_operations(owner_id,work_id,action,expected_revision,request_hash,request_body_hash,receipt)
  values(auth.uid(),p_id,'reopen',p_revision,trainer_private.session_work_hash(request),hash,receipt);
 return trainer_private.session_work_envelope(receipt,work);
end $$;

do $$ declare f record;begin
 for f in select p.oid::regprocedure signature from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='trainer_private'
  and (p.proname like 'session_work_%' or p.proname in ('lock_session_work_owner','validate_session_work_origin','validate_session_work_state','check_session_work_request',
   'list_trainer_session_work','get_trainer_session_work','save_trainer_session_work','discard_trainer_session_work','finalize_trainer_session_work','reopen_trainer_session_work')) loop
  execute format('revoke all on function %s from public,anon,authenticated',f.signature);
 end loop;
end $$;

create function public.list_trainer_session_work(p_expected_owner uuid) returns jsonb
language sql stable security invoker set search_path='' as $$select trainer_private.list_trainer_session_work(p_expected_owner)$$;
create function public.get_trainer_session_work(p_expected_owner uuid,p_id uuid) returns jsonb
language sql stable security invoker set search_path='' as $$select trainer_private.get_trainer_session_work(p_expected_owner,p_id)$$;
create function public.save_trainer_session_work(p_expected_owner uuid,p_id uuid,p_revision bigint,p_origin jsonb,p_state jsonb) returns jsonb
language sql security invoker set search_path='' as $$select trainer_private.save_trainer_session_work(p_expected_owner,p_id,p_revision,p_origin,p_state)$$;
create function public.discard_trainer_session_work(p_expected_owner uuid,p_id uuid,p_revision bigint) returns jsonb
language sql security invoker set search_path='' as $$select trainer_private.discard_trainer_session_work(p_expected_owner,p_id,p_revision)$$;
create function public.finalize_trainer_session_work(p_expected_owner uuid,p_id uuid,p_revision bigint) returns uuid
language sql security invoker set search_path='' as $$select trainer_private.finalize_trainer_session_work(p_expected_owner,p_id,p_revision)$$;
create function public.reopen_trainer_session_work(p_expected_owner uuid,p_id uuid,p_revision bigint) returns jsonb
language sql security invoker set search_path='' as $$select trainer_private.reopen_trainer_session_work(p_expected_owner,p_id,p_revision)$$;
revoke all on function public.list_trainer_session_work(uuid),public.get_trainer_session_work(uuid,uuid),
 public.save_trainer_session_work(uuid,uuid,bigint,jsonb,jsonb),public.discard_trainer_session_work(uuid,uuid,bigint),
 public.finalize_trainer_session_work(uuid,uuid,bigint),public.reopen_trainer_session_work(uuid,uuid,bigint) from public,anon,authenticated;
grant execute on function public.list_trainer_session_work(uuid),public.get_trainer_session_work(uuid,uuid),
 public.save_trainer_session_work(uuid,uuid,bigint,jsonb,jsonb),public.discard_trainer_session_work(uuid,uuid,bigint),
 public.finalize_trainer_session_work(uuid,uuid,bigint),public.reopen_trainer_session_work(uuid,uuid,bigint),
 trainer_private.list_trainer_session_work(uuid),trainer_private.get_trainer_session_work(uuid,uuid),
 trainer_private.save_trainer_session_work(uuid,uuid,bigint,jsonb,jsonb),trainer_private.discard_trainer_session_work(uuid,uuid,bigint),
 trainer_private.finalize_trainer_session_work(uuid,uuid,bigint),trainer_private.reopen_trainer_session_work(uuid,uuid,bigint) to authenticated;
commit;

