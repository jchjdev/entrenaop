begin;
create table trainer_private.assessment_limits (
 trainer_id uuid primary key references public.profiles(id) on delete cascade,
 version_limit integer not null default 100 check(version_limit between 1 and 10000)
);
create table trainer_private.assessment_protocols (
 id uuid primary key default gen_random_uuid(),trainer_id uuid not null references public.profiles(id) on delete cascade,
 protocol_key text not null,version integer not null check(version>0),fingerprint text not null,content jsonb not null,
 unique(trainer_id,protocol_key,version),unique(trainer_id,protocol_key,fingerprint)
);
create table trainer_private.assessments (
 id uuid primary key default gen_random_uuid(),trainer_id uuid not null references public.profiles(id) on delete cascade,
 family_id uuid not null,version integer not null check(version>0),current boolean not null default true,
 previous_id uuid references trainer_private.assessments(id) on delete restrict,
 content jsonb not null check(jsonb_typeof(content)='object' and octet_length(content::text)<=196608),
 created_at timestamptz not null default now(),unique(family_id,version)
);
create index trainer_assessments_owner on trainer_private.assessments(trainer_id,created_at desc,id desc);
create index trainer_assessments_previous on trainer_private.assessments(previous_id);
create table trainer_private.assessment_writes (
 trainer_id uuid not null references public.profiles(id) on delete cascade,operation_id uuid not null,
 previous_id uuid,expected_revision integer not null,payload jsonb not null,
 assessment_id uuid not null references trainer_private.assessments(id) on delete restrict,
 primary key(trainer_id,operation_id)
);
create index trainer_assessment_writes_target on trainer_private.assessment_writes(assessment_id);
create table trainer_private.assessment_deliveries (
 id uuid primary key,trainer_id uuid not null references public.profiles(id) on delete cascade,
 client_id uuid not null references public.profiles(id) on delete cascade,
 relation_id uuid not null references public.trainer_client_relations(id) on delete restrict,
 assessment_id uuid not null references trainer_private.assessments(id) on delete restrict,
 scheduled_date date not null check(scheduled_date between date '2000-01-01' and date '2200-12-31'),
 status text not null default 'planned' check(status in ('planned','in_progress','completed','withdrawn')),
 revision integer not null default 0 check(revision>=0),answers jsonb not null default '{}' check(jsonb_typeof(answers)='object'),
 created_at timestamptz not null default now(),started_at timestamptz,completed_at timestamptz,
 check((status in ('planned','withdrawn') and started_at is null and completed_at is null)
  or (status='in_progress' and started_at is not null and completed_at is null)
  or (status='completed' and started_at is not null and completed_at is not null))
);
create index trainer_assessment_deliveries_owner on trainer_private.assessment_deliveries(trainer_id,client_id,created_at desc,id desc);
create index trainer_assessment_deliveries_client on trainer_private.assessment_deliveries(client_id,created_at desc,id desc);
create index trainer_assessment_deliveries_relation on trainer_private.assessment_deliveries(relation_id);
create index trainer_assessment_deliveries_battery on trainer_private.assessment_deliveries(assessment_id);
create table trainer_private.assessment_result_revisions (
 actor_id uuid not null references public.profiles(id) on delete cascade,operation_id uuid not null,
 delivery_id uuid not null references trainer_private.assessment_deliveries(id) on delete cascade,
 action text not null,expected_revision integer not null,payload jsonb not null,result jsonb not null,
 created_at timestamptz not null default now(),primary key(actor_id,operation_id)
);
create index trainer_assessment_result_delivery on trainer_private.assessment_result_revisions(delivery_id);
do $$declare t text;begin
 foreach t in array array['assessment_limits','assessment_protocols','assessments','assessment_writes','assessment_deliveries','assessment_result_revisions'] loop
  execute format('alter table trainer_private.%I enable row level security',t);
  execute format('revoke all on trainer_private.%I from public,anon,authenticated',t);
 end loop;
end $$;

