begin;

-- La ficha es una prestación elegida por ADMIN, no una consecuencia de tener
-- herramientas. Comparte la vigencia del regalo y no publica ningún perfil.
alter table public.trainer_access
  add column manual_directory_enabled boolean not null default false;

create function directory_private.manual_eligible(p_trainer uuid) returns boolean
language sql stable security definer set search_path='' as $$
  select coalesce((select manual_access_enabled from public.trainer_access_settings where singleton),false)
    and exists(select 1 from public.trainer_access a
      where a.trainer_id=p_trainer and a.enabled and not a.suspended
        and a.manual_enabled and a.manual_directory_enabled
        and (a.manual_valid_until is null or a.manual_valid_until>statement_timestamp())
        and (a.valid_until is null or a.valid_until>statement_timestamp()))
$$;
revoke all on function directory_private.manual_eligible(uuid)
  from public,anon,authenticated,service_role;

create or replace function directory_private.eligible(p_trainer uuid) returns boolean
language sql stable security definer set search_path='' as $$
  select directory_private.commercial_eligible(p_trainer)
    or directory_private.manual_eligible(p_trainer)
    or (directory_private.pilot_until(p_trainer) is not null
      and exists(select 1 from public.trainer_access a where a.trainer_id=p_trainer
        and a.enabled and (a.valid_until is null or a.valid_until>statement_timestamp())))
$$;

create or replace function trainer_private.get_trainer_management_status(p_trainer_id uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
begin
  if auth.uid() is null or not public.can_manage_pro_accounts() then raise insufficient_privilege;end if;
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
    'suspension_reason',(select suspension_reason from public.trainer_access where trainer_id=p_trainer_id));
end $$;

-- Un único guardado atómico conserva bloqueo, revisión, reintento y auditoría.
-- El parámetro nulo solo conserva la selección de los clientes administrativos
-- anteriores: sus peticiones no añaden ni retiran esta prestación por accidente.
create function trainer_private.admin_set_trainer_access_with_directory(
  p_trainer_id uuid,p_client_limit integer,p_enabled boolean,p_expected_revision bigint,
  p_reason text,p_valid_until timestamptz,p_directory_enabled boolean
) returns jsonb language plpgsql security definer set search_path='' as $$
declare v public.trainer_access; previous jsonb; result jsonb; desired_directory boolean;
begin
  if auth.uid() is null or not public.can_manage_pro_accounts()
    or not coalesce((select manual_access_enabled from public.trainer_access_settings where singleton),false)
    then raise insufficient_privilege;end if;
  if p_trainer_id is null or p_client_limit is null or p_client_limit<1 or p_enabled is null
    or p_expected_revision is null or p_expected_revision<0
    or p_reason is null or char_length(btrim(p_reason)) not between 3 and 500
    or (p_enabled and p_valid_until is not null and p_valid_until<=clock_timestamp()) then
    raise exception 'Revisa el cupo, la vigencia y el motivo.' using errcode='22023';
  end if;
  perform pg_advisory_xact_lock(hashtextextended('trainer-access:'||p_trainer_id::text,0));
  select * into v from public.trainer_access where trainer_id=p_trainer_id for update;
  desired_directory:=coalesce(p_directory_enabled,v.manual_directory_enabled,false);
  if found then
    if v.last_action='manual' and v.revision=p_expected_revision+1
      and v.manual_client_limit=p_client_limit and v.manual_enabled=p_enabled
      and v.manual_directory_enabled=desired_directory
      and v.manual_valid_until is not distinct from p_valid_until
      and v.updated_by=auth.uid() and v.last_reason=btrim(p_reason) then
      return trainer_private.get_trainer_access(p_trainer_id)
        ||jsonb_build_object('manual_directory_enabled',v.manual_directory_enabled);
    end if;
    if v.revision<>p_expected_revision then
      raise exception 'El acceso ha cambiado; actualiza la ficha.' using errcode='40001';
    end if;
    if p_enabled and p_client_limit<(select count(*) from public.trainer_client_relations
      where trainer_id=p_trainer_id and trainer_id<>client_id and ended_at is null) then
      raise exception 'Finaliza los vínculos necesarios antes de reducir el cupo.' using errcode='23514';
    end if;
    previous:=trainer_private.get_trainer_management_status(p_trainer_id);
    update public.trainer_access set manual_enabled=p_enabled,manual_client_limit=p_client_limit,
      manual_valid_until=p_valid_until,manual_directory_enabled=desired_directory,
      revision=revision+1,updated_at=clock_timestamp(),updated_by=auth.uid(),
      last_reason=btrim(p_reason),last_action='manual' where trainer_id=p_trainer_id;
  else
    if p_expected_revision<>0 then raise exception 'El acceso ha cambiado.' using errcode='40001';end if;
    insert into public.trainer_access(trainer_id,enabled,client_limit,valid_until,updated_by,last_reason,manual_directory_enabled)
      values(p_trainer_id,p_enabled,p_client_limit,p_valid_until,auth.uid(),btrim(p_reason),desired_directory);
  end if;
  result:=trainer_private.get_trainer_access(p_trainer_id)
    ||jsonb_build_object('manual_directory_enabled',desired_directory);
  insert into public.trainer_access_audit(trainer_id,actor_id,revision,previous_access,new_access,reason)
    values(p_trainer_id,auth.uid(),(result->>'revision')::bigint,previous,result,btrim(p_reason));
  return result;
end $$;

create or replace function trainer_private.admin_set_trainer_access(
  p_trainer_id uuid,p_client_limit integer,p_enabled boolean,p_expected_revision bigint,
  p_reason text,p_valid_until timestamptz
) returns jsonb language sql security definer set search_path='' as $$
  select trainer_private.admin_set_trainer_access_with_directory(
    p_trainer_id,p_client_limit,p_enabled,p_expected_revision,p_reason,p_valid_until,null)
    - 'manual_directory_enabled';
$$;

create function public.admin_set_trainer_access_with_directory(
  p_trainer_id uuid,p_client_limit integer,p_enabled boolean,p_expected_revision bigint,
  p_reason text,p_valid_until timestamptz,p_directory_enabled boolean
) returns jsonb language sql security invoker set search_path='' as $$
  select trainer_private.admin_set_trainer_access_with_directory(
    p_trainer_id,p_client_limit,p_enabled,p_expected_revision,p_reason,p_valid_until,p_directory_enabled);
$$;
revoke all on function trainer_private.admin_set_trainer_access_with_directory(uuid,integer,boolean,bigint,text,timestamptz,boolean),
  public.admin_set_trainer_access_with_directory(uuid,integer,boolean,bigint,text,timestamptz,boolean)
  from public,anon,authenticated,service_role;
grant execute on function trainer_private.admin_set_trainer_access_with_directory(uuid,integer,boolean,bigint,text,timestamptz,boolean),
  public.admin_set_trainer_access_with_directory(uuid,integer,boolean,bigint,text,timestamptz,boolean)
  to authenticated;

commit;
