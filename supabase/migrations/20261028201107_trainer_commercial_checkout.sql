begin;
-- Solo Dev: el catálogo no acepta precios ni cupos procedentes de Flutter.
create schema commerce_private;
revoke all on schema commerce_private from public,anon,authenticated,service_role;
create table commerce_private.settings(
 singleton boolean primary key default true check(singleton),
 enabled boolean not null default false,
 account_id text not null check(account_id='acct_1UV6mYPhGz4xntMQ')
);
insert into commerce_private.settings(account_id) values('acct_1UV6mYPhGz4xntMQ');
create table commerce_private.offers(
 id uuid primary key, version integer not null check(version>0), title text not null,
 price_id text not null unique check(price_id ~ '^price_[A-Za-z0-9]+$'),
 amount integer not null check(amount>0), currency text not null check(currency='EUR'),
 interval text not null check(interval in ('month','year')),
 capacity integer not null check(capacity between 1 and 10000), active boolean not null default true
);
insert into commerce_private.offers values(
 '9d50b521-de26-48b0-8da7-d1fd3e85a660',1,'Ensayo de contratación · sin cobro real',
 'price_1UVdDqPhGz4xntMQW9YlmGFC',100,'EUR','month',5,true);
create table commerce_private.customers(
 owner_id uuid primary key references public.profiles(id) on delete restrict,
 customer_id text unique check(customer_id ~ '^cus_[A-Za-z0-9]+$'),
 created_at timestamptz not null default clock_timestamp()
);
create table commerce_private.orders(
 id uuid primary key default gen_random_uuid(),
 owner_id uuid not null references commerce_private.customers(owner_id) on delete restrict,
 offer_id uuid not null references commerce_private.offers(id) on delete restrict,
 created_at timestamptz not null default clock_timestamp(),
 session_id text unique check(session_id ~ '^cs_test_[A-Za-z0-9]+$'),
 subscription_id text unique check(subscription_id ~ '^sub_[A-Za-z0-9]+$'),
 state text not null default 'prepared' check(state in ('prepared','open','active','past_due','canceled','expired')),
 paid_until timestamptz, cancel_at_period_end boolean not null default false,
 lease uuid, lease_until timestamptz,
 checked_at timestamptz, next_check_at timestamptz not null default now()
);
create unique index commerce_one_contract on commerce_private.orders(owner_id) where state not in ('expired','canceled');
create index commerce_order_offer on commerce_private.orders(offer_id);
create table commerce_private.receipts(
 invoice_id text primary key check(invoice_id ~ '^in_[A-Za-z0-9]+$'),
 order_id uuid not null references commerce_private.orders(id) on delete restrict,
 period_end timestamptz not null, recorded_at timestamptz not null default now()
);
create index commerce_receipt_order on commerce_private.receipts(order_id);
create table commerce_private.events(
 event_id text primary key check(event_id ~ '^evt_[A-Za-z0-9]+$'),
 event_type text not null, object_id text not null,
 received_at timestamptz not null default now(), completed_at timestamptz
);
-- Tablas privadas sin Data API. Solo RPC de servidor o de cuenta propia.
alter table commerce_private.settings enable row level security;
alter table commerce_private.offers enable row level security;
alter table commerce_private.customers enable row level security;
alter table commerce_private.orders enable row level security;
alter table commerce_private.receipts enable row level security;
alter table commerce_private.events enable row level security;
revoke all on all tables in schema commerce_private from public,anon,authenticated,service_role;

-- El acceso existente pasa a ser una proyección compatible. Se conserva la fuente
-- manual íntegra: una renovación/cancelación jamás escribe sobre el regalo.
alter table public.trainer_access add column manual_enabled boolean,
 add column manual_client_limit integer check(manual_client_limit>0),
 add column manual_valid_until timestamptz, add column commercial_refresh_at timestamptz;
update public.trainer_access set manual_enabled=enabled,manual_client_limit=client_limit,manual_valid_until=valid_until,
 commercial_refresh_at=case when enabled and valid_until>statement_timestamp() then valid_until else null end;
