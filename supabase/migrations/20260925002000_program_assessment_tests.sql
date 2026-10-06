-- El administrador define las pruebas de un borrador. Los baremos oficiales
-- continúan en catálogos versionados y no se inventan al crear una prueba.
begin;

create table public.program_assessment_tests (
  id uuid primary key default gen_random_uuid(),
  program_id text not null references public.preparation_programs(id) on delete restrict,
  code text not null,
  name text not null,
  unit text not null,
  better_direction text not null,
  protocol_notes text not null,
  definition_version integer not null default 1,
  created_at timestamptz not null default now(),
  constraint program_assessment_tests_code_check
    check (code ~ '^[a-z][a-z0-9_]{2,63}$'),
  constraint program_assessment_tests_name_check
    check (char_length(btrim(name)) between 3 and 120),
  constraint program_assessment_tests_unit_check
    check (unit in ('repetitions', 'seconds', 'meters')),
  constraint program_assessment_tests_direction_check
    check (better_direction in ('higher', 'lower')),
  constraint program_assessment_tests_protocol_check
    check (char_length(btrim(protocol_notes)) between 10 and 2000),
  constraint program_assessment_tests_version_check
    check (definition_version > 0),
  unique (program_id, code, definition_version)
);

create index program_assessment_tests_program_idx
on public.program_assessment_tests(program_id, code, definition_version desc);

alter table public.program_assessment_tests enable row level security;
revoke all on public.program_assessment_tests from public, anon, authenticated;
grant select on public.program_assessment_tests to authenticated;

create policy program_assessment_tests_read on public.program_assessment_tests
for select to authenticated
using (
  (select public.is_admin())
  or exists (
    select 1 from public.preparation_programs p
    where p.id = program_id and p.enabled
  )
);

create function public.create_admin_program_assessment_test(
  p_program_id text,
  p_code text,
  p_name text,
  p_unit text,
  p_better_direction text,
  p_protocol_notes text
) returns uuid
language plpgsql security definer set search_path = ''
as $$
declare
  v_id uuid;
begin
  if (select auth.uid()) is null or not (select public.is_admin()) then
    raise exception 'No tienes permiso para definir pruebas.' using errcode = '42501';
  end if;
  if not exists (
    select 1 from public.preparation_programs p
    where p.id = p_program_id and not p.enabled
  ) then
    raise exception 'Solo se pueden definir pruebas en programas borrador.'
      using errcode = '22023';
  end if;
  insert into public.program_assessment_tests
    (program_id, code, name, unit, better_direction, protocol_notes)
  values
    (p_program_id, btrim(p_code), btrim(p_name), p_unit,
     p_better_direction, btrim(p_protocol_notes))
  returning id into v_id;
  return v_id;
end;
$$;

revoke all on function public.create_admin_program_assessment_test(
  text,text,text,text,text,text) from public, anon;
grant execute on function public.create_admin_program_assessment_test(
  text,text,text,text,text,text) to authenticated;

commit;
