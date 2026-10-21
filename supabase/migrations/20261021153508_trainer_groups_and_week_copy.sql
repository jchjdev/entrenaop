begin;

create table trainer_private.client_groups (
 id uuid primary key,
 trainer_id uuid not null references public.profiles(id) on delete cascade,
 name text not null check(char_length(btrim(name)) between 1 and 100),
 revision bigint not null check(revision>0),
 updated_at timestamptz not null default now(),
 unique(id,trainer_id)
);
create index trainer_groups_owner_page on trainer_private.client_groups(trainer_id,updated_at desc,id desc);
create table trainer_private.group_members (
 group_id uuid not null,
 trainer_id uuid not null,
 client_id uuid not null,
 primary key(group_id,client_id),
 foreign key(group_id,trainer_id) references trainer_private.client_groups(id,trainer_id) on delete cascade,
 foreign key(trainer_id,client_id) references public.trainer_clients(trainer_id,client_id) on delete cascade
);
create index trainer_group_members_owner on trainer_private.group_members(trainer_id,client_id);
create index trainer_group_members_group_owner on trainer_private.group_members(group_id,trainer_id);
create table trainer_private.bulk_writes (
 trainer_id uuid not null references public.profiles(id) on delete cascade,
 operation_id uuid not null,
 payload jsonb not null check(octet_length(payload::text)<=262144),
 result jsonb not null,
 created_at timestamptz not null default now(),
 primary key(trainer_id,operation_id)
);
do $$ declare tab text; begin
 foreach tab in array array['client_groups','group_members','bulk_writes'] loop
  execute format('alter table trainer_private.%I enable row level security',tab);
  execute format('revoke all on trainer_private.%I from public,anon,authenticated',tab);
 end loop;
end $$;

create function trainer_private.save_group(p_operation_id uuid,p_id uuid,p_expected_revision bigint,p_name text,p_client_ids uuid[]) returns jsonb
language plpgsql security definer set search_path='' as $$
declare owner uuid:=auth.uid(); member uuid; prior trainer_private.bulk_writes; existing trainer_private.client_groups;
 members uuid[]; payload jsonb; result jsonb;
begin
 if not trainer_private.has_trainer_mfa() then raise insufficient_privilege; end if;
 if p_operation_id is null or p_id is null or p_expected_revision is null or p_expected_revision<0
  or p_name is null or char_length(btrim(p_name)) not between 1 and 100 or p_client_ids is null
  or cardinality(p_client_ids)>100 or array_position(p_client_ids,null) is not null then raise invalid_parameter_value; end if;
 select coalesce(array_agg(x order by x),'{}'::uuid[]) into members from (select distinct unnest(p_client_ids) x) q;
 if cardinality(members)<>cardinality(p_client_ids) then raise invalid_parameter_value; end if;
 -- Todas las operaciones de alumnos toman los advisory en el mismo orden UUID.
 foreach member in array members loop
  perform pg_advisory_xact_lock(hashtextextended('trainer-client:'||member::text,0));
 end loop;
 perform trainer_private.require_authoring_access();
 payload:=jsonb_build_object('kind','group','id',p_id,'expected_revision',p_expected_revision,'name',btrim(p_name),'client_ids',members);
 select * into prior from trainer_private.bulk_writes where trainer_id=owner and operation_id=p_operation_id;
 if found then
  if prior.payload is distinct from payload then raise invalid_parameter_value; end if;
  return prior.result;
 end if;
 if exists(select 1 from unnest(members) m where not exists(select 1 from public.trainer_clients c where c.trainer_id=owner and c.client_id=m)) then raise insufficient_privilege; end if;
 select * into existing from trainer_private.client_groups where id=p_id for update;
 if found then
  if existing.trainer_id<>owner then raise insufficient_privilege; end if;
  if existing.revision<>p_expected_revision then raise serialization_failure; end if;
  update trainer_private.client_groups set name=btrim(p_name),revision=revision+1,updated_at=clock_timestamp() where id=p_id;
 else
  if p_expected_revision<>0 then raise serialization_failure; end if;
  insert into trainer_private.client_groups(id,trainer_id,name,revision) values(p_id,owner,btrim(p_name),1);
 end if;
 delete from trainer_private.group_members where group_id=p_id;
 insert into trainer_private.group_members select p_id,owner,m from unnest(members) m;
 select jsonb_build_object('id',id,'revision',revision) into result from trainer_private.client_groups where id=p_id;
 insert into trainer_private.bulk_writes(trainer_id,operation_id,payload,result) values(owner,p_operation_id,payload,result);
 -- Invalida también el snapshot de un envío REPEATABLE READ que preparó el
 -- grupo antes de esperar el acceso compartido del preparador.
 update public.trainer_access set membership_version=membership_version+1 where trainer_id=owner;
 return result;
