begin;

-- Recursos del servicio, separados de Pro personal y del catálogo oficial.
create table trainer_private.form_limits (
 trainer_id uuid primary key references public.profiles(id) on delete cascade,
 version_limit integer not null default 100 check(version_limit between 1 and 10000)
);
create table trainer_private.forms (
 id uuid primary key default gen_random_uuid(),
 trainer_id uuid not null references public.profiles(id) on delete cascade,
 family_id uuid not null,
 version integer not null check(version>0),
 previous_id uuid references trainer_private.forms(id) on delete restrict,
 current boolean not null default true,
 content jsonb not null check(jsonb_typeof(content)='object' and octet_length(content::text)<=131072),
 created_at timestamptz not null default now(),
 unique(family_id,version)
);
create index trainer_forms_owner on trainer_private.forms(trainer_id,created_at desc,id desc);
create index trainer_forms_previous on trainer_private.forms(previous_id);
create table trainer_private.form_writes (
 trainer_id uuid not null references public.profiles(id) on delete cascade,
 operation_id uuid not null,
 previous_id uuid,
 payload jsonb not null,
 form_id uuid not null references trainer_private.forms(id) on delete restrict,
 primary key(trainer_id,operation_id)
);
create index trainer_form_writes_form on trainer_private.form_writes(form_id);
create table trainer_private.form_assignments (
 id uuid primary key,
 trainer_id uuid not null references public.profiles(id) on delete cascade,
 client_id uuid not null references public.profiles(id) on delete cascade,
 relation_id uuid not null references public.trainer_client_relations(id) on delete restrict,
 form_id uuid not null references trainer_private.forms(id) on delete restrict,
 due_date date not null check(due_date between date '2000-01-01' and date '2200-12-31'),
 created_at timestamptz not null default now(),
 submitted_at timestamptz,
 submission_operation_id uuid,
 answers jsonb,
 check((submitted_at is null and submission_operation_id is null and answers is null)
   or (submitted_at is not null and submission_operation_id is not null and jsonb_typeof(answers)='object'))
);
create index trainer_form_assignments_owner on trainer_private.form_assignments(trainer_id,client_id,created_at desc,id desc);
create index trainer_form_assignments_client on trainer_private.form_assignments(client_id,created_at desc,id desc);
create index trainer_form_assignments_relation on trainer_private.form_assignments(relation_id);
create index trainer_form_assignments_form on trainer_private.form_assignments(form_id);
do $$ declare t text; begin
 foreach t in array array['form_limits','forms','form_writes','form_assignments'] loop
  execute format('alter table trainer_private.%I enable row level security',t);
  execute format('revoke all on trainer_private.%I from public,anon,authenticated',t);
 end loop;
end $$;

