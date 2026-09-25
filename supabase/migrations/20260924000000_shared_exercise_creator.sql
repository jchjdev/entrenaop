-- Unifica el contrato editorial de ejercicios y mantiene la autoridad de cada
-- contexto en funciones separadas: usuario privado frente a catálogo oficial.

begin;

create or replace function public.normalize_exercise_draft(
  p_name text,
  p_description text default null,
  p_video_url text default null,
  p_muscle_groups text[] default '{}',
  p_equipment text[] default '{}',
  p_difficulty text default 'inicial',
  p_exercise_type text default 'repeticiones'
)
returns table (
  normalized_name text,
  normalized_description text,
  normalized_video_url text,
  normalized_muscle_groups text[],
  normalized_equipment text[],
  normalized_difficulty text,
  normalized_exercise_type text
)
language plpgsql
immutable
set search_path = ''
as $$
declare
  clean_name text := btrim(coalesce(p_name, ''));
  clean_description text := nullif(btrim(p_description), '');
  clean_video_url text := nullif(btrim(p_video_url), '');
  clean_muscle_groups text[];
  clean_equipment text[];
begin
  select coalesce(array_agg(value order by value), '{}')
  into clean_muscle_groups
  from (
    select distinct lower(btrim(item)) as value
    from unnest(coalesce(p_muscle_groups, '{}')) as item
    where btrim(item) <> ''
  ) as normalized;

  select coalesce(array_agg(value order by value), '{}')
  into clean_equipment
  from (
    select distinct lower(btrim(item)) as value
    from unnest(coalesce(p_equipment, '{}')) as item
    where btrim(item) <> ''
  ) as normalized;

  if char_length(clean_name) not between 2 and 80 then
    raise exception 'Exercise name must contain between 2 and 80 characters'
      using errcode = '22023';
  end if;
  if char_length(coalesce(clean_description, '')) > 500 then
    raise exception 'Exercise description is too long' using errcode = '22023';
  end if;
  if char_length(coalesce(clean_video_url, '')) > 500
    or (clean_video_url is not null and clean_video_url !~ '^https://[^[:space:]]+$') then
    raise exception 'Exercise video must be a valid HTTPS URL'
      using errcode = '22023';
  end if;
  if cardinality(clean_muscle_groups) not between 1 and 10
    or exists (
      select 1 from unnest(clean_muscle_groups) as item
      where char_length(item) > 40
    ) then
    raise exception 'Exercise muscle groups are invalid' using errcode = '22023';
  end if;
  if cardinality(clean_equipment) > 10
    or exists (
      select 1 from unnest(clean_equipment) as item
      where char_length(item) > 40
    ) then
    raise exception 'Exercise equipment is invalid' using errcode = '22023';
  end if;
  if coalesce(p_difficulty, '') not in ('inicial', 'intermedio', 'avanzado') then
    raise exception 'Exercise difficulty is invalid' using errcode = '22023';
  end if;
  if coalesce(p_exercise_type, '') not in ('repeticiones', 'duración') then
    raise exception 'Exercise type is invalid' using errcode = '22023';
  end if;

  return query select clean_name, clean_description, clean_video_url,
    clean_muscle_groups, clean_equipment, p_difficulty, p_exercise_type;
end;
$$;

revoke all on function public.normalize_exercise_draft(
  text, text, text, text[], text[], text, text
) from public, anon, authenticated;

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
  normalized record;
begin
  if current_user_id is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  select * into normalized from public.normalize_exercise_draft(
    p_name, p_description, p_video_url, p_muscle_groups, p_equipment,
    p_difficulty, p_exercise_type
  );

  insert into public.exercises (
    name, description, video_url, muscle_groups, equipment, difficulty,
    exercise_type, is_public, created_by, origin
  ) values (
    normalized.normalized_name,
    normalized.normalized_description,
    normalized.normalized_video_url,
    normalized.normalized_muscle_groups,
    normalized.normalized_equipment,
    normalized.normalized_difficulty,
    normalized.normalized_exercise_type,
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

create or replace function public.create_admin_exercise(
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
  exercise_id uuid;
  normalized record;
begin
  if (select auth.uid()) is null or not (select public.is_admin()) then
    raise exception 'Administrative permission required' using errcode = '42501';
  end if;

  select * into normalized from public.normalize_exercise_draft(
    p_name, p_description, p_video_url, p_muscle_groups, p_equipment,
    p_difficulty, p_exercise_type
  );

  insert into public.exercises (
    name, description, video_url, muscle_groups, equipment, difficulty,
    exercise_type, is_public, created_by, origin
  ) values (
    normalized.normalized_name,
    normalized.normalized_description,
    normalized.normalized_video_url,
    normalized.normalized_muscle_groups,
    normalized.normalized_equipment,
    normalized.normalized_difficulty,
    normalized.normalized_exercise_type,
    true,
    null,
    'system'
  ) returning id into exercise_id;

  return exercise_id;
end;
$$;

create or replace function public.update_admin_exercise(
  p_exercise_id uuid,
  p_name text,
  p_description text default null,
  p_video_url text default null,
  p_muscle_groups text[] default '{}',
  p_equipment text[] default '{}',
  p_difficulty text default 'inicial',
  p_exercise_type text default 'repeticiones'
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  normalized record;
begin
  if (select auth.uid()) is null or not (select public.is_admin()) then
    raise exception 'Administrative permission required' using errcode = '42501';
  end if;

  select * into normalized from public.normalize_exercise_draft(
    p_name, p_description, p_video_url, p_muscle_groups, p_equipment,
    p_difficulty, p_exercise_type
  );

  update public.exercises
  set name = normalized.normalized_name,
      description = normalized.normalized_description,
      video_url = normalized.normalized_video_url,
      muscle_groups = normalized.normalized_muscle_groups,
      equipment = normalized.normalized_equipment,
      difficulty = normalized.normalized_difficulty,
      exercise_type = normalized.normalized_exercise_type,
      is_public = true,
      created_by = null,
      origin = 'system'
  where id = p_exercise_id and origin = 'system' and created_by is null;

  if not found then
    raise exception 'Official exercise not found' using errcode = '22023';
  end if;
end;
$$;

revoke all on function public.create_admin_exercise(
  text, text, text, text[], text[], text, text
) from public, anon;
grant execute on function public.create_admin_exercise(
  text, text, text, text[], text[], text, text
) to authenticated;

revoke all on function public.update_admin_exercise(
  uuid, text, text, text, text[], text[], text, text
) from public, anon;
grant execute on function public.update_admin_exercise(
  uuid, text, text, text, text[], text[], text, text
) to authenticated;

commit;
