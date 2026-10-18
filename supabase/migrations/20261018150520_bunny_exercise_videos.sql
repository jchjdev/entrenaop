begin;

-- Se conserva video_url como referencia estable en catálogo e instantáneas.
-- Las URLs firmadas se generan al consultar y nunca se guardan en el historial.
create table public.exercise_video_assets (
  id uuid primary key default gen_random_uuid(),
  created_by uuid references auth.users(id) on delete set null,
  library_id bigint not null check (library_id > 0),
  provider_video_id uuid,
  cdn_host text not null check (cdn_host ~ '^[a-z0-9][a-z0-9-]*\.b-cdn\.net$'),
  source_bytes integer not null check (source_bytes between 1 and 20971520),
  status text not null default 'uploading'
    check (status in ('uploading', 'processing', 'ready', 'rejected', 'failed')),
  duration_seconds numeric check (duration_seconds > 0 and duration_seconds <= 5),
  playback_url text unique,
  playback_bytes integer check (playback_bytes between 1 and 5242880),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (library_id, provider_video_id),
  check (status <> 'ready' or (
    provider_video_id is not null and duration_seconds is not null
    and playback_bytes is not null and playback_url is not null and playback_url in (
      'https://' || cdn_host || '/' || provider_video_id::text || '/play_720p.mp4',
      'https://' || cdn_host || '/' || provider_video_id::text || '/play_480p.mp4',
      'https://' || cdn_host || '/' || provider_video_id::text || '/play_360p.mp4')
  ))
);
create index exercise_video_assets_created_by_time
  on public.exercise_video_assets (created_by, created_at desc);
alter table public.exercise_video_assets enable row level security;
revoke all on public.exercise_video_assets from public, anon, authenticated;
grant select, insert, update on public.exercise_video_assets to service_role;

-- La reserva es administrativa y serializa la cuota antes de crear nada en Bunny.
create function public.reserve_official_exercise_video(
  p_library_id bigint, p_cdn_host text, p_source_bytes integer
) returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  owner_id uuid := auth.uid();
  asset_id uuid;
begin
  if owner_id is null or not public.is_admin() then
    raise exception 'Permiso administrativo requerido' using errcode = '42501';
  end if;
  perform pg_advisory_xact_lock(hashtextextended(owner_id::text, 1201));
  if (select count(*) from public.exercise_video_assets
      where created_by = owner_id and created_at > now() - interval '1 hour') >= 20 then
    raise exception 'Límite de subidas por hora alcanzado' using errcode = '54000';
  end if;
  insert into public.exercise_video_assets
    (created_by, library_id, cdn_host, source_bytes)
  values (owner_id, p_library_id, p_cdn_host, p_source_bytes)
  returning id into asset_id;
  return asset_id;
end;
$$;
revoke all on function public.reserve_official_exercise_video(bigint, text, integer)
  from public, anon;
grant execute on function public.reserve_official_exercise_video(bigint, text, integer)
  to authenticated;

-- SECURITY INVOKER conserva el acceso real a catálogo e instantáneas por RLS.
create function public.can_read_exercise_video(p_video_url text)
returns boolean language sql stable security invoker set search_path = '' as $$
  select auth.uid() is not null and (
    public.is_admin()
    or exists (select 1 from public.exercises where video_url = p_video_url)
    or exists (select 1 from public.workout_execution_sets
               where exercise_video_url = p_video_url)
  );
$$;
revoke all on function public.can_read_exercise_video(text) from public, anon;
grant execute on function public.can_read_exercise_video(text) to authenticated;

create function public.check_exercise_video_ready()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if tg_op = 'UPDATE' and new.video_url is not distinct from old.video_url then
    return new;
  end if;
  if exists (select 1 from public.exercise_video_assets where playback_url = new.video_url)
    and not exists (select 1 from public.exercise_video_assets
                    where playback_url = new.video_url and status = 'ready') then
    raise exception 'El vídeo todavía no está preparado' using errcode = '22023';
  end if;
  return new;
end;
$$;
revoke all on function public.check_exercise_video_ready() from public, anon, authenticated;
create trigger exercises_video_ready before insert or update of video_url
  on public.exercises for each row execute function public.check_exercise_video_ready();

comment on table public.exercise_video_assets is
  'VID-003: subidas oficiales de Bunny; escritura de estado exclusiva del servidor. Sin borrado automático de recursos históricos.';
commit;
