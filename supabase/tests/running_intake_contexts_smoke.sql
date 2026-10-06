-- Captura por preparación: integridad, propietario y archivo. Todo se revierte.
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
  v_rejected boolean;
begin
  select id into v_goal from public.preparation_goals
  where user_id = auth.uid() and program_id = 'armed_forces_troop_entry'
    and status = 'active';

  insert into public.running_intake_contexts (
    preparation_goal_id, available_minutes_by_weekday,
    reserved_strength_weekdays, running_days_last_four_weeks,
    running_minutes_last_four_weeks, recent_weeks_end_on,
    reports_pain, requires_professional_review, health_observed_at
  ) values (
    v_goal, '{"1":45,"3":40,"6":60}', array[3]::smallint[],
    array[2,2,1,0]::smallint[], array[80,75,35,0],
    current_date, false, true, now()
  );
  if (select count(*) from public.running_intake_contexts
      where preparation_goal_id = v_goal) <> 1 then
    raise exception 'No se guardó el contexto propio.';
  end if;

  v_rejected := false;
  begin
    update public.running_intake_contexts
    set running_days_last_four_weeks = array[2,2,1,0]::smallint[],
        running_minutes_last_four_weeks = array[80,75,0,0]
    where preparation_goal_id = v_goal;
  exception when check_violation then v_rejected := true;
  end;
  if not v_rejected then raise exception 'Se aceptó carga contradictoria.'; end if;

  perform set_config('request.jwt.claim.sub', gen_random_uuid()::text, true);
  if exists (select 1 from public.running_intake_contexts
      where preparation_goal_id = v_goal) then
    raise exception 'Otro usuario pudo leer el contexto.';
  end if;
  update public.running_intake_contexts set reports_pain = true
  where preparation_goal_id = v_goal;
  if found then raise exception 'Otro usuario pudo editar el contexto.'; end if;

  perform set_config('request.jwt.claim.sub', v_owner, true);
  update public.preparation_goals
  set status = 'archived', archived_at = now() where id = v_goal;
  update public.running_intake_contexts set reports_pain = true
  where preparation_goal_id = v_goal;
  if found then raise exception 'Se editó una preparación archivada.'; end if;
end;
$$;

rollback;