create index trainer_commercial_refresh on public.trainer_access(commercial_refresh_at) where commercial_refresh_at is not null;
create function commerce_private.project_access() returns trigger
language plpgsql security definer set search_path='' as $$
declare cap integer; horizon timestamptz; indefinite boolean;
begin
 if tg_op='INSERT' and new.manual_enabled is null then
  new.manual_enabled:=new.enabled;new.manual_client_limit:=new.client_limit;new.manual_valid_until:=new.valid_until;
 elsif tg_op='UPDATE' and (new.manual_enabled,new.manual_client_limit,new.manual_valid_until)
  is not distinct from (old.manual_enabled,old.manual_client_limit,old.manual_valid_until)
  and (new.enabled,new.client_limit,new.valid_until) is distinct from (old.enabled,old.client_limit,old.valid_until) then
  -- Compatibilidad con operaciones administrativas internas ya existentes.
  new.manual_enabled:=new.enabled;new.manual_client_limit:=new.client_limit;new.manual_valid_until:=new.valid_until;
 end if;
 select max(s.capacity) into cap from (
  select new.manual_client_limit capacity where new.manual_enabled
   and (new.manual_valid_until is null or new.manual_valid_until>statement_timestamp())
  union all select f.capacity from commerce_private.orders o join commerce_private.offers f on f.id=o.offer_id
   where o.owner_id=new.trainer_id and o.paid_until>statement_timestamp()
 ) s;
 if cap is null then
  -- Se conserva la distinción histórica habilitado/caducado. La consulta del
  -- servicio anterior no se convierte en una cuenta inexistente por expirar.
  if new.manual_enabled then
   new.enabled:=true;new.client_limit:=new.manual_client_limit;new.valid_until:=new.manual_valid_until;
  else
   select f.capacity,o.paid_until into cap,horizon from commerce_private.orders o
    join commerce_private.offers f on f.id=o.offer_id where o.owner_id=new.trainer_id and o.paid_until is not null
    order by o.paid_until desc limit 1;
   new.enabled:=cap is not null;new.client_limit:=coalesce(cap,new.manual_client_limit,1);new.valid_until:=horizon;
  end if;
 else
  select bool_or(s.until_at is null),max(s.until_at) into indefinite,horizon from (
   select new.manual_valid_until until_at where new.manual_enabled and new.manual_client_limit=cap
    and (new.manual_valid_until is null or new.manual_valid_until>statement_timestamp())
   union all select o.paid_until from commerce_private.orders o join commerce_private.offers f on f.id=o.offer_id
    where o.owner_id=new.trainer_id and o.paid_until>statement_timestamp() and f.capacity=cap
  ) s;
  new.enabled:=true;new.client_limit:=cap;new.valid_until:=case when indefinite then null else horizon end;
 end if;
 new.commercial_refresh_at:=case when new.enabled and new.valid_until>statement_timestamp() then new.valid_until else null end;
 return new;
end $$;
create trigger commerce_project_access before insert or update on public.trainer_access
for each row execute function commerce_private.project_access();
create function commerce_private.refresh_access(p_owner uuid) returns void
language plpgsql security definer set search_path='' as $$
begin
 perform pg_advisory_xact_lock(hashtextextended('trainer-access:'||p_owner::text,0));
 insert into public.trainer_access(trainer_id,enabled,client_limit,last_reason,manual_enabled,manual_client_limit)
 values(p_owner,false,1,'Proyección comercial Dev',false,1)
 on conflict(trainer_id) do update set enabled=public.trainer_access.enabled;
end $$;
-- La caducidad cierra el permiso aunque el scheduler se retrase. Esta tarea
-- recalcula el cupo de la fuente que quede, sin cerrar vínculos ni borrar datos.
create function commerce_private.refresh_expired_access() returns void
language plpgsql security definer set search_path='' as $$
declare v uuid;
begin
 for v in select trainer_id from public.trainer_access where commercial_refresh_at<=statement_timestamp()
 loop perform commerce_private.refresh_access(v);end loop;
end $$;
select cron.schedule('trainer-commerce-access-dev','* * * * *','select commerce_private.refresh_expired_access()');

create function commerce_private.assert_owner(p_owner uuid,p_mfa boolean default false) returns void
language plpgsql stable security definer set search_path='' as $$
begin
 if auth.uid() is null or p_owner is distinct from auth.uid()
 or coalesce((auth.jwt()->>'is_anonymous')::boolean,false)
 or not exists(select 1 from auth.users where id=p_owner and email_confirmed_at is not null)
 or (p_mfa and not trainer_private.has_trainer_mfa()) then raise insufficient_privilege;end if;
