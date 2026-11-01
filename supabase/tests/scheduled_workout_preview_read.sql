-- Consulta exacta de la pauta y comienzo explícito sin sustituir el ejecutor.
begin;
set local statement_timeout = '45s';

do $$
declare
  trainer uuid := gen_random_uuid();
  pupil uuid := gen_random_uuid();
  outsider uuid := gen_random_uuid();
  relation uuid := gen_random_uuid();
  planned uuid := gen_random_uuid();
  withdrawn uuid := gen_random_uuid();
  exercise uuid;
  original uuid;
  latest uuid;
  personal uuid;
  personal_schedule uuid;
  official uuid;
  official_schedule uuid;
  algorithm uuid;
  algorithm_schedule uuid := gen_random_uuid();
  private_draft uuid;
  denied_schedule uuid := gen_random_uuid();
  private_coach uuid;
  private_coach_latest uuid;
  private_session uuid;
  private_schedule uuid := gen_random_uuid();
  foreign_exercise uuid;
  own_exercise uuid;
  personal_item uuid;
  personal_set uuid;
  personal_execution uuid;
  personal_revision text;
  catalog_key bigint;
  exercise_draft jsonb;
  execution uuid;
  continuing_execution uuid;
  result_set uuid;
  continuing_revision text;
  payload jsonb;
  adapted jsonb;
  preview jsonb;
  fresh jsonb;
  plan jsonb;
  original_revision text;
  reviewed_revision text;
  before_schedule jsonb;
  executions_before integer;
