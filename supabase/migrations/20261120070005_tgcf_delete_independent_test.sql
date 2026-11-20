-- La condición del DELETE protege un intento que se asocia a una preparación
-- después de haber cargado el historial en el cliente.
create function builtin_assessment_private.delete_independent_fas_assessment(p_assessment_id uuid)
returns boolean
language plpgsql security definer set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
begin
  if v_user_id is null then
    raise insufficient_privilege;
  end if;

  delete from public.fas_periodic_assessments a
  where a.id = p_assessment_id and a.user_id = v_user_id
    and a.preparation_goal_id is null;

  return found;
end;
$$;

create function public.delete_independent_fas_assessment(p_assessment_id uuid)
returns boolean
language sql security invoker set search_path = ''
as $$
  select builtin_assessment_private.delete_independent_fas_assessment(p_assessment_id);
$$;

revoke all on function builtin_assessment_private.delete_independent_fas_assessment(uuid),
  public.delete_independent_fas_assessment(uuid) from public, anon, authenticated;
grant execute on function builtin_assessment_private.delete_independent_fas_assessment(uuid),
  public.delete_independent_fas_assessment(uuid) to authenticated;

notify pgrst, 'reload schema';
