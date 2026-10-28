begin;

-- La cita no es una pauta: no crea scheduled_workouts, ejecuciones ni envíos
-- a relojes. La relación fija sus participantes y no puede reasignarse.
create table trainer_private.appointments (
 id uuid primary key, relation_id uuid not null references public.trainer_client_relations on delete cascade,
 title text not null check(char_length(title) between 1 and 120),
 starts_at timestamptz not null, duration_minutes integer not null check(duration_minutes between 15 and 720),
 timezone text not null, location text not null default '' check(char_length(location)<=500),
 local_start timestamp generated always as (starts_at at time zone timezone) stored,
 status text not null default 'scheduled' check(status in ('scheduled','cancelled')),
 revision bigint not null default 1 check(revision between 1 and 1000000000),
 suggested_reminder integer not null default 0 check(suggested_reminder in (0,30,1440)),
 student_reminder integer not null default 0 check(student_reminder in (0,30,1440)),
 reminder_revision bigint not null default 0 check(reminder_revision>=0),
 created_at timestamptz not null default clock_timestamp(),updated_at timestamptz not null default clock_timestamp()
);
create index appointments_relation_date on trainer_private.appointments(relation_id,starts_at,id);
create index appointments_reminder_due on trainer_private.appointments(starts_at) where status='scheduled' and student_reminder>0;
alter table trainer_private.appointments enable row level security;
revoke all on trainer_private.appointments from public,anon,authenticated,service_role;

create function trainer_private.appointment_active(p_relation uuid) returns boolean
language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.trainer_client_relations r join public.trainer_access a on a.trainer_id=r.trainer_id
 where r.id=p_relation and r.ended_at is null and a.enabled and (a.valid_until is null or a.valid_until>statement_timestamp()));
$$;
create function trainer_private.appointment_json(p_id uuid) returns jsonb
language sql stable security definer set search_path='' as $$
 select to_jsonb(c)||jsonb_build_object('trainer_id',r.trainer_id,'client_id',r.client_id,
 'trainer_name',coalesce(nullif(btrim(t.full_name),''),'Preparador'),'client_name',coalesce(nullif(btrim(p.full_name),''),'Alumno'),
 'local_end',(c.starts_at+make_interval(mins=>c.duration_minutes)) at time zone c.timezone,
 'calendar_start',c.starts_at at time zone (push_private.preference_json(auth.uid())->>'timezone'),
 'calendar_end',(c.starts_at+make_interval(mins=>c.duration_minutes)) at time zone (push_private.preference_json(auth.uid())->>'timezone'),
 'calendar_timezone',push_private.preference_json(auth.uid())->>'timezone',
 'editable',r.trainer_id=auth.uid() and trainer_private.has_trainer_mfa() and trainer_private.appointment_active(r.id) and c.status='scheduled' and c.starts_at>statement_timestamp(),
 'can_remind',r.client_id=auth.uid() and trainer_private.appointment_active(r.id) and c.status='scheduled' and c.starts_at>statement_timestamp())
 from trainer_private.appointments c join public.trainer_client_relations r on r.id=c.relation_id
 join public.profiles t on t.id=r.trainer_id join public.profiles p on p.id=r.client_id where c.id=p_id;
$$;
create function trainer_private.get_appointment(p_owner uuid,p_id uuid,p_trainer boolean) returns jsonb
language plpgsql stable security definer set search_path='' as $$begin
 perform trainer_private.require_student_notice_owner(p_owner);
 if p_trainer and not trainer_private.has_trainer_mfa() then raise insufficient_privilege;end if;
 if not exists(select 1 from trainer_private.appointments c join public.trainer_client_relations r on r.id=c.relation_id
 where c.id=p_id and case when p_trainer then r.trainer_id else r.client_id end=auth.uid()) then raise insufficient_privilege;end if;
 return trainer_private.appointment_json(p_id);
