-- Prueba transaccional del límite privado/oficial del creador compartido.
-- Ejecutar con: supabase db query --linked --file supabase/tests/exercise_creator_security_smoke.sql
begin;

select set_config(
  'request.jwt.claim.sub',
  (select user_id::text from public.admin_permissions limit 1),
  true
);
select set_config(
  'test.admin_id',
  (select user_id::text from public.admin_permissions limit 1),
  true
);
select set_config(
  'test.user_id',
  (
    select id::text
    from auth.users as candidate
    where not exists (
      select 1
      from public.admin_permissions as permission
      where permission.user_id = candidate.id
    )
    limit 1
  ),
  true
);
set local role authenticated;

do $$
declare
  v_admin_id uuid;
  v_user_id uuid;
  v_official_id uuid;
  v_personal_id uuid;
begin
  v_admin_id := current_setting('test.admin_id')::uuid;
  v_user_id := current_setting('test.user_id')::uuid;

  if v_admin_id is null or v_user_id is null then
    raise exception 'La prueba necesita un administrador y un usuario no administrador.';
  end if;

  perform set_config('request.jwt.claim.sub', v_admin_id::text, true);

  v_official_id := public.create_admin_exercise(
    '  Ejercicio oficial temporal  ',
    ' Descripción ',
    'https://example.com/oficial',
    array[' Espalda ', 'espalda'],
    array[' Barra '],
    'intermedio',
    'repeticiones'
  );

  if not exists (
    select 1 from public.exercises
    where id = v_official_id
      and name = 'Ejercicio oficial temporal'
      and muscle_groups = array['espalda']
      and equipment = array['barra']
      and origin = 'system'
      and created_by is null
      and is_public is true
  ) then
    raise exception 'El ejercicio administrativo no conservó las invariantes oficiales.';
  end if;

  perform public.update_admin_exercise(
    v_official_id,
    'Ejercicio oficial revisado',
    null,
    null,
    array['espalda'],
    array[]::text[],
    'avanzado',
    'duración'
  );

  if not exists (
    select 1 from public.exercises
    where id = v_official_id
      and name = 'Ejercicio oficial revisado'
      and origin = 'system'
      and created_by is null
      and is_public is true
  ) then
    raise exception 'La edición administrativa alteró el origen o la visibilidad.';
  end if;

  perform set_config('request.jwt.claim.sub', v_user_id::text, true);

  begin
    perform public.create_admin_exercise(
      'Publicación indebida', null, null, array['pecho'], array[]::text[],
      'inicial', 'repeticiones'
    );
    raise exception 'Un usuario normal pudo crear un ejercicio oficial.';
  exception
    when insufficient_privilege then null;
  end;

  v_personal_id := public.create_personal_exercise(
    'Ejercicio privado temporal', null, null, array['piernas'],
    array[]::text[], 'inicial', 'repeticiones'
  );

  if not exists (
    select 1 from public.exercises
    where id = v_personal_id
      and origin = 'user'
      and created_by = v_user_id
      and is_public is false
  ) then
    raise exception 'El ejercicio personal no quedó privado y ligado a su autor.';
  end if;

  begin
    perform public.update_admin_exercise(
      v_personal_id,
      'Conversión indebida', null, null, array['piernas'], array[]::text[],
      'inicial', 'repeticiones'
    );
    raise exception 'Un usuario normal pudo convertir un ejercicio personal.';
  exception
    when insufficient_privilege then null;
  end;
end;
$$;

rollback;
