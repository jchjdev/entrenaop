begin;
do $$
declare
  admin_id uuid := gen_random_uuid();
  user_id uuid := gen_random_uuid();
  asset_id uuid;
  video_id uuid := gen_random_uuid();
  exercise_id uuid;
  reference text;
begin
  insert into auth.users (id, email) values
    (admin_id, 'bunny-admin@example.invalid'), (user_id, 'bunny-user@example.invalid');
  insert into public.admin_permissions (user_id, reason) values (admin_id, 'Prueba transaccional de vídeo');
  perform set_config('request.jwt.claim.sub', user_id::text, true);
  set local role authenticated;
  begin
    perform public.reserve_official_exercise_video(42, 'fixture.b-cdn.net', 1000);
    raise exception 'Un deportista pudo reservar una subida';
  exception when insufficient_privilege then null;
  end;
  begin
    insert into public.exercise_video_assets (library_id, cdn_host, source_bytes)
    values (42, 'fixture.b-cdn.net', 1000);
    raise exception 'Un cliente pudo crear activos directamente';
  exception when insufficient_privilege then null;
  end;
  perform set_config('request.jwt.claim.sub', admin_id::text, true);
  asset_id := public.reserve_official_exercise_video(42, 'fixture.b-cdn.net', 1000);
  begin
    perform public.reserve_official_exercise_video(42, 'fixture.b-cdn.net', 20971521);
    raise exception 'Se aceptó un archivo superior a 20 MB';
  exception when check_violation then null;
  end;
  reset role;
  reference := 'https://fixture.b-cdn.net/' || video_id || '/play_720p.mp4';
  update public.exercise_video_assets set provider_video_id = video_id,
    playback_url = reference, status = 'processing' where id = asset_id;
  set local role authenticated;
  begin
    exercise_id := public.create_admin_exercise('Vídeo aún pendiente', null, reference,
      array['espalda'], '{}', 'inicial', 'repeticiones');
    raise exception 'Se publicó un vídeo pendiente';
  exception when invalid_parameter_value then null;
  end;
  begin
    update public.exercise_video_assets set status = 'ready' where id = asset_id;
    raise exception 'Un administrador cliente pudo fingir la verificación';
  exception when insufficient_privilege then null;
  end;
  reset role;
  begin
    update public.exercise_video_assets set status = 'ready', duration_seconds = 6,
      playback_bytes = 1000 where id = asset_id;
    raise exception 'Se aceptó un clip superior a cinco segundos';
  exception when check_violation then null;
  end;
  begin
    update public.exercise_video_assets set status = 'ready', duration_seconds = 5,
      playback_bytes = null where id = asset_id;
    raise exception 'Se aceptó ready sin tamaño final';
  exception when check_violation then null;
  end;
  update public.exercise_video_assets set status = 'ready', duration_seconds = 5,
    playback_bytes = 1000 where id = asset_id;
  perform set_config('request.jwt.claim.sub', user_id::text, true);
  set local role authenticated;
  if public.can_read_exercise_video(reference) then
    raise exception 'Un deportista pudo acceder a un vídeo no publicado';
  end if;
  perform set_config('request.jwt.claim.sub', admin_id::text, true);
  exercise_id := public.create_admin_exercise('Vídeo preparado', null, reference,
      array['espalda'], '{}', 'inicial', 'repeticiones');
  perform set_config('request.jwt.claim.sub', user_id::text, true);
  if not public.can_read_exercise_video(reference) then
    raise exception 'El vídeo oficial publicado no es accesible';
  end if;
  reset role;
  -- Ningún token ni cambio posterior sustituye la referencia estable guardada.
  if (select video_url from public.exercises where id = exercise_id) <> reference then
    raise exception 'Se alteró la referencia estable';
  end if;
  perform set_config('request.jwt.claim.sub', admin_id::text, true);
  set local role authenticated;
  for i in 1..19 loop
    perform public.reserve_official_exercise_video(42, 'fixture.b-cdn.net', 1000);
  end loop;
  begin
    perform public.reserve_official_exercise_video(42, 'fixture.b-cdn.net', 1000);
    raise exception 'No se aplica la cuota administrativa';
  exception when program_limit_exceeded then null;
  end;
  reset role;
end;
$$;
rollback;
