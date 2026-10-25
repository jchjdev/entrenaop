begin;
create table trainer_private.notice_groups (
 id uuid primary key default gen_random_uuid(),owner_id uuid not null references public.profiles on delete cascade,
 relation_id uuid not null references public.trainer_client_relations on delete cascade,
 kind text not null check(kind in ('message','assignment','form','assessment','techniqueFeedback')),
 group_key text not null,generation bigint not null default 1 check(generation>0),last_at timestamptz not null,
 unique(owner_id,relation_id,group_key)
);
alter table trainer_private.notice_groups enable row level security;
revoke all on trainer_private.notice_groups from public,anon,authenticated;
alter table trainer_private.student_notices add column group_id uuid references trainer_private.notice_groups on delete cascade,
 add column group_generation bigint check(group_generation>0);
-- El backfill solo presenta el historial: no inserta avisos ni genera push.
insert into trainer_private.notice_groups(owner_id,relation_id,kind,group_key,generation,last_at)
 select owner_id,relation_id,kind,case when kind in ('assignment','message') then kind else id::text end,
 count(*),max(created_at) from trainer_private.student_notices
 group by owner_id,relation_id,kind,case when kind in ('assignment','message') then kind else id::text end;
with numbered as (
 select n.id,g.id as group_id,row_number() over(partition by g.id order by n.created_at,n.id) as generation
 from trainer_private.student_notices n join trainer_private.notice_groups g on g.owner_id=n.owner_id
 and g.relation_id=n.relation_id and g.group_key=case when n.kind in ('assignment','message') then n.kind else n.id::text end
) update trainer_private.student_notices n set group_id=x.group_id,group_generation=x.generation from numbered x where x.id=n.id;
alter table trainer_private.student_notices alter column group_id set not null,alter column group_generation set not null;
create index student_notice_group_page on trainer_private.student_notices(group_id,group_generation desc);
create index student_notice_group_unread on trainer_private.student_notices(owner_id,group_id) where read_at is null;
create index student_notice_group_feed on trainer_private.notice_groups(owner_id,last_at desc,id desc);
create function trainer_private.attach_notice_group() returns trigger
language plpgsql security definer set search_path='' as $$begin
 -- Una sola secuencia por alumno: no depende de fechas del cliente y evita que
 -- un acuse de lectura antiguo absorba un mensaje confirmado posteriormente.
 perform pg_advisory_xact_lock(hashtextextended(new.owner_id::text,204610));
 -- Los emisores originales reintentan con ON CONFLICT DO NOTHING. Su BEFORE
 -- no debe adelantar el grupo cuando finalmente no se inserta ningún aviso.
 if exists(select 1 from trainer_private.student_notices where id=new.id or
  (owner_id=new.owner_id and kind=new.kind and source_id=new.source_id and source_revision=new.source_revision)) then return null;end if;
 insert into trainer_private.notice_groups(owner_id,relation_id,kind,group_key,last_at)
 values(new.owner_id,new.relation_id,new.kind,case when new.kind in ('assignment','message') then new.kind else new.id::text end,new.created_at)
 on conflict(owner_id,relation_id,group_key) do update set generation=notice_groups.generation+1,
 last_at=greatest(notice_groups.last_at,excluded.last_at)
 returning id,generation into new.group_id,new.group_generation;
 return new;
end $$;
revoke all on function trainer_private.attach_notice_group() from public,anon,authenticated,service_role;
create trigger attach_student_notice_group before insert on trainer_private.student_notices
 for each row execute function trainer_private.attach_notice_group();

