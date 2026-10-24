begin;
-- Una instalación de otra cuenta también consume un nuevo registro del destino.
-- Conserva recibos propios, CAS, límite activo, grants y bloqueo del propietario.
create or replace function push_private.register_device(p_expected_owner uuid,p_id uuid,p_secret text,p_binding_id uuid,p_previous_binding uuid,p_token text,p_platform text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare d push_private.installations;lim push_private.owners;secret_digest text;token_digest text;
begin
 perform push_private.lock_owner(p_expected_owner);
 if not exists(select 1 from push_private.settings where singleton and enabled) then raise exception 'Avisos no disponibles.' using errcode='55000';end if;
 if p_id is null or p_binding_id is null or p_secret is null or p_secret !~ '^[a-f0-9]{64}$'
  or p_token is null or octet_length(p_token) not between 20 and 4096 or p_token ~ '[[:space:][:cntrl:]]'
  or p_platform is null or p_platform not in ('ios','android') then raise invalid_parameter_value;end if;
 secret_digest:=encode(extensions.digest(p_secret,'sha256'),'hex');token_digest:=encode(extensions.digest(p_token,'sha256'),'hex');
 select * into d from push_private.installations where id=p_id for update;
 if found then
  if d.secret_hash<>secret_digest then raise insufficient_privilege;end if;
  -- Una respuesta perdida no crea otra asociación si ya se confirmó lo mismo.
  if d.owner_id=auth.uid() and d.active and d.token=p_token and d.platform=p_platform then
   update push_private.installations set last_seen=clock_timestamp() where id=p_id;
   return jsonb_build_object('binding_id',d.binding_id);end if;
  if d.binding_id is distinct from p_previous_binding then raise serialization_failure;end if;
 elsif p_previous_binding is not null then raise serialization_failure;
 end if;
 if exists(select 1 from push_private.installations where installations.token_hash=token_digest and id<>p_id) then raise insufficient_privilege;end if;
 if (select count(*) from push_private.installations where owner_id=auth.uid() and active and id<>p_id)>=5
  or ((d.id is null or d.owner_id<>auth.uid()) and (select count(*) from push_private.installations where owner_id=auth.uid())>=20) then raise program_limit_exceeded;end if;
 select * into lim from push_private.owners where owner_id=auth.uid();
 if lim.window_at<=clock_timestamp()-interval '1 hour' then lim.window_at:=clock_timestamp();lim.writes:=0;end if;
 if lim.writes>=30 then raise program_limit_exceeded;end if;
 update push_private.owners set window_at=lim.window_at,writes=lim.writes+1 where owner_id=auth.uid();
 insert into push_private.installations(id,owner_id,secret_hash,binding_id,platform,token,token_hash)
  values(p_id,auth.uid(),secret_digest,p_binding_id,p_platform,p_token,token_digest)
  on conflict(id) do update set owner_id=excluded.owner_id,binding_id=excluded.binding_id,platform=excluded.platform,
   token=excluded.token,token_hash=excluded.token_hash,active=true,last_seen=clock_timestamp();
 insert into push_private.outbox(installation_id,owner_id,next_at) values(p_id,auth.uid(),clock_timestamp()+interval '5 seconds')
  on conflict(installation_id) do update set owner_id=excluded.owner_id,generation=outbox.generation+1,next_at=excluded.next_at,
   attempts=0,claim_id=null,lease_until=null,lease_generation=null;
 return jsonb_build_object('binding_id',p_binding_id);
end $$;
commit;
