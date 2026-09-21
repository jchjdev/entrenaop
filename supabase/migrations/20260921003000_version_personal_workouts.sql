-- Las ediciones crean una revisión nueva en vez de reescribir una plantilla
-- que puede estar referenciada por ejecuciones históricas.

begin;

alter table public.workout_templates
  add column family_id uuid not null default gen_random_uuid(),
  add column previous_version_id uuid
    references public.workout_templates (id) on delete restrict;

alter table public.workout_templates
  add constraint workout_templates_family_version_unique
    unique (family_id, version),
  add constraint workout_templates_previous_not_self
    check (previous_version_id is null or previous_version_id <> id);

create index workout_templates_family_idx
  on public.workout_templates (family_id, version desc);

create or replace function public.revise_personal_workout_template(
  p_template_id uuid,
  p_payload jsonb
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_user_id uuid := auth.uid();
  source_template record;
  v_template_id uuid;
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
    and template.status <> 'archived'
  for update;

  if not found then
    raise exception 'Personal workout is not accessible';
  end if;

  v_template_id := public.create_personal_workout_template(p_payload);

  update public.workout_templates as new_template
  set
    family_id = source_template.family_id,
    previous_version_id = source_template.id,
    version = source_template.version + 1
  where new_template.id = v_template_id;

  update public.workout_templates as previous_template
  set status = 'archived'
  where previous_template.id = source_template.id;

  return v_template_id;
end;
$$;

revoke all on function public.revise_personal_workout_template(uuid, jsonb)
from public, anon;
grant execute on function public.revise_personal_workout_template(uuid, jsonb)
to authenticated;

commit;
