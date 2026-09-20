-- Núcleo versionable de plantillas de entrenamiento.
--
-- Las tablas heredadas routines/routine_exercises no expresan bloques ni
-- series variables. Se conservan temporalmente, pero el nuevo recorrido usa
-- esta jerarquía: plantilla -> bloques -> ejercicios -> series prescritas.

begin;

alter table public.exercises
  add column origin text not null default 'user';

alter table public.exercises
  alter column created_by drop not null;

alter table public.exercises
  add constraint exercises_origin_check
    check (origin in ('system', 'user')),
  add constraint exercises_origin_owner_check
    check (
      (origin = 'system' and created_by is null)
      or (origin = 'user' and created_by is not null)
    ),
  add constraint exercises_name_not_blank
    check (btrim(name) <> '');

drop policy if exists exercises_insert_own on public.exercises;
create policy exercises_insert_own
on public.exercises
for insert
to authenticated
with check (
  (
    origin = 'user'
    and created_by = (select auth.uid())
    and is_public is false
  )
  or (
    (select public.is_admin())
    and (
      (origin = 'system' and created_by is null)
      or (origin = 'user' and created_by is not null)
    )
  )
);

drop policy if exists exercises_update_own on public.exercises;
create policy exercises_update_own
on public.exercises
for update
to authenticated
using (created_by = (select auth.uid()) or (select public.is_admin()))
with check (
  (
    origin = 'user'
    and created_by = (select auth.uid())
    and is_public is false
  )
  or (
    (select public.is_admin())
    and (
      (origin = 'system' and created_by is null)
      or (origin = 'user' and created_by is not null)
    )
  )
);

create table public.workout_templates (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  description text,
  origin text not null,
  owner_user_id uuid references public.profiles (id) on delete cascade,
  visibility text not null default 'private',
  status text not null default 'draft',
  estimated_duration_minutes integer,
  version integer not null default 1,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint workout_templates_name_not_blank check (btrim(name) <> ''),
  constraint workout_templates_origin_check
    check (origin in ('system', 'user', 'coach', 'algorithm')),
  constraint workout_templates_owner_check
    check (
      (origin = 'system' and owner_user_id is null)
      or (origin <> 'system' and owner_user_id is not null)
    ),
  constraint workout_templates_visibility_check
    check (visibility in ('private', 'public')),
  constraint workout_templates_status_check
    check (status in ('draft', 'published', 'archived')),
  constraint workout_templates_publication_check
    check (visibility <> 'public' or status = 'published'),
  constraint workout_templates_duration_positive
    check (
      estimated_duration_minutes is null
      or estimated_duration_minutes > 0
    ),
  constraint workout_templates_version_positive check (version > 0)
);

create table public.workout_blocks (
  id uuid primary key default gen_random_uuid(),
  template_id uuid not null
    references public.workout_templates (id) on delete cascade,
  order_index integer not null,
  name text not null,
  format text not null,
  rounds integer not null default 1,
  time_cap_seconds integer,
  rest_after_seconds integer not null default 0,
  constraint workout_blocks_order_nonnegative check (order_index >= 0),
  constraint workout_blocks_name_not_blank check (btrim(name) <> ''),
  constraint workout_blocks_format_check
    check (
      format in (
        'straight_sets',
        'circuit',
        'superset',
        'intervals',
        'emom',
        'amrap',
        'tabata',
        'warm_up',
        'cool_down'
      )
    ),
  constraint workout_blocks_rounds_positive check (rounds > 0),
  constraint workout_blocks_time_cap_positive
    check (time_cap_seconds is null or time_cap_seconds > 0),
  constraint workout_blocks_rest_nonnegative check (rest_after_seconds >= 0),
  constraint workout_blocks_template_order_unique
    unique (template_id, order_index)
);

create table public.workout_items (
  id uuid primary key default gen_random_uuid(),
  block_id uuid not null
    references public.workout_blocks (id) on delete cascade,
  exercise_id uuid not null
    references public.exercises (id) on delete restrict,
  order_index integer not null,
  notes text,
  constraint workout_items_order_nonnegative check (order_index >= 0),
  constraint workout_items_block_order_unique unique (block_id, order_index)
);

create table public.workout_sets (
  id uuid primary key default gen_random_uuid(),
  item_id uuid not null
    references public.workout_items (id) on delete cascade,
  order_index integer not null,
  target_reps integer,
  target_duration_seconds integer,
  target_distance_meters numeric,
  target_load_kg numeric,
  target_rpe numeric,
  target_rir numeric,
  rest_after_seconds integer not null default 0,
  constraint workout_sets_order_nonnegative check (order_index >= 0),
  constraint workout_sets_reps_positive
    check (target_reps is null or target_reps > 0),
  constraint workout_sets_duration_positive
    check (
      target_duration_seconds is null
      or target_duration_seconds > 0
    ),
  constraint workout_sets_distance_positive
    check (target_distance_meters is null or target_distance_meters > 0),
  constraint workout_sets_load_nonnegative
    check (target_load_kg is null or target_load_kg >= 0),
  constraint workout_sets_rpe_range
    check (target_rpe is null or target_rpe between 1 and 10),
  constraint workout_sets_rir_range
    check (target_rir is null or target_rir between 0 and 10),
  constraint workout_sets_rest_nonnegative check (rest_after_seconds >= 0),
  constraint workout_sets_has_target
    check (
      target_reps is not null
      or target_duration_seconds is not null
      or target_distance_meters is not null
    ),
  constraint workout_sets_item_order_unique unique (item_id, order_index)
);

