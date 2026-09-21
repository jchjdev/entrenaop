-- Acciones no destructivas sobre sesiones personales.

begin;

create or replace function public.archive_personal_workout_template(
  p_template_id uuid
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_user_id uuid := auth.uid();
begin
  if current_user_id is null then
    raise exception 'Authentication required';
  end if;

  update public.workout_templates as template
  set status = 'archived'
  where template.id = p_template_id
    and template.owner_user_id = current_user_id
    and template.origin = 'user'
    and template.status <> 'archived';

  if not found then
    raise exception 'Personal workout is not accessible';
  end if;
end;
$$;

create or replace function public.duplicate_personal_workout_template(
  p_template_id uuid
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_user_id uuid := auth.uid();
  source_template record;
  source_block record;
  source_item record;
  v_template_id uuid;
  v_block_id uuid;
  v_item_id uuid;
begin
  if current_user_id is null then
    raise exception 'Authentication required';
  end if;

  select template.*
  into source_template
  from public.workout_templates as template
  where template.id = p_template_id
    and template.owner_user_id = current_user_id
    and template.origin = 'user'
    and template.status <> 'archived';

  if not found then
    raise exception 'Personal workout is not accessible';
  end if;

  insert into public.workout_templates (
    name,
    description,
    origin,
    owner_user_id,
    visibility,
    status,
    estimated_duration_minutes,
    version
  )
  values (
    left(source_template.name, 72) || ' (copia)',
    source_template.description,
    'user',
    current_user_id,
    'private',
    'published',
    source_template.estimated_duration_minutes,
    1
  )
  returning id into v_template_id;

  for source_block in
    select block.*
    from public.workout_blocks as block
    where block.template_id = p_template_id
    order by block.order_index
  loop
    insert into public.workout_blocks (
      template_id,
      order_index,
      name,
      format,
      rounds,
      time_cap_seconds,
      rest_after_seconds
    )
    values (
      v_template_id,
      source_block.order_index,
      source_block.name,
      source_block.format,
      source_block.rounds,
      source_block.time_cap_seconds,
      source_block.rest_after_seconds
    )
    returning id into v_block_id;

    for source_item in
      select item.*
      from public.workout_items as item
      where item.block_id = source_block.id
      order by item.order_index
    loop
      insert into public.workout_items (
        block_id,
        exercise_id,
        order_index,
        notes
      )
      values (
        v_block_id,
        source_item.exercise_id,
        source_item.order_index,
        source_item.notes
      )
      returning id into v_item_id;

      insert into public.workout_sets (
        item_id,
        order_index,
        target_reps,
        target_duration_seconds,
        target_distance_meters,
        target_load_kg,
        target_rpe,
        target_rir,
        rest_after_seconds
      )
      select
        v_item_id,
        prescribed_set.order_index,
        prescribed_set.target_reps,
        prescribed_set.target_duration_seconds,
        prescribed_set.target_distance_meters,
        prescribed_set.target_load_kg,
        prescribed_set.target_rpe,
        prescribed_set.target_rir,
        prescribed_set.rest_after_seconds
      from public.workout_sets as prescribed_set
      where prescribed_set.item_id = source_item.id
      order by prescribed_set.order_index;
    end loop;
  end loop;

  return v_template_id;
end;
$$;

revoke all on function public.archive_personal_workout_template(uuid)
from public, anon;
revoke all on function public.duplicate_personal_workout_template(uuid)
from public, anon;
grant execute on function public.archive_personal_workout_template(uuid)
to authenticated;
grant execute on function public.duplicate_personal_workout_template(uuid)
to authenticated;

commit;
