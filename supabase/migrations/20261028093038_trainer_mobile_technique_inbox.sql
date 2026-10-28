-- Consulta profesional reutilizable. No concede acceso ni expone URLs de vídeo.
create function trainer_private.technique_inbox(
 p_expected_owner uuid,p_before_at timestamptz default null,p_before_id uuid default null
) returns jsonb language plpgsql stable security definer set search_path='' as $$
begin
 perform trainer_private.program_work_identity(p_expected_owner);
 if (p_before_at is null)<>(p_before_id is null) then raise invalid_parameter_value; end if;
 return (select coalesce(jsonb_agg(to_jsonb(x) order by created_at desc,id desc),'[]'::jsonb) from (
  select a.id,a.created_at,a.assignment_id,t.client_id,c.display_name as client_name,s.template_name
  from public.exercise_video_assets a
  join public.trainer_assignments t on t.scheduled_id=a.assignment_id and t.trainer_id=a.trainer_id
  join public.scheduled_workouts s on s.id=t.scheduled_id
  join public.trainer_clients c on c.trainer_id=t.trainer_id and c.client_id=t.client_id
  where a.trainer_id=auth.uid() and a.scope='client_technique' and a.shared and a.status='ready'
   and trainer_private.can_feedback_video(a.id)
   and not exists(select 1 from trainer_private.video_feedback f where f.asset_id=a.id)
   and (p_before_at is null or (a.created_at,a.id)<(p_before_at,p_before_id))
  order by a.created_at desc,a.id desc limit 50
 ) x);
end $$;

create function public.list_trainer_technique_inbox(
 p_expected_owner uuid,p_before_at timestamptz default null,p_before_id uuid default null
) returns jsonb language sql stable security invoker set search_path='' as $$
 select trainer_private.technique_inbox(p_expected_owner,p_before_at,p_before_id)
$$;
revoke all on function trainer_private.technique_inbox(uuid,timestamptz,uuid),
 public.list_trainer_technique_inbox(uuid,timestamptz,uuid) from public,anon,authenticated;
grant execute on function trainer_private.technique_inbox(uuid,timestamptz,uuid),
 public.list_trainer_technique_inbox(uuid,timestamptz,uuid) to authenticated;
