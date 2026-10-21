begin;

-- Cada reserva conserva contexto y límites: una firma nunca convierte ADMIN
-- en permiso sobre los medios privados de otro preparador o alumno.
alter table public.exercise_video_assets
 add column scope text not null default 'official' check(scope in('official','trainer_exercise','client_technique')),
 add column trainer_id uuid references public.profiles(id) on delete restrict,
 add column assignment_id uuid references public.trainer_assignments(scheduled_id) on delete restrict,
 add column execution_id uuid references public.workout_executions(id) on delete restrict,
 add column execution_set_id uuid references public.workout_execution_sets(id) on delete restrict,
 add column operation_id uuid,
 add column shared boolean not null default true,
 add column creation_state text not null default 'created' check(creation_state in('reserved','creating','created','uncertain')),
 add column creation_claim uuid,
 add column source_limit integer not null default 20971520 check(source_limit between 1 and 104857600),
 add column reserved_bytes bigint not null default 20971520 check(reserved_bytes>0),
 add column provider_storage_bytes bigint check(provider_storage_bytes>0),
 add column duration_limit integer not null default 10 check(duration_limit between 1 and 180),
 add column playback_limit integer not null default 5242880 check(playback_limit between 1 and 52428800),
 add constraint exercise_video_scope_context check(
  (scope='official' and trainer_id is null and assignment_id is null and execution_id is null and execution_set_id is null)
  or (scope='trainer_exercise' and trainer_id is not null and assignment_id is null and execution_id is null and execution_set_id is null and created_by=trainer_id)
  or (scope='client_technique' and trainer_id is not null and assignment_id is not null and execution_id is not null and created_by is not null));
alter table public.exercise_video_assets add constraint private_video_verified_storage check(scope='official' or status<>'ready' or (provider_storage_bytes is not null and provider_storage_bytes<=reserved_bytes));
alter table public.exercise_video_assets drop constraint exercise_video_assets_source_bytes_check;
alter table public.exercise_video_assets add constraint exercise_video_assets_source_bytes_check check(source_bytes between 1 and case when scope='official' then 20971520 else 104857600 end);
alter table public.exercise_video_assets drop constraint exercise_video_assets_duration_seconds_check;
alter table public.exercise_video_assets add constraint exercise_video_assets_duration_seconds_check check(duration_seconds>0 and duration_seconds<=duration_limit);
alter table public.exercise_video_assets drop constraint exercise_video_assets_playback_bytes_check;
alter table public.exercise_video_assets add constraint exercise_video_assets_playback_bytes_check check(playback_bytes between 1 and playback_limit);
alter table public.exercise_video_assets add constraint exercise_video_official_limits check(scope<>'official' or (source_limit=20971520 and duration_limit=10 and playback_limit=5242880));
create unique index exercise_video_operation on public.exercise_video_assets(created_by,operation_id) where operation_id is not null;
create index exercise_video_trainer_scope on public.exercise_video_assets(trainer_id,scope);
create index exercise_video_assignment on public.exercise_video_assets(assignment_id);
create index exercise_video_execution on public.exercise_video_assets(execution_id);
create index exercise_video_execution_set on public.exercise_video_assets(execution_set_id);

create table trainer_private.video_limits(
 trainer_id uuid not null references public.profiles(id) on delete cascade,
 scope text not null check(scope in('trainer_exercise','client_technique')),
 asset_limit integer not null default 100 check(asset_limit between 0 and 100000),
 byte_limit bigint not null default 2147483648 check(byte_limit>=0),
 source_limit integer not null default 104857600 check(source_limit between 1 and 104857600),
 duration_limit integer not null default 180 check(duration_limit between 1 and 180),
 playback_limit integer not null default 52428800 check(playback_limit between 1 and 52428800),
 feedback_limit integer not null default 100 check(feedback_limit between 0 and 10000),
 primary key(trainer_id,scope)
);
alter table trainer_private.video_limits enable row level security;
revoke all on trainer_private.video_limits from public,anon,authenticated;

create function trainer_private.can_manage_video(p_id uuid) returns boolean
language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.exercise_video_assets a where a.id=p_id and (
  (a.scope='official' and public.is_admin())
  or (a.scope='trainer_exercise' and a.created_by=auth.uid() and trainer_private.has_trainer_mfa())
  or (a.scope='client_technique' and a.created_by=auth.uid())));
