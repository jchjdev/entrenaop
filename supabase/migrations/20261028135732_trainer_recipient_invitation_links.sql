begin;
alter table public.trainer_invitations add column recipient_email text
 check(recipient_email is null or (recipient_email=lower(btrim(recipient_email)) and length(recipient_email)<=254
 and recipient_email ~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$' and recipient_email !~ '[[:cntrl:]]'));
grant select(recipient_email) on public.trainer_invitations to authenticated;
-- La autoridad es el email confirmado de Auth, nunca metadata editable o un
-- correo enviado por Flutter. Las invitaciones anteriores siguen siendo válidas.
create function trainer_private.require_invitation_recipient(p_id uuid) returns void
language plpgsql stable security definer set search_path='' as $$
declare recipient text;
begin
 select recipient_email into recipient from public.trainer_invitations where id=p_id;
 if not found then raise invalid_parameter_value;end if;
 if recipient is null then return;end if;
 if not exists(select 1 from auth.users where id=auth.uid() and lower(btrim(email))=recipient and email_confirmed_at is not null and not coalesce(is_anonymous,false)) then
  raise exception 'Invitación no disponible. Revisa el correo de tu cuenta o pide un enlace nuevo.' using errcode='22023';
 end if;
end $$;
revoke all on function trainer_private.require_invitation_recipient(uuid) from public,anon,authenticated,service_role;
create function trainer_private.create_recipient_invitation(p_expected_owner uuid,p_id uuid,p_secret text,p_recipient_email text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare v public.trainer_access;invite public.trainer_invitations;hashed bytea;recipient text:=lower(btrim(p_recipient_email));
begin
 perform trainer_private.program_work_identity(p_expected_owner);
 if recipient is null or length(recipient)>254 or recipient !~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$' or recipient ~ '[[:cntrl:]]' then raise invalid_parameter_value;end if;
 if p_id is null or p_secret is null or p_secret !~ '^[0-9a-f]{64}$' then raise invalid_parameter_value;end if;
 hashed:=extensions.digest(p_secret,'sha256');
 select * into v from public.trainer_access where trainer_id=auth.uid() for update;
 if not found or not v.enabled or (v.valid_until is not null and v.valid_until<=clock_timestamp()) then raise insufficient_privilege;end if;
 select * into invite from public.trainer_invitations where id=p_id for update;
 if found then
  if invite.trainer_id<>auth.uid() or invite.secret_hash<>hashed then raise insufficient_privilege;end if;
  if invite.recipient_email is distinct from recipient then raise exception 'El destinatario de esta invitación no puede cambiarse. Crea otra.' using errcode='22023';end if;
 else
  insert into public.trainer_invitations(id,trainer_id,secret_hash,expires_at,recipient_email)
   values(p_id,auth.uid(),hashed,clock_timestamp()+interval '7 days',recipient) returning * into invite;
 end if;
 return jsonb_build_object('id',invite.id,'trainer_id',invite.trainer_id,'recipient_email',invite.recipient_email,
  'expires_at',invite.expires_at,'revoked_at',invite.revoked_at,'accepted_at',invite.accepted_at);
end $$;
CREATE OR REPLACE FUNCTION trainer_private.preview_trainer_invitation(p_secret text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare invite public.trainer_invitations; v public.trainer_access; name text;
begin
  if auth.uid() is null or coalesce((auth.jwt()->>'is_anonymous')::boolean,false) then raise insufficient_privilege; end if;
  if p_secret is null or p_secret !~ '^[0-9a-f]{64}$' then
    raise exception 'Invitación no disponible.' using errcode='22023'; end if;
  select * into invite from public.trainer_invitations where secret_hash=extensions.digest(p_secret,'sha256');
  if not found or invite.revoked_at is not null or invite.accepted_at is not null
    or invite.expires_at<=statement_timestamp() then
    raise exception 'Invitación no disponible.' using errcode='22023'; end if;
  perform trainer_private.require_invitation_recipient(invite.id);
  select * into v from public.trainer_access where trainer_id=invite.trainer_id;
  if not found or not v.enabled or (v.valid_until is not null and v.valid_until<=statement_timestamp()) then
    raise exception 'Invitación no disponible.' using errcode='22023'; end if;
  select full_name into name from public.profiles where id=invite.trainer_id;
  -- Solo quien posee el código puede conocer a quién solicita vincularse.
  return jsonb_build_object('id',invite.id,'trainer_id',invite.trainer_id,
    'trainer_name',name,'expires_at',invite.expires_at);
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
  if invite.accepted_at is null then perform trainer_private.require_invitation_recipient(invite.id);end if;
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

create function public.create_trainer_invitation_for_email(p_expected_owner uuid,p_id uuid,p_secret text,p_recipient_email text) returns jsonb
language sql security invoker set search_path='' as $$select trainer_private.create_recipient_invitation(p_expected_owner,p_id,p_secret,p_recipient_email)$$;
revoke all on function trainer_private.create_recipient_invitation(uuid,uuid,text,text),public.create_trainer_invitation_for_email(uuid,uuid,text,text) from public,anon,authenticated,service_role;
grant execute on function trainer_private.create_recipient_invitation(uuid,uuid,text,text),public.create_trainer_invitation_for_email(uuid,uuid,text,text) to authenticated;
commit;