create index workout_templates_owner_idx
  on public.workout_templates (owner_user_id, updated_at desc);
create index workout_blocks_template_idx
  on public.workout_blocks (template_id, order_index);
create index workout_items_block_idx
  on public.workout_items (block_id, order_index);
create index workout_items_exercise_idx
  on public.workout_items (exercise_id);
create index workout_sets_item_idx
  on public.workout_sets (item_id, order_index);

alter table public.workout_templates enable row level security;
alter table public.workout_blocks enable row level security;
alter table public.workout_items enable row level security;
alter table public.workout_sets enable row level security;

revoke all on table public.workout_templates from anon, authenticated;
revoke all on table public.workout_blocks from anon, authenticated;
revoke all on table public.workout_items from anon, authenticated;
revoke all on table public.workout_sets from anon, authenticated;

grant select on table public.workout_templates to anon, authenticated;
grant select on table public.workout_blocks to anon, authenticated;
grant select on table public.workout_items to anon, authenticated;
grant select on table public.workout_sets to anon, authenticated;
grant insert, update, delete on table public.workout_templates to authenticated;
grant insert, update, delete on table public.workout_blocks to authenticated;
grant insert, update, delete on table public.workout_items to authenticated;
grant insert, update, delete on table public.workout_sets to authenticated;

create policy workout_templates_select_public
on public.workout_templates
for select
to anon, authenticated
using (
  visibility = 'public' and status = 'published'
);

create policy workout_templates_select_owned_or_admin
on public.workout_templates
for select
to authenticated
using (
  owner_user_id = (select auth.uid())
  or (select public.is_admin())
);

create policy workout_templates_insert_owned
on public.workout_templates
for insert
to authenticated
with check (
  (
    origin = 'user'
    and owner_user_id = (select auth.uid())
    and visibility = 'private'
  )
  or (select public.is_admin())
);

create policy workout_templates_update_owned
on public.workout_templates
for update
to authenticated
using (owner_user_id = (select auth.uid()) or (select public.is_admin()))
with check (
  (
    origin = 'user'
    and owner_user_id = (select auth.uid())
    and visibility = 'private'
  )
  or (select public.is_admin())
);

create policy workout_templates_delete_owned
on public.workout_templates
for delete
to authenticated
using (owner_user_id = (select auth.uid()) or (select public.is_admin()));

-- Los hijos heredan lectura y escritura de la plantilla raíz. La política se
-- repite explícitamente por tabla para que RLS siga siendo la autoridad.
create policy workout_blocks_select_accessible
on public.workout_blocks
for select
to anon, authenticated
using (
  exists (
    select 1
    from public.workout_templates as template
    where template.id = workout_blocks.template_id
  )
);

create policy workout_blocks_write_owned
on public.workout_blocks
for all
to authenticated
using (
  exists (
    select 1
    from public.workout_templates as template
    where template.id = workout_blocks.template_id
      and (
        template.owner_user_id = (select auth.uid())
        or (select public.is_admin())
      )
  )
)
with check (
  exists (
    select 1
    from public.workout_templates as template
    where template.id = workout_blocks.template_id
      and (
        template.owner_user_id = (select auth.uid())
        or (select public.is_admin())
      )
  )
);

create policy workout_items_select_accessible
on public.workout_items
for select
to anon, authenticated
using (
  exists (
    select 1
    from public.workout_blocks as block
    where block.id = workout_items.block_id
  )
);

create policy workout_items_write_owned
on public.workout_items
for all
to authenticated
using (
  exists (
    select 1
    from public.workout_blocks as block
    join public.workout_templates as template
      on template.id = block.template_id
    where block.id = workout_items.block_id
      and (
        template.owner_user_id = (select auth.uid())
        or (select public.is_admin())
      )
  )
)
with check (
  exists (
    select 1
    from public.workout_blocks as block
    join public.workout_templates as template
      on template.id = block.template_id
    where block.id = workout_items.block_id
      and (
        template.owner_user_id = (select auth.uid())
        or (select public.is_admin())
      )
  )
);

create policy workout_sets_select_accessible
on public.workout_sets
for select
to anon, authenticated
using (
  exists (
    select 1
    from public.workout_items as item
    where item.id = workout_sets.item_id
  )
);

create policy workout_sets_write_owned
on public.workout_sets
for all
to authenticated
using (
  exists (
    select 1
    from public.workout_items as item
    join public.workout_blocks as block on block.id = item.block_id
    join public.workout_templates as template
      on template.id = block.template_id
    where item.id = workout_sets.item_id
      and (
        template.owner_user_id = (select auth.uid())
        or (select public.is_admin())
      )
  )
)
with check (
  exists (
    select 1
    from public.workout_items as item
    join public.workout_blocks as block on block.id = item.block_id
    join public.workout_templates as template
      on template.id = block.template_id
    where item.id = workout_sets.item_id
      and (
        template.owner_user_id = (select auth.uid())
        or (select public.is_admin())
      )
  )
);

