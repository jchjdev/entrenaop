begin;

-- La cita existente sigue siendo la fuente de agenda y ejecución. Este vínculo
-- fija la etapa aceptada que autoriza al preparador a consultar sus resultados.
create table public.trainer_assignments (
  scheduled_id uuid primary key references public.scheduled_workouts(id) on delete cascade,
  relation_id uuid not null references public.trainer_client_relations(id) on delete restrict,
  trainer_id uuid not null references public.profiles(id) on delete cascade,
  client_id uuid not null references public.profiles(id) on delete cascade,
  note text check (char_length(note)<=500),
  created_at timestamptz not null default now(),
  check(trainer_id<>client_id)
);
create index trainer_assignments_client_page on public.trainer_assignments(trainer_id,client_id,created_at desc,scheduled_id desc);
create index trainer_assignments_relation on public.trainer_assignments(relation_id);
create index trainer_assignments_client on public.trainer_assignments(client_id);
alter table public.trainer_assignments enable row level security;
revoke all on public.trainer_assignments from public,anon,authenticated;
grant select on public.trainer_assignments to authenticated;
create policy trainer_assignment_participants on public.trainer_assignments for select to authenticated
using(client_id=(select auth.uid()) or (trainer_id=(select auth.uid()) and (select trainer_private.has_trainer_mfa())));

create table trainer_private.workout_writes (
  trainer_id uuid not null references public.profiles(id) on delete cascade,
  operation_id uuid not null,
  previous_id uuid,
  payload jsonb not null,
  template_id uuid not null references public.workout_templates(id) on delete restrict,
  primary key(trainer_id,operation_id)
);
alter table trainer_private.workout_writes enable row level security;
revoke all on trainer_private.workout_writes from public,anon,authenticated;

create function trainer_private.require_authoring_access() returns void
language plpgsql security definer set search_path='' as $$
begin
  if not trainer_private.has_trainer_mfa() then raise insufficient_privilege; end if;
  perform 1 from public.trainer_access where trainer_id=auth.uid()
    and enabled and (valid_until is null or valid_until>statement_timestamp()) for update;
  if not found then raise exception 'Acceso profesional inactivo.' using errcode='42501'; end if;
end $$;
revoke all on function trainer_private.require_authoring_access() from public,anon,authenticated;

-- Reutiliza las validaciones y los constructores que ya emplean deportista y
-- ADMIN. Igual que el contexto oficial existente, solo un RPC autorizado fija
-- el origen profesional antes del INSERT: no ocupa una cuota personal temporal.
do $migration$
declare definition text; anchor text := E'begin\n  -- El contexto solo lo fija';
begin
  definition:=pg_get_functiondef('public.enforce_personal_session_quota()'::regprocedure);
  if strpos(definition,anchor)=0 then raise exception 'Revisar el constructor compartido antes de migrar.'; end if;
  definition:=replace(definition,anchor,E'begin\n  if tg_op = ''INSERT'' and current_setting(''entrenaop.creating_coach_template'',true) = ''true'' then\n    perform trainer_private.require_authoring_access();\n    new.origin := ''coach''; new.owner_user_id := auth.uid();\n    new.visibility := ''private''; new.status := ''published'';\n    return new;\n  end if;\n  -- El contexto solo lo fija');
  execute definition;
end $migration$;

create function trainer_private.save_trainer_workout(p_operation_id uuid,p_payload jsonb,p_previous_id uuid default null)
returns uuid language plpgsql security definer set search_path='' as $$
declare prior trainer_private.workout_writes; old public.workout_templates; result uuid;
 context_before text:=current_setting('entrenaop.creating_coach_template',true);
begin
  perform trainer_private.require_authoring_access();
  if p_operation_id is null or p_payload is null then raise invalid_parameter_value; end if;
  select * into prior from trainer_private.workout_writes where trainer_id=auth.uid() and operation_id=p_operation_id;
  if found then
    if prior.payload is distinct from p_payload or prior.previous_id is distinct from p_previous_id then
      raise exception 'El reintento no coincide con la sesión original.' using errcode='22023'; end if;
    return prior.template_id;
  end if;
  if p_previous_id is not null then
    select * into old from public.workout_templates where id=p_previous_id
      and origin='coach' and owner_user_id=auth.uid() and status='published' for update;
    if not found then raise exception 'La sesión cambió. Recarga antes de revisarla.' using errcode='40001'; end if;
  end if;
  perform set_config('entrenaop.creating_coach_template','true',true);
  result:=public.create_personal_workout_template(p_payload);
  perform set_config('entrenaop.creating_coach_template',coalesce(context_before,''),true);
  if exists(select 1 from public.workout_blocks b join public.workout_items i on i.block_id=b.id
    join public.exercises e on e.id=i.exercise_id where b.template_id=result and not e.is_public) then
    raise exception 'Selecciona ejercicios del catálogo público.' using errcode='22023'; end if;
  update public.workout_templates set show_in_library=false where id=result;
  if p_previous_id is not null then
    update public.workout_templates set status='archived' where id=old.id;
    update public.workout_templates set family_id=old.family_id,previous_version_id=old.id,version=old.version+1 where id=result;
  end if;
  insert into trainer_private.workout_writes values(auth.uid(),p_operation_id,p_previous_id,p_payload,result);
  return result;
