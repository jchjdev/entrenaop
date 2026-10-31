begin;
-- Recogida autorizada por cuenta. Solo se comparten observaciones de pautas
-- propias de EntrenaOP; el historial general de Salud sigue siendo privado.
create table device_private.apple_result_preferences (
 owner_id uuid primary key references auth.users(id) on delete cascade,
 enabled boolean not null default false, updated_at timestamptz not null default now()
);
create table device_private.apple_result_test_markers (
 owner_id uuid not null references auth.users(id) on delete cascade,
 workout_id uuid not null, primary key(owner_id,workout_id)
);
create table device_private.apple_activity_results (
 id uuid primary key default gen_random_uuid(), owner_id uuid not null references auth.users(id) on delete cascade,
 workout_id uuid not null, scheduled_id uuid not null, plan_id uuid not null,
 delivery_revision text not null check(delivery_revision ~ '^[0-9a-f]{64}$'),
 source_snapshot jsonb not null, observation jsonb not null,
 needs_review boolean not null, is_test boolean not null default false,
 received_at timestamptz not null default now(),
 unique(owner_id,workout_id),
 foreign key(owner_id,scheduled_id) references device_private.apple_training_deliveries(owner_id,scheduled_id) on delete cascade,
 foreign key(plan_id) references device_private.apple_training_deliveries(plan_id) on delete cascade
);
create index apple_result_schedule on device_private.apple_activity_results(owner_id,scheduled_id,received_at desc);
create table device_private.apple_activity_revisions (
 result_id uuid not null references device_private.apple_activity_results(id) on delete cascade,
 revision text not null, observation jsonb not null, received_at timestamptz not null default now(),
 primary key(result_id,revision)
);
do $$declare t text;begin
 foreach t in array array['apple_result_preferences','apple_result_test_markers','apple_activity_results','apple_activity_revisions'] loop
  execute format('alter table device_private.%I enable row level security',t);
  execute format('revoke all on device_private.%I from public,anon,authenticated,service_role',t);
 end loop;
end $$;

create function device_private.apple_result_identity(p_owner uuid) returns void
language plpgsql stable set search_path='' as $$
begin
 if p_owner is null or auth.uid() is distinct from p_owner or coalesce((auth.jwt()->>'is_anonymous')::boolean,false)
 or not exists(select 1 from auth.sessions where id=(auth.jwt()->>'session_id')::uuid and user_id=p_owner
 and (not_after is null or not_after>statement_timestamp())) then
  raise exception 'account_changed' using errcode='42501';end if;
end $$;
revoke all on function device_private.apple_result_identity(uuid) from public,anon,authenticated,service_role;

create function device_private.apple_result_json(r device_private.apple_activity_results) returns jsonb
language sql stable set search_path='' as $$
 select jsonb_strip_nulls(jsonb_build_object('id',r.id,'scheduled_id',r.scheduled_id,
  'name',r.source_snapshot->>'name','started_at',r.observation->>'started_at',
  'timer_seconds',r.observation->'timer_seconds','distance_meters',r.observation->'distance_meters',
  'average_heart_rate',r.observation->'average_heart_rate','max_heart_rate',r.observation->'max_heart_rate',
  'state',case when r.is_test then 'test' when r.needs_review then 'review' else 'associated' end));
$$;
revoke all on function device_private.apple_result_json(device_private.apple_activity_results) from public,anon,authenticated,service_role;