create or replace function public.set_workout_template_updated_at()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

revoke all on function public.set_workout_template_updated_at()
from public, anon, authenticated;

create trigger set_workout_template_updated_at
before update on public.workout_templates
for each row execute function public.set_workout_template_updated_at();

-- Contenido mínimo real para validar lectura, representación y futura ejecución.
insert into public.exercises (
  id,
  name,
  description,
  muscle_groups,
  equipment,
  difficulty,
  exercise_type,
  is_public,
  created_by,
  origin
)
values
  (
    '20000000-0000-4000-8000-000000000001',
    'Flexiones',
    'Mantén el cuerpo alineado y controla tanto la bajada como la subida.',
    array['pecho', 'tríceps', 'core'],
    array['peso corporal'],
    'inicial',
    'repeticiones',
    true,
    null,
    'system'
  ),
  (
    '20000000-0000-4000-8000-000000000002',
    'Plancha frontal',
    'Mantén pelvis, tronco y cabeza alineados sin contener la respiración.',
    array['core'],
    array['peso corporal'],
    'inicial',
    'duración',
    true,
    null,
    'system'
  ),
  (
    '20000000-0000-4000-8000-000000000003',
    'Sentadilla con peso corporal',
    'Desciende con control manteniendo una posición estable de pies y rodillas.',
    array['cuádriceps', 'glúteos', 'core'],
    array['peso corporal'],
    'inicial',
    'repeticiones',
    true,
    null,
    'system'
  );

insert into public.workout_templates (
  id,
  name,
  description,
  origin,
  visibility,
  status,
  estimated_duration_minutes
)
values (
  '10000000-0000-4000-8000-000000000001',
  'Primera sesión · Fuerza base',
  'Sesión pública inicial para validar el motor de entrenamiento de EntrenaOP.',
  'system',
  'public',
  'published',
  20
);

insert into public.workout_blocks (
  id,
  template_id,
  order_index,
  name,
  format,
  rounds,
  rest_after_seconds
)
values
  (
    '30000000-0000-4000-8000-000000000001',
    '10000000-0000-4000-8000-000000000001',
    0,
    'Activación',
    'straight_sets',
    1,
    60
  ),
  (
    '30000000-0000-4000-8000-000000000002',
    '10000000-0000-4000-8000-000000000001',
    1,
    'Trabajo principal',
    'straight_sets',
    1,
    0
  );

insert into public.workout_items (
  id,
  block_id,
  exercise_id,
  order_index,
  notes
)
values
  (
    '40000000-0000-4000-8000-000000000001',
    '30000000-0000-4000-8000-000000000001',
    '20000000-0000-4000-8000-000000000003',
    0,
    'Movimiento controlado, sin buscar fatiga.'
  ),
  (
    '40000000-0000-4000-8000-000000000002',
    '30000000-0000-4000-8000-000000000002',
    '20000000-0000-4000-8000-000000000001',
    0,
    'Detén la serie si pierdes la alineación.'
  ),
  (
    '40000000-0000-4000-8000-000000000003',
    '30000000-0000-4000-8000-000000000002',
    '20000000-0000-4000-8000-000000000002',
    1,
    'Respira con normalidad durante toda la serie.'
  );

insert into public.workout_sets (
  id,
  item_id,
  order_index,
  target_reps,
  target_duration_seconds,
  target_rir,
  rest_after_seconds
)
values
  (
    '50000000-0000-4000-8000-000000000001',
    '40000000-0000-4000-8000-000000000001',
    0,
    10,
    null,
    4,
    45
  ),
  (
    '50000000-0000-4000-8000-000000000002',
    '40000000-0000-4000-8000-000000000001',
    1,
    10,
    null,
    4,
    0
  ),
  (
    '50000000-0000-4000-8000-000000000003',
    '40000000-0000-4000-8000-000000000002',
    0,
    8,
    null,
    3,
    60
  ),
  (
    '50000000-0000-4000-8000-000000000004',
    '40000000-0000-4000-8000-000000000002',
    1,
    8,
    null,
    3,
    60
  ),
  (
    '50000000-0000-4000-8000-000000000005',
    '40000000-0000-4000-8000-000000000002',
    2,
    8,
    null,
    3,
    0
  ),
  (
    '50000000-0000-4000-8000-000000000006',
    '40000000-0000-4000-8000-000000000003',
    0,
    null,
    20,
    3,
    45
  ),
  (
    '50000000-0000-4000-8000-000000000007',
    '40000000-0000-4000-8000-000000000003',
    1,
    null,
    20,
    3,
    45
  ),
  (
    '50000000-0000-4000-8000-000000000008',
    '40000000-0000-4000-8000-000000000003',
    2,
    null,
    20,
    3,
    0
  );

commit;