end $$;

create function trainer_private.can_read_coach_template(p_template_id uuid) returns boolean
language sql stable security definer set search_path='' as $$
 select auth.uid() is not null and (
   exists(select 1 from public.workout_templates t where t.id=p_template_id and t.owner_user_id=auth.uid()
     and trainer_private.has_trainer_mfa())
   or exists(select 1 from public.trainer_assignments a join public.scheduled_workouts s on s.id=a.scheduled_id
     join public.trainer_client_relations r on r.id=a.relation_id
     where s.template_id=p_template_id and a.client_id=auth.uid()
       and (s.execution_id is not null or (s.status='planned' and r.ended_at is null)))
   or exists(select 1 from public.workout_executions e where e.template_id=p_template_id and e.user_id=auth.uid())
 );
$$;
revoke all on function trainer_private.can_read_coach_template(uuid) from public,anon,authenticated;
grant execute on function trainer_private.can_read_coach_template(uuid) to authenticated;
create policy trainer_template_read on public.workout_templates for select to authenticated
 using(origin='coach' and trainer_private.can_read_coach_template(id));
create policy trainer_template_read_boundary on public.workout_templates as restrictive for select to authenticated
 using(origin<>'coach' or trainer_private.can_read_coach_template(id));
create policy trainer_template_insert_boundary on public.workout_templates as restrictive for insert to authenticated with check(origin<>'coach');
create policy trainer_template_update_boundary on public.workout_templates as restrictive for update to authenticated using(origin<>'coach') with check(origin<>'coach');
create policy trainer_template_delete_boundary on public.workout_templates as restrictive for delete to authenticated using(origin<>'coach');

create function trainer_private.is_coach_template(p_id uuid) returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.workout_templates where id=p_id and origin='coach');
$$;
revoke all on function trainer_private.is_coach_template(uuid) from public,anon,authenticated;
grant execute on function trainer_private.is_coach_template(uuid) to authenticated;
create policy trainer_schedule_read_boundary on public.scheduled_workouts as restrictive for select to authenticated
 using(source<>'coach' or user_id=(select auth.uid()));
create policy trainer_execution_read_boundary on public.workout_executions as restrictive for select to authenticated
 using(user_id=(select auth.uid()) or not trainer_private.is_coach_template(template_id));

-- Cierra también las escrituras antiguas de ADMIN sobre los hijos de recetas
-- profesionales. Las operaciones privilegiadas anteriores ya exigen origen
-- oficial o personal; el RPC profesional es la única autoría de origen coach.
do $policies$
declare tab text; predicate text;
begin
 foreach tab in array array['workout_blocks','workout_items','workout_sets'] loop
   predicate:=case tab
    when 'workout_blocks' then 'not exists(select 1 from public.workout_templates t where t.id=template_id and t.origin=''coach'')'
    when 'workout_items' then 'not exists(select 1 from public.workout_blocks b join public.workout_templates t on t.id=b.template_id where b.id=block_id and t.origin=''coach'')'
    else 'not exists(select 1 from public.workout_items i join public.workout_blocks b on b.id=i.block_id join public.workout_templates t on t.id=b.template_id where i.id=item_id and t.origin=''coach'')' end;
   execute format('create policy trainer_child_insert_boundary on public.%I as restrictive for insert to authenticated with check(%s)',tab,predicate);
   execute format('create policy trainer_child_update_boundary on public.%I as restrictive for update to authenticated using(%s) with check(%s)',tab,predicate,predicate);
   execute format('create policy trainer_child_delete_boundary on public.%I as restrictive for delete to authenticated using(%s)',tab,predicate);
 end loop;
end $policies$;