create function trainer_private.form_text_valid(v jsonb, maximum integer, mandatory boolean default false)
returns boolean language sql immutable set search_path='' as $$
 select case when v is null or v='null'::jsonb then not mandatory
 when jsonb_typeof(v)<>'string' then false
 else length(v#>>'{}') between (case when mandatory then 1 else 0 end) and maximum
  and (v#>>'{}')=btrim(v#>>'{}')
  and translate(v#>>'{}',E'\n\t','') !~ '[[:cntrl:]]' end;
$$;
create function trainer_private.validate_form_payload(p jsonb) returns void
language plpgsql immutable set search_path='' as $$
declare q jsonb; o jsonb; ids text[]:='{}'; positions integer[]:='{}'; opts text[];
 kind text; position integer; minimum numeric; maximum numeric; choices integer;
begin
 if p is null or jsonb_typeof(p)<>'object' or octet_length(p::text)>131072
  or exists(select 1 from jsonb_object_keys(p) k where k not in ('title','description','questions'))
  or not trainer_private.form_text_valid(p->'title',120,true)
  or not trainer_private.form_text_valid(p->'description',1000)
  or jsonb_typeof(p->'questions') is distinct from 'array' then raise invalid_parameter_value; end if;
 if jsonb_array_length(p->'questions') not between 1 and 40 then raise invalid_parameter_value; end if;
 for q in select value from jsonb_array_elements(p->'questions') loop
  if jsonb_typeof(q)<>'object' or exists(select 1 from jsonb_object_keys(q) k where k not in
   ('id','position','prompt','type','required','help','options','minimum','maximum','maximum_selections'))
   or jsonb_typeof(q->'id') is distinct from 'string' or (q->>'id') !~ '^[A-Za-z0-9][A-Za-z0-9_-]{0,63}$'
   or (q->>'id')=any(ids) or jsonb_typeof(q->'position') is distinct from 'number'
   or (q->>'position') !~ '^[0-9]{1,2}$'
   or not trainer_private.form_text_valid(q->'prompt',200,true)
   or not trainer_private.form_text_valid(q->'help',500)
   or jsonb_typeof(q->'required') is distinct from 'boolean'
   or coalesce(q->>'type','') not in ('shortText','longText','number','singleChoice','multipleChoice','scale','yesNo')
   or jsonb_typeof(q->'options') is distinct from 'array' then raise invalid_parameter_value; end if;
  ids:=array_append(ids,q->>'id'); position:=(q->>'position')::integer;
  if position>=jsonb_array_length(p->'questions') or position=any(positions) then raise invalid_parameter_value; end if;
  positions:=array_append(positions,position); kind:=q->>'type'; choices:=jsonb_array_length(q->'options');
  if (kind in ('singleChoice','multipleChoice') and choices not between 2 and 20)
   or (kind not in ('singleChoice','multipleChoice') and choices<>0) then raise invalid_parameter_value; end if;
  opts:='{}';
  for o in select value from jsonb_array_elements(q->'options') loop
   if jsonb_typeof(o)<>'object' or exists(select 1 from jsonb_object_keys(o) k where k not in ('id','label'))
    or jsonb_typeof(o->'id') is distinct from 'string' or (o->>'id') !~ '^[A-Za-z0-9][A-Za-z0-9_-]{0,63}$'
    or (o->>'id')=any(opts) or not trainer_private.form_text_valid(o->'label',100,true) then raise invalid_parameter_value; end if;
   opts:=array_append(opts,o->>'id');
  end loop;
  minimum:=null; maximum:=null;
  if q->'minimum' is not null and q->'minimum'<>'null'::jsonb then
   if kind not in ('number','scale') or jsonb_typeof(q->'minimum')<>'number' then raise invalid_parameter_value; end if;
   minimum:=(q->>'minimum')::numeric;
   if abs(minimum)>1000000000 then raise invalid_parameter_value; end if;
  end if;
  if q->'maximum' is not null and q->'maximum'<>'null'::jsonb then
   if kind not in ('number','scale') or jsonb_typeof(q->'maximum')<>'number' then raise invalid_parameter_value; end if;
   maximum:=(q->>'maximum')::numeric;
   if abs(maximum)>1000000000 then raise invalid_parameter_value; end if;
  end if;
  if minimum>maximum then raise invalid_parameter_value; end if;
  if kind='scale' and (minimum is null or maximum is null or trunc(minimum)<>minimum
   or trunc(maximum)<>maximum or maximum<=minimum or maximum-minimum>20) then raise invalid_parameter_value; end if;
  if q->'maximum_selections' is not null and q->'maximum_selections'<>'null'::jsonb then
   if kind<>'multipleChoice' or jsonb_typeof(q->'maximum_selections')<>'number'
    or (q->>'maximum_selections') !~ '^[0-9]{1,2}$'
    or (q->>'maximum_selections')::integer not between 1 and choices then raise invalid_parameter_value; end if;
  end if;
 end loop;
end $$;

create function trainer_private.validate_form_answers(p jsonb,a jsonb) returns void
language plpgsql immutable set search_path='' as $$
declare q jsonb; v jsonb; kind text; n numeric; choices integer;
begin
 if a is null or jsonb_typeof(a)<>'object' or octet_length(a::text)>131072
  or exists(select 1 from jsonb_object_keys(a) k where not exists
   (select 1 from jsonb_array_elements(p->'questions') candidate where candidate->>'id'=k)) then raise invalid_parameter_value; end if;
 for q in select value from jsonb_array_elements(p->'questions') loop
  v:=a->(q->>'id'); kind:=q->>'type';
  if v is null or v='null'::jsonb then
   if (q->>'required')::boolean then raise invalid_parameter_value; end if;
   continue;
  end if;
  case kind
  when 'shortText','longText' then
   if not trainer_private.form_text_valid(v,case when kind='shortText' then 240 else 2000 end,true) then raise invalid_parameter_value; end if;
  when 'number','scale' then
   if jsonb_typeof(v)<>'number' then raise invalid_parameter_value; end if;
   n:=(v#>>'{}')::numeric;
   if abs(n)>1000000000 or n<(q->>'minimum')::numeric or n>(q->>'maximum')::numeric
    or (kind='scale' and trunc(n)<>n) then raise invalid_parameter_value; end if;
  when 'yesNo' then
   if jsonb_typeof(v)<>'boolean' then raise invalid_parameter_value; end if;
  when 'singleChoice' then
   if jsonb_typeof(v)<>'string' or not exists(select 1 from jsonb_array_elements(q->'options') o where o->>'id'=v#>>'{}') then raise invalid_parameter_value; end if;
  when 'multipleChoice' then
   if jsonb_typeof(v)<>'array' then raise invalid_parameter_value; end if;
   choices:=jsonb_array_length(v);
   if choices<1 or choices>coalesce((q->>'maximum_selections')::integer,jsonb_array_length(q->'options'))
    or (select count(distinct value) from jsonb_array_elements(v))<>choices
    or exists(select 1 from jsonb_array_elements(v) x where jsonb_typeof(x)<>'string' or not exists
     (select 1 from jsonb_array_elements(q->'options') o where o->>'id'=x#>>'{}')) then raise invalid_parameter_value; end if;
  else raise invalid_parameter_value;
  end case;
 end loop;
end $$;

create function trainer_private.save_trainer_form(p_operation_id uuid,p_payload jsonb,p_previous_id uuid default null)
returns uuid language plpgsql security definer set search_path='' as $$
declare prior trainer_private.form_writes; old trainer_private.forms; result uuid:=gen_random_uuid(); family uuid; revision integer:=1; lim integer;
begin
 perform trainer_private.require_authoring_access();
 if p_operation_id is null then raise invalid_parameter_value; end if;
 select * into prior from trainer_private.form_writes where trainer_id=auth.uid() and operation_id=p_operation_id;
 if found then
  if prior.payload is distinct from p_payload or prior.previous_id is distinct from p_previous_id then raise invalid_parameter_value; end if;
  return prior.form_id;
 end if;
 perform trainer_private.validate_form_payload(p_payload);
 insert into trainer_private.form_limits(trainer_id) values(auth.uid()) on conflict do nothing;
 select version_limit into lim from trainer_private.form_limits where trainer_id=auth.uid();
 if (select count(*) from trainer_private.forms where trainer_id=auth.uid())>=lim then
  raise exception 'Has alcanzado el límite de formularios y versiones profesionales.' using errcode='22023'; end if;
 family:=result;
 if p_previous_id is not null then
  select * into old from trainer_private.forms where id=p_previous_id and trainer_id=auth.uid() and current for update;
  if not found then raise exception 'El formulario cambió. Actualiza antes de revisarlo.' using errcode='40001'; end if;
  family:=old.family_id; revision:=old.version+1;
  update trainer_private.forms set current=false where id=old.id;
 end if;
 insert into trainer_private.forms(id,trainer_id,family_id,version,previous_id,content)
  values(result,auth.uid(),family,revision,p_previous_id,p_payload);
 insert into trainer_private.form_writes values(auth.uid(),p_operation_id,p_previous_id,p_payload,result);
 -- El contador también fuerza reintento de un REPEATABLE READ que esperaba
 -- con un recuento de cuota anterior a otra creación confirmada.
 update public.trainer_access set membership_version=membership_version+1 where trainer_id=auth.uid();
 return result;
end $$;

create function trainer_private.get_trainer_form(p_id uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare result jsonb;
begin
 if not trainer_private.has_trainer_mfa() then raise insufficient_privilege; end if;
 select to_jsonb(f) into result from trainer_private.forms f where id=p_id and trainer_id=auth.uid();
 if result is null then raise insufficient_privilege; end if;
 return result;
end $$;
create function trainer_private.list_trainer_forms() returns jsonb
language plpgsql stable security definer set search_path='' as $$
begin
 if not trainer_private.has_trainer_mfa() then raise insufficient_privilege; end if;
 return (select coalesce(jsonb_agg(to_jsonb(f) order by created_at desc,id desc),'[]') from trainer_private.forms f where trainer_id=auth.uid() and current);
end $$;

create function trainer_private.assign_trainer_form(p_operation_id uuid,p_relation_id uuid,p_form_id uuid,p_due_date date)
returns uuid language plpgsql security definer set search_path='' as $$
declare r public.trainer_client_relations; old trainer_private.form_assignments;
begin
 if not trainer_private.has_trainer_mfa() then raise insufficient_privilege; end if;
 select * into r from public.trainer_client_relations where id=p_relation_id and trainer_id=auth.uid();
 if not found then raise insufficient_privilege; end if;
 perform pg_advisory_xact_lock(hashtextextended('trainer-client:'||r.client_id::text,0));
 select * into old from trainer_private.form_assignments where id=p_operation_id;
 if found then
  if old.trainer_id<>auth.uid() or old.relation_id<>p_relation_id or old.form_id<>p_form_id or old.due_date is distinct from p_due_date then raise invalid_parameter_value; end if;
  return old.id;
 end if;
 perform trainer_private.require_authoring_access();
 perform 1 from public.trainer_client_relations where id=r.id and ended_at is null;
 if not found then raise insufficient_privilege; end if;
 perform 1 from trainer_private.forms where id=p_form_id and trainer_id=auth.uid() and current;
 if not found then raise insufficient_privilege; end if;
 if p_operation_id is null or p_due_date is null or p_due_date not between date '2000-01-01' and date '2200-12-31' then raise invalid_parameter_value; end if;
 insert into trainer_private.form_assignments(id,trainer_id,client_id,relation_id,form_id,due_date)
  values(p_operation_id,auth.uid(),r.client_id,r.id,p_form_id,p_due_date);
 update public.trainer_access set membership_version=membership_version+1 where trainer_id=auth.uid();
 return p_operation_id;
end $$;

create function trainer_private.form_assignment_json(p_id uuid) returns jsonb
language sql stable security definer set search_path='' as $$
 select to_jsonb(a)-'submission_operation_id' || jsonb_build_object('content',f.content,'version',f.version,'family_id',f.family_id,
  'trainer_name',coalesce(p.full_name,'Tu preparador'),
  'can_respond',a.submitted_at is null and r.ended_at is null and t.enabled and (t.valid_until is null or t.valid_until>statement_timestamp()))
 from trainer_private.form_assignments a join trainer_private.forms f on f.id=a.form_id
 join public.trainer_client_relations r on r.id=a.relation_id
 join public.trainer_access t on t.trainer_id=a.trainer_id
 join public.profiles p on p.id=a.trainer_id where a.id=p_id;
$$;
create function trainer_private.list_my_trainer_forms(p_before_at timestamptz default null,p_before_id uuid default null) returns jsonb
language plpgsql stable security definer set search_path='' as $$
begin
 if auth.uid() is null or coalesce((auth.jwt()->>'is_anonymous')::boolean,false) then raise insufficient_privilege; end if;
 if (p_before_at is null)<>(p_before_id is null) then raise invalid_parameter_value; end if;
 return (select coalesce(jsonb_agg(trainer_private.form_assignment_json(x.id) order by created_at desc,id desc),'[]') from (
  select * from trainer_private.form_assignments where client_id=auth.uid()
   and (p_before_at is null or (created_at,id)<(p_before_at,p_before_id)) order by created_at desc,id desc limit 50) x);
end $$;
create function trainer_private.list_trainer_form_assignments(p_client_id uuid,p_before_at timestamptz default null,p_before_id uuid default null) returns jsonb
language plpgsql stable security definer set search_path='' as $$
begin
 if not trainer_private.has_trainer_mfa() then raise insufficient_privilege; end if;
 if (p_before_at is null)<>(p_before_id is null) then raise invalid_parameter_value; end if;
 return (select coalesce(jsonb_agg(trainer_private.form_assignment_json(x.id) order by created_at desc,id desc),'[]') from (
  select * from trainer_private.form_assignments where trainer_id=auth.uid() and client_id=p_client_id
   and (p_before_at is null or (created_at,id)<(p_before_at,p_before_id)) order by created_at desc,id desc limit 50) x);
end $$;
create function trainer_private.get_trainer_form_submission(p_assignment_id uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare a trainer_private.form_assignments;
begin
 select * into a from trainer_private.form_assignments where id=p_assignment_id and
  (client_id=auth.uid() or (trainer_id=auth.uid() and trainer_private.has_trainer_mfa()));
 if not found or coalesce((auth.jwt()->>'is_anonymous')::boolean,false) then raise insufficient_privilege; end if;
 return trainer_private.form_assignment_json(a.id);
end $$;
create function trainer_private.submit_trainer_form(p_operation_id uuid,p_assignment_id uuid,p_answers jsonb) returns uuid
language plpgsql security definer set search_path='' as $$
declare a trainer_private.form_assignments; content jsonb;
begin
 if auth.uid() is null or coalesce((auth.jwt()->>'is_anonymous')::boolean,false) then raise insufficient_privilege; end if;
 perform pg_advisory_xact_lock(hashtextextended('trainer-client:'||auth.uid()::text,0));
 select * into a from trainer_private.form_assignments where id=p_assignment_id and client_id=auth.uid();
 if not found then raise insufficient_privilege; end if;
 if a.submitted_at is not null then
  if a.submission_operation_id is distinct from p_operation_id or a.answers is distinct from p_answers then raise invalid_parameter_value; end if;
  return a.id;
 end if;
 -- Misma jerarquía de bloqueos que la baja: alumno -> acceso -> recurso.
 perform 1 from public.trainer_access where trainer_id=a.trainer_id and enabled
  and (valid_until is null or valid_until>statement_timestamp()) for update;
 if not found or not exists(select 1 from public.trainer_client_relations where id=a.relation_id and ended_at is null) then raise insufficient_privilege; end if;
 select * into a from trainer_private.form_assignments where id=p_assignment_id for update;
 if p_operation_id is null then raise invalid_parameter_value; end if;
 select f.content into content from trainer_private.forms f where f.id=a.form_id;
 perform trainer_private.validate_form_answers(content,p_answers);
 update trainer_private.form_assignments set answers=p_answers,submission_operation_id=p_operation_id,submitted_at=statement_timestamp() where id=a.id;
 update public.trainer_access set membership_version=membership_version+1 where trainer_id=a.trainer_id;
 return a.id;
end $$;

-- Solo las fachadas comprobadas son accesibles. Ninguna tabla ni helper abre
-- lectura general por ser ADMIN o por compartir una identidad profesional.
do $$ declare r record; begin
 for r in select p.oid::regprocedure as signature from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='trainer_private' and p.proname in ('form_text_valid','validate_form_payload','validate_form_answers',
   'save_trainer_form','get_trainer_form','list_trainer_forms','assign_trainer_form','form_assignment_json',
   'list_my_trainer_forms','list_trainer_form_assignments','get_trainer_form_submission','submit_trainer_form') loop
  execute format('revoke all on function %s from public,anon,authenticated',r.signature);
 end loop;
end $$;
create function public.save_trainer_form(p_operation_id uuid,p_payload jsonb,p_previous_id uuid default null) returns uuid
language sql security invoker set search_path='' as $$ select trainer_private.save_trainer_form(p_operation_id,p_payload,p_previous_id); $$;
create function public.get_trainer_form(p_id uuid) returns jsonb language sql stable security invoker set search_path='' as $$ select trainer_private.get_trainer_form(p_id); $$;
create function public.list_trainer_forms() returns jsonb language sql stable security invoker set search_path='' as $$ select trainer_private.list_trainer_forms(); $$;
create function public.assign_trainer_form(p_operation_id uuid,p_relation_id uuid,p_form_id uuid,p_due_date date) returns uuid
language sql security invoker set search_path='' as $$ select trainer_private.assign_trainer_form(p_operation_id,p_relation_id,p_form_id,p_due_date); $$;
create function public.list_my_trainer_forms(p_before_at timestamptz default null,p_before_id uuid default null) returns jsonb
language sql stable security invoker set search_path='' as $$ select trainer_private.list_my_trainer_forms(p_before_at,p_before_id); $$;
create function public.list_trainer_form_assignments(p_client_id uuid,p_before_at timestamptz default null,p_before_id uuid default null) returns jsonb
language sql stable security invoker set search_path='' as $$ select trainer_private.list_trainer_form_assignments(p_client_id,p_before_at,p_before_id); $$;
create function public.get_trainer_form_submission(p_assignment_id uuid) returns jsonb language sql stable security invoker set search_path='' as $$ select trainer_private.get_trainer_form_submission(p_assignment_id); $$;
create function public.submit_trainer_form(p_operation_id uuid,p_assignment_id uuid,p_answers jsonb) returns uuid
language sql security invoker set search_path='' as $$ select trainer_private.submit_trainer_form(p_operation_id,p_assignment_id,p_answers); $$;
do $$ declare r record; begin
 for r in select p.oid::regprocedure as signature,n.nspname,p.proname,pg_get_function_identity_arguments(p.oid) args
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname in ('public','trainer_private') and p.proname in ('save_trainer_form','get_trainer_form','list_trainer_forms',
   'assign_trainer_form','list_my_trainer_forms','list_trainer_form_assignments','get_trainer_form_submission','submit_trainer_form') loop
  execute format('revoke all on function %s from public,anon,authenticated',r.signature);
  execute format('grant execute on function %s to authenticated',r.signature);
 end loop;
end $$;
commit;
