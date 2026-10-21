begin;
create table trainer_private.recurrences (
 id uuid primary key default gen_random_uuid(),
 trainer_id uuid not null references public.profiles(id) on delete cascade,
 template_id uuid not null references public.workout_templates(id) on delete restrict,
 week_start date not null check(extract(isodow from week_start)=1),
 weeks integer not null check(weeks between 1 and 12),
 weekdays integer[] not null check(cardinality(weekdays) between 1 and 7 and weekdays<@array[1,2,3,4,5,6,7]),
 note text check(char_length(note)<=500),
 created_at timestamptz not null default now()
);
create index trainer_recurrences_owner on trainer_private.recurrences(trainer_id,created_at desc,id desc);
create index trainer_recurrences_template on trainer_private.recurrences(template_id);
create table trainer_private.recurrence_assignments (
 scheduled_id uuid primary key references public.trainer_assignments(scheduled_id) on delete cascade,
 recurrence_id uuid not null references trainer_private.recurrences(id) on delete restrict
);
create index trainer_recurrence_assignments_series on trainer_private.recurrence_assignments(recurrence_id);
do $$ declare tab text; begin
 foreach tab in array array['recurrences','recurrence_assignments'] loop
  execute format('alter table trainer_private.%I enable row level security',tab);
  execute format('revoke all on trainer_private.%I from public,anon,authenticated',tab);
 end loop;
end $$;

create function trainer_private.recurrence_plan(p_recipients jsonb,p_template_id uuid,p_week_start date,p_weeks integer,p_weekdays integer[],p_note text) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare base jsonb; days integer[]; dates date[]; recipient jsonb; details jsonb:='[]'; collisions jsonb; name text; payload jsonb; total integer;
begin
 if not trainer_private.has_professional_read_access() then raise insufficient_privilege; end if;
 if p_week_start is null or extract(isodow from p_week_start)<>1 or p_weeks is null or p_weeks not between 1 and 12
  or p_weekdays is null or cardinality(p_weekdays) not between 1 and 7 or array_position(p_weekdays,null) is not null
  or not p_weekdays<@array[1,2,3,4,5,6,7] then raise invalid_parameter_value; end if;
 select array_agg(d order by d) into days from (select distinct unnest(p_weekdays) d) x;
 if cardinality(days)<>cardinality(p_weekdays) then raise invalid_parameter_value; end if;
 base:=trainer_private.prepare_batch(p_recipients,p_template_id,p_week_start,null,null,p_note,null,null);
 select array_agg(p_week_start+w*7+d-1 order by w,d) into dates from generate_series(0,p_weeks-1) w cross join unnest(days) d;
 total:=jsonb_array_length(base->'recipients')*cardinality(dates);
 if total>256 then raise exception 'La serie suma más de 256 citas. Reduce alumnos, semanas o días.' using errcode='22023'; end if;
 for recipient in select value from jsonb_array_elements(base->'recipients') loop
  select c.display_name into name from public.trainer_clients c where c.trainer_id=auth.uid() and c.client_id=(recipient->>'client_id')::uuid;
  select coalesce(jsonb_agg(d order by d),'[]') into collisions from unnest(dates) d where exists(
   select 1 from public.scheduled_workouts s where s.user_id=(recipient->>'client_id')::uuid and s.scheduled_date=d and s.status in ('planned','in_progress'));
  details:=details||jsonb_build_array(recipient||jsonb_build_object('client_name',name,'dates',dates,'coincidences',collisions));
 end loop;
 payload:=jsonb_build_object('recipients',base->'recipients','template_id',p_template_id,'week_start',p_week_start,'weeks',p_weeks,'weekdays',days,'note',nullif(btrim(p_note),''),'preview',details);
 return payload||jsonb_build_object('assignment_count',total,'fingerprint',encode(extensions.digest(payload::text,'sha256'),'hex'));
end $$;