create function trainer_private.assign_trainer_workout(p_id uuid,p_relation_id uuid,p_template_id uuid,p_date date,p_note text default null)
returns uuid language plpgsql security definer set search_path='' as $$
declare r public.trainer_client_relations; t public.workout_templates; old public.scheduled_workouts; a public.trainer_assignments;
begin
  if not trainer_private.has_trainer_mfa() then raise insufficient_privilege; end if;
  select * into r from public.trainer_client_relations where id=p_relation_id and trainer_id=auth.uid();
  if not found then raise insufficient_privilege; end if;
  perform pg_advisory_xact_lock(hashtextextended('trainer-client:'||r.client_id::text,0));
  perform trainer_private.require_authoring_access();
  select * into a from public.trainer_assignments where scheduled_id=p_id;
  if found then
    select * into old from public.scheduled_workouts where id=p_id;
    if a.trainer_id=auth.uid() and a.relation_id=p_relation_id and old.template_id=p_template_id
      and old.scheduled_date=p_date and a.note is not distinct from nullif(btrim(p_note),'') then return p_id; end if;
    raise exception 'El reintento no coincide con la pauta original.' using errcode='22023';
  end if;
  select * into r from public.trainer_client_relations where id=p_relation_id and ended_at is null;
  if not found then raise exception 'El servicio ya no está activo.' using errcode='42501'; end if;
  select * into t from public.workout_templates where id=p_template_id and origin='coach'
    and owner_user_id=auth.uid() and status='published' for share;
  if not found then raise insufficient_privilege; end if;
  if p_id is null or p_date is null or char_length(p_note)>500 then raise invalid_parameter_value; end if;
  insert into public.scheduled_workouts(id,user_id,template_id,template_name,template_version,estimated_duration_minutes,scheduled_date,source)
   values(p_id,r.client_id,t.id,t.name,t.version,t.estimated_duration_minutes,p_date,'coach');
  insert into public.trainer_assignments(scheduled_id,relation_id,trainer_id,client_id,note)
   values(p_id,r.id,r.trainer_id,r.client_id,nullif(btrim(p_note),''));
  -- Invalida también snapshots REPEATABLE READ de una baja concurrente: debe
  -- reintentar y ver esta pauta antes de retirar las pendientes de la etapa.
  update public.trainer_access set membership_version=membership_version+1 where trainer_id=auth.uid();
  return p_id;
end $$;

create function trainer_private.list_trainer_workouts(p_before_at timestamptz default null,p_before_id uuid default null)
returns jsonb language plpgsql stable security definer set search_path='' as $$
begin
 if not trainer_private.has_trainer_mfa() then raise insufficient_privilege; end if;
 if (p_before_at is null)<>(p_before_id is null) then raise invalid_parameter_value; end if;
 return (select coalesce(jsonb_agg(to_jsonb(x) order by created_at desc,id desc),'[]') from (
  select id,name,version,created_at from public.workout_templates where owner_user_id=auth.uid() and origin='coach' and status='published'
   and (p_before_at is null or (created_at,id)<(p_before_at,p_before_id)) order by created_at desc,id desc limit 50) x);
end $$;

create function trainer_private.list_trainer_assignments(p_client_id uuid,p_before_at timestamptz default null,p_before_id uuid default null)
returns jsonb language plpgsql stable security definer set search_path='' as $$
begin
 if not trainer_private.has_trainer_mfa() then raise insufficient_privilege; end if;
 if (p_before_at is null)<>(p_before_id is null) then raise invalid_parameter_value; end if;
 if not exists(select 1 from public.trainer_clients where trainer_id=auth.uid() and client_id=p_client_id) then raise insufficient_privilege; end if;
 return (select coalesce(jsonb_agg(to_jsonb(x) order by created_at desc,id desc),'[]') from (
  select s.id,s.template_id,s.template_name,s.template_version,s.scheduled_date,s.status,s.execution_id,a.note,a.created_at,
    e.final_rpe,e.completed_at
  from public.trainer_assignments a join public.scheduled_workouts s on s.id=a.scheduled_id
   left join public.workout_executions e on e.id=s.execution_id
  where a.trainer_id=auth.uid() and a.client_id=p_client_id
   and (p_before_at is null or (a.created_at,s.id)<(p_before_at,p_before_id)) order by a.created_at desc,s.id desc limit 50) x);
end $$;

