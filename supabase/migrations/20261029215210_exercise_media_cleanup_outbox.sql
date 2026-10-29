-- TRN-046: solo una ausencia externa confirmada libera reservas de medios.
-- El despliegue inicial queda deshabilitado y no crea un cron activo.
begin;
alter table trainer_private.exercise_images add column cleanup_state text not null default 'active' check(cleanup_state in('active','deleting','deleted')),
 add column deleted_at timestamptz;
alter table public.exercise_video_assets add column cleanup_state text not null default 'active' check(cleanup_state in('active','deleting','deleted')),
 add column deleted_at timestamptz,add column upload_lease_until timestamptz,add column creation_guard_until timestamptz;
-- Las credenciales anteriores duraban una hora, pero no guardaban su emisión.
update public.exercise_video_assets set upload_lease_until=case when status='uploading' then clock_timestamp()+interval '1 hour' else updated_at+interval '1 hour' end,
 creation_guard_until=case when creation_state in('creating','uncertain') then clock_timestamp()+interval '1 hour' end;
alter table trainer_private.exercise_images add constraint exercise_image_cleanup_consistent check((cleanup_state='deleted')=(deleted_at is not null));
alter table public.exercise_video_assets add constraint exercise_video_cleanup_consistent check((cleanup_state='deleted')=(deleted_at is not null));

create table trainer_private.media_cleanup_jobs (
 id uuid primary key default gen_random_uuid(),resource_key text not null unique,
 kind text not null check(kind in('image','video')),scope text not null check(scope in('trainer','official')),
 owner_id uuid references public.profiles(id) on delete cascade,requested_by uuid references public.profiles(id) on delete set null,
 bucket text,path text,asset_id uuid references public.exercise_video_assets(id) on delete cascade,
 reserved_bytes bigint not null default 0 check(reserved_bytes>=0),resolved_provider_video_id uuid,
 state text not null default 'queued' check(state in('queued','deleting','retry','blocked','deleted')),
 created_at timestamptz not null default clock_timestamp(),updated_at timestamptz not null default clock_timestamp(),
 available_at timestamptz not null default clock_timestamp(),deleted_at timestamptz,
 blocked_reason text,error_code text check(error_code is null or error_code~'^[a-z0-9_]{1,64}$'),
 lease_id uuid,lease_until timestamptz,attempts integer not null default 0 check(attempts>=0),
 check((scope='trainer' and owner_id is not null) or(scope='official' and owner_id is null)),
 check((kind='image' and bucket is not null and path is not null and asset_id is null) or(kind='video' and asset_id is not null and bucket is null and path is null)),
 check((state='deleted')=(deleted_at is not null))
);
create index media_cleanup_owner_page on trainer_private.media_cleanup_jobs(owner_id,created_at desc,id desc);
create index media_cleanup_requested_by on trainer_private.media_cleanup_jobs(requested_by);
create index media_cleanup_asset on trainer_private.media_cleanup_jobs(asset_id);
create index media_cleanup_due on trainer_private.media_cleanup_jobs(available_at,id) where state in('queued','retry','deleting');
create table trainer_private.media_cleanup_operations (
 actor_id uuid not null references public.profiles(id) on delete cascade,operation_id uuid not null,request jsonb not null,job_ids uuid[] not null,
 primary key(actor_id,operation_id)
);
create table trainer_private.media_cleanup_settings (
 singleton boolean primary key default true check(singleton),enabled boolean not null default false,
 ticket_hash text,ticket_expires_at timestamptz,ticket_used boolean not null default true
);
insert into trainer_private.media_cleanup_settings(singleton) values(true);
alter table trainer_private.media_cleanup_jobs enable row level security;
alter table trainer_private.media_cleanup_operations enable row level security;
alter table trainer_private.media_cleanup_settings enable row level security;
revoke all on trainer_private.media_cleanup_jobs,trainer_private.media_cleanup_operations,trainer_private.media_cleanup_settings from public,anon,authenticated,service_role;

create function trainer_private.media_context(p_scope text) returns void
language plpgsql security definer set search_path='' as $$
declare sid uuid;
begin
 if auth.uid() is null or p_scope is null or p_scope not in('trainer','official') or coalesce((auth.jwt()->>'is_anonymous')::boolean,false)
  or (auth.jwt()->>'aal') is distinct from 'aal2' or not exists(select 1 from auth.mfa_factors where user_id=auth.uid() and status='verified')
  or coalesce(auth.jwt()->>'session_id','')!~'^[0-9a-fA-F-]{36}$' then raise insufficient_privilege;end if;
 begin sid:=(auth.jwt()->>'session_id')::uuid;exception when invalid_text_representation then raise insufficient_privilege;end;
 perform 1 from auth.sessions where id=sid and user_id=auth.uid() and(not_after is null or not_after>clock_timestamp()) for key share;
 if not found or(p_scope='official' and not coalesce(public.is_admin(),false)) then raise insufficient_privilege;end if;
 -- Limpiar archivos propios no exige una suscripción profesional vigente.
end $$;
create function trainer_private.media_lock(p_key text,p_exclusive boolean default false) returns void
language plpgsql set search_path='' as $$begin
 if p_exclusive then perform pg_advisory_xact_lock(hashtextextended('exercise-media:'||p_key,0));
 else perform pg_advisory_xact_lock_shared(hashtextextended('exercise-media:'||p_key,0));end if;
end $$;
create function trainer_private.media_contains(p_body jsonb,p_path text,p_asset uuid,p_url text,p_provider uuid) returns boolean
language sql immutable set search_path='' as $$select coalesce(
 (p_path is not null and(strpos(p_body::text,p_path)>0 or strpos(lower(p_body::text),lower(replace(p_path,'/','%2f')))>0)) or(p_asset is not null and strpos(lower(p_body::text),p_asset::text)>0)
 or(p_url is not null and strpos(p_body::text,p_url)>0) or(p_provider is not null and strpos(lower(p_body::text),p_provider::text)>0),false)$$;