create function trainer_private.group_snapshot(p_expected_owner uuid,p_before_at timestamptz default null,p_before_id uuid default null,p_kind text default null)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare resources jsonb;result jsonb;
begin
 perform trainer_private.require_student_notice_owner(p_expected_owner);
 if (p_before_at is null)<>(p_before_id is null) or (p_kind is not null and p_kind not in ('message','assignment','form','assessment','techniqueFeedback')) then raise invalid_parameter_value;end if;
 resources:=trainer_private.student_notice_snapshot(p_expected_owner)->'resources';
 with page as (
  select g.id,g.kind,g.generation as group_generation,g.last_at as created_at,n.source_revision,
   (select coalesce(nullif(btrim(p.full_name),''),'Tu preparador') from public.trainer_client_relations r join public.profiles p on p.id=r.trainer_id where r.id=g.relation_id) as trainer_name,
   (select count(*) from trainer_private.student_notices m where m.group_id=g.id) as event_count,
   (select count(*) from trainer_private.student_notices m where m.group_id=g.id and m.read_at is null) as new_count,
   case when exists(select 1 from trainer_private.student_notices m where m.group_id=g.id and m.read_at is null) then null
    else (select max(read_at) from trainer_private.student_notices m where m.group_id=g.id) end as read_at
  from trainer_private.notice_groups g join trainer_private.student_notices n on n.group_id=g.id and n.group_generation=g.generation
  where g.owner_id=auth.uid() and (p_kind is null or g.kind=p_kind)
   and (p_before_at is null or (g.last_at,g.id)<(p_before_at,p_before_id))
  order by g.last_at desc,g.id desc limit 51
 ), visible as(select * from page order by created_at desc,id desc limit 50)
 select jsonb_build_object('items',coalesce((select jsonb_agg(to_jsonb(v) order by created_at desc,id desc) from visible v),'[]'),
 'has_more',(select count(*)>50 from page),'resources',resources,
 'unread_count',(select count(distinct group_id) from trainer_private.student_notices where owner_id=auth.uid() and read_at is null)) into result;
 return result;
end $$;
create function trainer_private.ack_notice_group(p_expected_owner uuid,p_group_id uuid,p_generation bigint) returns void
language plpgsql security definer set search_path='' as $$begin
 perform trainer_private.require_student_notice_owner(p_expected_owner);
 if p_generation is null or not exists(select 1 from trainer_private.notice_groups where id=p_group_id and owner_id=auth.uid() and p_generation between 1 and generation) then raise insufficient_privilege;end if;
 update trainer_private.student_notices set read_at=coalesce(read_at,clock_timestamp())
 where owner_id=auth.uid() and group_id=p_group_id and group_generation<=p_generation;
end $$;
create function trainer_private.resolve_notice_group(p_expected_owner uuid,p_group_id uuid,p_generation bigint) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare g trainer_private.notice_groups;n uuid;day date;
begin
 perform trainer_private.require_student_notice_owner(p_expected_owner);
 select * into g from trainer_private.notice_groups where id=p_group_id and owner_id=auth.uid() and p_generation between 1 and generation;
 if not found then raise insufficient_privilege;end if;
 if g.kind='assignment' then
  select min(s.scheduled_date) filter(where s.status='planned' and s.scheduled_date>=current_date)
  into day from trainer_private.student_notices m join public.scheduled_workouts s on s.id=m.source_id
  where m.group_id=g.id and m.group_generation<=p_generation and s.user_id=auth.uid();
  -- La agenda sigue siendo propia y resuelve sus recursos con sus permisos.
  if day is null then select min(s.scheduled_date) into day from trainer_private.student_notices m join public.scheduled_workouts s on s.id=m.source_id
   where m.group_id=g.id and m.group_generation<=p_generation and s.user_id=auth.uid();end if;
  if day is null then return null;end if;
  return jsonb_build_object('kind','planning','target_id',g.id,'scheduled_date',day);
 end if;
 select id into n from trainer_private.student_notices where group_id=g.id and group_generation<=p_generation order by group_generation desc limit 1;
 return trainer_private.student_notice_target(n);
end $$;

create table push_private.preferences (
 owner_id uuid primary key references public.profiles on delete cascade,revision bigint not null default 0 check(revision>=0),
 reminder_mode text not null default 'off' check(reminder_mode in ('off','sameDay','previousDay')),
 reminder_minute integer not null default 540 check(reminder_minute between 0 and 1439),
 timezone text not null default 'Europe/Madrid',quiet_enabled boolean not null default true,
 quiet_start integer not null default 1320 check(quiet_start between 0 and 1439),quiet_end integer not null default 480 check(quiet_end between 0 and 1439),
 updated_at timestamptz not null default now(),check(not quiet_enabled or quiet_start<>quiet_end)
);
alter table push_private.preferences enable row level security;
revoke all on push_private.preferences from public,anon,authenticated;
create function push_private.preference_json(p_owner uuid) returns jsonb
language sql stable security definer set search_path='' as $$
 select coalesce((select to_jsonb(p)-'owner_id'-'updated_at' from push_private.preferences p where owner_id=p_owner),
 '{"revision":0,"reminder_mode":"off","reminder_minute":540,"timezone":"Europe/Madrid","quiet_enabled":true,"quiet_start":1320,"quiet_end":480}'::jsonb);
