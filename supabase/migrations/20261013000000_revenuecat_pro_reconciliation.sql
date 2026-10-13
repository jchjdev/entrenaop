-- Las compras verificadas se separan de las concesiones manuales de desarrollo.
begin;

create table public.revenuecat_access_settings (
  singleton boolean primary key default true check (singleton),
  environment text not null default 'DISABLED'
    check (environment in ('DISABLED','SANDBOX','PRODUCTION'))
);
insert into public.revenuecat_access_settings(singleton) values(true);
alter table public.revenuecat_access_settings enable row level security;
revoke all on public.revenuecat_access_settings from public, anon, authenticated;

create table public.revenuecat_pro_state (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  environment text not null check (environment in ('SANDBOX','PRODUCTION')),
  active boolean not null,
  product_identifier text,
  store text,
  valid_until timestamptz,
  observed_at timestamptz not null,
  check (not active or (valid_until is not null and product_identifier is not null and store is not null and
    product_identifier in ('entrenaop_pro_monthly','entrenaop_pro_annual') and
    store in ('test_store','app_store','play_store'))),
  check (environment = 'SANDBOX' or store is distinct from 'test_store')
);
alter table public.revenuecat_pro_state enable row level security;
revoke all on public.revenuecat_pro_state from public, anon, authenticated;
grant select on public.revenuecat_pro_state to authenticated;
create policy revenuecat_read_own on public.revenuecat_pro_state for select
  to authenticated using (user_id = (select auth.uid()));

create table public.revenuecat_processed_events (
  event_id text not null check (char_length(event_id) between 1 and 256),
  user_id uuid not null references public.profiles(id) on delete cascade,
  event_type text not null check (char_length(event_type) between 1 and 80),
  received_at timestamptz not null default statement_timestamp(),
  primary key(event_id,user_id)
);
alter table public.revenuecat_processed_events enable row level security;
revoke all on public.revenuecat_processed_events from public, anon, authenticated;

create table public.revenuecat_sync_attempts (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  attempted_at timestamptz not null
);
alter table public.revenuecat_sync_attempts enable row level security;
revoke all on public.revenuecat_sync_attempts from public, anon, authenticated;

