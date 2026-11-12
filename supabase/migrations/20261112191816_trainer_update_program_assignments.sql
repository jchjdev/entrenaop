begin;

create table trainer_private.program_update_receipts (
  trainer_id uuid not null references public.profiles(id) on delete cascade,
  operation_id uuid not null,
  request jsonb not null,
  result jsonb not null,
  primary key (trainer_id, operation_id)
);
alter table trainer_private.program_update_receipts enable row level security;
revoke all on trainer_private.program_update_receipts from public, anon, authenticated;

create function trainer_private.program_update_candidates(p_program_id uuid, p_ids uuid[] default null)
returns table (
  id uuid, client_id uuid, client_name text, scheduled_date date, session_name text,
  revision bigint, from_version integer, template_id uuid, to_version integer, reason text
)
language sql stable set search_path='' as $$
  select a.scheduled_id, a.client_id, c.display_name, s.scheduled_date, s.template_name,
    a.planning_revision, current_recipe.version, mapped.recipe_id, mapped.recipe_version,
    case
      when s.execution_id is not null or a.result_revision > 0 then 'started'
      when s.status <> 'planned' then 'not_pending'
      when exists (select 1 from trainer_private.assignment_variants v where v.assignment_id=a.scheduled_id)
        then 'adapted'
      when mapped.matches <> 1 or not mapped.available or original_position.matches <> 1
        or original_phase.matches <> 1 or mapped_phase.matches <> 1
        or current_recipe.family_id is distinct from original_recipe.family_id then 'uncertain'
      when mapped.recipe_id = s.template_id then 'unchanged'
      when mapped.recipe_version <= current_recipe.version then 'uncertain'
      else 'eligible'
    end
  from trainer_private.programs target
  join trainer_private.programs origin on origin.family_id=target.family_id and origin.version<target.version
  join trainer_private.program_deliveries d on d.program_id=origin.id and d.trainer_id=target.trainer_id
  join public.trainer_assignments a on a.program_delivery_id=d.id and a.trainer_id=d.trainer_id
  join public.trainer_client_relations r on r.id=a.relation_id and r.id=d.relation_id
    and r.trainer_id=a.trainer_id and r.client_id=a.client_id and r.ended_at is null
  join public.trainer_clients c on c.trainer_id=a.trainer_id and c.client_id=a.client_id
  join public.scheduled_workouts s on s.id=a.scheduled_id and s.user_id=a.client_id and s.source='coach'
  join public.workout_templates current_recipe on current_recipe.id=s.template_id
  left join trainer_private.assignment_origins original on original.assignment_id=a.scheduled_id
  left join public.workout_templates original_recipe on original_recipe.id=original.template_id
  cross join lateral (
    select origin.content->'phases'->a.program_phase_index->>'name' as name
  ) phase
  cross join lateral (
    select count(*) as matches
    from jsonb_array_elements(origin.content->'phases') f(value)
    where f.value->>'name'=phase.name
  ) original_phase
  cross join lateral (
    select count(*) as matches, min(f.ordinality-1) as phase_index
    from jsonb_array_elements(target.content->'phases') with ordinality f(value, ordinality)
    where f.value->>'name'=phase.name
  ) mapped_phase
  cross join lateral (
    select count(*) as matches
    from trainer_private.program_sessions ps
    join public.workout_templates recipe on recipe.id=ps.template_id
    where ps.program_id=origin.id and ps.phase_index=a.program_phase_index
      and recipe.family_id=original_recipe.family_id
  ) original_position
  cross join lateral (
    select count(*) as matches, (array_agg(recipe.id))[1] as recipe_id,
      (array_agg(recipe.version))[1] as recipe_version,
      bool_and(recipe.owner_user_id=target.trainer_id and recipe.origin='coach'
        and recipe.trashed_at is null) as available
    from trainer_private.program_sessions ps
    join public.workout_templates recipe on recipe.id=ps.template_id
    where ps.program_id=target.id and ps.phase_index=mapped_phase.phase_index
      and recipe.family_id=original_recipe.family_id
  ) mapped
  where target.id=p_program_id and target.trainer_id=auth.uid()
    and target.status='published' and target.trashed_at is null
    and (p_ids is null or a.scheduled_id=any(p_ids));
$$;

