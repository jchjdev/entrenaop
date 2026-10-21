-- Resúmenes de participantes: no abre perfiles, correos ni historiales completos.
create function trainer_private.list_my_trainer_relations(
  p_as_trainer boolean, p_ended boolean default false,
  p_before_at timestamptz default null, p_before_id uuid default null
) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare result jsonb;
begin
  if auth.uid() is null or coalesce((auth.jwt()->>'is_anonymous')::boolean,false) then
    raise insufficient_privilege;
  end if;
  if p_as_trainer is null or p_ended is null or
    ((p_before_at is null) <> (p_before_id is null)) then
    raise exception 'Paginación inválida.' using errcode='22023';
  end if;
  select coalesce(jsonb_agg(to_jsonb(items) order by accepted_at desc,id desc),'[]'::jsonb)
    into result from (
      select r.id,r.accepted_at,r.ended_at,
        case when p_as_trainer then r.client_id else r.trainer_id end as person_id,
        coalesce(nullif(btrim(p.full_name),''),'Usuario de EntrenaOP') as person_name
      from public.trainer_client_relations r
      join public.profiles p on p.id=case when p_as_trainer then r.client_id else r.trainer_id end
      where (case when p_as_trainer then r.trainer_id else r.client_id end)=auth.uid()
        and (r.ended_at is not null)=p_ended
        and (p_before_at is null or (r.accepted_at,r.id)<(p_before_at,p_before_id))
      order by r.accepted_at desc,r.id desc limit 50
    ) items;
  return result;
end $$;

create function public.list_my_trainer_relations(
  p_as_trainer boolean, p_ended boolean default false,
  p_before_at timestamptz default null, p_before_id uuid default null
) returns jsonb language sql stable security invoker set search_path='' as $$
  select trainer_private.list_my_trainer_relations(p_as_trainer,p_ended,p_before_at,p_before_id);
$$;
revoke all on function trainer_private.list_my_trainer_relations(boolean,boolean,timestamptz,uuid) from public,anon,authenticated;
revoke all on function public.list_my_trainer_relations(boolean,boolean,timestamptz,uuid) from public,anon,authenticated;
grant execute on function trainer_private.list_my_trainer_relations(boolean,boolean,timestamptz,uuid) to authenticated;
grant execute on function public.list_my_trainer_relations(boolean,boolean,timestamptz,uuid) to authenticated;

create function trainer_private.get_trainer_management_status(p_trainer_id uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
begin
  if auth.uid() is null or not public.can_manage_pro_accounts() then raise insufficient_privilege; end if;
  return jsonb_build_object('access',trainer_private.get_trainer_access(p_trainer_id),
    'manual_access_enabled',coalesce((select manual_access_enabled
      from public.trainer_access_settings where singleton),false));
end $$;
create function public.get_trainer_management_status(p_trainer_id uuid)
returns jsonb language sql stable security invoker set search_path='' as $$
  select trainer_private.get_trainer_management_status(p_trainer_id);
$$;
revoke all on function trainer_private.get_trainer_management_status(uuid) from public,anon,authenticated;
revoke all on function public.get_trainer_management_status(uuid) from public,anon,authenticated;
grant execute on function trainer_private.get_trainer_management_status(uuid) to authenticated;
grant execute on function public.get_trainer_management_status(uuid) to authenticated;
