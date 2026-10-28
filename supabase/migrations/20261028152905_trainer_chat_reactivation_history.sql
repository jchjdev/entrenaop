begin;

create or replace function trainer_private.list_messages(
 p_relation_id uuid,
 p_before_at timestamptz default null,
 p_before_id uuid default null
) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare r public.trainer_client_relations;
begin
 select * into r from public.trainer_client_relations
 where id=p_relation_id and trainer_id<>client_id
   and (trainer_id=auth.uid() or client_id=auth.uid());
 if not found or (r.trainer_id=auth.uid() and not trainer_private.has_trainer_mfa()) then
  raise insufficient_privilege;
 end if;
 if (p_before_at is null)<>(p_before_id is null) then raise invalid_parameter_value; end if;

 -- Una etapa cerrada conserva su consulta exacta. La activa recupera también
 -- etapas terminadas de esa misma pareja, sin trasladar mensajes ni derechos.
 -- Como la página global tiene 50 filas, nunca necesita más de 50 de cada
 -- etapa. El lateral aprovecha el índice por relación/fecha/id, también al paginar.
 return (
  select coalesce(jsonb_agg(to_jsonb(page) order by created_at desc,id desc),'[]'::jsonb)
  from (
   select item.*
   from public.trainer_client_relations history
   cross join lateral (
    select m.id,m.assignment_id,m.sender_id,m.body,m.created_at
    from trainer_private.messages m
    where m.relation_id=history.id
      and (p_before_at is null or (m.created_at,m.id)<(p_before_at,p_before_id))
    order by m.created_at desc,m.id desc limit 50
   ) item
   where history.trainer_id=r.trainer_id and history.client_id=r.client_id
     and (history.id=r.id or (r.ended_at is null and history.ended_at is not null))
   order by item.created_at desc,item.id desc limit 50
  ) page
 );
end $$;

-- CREATE OR REPLACE conserva las ACL: el wrapper público sigue siendo invoker,
-- y la comprobación de participante/MFA permanece dentro de la función privada.
commit;
