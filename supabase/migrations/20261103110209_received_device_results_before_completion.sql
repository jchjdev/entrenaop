begin;

-- Un enlace de recepción no equivale a completar la pauta ni inventa series.
alter table device_private.activity_return_jobs
 add column matched_schedule_id uuid references public.scheduled_workouts(id) on delete set null,
 add column matched_delivery_revision text check(matched_delivery_revision is null or matched_delivery_revision ~ '^[a-f0-9]{64}$');
create index activity_return_matched_schedule on device_private.activity_return_jobs(owner_id,matched_schedule_id)
 where matched_schedule_id is not null;

do $migration$ declare definition text;anchor text;begin
 definition:=pg_get_functiondef('device_private.garmin_automatic_result(text,uuid,jsonb)'::regprocedure);
 anchor:=$anchor$  update device_private.activity_return_jobs set completion_state='review',completion_code=code where id=j.id;$anchor$;
 if strpos(definition,anchor)=0 then raise exception 'Revisar enlace de recepción Garmin';end if;
 execute replace(definition,anchor,$body$
  if code='intervals_require_review' and p_input->>'scheduled_id' is not null then
   select * into d from device_private.training_deliveries where owner_id=p_owner and provider='garmin'
    and scheduled_id=(p_input->>'scheduled_id')::uuid and revision=p_input->>'delivery_revision'
    and status='sent' and connection_generation=c.generation;
   if not found or a.observation->>'prescriptionReference' is null or a.observation->>'offsetSeconds' is null
    or (a.observation->>'offsetSeconds')::integer%60<>0 then raise exception 'stale_prescription' using errcode='40001';end if;
   if not device_private.activity_in_completion_window((a.observation->>'startedAt')::timestamptz,
    (a.observation->>'offsetSeconds')::integer/60,(d.snapshot->>'date')::date) then
     raise exception 'completion_window_required' using errcode='22023';end if;
   update device_private.activity_return_jobs set matched_schedule_id=d.scheduled_id,matched_delivery_revision=d.revision where id=j.id;
  else
   update device_private.activity_return_jobs set matched_schedule_id=null,matched_delivery_revision=null where id=j.id;
  end if;
$body$||anchor);
end $migration$;

create function device_private.my_scheduled_device_results(p_owner uuid,p_ids uuid[]) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare result jsonb:='{}'; s public.scheduled_workouts; garmin jsonb;
begin
 perform device_private.apple_result_identity(p_owner);
 if p_ids is null or cardinality(p_ids)>200 or array_position(p_ids,null) is not null then raise invalid_parameter_value;end if;
 for s in select * from public.scheduled_workouts where user_id=p_owner and id=any(p_ids) loop
  select coalesce(jsonb_agg(x.body order by x.created_at desc),'[]') into garmin from (
   select distinct on(a.external_id) a.external_id,a.created_at,
    jsonb_strip_nulls(jsonb_build_object('id',a.id,'scheduled_id',s.id,'provider','garmin',
     'name',a.observation->>'name','started_at',a.observation->>'startedAt',
     'timer_seconds',a.observation->'timerSeconds','distance_meters',a.observation->'distanceMeters',
     'average_heart_rate',a.observation->'averageHeartRate','max_heart_rate',a.observation->'maxHeartRate',
     'interval_count',jsonb_array_length(coalesce(a.observation->'laps',a.observation->'sets','[]')),
     'execution_id',f.execution_id,'state',case when f.execution_id is null then 'review' else 'associated' end)) as body
   from device_private.activity_observations a
   left join device_private.activity_confirmations f on f.owner_id=p_owner and f.external_id=a.external_id and f.scheduled_id=s.id
   where a.owner_id=p_owner and a.channel='garmin' and (f.execution_id is not null or exists(
    select 1 from device_private.activity_return_jobs j where j.owner_id=p_owner
     and j.matched_schedule_id=s.id and j.metadata->>'activityId'=a.external_id))
    and not exists(select 1 from device_private.activity_confirmations other
      where other.owner_id=p_owner and other.external_id=a.external_id and other.scheduled_id<>s.id)
   order by a.external_id,a.created_at desc,a.id desc limit 20
  ) x;
  result:=result||jsonb_build_object(s.id,device_private.apple_results_for_schedule(p_owner,p_owner,s.id)||garmin);
 end loop;
 return result;
end $$;
revoke all on function device_private.my_scheduled_device_results(uuid,uuid[]) from public,anon,authenticated,service_role;
grant execute on function device_private.my_scheduled_device_results(uuid,uuid[]) to authenticated;
create function public.my_scheduled_device_results(p_owner uuid,p_ids uuid[]) returns jsonb
language sql stable security invoker set search_path='' as $$
 select device_private.my_scheduled_device_results(p_owner,p_ids);
$$;
revoke all on function public.my_scheduled_device_results(uuid,uuid[]) from public,anon,authenticated,service_role;
grant execute on function public.my_scheduled_device_results(uuid,uuid[]) to authenticated;

commit;
