-- Prueba de integración en desarrollo para Carrera V1.
-- Ejecutar con:
-- supabase db query --linked --file supabase/tests/running_security_smoke.sql
-- Toda la preparación, sesión, ejecución y marcas temporales se revierten.
begin;

select set_config(
  'request.jwt.claim.sub',
  (select user_id::text from public.admin_permissions limit 1),
  true
);

-- La prueba reutiliza un perfil administrativo real, pero restaura mediante
-- ROLLBACK cualquier preparación que archive temporalmente.
update public.preparation_goals
set status = 'archived', archived_at = now()
where user_id = auth.uid() and status = 'active';

insert into public.preparation_goals (user_id, program_id, target_date)
values (auth.uid(), 'armed_forces_troop_entry', current_date + 30);

set local role authenticated;

do $$
declare
  v_owner uuid := auth.uid();
  v_other uuid := gen_random_uuid();
  v_goal_id uuid;
  v_template_id uuid;
  v_execution_id uuid;
  v_result_id uuid;
  v_running_test_id uuid;
  v_rejected boolean;
begin
  select id into v_goal_id
  from public.preparation_goals
  where user_id = v_owner
    and program_id = 'armed_forces_troop_entry'
    and status = 'active';

  v_template_id := public.create_personal_workout_template(
    jsonb_build_object(
      'name', 'Comprobación temporal de resultados de carrera',
      'estimated_duration_minutes', 20,
      'blocks', jsonb_build_array(jsonb_build_object(
        'name', 'Carrera',
        'format', 'running',
        'rounds', 1,
        'rest_after_seconds', 0,
        'exercises', jsonb_build_array(jsonb_build_object(
          'exercise_id', '20000000-0000-4000-8000-000000000004',
          'sets', jsonb_build_array(jsonb_build_object(
            'target_distance_meters', 400,
            'target_pace_min_seconds_per_km', 240,
            'target_pace_max_seconds_per_km', 260,
            'recovery_type', 'passive',
            'recovery_duration_seconds', 60,
            'rest_after_seconds', 0
          ))
        ))
      ))
    )
  );
  v_execution_id := public.start_workout_execution(v_template_id);
  select id into v_result_id
  from public.workout_execution_sets
  where execution_id = v_execution_id;

  -- Otro usuario no puede leer ni completar la ejecución del propietario.
  perform set_config('request.jwt.claim.sub', v_other::text, true);
  if exists (
    select 1 from public.workout_executions where id = v_execution_id
  ) then
    raise exception 'RLS expuso una ejecución de carrera ajena.';
  end if;
  v_rejected := false;
  begin
    perform public.complete_workout_set(
      p_result_id => v_result_id,
      p_actual_duration_seconds => 95,
      p_actual_distance_meters => 400,
      p_actual_recovery_duration_seconds => 60
    );
  exception when others then
    if sqlerrm <> 'Pending workout set not found' then
      raise;
    end if;
    v_rejected := true;
  end;
  if not v_rejected then
    raise exception 'Un usuario ajeno completó un tramo de carrera.';
  end if;

  perform set_config('request.jwt.claim.sub', v_owner::text, true);

  -- Un tramo con recuperación prescrita no se completa sin su resultado real.
  v_rejected := false;
  begin
    perform public.complete_workout_set(
      p_result_id => v_result_id,
      p_actual_duration_seconds => 95,
      p_actual_distance_meters => 400
    );
  exception when others then
    if sqlerrm <> 'Actual recovery duration is required' then
      raise;
    end if;
    v_rejected := true;
  end;
  if not v_rejected then
    raise exception 'Se aceptó una carrera sin la recuperación obligatoria.';
  end if;

  perform public.complete_workout_set(
    p_result_id => v_result_id,
    p_actual_duration_seconds => 95,
    p_actual_distance_meters => 400,
    p_actual_recovery_duration_seconds => 60,
    p_result_source => 'manual'
  );
  if not exists (
    select 1 from public.workout_execution_sets
    where id = v_result_id
      and status = 'completed'
      and actual_duration_seconds = 95
      and actual_distance_meters = 400
      and actual_recovery_duration_seconds = 60
      and result_source = 'manual'
  ) then
    raise exception 'El resultado completo de carrera no se conservó.';
  end if;

  -- La FC máxima no puede ser menor que la media.
  v_rejected := false;
  begin
    perform public.finish_workout_execution(
      v_execution_id, 7, null, 170, 160, 'manual'
    );
  exception when others then
    if sqlerrm <> 'Heart rate values are invalid' then
      raise;
    end if;
    v_rejected := true;
  end;
  if not v_rejected then
    raise exception 'Se aceptó una frecuencia cardíaca incoherente.';
  end if;
  perform public.finish_workout_execution(
    v_execution_id, 7, 'Comprobación temporal', 160, 175, 'manual'
  );

  insert into public.preparation_running_tests (
    user_id, preparation_goal_id, duration_seconds, rpe,
    average_hr_bpm, max_hr_bpm, splits_seconds
  ) values (
    v_owner, v_goal_id, 600, 8, 165, 182,
    array[120, 120, 120, 120, 120]
  ) returning id into v_running_test_id;

  -- Los parciales deben sumar exactamente el tiempo total.
  v_rejected := false;
  begin
    insert into public.preparation_running_tests (
      user_id, preparation_goal_id, duration_seconds, rpe, splits_seconds
    ) values (
      v_owner, v_goal_id, 600, 8, array[100, 100, 100, 100, 100]
    );
  exception when others then
    if sqlstate <> '23514' then
      raise;
    end if;
    v_rejected := true;
  end;
  if not v_rejected then
    raise exception 'Se aceptaron parciales que no suman el tiempo total.';
  end if;

  -- Un usuario distinto no ve el control ni puede asociarlo a la preparación.
  perform set_config('request.jwt.claim.sub', v_other::text, true);
  if exists (
    select 1 from public.preparation_running_tests
    where id = v_running_test_id
  ) then
    raise exception 'RLS expuso un control de carrera ajeno.';
  end if;
  v_rejected := false;
  begin
    insert into public.preparation_running_tests (
      user_id, preparation_goal_id, duration_seconds, rpe
    ) values (v_other, v_goal_id, 600, 8);
  exception when others then
    if sqlstate <> '42501' then
      raise;
    end if;
    v_rejected := true;
  end;
  if not v_rejected then
    raise exception 'Un usuario ajeno escribió en otra preparación.';
  end if;
end;
$$;

rollback;