$$;
create or replace function push_private.configuration(p_expected_owner uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$begin
 perform push_private.identity(p_expected_owner);
 return (select jsonb_build_object('enabled',enabled,'firebase_project_id',firebase_project_id,
  'preferences',push_private.preference_json(auth.uid())) from push_private.settings where singleton);
end $$;
create function push_private.save_preferences(p_expected_owner uuid,p_revision bigint,p_mode text,p_minute integer,p_timezone text,
 p_quiet_enabled boolean,p_quiet_start integer,p_quiet_end integer) returns jsonb
language plpgsql security definer set search_path='' as $$
declare p push_private.preferences;
begin
 perform push_private.identity(p_expected_owner);
 if p_revision is null or p_mode is null or p_mode not in ('off','sameDay','previousDay') or p_minute is null or p_minute not between 0 and 1439
  or p_timezone is null or not exists(select 1 from pg_timezone_names where name=p_timezone and (name like '%/%' or name='UTC'))
  or p_quiet_enabled is null or p_quiet_start is null or p_quiet_end is null or p_quiet_start not between 0 and 1439 or p_quiet_end not between 0 and 1439
  or (p_quiet_enabled and p_quiet_start=p_quiet_end) then raise invalid_parameter_value;end if;
 if p_mode<>'off' and p_quiet_enabled and (case when p_quiet_start<p_quiet_end then p_minute>=p_quiet_start and p_minute<p_quiet_end else p_minute>=p_quiet_start or p_minute<p_quiet_end end) then
  raise exception 'Elige una hora fuera del horario de descanso.' using errcode='22023';end if;
 perform 1 from public.profiles where id=auth.uid() for key share;
 if not found then raise insufficient_privilege;end if;
 insert into push_private.preferences(owner_id) values(auth.uid()) on conflict do nothing;
 select * into p from push_private.preferences where owner_id=auth.uid() for update;
 if p.revision<>p_revision then raise exception 'Los ajustes han cambiado. Actualiza antes de guardar.' using errcode='40001';end if;
 update push_private.preferences set revision=revision+1,reminder_mode=p_mode,reminder_minute=p_minute,timezone=p_timezone,
  quiet_enabled=p_quiet_enabled,quiet_start=p_quiet_start,quiet_end=p_quiet_end,updated_at=clock_timestamp() where owner_id=auth.uid();
 return push_private.preference_json(auth.uid());
end $$;
create function public.get_my_trainer_notice_groups(p_expected_owner uuid,p_before_at timestamptz default null,p_before_id uuid default null,p_kind text default null)
returns jsonb language sql stable security invoker set search_path='' as $$select trainer_private.group_snapshot(p_expected_owner,p_before_at,p_before_id,p_kind)$$;
create function public.ack_my_trainer_notice_group(p_expected_owner uuid,p_group_id uuid,p_generation bigint) returns void
language sql security invoker set search_path='' as $$select trainer_private.ack_notice_group(p_expected_owner,p_group_id,p_generation)$$;
create function public.resolve_my_trainer_notice_group(p_expected_owner uuid,p_group_id uuid,p_generation bigint) returns jsonb
language sql stable security invoker set search_path='' as $$select trainer_private.resolve_notice_group(p_expected_owner,p_group_id,p_generation)$$;
create function public.save_my_trainer_notice_preferences(p_expected_owner uuid,p_revision bigint,p_mode text,p_minute integer,p_timezone text,
 p_quiet_enabled boolean,p_quiet_start integer,p_quiet_end integer) returns jsonb language sql security invoker set search_path='' as $$
 select push_private.save_preferences(p_expected_owner,p_revision,p_mode,p_minute,p_timezone,p_quiet_enabled,p_quiet_start,p_quiet_end)$$;
create function public.get_my_notice_timezones(p_expected_owner uuid) returns jsonb
language plpgsql stable security invoker set search_path='' as $$begin
 perform public.get_my_push_configuration(p_expected_owner);
 return (select jsonb_agg(name order by name) from pg_timezone_names where (name like '%/%' and name not like 'posix/%' and name not like 'right/%') or name='UTC');
end $$;

create function push_private.next_allowed(p_owner uuid,p_at timestamptz) returns timestamptz
language plpgsql stable security definer set search_path='' as $$
declare cfg jsonb:=push_private.preference_json(p_owner);local_at timestamp;minute integer;start_at integer;end_at integer;day date;
begin
 if not (cfg->>'quiet_enabled')::boolean then return p_at;end if;
 local_at:=p_at at time zone (cfg->>'timezone');minute:=extract(hour from local_at)::integer*60+extract(minute from local_at)::integer;
 start_at:=(cfg->>'quiet_start')::integer;end_at:=(cfg->>'quiet_end')::integer;day:=local_at::date;
 if start_at<end_at then
  if minute<start_at or minute>=end_at then return p_at;end if;
 else
  if minute>=end_at and minute<start_at then return p_at;end if;
  if minute>=start_at then day:=day+1;end if;
 end if;
 return (day::timestamp+make_interval(mins=>end_at)) at time zone (cfg->>'timezone');
end $$;
create function push_private.notice_due(p_owner uuid,p_kind text,p_first timestamptz,p_last timestamptz,p_sent timestamptz) returns timestamptz
language sql stable security definer set search_path='' as $$
 select push_private.next_allowed(p_owner,greatest(
  least(p_last+case p_kind when 'assignment' then interval '5 minutes' when 'message' then interval '1 minute' else interval '30 seconds' end,
    p_first+case p_kind when 'assignment' then interval '15 minutes' else interval '2 minutes' end),
  coalesce(p_sent+case p_kind when 'assignment' then interval '30 minutes' else interval '5 minutes' end,'-infinity'::timestamptz)));
$$;
create table push_private.notice_jobs (
 id uuid primary key default gen_random_uuid(),installation_id uuid not null references push_private.installations on delete cascade,
 owner_id uuid not null references public.profiles on delete cascade,relation_id uuid references public.trainer_client_relations on delete cascade,
 kind text not null check(kind in ('assignment','message','other','reminder')),scope_key text not null,
 generation bigint not null default 1 check(generation>0),delivered_generation bigint not null default 0,
 first_pending_at timestamptz not null default now(),last_event_at timestamptz not null default now(),last_sent_at timestamptz,
 next_at timestamptz not null,attempts integer not null default 0 check(attempts between 0 and 8),
 claim_id uuid,lease_until timestamptz,lease_generation bigint,
 reminder_date date,reminder_revision bigint,expires_at timestamptz,
 unique(installation_id,owner_id,scope_key),check(delivered_generation between 0 and generation),
 check((claim_id is null)=(lease_until is null) and (claim_id is null)=(lease_generation is null)),
 check((kind='reminder')=(reminder_date is not null))
);
create index push_notice_due on push_private.notice_jobs(next_at) where generation>delivered_generation and attempts<8;
create table push_private.job_notices (
 job_id uuid not null references push_private.notice_jobs on delete cascade,
 notice_id uuid not null references trainer_private.student_notices on delete cascade,
 generation bigint not null,primary key(job_id,generation,notice_id),unique(job_id,notice_id)
);
alter table push_private.notice_jobs enable row level security;
alter table push_private.job_notices enable row level security;
revoke all on push_private.notice_jobs,push_private.job_notices from public,anon,authenticated;
create index push_reminder_preferences on push_private.preferences(owner_id) where reminder_mode<>'off';
create function push_private.capture_grouped_notice() returns trigger
language plpgsql security definer set search_path='' as $$
declare d push_private.installations;q push_private.notice_jobs;category text;moment timestamptz:=clock_timestamp();
begin
 if new.read_at is not null or not exists(select 1 from push_private.settings where singleton and enabled) then return new;end if;
 category:=case when new.kind in ('assignment','message') then new.kind else 'other' end;
 for d in select * from push_private.installations where owner_id=new.owner_id and active and last_seen>moment-interval '90 days' order by id loop
  insert into push_private.notice_jobs(installation_id,owner_id,relation_id,kind,scope_key,next_at,first_pending_at,last_event_at)
  values(d.id,new.owner_id,new.relation_id,category,new.relation_id::text||':'||category,moment,moment,moment)
  on conflict(installation_id,owner_id,scope_key) do update set generation=notice_jobs.generation+1,attempts=0,
   first_pending_at=case when notice_jobs.generation=notice_jobs.delivered_generation then moment else notice_jobs.first_pending_at end,last_event_at=moment
  returning * into q;
  update push_private.notice_jobs set next_at=push_private.notice_due(q.owner_id,q.kind,q.first_pending_at,q.last_event_at,q.last_sent_at) where id=q.id;
  insert into push_private.job_notices(job_id,notice_id,generation) values(q.id,new.id,q.generation);
 end loop;
 return new;
end $$;
create trigger student_notice_grouped_push after insert on trainer_private.student_notices for each row execute function push_private.capture_grouped_notice();

create function push_private.has_training(p_owner uuid,p_day date) returns boolean
language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.scheduled_workouts s join public.trainer_assignments t on t.scheduled_id=s.id
  join public.trainer_client_relations r on r.id=t.relation_id join public.trainer_access a on a.trainer_id=r.trainer_id
  where s.user_id=p_owner and t.client_id=p_owner and s.source='coach' and s.status='planned' and s.execution_id is null and s.scheduled_date=p_day
   and r.client_id=p_owner and r.ended_at is null and a.enabled and (a.valid_until is null or a.valid_until>statement_timestamp()));