create function trainer_private.get_trainer_assignment_result(p_id uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare execution uuid;
begin
 if not trainer_private.has_trainer_mfa() then raise insufficient_privilege; end if;
 select s.execution_id into execution from public.trainer_assignments a join public.scheduled_workouts s on s.id=a.scheduled_id
  where a.scheduled_id=p_id and a.trainer_id=auth.uid();
 if not found then raise insufficient_privilege; end if;
 if execution is null then return null; end if;
 return (select to_jsonb(e)||jsonb_build_object(
  'workout_execution_sets',coalesce((select jsonb_agg(to_jsonb(es) order by block_order,item_order,set_order) from public.workout_execution_sets es where es.execution_id=e.id),'[]'),
  'workout_amrap_results',coalesce((select jsonb_agg(to_jsonb(ar) order by block_order) from public.workout_amrap_results ar where ar.execution_id=e.id),'[]'))
  from public.workout_executions e where e.id=execution);
end $$;

create function trainer_private.cancel_trainer_assignment(p_id uuid) returns void
language plpgsql security definer set search_path='' as $$
begin
 if not trainer_private.has_trainer_mfa() or not exists(select 1 from public.trainer_assignments where scheduled_id=p_id and trainer_id=auth.uid()) then raise insufficient_privilege; end if;
 update public.scheduled_workouts set status='cancelled' where id=p_id and status='planned';
 if not found and not exists(select 1 from public.scheduled_workouts where id=p_id and status='cancelled') then
  raise exception 'Solo se puede retirar una pauta pendiente.' using errcode='22023'; end if;
end $$;

create function trainer_private.withdraw_ended_assignments() returns trigger language plpgsql security definer set search_path='' as $$
begin
 if new.ended_at is not null and old.ended_at is null then
  update public.scheduled_workouts s set status='cancelled' from public.trainer_assignments a
   where a.scheduled_id=s.id and a.relation_id=new.id and s.status='planned';
 end if;
 return new;
end $$;
revoke all on function trainer_private.withdraw_ended_assignments() from public,anon,authenticated;
create trigger withdraw_trainer_assignments after update of ended_at on public.trainer_client_relations
 for each row execute function trainer_private.withdraw_ended_assignments();

-- Una ejecución descartada después de la baja no puede reabrir su pauta.
create function trainer_private.guard_coach_schedule_reset() returns trigger language plpgsql security definer set search_path='' as $$
begin
 if new.source='coach' and new.status='planned' and exists(select 1 from public.trainer_assignments a
   join public.trainer_client_relations r on r.id=a.relation_id where a.scheduled_id=new.id and r.ended_at is not null) then
   new.status:='cancelled';
 end if;
 return new;
end $$;
revoke all on function trainer_private.guard_coach_schedule_reset() from public,anon,authenticated;
create trigger guard_coach_schedule_reset before update on public.scheduled_workouts for each row execute function trainer_private.guard_coach_schedule_reset();

-- Conserva el motor de snapshots y sus triggers. El inicio profesional solo
-- pasa desde una cita propia, nunca desde una plantilla suelta o su UUID.
alter function public.start_workout_execution(uuid) set schema trainer_private;
revoke all on function trainer_private.start_workout_execution(uuid) from public,anon,authenticated;
do $migration$
declare definition text; anchor text:='or template.owner_user_id = current_user_id';
begin
 definition:=pg_get_functiondef('trainer_private.start_workout_execution(uuid)'::regprocedure);
 if strpos(definition,anchor)=0 then raise exception 'Revisar inicio compartido.'; end if;
 definition:=replace(definition,anchor,anchor||E'\n      or (template.origin = ''coach'' and trainer_private.can_read_coach_template(template.id))');
 execute definition;
end $migration$;
create function trainer_private.start_unassigned_workout(p_template_id uuid) returns uuid language plpgsql security definer set search_path='' as $$
begin
 if exists(select 1 from public.workout_templates where id=p_template_id and origin='coach') then
  raise exception 'Inicia la pauta desde tu agenda.' using errcode='42501'; end if;
 return trainer_private.start_workout_execution(p_template_id);
end $$;
create function public.start_workout_execution(p_template_id uuid) returns uuid language sql volatile security invoker set search_path='' as $$
 select trainer_private.start_unassigned_workout(p_template_id);
$$;
revoke all on function trainer_private.start_unassigned_workout(uuid) from public,anon,authenticated;
revoke all on function public.start_workout_execution(uuid) from public,anon,authenticated;
grant execute on function trainer_private.start_unassigned_workout(uuid),public.start_workout_execution(uuid) to authenticated;

alter function public.start_scheduled_workout(uuid) set schema trainer_private;
create or replace function trainer_private.start_scheduled_workout(p_scheduled_id uuid) returns uuid
language plpgsql security definer set search_path='' as $$
declare s public.scheduled_workouts; execution uuid;
begin
 if auth.uid() is null then raise insufficient_privilege; end if;
 perform pg_advisory_xact_lock(hashtextextended('trainer-client:'||auth.uid()::text,0));
 select * into s from public.scheduled_workouts where id=p_scheduled_id and user_id=auth.uid()
  and status in ('planned','in_progress') for update;
 if not found then raise insufficient_privilege; end if;
 if s.execution_id is not null then return s.execution_id; end if;
 if s.source='coach' then
  if not exists(select 1 from public.trainer_assignments a join public.trainer_client_relations r on r.id=a.relation_id
    where a.scheduled_id=s.id and a.client_id=auth.uid() and r.ended_at is null) then raise insufficient_privilege; end if;
  execution:=trainer_private.start_workout_execution(s.template_id);
 else execution:=public.start_workout_execution(s.template_id); end if;
 if exists(select 1 from public.scheduled_workouts where execution_id=execution and id<>s.id) then
  raise exception 'La sesión ya tiene otra ejecución en curso.' using errcode='22023'; end if;
 update public.scheduled_workouts set execution_id=execution,status='in_progress' where id=s.id;
 return execution;
end $$;
create function public.start_scheduled_workout(p_scheduled_id uuid) returns uuid language sql volatile security invoker set search_path='' as $$
 select trainer_private.start_scheduled_workout(p_scheduled_id);
$$;
revoke all on function trainer_private.start_scheduled_workout(uuid),public.start_scheduled_workout(uuid) from public,anon,authenticated;
grant execute on function trainer_private.start_scheduled_workout(uuid),public.start_scheduled_workout(uuid) to authenticated;

do $migration$
declare signature text; definition text; anchor text:='and scheduled.preparation_goal_id is null';
begin
 foreach signature in array array['public.reschedule_workout(uuid,date,time)','public.cancel_scheduled_workout(uuid)'] loop
  definition:=pg_get_functiondef(signature::regprocedure);
  if strpos(definition,anchor)=0 then raise exception 'Revisar gestión personal de agenda.'; end if;
  execute replace(definition,anchor,anchor||E'\n    and scheduled.source <> ''coach''');
 end loop;
end $migration$;

-- Cada RPC expuesta delega en una operación autorizada fuera de la API.
create function public.save_trainer_workout(p_operation_id uuid,p_payload jsonb,p_previous_id uuid default null) returns uuid language sql volatile security invoker set search_path='' as $$ select trainer_private.save_trainer_workout(p_operation_id,p_payload,p_previous_id); $$;
create function public.assign_trainer_workout(p_id uuid,p_relation_id uuid,p_template_id uuid,p_date date,p_note text default null) returns uuid language sql volatile security invoker set search_path='' as $$ select trainer_private.assign_trainer_workout(p_id,p_relation_id,p_template_id,p_date,p_note); $$;
create function public.list_trainer_workouts(p_before_at timestamptz default null,p_before_id uuid default null) returns jsonb language sql stable security invoker set search_path='' as $$ select trainer_private.list_trainer_workouts(p_before_at,p_before_id); $$;
create function public.list_trainer_assignments(p_client_id uuid,p_before_at timestamptz default null,p_before_id uuid default null) returns jsonb language sql stable security invoker set search_path='' as $$ select trainer_private.list_trainer_assignments(p_client_id,p_before_at,p_before_id); $$;
create function public.get_trainer_assignment_result(p_id uuid) returns jsonb language sql stable security invoker set search_path='' as $$ select trainer_private.get_trainer_assignment_result(p_id); $$;
create function public.cancel_trainer_assignment(p_id uuid) returns void language sql volatile security invoker set search_path='' as $$ select trainer_private.cancel_trainer_assignment(p_id); $$;
do $grants$
declare schema_name text; signature text;
begin
 foreach schema_name in array array['public','trainer_private'] loop
  foreach signature in array array['save_trainer_workout(uuid,jsonb,uuid)','assign_trainer_workout(uuid,uuid,uuid,date,text)',
    'list_trainer_workouts(timestamptz,uuid)','list_trainer_assignments(uuid,timestamptz,uuid)',
    'get_trainer_assignment_result(uuid)','cancel_trainer_assignment(uuid)'] loop
    execute format('revoke all on function %I.%s from public,anon,authenticated',schema_name,signature);
    execute format('grant execute on function %I.%s to authenticated',schema_name,signature);
  end loop;
 end loop;
end $grants$;
commit;