create function trainer_private.create_recurrence(p_operation_id uuid,p_recipients jsonb,p_template_id uuid,p_week_start date,p_weeks integer,p_weekdays integer[],p_note text,p_fingerprint text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare member uuid; prior trainer_private.bulk_writes; payload jsonb; plan jsonb; series uuid:=gen_random_uuid();
 recipient jsonb; date_json jsonb; assignment uuid; ids jsonb; receipts jsonb:='[]'; result jsonb;
begin
 if not trainer_private.has_trainer_mfa() then raise insufficient_privilege; end if;
 if p_operation_id is null or p_fingerprint is null or p_fingerprint !~ '^[0-9a-f]{64}$' or jsonb_typeof(p_recipients) is distinct from 'array'
  or jsonb_array_length(p_recipients) not between 1 and 100 then raise invalid_parameter_value; end if;
 for member in select distinct (r->>'client_id')::uuid from jsonb_array_elements(p_recipients) r order by 1 loop
  if member is null then raise invalid_parameter_value; end if;
  perform pg_advisory_xact_lock(hashtextextended('trainer-client:'||member::text,0));
 end loop;
 perform trainer_private.require_authoring_access();
 payload:=jsonb_build_object('kind','recurrence','recipients',p_recipients,'template_id',p_template_id,'week_start',p_week_start,'weeks',p_weeks,'weekdays',p_weekdays,'note',nullif(btrim(p_note),''),'fingerprint',p_fingerprint);
 select * into prior from trainer_private.bulk_writes where trainer_id=auth.uid() and operation_id=p_operation_id;
 if found then
  if prior.payload is distinct from payload then raise invalid_parameter_value; end if;
  return prior.result;
 end if;
 plan:=trainer_private.recurrence_plan(p_recipients,p_template_id,p_week_start,p_weeks,p_weekdays,p_note);
 if plan->>'fingerprint'<>p_fingerprint then raise exception 'La planificación ha cambiado. Revisa fechas y coincidencias de nuevo.' using errcode='40001'; end if;
 insert into trainer_private.recurrences(id,trainer_id,template_id,week_start,weeks,weekdays,note)
  values(series,auth.uid(),p_template_id,p_week_start,p_weeks,array(select (d#>>'{}')::integer from jsonb_array_elements(plan->'weekdays') d),nullif(btrim(p_note),''));
 for recipient in select value from jsonb_array_elements(plan->'preview') order by (value->>'client_id')::uuid loop
  ids:='[]';
  for date_json in select value from jsonb_array_elements(recipient->'dates') loop
   assignment:=trainer_private.assign_trainer_workout_version(gen_random_uuid(),(recipient->>'relation_id')::uuid,p_template_id,(date_json#>>'{}')::date,p_note,true);
   insert into trainer_private.recurrence_assignments values(assignment,series);
   ids:=ids||jsonb_build_array(assignment);
  end loop;
  receipts:=receipts||jsonb_build_array(jsonb_build_object('client_id',recipient->>'client_id','relation_id',recipient->>'relation_id','assignment_ids',ids));
 end loop;
 result:=jsonb_build_object('series_id',series,'assignment_count',plan->'assignment_count','recipients',receipts);
 insert into trainer_private.bulk_writes(trainer_id,operation_id,payload,result) values(auth.uid(),p_operation_id,payload,result);
 return result;
end $$;

create function trainer_private.list_recurrences(p_before_at timestamptz default null,p_before_id uuid default null) returns jsonb
language plpgsql stable security definer set search_path='' as $$
begin
 if not trainer_private.has_trainer_mfa() then raise insufficient_privilege; end if;
 if (p_before_at is null)<>(p_before_id is null) then raise invalid_parameter_value; end if;
 return (select coalesce(jsonb_agg(to_jsonb(x) order by created_at desc,id desc),'[]') from (
  select r.id,r.template_id,t.name as template_name,t.version as template_version,r.week_start,r.weeks,r.weekdays,r.created_at,r.note,
   (select count(*) from trainer_private.recurrence_assignments a where a.recurrence_id=r.id) as assignment_count,
   (select count(*) from trainer_private.recurrence_assignments a join public.scheduled_workouts s on s.id=a.scheduled_id
    where a.recurrence_id=r.id and s.status='planned' and s.execution_id is null) as pending_count
  from trainer_private.recurrences r join public.workout_templates t on t.id=r.template_id
  where r.trainer_id=auth.uid() and (p_before_at is null or (r.created_at,r.id)<(p_before_at,p_before_id))
  order by r.created_at desc,r.id desc limit 50
 ) x);
end $$;

create function trainer_private.recurrence_withdrawal_plan(p_series_id uuid,p_from_date date) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare source jsonb; eligible jsonb; fingerprint text;
begin
 if not trainer_private.has_trainer_mfa() or not exists(select 1 from trainer_private.recurrences where id=p_series_id and trainer_id=auth.uid()) then raise insufficient_privilege; end if;
 if p_from_date is null then raise invalid_parameter_value; end if;
 select coalesce(jsonb_agg(jsonb_build_object('id',s.id,'client_id',a.client_id,'client_name',c.display_name,'date',s.scheduled_date,'status',s.status,'execution_id',s.execution_id,'planning_revision',a.planning_revision) order by s.id),'[]')
  into source from trainer_private.recurrence_assignments links join public.scheduled_workouts s on s.id=links.scheduled_id
   join public.trainer_assignments a on a.scheduled_id=s.id join public.trainer_clients c on c.trainer_id=a.trainer_id and c.client_id=a.client_id
  where links.recurrence_id=p_series_id and a.trainer_id=auth.uid() and s.scheduled_date>=p_from_date;
 select coalesce(jsonb_agg(e order by e->>'id'),'[]') into eligible from jsonb_array_elements(source) e where e->>'status'='planned' and e->>'execution_id' is null;
 fingerprint:=encode(extensions.digest(jsonb_build_object('series_id',p_series_id,'from_date',p_from_date,'source',source)::text,'sha256'),'hex');
 return jsonb_build_object('fingerprint',fingerprint,'items',eligible,'excluded_count',jsonb_array_length(source)-jsonb_array_length(eligible));
end $$;

create function trainer_private.withdraw_recurrence(p_operation_id uuid,p_series_id uuid,p_from_date date,p_fingerprint text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare member uuid; payload jsonb; prior trainer_private.bulk_writes; plan jsonb; ids uuid[]; count_cancelled integer; result jsonb;
begin
 if not trainer_private.has_trainer_mfa() or not exists(select 1 from trainer_private.recurrences where id=p_series_id and trainer_id=auth.uid()) then raise insufficient_privilege; end if;
 if p_operation_id is null or p_from_date is null or p_fingerprint is null or p_fingerprint !~ '^[0-9a-f]{64}$' then raise invalid_parameter_value; end if;
 for member in select distinct a.client_id from trainer_private.recurrence_assignments links join public.trainer_assignments a on a.scheduled_id=links.scheduled_id
  where links.recurrence_id=p_series_id order by 1 loop
  perform pg_advisory_xact_lock(hashtextextended('trainer-client:'||member::text,0));
 end loop;
 perform trainer_private.require_authoring_access();
 payload:=jsonb_build_object('kind','withdraw_recurrence','series_id',p_series_id,'from_date',p_from_date,'fingerprint',p_fingerprint);
 select * into prior from trainer_private.bulk_writes where trainer_id=auth.uid() and operation_id=p_operation_id;
 if found then
  if prior.payload is distinct from payload then raise invalid_parameter_value; end if;
  return prior.result;
 end if;
 plan:=trainer_private.recurrence_withdrawal_plan(p_series_id,p_from_date);
 if plan->>'fingerprint'<>p_fingerprint then raise exception 'Las pautas han cambiado. Revisa de nuevo antes de retirar.' using errcode='40001'; end if;
 select array_agg((e->>'id')::uuid) into ids from jsonb_array_elements(plan->'items') e;
 if coalesce(cardinality(ids),0)=0 then raise exception 'No hay pautas pendientes para retirar desde esa fecha.' using errcode='22023'; end if;
 update public.scheduled_workouts set status='cancelled' where id=any(ids) and status='planned' and execution_id is null;
 get diagnostics count_cancelled=row_count;
 if count_cancelled<>cardinality(ids) then raise serialization_failure; end if;
 update public.trainer_access set membership_version=membership_version+1 where trainer_id=auth.uid();
 result:=jsonb_build_object('cancelled_count',count_cancelled);
 insert into trainer_private.bulk_writes(trainer_id,operation_id,payload,result) values(auth.uid(),p_operation_id,payload,result);
 return result;
end $$;

create function public.preview_trainer_recurrence(p_recipients jsonb,p_template_id uuid,p_week_start date,p_weeks integer,p_weekdays integer[],p_note text default null) returns jsonb
language sql stable security invoker set search_path='' as $$select trainer_private.recurrence_plan(p_recipients,p_template_id,p_week_start,p_weeks,p_weekdays,p_note)$$;
create function public.create_trainer_recurrence(p_operation_id uuid,p_recipients jsonb,p_template_id uuid,p_week_start date,p_weeks integer,p_weekdays integer[],p_note text,p_fingerprint text) returns jsonb
language sql security invoker set search_path='' as $$select trainer_private.create_recurrence(p_operation_id,p_recipients,p_template_id,p_week_start,p_weeks,p_weekdays,p_note,p_fingerprint)$$;
create function public.list_trainer_recurrences(p_before_at timestamptz default null,p_before_id uuid default null) returns jsonb
language sql stable security invoker set search_path='' as $$select trainer_private.list_recurrences(p_before_at,p_before_id)$$;
create function public.preview_trainer_recurrence_withdrawal(p_series_id uuid,p_from_date date) returns jsonb
language sql stable security invoker set search_path='' as $$select trainer_private.recurrence_withdrawal_plan(p_series_id,p_from_date)$$;
create function public.withdraw_trainer_recurrence(p_operation_id uuid,p_series_id uuid,p_from_date date,p_fingerprint text) returns jsonb
language sql security invoker set search_path='' as $$select trainer_private.withdraw_recurrence(p_operation_id,p_series_id,p_from_date,p_fingerprint)$$;
do $$ declare f record; begin
 for f in select p.oid::regprocedure as signature from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname in ('public','trainer_private')
  and p.proname in ('recurrence_plan','create_recurrence','list_recurrences','recurrence_withdrawal_plan','withdraw_recurrence',
   'preview_trainer_recurrence','create_trainer_recurrence','list_trainer_recurrences','preview_trainer_recurrence_withdrawal','withdraw_trainer_recurrence') loop
  execute format('revoke all on function %s from public,anon,authenticated',f.signature);
  execute format('grant execute on function %s to authenticated',f.signature);
 end loop;
end $$;
commit;
