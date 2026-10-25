begin;
set local statement_timeout='90s';
do $$
declare owner uuid:=gen_random_uuid();device uuid:=gen_random_uuid();ticket text:=repeat('T',43);
 request_id bigint;queued_headers jsonb;public_jwt text;vault_id uuid;
begin
 if has_function_privilege('anon','public.consume_student_push_dispatch_ticket(text)','execute')
   or has_function_privilege('authenticated','public.consume_student_push_dispatch_ticket(text)','execute')
   or has_function_privilege('service_role','push_private.dispatch_due_dev()','execute') then
   raise exception 'Permisos excesivos del programador';end if;
 update push_private.settings set enabled=true,firebase_project_id='entrenaop-dev',dispatch_ticket_used=false,
   dispatch_ticket_hash=encode(sha256(convert_to(ticket,'UTF8')),'hex'),
   dispatch_ticket_expires_at=clock_timestamp()+interval '55 seconds' where singleton;
 set local role service_role;
 if public.consume_student_push_dispatch_ticket('invalid') then raise exception 'Acepta ticket mal formado';end if;
 if not public.consume_student_push_dispatch_ticket(ticket) then raise exception 'Rechaza ticket válido';end if;
 if public.consume_student_push_dispatch_ticket(ticket) then raise exception 'Repite ticket consumido';end if;
 reset role;
 update push_private.settings set dispatch_ticket_used=false,dispatch_ticket_expires_at=clock_timestamp()-interval '1 second';
 set local role service_role;
 if public.consume_student_push_dispatch_ticket(ticket) then raise exception 'Acepta ticket caducado';end if;
 reset role;
 insert into auth.users(id,email) values(owner,owner||'@push-scheduler.invalid');
 insert into push_private.installations(id,owner_id,secret_hash,binding_id,platform,token,token_hash)
 values(device,owner,repeat('a',64),gen_random_uuid(),'android',device::text,encode(sha256(convert_to(device::text,'UTF8')),'hex'));
 insert into push_private.outbox(installation_id,owner_id,next_at) values(device,owner,clock_timestamp()-interval '1 second');
 insert into push_private.preferences(owner_id,quiet_enabled,timezone) values(owner,false,'UTC');
 insert into push_private.notice_jobs(installation_id,owner_id,kind,scope_key,next_at) values(device,owner,'other','scheduler-fixture',clock_timestamp()-interval '1 second');
 select id,decrypted_secret into vault_id,public_jwt from vault.decrypted_secrets where name='student_push_dev_public_jwt';
 if vault_id is null then
   perform vault.create_secret('public-fixture-jwt','student_push_dev_public_jwt');public_jwt:='public-fixture-jwt';
 end if;
 request_id:=push_private.dispatch_due_dev();
 if request_id is null then raise exception 'No despacha trabajo elegible';end if;
 select headers into queued_headers from net.http_request_queue where id=request_id;
 if queued_headers->>'Authorization' is distinct from 'Bearer '||public_jwt
   or queued_headers ? 'X-EntrenaOP-Push-Worker'
   or queued_headers->>'X-EntrenaOP-Push-Ticket' !~ '^[A-Za-z0-9_-]{43}$' then
   raise exception 'La cola contiene credenciales incorrectas';end if;
 if push_private.dispatch_due_dev() is not null then raise exception 'Duplica un despacho en curso';end if;
 ticket:=queued_headers->>'X-EntrenaOP-Push-Ticket';
 set local role service_role;
 if not public.consume_student_push_dispatch_ticket(ticket) then raise exception 'No consume ticket despachado';end if;
 if public.consume_student_push_dispatch_ticket(ticket) then raise exception 'Repite ticket despachado';end if;
 reset role;
 update push_private.settings set enabled=false;
 if push_private.dispatch_due_dev() is not null then raise exception 'Despacha estando apagado';end if;
end $$;
select 'student_push_scheduler: OK' as result;
rollback;
