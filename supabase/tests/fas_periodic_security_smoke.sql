-- Prueba de integración en desarrollo para la evaluación periódica FAS.
-- Ejecutar con:
-- supabase db query --linked --file supabase/tests/fas_periodic_security_smoke.sql
-- Los perfiles, preparaciones e intentos temporales se restauran con ROLLBACK.
begin;

select set_config(
  'request.jwt.claim.sub',
  (select user_id::text from public.admin_permissions limit 1),
  true
);

update public.preparation_goals
set status = 'archived', archived_at = now()
where user_id = auth.uid() and status = 'active';

update public.profiles
set fecha_nacimiento =
  (now() at time zone 'Europe/Madrid')::date - interval '36 years'
where id = auth.uid();

insert into public.preparation_goals (user_id, program_id, target_date)
values (auth.uid(), 'fas_periodic_assessment', current_date + 30);

set local role authenticated;

do $$
declare
  v_owner uuid := auth.uid();
  v_other uuid := gen_random_uuid();
  v_goal_id uuid;
  v_other_program_goal_id uuid;
  v_assessment_id uuid;
  v_free_assessment_id uuid;
  v_other_free_assessment_id uuid;
  v_rejected boolean;
  v_marks jsonb := jsonb_build_array(
    jsonb_build_object('test_id', 'upper_body_push_ups_2_min', 'value', 20),
    jsonb_build_object('test_id', 'abdominal_plank', 'value', 60000),
    jsonb_build_object('test_id', 'run_2000_m', 'value', 700000),
    jsonb_build_object('test_id', 'agility_speed_circuit', 'value', 15000)
  );
begin
  select id into v_goal_id
  from public.preparation_goals
  where user_id = v_owner
    and program_id = 'fas_periodic_assessment'
    and status = 'active';

  v_assessment_id := public.record_fas_periodic_assessment(
    v_goal_id, 'men', 36, v_marks, now()
  );
  if (select count(*) from public.fas_periodic_results
      where assessment_id = v_assessment_id) <> 4 then
    raise exception 'La evaluación FAS no conservó sus cuatro pruebas.';
  end if;
  if not exists (
    select 1 from public.fas_periodic_assessments
    where id = v_assessment_id and is_pre_effective_reference
  ) then
    raise exception 'El intento de 2026 no quedó marcado como referencia.';
  end if;

  -- Un test libre solo entra en esta preparación tras elección explícita.
  v_free_assessment_id := public.record_fas_periodic_assessment(
    null, 'men', 36, v_marks, now()
  );
  if not exists (
    select 1 from public.fas_periodic_assessments
    where id = v_free_assessment_id and preparation_goal_id is null
  ) then
    raise exception 'El test libre se vinculó sin consentimiento.';
  end if;
  perform public.link_recent_fas_assessment_to_goal(
    v_free_assessment_id, v_goal_id
  );
  if not exists (
    select 1 from public.fas_periodic_assessments
    where id = v_free_assessment_id and preparation_goal_id = v_goal_id
  ) then
    raise exception 'No se vinculó el test libre reciente.';
  end if;
  v_rejected := false;
  begin
    perform public.link_recent_fas_assessment_to_goal(
      v_free_assessment_id, v_goal_id
    );
  exception when others then
    if sqlstate <> '22023' then raise; end if;
    v_rejected := true;
  end;
  if not v_rejected then
    raise exception 'Se permitió volver a vincular un test ya usado.';
  end if;

  -- Un test FAS no puede alimentar otro programa del mismo usuario.
  insert into public.preparation_goals (user_id, program_id, target_date)
  values (v_owner, 'armed_forces_troop_entry', current_date + 30)
  returning id into v_other_program_goal_id;
  v_other_free_assessment_id := public.record_fas_periodic_assessment(
    null, 'men', 36, v_marks, now()
  );
  v_rejected := false;
  begin
    perform public.link_recent_fas_assessment_to_goal(
      v_other_free_assessment_id, v_other_program_goal_id
    );
  exception when insufficient_privilege then
    v_rejected := true;
  end;
  if not v_rejected then
    raise exception 'Un test FAS alimentó un programa distinto de FAS.';
  end if;
  if not exists (
    select 1 from public.fas_periodic_assessments
    where id = v_other_free_assessment_id and preparation_goal_id is null
  ) then
    raise exception 'Se alteró el test FAS tras rechazar otro programa.';
  end if;

  -- La función rechaza conjuntos incompletos y edades ajenas al perfil.
  v_rejected := false;
  begin
    perform public.record_fas_periodic_assessment(
      v_goal_id,
      'men',
      36,
      v_marks - 3,
      now()
    );
  exception when others then
    if sqlstate <> '22023' then
      raise;
    end if;
    v_rejected := true;
  end;
  if not v_rejected then
    raise exception 'Se aceptó una evaluación FAS incompleta.';
  end if;

  v_rejected := false;
  begin
    perform public.record_fas_periodic_assessment(
      v_goal_id, 'men', 35, v_marks, now()
    );
  exception when others then
    if sqlstate <> '22023' then
      raise;
    end if;
    v_rejected := true;
  end;
  if not v_rejected then
    raise exception 'Se aceptó una edad distinta de la fecha de nacimiento.';
  end if;

  -- Un usuario distinto no ve el historial ni puede registrar en la
  -- preparación del propietario.
  perform set_config('request.jwt.claim.sub', v_other::text, true);
  v_rejected := false;
  begin
    perform public.link_recent_fas_assessment_to_goal(
      v_assessment_id, v_goal_id
    );
  exception when others then
    if sqlstate <> '42501' then raise; end if;
    v_rejected := true;
  end;
  if not v_rejected then
    raise exception 'Un usuario ajeno pudo vincular un test FAS.';
  end if;
  if exists (
    select 1 from public.fas_periodic_results
    where assessment_id = v_assessment_id
  ) then
    raise exception 'RLS expuso una evaluación FAS ajena.';
  end if;
  v_rejected := false;
  begin
    perform public.record_fas_periodic_assessment(
      v_goal_id, 'men', 36, v_marks, now()
    );
  exception when others then
    if sqlstate <> '42501' then
      raise;
    end if;
    v_rejected := true;
  end;
  if not v_rejected then
    raise exception 'Un usuario ajeno registró una evaluación FAS.';
  end if;
end;
$$;

-- A partir de 45 años el circuito deja de ser obligatorio y no se acepta si
-- se envía. La edad continúa derivándose de la fecha de nacimiento.
reset role;
select set_config(
  'request.jwt.claim.sub',
  (select user_id::text from public.admin_permissions limit 1),
  true
);
update public.profiles
set fecha_nacimiento =
  (now() at time zone 'Europe/Madrid')::date - interval '45 years'
where id = auth.uid();
set local role authenticated;

do $$
declare
  v_goal_id uuid;
  v_assessment_id uuid;
begin
  select id into v_goal_id
  from public.preparation_goals
  where user_id = auth.uid()
    and program_id = 'fas_periodic_assessment'
    and status = 'active';
  v_assessment_id := public.record_fas_periodic_assessment(
    v_goal_id,
    'women',
    45,
    jsonb_build_array(
      jsonb_build_object('test_id', 'upper_body_push_ups_2_min', 'value', 10),
      jsonb_build_object('test_id', 'abdominal_plank', 'value', 45000),
      jsonb_build_object('test_id', 'run_2000_m', 'value', 800000)
    ),
    now()
  );
  if (select count(*) from public.fas_periodic_results
      where assessment_id = v_assessment_id) <> 3 then
    raise exception 'La evaluación desde 45 años no conservó tres pruebas.';
  end if;
end;
$$;

rollback;
