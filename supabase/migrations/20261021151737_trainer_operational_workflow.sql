begin;

-- La consulta histórica del servicio conserva sus permisos. Leer una señal
-- nueva de la agenda personal del alumno exige además acceso profesional vigente.
create function trainer_private.has_professional_read_access() returns boolean
language sql stable security definer set search_path='' as $$
 select trainer_private.has_trainer_mfa() and exists(
  select 1 from public.trainer_access where trainer_id=auth.uid() and enabled
   and (valid_until is null or valid_until>statement_timestamp())
 );
$$;
revoke all on function trainer_private.has_professional_read_access() from public,anon,authenticated;

alter table public.trainer_assignments
 add column planning_revision bigint not null default 0,
 add column result_revision bigint not null default 0,
 add column result_changed_at timestamptz not null default now();

-- La orden de entrega no cambia al mover/adaptar la cita que produjo.
create table trainer_private.assignment_origins (
 assignment_id uuid primary key references public.trainer_assignments(scheduled_id) on delete cascade,
 trainer_id uuid not null references public.profiles(id) on delete cascade,
 relation_id uuid not null references public.trainer_client_relations(id) on delete restrict,
 template_id uuid not null references public.workout_templates(id) on delete restrict,
 scheduled_date date not null,
 note text
);
create index assignment_origins_owner on trainer_private.assignment_origins(trainer_id);
create index assignment_origins_relation on trainer_private.assignment_origins(relation_id);
create index assignment_origins_template on trainer_private.assignment_origins(template_id);
insert into trainer_private.assignment_origins
 select a.scheduled_id,a.trainer_id,a.relation_id,s.template_id,s.scheduled_date,a.note
 from public.trainer_assignments a join public.scheduled_workouts s on s.id=a.scheduled_id;

create function trainer_private.keep_assignment_origin() returns trigger
language plpgsql security definer set search_path='' as $$
begin
 insert into trainer_private.assignment_origins
  select new.scheduled_id,new.trainer_id,new.relation_id,s.template_id,s.scheduled_date,new.note
  from public.scheduled_workouts s where s.id=new.scheduled_id;
 return new;
end $$;
create trigger trainer_assignment_origin after insert on public.trainer_assignments
 for each row execute function trainer_private.keep_assignment_origin();

create table trainer_private.planning_writes (
 trainer_id uuid not null references public.profiles(id) on delete cascade,
 operation_id uuid not null,
 payload jsonb not null check(octet_length(payload::text)<=131072),
 result jsonb not null,
 created_at timestamptz not null default now(),
 primary key(trainer_id,operation_id)
);
create table trainer_private.assignment_variants (
 template_id uuid primary key references public.workout_templates(id) on delete restrict,
 assignment_id uuid not null references public.trainer_assignments(scheduled_id) on delete cascade
);
create index assignment_variants_assignment on trainer_private.assignment_variants(assignment_id);
create table trainer_private.assignment_reviews (
 assignment_id uuid primary key references public.trainer_assignments(scheduled_id) on delete cascade,
 trainer_id uuid not null references public.profiles(id) on delete cascade,
 result_revision bigint not null check(result_revision>=0),
 reviewed_at timestamptz not null default now(),
 private_note text check(char_length(private_note)<=2000)
);
create index assignment_reviews_owner on trainer_private.assignment_reviews(trainer_id);
create table trainer_private.review_writes (
 trainer_id uuid not null references public.profiles(id) on delete cascade,
 operation_id uuid not null,
 assignment_id uuid not null references public.trainer_assignments(scheduled_id) on delete cascade,
 payload jsonb not null check(octet_length(payload::text)<=12000),
 primary key(trainer_id,operation_id)
);
create index review_writes_assignment on trainer_private.review_writes(assignment_id);
create table trainer_private.messages (
 id uuid primary key,
 relation_id uuid not null references public.trainer_client_relations(id) on delete restrict,
 assignment_id uuid references public.trainer_assignments(scheduled_id) on delete restrict,
 sender_id uuid not null references public.profiles(id) on delete cascade,
 body text not null check(char_length(btrim(body)) between 1 and 4000),
 created_at timestamptz not null default now()
);
create index trainer_messages_relation_page on trainer_private.messages(relation_id,created_at desc,id desc);
create index trainer_messages_sender on trainer_private.messages(sender_id,created_at desc);
create index trainer_messages_assignment on trainer_private.messages(assignment_id);
-- El advisory ordena emisores; la versión detecta snapshots REPEATABLE READ
-- anteriores al último envío, incluso al escribir a alumnos distintos.
create table trainer_private.message_sender_versions (
 sender_id uuid primary key references public.profiles(id) on delete cascade,
 revision bigint not null default 0 check(revision>=0)
);

