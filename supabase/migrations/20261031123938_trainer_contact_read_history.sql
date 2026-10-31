begin;

-- El contacto sigue siendo una entrada al mismo chat tras formalizar o reactivar
-- el vínculo: sus recibos admiten mensajes de las etapas de esa misma pareja.
create or replace function trainer_private.contact_read(p_contact uuid,p_ids uuid[]) returns void
language plpgsql security definer set search_path='' as $$
declare t trainer_private.contact_threads;
begin
 t:=trainer_private.contact_member(p_contact);
 perform pg_advisory_xact_lock(hashtextextended('trainer-client:'||t.requester_id::text,0));
 select * into t from trainer_private.contact_threads where id=p_contact;
 if auth.uid()<>t.trainer_id or p_ids is null or cardinality(p_ids)>50 then raise insufficient_privilege;end if;
 if exists(select 1 from unnest(p_ids) i where not exists(select 1 from trainer_private.messages m where m.id=i
   and m.sender_id=t.requester_id and (m.contact_id=t.id or (t.relation_id is not null and exists(
     select 1 from public.trainer_client_relations r where r.id=m.relation_id
       and r.trainer_id=t.trainer_id and r.client_id=t.requester_id))))) then raise insufficient_privilege;end if;
 insert into trainer_private.message_reads(trainer_id,message_id)
   select auth.uid(),i from unnest(p_ids) i on conflict do nothing;
end $$;

commit;