$$;
create function trainer_private.can_read_video(p_id uuid) returns boolean
language sql stable security definer set search_path='' as $$
 select auth.uid() is not null and exists(select 1 from public.exercise_video_assets a where a.id=p_id and (
  (a.scope='official' and (public.is_admin() or exists(select 1 from public.exercises e where e.video_url=a.playback_url and
   (e.is_public or (e.origin='user' and e.created_by=auth.uid()) or (e.origin='coach' and trainer_private.can_read_exercise(e.id))))
   or exists(select 1 from public.workout_execution_sets s join public.workout_executions x on x.id=s.execution_id where s.exercise_video_url=a.playback_url and x.user_id=auth.uid())))
  or (a.scope='trainer_exercise' and ((a.created_by=auth.uid() and trainer_private.has_trainer_mfa())
   or exists(select 1 from public.exercises e where e.origin='coach' and e.created_by=a.trainer_id and e.video_url=a.playback_url and trainer_private.can_read_exercise(e.id))))
  or (a.scope='client_technique' and (a.created_by=auth.uid() or (a.shared and a.trainer_id=auth.uid() and trainer_private.has_trainer_mfa()
   and exists(select 1 from public.trainer_assignments t where t.scheduled_id=a.assignment_id and t.trainer_id=auth.uid() and t.client_id=a.created_by))))));
$$;
create function trainer_private.can_upload_video(p_id uuid) returns boolean
language sql stable security definer set search_path='' as $$
 select trainer_private.can_manage_video(p_id) and exists(select 1 from public.exercise_video_assets v where v.id=p_id and (
  v.scope='official' or exists(select 1 from public.trainer_access a where a.trainer_id=v.trainer_id and a.enabled and (a.valid_until is null or a.valid_until>statement_timestamp())
   and (v.scope='trainer_exercise' or exists(select 1 from public.trainer_assignments t join public.trainer_client_relations r on r.id=t.relation_id where t.scheduled_id=v.assignment_id and r.ended_at is null)))));
$$;
-- El helper por URL no expone metadatos de activos no autorizados.
create function trainer_private.can_read_video_url(p_url text) returns boolean
language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.exercise_video_assets a where a.playback_url=p_url and trainer_private.can_read_video(a.id));
$$;
create or replace function public.can_read_exercise_video(p_video_url text) returns boolean
language sql stable security invoker set search_path='' as $$ select trainer_private.can_read_video_url(p_video_url) $$;

create function trainer_private.reserve_video(p_scope text,p_operation_id uuid,p_library_id bigint,p_cdn_host text,p_source_bytes integer,
 p_assignment_id uuid default null,p_execution_id uuid default null,p_execution_set_id uuid default null) returns uuid