do $$ declare tab text; begin
 foreach tab in array array['assignment_origins','planning_writes','assignment_variants','assignment_reviews','review_writes','messages','message_sender_versions'] loop
  execute format('alter table trainer_private.%I enable row level security',tab);
  execute format('revoke all on trainer_private.%I from public,anon,authenticated',tab);
 end loop;
end $$;

-- Los reintentos iniciales comparan el ledger, nunca los datos vivos editables.
do $migration$
declare definition text;
 anchor text:=E'if a.trainer_id=auth.uid() and a.relation_id=p_relation_id and old.template_id=p_template_id\n      and old.scheduled_date=p_date and a.note is not distinct from nullif(btrim(p_note),'''') then return p_id; end if;';
begin
 definition:=pg_get_functiondef('trainer_private.assign_trainer_workout_version(uuid,uuid,uuid,date,text,boolean)'::regprocedure);
 if strpos(definition,anchor)=0 then raise exception 'Revisar el motor de entrega antes de migrar.'; end if;
 definition:=replace(definition,anchor,E'if exists(select 1 from trainer_private.assignment_origins o where o.assignment_id=p_id\n      and o.trainer_id=auth.uid() and o.relation_id=p_relation_id and o.template_id=p_template_id\n      and o.scheduled_date=p_date and o.note is not distinct from nullif(btrim(p_note),'''')) then return p_id; end if;');
 execute definition;
end $migration$;

create function trainer_private.bump_assignment_result() returns trigger
language plpgsql security definer set search_path='' as $$
declare execution uuid;
begin
 if tg_table_name='workout_executions' then
  execution:=case when tg_op='DELETE' then old.id else new.id end;
 else execution:=case when tg_op='DELETE' then old.execution_id else new.execution_id end; end if;
 update public.trainer_assignments a set result_revision=result_revision+1,result_changed_at=clock_timestamp()
  from public.scheduled_workouts s where a.scheduled_id=s.id and s.execution_id=execution;
 if tg_op='DELETE' then return old; end if;
 return new;
end $$;
create trigger trainer_execution_revision after insert or update or delete on public.workout_executions
 for each row execute function trainer_private.bump_assignment_result();
create trigger trainer_set_revision after insert or update or delete on public.workout_execution_sets
 for each row execute function trainer_private.bump_assignment_result();
create trigger trainer_amrap_revision after insert or update or delete on public.workout_amrap_results
 for each row execute function trainer_private.bump_assignment_result();

-- Al iniciar, las filas de ejecución nacen antes de enlazarlas con la cita.
-- El enlace, su retirada y los cambios de estado también cambian el resultado.
create function trainer_private.bump_assignment_schedule_result() returns trigger
language plpgsql security definer set search_path='' as $$
begin
 if (old.execution_id is not null or new.execution_id is not null)
  and (old.execution_id is distinct from new.execution_id or old.status is distinct from new.status) then
  update public.trainer_assignments set result_revision=result_revision+1,result_changed_at=clock_timestamp()
   where scheduled_id=new.id;
 end if;
 return new;
end $$;
create trigger trainer_schedule_result_revision after update of execution_id,status on public.scheduled_workouts
 for each row execute function trainer_private.bump_assignment_schedule_result();

create function trainer_private.lock_assignment(p_id uuid) returns public.trainer_assignments
language plpgsql security definer set search_path='' as $$
declare a public.trainer_assignments;
begin
 if not trainer_private.has_trainer_mfa() then raise insufficient_privilege; end if;
 select * into a from public.trainer_assignments where scheduled_id=p_id and trainer_id=auth.uid();
 if not found then raise insufficient_privilege; end if;
 perform pg_advisory_xact_lock(hashtextextended('trainer-client:'||a.client_id::text,0));
 perform trainer_private.require_authoring_access();
 -- El ejecutor sincroniza primero la cita y luego su revisión. Conservar ese
 -- orden evita el ciclo cita/asignación frente a finalización o correcciones.
 perform 1 from public.scheduled_workouts where id=p_id for update;
 select * into a from public.trainer_assignments where scheduled_id=p_id and trainer_id=auth.uid() for update;
 if not found then raise insufficient_privilege; end if;
 return a;