$$;
create function push_private.enqueue_reminders(p_now timestamptz) returns void
language plpgsql security definer set search_path='' as $$
declare p push_private.preferences;d push_private.installations;day date;due_at timestamptz;until_at timestamptz;
begin
 if not exists(select 1 from push_private.settings where singleton and enabled) then return;end if;
 for p in select * from push_private.preferences where reminder_mode<>'off' order by owner_id loop
  day:=(p_now at time zone p.timezone)::date;
  due_at:=(day::timestamp+make_interval(mins=>p.reminder_minute)) at time zone p.timezone;
  until_at:=least(due_at+interval '2 hours',((day+1)::timestamp at time zone p.timezone));
  if p.updated_at>due_at or p_now<due_at or p_now>=until_at then continue;end if;
  if p.reminder_mode='previousDay' then day:=day+1;end if;
  if not push_private.has_training(p.owner_id,day) then continue;end if;
  for d in select * from push_private.installations where owner_id=p.owner_id and active and last_seen>p_now-interval '90 days' order by id loop
   insert into push_private.notice_jobs(installation_id,owner_id,kind,scope_key,next_at,reminder_date,reminder_revision,expires_at)
   values(d.id,p.owner_id,'reminder','reminder:'||day::text,p_now,day,p.revision,until_at)
   on conflict(installation_id,owner_id,scope_key) do update set generation=notice_jobs.generation+1,reminder_revision=p.revision,
    next_at=p_now,expires_at=until_at,attempts=0
   where notice_jobs.last_sent_at is null and (notice_jobs.reminder_revision<>p.revision or notice_jobs.generation=notice_jobs.delivered_generation)
    and (notice_jobs.lease_until is null or notice_jobs.lease_until<p_now);
  end loop;
 end loop;
