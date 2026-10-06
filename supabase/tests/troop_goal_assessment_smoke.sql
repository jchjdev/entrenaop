-- Registro de las cuatro marcas dentro de una preparación de Tropa.
-- No asocia registros anteriores ni deja datos después de ROLLBACK.
begin;

select set_config('request.jwt.claim.sub',
  (select user_id::text from public.admin_permissions limit 1), true);

update public.preparation_goals
set status = 'archived', archived_at = now()
where user_id = auth.uid() and status = 'active';

insert into public.preparation_goals (user_id,program_id,target_date)
values (auth.uid(),'armed_forces_troop_entry',current_date + 30);

set local role authenticated;

do $$
declare
  v_owner text := current_setting('request.jwt.claim.sub');
  v_goal uuid;
  v_linked uuid;
  v_global uuid;
  v_rejected boolean := false;
  v_marks jsonb := '[
    {"test_id":"upper_body_push_ups_2_min","value":10},
    {"test_id":"abdominal_plank","value":45000},
    {"test_id":"run_2000_m","value":470000},
    {"test_id":"agility_speed_circuit","value":16000}
  ]'::jsonb;
begin
  select id into v_goal from public.preparation_goals
  where user_id = auth.uid() and program_id = 'armed_forces_troop_entry'
    and status = 'active';
  v_global := public.record_physical_assessment(
    'es_def_15_2026_troop_v1','men','entry',v_marks,now());
  v_linked := public.record_troop_goal_assessment(
    v_goal,'es_def_15_2026_troop_v1','men',v_marks,now());
  if (select count(*) from public.physical_assessment_results
      where preparation_goal_id = v_goal) <> 4 then
    raise exception 'La preparación no muestra exactamente sus cuatro marcas.';
  end if;
  if exists (select 1 from public.physical_assessment_results
      where assessment_id = v_global and preparation_goal_id is not null) then
    raise exception 'Un registro general se asoció automáticamente.';
  end if;
  if not exists (select 1 from public.physical_assessment_results
      where assessment_id = v_linked and preparation_goal_id = v_goal) then
    raise exception 'No se guardó el vínculo de la evaluación.';
  end if;

  perform set_config('request.jwt.claim.sub', gen_random_uuid()::text, true);
  begin
    perform public.record_troop_goal_assessment(
      v_goal,'es_def_15_2026_troop_v1','men',v_marks,now());
  exception when sqlstate '42501' then v_rejected := true;
  end;
  if not v_rejected then
    raise exception 'Otro usuario pudo escribir en la preparación.';
  end if;
  if exists (select 1 from public.physical_assessment_results
      where preparation_goal_id = v_goal) then
    raise exception 'RLS expuso la evaluación de otro usuario.';
  end if;
  perform set_config('request.jwt.claim.sub', v_owner, true);
end;
$$;

rollback;
