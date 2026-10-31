begin;

alter table directory_private.settings add column contact_enabled boolean not null default false;
alter table directory_private.profiles add column app_contact_enabled boolean not null default false;

-- Es otro contexto del mismo chat: no se crean un servicio ni una tabla de mensajes nuevos.
create table trainer_private.contact_threads (
 id uuid primary key,
 profile_id uuid not null references directory_private.profiles(id) on delete restrict,
 requester_id uuid not null references public.profiles(id) on delete restrict,
 trainer_id uuid not null references public.profiles(id) on delete restrict,
 state text not null default 'pending' check(state in('pending','accepted','declined','blocked')),
 relation_id uuid references public.trainer_client_relations(id) on delete restrict,
 notice_version integer not null check(notice_version=1),
 created_at timestamptz not null default statement_timestamp(),
 updated_at timestamptz not null default statement_timestamp(),
 check(requester_id<>trainer_id), unique(trainer_id,requester_id)
);
create index contact_threads_requester on trainer_private.contact_threads(requester_id,created_at desc,id desc);
create index contact_threads_trainer on trainer_private.contact_threads(trainer_id,created_at desc,id desc);
create index contact_threads_profile on trainer_private.contact_threads(profile_id);
create index contact_threads_relation on trainer_private.contact_threads(relation_id);
alter table trainer_private.contact_threads enable row level security;
revoke all on trainer_private.contact_threads from public,anon,authenticated,service_role;

alter table trainer_private.messages alter column relation_id drop not null;
alter table trainer_private.messages add column contact_id uuid references trainer_private.contact_threads(id) on delete restrict;
alter table trainer_private.messages add constraint message_context
 check((relation_id is not null and contact_id is null) or (relation_id is null and contact_id is not null and assignment_id is null));
create index trainer_messages_contact_page on trainer_private.messages(contact_id,created_at desc,id desc) where contact_id is not null;

create or replace function directory_private.profile_json(p directory_private.profiles) returns jsonb
language sql stable security definer set search_path='' as $$
 select jsonb_build_object('id',p.id,'name',p.name,'description',p.description,'specialties',p.specialties,'services',p.services,
 'mode',p.mode,'city',p.city,'visibility',p.visibility,'photo_path',p.photo_path,'email',p.email,'website',p.website,
 'whatsapp',p.whatsapp,'price',p.price,'accepting',p.accepting,
 'app_contact_enabled',p.app_contact_enabled and (select contact_enabled from directory_private.settings where singleton),
 'is_owner',p.trainer_id=auth.uid(),
 'favorite',exists(select 1 from directory_private.favorites f where f.owner_id=auth.uid() and f.profile_id=p.id))
$$;

-- Mantiene la RPC y todas sus validaciones; los clientes anteriores conservan el valor vigente.
do $migration$
declare d text; original text;
begin
 original:=pg_get_functiondef('directory_private.save(uuid,integer,jsonb,boolean,boolean)'::regprocedure);
 d:=replace(original,'price,accepting,published,consent_at','price,accepting,app_contact_enabled,published,consent_at');
 d:=replace(d,$anchor$(p_data->>'accepting')::boolean,p_published$anchor$, $replacement$(p_data->>'accepting')::boolean,coalesce((p_data->>'app_contact_enabled')::boolean,p.app_contact_enabled,false),p_published$replacement$);
 d:=replace(d,'accepting=excluded.accepting,published=', 'accepting=excluded.accepting,app_contact_enabled=excluded.app_contact_enabled,published=');
 if d=original or position('app_contact_enabled=excluded' in d)=0 then raise exception 'Contrato de guardado no reconocido';end if;
 execute d;
end $migration$;

do $migration$
declare d text; original text;
begin
 original:=pg_get_functiondef('trainer_private.send_message(uuid,uuid,text,uuid)'::regprocedure);
 d:=replace(original,'prior.relation_id<>p_relation_id','prior.relation_id is distinct from p_relation_id');
 if d=original then raise exception 'Contrato de envío no reconocido';end if;
 execute d;
end $migration$;

create function trainer_private.contact_member(p_id uuid) returns trainer_private.contact_threads
language plpgsql stable security definer set search_path='' as $$
declare t trainer_private.contact_threads;
begin
 if not directory_private.member() then raise insufficient_privilege;end if;
 select * into t from trainer_private.contact_threads where id=p_id and auth.uid() in(requester_id,trainer_id);
 if not found or (t.trainer_id=auth.uid() and not trainer_private.has_trainer_mfa()) then raise insufficient_privilege;end if;
 return t;