end $$;

create function trainer_private.change_assignment(p_operation_id uuid,p_id uuid,p_expected_revision bigint,
 p_date date,p_note text,p_recipe jsonb default null) returns jsonb
language plpgsql security definer set search_path='' as $$
declare a public.trainer_assignments; s public.scheduled_workouts; prior trainer_private.planning_writes;
 payload jsonb; result jsonb; template uuid; t public.workout_templates;
begin
 a:=trainer_private.lock_assignment(p_id);
 if p_operation_id is null or p_expected_revision is null or p_date is null or char_length(p_note)>500 then raise invalid_parameter_value; end if;
 payload:=jsonb_build_object('assignment_id',p_id,'expected_revision',p_expected_revision,'date',p_date,'note',nullif(btrim(p_note),''),'recipe',p_recipe);
 select * into prior from trainer_private.planning_writes where trainer_id=auth.uid() and operation_id=p_operation_id;
 if found then
  if prior.payload is distinct from payload then raise exception 'El reintento no coincide con la edición.' using errcode='22023'; end if;
  return prior.result;
 end if;
 if a.planning_revision<>p_expected_revision then raise exception 'La pauta cambió. Actualiza la agenda.' using errcode='40001'; end if;
 perform 1 from public.trainer_client_relations where id=a.relation_id and ended_at is null;
 if not found then raise insufficient_privilege; end if;
 select * into s from public.scheduled_workouts where id=p_id and status='planned' and execution_id is null for update;
 if not found then raise exception 'Solo se puede editar una pauta pendiente sin iniciar.' using errcode='22023'; end if;
 if p_recipe is not null then
  template:=trainer_private.save_trainer_workout(p_operation_id,p_recipe,null);
  insert into trainer_private.assignment_variants values(template,p_id);
  select * into t from public.workout_templates where id=template;
  update public.scheduled_workouts set template_id=t.id,template_name=t.name,template_version=t.version,
   estimated_duration_minutes=t.estimated_duration_minutes where id=p_id;
 end if;
 update public.scheduled_workouts set scheduled_date=p_date where id=p_id;
 update public.trainer_assignments set note=nullif(btrim(p_note),''),planning_revision=planning_revision+1 where scheduled_id=p_id
  returning planning_revision into a.planning_revision;
 result:=jsonb_build_object('id',p_id,'planning_revision',a.planning_revision,'template_id',coalesce(template,s.template_id));
 insert into trainer_private.planning_writes(trainer_id,operation_id,payload,result) values(auth.uid(),p_operation_id,payload,result);
 update public.trainer_access set membership_version=membership_version+1 where trainer_id=auth.uid();
 return result;
end $$;

create function trainer_private.preview_schedule(p_client_id uuid,p_from date,p_to date) returns jsonb
language plpgsql stable security definer set search_path='' as $$
begin
 if not trainer_private.has_professional_read_access() or not exists(select 1 from public.trainer_client_relations
  where trainer_id=auth.uid() and client_id=p_client_id and ended_at is null) then raise insufficient_privilege; end if;
 if p_from is null or p_to is null or p_to<p_from or p_to-p_from>366 then raise invalid_parameter_value; end if;
 -- Solo presencia/fecha: el preparador no obtiene el nombre de un plan personal.
 return (select coalesce(jsonb_agg(jsonb_build_object('date',d,'has_other_workout',true) order by d),'[]') from (
  select distinct s.scheduled_date as d from public.scheduled_workouts s
  where s.user_id=p_client_id and s.scheduled_date between p_from and p_to and s.status in ('planned','in_progress')
   and not exists(select 1 from public.trainer_assignments a where a.scheduled_id=s.id and a.trainer_id=auth.uid())
 ) x);
end $$;

