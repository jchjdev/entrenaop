begin;

-- Mantener la fachada propia para clientes anteriores. La bandeja contiene
-- actividades sin confirmar, aunque el trabajador ya haya identificado su pauta.
create or replace function device_private.my_unassigned_device_activities(p_expected_owner uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare v_owner uuid:=auth.uid();
begin
 if v_owner is null or v_owner is distinct from p_expected_owner then
  raise exception 'account_changed' using errcode='42501';
 end if;
 return (select coalesce(jsonb_agg(jsonb_build_object(
  'id',r.id,'scheduled_id',case when m.matches=1 then m.scheduled_id end,
  'scheduled_name',case when m.matches=1 then m.scheduled_name end,
  'provider',r.channel,'state',case when m.matches=1 then 'review' else 'unassigned' end,
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
 ) r
 cross join lateral (
  -- No inferir por nombre o fecha ni escoger una pauta entre vínculos distintos.
  select count(distinct s.id) as matches,min(s.id::text) as scheduled_id,
   min(s.template_name) as scheduled_name
  from device_private.activity_return_jobs j
  join public.scheduled_workouts s on s.id=j.matched_schedule_id and s.user_id=v_owner
  where j.owner_id=v_owner and j.status='done' and j.metadata->>'activityId'=r.external_id
 ) m);
end $$;

commit;
