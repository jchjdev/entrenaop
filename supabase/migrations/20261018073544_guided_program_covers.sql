-- Portada editorial común a las versiones de una familia, sin cambiar entrenamientos.
begin;
create table public.guided_program_covers (
  program_id uuid primary key references public.guided_programs(id) on delete restrict,
  card_image_path text, header_image_path text,
  focal_x double precision not null default 0.5,
  focal_y double precision not null default 0.5,
  header_focal_x double precision not null default 0.5,
  header_focal_y double precision not null default 0.5,
  revision integer not null check (revision > 0),
  updated_at timestamptz not null default now(),
  check (focal_x between 0 and 1 and focal_y between 0 and 1
    and header_focal_x between 0 and 1 and header_focal_y between 0 and 1),
  check ((card_image_path is null and header_image_path is null) or (
    card_image_path is not null and header_image_path is not null
    and length(card_image_path)<=300 and length(header_image_path)<=300
    and card_image_path ~ '^guided/[a-f0-9-]{36}/[a-f0-9]{32}/card[.]jpg$'
    and header_image_path=regexp_replace(card_image_path,'card[.]jpg$','header.jpg')
    and split_part(card_image_path,'/',2)=program_id::text))
);
alter table public.guided_program_covers enable row level security;
revoke all on public.guided_program_covers from public,anon,authenticated;
grant select on public.guided_program_covers to authenticated;
create policy guided_covers_read on public.guided_program_covers for select to authenticated
using ((select public.is_admin()) or exists (
  select 1 from public.guided_programs p where p.family_id=guided_program_covers.program_id
    and (p.status='published' or exists(select 1 from public.guided_program_follows f
      where f.program_id=p.id and f.user_id=(select auth.uid())))
));

-- Se conserva el recurso de preparaciones y se amplía el mismo bucket con otro prefijo.
drop policy program_covers_admin_upload on storage.objects;
create policy program_covers_admin_upload on storage.objects for insert to authenticated
with check (bucket_id='program-covers-public' and (select public.is_admin()) and (
  (storage.objects.name ~ '^official/[^/]+/[a-f0-9]{32}/(card|header)[.]jpg$'
    and exists(select 1 from public.preparation_programs p where p.id=split_part(storage.objects.name,'/',2)))
  or (storage.objects.name ~ '^guided/[a-f0-9-]{36}/[a-f0-9]{32}/(card|header)[.]jpg$'
    and exists(select 1 from public.guided_programs p where p.id=p.family_id
      and p.id::text=split_part(storage.objects.name,'/',2)))
));
drop policy program_covers_admin_cleanup on storage.objects;
create policy program_covers_admin_cleanup on storage.objects for delete to authenticated
using (bucket_id='program-covers-public' and (select public.is_admin())
  and not exists(select 1 from public.preparation_program_covers c where c.card_image_path=name or c.header_image_path=name)
  and not exists(select 1 from public.guided_program_covers c where c.card_image_path=name or c.header_image_path=name));

create function public.set_admin_guided_program_cover(
  p_program_id uuid,p_card_image_path text,p_header_image_path text,
  p_focal_x double precision,p_focal_y double precision,
  p_header_focal_x double precision,p_header_focal_y double precision,p_expected_revision integer
) returns jsonb language plpgsql security definer set search_path='' as $$
declare root uuid; previous public.guided_program_covers; saved public.guided_program_covers;
begin
  if auth.uid() is null or not coalesce(public.is_admin(),false) then
    raise exception 'Solo administración puede cambiar portadas.' using errcode='42501'; end if;
  if p_expected_revision is null or p_expected_revision<0
    or p_focal_x is null or p_focal_y is null or p_header_focal_x is null or p_header_focal_y is null
    or not (p_focal_x between 0 and 1 and p_focal_y between 0 and 1
      and p_header_focal_x between 0 and 1 and p_header_focal_y between 0 and 1) then
    raise exception 'Encuadre o revisión no válidos.' using errcode='22023'; end if;
  select family_id into root from public.guided_programs where id=p_program_id;
  if not found then raise exception 'Programa inexistente.' using errcode='22023'; end if;
  -- Bloquea la raíz para serializar también la primera portada y las ediciones entre versiones.
  perform 1 from public.guided_programs where id=root and family_id=root for update;
  if not found then raise exception 'Familia inexistente.' using errcode='22023'; end if;
  select * into previous from public.guided_program_covers where program_id=root;
  if coalesce(previous.revision,0)<>p_expected_revision then
    raise exception 'Otra edición ha cambiado la portada.' using errcode='40001'; end if;
  if (p_card_image_path is null)<>(p_header_image_path is null) then
    raise exception 'Se necesitan las dos versiones de la imagen.' using errcode='22023'; end if;
  if p_card_image_path is not null and (
    p_card_image_path !~ '^guided/[a-f0-9-]{36}/[a-f0-9]{32}/card[.]jpg$'
    or split_part(p_card_image_path,'/',2)<>root::text
    or p_header_image_path<>regexp_replace(p_card_image_path,'card[.]jpg$','header.jpg')
    or not exists(select 1 from storage.objects where bucket_id='program-covers-public'
      and name=p_card_image_path and metadata->>'mimetype'='image/jpeg')
    or not exists(select 1 from storage.objects where bucket_id='program-covers-public'
      and name=p_header_image_path and metadata->>'mimetype'='image/jpeg')) then
    raise exception 'Portada no válida o archivos pendientes de subir.' using errcode='22023'; end if;
  insert into public.guided_program_covers(program_id,card_image_path,header_image_path,
    focal_x,focal_y,header_focal_x,header_focal_y,revision)
    values(root,p_card_image_path,p_header_image_path,p_focal_x,p_focal_y,p_header_focal_x,p_header_focal_y,p_expected_revision+1)
    on conflict(program_id) do update set card_image_path=excluded.card_image_path,
      header_image_path=excluded.header_image_path,focal_x=excluded.focal_x,focal_y=excluded.focal_y,
      header_focal_x=excluded.header_focal_x,header_focal_y=excluded.header_focal_y,
      revision=excluded.revision,updated_at=now() returning * into saved;
  return jsonb_build_object('cover',to_jsonb(saved),
    'previous_card_path',previous.card_image_path,'previous_header_path',previous.header_image_path);
end $$;
revoke all on function public.set_admin_guided_program_cover(uuid,text,text,double precision,double precision,double precision,double precision,integer)
  from public,anon,authenticated;
grant execute on function public.set_admin_guided_program_cover(uuid,text,text,double precision,double precision,double precision,double precision,integer)
  to authenticated;
commit;
