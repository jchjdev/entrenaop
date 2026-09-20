-- Conserva la explicación y el vídeo usados al iniciar cada sesión. Así una
-- edición posterior del catálogo no cambia retrospectivamente el historial.

begin;

alter table public.workout_execution_sets
  add column exercise_description text,
  add column exercise_video_url text;

create or replace function public.start_workout_execution(p_template_id uuid)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_user_id uuid := auth.uid();
  selected_template record;
  execution_id uuid;
begin
  if current_user_id is null then
    raise exception 'Authentication required';
  end if;

  select template.id, template.name, template.version
  into selected_template
  from public.workout_templates as template
  where template.id = p_template_id
    and (
      (template.visibility = 'public' and template.status = 'published')
      or template.owner_user_id = current_user_id
      or public.is_admin()
    );

  if not found then
    raise exception 'Workout template is not accessible';
  end if;

  select execution.id
  into execution_id
  from public.workout_executions as execution
  where execution.user_id = current_user_id
    and execution.template_id = p_template_id
    and execution.status = 'in_progress';

  if execution_id is not null then
    return execution_id;
  end if;

  insert into public.workout_executions (
    user_id,
    template_id,
    template_name,
    template_version
  ) values (
    current_user_id,
    selected_template.id,
    selected_template.name,
    selected_template.version
  )
  returning id into execution_id;

  insert into public.workout_execution_sets (
    execution_id,
    source_set_id,
    block_order,
    block_name,
    item_order,
    exercise_id,
    exercise_name,
    exercise_description,
    exercise_video_url,
    set_order,
    target_reps,
    target_duration_seconds,
    target_distance_meters,
    target_load_kg,
    target_rpe,
    target_rir,
    rest_after_seconds
  )
  select
    execution_id,
    prescribed_set.id,
    block.order_index,
    block.name,
    item.order_index,
    exercise.id,
    exercise.name,
    exercise.description,
    exercise.video_url,
    prescribed_set.order_index,
    prescribed_set.target_reps,
    prescribed_set.target_duration_seconds,
    prescribed_set.target_distance_meters,
    prescribed_set.target_load_kg,
    prescribed_set.target_rpe,
    prescribed_set.target_rir,
    prescribed_set.rest_after_seconds
  from public.workout_blocks as block
  join public.workout_items as item on item.block_id = block.id
  join public.workout_sets as prescribed_set on prescribed_set.item_id = item.id
  join public.exercises as exercise on exercise.id = item.exercise_id
  where block.template_id = p_template_id;

  if not found then
    raise exception 'Workout template has no prescribed sets';
  end if;

  return execution_id;
end;
$$;

commit;