create function trainer_private.get_assignment(p_id uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare result jsonb;
begin
 if not trainer_private.has_trainer_mfa() then raise insufficient_privilege; end if;
 select to_jsonb(x) into result from (
  select s.id,s.template_id,s.template_name,s.template_version,s.scheduled_date,s.status,s.execution_id,
   a.note,a.created_at,a.planning_revision,a.result_revision,a.result_changed_at,a.client_id,a.relation_id,
   c.display_name as client_name,e.final_rpe,e.completed_at
  from public.trainer_assignments a join public.scheduled_workouts s on s.id=a.scheduled_id
   join public.trainer_clients c on c.trainer_id=a.trainer_id and c.client_id=a.client_id
   left join public.workout_executions e on e.id=s.execution_id
  where a.scheduled_id=p_id and a.trainer_id=auth.uid()
 ) x;
 if result is null then raise insufficient_privilege; end if;
 return result;
end $$;

create function trainer_private.mark_reviewed(p_operation_id uuid,p_id uuid,p_seen_revision bigint,p_private_note text default null) returns void
language plpgsql security definer set search_path='' as $$
declare a public.trainer_assignments; payload jsonb; prior trainer_private.review_writes;
begin
 a:=trainer_private.lock_assignment(p_id);
 if p_operation_id is null or p_seen_revision is null or char_length(p_private_note)>2000 then raise invalid_parameter_value; end if;
 payload:=jsonb_build_object('seen_revision',p_seen_revision,'private_note',nullif(btrim(p_private_note),''));
 select * into prior from trainer_private.review_writes where trainer_id=auth.uid() and operation_id=p_operation_id;
 if found then
  if prior.assignment_id<>p_id or prior.payload is distinct from payload then raise invalid_parameter_value; end if;
  return;
 end if;
 if a.result_revision<>p_seen_revision then raise exception 'El alumno ha actualizado el resultado. Vuelve a revisarlo.' using errcode='40001'; end if;
 if not exists(select 1 from public.scheduled_workouts s join public.workout_executions e on e.id=s.execution_id
  where s.id=p_id and e.status in ('completed','abandoned')) then raise invalid_parameter_value; end if;
 insert into trainer_private.assignment_reviews(assignment_id,trainer_id,result_revision,reviewed_at,private_note)
  values(p_id,auth.uid(),p_seen_revision,clock_timestamp(),nullif(btrim(p_private_note),''))
 on conflict(assignment_id) do update set result_revision=excluded.result_revision,reviewed_at=excluded.reviewed_at,private_note=excluded.private_note;
 insert into trainer_private.review_writes values(auth.uid(),p_operation_id,p_id,payload);
end $$;

create function trainer_private.list_review_queue(p_before_at timestamptz default null,p_before_id uuid default null) returns jsonb
language plpgsql stable security definer set search_path='' as $$
begin
 if not trainer_private.has_trainer_mfa() then raise insufficient_privilege; end if;
 if (p_before_at is null)<>(p_before_id is null) then raise invalid_parameter_value; end if;
 return (select coalesce(jsonb_agg(to_jsonb(x) order by result_changed_at desc,id desc),'[]') from (
  select s.id,a.client_id,c.display_name as client_name,s.template_name,s.template_id,s.template_version,s.scheduled_date,
   s.status,s.execution_id,a.note,a.created_at,a.planning_revision,a.result_revision,a.result_changed_at,e.completed_at,e.final_rpe
  from public.trainer_assignments a join public.scheduled_workouts s on s.id=a.scheduled_id
   join public.workout_executions e on e.id=s.execution_id join public.trainer_clients c on c.trainer_id=a.trainer_id and c.client_id=a.client_id
   left join trainer_private.assignment_reviews r on r.assignment_id=a.scheduled_id
  where a.trainer_id=auth.uid() and e.status in ('completed','abandoned') and r.result_revision is distinct from a.result_revision
   and (p_before_at is null or (a.result_changed_at,a.scheduled_id)<(p_before_at,p_before_id))
  order by a.result_changed_at desc,a.scheduled_id desc limit 100
 ) x);
end $$;

create or replace function trainer_private.get_trainer_assignment_result(p_id uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare execution uuid; a public.trainer_assignments;
begin
 if not trainer_private.has_trainer_mfa() then raise insufficient_privilege; end if;
 select * into a from public.trainer_assignments where scheduled_id=p_id and trainer_id=auth.uid();
 if not found then raise insufficient_privilege; end if;
 select execution_id into execution from public.scheduled_workouts where id=p_id;
 if execution is null then return null; end if;
 return (select to_jsonb(e)||jsonb_build_object('result_revision',a.result_revision,
  'review',(select to_jsonb(r)-'trainer_id' from trainer_private.assignment_reviews r where r.assignment_id=p_id),
  'workout_execution_sets',coalesce((select jsonb_agg(to_jsonb(es) order by block_order,item_order,set_order) from public.workout_execution_sets es where es.execution_id=e.id),'[]'),
  'workout_amrap_results',coalesce((select jsonb_agg(to_jsonb(ar) order by block_order) from public.workout_amrap_results ar where ar.execution_id=e.id),'[]'))
  from public.workout_executions e where e.id=execution);
end $$;

create function trainer_private.send_message(p_id uuid,p_relation_id uuid,p_body text,p_assignment_id uuid default null) returns uuid
language plpgsql security definer set search_path='' as $$
declare r public.trainer_client_relations; prior trainer_private.messages;
begin
 if auth.uid() is null then raise insufficient_privilege; end if;
 select * into r from public.trainer_client_relations where id=p_relation_id and (trainer_id=auth.uid() or client_id=auth.uid());
 if not found or (r.trainer_id=auth.uid() and not trainer_private.has_trainer_mfa()) then raise insufficient_privilege; end if;
 perform pg_advisory_xact_lock(hashtextextended('trainer-client:'||r.client_id::text,0));
 perform pg_advisory_xact_lock(hashtextextended('trainer-message-sender:'||auth.uid()::text,0));
 select * into prior from trainer_private.messages where id=p_id and sender_id=auth.uid();
 if found then
  if prior.relation_id<>p_relation_id or prior.assignment_id is distinct from p_assignment_id or prior.body is distinct from btrim(p_body) then raise invalid_parameter_value; end if;
  return p_id;
 end if;
 if r.trainer_id=auth.uid() then perform trainer_private.require_authoring_access();
 else
  perform 1 from public.trainer_access where trainer_id=r.trainer_id and enabled and (valid_until is null or valid_until>statement_timestamp()) for update;
  if not found then raise insufficient_privilege; end if;
 end if;
 perform 1 from public.trainer_client_relations where id=r.id and ended_at is null;
 if not found then raise exception 'El servicio está inactivo. Conservas la conversación en consulta.' using errcode='42501'; end if;
 if p_id is null or p_body is null or char_length(btrim(p_body)) not between 1 and 4000 then raise invalid_parameter_value; end if;
 if p_assignment_id is not null and not exists(select 1 from public.trainer_assignments where scheduled_id=p_assignment_id and relation_id=r.id) then raise insufficient_privilege; end if;
 insert into trainer_private.message_sender_versions(sender_id,revision) values(auth.uid(),1)
  on conflict(sender_id) do update set revision=message_sender_versions.revision+1;
 if (select count(*) from trainer_private.messages where sender_id=auth.uid() and created_at>statement_timestamp()-interval '1 hour')>=100 then
  raise exception 'Has enviado muchos mensajes. Espera antes de volver a intentarlo.' using errcode='54000'; end if;
 insert into trainer_private.messages(id,relation_id,assignment_id,sender_id,body) values(p_id,r.id,p_assignment_id,auth.uid(),btrim(p_body));
 return p_id;
end $$;

create function trainer_private.conversation_context(p_relation_id uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare r public.trainer_client_relations; counterpart uuid; can_send boolean;
begin
 select * into r from public.trainer_client_relations where id=p_relation_id and (trainer_id=auth.uid() or client_id=auth.uid());
 if not found or (r.trainer_id=auth.uid() and not trainer_private.has_trainer_mfa()) then raise insufficient_privilege; end if;
 counterpart:=case when r.trainer_id=auth.uid() then r.client_id else r.trainer_id end;
 can_send:=r.ended_at is null and exists(select 1 from public.trainer_access where trainer_id=r.trainer_id
  and enabled and (valid_until is null or valid_until>statement_timestamp()));
 return jsonb_build_object('name',coalesce((select nullif(btrim(full_name),'') from public.profiles where id=counterpart),'Preparación acompañada'),
  'can_send',can_send);
end $$;

create function trainer_private.list_messages(p_relation_id uuid,p_before_at timestamptz default null,p_before_id uuid default null) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare r public.trainer_client_relations;
begin
 select * into r from public.trainer_client_relations where id=p_relation_id and (trainer_id=auth.uid() or client_id=auth.uid());
 if not found or (r.trainer_id=auth.uid() and not trainer_private.has_trainer_mfa()) then raise insufficient_privilege; end if;
 if (p_before_at is null)<>(p_before_id is null) then raise invalid_parameter_value; end if;
 return (select coalesce(jsonb_agg(to_jsonb(x) order by created_at desc,id desc),'[]') from (
  select m.id,m.assignment_id,m.sender_id,m.body,m.created_at from trainer_private.messages m where m.relation_id=r.id
   and (p_before_at is null or (m.created_at,m.id)<(p_before_at,p_before_id)) order by m.created_at desc,m.id desc limit 50
 ) x);
end $$;

-- Las bibliotecas no muestran adaptaciones particulares como nuevas plantillas.
do $migration$
declare definition text; anchor text:='where t.owner_user_id=auth.uid() and t.origin=''coach'' and t.status=''published''';
begin
 definition:=pg_get_functiondef('trainer_private.list_trainer_workouts(timestamptz,uuid)'::regprocedure);
 if strpos(definition,anchor)=0 then raise exception 'Revisar biblioteca antes de filtrar adaptaciones.'; end if;
 execute replace(definition,anchor,anchor||' and not exists(select 1 from trainer_private.assignment_variants v where v.template_id=t.id)');
 -- Las listas existentes añaden revisión sin romper consumidores anteriores.
 definition:=pg_get_functiondef('trainer_private.list_trainer_assignments(uuid,timestamptz,uuid)'::regprocedure);
 if strpos(definition,'a.note,a.created_at')=0 then raise exception 'Revisar lista de pautas.'; end if;
 execute replace(definition,'a.note,a.created_at','a.note,a.created_at,a.planning_revision,a.result_revision');
 definition:=pg_get_functiondef('trainer_private.list_trainer_agenda(date,date,date,uuid)'::regprocedure);
 if strpos(definition,'a.note,a.created_at')=0 then raise exception 'Revisar agenda.'; end if;
 execute replace(definition,'a.note,a.created_at','a.note,a.created_at,a.planning_revision,a.result_revision');
end $migration$;

create function public.change_trainer_assignment(p_operation_id uuid,p_id uuid,p_expected_revision bigint,p_date date,p_note text,p_recipe jsonb default null) returns jsonb
language sql security invoker set search_path='' as $$select trainer_private.change_assignment(p_operation_id,p_id,p_expected_revision,p_date,p_note,p_recipe)$$;
create function public.preview_trainer_schedule(p_client_id uuid,p_from date,p_to date) returns jsonb
language sql security invoker set search_path='' as $$select trainer_private.preview_schedule(p_client_id,p_from,p_to)$$;
create function public.get_trainer_assignment(p_id uuid) returns jsonb
language sql security invoker set search_path='' as $$select trainer_private.get_assignment(p_id)$$;
create function public.mark_trainer_assignment_reviewed(p_operation_id uuid,p_id uuid,p_seen_revision bigint,p_private_note text default null) returns void
language sql security invoker set search_path='' as $$select trainer_private.mark_reviewed(p_operation_id,p_id,p_seen_revision,p_private_note)$$;
create function public.list_trainer_review_queue(p_before_at timestamptz default null,p_before_id uuid default null) returns jsonb
language sql security invoker set search_path='' as $$select trainer_private.list_review_queue(p_before_at,p_before_id)$$;
create function public.send_trainer_message(p_id uuid,p_relation_id uuid,p_body text,p_assignment_id uuid default null) returns uuid
language sql security invoker set search_path='' as $$select trainer_private.send_message(p_id,p_relation_id,p_body,p_assignment_id)$$;
create function public.list_trainer_messages(p_relation_id uuid,p_before_at timestamptz default null,p_before_id uuid default null) returns jsonb
language sql security invoker set search_path='' as $$select trainer_private.list_messages(p_relation_id,p_before_at,p_before_id)$$;
create function public.get_trainer_conversation(p_relation_id uuid) returns jsonb
language sql security invoker set search_path='' as $$select trainer_private.conversation_context(p_relation_id)$$;

do $$ declare f record; begin
 for f in select p.oid::regprocedure as signature from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname in ('public','trainer_private') and p.proname in (
   'keep_assignment_origin','bump_assignment_result','bump_assignment_schedule_result','lock_assignment','change_assignment','preview_schedule','get_assignment','mark_reviewed','list_review_queue','send_message','list_messages','conversation_context','get_trainer_conversation',
   'change_trainer_assignment','preview_trainer_schedule','get_trainer_assignment','mark_trainer_assignment_reviewed','list_trainer_review_queue','send_trainer_message','list_trainer_messages') loop
  execute format('revoke all on function %s from public,anon,authenticated',f.signature);
  if f.signature::text !~ '(keep_assignment_origin|bump_assignment_result|bump_assignment_schedule_result|lock_assignment)' then
   execute format('grant execute on function %s to authenticated',f.signature);
  end if;
 end loop;
end $$;
commit;