create function trainer_private.media_block_reason(p_kind text,p_bucket text,p_path text,p_asset uuid,p_resolved uuid default null) returns text
language plpgsql stable security definer set search_path='' as $$
declare url text;provider uuid;a public.exercise_video_assets;r record;hit boolean;
begin
 if p_kind='video' then
  select * into a from public.exercise_video_assets where id=p_asset;
  if not found then return 'asset_missing';end if;
  if a.scope='client_technique' or a.execution_id is not null or a.execution_set_id is not null then return 'technique_history';end if;
  url:=a.playback_url;provider:=coalesce(p_resolved,(select resolved_provider_video_id from trainer_private.media_cleanup_jobs where asset_id=p_asset),a.provider_video_id);
 end if;
 if exists(select 1 from public.exercises e where trainer_private.media_contains(to_jsonb(e),p_path,p_asset,url,provider)) then return 'exercise_reference';end if;
 if exists(select 1 from public.workout_execution_sets s where trainer_private.media_contains(to_jsonb(s),p_path,p_asset,url,provider)) then return 'execution_history';end if;
 -- Los trabajos abiertos se revisan en todos los contextos, también de otro
 -- autor autorizado. Un recibo cerrado no vuelve a convertirlo en pendiente.
 if exists(select 1 from trainer_private.session_works w join trainer_private.session_work_bodies b
  on(b.owner_id,b.context,b.hash)=(w.owner_id,w.context,w.state_hash) where w.lifecycle='open'
  and(trainer_private.media_contains(b.body,p_path,p_asset,url,provider) or trainer_private.media_contains(w.origin,p_path,p_asset,url,provider)))
  or exists(select 1 from trainer_private.program_works w join trainer_private.program_work_bodies b
   on(b.owner_id,b.context,b.hash)=(w.owner_id,w.context,w.state_hash) where w.lifecycle='open' and trainer_private.media_contains(b.body,p_path,p_asset,url,provider))
  or exists(select 1 from admin_work_private.session_work w where not w.discarded and w.result_id is null
   and(trainer_private.media_contains(w.state,p_path,p_asset,url,provider) or trainer_private.media_contains(w.origin,p_path,p_asset,url,provider)))
  or exists(select 1 from public.admin_guided_work_drafts w where w.discarded_at is null and w.finalized_program_id is null
   and trainer_private.media_contains(w.state,p_path,p_asset,url,provider)) then return 'open_draft';end if;
 if exists(select 1 from trainer_private.programs p where trainer_private.media_contains(p.content,p_path,p_asset,url,provider))
  or exists(select 1 from public.guided_programs p where trainer_private.media_contains(p.content,p_path,p_asset,url,provider)) then return 'program_history';end if;
 for r in select n.nspname,c.relname,at.attname from pg_class c join pg_namespace n on n.oid=c.relnamespace
  join pg_attribute at on at.attrelid=c.oid and at.attnum>0 and not at.attisdropped
  where c.relkind='r' and n.nspname='device_private' and at.atttypid='jsonb'::regtype loop
  execute format('select exists(select 1 from %I.%I where trainer_private.media_contains(%I,$1,$2,$3,$4))',r.nspname,r.relname,r.attname)
   into hit using p_path,p_asset,url,provider;
  if hit then return 'device_history';end if;
 end loop;
 return null;
end $$;

create function trainer_private.media_job_json(j trainer_private.media_cleanup_jobs) returns jsonb
language sql stable set search_path='' as $$select jsonb_build_object('job_id',j.id,'kind',j.kind,'scope',j.scope,'state',j.state,
 'created_at',j.created_at,'updated_at',j.updated_at,'available_at',j.available_at,'deleted_at',j.deleted_at,'blocked_reason',j.blocked_reason,'error_code',j.error_code)$$;
create function trainer_private.enqueue_media(p_scope text,p_kind text,p_target text) returns trainer_private.media_cleanup_jobs
language plpgsql security definer set search_path='' as $$
declare j trainer_private.media_cleanup_jobs;a public.exercise_video_assets;i trainer_private.exercise_images;k text;bucket text;owner uuid;reason text;deadline timestamptz:=clock_timestamp();
begin
 if p_kind='image' then
  bucket:=case p_scope when 'trainer' then 'trainer-exercise-images' else 'exercise-images-public' end;
  if p_scope='trainer' then
   select * into i from trainer_private.exercise_images where path=p_target and trainer_id=auth.uid();
   if not found then raise insufficient_privilege;end if;owner:=i.trainer_id;
  elsif p_target!~'^official/[A-Za-z0-9_/-]+\.(jpg|jpeg)$' then raise invalid_parameter_value;end if;
  k:='image:'||bucket||':'||p_target;
 else
  if p_target!~'^[0-9a-fA-F-]{36}$' then raise invalid_parameter_value;end if;
  select * into a from public.exercise_video_assets where id=p_target::uuid;
  if not found or(p_scope='trainer' and(a.scope<>'trainer_exercise' or a.created_by is distinct from auth.uid()))
   or(p_scope='official' and a.scope<>'official') then raise insufficient_privilege;end if;
  owner:=case when p_scope='trainer' then a.created_by end;k:='video:'||a.id::text;
  deadline:=greatest(deadline,coalesce(a.upload_lease_until,'-infinity')+interval '5 minutes',coalesce(a.creation_guard_until,'-infinity')+interval '5 minutes');
 end if;
 perform trainer_private.media_lock(k);
 reason:=trainer_private.media_block_reason(p_kind,bucket,case when p_kind='image' then p_target end,a.id);
 insert into trainer_private.media_cleanup_jobs(resource_key,kind,scope,owner_id,requested_by,bucket,path,asset_id,reserved_bytes,available_at,state,blocked_reason)
 values(k,p_kind,p_scope,owner,auth.uid(),bucket,case when p_kind='image' then p_target end,a.id,coalesce(a.reserved_bytes,0),deadline,
  case when reason is null then 'queued' else 'blocked' end,reason)
 on conflict(resource_key) do update set requested_by=excluded.requested_by,
  state=case when media_cleanup_jobs.state in('deleted','deleting','retry') then media_cleanup_jobs.state else excluded.state end,
  blocked_reason=case when media_cleanup_jobs.state in('deleted','deleting','retry') then media_cleanup_jobs.blocked_reason else excluded.blocked_reason end,
  available_at=greatest(media_cleanup_jobs.available_at,excluded.available_at),updated_at=clock_timestamp()
 returning * into j;
 return j;
