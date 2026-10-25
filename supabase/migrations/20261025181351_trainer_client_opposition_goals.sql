begin;

-- Instantáneas de la meta profesional; ninguna fila concede acceso al plan
-- personal del alumno ni al servicio de otro preparador.
create table trainer_private.client_goal_versions (
 trainer_id uuid not null references public.profiles(id) on delete cascade,
 client_id uuid not null references public.profiles(id) on delete cascade,
 revision integer not null check(revision>0),
 operation_id uuid not null,
 expected_revision integer not null check(expected_revision>=0),
 payload jsonb not null check(jsonb_typeof(payload)='object' and octet_length(payload::text)<=16384),
 content jsonb not null check(jsonb_typeof(content)='object' and octet_length(content::text)<=196608),
 created_at timestamptz not null default now(),
 primary key(trainer_id,client_id,revision), unique(trainer_id,operation_id),
 foreign key(trainer_id,client_id) references public.trainer_clients(trainer_id,client_id) on delete cascade
);
create index trainer_client_goal_client on trainer_private.client_goal_versions(client_id);
alter table trainer_private.client_goal_versions enable row level security;
revoke all on trainer_private.client_goal_versions from public,anon,authenticated;

create function trainer_private.list_trainer_goal_protocols(p_expected_owner uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare result jsonb;
begin
 perform trainer_private.program_work_identity(p_expected_owner);
 -- Solo protocolos propios ya guardados en baterías, con su huella real.
 select coalesce(jsonb_agg(content||jsonb_build_object('id',id,'protocol_id',id,
  'protocol_version',version,'protocol_fingerprint',fingerprint) order by content->>'name',id),'[]') into result
 from (select distinct on(protocol_key) * from trainer_private.assessment_protocols
  where trainer_id=auth.uid() order by protocol_key,version desc) p;
 if jsonb_array_length(result)>4000 then
  raise exception 'La biblioteca supera 4.000 protocolos. Revisa tus baterías antes de añadir nuevas metas.' using errcode='22023';
 end if;
 return result;
end $$;

create function trainer_private.save_trainer_client_goal(p_expected_owner uuid,p_operation_id uuid,p_client_id uuid,
 p_expected_revision integer,p_payload jsonb) returns integer
language plpgsql security definer set search_path='' as $$
declare prior trainer_private.client_goal_versions; latest integer; item jsonb; snapshot jsonb:='[]';
 protocol trainer_private.assessment_protocols; ids uuid[]:='{}'; mark_value numeric; goal_date date; normalized jsonb;
begin
 perform trainer_private.program_work_identity(p_expected_owner);
 perform trainer_private.require_client_portfolio(p_client_id);
 if p_operation_id is null or p_expected_revision is null or p_expected_revision<0 then raise invalid_parameter_value; end if;
 perform pg_advisory_xact_lock(hashtextextended('trainer-client:'||p_client_id::text,0));
 -- El bloqueo del acceso serializa operaciones del preparador, incluso entre
 -- alumnos distintos. Una revisión ya confirmada puede recuperarse tras la baja.
 perform 1 from public.trainer_access where trainer_id=auth.uid() for update;
 select * into prior from trainer_private.client_goal_versions where trainer_id=auth.uid() and operation_id=p_operation_id;
 if found then
  if prior.client_id<>p_client_id or prior.expected_revision<>p_expected_revision or prior.payload is distinct from p_payload then raise invalid_parameter_value; end if;
  return prior.revision;
 end if;
 perform trainer_private.require_authoring_access();
 if not exists(select 1 from public.trainer_client_relations where trainer_id=auth.uid() and client_id=p_client_id and ended_at is null)
  or exists(select 1 from public.trainer_clients where trainer_id=auth.uid() and client_id=p_client_id and archived_at is not null) then raise insufficient_privilege;end if;
 if p_payload is null or jsonb_typeof(p_payload)<>'object' or octet_length(p_payload::text)>16384
  or exists(select 1 from jsonb_object_keys(p_payload) k where k not in ('title','target_date','targets'))
  or not trainer_private.form_text_valid(p_payload->'title',120,true)
  or jsonb_typeof(p_payload->'targets') is distinct from 'array' then raise invalid_parameter_value;end if;
 if jsonb_array_length(p_payload->'targets')>40 then raise invalid_parameter_value;end if;
 if p_payload->'target_date' is not null and p_payload->'target_date'<>'null'::jsonb then
  if jsonb_typeof(p_payload->'target_date')<>'string' or p_payload->>'target_date' !~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' then raise invalid_parameter_value;end if;
  begin goal_date:=(p_payload->>'target_date')::date; exception when datetime_field_overflow or invalid_datetime_format then raise invalid_parameter_value;end;
  if goal_date not between date '2000-01-01' and date '2200-12-31' then raise invalid_parameter_value;end if;
 end if;
 for item in select value from jsonb_array_elements(p_payload->'targets') loop
  if jsonb_typeof(item)<>'object' or exists(select 1 from jsonb_object_keys(item) k where k not in ('protocol_id','value'))
   or jsonb_typeof(item->'protocol_id') is distinct from 'string' or jsonb_typeof(item->'value') is distinct from 'number' then raise invalid_parameter_value;end if;
  select * into protocol from trainer_private.assessment_protocols where id=(item->>'protocol_id')::uuid and trainer_id=auth.uid();
  if not found then raise insufficient_privilege;end if;
  if protocol.id=any(ids) then raise invalid_parameter_value;end if; ids:=array_append(ids,protocol.id);
  mark_value:=(item->>'value')::numeric;
  if mark_value not between 0 and 1000000000 or mod(mark_value,(protocol.content->>'resolution')::numeric)<>0
   or (protocol.content->>'unit'='repetitions' and mod(mark_value,1)<>0) then raise invalid_parameter_value;end if;
  snapshot:=snapshot||jsonb_build_array(jsonb_build_object('value',mark_value,'protocol',protocol.content||jsonb_build_object(
   'id',protocol.id,'protocol_id',protocol.id,'protocol_version',protocol.version,'protocol_fingerprint',protocol.fingerprint)));
 end loop;
 -- No se aceptan dos versiones de la misma huella como metas diferentes.
 if (select count(distinct t->'protocol'->>'protocol_fingerprint') from jsonb_array_elements(snapshot) t)<>jsonb_array_length(snapshot) then raise invalid_parameter_value;end if;
 select coalesce(max(revision),0) into latest from trainer_private.client_goal_versions where trainer_id=auth.uid() and client_id=p_client_id;
 if latest<>p_expected_revision then raise exception 'El objetivo cambió. Recarga antes de guardar.' using errcode='40001';end if;
 normalized:=jsonb_build_object('title',btrim(p_payload->>'title'),'target_date',goal_date,'targets',snapshot);
 insert into trainer_private.client_goal_versions(trainer_id,client_id,revision,operation_id,expected_revision,payload,content)
  values(auth.uid(),p_client_id,latest+1,p_operation_id,p_expected_revision,p_payload,normalized);
 update public.trainer_access set membership_version=membership_version+1 where trainer_id=auth.uid();
 return latest+1;
end $$;

create function trainer_private.get_trainer_client_goal(p_expected_owner uuid,p_client_id uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare goal trainer_private.client_goal_versions; result jsonb; can_edit boolean;
begin
 perform trainer_private.program_work_identity(p_expected_owner);
 perform trainer_private.require_client_portfolio(p_client_id);
 can_edit:=exists(select 1 from public.trainer_access where trainer_id=auth.uid() and enabled and (valid_until is null or valid_until>statement_timestamp()))
  and exists(select 1 from public.trainer_client_relations where trainer_id=auth.uid() and client_id=p_client_id and ended_at is null)
  and exists(select 1 from public.trainer_clients where trainer_id=auth.uid() and client_id=p_client_id and archived_at is null);
 select * into goal from trainer_private.client_goal_versions where trainer_id=auth.uid() and client_id=p_client_id order by revision desc limit 1;
 if not found then return jsonb_build_object('revision',0,'title','','target_date',null,'targets','[]'::jsonb,'history_complete',true,'evaluations_considered',0,'can_edit',can_edit);end if;
 -- Un máximo explícito evita presentar una muestra reciente como récord de
 -- toda la vida. Solo pruebas completadas propias y protocolos idénticos.
 with candidates as materialized (
  select d.id,d.assessment_id,d.answers,d.completed_at from trainer_private.assessment_deliveries d
   where d.trainer_id=auth.uid() and d.client_id=p_client_id and d.status='completed' and d.completed_at is not null
   order by d.completed_at desc,d.id desc limit 201
 ), recent as materialized (select * from candidates order by completed_at desc,id desc limit 200),
 enriched as (
  select t.ordinality,t.value||jsonb_build_object('best',best.mark,'recorded_at',best.completed_at) as target
  from jsonb_array_elements(goal.content->'targets') with ordinality t(value,ordinality)
  left join lateral (
   select (a.value->>'value')::numeric as mark,d.completed_at
   from recent d join trainer_private.assessments b on b.id=d.assessment_id
   cross join lateral jsonb_array_elements(b.content->'tests') test
   cross join lateral jsonb_array_elements(coalesce(d.answers->(test->>'id'),'[]'::jsonb)) a(value)
   where test->>'protocol_fingerprint'=t.value->'protocol'->>'protocol_fingerprint'
    and test->>'unit'=t.value->'protocol'->>'unit' and test->>'direction'=t.value->'protocol'->>'direction'
    and test->'resolution'=t.value->'protocol'->'resolution'
    and a.value->'valid'='true'::jsonb and jsonb_typeof(a.value->'value')='number'
   order by case when t.value->'protocol'->>'direction'='higher' then (a.value->>'value')::numeric end desc nulls last,
    case when t.value->'protocol'->>'direction'='lower' then (a.value->>'value')::numeric end asc nulls last,d.completed_at desc,d.id desc
   limit 1
  ) best on true
 )
 select goal.content||jsonb_build_object('revision',goal.revision,'can_edit',can_edit,'targets',coalesce((select jsonb_agg(target order by ordinality) from enriched),'[]'),
  'history_complete',(select count(*)<=200 from candidates),'evaluations_considered',(select count(*) from recent)) into result;
 return result;
end $$;

-- Agenda de un alumno concreto: no escanea toda la cartera ni comparte
-- resultados/notas ajenas por el consentimiento de calendario.
create function trainer_private.list_trainer_client_agenda(p_expected_owner uuid,p_client_id uuid,p_from date,p_to date,
 p_after_date date default null,p_after_id uuid default null) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare result jsonb;
begin
 perform trainer_private.program_work_identity(p_expected_owner);
 perform trainer_private.require_client_portfolio(p_client_id);
 if p_from is null or p_to is null or p_to<p_from or p_to-p_from>61 or (p_after_date is null)<>(p_after_id is null) then raise invalid_parameter_value;end if;
 with candidates as materialized (
  select s.id,s.template_id,s.template_name,s.template_version,s.scheduled_date,s.status,s.execution_id,
   a.note,a.created_at,a.planning_revision,a.result_revision,
   exists(select 1 from public.workout_blocks b where b.template_id=s.template_id and b.format='running') as is_running
  from public.trainer_assignments a join public.scheduled_workouts s on s.id=a.scheduled_id
  where a.trainer_id=auth.uid() and a.client_id=p_client_id and s.scheduled_date between p_from and p_to
   and (p_after_date is null or (s.scheduled_date,s.id)>(p_after_date,p_after_id))
  order by s.scheduled_date,s.id limit 51
 )
 select jsonb_build_object('items',coalesce((select jsonb_agg(to_jsonb(x) order by scheduled_date,id) from (
  select * from candidates order by scheduled_date,id limit 50) x),'[]'),'has_more',(select count(*)>50 from candidates)) into result;
 return result;
end $$;

create function public.list_trainer_goal_protocols(p_expected_owner uuid) returns jsonb
language sql stable security invoker set search_path='' as $$select trainer_private.list_trainer_goal_protocols(p_expected_owner)$$;
create function public.save_trainer_client_goal(p_expected_owner uuid,p_operation_id uuid,p_client_id uuid,p_expected_revision integer,p_payload jsonb) returns integer
language sql security invoker set search_path='' as $$select trainer_private.save_trainer_client_goal(p_expected_owner,p_operation_id,p_client_id,p_expected_revision,p_payload)$$;
create function public.get_trainer_client_goal(p_expected_owner uuid,p_client_id uuid) returns jsonb
language sql stable security invoker set search_path='' as $$select trainer_private.get_trainer_client_goal(p_expected_owner,p_client_id)$$;
create function public.list_trainer_client_agenda(p_expected_owner uuid,p_client_id uuid,p_from date,p_to date,p_after_date date default null,p_after_id uuid default null) returns jsonb
language sql stable security invoker set search_path='' as $$select trainer_private.list_trainer_client_agenda(p_expected_owner,p_client_id,p_from,p_to,p_after_date,p_after_id)$$;

do $$declare signature text;begin
 foreach signature in array array['list_trainer_goal_protocols(uuid)','save_trainer_client_goal(uuid,uuid,uuid,integer,jsonb)',
  'get_trainer_client_goal(uuid,uuid)','list_trainer_client_agenda(uuid,uuid,date,date,date,uuid)'] loop
  execute format('revoke all on function trainer_private.%s from public,anon,authenticated',signature);
  execute format('revoke all on function public.%s from public,anon,authenticated',signature);
  execute format('grant execute on function trainer_private.%s to authenticated',signature);
  execute format('grant execute on function public.%s to authenticated',signature);
 end loop;
end $$;
commit;
