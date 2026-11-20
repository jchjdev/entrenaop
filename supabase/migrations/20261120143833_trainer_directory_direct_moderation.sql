begin;

-- Las decisiones anteriores conservan su denuncia. Una decisión directa
-- identifica la ficha sin inventar una denuncia ni cambiar las existentes.
alter table directory_private.moderation_events
  alter column report_id drop not null,
  add column profile_id uuid references directory_private.profiles(id) on delete restrict,
  add constraint directory_moderation_target
    check (num_nonnulls(report_id, profile_id) = 1);

create index directory_moderation_direct_profile
  on directory_private.moderation_events(profile_id) where profile_id is not null;

create or replace function trainer_private.get_trainer_management_status(p_trainer_id uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
begin
  if auth.uid() is null or not public.can_manage_pro_accounts() then raise insufficient_privilege; end if;
  return jsonb_build_object('access',trainer_private.get_trainer_access(p_trainer_id),
    'manual_access_enabled',coalesce((select manual_access_enabled from public.trainer_access_settings where singleton),false),
    'manual_enabled',coalesce((select manual_enabled from public.trainer_access where trainer_id=p_trainer_id),false),
    'manual_client_limit',(select manual_client_limit from public.trainer_access where trainer_id=p_trainer_id),
    'manual_valid_until',(select manual_valid_until from public.trainer_access where trainer_id=p_trainer_id),
    'manual_directory_enabled',coalesce((select manual_directory_enabled from public.trainer_access where trainer_id=p_trainer_id),false),
    'directory_source',case
      when directory_private.commercial_eligible(p_trainer_id) then 'paid'
      when directory_private.manual_eligible(p_trainer_id) then 'manual'
      when directory_private.eligible(p_trainer_id) then 'pilot' else null end,
    'suspension_reason',(select suspension_reason from public.trainer_access where trainer_id=p_trainer_id),
    'directory_moderation',(select jsonb_build_object('suspended',p.suspended,'revision',p.revision)
      from directory_private.profiles p where p.trainer_id=p_trainer_id));
end $$;

create function directory_private.moderate_profile(
  p_expected_owner uuid, p_trainer_id uuid, p_suspend boolean,
  p_expected_revision integer, p_reason text
) returns jsonb language plpgsql security definer set search_path='' as $$
declare
  profile directory_private.profiles%rowtype;
  reason text := btrim(p_reason);
begin
  perform commerce_private.assert_owner(p_expected_owner, true);
  if not public.can_manage_pro_accounts() then raise insufficient_privilege; end if;
  if p_trainer_id is null or p_suspend is null or p_expected_revision is null
    or reason is null or length(reason) not between 5 and 1000 then
    raise invalid_parameter_value;
  end if;

  select * into profile from directory_private.profiles where trainer_id=p_trainer_id for update;
  if not found then raise insufficient_privilege; end if;
  -- Las denuncias y el editor también avanzan la revisión de la ficha.
  if profile.revision <> p_expected_revision then raise serialization_failure; end if;

  if profile.suspended <> p_suspend then
    update directory_private.profiles
      set suspended=p_suspend, revision=revision+1, updated_at=statement_timestamp()
      where id=profile.id returning * into profile;
    insert into directory_private.moderation_events(actor_id,profile_id,suspended,reason)
      values(p_expected_owner,profile.id,p_suspend,reason);
  end if;
  return jsonb_build_object('suspended',profile.suspended,'revision',profile.revision);
end $$;

create function public.directory_moderate_profile(
  p_expected_owner uuid, p_trainer_id uuid, p_suspend boolean,
  p_expected_revision integer, p_reason text
) returns jsonb language sql security invoker set search_path='' as $$
  select directory_private.moderate_profile(p_expected_owner,p_trainer_id,
    p_suspend,p_expected_revision,p_reason)
$$;

revoke all on function directory_private.moderate_profile(uuid,uuid,boolean,integer,text),
  public.directory_moderate_profile(uuid,uuid,boolean,integer,text) from public,anon,authenticated,service_role;
grant execute on function directory_private.moderate_profile(uuid,uuid,boolean,integer,text),
  public.directory_moderate_profile(uuid,uuid,boolean,integer,text) to authenticated;

commit;