end $$;

create function trainer_private.contact_json(t trainer_private.contact_threads) returns jsonb
language sql stable security definer set search_path='' as $$
 select jsonb_build_object('id',t.id,'profile_id',t.profile_id,'requester_id',t.requester_id,'relation_id',t.relation_id,
 'state',t.state,'is_trainer',t.trainer_id=auth.uid(),
 'name',case when auth.uid()=t.trainer_id then coalesce((select nullif(btrim(p.full_name),'') from public.profiles p
   where p.id=t.requester_id),'Contacto') else (select name from directory_private.profiles where id=t.profile_id) end,
 'can_send',t.state='accepted' and t.relation_id is null
   and exists(select 1 from public.trainer_access a where a.trainer_id=t.trainer_id and a.enabled
     and (a.valid_until is null or a.valid_until>statement_timestamp()))
   and exists(select 1 from directory_private.profiles p where p.id=t.profile_id and not p.suspended),
 'created_at',t.created_at,'updated_at',t.updated_at)
$$;

create function trainer_private.contact_context(p_id uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare t trainer_private.contact_threads;
begin t:=trainer_private.contact_member(p_id);return trainer_private.contact_json(t);end $$;

create function trainer_private.contact_open(p_profile uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare p directory_private.profiles; t trainer_private.contact_threads; r uuid;
begin
 if not directory_private.member() then raise insufficient_privilege;end if;
 select * into p from directory_private.profiles where id=p_profile;
 if not found or p.trainer_id=auth.uid() then raise insufficient_privilege;end if;
 select id into r from public.trainer_client_relations where trainer_id=p.trainer_id and client_id=auth.uid() and ended_at is null;
 if r is not null then return jsonb_build_object('relation_id',r);end if;
 select * into t from trainer_private.contact_threads where profile_id=p.id and requester_id=auth.uid();
 if found then return trainer_private.contact_context(t.id);end if;
 if not directory_private.can_read(p.id,false) or not p.accepting or not p.app_contact_enabled
   or not (select contact_enabled from directory_private.settings where singleton) then raise insufficient_privilege;end if;
 return jsonb_build_object('profile_id',p.id,'name',p.name,'state','new','can_send',true,'is_trainer',false);
end $$;

create function trainer_private.contact_request(p_id uuid,p_profile uuid,p_body text,p_notice integer) returns jsonb
language plpgsql security definer set search_path='' as $$
declare p directory_private.profiles; t trainer_private.contact_threads; prior trainer_private.messages; r uuid;
begin
 if not directory_private.member() then raise insufficient_privilege;end if;
 if p_id is null or p_body is null or length(btrim(p_body)) not between 1 and 4000 or p_notice is distinct from 1 then raise invalid_parameter_value;end if;
 perform pg_advisory_xact_lock(hashtextextended('trainer-client:'||auth.uid()::text,0));
 select * into t from trainer_private.contact_threads where id=p_id;
 if found then
   select * into prior from trainer_private.messages where id=p_id;
   if t.requester_id<>auth.uid() or t.profile_id<>p_profile or prior.sender_id is distinct from auth.uid()
     or prior.body is distinct from btrim(p_body) then raise invalid_parameter_value;end if;
   return trainer_private.contact_json(t);
 end if;
 select * into p from directory_private.profiles where id=p_profile;
 if not found or p.trainer_id=auth.uid() then raise insufficient_privilege;end if;
 select * into t from trainer_private.contact_threads where trainer_id=p.trainer_id and requester_id=auth.uid();
 -- Otra pestaña puede haber iniciado el contacto: nunca confirmar como enviado
 -- un texto distinto que no se ha guardado.
 if found then raise object_not_in_prerequisite_state;end if;
 select id into r from public.trainer_client_relations where trainer_id=p.trainer_id and client_id=auth.uid() and ended_at is null;
 if r is not null then
   perform trainer_private.send_message(p_id,r,p_body);
   return jsonb_build_object('relation_id',r);
 end if;
 if not directory_private.can_read(p.id,false) or not p.accepting or not p.app_contact_enabled
   or not (select contact_enabled from directory_private.settings where singleton) then raise insufficient_privilege;end if;
 if (select count(*) from trainer_private.contact_threads where requester_id=auth.uid()
     and created_at>statement_timestamp()-interval '1 day')>=5 then
   raise exception 'Has alcanzado el límite de cinco primeros contactos al día.' using errcode='54000';end if;
 perform pg_advisory_xact_lock(hashtextextended('trainer-message-sender:'||auth.uid()::text,0));
 if (select count(*) from trainer_private.messages where sender_id=auth.uid() and created_at>statement_timestamp()-interval '1 hour')>=100 then
   raise exception 'Has enviado muchos mensajes. Espera antes de volver a intentarlo.' using errcode='54000';end if;
 insert into trainer_private.message_sender_versions(sender_id,revision) values(auth.uid(),1)
   on conflict(sender_id) do update set revision=message_sender_versions.revision+1;
 insert into trainer_private.contact_threads(id,profile_id,requester_id,trainer_id,notice_version)
   values(p_id,p.id,auth.uid(),p.trainer_id,p_notice) returning * into t;
 insert into trainer_private.messages(id,contact_id,sender_id,body) values(p_id,t.id,auth.uid(),btrim(p_body));
 return trainer_private.contact_json(t);
end $$;

create function trainer_private.contact_decide(p_id uuid,p_action text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare t trainer_private.contact_threads;
begin
 t:=trainer_private.contact_member(p_id);
 perform pg_advisory_xact_lock(hashtextextended('trainer-client:'||t.requester_id::text,0));
 select * into t from trainer_private.contact_threads where id=t.id for update;
 if p_action is null or p_action not in('accepted','declined','blocked') then raise invalid_parameter_value;end if;
 if t.relation_id is not null then raise insufficient_privilege;end if;
 if p_action<>'blocked' and (auth.uid()<>t.trainer_id or t.state not in('pending',p_action)) then raise insufficient_privilege;end if;
 if p_action='accepted' then
   perform trainer_private.require_authoring_access();
   if exists(select 1 from directory_private.profiles where id=t.profile_id and suspended) then raise insufficient_privilege;end if;
 end if;
 if t.state='blocked' and p_action<>'blocked' then raise insufficient_privilege;end if;
 update trainer_private.contact_threads set state=p_action,updated_at=statement_timestamp() where id=t.id returning * into t;
 return trainer_private.contact_json(t);
end $$;

create function trainer_private.contact_send(p_id uuid,p_contact uuid,p_body text) returns void
language plpgsql security definer set search_path='' as $$
declare t trainer_private.contact_threads; prior trainer_private.messages;
begin
 t:=trainer_private.contact_member(p_contact);
 perform pg_advisory_xact_lock(hashtextextended('trainer-client:'||t.requester_id::text,0));
 perform pg_advisory_xact_lock(hashtextextended('trainer-message-sender:'||auth.uid()::text,0));
 select * into t from trainer_private.contact_threads where id=t.id for update;
 select * into prior from trainer_private.messages where id=p_id;
 if found then
   if prior.sender_id<>auth.uid() or prior.body is distinct from btrim(p_body)
     or not coalesce(prior.contact_id=t.id or (prior.assignment_id is null and exists(
       select 1 from public.trainer_client_relations r where r.id=prior.relation_id
         and r.trainer_id=t.trainer_id and r.client_id=t.requester_id)),false) then raise invalid_parameter_value;end if;
   return;
 end if;
 if t.relation_id is not null then perform trainer_private.send_message(p_id,t.relation_id,p_body);return;end if;
 if (trainer_private.contact_json(t)->>'can_send')::boolean is not true then raise insufficient_privilege;end if;
 if t.trainer_id=auth.uid() then perform trainer_private.require_authoring_access();end if;
 if p_id is null or p_body is null or length(btrim(p_body)) not between 1 and 4000 then raise invalid_parameter_value;end if;
 if (select count(*) from trainer_private.messages where sender_id=auth.uid() and created_at>statement_timestamp()-interval '1 hour')>=100 then
   raise exception 'Has enviado muchos mensajes. Espera antes de volver a intentarlo.' using errcode='54000';end if;
 insert into trainer_private.message_sender_versions(sender_id,revision) values(auth.uid(),1)
   on conflict(sender_id) do update set revision=message_sender_versions.revision+1;
 insert into trainer_private.messages(id,contact_id,sender_id,body) values(p_id,t.id,auth.uid(),btrim(p_body));
 update trainer_private.contact_threads set updated_at=statement_timestamp() where id=t.id;
end $$;

create function trainer_private.contact_messages(p_contact uuid,p_before_at timestamptz default null,p_before_id uuid default null) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare t trainer_private.contact_threads;
begin
 t:=trainer_private.contact_member(p_contact);
 if t.relation_id is not null then return trainer_private.list_messages(t.relation_id,p_before_at,p_before_id);end if;
 if (p_before_at is null)<>(p_before_id is null) then raise invalid_parameter_value;end if;
 return (select coalesce(jsonb_agg(to_jsonb(page) order by created_at desc,id desc),'[]'::jsonb) from
   (select id,sender_id,body,created_at from trainer_private.messages where contact_id=t.id
    and (p_before_at is null or (created_at,id)<(p_before_at,p_before_id)) order by created_at desc,id desc limit 50) page);
end $$;

create function trainer_private.contact_inbox(p_before_at timestamptz default null,p_before_id uuid default null) returns jsonb
language plpgsql stable security definer set search_path='' as $$
begin
 if not directory_private.member() then raise insufficient_privilege;end if;
 if (p_before_at is null)<>(p_before_id is null) then raise invalid_parameter_value;end if;
 return jsonb_build_object('pending_count',(select count(*) from trainer_private.contact_threads
     where trainer_id=auth.uid() and state='pending' and trainer_private.has_trainer_mfa()),
   'items',(select coalesce(jsonb_agg(trainer_private.contact_json(page::trainer_private.contact_threads) order by page.created_at desc,page.id desc),'[]'::jsonb)
     from (select * from trainer_private.contact_threads where
       (requester_id=auth.uid() or (trainer_id=auth.uid() and trainer_private.has_trainer_mfa()))
       and (p_before_at is null or (created_at,id)<(p_before_at,p_before_id)) order by created_at desc,id desc limit 50) page));
end $$;

create function trainer_private.contact_read(p_contact uuid,p_ids uuid[]) returns void
language plpgsql security definer set search_path='' as $$
declare t trainer_private.contact_threads;
begin
 t:=trainer_private.contact_member(p_contact);
 if auth.uid()<>t.trainer_id or p_ids is null or cardinality(p_ids)>50 then raise insufficient_privilege;end if;
 if exists(select 1 from unnest(p_ids) i where not exists(select 1 from trainer_private.messages m where m.id=i
   and m.sender_id=t.requester_id and (m.contact_id=t.id or (t.relation_id is not null and m.relation_id=t.relation_id)))) then raise insufficient_privilege;end if;
 insert into trainer_private.message_reads(trainer_id,message_id)
   select auth.uid(),i from unnest(p_ids) i on conflict do nothing;
end $$;

-- La denuncia del preparador reutiliza la bandeja y moderación del directorio.
create function trainer_private.contact_report(p_id uuid,p_reason text,p_details text) returns void
language plpgsql security definer set search_path='' as $$
declare t trainer_private.contact_threads;
begin
 t:=trainer_private.contact_member(p_id);
 if auth.uid()<>t.requester_id then raise insufficient_privilege;end if;
 if p_reason is null or p_reason not in('explicit','harassment','impersonation','spam','misleading','other')
   or p_details is null or length(p_details)>850 then raise invalid_parameter_value;end if;
 perform pg_advisory_xact_lock(hashtextextended('directory-report:'||auth.uid()::text,0));
 if exists(select 1 from directory_private.reports where reporter_id=auth.uid() and profile_id=t.profile_id and status='pending') then return;end if;
 if (select count(*) from directory_private.reports where reporter_id=auth.uid() and created_at>statement_timestamp()-interval '1 day')>=10 then raise insufficient_privilege;end if;
 insert into directory_private.reports(reporter_id,profile_id,reason,details)
   values(auth.uid(),t.profile_id,p_reason,'Conversación de contacto '||t.id::text||E'\n'||btrim(p_details));
end $$;

create function trainer_private.promote_contact() returns trigger
language plpgsql security definer set search_path='' as $$
declare t trainer_private.contact_threads;
begin
 if new.ended_at is not null or new.trainer_id=new.client_id then return new;end if;
 perform pg_advisory_xact_lock(hashtextextended('trainer-client:'||new.client_id::text,0));
 select * into t from trainer_private.contact_threads where trainer_id=new.trainer_id and requester_id=new.client_id
   and state in('pending','accepted') for update;
 if found then
   update trainer_private.messages set relation_id=new.id,contact_id=null where contact_id=t.id;
   update trainer_private.contact_threads set relation_id=new.id,state='accepted',updated_at=statement_timestamp() where id=t.id;
 end if;
 return new;
end $$;
create trigger trainer_promote_contact after insert on public.trainer_client_relations for each row execute function trainer_private.promote_contact();

create function public.open_directory_contact(p_profile uuid) returns jsonb
language sql stable security invoker set search_path='' as $$select trainer_private.contact_open(p_profile)$$;
create function public.request_directory_contact(p_id uuid,p_profile uuid,p_body text,p_notice integer) returns jsonb
language sql security invoker set search_path='' as $$select trainer_private.contact_request(p_id,p_profile,p_body,p_notice)$$;
create function public.get_directory_contact(p_id uuid) returns jsonb
language sql stable security invoker set search_path='' as $$select trainer_private.contact_context(p_id)$$;
create function public.decide_directory_contact(p_id uuid,p_action text) returns jsonb
language sql security invoker set search_path='' as $$select trainer_private.contact_decide(p_id,p_action)$$;
create function public.send_directory_contact_message(p_id uuid,p_contact uuid,p_body text) returns void
language sql security invoker set search_path='' as $$select trainer_private.contact_send(p_id,p_contact,p_body)$$;
create function public.list_directory_contact_messages(p_contact uuid,p_before_at timestamptz default null,p_before_id uuid default null) returns jsonb
language sql stable security invoker set search_path='' as $$select trainer_private.contact_messages(p_contact,p_before_at,p_before_id)$$;
create function public.list_directory_contacts(p_before_at timestamptz default null,p_before_id uuid default null) returns jsonb
language sql stable security invoker set search_path='' as $$select trainer_private.contact_inbox(p_before_at,p_before_id)$$;
create function public.report_directory_contact(p_id uuid,p_reason text,p_details text) returns void
language sql security invoker set search_path='' as $$select trainer_private.contact_report(p_id,p_reason,p_details)$$;
create function public.read_directory_contact_messages(p_contact uuid,p_ids uuid[]) returns void
language sql security invoker set search_path='' as $$select trainer_private.contact_read(p_contact,p_ids)$$;

revoke all on function trainer_private.contact_member(uuid),trainer_private.contact_json(trainer_private.contact_threads),trainer_private.promote_contact()
 from public,anon,authenticated,service_role;
revoke all on function trainer_private.contact_open(uuid),trainer_private.contact_request(uuid,uuid,text,integer),trainer_private.contact_context(uuid),
 trainer_private.contact_decide(uuid,text),trainer_private.contact_send(uuid,uuid,text),trainer_private.contact_messages(uuid,timestamptz,uuid),
 trainer_private.contact_inbox(timestamptz,uuid),trainer_private.contact_report(uuid,text,text) from public,anon,authenticated,service_role;
grant execute on function trainer_private.contact_open(uuid),trainer_private.contact_request(uuid,uuid,text,integer),trainer_private.contact_context(uuid),
 trainer_private.contact_decide(uuid,text),trainer_private.contact_send(uuid,uuid,text),trainer_private.contact_messages(uuid,timestamptz,uuid),
 trainer_private.contact_inbox(timestamptz,uuid),trainer_private.contact_report(uuid,text,text) to authenticated;
revoke all on function public.open_directory_contact(uuid),public.request_directory_contact(uuid,uuid,text,integer),public.get_directory_contact(uuid),
 public.decide_directory_contact(uuid,text),public.send_directory_contact_message(uuid,uuid,text),public.list_directory_contact_messages(uuid,timestamptz,uuid),
 public.list_directory_contacts(timestamptz,uuid),public.report_directory_contact(uuid,text,text) from public,anon,authenticated,service_role;
grant execute on function public.open_directory_contact(uuid),public.request_directory_contact(uuid,uuid,text,integer),public.get_directory_contact(uuid),
 public.decide_directory_contact(uuid,text),public.send_directory_contact_message(uuid,uuid,text),public.list_directory_contact_messages(uuid,timestamptz,uuid),
 public.list_directory_contacts(timestamptz,uuid),public.report_directory_contact(uuid,text,text) to authenticated;
revoke all on function trainer_private.contact_read(uuid,uuid[]),public.read_directory_contact_messages(uuid,uuid[]) from public,anon,authenticated,service_role;
grant execute on function trainer_private.contact_read(uuid,uuid[]),public.read_directory_contact_messages(uuid,uuid[]) to authenticated;
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
 ) || jsonb_build_object(
   'contact_pending_count',(select count(*) from trainer_private.contact_threads where trainer_id=auth.uid() and state='pending'),
   'contact_unread_count',(select count(*) from trainer_private.messages m join trainer_private.contact_threads t on t.id=m.contact_id
     where t.trainer_id=auth.uid() and m.sender_id=t.requester_id and not exists(
       select 1 from trainer_private.message_reads seen where seen.trainer_id=auth.uid() and seen.message_id=m.id))
 );
end $$;

commit;
