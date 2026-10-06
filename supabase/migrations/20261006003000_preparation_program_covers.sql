-- Identidad editorial independiente de pruebas, baremos y algoritmos publicados.
-- Numeración reservada para no colisionar con el trabajo paralelo de disponibilidad.
begin;

create table public.preparation_program_covers (
  program_id text primary key references public.preparation_programs(id) on delete restrict,
  card_image_path text,
  header_image_path text,
  focal_x double precision not null default 0.5,
  focal_y double precision not null default 0.5,
  revision integer not null default 1 check (revision > 0),
  updated_at timestamptz not null default now(),
  constraint preparation_program_covers_focus check (focal_x between 0 and 1 and focal_y between 0 and 1),
  constraint preparation_program_covers_paths check (
    (card_image_path is null and header_image_path is null)
    or (card_image_path is not null and header_image_path is not null
      and length(card_image_path) <= 300 and length(header_image_path) <= 300
      and card_image_path ~ '^official/[^/]+/[a-f0-9]{32}/card[.]jpg$'
      and header_image_path = regexp_replace(card_image_path, 'card[.]jpg$', 'header.jpg')
      and split_part(card_image_path, '/', 2) = program_id)
  )
);
alter table public.preparation_program_covers enable row level security;
revoke all on public.preparation_program_covers from public, anon, authenticated;
grant select on public.preparation_program_covers to authenticated;
create policy program_covers_read_catalog on public.preparation_program_covers
for select to authenticated using (exists (
  select 1 from public.preparation_programs p where p.id = program_id
    and (p.enabled or (select public.is_admin()))
));

insert into storage.buckets(id, name, public, file_size_limit, allowed_mime_types)
values ('program-covers-public', 'program-covers-public', true, 524288, array['image/jpeg']);
create policy program_covers_admin_inspect on storage.objects for select to authenticated
using (bucket_id = 'program-covers-public' and (select public.is_admin()));
create policy program_covers_admin_upload on storage.objects for insert to authenticated
with check (bucket_id = 'program-covers-public' and (select public.is_admin())
  and name ~ '^official/[^/]+/[a-f0-9]{32}/(card|header)[.]jpg$'
  and exists(select 1 from public.preparation_programs p where p.id = split_part(name, '/', 2)));
-- Las rutas son inmutables. Retirar solo archivos que ya no sean la portada vigente.
create policy program_covers_admin_cleanup on storage.objects for delete to authenticated
using (bucket_id = 'program-covers-public' and (select public.is_admin())
  and not exists (select 1 from public.preparation_program_covers c
    where c.card_image_path = name or c.header_image_path = name));

create function public.set_admin_program_cover(
  p_program_id text, p_card_image_path text, p_header_image_path text,
  p_focal_x double precision, p_focal_y double precision, p_expected_revision integer
) returns jsonb language plpgsql security definer set search_path = '' as $$
declare previous public.preparation_program_covers%rowtype;
        saved public.preparation_program_covers%rowtype;
begin
  if not coalesce(public.is_admin(), false) then
    raise exception 'Solo administración puede cambiar portadas.' using errcode = '42501';
  end if;
  if p_expected_revision is null or p_expected_revision < 0
    or p_focal_x is null or p_focal_y is null
    or not (p_focal_x between 0 and 1 and p_focal_y between 0 and 1) then
    raise exception 'Encuadre o revisión no válidos.' using errcode = '22023';
  end if;
  -- Serializa también la primera portada, cuando todavía no existe la fila editorial.
  perform 1 from public.preparation_programs where id = p_program_id for update;
  if not found then raise exception 'Preparación inexistente.' using errcode = '22023'; end if;
  select * into previous from public.preparation_program_covers where program_id = p_program_id;
  if coalesce(previous.revision, 0) <> p_expected_revision then
    raise exception 'Otra edición ha cambiado la portada. Recarga antes de guardar.' using errcode = '40001';
  end if;
  if (p_card_image_path is null) <> (p_header_image_path is null) then
    raise exception 'Se necesitan las dos versiones de la imagen.' using errcode = '22023';
  end if;
  if p_card_image_path is not null then
    if p_card_image_path !~ '^official/[^/]+/[a-f0-9]{32}/card[.]jpg$'
      or p_header_image_path <> regexp_replace(p_card_image_path, 'card[.]jpg$', 'header.jpg')
      or split_part(p_card_image_path, '/', 2) <> p_program_id
      or not exists(select 1 from storage.objects where bucket_id = 'program-covers-public'
        and name = p_card_image_path and metadata->>'mimetype' = 'image/jpeg')
      or not exists(select 1 from storage.objects where bucket_id = 'program-covers-public'
        and name = p_header_image_path and metadata->>'mimetype' = 'image/jpeg') then
      raise exception 'Portada no válida o archivos pendientes de subir.' using errcode = '22023';
    end if;
  end if;
  insert into public.preparation_program_covers(program_id, card_image_path, header_image_path,
      focal_x, focal_y, revision, updated_at)
    values(p_program_id, p_card_image_path, p_header_image_path, p_focal_x, p_focal_y,
      p_expected_revision + 1, now())
    on conflict(program_id) do update set card_image_path = excluded.card_image_path,
      header_image_path = excluded.header_image_path, focal_x = excluded.focal_x,
      focal_y = excluded.focal_y, revision = excluded.revision, updated_at = excluded.updated_at
    returning * into saved;
  return jsonb_build_object('cover', to_jsonb(saved),
    'previous_card_path', previous.card_image_path, 'previous_header_path', previous.header_image_path);
end;
$$;
revoke all on function public.set_admin_program_cover(text,text,text,double precision,double precision,integer)
from public, anon, authenticated;
grant execute on function public.set_admin_program_cover(text,text,text,double precision,double precision,integer)
to authenticated;
commit;
