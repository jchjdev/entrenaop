begin;
create schema push_private;
revoke all on schema push_private from public,anon,authenticated;
grant usage on schema push_private to authenticated,service_role;
create table push_private.settings (
 singleton boolean primary key default true check(singleton),
 enabled boolean not null default false,
 firebase_project_id text,
 check(not enabled or (firebase_project_id is not null and firebase_project_id ~ '^[a-z][a-z0-9-]{4,62}$'))
);
insert into push_private.settings(singleton) values(true);
create table push_private.owners (
 owner_id uuid primary key references public.profiles(id) on delete cascade,
 revision bigint not null default 0 check(revision>=0), window_at timestamptz not null default now(), writes integer not null default 0 check(writes between 0 and 30)
);
create table push_private.installations (
 id uuid primary key, owner_id uuid not null references public.profiles(id) on delete cascade,
 secret_hash text not null check(secret_hash ~ '^[a-f0-9]{64}$'), binding_id uuid not null, platform text not null check(platform in ('ios','android')),
 token text check(octet_length(token)<=4096), token_hash text unique check(token_hash is null or token_hash ~ '^[a-f0-9]{64}$'),
 active boolean not null default true, last_seen timestamptz not null default now(),
 check(not active or (token is not null and token_hash is not null))
);
create index push_installations_owner on push_private.installations(owner_id);
-- Un único trabajo por dispositivo reúne las novedades: no envía un HTTP por
-- cada mensaje. La generación permite novedades durante un envío ya reclamado.
create table push_private.outbox (
 installation_id uuid primary key references push_private.installations(id) on delete cascade,
 owner_id uuid not null, generation bigint not null default 1,
 delivered_generation bigint not null default 0,
 next_at timestamptz not null default now(), attempts integer not null default 0,
 claim_id uuid, lease_until timestamptz, lease_generation bigint,
 check(generation>0 and delivered_generation between 0 and generation and attempts between 0 and 8),
 check((claim_id is null)=(lease_until is null) and (claim_id is null)=(lease_generation is null)),
 check(lease_generation is null or lease_generation between 1 and generation)
);
create index push_outbox_due on push_private.outbox(next_at,installation_id)
 where generation>delivered_generation and attempts<8;
do $$declare t text;begin
 foreach t in array array['settings','owners','installations','outbox'] loop
  execute format('alter table push_private.%I enable row level security',t);
  execute format('revoke all on push_private.%I from public,anon,authenticated',t);
 end loop;
end $$;

create function push_private.identity(p_expected_owner uuid) returns void
language plpgsql stable security definer set search_path='' as $$begin
 perform trainer_private.require_student_notice_owner(p_expected_owner);
end $$;
create function push_private.lock_owner(p_expected_owner uuid) returns void
language plpgsql security definer set search_path='' as $$begin
 perform push_private.identity(p_expected_owner);
 perform 1 from public.profiles where id=auth.uid() for key share;
 if not found then raise insufficient_privilege;end if;
 insert into push_private.owners(owner_id) values(auth.uid()) on conflict(owner_id)
  do update set revision=push_private.owners.revision+1;
