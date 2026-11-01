begin;

-- Bandeja del titular, sin parámetros para consultar a un alumno. El resumen
-- conserva ausencias y precisión; no concede asociación ni acceso a otra cuenta.
create function device_private.my_unassigned_device_activities(p_expected_owner uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare v_owner uuid:=auth.uid();
begin
 if v_owner is null or v_owner is distinct from p_expected_owner then
  raise exception 'account_changed' using errcode='42501';
 end if;
 return (select coalesce(jsonb_agg(jsonb_build_object(
  'id',r.id,'scheduled_id',null,'provider',r.channel,'state','unassigned',
  'name',r.observation->>'name','started_at',r.observation->>'startedAt',
  'timer_seconds',r.observation->'timerSeconds','distance_meters',r.observation->'distanceMeters',
  'average_heart_rate',r.observation->'averageHeartRate','max_heart_rate',r.observation->'maxHeartRate',
  'interval_count',case when r.observation->>'schemaVersion'='1'
   then jsonb_array_length(r.observation->'laps') else 0 end
 ) order by r.created_at desc,r.id desc),'[]'::jsonb)
 from (
  select latest.* from (
   select distinct on (a.external_id) a.id,a.channel,a.external_id,a.observation,a.created_at
   from device_private.activity_observations a
   where a.owner_id=v_owner and a.channel='garmin'
    and not exists(select 1 from device_private.activity_confirmations c
     where c.owner_id=a.owner_id and c.external_id=a.external_id)
   order by a.external_id,a.created_at desc,a.id desc
  ) latest order by latest.created_at desc,latest.id desc limit 30
 ) r);
end $$;
revoke all on function device_private.my_unassigned_device_activities(uuid) from public,anon,authenticated,service_role;
grant execute on function device_private.my_unassigned_device_activities(uuid) to authenticated;

create function public.my_unassigned_device_activities(p_expected_owner uuid)
returns jsonb language sql stable security invoker set search_path='' as $$
 select device_private.my_unassigned_device_activities(p_expected_owner);
$$;
revoke all on function public.my_unassigned_device_activities(uuid) from public,anon,authenticated,service_role;
grant execute on function public.my_unassigned_device_activities(uuid) to authenticated;

commit;
