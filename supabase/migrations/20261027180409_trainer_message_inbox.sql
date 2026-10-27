begin;

-- Recibos por mensaje: un envío concurrente nunca queda leído por un cursor temporal.
create table trainer_private.message_reads (
 trainer_id uuid not null references public.profiles(id) on delete cascade,
 message_id uuid not null references trainer_private.messages(id) on delete cascade,
 read_at timestamptz not null default statement_timestamp(),
 primary key(trainer_id,message_id)
);
alter table trainer_private.message_reads enable row level security;
revoke all on trainer_private.message_reads from public,anon,authenticated;

create function trainer_private.message_inbox(p_expected_owner uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
begin
 if auth.uid() is null or p_expected_owner is distinct from auth.uid()
  or not trainer_private.has_trainer_mfa() then raise insufficient_privilege; end if;
 return (
  with unread as (
   select r.id as relation_id,r.client_id,
    coalesce(nullif(btrim(p.full_name),''),'Alumno') as client_name,
    count(*) as unread_count,max(m.created_at) as latest_at
   from public.trainer_client_relations r
   join trainer_private.messages m on m.relation_id=r.id and m.sender_id=r.client_id
   join public.profiles p on p.id=r.client_id
   where r.trainer_id=auth.uid() and not exists (
    select 1 from trainer_private.message_reads seen
    where seen.trainer_id=auth.uid() and seen.message_id=m.id)
   group by r.id,r.client_id,p.full_name
  ) select jsonb_build_object('total_unread',coalesce((select sum(unread_count) from unread),0),
   'conversations',coalesce((select jsonb_agg(to_jsonb(page) order by latest_at desc,relation_id) from
    (select * from unread order by latest_at desc,relation_id limit 50) page),'[]'::jsonb))
 );
end $$;

create function trainer_private.read_messages(p_expected_owner uuid,p_message_ids uuid[]) returns void
language plpgsql security definer set search_path='' as $$
begin
 if auth.uid() is null or p_expected_owner is distinct from auth.uid()
  or not trainer_private.has_trainer_mfa() then raise insufficient_privilege; end if;
 if p_message_ids is null or cardinality(p_message_ids)>50 then raise invalid_parameter_value; end if;
 -- Se valida todo el lote antes de escribir; ni ADMIN ni otro preparador heredan acceso.
 if exists(select 1 from unnest(p_message_ids) wanted(id) where not exists(
  select 1 from trainer_private.messages m join public.trainer_client_relations r on r.id=m.relation_id
  where m.id=wanted.id and r.trainer_id=auth.uid() and m.sender_id=r.client_id)) then
  raise insufficient_privilege;
 end if;
 insert into trainer_private.message_reads(trainer_id,message_id)
 select auth.uid(),id from unnest(p_message_ids) wanted(id) on conflict do nothing;
end $$;

create function public.get_trainer_message_inbox(p_expected_owner uuid) returns jsonb
language sql security invoker set search_path='' as $$select trainer_private.message_inbox(p_expected_owner)$$;
create function public.read_trainer_messages(p_expected_owner uuid,p_message_ids uuid[]) returns void
language sql security invoker set search_path='' as $$select trainer_private.read_messages(p_expected_owner,p_message_ids)$$;
revoke all on function trainer_private.message_inbox(uuid),trainer_private.read_messages(uuid,uuid[]),
 public.get_trainer_message_inbox(uuid),public.read_trainer_messages(uuid,uuid[]) from public,anon,authenticated;
grant execute on function trainer_private.message_inbox(uuid),trainer_private.read_messages(uuid,uuid[]),
 public.get_trainer_message_inbox(uuid),public.read_trainer_messages(uuid,uuid[]) to authenticated;
commit;