begin
  insert into auth.users(id, email) values
    (trainer, trainer || '@preview.invalid'),
    (pupil, pupil || '@preview.invalid'),
    (outsider, outsider || '@preview.invalid');
  insert into auth.mfa_factors(id, user_id, factor_type, status, created_at, updated_at)
    values (gen_random_uuid(), trainer, 'totp', 'verified', now(), now()),
      (gen_random_uuid(), outsider, 'totp', 'verified', now(), now());
  insert into public.admin_permissions(user_id) values (outsider);
  insert into public.trainer_access(trainer_id, enabled, client_limit, last_reason)
    values (trainer, true, 1, 'Prueba de consulta pautada');
  insert into public.trainer_client_relations(id, trainer_id, client_id, accepted_at)
    values (relation, trainer, pupil, now());
  select id into exercise from public.exercises
    where is_public and id <> '20000000-0000-4000-8000-000000000004'
    order by id limit 1;
  if exercise is null then raise exception 'Se requiere el catálogo de ejercicios públicos.'; end if;

  payload := jsonb_build_object('name', 'Pauta original', 'blocks', jsonb_build_array(jsonb_build_object(
    'name', 'Fuerza pautada', 'format', 'straight_sets', 'rounds', 1, 'rest_after_seconds', 0,
    'exercises', jsonb_build_array(jsonb_build_object('exercise_id', exercise,
      'sets', jsonb_build_array(jsonb_build_object('target_reps', 10, 'rest_after_seconds', 60)))))));
  adapted := jsonb_set(jsonb_set(payload, '{name}', '"Pauta adaptada"'),
    '{blocks,0,exercises,0,sets,0,target_reps}', '20');

  perform set_config('request.jwt.claim.sub', trainer::text, true);
  perform set_config('request.jwt.claims', jsonb_build_object('sub', trainer, 'role', 'authenticated', 'aal', 'aal2')::text, true);
  set local role authenticated;
  original := public.save_trainer_workout(gen_random_uuid(), payload);
  perform public.assign_trainer_workout(planned, relation, original, current_date + 1, 'Indicaciones del preparador');
  perform public.assign_trainer_workout(withdrawn, relation, original, current_date + 3, null);
  latest := public.save_trainer_workout(gen_random_uuid(), adapted, original);
  exercise_draft := jsonb_build_object('name', 'Ejercicio privado exacto', 'description', 'Instrucción original',
    'muscle_groups', jsonb_build_array('espalda'), 'equipment', jsonb_build_array('barra'),
    'difficulty', 'intermedio', 'exercise_type', 'repeticiones');
  private_coach := public.save_trainer_exercise(gen_random_uuid(), exercise_draft);
  private_session := public.save_trainer_workout(gen_random_uuid(),
    jsonb_set(payload, '{blocks,0,exercises,0,exercise_id}', to_jsonb(private_coach::text)));
  perform public.assign_trainer_workout(private_schedule, relation, private_session, current_date + 4, null);
  private_coach_latest := public.save_trainer_exercise(gen_random_uuid(),
    jsonb_set(exercise_draft, '{description}', '"Instrucción revisada"'), private_coach);

  perform set_config('request.jwt.claim.sub', pupil::text, true);
  perform set_config('request.jwt.claims', jsonb_build_object('sub', pupil, 'role', 'authenticated', 'aal', 'aal1')::text, true);
  select to_jsonb(s) into before_schedule from public.scheduled_workouts s where id = planned;
  select count(*) into executions_before from public.workout_executions where user_id = pupil;
  if exists (select 1 from public.workout_templates where id = latest) then
    raise exception 'La versión no asignada es visible antes de consultar la pauta.';
  end if;
  preview := public.get_scheduled_workout_preview(pupil, planned);
  original_revision := preview->>'revision';
  if preview->'template'->>'id' <> original::text
    or (preview->'template'->>'version')::integer <> 1
    or (preview#>>'{template,workout_blocks,0,workout_items,0,workout_sets,0,target_reps}')::integer <> 10
    or preview#>>'{scheduled_workout,trainer_assignments,note}' <> 'Indicaciones del preparador'
    or preview#>>'{scheduled_workout,status}' <> 'planned' then
    raise exception 'La consulta sustituye la versión asignada por la última de la biblioteca.';
  end if;
  if length(original_revision) <> 64 or public.get_scheduled_workout_preview(pupil, planned) <> preview then
    raise exception 'La revisión no es estable entre consultas iguales.';
  end if;
  if (select count(*) from public.workout_executions where user_id = pupil) <> executions_before
    or (select to_jsonb(s) from public.scheduled_workouts s where id = planned) <> before_schedule
    or exists (select 1 from public.workout_execution_sets r join public.workout_executions e on e.id = r.execution_id where e.user_id = pupil) then
    raise exception 'Consultar el entrenamiento inicia o modifica la pauta.';
  end if;
  if exists (select 1 from public.workout_templates where id = latest) then
    raise exception 'La consulta amplía la biblioteca profesional del alumno.';
  end if;
  fresh := public.get_scheduled_workout_preview(pupil, private_schedule);
  if fresh#>>'{template,workout_blocks,0,workout_items,0,exercises,id}' <> private_coach::text
    or fresh#>>'{template,workout_blocks,0,workout_items,0,exercises,description}' <> 'Instrucción original'
    or exists (select 1 from public.exercises where id = private_coach_latest) then
    raise exception 'La lectura privada pierde el ejercicio asignado o revela otra revisión.';
  end if;
  begin perform public.get_scheduled_workout_preview(outsider, planned);
    raise exception 'Acepta otra identidad esperada.';
  exception when insufficient_privilege then null; end;
  perform set_config('request.jwt.claim.sub', '', true);
  perform set_config('request.jwt.claims', '{}'::text, true);
  begin perform public.get_scheduled_workout_preview(pupil, planned);
    raise exception 'Se consulta sin una identidad de sesión.';
  exception when insufficient_privilege then null; end;
  perform set_config('request.jwt.claim.sub', pupil::text, true);
  perform set_config('request.jwt.claims', jsonb_build_object('sub', pupil, 'role', 'authenticated', 'aal', 'aal1')::text, true);
  begin perform public.get_scheduled_workout_preview(pupil, latest);
    raise exception 'Usar el UUID de una plantilla concede acceso sin cita.';
  exception when insufficient_privilege then null; end;
  begin perform public.start_reviewed_scheduled_workout(pupil, planned, 'otra-revision');
    raise exception 'Comienza sin revisar la pauta actual.';
  exception when serialization_failure then null; end;
  if (select count(*) from public.workout_executions where user_id = pupil) <> executions_before then
    raise exception 'El rechazo de revisión creó una ejecución.';
  end if;

  perform set_config('request.jwt.claim.sub', outsider::text, true);
  perform set_config('request.jwt.claims', jsonb_build_object('sub', outsider, 'role', 'authenticated', 'aal', 'aal2')::text, true);
  begin perform public.get_scheduled_workout_preview(outsider, planned);
    raise exception 'ADMIN ajeno consulta el entrenamiento del alumno.';
  exception when insufficient_privilege then null; end;
  begin perform public.start_reviewed_scheduled_workout(outsider, planned, original_revision);
    raise exception 'ADMIN ajeno inicia el entrenamiento del alumno.';
  exception when insufficient_privilege then null; end;
  official := public.create_admin_workout_draft(null, payload);
  private_draft := public.create_admin_workout_draft(null, payload);
  reset role;
  update public.workout_templates set visibility = 'public', status = 'published' where id = official;
  insert into public.scheduled_workouts(id, user_id, template_id, template_name, template_version, scheduled_date, source)
    values (denied_schedule, pupil, private_draft, 'Borrador ajeno no publicado', 1, current_date, 'library');

  perform set_config('request.jwt.claim.sub', pupil::text, true);
  perform set_config('request.jwt.claims', jsonb_build_object('sub', pupil, 'role', 'authenticated', 'aal', 'aal1')::text, true);
  set local role authenticated;
  begin perform public.get_scheduled_workout_preview(pupil, denied_schedule);
    raise exception 'Un propietario NULL autoriza por accidente un borrador privado.';
  exception when insufficient_privilege then null; end;
  personal := public.create_personal_workout_template(payload);
  personal_schedule := public.schedule_workout(personal, current_date);
  official_schedule := public.schedule_workout(official, current_date);
  if public.get_scheduled_workout_preview(pupil, personal_schedule)#>>'{scheduled_workout,source}' <> 'user'
    or public.get_scheduled_workout_preview(pupil, official_schedule)#>>'{scheduled_workout,source}' <> 'library' then
    raise exception 'La consulta rompe plantillas personales u oficiales.';
  end if;

  reset role;
  insert into public.exercises(name, description, muscle_groups, equipment, difficulty, exercise_type, is_public, created_by, origin)
    values ('Ejercicio ajeno secreto', 'Descripción privada ajena', array['espalda'], array['barra'],
      'intermedio', 'repeticiones', false, outsider, 'user') returning id into foreign_exercise;
  set local role authenticated;
  -- La FK por sí sola permite referenciar un UUID ajeno. El puerto de lectura
  -- debe rechazar la pauta completa, sin devolver ni omitir ese ejercicio.
  update public.workout_items set exercise_id = foreign_exercise
    where block_id in (select id from public.workout_blocks where template_id = personal);
  begin perform public.get_scheduled_workout_preview(pupil, personal_schedule);
    raise exception 'Una plantilla propia filtra un ejercicio privado ajeno.';
  exception when insufficient_privilege then null; end;
  update public.workout_items set exercise_id = exercise
    where block_id in (select id from public.workout_blocks where template_id = personal);

  -- La autoría personal admite DML directo sobre hijos con el mismo UUID y
  -- versión. Cualquier cambio entre consulta y comienzo exige revisar de nuevo.
  insert into public.exercises(name, description, muscle_groups, equipment, difficulty, exercise_type, is_public, created_by, origin)
    values ('Ejercicio propio de prueba', 'Indicación propia inicial', array['espalda'], array['barra'],
      'intermedio', 'repeticiones', false, pupil, 'user') returning id into own_exercise;
  select i.id into personal_item from public.workout_items i join public.workout_blocks b on b.id = i.block_id
    where b.template_id = personal limit 1;
  select id into personal_set from public.workout_sets where item_id = personal_item limit 1;
  fresh := public.get_scheduled_workout_preview(pupil, personal_schedule);
  personal_revision := fresh->>'revision';
  update public.workout_items set exercise_id = own_exercise where id = personal_item;
  begin perform public.start_reviewed_scheduled_workout(pupil, personal_schedule, personal_revision);
    raise exception 'Una referencia modificada no exige volver a revisar.';
  exception when serialization_failure then null; end;

  fresh := public.get_scheduled_workout_preview(pupil, personal_schedule);
  personal_revision := fresh->>'revision';
  update public.workout_sets set target_reps = 11 where id = personal_set;
  begin perform public.start_reviewed_scheduled_workout(pupil, personal_schedule, personal_revision);
    raise exception 'La dosis cambia bajo el mismo UUID sin exigir revisión.';
  exception when serialization_failure then null; end;

  fresh := public.get_scheduled_workout_preview(pupil, personal_schedule);
  personal_revision := fresh->>'revision';
  insert into public.workout_sets(item_id, order_index, target_reps, rest_after_seconds)
    values (personal_item, 1, 8, 60);
  begin perform public.start_reviewed_scheduled_workout(pupil, personal_schedule, personal_revision);
    raise exception 'Un nuevo hijo no exige revisar el entrenamiento.';
  exception when serialization_failure then null; end;

  fresh := public.get_scheduled_workout_preview(pupil, personal_schedule);
  personal_revision := fresh->>'revision';
  update public.exercises set description = 'Indicación propia revisada' where id = own_exercise;
  begin perform public.start_reviewed_scheduled_workout(pupil, personal_schedule, personal_revision);
    raise exception 'Las instrucciones cambian sin exigir revisión.';
  exception when serialization_failure then null; end;
  if (select count(*) from public.workout_executions where user_id = pupil) <> executions_before then
    raise exception 'Los rechazos de DML personal crean una ejecución.';
  end if;

  fresh := public.get_scheduled_workout_preview(pupil, personal_schedule);
  personal_revision := fresh->>'revision';
  personal_execution := public.start_reviewed_scheduled_workout(pupil, personal_schedule, personal_revision);
  if (select count(*) from public.workout_execution_sets where execution_id = personal_execution) <> 2
    or not exists (select 1 from public.workout_execution_sets where execution_id = personal_execution
      and target_reps = 11 and exercise_description = 'Indicación propia revisada') then
    raise exception 'El motor no copia el árbol personal realmente revisado.';
  end if;
  -- Verificación estructural en la misma transacción: se retienen los bloqueos
  -- de lectura de filas en todos los niveles mutables, además del catálogo.
  reset role;
  if exists (
    select 1 from unnest(array['public.workout_templates'::regclass, 'public.workout_blocks'::regclass,
      'public.workout_items'::regclass, 'public.workout_sets'::regclass, 'public.exercises'::regclass]) resource
    where not exists (select 1 from pg_locks l where l.pid = pg_backend_pid()
      and l.locktype = 'relation' and l.relation = resource and l.mode = 'RowShareLock' and l.granted)
  ) then raise exception 'El comienzo personal no conserva el cierre de filas del árbol.'; end if;
  catalog_key := hashtextextended('entrenaop:catalog:' || personal::text, 0);
  if not exists (select 1 from pg_locks l where l.pid = pg_backend_pid() and l.locktype = 'advisory'
    and l.classid::bigint = ((catalog_key >> 32) & 4294967295)
    and l.objid::bigint = (catalog_key & 4294967295)
    and l.objsubid = 1 and l.mode = 'ShareLock' and l.granted) then
    raise exception 'El comienzo personal no conserva el candado compartido de catálogo.';
  end if;
  set local role authenticated;
  executions_before := executions_before + 1;

  reset role;
  -- Fixture del mismo formato publicado por el motor, sin ejecutar el algoritmo.
  insert into public.workout_templates(name, origin, owner_user_id, visibility, status, version)
    values ('Pauta automática de prueba', 'algorithm', pupil, 'private', 'published', 1) returning id into algorithm;
  insert into public.scheduled_workouts(id, user_id, template_id, template_name, template_version, scheduled_date, source)
    values (algorithm_schedule, pupil, algorithm, 'Pauta automática de prueba', 1, current_date, 'algorithm');
  set local role authenticated;
  if public.get_scheduled_workout_preview(pupil, algorithm_schedule)#>>'{scheduled_workout,source}' <> 'algorithm' then
    raise exception 'La consulta rompe el origen automático.';
  end if;

  reset role;
  update public.scheduled_workouts set template_version = 99 where id = planned;
  set local role authenticated;
  begin perform public.get_scheduled_workout_preview(pupil, planned);
    raise exception 'Una versión incoherente se sustituye silenciosamente por la vigente.';
  exception when serialization_failure then null; end;
  reset role;
  update public.scheduled_workouts set template_version = 1 where id = planned;
  -- Defensa adicional ante una marca de archivo inconsistente con la agenda.
  update trainer_private.assignment_lifecycle set archived_at = now() where assignment_id = planned;
  set local role authenticated;
  begin perform public.get_scheduled_workout_preview(pupil, planned);
    raise exception 'Se consulta una pauta archivada.';
  exception when insufficient_privilege then null; end;
  reset role;
  update trainer_private.assignment_lifecycle set archived_at = null where assignment_id = planned;

  perform set_config('request.jwt.claim.sub', trainer::text, true);
  perform set_config('request.jwt.claims', jsonb_build_object('sub', trainer, 'role', 'authenticated', 'aal', 'aal2')::text, true);
  set local role authenticated;
  begin perform public.get_scheduled_workout_preview(trainer, planned);
    raise exception 'El autor utiliza el puerto del alumno para consultar una cita ajena.';
  exception when insufficient_privilege then null; end;
  plan := public.preview_trainer_assignment_change(planned, 0, current_date + 2, 'Nueva pauta revisada', adapted);
  perform public.change_trainer_assignment_reviewed(gen_random_uuid(), planned, 0,
    current_date + 2, 'Nueva pauta revisada', plan->>'fingerprint', adapted);

  perform set_config('request.jwt.claim.sub', pupil::text, true);
  perform set_config('request.jwt.claims', jsonb_build_object('sub', pupil, 'role', 'authenticated', 'aal', 'aal1')::text, true);
  fresh := public.get_scheduled_workout_preview(pupil, planned);
  reviewed_revision := fresh->>'revision';
  if reviewed_revision = original_revision
    or fresh#>>'{scheduled_workout,template_id}' = original::text
    or (fresh#>>'{template,workout_blocks,0,workout_items,0,workout_sets,0,target_reps}')::integer <> 20 then
    raise exception 'La consulta no refleja la adaptación explícita de la cita.';
  end if;
  begin perform public.start_reviewed_scheduled_workout(pupil, planned, original_revision);
    raise exception 'Se inicia una adaptación que el alumno todavía no vio.';
  exception when serialization_failure then null; end;
  execution := public.start_reviewed_scheduled_workout(pupil, planned, reviewed_revision);
  if public.start_reviewed_scheduled_workout(pupil, planned, reviewed_revision) <> execution then
    raise exception 'El reintento duplica una ejecución.';
  end if;
  begin perform public.start_reviewed_scheduled_workout(pupil, planned, original_revision);
    raise exception 'Una segunda pantalla obsoleta retoma otra revisión ya iniciada.';
  exception when serialization_failure then null; end;
  if public.get_scheduled_workout_preview(pupil, planned)->>'revision' <> reviewed_revision
    or (select count(*) from public.workout_executions where user_id = pupil) <> executions_before + 1
    or not exists (select 1 from public.workout_execution_sets where execution_id = execution and target_reps = 20) then
    raise exception 'El comienzo no conserva el entrenamiento revisado.';
  end if;

  fresh := public.get_scheduled_workout_preview(pupil, private_schedule);
  continuing_revision := fresh->>'revision';
  continuing_execution := public.start_reviewed_scheduled_workout(pupil, private_schedule, continuing_revision);
  select id into result_set from public.workout_execution_sets where execution_id = execution limit 1;
  perform public.complete_workout_set(result_set, p_actual_reps => 20);
  perform public.finish_workout_execution(execution, 6, 'Prueba de cambio de estado', null, null, 'manual');
  begin perform public.start_reviewed_scheduled_workout(pupil, planned, reviewed_revision);
    raise exception 'Una pantalla obsoleta vuelve a iniciar una pauta ya realizada.';
  exception when serialization_failure then null; end;
  if public.get_scheduled_workout_preview(pupil, planned)#>>'{scheduled_workout,status}' <> 'completed' then
    raise exception 'La consulta no conserva el resultado del cambio de estado.';
  end if;

  perform public.end_trainer_relation(relation);
  begin perform public.get_scheduled_workout_preview(pupil, withdrawn);
    raise exception 'La baja conserva acceso a una pauta pendiente retirada.';
  exception when insufficient_privilege then null; end;
  if public.start_reviewed_scheduled_workout(pupil, private_schedule, continuing_revision) <> continuing_execution then
    raise exception 'La baja interrumpe una ejecución propia ya iniciada.';
  end if;
  if has_function_privilege('anon', 'public.get_scheduled_workout_preview(uuid,uuid)', 'EXECUTE')
    or has_function_privilege('anon', 'public.start_reviewed_scheduled_workout(uuid,uuid,text)', 'EXECUTE') then
    raise exception 'La consulta o el inicio están concedidos a anónimos.';
  end if;
  reset role;
end;
$$;

select 'scheduled_workout_preview_read: OK' as result;
rollback;
