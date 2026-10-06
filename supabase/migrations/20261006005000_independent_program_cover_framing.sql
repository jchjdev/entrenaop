-- Encuadres independientes sin alterar las fotos ni las posiciones existentes.
begin;
alter table public.preparation_program_covers
  add column header_focal_x double precision not null default 0.5,
  add column header_focal_y double precision not null default 0.5;
update public.preparation_program_covers
  set header_focal_x = focal_x, header_focal_y = focal_y;
alter table public.preparation_program_covers
  add constraint preparation_program_covers_header_focus
  check (header_focal_x between 0 and 1 and header_focal_y between 0 and 1);

create function public.set_admin_program_cover_v2(
  p_program_id text, p_card_image_path text, p_header_image_path text,
  p_focal_x double precision, p_focal_y double precision,
  p_header_focal_x double precision, p_header_focal_y double precision, p_expected_revision integer
) returns jsonb language plpgsql security definer set search_path = '' as $$
declare previous public.preparation_program_covers%rowtype;
        saved public.preparation_program_covers%rowtype;
begin
  if not coalesce(public.is_admin(), false) then
    raise exception 'Solo administración puede cambiar portadas.' using errcode = '42501';
  end if;
  if p_expected_revision is null or p_expected_revision < 0
    or p_focal_x is null or p_focal_y is null
    or not (p_focal_x between 0 and 1 and p_focal_y between 0 and 1)
    or p_header_focal_x is null or p_header_focal_y is null
    or not (p_header_focal_x between 0 and 1 and p_header_focal_y between 0 and 1) then
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
      focal_x, focal_y, header_focal_x, header_focal_y, revision, updated_at)
    values(p_program_id, p_card_image_path, p_header_image_path, p_focal_x, p_focal_y,
      p_header_focal_x, p_header_focal_y, p_expected_revision + 1, now())
    on conflict(program_id) do update set card_image_path = excluded.card_image_path,
      header_image_path = excluded.header_image_path, focal_x = excluded.focal_x,
      focal_y = excluded.focal_y, header_focal_x = excluded.header_focal_x,
      header_focal_y = excluded.header_focal_y, revision = excluded.revision, updated_at = excluded.updated_at
    returning * into saved;
  return jsonb_build_object('cover', to_jsonb(saved),
    'previous_card_path', previous.card_image_path, 'previous_header_path', previous.header_image_path);
end;
$$;
revoke all on function public.set_admin_program_cover_v2(text,text,text,double precision,double precision,double precision,double precision,integer)
from public, anon, authenticated;
grant execute on function public.set_admin_program_cover_v2(text,text,text,double precision,double precision,double precision,double precision,integer)
to authenticated;

-- Compatibilidad con editores anteriores: conservan el encuadre independiente
-- de cabecera. Solo las altas antiguas inicializan ambos con el mismo punto.
create or replace function public.set_admin_program_cover(
  p_program_id text, p_card_image_path text, p_header_image_path text,
  p_focal_x double precision, p_focal_y double precision, p_expected_revision integer
) returns jsonb language plpgsql security definer set search_path = '' as $$
declare header_x double precision; header_y double precision;
begin
  if not coalesce(public.is_admin(), false) then
    raise exception 'Solo administración puede cambiar portadas.' using errcode = '42501';
  end if;
  select header_focal_x, header_focal_y into header_x, header_y
    from public.preparation_program_covers where program_id = p_program_id;
  if not found then header_x := p_focal_x; header_y := p_focal_y; end if;
  return public.set_admin_program_cover_v2(p_program_id, p_card_image_path, p_header_image_path,
    p_focal_x, p_focal_y, header_x, header_y, p_expected_revision);
end;
$$;
revoke all on function public.set_admin_program_cover(text,text,text,double precision,double precision,integer)
from public, anon, authenticated;
grant execute on function public.set_admin_program_cover(text,text,text,double precision,double precision,integer)
to authenticated;
commit;

