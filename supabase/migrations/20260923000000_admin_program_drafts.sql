-- La autoría inicial crea programas genéricos sin publicarlos al alumno.
-- Ni el cliente ni un permiso comercial pueden concederse acceso administrativo.

begin;

create policy preparation_programs_select_admin
on public.preparation_programs
for select
to authenticated
using ((select public.is_admin()));

create or replace function public.create_admin_preparation_program(
  p_name text,
  p_kind text
)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  new_id text;
  clean_name text := btrim(p_name);
begin
  if (select auth.uid()) is null or not (select public.is_admin()) then
    raise exception 'No tienes permiso para crear programas.'
      using errcode = '42501';
  end if;

  if clean_name is null or char_length(clean_name) < 3
      or char_length(clean_name) > 120 then
    raise exception 'El nombre debe tener entre 3 y 120 caracteres.'
      using errcode = '22023';
  end if;

  if p_kind is null or p_kind not in ('access', 'internal_assessment') then
    raise exception 'Tipo de programa no válido.'
      using errcode = '22023';
  end if;

  new_id := gen_random_uuid()::text;
  insert into public.preparation_programs (id, name, kind, enabled)
  values (new_id, clean_name, p_kind, false);
  return new_id;
end;
$$;

revoke all on function public.create_admin_preparation_program(text, text)
from public, anon;
grant execute on function public.create_admin_preparation_program(text, text)
to authenticated;

commit;