end $$;

create function trainer_private.queue_media(p_operation_id uuid,p_scope text,p_kind text,p_target text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare previous trainer_private.media_cleanup_operations;j trainer_private.media_cleanup_jobs;request jsonb;
begin
 perform trainer_private.media_context(p_scope);
 if p_operation_id is null or p_kind is null or p_kind not in('image','video') or p_target is null or length(p_target)>300 then raise invalid_parameter_value;end if;
 request:=jsonb_build_object('action','queue','scope',p_scope,'kind',p_kind,'target',p_target);
 perform pg_advisory_xact_lock(hashtextextended('media-operation:'||auth.uid()::text||p_operation_id::text,0));
 select * into previous from trainer_private.media_cleanup_operations where actor_id=auth.uid() and operation_id=p_operation_id;
 if found then
  if previous.request is distinct from request then raise invalid_parameter_value;end if;
  select * into j from trainer_private.media_cleanup_jobs where id=previous.job_ids[1];
 else
  j:=trainer_private.enqueue_media(p_scope,p_kind,p_target);
  insert into trainer_private.media_cleanup_operations values(auth.uid(),p_operation_id,request,array[j.id]);
 end if;
 return trainer_private.media_job_json(j);
end $$;
create function trainer_private.sweep_media(p_operation_id uuid,p_scope text,p_limit integer) returns jsonb
language plpgsql security definer set search_path='' as $$
declare previous trainer_private.media_cleanup_operations;j trainer_private.media_cleanup_jobs;request jsonb;ids uuid[]:='{}';r record;
begin
 perform trainer_private.media_context(p_scope);
 if p_operation_id is null then raise invalid_parameter_value;end if;
 p_limit:=greatest(1,least(coalesce(p_limit,50),100));request:=jsonb_build_object('action','sweep','scope',p_scope,'limit',p_limit);
 perform pg_advisory_xact_lock(hashtextextended('media-operation:'||auth.uid()::text||p_operation_id::text,0));
 select * into previous from trainer_private.media_cleanup_operations where actor_id=auth.uid() and operation_id=p_operation_id;
 if found then
  if previous.request is distinct from request then raise invalid_parameter_value;end if;ids:=previous.job_ids;
 else
  for r in select 'image' kind,i.path target from trainer_private.exercise_images i
   where p_scope='trainer' and i.trainer_id=auth.uid() and i.deleted_at is null and i.created_at<clock_timestamp()-interval '24 hours'
   union all select 'image',o.name from storage.objects o where p_scope='official' and o.bucket_id='exercise-images-public' and o.name like 'official/%'
    and o.created_at<clock_timestamp()-interval '24 hours'
   union all select 'video',a.id::text from public.exercise_video_assets a where a.deleted_at is null and a.created_at<clock_timestamp()-interval '24 hours'
    and((p_scope='trainer' and a.scope='trainer_exercise' and a.created_by=auth.uid()) or(p_scope='official' and a.scope='official'))
    and((a.creation_state='reserved' and a.provider_video_id is null) or a.status in('failed','rejected'))
   limit p_limit loop
   j:=trainer_private.enqueue_media(p_scope,r.kind,r.target);ids:=array_append(ids,j.id);
  end loop;
  insert into trainer_private.media_cleanup_operations values(auth.uid(),p_operation_id,request,ids);
 end if;
 return jsonb_build_object('items',(select coalesce(jsonb_agg(trainer_private.media_job_json(x) order by x.created_at desc,x.id desc),'[]') from trainer_private.media_cleanup_jobs x where x.id=any(ids)),
  'queued',(select count(*) from trainer_private.media_cleanup_jobs where id=any(ids) and state in('queued','deleting','retry')));
end $$;
create function trainer_private.list_media(p_scope text,p_before_at timestamptz,p_before_id uuid,p_limit integer) returns jsonb
language plpgsql security definer set search_path='' as $$
begin
 perform trainer_private.media_context(p_scope);
 if(p_before_at is null)<>(p_before_id is null) then raise invalid_parameter_value;end if;
 return jsonb_build_object('items',(select coalesce(jsonb_agg(trainer_private.media_job_json(x) order by x.created_at desc,x.id desc),'[]') from(
  select * from trainer_private.media_cleanup_jobs where scope=p_scope and(p_scope='official' or owner_id=auth.uid())
  and(p_before_at is null or(created_at,id)<(p_before_at,p_before_id)) order by created_at desc,id desc limit greatest(1,least(coalesce(p_limit,50),100)))x),
 'summary',(select jsonb_build_object('pending',count(*)filter(where state in('queued','deleting','retry')),'deleted',count(*)filter(where state='deleted'),
  'protected',count(*)filter(where state='blocked'),'freed_images',count(*)filter(where state='deleted' and kind='image' and scope='trainer'),
  'freed_bytes',coalesce(sum(reserved_bytes)filter(where state='deleted' and kind='video'),0)) from trainer_private.media_cleanup_jobs where scope=p_scope and(p_scope='official' or owner_id=auth.uid())));
end $$;

create function trainer_private.claim_media(p_limit integer,p_owner uuid,p_claim uuid,p_scope text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare j trainer_private.media_cleanup_jobs;a public.exercise_video_assets;reason text;deadline timestamptz;result jsonb:='[]';old_context text:=current_setting('entrenaop.media_cleanup_transition',true);
begin
 if p_claim is null or(p_scope is not null and p_scope not in('trainer','official')) then raise invalid_parameter_value;end if;
 if not coalesce((select enabled from trainer_private.media_cleanup_settings where singleton),false) then return result;end if;
 for j in select * from trainer_private.media_cleanup_jobs where state in('queued','retry','deleting') and available_at<=clock_timestamp()
  and(lease_until is null or lease_until<clock_timestamp())
  and(p_scope is null or scope=p_scope) and(p_owner is null or(scope='trainer' and owner_id=p_owner) or(scope='official' and requested_by=p_owner))
  order by available_at,id for update skip locked limit greatest(1,least(coalesce(p_limit,3),10)) loop
  if not pg_try_advisory_xact_lock(hashtextextended('exercise-media:'||j.resource_key,0)) then continue;end if;
  reason:=trainer_private.media_block_reason(j.kind,j.bucket,j.path,j.asset_id);
  if reason is not null then
   update trainer_private.media_cleanup_jobs set state='blocked',blocked_reason=reason,lease_id=null,lease_until=null,updated_at=clock_timestamp() where id=j.id;
   continue;
  end if;
  if j.kind='video' then
   select * into a from public.exercise_video_assets where id=j.asset_id for update;
   deadline:=greatest(coalesce(a.upload_lease_until,'-infinity')+interval '5 minutes',coalesce(a.creation_guard_until,'-infinity')+interval '5 minutes');
   if deadline>clock_timestamp() then update trainer_private.media_cleanup_jobs set available_at=deadline where id=j.id;continue;end if;
  end if;
  perform set_config('entrenaop.media_cleanup_transition','true',true);
  if j.kind='image' and j.scope='trainer' then
   update trainer_private.exercise_images set cleanup_state='deleting' where path=j.path and trainer_id=j.owner_id and deleted_at is null;
  elsif j.kind='video' then update public.exercise_video_assets set cleanup_state='deleting' where id=j.asset_id and deleted_at is null;end if;
  perform set_config('entrenaop.media_cleanup_transition',coalesce(old_context,''),true);
  update trainer_private.media_cleanup_jobs set state='deleting',lease_id=p_claim,lease_until=clock_timestamp()+interval '5 minutes',attempts=attempts+1,
   blocked_reason=null,error_code=null,updated_at=clock_timestamp() where id=j.id returning * into j;
  result:=result||jsonb_build_array(jsonb_build_object('job_id',j.id,'lease_id',j.lease_id,'kind',j.kind,'scope',j.scope,'owner_id',j.owner_id,'requested_by',j.requested_by,
   'bucket',j.bucket,'path',j.path,'asset_id',j.asset_id,'library_id',case when j.kind='video' then a.library_id end,
   'provider_video_id',coalesce(j.resolved_provider_video_id,case when j.kind='video' then a.provider_video_id end),
   'creation_state',case when j.kind='video' then a.creation_state end,
   'requires_reconciliation',j.kind='video' and(a.creation_state in('creating','uncertain') or(a.creation_state<>'reserved' and a.provider_video_id is null)) and j.resolved_provider_video_id is null,
   'provider_identity_confirmed',j.kind='video' and(j.resolved_provider_video_id is not null or(a.creation_state='created' and a.provider_video_id is not null)),
   'state',j.state));
 end loop;
 return result;
end $$;

create function trainer_private.resolve_media(p_job_id uuid,p_lease_id uuid,p_provider_video_id uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare j trainer_private.media_cleanup_jobs;a public.exercise_video_assets;reason text;old_context text:=current_setting('entrenaop.media_cleanup_transition',true);
begin
 if p_provider_video_id is null then raise invalid_parameter_value;end if;
 -- GUID antes de recurso, también cuando aún no existe ningún mapeo.
 perform pg_advisory_xact_lock(hashtextextended('exercise-media-guid:'||p_provider_video_id::text,0));
 select * into j from trainer_private.media_cleanup_jobs where id=p_job_id;
 if not found then raise insufficient_privilege;end if;
 perform trainer_private.media_lock(j.resource_key,true);
 select * into j from trainer_private.media_cleanup_jobs where id=p_job_id for update;
 if j.kind<>'video' or j.state<>'deleting' or j.lease_id is distinct from p_lease_id or p_lease_id is null or j.lease_until is null or j.lease_until<=clock_timestamp() then raise insufficient_privilege;end if;
 select * into a from public.exercise_video_assets where id=j.asset_id;
 if(a.provider_video_id is not null and a.provider_video_id<>p_provider_video_id)
  or(j.resolved_provider_video_id is not null and j.resolved_provider_video_id<>p_provider_video_id) then raise invalid_parameter_value;end if;
 reason:=trainer_private.media_block_reason(j.kind,j.bucket,j.path,j.asset_id,p_provider_video_id);
 if reason is not null then
  perform set_config('entrenaop.media_cleanup_transition','true',true);
  update public.exercise_video_assets set cleanup_state='active' where id=j.asset_id and deleted_at is null;
  perform set_config('entrenaop.media_cleanup_transition',coalesce(old_context,''),true);
  update trainer_private.media_cleanup_jobs set resolved_provider_video_id=p_provider_video_id,state='blocked',blocked_reason=reason,lease_until=null,updated_at=clock_timestamp() where id=j.id;
  return jsonb_build_object('job_id',j.id,'state','blocked','provider_identity_confirmed',false,'blocked_reason',reason);
 end if;
 update trainer_private.media_cleanup_jobs set resolved_provider_video_id=p_provider_video_id,updated_at=clock_timestamp() where id=j.id;
 return jsonb_build_object('job_id',j.id,'provider_video_id',p_provider_video_id,'provider_identity_confirmed',true);
end $$;

create function trainer_private.finish_media(p_job_id uuid,p_lease_id uuid,p_deleted boolean,p_error_code text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare j trainer_private.media_cleanup_jobs;a public.exercise_video_assets;changed integer;reason text;old_context text:=current_setting('entrenaop.media_cleanup_transition',true);
begin
 if p_deleted is null or(p_error_code is not null and p_error_code!~'^[a-z0-9_]{1,64}$') then raise invalid_parameter_value;end if;
 select * into j from trainer_private.media_cleanup_jobs where id=p_job_id;
 if not found then raise insufficient_privilege;end if;
 perform trainer_private.media_lock(j.resource_key,true);
 select * into j from trainer_private.media_cleanup_jobs where id=p_job_id for update;
 if j.lease_id is distinct from p_lease_id or p_lease_id is null then raise insufficient_privilege;end if;
 if j.state='deleted' and p_deleted then return trainer_private.media_job_json(j);end if;
 if j.state<>'deleting' or j.lease_until is null or j.lease_until<=clock_timestamp() then raise insufficient_privilege;end if;
 if not p_deleted then
  update trainer_private.media_cleanup_jobs set state='retry',error_code=coalesce(p_error_code,'not_confirmed'),lease_until=null,
   available_at=clock_timestamp()+interval '5 minutes',updated_at=clock_timestamp() where id=j.id returning * into j;
  return trainer_private.media_job_json(j);
 end if;
 reason:=trainer_private.media_block_reason(j.kind,j.bucket,j.path,j.asset_id);
 if reason is not null then raise exception 'El medio tiene referencias que deben conservarse: %',reason using errcode='22023';end if;
 if j.kind='image' and exists(select 1 from storage.objects where bucket_id=j.bucket and name=j.path) then
  raise exception 'storage_object_still_registered' using errcode='22023';end if;
 if j.kind='video' then
  select * into a from public.exercise_video_assets where id=j.asset_id for update;
  if(a.creation_state in('creating','uncertain') or(a.creation_state<>'reserved' and a.provider_video_id is null)) and j.resolved_provider_video_id is null then
   raise exception 'provider_reconciliation_required' using errcode='22023';end if;
 end if;
 perform set_config('entrenaop.media_cleanup_transition','true',true);
 if j.kind='image' and j.scope='trainer' then
  update trainer_private.exercise_images set cleanup_state='deleted',deleted_at=clock_timestamp() where path=j.path and trainer_id=j.owner_id and deleted_at is null;
  get diagnostics changed=row_count;
  if changed=1 then
   update trainer_private.exercise_limits set image_used=image_used-1 where trainer_id=j.owner_id and image_used>0;
   if not found then raise exception 'image_quota_inconsistent' using errcode='22023';end if;
  end if;
 elsif j.kind='video' then update public.exercise_video_assets set cleanup_state='deleted',deleted_at=clock_timestamp() where id=j.asset_id and deleted_at is null;end if;
 perform set_config('entrenaop.media_cleanup_transition',coalesce(old_context,''),true);
 update trainer_private.media_cleanup_jobs set state='deleted',deleted_at=clock_timestamp(),blocked_reason=null,error_code=null,lease_until=null,updated_at=clock_timestamp()
  where id=j.id returning * into j;
 return trainer_private.media_job_json(j);
end $$;

create function public.prepare_exercise_video_upload(p_id uuid,p_expires_at timestamptz) returns jsonb
language plpgsql security definer set search_path='' as $$
declare a public.exercise_video_assets;
begin
 if p_expires_at is null or p_expires_at<=clock_timestamp() or p_expires_at>clock_timestamp()+interval '2 hours' then raise invalid_parameter_value;end if;
 perform trainer_private.media_lock('video:'||p_id::text);
 select * into a from public.exercise_video_assets where id=p_id for update;
 if not found or a.cleanup_state<>'active' or a.deleted_at is not null or a.status not in('uploading','processing') or a.creation_state<>'created' or a.provider_video_id is null then
  raise exception 'video_upload_closed' using errcode='22023';end if;
 update public.exercise_video_assets set upload_lease_until=greatest(upload_lease_until,p_expires_at) where id=p_id;
 return jsonb_build_object('id',p_id,'expires_at',p_expires_at);
end $$;

create function trainer_private.media_strings(p_body jsonb) returns text[]
language sql immutable set search_path='' as $$
 select array_agg(distinct s) from(
  select value#>>'{}' s from jsonb_path_query(p_body,'strict $.**') value where jsonb_typeof(value)='string'
  union select regexp_replace(split_part(value#>>'{}','?',1),'^https?://[^/]+/storage/v1/object/(public|sign|authenticated)/(trainer-exercise-images|exercise-images-public)/','')
   from jsonb_path_query(p_body,'strict $.**') value where jsonb_typeof(value)='string'
  union select m[1] from regexp_matches(p_body::text,'(official/[A-Za-z0-9_/-]+\.(?:jpg|jpeg))','g')m
  union select m[1] from regexp_matches(p_body::text,'([0-9a-fA-F-]{36}/[0-9a-fA-F-]{36}\.jpg)','g')m
 ) paths
$$;
create function trainer_private.media_reference_guard() returns trigger
language plpgsql security definer set search_path='' as $$
declare body jsonb;strings text[];ids uuid[];r record;blocked boolean;cached jsonb;active_body jsonb;j trainer_private.media_cleanup_jobs;a public.exercise_video_assets;guid uuid;
begin
 body:=case when tg_op='DELETE' then to_jsonb(old) when tg_op='UPDATE' then jsonb_build_array(to_jsonb(old),to_jsonb(new)) else to_jsonb(new) end;
 if tg_op<>'DELETE' then active_body:=to_jsonb(new);end if;
 if tg_op<>'DELETE' and tg_table_schema='trainer_private' and tg_table_name in('session_works','program_works') and(to_jsonb(new)->>'lifecycle')='open' then
  if tg_table_name='session_works' then select b.body into cached from trainer_private.session_work_bodies b where(b.owner_id,b.context,b.hash)=(new.owner_id,new.context,new.state_hash);
  else select b.body into cached from trainer_private.program_work_bodies b where(b.owner_id,b.context,b.hash)=(new.owner_id,new.context,new.state_hash);end if;
  body:=jsonb_build_array(body,cached);
  active_body:=jsonb_build_array(active_body,cached);
 elsif tg_op<>'DELETE' and tg_table_schema='trainer_private' and tg_table_name in('session_works','program_works') then active_body:=null;
 end if;
 if tg_op='UPDATE' and tg_table_schema='trainer_private' and tg_table_name in('session_work_bodies','program_work_bodies') then
  if new.body is not distinct from old.body then active_body:=null;end if;
 end if;
 body:=replace(replace(body::text,'%2F','/'),'%2f','/')::jsonb;
 if active_body is not null then active_body:=replace(replace(active_body::text,'%2F','/'),'%2f','/')::jsonb;end if;
 strings:=trainer_private.media_strings(body);
 select array_agg(distinct m[1]::uuid) into ids from regexp_matches(lower(body::text),'[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}','g')m;
 for guid in select x from unnest(ids)x order by x loop
  perform pg_advisory_xact_lock_shared(hashtextextended('exercise-media-guid:'||guid::text,0));
 end loop;
 for r in select distinct k from(
  select 'image:trainer-exercise-images:'||path k from trainer_private.exercise_images where path=any(strings) or id=any(ids)
  union select 'image:exercise-images-public:'||name from storage.objects where bucket_id='exercise-images-public' and name=any(strings)
  union select resource_key from trainer_private.media_cleanup_jobs where kind='image' and path=any(strings)
  union select 'video:'||id::text from public.exercise_video_assets where id=any(ids) or provider_video_id=any(ids) or playback_url=any(strings)
  union select resource_key from trainer_private.media_cleanup_jobs where kind='video' and resolved_provider_video_id=any(ids)
 ) refs order by k loop
  perform trainer_private.media_lock(r.k);
  if active_body is not null then
   select * into j from trainer_private.media_cleanup_jobs where resource_key=r.k and state in('deleting','retry','deleted');
   if found then
    if j.kind='video' then select * into a from public.exercise_video_assets where id=j.asset_id;else a:=null;end if;
    if trainer_private.media_contains(active_body,j.path,j.asset_id,a.playback_url,coalesce(j.resolved_provider_video_id,a.provider_video_id)) then
     raise exception 'El medio se está eliminando o ya fue eliminado. Guarda otra imagen o vídeo.' using errcode='22023';end if;
   end if;
  end if;
 end loop;
 if tg_op='DELETE' then return old;end if;return new;
end $$;



create function trainer_private.media_storage_guard() returns trigger
language plpgsql security definer set search_path='' as $$
declare b text;p text;k text;j trainer_private.media_cleanup_jobs;
begin
 if tg_op='DELETE' then b:=old.bucket_id;p:=old.name;else b:=new.bucket_id;p:=new.name;end if;
 if b not in('trainer-exercise-images','exercise-images-public') then if tg_op='DELETE' then return old;end if;return new;end if;
 k:='image:'||b||':'||p;perform trainer_private.media_lock(k);
 select * into j from trainer_private.media_cleanup_jobs where resource_key=k;
 if tg_op='DELETE' then
  if coalesce(auth.jwt()->>'role','')<>'service_role' or j.state is distinct from 'deleting' or j.lease_until is null or j.lease_until<=clock_timestamp() then
   raise exception 'Utiliza la limpieza de medios para borrar esta imagen.' using errcode='42501';end if;
 else
  if j.state in('deleting','retry','deleted') or exists(select 1 from trainer_private.exercise_images where path=p and cleanup_state<>'active') then
   raise exception 'image_upload_closed' using errcode='22023';end if;
 end if;
 if tg_op='DELETE' then return old;end if;return new;
end $$;
create trigger exercise_media_storage_guard before insert or update or delete on storage.objects for each row execute function trainer_private.media_storage_guard();

create function trainer_private.media_asset_guard() returns trigger
language plpgsql security definer set search_path='' as $$
declare id uuid;transition boolean:=current_setting('entrenaop.media_cleanup_transition',true)='true';
begin
 if tg_op='DELETE' then
  -- Conserva la cascada existente al eliminar al propietario; no convierte
  -- una limpieza de ficheros en un bloqueo general del borrado de cuenta.
  if old.trainer_id is not null and not exists(select 1 from public.profiles p where p.id=old.trainer_id) then return old;end if;
  raise exception 'Las reservas se conservan como tombstone.' using errcode='22023';
 end if;
 if tg_table_name='exercise_images' then id:=new.id;perform trainer_private.media_lock('image:trainer-exercise-images:'||new.path);
 else id:=new.id;perform trainer_private.media_lock('video:'||id::text);end if;
 if tg_op='UPDATE' then
  if not coalesce(transition,false) and(old.cleanup_state<>'active' or new.cleanup_state is distinct from old.cleanup_state or new.deleted_at is distinct from old.deleted_at) then
   raise exception 'media_upload_closed' using errcode='22023';end if;
 elsif new.cleanup_state<>'active' or new.deleted_at is not null then raise insufficient_privilege;
 end if;
 return new;
end $$;
create trigger exercise_image_cleanup_guard before insert or update or delete on trainer_private.exercise_images for each row execute function trainer_private.media_asset_guard();
create trigger exercise_video_cleanup_guard before insert or update or delete on public.exercise_video_assets for each row execute function trainer_private.media_asset_guard();

-- Se cercan tanto las recetas nuevas como los snapshots y borradores que
-- pueden adquirir una referencia. No se usa un bloqueo global entre autores.
do $$declare t regclass;begin
 for t in select unnest(array['public.exercises'::regclass,'public.workout_items'::regclass,'public.workout_sets'::regclass,'public.workout_execution_sets'::regclass,
  'public.guided_programs'::regclass,'public.admin_guided_work_drafts'::regclass,'admin_work_private.session_work'::regclass,
  'trainer_private.session_work_bodies'::regclass,'trainer_private.program_work_bodies'::regclass,'trainer_private.session_works'::regclass,'trainer_private.program_works'::regclass,
  'trainer_private.programs'::regclass,'trainer_private.workout_writes'::regclass,'trainer_private.program_writes'::regclass,'trainer_private.exercise_versions'::regclass])
  union select c.oid from pg_class c join pg_namespace n on n.oid=c.relnamespace where c.relkind='r' and n.nspname='device_private'
   and exists(select 1 from pg_attribute a where a.attrelid=c.oid and a.atttypid='jsonb'::regtype and a.attnum>0 and not a.attisdropped)
 loop execute format('create trigger aa_exercise_media_reference_guard before insert or update or delete on %s for each row execute function trainer_private.media_reference_guard()',t);end loop;
end $$;

create function trainer_private.enqueue_previous_exercise_media() returns trigger
language plpgsql security definer set search_path='' as $$
declare context_scope text;a public.exercise_video_assets;changed_image boolean;changed_video boolean;
begin
 if old.origin not in('system','coach') then return null;end if;
 if old.origin='coach' and not exists(select 1 from public.profiles where id=old.created_by) then return null;end if;
 context_scope:=case when old.origin='coach' then 'trainer' else 'official' end;
 changed_image:=old.image_path is not null and(tg_op='DELETE' or(old.origin='system' and old.image_path is distinct from new.image_path));
 changed_video:=old.video_url is not null and(tg_op='DELETE' or(old.origin='system' and old.video_url is distinct from new.video_url));
 if changed_video then
  select * into a from public.exercise_video_assets where playback_url=old.video_url and((context_scope='trainer' and trainer_id=old.created_by and a.scope='trainer_exercise') or(context_scope='official' and a.scope='official'));
  changed_video:=found;
 end if;
 if not changed_image and not changed_video then return null;end if;
 perform trainer_private.media_context(context_scope);
 if changed_image then perform trainer_private.enqueue_media(context_scope,'image',old.image_path);end if;
 if changed_video then
  perform trainer_private.enqueue_media(context_scope,'video',a.id::text);
 end if;
 return null;
end $$;
create trigger enqueue_previous_exercise_media after update of image_path,video_url or delete on public.exercises for each row execute function trainer_private.enqueue_previous_exercise_media();

create or replace function trainer_private.reserve_exercise_image(p_id uuid) returns text
language plpgsql security definer set search_path='' as $$
declare i trainer_private.exercise_images;p text;
begin
 perform trainer_private.require_authoring_access();if p_id is null then raise invalid_parameter_value;end if;
 p:=auth.uid()::text||'/'||p_id::text||'.jpg';perform trainer_private.media_lock('image:trainer-exercise-images:'||p);
 select * into i from trainer_private.exercise_images where id=p_id and trainer_id=auth.uid() for update;
 if found then
  if i.cleanup_state<>'active' or i.deleted_at is not null then raise exception 'La reserva de imagen fue retirada definitivamente.' using errcode='22023';end if;
  return i.path;
 end if;
 insert into trainer_private.exercise_limits(trainer_id) values(auth.uid()) on conflict do nothing;
 update trainer_private.exercise_limits set image_used=image_used+1 where trainer_id=auth.uid() and image_used<image_limit;
 if not found then raise exception 'Has alcanzado el límite de imágenes profesionales.' using errcode='22023';end if;
 insert into trainer_private.exercise_images(id,trainer_id,path) values(p_id,auth.uid(),p);return p;
end $$;

-- Mantiene las validaciones existentes; solo cerca estados retirados y deja
-- de contar reservas cuya ausencia externa ya quedó confirmada.
do $$declare signature text;definition text;anchor text;replacement text;begin
 for signature,anchor,replacement in values
  ('trainer_private.can_upload_exercise_image(text)','where i.path=p_path','where i.cleanup_state=''active'' and i.deleted_at is null and i.path=p_path'),
  ('trainer_private.can_read_exercise_image(text)','where path=p_path and trainer_id=auth.uid()','where cleanup_state=''active'' and deleted_at is null and path=p_path and trainer_id=auth.uid()'),
  ('trainer_private.can_manage_video(uuid)','where a.id=p_id','where a.cleanup_state=''active'' and a.deleted_at is null and a.id=p_id'),
  ('trainer_private.can_read_video(uuid)','where a.id=p_id','where a.cleanup_state=''active'' and a.deleted_at is null and a.id=p_id'),
  ('trainer_private.can_upload_video(uuid)','where v.id=p_id','where v.cleanup_state=''active'' and v.deleted_at is null and v.id=p_id'),
  ('trainer_private.video_usage()','where a.trainer_id=auth.uid() and a.scope=s.scope','where a.deleted_at is null and a.trainer_id=auth.uid() and a.scope=s.scope'),
  ('trainer_private.list_exercise_videos(timestamptz,uuid)','where scope=''trainer_exercise''','where cleanup_state=''active'' and deleted_at is null and scope=''trainer_exercise'''),
  ('trainer_private.reserve_video(text,uuid,bigint,text,integer,uuid,uuid,uuid)','from public.exercise_video_assets where trainer_id=coach and scope=p_scope','from public.exercise_video_assets where deleted_at is null and trainer_id=coach and scope=p_scope')
 loop
  definition:=pg_get_functiondef(signature::regprocedure);if strpos(definition,anchor)=0 then raise exception 'Revisar fence de medios: %',signature;end if;
  execute replace(definition,anchor,replacement);
 end loop;
 definition:=pg_get_functiondef('trainer_private.reserve_video(text,uuid,bigint,text,integer,uuid,uuid,uuid)'::regprocedure);
 anchor:='if found then';
 definition:=replace(definition,anchor,anchor||' if prior.cleanup_state<>''active'' or prior.deleted_at is not null then raise exception ''La reserva de vídeo fue retirada definitivamente.'' using errcode=''22023'';end if;');
 execute definition;
end $$;

-- Un servicio que llegue tarde de Bunny tampoco puede revivir el activo.
create function trainer_private.require_active_media_video(p_id uuid) returns void
language plpgsql security definer set search_path='' as $$begin
 perform trainer_private.media_lock('video:'||p_id::text);
 perform 1 from public.exercise_video_assets where id=p_id and cleanup_state='active' and deleted_at is null;
 if not found then raise exception 'video_upload_closed' using errcode='22023';end if;
end $$;
do $$declare signature text;definition text;begin
 for signature in select unnest(array['public.claim_exercise_video_creation(uuid,uuid)','public.complete_exercise_video_creation(uuid,uuid,uuid,boolean)','public.mark_exercise_video_creation_uncertain(uuid,uuid)']) loop
  definition:=pg_get_functiondef(signature::regprocedure);
  if signature like '%mark_exercise%' then
   execute 'create or replace function public.mark_exercise_video_creation_uncertain(p_id uuid,p_claim uuid) returns void language plpgsql security definer set search_path='''' as $f$ begin perform trainer_private.require_active_media_video(p_id);update public.exercise_video_assets set creation_state=''uncertain'',updated_at=now() where id=p_id and creation_claim=p_claim and creation_state=''creating'';end $f$';
  else
   if strpos(definition,'begin')=0 then raise exception 'Revisar creador de vídeo';end if;
   definition:=regexp_replace(definition,'\mbegin\M','begin perform trainer_private.require_active_media_video(p_id);',1,1);
   if signature like '%claim_exercise%' then
    definition:=replace(definition,'set creation_state=''creating'',creation_claim=p_claim','set creation_guard_until=greatest(creation_guard_until,clock_timestamp()+interval ''5 minutes''),creation_state=''creating'',creation_claim=p_claim');
   end if;
   execute definition;
  end if;
 end loop;
end $$;

create function public.queue_exercise_media_cleanup(p_operation_id uuid,p_scope text,p_kind text,p_target text) returns jsonb
language sql security invoker set search_path='' as $$select trainer_private.queue_media(p_operation_id,p_scope,p_kind,p_target)$$;
create function public.sweep_exercise_media_cleanup(p_operation_id uuid,p_scope text,p_limit integer default 50) returns jsonb
language sql security invoker set search_path='' as $$select trainer_private.sweep_media(p_operation_id,p_scope,p_limit)$$;
create function public.list_exercise_media_cleanup(p_scope text,p_before_at timestamptz default null,p_before_id uuid default null,p_limit integer default 50) returns jsonb
language sql security invoker set search_path='' as $$select trainer_private.list_media(p_scope,p_before_at,p_before_id,p_limit)$$;
create function public.claim_exercise_media_cleanup(p_limit integer,p_owner uuid,p_claim uuid,p_scope text default null) returns jsonb
language sql security invoker set search_path='' as $$select trainer_private.claim_media(p_limit,p_owner,p_claim,p_scope)$$;
create function public.finish_exercise_media_cleanup(p_job_id uuid,p_lease_id uuid,p_deleted boolean,p_error_code text default null) returns jsonb
language sql security invoker set search_path='' as $$select trainer_private.finish_media(p_job_id,p_lease_id,p_deleted,p_error_code)$$;
create function public.resolve_exercise_media_cleanup_provider(p_job_id uuid,p_lease_id uuid,p_provider_video_id uuid) returns jsonb
language sql security invoker set search_path='' as $$select trainer_private.resolve_media(p_job_id,p_lease_id,p_provider_video_id)$$;

create function trainer_private.consume_media_ticket(p_token text) returns boolean
language plpgsql security definer set search_path='' as $$
declare consumed boolean;
begin
 if p_token is null or p_token!~'^[A-Za-z0-9_-]{43}$' then return false;end if;
 update trainer_private.media_cleanup_settings set ticket_used=true where singleton and enabled and not ticket_used
  and ticket_expires_at>clock_timestamp() and ticket_hash=encode(sha256(convert_to(p_token,'UTF8')),'hex') returning true into consumed;
 return coalesce(consumed,false);
end $$;
create function public.consume_exercise_media_cleanup_ticket(p_token text) returns boolean
language sql security invoker set search_path='' as $$select trainer_private.consume_media_ticket(p_token)$$;
create function trainer_private.dispatch_media_cleanup_dev() returns bigint
language plpgsql security definer set search_path='' as $$
declare ticket text;public_jwt text;
begin
 perform 1 from trainer_private.media_cleanup_settings where singleton and enabled for update;
 if not found then return null;end if;
 if exists(select 1 from trainer_private.media_cleanup_settings where singleton and not ticket_used and ticket_expires_at>clock_timestamp()) then return null;end if;
 if not exists(select 1 from trainer_private.media_cleanup_jobs where state in('queued','retry','deleting') and available_at<=clock_timestamp()
  and(lease_until is null or lease_until<clock_timestamp())) then return null;end if;
 select decrypted_secret into public_jwt from vault.decrypted_secrets where name='student_push_dev_public_jwt';
 if public_jwt is null then return null;end if;
 ticket:=rtrim(translate(encode(extensions.gen_random_bytes(32),'base64'),'+/','-_'),'=');
 update trainer_private.media_cleanup_settings set ticket_hash=encode(sha256(convert_to(ticket,'UTF8')),'hex'),ticket_expires_at=clock_timestamp()+interval '55 seconds',ticket_used=false where singleton;
 return net.http_post(url:='https://sxbxfjqgoddzhtcyhalw.supabase.co/functions/v1/trainer-media-cleanup',
  headers:=jsonb_build_object('Content-Type','application/json','Authorization','Bearer '||public_jwt,'X-EntrenaOP-Media-Ticket',ticket),body:='{"action":"tick"}'::jsonb,timeout_milliseconds:=55000);
end $$;

do $$declare f regprocedure;begin
 for f in select p.oid::regprocedure from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where(n.nspname='trainer_private' and(p.proname like 'media_%' or p.proname in('enqueue_media','queue_media','sweep_media','list_media','claim_media','resolve_media','finish_media',
   'enqueue_previous_exercise_media','require_active_media_video','consume_media_ticket','dispatch_media_cleanup_dev')))
  or(n.nspname='public' and p.proname in('queue_exercise_media_cleanup','sweep_exercise_media_cleanup','list_exercise_media_cleanup','claim_exercise_media_cleanup','finish_exercise_media_cleanup',
   'resolve_exercise_media_cleanup_provider','prepare_exercise_video_upload','consume_exercise_media_cleanup_ticket')) loop
  execute format('revoke all on function %s from public,anon,authenticated,service_role',f);
 end loop;
end $$;
grant execute on function public.queue_exercise_media_cleanup(uuid,text,text,text),public.sweep_exercise_media_cleanup(uuid,text,integer),public.list_exercise_media_cleanup(text,timestamptz,uuid,integer),
 trainer_private.queue_media(uuid,text,text,text),trainer_private.sweep_media(uuid,text,integer),trainer_private.list_media(text,timestamptz,uuid,integer) to authenticated;
grant execute on function public.claim_exercise_media_cleanup(integer,uuid,uuid,text),public.finish_exercise_media_cleanup(uuid,uuid,boolean,text),public.resolve_exercise_media_cleanup_provider(uuid,uuid,uuid),
 public.prepare_exercise_video_upload(uuid,timestamptz),public.consume_exercise_media_cleanup_ticket(text),trainer_private.claim_media(integer,uuid,uuid,text),trainer_private.finish_media(uuid,uuid,boolean,text),
 trainer_private.resolve_media(uuid,uuid,uuid),trainer_private.consume_media_ticket(text) to service_role;
grant usage on schema trainer_private to service_role;

commit;
