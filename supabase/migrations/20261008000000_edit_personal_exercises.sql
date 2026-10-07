-- Edición del contenido privado: conserva identidad, permisos e historial.
begin;

create function public.update_personal_exercise(
  p_exercise_id uuid, p_name text,
  p_description text default null, p_video_url text default null,
  p_muscle_groups text[] default '{}', p_equipment text[] default '{}',
  p_difficulty text default 'inicial', p_exercise_type text default 'repeticiones',
  p_replace_image boolean default false, p_image_path text default null
) returns void
language plpgsql security definer set search_path = '' as $$
declare
  current_user_id uuid := auth.uid();
  normalized record;
begin
  if current_user_id is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;
  perform 1 from public.exercises
  where id = p_exercise_id and origin = 'user' and not is_public
    and created_by = current_user_id for update;
  if not found then
    raise exception 'Personal exercise not found' using errcode = '42501';
  end if;
  select * into normalized from public.normalize_exercise_draft(
    p_name, p_description, p_video_url, p_muscle_groups, p_equipment,
    p_difficulty, p_exercise_type
  );
  if p_replace_image is null then
    raise exception 'Image action required' using errcode = '22023';
  end if;
  if p_replace_image and p_image_path is not null and (
    split_part(p_image_path, '/', 1) <> current_user_id::text
    or split_part(p_image_path, '/', 2) <> p_exercise_id::text
    or p_image_path !~ '/[0-9]+\.jpg$'
  ) then
    raise exception 'Invalid personal exercise image path' using errcode = '22023';
  end if;
  if p_replace_image and p_image_path is not null and not exists (
    select 1 from storage.objects
    where bucket_id = 'exercise-images-private' and name = p_image_path
  ) then
    raise exception 'Personal image must be uploaded first' using errcode = '22023';
  end if;
  update public.exercises set
    name = normalized.normalized_name,
    description = normalized.normalized_description,
    video_url = normalized.normalized_video_url,
    muscle_groups = normalized.normalized_muscle_groups,
    equipment = normalized.normalized_equipment,
    difficulty = normalized.normalized_difficulty,
    exercise_type = normalized.normalized_exercise_type,
    image_path = case when p_replace_image then p_image_path else image_path end
  where id = p_exercise_id;
end;
$$;
revoke all on function public.update_personal_exercise(
  uuid, text, text, text, text[], text[], text, text, boolean, text
) from public, anon;
grant execute on function public.update_personal_exercise(
  uuid, text, text, text, text[], text[], text, text, boolean, text
) to authenticated;

commit;