language plpgsql security definer set search_path='' as $$
declare owner_id uuid:=auth.uid(); coach uuid; prior public.exercise_video_assets; limits trainer_private.video_limits; result uuid; current_count integer; current_bytes bigint;
begin
 if owner_id is null or p_operation_id is null or p_scope is null or p_scope not in('official','trainer_exercise','client_technique') then raise insufficient_privilege; end if;
 if coalesce((auth.jwt()->>'is_anonymous')::boolean,false) then raise insufficient_privilege; end if;
 if p_scope='official' then
  if not public.is_admin() or p_source_bytes not between 1 and 20971520 or p_assignment_id is not null or p_execution_id is not null or p_execution_set_id is not null then raise insufficient_privilege; end if;
 elsif p_scope='trainer_exercise' then
  perform trainer_private.require_authoring_access(); coach:=owner_id;
  if p_assignment_id is not null or p_execution_id is not null or p_execution_set_id is not null then raise invalid_parameter_value; end if;
 else
  -- Mismo bloqueo que inicio y baja; ni el cliente ni ADMIN eligen preparador.
  select t.trainer_id into coach from public.trainer_assignments t where t.scheduled_id=p_assignment_id and t.client_id=owner_id;
  if not found then raise insufficient_privilege; end if;
  perform pg_advisory_xact_lock(hashtextextended('trainer-client:'||owner_id::text,0));
 end if;
 perform pg_advisory_xact_lock(hashtextextended('video-owner:'||owner_id::text,0));
 if p_scope='client_technique' and not exists(select 1 from public.trainer_assignments t join public.trainer_client_relations r on r.id=t.relation_id
  join public.trainer_access a on a.trainer_id=t.trainer_id where t.scheduled_id=p_assignment_id and t.client_id=owner_id and r.ended_at is null
  and a.enabled and (a.valid_until is null or a.valid_until>statement_timestamp())) then raise insufficient_privilege; end if;
 select * into prior from public.exercise_video_assets where created_by=owner_id and operation_id=p_operation_id;
 if found then
  if prior.scope is distinct from p_scope or prior.library_id is distinct from p_library_id or prior.cdn_host is distinct from p_cdn_host or prior.source_bytes is distinct from p_source_bytes
   or prior.assignment_id is distinct from p_assignment_id or prior.execution_id is distinct from p_execution_id or prior.execution_set_id is distinct from p_execution_set_id then
   raise exception 'El reintento no coincide con la reserva de vídeo.' using errcode='22023'; end if;
  return prior.id;
 end if;
 if p_scope='client_technique' then
  if not exists(select 1 from public.trainer_assignments t join public.trainer_client_relations r on r.id=t.relation_id
   join public.scheduled_workouts s on s.id=t.scheduled_id join public.workout_executions e on e.id=s.execution_id
   join public.trainer_access a on a.trainer_id=t.trainer_id
   where t.scheduled_id=p_assignment_id and t.client_id=owner_id and t.trainer_id=coach and r.ended_at is null
   and s.execution_id=p_execution_id and e.user_id=owner_id and a.enabled and (a.valid_until is null or a.valid_until>statement_timestamp()))
   then raise insufficient_privilege; end if;
  if p_execution_set_id is not null and not exists(select 1 from public.workout_execution_sets s where s.id=p_execution_set_id and s.execution_id=p_execution_id) then raise insufficient_privilege; end if;
 end if;
 if p_scope='official' then
  if (select count(*) from public.exercise_video_assets where created_by=owner_id and scope='official' and created_at>now()-interval '1 hour')>=20 then raise exception 'Límite de subidas por hora' using errcode='54000'; end if;
 else
  -- Se separan las cuotas de demostraciones y técnica; reservas fallidas
  -- también cuentan hasta su reconciliación explícita en el servidor.
  perform pg_advisory_xact_lock(hashtextextended('video-budget:'||coach::text||':'||p_scope,0));
  insert into trainer_private.video_limits(trainer_id,scope) values(coach,p_scope) on conflict do nothing;
  select * into limits from trainer_private.video_limits where trainer_id=coach and scope=p_scope for update;
  -- Invalida snapshots REPEATABLE READ previos a una reserva competidora.
  update trainer_private.video_limits set asset_limit=asset_limit where trainer_id=coach and scope=p_scope;
  select count(*),coalesce(sum(reserved_bytes),0) into current_count,current_bytes from public.exercise_video_assets where trainer_id=coach and scope=p_scope;
  if p_source_bytes is null or p_source_bytes not between 1 and limits.source_limit then raise invalid_parameter_value; end if;
  if current_count>=limits.asset_limit or current_bytes+limits.source_limit>limits.byte_limit then raise exception 'Límite de vídeos privados alcanzado' using errcode='54000'; end if;
 end if;
 insert into public.exercise_video_assets(created_by,scope,trainer_id,assignment_id,execution_id,execution_set_id,operation_id,library_id,cdn_host,source_bytes,creation_state,source_limit,reserved_bytes,duration_limit,playback_limit)
 values(owner_id,p_scope,coach,p_assignment_id,p_execution_id,p_execution_set_id,p_operation_id,p_library_id,p_cdn_host,p_source_bytes,'reserved',coalesce(limits.source_limit,20971520),coalesce(limits.source_limit,p_source_bytes),coalesce(limits.duration_limit,10),coalesce(limits.playback_limit,5242880)) returning id into result;
 return result;
end $$;
create function public.reserve_exercise_video_upload(p_scope text,p_operation_id uuid,p_library_id bigint,p_cdn_host text,p_source_bytes integer,
 p_assignment_id uuid default null,p_execution_id uuid default null,p_execution_set_id uuid default null) returns uuid
language sql security invoker set search_path='' as $$ select trainer_private.reserve_video(p_scope,p_operation_id,p_library_id,p_cdn_host,p_source_bytes,p_assignment_id,p_execution_id,p_execution_set_id) $$;

