begin;

-- La bandeja contiene referencias, nunca mensajes privados, respuestas o marcas.
create table trainer_private.student_notices (
 id uuid primary key default gen_random_uuid(),
 owner_id uuid not null references public.profiles(id) on delete cascade,
 relation_id uuid not null references public.trainer_client_relations(id) on delete cascade,
 kind text not null check(kind in ('message','form','assessment','techniqueFeedback','assignment')),
 source_id uuid not null,
 source_revision bigint not null default 0 check(source_revision>=0),
 created_at timestamptz not null default now(),
 read_at timestamptz,
 unique(owner_id,kind,source_id,source_revision)
);
create index student_notices_page on trainer_private.student_notices(owner_id,created_at desc,id desc);
create index student_notices_kind_page on trainer_private.student_notices(owner_id,kind,created_at desc,id desc);
create index student_notices_unread on trainer_private.student_notices(owner_id) where read_at is null;
create index student_notices_relation on trainer_private.student_notices(relation_id);
alter table trainer_private.student_notices enable row level security;
revoke all on trainer_private.student_notices from public,anon,authenticated;

create function trainer_private.require_student_notice_owner(p_expected_owner uuid) returns void
language plpgsql stable security definer set search_path='' as $$
begin
 if auth.uid() is null or p_expected_owner is distinct from auth.uid()
  or coalesce((auth.jwt()->>'is_anonymous')::boolean,false) then raise insufficient_privilege; end if;
end $$;

create function trainer_private.capture_student_notice() returns trigger
language plpgsql security definer set search_path='' as $$
declare pupil uuid; relation uuid; event_kind text; source uuid; revision bigint:=0;
begin
 if tg_table_name='messages' then
  select r.client_id,r.id into pupil,relation from public.trainer_client_relations r
   where r.id=new.relation_id and r.trainer_id=new.sender_id;
  event_kind:='message'; source:=new.id;
 elsif tg_table_name='form_assignments' then
  pupil:=new.client_id; relation:=new.relation_id; event_kind:='form'; source:=new.id;
 elsif tg_table_name='assessment_deliveries' then
  pupil:=new.client_id; relation:=new.relation_id; event_kind:='assessment'; source:=new.id;
 elsif tg_table_name='video_feedback' then
  select a.created_by,t.relation_id into pupil,relation from public.exercise_video_assets a
   join public.trainer_assignments t on t.scheduled_id=a.assignment_id
   where a.id=new.asset_id and a.scope='client_technique' and t.client_id=a.created_by;
  event_kind:='techniqueFeedback'; source:=new.id;
 elsif tg_table_name='trainer_assignments' then
  if tg_op='UPDATE' and old.planning_revision=new.planning_revision then return new; end if;
  pupil:=new.client_id; relation:=new.relation_id; event_kind:='assignment';
  source:=new.scheduled_id; revision:=new.planning_revision;
 end if;
 if pupil is not null then
  insert into trainer_private.student_notices(owner_id,relation_id,kind,source_id,source_revision)
   values(pupil,relation,event_kind,source,revision) on conflict do nothing;
 end if;
 return new;
end $$;
create trigger student_message_notice after insert on trainer_private.messages for each row execute function trainer_private.capture_student_notice();
create trigger student_form_notice after insert on trainer_private.form_assignments for each row execute function trainer_private.capture_student_notice();
create trigger student_assessment_notice after insert on trainer_private.assessment_deliveries for each row execute function trainer_private.capture_student_notice();
create trigger student_technique_notice after insert on trainer_private.video_feedback for each row execute function trainer_private.capture_student_notice();
create trigger student_assignment_notice after insert or update of planning_revision on public.trainer_assignments for each row execute function trainer_private.capture_student_notice();

-- No conocemos las lecturas previas: solo las tareas aún pendientes se anuncian.
insert into trainer_private.student_notices(owner_id,relation_id,kind,source_id,created_at,read_at)
 select r.client_id,m.relation_id,'message',m.id,m.created_at,statement_timestamp()
 from trainer_private.messages m join public.trainer_client_relations r on r.id=m.relation_id where m.sender_id=r.trainer_id;
insert into trainer_private.student_notices(owner_id,relation_id,kind,source_id,created_at,read_at)
 select f.client_id,f.relation_id,'form',f.id,f.created_at,
  case when f.submitted_at is null and r.ended_at is null and a.enabled and (a.valid_until is null or a.valid_until>statement_timestamp()) then null else statement_timestamp() end
 from trainer_private.form_assignments f join public.trainer_client_relations r on r.id=f.relation_id join public.trainer_access a on a.trainer_id=f.trainer_id;
