-- Los ejercicios propios nacen siempre privados y ligados al usuario autenticado.

begin;

create or replace function public.create_personal_exercise(
  p_name text,
  p_description text default null,
  p_video_url text default null,
  p_muscle_groups text[] default '{}',
  p_equipment text[] default '{}',
  p_difficulty text default 'inicial',
  p_exercise_type text default 'repeticiones'
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_user_id uuid := auth.uid();
  exercise_id uuid;
  normalized_name text := btrim(coalesce(p_name, ''));
  normalized_description text := nullif(btrim(p_description), '');
  normalized_video_url text := nullif(btrim(p_video_url), '');
begin
  if current_user_id is null then
    raise exception 'Authentication required';
  end if;
  if char_length(normalized_name) not between 2 and 80 then
    raise exception 'Exercise name must contain between 2 and 80 characters';
  end if;
  if char_length(coalesce(normalized_description, '')) > 500 then
    raise exception 'Exercise description is too long';
  end if;
  if char_length(coalesce(normalized_video_url, '')) > 500
    or (
      normalized_video_url is not null
      and normalized_video_url !~ '^https://[^[:space:]]+$'
    ) then
    raise exception 'Exercise video must be a valid HTTPS URL';
  end if;
  if coalesce(cardinality(p_muscle_groups), 0) not between 1 and 10
    or exists (
      select 1 from unnest(p_muscle_groups) as muscle(value)
      where btrim(muscle.value) = '' or char_length(muscle.value) > 40
    ) then
    raise exception 'Exercise muscle groups are invalid';
  end if;
  if coalesce(cardinality(p_equipment), 0) > 10
    or exists (
      select 1 from unnest(p_equipment) as item(value)
      where btrim(item.value) = '' or char_length(item.value) > 40
    ) then
    raise exception 'Exercise equipment is invalid';
  end if;
  if coalesce(p_difficulty, '') not in ('inicial', 'intermedio', 'avanzado') then
    raise exception 'Exercise difficulty is invalid';
  end if;
  if coalesce(p_exercise_type, '') not in ('repeticiones', 'duración') then
    raise exception 'Exercise type is invalid';
  end if;

  insert into public.exercises (
    name,
    description,
    video_url,
    muscle_groups,
    equipment,
    difficulty,
    exercise_type,
    is_public,
    created_by,
    origin
  ) values (
    normalized_name,
    normalized_description,
    normalized_video_url,
    array(
      select distinct lower(btrim(muscle.value))
      from unnest(p_muscle_groups) as muscle(value)
    ),
    array(
      select distinct lower(btrim(item.value))
      from unnest(p_equipment) as item(value)
    ),
    p_difficulty,
    p_exercise_type,
    false,
    current_user_id,
    'user'
  ) returning id into exercise_id;

  return exercise_id;
end;
$$;

revoke all on function public.create_personal_exercise(
  text, text, text, text[], text[], text, text
) from public, anon;
grant execute on function public.create_personal_exercise(
  text, text, text, text[], text[], text, text
) to authenticated;

commit;
