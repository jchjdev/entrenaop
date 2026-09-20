-- Los catálogos públicos solo deben exponer programas habilitados.
--
-- La política inicial consultaba is_admin() también para usuarios anónimos,
-- que no tienen permiso para ejecutar esa función. Mantenemos el catálogo
-- público con el criterio mínimo que necesita la aplicación cliente.

begin;

drop policy if exists preparation_programs_select_enabled
on public.preparation_programs;

create policy preparation_programs_select_enabled
on public.preparation_programs
for select
to anon, authenticated
using (enabled);

drop policy if exists preparation_program_catalogs_select_all
on public.preparation_program_catalogs;

create policy preparation_program_catalogs_select_enabled
on public.preparation_program_catalogs
for select
to anon, authenticated
using (
  exists (
    select 1
    from public.preparation_programs as program
    where program.id = preparation_program_catalogs.program_id
      and program.enabled
  )
);

commit;
