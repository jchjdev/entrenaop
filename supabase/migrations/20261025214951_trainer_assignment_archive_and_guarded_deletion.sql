begin;

-- Estado de presentación privado: nunca modifica la cita ni la receta del alumno.
-- La fila se crea al asignar y también serializa el enlace externo frente al borrado.
create table trainer_private.assignment_lifecycle (
 assignment_id uuid primary key references public.trainer_assignments(scheduled_id) on delete cascade,
 revision bigint not null default 0 check(revision>=0),archived_at timestamptz,
 external_reference boolean not null default false
);
create table trainer_private.assignment_lifecycle_writes (
 trainer_id uuid not null references public.profiles on delete cascade,operation_id uuid not null,
 assignment_id uuid not null,action text not null check(action in ('archive','restore','delete')),
 payload jsonb not null,result jsonb not null,created_at timestamptz not null default now(),
 primary key(trainer_id,operation_id)
);
create unique index assignment_deleted_identity on trainer_private.assignment_lifecycle_writes(assignment_id) where action='delete';
alter table trainer_private.assignment_lifecycle enable row level security;
alter table trainer_private.assignment_lifecycle_writes enable row level security;
revoke all on trainer_private.assignment_lifecycle,trainer_private.assignment_lifecycle_writes from public,anon,authenticated;
insert into trainer_private.assignment_lifecycle(assignment_id,external_reference)
 select a.scheduled_id,exists(select 1 from device_private.training_deliveries d where d.scheduled_id=a.scheduled_id)
  or exists(select 1 from device_private.training_sync_jobs j where j.scheduled_id=a.scheduled_id)
  or exists(select 1 from device_private.activity_confirmations c where c.scheduled_id=a.scheduled_id)
 from public.trainer_assignments a;

create function trainer_private.initialize_assignment_lifecycle() returns trigger
language plpgsql security definer set search_path='' as $$begin
 insert into trainer_private.assignment_lifecycle(assignment_id) values(new.scheduled_id);
 return new;
end $$;
create trigger initialize_assignment_lifecycle after insert on public.trainer_assignments
 for each row execute function trainer_private.initialize_assignment_lifecycle();
create function trainer_private.reject_deleted_assignment_identity() returns trigger
language plpgsql security definer set search_path='' as $$begin
 if exists(select 1 from trainer_private.assignment_lifecycle_writes where assignment_id=new.scheduled_id and action='delete') then
  raise exception 'Esta asignación fue eliminada. Crea una nueva pauta.' using errcode='22023';end if;
 return new;
end $$;
create trigger reject_deleted_assignment_identity before insert on public.trainer_assignments
 for each row execute function trainer_private.reject_deleted_assignment_identity();

create function trainer_private.retain_assignment_external_reference() returns trigger
language plpgsql security definer set search_path='' as $$begin
 -- UPDATE escribe una versión aunque el enlace ya exista. Frente a DELETE,
 -- READ COMMITTED ve el marcador confirmado y REPEATABLE READ debe reintentarse.
 update trainer_private.assignment_lifecycle set external_reference=true where assignment_id=new.scheduled_id;
 if not found and exists(select 1 from trainer_private.assignment_lifecycle_writes where assignment_id=new.scheduled_id and action='delete') then
  raise exception 'La asignación fue eliminada; no se puede enlazar con Garmin.' using errcode='23503';end if;
 return new;
end $$;
create trigger retain_assignment_external_reference before insert or update of scheduled_id on device_private.training_deliveries
 for each row execute function trainer_private.retain_assignment_external_reference();
create trigger retain_assignment_external_reference before insert or update of scheduled_id on device_private.training_sync_jobs
 for each row execute function trainer_private.retain_assignment_external_reference();
create trigger retain_assignment_external_reference before insert or update of scheduled_id on device_private.activity_confirmations
 for each row execute function trainer_private.retain_assignment_external_reference();

create function trainer_private.assignment_delete_block(p_id uuid) returns text
language plpgsql stable security definer set search_path='' as $$
declare s public.scheduled_workouts;a public.trainer_assignments;
begin
 select * into a from public.trainer_assignments where scheduled_id=p_id;
 select * into s from public.scheduled_workouts where id=p_id;
 if a.scheduled_id is null or s.id is null then return 'missing';end if;
 if s.execution_id is not null or a.result_revision>0
  or exists(select 1 from trainer_private.assignment_reviews where assignment_id=p_id)
  or exists(select 1 from trainer_private.review_writes where assignment_id=p_id) then return 'results';end if;
 if exists(select 1 from trainer_private.assignment_lifecycle where assignment_id=p_id and external_reference)
  or exists(select 1 from device_private.training_deliveries where scheduled_id=p_id)
  or exists(select 1 from device_private.training_sync_jobs where scheduled_id=p_id)
  or exists(select 1 from device_private.activity_confirmations where scheduled_id=p_id) then return 'garmin';end if;
 if exists(select 1 from trainer_private.messages where assignment_id=p_id)
  or exists(select 1 from public.exercise_video_assets where assignment_id=p_id)
  or exists(select 1 from public.running_week_sessions where scheduled_workout_id=p_id)
  or exists(select 1 from public.performance_week_work where scheduled_workout_id=p_id) then return 'references';end if;
 if s.status<>'cancelled' then return 'notWithdrawn';end if;
 return null;
