begin;

-- La suspensión es una decisión administrativa; nunca una fuente comercial.
alter table public.trainer_access
 add column suspended boolean not null default false,
 add column suspended_at timestamptz,
 add column suspension_reason text check(char_length(suspension_reason) between 3 and 500),
 add column last_action text not null default 'manual' check(last_action in ('manual','suspension')),
 add constraint trainer_suspension_details check(
  (suspended and suspended_at is not null and suspension_reason is not null)
  or (not suspended and suspended_at is null and suspension_reason is null));

-- Se conserva la proyección única de cupo y vigencia. El último paso impide
-- que un webhook, una renovación o un regalo levanten el bloqueo.
do $migration$
declare definition text;
begin
 definition:=pg_get_functiondef('commerce_private.project_access()'::regprocedure);
 if strpos(definition,'new.commercial_refresh_at:=')=0 then
  raise exception 'Revisar la proyección comercial antes de migrar';end if;
 definition:=replace(definition,'new.commercial_refresh_at:=',
  'if new.suspended then new.enabled:=false; end if;'||chr(10)||' new.commercial_refresh_at:=');
 execute definition;
end $migration$;

-- MFA puro sigue sirviendo para autenticación y gestión del propio pago.
-- Las consultas y operaciones profesionales usan esta puerta común, también
-- con un JWT ya emitido. No se revocan las sesiones del deportista.
create function trainer_private.has_professional_session() returns boolean
language sql stable security definer set search_path='' as $$
 select trainer_private.has_trainer_mfa() and not exists(
  select 1 from public.trainer_access where trainer_id=auth.uid() and suspended);
$$;
revoke all on function trainer_private.has_professional_session() from public,anon,authenticated;
grant execute on function trainer_private.has_professional_session() to authenticated;

-- Sustituye exclusivamente la puerta profesional ya existente, conservando
-- las ramas de propietario/alumno y todos sus demás criterios de autorización.
-- get_trainer_access debe seguir dejando consultar el estado del bloqueo.
do $migration$
declare v record; definition text;
begin
 for v in select p.oid from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname in ('trainer_private','editor_private','directory_private','profile_private')
   and p.prokind='f' and strpos(p.prosrc,'trainer_private.has_trainer_mfa()')>0
   and not (n.nspname='trainer_private' and p.proname in ('has_professional_session','get_trainer_access'))
 loop
  definition:=pg_get_functiondef(v.oid);
  execute replace(definition,'trainer_private.has_trainer_mfa()','trainer_private.has_professional_session()');
 end loop;
 for v in select schemaname,tablename,policyname,qual,with_check from pg_policies
  where (strpos(coalesce(qual,''),'trainer_private.has_trainer_mfa()')>0
    or strpos(coalesce(with_check,''),'trainer_private.has_trainer_mfa()')>0)
   and not (schemaname='public' and tablename='trainer_access' and policyname='trainer_access_read')
 loop
  execute format('alter policy %I on %I.%I %s %s',v.policyname,v.schemaname,v.tablename,
   case when v.qual is null then '' else 'using ('||replace(v.qual,'trainer_private.has_trainer_mfa()','trainer_private.has_professional_session()')||')' end,
   case when v.with_check is null then '' else 'with check ('||replace(v.with_check,'trainer_private.has_trainer_mfa()','trainer_private.has_professional_session()')||')' end);
 end loop;
end $migration$;

