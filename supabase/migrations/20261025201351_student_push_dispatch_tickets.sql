begin;
-- pg_net recibe una capacidad de un uso y corta duración, nunca claves
-- permanentes de servicio ni del proveedor de notificaciones.
alter table push_private.settings
 add column dispatch_ticket_hash text,
 add column dispatch_ticket_expires_at timestamptz,
 add column dispatch_ticket_used boolean not null default true,
 add constraint push_dispatch_hash_shape check (
   dispatch_ticket_hash is null or dispatch_ticket_hash ~ '^[a-f0-9]{64}$'
 );
create function push_private.consume_dispatch_ticket(p_token text) returns boolean
language plpgsql security definer set search_path='' as $$
declare consumed boolean;
begin
 if p_token is null or p_token !~ '^[A-Za-z0-9_-]{43}$' then return false;end if;
 update push_private.settings set dispatch_ticket_used=true
 where singleton and enabled and firebase_project_id='entrenaop-dev'
   and not dispatch_ticket_used and dispatch_ticket_expires_at>clock_timestamp()
   and dispatch_ticket_hash=encode(sha256(convert_to(p_token,'UTF8')),'hex')
 returning true into consumed;
 return coalesce(consumed,false);
end $$;
revoke all on function push_private.consume_dispatch_ticket(text) from public,anon,authenticated;
grant execute on function push_private.consume_dispatch_ticket(text) to service_role;
create function public.consume_student_push_dispatch_ticket(p_token text) returns boolean
language sql security invoker set search_path='' as $$
 select push_private.consume_dispatch_ticket(p_token);
$$;
revoke all on function public.consume_student_push_dispatch_ticket(text) from public,anon,authenticated;
grant execute on function public.consume_student_push_dispatch_ticket(text) to service_role;
create function push_private.dispatch_due_dev() returns bigint
language plpgsql security definer set search_path='' as $$
declare ticket text; public_jwt text;
begin
 perform 1 from push_private.settings where singleton and enabled
   and firebase_project_id='entrenaop-dev' for update;
 if not found then return null;end if;
 if exists(select 1 from push_private.settings where singleton
   and not dispatch_ticket_used and dispatch_ticket_expires_at>clock_timestamp()) then return null;end if;
 if not exists(
   select 1 from push_private.outbox q join push_private.installations d on d.id=q.installation_id
   where q.generation>q.delivered_generation and q.attempts<8 and q.next_at<=clock_timestamp()
    and (q.lease_until is null or q.lease_until<clock_timestamp()) and d.active and d.owner_id=q.owner_id
    and d.last_seen>clock_timestamp()-interval '90 days'
 ) then return null;end if;
 select decrypted_secret into public_jwt from vault.decrypted_secrets where name='student_push_dev_public_jwt';
 if public_jwt is null then return null;end if;
 ticket:=rtrim(translate(encode(extensions.gen_random_bytes(32),'base64'),'+/','-_'),'=');
 update push_private.settings set dispatch_ticket_hash=encode(sha256(convert_to(ticket,'UTF8')),'hex'),
   dispatch_ticket_expires_at=clock_timestamp()+interval '55 seconds',dispatch_ticket_used=false where singleton;
 return net.http_post(url:='https://sxbxfjqgoddzhtcyhalw.supabase.co/functions/v1/student-push',
   headers:=jsonb_build_object('Content-Type','application/json','Authorization','Bearer '||public_jwt,
     'X-EntrenaOP-Push-Ticket',ticket),body:='{}'::jsonb,timeout_milliseconds:=55000);
end $$;
revoke all on function push_private.dispatch_due_dev() from public,anon,authenticated,service_role;
commit;