-- Solo contratos escalares íntegramente aplicables, sin datos personales de
-- contexto. Fuentes por columna/edad específica no se ofrecen aún. No puntúa.
create function trainer_private.assessment_official_eligible(t public.program_assessment_tests) returns boolean
language sql stable set search_path='' as $$
 select t.category='both' and t.min_age=0 and t.max_age=120
  and t.unit in ('repetitions','seconds','meters') and t.mark_step between 0.000001 and 1000000000
  and t.max_attempts between 1 and 10 and t.retry_policy in ('none','always','invalid_only')
  and (t.unit<>'repetitions' or mod(t.mark_step,1)=0)
  and length(btrim(t.protocol_notes)) between 10 and 2000
  and exists(select 1 from public.preparation_programs p where p.id=t.program_id and p.enabled);
$$;
create function trainer_private.list_trainer_assessment_catalog() returns jsonb
language plpgsql stable security definer set search_path='' as $$
begin
 if not trainer_private.has_trainer_mfa() or not exists(select 1 from public.trainer_access where trainer_id=auth.uid()
  and enabled and (valid_until is null or valid_until>statement_timestamp())) then raise insufficient_privilege;end if;
 return (select coalesce(jsonb_agg(jsonb_build_object('id',t.id,'program_id',t.program_id,'name',t.name,
  'definition_version',t.definition_version,'unit',t.unit,'direction',t.better_direction,'resolution',t.mark_step,
  'instructions',t.protocol_notes,'max_attempts',t.max_attempts,'retry_policy',t.retry_policy,'source','official','official_test_id',t.id)
  order by t.program_id,t.display_order,t.id),'[]') from public.program_assessment_tests t
  where trainer_private.assessment_official_eligible(t));
