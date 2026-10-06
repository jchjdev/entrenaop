-- Biblioteca operativa completa y lectura sin dependencia de un programa.
begin;
select set_config('test.library_user_id',(select id::text from auth.users u
  where not exists(select 1 from public.admin_permissions a where a.user_id=u.id) limit 1),true);

do $$
declare v_exercise public.exercises%rowtype;
begin
  if exists(select 1 from public.exercise_training_profiles p
    where p.catalog_version in (1,2) and p.definition_version=1 and (
      select count(*) from public.exercises e where e.training_profile_code=p.code
        and e.training_profile_version=p.definition_version
        and e.origin='system' and e.created_by is null and e.is_public)<>1) then
    raise exception 'Cada una de las 63 variantes debe tener un ejercicio oficial visible.';
  end if;
  for v_exercise in select e.* from public.exercises e
    join public.exercise_training_profiles p on p.code=e.training_profile_code
      and p.definition_version=e.training_profile_version
    where p.catalog_version in (1,2) and p.definition_version=1 loop
    perform public.normalize_exercise_draft(v_exercise.name,v_exercise.description,v_exercise.video_url,
      v_exercise.muscle_groups,v_exercise.equipment,v_exercise.difficulty,v_exercise.exercise_type);
  end loop;
  if (select id from public.exercises where training_profile_code='push_up_standard')
      <> '20000000-0000-4000-8000-000000000001'::uuid
    or (select id from public.exercises where training_profile_code='front_plank_forearms')
      <> '20000000-0000-4000-8000-000000000002'::uuid
    or (select id from public.exercises where training_profile_code='squat_bodyweight')
      <> '20000000-0000-4000-8000-000000000003'::uuid then
    raise exception 'La carga duplicó o sustituyó las identidades existentes.';
  end if;
end $$;

-- Retirar los enlaces de borradores no retira ejercicios ni definiciones.
delete from public.program_test_training_bindings b using public.preparation_programs p
where p.id=b.program_id and not p.enabled;
set local role authenticated;
select set_config('request.jwt.claim.sub',current_setting('test.library_user_id'),true);
do $$
begin
  if coalesce(current_setting('test.library_user_id'),'')='' then
    raise exception 'La prueba necesita un deportista sin permisos administrativos.'; end if;
  if (select count(*) from public.exercises e
    join public.exercise_training_profiles p on p.code=e.training_profile_code
      and p.definition_version=e.training_profile_version
    where p.catalog_version=1 and p.definition_version=1 and e.origin='system' and e.is_public)<>63 then
    raise exception 'La RLS impide resolver las 63 variantes desde la biblioteca general.';
  end if;
  if exists(select 1 from public.exercises e
    where e.training_profile_code is not null and not e.is_public and e.created_by is null) then
    raise exception 'La biblioteca expone un ejercicio oficial privado.';
  end if;
  if not exists(select 1 from public.exercises where training_profile_code='slalom_ball_course_16m' and is_public and origin='system') then raise exception 'No se lee el circuito específico nuevo'; end if;
  if not exists(select 1 from public.exercises where training_profile_code='bench_press_barbell'
      and equipment @> array['barra','banco'] and muscle_groups @> array['pecho']) then
    raise exception 'La biblioteca perdió los campos editoriales del press banca.'; end if;
end $$;
rollback;