create function trainer_private.preview_program_updates(p_program_id uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
begin
  if not trainer_private.has_professional_read_access() then raise insufficient_privilege; end if;
  if not exists (
    select 1 from trainer_private.programs p where p.id=p_program_id and p.trainer_id=auth.uid()
      and p.status='published' and p.trashed_at is null
  ) then raise insufficient_privilege; end if;
  return coalesce((
    select jsonb_agg(to_jsonb(c) order by c.client_name, c.client_id, c.scheduled_date, c.id)
    from trainer_private.program_update_candidates(p_program_id) c
  ), '[]'::jsonb);
end $$;

create function trainer_private.apply_program_updates(
  p_operation_id uuid, p_program_id uuid, p_selection jsonb
) returns jsonb language plpgsql security definer set search_path='' as $$
declare
  owner_id uuid := auth.uid();
  selected_ids uuid[];
  member uuid;
  receipt trainer_private.program_update_receipts;
  payload jsonb;
  result jsonb;
begin
  if not trainer_private.has_trainer_mfa() then raise insufficient_privilege; end if;
  if p_operation_id is null or p_program_id is null
    or jsonb_typeof(p_selection) is distinct from 'array' then raise invalid_parameter_value; end if;
  select array_agg(x.id order by x.id) into selected_ids
  from jsonb_to_recordset(p_selection) x(id uuid, revision bigint, template_id uuid);
  if selected_ids is null or array_position(selected_ids,null) is not null
    or cardinality(selected_ids)<>(select count(distinct id) from unnest(selected_ids) u(id))
    or exists (select 1 from jsonb_to_recordset(p_selection) x(revision bigint, template_id uuid)
      where x.revision is null or x.revision<0 or x.template_id is null) then raise invalid_parameter_value; end if;
  payload:=jsonb_build_object('program_id',p_program_id,'selection',p_selection);

  -- Mismo orden que la planificación de grupos y el inicio de una sesión.
  for member in
    select distinct a.client_id from public.trainer_assignments a
    where a.trainer_id=owner_id and a.scheduled_id=any(selected_ids) order by a.client_id
  loop
    perform pg_advisory_xact_lock(hashtextextended('trainer-client:'||member::text,0));
  end loop;
  perform 1 from public.profiles where id=owner_id for key share;
  perform trainer_private.require_authoring_access();
  select * into receipt from trainer_private.program_update_receipts w
  where w.trainer_id=owner_id and w.operation_id=p_operation_id;
  if found then
    if receipt.request is distinct from payload then raise invalid_parameter_value; end if;
    return receipt.result;
  end if;
  if not exists (
    select 1 from trainer_private.programs p where p.id=p_program_id and p.trainer_id=owner_id
      and p.status='published' and p.trashed_at is null
  ) then raise insufficient_privilege; end if;

  -- El ejecutor toma la cita antes de actualizar la asignación. Volver a
  -- evaluar bajo ese bloqueo protege también una ejecución recién iniciada.
  perform 1 from public.scheduled_workouts s join public.trainer_assignments a on a.scheduled_id=s.id
    where a.trainer_id=owner_id and s.id=any(selected_ids) order by s.user_id,s.id for update of s;
  perform 1 from public.trainer_assignments a
    where a.trainer_id=owner_id and a.scheduled_id=any(selected_ids)
    order by a.client_id,a.scheduled_id for update;

  with eligible as (
    select c.id,c.template_id
    from trainer_private.program_update_candidates(p_program_id,selected_ids) c
    join jsonb_to_recordset(p_selection) x(id uuid, revision bigint, template_id uuid)
      on x.id=c.id and x.revision=c.revision and x.template_id=c.template_id
    where c.reason='eligible'
  ), changed as (
    update public.scheduled_workouts s set template_id=t.id,template_name=t.name,
      template_version=t.version,estimated_duration_minutes=t.estimated_duration_minutes
    from eligible e join public.workout_templates t on t.id=e.template_id
    where s.id=e.id and s.status='planned' and s.execution_id is null
    returning s.id
  ), revised as (
    update public.trainer_assignments a set planning_revision=a.planning_revision+1
    from changed c where a.scheduled_id=c.id returning a.scheduled_id
  )
  select jsonb_build_object('updated',count(*),'skipped',cardinality(selected_ids)-count(*))
  into result from revised;
  if (result->>'updated')::integer>0 then
    update public.trainer_access set membership_version=membership_version+1 where trainer_id=owner_id;
  end if;
  insert into trainer_private.program_update_receipts values(owner_id,p_operation_id,payload,result);
  return result;
end $$;

create function public.preview_trainer_program_updates(p_program_id uuid)
returns jsonb language sql stable security invoker set search_path='' as $$
  select trainer_private.preview_program_updates(p_program_id);
$$;
create function public.apply_trainer_program_updates(p_operation_id uuid,p_program_id uuid,p_selection jsonb)
returns jsonb language sql security invoker set search_path='' as $$
  select trainer_private.apply_program_updates(p_operation_id,p_program_id,p_selection);
$$;

revoke all on function trainer_private.program_update_candidates(uuid,uuid[]),
  trainer_private.preview_program_updates(uuid), trainer_private.apply_program_updates(uuid,uuid,jsonb),
  public.preview_trainer_program_updates(uuid), public.apply_trainer_program_updates(uuid,uuid,jsonb)
  from public,anon,authenticated;
grant execute on function trainer_private.preview_program_updates(uuid),
  trainer_private.apply_program_updates(uuid,uuid,jsonb), public.preview_trainer_program_updates(uuid),
  public.apply_trainer_program_updates(uuid,uuid,jsonb) to authenticated;

commit;