end $$;

create function trainer_private.list_groups(p_before_at timestamptz default null,p_before_id uuid default null) returns jsonb
language plpgsql stable security definer set search_path='' as $$
begin
 if not trainer_private.has_trainer_mfa() then raise insufficient_privilege; end if;
 if (p_before_at is null)<>(p_before_id is null) then raise invalid_parameter_value; end if;
 return (select coalesce(jsonb_agg(to_jsonb(x) order by updated_at desc,id desc),'[]') from (
  select g.id,g.name,g.revision,g.updated_at,
   (select coalesce(jsonb_agg(jsonb_build_object('client_id',m.client_id,'client_name',c.display_name,'relation_id',r.id) order by m.client_id),'[]')
    from trainer_private.group_members m join public.trainer_clients c on c.trainer_id=m.trainer_id and c.client_id=m.client_id
     left join public.trainer_client_relations r on r.trainer_id=m.trainer_id and r.client_id=m.client_id and r.ended_at is null
    where m.group_id=g.id) as members
  from trainer_private.client_groups g where g.trainer_id=auth.uid()
   and (p_before_at is null or (g.updated_at,g.id)<(p_before_at,p_before_id))
  order by g.updated_at desc,g.id desc limit 50
 ) x);
end $$;

-- Composición explícita del envío. Nunca expande un grupo después de que el
-- preparador haya revisado sus destinatarios; una revisión de grupo obsoleta falla.
create function trainer_private.prepare_batch(p_recipients jsonb,p_template_id uuid,p_date date,p_program_id uuid,p_entries jsonb,p_note text,p_group_id uuid,p_group_revision bigint) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare recipients jsonb; total integer; entry jsonb; recipient jsonb; member_ids uuid[]; actual_ids uuid[];
 g trainer_private.client_groups; tid uuid; d date;
