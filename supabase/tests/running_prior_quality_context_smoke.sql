-- La experiencia declarada no debe convertirse en ejecución verificada.
begin;

select set_config('request.jwt.claim.sub',
  (select user_id::text from public.admin_permissions limit 1), true);

update public.preparation_goals set status='archived', archived_at=now()
where user_id=auth.uid() and status='active';
insert into public.preparation_goals(user_id, program_id, target_date)
values(auth.uid(),'armed_forces_troop_entry',current_date+30);
set local role authenticated;

do $$
declare
  g uuid;
  refused boolean := false;
begin
  select id into g from public.preparation_goals
  where user_id=auth.uid() and status='active' and program_id='armed_forces_troop_entry';
  insert into public.running_intake_contexts(
    preparation_goal_id,context_version,available_minutes_by_weekday,
    running_days_last_four_weeks,running_minutes_last_four_weeks,
    quality_weeks_last_four,recent_weeks_end_on,reports_pain,
    requires_professional_review,health_observed_at,
    comfortable_continuous_minutes
  ) values (
    g,'running_initial_context_v3','{"1":45,"3":45,"6":45}',
    array[3,3,2,0]::smallint[],array[120,110,70,0],
    2,current_date,false,false,now(),45
  );
  if (select quality_weeks_last_four from public.running_intake_contexts
      where preparation_goal_id=g)<>2 then
    raise exception 'No se conserva la experiencia declarada';
  end if;
  begin
    update public.running_intake_contexts set quality_weeks_last_four=4
    where preparation_goal_id=g;
  exception when check_violation then refused:=true;
  end;
  if not refused then raise exception 'Se aceptó más calidad que semanas corridas'; end if;
end $$;

rollback;
