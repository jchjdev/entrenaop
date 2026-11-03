begin;

-- Un único resumen por pauta para el titular y su preparador autor vigente.
-- No concede al preparador acceso a actividades privadas sin pauta confirmable.
create function device_private.results_for_schedule(p_actor uuid,p_owner uuid,p_id uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare apple jsonb; garmin jsonb;
begin
 if p_actor is null or p_owner is null or p_id is null then raise invalid_parameter_value;end if;
 if not exists(select 1 from public.scheduled_workouts where id=p_id and user_id=p_owner) then return '[]';end if;
 if p_actor is distinct from p_owner and (
  p_actor is distinct from auth.uid() or not trainer_private.has_professional_read_access() or not exists(
   select 1 from auth.sessions where id=(auth.jwt()->>'session_id')::uuid and user_id=p_actor and aal='aal2'
    and (not_after is null or not_after>statement_timestamp())
  ) or not exists(
   select 1 from public.trainer_assignments a join public.trainer_client_relations r on r.id=a.relation_id
   where a.scheduled_id=p_id and a.client_id=p_owner and a.trainer_id=p_actor
    and r.trainer_id=p_actor and r.client_id=p_owner and r.ended_at is null
  )) then return '[]';end if;
 select coalesce(jsonb_agg(value||'{"provider":"apple"}'::jsonb),'[]') into apple
 from jsonb_array_elements(device_private.apple_results_for_schedule(p_actor,p_owner,p_id));
 select coalesce(jsonb_agg(x.body order by x.created_at desc),'[]') into garmin from (
  select distinct on(a.external_id) a.external_id,a.created_at,
   jsonb_strip_nulls(jsonb_build_object('id',a.id,'scheduled_id',p_id,'provider','garmin',
    'name',a.observation->>'name','started_at',a.observation->>'startedAt',
    'timer_seconds',a.observation->'timerSeconds','distance_meters',a.observation->'distanceMeters',
    'average_heart_rate',a.observation->'averageHeartRate','max_heart_rate',a.observation->'maxHeartRate',
    'interval_count',jsonb_array_length(coalesce(a.observation->'laps',a.observation->'sets','[]')),
    'execution_id',f.execution_id,'state',case when f.execution_id is null then 'review' else 'associated' end)) as body
  from device_private.activity_observations a
  left join device_private.activity_confirmations f on f.owner_id=p_owner and f.external_id=a.external_id and f.scheduled_id=p_id
  where a.owner_id=p_owner and a.channel='garmin' and (f.execution_id is not null or exists(
   select 1 from device_private.activity_return_jobs j where j.owner_id=p_owner and j.status='done'
    and j.matched_schedule_id=p_id and j.metadata->>'activityId'=a.external_id))
   and not exists(select 1 from device_private.activity_confirmations other
     where other.owner_id=p_owner and other.external_id=a.external_id and other.scheduled_id<>p_id)
  order by a.external_id,a.created_at desc,a.id desc limit 20
 ) x;
 return apple||garmin;
end $$;
revoke all on function device_private.results_for_schedule(uuid,uuid,uuid) from public,anon,authenticated,service_role;

-- Conservar la fachada propia y la validación de sesión viva ya desplegadas.
create or replace function device_private.my_scheduled_device_results(p_owner uuid,p_ids uuid[]) returns jsonb
language plpgsql stable security definer set search_path='' as $$
begin
 perform device_private.apple_result_identity(p_owner);
 if p_ids is null or cardinality(p_ids)>200 or array_position(p_ids,null) is not null then raise invalid_parameter_value;end if;
 return coalesce((select jsonb_object_agg(s.id,device_private.results_for_schedule(p_owner,p_owner,s.id))
  from public.scheduled_workouts s where s.user_id=p_owner and s.id=any(p_ids)),'{}');
end $$;

-- Campo común aditivo. Los clientes anteriores conservan su campo Apple
-- original, sin mezclar proveedores bajo un nombre antiguo ni duplicarlos.
do $migration$ declare definition text;anchor text;begin
 definition:=pg_get_functiondef('device_private.training_progress(uuid,uuid,uuid)'::regprocedure);
 anchor:='state text; reason text; target jsonb; auto_enabled boolean; confirmed boolean;';
 if strpos(definition,anchor)=0 then raise exception 'Revisar variables de la proyección profesional';end if;
 definition:=replace(definition,anchor,anchor||' received jsonb;');
 anchor:=$anchor$return jsonb_build_object('id',s.id,'name',s.template_name,'date',s.scheduled_date,$anchor$;
 if strpos(definition,anchor)=0 then raise exception 'Revisar retorno de la proyección profesional';end if;
 definition:=replace(definition,anchor,'received:=device_private.results_for_schedule(p_actor,p_owner,p_schedule);'||anchor);
 anchor:=$anchor$'apple_results',device_private.apple_results_for_schedule(p_actor,p_owner,p_schedule),$anchor$;
 if strpos(definition,anchor)=0 then raise exception 'Revisar proyección profesional de actividades recibidas';end if;
 execute replace(definition,anchor,
  $body$'device_results',received,'apple_results',coalesce((select jsonb_agg(value)
   from jsonb_array_elements(received) where value->>'provider'='apple'),'[]'::jsonb),$body$);
end $migration$;

commit;
