-- Regalos administrativos sin facturación, independientes de las compras.
begin;

alter table public.commercial_access_settings
  add column gift_management_enabled boolean not null default false;

create table public.pro_gift_grants (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  starts_at timestamptz not null default statement_timestamp(),
  ends_at timestamptz,
  granted_by uuid references auth.users(id) on delete set null,
  reason text not null check (char_length(btrim(reason)) between 3 and 200),
  revoked_at timestamptz,
  revoked_by uuid references auth.users(id) on delete set null,
  revocation_reason text,
  check (ends_at is null or ends_at > starts_at),
  check (revoked_at is null or revoked_at >= starts_at),
  check (revoked_at is null or (revocation_reason is not null
    and char_length(btrim(revocation_reason)) between 3 and 200))
);
create unique index pro_gift_one_unrevoked on public.pro_gift_grants(user_id)
  where revoked_at is null;
alter table public.pro_gift_grants enable row level security;
revoke all on public.pro_gift_grants from public, anon, authenticated;

create or replace function public.has_pro_access(p_user_id uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists(select 1 from public.pro_access_grants
    where user_id=p_user_id and revoked_at is null and starts_at <= statement_timestamp()
      and ends_at > statement_timestamp())
  or exists(select 1 from public.pro_gift_grants where user_id=p_user_id
    and revoked_at is null and starts_at <= statement_timestamp()
    and (ends_at is null or ends_at > statement_timestamp()))
  or exists(select 1 from public.revenuecat_pro_state s
    join public.revenuecat_access_settings c on c.singleton and c.environment=s.environment
    where s.user_id=p_user_id and s.active and s.valid_until > statement_timestamp());
$$;

create or replace function public.pro_access_snapshot(p_user_id uuid) returns jsonb
language sql stable security definer set search_path = '' as $$
  with sources as (
    select ends_at valid_until, 'development_manual'::text source, null::text environment
      from public.pro_access_grants where user_id=p_user_id and revoked_at is null
      and starts_at <= statement_timestamp() and ends_at > statement_timestamp()
    union all
    select ends_at, 'administrative_gift', null from public.pro_gift_grants
      where user_id=p_user_id and revoked_at is null and starts_at <= statement_timestamp()
      and (ends_at is null or ends_at > statement_timestamp())
    union all
    select s.valid_until, 'revenuecat', s.environment from public.revenuecat_pro_state s
      join public.revenuecat_access_settings c on c.singleton and c.environment=s.environment
      where s.user_id=p_user_id and s.active and s.valid_until > statement_timestamp()
  ), selected as (select * from sources order by valid_until desc nulls first, source limit 1)
  select jsonb_build_object(
    'user_id',p_user_id,'tier',case when exists(select 1 from sources) then 'pro' else 'free' end,
    'checked_at',statement_timestamp(),'valid_until',(select valid_until from selected),
    'source',(select source from selected),'billing_environment',(select environment from selected),
    'personal_exercises',(select count(*) from public.exercises where created_by=p_user_id and origin='user'),
    'personal_sessions',(select count(distinct family_id) from public.workout_templates
      where owner_user_id=p_user_id and origin='user' and status <> 'archived'),
    'exercise_limit',case when exists(select 1 from sources) then null else 8 end,
    'session_limit',case when exists(select 1 from sources) then null else 4 end
  );
$$;

-- La ficha muestra todas las fuentes: el origen dominante no oculta una compra.
create function public.admin_pro_account_snapshot(p_user_id uuid) returns jsonb
language sql stable security definer set search_path = '' as $$
  with free_sources as (
    select ends_at from public.pro_gift_grants where user_id=p_user_id and revoked_at is null
      and starts_at <= statement_timestamp() and (ends_at is null or ends_at > statement_timestamp())
    union all
    select ends_at from public.pro_access_grants where user_id=p_user_id and revoked_at is null
      and starts_at <= statement_timestamp() and ends_at > statement_timestamp()
  ), subscription as (
    select s.* from public.revenuecat_pro_state s
      join public.revenuecat_access_settings c on c.singleton and c.environment=s.environment
      where s.user_id=p_user_id and s.active and s.valid_until > statement_timestamp()
  )
  select public.pro_access_snapshot(p_user_id) || jsonb_build_object(
    'free_pro_active',exists(select 1 from free_sources),
    'free_pro_valid_until',(select ends_at from free_sources order by ends_at desc nulls first limit 1),
    'gift_management_enabled',coalesce((select gift_management_enabled from public.commercial_access_settings where singleton),false),
    'subscription_active',exists(select 1 from subscription),
    'subscription_valid_until',(select valid_until from subscription),
    'subscription_product_identifier',(select product_identifier from subscription),
    'subscription_environment',(select environment from subscription)
  );
$$;
revoke all on function public.admin_pro_account_snapshot(uuid) from public,anon,authenticated;

create function public.admin_find_pro_account(p_email text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare u uuid; matches integer;
begin
  if auth.uid() is null or not coalesce(public.is_admin(),false) then
    raise exception 'Solo administración puede gestionar Cuentas y Pro.' using errcode='42501';
  end if;
  select count(*),(array_agg(id))[1] into matches,u from auth.users
    where lower(email)=lower(btrim(p_email));
  if matches <> 1 then
    raise exception 'No se encuentra una cuenta única con ese correo.' using errcode='22023';
  end if;
  return public.admin_pro_account_snapshot(u);
end $$;

create function public.admin_set_free_pro_access(
  p_user_id uuid,p_enabled boolean,p_valid_until timestamptz default null,
  p_reason text default 'Acceso Pro gratuito'
) returns jsonb language plpgsql security definer set search_path = '' as $$
begin
  if auth.uid() is null or not coalesce(public.is_admin(),false) then
    raise exception 'Solo administración puede gestionar Cuentas y Pro.' using errcode='42501';
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