end $$;
create function push_private.claim_notice_jobs(p_limit integer) returns jsonb
language plpgsql security definer set search_path='' as $$
declare result jsonb;
begin
 if p_limit is null or p_limit not between 1 and 20 then raise invalid_parameter_value;end if;
 if not exists(select 1 from push_private.settings where singleton and enabled) then return '[]';end if;
 with candidates as (
  select q.id from push_private.notice_jobs q join push_private.installations d on d.id=q.installation_id
  where q.generation>q.delivered_generation and q.attempts<8 and q.next_at<=clock_timestamp()
   and (q.lease_until is null or q.lease_until<clock_timestamp()) and d.active and d.owner_id=q.owner_id and d.last_seen>clock_timestamp()-interval '90 days'
   and push_private.next_allowed(q.owner_id,clock_timestamp())<=clock_timestamp()
  order by q.next_at,q.id limit p_limit for update of q skip locked
 ), claimed as (
  update push_private.notice_jobs q set claim_id=gen_random_uuid(),lease_until=clock_timestamp()+interval '2 minutes',lease_generation=q.generation
  from candidates c where c.id=q.id returning q.*
 ) select coalesce(jsonb_agg(jsonb_build_object('job_id',q.id,'installation_id',q.installation_id,'claim_id',q.claim_id,
    'generation',q.lease_generation,'binding_id',d.binding_id,'token',d.token)),'[]') into result
 from claimed q join push_private.installations d on d.id=q.installation_id;
 return result;