begin
 if not trainer_private.has_professional_read_access() then raise insufficient_privilege; end if;
 if jsonb_typeof(p_recipients) is distinct from 'array' or jsonb_array_length(p_recipients) not between 1 and 100
  or (p_template_id is null)=(p_program_id is null)
  or (p_group_id is null)<>(p_group_revision is null) then raise invalid_parameter_value; end if;
 if exists(select 1 from jsonb_array_elements(p_recipients) r where jsonb_typeof(r)<>'object' or nullif(r->>'client_id','') is null or nullif(r->>'relation_id','') is null) then raise invalid_parameter_value; end if;
 select jsonb_agg(jsonb_build_object('client_id',(r->>'client_id')::uuid,'relation_id',(r->>'relation_id')::uuid) order by (r->>'client_id')::uuid)
  into recipients from jsonb_array_elements(p_recipients) r;
 if exists(select 1 from jsonb_array_elements(recipients) r group by r->>'client_id' having count(*)>1) then raise invalid_parameter_value; end if;
 for recipient in select value from jsonb_array_elements(recipients) loop
  if not exists(select 1 from public.trainer_client_relations where id=(recipient->>'relation_id')::uuid
   and client_id=(recipient->>'client_id')::uuid and trainer_id=auth.uid() and ended_at is null) then raise insufficient_privilege; end if;
 end loop;
 if p_group_id is not null then
  select * into g from trainer_private.client_groups where id=p_group_id and trainer_id=auth.uid();
  if not found then raise insufficient_privilege; end if;
  if g.revision<>p_group_revision then raise serialization_failure; end if;
  select coalesce(array_agg(client_id order by client_id),'{}'::uuid[]) into member_ids from trainer_private.group_members where group_id=g.id;
  select array_agg((r->>'client_id')::uuid order by (r->>'client_id')::uuid) into actual_ids from jsonb_array_elements(recipients) r;
  if member_ids is distinct from actual_ids then raise exception 'Revisa los destinatarios del grupo antes de enviar.' using errcode='40001'; end if;
 end if;
 if p_template_id is not null then
  if p_date is null or p_entries is not null or char_length(p_note)>500 then raise invalid_parameter_value; end if;
  if not exists(select 1 from public.workout_templates where id=p_template_id and owner_user_id=auth.uid() and origin='coach' and status='published') then raise insufficient_privilege; end if;
  total:=jsonb_array_length(recipients);
 else
  if p_date is not null or jsonb_typeof(p_entries) is distinct from 'array' or jsonb_array_length(p_entries) not between 1 and 256 or char_length(p_note)>320 then raise invalid_parameter_value; end if;
  if not exists(select 1 from trainer_private.programs where id=p_program_id and trainer_id=auth.uid()) then raise insufficient_privilege; end if;
  if exists(select 1 from jsonb_array_elements(p_entries) e group by e->>'phase',e->>'session',e->>'date' having count(*)>1) then raise invalid_parameter_value; end if;
  for entry in select value from jsonb_array_elements(p_entries) loop
   if jsonb_typeof(entry)<>'object' or nullif(entry->>'date','') is null then raise invalid_parameter_value; end if;
   d:=(entry->>'date')::date;
   select template_id into tid from trainer_private.program_sessions where program_id=p_program_id
    and phase_index=(entry->>'phase')::integer and session_index=(entry->>'session')::integer;
   if not found or d is null then raise invalid_parameter_value; end if;
  end loop;
  total:=jsonb_array_length(recipients)*jsonb_array_length(p_entries);
 end if;
 if total>256 then raise exception 'Una orden admite como máximo 256 citas en total.' using errcode='22023'; end if;
 return jsonb_build_object('recipients',recipients,'assignment_count',total);
end $$;

create function trainer_private.preview_batch(p_recipients jsonb,p_template_id uuid,p_date date,p_program_id uuid,p_entries jsonb,p_note text,p_group_id uuid,p_group_revision bigint) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare result jsonb; previews jsonb:='[]'; recipient jsonb; dates date[]; item jsonb; collisions jsonb;
begin
 result:=trainer_private.prepare_batch(p_recipients,p_template_id,p_date,p_program_id,p_entries,p_note,p_group_id,p_group_revision);
 if p_template_id is not null then dates:=array[p_date];
 else select array_agg(distinct (e->>'date')::date order by (e->>'date')::date) into dates from jsonb_array_elements(p_entries) e; end if;
 for recipient in select value from jsonb_array_elements(result->'recipients') loop
  select coalesce(jsonb_agg(jsonb_build_object('date',d,'has_other_workout',true) order by d),'[]') into collisions from unnest(dates) d
   where exists(select 1 from public.scheduled_workouts s where s.user_id=(recipient->>'client_id')::uuid and s.scheduled_date=d and s.status in ('planned','in_progress'));
  select recipient||jsonb_build_object('client_name',c.display_name,'dates',dates,'coincidences',collisions) into item
   from public.trainer_clients c where c.trainer_id=auth.uid() and c.client_id=(recipient->>'client_id')::uuid;
  previews:=previews||jsonb_build_array(item);
 end loop;
 return result||jsonb_build_object('preview',previews);