create function public.authorize_exercise_video_asset(p_id uuid,p_action text) returns boolean
language sql stable security invoker set search_path='' as $$
 select case when p_action in('create','recover') then trainer_private.can_upload_video(p_id)
 when p_action in('status','thumbnail') then trainer_private.can_manage_video(p_id)
 when p_action='playback' then trainer_private.can_read_video(p_id) else false end;
$$;
create function trainer_private.video_asset(p_id uuid,p_action text) returns jsonb
language plpgsql stable security definer set search_path='' as $$
begin
 if not public.authorize_exercise_video_asset(p_id,p_action) then raise insufficient_privilege; end if;
 return (select to_jsonb(a)-'creation_claim' from public.exercise_video_assets a where a.id=p_id);
end $$;
create function public.get_exercise_video_asset(p_id uuid,p_action text default 'status') returns jsonb
language sql stable security invoker set search_path='' as $$ select trainer_private.video_asset(p_id,p_action) $$;
create function trainer_private.video_usage() returns jsonb
language plpgsql stable security definer set search_path='' as $$
begin
 if not trainer_private.has_trainer_mfa() then raise insufficient_privilege; end if;
 return (select jsonb_agg(jsonb_build_object('scope',s.scope,'asset_limit',coalesce(l.asset_limit,100),'byte_limit',coalesce(l.byte_limit,2147483648),
  'source_limit',coalesce(l.source_limit,104857600),'duration_limit',coalesce(l.duration_limit,180),'playback_limit',coalesce(l.playback_limit,52428800),
  'asset_used',(select count(*) from public.exercise_video_assets a where a.trainer_id=auth.uid() and a.scope=s.scope),
  'bytes_reserved',(select coalesce(sum(a.reserved_bytes),0) from public.exercise_video_assets a where a.trainer_id=auth.uid() and a.scope=s.scope)))
  from (values('trainer_exercise'),('client_technique')) s(scope) left join trainer_private.video_limits l on l.trainer_id=auth.uid() and l.scope=s.scope);
end $$;
create function public.get_trainer_video_usage() returns jsonb language sql stable security invoker set search_path='' as $$ select trainer_private.video_usage() $$;
create function trainer_private.list_exercise_videos(p_before_at timestamptz default null,p_before_id uuid default null) returns jsonb
language plpgsql stable security definer set search_path='' as $$
begin
 if not trainer_private.has_trainer_mfa() then raise insufficient_privilege; end if;
 if (p_before_at is null)<>(p_before_id is null) then raise invalid_parameter_value; end if;
 return (select coalesce(jsonb_agg(to_jsonb(x)-'creation_claim' order by created_at desc,id desc),'[]') from (
  select * from public.exercise_video_assets where scope='trainer_exercise' and trainer_id=auth.uid()
  and (p_before_at is null or (created_at,id)<(p_before_at,p_before_id)) order by created_at desc,id desc limit 50) x);
end $$;
create function public.list_trainer_exercise_videos(p_before_at timestamptz default null,p_before_id uuid default null) returns jsonb
language sql stable security invoker set search_path='' as $$ select trainer_private.list_exercise_videos(p_before_at,p_before_id) $$;

