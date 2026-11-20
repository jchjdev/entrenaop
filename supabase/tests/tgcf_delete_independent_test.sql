-- Prueba de permisos y borrado con datos efímeros. Solo Dev.
begin;

do $$
declare
  athlete uuid := gen_random_uuid();
  outsider uuid := gen_random_uuid();
  goal_id uuid;
  revision_id uuid;
  independent_id uuid;
  linked_id uuid;
  sibling_id uuid;
  linked_before jsonb;
  test_marks jsonb := '[{"test_id":"upper_body_push_ups_2_min","value":20},{"test_id":"abdominal_plank","value":60000},{"test_id":"run_2000_m","value":700000},{"test_id":"agility_speed_circuit","value":15800}]';
begin
  if has_function_privilege('anon', 'public.delete_independent_fas_assessment(uuid)', 'execute')
    or has_function_privilege('anon', 'builtin_assessment_private.delete_independent_fas_assessment(uuid)', 'execute')
    or has_table_privilege('authenticated', 'public.fas_periodic_assessments', 'delete')
    or has_table_privilege('authenticated', 'public.fas_periodic_marks', 'delete') then
    raise exception 'El borrado admite acceso anónimo o directo a las tablas.';
  end if;

  insert into auth.users(id, email) values
    (athlete, athlete || '@tgcf-delete.invalid'),
    (outsider, outsider || '@tgcf-delete.invalid');
  update public.profiles
  set fecha_nacimiento = current_date - interval '36 years 1 month'
  where id = athlete;
  insert into public.preparation_goals(user_id, program_id, target_date)
  values (athlete, 'fas_periodic_assessment', current_date + 30)
  returning id into goal_id;

  perform set_config('request.jwt.claim.sub', '', true);
  perform set_config('request.jwt.claims', '{}', true);
  set local role authenticated;
  begin
    perform public.delete_independent_fas_assessment(gen_random_uuid());
    raise exception 'Se permitió la operación sin sesión.';
  exception when insufficient_privilege then
    null;
  end;

  perform set_config('request.jwt.claim.sub', athlete::text, true);
  revision_id := (public.builtin_assessment_reference('fas_periodic_assessment')->>'id')::uuid;
  independent_id := public.record_builtin_assessment(revision_id, null, 'men', 36, null, test_marks, now(), 'literal_rows_v2');
  linked_id := public.record_builtin_assessment(revision_id, null, 'men', 36, null, test_marks, now(), 'literal_rows_v2');
  sibling_id := public.record_builtin_assessment(revision_id, null, 'men', 36, null, test_marks, now(), 'literal_rows_v2');
  perform public.link_recent_fas_assessment_to_goal(linked_id, goal_id);
  select jsonb_agg(to_jsonb(r) order by r.test_id) into strict linked_before
  from public.fas_periodic_results r where r.assessment_id = linked_id;
  if jsonb_array_length(linked_before) is distinct from 4 then
    raise exception 'Falta el test asociado que se debe conservar.';
  end if;

  perform set_config('request.jwt.claim.sub', outsider::text, true);
  if public.delete_independent_fas_assessment(independent_id) is distinct from false then
    raise exception 'Otra cuenta eliminó un test ajeno.';
  end if;

  perform set_config('request.jwt.claim.sub', athlete::text, true);
  if public.delete_independent_fas_assessment(linked_id) is distinct from false then
    raise exception 'Se borró un test asociado después de guardarlo.';
  end if;
  if public.delete_independent_fas_assessment(independent_id) is distinct from true then
    raise exception 'El titular no pudo borrar su test independiente.';
  end if;
  if public.delete_independent_fas_assessment(independent_id) is distinct from false then
    raise exception 'El reintento devolvió otro borrado.';
  end if;

  reset role;
  if exists (select 1 from public.fas_periodic_assessments where id = independent_id)
    or exists (select 1 from public.fas_periodic_marks where assessment_id = independent_id)
    or (select count(*) from public.fas_periodic_marks where assessment_id = sibling_id) <> 4
    or (select jsonb_agg(to_jsonb(r) order by r.test_id) from public.fas_periodic_results r
        where r.assessment_id = linked_id) is distinct from linked_before then
    raise exception 'El borrado no se limitó a un test y a sus marcas.';
  end if;
end $$;

select 'TGCF: titular, permisos, asociación, cascada y reintento verificados' as resultado;
rollback;
