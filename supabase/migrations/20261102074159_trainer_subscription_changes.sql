begin;
-- La compra inicial y sus recibos no se reescriben al cambiar de plan.
alter table commerce_private.orders add column current_offer_id uuid references commerce_private.offers(id),
 add column offer_revision bigint not null default 0 check(offer_revision>=0);
create table commerce_private.plan_changes (
 id uuid primary key default gen_random_uuid(),
 order_id uuid not null references commerce_private.orders(id),
 from_offer_id uuid not null references commerce_private.offers(id),
 offer_id uuid not null references commerce_private.offers(id),
 expected_revision bigint not null,
 kind text not null check(kind in ('immediate','renewal')),
 state text not null default 'prepared' check(state in ('prepared','quoted','processing','payment_pending','scheduled','applied','canceled','expired')),
 created_at timestamptz not null default clock_timestamp(),
 quoted_at timestamptz, expires_at timestamptz, proration_at bigint,
 amount integer check(amount>=0), effective_at timestamptz,
 item_id text, invoice_id text unique, schedule_id text unique,
 completed_at timestamptz,
 check(from_offer_id<>offer_id)
);
create unique index one_open_trainer_plan_change on commerce_private.plan_changes(order_id)
 where state in ('prepared','quoted','processing','payment_pending','scheduled');
alter table commerce_private.plan_changes enable row level security;
revoke all on commerce_private.plan_changes from public,anon,authenticated,service_role;

-- Solo la oferta cuya cobertura se ha acreditado alimenta la proyección.
do $migration$
declare definition text;
begin
 definition:=pg_get_functiondef('commerce_private.project_access()'::regprocedure);
 if strpos(definition,'f.id=o.offer_id')=0 then raise exception 'Revisar proyección comercial';end if;
 execute replace(definition,'f.id=o.offer_id','f.id=coalesce(o.current_offer_id,o.offer_id)');
end $migration$;

create function commerce_private.change_json(p_order uuid) returns jsonb
language sql stable security definer set search_path='' as $$
 select to_jsonb(c)||jsonb_build_object('offer',to_jsonb(f),'from_offer',to_jsonb(previous))
 from commerce_private.plan_changes c join commerce_private.offers f on f.id=c.offer_id
 join commerce_private.offers previous on previous.id=c.from_offer_id
 where c.order_id=p_order order by c.created_at desc,c.id desc limit 1;
$$;
revoke all on function commerce_private.change_json(uuid) from public,anon,authenticated,service_role;