end $$;
create function trainer_private.assessment_snapshot(p_payload jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare t jsonb; snapshot jsonb; tests jsonb:='[]'; ids text[]:='{}'; protocol_keys text[]:='{}'; official public.program_assessment_tests;
 key text; contract_fingerprint text; protocol trainer_private.assessment_protocols; next_version integer;
begin
 if p_payload is null or jsonb_typeof(p_payload)<>'object' or octet_length(p_payload::text)>131072
  or exists(select 1 from jsonb_object_keys(p_payload) k where k not in ('title','description','tests'))
  or not trainer_private.form_text_valid(p_payload->'title',120,true)
  or not trainer_private.form_text_valid(p_payload->'description',1000)
  or jsonb_typeof(p_payload->'tests') is distinct from 'array' then raise invalid_parameter_value; end if;
 if jsonb_array_length(p_payload->'tests') not between 1 and 40 then raise invalid_parameter_value; end if;
 for t in select value from jsonb_array_elements(p_payload->'tests') loop
  if jsonb_typeof(t)<>'object' or jsonb_typeof(t->'id') is distinct from 'string'
   or t->>'id' !~ '^[A-Za-z0-9][A-Za-z0-9_-]{0,63}$' or t->>'id'=any(ids)
   or coalesce(t->>'source','') not in ('custom','official') then raise invalid_parameter_value; end if;
  ids:=array_append(ids,t->>'id');
  if t->>'source'='official' then
   if exists(select 1 from jsonb_object_keys(t) k where k not in ('id','source','official_test_id')) then raise invalid_parameter_value; end if;
   select * into official from public.program_assessment_tests where id=(t->>'official_test_id')::uuid;
   if not found or not trainer_private.assessment_official_eligible(official) then
    raise exception 'Este protocolo oficial no está publicado o no tiene un contrato aplicable completo.' using errcode='22023'; end if;
   snapshot:=jsonb_build_object('name',official.name,'unit',official.unit,'direction',official.better_direction,
    'resolution',official.mark_step,'instructions',official.protocol_notes,'max_attempts',official.max_attempts,
    'retry_policy',official.retry_policy,'source','official','official_test_id',official.id,'program_id',official.program_id,
    'definition_version',official.definition_version,'category',official.category,'min_age',official.min_age,'max_age',official.max_age,
    'distance_meters',official.distance_meters,'measurement_protocol',official.measurement_protocol,'scoring_available',false);
   key:='official:'||official.id::text||':'||official.definition_version::text;
  else
   if exists(select 1 from jsonb_object_keys(t) k where k not in ('id','source','name','unit','direction','resolution','instructions','max_attempts','retry_policy'))
    or not trainer_private.form_text_valid(t->'name',120,true)
    or not trainer_private.form_text_valid(t->'instructions',2000,true) or length(t->>'instructions')<10
    or coalesce(t->>'unit','') not in ('repetitions','seconds','meters') or coalesce(t->>'direction','') not in ('higher','lower')
    or jsonb_typeof(t->'resolution') is distinct from 'number' or (t->>'resolution')::numeric not between 0.000001 and 1000000000
    or jsonb_typeof(t->'max_attempts') is distinct from 'number' or (t->>'max_attempts') !~ '^([1-9]|10)$'
    or coalesce(t->>'retry_policy','') not in ('none','always','invalid_only') then raise invalid_parameter_value; end if;
   if ((t->>'max_attempts')::integer=1)<>(t->>'retry_policy'='none')
    or (t->>'unit'='repetitions' and mod((t->>'resolution')::numeric,1)<>0) then raise invalid_parameter_value; end if;
   snapshot:=(t-'id')||jsonb_build_object('scoring_available',false);key:='custom:'||(t->>'id');
  end if;
  if key=any(protocol_keys) then raise exception 'Una misma prueba oficial no puede duplicarse dentro de la batería.' using errcode='22023';end if;
  protocol_keys:=array_append(protocol_keys,key);
  contract_fingerprint:=md5(jsonb_build_object('trainer',auth.uid(),'key',key,'contract',snapshot)::text);
  select * into protocol from trainer_private.assessment_protocols where trainer_id=auth.uid() and protocol_key=key and fingerprint=contract_fingerprint;
  if not found then
   select coalesce(max(version),0)+1 into next_version from trainer_private.assessment_protocols where trainer_id=auth.uid() and protocol_key=key;
   insert into trainer_private.assessment_protocols(trainer_id,protocol_key,version,fingerprint,content)
    values(auth.uid(),key,next_version,contract_fingerprint,snapshot) returning * into protocol;
  end if;
  tests:=tests||jsonb_build_array(snapshot||jsonb_build_object('id',t->>'id','protocol_id',protocol.id,
    'protocol_version',protocol.version,'protocol_fingerprint',protocol.fingerprint));
 end loop;
 return jsonb_build_object('title',p_payload->'title','description',p_payload->'description','tests',tests,'scoring_available',false);
end $$;
create function trainer_private.save_trainer_assessment(p_operation_id uuid,p_payload jsonb,p_previous_id uuid default null,p_expected_revision integer default 0)
returns uuid language plpgsql security definer set search_path='' as $$
declare old trainer_private.assessments; prior trainer_private.assessment_writes; result uuid:=gen_random_uuid(); family uuid; v integer:=1; lim integer; snapshot jsonb;
begin
 perform trainer_private.require_authoring_access();
 if p_operation_id is null or p_expected_revision is null then raise invalid_parameter_value; end if;
 select * into prior from trainer_private.assessment_writes where trainer_id=auth.uid() and operation_id=p_operation_id;
 if found then
  if prior.payload is distinct from p_payload or prior.previous_id is distinct from p_previous_id or prior.expected_revision<>p_expected_revision then raise invalid_parameter_value; end if;
  return prior.assessment_id;
 end if;
 insert into trainer_private.assessment_limits(trainer_id) values(auth.uid()) on conflict do nothing;
 select version_limit into lim from trainer_private.assessment_limits where trainer_id=auth.uid();
 if (select count(*) from trainer_private.assessments where trainer_id=auth.uid())>=lim then raise exception 'Has alcanzado el límite de baterías y versiones.' using errcode='22023'; end if;
 family:=result;
 if p_previous_id is not null then
  select * into old from trainer_private.assessments where id=p_previous_id and trainer_id=auth.uid() and current for update;
  if not found or old.version<>p_expected_revision then raise serialization_failure; end if;
  family:=old.family_id;v:=old.version+1;
  update trainer_private.assessments set current=false where id=old.id;
 elsif p_expected_revision<>0 then raise invalid_parameter_value; end if;
 snapshot:=trainer_private.assessment_snapshot(p_payload);
 insert into trainer_private.assessments(id,trainer_id,family_id,version,previous_id,content) values(result,auth.uid(),family,v,p_previous_id,snapshot);
 insert into trainer_private.assessment_writes values(auth.uid(),p_operation_id,p_previous_id,p_expected_revision,p_payload,result);
 update public.trainer_access set membership_version=membership_version+1 where trainer_id=auth.uid();return result;
end $$;
create function trainer_private.get_trainer_assessment(p_id uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare result jsonb;begin
 if not trainer_private.has_trainer_mfa() then raise insufficient_privilege; end if;
 select to_jsonb(a) into result from trainer_private.assessments a where id=p_id and trainer_id=auth.uid();
 if result is null then raise insufficient_privilege;end if;return result;
end $$;
create function trainer_private.list_trainer_assessments() returns jsonb
language plpgsql stable security definer set search_path='' as $$begin
 if not trainer_private.has_trainer_mfa() then raise insufficient_privilege;end if;
 return(select coalesce(jsonb_agg(to_jsonb(a) order by created_at desc,id desc),'[]') from trainer_private.assessments a where trainer_id=auth.uid() and current);
end $$;

create function trainer_private.assign_trainer_assessment(p_operation_id uuid,p_relation_id uuid,p_assessment_id uuid,p_date date) returns uuid
language plpgsql security definer set search_path='' as $$
declare r public.trainer_client_relations;old trainer_private.assessment_deliveries;begin
 if not trainer_private.has_trainer_mfa() then raise insufficient_privilege;end if;
 select * into r from public.trainer_client_relations where id=p_relation_id and trainer_id=auth.uid();if not found then raise insufficient_privilege;end if;
 perform pg_advisory_xact_lock(hashtextextended('trainer-client:'||r.client_id::text,0));
 select * into old from trainer_private.assessment_deliveries where id=p_operation_id;
 if found then
  if old.trainer_id<>auth.uid() or old.relation_id<>p_relation_id or old.assessment_id<>p_assessment_id or old.scheduled_date is distinct from p_date then raise invalid_parameter_value;end if;return old.id;
 end if;
 perform trainer_private.require_authoring_access();
 if not exists(select 1 from public.trainer_client_relations where id=r.id and ended_at is null)
  or not exists(select 1 from trainer_private.assessments where id=p_assessment_id and trainer_id=auth.uid() and current) then raise insufficient_privilege;end if;
 if p_operation_id is null or p_date is null or p_date not between date '2000-01-01' and date '2200-12-31' then raise invalid_parameter_value;end if;
 insert into trainer_private.assessment_deliveries(id,trainer_id,client_id,relation_id,assessment_id,scheduled_date)
  values(p_operation_id,auth.uid(),r.client_id,r.id,p_assessment_id,p_date);
 update public.trainer_access set membership_version=membership_version+1 where trainer_id=auth.uid();return p_operation_id;
end $$;
create function trainer_private.validate_assessment_answers(content jsonb,answers jsonb,complete boolean) returns void
language plpgsql immutable set search_path='' as $$
declare t jsonb;a jsonb;values jsonb;seen boolean;v numeric;n integer;begin
 if answers is null or jsonb_typeof(answers)<>'object' or octet_length(answers::text)>131072
  or exists(select 1 from jsonb_object_keys(answers) k where not exists(select 1 from jsonb_array_elements(content->'tests') test where test->>'id'=k)) then raise invalid_parameter_value;end if;
 for t in select value from jsonb_array_elements(content->'tests') loop
  values:=answers->(t->>'id');
  if values is null then if complete then raise invalid_parameter_value;end if;continue;end if;
  if jsonb_typeof(values)<>'array' then raise invalid_parameter_value;end if;
  n:=jsonb_array_length(values);
  if n<1 or n>(t->>'max_attempts')::integer then raise invalid_parameter_value;end if;
  seen:=false;
  for a in select value from jsonb_array_elements(values) loop
   if jsonb_typeof(a)<>'object' or exists(select 1 from jsonb_object_keys(a) k where k not in ('valid','value'))
    or jsonb_typeof(a->'valid') is distinct from 'boolean' or (t->>'retry_policy'='invalid_only' and seen) then raise invalid_parameter_value;end if;
   if (a->>'valid')::boolean then
    if jsonb_typeof(a->'value') is distinct from 'number' then raise invalid_parameter_value;end if;
    v:=(a->>'value')::numeric;
    if v not between 0 and 1000000000 or mod(v,(t->>'resolution')::numeric)<>0 or (t->>'unit'='repetitions' and mod(v,1)<>0) then raise invalid_parameter_value;end if;
    seen:=true;
   elsif a->'value' is not null and a->'value'<>'null'::jsonb then raise invalid_parameter_value;end if;
  end loop;
 end loop;
end $$;
create function trainer_private.write_trainer_assessment(p_operation_id uuid,p_id uuid,p_expected_revision integer,p_action text,p_payload jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare d trainer_private.assessment_deliveries;prior trainer_private.assessment_result_revisions;c jsonb;result jsonb;begin
 if auth.uid() is null or coalesce((auth.jwt()->>'is_anonymous')::boolean,false) then raise insufficient_privilege;end if;
 perform pg_advisory_xact_lock(hashtextextended('trainer-client:'||auth.uid()::text,0));
 select * into d from trainer_private.assessment_deliveries where id=p_id and client_id=auth.uid();if not found then raise insufficient_privilege;end if;
 select * into prior from trainer_private.assessment_result_revisions where actor_id=auth.uid() and operation_id=p_operation_id;
 if found then
  if prior.delivery_id<>p_id or prior.action<>p_action or prior.expected_revision is distinct from p_expected_revision or prior.payload is distinct from p_payload then raise invalid_parameter_value;end if;return prior.result;
 end if;
 perform 1 from public.trainer_access where trainer_id=d.trainer_id for update;
 select * into d from trainer_private.assessment_deliveries where id=p_id for update;
 if p_operation_id is null or p_expected_revision is null or p_action is null or p_action not in ('start','save','finish') then raise invalid_parameter_value;end if;
 if d.revision<>p_expected_revision then raise serialization_failure;end if;
 if p_action='start' then
  if d.status<>'planned' or p_payload is distinct from '{"protocols_confirmed":true}'::jsonb
   or not exists(select 1 from public.trainer_client_relations where id=d.relation_id and ended_at is null)
   or not exists(select 1 from public.trainer_access where trainer_id=d.trainer_id and enabled and (valid_until is null or valid_until>statement_timestamp())) then raise insufficient_privilege;end if;
  update trainer_private.assessment_deliveries set status='in_progress',started_at=statement_timestamp(),revision=revision+1 where id=p_id returning * into d;
 else
  if d.status<>'in_progress' then raise insufficient_privilege;end if;
  select content into c from trainer_private.assessments where id=d.assessment_id;
  perform trainer_private.validate_assessment_answers(c,p_payload,p_action='finish');
  update trainer_private.assessment_deliveries set answers=p_payload,revision=revision+1,
   status=case when p_action='finish' then 'completed' else 'in_progress' end,
   completed_at=case when p_action='finish' then statement_timestamp() else null end where id=p_id returning * into d;
 end if;
 result:=jsonb_build_object('id',d.id,'revision',d.revision,'status',d.status);
 insert into trainer_private.assessment_result_revisions values(auth.uid(),p_operation_id,p_id,p_action,p_expected_revision,p_payload,result,now());
 update public.trainer_access set membership_version=membership_version+1 where trainer_id=d.trainer_id;return result;
end $$;
create function trainer_private.withdraw_assessments() returns trigger language plpgsql security definer set search_path='' as $$begin
 if old.ended_at is null and new.ended_at is not null then
  update trainer_private.assessment_deliveries set status='withdrawn',revision=revision+1 where relation_id=new.id and status='planned';
 end if;return new;
end $$;
create trigger trainer_withdraw_assessments after update of ended_at on public.trainer_client_relations for each row execute function trainer_private.withdraw_assessments();

create function trainer_private.assessment_delivery_json(p_id uuid) returns jsonb language sql stable security definer set search_path='' as $$
 select to_jsonb(d)||jsonb_build_object('kind','assessment','battery',to_jsonb(a),
  'trainer_name',coalesce(p.full_name,'Tu preparador'),'client_name',c.display_name,
  'can_start',d.client_id=auth.uid() and d.status='planned' and r.ended_at is null and access.enabled and (access.valid_until is null or access.valid_until>statement_timestamp()),
  'can_edit',d.client_id=auth.uid() and d.status='in_progress')
 from trainer_private.assessment_deliveries d join trainer_private.assessments a on a.id=d.assessment_id
 join public.trainer_client_relations r on r.id=d.relation_id join public.trainer_access access on access.trainer_id=d.trainer_id
 join public.profiles p on p.id=d.trainer_id join public.trainer_clients c on c.trainer_id=d.trainer_id and c.client_id=d.client_id where d.id=p_id;
$$;
create function trainer_private.get_trainer_assessment_delivery(p_id uuid) returns jsonb language plpgsql stable security definer set search_path='' as $$begin
 if not exists(select 1 from trainer_private.assessment_deliveries where id=p_id and
  (client_id=auth.uid() or (trainer_id=auth.uid() and trainer_private.has_trainer_mfa()))) or coalesce((auth.jwt()->>'is_anonymous')::boolean,false) then raise insufficient_privilege;end if;
 return trainer_private.assessment_delivery_json(p_id);
end $$;
create function trainer_private.list_trainer_assessment_deliveries(p_client_id uuid default null,p_before_at timestamptz default null,p_before_id uuid default null) returns jsonb
language plpgsql stable security definer set search_path='' as $$begin
 if auth.uid() is null or coalesce((auth.jwt()->>'is_anonymous')::boolean,false) then raise insufficient_privilege;end if;
 if p_client_id is not null and not trainer_private.has_trainer_mfa() then raise insufficient_privilege;end if;
 if (p_before_at is null)<>(p_before_id is null) then raise invalid_parameter_value;end if;
 return(select coalesce(jsonb_agg(trainer_private.assessment_delivery_json(x.id) order by created_at desc,id desc),'[]') from(
  select * from trainer_private.assessment_deliveries where case when p_client_id is null then client_id=auth.uid() else trainer_id=auth.uid() and client_id=p_client_id end
   and (p_before_at is null or (created_at,id)<(p_before_at,p_before_id)) order by created_at desc,id desc limit 50)x);
end $$;
create function trainer_private.list_trainer_assessment_events(p_start date,p_end_exclusive date,p_as_trainer boolean default true,p_before_date date default null,p_before_id uuid default null) returns jsonb
language plpgsql stable security definer set search_path='' as $$begin
 if auth.uid() is null or coalesce((auth.jwt()->>'is_anonymous')::boolean,false) or (p_as_trainer and not trainer_private.has_trainer_mfa()) then raise insufficient_privilege;end if;
 if p_start is null or p_end_exclusive is null or p_end_exclusive<=p_start or p_end_exclusive-p_start>366 or p_as_trainer is null or (p_before_date is null)<>(p_before_id is null) then raise invalid_parameter_value;end if;
 return(select coalesce(jsonb_agg(to_jsonb(x) order by date desc,id desc),'[]') from(
  select d.id,'assessment'::text as kind,d.scheduled_date as date,d.status,d.revision,a.content->>'title' as title,
   d.client_id,d.relation_id,case when p_as_trainer then c.display_name else coalesce(p.full_name,'Tu preparador') end as person_name
  from trainer_private.assessment_deliveries d join trainer_private.assessments a on a.id=d.assessment_id
  join public.trainer_clients c on c.trainer_id=d.trainer_id and c.client_id=d.client_id join public.profiles p on p.id=d.trainer_id
  where case when p_as_trainer then d.trainer_id=auth.uid() else d.client_id=auth.uid() end
   and d.scheduled_date>=p_start and d.scheduled_date<p_end_exclusive
   and (p_before_date is null or (d.scheduled_date,d.id)<(p_before_date,p_before_id)) order by date desc,id desc limit 200)x);
end $$;

-- Helpers no expuestos. Solo se concede EXECUTE a las fachadas con propiedad.
do $$declare r record;begin
 for r in select p.oid::regprocedure signature from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='trainer_private'
  and p.proname in ('assessment_official_eligible','list_trainer_assessment_catalog','assessment_snapshot','save_trainer_assessment',
   'get_trainer_assessment','list_trainer_assessments','assign_trainer_assessment','validate_assessment_answers','write_trainer_assessment',
   'withdraw_assessments','assessment_delivery_json','get_trainer_assessment_delivery','list_trainer_assessment_deliveries','list_trainer_assessment_events') loop
  execute format('revoke all on function %s from public,anon,authenticated',r.signature);
 end loop;
end $$;
create function public.list_trainer_assessment_catalog() returns jsonb language sql security invoker set search_path='' as $$select trainer_private.list_trainer_assessment_catalog();$$;
create function public.save_trainer_assessment(p_operation_id uuid,p_payload jsonb,p_previous_id uuid default null,p_expected_revision integer default 0) returns uuid
language sql security invoker set search_path='' as $$select trainer_private.save_trainer_assessment(p_operation_id,p_payload,p_previous_id,p_expected_revision);$$;
create function public.get_trainer_assessment(p_id uuid) returns jsonb language sql stable security invoker set search_path='' as $$select trainer_private.get_trainer_assessment(p_id);$$;
create function public.list_trainer_assessments() returns jsonb language sql stable security invoker set search_path='' as $$select trainer_private.list_trainer_assessments();$$;
create function public.assign_trainer_assessment(p_operation_id uuid,p_relation_id uuid,p_assessment_id uuid,p_date date) returns uuid language sql security invoker set search_path='' as $$select trainer_private.assign_trainer_assessment(p_operation_id,p_relation_id,p_assessment_id,p_date);$$;
create function public.write_trainer_assessment(p_operation_id uuid,p_id uuid,p_expected_revision integer,p_action text,p_payload jsonb) returns jsonb language sql security invoker set search_path='' as $$select trainer_private.write_trainer_assessment(p_operation_id,p_id,p_expected_revision,p_action,p_payload);$$;
create function public.get_trainer_assessment_delivery(p_id uuid) returns jsonb language sql stable security invoker set search_path='' as $$select trainer_private.get_trainer_assessment_delivery(p_id);$$;
create function public.list_trainer_assessment_deliveries(p_client_id uuid default null,p_before_at timestamptz default null,p_before_id uuid default null) returns jsonb language sql stable security invoker set search_path='' as $$select trainer_private.list_trainer_assessment_deliveries(p_client_id,p_before_at,p_before_id);$$;
create function public.list_trainer_assessment_events(p_start date,p_end_exclusive date,p_as_trainer boolean default true,p_before_date date default null,p_before_id uuid default null) returns jsonb language sql stable security invoker set search_path='' as $$select trainer_private.list_trainer_assessment_events(p_start,p_end_exclusive,p_as_trainer,p_before_date,p_before_id);$$;
do $$declare r record;begin
 for r in select p.proname,pg_get_function_identity_arguments(p.oid) args from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public'
  and p.proname in ('list_trainer_assessment_catalog','save_trainer_assessment','get_trainer_assessment','list_trainer_assessments','assign_trainer_assessment',
   'write_trainer_assessment','get_trainer_assessment_delivery','list_trainer_assessment_deliveries','list_trainer_assessment_events') loop
  execute format('revoke all on function public.%I(%s) from public,anon,authenticated',r.proname,r.args);
  execute format('grant execute on function public.%I(%s) to authenticated',r.proname,r.args);
  execute format('grant execute on function trainer_private.%I(%s) to authenticated',r.proname,r.args);
 end loop;
end $$;
commit;