end $$;
create function trainer_private.list_appointments(p_owner uuid,p_trainer boolean,p_from date,p_to date,p_history boolean,p_after_at timestamptz,p_after_id uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare result jsonb;zone text:=push_private.preference_json(auth.uid())->>'timezone';
begin
 perform trainer_private.require_student_notice_owner(p_owner);
 if p_trainer and not trainer_private.has_trainer_mfa() then raise insufficient_privilege;end if;
 if p_trainer is null or p_history is null or (p_after_at is null)<>(p_after_id is null) or
  (p_trainer and (p_from is null or p_to is null or p_to<p_from or p_to-p_from>93)) then raise invalid_parameter_value;end if;
 with page as (
 select c.id,c.starts_at from trainer_private.appointments c join public.trainer_client_relations r on r.id=c.relation_id
 where case when p_trainer then r.trainer_id else r.client_id end=auth.uid()
 and (not p_trainer or (c.starts_at<((p_to+1)::timestamp at time zone zone) and c.starts_at>=((p_from::timestamp at time zone zone)-interval '12 hours') and c.starts_at+make_interval(mins=>c.duration_minutes)>(p_from::timestamp at time zone zone)))
 and (p_trainer or case when p_history then c.status='cancelled' or c.starts_at+make_interval(mins=>c.duration_minutes)<statement_timestamp() else c.status='scheduled' and c.starts_at+make_interval(mins=>c.duration_minutes)>=statement_timestamp() end)
 and (p_after_at is null or case when not p_trainer and p_history then (c.starts_at,c.id)<(p_after_at,p_after_id) else (c.starts_at,c.id)>(p_after_at,p_after_id) end)
 order by case when not p_trainer and p_history then null else c.starts_at end,case when not p_trainer and p_history then c.starts_at end desc,
  case when not p_trainer and p_history then null else c.id end,case when not p_trainer and p_history then c.id end desc limit 101
 ), visible as(select * from page order by case when not p_trainer and p_history then null else starts_at end,case when not p_trainer and p_history then starts_at end desc,
 case when not p_trainer and p_history then null else id end,case when not p_trainer and p_history then id end desc limit 100)
 select jsonb_build_object('items',coalesce((select jsonb_agg(trainer_private.appointment_json(id) order by case when not p_trainer and p_history then null else starts_at end,
 case when not p_trainer and p_history then starts_at end desc,case when not p_trainer and p_history then null else id end,case when not p_trainer and p_history then id end desc) from visible),'[]'),
 'has_more',(select count(*)>100 from page)) into result;
 return result;
end $$;

create function trainer_private.save_appointment(p_owner uuid,p_id uuid,p_revision bigint,p_relation uuid,p_title text,p_day date,p_minute integer,p_duration integer,p_timezone text,p_location text,p_suggestion integer,p_overlap boolean,p_exact_start timestamptz default null) returns jsonb
language plpgsql security definer set search_path='' as $$
declare previous trainer_private.appointments;moment timestamptz;local_time timestamp;is_new boolean;row_id uuid;
begin
 perform trainer_private.require_student_notice_owner(p_owner);
 perform trainer_private.require_authoring_access();
 if p_id is null or p_revision is null or p_revision<0 or p_relation is null or p_title is null or char_length(btrim(p_title)) not between 1 and 120
  or p_day is null or p_minute is null or p_minute not between 0 and 1439 or p_duration is null or p_duration not between 15 and 720
  or p_timezone is null or not exists(select 1 from pg_timezone_names where name=p_timezone and (name like '%/%' or name='UTC'))
  or p_location is null or char_length(btrim(p_location))>500 or p_suggestion is null or p_suggestion not in (0,30,1440) or p_overlap is null then raise invalid_parameter_value;end if;
 -- Se serializan las citas del autor, también si dos pestañas crean a la vez.
 perform pg_advisory_xact_lock(hashtextextended('trainer-appointments:'||auth.uid()::text,0));
 perform 1 from public.trainer_client_relations where id=p_relation and trainer_id=auth.uid() and ended_at is null for update;
 if not found then raise insufficient_privilege;end if;
 local_time:=p_day::timestamp+make_interval(mins=>p_minute);moment:=coalesce(p_exact_start,local_time at time zone p_timezone);
 if (moment at time zone p_timezone)<>local_time then raise exception 'La hora no existe en esa zona por el cambio de horario.' using errcode='22023';end if;
 if moment<clock_timestamp()-interval '5 minutes' or moment>clock_timestamp()+interval '3 years' then raise exception 'Elige una fecha futura, dentro de los próximos tres años.' using errcode='22023';end if;
 select * into previous from trainer_private.appointments where id=p_id for update;is_new:=not found;
 if not is_new and previous.relation_id<>p_relation then raise insufficient_privilege;end if;
 -- El mismo intento tras una respuesta perdida no crea otro evento ni otro aviso.
 if not is_new and previous.status='scheduled' and previous.title=btrim(p_title) and previous.starts_at=moment
  and previous.duration_minutes=p_duration and previous.timezone=p_timezone and previous.location=btrim(p_location) and previous.suggested_reminder=p_suggestion
  and previous.revision in (p_revision,p_revision+1) then return jsonb_build_object('appointment',trainer_private.appointment_json(p_id));end if;
 if (is_new and p_revision<>0) or (not is_new and (previous.revision<>p_revision or previous.status<>'scheduled')) then raise serialization_failure;end if;
 if not p_overlap and exists(select 1 from trainer_private.appointments c join public.trainer_client_relations r on r.id=c.relation_id
  where r.trainer_id=auth.uid() and c.id<>p_id and c.status='scheduled'
  and tstzrange(c.starts_at,c.starts_at+make_interval(mins=>c.duration_minutes),'[)') && tstzrange(moment,moment+make_interval(mins=>p_duration),'[)'))
 then return jsonb_build_object('requires_confirmation',true);end if;
 if is_new then
  insert into trainer_private.appointments(id,relation_id,title,starts_at,duration_minutes,timezone,location,suggested_reminder)
   values(p_id,p_relation,btrim(p_title),moment,p_duration,p_timezone,btrim(p_location),p_suggestion) returning id into row_id;
 else
  update trainer_private.appointments set title=btrim(p_title),starts_at=moment,duration_minutes=p_duration,timezone=p_timezone,
   location=btrim(p_location),suggested_reminder=p_suggestion,revision=revision+1,updated_at=clock_timestamp() where id=p_id returning id into row_id;
 end if;
 return jsonb_build_object('appointment',trainer_private.appointment_json(row_id));
end $$;

create function trainer_private.move_appointment(p_owner uuid,p_id uuid,p_revision bigint,p_day date,p_minute integer,p_overlap boolean) returns jsonb
language plpgsql security definer set search_path='' as $$
declare c trainer_private.appointments;zone text;local_time timestamp;moment timestamptz;original_time timestamp;
begin
 perform trainer_private.get_appointment(p_owner,p_id,true);
 select * into c from trainer_private.appointments where id=p_id;
 zone:=push_private.preference_json(auth.uid())->>'timezone';
 if p_day is null or p_minute is null or p_minute not between 0 and 1439 then raise invalid_parameter_value;end if;
 local_time:=p_day::timestamp+make_interval(mins=>p_minute);moment:=local_time at time zone zone;
 if (moment at time zone zone)<>local_time then raise exception 'La hora no existe en la zona de la agenda.' using errcode='22023';end if;
 original_time:=moment at time zone c.timezone;
 return trainer_private.save_appointment(p_owner,p_id,p_revision,c.relation_id,c.title,original_time::date,
 extract(hour from original_time)::integer*60+extract(minute from original_time)::integer,c.duration_minutes,c.timezone,c.location,c.suggested_reminder,p_overlap,moment);
end $$;

create function trainer_private.cancel_appointment(p_owner uuid,p_id uuid,p_revision bigint) returns jsonb
language plpgsql security definer set search_path='' as $$
declare c trainer_private.appointments;
begin
 perform trainer_private.require_student_notice_owner(p_owner);
 if not trainer_private.has_trainer_mfa() then raise insufficient_privilege;end if;
 select a.* into c from trainer_private.appointments a join public.trainer_client_relations r on r.id=a.relation_id
  where a.id=p_id and r.trainer_id=auth.uid() for update of a;
 if not found then raise insufficient_privilege;end if;
 if c.status='cancelled' and c.revision in (p_revision,p_revision+1) then return trainer_private.appointment_json(p_id);end if;
 if c.revision is distinct from p_revision then raise serialization_failure;end if;
 update trainer_private.appointments set status='cancelled',student_reminder=0,revision=revision+1,updated_at=clock_timestamp() where id=p_id;
 return trainer_private.appointment_json(p_id);
end $$;
create function trainer_private.set_appointment_reminder(p_owner uuid,p_id uuid,p_revision bigint,p_reminder_revision bigint,p_minutes integer) returns jsonb
language plpgsql security definer set search_path='' as $$
declare c trainer_private.appointments;
begin
 perform trainer_private.require_student_notice_owner(p_owner);
 select a.* into c from trainer_private.appointments a join public.trainer_client_relations r on r.id=a.relation_id
  where a.id=p_id and r.client_id=auth.uid() for update of a;
 if not found then raise insufficient_privilege;end if;
 if p_minutes is null or p_minutes not in (0,30,1440) then raise invalid_parameter_value;end if;
 if c.revision is distinct from p_revision then raise serialization_failure;end if;
 if c.student_reminder=p_minutes and c.reminder_revision in (p_reminder_revision,p_reminder_revision+1) then return trainer_private.appointment_json(p_id);end if;
 if c.reminder_revision is distinct from p_reminder_revision then raise serialization_failure;end if;
 if p_minutes>0 and (c.status<>'scheduled' or c.starts_at<=clock_timestamp() or not trainer_private.appointment_active(c.relation_id)) then raise insufficient_privilege;end if;
 update trainer_private.appointments set student_reminder=p_minutes,reminder_revision=reminder_revision+1 where id=p_id;
 return trainer_private.appointment_json(p_id);
end $$;

-- Las instalaciones antiguas no reciben push de un recurso que no saben abrir.
-- La capacidad se liga al binding actual, no a una bandera heredable al cambiar
-- de cuenta o de instalación.
alter table push_private.installations add column appointment_binding uuid;
create function trainer_private.enable_appointment_notices(p_owner uuid,p_id uuid,p_secret text,p_binding uuid) returns void
language plpgsql security definer set search_path='' as $$
declare d jsonb;
begin
 d:=push_private.device_state(p_owner,p_id,p_secret);
 if not coalesce((d->>'owned')::boolean,false) or (d->>'binding_id')::uuid is distinct from p_binding then raise insufficient_privilege;end if;
 update push_private.installations set appointment_binding=p_binding where id=p_id and owner_id=auth.uid() and binding_id=p_binding;
 if not found then raise serialization_failure;end if;
end $$;

alter table trainer_private.student_notices drop constraint student_notices_kind_check;
alter table trainer_private.student_notices add constraint student_notices_kind_check check(kind in ('message','form','assessment','techniqueFeedback','assignment','appointment'));
alter table trainer_private.notice_groups drop constraint notice_groups_kind_check;
alter table trainer_private.notice_groups add constraint notice_groups_kind_check check(kind in ('message','form','assessment','techniqueFeedback','assignment','appointment'));
create function trainer_private.capture_appointment_notice() returns trigger
language plpgsql security definer set search_path='' as $$
declare pupil uuid;
begin
 if tg_op='UPDATE' and new.revision=old.revision then return new;end if;
 select client_id into pupil from public.trainer_client_relations where id=new.relation_id;
 insert into trainer_private.student_notices(owner_id,relation_id,kind,source_id,source_revision)
 values(pupil,new.relation_id,'appointment',new.id,new.revision*2) on conflict do nothing;
 return new;
end $$;
create trigger appointment_notice after insert or update on trainer_private.appointments for each row execute function trainer_private.capture_appointment_notice();
create function trainer_private.appointment_notice_pushable(p_notice uuid) returns boolean
language sql stable security definer set search_path='' as $$
 select exists(select 1 from trainer_private.student_notices n join trainer_private.appointments c on c.id=n.source_id
 where n.id=p_notice and n.kind='appointment' and n.relation_id=c.relation_id and trainer_private.appointment_active(c.relation_id)
 and (n.source_revision%2=0 or (n.source_revision=c.revision*2+1 and c.status='scheduled' and c.starts_at>statement_timestamp() and c.student_reminder>0)));
$$;
create function trainer_private.enqueue_appointment_reminders(p_now timestamptz) returns void
language plpgsql security definer set search_path='' as $$
declare c trainer_private.appointments;r public.trainer_client_relations;
begin
 for c in select * from trainer_private.appointments where status='scheduled' and student_reminder>0
  and starts_at>p_now and starts_at-make_interval(mins=>student_reminder) between p_now-interval '10 minutes' and p_now
 and not exists(select 1 from trainer_private.student_notices n where n.kind='appointment' and n.source_id=appointments.id and n.source_revision=appointments.revision*2+1)
  order by starts_at,id limit 1000 for update skip locked loop
  if not trainer_private.appointment_active(c.relation_id) then continue;end if;
  select * into r from public.trainer_client_relations where id=c.relation_id;
  insert into trainer_private.student_notices(owner_id,relation_id,kind,source_id,source_revision)
   values(r.client_id,c.relation_id,'appointment',c.id,c.revision*2+1) on conflict do nothing;
 end loop;
end $$;

create function public.list_trainer_appointments(p_expected_owner uuid,p_from date,p_to date,p_after_at timestamptz default null,p_after_id uuid default null) returns jsonb
language sql stable security invoker set search_path='' as $$select trainer_private.list_appointments(p_expected_owner,true,p_from,p_to,false,p_after_at,p_after_id)$$;
create function public.list_my_appointments(p_expected_owner uuid,p_history boolean default false,p_after_at timestamptz default null,p_after_id uuid default null) returns jsonb
language sql stable security invoker set search_path='' as $$select trainer_private.list_appointments(p_expected_owner,false,null,null,p_history,p_after_at,p_after_id)$$;
create function public.get_trainer_appointment(p_expected_owner uuid,p_id uuid) returns jsonb
language sql stable security invoker set search_path='' as $$select trainer_private.get_appointment(p_expected_owner,p_id,true)$$;
create function public.get_my_appointment(p_expected_owner uuid,p_id uuid) returns jsonb
language sql stable security invoker set search_path='' as $$select trainer_private.get_appointment(p_expected_owner,p_id,false)$$;
create function public.save_trainer_appointment(p_expected_owner uuid,p_id uuid,p_revision bigint,p_relation uuid,p_title text,p_day date,p_minute integer,p_duration integer,p_timezone text,p_location text,p_suggestion integer,p_overlap boolean default false) returns jsonb
language sql security invoker set search_path='' as $$select trainer_private.save_appointment(p_expected_owner,p_id,p_revision,p_relation,p_title,p_day,p_minute,p_duration,p_timezone,p_location,p_suggestion,p_overlap)$$;
create function public.cancel_trainer_appointment(p_expected_owner uuid,p_id uuid,p_revision bigint) returns jsonb
language sql security invoker set search_path='' as $$select trainer_private.cancel_appointment(p_expected_owner,p_id,p_revision)$$;
create function public.move_trainer_appointment(p_expected_owner uuid,p_id uuid,p_revision bigint,p_day date,p_minute integer,p_overlap boolean default false) returns jsonb
language sql security invoker set search_path='' as $$select trainer_private.move_appointment(p_expected_owner,p_id,p_revision,p_day,p_minute,p_overlap)$$;
create function public.set_my_appointment_reminder(p_expected_owner uuid,p_id uuid,p_revision bigint,p_reminder_revision bigint,p_minutes integer) returns jsonb
language sql security invoker set search_path='' as $$select trainer_private.set_appointment_reminder(p_expected_owner,p_id,p_revision,p_reminder_revision,p_minutes)$$;
create function public.enable_my_appointment_notices(p_expected_owner uuid,p_id uuid,p_secret text,p_binding uuid) returns void
language sql security invoker set search_path='' as $$select trainer_private.enable_appointment_notices(p_expected_owner,p_id,p_secret,p_binding)$$;

-- Los permisos se fijan al final, después de ampliar los adaptadores existentes.

-- Adaptadores verificados contra las definiciones vigentes; las ramas anteriores se conservan.
CREATE OR REPLACE FUNCTION trainer_private.attach_notice_group()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$begin
 -- Una sola secuencia por alumno: no depende de fechas del cliente y evita que
 -- un acuse de lectura antiguo absorba un mensaje confirmado posteriormente.
 perform pg_advisory_xact_lock(hashtextextended(new.owner_id::text,204610));
 -- Los emisores originales reintentan con ON CONFLICT DO NOTHING. Su BEFORE
 -- no debe adelantar el grupo cuando finalmente no se inserta ningún aviso.
 if exists(select 1 from trainer_private.student_notices where id=new.id or
  (owner_id=new.owner_id and kind=new.kind and source_id=new.source_id and source_revision=new.source_revision)) then return null;end if;
 insert into trainer_private.notice_groups(owner_id,relation_id,kind,group_key,last_at)
 values(new.owner_id,new.relation_id,new.kind,case when new.kind='appointment' then 'appointment:'||new.source_id::text when new.kind in ('assignment','message') then new.kind else new.id::text end,new.created_at)
 on conflict(owner_id,relation_id,group_key) do update set generation=notice_groups.generation+1,
 last_at=greatest(notice_groups.last_at,excluded.last_at)
 returning id,generation into new.group_id,new.group_generation;
 return new;
end $function$
;

CREATE OR REPLACE FUNCTION trainer_private.student_notice_snapshot(p_expected_owner uuid, p_before_at timestamp with time zone DEFAULT NULL::timestamp with time zone, p_before_id uuid DEFAULT NULL::uuid, p_kind text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
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
  'has_conversations',conversation is not null,
 'conversation_relation_id',case when (select count(*) from public.trainer_client_relations r
   where r.client_id=auth.uid() and r.ended_at is null and exists(select 1 from trainer_private.messages m where m.relation_id=r.id))>1 then null else conversation end,
 'conversations',coalesce((select jsonb_agg(jsonb_build_object('relation_id',r.id,
    'trainer_name',coalesce(nullif(btrim(p.full_name),''),'Preparador')) order by r.accepted_at,r.id)
   from public.trainer_client_relations r join public.profiles p on p.id=r.trainer_id
   where r.client_id=auth.uid() and r.ended_at is null and exists(select 1 from trainer_private.messages m where m.relation_id=r.id)),'[]'::jsonb),
  'has_assigned_workouts',exists(select 1 from public.trainer_assignments t join public.scheduled_workouts s on s.id=t.scheduled_id
   join public.trainer_client_relations r on r.id=t.relation_id where t.client_id=auth.uid() and s.user_id=auth.uid() and s.source='coach'
    and ((s.status='planned' and r.ended_at is null) or s.execution_id is not null)),
  'has_technique',exists(select 1 from public.trainer_assignments t join public.scheduled_workouts s on s.id=t.scheduled_id
   join public.workout_executions e on e.id=s.execution_id where t.client_id=auth.uid() and s.user_id=auth.uid() and s.source='coach' and e.user_id=auth.uid()));
 with page as (
  select n.id,n.kind,n.source_revision,n.created_at,n.read_at from trainer_private.student_notices n where n.owner_id=auth.uid() and n.kind<>'appointment'
   and (p_kind is null or n.kind=p_kind) and (p_before_at is null or (n.created_at,n.id)<(p_before_at,p_before_id))
   order by n.created_at desc,n.id desc limit 51
 ), visible as (select * from page order by created_at desc,id desc limit 50)
 select jsonb_build_object('items',coalesce((select jsonb_agg(to_jsonb(v) order by created_at desc,id desc) from visible v),'[]'),
  'has_more',(select count(*)>50 from page),
  'unread_count',(select count(*) from trainer_private.student_notices where owner_id=auth.uid() and kind<>'appointment' and read_at is null),
  'resources',resources) into result;
 return result;
end $function$
;

CREATE OR REPLACE FUNCTION trainer_private.group_snapshot(p_expected_owner uuid, p_before_at timestamp with time zone DEFAULT NULL::timestamp with time zone, p_before_id uuid DEFAULT NULL::uuid, p_kind text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
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
  where g.owner_id=auth.uid() and g.kind<>'appointment' and (p_kind is null or g.kind=p_kind)
   and (p_before_at is null or (g.last_at,g.id)<(p_before_at,p_before_id))
  order by g.last_at desc,g.id desc limit 51
 ), visible as(select * from page order by created_at desc,id desc limit 50)
 select jsonb_build_object('items',coalesce((select jsonb_agg(to_jsonb(v) order by created_at desc,id desc) from visible v),'[]'),
 'has_more',(select count(*)>50 from page),'resources',resources,
 'unread_count',(select count(distinct group_id) from trainer_private.student_notices where owner_id=auth.uid() and kind<>'appointment' and read_at is null)) into result;
 return result;
end $function$
;

CREATE OR REPLACE FUNCTION trainer_private.group_snapshot_v2(p_expected_owner uuid, p_before_at timestamp with time zone DEFAULT NULL::timestamp with time zone, p_before_id uuid DEFAULT NULL::uuid, p_kind text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare resources jsonb;result jsonb;
begin
 perform trainer_private.require_student_notice_owner(p_expected_owner);
 if (p_before_at is null)<>(p_before_id is null) or (p_kind is not null and p_kind not in ('message','assignment','form','assessment','techniqueFeedback','appointment')) then raise invalid_parameter_value;end if;
 resources:=trainer_private.student_notice_snapshot(p_expected_owner)->'resources';
 resources:=resources||jsonb_build_object('has_appointments',exists(select 1 from trainer_private.appointments c join public.trainer_client_relations r on r.id=c.relation_id where r.client_id=auth.uid()));
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
end $function$
;

CREATE OR REPLACE FUNCTION trainer_private.student_notice_target(p_notice_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare n trainer_private.student_notices; result jsonb;
begin
 select * into n from trainer_private.student_notices where id=p_notice_id and owner_id=auth.uid();
 if not found then raise insufficient_privilege; end if;
 if n.kind='appointment' then
  select jsonb_build_object('kind','appointment','target_id',c.id) into result from trainer_private.appointments c join public.trainer_client_relations r on r.id=c.relation_id where c.id=n.source_id and c.relation_id=n.relation_id and r.client_id=auth.uid();
 elsif n.kind='message' then
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
end $function$
;

CREATE OR REPLACE FUNCTION push_private.capture_grouped_notice()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare d push_private.installations;q push_private.notice_jobs;category text;moment timestamptz:=clock_timestamp();
begin
 if new.read_at is not null or not exists(select 1 from push_private.settings where singleton and enabled) then return new;end if;
 category:=case when new.kind in ('assignment','message') then new.kind else 'other' end;
 for d in select * from push_private.installations where owner_id=new.owner_id and active and (new.kind<>'appointment' or (appointment_binding=binding_id and personal_enabled)) and last_seen>moment-interval '90 days' order by id loop
  insert into push_private.notice_jobs(installation_id,owner_id,relation_id,kind,scope_key,next_at,first_pending_at,last_event_at)
  values(d.id,new.owner_id,new.relation_id,category,new.relation_id::text||':'||category,moment,moment,moment)
  on conflict(installation_id,owner_id,scope_key) do update set generation=notice_jobs.generation+1,attempts=0,
   first_pending_at=case when notice_jobs.generation=notice_jobs.delivered_generation then moment else notice_jobs.first_pending_at end,last_event_at=moment
  returning * into q;
  update push_private.notice_jobs set next_at=push_private.notice_due(q.owner_id,q.kind,q.first_pending_at,q.last_event_at,q.last_sent_at) where id=q.id;
  insert into push_private.job_notices(job_id,notice_id,generation) values(q.id,new.id,q.generation);
 end loop;
 return new;
end $function$
;

CREATE OR REPLACE FUNCTION push_private.prepare_notice_job(p_id uuid, p_claim uuid, p_generation bigint, p_binding uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$

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

 elsif not exists(select 1 from push_private.installations where id=q.installation_id and owner_id=q.owner_id and personal_enabled) then return null;

 elsif q.kind='reminder' then

  select * into p from push_private.preferences where owner_id=q.owner_id;

  if not found or p.reminder_mode='off' or p.revision<>q.reminder_revision or q.expires_at<=statement_timestamp()

   or not push_private.has_training(q.owner_id,q.reminder_date) then return null;end if;

 else

  if not exists(select 1 from push_private.job_notices j join trainer_private.student_notices n on n.id=j.notice_id

   join public.trainer_client_relations r on r.id=n.relation_id join public.trainer_access a on a.trainer_id=r.trainer_id

   where j.job_id=q.id and j.generation>q.delivered_generation and j.generation<=p_generation and n.owner_id=q.owner_id

    and (n.kind<>'assignment' or exists(select 1 from public.scheduled_workouts s where s.id=n.source_id and s.user_id=n.owner_id and s.status<>'cancelled'))

    and (n.kind<>'appointment' or (trainer_private.appointment_notice_pushable(n.id) and exists(select 1 from push_private.installations where id=q.installation_id and appointment_binding=binding_id)))
    and n.read_at is null and n.created_at>statement_timestamp()-interval '24 hours' and r.client_id=q.owner_id and r.ended_at is null

    and a.enabled and (a.valid_until is null or a.valid_until>statement_timestamp())) then return null;end if;

 end if;

 return jsonb_build_object('kind',q.kind,'previous_day',q.kind='reminder' and p.reminder_mode='previousDay');

end $function$
;

create function public.get_my_trainer_notice_groups_v2(p_expected_owner uuid,p_before_at timestamptz default null,p_before_id uuid default null,p_kind text default null) returns jsonb
language sql stable security invoker set search_path='' as $$select trainer_private.group_snapshot_v2(p_expected_owner,p_before_at,p_before_id,p_kind)$$;

do $permissions$
declare f record;
begin
 for f in select p.oid::regprocedure as signature,p.proname from pg_proc p join pg_namespace n on n.oid=p.pronamespace
 where (n.nspname='trainer_private' and p.proname in ('appointment_active','appointment_json','get_appointment','list_appointments',
 'save_appointment','move_appointment','cancel_appointment','set_appointment_reminder','enable_appointment_notices','capture_appointment_notice',
 'appointment_notice_pushable','enqueue_appointment_reminders','group_snapshot_v2')) or
 (n.nspname='public' and p.proname in ('list_trainer_appointments','list_my_appointments','get_trainer_appointment','get_my_appointment',
 'save_trainer_appointment','move_trainer_appointment','cancel_trainer_appointment','set_my_appointment_reminder','enable_my_appointment_notices','get_my_trainer_notice_groups_v2')) loop
  execute format('revoke all on function %s from public,anon,authenticated,service_role',f.signature);
  if f.proname in ('get_appointment','list_appointments','save_appointment','move_appointment','cancel_appointment','set_appointment_reminder',
   'enable_appointment_notices','group_snapshot_v2','list_trainer_appointments','list_my_appointments','get_trainer_appointment',
   'get_my_appointment','save_trainer_appointment','move_trainer_appointment','cancel_trainer_appointment','set_my_appointment_reminder','enable_my_appointment_notices','get_my_trainer_notice_groups_v2') then
   execute format('grant execute on function %s to authenticated',f.signature);
  end if;
 end loop;
end $permissions$;

select cron.schedule('trainer-appointment-reminders-dev','* * * * *',
 $$select trainer_private.enqueue_appointment_reminders(clock_timestamp());$$);
commit;
