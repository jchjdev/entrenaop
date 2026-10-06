-- Aislamiento por preparación y propietario. Toda escritura se revierte.
begin;

select set_config('request.jwt.claim.sub',
  (select user_id::text from public.admin_permissions limit 1), true);

update public.preparation_goals
set status = 'archived', archived_at = now()
where user_id = auth.uid() and status = 'active';

insert into public.preparation_goals (user_id, program_id, target_date)
values (auth.uid(), 'armed_forces_troop_entry', current_date + 30);

set local role authenticated;

do $$
declare
  v_owner text := current_setting('request.jwt.claim.sub');
  v_goal uuid;
  v_other uuid := gen_random_uuid();
begin
  select id into v_goal from public.preparation_goals
  where user_id = auth.uid() and program_id = 'armed_forces_troop_entry'
    and status = 'active';

  insert into public.running_reference_selections (
    preparation_goal_id, reference_source, reference_record_id,
    selected_at, continuity_confirmed_at
  ) values (
    v_goal, 'troopControl', gen_random_uuid()::text, now(), now()
  );

  if (select count(*) from public.running_reference_selections
      where preparation_goal_id = v_goal) <> 1 then
    raise exception 'No se guardó la selección propia.';
  end if;

  perform set_config('request.jwt.claim.sub', v_other::text, true);
  if exists (select 1 from public.running_reference_selections
      where preparation_goal_id = v_goal) then
    raise exception 'Otro usuario pudo leer la selección.';
  end if;
  update public.running_reference_selections
  set reference_record_id = gen_random_uuid()::text
  where preparation_goal_id = v_goal;
  if found then raise exception 'Otro usuario pudo modificar la selección.'; end if;
  delete from public.running_reference_selections
  where preparation_goal_id = v_goal;
  if found then raise exception 'Otro usuario pudo borrar la selección.'; end if;

  perform set_config('request.jwt.claim.sub', v_owner, true);
  update public.preparation_goals
  set status = 'archived', archived_at = now() where id = v_goal;
  update public.running_reference_selections
  set reference_record_id = gen_random_uuid()::text
  where preparation_goal_id = v_goal;
  if found then raise exception 'Se modificó una selección archivada.'; end if;
  delete from public.running_reference_selections
  where preparation_goal_id = v_goal;
  if found then raise exception 'Se borró una selección archivada.'; end if;
end;
$$;

rollback;
