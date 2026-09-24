begin;

do $$
declare
  admin_id uuid := gen_random_uuid();
  user_id uuid := gen_random_uuid();
  other_user_id uuid := gen_random_uuid();
  official_id uuid;
  personal_id uuid;
begin
  insert into auth.users (id, email) values
    (admin_id, 'exercise-image-admin@example.invalid'),
    (user_id, 'exercise-image-user@example.invalid'),
    (other_user_id, 'exercise-image-other@example.invalid');
  insert into public.admin_permissions (user_id, reason)
  values (admin_id, 'Prueba transaccional de imágenes');

  perform set_config('request.jwt.claim.sub', admin_id::text, true);
  set local role authenticated;
  official_id := public.create_admin_exercise(
    'Ejercicio imagen oficial', null, null, array['piernas'], '{}',
    'inicial', 'repeticiones'
  );
  perform public.set_admin_exercise_image(
    official_id,
    'official/' || official_id || '/123.jpg'
  );

  perform set_config('request.jwt.claim.sub', user_id::text, true);
  personal_id := public.create_personal_exercise(
    'Ejercicio imagen personal', null, null, array['espalda'], '{}',
    'inicial', 'repeticiones'
  );
  perform public.set_personal_exercise_image(
    personal_id,
    user_id || '/' || personal_id || '/456.jpg'
  );

  perform set_config('request.jwt.claim.sub', other_user_id::text, true);
  begin
    perform public.set_personal_exercise_image(
      personal_id,
      other_user_id || '/' || personal_id || '/789.jpg'
    );
    raise exception 'Otro usuario pudo modificar una imagen privada';
  exception
    when sqlstate '22023' then null;
  end;
end;
$$;

rollback;
