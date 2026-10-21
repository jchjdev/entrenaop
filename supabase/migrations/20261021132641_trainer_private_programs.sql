begin;

-- La receta profesional comparte el modelo de composición, pero no pertenece
-- al escaparate oficial ni concede acceso general al resto de sus sesiones.
create table trainer_private.programs (
 id uuid primary key default gen_random_uuid(),
 trainer_id uuid not null references public.profiles(id) on delete cascade,
 family_id uuid not null,
 version integer not null check(version>0),
 previous_id uuid references trainer_private.programs(id) on delete restrict,
 status text not null default 'published' check(status in ('published','archived')),
 content jsonb not null check(jsonb_typeof(content)='object' and octet_length(content::text)<=262144),
 created_at timestamptz not null default now(),
 unique(family_id,version)
);
create index trainer_programs_owner_page on trainer_private.programs(trainer_id,created_at desc,id desc);
create index trainer_programs_previous on trainer_private.programs(previous_id);
create table trainer_private.program_sessions (
 program_id uuid not null references trainer_private.programs(id) on delete cascade,
 phase_index integer not null check(phase_index>=0),
 session_index integer not null check(session_index>=0),
 template_id uuid not null references public.workout_templates(id) on delete restrict,
 primary key(program_id,phase_index,session_index)
);
create index trainer_program_sessions_template on trainer_private.program_sessions(template_id);
create table trainer_private.program_writes (
 trainer_id uuid not null references public.profiles(id) on delete cascade,
 operation_id uuid not null,
 previous_id uuid,
 payload jsonb not null,
 program_id uuid not null references trainer_private.programs(id) on delete restrict,
 primary key(trainer_id,operation_id)
);
create index trainer_program_writes_program on trainer_private.program_writes(program_id);
create table trainer_private.program_deliveries (
 id uuid primary key,
 trainer_id uuid not null references public.profiles(id) on delete cascade,
 relation_id uuid not null references public.trainer_client_relations(id) on delete restrict,
 program_id uuid not null references trainer_private.programs(id) on delete restrict,
 entries jsonb not null,
 note text,
 created_at timestamptz not null default now()
);
create index trainer_program_deliveries_owner on trainer_private.program_deliveries(trainer_id);
create index trainer_program_deliveries_relation on trainer_private.program_deliveries(relation_id);
create index trainer_program_deliveries_program on trainer_private.program_deliveries(program_id);
alter table public.trainer_assignments add column program_delivery_id uuid
 references trainer_private.program_deliveries(id) on delete restrict;
create index trainer_assignments_program_delivery on public.trainer_assignments(program_delivery_id);

do $$ declare t text; begin
 foreach t in array array['programs','program_sessions','program_writes','program_deliveries'] loop
  execute format('alter table trainer_private.%I enable row level security',t);
  execute format('revoke all on trainer_private.%I from public,anon,authenticated',t);
 end loop;
end $$;

create function trainer_private.save_trainer_program(p_operation_id uuid,p_payload jsonb,p_previous_id uuid default null)
returns uuid language plpgsql security definer set search_path='' as $$
declare prior trainer_private.program_writes; old trainer_private.programs;
 result uuid:=gen_random_uuid(); family uuid; version_number integer:=1;
 phase jsonb; session jsonb; pi integer:=0; si integer; tid uuid;