-- Solo Edge (service_role) puede reclamar una creación o registrar el ID
-- verificado de Bunny. Un timeout incierto nunca autoriza otra creación.
create function public.claim_exercise_video_creation(p_id uuid,p_claim uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare a public.exercise_video_assets;
begin
 select * into a from public.exercise_video_assets where id=p_id for update;
 if not found then raise no_data_found; end if;
 if a.creation_state='reserved' then
  update public.exercise_video_assets set creation_state='creating',creation_claim=p_claim where id=p_id;
  return jsonb_build_object('state','claimed');
 end if;
 return jsonb_build_object('state',a.creation_state,'video_id',a.provider_video_id);
end $$;
create function public.complete_exercise_video_creation(p_id uuid,p_claim uuid,p_video_id uuid,p_recovery boolean default false) returns void
language plpgsql security definer set search_path='' as $$
declare a public.exercise_video_assets;
begin
 select * into a from public.exercise_video_assets where id=p_id for update;
 if not found or (not p_recovery and a.creation_claim is distinct from p_claim) then raise insufficient_privilege; end if;
 if a.provider_video_id is not null and a.provider_video_id<>p_video_id then raise invalid_parameter_value; end if;
 if a.creation_state not in('creating','uncertain','created') then raise invalid_parameter_value; end if;
 update public.exercise_video_assets set provider_video_id=p_video_id,playback_url='https://'||cdn_host||'/'||p_video_id::text||'/play_720p.mp4',creation_state='created',updated_at=now() where id=p_id;
end $$;
create function public.mark_exercise_video_creation_uncertain(p_id uuid,p_claim uuid) returns void
language sql security definer set search_path='' as $$
 update public.exercise_video_assets set creation_state='uncertain',updated_at=now() where id=p_id and creation_claim=p_claim and creation_state='creating';
$$;
revoke all on function public.claim_exercise_video_creation(uuid,uuid),public.complete_exercise_video_creation(uuid,uuid,uuid,boolean),public.mark_exercise_video_creation_uncertain(uuid,uuid) from public,anon,authenticated;
grant execute on function public.claim_exercise_video_creation(uuid,uuid),public.complete_exercise_video_creation(uuid,uuid,uuid,boolean),public.mark_exercise_video_creation_uncertain(uuid,uuid) to service_role;

create function trainer_private.guard_video_transition() returns trigger language plpgsql set search_path='' as $$
begin
 if old.status in('ready','rejected','failed') and new.status<>old.status then raise exception 'El estado del vídeo ya es final.' using errcode='22023'; end if;
 if old.status='processing' and new.status='uploading' then raise invalid_parameter_value; end if;
 if old.status='ready' and (new.playback_url is distinct from old.playback_url or new.provider_video_id is distinct from old.provider_video_id
  or new.playback_bytes is distinct from old.playback_bytes or (old.scope<>'official' and (new.duration_seconds is distinct from old.duration_seconds or new.provider_storage_bytes is distinct from old.provider_storage_bytes))) then raise invalid_parameter_value; end if;
 if new.scope<>old.scope or new.created_by is distinct from old.created_by or new.trainer_id is distinct from old.trainer_id or new.assignment_id is distinct from old.assignment_id
  or new.execution_id is distinct from old.execution_id or new.execution_set_id is distinct from old.execution_set_id or new.source_bytes<>old.source_bytes
  or new.operation_id is distinct from old.operation_id or new.library_id<>old.library_id or new.cdn_host<>old.cdn_host
  or new.source_limit<>old.source_limit or new.reserved_bytes<>old.reserved_bytes or new.duration_limit<>old.duration_limit or new.playback_limit<>old.playback_limit then raise invalid_parameter_value; end if;
 return new;
end $$;
create trigger exercise_video_transition before update on public.exercise_video_assets for each row execute function trainer_private.guard_video_transition();

create or replace function public.check_exercise_video_ready() returns trigger language plpgsql security definer set search_path='' as $$
declare a public.exercise_video_assets;
begin
 if tg_op='UPDATE' and new.video_url is not distinct from old.video_url then return new; end if;
 select * into a from public.exercise_video_assets where playback_url=new.video_url;
 if not found then return new; end if;
 if a.status<>'ready' then raise exception 'El vídeo todavía no está preparado' using errcode='22023'; end if;
 if a.scope='client_technique' or (a.scope='trainer_exercise' and (new.origin<>'coach' or new.created_by<>a.trainer_id))
  or (a.scope='official' and new.origin='coach' and not trainer_private.can_read_video(a.id)) then raise insufficient_privilege; end if;
 return new;
end $$;

create table trainer_private.video_share_writes(
 owner_id uuid not null references public.profiles(id) on delete cascade,operation_id uuid not null,asset_id uuid not null references public.exercise_video_assets(id) on delete restrict,
 shared boolean not null,primary key(owner_id,operation_id)
);
create table trainer_private.video_feedback(
 id uuid primary key,asset_id uuid not null references public.exercise_video_assets(id) on delete restrict,
 trainer_id uuid not null references public.profiles(id) on delete restrict,second numeric not null check(second>=0),body text not null check(char_length(body) between 1 and 2000),created_at timestamptz not null default now()
);
create index video_feedback_asset on trainer_private.video_feedback(asset_id,created_at,id);
alter table trainer_private.video_share_writes enable row level security;
alter table trainer_private.video_feedback enable row level security;
revoke all on trainer_private.video_share_writes,trainer_private.video_feedback from public,anon,authenticated;
create function trainer_private.set_video_shared(p_operation_id uuid,p_id uuid,p_shared boolean) returns void
language plpgsql security definer set search_path='' as $$
declare prior trainer_private.video_share_writes;
begin
 if p_operation_id is null or p_shared is null or not exists(select 1 from public.exercise_video_assets where id=p_id and scope='client_technique' and created_by=auth.uid()) then raise insufficient_privilege; end if;
 perform 1 from public.exercise_video_assets where id=p_id for update;
 select * into prior from trainer_private.video_share_writes where owner_id=auth.uid() and operation_id=p_operation_id;
 if found then if prior.asset_id<>p_id or prior.shared<>p_shared then raise invalid_parameter_value; end if; return; end if;
 update public.exercise_video_assets set shared=p_shared where id=p_id;
 insert into trainer_private.video_share_writes values(auth.uid(),p_operation_id,p_id,p_shared);
end $$;
create function public.set_client_technique_shared(p_operation_id uuid,p_id uuid,p_shared boolean) returns void
language sql security invoker set search_path='' as $$ select trainer_private.set_video_shared(p_operation_id,p_id,p_shared) $$;
create function trainer_private.add_video_feedback(p_operation_id uuid,p_id uuid,p_second numeric,p_body text) returns uuid
language plpgsql security definer set search_path='' as $$
declare a public.exercise_video_assets; prior trainer_private.video_feedback; message text:=nullif(btrim(p_body),''); comment_limit integer;
begin
 if not trainer_private.has_trainer_mfa() then raise insufficient_privilege; end if;
 -- El recibo confirmado sigue siendo recuperable después de la baja o de
 -- retirar el acceso. No autoriza otro envío ni consulta del medio retirado.
 select * into prior from trainer_private.video_feedback where id=p_operation_id;
 if found then if prior.trainer_id<>auth.uid() or prior.asset_id is distinct from p_id or prior.second is distinct from p_second or prior.body is distinct from message then raise invalid_parameter_value; end if; return prior.id; end if;
 select * into a from public.exercise_video_assets where id=p_id;
 if not found or a.scope<>'client_technique' or a.trainer_id<>auth.uid() or not trainer_private.has_trainer_mfa() or not a.shared or a.status<>'ready' then raise insufficient_privilege; end if;
 perform pg_advisory_xact_lock(hashtextextended('trainer-client:'||a.created_by::text,0));
 perform trainer_private.require_authoring_access();
 select * into prior from trainer_private.video_feedback where id=p_operation_id;
 if found then if prior.trainer_id<>auth.uid() or prior.asset_id is distinct from p_id or prior.second is distinct from p_second or prior.body is distinct from message then raise invalid_parameter_value; end if; return prior.id; end if;
 select * into a from public.exercise_video_assets where id=p_id for update;
 if not a.shared or not exists(select 1 from public.trainer_assignments t join public.trainer_client_relations r on r.id=t.relation_id
  where t.scheduled_id=a.assignment_id and t.trainer_id=auth.uid() and r.ended_at is null) then raise insufficient_privilege; end if;
 if p_operation_id is null or p_second is null or p_second<0 or p_second>a.duration_seconds or message is null or char_length(message)>2000 then raise invalid_parameter_value; end if;
 -- El cambio de versión física del activo invalida un snapshot RR anterior;
 -- bloqueo y contador no dependen de que una lectura espere el advisory lock.
 update public.exercise_video_assets set shared=shared where id=p_id;
 select coalesce((select feedback_limit from trainer_private.video_limits where trainer_id=auth.uid() and scope='client_technique'),100) into comment_limit;
 if (select count(*) from trainer_private.video_feedback where asset_id=p_id)>=comment_limit then raise exception 'Límite de comentarios de este vídeo alcanzado.' using errcode='54000'; end if;
 insert into trainer_private.video_feedback(id,asset_id,trainer_id,second,body) values(p_operation_id,p_id,auth.uid(),p_second,message);
 return p_operation_id;
end $$;
create function public.add_trainer_video_feedback(p_operation_id uuid,p_id uuid,p_second numeric,p_body text) returns uuid
language sql security invoker set search_path='' as $$ select trainer_private.add_video_feedback(p_operation_id,p_id,p_second,p_body) $$;
create function trainer_private.can_feedback_video(p_id uuid) returns boolean
language sql stable security definer set search_path='' as $$
 select trainer_private.has_trainer_mfa() and exists(select 1 from public.exercise_video_assets a join public.trainer_assignments t on t.scheduled_id=a.assignment_id
 join public.trainer_client_relations r on r.id=t.relation_id join public.trainer_access access on access.trainer_id=t.trainer_id
 where a.id=p_id and a.scope='client_technique' and a.status='ready' and a.shared and a.trainer_id=auth.uid() and t.trainer_id=auth.uid()
 and r.ended_at is null and access.enabled and (access.valid_until is null or access.valid_until>statement_timestamp()));
$$;
create function trainer_private.list_technique_videos(p_assignment_id uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
begin
 if not exists(select 1 from public.trainer_assignments t where t.scheduled_id=p_assignment_id and (t.client_id=auth.uid() or (t.trainer_id=auth.uid() and trainer_private.has_trainer_mfa()))) then raise insufficient_privilege; end if;
 return (select coalesce(jsonb_agg(to_jsonb(a)-'creation_claim'||jsonb_build_object('can_feedback',trainer_private.can_feedback_video(a.id),
  'feedback_limit',coalesce((select feedback_limit from trainer_private.video_limits where trainer_id=a.trainer_id and scope='client_technique'),100),
  'feedback_count',(select count(*) from trainer_private.video_feedback where asset_id=a.id),
  'feedback',(select coalesce(jsonb_agg(to_jsonb(f) order by created_at,id),'[]') from trainer_private.video_feedback f where f.asset_id=a.id)) order by a.created_at,a.id),'[]')
  from public.exercise_video_assets a where a.assignment_id=p_assignment_id and a.scope='client_technique' and trainer_private.can_read_video(a.id));
end $$;
create function public.list_client_technique_videos(p_assignment_id uuid) returns jsonb
language sql stable security invoker set search_path='' as $$ select trainer_private.list_technique_videos(p_assignment_id) $$;
create function trainer_private.client_technique_context(p_execution_id uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare result jsonb;
begin
 if auth.uid() is null or not exists(select 1 from public.workout_executions e where e.id=p_execution_id and e.user_id=auth.uid()) then raise insufficient_privilege; end if;
 select jsonb_build_object('assignment_id',t.scheduled_id,'execution_id',p_execution_id,
  'can_upload',r.ended_at is null and a.enabled and (a.valid_until is null or a.valid_until>statement_timestamp()),
  'source_limit',coalesce(l.source_limit,104857600),'duration_limit',coalesce(l.duration_limit,180),'playback_limit',coalesce(l.playback_limit,52428800)) into result
 from public.trainer_assignments t join public.scheduled_workouts s on s.id=t.scheduled_id
 join public.trainer_client_relations r on r.id=t.relation_id join public.trainer_access a on a.trainer_id=t.trainer_id
 left join trainer_private.video_limits l on l.trainer_id=t.trainer_id and l.scope='client_technique'
 where s.execution_id=p_execution_id and t.client_id=auth.uid();
 return result;
end $$;
create function public.get_client_technique_context(p_execution_id uuid) returns jsonb
language sql stable security invoker set search_path='' as $$ select trainer_private.client_technique_context(p_execution_id) $$;

do $grants$
declare x record;
begin
 for x in select p.oid::regprocedure as signature from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname in('public','trainer_private') and p.proname in(
 'can_manage_video','can_read_video','can_upload_video','can_read_video_url','reserve_video','reserve_exercise_video_upload','authorize_exercise_video_asset','video_asset','get_exercise_video_asset','video_usage','get_trainer_video_usage','list_exercise_videos','list_trainer_exercise_videos','set_video_shared','set_client_technique_shared','add_video_feedback','add_trainer_video_feedback','can_feedback_video','list_technique_videos','list_client_technique_videos','client_technique_context','get_client_technique_context') loop
 execute format('revoke all on function %s from public,anon,authenticated',x.signature);
 execute format('grant execute on function %s to authenticated',x.signature);
 end loop;
end $grants$;
revoke all on function trainer_private.guard_video_transition() from public,anon,authenticated;
comment on table trainer_private.video_limits is 'Límites técnicos provisionales por preparador y clase de vídeo; no tarifas ni derechos comerciales. Reservas y versiones cuentan.';
commit;
