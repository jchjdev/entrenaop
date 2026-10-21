begin;
create table trainer_private.client_note_versions (
 trainer_id uuid not null references public.profiles(id) on delete cascade,
 client_id uuid not null references public.profiles(id) on delete cascade,
 revision integer not null check(revision>0),
 notes text not null check(length(notes)<=2000),
 goal text not null check(length(goal)<=500),
 operation_id uuid not null,
 expected_revision integer not null check(expected_revision>=0),
 created_at timestamptz not null default now(),
 primary key(trainer_id,client_id,revision),
 unique(trainer_id,operation_id),
 foreign key(trainer_id,client_id) references public.trainer_clients(trainer_id,client_id) on delete cascade
);
create index trainer_client_notes_client on trainer_private.client_note_versions(client_id);
alter table trainer_private.client_note_versions enable row level security;
revoke all on trainer_private.client_note_versions from public,anon,authenticated;

create function trainer_private.require_client_portfolio(p_client_id uuid) returns void
language plpgsql stable security definer set search_path='' as $$
begin
 if not trainer_private.has_trainer_mfa() or not exists(select 1 from public.trainer_clients
  where trainer_id=auth.uid() and client_id=p_client_id) then raise insufficient_privilege; end if;
end $$;
create function trainer_private.get_trainer_client_workspace(p_client_id uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare client jsonb; notes jsonb; relations jsonb; episodes bigint;
begin
 perform trainer_private.require_client_portfolio(p_client_id);
 select to_jsonb(x) into client from (
  select c.client_id as person_id,c.display_name as person_name,c.created_at,c.updated_at,c.archived_at,
   latest.accepted_at,latest.ended_at,active.id as active_relation_id,
   (select count(*) from public.trainer_client_relations r where r.trainer_id=c.trainer_id and r.client_id=c.client_id) as episode_count
  from public.trainer_clients c
  join lateral(select r.accepted_at,r.ended_at from public.trainer_client_relations r
   where r.trainer_id=c.trainer_id and r.client_id=c.client_id order by r.accepted_at desc,r.id desc limit 1) latest on true
  left join public.trainer_client_relations active on active.trainer_id=c.trainer_id and active.client_id=c.client_id and active.ended_at is null
  where c.trainer_id=auth.uid() and c.client_id=p_client_id) x;
 select jsonb_build_object('revision',v.revision,'notes',v.notes,'goal',v.goal,'created_at',v.created_at) into notes
  from trainer_private.client_note_versions v where trainer_id=auth.uid() and client_id=p_client_id order by revision desc limit 1;
 select count(*) into episodes from public.trainer_client_relations where trainer_id=auth.uid() and client_id=p_client_id;
 select coalesce(jsonb_agg(to_jsonb(x) order by accepted_at desc,id desc),'[]') into relations from (
  select id,accepted_at,ended_at from public.trainer_client_relations where trainer_id=auth.uid() and client_id=p_client_id
  order by accepted_at desc,id desc limit 50) x;
 return jsonb_build_object('client',client,'relations',relations,'relations_complete',episodes<=50,
  'notes',coalesce(notes,'{"revision":0,"notes":"","goal":""}'::jsonb),
  'can_edit_notes',exists(select 1 from public.trainer_access where trainer_id=auth.uid() and enabled
   and (valid_until is null or valid_until>statement_timestamp())));
end $$;
create function trainer_private.save_trainer_client_notes(p_operation_id uuid,p_client_id uuid,p_expected_revision integer,p_notes text,p_goal text)
returns integer language plpgsql security definer set search_path='' as $$
declare old trainer_private.client_note_versions; latest integer; notes text:=btrim(coalesce(p_notes,'')); goal text:=btrim(coalesce(p_goal,''));
begin
 perform trainer_private.require_client_portfolio(p_client_id);
 perform trainer_private.require_authoring_access();
 if p_operation_id is null or p_expected_revision is null or p_expected_revision<0 or length(notes)>2000 or length(goal)>500
  or translate(notes||goal,E'\n\t\r','') ~ '[[:cntrl:]]' then raise invalid_parameter_value; end if;
 select * into old from trainer_private.client_note_versions where trainer_id=auth.uid() and operation_id=p_operation_id;
 if found then
  if old.client_id<>p_client_id or old.expected_revision<>p_expected_revision or old.notes<>notes or old.goal<>goal then raise invalid_parameter_value; end if;
  return old.revision;
 end if;
 select coalesce(max(revision),0) into latest from trainer_private.client_note_versions where trainer_id=auth.uid() and client_id=p_client_id;
 if latest<>p_expected_revision then raise exception 'La ficha cambió. Recarga antes de guardar tus notas.' using errcode='40001'; end if;
 insert into trainer_private.client_note_versions(trainer_id,client_id,revision,notes,goal,operation_id,expected_revision)
  values(auth.uid(),p_client_id,latest+1,notes,goal,p_operation_id,p_expected_revision);
 update public.trainer_access set membership_version=membership_version+1 where trainer_id=auth.uid();
 return latest+1;
end $$;

-- Solo registros originados por pautas del servicio propio. Las métricas se
-- agrupan por fecha de INICIO de ejecución en UTC, no por una fecha de serie
-- supuesta. El cumplimiento conserva la fecha civil pautada.
create function trainer_private.client_progress_rows(p_client_id uuid,p_start date,p_end_exclusive date,p_kind text)
returns table(cursor_date date,cursor_id text,content jsonb)
language sql stable security definer set search_path='' as $$
 select s.scheduled_date,s.id::text,to_jsonb(s)||jsonb_build_object('id',a.scheduled_id,'record_date',s.scheduled_date)
 from public.trainer_assignments a join public.scheduled_workouts s on s.id=a.scheduled_id
 where p_kind='assignments' and a.trainer_id=auth.uid() and a.client_id=p_client_id
  and s.scheduled_date>=p_start and s.scheduled_date<p_end_exclusive
 union all
 select (e.started_at at time zone 'UTC')::date,es.id::text,to_jsonb(es)||jsonb_build_object(
  'record_date',(e.started_at at time zone 'UTC')::date,'execution_started_at',e.started_at,'date_source','execution_started_at_utc')
 from public.trainer_assignments a join public.scheduled_workouts s on s.id=a.scheduled_id
 join public.workout_executions e on e.id=s.execution_id join public.workout_execution_sets es on es.execution_id=e.id
 where p_kind='sets' and a.trainer_id=auth.uid() and a.client_id=p_client_id
  and (e.started_at at time zone 'UTC')::date>=p_start and (e.started_at at time zone 'UTC')::date<p_end_exclusive
 union all
 select (e.started_at at time zone 'UTC')::date,ar.execution_id::text||':'||ar.block_order::text,
  to_jsonb(ar)||jsonb_build_object('id',ar.execution_id::text||':'||ar.block_order::text,
   'record_date',(e.started_at at time zone 'UTC')::date,'execution_started_at',e.started_at,'date_source','execution_started_at_utc')
 from public.trainer_assignments a join public.scheduled_workouts s on s.id=a.scheduled_id
 join public.workout_executions e on e.id=s.execution_id join public.workout_amrap_results ar on ar.execution_id=e.id
 where p_kind='amrap' and a.trainer_id=auth.uid() and a.client_id=p_client_id
  and (e.started_at at time zone 'UTC')::date>=p_start and (e.started_at at time zone 'UTC')::date<p_end_exclusive;
$$;
create function trainer_private.get_trainer_client_progress(p_client_id uuid,p_start date,p_end_exclusive date,p_kind text,
 p_before_date date default null,p_before_id text default null) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare items jsonb; total bigint; remaining bigint; fingerprint text;
begin
 perform trainer_private.require_client_portfolio(p_client_id);
 if p_start is null or p_end_exclusive is null or p_end_exclusive<=p_start or p_end_exclusive-p_start>366
  or p_kind is null or p_kind not in ('assignments','sets','amrap') or (p_before_date is null)<>(p_before_id is null)
  or length(p_before_id)>80 then raise invalid_parameter_value; end if;
 -- Depende de trainer_operational_workflow: sus triggers incrementan las
 -- revisiones al cambiar cabecera, series, AMRAP o enlace de ejecución.
 -- La fecha de inicio forma parte de la cohorte y detecta entradas/salidas
 -- del periodo sin serializar otra vez todas las series en cada página.
 -- Esta huella solo comprueba consistencia; nunca autoriza lectura.
 select md5(concat_ws('|',auth.uid(),p_client_id,p_start,p_end_exclusive,coalesce(
  string_agg(concat_ws(':',a.scheduled_id,a.planning_revision,a.result_revision,s.scheduled_date,s.status,s.execution_id,e.started_at),',' order by a.scheduled_id),'')))
 into fingerprint from public.trainer_assignments a join public.scheduled_workouts s on s.id=a.scheduled_id
 left join public.workout_executions e on e.id=s.execution_id
 where a.trainer_id=auth.uid() and a.client_id=p_client_id and
  ((s.scheduled_date>=p_start and s.scheduled_date<p_end_exclusive)
   or ((e.started_at at time zone 'UTC')::date>=p_start and (e.started_at at time zone 'UTC')::date<p_end_exclusive));
 select count(*) into total from trainer_private.client_progress_rows(p_client_id,p_start,p_end_exclusive,p_kind);
 select count(*) into remaining from trainer_private.client_progress_rows(p_client_id,p_start,p_end_exclusive,p_kind)
  where p_before_date is null or (cursor_date,cursor_id)<(p_before_date,p_before_id);
 select coalesce(jsonb_agg(content order by cursor_date desc,cursor_id desc),'[]') into items from (
  select * from trainer_private.client_progress_rows(p_client_id,p_start,p_end_exclusive,p_kind)
   where p_before_date is null or (cursor_date,cursor_id)<(p_before_date,p_before_id)
   order by cursor_date desc,cursor_id desc limit 200) x;
 return jsonb_build_object('items',items,'total',total,'has_more',remaining>200,'limit',200,'fingerprint',fingerprint,
  'start',p_start,'end_exclusive',p_end_exclusive,'date_basis',case when p_kind='assignments' then 'scheduled_civil_date' else 'execution_started_at_utc' end);
end $$;

do $$ declare signature text; begin
 foreach signature in array array[
 'trainer_private.require_client_portfolio(uuid)',
 'trainer_private.get_trainer_client_workspace(uuid)',
 'trainer_private.save_trainer_client_notes(uuid,uuid,integer,text,text)',
 'trainer_private.client_progress_rows(uuid,date,date,text)',
 'trainer_private.get_trainer_client_progress(uuid,date,date,text,date,text)'] loop
  execute format('revoke all on function %s from public,anon,authenticated',signature);
 end loop;
end $$;
create function public.get_trainer_client_workspace(p_client_id uuid) returns jsonb
language sql stable security invoker set search_path='' as $$ select trainer_private.get_trainer_client_workspace(p_client_id); $$;
create function public.save_trainer_client_notes(p_operation_id uuid,p_client_id uuid,p_expected_revision integer,p_notes text,p_goal text) returns integer
language sql security invoker set search_path='' as $$ select trainer_private.save_trainer_client_notes(p_operation_id,p_client_id,p_expected_revision,p_notes,p_goal); $$;
create function public.get_trainer_client_progress(p_client_id uuid,p_start date,p_end_exclusive date,p_kind text,
 p_before_date date default null,p_before_id text default null) returns jsonb language sql stable security invoker set search_path='' as $$
 select trainer_private.get_trainer_client_progress(p_client_id,p_start,p_end_exclusive,p_kind,p_before_date,p_before_id); $$;
do $$ declare signature text; begin
 foreach signature in array array['get_trainer_client_workspace(uuid)',
 'save_trainer_client_notes(uuid,uuid,integer,text,text)','get_trainer_client_progress(uuid,date,date,text,date,text)'] loop
  execute format('revoke all on function public.%s from public,anon,authenticated',signature);
  execute format('grant execute on function public.%s to authenticated',signature);
  execute format('grant execute on function trainer_private.%s to authenticated',signature);
 end loop;
end $$;
commit;