end $$;

create function trainer_private.deliver_batch(p_operation_id uuid,p_recipients jsonb,p_template_id uuid,p_date date,p_program_id uuid,p_entries jsonb,p_note text,p_group_id uuid,p_group_revision bigint) returns jsonb
language plpgsql security definer set search_path='' as $$
declare member uuid; payload jsonb; prior trainer_private.bulk_writes; plan jsonb; recipient jsonb;
 receipts jsonb:='[]'; ids jsonb; delivery uuid; assignment uuid; result jsonb;
begin
 if not trainer_private.has_trainer_mfa() then raise insufficient_privilege; end if;
 if p_operation_id is null or jsonb_typeof(p_recipients) is distinct from 'array' or jsonb_array_length(p_recipients) not between 1 and 100 then raise invalid_parameter_value; end if;
 for member in select distinct (r->>'client_id')::uuid from jsonb_array_elements(p_recipients) r order by 1 loop
  if member is null then raise invalid_parameter_value; end if;
  perform pg_advisory_xact_lock(hashtextextended('trainer-client:'||member::text,0));
 end loop;
 perform trainer_private.require_authoring_access();
 payload:=jsonb_build_object('kind','batch','recipients',p_recipients,'template_id',p_template_id,'date',p_date,'program_id',p_program_id,'entries',p_entries,'note',nullif(btrim(p_note),''),'group_id',p_group_id,'group_revision',p_group_revision);
 select * into prior from trainer_private.bulk_writes where trainer_id=auth.uid() and operation_id=p_operation_id;
 if found then
  if prior.payload is distinct from payload then raise invalid_parameter_value; end if;
  return prior.result;
 end if;
 plan:=trainer_private.prepare_batch(p_recipients,p_template_id,p_date,p_program_id,p_entries,p_note,p_group_id,p_group_revision);
 for recipient in select value from jsonb_array_elements(plan->'recipients') loop
  delivery:=null;
  if p_template_id is not null then
   assignment:=trainer_private.assign_trainer_workout_version(gen_random_uuid(),(recipient->>'relation_id')::uuid,p_template_id,p_date,p_note,false);
   ids:=jsonb_build_array(assignment);
  else
   delivery:=trainer_private.assign_trainer_program(gen_random_uuid(),(recipient->>'relation_id')::uuid,p_program_id,p_entries,p_note);
   select jsonb_agg(scheduled_id order by scheduled_id) into ids from public.trainer_assignments where program_delivery_id=delivery;
  end if;
  receipts:=receipts||jsonb_build_array(recipient||jsonb_build_object('assignment_ids',ids,'program_delivery_id',delivery));
 end loop;
 result:=jsonb_build_object('recipients',receipts,'assignment_count',plan->'assignment_count');
 insert into trainer_private.bulk_writes(trainer_id,operation_id,payload,result) values(auth.uid(),p_operation_id,payload,result);
 return result;
end $$;

