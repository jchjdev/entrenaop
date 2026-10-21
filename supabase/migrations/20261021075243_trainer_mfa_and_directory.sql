-- El panel profesional exige MFA también fuera de Flutter.
create function trainer_private.has_trainer_mfa()
returns boolean language sql stable security definer set search_path='' as $$
  select auth.uid() is not null
    and not coalesce((auth.jwt()->>'is_anonymous')::boolean,false)
    and coalesce(auth.jwt()->>'aal'='aal2',false)
    and exists(select 1 from auth.mfa_factors
      where user_id=auth.uid() and status='verified' and factor_type='totp');
$$;
revoke all on function trainer_private.has_trainer_mfa() from public,anon,authenticated;
grant execute on function trainer_private.has_trainer_mfa() to authenticated;

create function public.get_trainer_security_status()
returns boolean language sql stable security invoker set search_path='' as $$
  select trainer_private.has_trainer_mfa();
$$;
revoke all on function public.get_trainer_security_status() from public,anon,authenticated;
grant execute on function public.get_trainer_security_status() to authenticated;

-- Se protegen las entradas existentes sin cambiar sus contratos ni bloqueos.
-- La implementación anterior pasa a interna y pierde ejecución de cliente.
alter function trainer_private.get_trainer_access(uuid) rename to get_trainer_access_without_mfa;
revoke all on function trainer_private.get_trainer_access_without_mfa(uuid) from public,anon,authenticated;
create function trainer_private.get_trainer_access(p_trainer_id uuid)
returns jsonb language plpgsql volatile security definer set search_path='' as $$
begin
  if p_trainer_id is not distinct from auth.uid() and not trainer_private.has_trainer_mfa() then raise insufficient_privilege; end if;
  return trainer_private.get_trainer_access_without_mfa(p_trainer_id);
end $$;
revoke all on function trainer_private.get_trainer_access(uuid) from public,anon,authenticated;
grant execute on function trainer_private.get_trainer_access(uuid) to authenticated;
alter function trainer_private.create_trainer_invitation(uuid,text) rename to create_trainer_invitation_without_mfa;
revoke all on function trainer_private.create_trainer_invitation_without_mfa(uuid,text) from public,anon,authenticated;
create function trainer_private.create_trainer_invitation(p_id uuid,p_secret text)
returns jsonb language plpgsql volatile security definer set search_path='' as $$
begin
  if not trainer_private.has_trainer_mfa() then raise insufficient_privilege; end if;
  return trainer_private.create_trainer_invitation_without_mfa(p_id,p_secret);
end $$;
revoke all on function trainer_private.create_trainer_invitation(uuid,text) from public,anon,authenticated;
grant execute on function trainer_private.create_trainer_invitation(uuid,text) to authenticated;
alter function trainer_private.cancel_trainer_invitation(uuid) rename to cancel_trainer_invitation_without_mfa;
revoke all on function trainer_private.cancel_trainer_invitation_without_mfa(uuid) from public,anon,authenticated;
create function trainer_private.cancel_trainer_invitation(p_id uuid)
returns void language plpgsql volatile security definer set search_path='' as $$
begin
  if not trainer_private.has_trainer_mfa() then raise insufficient_privilege; end if;
  perform trainer_private.cancel_trainer_invitation_without_mfa(p_id);
end $$;
revoke all on function trainer_private.cancel_trainer_invitation(uuid) from public,anon,authenticated;
grant execute on function trainer_private.cancel_trainer_invitation(uuid) to authenticated;
alter function trainer_private.list_my_trainer_relations(boolean,boolean,timestamptz,uuid) rename to list_my_trainer_relations_without_mfa;
revoke all on function trainer_private.list_my_trainer_relations_without_mfa(boolean,boolean,timestamptz,uuid) from public,anon,authenticated;
create function trainer_private.list_my_trainer_relations(p_as_trainer boolean,p_ended boolean default false,p_before_at timestamptz default null,p_before_id uuid default null)
returns jsonb language plpgsql volatile security definer set search_path='' as $$
begin
  if p_as_trainer and not trainer_private.has_trainer_mfa() then raise insufficient_privilege; end if;
  return trainer_private.list_my_trainer_relations_without_mfa(p_as_trainer,p_ended,p_before_at,p_before_id);
end $$;
revoke all on function trainer_private.list_my_trainer_relations(boolean,boolean,timestamptz,uuid) from public,anon,authenticated;
grant execute on function trainer_private.list_my_trainer_relations(boolean,boolean,timestamptz,uuid) to authenticated;
alter function trainer_private.end_trainer_relation(uuid) rename to end_trainer_relation_without_mfa;
revoke all on function trainer_private.end_trainer_relation_without_mfa(uuid) from public,anon,authenticated;
create function trainer_private.end_trainer_relation(p_id uuid)
returns void language plpgsql volatile security definer set search_path='' as $$
begin
  if exists(select 1 from public.trainer_client_relations where id=p_id and trainer_id=auth.uid()) and not trainer_private.has_trainer_mfa() then raise insufficient_privilege; end if;
  perform trainer_private.end_trainer_relation_without_mfa(p_id);
end $$;
revoke all on function trainer_private.end_trainer_relation(uuid) from public,anon,authenticated;
grant execute on function trainer_private.end_trainer_relation(uuid) to authenticated;

alter policy trainer_access_read on public.trainer_access
  using ((trainer_id=(select auth.uid()) and (select trainer_private.has_trainer_mfa()))
    or (select public.can_manage_pro_accounts()));
alter policy trainer_client_participant on public.trainer_client_relations
  using ((client_id=(select auth.uid())) or
    (trainer_id=(select auth.uid()) and (select trainer_private.has_trainer_mfa())));
alter policy trainer_invitation_owner on public.trainer_invitations
  using (trainer_id=(select auth.uid()) and (select trainer_private.has_trainer_mfa()));

create function trainer_private.list_managed_trainers(p_after_id uuid default null)
returns jsonb language plpgsql stable security definer set search_path='' as $$
begin
  if auth.uid() is null or not public.can_manage_pro_accounts() then raise insufficient_privilege; end if;
  return coalesce((select jsonb_agg(to_jsonb(items) order by trainer_id) from (
    select a.trainer_id,p.full_name as name,u.email,a.enabled,a.client_limit,a.valid_until,
      (select count(*) from public.trainer_client_relations r
        where r.trainer_id=a.trainer_id and r.ended_at is null) as active_clients
    from public.trainer_access a
    join public.profiles p on p.id=a.trainer_id join auth.users u on u.id=a.trainer_id
    where p_after_id is null or a.trainer_id>p_after_id
    order by a.trainer_id limit 50
  ) items),'[]'::jsonb);
end $$;
create function public.list_managed_trainers(p_after_id uuid default null)
returns jsonb language sql stable security invoker set search_path='' as $$
  select trainer_private.list_managed_trainers(p_after_id);
$$;
revoke all on function trainer_private.list_managed_trainers(uuid) from public,anon,authenticated;
revoke all on function public.list_managed_trainers(uuid) from public,anon,authenticated;
grant execute on function trainer_private.list_managed_trainers(uuid) to authenticated;
grant execute on function public.list_managed_trainers(uuid) to authenticated;
