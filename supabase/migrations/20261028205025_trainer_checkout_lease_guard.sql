begin;
-- Incluso la RPC de servidor exige una lease adquirida y vigente.
create or replace function commerce_private.server(p_action text,p_data jsonb) returns jsonb
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
 if o.lease is null or o.lease_until is null or p_data->>'lease' is null
    or o.lease is distinct from (p_data->>'lease')::uuid or o.lease_until<=clock_timestamp()
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
commit;