-- La huella incluye también las pautas excluidas y el estado del vínculo: un
-- inicio, baja, nueva pauta o edición entre revisión y copia exige revisar otra vez.
create function trainer_private.week_snapshot(p_week_start date,p_offset_days integer) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare source jsonb; eligible jsonb; clients integer; fingerprint text;
begin
 if not trainer_private.has_professional_read_access() then raise insufficient_privilege; end if;
 if p_week_start is null or extract(isodow from p_week_start)<>1 or p_offset_days is null or p_offset_days=0 or p_offset_days%7<>0 then raise invalid_parameter_value; end if;
 select coalesce(jsonb_agg(jsonb_build_object('id',s.id,'client_id',a.client_id,'client_name',c.display_name,'relation_id',a.relation_id,
  'template_id',s.template_id,'template_name',s.template_name,'date',s.scheduled_date,'target_date',s.scheduled_date+p_offset_days,
  'planning_revision',a.planning_revision,'note',a.note,'status',s.status,'execution_id',s.execution_id,'relation_ended_at',r.ended_at,
  'has_date_coincidence',exists(select 1 from public.scheduled_workouts destination
   where destination.user_id=a.client_id and destination.scheduled_date=s.scheduled_date+p_offset_days
    and destination.status in ('planned','in_progress'))) order by s.id),'[]')
  into source from public.trainer_assignments a join public.scheduled_workouts s on s.id=a.scheduled_id
   join public.trainer_client_relations r on r.id=a.relation_id
   join public.trainer_clients c on c.trainer_id=a.trainer_id and c.client_id=a.client_id
  where a.trainer_id=auth.uid() and s.scheduled_date between p_week_start and p_week_start+6;
 select coalesce(jsonb_agg(e order by e->>'id'),'[]'),count(distinct e->>'client_id') into eligible,clients
  from jsonb_array_elements(source) e where e->>'status'='planned' and e->>'execution_id' is null and e->>'relation_ended_at' is null;
 if clients>100 or jsonb_array_length(eligible)>256 then raise exception 'Una copia admite como máximo 100 alumnos y 256 citas. Divide la planificación.' using errcode='22023'; end if;
 fingerprint:=encode(extensions.digest(jsonb_build_object('week_start',p_week_start,'offset_days',p_offset_days,'source',source)::text,'sha256'),'hex');
 return jsonb_build_object('fingerprint',fingerprint,'week_start',p_week_start,'offset_days',p_offset_days,'items',eligible,'excluded_count',jsonb_array_length(source)-jsonb_array_length(eligible));
end $$;

