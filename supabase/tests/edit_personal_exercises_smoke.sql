begin;
do $$
declare
  owner_id uuid := gen_random_uuid();
  stranger_id uuid := gen_random_uuid();
  own_id uuid;
  official_id uuid := gen_random_uuid();
  old_path text;
  new_path text;
  template_id uuid;
  saved_execution_id uuid;
begin
  insert into auth.users(id, email) values
    (owner_id, 'exercise-edit-owner@example.invalid'),
    (stranger_id, 'exercise-edit-stranger@example.invalid');
  insert into public.exercises(id, name, muscle_groups, equipment, difficulty,
    exercise_type, origin, is_public) values
    (official_id, 'Sistema de prueba', array['core'], '{}', 'inicial', 'duración', 'system', true);
  perform set_config('request.jwt.claim.sub', owner_id::text, true);
  set local role authenticated;
  own_id := public.create_personal_exercise('Mi ejercicio', null, null,
    array['core'], '{}', 'inicial', 'duración');
  old_path := owner_id || '/' || own_id || '/123.jpg';
  new_path := owner_id || '/' || own_id || '/456.jpg';
  insert into storage.objects(bucket_id, name) values
    ('exercise-images-private', old_path), ('exercise-images-private', new_path);
  perform public.set_personal_exercise_image(own_id, old_path);
  template_id := public.create_personal_workout_template(jsonb_build_object(
    'name', 'Sesión de prueba', 'blocks', jsonb_build_array(jsonb_build_object(
      'name', 'Bloque', 'format', 'straight_sets', 'rounds', 1, 'rest_after_seconds', 0,
      'exercises', jsonb_build_array(jsonb_build_object('exercise_id', own_id,
        'sets', jsonb_build_array(jsonb_build_object('target_duration_seconds', 30,
          'rest_after_seconds', 0))))))));
  saved_execution_id := public.start_workout_execution(template_id);
  perform public.update_personal_exercise(own_id, '  Ejercicio editado  ', ' Técnica ',
    'https://example.invalid/video.mp4', array[' CORE ', 'core'], '{}', 'intermedio', 'duración');
  if not exists (select 1 from public.exercises where id = own_id
    and name = 'Ejercicio editado' and description = 'Técnica'
    and muscle_groups = array['core'] and image_path = old_path
    and origin = 'user' and not is_public and created_by = owner_id) then
    raise exception 'No normaliza contenido o pierde foto/autoría';
  end if;
  if not exists (select 1 from public.workout_execution_sets
    where workout_execution_sets.execution_id = saved_execution_id
      and exercise_name = 'Mi ejercicio' and exercise_description is null
      and exercise_video_url is null and target_duration_seconds = 30) then
    raise exception 'La edición altera la instantánea de ejecución';
  end if;
  begin
    perform public.update_personal_exercise(own_id, 'x', null, null,
      array['core'], '{}', 'inicial', 'duración', true, new_path);
    raise exception 'Acepta nombre inválido';
  exception when invalid_parameter_value then null;
  end;
  if (select image_path from public.exercises where id = own_id) <> old_path then
    raise exception 'Un fallo modifica la foto';
  end if;
  perform public.update_personal_exercise(own_id, 'Ejercicio editado', null, null,
    array['core'], '{}', 'inicial', 'duración', true, new_path);
  if (select image_path from public.exercises where id = own_id) <> new_path then
    raise exception 'No sustituye la imagen';
  end if;
  begin
    perform public.update_personal_exercise(own_id, 'Ejercicio editado', null, null,
      array['core'], '{}', 'inicial', 'duración', true,
      stranger_id || '/' || own_id || '/456.jpg');
    raise exception 'Permite vincular una imagen ajena';
  exception when invalid_parameter_value then null;
  end;
  begin
    perform public.update_personal_exercise(own_id, 'Ejercicio editado', null, null,
      array['core'], '{}', 'inicial', 'duración', true,
      owner_id || '/' || own_id || '/789.jpg');
    raise exception 'Permite vincular una imagen inexistente';
  exception when invalid_parameter_value then null;
  end;
  perform public.update_personal_exercise(own_id, 'Ejercicio editado', null, null,
    array['core'], '{}', 'inicial', 'duración', true, null);
  if (select image_path from public.exercises where id = own_id) is not null then
    raise exception 'No retira la imagen';
  end if;
  begin
    perform public.update_personal_exercise(official_id, 'Cambiar oficial', null, null,
      array['core'], '{}', 'inicial', 'duración');
    raise exception 'Permite editar contenido de sistema';
  exception when insufficient_privilege then null;
  end;
  perform set_config('request.jwt.claim.sub', stranger_id::text, true);
  begin
    perform public.update_personal_exercise(own_id, 'Cambiar ajeno', null, null,
      array['core'], '{}', 'inicial', 'duración');
    raise exception 'Permite editar otro autor';
  exception when insufficient_privilege then null;
  end;
  if has_function_privilege('anon',
    'public.update_personal_exercise(uuid,text,text,text,text[],text[],text,text,boolean,text)', 'execute') then
    raise exception 'Permite edición anónima';
  end if;
end $$;
select 'Edición privada, autoría, normalización e imagen atómica: OK' as result;
rollback;
