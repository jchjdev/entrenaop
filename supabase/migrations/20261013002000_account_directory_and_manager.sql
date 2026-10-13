-- El responsable de cuentas es único y se configura por una operación de confianza.
begin;
alter table public.commercial_access_settings
  add column account_manager_user_id uuid references auth.users(id) on delete set null;

create function public.can_manage_pro_accounts() returns boolean
language sql stable security definer set search_path = '' as $$
  select auth.uid() is not null and coalesce(public.is_admin(),false)
    and exists(select 1 from public.commercial_access_settings
      where singleton and account_manager_user_id=auth.uid());
$$;
revoke all on function public.can_manage_pro_accounts() from public,anon;
grant execute on function public.can_manage_pro_accounts() to authenticated;

-- También se protege el recorrido antiguo para que no eluda el permiso nuevo.
create or replace function public.check_development_access_admin() returns void
language plpgsql security definer set search_path = '' as $$
begin
  if not public.can_manage_pro_accounts() then
    raise exception 'Solo el responsable de cuentas puede gestionar Cuentas y Pro.' using errcode='42501';
  end if;
  if not coalesce((select development_manual_access_enabled from public.commercial_access_settings where singleton),false) then
    raise exception 'La gestión de cuentas de prueba está deshabilitada en este entorno.' using errcode='42501';
  end if;
end $$;

create function public.admin_list_pro_accounts(
  p_search text default '', p_after_id uuid default null, p_limit integer default 25
) returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare result jsonb;
begin
  if not public.can_manage_pro_accounts() then
    raise exception 'Solo el responsable de cuentas puede gestionar Cuentas y Pro.' using errcode='42501';
  end if;
  if p_limit is null or p_limit not between 1 and 50 or p_search is null or char_length(p_search)>200 then
    raise exception 'Revisa la búsqueda y el tamaño de página.' using errcode='22023';
  end if;
  -- Cursor sobre la PK de Auth: evita offsets crecientes y descargas completas.
  with candidates as materialized (
    select u.id,u.email from auth.users u join public.profiles p on p.id=u.id
    where u.email is not null and (p_after_id is null or u.id>p_after_id)
      and strpos(lower(u.email),lower(btrim(p_search)))>0
    order by u.id limit p_limit+1
  ), page as (select * from candidates order by id limit p_limit), rows as (
    select p.id,jsonb_build_object(
      'user_id',p.id,'email',p.email,
      'tier',case when public.has_pro_access(p.id) then 'pro' else 'free' end,
      'free_pro_active',exists(select 1 from public.pro_gift_grants g where g.user_id=p.id
        and g.revoked_at is null and g.starts_at<=statement_timestamp()
        and (g.ends_at is null or g.ends_at>statement_timestamp()))
        or exists(select 1 from public.pro_access_grants g where g.user_id=p.id
          and g.revoked_at is null and g.starts_at<=statement_timestamp() and g.ends_at>statement_timestamp()),
      'subscription_active',exists(select 1 from public.revenuecat_pro_state s
        join public.revenuecat_access_settings c on c.singleton and c.environment=s.environment
        where s.user_id=p.id and s.active and s.valid_until>statement_timestamp()),
      'subscription_environment',(select s.environment from public.revenuecat_pro_state s
        join public.revenuecat_access_settings c on c.singleton and c.environment=s.environment
        where s.user_id=p.id and s.active and s.valid_until>statement_timestamp())
    ) value from page p
  )
  select jsonb_build_object('accounts',coalesce((select jsonb_agg(value order by id) from rows),'[]'::jsonb),
    'next_cursor',case when (select count(*) from candidates)>p_limit
      then (select id::text from page order by id desc limit 1) else null end) into result;
  return result;
end $$;
revoke all on function public.admin_list_pro_accounts(text,uuid,integer) from public,anon;
grant execute on function public.admin_list_pro_accounts(text,uuid,integer) to authenticated;
create or replace function public.admin_find_pro_account(p_email text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare u uuid; matches integer;
begin
  if not public.can_manage_pro_accounts() then
    raise exception 'Solo el responsable de cuentas puede gestionar Cuentas y Pro.' using errcode='42501';
  end if;
  select count(*),(array_agg(id))[1] into matches,u from auth.users
    where lower(email)=lower(btrim(p_email));
  if matches <> 1 then
    raise exception 'No se encuentra una cuenta única con ese correo.' using errcode='22023';
  end if;
  return public.admin_pro_account_snapshot(u);
end $$;

create or replace function public.admin_set_free_pro_access(
  p_user_id uuid,p_enabled boolean,p_valid_until timestamptz default null,
  p_reason text default 'Acceso Pro gratuito'
) returns jsonb language plpgsql security definer set search_path = '' as $$
begin
  if not public.can_manage_pro_accounts() then
    raise exception 'Solo el responsable de cuentas puede gestionar Cuentas y Pro.' using errcode='42501';
  end if;
  if not coalesce((select gift_management_enabled from public.commercial_access_settings where singleton),false) then
    raise exception 'La gestión de Pro gratuito está deshabilitada en este entorno.' using errcode='42501';
  end if;
  if p_enabled is null or p_reason is null or char_length(btrim(p_reason)) not between 3 and 200
    or (p_enabled and p_valid_until is not null and p_valid_until <= statement_timestamp()) then
    raise exception 'Revisa la vigencia y el motivo del Pro gratuito.' using errcode='22023';
  end if;
  perform 1 from public.profiles where id=p_user_id for update;
  if not found then raise exception 'La cuenta ya no está disponible.' using errcode='22023'; end if;
  update public.pro_gift_grants set revoked_at=statement_timestamp(),revoked_by=auth.uid(),
    revocation_reason=btrim(p_reason) where user_id=p_user_id and revoked_at is null;
  -- Los accesos gratuitos previos de Dev también son retirables; las compras no.
  update public.pro_access_grants set revoked_at=statement_timestamp(),revoked_by=auth.uid(),
    revocation_reason=btrim(p_reason)
    where user_id=p_user_id and source='development_manual' and revoked_at is null;
  if p_enabled then
    insert into public.pro_gift_grants(user_id,ends_at,granted_by,reason)
      values(p_user_id,p_valid_until,auth.uid(),btrim(p_reason));
  end if;
  return public.admin_pro_account_snapshot(p_user_id);
end $$;
revoke all on function public.admin_find_pro_account(text),
  public.admin_set_free_pro_access(uuid,boolean,timestamptz,text) from public,anon;
grant execute on function public.admin_find_pro_account(text),
  public.admin_set_free_pro_access(uuid,boolean,timestamptz,text) to authenticated;

commit;
