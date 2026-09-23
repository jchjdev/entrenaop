-- Las sesiones oficiales nacen privadas y en borrador. El creador compartido
-- valida y guarda los bloques; esta transacción cambia la titularidad y las
-- vincula al programa sin exponer nunca un estado intermedio al alumno.
begin;

create table public.program_workout_templates (
  program_id text not null
    references public.preparation_programs (id) on delete cascade,
  template_id uuid primary key
    references public.workout_templates (id) on delete cascade,
  created_at timestamptz not null default now()
);

create index program_workout_templates_program_idx
on public.program_workout_templates (program_id, created_at desc);

alter table public.program_workout_templates enable row level security;
revoke all on public.program_workout_templates from anon, authenticated;
grant select on public.program_workout_templates to authenticated;

create policy program_workout_templates_admin_select
on public.program_workout_templates for select to authenticated
using ((select public.is_admin()));

create function public.create_admin_workout_draft(
  p_program_id text,
  p_payload jsonb
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  new_template_id uuid;
begin
  if (select auth.uid()) is null or not (select public.is_admin()) then
    raise exception 'No tienes permiso para crear sesiones oficiales.'
      using errcode = '42501';
  end if;

  if not exists (
    select 1 from public.preparation_programs
    where id = p_program_id
  ) then
    raise exception 'El programa no existe.'
      using errcode = '22023';
  end if;

  new_template_id := public.create_personal_workout_template(p_payload);

  -- Un borrador oficial nunca debe depender de ejercicios privados de un
  -- administrador: el alumno no podría leerlos al publicarlo.
  if exists (
    select 1
    from public.workout_blocks as block
    join public.workout_items as item on item.block_id = block.id
    join public.exercises as exercise on exercise.id = item.exercise_id
    where block.template_id = new_template_id
      and exercise.is_public is distinct from true
  ) then
    raise exception 'Una sesión oficial solo puede usar ejercicios públicos.'
      using errcode = '22023';
  end if;

  update public.workout_templates
  set origin = 'system',
      owner_user_id = null,
      visibility = 'private',
      status = 'draft',
      updated_at = now()
  where id = new_template_id;

  insert into public.program_workout_templates (program_id, template_id)
  values (p_program_id, new_template_id);

  return new_template_id;
end;
$$;

revoke all on function public.create_admin_workout_draft(text, jsonb)
from public, anon;
grant execute on function public.create_admin_workout_draft(text, jsonb)
to authenticated;

commit;
