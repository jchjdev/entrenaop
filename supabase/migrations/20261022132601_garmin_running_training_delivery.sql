begin;

alter table device_private.garmin_connections add column training_lease uuid, add column training_lease_until timestamptz,
 add constraint garmin_training_lease_pair check((training_lease is null)=(training_lease_until is null));

-- Cita y snapshot son comunes al algoritmo y al preparador. Ningún JSON del
-- cliente puede sustituir la receta ni su autoridad de prescripción.
create function device_private.training_source(p_actor uuid,p_owner uuid,p_schedule uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare s public.scheduled_workouts; t public.workout_templates; a public.trainer_assignments;
 decision jsonb; recipe jsonb;
begin
 select * into s from public.scheduled_workouts where id=p_schedule and user_id=p_owner for share;
 if not found or s.status<>'planned' or s.execution_id is not null then raise exception 'source_not_available' using errcode='42501'; end if;
 select * into t from public.workout_templates where id=s.template_id for share;
 if not found or t.status<>'published' or t.version<>s.template_version then raise exception 'stale_prescription' using errcode='40001'; end if;
 if s.source='algorithm' then
  if p_actor<>p_owner or t.origin is distinct from 'algorithm' or t.owner_user_id is distinct from p_owner then raise insufficient_privilege; end if;
  select jsonb_build_object('decision_id',d.id,'policy_version',d.policy_version) into decision
   from public.running_week_sessions rs join public.running_week_decisions d on d.id=rs.decision_id
   join public.preparation_goals g on g.id=s.preparation_goal_id
   where rs.scheduled_workout_id=s.id and d.user_id=p_owner and d.preparation_goal_id=g.id and g.user_id=p_owner and g.status='active';
  if decision is null then raise exception 'source_not_allowed' using errcode='42501'; end if;
 elsif s.source='coach' then
  select * into a from public.trainer_assignments where scheduled_id=s.id and client_id=p_owner;
  if not found or (p_actor<>p_owner and a.trainer_id<>p_actor) then raise insufficient_privilege; end if;
  if not exists(select 1 from public.trainer_client_relations r join public.trainer_access x on x.trainer_id=r.trainer_id
    where r.id=a.relation_id and r.client_id=p_owner and r.trainer_id=a.trainer_id and r.ended_at is null and x.enabled
    and (x.valid_until is null or x.valid_until>clock_timestamp())) then raise insufficient_privilege; end if;
  if t.origin is distinct from 'coach' or t.owner_user_id is distinct from a.trainer_id then raise exception 'source_not_allowed' using errcode='42501'; end if;
  decision:=jsonb_build_object('assignment_id',s.id,'planning_revision',a.planning_revision);
 else raise exception 'source_not_allowed' using errcode='42501'; end if;
 select jsonb_build_object('name',s.template_name,'description',t.description,'date',s.scheduled_date,'source',s.source,
   'template_id',t.id,'template_version',t.version,'authority',decision,'blocks',coalesce(jsonb_agg(
    jsonb_build_object('order_index',b.order_index,'name',b.name,'format',b.format,'rounds',b.rounds,
      'rest_after_seconds',b.rest_after_seconds,'time_cap_seconds',b.time_cap_seconds,'items',
      (select coalesce(jsonb_agg(jsonb_build_object('order_index',i.order_index,'exercise_id',i.exercise_id,'notes',i.notes,
       'sets',(select coalesce(jsonb_agg(to_jsonb(w)-'id'-'item_id' order by w.order_index),'[]'::jsonb)
        from public.workout_sets w where w.item_id=i.id)) order by i.order_index),'[]'::jsonb)
       from public.workout_items i where i.block_id=b.id)) order by b.order_index),'[]'::jsonb)) into recipe
  from public.workout_blocks b where b.template_id=t.id;
 if octet_length(recipe::text)>131072 then raise exception 'unsupported_prescription' using errcode='22023'; end if;
 return jsonb_build_object('snapshot',recipe,'revision',encode(sha256(convert_to(recipe::text,'UTF8')),'hex'));
end $$;
revoke all on function device_private.training_source(uuid,uuid,uuid) from public,anon,authenticated,service_role;

create table device_private.training_deliveries (
 id uuid primary key default gen_random_uuid(),
 owner_id uuid not null references auth.users(id) on delete cascade,
 -- Referencia histórica deliberada: no impedir reset/borrado de la agenda ni
 -- borrar el recibo que evita repetir un envío remoto ya producido.
 scheduled_id uuid not null,
 provider text not null default 'garmin' check(provider='garmin'),
 adapter_version integer not null default 1 check(adapter_version=1),
 connection_generation bigint not null,
 revision text not null check(revision ~ '^[0-9a-f]{64}$'),
 snapshot jsonb not null check(jsonb_typeof(snapshot)='object' and octet_length(snapshot::text)<=131072),
 status text not null default 'prepared' check(status in ('prepared','refreshing','creating','workout_created','scheduling','sent','failed','uncertain')),
 workout_id bigint check(workout_id>0 and workout_id<=9007199254740991),
 schedule_id bigint check(schedule_id>0 and schedule_id<=9007199254740991),
 lease_id uuid, lease_until timestamptz, lease_actor uuid, lease_session uuid, last_attempt_at timestamptz,
 error_code text check(error_code in ('provider_rejected','provider_unavailable','rate_limited','permission_denied',
   'reauthorization_required','invalid_provider_response','schedule_not_confirmed','delivery_uncertain','connection_changed','stale_prescription','garmin_unavailable')),
 created_at timestamptz not null default clock_timestamp(),updated_at timestamptz not null default clock_timestamp(),
 unique(owner_id,scheduled_id,provider),
 check(status not in ('workout_created','scheduling','sent') or workout_id is not null),
 check(status<>'sent' or schedule_id is not null)
);
alter table device_private.training_deliveries enable row level security;
revoke all on device_private.training_deliveries from public,anon,authenticated,service_role;
create index training_deliveries_schedule on device_private.training_deliveries(scheduled_id);

create function device_private.training_receipt(p_id uuid) returns jsonb language sql stable set search_path='' as $$
 select jsonb_build_object('id',id,'scheduled_id',scheduled_id,'revision',revision,
  'status',case when status in ('refreshing','creating','scheduling') and (lease_until is null or lease_until<=statement_timestamp()) then 'uncertain' else status end,
  'error_code',error_code,'date',snapshot->>'date','name',snapshot->>'name','source',snapshot->>'source')
 from device_private.training_deliveries where id=p_id;
$$;
revoke all on function device_private.training_receipt(uuid) from public,anon,authenticated,service_role;

create function device_private.garmin_training_command(p_action text,p_actor uuid,p_owner uuid,p_session uuid,p_input jsonb)
returns jsonb language plpgsql security definer set search_path='' as $$
declare c device_private.garmin_connections; j device_private.training_deliveries; src jsonb;
 v_now timestamptz; v_schedule uuid; v_lease uuid; v_generation bigint; v_code text; v_count integer;
begin
 if p_input is null or jsonb_typeof(p_input)<>'object' or octet_length(p_input::text)>40000 or p_owner is null or p_actor is null then
  raise invalid_parameter_value; end if;
 -- Mismo orden que la edición/retirada profesional, antes de cita y conexión.
 perform pg_advisory_xact_lock(hashtextextended('trainer-client:'||p_owner::text,0));
 perform 1 from auth.users where id=p_owner for key share;
 if not found then raise insufficient_privilege; end if;
 if p_action in ('list','preview','claim','mark_refreshing','mark_creating','mark_scheduling') then
 perform 1 from auth.sessions where id=p_session and user_id=p_actor and (not_after is null or not_after>clock_timestamp())
  and (p_actor=p_owner or aal='aal2') for key share;
 if not found then raise exception 'account_changed' using errcode='42501'; end if;
 if p_actor<>p_owner and not exists(select 1 from public.trainer_client_relations r join public.trainer_access a on a.trainer_id=r.trainer_id
  where r.trainer_id=p_actor and r.client_id=p_owner and r.ended_at is null and a.enabled
   and (a.valid_until is null or a.valid_until>clock_timestamp())) then raise insufficient_privilege; end if;
 end if;
 if p_action='list' then
  return jsonb_build_object('candidates',(select coalesce(jsonb_agg(to_jsonb(x)),'[]'::jsonb) from (
   select s.id,s.template_name as name,s.scheduled_date as date,s.source
    from public.scheduled_workouts s where s.user_id=p_owner and s.status='planned' and s.execution_id is null
    and s.scheduled_date between current_date-1 and current_date+366
    and ((p_actor=p_owner and s.source='algorithm') or (s.source='coach' and exists(select 1 from public.trainer_assignments a
     where a.scheduled_id=s.id and a.client_id=p_owner and (p_actor=p_owner or a.trainer_id=p_actor))))
    and exists(select 1 from public.workout_blocks b where b.template_id=s.template_id and b.format='running')
    order by s.scheduled_date,s.order_index,s.id limit 30) x),
   'deliveries',(select coalesce(jsonb_agg(device_private.training_receipt(x.id)),'[]'::jsonb) from (
    select d.id from device_private.training_deliveries d where d.owner_id=p_owner and (p_actor=p_owner or exists(
     select 1 from public.trainer_assignments a where a.scheduled_id=d.scheduled_id and a.trainer_id=p_actor))
     order by d.created_at desc limit 30) x));
 end if;
 if p_action in ('preview','claim') then
  if not device_private.garmin_access(p_owner) then raise exception 'access_required' using errcode='42501'; end if;
  v_schedule:=(p_input->>'scheduled_id')::uuid;
  src:=device_private.training_source(p_actor,p_owner,v_schedule);
  if p_action='preview' then return src; end if;
  if src->>'revision' is distinct from p_input->>'revision' then raise exception 'stale_prescription' using errcode='40001'; end if;
 end if;
 select * into c from device_private.garmin_connections where owner_id=p_owner for update;
 if not found then raise exception 'connection_required' using errcode='42501'; end if;
 v_now:=clock_timestamp();
 if p_action='claim' then
  select * into j from device_private.training_deliveries where owner_id=p_owner and scheduled_id=v_schedule for update;
  if found then
   if j.revision<>src->>'revision' or (j.connection_generation<>c.generation and (j.workout_id is not null or j.status not in ('prepared','failed'))) then
    raise exception 'delivery_needs_review' using errcode='40001'; end if;
   if j.status='sent' then return jsonb_build_object('done',true,'receipt',device_private.training_receipt(j.id)); end if;
   if j.status in ('refreshing','creating','scheduling','uncertain') then
    if j.lease_until>v_now then raise exception 'connection_busy' using errcode='40001'; end if;
    return jsonb_build_object('done',true,'receipt',device_private.training_receipt(j.id)||jsonb_build_object('status','uncertain'));
   end if;
   if j.lease_until>v_now then raise exception 'connection_busy' using errcode='40001'; end if;
   if j.last_attempt_at>v_now-interval '30 seconds' then raise exception 'rate_limited' using errcode='P0001'; end if;
  end if;
  if c.status<>'connected' or not c.can_send then raise exception 'connection_required' using errcode='42501'; end if;
  if c.training_lease_until>v_now or c.disconnect_lease_until>v_now then raise exception 'connection_busy' using errcode='40001'; end if;
  if j.id is null then
   insert into device_private.training_deliveries(owner_id,scheduled_id,connection_generation,revision,snapshot)
    values(p_owner,v_schedule,c.generation,src->>'revision',src->'snapshot') returning * into j;
  elsif j.connection_generation<>c.generation then
   -- Reconectar permite continuar solo si se sabe que no se creó nada remoto.
   update device_private.training_deliveries set connection_generation=c.generation where id=j.id;
  end if;
  v_lease:=(p_input->>'lease_id')::uuid;
  if v_lease is null then raise invalid_parameter_value; end if;
  update device_private.garmin_connections set training_lease=v_lease,training_lease_until=v_now+interval '3 minutes' where owner_id=p_owner;
  update device_private.training_deliveries set lease_id=v_lease,lease_until=v_now+interval '3 minutes',lease_actor=p_actor,lease_session=p_session,
   last_attempt_at=v_now,updated_at=v_now where id=j.id;
  return jsonb_build_object('done',false,'id',j.id,'generation',c.generation,'snapshot',j.snapshot,
   'workout_id',j.workout_id,'garmin_user_id',c.garmin_user_id,'tokens_cipher',c.tokens_cipher,'access_expires_at',c.access_expires_at,'refresh_expires_at',c.refresh_expires_at);
 end if;
 select * into j from device_private.training_deliveries where id=(p_input->>'id')::uuid and owner_id=p_owner for update;
 if not found or j.lease_actor is distinct from p_actor or j.lease_session is distinct from p_session then
  raise insufficient_privilege; end if;
 v_lease:=(p_input->>'lease_id')::uuid;
 if j.lease_id is distinct from v_lease or v_lease is null or c.training_lease is distinct from v_lease
  or c.generation<>j.connection_generation or j.lease_until<=v_now or c.training_lease_until<=v_now then
  raise exception 'stale_attempt' using errcode='40001'; end if;
 if p_action='release' then
  update device_private.training_deliveries set lease_id=null,lease_until=null where id=j.id;
  update device_private.garmin_connections set training_lease=null,training_lease_until=null where owner_id=p_owner;
  return device_private.training_receipt(j.id);
 end if;
 if p_action='fail' then
  if j.status='sent' then return device_private.training_receipt(j.id); end if;
  v_code:=p_input->>'code';
  if j.status='refreshing' and coalesce((p_input->>'uncertain')::boolean,false) then
   update device_private.garmin_connections set status='revocation_pending',can_read=false,can_send=false where owner_id=p_owner;
  end if;
  -- Una respuesta local perdida no borra hechos que sí quedaron confirmados:
  -- reutilizar el workout guardado o devolver el recibo final, sin otro POST.
  update device_private.training_deliveries set status=case when coalesce((p_input->>'uncertain')::boolean,false)
    and j.status in ('refreshing','creating','scheduling') then 'uncertain' else 'failed' end,
   error_code=v_code,updated_at=v_now where id=j.id;
  return device_private.training_receipt(j.id);
 end if;
 if p_action='rotate' then
  if j.status<>'refreshing' or coalesce(p_input->>'tokens_cipher','')='' or
   (p_input->>'access_expires_at')::timestamptz<=v_now or (p_input->>'refresh_expires_at')::timestamptz<=v_now or
   not isfinite((p_input->>'access_expires_at')::timestamptz) or not isfinite((p_input->>'refresh_expires_at')::timestamptz) then
    raise invalid_parameter_value; end if;
  update device_private.garmin_connections set tokens_cipher=p_input->>'tokens_cipher',
   access_expires_at=(p_input->>'access_expires_at')::timestamptz,refresh_expires_at=(p_input->>'refresh_expires_at')::timestamptz where owner_id=p_owner;
  update device_private.training_deliveries set status=case when workout_id is null then 'prepared' else 'workout_created' end where id=j.id;
  return '{}'::jsonb;
 end if;
 if p_action='permissions' then
  update device_private.garmin_connections set can_read=status='connected' and (p_input->>'can_read')::boolean,
   can_send=status='connected' and (p_input->>'can_send')::boolean where owner_id=p_owner;
  return '{}'::jsonb;
 end if;
 if p_action='mark_refreshing' then
  if c.status<>'connected' or not c.can_send or j.status not in ('prepared','workout_created','failed') then raise exception 'connection_changed' using errcode='40001'; end if;
  update device_private.training_deliveries set status='refreshing',updated_at=v_now where id=j.id;
  return '{}'::jsonb;
 end if;
 if p_action in ('mark_creating','mark_scheduling') then
  if c.status<>'connected' or not c.can_send then raise exception 'connection_changed' using errcode='40001'; end if;
  if not device_private.garmin_access(p_owner) then raise exception 'access_required' using errcode='42501'; end if;
  -- Revalidar autoridad/versión justo antes de cada escritura externa.
  src:=device_private.training_source(p_actor,p_owner,j.scheduled_id);
  if src->>'revision'<>j.revision then raise exception 'stale_prescription' using errcode='40001'; end if;
  if (p_action='mark_creating' and (j.status not in ('prepared','failed') or j.workout_id is not null))
   or (p_action='mark_scheduling' and (j.status not in ('workout_created','failed') or j.workout_id is null)) then raise invalid_parameter_value; end if;
  update device_private.training_deliveries set status=case p_action when 'mark_creating' then 'creating' else 'scheduling' end,
   error_code=null,updated_at=v_now where id=j.id;
 elsif p_action='save_workout' then
  if j.status<>'creating' then raise invalid_parameter_value; end if;
  update device_private.training_deliveries set status='workout_created',workout_id=(p_input->>'workout_id')::bigint,updated_at=v_now where id=j.id;
 elsif p_action='save_schedule' then
  if j.status<>'scheduling' then raise invalid_parameter_value; end if;
  update device_private.training_deliveries set status='sent',schedule_id=(p_input->>'schedule_id')::bigint,error_code=null,updated_at=v_now where id=j.id;
 else raise invalid_parameter_value; end if;
 return device_private.training_receipt(j.id);
end $$;
revoke all on function device_private.garmin_training_command(text,uuid,uuid,uuid,jsonb) from public,anon,authenticated;
grant execute on function device_private.garmin_training_command(text,uuid,uuid,uuid,jsonb) to service_role;
create function public.garmin_training_command(p_action text,p_actor uuid,p_owner uuid,p_session uuid,p_input jsonb) returns jsonb
language sql security invoker set search_path='' as $$select device_private.garmin_training_command(p_action,p_actor,p_owner,p_session,p_input);$$;
revoke all on function public.garmin_training_command(text,uuid,uuid,uuid,jsonb) from public,anon,authenticated;
grant execute on function public.garmin_training_command(text,uuid,uuid,uuid,jsonb) to service_role;

-- Una desconexión invalida nuevos pasos de envío inmediatamente, pero no rota
-- ni revoca tokens mientras una petición acotada usa la concesión existente.
do $$declare definition text; anchor text:='or (c.disconnect_lease_until is not null and c.disconnect_lease_until>v_now) then';begin
 definition:=pg_get_functiondef('device_private.garmin_account_command(text,uuid,uuid,jsonb)'::regprocedure);
 if strpos(definition,anchor)=0 then raise exception 'Revisar contrato de revocación antes de extenderlo.';end if;
 definition:=replace(definition,anchor,'or (c.training_lease_until is not null and c.training_lease_until>v_now) '||anchor);
 execute definition;
end $$;

commit;