end $$;
create function push_private.configuration(p_expected_owner uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$begin
 perform push_private.identity(p_expected_owner);
 return (select jsonb_build_object('enabled',enabled,'firebase_project_id',firebase_project_id) from push_private.settings where singleton);
end $$;
create function push_private.device_state(p_expected_owner uuid,p_id uuid,p_secret text) returns jsonb
language plpgsql stable security definer set search_path='' as $$declare d push_private.installations;begin
 perform push_private.identity(p_expected_owner);
 if p_id is null or p_secret is null or p_secret !~ '^[a-f0-9]{64}$' then raise invalid_parameter_value;end if;
 select * into d from push_private.installations where id=p_id;
 if not found then return null;end if;
 if d.secret_hash<>encode(extensions.digest(p_secret,'sha256'),'hex') then raise insufficient_privilege;end if;
 return jsonb_build_object('binding_id',d.binding_id,'owned',d.owner_id=auth.uid(),'active',d.active);
end $$;
create function push_private.register_device(p_expected_owner uuid,p_id uuid,p_secret text,p_binding_id uuid,p_previous_binding uuid,p_token text,p_platform text) returns jsonb
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
  or (d.id is null and (select count(*) from push_private.installations where owner_id=auth.uid())>=20) then raise program_limit_exceeded;end if;
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
create function push_private.unregister_device(p_expected_owner uuid,p_id uuid,p_secret text,p_binding_id uuid) returns void
language plpgsql security definer set search_path='' as $$declare d push_private.installations;begin
 perform push_private.lock_owner(p_expected_owner);
 if p_id is null or p_binding_id is null or p_secret is null or p_secret !~ '^[a-f0-9]{64}$' then raise invalid_parameter_value;end if;
 select * into d from push_private.installations where id=p_id for update;
 if not found then return;end if;
 if d.owner_id<>auth.uid() or d.secret_hash<>encode(extensions.digest(p_secret,'sha256'),'hex') or d.binding_id is distinct from p_binding_id then raise insufficient_privilege;end if;
 update push_private.installations set active=false,token=null,token_hash=null where id=p_id;
 update push_private.outbox set delivered_generation=generation,claim_id=null,lease_until=null,lease_generation=null where installation_id=p_id;
end $$;

create function push_private.capture_notice() returns trigger
language plpgsql security definer set search_path='' as $$declare d push_private.installations;begin
 if new.read_at is not null or not exists(select 1 from push_private.settings where singleton and enabled) then return new;end if;
 for d in select * from push_private.installations where owner_id=new.owner_id and active
  and last_seen>clock_timestamp()-interval '90 days' order by id for update loop
  insert into push_private.outbox(installation_id,owner_id,next_at) values(d.id,d.owner_id,clock_timestamp()+interval '5 seconds')
   on conflict(installation_id) do update set generation=outbox.generation+1,owner_id=excluded.owner_id,
    next_at=least(outbox.next_at,excluded.next_at),attempts=0;
 end loop;
 return new;
end $$;
create trigger student_notice_push after insert on trainer_private.student_notices for each row execute function push_private.capture_notice();

create function push_private.claim_jobs(p_limit integer) returns jsonb
language plpgsql security definer set search_path='' as $$declare result jsonb;begin
 if p_limit is null or p_limit not between 1 and 20 then raise invalid_parameter_value;end if;
 if not exists(select 1 from push_private.settings where singleton and enabled) then return '[]';end if;
 with candidates as (
  select q.installation_id from push_private.outbox q join push_private.installations d on d.id=q.installation_id
  where q.generation>q.delivered_generation and q.attempts<8 and q.next_at<=clock_timestamp()
   and (q.lease_until is null or q.lease_until<clock_timestamp()) and d.active and d.owner_id=q.owner_id
   and d.last_seen>clock_timestamp()-interval '90 days'
  order by q.next_at,q.installation_id limit p_limit for update of q skip locked
 ), claimed as (
  update push_private.outbox q set claim_id=gen_random_uuid(),lease_until=clock_timestamp()+interval '2 minutes',lease_generation=q.generation
   from candidates c where c.installation_id=q.installation_id returning q.*
 ) select coalesce(jsonb_agg(jsonb_build_object('installation_id',c.installation_id,'claim_id',c.claim_id,'generation',c.lease_generation,
   'binding_id',d.binding_id,'token',d.token,'platform',d.platform)),'[]') into result
 from claimed c join push_private.installations d on d.id=c.installation_id;
 return result;
end $$;
create function push_private.prepare_job(p_id uuid,p_claim uuid,p_generation bigint,p_binding uuid) returns boolean
language sql stable security definer set search_path='' as $$
 select exists(select 1 from push_private.outbox q join push_private.installations d on d.id=q.installation_id
  where q.installation_id=p_id and q.claim_id=p_claim and q.lease_generation=p_generation and q.lease_until>statement_timestamp()
   and d.binding_id=p_binding and d.active and d.owner_id=q.owner_id
   and exists(select 1 from push_private.settings where singleton and enabled)
   and exists(select 1 from trainer_private.student_notices n join public.trainer_client_relations r on r.id=n.relation_id
    join public.trainer_access a on a.trainer_id=r.trainer_id
    where n.owner_id=d.owner_id and n.read_at is null and n.created_at>statement_timestamp()-interval '24 hours' and r.client_id=d.owner_id and r.ended_at is null
     and a.enabled and (a.valid_until is null or a.valid_until>statement_timestamp())));
$$;
create function push_private.finish_job(p_id uuid,p_claim uuid,p_generation bigint,p_binding uuid,p_outcome text) returns void
language plpgsql security definer set search_path='' as $$declare q push_private.outbox;begin
 if p_outcome is null or p_outcome not in ('sent','skipped','retry','invalid') then raise invalid_parameter_value;end if;
 select * into q from push_private.outbox where installation_id=p_id for update;
 if not found or q.claim_id is distinct from p_claim or q.lease_generation is distinct from p_generation or q.lease_until<=clock_timestamp() then return;end if;
 if not exists(select 1 from push_private.installations where id=p_id and binding_id=p_binding and owner_id=q.owner_id) then return;end if;
 -- El worker no bloquea instalación después de la cola: alta/aviso siguen el
 -- orden instalación→cola. Un token inválido se retira con CAS en otra llamada.
 update push_private.outbox set delivered_generation=case when p_outcome in ('sent','skipped','invalid') then greatest(delivered_generation,p_generation) else delivered_generation end,
  attempts=case when p_outcome='retry' then least(attempts+1,8) else 0 end,
  next_at=clock_timestamp()+make_interval(secs=>case when p_outcome='retry' then least(21600,60*power(2,attempts)::integer) else 5 end),
  claim_id=null,lease_until=null,lease_generation=null where installation_id=p_id;
end $$;
create function push_private.retire_invalid_device(p_id uuid,p_binding uuid) returns void
language plpgsql security definer set search_path='' as $$begin
 update push_private.installations set active=false,token=null,token_hash=null where id=p_id and binding_id=p_binding;
end $$;
create function push_private.worker_configuration() returns jsonb
language sql stable security definer set search_path='' as $$select jsonb_build_object('enabled',enabled,'firebase_project_id',firebase_project_id) from push_private.settings where singleton$$;

create function public.get_my_push_configuration(p_expected_owner uuid) returns jsonb language sql stable security invoker set search_path='' as $$select push_private.configuration(p_expected_owner)$$;
create function public.get_my_push_device(p_expected_owner uuid,p_id uuid,p_secret text) returns jsonb language sql stable security invoker set search_path='' as $$select push_private.device_state(p_expected_owner,p_id,p_secret)$$;
create function public.register_my_push_device(p_expected_owner uuid,p_id uuid,p_secret text,p_binding_id uuid,p_previous_binding uuid,p_token text,p_platform text) returns jsonb language sql security invoker set search_path='' as $$select push_private.register_device(p_expected_owner,p_id,p_secret,p_binding_id,p_previous_binding,p_token,p_platform)$$;
create function public.unregister_my_push_device(p_expected_owner uuid,p_id uuid,p_secret text,p_binding_id uuid) returns void language sql security invoker set search_path='' as $$select push_private.unregister_device(p_expected_owner,p_id,p_secret,p_binding_id)$$;
create function public.claim_student_push_jobs(p_limit integer) returns jsonb language sql security invoker set search_path='' as $$select push_private.claim_jobs(p_limit)$$;
create function public.prepare_student_push_job(p_id uuid,p_claim uuid,p_generation bigint,p_binding uuid) returns boolean language sql stable security invoker set search_path='' as $$select push_private.prepare_job(p_id,p_claim,p_generation,p_binding)$$;
create function public.finish_student_push_job(p_id uuid,p_claim uuid,p_generation bigint,p_binding uuid,p_outcome text) returns void language sql security invoker set search_path='' as $$select push_private.finish_job(p_id,p_claim,p_generation,p_binding,p_outcome)$$;
create function public.retire_invalid_push_device(p_id uuid,p_binding uuid) returns void language sql security invoker set search_path='' as $$select push_private.retire_invalid_device(p_id,p_binding)$$;
create function public.get_student_push_worker_configuration() returns jsonb language sql stable security invoker set search_path='' as $$select push_private.worker_configuration()$$;
do $$declare f record;begin
 for f in select p.oid::regprocedure signature,p.proname from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='push_private' or (n.nspname='public' and p.proname in ('get_my_push_configuration','get_my_push_device','register_my_push_device','unregister_my_push_device',
    'claim_student_push_jobs','prepare_student_push_job','finish_student_push_job','retire_invalid_push_device','get_student_push_worker_configuration')) loop
  execute format('revoke all on function %s from public,anon,authenticated,service_role',f.signature);
  if f.proname in ('configuration','device_state','register_device','unregister_device','get_my_push_configuration','get_my_push_device','register_my_push_device','unregister_my_push_device') then
   execute format('grant execute on function %s to authenticated',f.signature);
  elsif f.proname in ('claim_jobs','prepare_job','finish_job','retire_invalid_device','worker_configuration',
    'claim_student_push_jobs','prepare_student_push_job','finish_student_push_job','retire_invalid_push_device','get_student_push_worker_configuration') then
   execute format('grant execute on function %s to service_role',f.signature);
  end if;
 end loop;
end $$;
commit;
