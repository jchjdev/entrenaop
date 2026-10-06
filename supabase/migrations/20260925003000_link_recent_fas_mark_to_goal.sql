-- Un test libre FAS reciente puede asociarse expresamente a una preparación FAS.
-- La asociación no cambia marcas, baremo ni fecha histórica.
begin;

create function public.link_recent_fas_assessment_to_goal(
  p_assessment_id uuid,
  p_goal_id uuid
) returns void
language plpgsql security definer set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
begin
  if v_user_id is null then
    raise exception 'Debes iniciar sesión.' using errcode = '42501';
  end if;
  if not exists (
    select 1 from public.preparation_goals g
    where g.id = p_goal_id and g.user_id = v_user_id
      and g.program_id = 'fas_periodic_assessment' and g.status = 'active'
  ) then
    raise exception 'Preparación FAS no disponible.' using errcode = '42501';
  end if;

  update public.fas_periodic_assessments a
  set preparation_goal_id = p_goal_id
  where a.id = p_assessment_id and a.user_id = v_user_id
    and a.preparation_goal_id is null
    and a.completed_at <= now() + interval '5 minutes'
    and a.completed_at >= now() - interval '30 days';
  if not found then
    raise exception 'El test no está disponible o ya no es reciente.'
      using errcode = '22023';
  end if;
end;
$$;

revoke all on function public.link_recent_fas_assessment_to_goal(uuid, uuid)
from public, anon;
grant execute on function public.link_recent_fas_assessment_to_goal(uuid, uuid)
to authenticated;

commit;