create function device_private.apple_results_for_schedule(p_actor uuid,p_owner uuid,p_id uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
begin
 if not exists(select 1 from public.scheduled_workouts where id=p_id and user_id=p_owner) then return '[]';end if;
 if p_actor is distinct from p_owner and (not trainer_private.has_professional_read_access() or not exists(
  select 1 from public.trainer_assignments a join public.trainer_client_relations r on r.id=a.relation_id
  where a.scheduled_id=p_id and a.client_id=p_owner and a.trainer_id=p_actor and r.ended_at is null)) then return '[]';end if;
 return coalesce((select jsonb_agg(device_private.apple_result_json(x) order by x.received_at desc,x.id)
  from device_private.apple_activity_results x where x.owner_id=p_owner and x.scheduled_id=p_id),'[]');
end $$;
revoke all on function device_private.apple_results_for_schedule(uuid,uuid,uuid) from public,anon,authenticated,service_role;

create function device_private.apple_results_command(p_owner uuid,p_action text,p_input jsonb default '{}') returns jsonb
language plpgsql security definer set search_path='' as $$
declare d device_private.apple_training_deliveries; s public.scheduled_workouts; existing device_private.apple_activity_results;
 x jsonb; v jsonb; src jsonb; ids jsonb; k text; wid uuid; pid uuid; v_result_id uuid; h text;
 start_at timestamptz; end_at timestamptz; timer numeric; elapsed numeric; n numeric; valid boolean; inserted integer:=0;
begin
 perform device_private.apple_result_identity(p_owner);
 if p_input is null or jsonb_typeof(p_input)<>'object' or octet_length(p_input::text)>65536 then raise invalid_parameter_value;end if;
 if p_action='enable' then
  if jsonb_typeof(p_input->'enabled') is distinct from 'boolean' then raise invalid_parameter_value;end if;
  if (p_input->>'enabled')::boolean and not device_private.training_device_access(p_owner) then raise exception 'access_required' using errcode='42501';end if;
  insert into device_private.apple_result_preferences(owner_id,enabled) values(p_owner,(p_input->>'enabled')::boolean)
   on conflict(owner_id) do update set enabled=excluded.enabled,updated_at=now();
  return jsonb_build_object('enabled',(p_input->>'enabled')::boolean);
 end if;
 if p_action='catalog' then
  return jsonb_build_object('enabled',coalesce((select enabled from device_private.apple_result_preferences where owner_id=p_owner),false),
   'plans',case when device_private.training_device_access(p_owner) then coalesce((select jsonb_agg(to_jsonb(q)) from (
    select plan_id,revision,snapshot from device_private.apple_training_deliveries where owner_id=p_owner
    and status in ('submitted','removed') order by updated_at desc limit 200) q),'[]') else '[]'::jsonb end,
   'results',coalesce((select jsonb_agg(device_private.apple_result_json(q)) from (
    select * from device_private.apple_activity_results where owner_id=p_owner order by received_at desc,id limit 100) q),'[]'));
 end if;
 if p_action='classify' then
  if jsonb_typeof(p_input->'is_test') is distinct from 'boolean' then raise invalid_parameter_value;end if;
  update device_private.apple_activity_results set is_test=(p_input->>'is_test')::boolean
   where owner_id=p_owner and id=(p_input->>'id')::uuid returning * into existing;
  if not found then raise insufficient_privilege;end if;
  if existing.is_test then insert into device_private.apple_result_test_markers values(p_owner,existing.workout_id) on conflict do nothing;
  else delete from device_private.apple_result_test_markers where owner_id=p_owner and workout_id=existing.workout_id;end if;
  return jsonb_build_object('classified',true);
 end if;
 if p_action<>'ingest' or p_action is null then raise invalid_parameter_value;end if;
 -- Misma exclusión que programación, retirada y operaciones del entrenador.
 perform pg_advisory_xact_lock(hashtextextended('trainer-client:'||p_owner::text,0));
 perform 1 from device_private.apple_result_preferences where owner_id=p_owner and enabled for share;
 if not found then raise exception 'results_disabled' using errcode='42501';end if;
 if not device_private.training_device_access(p_owner) then raise exception 'access_required' using errcode='42501';end if;
 if jsonb_typeof(p_input->'observations') is distinct from 'array' or jsonb_array_length(p_input->'observations')>20 then raise invalid_parameter_value;end if;
 for x in select value from jsonb_array_elements(p_input->'observations') loop
  if jsonb_typeof(x) is distinct from 'object' or octet_length(x::text)>4096 or exists(
   select 1 from jsonb_object_keys(x) a where a not in ('workout_id','plan_id','revision','matches_prescription',
    'started_at','ended_at','timer_seconds','distance_meters','average_heart_rate','max_heart_rate')) then raise invalid_parameter_value;end if;
  wid:=(x->>'workout_id')::uuid;pid:=(x->>'plan_id')::uuid;
  if wid is null or pid is null or jsonb_typeof(x->'matches_prescription') is distinct from 'boolean' then raise invalid_parameter_value;end if;
  select * into d from device_private.apple_training_deliveries where owner_id=p_owner and plan_id=pid for share;
  if not found then raise insufficient_privilege;end if;
  -- Revalida propietario/receta incluso si cambió mientras HealthKit respondía.
  select * into s from public.scheduled_workouts where id=d.scheduled_id and user_id=p_owner for share;
  if not found then raise insufficient_privilege;end if;
  start_at:=(x->>'started_at')::timestamptz;end_at:=(x->>'ended_at')::timestamptz;
  timer:=(x->>'timer_seconds')::numeric;elapsed:=extract(epoch from end_at-start_at);
  if start_at is null or end_at is null or not isfinite(start_at) or not isfinite(end_at) or start_at<'2000-01-01'::timestamptz
   or end_at>statement_timestamp()+interval '5 minutes' or elapsed not between 0 and 604800 or timer is null
   or jsonb_typeof(x->'timer_seconds')<>'number' or not(timer>0 and timer<=elapsed+1) then raise invalid_parameter_value;end if;
  foreach k in array array['distance_meters','average_heart_rate','max_heart_rate'] loop
   if coalesce(x->k,'null'::jsonb)='null'::jsonb then continue;end if;
   n:=(x->>k)::numeric;
   if jsonb_typeof(x->k)<>'number' or not(n>=0 and n<100000000) or (k<>'distance_meters' and not(n>0 and n<=400)) then raise invalid_parameter_value;end if;
  end loop;
  if (x->>'max_heart_rate')::numeric<(x->>'average_heart_rate')::numeric then raise invalid_parameter_value;end if;
  v:=jsonb_strip_nulls(jsonb_build_object('started_at',to_char(start_at at time zone 'UTC','YYYY-MM-DD"T"HH24:MI:SS.US"Z"'),
   'ended_at',to_char(end_at at time zone 'UTC','YYYY-MM-DD"T"HH24:MI:SS.US"Z"'),'timer_seconds',timer,
   'distance_meters',x->'distance_meters','average_heart_rate',x->'average_heart_rate','max_heart_rate',x->'max_heart_rate'));
  select * into existing from device_private.apple_activity_results where owner_id=p_owner and workout_id=wid for update;
  if found then
   if existing.plan_id<>pid then raise exception 'activity_conflict' using errcode='22023';end if;
   v_result_id:=existing.id;
   if exists(select 1 from jsonb_each(existing.observation) e where v ? e.key and v->e.key<>e.value) then
    update device_private.apple_activity_results set needs_review=true where id=v_result_id;
   else
    -- Añadir una medición que llegó tarde conserva las revisiones anteriores.
    update device_private.apple_activity_results set observation=observation||v where id=v_result_id;
   end if;
  else
   if (select count(*) from device_private.apple_activity_results where owner_id=p_owner)>=20000 then raise exception 'history_limit' using errcode='54000';end if;
   valid:=d.status='submitted' and d.revision=x->>'revision' and (x->>'matches_prescription')::boolean;
   if valid then
    begin src:=device_private.training_source_snapshot(p_owner,p_owner,s.id);valid:=(src->'snapshot'=d.snapshot);
    exception when insufficient_privilege or serialization_failure or invalid_parameter_value then valid:=false;end;
   end if;
   insert into device_private.apple_activity_results(owner_id,workout_id,scheduled_id,plan_id,delivery_revision,
    source_snapshot,observation,needs_review,is_test) values(p_owner,wid,s.id,pid,d.revision,d.snapshot,v,not coalesce(valid,false),
     exists(select 1 from device_private.apple_result_test_markers where owner_id=p_owner and workout_id=wid)) returning id into v_result_id;
   inserted:=inserted+1;
  end if;
  h:=device_private.history_hash(v);
  if (select count(*) from device_private.apple_activity_revisions where apple_activity_revisions.result_id=v_result_id)<32 then
   insert into device_private.apple_activity_revisions(result_id,revision,observation) values(v_result_id,h,v) on conflict do nothing;
  else update device_private.apple_activity_results set needs_review=true where id=v_result_id;end if;
 end loop;
 -- No se inventan series realizadas, RPE ni una ejecución completa a partir de totales.
 return jsonb_build_object('inserted',inserted);
end $$;
revoke all on function device_private.apple_results_command(uuid,text,jsonb) from public,anon,authenticated,service_role;
grant execute on function device_private.apple_results_command(uuid,text,jsonb) to authenticated;
create function public.apple_results_command(p_owner uuid,p_action text,p_input jsonb default '{}') returns jsonb
language sql security invoker set search_path='' as $$select device_private.apple_results_command(p_owner,p_action,p_input);$$;
revoke all on function public.apple_results_command(uuid,text,jsonb) from public,anon,authenticated,service_role;
grant execute on function public.apple_results_command(uuid,text,jsonb) to authenticated;

create function device_private.my_apple_workout_results(p_owner uuid,p_ids uuid[]) returns jsonb
language plpgsql stable security definer set search_path='' as $$
begin
 perform device_private.apple_result_identity(p_owner);
 if p_ids is null or cardinality(p_ids)>200 or array_position(p_ids,null) is not null then raise invalid_parameter_value;end if;
 return coalesce((select jsonb_object_agg(s.id,device_private.apple_results_for_schedule(p_owner,p_owner,s.id))
  from public.scheduled_workouts s where s.user_id=p_owner and s.id=any(p_ids)),'{}');
end $$;
revoke all on function device_private.my_apple_workout_results(uuid,uuid[]) from public,anon,authenticated,service_role;
grant execute on function device_private.my_apple_workout_results(uuid,uuid[]) to authenticated;
create function public.my_apple_workout_results(p_owner uuid,p_ids uuid[]) returns jsonb
language sql security invoker set search_path='' as $$ select device_private.my_apple_workout_results(p_owner,p_ids);$$;
revoke all on function public.my_apple_workout_results(uuid,uuid[]) from public,anon,authenticated,service_role;
grant execute on function public.my_apple_workout_results(uuid,uuid[]) to authenticated;

-- La proyección ya usada por Trainer incorpora evidencia Apple sin conceder
-- acceso al historial completo ni tocar el estado de entrega de Garmin.
do $$declare definition text;anchor text:='''results_confirmed'',confirmed,';begin
 definition:=pg_get_functiondef('device_private.training_progress(uuid,uuid,uuid)'::regprocedure);
 if strpos(definition,anchor)=0 then raise exception 'Revisar proyección de entrega compartida';end if;
 execute replace(definition,anchor,anchor||'''apple_results'',device_private.apple_results_for_schedule(p_actor,p_owner,p_schedule),');
end $$;
commit;
