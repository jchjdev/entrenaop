begin;
-- pg_net pertenece a supabase_admin y mantiene concesiones administradas por
-- la plataforma. No depositar un secreto permanente en sus encabezados:
-- cada tick crea una capacidad de un uso, de corta duración y sin parámetros.
alter table device_private.training_sync_worker add column ticket_expires_at timestamptz,
 add column ticket_used boolean not null default true;
create function device_private.consume_training_sync_ticket(p_token text) returns boolean
language plpgsql security definer set search_path='' as $$
declare consumed boolean;
begin
 update device_private.training_sync_worker set ticket_used=true
  where enabled and not ticket_used and ticket_expires_at>clock_timestamp()
   and token_hash=encode(sha256(convert_to(p_token,'UTF8')),'hex') returning true into consumed;
 return coalesce(consumed,false);
end $$;
revoke all on function device_private.consume_training_sync_ticket(text) from public,anon,authenticated,service_role;
do $$declare definition text; anchor text;begin
 definition:=pg_get_functiondef('device_private.garmin_training_sync_command(text,jsonb)'::regprocedure);
 anchor:=$a$exists(select 1 from device_private.training_sync_worker
  where enabled and token_hash=encode(sha256(convert_to(p_input->>'token','UTF8')),'hex'))$a$;
 if strpos(definition,anchor)=0 then raise exception 'Revisar autenticación del trabajador';end if;
 definition:=replace(definition,anchor,$a$device_private.consume_training_sync_ticket(p_input->>'token')$a$);
 execute definition;
end $$;
create or replace function device_private.dispatch_training_sync_dev() returns bigint
language plpgsql security definer set search_path='' as $$
declare token text;
begin
 perform 1 from device_private.training_sync_worker where enabled for update;
 if not found then return null;end if;
 token:=rtrim(translate(encode(extensions.gen_random_bytes(32),'base64'),'+/','-_'),'=');
 update device_private.training_sync_worker set token_hash=encode(sha256(convert_to(token,'UTF8')),'hex'),
  ticket_expires_at=clock_timestamp()+interval '55 seconds',ticket_used=false;
 return net.http_post(url:='https://sxbxfjqgoddzhtcyhalw.supabase.co/functions/v1/garmin-training-sync',
  headers:=jsonb_build_object('Content-Type','application/json','Authorization','Bearer '||token),
  body:='{}'::jsonb,timeout_milliseconds:=55000);
end $$;
revoke all on function device_private.dispatch_training_sync_dev() from public,anon,authenticated,service_role;
commit;