create function trainer_private.copy_week(p_operation_id uuid,p_week_start date,p_offset_days integer,p_fingerprint text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare member uuid; locked_clients uuid[]; current_clients uuid[]; payload jsonb; prior trainer_private.bulk_writes;
 snapshot jsonb; entry jsonb; created uuid; receipts jsonb:='[]'; result jsonb;
begin
 if not trainer_private.has_trainer_mfa() then raise insufficient_privilege; end if;
 if p_operation_id is null or p_fingerprint is null or p_fingerprint !~ '^[0-9a-f]{64}$' then raise invalid_parameter_value; end if;
 -- Se recogen todos los clientes antes del primer lock. Tras bloquear access se
 -- rechaza cualquier nuevo cliente para no adquirir advisory fuera de orden.
 select coalesce(array_agg(distinct a.client_id order by a.client_id),'{}'::uuid[]) into locked_clients
  from public.trainer_assignments a join public.scheduled_workouts s on s.id=a.scheduled_id
  where a.trainer_id=auth.uid() and s.scheduled_date between p_week_start and p_week_start+6;
 foreach member in array locked_clients loop
  perform pg_advisory_xact_lock(hashtextextended('trainer-client:'||member::text,0));
 end loop;
 perform trainer_private.require_authoring_access();
 payload:=jsonb_build_object('kind','copy_week','week_start',p_week_start,'offset_days',p_offset_days,'fingerprint',p_fingerprint);
 select * into prior from trainer_private.bulk_writes where trainer_id=auth.uid() and operation_id=p_operation_id;
 if found then
  if prior.payload is distinct from payload then raise invalid_parameter_value; end if;
  return prior.result;
 end if;
 select coalesce(array_agg(distinct a.client_id order by a.client_id),'{}'::uuid[]) into current_clients
  from public.trainer_assignments a join public.scheduled_workouts s on s.id=a.scheduled_id
  where a.trainer_id=auth.uid() and s.scheduled_date between p_week_start and p_week_start+6;
 if current_clients is distinct from locked_clients then raise serialization_failure; end if;
 snapshot:=trainer_private.week_snapshot(p_week_start,p_offset_days);
 if snapshot->>'fingerprint'<>p_fingerprint then raise exception 'La semana ha cambiado. Revisa de nuevo antes de copiar.' using errcode='40001'; end if;
 if jsonb_array_length(snapshot->'items')=0 then raise exception 'No hay pautas pendientes de vínculos activos para copiar.' using errcode='22023'; end if;
 for entry in select value from jsonb_array_elements(snapshot->'items') order by (value->>'client_id')::uuid,(value->>'id')::uuid loop
  created:=trainer_private.assign_trainer_workout_version(gen_random_uuid(),(entry->>'relation_id')::uuid,(entry->>'template_id')::uuid,(entry->>'target_date')::date,entry->>'note',true);
  receipts:=receipts||jsonb_build_array(jsonb_build_object('source_assignment_id',entry->>'id','assignment_id',created,'client_id',entry->>'client_id','relation_id',entry->>'relation_id','date',entry->>'target_date'));
 end loop;
 result:=jsonb_build_object('assignments',receipts,'assignment_count',jsonb_array_length(receipts));
 insert into trainer_private.bulk_writes(trainer_id,operation_id,payload,result) values(auth.uid(),p_operation_id,payload,result);
 return result;
end $$;

create function public.save_trainer_group(p_operation_id uuid,p_id uuid,p_expected_revision bigint,p_name text,p_client_ids uuid[]) returns jsonb
language sql security invoker set search_path='' as $$select trainer_private.save_group(p_operation_id,p_id,p_expected_revision,p_name,p_client_ids)$$;
create function public.list_trainer_groups(p_before_at timestamptz default null,p_before_id uuid default null) returns jsonb
language sql stable security invoker set search_path='' as $$select trainer_private.list_groups(p_before_at,p_before_id)$$;
create function public.preview_trainer_batch(p_recipients jsonb,p_template_id uuid default null,p_date date default null,p_program_id uuid default null,p_entries jsonb default null,p_note text default null,p_group_id uuid default null,p_group_revision bigint default null) returns jsonb
language sql stable security invoker set search_path='' as $$select trainer_private.preview_batch(p_recipients,p_template_id,p_date,p_program_id,p_entries,p_note,p_group_id,p_group_revision)$$;
create function public.deliver_trainer_batch(p_operation_id uuid,p_recipients jsonb,p_template_id uuid default null,p_date date default null,p_program_id uuid default null,p_entries jsonb default null,p_note text default null,p_group_id uuid default null,p_group_revision bigint default null) returns jsonb
language sql security invoker set search_path='' as $$select trainer_private.deliver_batch(p_operation_id,p_recipients,p_template_id,p_date,p_program_id,p_entries,p_note,p_group_id,p_group_revision)$$;
create function public.preview_trainer_week(p_week_start date,p_offset_days integer) returns jsonb
language sql stable security invoker set search_path='' as $$select trainer_private.week_snapshot(p_week_start,p_offset_days)$$;
create function public.copy_trainer_week(p_operation_id uuid,p_week_start date,p_offset_days integer,p_fingerprint text) returns jsonb
language sql security invoker set search_path='' as $$select trainer_private.copy_week(p_operation_id,p_week_start,p_offset_days,p_fingerprint)$$;

do $$ declare f record; begin
 for f in select p.oid::regprocedure as signature,p.proname from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname in ('public','trainer_private') and p.proname in ('save_group','list_groups','prepare_batch','preview_batch','deliver_batch','week_snapshot','copy_week',
  'save_trainer_group','list_trainer_groups','preview_trainer_batch','deliver_trainer_batch','preview_trainer_week','copy_trainer_week') loop
  execute format('revoke all on function %s from public,anon,authenticated',f.signature);
  if f.proname<>'prepare_batch' then execute format('grant execute on function %s to authenticated',f.signature); end if;
 end loop;
end $$;
commit;
