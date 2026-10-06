-- La columna name del programa no debe ocultar la ruta del objeto de Storage.
-- Continúa la migración editorial 20261006003000.
begin;
drop policy program_covers_admin_upload on storage.objects;
create policy program_covers_admin_upload on storage.objects for insert to authenticated
with check (bucket_id = 'program-covers-public' and (select public.is_admin())
  and storage.objects.name ~ '^official/[^/]+/[a-f0-9]{32}/(card|header)[.]jpg$'
  and exists(select 1 from public.preparation_programs p
    where p.id = split_part(storage.objects.name, '/', 2)));
commit;