end $$;
create function push_private.prepare_notice_job(p_id uuid,p_claim uuid,p_generation bigint,p_binding uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare q push_private.notice_jobs;p push_private.preferences;
begin
 select j.* into q from push_private.notice_jobs j join push_private.installations d on d.id=j.installation_id
 where j.id=p_id and j.claim_id=p_claim and j.lease_generation=p_generation and j.lease_until>statement_timestamp()
  and d.binding_id=p_binding and d.owner_id=j.owner_id and d.active;
 if not found or not exists(select 1 from push_private.settings where singleton and enabled) then return null;end if;
 if push_private.next_allowed(q.owner_id,statement_timestamp())>statement_timestamp() then return jsonb_build_object('kind','defer');end if;
 if q.kind='reminder' then
  select * into p from push_private.preferences where owner_id=q.owner_id;
  if not found or p.reminder_mode='off' or p.revision<>q.reminder_revision or q.expires_at<=statement_timestamp()
   or not push_private.has_training(q.owner_id,q.reminder_date) then return null;end if;
 else
  if not exists(select 1 from push_private.job_notices j join trainer_private.student_notices n on n.id=j.notice_id
   join public.trainer_client_relations r on r.id=n.relation_id join public.trainer_access a on a.trainer_id=r.trainer_id
   where j.job_id=q.id and j.generation>q.delivered_generation and j.generation<=p_generation and n.owner_id=q.owner_id
    and n.read_at is null and n.created_at>statement_timestamp()-interval '24 hours' and r.client_id=q.owner_id and r.ended_at is null
    and a.enabled and (a.valid_until is null or a.valid_until>statement_timestamp())) then return null;end if;
 end if;
 return jsonb_build_object('kind',q.kind,'previous_day',q.kind='reminder' and p.reminder_mode='previousDay');
end $$;
create function push_private.finish_notice_job(p_id uuid,p_claim uuid,p_generation bigint,p_binding uuid,p_outcome text) returns void
language plpgsql security definer set search_path='' as $$
declare q push_private.notice_jobs;
begin
 if p_outcome is null or p_outcome not in ('sent','skipped','retry','invalid','deferred') then raise invalid_parameter_value;end if;
 select * into q from push_private.notice_jobs where id=p_id for update;
 if not found or q.claim_id is distinct from p_claim or q.lease_generation is distinct from p_generation or q.lease_until<=clock_timestamp() then return;end if;
 if not exists(select 1 from push_private.installations where id=q.installation_id and binding_id=p_binding and owner_id=q.owner_id) then return;end if;
 update push_private.notice_jobs set delivered_generation=case when p_outcome in ('retry','deferred') then delivered_generation else p_generation end,
  last_sent_at=case when p_outcome='sent' then clock_timestamp() else last_sent_at end,
  attempts=case when p_outcome='retry' then least(attempts+1,8) else 0 end,
  claim_id=null,lease_until=null,lease_generation=null where id=q.id;
 select * into q from push_private.notice_jobs where id=q.id;
 update push_private.notice_jobs set next_at=case when p_outcome='deferred' then push_private.next_allowed(q.owner_id,clock_timestamp()) when p_outcome='retry' then clock_timestamp()+make_interval(secs=>least(1800,15*(2^q.attempts)::integer))
  when q.kind='reminder' then clock_timestamp() else push_private.notice_due(q.owner_id,q.kind,q.first_pending_at,q.last_event_at,q.last_sent_at) end where id=q.id;
 -- El protocolo anterior se conserva por compatibilidad, sin despacharlo otra
 -- vez. Sus filas son por instalación; el historial de avisos no se modifica.
 update push_private.outbox set delivered_generation=generation,claim_id=null,lease_until=null,lease_generation=null
 where installation_id=q.installation_id and owner_id=q.owner_id and p_outcome not in ('retry','deferred')
  and exists(select 1 from push_private.installations where id=q.installation_id and binding_id=p_binding and owner_id=q.owner_id);
end $$;
create function public.claim_student_notice_jobs(p_limit integer) returns jsonb language sql security invoker set search_path='' as $$select push_private.claim_notice_jobs(p_limit)$$;
create function public.prepare_student_notice_job(p_id uuid,p_claim uuid,p_generation bigint,p_binding uuid) returns jsonb language sql stable security invoker set search_path='' as $$select push_private.prepare_notice_job(p_id,p_claim,p_generation,p_binding)$$;
create function public.finish_student_notice_job(p_id uuid,p_claim uuid,p_generation bigint,p_binding uuid,p_outcome text) returns void language sql security invoker set search_path='' as $$select push_private.finish_notice_job(p_id,p_claim,p_generation,p_binding,p_outcome)$$;
create function push_private.reminder_target(p_expected_owner uuid) returns date
language plpgsql stable security definer set search_path='' as $$
declare result date;
begin
 perform push_private.identity(p_expected_owner);
 select reminder_date into result from push_private.notice_jobs where owner_id=auth.uid() and kind='reminder'
  and last_sent_at>statement_timestamp()-interval '2 hours'
  and push_private.has_training(auth.uid(),reminder_date) order by last_sent_at desc limit 1;
 return result;
end $$;
create function public.resolve_my_trainer_reminder(p_expected_owner uuid) returns date
language sql stable security invoker set search_path='' as $$select push_private.reminder_target(p_expected_owner)$$;

create or replace function push_private.dispatch_due_dev() returns bigint
language plpgsql security definer set search_path='' as $$
declare ticket text;public_jwt text;
begin
 perform push_private.enqueue_reminders(clock_timestamp());
 perform 1 from push_private.settings where singleton and enabled and firebase_project_id='entrenaop-dev' for update;
 if not found then return null;end if;
 if exists(select 1 from push_private.settings where singleton and not dispatch_ticket_used and dispatch_ticket_expires_at>clock_timestamp()) then return null;end if;
 if not exists(select 1 from push_private.notice_jobs q join push_private.installations d on d.id=q.installation_id
  where q.generation>q.delivered_generation and q.attempts<8 and q.next_at<=clock_timestamp()
   and (q.lease_until is null or q.lease_until<clock_timestamp()) and d.active and d.owner_id=q.owner_id
   and d.last_seen>clock_timestamp()-interval '90 days' and push_private.next_allowed(q.owner_id,clock_timestamp())<=clock_timestamp()) then return null;end if;
 select decrypted_secret into public_jwt from vault.decrypted_secrets where name='student_push_dev_public_jwt';
 if public_jwt is null then return null;end if;
 ticket:=rtrim(translate(encode(extensions.gen_random_bytes(32),'base64'),'+/','-_'),'=');
 update push_private.settings set dispatch_ticket_hash=encode(sha256(convert_to(ticket,'UTF8')),'hex'),dispatch_ticket_expires_at=clock_timestamp()+interval '55 seconds',dispatch_ticket_used=false where singleton;
 return net.http_post(url:='https://sxbxfjqgoddzhtcyhalw.supabase.co/functions/v1/student-push',
 headers:=jsonb_build_object('Content-Type','application/json','Authorization','Bearer '||public_jwt,'X-EntrenaOP-Push-Ticket',ticket),body:='{}'::jsonb,timeout_milliseconds:=55000);
end $$;

-- Las fachadas propias no conceden lectura directa de tablas ni derechos Pro.
do $$declare f record;begin
 for f in select p.oid::regprocedure as signature,p.proname from pg_proc p join pg_namespace n on n.oid=p.pronamespace
 where (n.nspname='trainer_private' and p.proname in ('group_snapshot','ack_notice_group','resolve_notice_group'))
  or (n.nspname='push_private' and p.proname in ('preference_json','save_preferences','next_allowed','notice_due','capture_grouped_notice','has_training','enqueue_reminders','claim_notice_jobs','prepare_notice_job','finish_notice_job','reminder_target'))
  or (n.nspname='public' and p.proname in ('get_my_trainer_notice_groups','ack_my_trainer_notice_group','resolve_my_trainer_notice_group','save_my_trainer_notice_preferences','get_my_notice_timezones','claim_student_notice_jobs','prepare_student_notice_job','finish_student_notice_job','resolve_my_trainer_reminder')) loop
  execute format('revoke all on function %s from public,anon,authenticated,service_role',f.signature);
  if f.proname in ('group_snapshot','ack_notice_group','resolve_notice_group','save_preferences','get_my_trainer_notice_groups','ack_my_trainer_notice_group','resolve_my_trainer_notice_group','save_my_trainer_notice_preferences','get_my_notice_timezones','reminder_target','resolve_my_trainer_reminder') then
   execute format('grant execute on function %s to authenticated',f.signature);
  elsif f.proname in ('claim_notice_jobs','prepare_notice_job','finish_notice_job','claim_student_notice_jobs','prepare_student_notice_job','finish_student_notice_job') then
   execute format('grant execute on function %s to service_role',f.signature);
  end if;
 end loop;
end $$;
commit;