end $$;
create function commerce_private.status(p_owner uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare result jsonb;
begin
 perform commerce_private.assert_owner(p_owner);
 if exists(select 1 from public.trainer_access where trainer_id=p_owner) then
  perform commerce_private.refresh_access(p_owner);
 end if;
 select jsonb_build_object('sandbox',true,'enabled',s.enabled,'offers',
  coalesce((select jsonb_agg(jsonb_build_object('id',f.id,'title',f.title,'amount',f.amount,'currency',f.currency,
   'interval',f.interval,'capacity',f.capacity) order by f.amount) from commerce_private.offers f where f.active),'[]'::jsonb),
  'subscription',(select jsonb_build_object('id',o.id,'state',o.state,'paid_until',o.paid_until,
    'cancel_at_period_end',o.cancel_at_period_end,'capacity',f.capacity,'checked_at',o.checked_at)
   from commerce_private.orders o join commerce_private.offers f on f.id=o.offer_id
   where o.owner_id=p_owner order by o.created_at desc,o.id desc limit 1))
 into result from commerce_private.settings s where singleton;
 return result;
end $$;
create function commerce_private.prepare(p_owner uuid,p_offer uuid) returns uuid
language plpgsql security definer set search_path='' as $$
declare result uuid;
begin
 perform commerce_private.assert_owner(p_owner,true);
 if not exists(select 1 from commerce_private.settings where enabled) then raise exception 'commerce_unavailable' using errcode='55000';end if;
 perform pg_advisory_xact_lock(hashtextextended('commerce:'||p_owner::text,0));
 select id into result from commerce_private.orders where owner_id=p_owner and state not in ('expired','canceled');
 if result is not null then return result;end if;
 if not exists(select 1 from commerce_private.offers where id=p_offer and active) then raise exception 'offer_unavailable' using errcode='22023';end if;
 insert into commerce_private.customers(owner_id) values(p_owner) on conflict do nothing;
 insert into commerce_private.orders(owner_id,offer_id) values(p_owner,p_offer) returning id into result;
 return result;
end $$;
create function public.get_my_trainer_subscription(p_expected_owner uuid) returns jsonb
language sql security invoker set search_path='' as $$select commerce_private.status(p_expected_owner)$$;
create function public.prepare_trainer_subscription(p_expected_owner uuid,p_offer uuid) returns uuid
language sql security invoker set search_path='' as $$select commerce_private.prepare(p_expected_owner,p_offer)$$;
grant usage on schema commerce_private to authenticated;
revoke all on function commerce_private.status(uuid),commerce_private.prepare(uuid,uuid),commerce_private.assert_owner(uuid,boolean),
 commerce_private.project_access(),commerce_private.refresh_access(uuid),commerce_private.refresh_expired_access(),
 public.get_my_trainer_subscription(uuid),public.prepare_trainer_subscription(uuid,uuid) from public,anon,authenticated,service_role;
grant execute on function commerce_private.status(uuid),commerce_private.prepare(uuid,uuid),
 public.get_my_trainer_subscription(uuid),public.prepare_trainer_subscription(uuid,uuid) to authenticated;

-- Canal interno: solo service_role. El navegador jamás puede aportar evidencia
-- de pago, sesiones de Stripe, Customer IDs, cupos o periodos al RPC público.
create function commerce_private.server(p_action text,p_data jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare o commerce_private.orders; f commerce_private.offers; c commerce_private.customers; token uuid; prior uuid;
begin
 if p_action='event' then
  insert into commerce_private.events(event_id,event_type,object_id)
   values(p_data->>'event_id',p_data->>'event_type',p_data->>'object_id') on conflict do nothing;
  return jsonb_build_object('done',exists(select 1 from commerce_private.events where event_id=p_data->>'event_id' and completed_at is not null));
 elsif p_action='event_done' then
  update commerce_private.events set completed_at=clock_timestamp() where event_id=p_data->>'event_id';return '{}'::jsonb;
 elsif p_action='lookup' then
  select * into o from commerce_private.orders where
    (session_id=p_data->>'session_id' or subscription_id=p_data->>'subscription_id'
     or owner_id=(select owner_id from commerce_private.customers where customer_id=p_data->>'customer_id'))
   order by (session_id=p_data->>'session_id' or subscription_id=p_data->>'subscription_id') desc nulls last,created_at desc,id desc limit 1;
  return case when o.id is null then null else jsonb_build_object('id',o.id,'owner_id',o.owner_id) end;
 end if;
 select * into o from commerce_private.orders where id=(p_data->>'id')::uuid for update;
 if not found then raise exception 'order_not_found' using errcode='22023';end if;
 if p_action='claim' then
  if o.lease_until>clock_timestamp() then raise exception 'commerce_busy' using errcode='55P03';end if;
  token:=gen_random_uuid();
  update commerce_private.orders set lease=token,lease_until=clock_timestamp()+interval '2 minutes' where id=o.id;
  select * into f from commerce_private.offers where id=o.offer_id;
  select * into c from commerce_private.customers where owner_id=o.owner_id;
  return to_jsonb(o)||jsonb_build_object('lease',token,'offer',to_jsonb(f),'customer_id',c.customer_id);
 end if;
 if o.lease is distinct from (p_data->>'lease')::uuid or o.lease_until<=clock_timestamp()
 then raise exception 'commerce_lease_lost' using errcode='40001';end if;
 if p_action='customer' then
  update commerce_private.customers set customer_id=p_data->>'customer_id'
   where owner_id=o.owner_id and (customer_id is null or customer_id=p_data->>'customer_id');
  if not found then raise exception 'customer_conflict';end if;
 elsif p_action='checkout' then
  update commerce_private.orders set session_id=p_data->>'session_id',state='open'
   where id=o.id and (session_id is null or session_id=p_data->>'session_id');
  if not found then raise exception 'checkout_conflict';end if;
 elsif p_action='apply' then
  if o.subscription_id is not null and o.subscription_id is distinct from p_data->>'subscription_id'
   then raise exception 'subscription_conflict';end if;
  if p_data->>'invoice_id' is not null then
   select order_id into prior from commerce_private.receipts where invoice_id=p_data->>'invoice_id';
   if prior is not null and prior<>o.id then raise exception 'receipt_conflict';end if;
   insert into commerce_private.receipts(invoice_id,order_id,period_end)
    values(p_data->>'invoice_id',o.id,(p_data->>'paid_until')::timestamptz) on conflict do nothing;
  end if;
  update commerce_private.orders set subscription_id=p_data->>'subscription_id',state=p_data->>'state',
   paid_until=greatest(paid_until,(p_data->>'paid_until')::timestamptz),
   cancel_at_period_end=coalesce((p_data->>'cancel_at_period_end')::boolean,false),checked_at=clock_timestamp()
   where id=o.id;
  perform commerce_private.refresh_access(o.owner_id);
 elsif p_action='expired' then
  if o.paid_until>statement_timestamp() then raise exception 'paid_order_not_expirable';end if;
  update commerce_private.orders set state='expired',checked_at=clock_timestamp() where id=o.id;
 elsif p_action='release' then
  update commerce_private.orders set lease=null,lease_until=null where id=o.id;
 else raise exception 'invalid_commerce_action' using errcode='22023';end if;
 return '{}'::jsonb;
end $$;
create function public.trainer_commerce_server(p_action text,p_data jsonb) returns jsonb
language sql security invoker set search_path='' as $$select commerce_private.server(p_action,p_data)$$;
revoke all on function commerce_private.server(text,jsonb),public.trainer_commerce_server(text,jsonb) from public,anon,authenticated,service_role;
grant usage on schema commerce_private to service_role;
grant execute on function commerce_private.server(text,jsonb),public.trainer_commerce_server(text,jsonb) to service_role;

-- ADMIN modifica exclusivamente su fuente manual, con su auditoría y revisión.
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
    if v.revision=p_expected_revision+1 and v.manual_client_limit=p_client_limit and v.manual_enabled=p_enabled
      and v.manual_valid_until is not distinct from p_valid_until and v.updated_by=auth.uid()
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
    update public.trainer_access set manual_enabled=p_enabled,manual_client_limit=p_client_limit,
      manual_valid_until=p_valid_until,revision=revision+1,updated_at=clock_timestamp(),
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
commit;