end $$;
create function trainer_private.assignment_lifecycle_json(p_id uuid) returns jsonb
language sql stable security definer set search_path='' as $$
 select jsonb_build_object('archived_at',l.archived_at,'archive_revision',l.revision,
  'delete_block_reason',trainer_private.assignment_delete_block(l.assignment_id))
 from trainer_private.assignment_lifecycle l join public.trainer_assignments a on a.scheduled_id=l.assignment_id
 where l.assignment_id=p_id and a.trainer_id=auth.uid();
$$;
create function trainer_private.assignment_visible(p_id uuid,p_status text,p_visibility text) returns boolean
language sql stable security definer set search_path='' as $$
 select case p_visibility when 'all' then true
  when 'archived' then exists(select 1 from trainer_private.assignment_lifecycle where assignment_id=p_id and archived_at is not null)
  when 'withdrawn' then p_status='cancelled' and not exists(select 1 from trainer_private.assignment_lifecycle where assignment_id=p_id and archived_at is not null)
  else not exists(select 1 from trainer_private.assignment_lifecycle where assignment_id=p_id and archived_at is not null) end;
$$;

create function trainer_private.change_assignment_lifecycle(p_expected_owner uuid,p_operation_id uuid,p_id uuid,p_revision bigint,p_action text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare a public.trainer_assignments;l trainer_private.assignment_lifecycle;prior trainer_private.assignment_lifecycle_writes;
 payload jsonb;result jsonb;blocked text;state text;
begin
 perform trainer_private.program_work_identity(p_expected_owner);
 perform trainer_private.require_authoring_access();
 if p_operation_id is null or p_revision is null or p_revision<0 or p_action is null or p_action not in ('archive','restore','delete') then raise invalid_parameter_value;end if;
 payload:=jsonb_build_object('id',p_id,'revision',p_revision,'action',p_action);
 perform pg_advisory_xact_lock(hashtextextended('trainer-lifecycle:'||auth.uid()::text||':'||p_operation_id::text,0));
 select * into prior from trainer_private.assignment_lifecycle_writes where trainer_id=auth.uid() and operation_id=p_operation_id;
 if found then
  if prior.payload<>payload then raise exception 'La operación ya se utilizó para otro cambio.' using errcode='22023';end if;
  return prior.result;
 end if;
 a:=trainer_private.lock_assignment(p_id);
 -- Mismo orden que el ejecutor: alumno → cita → asignación → presentación.
 select * into l from trainer_private.assignment_lifecycle where assignment_id=p_id for update;
 if not found or l.revision<>p_revision then raise exception 'La pauta cambió. Actualiza antes de continuar.' using errcode='40001';end if;
 select status into state from public.scheduled_workouts where id=p_id;
 if state<>'cancelled' then raise exception 'Retira primero la pauta. No se puede archivar ni borrar una sesión activa o realizada.' using errcode='22023';end if;
 if p_action='delete' then
  blocked:=trainer_private.assignment_delete_block(p_id);
  if blocked is not null then
   raise exception '%',case blocked when 'results' then 'No se puede borrar: conserva una ejecución o resultados. Puedes archivarla.'
    when 'garmin' then 'No se puede borrar: conserva vínculos con Garmin. Puedes archivarla.'
    else 'No se puede borrar: conserva conversaciones, vídeos u otras referencias. Puedes archivarla.' end using errcode='22023';end if;
  result:=jsonb_build_object('id',p_id,'deleted',true);
 else
  update trainer_private.assignment_lifecycle set archived_at=case when p_action='archive' then coalesce(archived_at,clock_timestamp()) else null end,
   revision=revision+1 where assignment_id=p_id;
  result:=jsonb_build_object('id',p_id,'deleted',false)||trainer_private.assignment_lifecycle_json(p_id);
 end if;
 insert into trainer_private.assignment_lifecycle_writes(trainer_id,operation_id,assignment_id,action,payload,result)
 values(auth.uid(),p_operation_id,p_id,p_action,payload,result);
 if p_action='delete' then
  -- Solo elimina la cita: ni plantilla, ni historial de avisos, ni recetas ajenas.
  delete from public.scheduled_workouts where id=p_id;
 end if;
 return result;
end $$;
create function public.change_trainer_assignment_lifecycle(p_expected_owner uuid,p_operation_id uuid,p_id uuid,p_revision bigint,p_action text) returns jsonb
language sql security invoker set search_path='' as $$select trainer_private.change_assignment_lifecycle(p_expected_owner,p_operation_id,p_id,p_revision,p_action)$$;

-- Filtrar ANTES de paginar. Se reutilizan las proyecciones vigentes, incluida
-- device_training propia y READ ONLY; no se llama al motor de envío Garmin.
do $$declare name text;signature text;definition text;anchor text;begin
 foreach name in array array['list_trainer_agenda','list_trainer_assignments','list_trainer_client_agenda'] loop
  signature:=case name when 'list_trainer_agenda' then '(date,date,date,uuid)' when 'list_trainer_assignments' then '(uuid,timestamptz,uuid)' else '(uuid,uuid,date,date,date,uuid)' end;
  definition:=pg_get_functiondef(('trainer_private.'||name||signature)::regprocedure);
  definition:=replace(definition,'trainer_private.'||name||'(', 'trainer_private.'||name||'_filtered('||case when name='list_trainer_client_agenda' then '' else 'p_expected_owner uuid, ' end||'p_visibility text, ');
  anchor:='where a.trainer_id=auth.uid()';
  if strpos(definition,anchor)=0 or strpos(definition,'to_jsonb(x)')=0 then raise exception 'Revisar la proyección de % antes de migrar',name;end if;
  definition:=replace(definition,anchor,anchor||' and trainer_private.assignment_visible(s.id,s.status,p_visibility)');
  definition:=replace(definition,'to_jsonb(x)','(to_jsonb(x)||trainer_private.assignment_lifecycle_json(x.id))');
  definition:=regexp_replace(definition,'\mbegin\M',E'begin\n perform trainer_private.program_work_identity(p_expected_owner);\n if p_visibility is null or p_visibility not in (''current'',''withdrawn'',''archived'',''all'') then raise invalid_parameter_value;end if;','i');
  execute definition;
 end loop;
end $$;
create function public.list_trainer_agenda_filtered(p_expected_owner uuid,p_visibility text,p_from date,p_to date,p_after_date date default null,p_after_id uuid default null) returns jsonb
language sql stable security invoker set search_path='' as $$select trainer_private.list_trainer_agenda_filtered(p_expected_owner,p_visibility,p_from,p_to,p_after_date,p_after_id)$$;
create function public.list_trainer_assignments_filtered(p_expected_owner uuid,p_visibility text,p_client_id uuid,p_before_at timestamptz default null,p_before_id uuid default null) returns jsonb
language sql stable security invoker set search_path='' as $$select trainer_private.list_trainer_assignments_filtered(p_expected_owner,p_visibility,p_client_id,p_before_at,p_before_id)$$;
create function public.list_trainer_client_agenda_filtered(p_visibility text,p_expected_owner uuid,p_client_id uuid,p_from date,p_to date,p_after_date date default null,p_after_id uuid default null) returns jsonb
language sql stable security invoker set search_path='' as $$select trainer_private.list_trainer_client_agenda_filtered(p_visibility,p_expected_owner,p_client_id,p_from,p_to,p_after_date,p_after_id)$$;

-- La bandeja conserva su historial, pero una cita eliminada o retirada no debe
-- producir una push de planificación huérfana cuando su grupo estaba pendiente.
do $$declare definition text;anchor text;begin
 definition:=pg_get_functiondef('push_private.prepare_notice_job(uuid,uuid,bigint,uuid)'::regprocedure);
 anchor:='and n.read_at is null and n.created_at>';
 if strpos(definition,anchor)=0 then raise exception 'Revisar la preparación de avisos antes de migrar';end if;
 definition:=replace(definition,anchor,'and (n.kind<>''assignment'' or exists(select 1 from public.scheduled_workouts s where s.id=n.source_id and s.user_id=n.owner_id and s.status<>''cancelled'')) '||anchor);
 execute definition;
end $$;

do $$declare f record;begin
 for f in select p.oid::regprocedure as signature,p.proname,n.nspname from pg_proc p join pg_namespace n on n.oid=p.pronamespace
 where (n.nspname='trainer_private' and p.proname in ('initialize_assignment_lifecycle','reject_deleted_assignment_identity','retain_assignment_external_reference','assignment_delete_block','assignment_lifecycle_json','assignment_visible','change_assignment_lifecycle','list_trainer_agenda_filtered','list_trainer_assignments_filtered','list_trainer_client_agenda_filtered'))
  or (n.nspname='public' and p.proname in ('change_trainer_assignment_lifecycle','list_trainer_agenda_filtered','list_trainer_assignments_filtered','list_trainer_client_agenda_filtered')) loop
  execute format('revoke all on function %s from public,anon,authenticated,service_role',f.signature);
  if f.proname in ('change_assignment_lifecycle','change_trainer_assignment_lifecycle','list_trainer_agenda_filtered','list_trainer_assignments_filtered','list_trainer_client_agenda_filtered') then
   execute format('grant execute on function %s to authenticated',f.signature);
  end if;
 end loop;
end $$;
commit;
