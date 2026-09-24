-- Las fotografías viven en Storage. PostgreSQL conserva únicamente una ruta
-- estable y nunca los bytes ni una URL firmada temporal.

begin;

alter table public.exercises
add column image_path text;

alter table public.exercises
add constraint exercises_image_path_check
check (
  image_path is null
  or (
    char_length(image_path) <= 300
    and image_path ~ '^[a-zA-Z0-9_/-]+\.(jpg|jpeg)$'
  )
);

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'exercise-images-public',
  'exercise-images-public',
  true,
  524288,
  array['image/jpeg']
)
on conflict (id) do update
set public = excluded.public,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'exercise-images-private',
  'exercise-images-private',
  false,
  524288,
  array['image/jpeg']
)
on conflict (id) do update
set public = excluded.public,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

create policy exercise_images_public_admin_insert
on storage.objects for insert to authenticated
with check (
  bucket_id = 'exercise-images-public'
  and (storage.foldername(name))[1] = 'official'
  and (select public.is_admin())
);

create policy exercise_images_public_admin_delete
on storage.objects for delete to authenticated
using (
  bucket_id = 'exercise-images-public'
  and (select public.is_admin())
);

create policy exercise_images_private_owner_select
on storage.objects for select to authenticated
using (
  bucket_id = 'exercise-images-private'
  and (storage.foldername(name))[1] = (select auth.uid())::text
);

create policy exercise_images_private_owner_insert
on storage.objects for insert to authenticated
with check (
  bucket_id = 'exercise-images-private'
  and (storage.foldername(name))[1] = (select auth.uid())::text
);

create policy exercise_images_private_owner_delete
on storage.objects for delete to authenticated
using (
  bucket_id = 'exercise-images-private'
  and (storage.foldername(name))[1] = (select auth.uid())::text
);

create or replace function public.set_personal_exercise_image(
  p_exercise_id uuid,
  p_image_path text
)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_user_id uuid := auth.uid();
  previous_path text;
begin
  if current_user_id is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;
  if p_image_path is null
    or split_part(p_image_path, '/', 1) <> current_user_id::text
    or split_part(p_image_path, '/', 2) <> p_exercise_id::text
    or p_image_path !~ '/[0-9]+\.jpg$' then
    raise exception 'Invalid personal exercise image path' using errcode = '22023';
  end if;

  select image_path into previous_path
  from public.exercises
  where id = p_exercise_id
    and created_by = current_user_id
    and origin = 'user'
    and not is_public
  for update;

  if not found then
    raise exception 'Personal exercise not found' using errcode = '22023';
  end if;

  update public.exercises
  set image_path = p_image_path
  where id = p_exercise_id;
  return previous_path;
end;
$$;

revoke all on function public.set_personal_exercise_image(uuid, text)
from public, anon;
grant execute on function public.set_personal_exercise_image(uuid, text)
to authenticated;

create or replace function public.set_admin_exercise_image(
  p_exercise_id uuid,
  p_image_path text
)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  previous_path text;
begin
  if (select auth.uid()) is null or not (select public.is_admin()) then
    raise exception 'Administrative permission required' using errcode = '42501';
  end if;
  if p_image_path is not null and (
    split_part(p_image_path, '/', 1) <> 'official'
    or split_part(p_image_path, '/', 2) <> p_exercise_id::text
    or p_image_path !~ '/[0-9]+\.jpg$'
  ) then
    raise exception 'Invalid official exercise image path' using errcode = '22023';
  end if;

  select image_path into previous_path
  from public.exercises
  where id = p_exercise_id and origin = 'system' and created_by is null
  for update;

  if not found then
    raise exception 'Official exercise not found' using errcode = '22023';
  end if;

  update public.exercises
  set image_path = p_image_path
  where id = p_exercise_id;
  return previous_path;
end;
$$;

revoke all on function public.set_admin_exercise_image(uuid, text)
from public, anon;
grant execute on function public.set_admin_exercise_image(uuid, text)
to authenticated;

commit;
