begin;

-- Proyección de lectura: nunca reclama cola, renueva tokens o llama a Garmin.
-- Solo las fachadas ya autenticadas pueden invocarla. Las pautas compartidas
-- con otro preparador no amplían la lectura de la conexión o de sus entregas.
create function device_private.training_progress(p_actor uuid,p_owner uuid,p_schedule uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare s public.scheduled_workouts; c device_private.garmin_connections;
 d device_private.training_deliveries; j device_private.training_sync_jobs;
 today date:=(statement_timestamp() at time zone 'Europe/Madrid')::date;
 state text; reason text; target jsonb; auto_enabled boolean; confirmed boolean;
begin
 if p_actor is null or p_owner is null or p_schedule is null then raise invalid_parameter_value;end if;
 if p_actor<>p_owner and not exists(select 1 from public.trainer_assignments a
   where a.scheduled_id=p_schedule and a.client_id=p_owner and a.trainer_id=p_actor) then return null;end if;
 select * into s from public.scheduled_workouts where id=p_schedule and user_id=p_owner;
 if not found or s.source not in ('coach','algorithm') then return null;end if;
 select * into c from device_private.garmin_connections where owner_id=p_owner;
 select * into d from device_private.training_deliveries where owner_id=p_owner and scheduled_id=p_schedule;
 select * into j from device_private.training_sync_jobs where owner_id=p_owner and scheduled_id=p_schedule;
 auto_enabled:=device_private.training_sync_enabled(p_owner);
 confirmed:=exists(select 1 from device_private.activity_confirmations where owner_id=p_owner and scheduled_id=p_schedule);
 if s.status='completed' then state:='completed';
 elsif s.execution_id is not null or s.status in ('in_progress','abandoned') then state:='started';
 elsif d.status='cancelled' then state:='cancelled';
 elsif d.workout_id is not null and d.connection_generation is distinct from c.generation then
  state:='review';reason:='connection_changed';
 elsif j.state='review' or d.status in ('uncertain','refreshing','creating','scheduling') and (d.lease_until is null or d.lease_until<=statement_timestamp()) then
  state:='review';reason:=coalesce(j.error_code,d.error_code,'delivery_uncertain');
 elsif s.status in ('cancelled','skipped') then
  if d.workout_id is not null and (d.snapshot->>'date')::date>=today then
   state:='cancellation_pending';if not auto_enabled then reason:='auto_disabled';end if;
  elsif d.workout_id is not null then state:='sent';reason:='historical_preserved';
  else state:='not_sent';reason:='appointment_cancelled';end if;
 elsif d.status in ('creating','scheduling','refreshing','updating','cancelling') then
  state:=case d.status when 'updating' then 'updating' when 'cancelling' then 'cancelling' else 'sending' end;
 elsif not device_private.device_training_template(s.template_id) then state:='unsupported';reason:='unsupported_prescription';
 elsif s.scheduled_date<today then
  state:=case when d.status='sent' then 'sent' else 'not_sent' end;
  if d.status is distinct from 'sent' then reason:='past_date';end if;
 elsif not device_private.garmin_access(p_owner) then state:='blocked';reason:='access_required';
 elsif c.status is distinct from 'connected' then state:='blocked';reason:='connection_required';
 elsif not coalesce(c.can_send,false) then state:='blocked';reason:='permission_denied';
 else
  begin target:=device_private.training_sync_target(p_owner,p_schedule);
  exception when insufficient_privilege or serialization_failure or invalid_parameter_value then
   target:='{"mode":"review"}';reason:='source_changed';
  end;
  if target->>'mode'='review' then state:='review';reason:=coalesce(reason,'delivery_needs_review');
  elsif target->>'mode'='cancel' then state:='cancellation_pending';
  elsif d.status='sent' and target->>'revision'=d.revision then state:='sent';
  elsif d.status='sent' and target->>'mode'='sync' then state:='change_pending';
  elsif d.status='failed' then state:=case when j.state='pending' and auto_enabled then 'retry_pending' else 'review' end;reason:=coalesce(j.error_code,d.error_code);
  elsif s.scheduled_date>today+14 then state:='not_sent';reason:='outside_window';
  elsif target->>'mode'='hold' then state:='blocked';reason:='source_changed';
  elsif not auto_enabled then state:='not_sent';reason:='auto_disabled';
  else state:='pending';end if;
  if state in ('change_pending','cancellation_pending') and not auto_enabled then reason:='auto_disabled';end if;
 end if;
 return jsonb_build_object('id',s.id,'name',s.template_name,'date',s.scheduled_date,
  'state',state,'reason',reason,'updated_at',d.updated_at,'results_confirmed',confirmed,
  'has_delivery',d.workout_id is not null,'execution_id',s.execution_id);
end $$;
revoke all on function device_private.training_progress(uuid,uuid,uuid) from public,anon,authenticated,service_role;

create function device_private.training_progress_list(p_actor uuid,p_owner uuid) returns jsonb
language sql stable security definer set search_path='' as $$
 select coalesce(jsonb_agg(device_private.training_progress(p_actor,p_owner,x.id) order by x.scheduled_date,x.id),'[]'::jsonb)
 from (select s.id,s.scheduled_date from public.scheduled_workouts s where s.user_id=p_owner
  and s.source in ('coach','algorithm') and s.scheduled_date between (statement_timestamp() at time zone 'Europe/Madrid')::date-7
   and (statement_timestamp() at time zone 'Europe/Madrid')::date+30
  and (p_actor=p_owner or exists(select 1 from public.trainer_assignments a where a.scheduled_id=s.id and a.trainer_id=p_actor and a.client_id=p_owner))
  order by s.scheduled_date,s.id limit 60) x;
$$;
revoke all on function device_private.training_progress_list(uuid,uuid) from public,anon,authenticated,service_role;

-- Campos aditivos: los clientes anteriores siguen leyendo candidates/deliveries.
do $$declare definition text;anchor text;begin
 definition:=pg_get_functiondef('device_private.garmin_training_command(text,uuid,uuid,uuid,jsonb)'::regprocedure);
 anchor:='''deliveries'',(select';
 if strpos(definition,anchor)=0 then raise exception 'Revisar contrato de listado Garmin';end if;
 definition:=replace(definition,anchor,'''progress'',device_private.training_progress_list(p_actor,p_owner),''deliveries'',(select');
 execute definition;
 definition:=pg_get_functiondef('trainer_private.list_trainer_client_agenda(uuid,uuid,date,date,date,uuid)'::regprocedure);
 anchor:='return result;';
 if strpos(definition,anchor)=0 then raise exception 'Revisar contrato de agenda profesional';end if;
 definition:=replace(definition,anchor,'return result||jsonb_build_object(''items'',(select coalesce(jsonb_agg(x||jsonb_build_object(''device_training'',device_private.training_progress(auth.uid(),p_client_id,(x->>''id'')::uuid))),''[]''::jsonb) from jsonb_array_elements(result->''items'') x));');
 execute definition;
 -- Conservar también las causas de confirmación/estructura al finalizar cola.
 definition:=pg_get_functiondef('device_private.garmin_training_sync_command(text,jsonb)'::regprocedure);
 definition:=replace(definition,'''provider_missing'')','''provider_missing'',''schedule_not_confirmed'',''invalid_provider_response'')');
 definition:=replace(definition,'''delivery_uncertain'',''connection_changed'',''stale_prescription'')',
  '''delivery_uncertain'',''connection_changed'',''stale_prescription'',''schedule_not_confirmed'',''invalid_provider_response'')');
 execute definition;
end $$;
commit;
