-- Edición del catálogo oficial con una pauta iniciada y otra pendiente.
begin;
set local statement_timeout = '60s';
do $$
declare
  editor uuid := gen_random_uuid();
  athlete uuid := gen_random_uuid();
  editor_session uuid := gen_random_uuid();
  editor_claims jsonb;
  athlete_claims jsonb;
  exercise uuid;
  empty_exercise uuid;
  template uuid;
  started uuid;
  pending uuid;
  execution uuid;
  first_image text;
  second_image text;
  added_image text;
  preview jsonb;
  payload jsonb;
begin
  insert into auth.users(id, email) values
    (editor, editor || '@official-exercise.test'),
    (athlete, athlete || '@official-exercise.test');
  insert into auth.mfa_factors(id,user_id,factor_type,status,created_at,updated_at)
    values (gen_random_uuid(),editor,'totp','verified',now(),now());
  insert into auth.sessions(id,user_id,created_at,updated_at)
    values (editor_session,editor,now(),now());
  insert into public.admin_permissions(user_id) values (editor);
  editor_claims := jsonb_build_object('sub',editor,'session_id',editor_session,'aal','aal2','role','authenticated');
  athlete_claims := jsonb_build_object('sub',athlete,'aal','aal1','role','authenticated');

  perform set_config('request.jwt.claim.sub',editor::text,true);
  perform set_config('request.jwt.claims',editor_claims::text,true);
  set local role authenticated;
  exercise := public.create_admin_exercise(
    'Ejercicio oficial con medios','Texto anterior','https://example.invalid/anterior',
    array['piernas'],array['barra']
  );
  empty_exercise := public.create_admin_exercise('Ejercicio sin ficha',p_muscle_groups=>array['piernas']);
  first_image := 'official/' || exercise || '/1.jpg';
  second_image := 'official/' || exercise || '/2.jpg';
  added_image := 'official/' || empty_exercise || '/1.jpg';
  insert into storage.objects(bucket_id,name) values
    ('exercise-images-public',first_image),
    ('exercise-images-public',second_image),
    ('exercise-images-public',added_image);
  perform public.set_admin_exercise_image(exercise,first_image);

  payload := jsonb_build_object('name','Sesión oficial de prueba','blocks',jsonb_build_array(jsonb_build_object(
    'name','Fuerza','format','straight_sets','rounds',1,'rest_after_seconds',0,
    'exercises',jsonb_build_array(
      jsonb_build_object('exercise_id',exercise,'sets',jsonb_build_array(jsonb_build_object('target_reps',8))),
      jsonb_build_object('exercise_id',empty_exercise,'sets',jsonb_build_array(jsonb_build_object('target_reps',8)))
    )
  )));
  template := public.create_admin_workout_draft(null,payload);
  reset role;
  update public.workout_templates set visibility='public', status='published' where id=template;

  perform set_config('request.jwt.claim.sub',athlete::text,true);
  perform set_config('request.jwt.claims',athlete_claims::text,true);
  set local role authenticated;
  started := public.schedule_workout(template,current_date);
  pending := public.schedule_workout(template,current_date+1);
  preview := public.get_scheduled_workout_preview(athlete,started);
  execution := public.start_reviewed_scheduled_workout(athlete,started,preview->>'revision');

  perform set_config('request.jwt.claim.sub',editor::text,true);
  perform set_config('request.jwt.claims',editor_claims::text,true);
  perform public.update_admin_exercise(
    exercise,'Ejercicio oficial con medios','Texto actualizado','https://example.invalid/nuevo',
    array['piernas'],array['barra']
  );
  perform public.set_admin_exercise_image(exercise,second_image);
  perform public.update_admin_exercise(
    empty_exercise,'Ejercicio sin ficha','Texto añadido','https://example.invalid/anadido',array['piernas']
  );
  perform public.set_admin_exercise_image(empty_exercise,added_image);

  perform set_config('request.jwt.claim.sub',athlete::text,true);
  perform set_config('request.jwt.claims',athlete_claims::text,true);
  if not exists (
    select 1 from public.workout_execution_sets s where s.execution_id=execution
      and s.exercise_id=exercise and s.official_exercise_image->>'path'=first_image
      and s.exercise_description='Texto anterior' and s.exercise_image_path is null
      and s.exercise_video_url='https://example.invalid/anterior'
  ) or not exists (
    select 1 from public.workout_execution_sets s where s.execution_id=execution
      and s.exercise_id=empty_exercise and s.official_exercise_image is not null
      and s.official_exercise_image->>'path' is null and s.exercise_image_path is null
      and s.exercise_description is null and s.exercise_video_url is null
  ) then raise exception 'Editar el catálogo cambió una ficha iniciada'; end if;

  if public.get_scheduled_workout_preview(athlete,started)#>>'{template,workout_blocks,0,workout_items,0,exercises,description}'
      is distinct from 'Texto anterior'
    or public.get_scheduled_workout_preview(athlete,pending)#>>'{template,workout_blocks,0,workout_items,0,exercises,description}'
      is distinct from 'Texto actualizado' then
    raise exception 'La consulta no distingue la ficha iniciada de la vigente';
  end if;
  if not exists (
    select 1 from public.exercises where id=exercise
      and image_path=second_image and video_url='https://example.invalid/nuevo'
  ) then raise exception 'La pauta pendiente no tiene acceso a los medios actualizados'; end if;

  reset role;
  if not exists (
    select 1 from trainer_private.media_cleanup_jobs where path=first_image
      and state='blocked' and blocked_reason='execution_history'
  ) then raise exception 'La limpieza no protegió la foto histórica'; end if;
end $$;
select 'official_exercise_presentation_snapshots: OK' as result;
rollback;