begin
 perform trainer_private.require_authoring_access();
 if p_operation_id is null or p_payload is null then raise invalid_parameter_value; end if;
 select * into prior from trainer_private.program_writes where trainer_id=auth.uid() and operation_id=p_operation_id;
 if found then
  if prior.payload is distinct from p_payload or prior.previous_id is distinct from p_previous_id then
   raise exception 'El reintento no coincide con el programa original.' using errcode='22023'; end if;
  return prior.program_id;
 end if;
 if jsonb_typeof(p_payload)<>'object' or octet_length(p_payload::text)>262144
  or length(coalesce(btrim(p_payload->>'name'),'')) not between 1 and 80
  or coalesce(p_payload->>'mode','') not in ('guide','phased')
  or jsonb_typeof(p_payload->'phases') is distinct from 'array' then raise invalid_parameter_value; end if;
 if jsonb_array_length(p_payload->'phases') not between 1 and 24
  or (p_payload->>'mode'='guide' and jsonb_array_length(p_payload->'phases')<>1) then raise invalid_parameter_value; end if;
 family:=result;
 if p_previous_id is not null then
  select * into old from trainer_private.programs where id=p_previous_id and trainer_id=auth.uid() and status='published' for update;
  if not found then raise exception 'El programa cambió. Recarga antes de revisarlo.' using errcode='40001'; end if;
  family:=old.family_id; version_number:=old.version+1;
  update trainer_private.programs set status='archived' where id=old.id;
 end if;
 insert into trainer_private.programs(id,trainer_id,family_id,version,previous_id,content)
  values(result,auth.uid(),family,version_number,p_previous_id,p_payload);
 for phase in select value from jsonb_array_elements(p_payload->'phases') loop
  if length(coalesce(btrim(phase->>'name'),'')) not between 1 and 80
   or jsonb_typeof(phase->'sessions') is distinct from 'array' then raise invalid_parameter_value; end if;
  if jsonb_array_length(phase->'sessions') not between 1 and 64
   or (p_payload->>'mode'='phased' and (coalesce((phase->>'duration_weeks')::integer,0) not between 1 and 104
    or btrim(coalesce(phase->>'instructions',''))='')) then raise invalid_parameter_value; end if;
  si:=0;
  for session in select value from jsonb_array_elements(phase->'sessions') loop
   tid:=(session->>'template_id')::uuid;
   -- El descanso y calentamiento ya quedan fijados en la receta. Los ajustes
   -- de consumo del programa oficial no se aplican silenciosamente a una cita.
   if btrim(coalesce(session->>'name',''))='' or nullif(session->>'warmup_id','') is not null
    or session->'rest'->>'min_seconds' is not null or session->'rest'->>'max_seconds' is not null then
    raise exception 'Conserva calentamientos y descansos dentro de la sesión privada.' using errcode='22023'; end if;
   perform 1 from public.workout_templates where id=tid and origin='coach' and owner_user_id=auth.uid()
    and status in ('published','archived') for share;
   if not found then raise insufficient_privilege; end if;
   insert into trainer_private.program_sessions values(result,pi,si,tid);
   si:=si+1;
  end loop;
  pi:=pi+1;
 end loop;
 insert into trainer_private.program_writes values(auth.uid(),p_operation_id,p_previous_id,p_payload,result);
 return result;
end $$;

