begin;
-- El reintento conserva su oferta. Otra selección nunca se cobra como el plan anterior.
create or replace function commerce_private.status(p_owner uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare result jsonb;
begin
 perform commerce_private.assert_owner(p_owner);
 if exists(select 1 from public.trainer_access where trainer_id=p_owner) then
  perform commerce_private.refresh_access(p_owner);
 end if;
 select jsonb_build_object('sandbox',true,'enabled',s.enabled,'offers',
  coalesce((select jsonb_agg(jsonb_build_object('id',f.id,'title',f.title,'amount',f.amount,'currency',f.currency,
   'interval',f.interval,'capacity',f.capacity,'plan_key',f.plan_key,'directory_option',f.directory_option) order by f.amount) from commerce_private.offers f where f.active),'[]'::jsonb),
  'subscription',(select jsonb_build_object('id',o.id,'offer_id',o.offer_id,'title',f.title,'amount',f.amount,'currency',f.currency,'interval',f.interval,'state',o.state,'paid_until',o.paid_until,
    'cancel_at_period_end',o.cancel_at_period_end,'capacity',f.capacity,'checked_at',o.checked_at)
   from commerce_private.orders o join commerce_private.offers f on f.id=o.offer_id
   where o.owner_id=p_owner order by o.created_at desc,o.id desc limit 1))
 into result from commerce_private.settings s where singleton;
 return result;
end $$;

create or replace function commerce_private.prepare(p_owner uuid,p_offer uuid) returns uuid
language plpgsql security definer set search_path='' as $$
declare result uuid; selected_offer uuid;
begin
 perform commerce_private.assert_owner(p_owner,true);
 if not exists(select 1 from commerce_private.settings where enabled) then raise exception 'commerce_unavailable' using errcode='55000';end if;
 perform pg_advisory_xact_lock(hashtextextended('commerce:'||p_owner::text,0));
 select id,offer_id into result,selected_offer from commerce_private.orders where owner_id=p_owner and state not in ('expired','canceled');
 if result is not null then
   if selected_offer is distinct from p_offer then
     raise exception 'Ya hay una contratación pendiente para otro plan.' using errcode='23505';
   end if;
   return result;
 end if;
 if not exists(select 1 from commerce_private.offers where id=p_offer and active) then raise exception 'offer_unavailable' using errcode='22023';end if;
 insert into commerce_private.customers(owner_id) values(p_owner) on conflict do nothing;
 insert into commerce_private.orders(owner_id,offer_id) values(p_owner,p_offer) returning id into result;
 return result;
end $$;

commit;