create or replace function trainer_private.get_trainer_access_without_mfa(p_trainer_id uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare v public.trainer_access; used integer;
begin
 if auth.uid() is null or (p_trainer_id is distinct from auth.uid()
  and not public.can_manage_pro_accounts()) then raise insufficient_privilege;end if;
 select * into v from public.trainer_access where trainer_id=p_trainer_id;
 select count(*) into used from public.trainer_client_relations
  where trainer_id=p_trainer_id and trainer_id<>client_id and ended_at is null;
 return jsonb_build_object('trainer_id',p_trainer_id,
  'enabled',coalesce(v.enabled,false),'client_limit',coalesce(v.client_limit,0),
  'valid_until',v.valid_until,'revision',coalesce(v.revision,0),
  'active_clients',used,'over_limit',used>coalesce(v.client_limit,0),
  'suspended',coalesce(v.suspended,false),'suspended_at',v.suspended_at,
  'effective',coalesce(not v.suspended and v.enabled and (v.valid_until is null or v.valid_until>statement_timestamp()),false));
end $$;

create or replace function trainer_private.get_trainer_management_status(p_trainer_id uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
begin
 if auth.uid() is null or not public.can_manage_pro_accounts() then raise insufficient_privilege;end if;
 return jsonb_build_object('access',trainer_private.get_trainer_access(p_trainer_id),
  'manual_access_enabled',coalesce((select manual_access_enabled from public.trainer_access_settings where singleton),false),
  'manual_enabled',coalesce((select manual_enabled from public.trainer_access where trainer_id=p_trainer_id),false),
  'manual_client_limit',(select manual_client_limit from public.trainer_access where trainer_id=p_trainer_id),
  'manual_valid_until',(select manual_valid_until from public.trainer_access where trainer_id=p_trainer_id),
  'suspension_reason',(select suspension_reason from public.trainer_access where trainer_id=p_trainer_id));
end $$;

create function trainer_private.admin_set_trainer_suspension(
 p_trainer_id uuid,p_suspended boolean,p_expected_revision bigint,p_reason text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v public.trainer_access; previous jsonb; result jsonb;
begin
 if not coalesce(public.can_manage_pro_accounts(),false)
  or not trainer_private.has_trainer_mfa() then raise insufficient_privilege;end if;
 if p_trainer_id is null or p_suspended is null or p_expected_revision is null or p_expected_revision<1
  or p_reason is null or char_length(btrim(p_reason)) not between 3 and 500 then raise invalid_parameter_value;end if;
 perform pg_advisory_xact_lock(hashtextextended('trainer-access:'||p_trainer_id::text,0));
 select * into v from public.trainer_access where trainer_id=p_trainer_id for update;
 if not found then raise invalid_parameter_value;end if;
 if v.revision=p_expected_revision+1 and v.suspended=p_suspended and v.last_action='suspension'
  and v.updated_by=auth.uid() and v.last_reason=btrim(p_reason) then
  return trainer_private.get_trainer_access(p_trainer_id);end if;
 if v.revision<>p_expected_revision then raise serialization_failure;end if;
 previous:=trainer_private.get_trainer_management_status(p_trainer_id);
 update public.trainer_access set suspended=p_suspended,
  suspended_at=case when p_suspended then clock_timestamp() else null end,
  suspension_reason=case when p_suspended then btrim(p_reason) else null end,
  revision=revision+1,updated_at=clock_timestamp(),updated_by=auth.uid(),
  last_reason=btrim(p_reason),last_action='suspension' where trainer_id=p_trainer_id;
 result:=trainer_private.get_trainer_access(p_trainer_id);
 insert into public.trainer_access_audit(trainer_id,actor_id,revision,previous_access,new_access,reason)
 values(p_trainer_id,auth.uid(),(result->>'revision')::bigint,previous,
  trainer_private.get_trainer_management_status(p_trainer_id),btrim(p_reason));
 return result;
end $$;
create function public.admin_set_trainer_suspension(
 p_trainer_id uuid,p_suspended boolean,p_expected_revision bigint,p_reason text)
returns jsonb language sql security invoker set search_path='' as $$
 select trainer_private.admin_set_trainer_suspension(p_trainer_id,p_suspended,p_expected_revision,p_reason);
$$;
revoke all on function trainer_private.admin_set_trainer_suspension(uuid,boolean,bigint,text),
 public.admin_set_trainer_suspension(uuid,boolean,bigint,text) from public,anon,authenticated;
grant execute on function trainer_private.admin_set_trainer_suspension(uuid,boolean,bigint,text),
 public.admin_set_trainer_suspension(uuid,boolean,bigint,text) to authenticated;

-- Las concesiones manuales no deben copiar cupo o vigencia de una compra ni
-- confundirse con la última suspensión al reconocer un reintento.
do $migration$
declare definition text;
begin
 definition:=pg_get_functiondef('trainer_private.admin_set_trainer_access(uuid,integer,boolean,bigint,text,timestamptz)'::regprocedure);
 if strpos(definition,'v.manual_client_limit=p_client_limit')=0
  or strpos(definition,'last_reason=btrim(p_reason) where')=0 then
  raise exception 'Revisar concesiones manuales antes de migrar';end if;
 definition:=replace(definition,'if v.revision=p_expected_revision+1 and',
  'if v.last_action=''manual'' and v.revision=p_expected_revision+1 and');
 definition:=replace(definition,'last_reason=btrim(p_reason) where',
  'last_reason=btrim(p_reason),last_action=''manual'' where');
 definition:=replace(definition,'previous:=jsonb_build_object(''enabled'',v.enabled,''client_limit'',v.client_limit,'||chr(10)||
  '      ''valid_until'',v.valid_until,''revision'',v.revision);',
  'previous:=trainer_private.get_trainer_management_status(p_trainer_id);');
 execute definition;
end $migration$;

create or replace function trainer_private.list_managed_trainers(p_after_id uuid default null)
returns jsonb language plpgsql stable security definer set search_path='' as $$
begin
 if auth.uid() is null or not public.can_manage_pro_accounts() then raise insufficient_privilege;end if;
 return coalesce((select jsonb_agg(to_jsonb(items) order by trainer_id) from (
  select a.trainer_id,p.full_name as name,u.email,a.enabled,a.suspended,a.client_limit,a.valid_until,
   (select count(*) from public.trainer_client_relations r
    where r.trainer_id=a.trainer_id and r.trainer_id<>r.client_id and r.ended_at is null) as active_clients
  from public.trainer_access a join public.profiles p on p.id=a.trainer_id join auth.users u on u.id=a.trainer_id
  where p_after_id is null or a.trainer_id>p_after_id order by a.trainer_id limit 50
 ) items),'[]'::jsonb);
end $$;

-- Estado propio sin MFA para dirigir al aviso, nunca al panel ni a otro pago.
do $migration$
declare definition text;
begin
 definition:=pg_get_functiondef('trainer_private.my_account_status(uuid)'::regprocedure);
 definition:=replace(definition,'''professional_account'',exists',
  '''suspended'',exists(select 1 from public.trainer_access where trainer_id=auth.uid() and suspended),'||chr(10)||'  ''professional_account'',exists');
 execute definition;
 definition:=pg_get_functiondef('commerce_private.status(uuid)'::regprocedure);
 definition:=replace(definition,'''sandbox'',true,''enabled'',s.enabled',
  '''sandbox'',true,''suspended'',exists(select 1 from public.trainer_access where trainer_id=p_owner and suspended),''enabled'',s.enabled');
 execute definition;
 definition:=pg_get_functiondef('commerce_private.prepare(uuid,uuid)'::regprocedure);
 definition:=replace(definition,'perform commerce_private.assert_owner(p_owner,true);',
  'perform commerce_private.assert_owner(p_owner,true);'||chr(10)||
  ' if exists(select 1 from public.trainer_access where trainer_id=p_owner and suspended) then raise insufficient_privilege;end if;');
 execute definition;
end $migration$;

commit;