insert into trainer_private.student_notices(owner_id,relation_id,kind,source_id,created_at,read_at)
 select d.client_id,d.relation_id,'assessment',d.id,d.created_at,
  case when d.status='in_progress' or (d.status='planned' and r.ended_at is null and a.enabled and (a.valid_until is null or a.valid_until>statement_timestamp())) then null else statement_timestamp() end
 from trainer_private.assessment_deliveries d join public.trainer_client_relations r on r.id=d.relation_id join public.trainer_access a on a.trainer_id=d.trainer_id;
insert into trainer_private.student_notices(owner_id,relation_id,kind,source_id,created_at,read_at)
 select a.created_by,t.relation_id,'techniqueFeedback',f.id,f.created_at,statement_timestamp()
 from trainer_private.video_feedback f join public.exercise_video_assets a on a.id=f.asset_id
 join public.trainer_assignments t on t.scheduled_id=a.assignment_id where a.scope='client_technique' and t.client_id=a.created_by;
insert into trainer_private.student_notices(owner_id,relation_id,kind,source_id,source_revision,created_at,read_at)
 select client_id,relation_id,'assignment',scheduled_id,planning_revision,created_at,statement_timestamp() from public.trainer_assignments;

create function trainer_private.student_notice_target(p_notice_id uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare n trainer_private.student_notices; result jsonb;
begin
 select * into n from trainer_private.student_notices where id=p_notice_id and owner_id=auth.uid();
 if not found then raise insufficient_privilege; end if;
 if n.kind='message' then
  select jsonb_build_object('kind','conversation','target_id',r.id) into result
   from trainer_private.messages m join public.trainer_client_relations r on r.id=m.relation_id
   where m.id=n.source_id and r.id=n.relation_id and r.client_id=auth.uid() and m.sender_id=r.trainer_id;
 elsif n.kind='form' then
  select jsonb_build_object('kind','form','target_id',f.id) into result from trainer_private.form_assignments f
   where f.id=n.source_id and f.relation_id=n.relation_id and f.client_id=auth.uid();
 elsif n.kind='assessment' then
  select jsonb_build_object('kind','assessment','target_id',d.id) into result from trainer_private.assessment_deliveries d
   where d.id=n.source_id and d.relation_id=n.relation_id and d.client_id=auth.uid();
 elsif n.kind='techniqueFeedback' then
  select jsonb_build_object('kind','technique','target_id',e.id) into result
   from trainer_private.video_feedback f join public.exercise_video_assets a on a.id=f.asset_id
   join public.trainer_assignments t on t.scheduled_id=a.assignment_id
   join public.scheduled_workouts s on s.id=t.scheduled_id join public.workout_executions e on e.id=s.execution_id
   where f.id=n.source_id and a.scope='client_technique' and a.created_by=auth.uid() and t.client_id=auth.uid()
    and t.relation_id=n.relation_id and s.source='coach' and s.user_id=auth.uid() and e.user_id=auth.uid()
    and a.execution_id=e.id and trainer_private.can_read_video(a.id);
 elsif n.kind='assignment' then
  select jsonb_build_object('kind','workout','target_id',s.id,'scheduled_date',s.scheduled_date) into result
   from public.trainer_assignments t join public.scheduled_workouts s on s.id=t.scheduled_id
   join public.trainer_client_relations r on r.id=t.relation_id
   where t.scheduled_id=n.source_id and t.relation_id=n.relation_id and t.client_id=auth.uid() and s.user_id=auth.uid() and s.source='coach'
    and ((s.status='planned' and r.ended_at is null) or s.execution_id is not null)
    and trainer_private.can_read_coach_template(s.template_id);
 end if;
 return result;
end $$;

create function trainer_private.student_notice_snapshot(p_expected_owner uuid,p_before_at timestamptz default null,p_before_id uuid default null,p_kind text default null) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare result jsonb; resources jsonb; conversation uuid;
begin
 perform trainer_private.require_student_notice_owner(p_expected_owner);
 if (p_before_at is null)<>(p_before_id is null) or (p_kind is not null and p_kind not in ('message','form','assessment','techniqueFeedback','assignment')) then raise invalid_parameter_value; end if;
 -- El vínculo vacío no crea una sección profesional; una conversación exige contenido real.
 select r.id into conversation from public.trainer_client_relations r join trainer_private.messages m on m.relation_id=r.id
  where r.client_id=auth.uid() order by (r.ended_at is null) desc,m.created_at desc,m.id desc limit 1;
 resources:=jsonb_build_object(
  'has_forms',exists(select 1 from trainer_private.form_assignments where client_id=auth.uid()),
  'has_assessments',exists(select 1 from trainer_private.assessment_deliveries where client_id=auth.uid()),
  'has_conversations',conversation is not null,'conversation_relation_id',conversation,
  'has_assigned_workouts',exists(select 1 from public.trainer_assignments t join public.scheduled_workouts s on s.id=t.scheduled_id
   join public.trainer_client_relations r on r.id=t.relation_id where t.client_id=auth.uid() and s.user_id=auth.uid() and s.source='coach'
    and ((s.status='planned' and r.ended_at is null) or s.execution_id is not null)),
  'has_technique',exists(select 1 from public.trainer_assignments t join public.scheduled_workouts s on s.id=t.scheduled_id
   join public.workout_executions e on e.id=s.execution_id where t.client_id=auth.uid() and s.user_id=auth.uid() and s.source='coach' and e.user_id=auth.uid()));
 with page as (
  select n.id,n.kind,n.source_revision,n.created_at,n.read_at from trainer_private.student_notices n where n.owner_id=auth.uid()
   and (p_kind is null or n.kind=p_kind) and (p_before_at is null or (n.created_at,n.id)<(p_before_at,p_before_id))
   order by n.created_at desc,n.id desc limit 51
 ), visible as (select * from page order by created_at desc,id desc limit 50)
 select jsonb_build_object('items',coalesce((select jsonb_agg(to_jsonb(v) order by created_at desc,id desc) from visible v),'[]'),
  'has_more',(select count(*)>50 from page),
  'unread_count',(select count(*) from trainer_private.student_notices where owner_id=auth.uid() and read_at is null),
  'resources',resources) into result;
 return result;
end $$;

create function trainer_private.ack_student_notice(p_expected_owner uuid,p_notice_id uuid) returns void
language plpgsql security definer set search_path='' as $$
begin
 perform trainer_private.require_student_notice_owner(p_expected_owner);
 update trainer_private.student_notices set read_at=coalesce(read_at,clock_timestamp()) where id=p_notice_id and owner_id=auth.uid();
 if not found then raise insufficient_privilege; end if;
end $$;
create function trainer_private.resolve_student_notice(p_expected_owner uuid,p_notice_id uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
begin
 perform trainer_private.require_student_notice_owner(p_expected_owner);
 return trainer_private.student_notice_target(p_notice_id);
end $$;

create function trainer_private.list_student_technique(p_expected_owner uuid,p_before_at timestamptz default null,p_before_id uuid default null) returns jsonb
language plpgsql stable security definer set search_path='' as $$
begin
 perform trainer_private.require_student_notice_owner(p_expected_owner);
 if (p_before_at is null)<>(p_before_id is null) then raise invalid_parameter_value; end if;
 return (with page as (
  select e.id as execution_id,e.started_at,s.template_name as session_name
  from public.scheduled_workouts s join public.trainer_assignments t on t.scheduled_id=s.id join public.workout_executions e on e.id=s.execution_id
  where s.user_id=auth.uid() and s.source='coach' and t.client_id=auth.uid() and e.user_id=auth.uid()
   and (p_before_at is null or (e.started_at,e.id)<(p_before_at,p_before_id))
  order by e.started_at desc,e.id desc limit 51
 ), visible as (select * from page order by started_at desc,execution_id desc limit 50)
 select jsonb_build_object('items',coalesce((select jsonb_agg(to_jsonb(v) order by started_at desc,execution_id desc) from visible v),'[]'),
 'has_more',(select count(*)>50 from page)));
end $$;

create function public.get_my_trainer_notices(p_expected_owner uuid,p_before_at timestamptz default null,p_before_id uuid default null,p_kind text default null) returns jsonb
language sql stable security invoker set search_path='' as $$ select trainer_private.student_notice_snapshot(p_expected_owner,p_before_at,p_before_id,p_kind) $$;
create function public.ack_my_trainer_notice(p_expected_owner uuid,p_notice_id uuid) returns void
language sql security invoker set search_path='' as $$ select trainer_private.ack_student_notice(p_expected_owner,p_notice_id) $$;
create function public.resolve_my_trainer_notice(p_expected_owner uuid,p_notice_id uuid) returns jsonb
language sql stable security invoker set search_path='' as $$ select trainer_private.resolve_student_notice(p_expected_owner,p_notice_id) $$;
create function public.list_my_trainer_technique(p_expected_owner uuid,p_before_at timestamptz default null,p_before_id uuid default null) returns jsonb
language sql stable security invoker set search_path='' as $$ select trainer_private.list_student_technique(p_expected_owner,p_before_at,p_before_id) $$;

do $$ declare f record; begin
 for f in select p.oid::regprocedure as signature,p.proname from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname in ('public','trainer_private') and p.proname in ('require_student_notice_owner','capture_student_notice','student_notice_target',
   'student_notice_snapshot','ack_student_notice','resolve_student_notice','list_student_technique',
   'get_my_trainer_notices','ack_my_trainer_notice','resolve_my_trainer_notice','list_my_trainer_technique') loop
  execute format('revoke all on function %s from public,anon,authenticated',f.signature);
  if f.proname not in ('require_student_notice_owner','capture_student_notice','student_notice_target') then
   execute format('grant execute on function %s to authenticated',f.signature);
  end if;
 end loop;
end $$;
commit;
