begin;

-- «Para mí» reutiliza la relación y las citas existentes sin crear otra identidad.
-- Las tablas siguen sin INSERT/UPDATE de cliente; solo la RPC propia puede darla de alta.
alter table public.trainer_client_relations drop constraint trainer_client_relations_check;
alter table public.trainer_client_relations add constraint trainer_self_relation_active
 check(trainer_id<>client_id or (ended_at is null and ended_by is null));
alter table public.trainer_clients drop constraint trainer_clients_check;
alter table public.trainer_clients add constraint trainer_self_client_unarchived
 check(trainer_id<>client_id or archived_at is null);
alter table public.trainer_assignments drop constraint trainer_assignments_check;

CREATE OR REPLACE FUNCTION trainer_private.get_trainer_access_without_mfa(p_trainer_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v public.trainer_access; used integer;
begin
  if auth.uid() is null or (p_trainer_id is distinct from auth.uid()
    and not public.can_manage_pro_accounts()) then raise insufficient_privilege; end if;
  select * into v from public.trainer_access where trainer_id=p_trainer_id;
  select count(*) into used from public.trainer_client_relations
    where trainer_id=p_trainer_id and trainer_id<>client_id and ended_at is null;
  return jsonb_build_object('trainer_id',p_trainer_id,
    'enabled',coalesce(v.enabled,false),'client_limit',coalesce(v.client_limit,0),
    'valid_until',v.valid_until,'revision',coalesce(v.revision,0),
    'active_clients',used,'over_limit',used>coalesce(v.client_limit,0),
    'effective',coalesce(v.enabled and (v.valid_until is null or v.valid_until>statement_timestamp()),false));
end $function$;


CREATE OR REPLACE FUNCTION trainer_private.admin_set_trainer_access(p_trainer_id uuid, p_client_limit integer, p_enabled boolean, p_expected_revision bigint, p_reason text, p_valid_until timestamp with time zone)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v public.trainer_access; previous jsonb; result jsonb;
begin
  if auth.uid() is null or not public.can_manage_pro_accounts()
    or not coalesce((select manual_access_enabled from public.trainer_access_settings where singleton),false)
    then raise insufficient_privilege; end if;
  if p_trainer_id is null or p_client_limit is null or p_client_limit<1 or p_enabled is null
    or p_expected_revision is null or p_expected_revision<0
    or p_reason is null or char_length(btrim(p_reason)) not between 3 and 500
    or (p_enabled and p_valid_until is not null and p_valid_until<=clock_timestamp()) then
    raise exception 'Revisa el cupo, la vigencia y el motivo.' using errcode='22023';
  end if;
  -- Incluye la primera concesión, cuando aún no existe una fila que bloquear.
  perform pg_advisory_xact_lock(hashtextextended('trainer-access:'||p_trainer_id::text,0));
  select * into v from public.trainer_access where trainer_id=p_trainer_id for update;
  if found then
    if v.revision=p_expected_revision+1 and v.client_limit=p_client_limit and v.enabled=p_enabled
      and v.valid_until is not distinct from p_valid_until and v.updated_by=auth.uid()
      and v.last_reason=btrim(p_reason) then
      return trainer_private.get_trainer_access(p_trainer_id);
    end if;
    if v.revision<>p_expected_revision then
      raise exception 'El acceso ha cambiado; actualiza la ficha.' using errcode='40001';
    end if;
    -- La política comercial de bajada de paquete sigue pendiente: no desactiva alumnos por su cuenta.
    if p_enabled and p_client_limit < (select count(*) from public.trainer_client_relations
      where trainer_id=p_trainer_id and trainer_id<>client_id and ended_at is null) then
      raise exception 'Finaliza los vínculos necesarios antes de reducir el cupo.' using errcode='23514';
    end if;
    previous:=jsonb_build_object('enabled',v.enabled,'client_limit',v.client_limit,
      'valid_until',v.valid_until,'revision',v.revision);
    update public.trainer_access set enabled=p_enabled,client_limit=p_client_limit,
      valid_until=p_valid_until,revision=revision+1,updated_at=clock_timestamp(),
      updated_by=auth.uid(),last_reason=btrim(p_reason) where trainer_id=p_trainer_id;
  else
    if p_expected_revision<>0 then raise exception 'El acceso ha cambiado.' using errcode='40001'; end if;
    insert into public.trainer_access(trainer_id,enabled,client_limit,valid_until,updated_by,last_reason)
      values(p_trainer_id,p_enabled,p_client_limit,p_valid_until,auth.uid(),btrim(p_reason));
  end if;
  result:=trainer_private.get_trainer_access(p_trainer_id);
  insert into public.trainer_access_audit(trainer_id,actor_id,revision,previous_access,new_access,reason)
    values(p_trainer_id,auth.uid(),(result->>'revision')::bigint,previous,result,btrim(p_reason));
  return result;
end $function$;


CREATE OR REPLACE FUNCTION trainer_private.accept_trainer_invitation(p_secret text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare invite public.trainer_invitations; v public.trainer_access; relation uuid; used integer;
begin
  if auth.uid() is null or coalesce((auth.jwt()->>'is_anonymous')::boolean,false) then raise insufficient_privilege; end if;
  if p_secret is null or p_secret !~ '^[0-9a-f]{64}$' then
    raise exception 'Invitación no disponible.' using errcode='22023'; end if;
  select * into invite from public.trainer_invitations where secret_hash=extensions.digest(p_secret,'sha256');
  if not found then raise exception 'Invitación no disponible.' using errcode='22023'; end if;
  if invite.trainer_id=auth.uid() then raise exception 'No puedes ser tu propio preparador.' using errcode='22023'; end if;
  -- Orden único: alumno -> acceso del preparador -> invitación -> vínculo.
  perform pg_advisory_xact_lock(hashtextextended('trainer-client:'||auth.uid()::text,0));
  select * into v from public.trainer_access where trainer_id=invite.trainer_id for update;
  select * into invite from public.trainer_invitations where id=invite.id for update;
  if invite.accepted_at is not null then
    if invite.accepted_by=auth.uid() and exists(select 1 from public.trainer_client_relations
      where id=invite.relation_id and client_id=auth.uid() and ended_at is null) then return invite.relation_id; end if;
    raise exception 'Invitación no disponible.' using errcode='22023';
  end if;
  if v.trainer_id is null or not v.enabled or (v.valid_until is not null and v.valid_until<=clock_timestamp())
    or invite.revoked_at is not null or invite.expires_at<=clock_timestamp() then
    raise exception 'Invitación no disponible.' using errcode='22023'; end if;
  if exists(select 1 from public.trainer_client_relations where client_id=auth.uid() and trainer_id=invite.trainer_id and ended_at is null) then
    raise exception 'Ya estás vinculado a este preparador.' using errcode='23505'; end if;
  select count(*) into used from public.trainer_client_relations
    where trainer_id=invite.trainer_id and trainer_id<>client_id and ended_at is null;
  if used>=v.client_limit then raise exception 'El preparador ha completado su cupo.' using errcode='23514'; end if;
  -- Fuerza conflicto ante snapshots obsoletos en REPEATABLE READ, además del bloqueo del cupo.
  update public.trainer_access set membership_version=membership_version+1 where trainer_id=invite.trainer_id;
  insert into public.trainer_client_relations(trainer_id,client_id)
    values(invite.trainer_id,auth.uid()) returning id into relation;
  update public.trainer_invitations set accepted_at=clock_timestamp(),accepted_by=auth.uid(),relation_id=relation
    where id=invite.id;
  return relation;
end $function$;


CREATE OR REPLACE FUNCTION trainer_private.list_managed_trainers(p_after_id uuid DEFAULT NULL::uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
begin
  if auth.uid() is null or not public.can_manage_pro_accounts() then raise insufficient_privilege; end if;
  return coalesce((select jsonb_agg(to_jsonb(items) order by trainer_id) from (
    select a.trainer_id,p.full_name as name,u.email,a.enabled,a.client_limit,a.valid_until,
      (select count(*) from public.trainer_client_relations r
        where r.trainer_id=a.trainer_id and r.trainer_id<>r.client_id and r.ended_at is null) as active_clients
    from public.trainer_access a
    join public.profiles p on p.id=a.trainer_id join auth.users u on u.id=a.trainer_id
    where p_after_id is null or a.trainer_id>p_after_id
    order by a.trainer_id limit 50
  ) items),'[]'::jsonb);
end $function$;


CREATE OR REPLACE FUNCTION trainer_private.guard_relation_membership()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare limit_count integer;
begin
 if tg_op='UPDATE' then
  if new.client_id is distinct from old.client_id or new.trainer_id is distinct from old.trainer_id then
   raise exception 'La identidad del vínculo no se puede sustituir.' using errcode='23514'; end if;
  if new.ended_at is not distinct from old.ended_at then return new; end if;
 end if;
 -- La vinculación personal no es una admisión comercial ni un destinatario
 -- del consentimiento para compartir calendario. Solo la crea ensure_self_client.
 if new.trainer_id=new.client_id then
  if new.ended_at is not null or new.ended_by is not null then
   raise exception 'La planificación personal no se desactiva como un alumno.' using errcode='22023'; end if;
  return new;
 end if;
 perform pg_advisory_xact_lock(hashtextextended('trainer-client:'||new.client_id::text,0));
 -- Mismo orden perfil→contador que el resto de escritores del calendario.
 perform 1 from public.profiles where id=new.client_id for key share;
 if not found then raise foreign_key_violation; end if;
 -- Compartido también entre preparadores distintos: en REPEATABLE READ fuerza
 -- 40001 cuando cambió el conjunto de vínculos después de tomar el snapshot.
 insert into trainer_private.calendar_revisions(user_id,revision) values(new.client_id,1)
  on conflict(user_id) do update set revision=trainer_private.calendar_revisions.revision+1;
 if new.ended_at is null then
  if exists(select 1 from public.trainer_client_relations r where r.client_id=new.client_id
    and r.trainer_id=new.trainer_id and r.trainer_id<>r.client_id and r.ended_at is null and r.id<>new.id) then
   raise exception 'Ya estás vinculado a este preparador.' using errcode='23505'; end if;
  select max_active_trainers_per_client into strict limit_count
   from public.trainer_access_settings where singleton;
  if (select count(*) from public.trainer_client_relations r where r.client_id=new.client_id
      and r.trainer_id<>r.client_id and r.ended_at is null and r.id<>new.id)>=limit_count then
   raise exception 'Has alcanzado el máximo de preparadores activos.' using errcode='23514'; end if;
 elsif not exists(select 1 from public.trainer_client_relations r where r.client_id=new.client_id
     and r.trainer_id<>r.client_id and r.ended_at is null and r.id<>new.id) then
  -- Una futura etapa no hereda una compartición que quedó sin destinatarios.
  update trainer_private.calendar_sharing set enabled=false,revision=revision+1,
   updated_at=clock_timestamp() where client_id=new.client_id and enabled;
 end if;
 return new;
end $function$;


CREATE OR REPLACE FUNCTION trainer_private.list_my_trainer_relations_without_mfa(p_as_trainer boolean, p_ended boolean DEFAULT false, p_before_at timestamp with time zone DEFAULT NULL::timestamp with time zone, p_before_id uuid DEFAULT NULL::uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare result jsonb;
begin
  if auth.uid() is null or coalesce((auth.jwt()->>'is_anonymous')::boolean,false) then
    raise insufficient_privilege;
  end if;
  if p_as_trainer is null or p_ended is null or
    ((p_before_at is null) <> (p_before_id is null)) then
    raise exception 'Paginación inválida.' using errcode='22023';
  end if;
  select coalesce(jsonb_agg(to_jsonb(items) order by accepted_at desc,id desc),'[]'::jsonb)
    into result from (
      select r.id,r.accepted_at,r.ended_at,(r.trainer_id=r.client_id) as is_self,
        case when p_as_trainer then r.client_id else r.trainer_id end as person_id,
        case when r.trainer_id=r.client_id then 'Para mí' else coalesce(nullif(btrim(p.full_name),''),'Usuario de EntrenaOP') end as person_name
      from public.trainer_client_relations r
      join public.profiles p on p.id=case when p_as_trainer then r.client_id else r.trainer_id end
      where (case when p_as_trainer then r.trainer_id else r.client_id end)=auth.uid()
        and (p_as_trainer or r.trainer_id<>r.client_id)
        and (r.ended_at is not null)=p_ended
        and (p_before_at is null or (r.accepted_at,r.id)<(p_before_at,p_before_id))
      order by r.accepted_at desc,r.id desc limit 50
    ) items;
  return result;
end $function$;


CREATE OR REPLACE FUNCTION trainer_private.list_trainer_clients(p_state text DEFAULT 'active'::text, p_before_at timestamp with time zone DEFAULT NULL::timestamp with time zone, p_before_client_id uuid DEFAULT NULL::uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
begin
  if not trainer_private.has_trainer_mfa() then raise insufficient_privilege; end if;
  if p_state is null or p_state not in ('active','inactive','archived')
    or ((p_before_at is null)<>(p_before_client_id is null)) then
    raise exception 'Estado o paginación inválidos.' using errcode='22023'; end if;
  return (select coalesce(jsonb_agg(to_jsonb(items) order by updated_at desc,person_id desc),'[]'::jsonb) from (
    select c.client_id as person_id,c.display_name as person_name,c.created_at,c.updated_at,c.archived_at,
      latest.accepted_at,latest.ended_at,
      active.id as active_relation_id,
      (select count(*) from public.trainer_client_relations r
        where r.trainer_id=c.trainer_id and r.client_id=c.client_id) as episode_count
    from public.trainer_clients c
    join lateral(select r.accepted_at,r.ended_at from public.trainer_client_relations r
      where r.trainer_id=c.trainer_id and r.client_id=c.client_id
      order by r.accepted_at desc,r.id desc limit 1) latest on true
    left join public.trainer_client_relations active on active.trainer_id=c.trainer_id
      and active.client_id=c.client_id and active.ended_at is null
    where c.trainer_id=auth.uid() and c.trainer_id<>c.client_id
      and case p_state when 'archived' then c.archived_at is not null
        when 'active' then c.archived_at is null and active.id is not null
        else c.archived_at is null and active.id is null end
      and (p_before_at is null or (c.updated_at,c.client_id)<(p_before_at,p_before_client_id))
    order by c.updated_at desc,c.client_id desc limit 50
  ) items);
end $function$;


CREATE OR REPLACE FUNCTION trainer_private.get_trainer_client_workspace(p_client_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare client jsonb; notes jsonb; relations jsonb; episodes bigint;
begin
 perform trainer_private.require_client_portfolio(p_client_id);
 select to_jsonb(x) into client from (
  select c.client_id as person_id,c.display_name as person_name,c.created_at,c.updated_at,c.archived_at,
   latest.accepted_at,latest.ended_at,active.id as active_relation_id,
   (select count(*) from public.trainer_client_relations r where r.trainer_id=c.trainer_id and r.client_id=c.client_id) as episode_count
  from public.trainer_clients c
  join lateral(select r.accepted_at,r.ended_at from public.trainer_client_relations r
   where r.trainer_id=c.trainer_id and r.client_id=c.client_id order by r.accepted_at desc,r.id desc limit 1) latest on true
  left join public.trainer_client_relations active on active.trainer_id=c.trainer_id and active.client_id=c.client_id and active.ended_at is null
  where c.trainer_id=auth.uid() and c.client_id=p_client_id) x;
 select jsonb_build_object('revision',v.revision,'notes',v.notes,'goal',v.goal,'created_at',v.created_at) into notes
  from trainer_private.client_note_versions v where trainer_id=auth.uid() and client_id=p_client_id order by revision desc limit 1;
 select count(*) into episodes from public.trainer_client_relations where trainer_id=auth.uid() and client_id=p_client_id;
 select coalesce(jsonb_agg(to_jsonb(x) order by accepted_at desc,id desc),'[]') into relations from (
  select id,accepted_at,ended_at from public.trainer_client_relations where trainer_id=auth.uid() and client_id=p_client_id
  order by accepted_at desc,id desc limit 50) x;
 return jsonb_build_object('client',client||jsonb_build_object('is_self',p_client_id=auth.uid())||
    case when p_client_id=auth.uid() then jsonb_build_object('person_name','Para mí') else '{}'::jsonb end,'relations',relations,'relations_complete',episodes<=50,
  'notes',coalesce(notes,'{"revision":0,"notes":"","goal":""}'::jsonb),
  'can_edit_notes',exists(select 1 from public.trainer_access where trainer_id=auth.uid() and enabled
   and (valid_until is null or valid_until>statement_timestamp())));
end $function$;


CREATE OR REPLACE FUNCTION trainer_private.my_calendar_sharing(p_expected_owner uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v trainer_private.calendar_sharing;
begin
 if auth.uid() is null or auth.uid() is distinct from p_expected_owner
  or coalesce((auth.jwt()->>'is_anonymous')::boolean,false) then raise insufficient_privilege; end if;
 select * into v from trainer_private.calendar_sharing where client_id=auth.uid();
 return jsonb_build_object('enabled',coalesce(v.enabled,false),'revision',coalesce(v.revision,0),
  'active_trainers',(select count(*) from public.trainer_client_relations where client_id=auth.uid() and trainer_id<>client_id and ended_at is null),
  'max_active_trainers',(select max_active_trainers_per_client from public.trainer_access_settings where singleton));
end $function$;


CREATE OR REPLACE FUNCTION trainer_private.set_my_calendar_sharing(p_expected_owner uuid, p_enabled boolean, p_expected_revision bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v trainer_private.calendar_sharing;
begin
 perform trainer_private.my_calendar_sharing(p_expected_owner);
 if p_enabled is null or p_expected_revision is null or p_expected_revision<0 then raise invalid_parameter_value; end if;
 perform pg_advisory_xact_lock(hashtextextended('trainer-client:'||auth.uid()::text,0));
 perform 1 from public.profiles where id=auth.uid() for key share;
 if not found then raise insufficient_privilege; end if;
 insert into trainer_private.calendar_revisions(user_id,revision) values(auth.uid(),1)
    on conflict(user_id) do update set revision=trainer_private.calendar_revisions.revision+1;
   select * into v from trainer_private.calendar_sharing where client_id=auth.uid() for update;
 if v.revision=p_expected_revision+1 and v.enabled=p_enabled then
  return trainer_private.my_calendar_sharing(p_expected_owner); end if;
 if coalesce(v.revision,0)<>p_expected_revision then
  raise exception 'La compartición ha cambiado; actualiza antes de continuar.' using errcode='40001'; end if;
 if p_enabled and not exists(select 1 from public.trainer_client_relations where client_id=auth.uid() and trainer_id<>client_id and ended_at is null) then
  raise exception 'Necesitas un preparador activo para compartir tu calendario.' using errcode='23514'; end if;
 if coalesce(v.enabled,false)=p_enabled then return trainer_private.my_calendar_sharing(p_expected_owner); end if;
 insert into trainer_private.calendar_sharing(client_id,enabled) values(auth.uid(),p_enabled)
  on conflict(client_id) do update set enabled=excluded.enabled,
   revision=trainer_private.calendar_sharing.revision+1,updated_at=clock_timestamp();
 return trainer_private.my_calendar_sharing(p_expected_owner);
end $function$;


CREATE OR REPLACE FUNCTION trainer_private.shared_calendar_access(p_expected_owner uuid, p_client_id uuid)
 RETURNS boolean
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
begin
 if auth.uid() is distinct from p_expected_owner or not trainer_private.has_trainer_mfa()
  or not exists(select 1 from public.trainer_access where trainer_id=auth.uid() and enabled
    and (valid_until is null or valid_until>statement_timestamp()))
  or not exists(select 1 from public.trainer_client_relations where trainer_id=auth.uid()
    and client_id=p_client_id and ended_at is null) then raise insufficient_privilege; end if;
 return p_client_id=auth.uid() or coalesce((select enabled from trainer_private.calendar_sharing where client_id=p_client_id),false);
end $function$;


CREATE OR REPLACE FUNCTION trainer_private.shared_client_calendar(p_expected_owner uuid, p_client_id uuid, p_from date, p_to date, p_after_date date DEFAULT NULL::date, p_after_id uuid DEFAULT NULL::uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
begin
 if not trainer_private.shared_calendar_access(p_expected_owner,p_client_id) then
  return jsonb_build_object('shared',false,'items','[]'::jsonb,'has_more',false,'coaches','[]'::jsonb); end if;
 if p_from is null or p_to is null or p_to<p_from or p_to-p_from>61
  or (p_after_date is null)<>(p_after_id is null) then raise invalid_parameter_value; end if;
 return (with page as (
  select s.id,s.scheduled_date,s.scheduled_time,s.template_name,s.estimated_duration_minutes,
   s.source,s.status,a.trainer_id=auth.uid() as is_own,
   case when s.source='coach' then coalesce(nullif(btrim(p.full_name),''),'Preparador') end as trainer_name,
   case when s.source='coach' then r.ended_at is null and r.id is not null else true end as relation_active,
   exists(select 1 from public.workout_blocks b where b.template_id=s.template_id and b.format='running') as is_running
  from public.scheduled_workouts s
  left join public.trainer_assignments a on a.scheduled_id=s.id and a.client_id=p_client_id
  left join public.trainer_client_relations r on r.id=a.relation_id
  left join public.profiles p on p.id=a.trainer_id
  where s.user_id=p_client_id and s.scheduled_date between p_from and p_to
   and (p_after_date is null or (s.scheduled_date,s.id)>(p_after_date,p_after_id))
  order by s.scheduled_date,s.id limit 51
 ), visible as (select * from page order by scheduled_date,id limit 50)
 select jsonb_build_object('shared',true,
  'items',coalesce((select jsonb_agg(to_jsonb(v) order by scheduled_date,id) from visible v),'[]'::jsonb),
  'has_more',(select count(*)>50 from page),
  'coaches',coalesce((select jsonb_agg(jsonb_build_object('name',coalesce(nullif(btrim(p.full_name),''),'Preparador'),
     'is_you',r.trainer_id=auth.uid()) order by r.accepted_at,r.id)
    from public.trainer_client_relations r join public.profiles p on p.id=r.trainer_id
    where r.client_id=p_client_id and r.trainer_id<>r.client_id and r.ended_at is null),'[]'::jsonb)));
end $function$;


CREATE OR REPLACE FUNCTION trainer_private.conversation_context(p_relation_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare r public.trainer_client_relations; counterpart uuid; can_send boolean;
begin
 select * into r from public.trainer_client_relations where id=p_relation_id and trainer_id<>client_id and (trainer_id=auth.uid() or client_id=auth.uid());
 if not found or (r.trainer_id=auth.uid() and not trainer_private.has_trainer_mfa()) then raise insufficient_privilege; end if;
 counterpart:=case when r.trainer_id=auth.uid() then r.client_id else r.trainer_id end;
 can_send:=r.ended_at is null and exists(select 1 from public.trainer_access where trainer_id=r.trainer_id
  and enabled and (valid_until is null or valid_until>statement_timestamp()));
 return jsonb_build_object('name',coalesce((select nullif(btrim(full_name),'') from public.profiles where id=counterpart),'Preparación acompañada'),
  'can_send',can_send);
end $function$;


CREATE OR REPLACE FUNCTION trainer_private.send_message(p_id uuid, p_relation_id uuid, p_body text, p_assignment_id uuid DEFAULT NULL::uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare r public.trainer_client_relations; prior trainer_private.messages;
begin
 if auth.uid() is null then raise insufficient_privilege; end if;
 select * into r from public.trainer_client_relations where id=p_relation_id and trainer_id<>client_id and (trainer_id=auth.uid() or client_id=auth.uid());
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
end $function$;


CREATE OR REPLACE FUNCTION trainer_private.list_messages(p_relation_id uuid, p_before_at timestamp with time zone DEFAULT NULL::timestamp with time zone, p_before_id uuid DEFAULT NULL::uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare r public.trainer_client_relations;
begin
 select * into r from public.trainer_client_relations where id=p_relation_id and trainer_id<>client_id and (trainer_id=auth.uid() or client_id=auth.uid());
 if not found or (r.trainer_id=auth.uid() and not trainer_private.has_trainer_mfa()) then raise insufficient_privilege; end if;
 if (p_before_at is null)<>(p_before_id is null) then raise invalid_parameter_value; end if;
 return (select coalesce(jsonb_agg(to_jsonb(x) order by created_at desc,id desc),'[]') from (
  select m.id,m.assignment_id,m.sender_id,m.body,m.created_at from trainer_private.messages m where m.relation_id=r.id
   and (p_before_at is null or (m.created_at,m.id)<(p_before_at,p_before_id)) order by m.created_at desc,m.id desc limit 50
 ) x);
end $function$;


CREATE OR REPLACE FUNCTION trainer_private.capture_student_notice()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare pupil uuid; relation uuid; event_kind text; source uuid; revision bigint:=0;
begin
 if tg_table_name='messages' then
  select r.client_id,r.id into pupil,relation from public.trainer_client_relations r
   where r.id=new.relation_id and r.trainer_id=new.sender_id;
  event_kind:='message'; source:=new.id;
 elsif tg_table_name='form_assignments' then
  pupil:=new.client_id; relation:=new.relation_id; event_kind:='form'; source:=new.id;
 elsif tg_table_name='assessment_deliveries' then
  pupil:=new.client_id; relation:=new.relation_id; event_kind:='assessment'; source:=new.id;
 elsif tg_table_name='video_feedback' then
  select a.created_by,t.relation_id into pupil,relation from public.exercise_video_assets a
   join public.trainer_assignments t on t.scheduled_id=a.assignment_id
   where a.id=new.asset_id and a.scope='client_technique' and t.client_id=a.created_by;
  event_kind:='techniqueFeedback'; source:=new.id;
 elsif tg_table_name='trainer_assignments' then
  if tg_op='UPDATE' and old.planning_revision=new.planning_revision then return new; end if;
  pupil:=new.client_id; relation:=new.relation_id; event_kind:='assignment';
  source:=new.scheduled_id; revision:=new.planning_revision;
 end if;
 if pupil is not null and not exists(select 1 from public.trainer_client_relations r
   where r.id=relation and r.trainer_id=r.client_id) then
  insert into trainer_private.student_notices(owner_id,relation_id,kind,source_id,source_revision)
   values(pupil,relation,event_kind,source,revision) on conflict do nothing;
 end if;
 return new;
end $function$;

-- La agenda del deportista identifica la autoasignación sin inventar otro preparador.
create or replace function trainer_private.my_schedule_coaches(p_expected_owner uuid,p_ids uuid[]) returns jsonb
language plpgsql stable security definer set search_path='' as $$
begin
 perform trainer_private.my_calendar_sharing(p_expected_owner);
 if p_ids is null or cardinality(p_ids)>200 or array_position(p_ids,null) is not null then raise invalid_parameter_value; end if;
 return coalesce((select jsonb_agg(jsonb_build_object('id',s.id,
   'is_self',a.trainer_id=a.client_id,
   'trainer_name',coalesce(nullif(btrim(p.full_name),''),'Preparador')) order by s.id)
  from public.scheduled_workouts s join public.trainer_assignments a on a.scheduled_id=s.id
  join public.profiles p on p.id=a.trainer_id
  where s.id=any(p_ids) and s.user_id=auth.uid() and a.client_id=auth.uid() and s.source='coach'),'[]'::jsonb);
end $$;

create function trainer_private.ensure_self_client(p_expected_owner uuid) returns uuid
language plpgsql security definer set search_path='' as $$
declare result uuid;
begin
 if auth.uid() is null or auth.uid() is distinct from p_expected_owner
  or not trainer_private.has_trainer_mfa() then raise insufficient_privilege; end if;
 -- Mismo orden que asignar y aceptar: deportista → acceso → relación.
 perform pg_advisory_xact_lock(hashtextextended('trainer-client:'||auth.uid()::text,0));
 select id into result from public.trainer_client_relations
  where trainer_id=auth.uid() and client_id=auth.uid() and ended_at is null;
 if found then return result; end if;
 perform trainer_private.require_authoring_access();
 -- La versión del acceso invalida la creación concurrente bajo REPEATABLE READ.
 update public.trainer_access set membership_version=membership_version+1 where trainer_id=auth.uid();
 insert into public.trainer_client_relations(trainer_id,client_id)
  values(auth.uid(),auth.uid()) returning id into result;
 return result;
end $$;
revoke all on function trainer_private.ensure_self_client(uuid) from public,anon,authenticated;
grant execute on function trainer_private.ensure_self_client(uuid) to authenticated;
create function public.ensure_trainer_self_client(p_expected_owner uuid) returns uuid
language sql security invoker set search_path='' as $$
 select trainer_private.ensure_self_client(p_expected_owner);
$$;
revoke all on function public.ensure_trainer_self_client(uuid) from public,anon,authenticated;
grant execute on function public.ensure_trainer_self_client(uuid) to authenticated;

commit;