create function trainer_private.get_trainer_program(p_id uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare result jsonb;
begin
 if not trainer_private.has_trainer_mfa() then raise insufficient_privilege; end if;
 select to_jsonb(p) into result from trainer_private.programs p where id=p_id and trainer_id=auth.uid();
 if result is null then raise insufficient_privilege; end if;
 return result;
end $$;
create function trainer_private.list_trainer_programs(p_before_at timestamptz default null,p_before_id uuid default null) returns jsonb
language plpgsql stable security definer set search_path='' as $$
begin
 if not trainer_private.has_trainer_mfa() then raise insufficient_privilege; end if;
 if (p_before_at is null)<>(p_before_id is null) then raise invalid_parameter_value; end if;
 return (select coalesce(jsonb_agg(to_jsonb(x) order by created_at desc,id desc),'[]') from (
  select id,family_id,version,status,content,created_at from trainer_private.programs where trainer_id=auth.uid() and status='published'
   and (p_before_at is null or (created_at,id)<(p_before_at,p_before_id)) order by created_at desc,id desc limit 50) x);
end $$;

-- Una versión de programa fija recetas que pueden haberse revisado después.
-- Solo esta entrada interna permite asignar esas versiones retiradas. La RPC
-- de sesión suelta continúa admitiendo exclusivamente la versión vigente.
do $migration$
declare definition text;
begin
 definition:=pg_get_functiondef('trainer_private.assign_trainer_workout(uuid,uuid,uuid,date,text)'::regprocedure);
 if strpos(definition,'and status=''published'' for share')=0 then raise exception 'Revisar motor de asignación.'; end if;
 definition:=replace(definition,'assign_trainer_workout(p_id uuid, p_relation_id uuid, p_template_id uuid, p_date date, p_note text DEFAULT NULL::text)',
  'assign_trainer_workout_version(p_id uuid, p_relation_id uuid, p_template_id uuid, p_date date, p_note text, p_pinned boolean)');
 if strpos(definition,'assign_trainer_workout_version')=0 then raise exception 'Revisar firma del motor de asignación.'; end if;
 definition:=replace(definition,'and status=''published'' for share','and (status=''published'' or (p_pinned and status=''archived'')) for share');
 execute definition;
end $migration$;
revoke all on function trainer_private.assign_trainer_workout_version(uuid,uuid,uuid,date,text,boolean) from public,anon,authenticated;
create or replace function trainer_private.assign_trainer_workout(p_id uuid,p_relation_id uuid,p_template_id uuid,p_date date,p_note text default null)
returns uuid language sql security definer set search_path='' as $$
 select trainer_private.assign_trainer_workout_version(p_id,p_relation_id,p_template_id,p_date,p_note,false);
$$;

create function trainer_private.assign_trainer_program(p_id uuid,p_relation_id uuid,p_program_id uuid,p_entries jsonb,p_note text default null)
returns uuid language plpgsql security definer set search_path='' as $$
declare r public.trainer_client_relations; p trainer_private.programs; prior trainer_private.program_deliveries;
 entry jsonb; tid uuid; sid uuid; pi integer; si integer; full_note text;
begin
 if not trainer_private.has_trainer_mfa() then raise insufficient_privilege; end if;
 select * into r from public.trainer_client_relations where id=p_relation_id and trainer_id=auth.uid();
 if not found then raise insufficient_privilege; end if;
 perform pg_advisory_xact_lock(hashtextextended('trainer-client:'||r.client_id::text,0));
 perform trainer_private.require_authoring_access();
 select * into prior from trainer_private.program_deliveries where id=p_id;
 if found then
  if prior.trainer_id=auth.uid() and prior.relation_id=p_relation_id and prior.program_id=p_program_id
   and prior.entries=p_entries and prior.note is not distinct from nullif(btrim(p_note),'') then return p_id; end if;
  raise exception 'El reintento no coincide con la planificación original.' using errcode='22023';
 end if;
 if p_id is null or jsonb_typeof(p_entries) is distinct from 'array' or char_length(p_note)>320 then raise invalid_parameter_value; end if;
 if jsonb_array_length(p_entries) not between 1 and 256 then raise invalid_parameter_value; end if;
 if exists(select 1 from jsonb_array_elements(p_entries) e group by e->>'phase',e->>'session',e->>'date' having count(*)>1) then
  raise exception 'Hay una misma sesión repetida en la misma fecha.' using errcode='22023'; end if;
 perform 1 from public.trainer_client_relations where id=r.id and ended_at is null;
 if not found then raise insufficient_privilege; end if;
 select * into p from trainer_private.programs where id=p_program_id and trainer_id=auth.uid() for share;
 if not found then raise insufficient_privilege; end if;
 insert into trainer_private.program_deliveries(id,trainer_id,relation_id,program_id,entries,note)
  values(p_id,auth.uid(),r.id,p.id,p_entries,nullif(btrim(p_note),''));
 for entry in select value from jsonb_array_elements(p_entries) loop
  pi:=(entry->>'phase')::integer; si:=(entry->>'session')::integer;
  select template_id into tid from trainer_private.program_sessions where program_id=p.id and phase_index=pi and session_index=si;
  if not found or nullif(entry->>'date','') is null then raise invalid_parameter_value; end if;
  full_note:=(p.content->>'name')||' · '||(p.content->'phases'->pi->>'name')||coalesce(E'\n'||nullif(btrim(p_note),''),'');
  sid:=trainer_private.assign_trainer_workout_version(gen_random_uuid(),r.id,tid,(entry->>'date')::date,full_note,true);
  update public.trainer_assignments set program_delivery_id=p_id where scheduled_id=sid;
 end loop;
 return p_id;
end $$;

create function public.save_trainer_program(p_operation_id uuid,p_payload jsonb,p_previous_id uuid default null) returns uuid
language sql security invoker set search_path='' as $$ select trainer_private.save_trainer_program(p_operation_id,p_payload,p_previous_id); $$;
create function public.get_trainer_program(p_id uuid) returns jsonb
language sql stable security invoker set search_path='' as $$ select trainer_private.get_trainer_program(p_id); $$;
create function public.list_trainer_programs(p_before_at timestamptz default null,p_before_id uuid default null) returns jsonb
language sql stable security invoker set search_path='' as $$ select trainer_private.list_trainer_programs(p_before_at,p_before_id); $$;
create function public.assign_trainer_program(p_id uuid,p_relation_id uuid,p_program_id uuid,p_entries jsonb,p_note text default null) returns uuid
language sql security invoker set search_path='' as $$ select trainer_private.assign_trainer_program(p_id,p_relation_id,p_program_id,p_entries,p_note); $$;

create function trainer_private.list_trainer_agenda(p_from date,p_to date,p_after_date date default null,p_after_id uuid default null)
returns jsonb language plpgsql stable security definer set search_path='' as $$
begin
 if not trainer_private.has_trainer_mfa() then raise insufficient_privilege; end if;
 if p_from is null or p_to is null or p_to<p_from or p_to-p_from>61
  or (p_after_date is null)<>(p_after_id is null) then raise invalid_parameter_value; end if;
 return (select coalesce(jsonb_agg(to_jsonb(x) order by scheduled_date,id),'[]') from (
  select s.id,s.template_id,s.template_name,s.template_version,s.scheduled_date,s.status,s.execution_id,a.note,a.created_at,
   a.client_id,c.display_name as client_name,e.final_rpe,e.completed_at
  from public.trainer_assignments a join public.scheduled_workouts s on s.id=a.scheduled_id
   join public.trainer_clients c on c.trainer_id=a.trainer_id and c.client_id=a.client_id
   left join public.workout_executions e on e.id=s.execution_id
  where a.trainer_id=auth.uid() and s.scheduled_date between p_from and p_to
   and (p_after_date is null or (s.scheduled_date,s.id)>(p_after_date,p_after_id))
  order by s.scheduled_date,s.id limit 100) x);
end $$;
create function public.list_trainer_agenda(p_from date,p_to date,p_after_date date default null,p_after_id uuid default null) returns jsonb
language sql stable security invoker set search_path='' as $$ select trainer_private.list_trainer_agenda(p_from,p_to,p_after_date,p_after_id); $$;

create or replace function trainer_private.list_trainer_workouts(p_before_at timestamptz default null,p_before_id uuid default null)
returns jsonb language plpgsql stable security definer set search_path='' as $$
begin
 if not trainer_private.has_trainer_mfa() then raise insufficient_privilege; end if;
 if (p_before_at is null)<>(p_before_id is null) then raise invalid_parameter_value; end if;
 return (select coalesce(jsonb_agg(to_jsonb(x) order by created_at desc,id desc),'[]') from (
  select t.id,t.name,t.version,t.created_at,
   exists(select 1 from public.workout_blocks b where b.template_id=t.id and b.format='running') as is_running
  from public.workout_templates t where t.owner_user_id=auth.uid() and t.origin='coach' and t.status='published'
   and (p_before_at is null or (t.created_at,t.id)<(p_before_at,p_before_id)) order by t.created_at desc,t.id desc limit 50) x);
end $$;

do $$ declare f record; begin
 for f in select p.oid::regprocedure as signature from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname in ('public','trainer_private') and p.proname in ('save_trainer_program','get_trainer_program','list_trainer_programs','assign_trainer_program','list_trainer_agenda') loop
  execute format('revoke all on function %s from public,anon,authenticated',f.signature);
  execute format('grant execute on function %s to authenticated',f.signature);
 end loop;
end $$;
commit;
