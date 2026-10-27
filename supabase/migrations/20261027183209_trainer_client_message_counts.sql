-- Amplía el resumen ya autorizado; conserva firma, MFA y grants existentes.
create or replace function trainer_private.message_inbox(p_expected_owner uuid) returns jsonb
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
    (select * from unread order by latest_at desc,relation_id limit 50) page),'[]'::jsonb),
   -- Los globos por alumno no dependen del límite de la bandeja de etapas.
   'clients',coalesce((select jsonb_object_agg(client_id,jsonb_build_object(
    'unread_count',unread_count,'relation_id',relation_id)) from (
     select client_id,sum(unread_count) as unread_count,
      (array_agg(relation_id order by latest_at desc,relation_id))[1] as relation_id
     from unread group by client_id
   ) clients),'{}'::jsonb))
 );
end $$;