create function commerce_private.prepare_change(p_owner uuid,p_offer uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare o commerce_private.orders; current_offer commerce_private.offers; target commerce_private.offers;
 c commerce_private.plan_changes; kind text; current_rank integer; target_rank integer;
begin
 perform commerce_private.assert_owner(p_owner,true);
 if not exists(select 1 from commerce_private.settings where enabled)
  or exists(select 1 from public.trainer_access where trainer_id=p_owner and suspended) then raise insufficient_privilege;end if;
 perform pg_advisory_xact_lock(hashtextextended('commerce:'||p_owner::text,0));
 select * into o from commerce_private.orders where owner_id=p_owner and state='active'
  and paid_until>statement_timestamp() and subscription_id is not null for update;
 if not found or o.cancel_at_period_end then raise exception 'Resuelve la renovación antes de cambiar de plan' using errcode='22023';end if;
 select * into current_offer from commerce_private.offers where id=coalesce(o.current_offer_id,o.offer_id);
 select * into target from commerce_private.offers where id=p_offer and active and plan_key<>'legacy';
 if not found or target.id=current_offer.id or target.currency<>current_offer.currency
  or target.interval<>current_offer.interval then raise invalid_parameter_value;end if;
 select * into c from commerce_private.plan_changes where order_id=o.id
  and state in ('prepared','quoted','processing','payment_pending','scheduled') for update;
 if found then
  if c.offer_id=p_offer and c.expected_revision=o.offer_revision then
   return jsonb_build_object('order_id',o.id,'change_id',c.id);end if;
  if c.state not in ('prepared','quoted') then raise exception 'Hay un cambio pendiente' using errcode='23505';end if;
  update commerce_private.plan_changes set state='canceled',completed_at=clock_timestamp() where id=c.id;
 end if;
 current_rank:=case current_offer.plan_key when 'complete' then 3 when 'professional' then 2 else 1 end;
 target_rank:=case target.plan_key when 'complete' then 3 when 'professional' then 2 else 1 end;
 -- Si se pierde alguna cobertura o no aumenta el importe, se conserva todo
 -- hasta renovar. Nunca se expulsan alumnos por superar el futuro cupo.
 kind:=case when target.capacity<current_offer.capacity or target_rank<current_rank
  or (current_offer.directory_option and not target.directory_option)
  or target.amount<=current_offer.amount then 'renewal' else 'immediate' end;
 insert into commerce_private.plan_changes(order_id,from_offer_id,offer_id,expected_revision,kind)
 values(o.id,current_offer.id,p_offer,o.offer_revision,kind) returning * into c;
 return jsonb_build_object('order_id',o.id,'change_id',c.id);
end $$;
create function public.prepare_trainer_plan_change(p_expected_owner uuid,p_offer uuid) returns jsonb
language sql security invoker set search_path='' as $$select commerce_private.prepare_change(p_expected_owner,p_offer)$$;
revoke all on function commerce_private.prepare_change(uuid,uuid),public.prepare_trainer_plan_change(uuid,uuid) from public,anon,authenticated,service_role;
grant execute on function commerce_private.prepare_change(uuid,uuid),public.prepare_trainer_plan_change(uuid,uuid) to authenticated;

-- Conserva el canal ya protegido de conciliación y añade operaciones bajo la
-- misma lease. El navegador no puede declarar pagos ni aplicar ofertas.
alter function commerce_private.server(text,jsonb) rename to server_before_plan_changes;
revoke all on function commerce_private.server_before_plan_changes(text,jsonb) from public,anon,authenticated,service_role;
create function commerce_private.server(p_action text,p_data jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare o commerce_private.orders; c commerce_private.plan_changes; result jsonb;
begin
 if p_action='claim' then
  result:=commerce_private.server_before_plan_changes(p_action,p_data);
  select * into o from commerce_private.orders where id=(p_data->>'id')::uuid;
  return result||jsonb_build_object('current_offer',(select to_jsonb(f) from commerce_private.offers f
   where f.id=coalesce(o.current_offer_id,o.offer_id)),'change',commerce_private.change_json(o.id));
 elsif p_action not like 'change_%' then
  return commerce_private.server_before_plan_changes(p_action,p_data);
 end if;
 select * into o from commerce_private.orders where id=(p_data->>'id')::uuid for update;
 if not found or o.lease is distinct from (p_data->>'lease')::uuid or o.lease_until<=clock_timestamp() then raise serialization_failure;end if;
 if p_action='change_evidence' then
  return jsonb_build_object('known',exists(select 1 from commerce_private.plan_changes c
   where c.order_id=o.id and c.invoice_id=p_data->>'invoice_id' and c.kind='immediate'
    and ((c.state='applied' and c.offer_id=coalesce(o.current_offer_id,o.offer_id))
     or (c.state='canceled' and c.from_offer_id=coalesce(o.current_offer_id,o.offer_id)))));
 end if;
 select * into c from commerce_private.plan_changes where id=(p_data->>'change_id')::uuid and order_id=o.id for update;
 if not found then raise invalid_parameter_value;end if;
 if p_action in ('change_quote','change_start') and exists(select 1 from public.trainer_access
  where trainer_id=o.owner_id and suspended) then raise insufficient_privilege;end if;
 if p_action='change_quote' then
  if c.state not in ('prepared','quoted') or c.expected_revision<>o.offer_revision then raise serialization_failure;end if;
  if (p_data->>'amount')::integer is null or (p_data->>'amount')::integer<0
   or (p_data->>'amount')::integer>(select amount from commerce_private.offers where id=c.offer_id)
   or (p_data->>'effective_at')::timestamptz<=clock_timestamp()
   or (p_data->>'effective_at')::timestamptz>clock_timestamp()+interval '367 days'
   or (p_data->>'proration_at')::bigint is null or p_data->>'item_id' is null then raise invalid_parameter_value;end if;
  update commerce_private.plan_changes set state='quoted',quoted_at=clock_timestamp(),
   expires_at=clock_timestamp()+interval '10 minutes',amount=(p_data->>'amount')::integer,
   proration_at=(p_data->>'proration_at')::bigint,effective_at=(p_data->>'effective_at')::timestamptz,
   item_id=p_data->>'item_id' where id=c.id;
 elsif p_action='change_start' then
  if c.state='quoted' then
   if c.expires_at<=clock_timestamp() or c.expected_revision<>o.offer_revision then raise serialization_failure;end if;
   update commerce_private.plan_changes set state='processing' where id=c.id;
  elsif c.state not in ('processing','payment_pending','scheduled') then raise serialization_failure;end if;
 elsif p_action='change_invoice' then
  if c.state not in ('processing','payment_pending') or c.kind<>'immediate' then raise serialization_failure;end if;
  update commerce_private.plan_changes set state='payment_pending',invoice_id=p_data->>'invoice_id' where id=c.id;
 elsif p_action='change_schedule_id' then
  if c.kind<>'renewal' or c.state not in ('processing','scheduled') then raise serialization_failure;end if;
  if c.schedule_id is not null and c.schedule_id is distinct from p_data->>'schedule_id' then raise serialization_failure;end if;
  update commerce_private.plan_changes set schedule_id=p_data->>'schedule_id' where id=c.id;
 elsif p_action='change_scheduled' then
  if c.kind<>'renewal' or c.state not in ('processing','scheduled') or c.schedule_id is null then raise serialization_failure;end if;
  update commerce_private.plan_changes set state='scheduled' where id=c.id;
 elsif p_action='change_apply' then
  if c.state='applied' and o.current_offer_id=c.offer_id then return '{}'::jsonb;end if;
  if c.state not in ('processing','payment_pending','scheduled') or c.expected_revision<>o.offer_revision
   or (p_data->>'paid_until')::timestamptz<=statement_timestamp() or p_data->>'invoice_id' is null then raise serialization_failure;end if;
  if (c.invoice_id is not null and c.invoice_id is distinct from p_data->>'invoice_id')
   or (c.kind='renewal' and (c.effective_at>statement_timestamp() or (p_data->>'paid_until')::timestamptz<=c.effective_at))
   or (c.kind='immediate' and (p_data->>'paid_until')::timestamptz is distinct from c.effective_at) then raise serialization_failure;end if;
  update commerce_private.orders set current_offer_id=c.offer_id,offer_revision=offer_revision+1 where id=o.id;
  update commerce_private.plan_changes set state='applied',invoice_id=p_data->>'invoice_id',completed_at=clock_timestamp() where id=c.id;
  perform commerce_private.server_before_plan_changes('apply',p_data||jsonb_build_object('state','active','subscription_id',o.subscription_id));
 elsif p_action='change_cancel' then
  if c.state='applied' then raise serialization_failure;end if;
  update commerce_private.plan_changes set state='canceled',completed_at=clock_timestamp() where id=c.id;
 else raise invalid_parameter_value;
 end if;
 return coalesce(commerce_private.change_json(o.id),'{}'::jsonb);
end $$;
revoke all on function commerce_private.server(text,jsonb) from public,anon,authenticated,service_role;
grant execute on function commerce_private.server(text,jsonb) to service_role;
-- La envoltura SQL existente debe apuntar al canal vigente, no al OID renombrado.
create or replace function public.trainer_commerce_server(p_action text,p_data jsonb) returns jsonb
language sql security invoker set search_path='' as $$select commerce_private.server(p_action,p_data)$$;

do $migration$
declare definition text;
begin
 definition:=pg_get_functiondef('commerce_private.status(uuid)'::regprocedure);
 if strpos(definition,'''subscription'',')=0 or strpos(definition,'f.id=o.offer_id')=0 then raise exception 'Revisar estado comercial';end if;
 definition:=replace(definition,'f.id=o.offer_id','f.id=coalesce(o.current_offer_id,o.offer_id)');
 definition:=replace(definition,'''subscription'',',
  '''change'',(select commerce_private.change_json(o.id) from commerce_private.orders o where o.owner_id=p_owner order by o.created_at desc,o.id desc limit 1),'||chr(10)||'  ''subscription'',');
 execute definition;
end $migration$;
commit;