create or replace function public.has_pro_access(p_user_id uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists(select 1 from public.pro_access_grants
    where user_id = p_user_id and revoked_at is null
      and starts_at <= statement_timestamp() and ends_at > statement_timestamp())
  or exists(select 1 from public.revenuecat_pro_state s
    join public.revenuecat_access_settings c on c.singleton and c.environment = s.environment
    where s.user_id = p_user_id and s.active and s.valid_until > statement_timestamp());
$$;

create or replace function public.pro_access_snapshot(p_user_id uuid) returns jsonb
language sql stable security definer set search_path = '' as $$
  with sources as (
    select ends_at valid_until, 'development_manual'::text source, null::text environment
    from public.pro_access_grants where user_id = p_user_id and revoked_at is null
      and starts_at <= statement_timestamp() and ends_at > statement_timestamp()
    union all
    select s.valid_until, 'revenuecat', s.environment from public.revenuecat_pro_state s
      join public.revenuecat_access_settings c on c.singleton and c.environment = s.environment
      where s.user_id = p_user_id and s.active and s.valid_until > statement_timestamp()
  ), selected as (select * from sources order by valid_until desc, source limit 1)
  select jsonb_build_object(
    'user_id', p_user_id, 'tier', case when exists(select 1 from sources) then 'pro' else 'free' end,
    'checked_at', statement_timestamp(),
    'valid_until', (select valid_until from selected),
    'source', (select source from selected), 'billing_environment', (select environment from selected),
    'personal_exercises', (select count(*) from public.exercises where created_by = p_user_id and origin = 'user'),
    'personal_sessions', (select count(distinct family_id) from public.workout_templates
      where owner_user_id = p_user_id and origin = 'user' and status <> 'archived'),
    'exercise_limit', case when exists(select 1 from sources) then null else 8 end,
    'session_limit', case when exists(select 1 from sources) then null else 4 end
  );
$$;

-- El usuario no presenta un recibo ni una vigencia: solo el servidor de confianza
-- puede escribir el resultado de consultar al proveedor con sus credenciales.
create function public.apply_revenuecat_pro_snapshot(
  p_user_id uuid, p_environment text, p_active boolean,
  p_product_identifier text, p_store text, p_valid_until timestamptz,
  p_observed_at timestamptz, p_event_id text default null, p_event_type text default null
) returns jsonb language plpgsql security definer set search_path = '' as $$
declare n integer;
begin
  if p_environment is null or p_environment not in ('SANDBOX','PRODUCTION') or
    p_environment is distinct from (select environment from public.revenuecat_access_settings where singleton) then
    raise exception 'La integración de compras no está configurada.' using errcode = '42501';
  end if;
  if p_active is null or p_observed_at is null or
    p_observed_at > statement_timestamp() + interval '5 minutes' or
    p_observed_at < statement_timestamp() - interval '1 day' or
    (p_active and (p_valid_until is null or p_valid_until <= p_observed_at or
      p_product_identifier is null or p_product_identifier not in ('entrenaop_pro_monthly','entrenaop_pro_annual') or
      p_store is null or p_store not in ('test_store','app_store','play_store'))) or
    (p_environment = 'PRODUCTION' and p_store = 'test_store') then
    raise exception 'Respuesta del proveedor no válida.' using errcode = '22023';
  end if;
  perform 1 from public.profiles where id = p_user_id for update;
  if not found then return null; end if;
  if p_event_id is not null then
    insert into public.revenuecat_processed_events(event_id,user_id,event_type)
      values(p_event_id,p_user_id,p_event_type)
      on conflict(event_id,user_id) do nothing;
    get diagnostics n = row_count;
    if n = 0 then return public.pro_access_snapshot(p_user_id); end if;
  end if;
  -- Una consulta anterior que termina tarde no revoca una confirmación posterior.
  insert into public.revenuecat_pro_state(user_id,environment,active,product_identifier,store,valid_until,observed_at)
    values(p_user_id,p_environment,p_active,p_product_identifier,p_store,p_valid_until,p_observed_at)
    on conflict(user_id) do update set environment=excluded.environment,active=excluded.active,
      product_identifier=excluded.product_identifier,store=excluded.store,
      valid_until=excluded.valid_until,observed_at=excluded.observed_at
    where public.revenuecat_pro_state.observed_at < excluded.observed_at;
  return public.pro_access_snapshot(p_user_id);
end $$;
revoke all on function public.apply_revenuecat_pro_snapshot(uuid,text,boolean,text,text,timestamptz,timestamptz,text,text)
  from public, anon, authenticated;
grant execute on function public.apply_revenuecat_pro_snapshot(uuid,text,boolean,text,text,timestamptz,timestamptz,text,text)
  to service_role;

create function public.claim_revenuecat_sync(p_user_id uuid) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare last_attempt timestamptz;
begin
  if (select environment from public.revenuecat_access_settings where singleton) = 'DISABLED' then
    raise exception 'La integración de compras no está configurada.' using errcode = '42501';
  end if;
  perform 1 from public.profiles where id = p_user_id for update;
  if not found then return jsonb_build_object('should_sync',false,'access',null); end if;
  select attempted_at into last_attempt from public.revenuecat_sync_attempts where user_id=p_user_id;
  if last_attempt > statement_timestamp() - interval '5 seconds' then
    return jsonb_build_object('should_sync',false,'access',public.pro_access_snapshot(p_user_id));
  end if;
  insert into public.revenuecat_sync_attempts(user_id,attempted_at) values(p_user_id,statement_timestamp())
    on conflict(user_id) do update set attempted_at=excluded.attempted_at;
  return jsonb_build_object('should_sync',true);
end $$;
revoke all on function public.claim_revenuecat_sync(uuid) from public, anon, authenticated;
grant execute on function public.claim_revenuecat_sync(uuid) to service_role;

commit;
