begin;
-- Un consentimiento profesional independiente del seguimiento personal.
alter table push_private.settings add column coach_enabled boolean not null default false;
alter table push_private.notice_jobs drop constraint notice_jobs_kind_check;
alter table push_private.notice_jobs add constraint notice_jobs_kind_check
 check(kind in ('assignment','message','other','reminder','coachMessage','coachVideo'));
create table push_private.coach_preferences (
 owner_id uuid primary key references public.profiles on delete cascade,
 revision bigint not null default 0 check(revision>=0),enabled boolean not null default false,
 messages boolean not null default true,videos boolean not null default true,
 updated_at timestamptz not null default now()
);
-- El dispositivo es común; el consentimiento de cada bandeja es independiente.
create table push_private.student_delivery_preferences (
 owner_id uuid primary key references public.profiles on delete cascade,enabled boolean not null
);
alter table push_private.student_delivery_preferences enable row level security;
revoke all on push_private.student_delivery_preferences from public,anon,authenticated;
create function push_private.personal_delivery(p_owner uuid) returns boolean
language sql stable security definer set search_path='' as $$
 select coalesce((select enabled from push_private.student_delivery_preferences where owner_id=p_owner),
   exists(select 1 from push_private.installations where owner_id=p_owner and active));
$$;
create or replace function push_private.configuration(p_expected_owner uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$begin
 perform push_private.identity(p_expected_owner);
 return (select jsonb_build_object('enabled',enabled,'firebase_project_id',firebase_project_id,
  'personal_enabled',push_private.personal_delivery(auth.uid()),
  'professional_enabled',coach_enabled and exists(select 1 from push_private.coach_preferences where owner_id=auth.uid() and enabled),
  'preferences',push_private.preference_json(auth.uid())) from push_private.settings where singleton);
end $$;
create function push_private.set_personal_delivery(p_expected_owner uuid,p_enabled boolean) returns jsonb
language plpgsql security definer set search_path='' as $$begin
 perform push_private.identity(p_expected_owner);
 if p_enabled is null then raise invalid_parameter_value;end if;
 insert into push_private.student_delivery_preferences values(auth.uid(),p_enabled)
 on conflict(owner_id) do update set enabled=excluded.enabled;
 return push_private.configuration(p_expected_owner);
end $$;
create function push_private.prepare_professional_delivery(p_expected_owner uuid) returns jsonb
language plpgsql security definer set search_path='' as $$begin
 perform trainer_private.program_work_identity(p_expected_owner);
 if not exists(select 1 from public.trainer_access where trainer_id=auth.uid() and enabled and (valid_until is null or valid_until>statement_timestamp())) then raise insufficient_privilege;end if;
 -- Conserva el consentimiento previo; una primera alta profesional no activa
 -- por accidente los avisos de quien entrena al propio entrenador.
 insert into push_private.student_delivery_preferences values(auth.uid(),push_private.personal_delivery(auth.uid())) on conflict do nothing;
 return push_private.configuration(p_expected_owner);
end $$;
create function public.set_my_personal_push_delivery(p_expected_owner uuid,p_enabled boolean) returns jsonb
language sql security invoker set search_path='' as $$select push_private.set_personal_delivery(p_expected_owner,p_enabled)$$;
create function public.prepare_my_professional_push_delivery(p_expected_owner uuid) returns jsonb
language sql security invoker set search_path='' as $$select push_private.prepare_professional_delivery(p_expected_owner)$$;
revoke all on function push_private.personal_delivery(uuid),push_private.set_personal_delivery(uuid,boolean),push_private.prepare_professional_delivery(uuid),
 public.set_my_personal_push_delivery(uuid,boolean),public.prepare_my_professional_push_delivery(uuid) from public,anon,authenticated,service_role;
grant execute on function push_private.set_personal_delivery(uuid,boolean),push_private.prepare_professional_delivery(uuid),
 public.set_my_personal_push_delivery(uuid,boolean),public.prepare_my_professional_push_delivery(uuid) to authenticated;

create table push_private.coach_events (
 id uuid primary key default gen_random_uuid(),owner_id uuid not null references public.profiles on delete cascade,
 relation_id uuid not null references public.trainer_client_relations on delete cascade,
 kind text not null check(kind in ('coachMessage','coachVideo')),
 message_id uuid unique references trainer_private.messages on delete cascade,
 asset_id uuid unique references public.exercise_video_assets on delete cascade,
 created_at timestamptz not null default clock_timestamp(),
 check((kind='coachMessage' and message_id is not null and asset_id is null)
    or (kind='coachVideo' and asset_id is not null and message_id is null))
);
create table push_private.coach_video_reads (
 owner_id uuid not null references public.profiles on delete cascade,
 asset_id uuid not null references public.exercise_video_assets on delete cascade,
 primary key(owner_id,asset_id)
);
create table push_private.coach_job_events (
 job_id uuid not null references push_private.notice_jobs on delete cascade,
 event_id uuid not null references push_private.coach_events on delete cascade,
 generation bigint not null check(generation>0),primary key(job_id,generation,event_id),unique(job_id,event_id)
);
create index coach_events_owner_feed on push_private.coach_events(owner_id,kind,created_at desc,id desc);
create index coach_events_relation on push_private.coach_events(relation_id);
create index coach_job_event_source on push_private.coach_job_events(event_id);
create index coach_video_reads_asset on push_private.coach_video_reads(asset_id);
alter table push_private.coach_preferences enable row level security;
alter table push_private.coach_events enable row level security;
alter table push_private.coach_video_reads enable row level security;
alter table push_private.coach_job_events enable row level security;
revoke all on push_private.coach_preferences,push_private.coach_events,push_private.coach_video_reads,push_private.coach_job_events from public,anon,authenticated;

create function push_private.coach_preference_json(p_owner uuid) returns jsonb
language sql stable security definer set search_path='' as $$
 select coalesce((select to_jsonb(p)-'owner_id'-'updated_at' from push_private.coach_preferences p where owner_id=p_owner),
 '{"revision":0,"enabled":false,"messages":true,"videos":true}'::jsonb)
 ||jsonb_build_object('available',exists(select 1 from push_private.settings where singleton and enabled and coach_enabled));
$$;
create function push_private.coach_preferences_get(p_expected_owner uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$begin
 perform trainer_private.program_work_identity(p_expected_owner);
 return push_private.coach_preference_json(auth.uid());
end $$;
create function push_private.coach_preferences_save(p_expected_owner uuid,p_revision bigint,p_enabled boolean,p_messages boolean,p_videos boolean) returns jsonb
language plpgsql security definer set search_path='' as $$
declare p push_private.coach_preferences;
begin
 perform trainer_private.program_work_identity(p_expected_owner);
 if p_revision is null or p_enabled is null or p_messages is null or p_videos is null then raise invalid_parameter_value;end if;
 if p_enabled and not exists(select 1 from public.trainer_access where trainer_id=auth.uid() and enabled and (valid_until is null or valid_until>statement_timestamp())) then raise insufficient_privilege;end if;
 insert into push_private.coach_preferences(owner_id) values(auth.uid()) on conflict do nothing;
 select * into p from push_private.coach_preferences where owner_id=auth.uid() for update;
 if p.revision<>p_revision then raise exception 'Los ajustes han cambiado. Recarga antes de guardar.' using errcode='40001';end if;
 update push_private.coach_preferences set revision=revision+1,enabled=p_enabled,messages=p_messages,videos=p_videos,updated_at=clock_timestamp() where owner_id=auth.uid();
 return push_private.coach_preference_json(auth.uid());
end $$;

create or replace function push_private.notice_due(p_owner uuid,p_kind text,p_first timestamptz,p_last timestamptz,p_sent timestamptz) returns timestamptz
language sql stable security definer set search_path='' as $$
 select push_private.next_allowed(p_owner,greatest(
  least(p_last+case when p_kind='assignment' then interval '5 minutes' when p_kind in ('message','coachMessage','coachVideo') then interval '1 minute' else interval '30 seconds' end,
    p_first+case p_kind when 'assignment' then interval '15 minutes' else interval '2 minutes' end),
  coalesce(p_sent+case when p_kind='assignment' then interval '30 minutes' when p_kind in ('coachMessage','coachVideo') then interval '10 minutes' else interval '5 minutes' end,'-infinity'::timestamptz)));
$$;
create function push_private.capture_coach_event() returns trigger
language plpgsql security definer set search_path='' as $$
declare d push_private.installations;q push_private.notice_jobs;moment timestamptz:=clock_timestamp();
begin
 -- Un grupo por tipo y teléfono para TODOS sus alumnos, también entre etapas.
 for d in select * from push_private.installations where owner_id=new.owner_id and active and last_seen>moment-interval '90 days' order by id loop
  insert into push_private.notice_jobs(installation_id,owner_id,kind,scope_key,next_at,first_pending_at,last_event_at)
  values(d.id,new.owner_id,new.kind,'coach:'||new.kind,moment,moment,moment)
  on conflict(installation_id,owner_id,scope_key) do update set generation=notice_jobs.generation+1,attempts=0,
   first_pending_at=case when notice_jobs.generation=notice_jobs.delivered_generation then moment else notice_jobs.first_pending_at end,last_event_at=moment
  returning * into q;
  update push_private.notice_jobs set next_at=push_private.notice_due(q.owner_id,q.kind,q.first_pending_at,q.last_event_at,q.last_sent_at) where id=q.id;
  insert into push_private.coach_job_events(job_id,event_id,generation) values(q.id,new.id,q.generation);
 end loop;
 return new;
end $$;
create trigger coach_event_push after insert on push_private.coach_events for each row execute function push_private.capture_coach_event();
create function push_private.capture_coach_source() returns trigger
language plpgsql security definer set search_path='' as $$
declare r public.trainer_client_relations;category text;
begin
 if not exists(select 1 from push_private.settings where singleton and enabled and coach_enabled) then return new;end if;
 if tg_table_name='messages' then
  select * into r from public.trainer_client_relations where id=new.relation_id and ended_at is null and client_id=new.sender_id and trainer_id<>client_id;
  category:='coachMessage';
 else
  if new.scope<>'client_technique' or new.status<>'ready' or not new.shared then return new;end if;
  select rel.* into r from public.trainer_assignments t join public.trainer_client_relations rel on rel.id=t.relation_id
   where t.scheduled_id=new.assignment_id and t.trainer_id=new.trainer_id and rel.trainer_id=t.trainer_id
    and rel.client_id=t.client_id and rel.ended_at is null and rel.trainer_id<>rel.client_id and new.created_by=rel.client_id;
  category:='coachVideo';
 end if;
 if r.id is null or not exists(select 1 from public.trainer_access where trainer_id=r.trainer_id and enabled and (valid_until is null or valid_until>statement_timestamp()))
  or not exists(select 1 from push_private.coach_preferences where owner_id=r.trainer_id and enabled and case category when 'coachMessage' then messages else videos end) then return new;end if;
 if category='coachMessage' then
  insert into push_private.coach_events(owner_id,relation_id,kind,message_id) values(r.trainer_id,r.id,category,new.id) on conflict do nothing;
 else
  insert into push_private.coach_events(owner_id,relation_id,kind,asset_id) values(r.trainer_id,r.id,category,new.id) on conflict do nothing;
 end if;
 return new;
end $$;
create trigger coach_message_push after insert on trainer_private.messages for each row execute function push_private.capture_coach_source();
create trigger coach_video_push after insert or update of status,shared on public.exercise_video_assets for each row execute function push_private.capture_coach_source();

-- Se consulta otra vez justo antes de enviar; leer en web también cancela la push.
create function push_private.coach_event_pending(p_event uuid,p_owner uuid) returns boolean
language sql stable security definer set search_path='' as $$
 select exists(select 1 from push_private.coach_events e
 join public.trainer_client_relations r on r.id=e.relation_id and r.trainer_id=e.owner_id
 join public.trainer_access a on a.trainer_id=e.owner_id
 join push_private.coach_preferences pref on pref.owner_id=e.owner_id and pref.enabled
 where e.id=p_event and e.owner_id=p_owner and e.created_at>statement_timestamp()-interval '24 hours'
  and r.ended_at is null and r.client_id<>r.trainer_id and a.enabled and (a.valid_until is null or a.valid_until>statement_timestamp())
  and exists(select 1 from push_private.settings where singleton and enabled and coach_enabled)
  and ((e.kind='coachMessage' and pref.messages and exists(select 1 from trainer_private.messages m where m.id=e.message_id and m.relation_id=r.id and m.sender_id=r.client_id)
    and not exists(select 1 from trainer_private.message_reads seen where seen.trainer_id=e.owner_id and seen.message_id=e.message_id))
   or (e.kind='coachVideo' and pref.videos and exists(select 1 from public.exercise_video_assets v join public.trainer_assignments t on t.scheduled_id=v.assignment_id
     where v.id=e.asset_id and v.trainer_id=e.owner_id and v.scope='client_technique' and v.status='ready' and v.shared and v.created_by=r.client_id and t.relation_id=r.id and t.trainer_id=e.owner_id)
    and not exists(select 1 from push_private.coach_video_reads seen where seen.owner_id=e.owner_id and seen.asset_id=e.asset_id)
    and not exists(select 1 from trainer_private.video_feedback f where f.asset_id=e.asset_id))));
$$;
create function push_private.coach_video_read(p_expected_owner uuid,p_asset_id uuid) returns void
language plpgsql security definer set search_path='' as $$begin
 perform trainer_private.program_work_identity(p_expected_owner);
 if p_asset_id is null or not trainer_private.can_feedback_video(p_asset_id) then raise insufficient_privilege;end if;
 insert into push_private.coach_video_reads(owner_id,asset_id) values(auth.uid(),p_asset_id) on conflict do nothing;
end $$;
create function push_private.coach_notice_target(p_expected_owner uuid,p_kind text) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare e push_private.coach_events;target uuid;
begin
 perform trainer_private.program_work_identity(p_expected_owner);
 if p_kind is null or p_kind not in ('coachMessage','coachVideo') then raise invalid_parameter_value;end if;
 select * into e from push_private.coach_events where owner_id=auth.uid() and kind=p_kind and push_private.coach_event_pending(id,auth.uid()) order by created_at desc,id desc limit 1;
 if not found then return null;end if;
 if p_kind='coachMessage' then return jsonb_build_object('kind','conversation','target_id',e.relation_id);end if;
 select assignment_id into target from public.exercise_video_assets where id=e.asset_id;
 return jsonb_build_object('kind','technique','target_id',target);
end $$;
create or replace function push_private.prepare_notice_job(p_id uuid,p_claim uuid,p_generation bigint,p_binding uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare q push_private.notice_jobs;p push_private.preferences;
begin
 select j.* into q from push_private.notice_jobs j join push_private.installations d on d.id=j.installation_id
 where j.id=p_id and j.claim_id=p_claim and j.lease_generation=p_generation and j.lease_until>statement_timestamp()
  and d.binding_id=p_binding and d.owner_id=j.owner_id and d.active;
 if not found or not exists(select 1 from push_private.settings where singleton and enabled) then return null;end if;
 if push_private.next_allowed(q.owner_id,statement_timestamp())>statement_timestamp() then return jsonb_build_object('kind','defer');end if;
 if q.kind in ('coachMessage','coachVideo') then
  if not exists(select 1 from push_private.coach_job_events j where j.job_id=q.id and j.generation>q.delivered_generation and j.generation<=p_generation
    and push_private.coach_event_pending(j.event_id,q.owner_id)) then return null;end if;
 elsif not push_private.personal_delivery(q.owner_id) then return null;
 elsif q.kind='reminder' then
  select * into p from push_private.preferences where owner_id=q.owner_id;
  if not found or p.reminder_mode='off' or p.revision<>q.reminder_revision or q.expires_at<=statement_timestamp()
   or not push_private.has_training(q.owner_id,q.reminder_date) then return null;end if;
 else
  if not exists(select 1 from push_private.job_notices j join trainer_private.student_notices n on n.id=j.notice_id
   join public.trainer_client_relations r on r.id=n.relation_id join public.trainer_access a on a.trainer_id=r.trainer_id
   where j.job_id=q.id and j.generation>q.delivered_generation and j.generation<=p_generation and n.owner_id=q.owner_id
    and (n.kind<>'assignment' or exists(select 1 from public.scheduled_workouts s where s.id=n.source_id and s.user_id=n.owner_id and s.status<>'cancelled'))
    and n.read_at is null and n.created_at>statement_timestamp()-interval '24 hours' and r.client_id=q.owner_id and r.ended_at is null
    and a.enabled and (a.valid_until is null or a.valid_until>statement_timestamp())) then return null;end if;
 end if;
 return jsonb_build_object('kind',q.kind,'previous_day',q.kind='reminder' and p.reminder_mode='previousDay');
end $$;
create function public.get_my_coach_push_preferences(p_expected_owner uuid) returns jsonb
language sql stable security invoker set search_path='' as $$select push_private.coach_preferences_get(p_expected_owner)$$;
create function public.save_my_coach_push_preferences(p_expected_owner uuid,p_revision bigint,p_enabled boolean,p_messages boolean,p_videos boolean) returns jsonb
language sql security invoker set search_path='' as $$select push_private.coach_preferences_save(p_expected_owner,p_revision,p_enabled,p_messages,p_videos)$$;
create function public.read_my_coach_video(p_expected_owner uuid,p_asset_id uuid) returns void
language sql security invoker set search_path='' as $$select push_private.coach_video_read(p_expected_owner,p_asset_id)$$;
create function public.resolve_my_coach_notice(p_expected_owner uuid,p_kind text) returns jsonb
language sql stable security invoker set search_path='' as $$select push_private.coach_notice_target(p_expected_owner,p_kind)$$;
revoke all on function push_private.coach_preference_json(uuid),push_private.coach_preferences_get(uuid),push_private.coach_preferences_save(uuid,bigint,boolean,boolean,boolean),
 push_private.capture_coach_event(),push_private.capture_coach_source(),push_private.coach_event_pending(uuid,uuid),push_private.coach_video_read(uuid,uuid),push_private.coach_notice_target(uuid,text),
 public.get_my_coach_push_preferences(uuid),public.save_my_coach_push_preferences(uuid,bigint,boolean,boolean,boolean),public.read_my_coach_video(uuid,uuid),public.resolve_my_coach_notice(uuid,text)
 from public,anon,authenticated,service_role;
grant execute on function push_private.coach_preferences_get(uuid),push_private.coach_preferences_save(uuid,bigint,boolean,boolean,boolean),push_private.coach_video_read(uuid,uuid),push_private.coach_notice_target(uuid,text),
 public.get_my_coach_push_preferences(uuid),public.save_my_coach_push_preferences(uuid,bigint,boolean,boolean,boolean),public.read_my_coach_video(uuid,uuid),public.resolve_my_coach_notice(uuid,text) to authenticated;
commit;
