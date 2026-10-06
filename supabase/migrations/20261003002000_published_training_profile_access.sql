-- Un enlace publicado debe permitir leer también su definición deportiva.
begin;

create index program_test_training_bindings_profile_idx
on public.program_test_training_bindings(profile_code,profile_version,program_id);

alter policy exercise_training_profiles_read on public.exercise_training_profiles
using (
  (select public.is_admin())
  or exists (
    select 1 from public.exercises e
    where e.training_profile_code=exercise_training_profiles.code
      and e.training_profile_version=exercise_training_profiles.definition_version
      and e.origin='system' and e.is_public
  )
  or exists (
    select 1 from public.program_test_training_bindings b
    join public.preparation_programs p on p.id=b.program_id
    where b.profile_code=exercise_training_profiles.code
      and b.profile_version=exercise_training_profiles.definition_version
      and p.enabled
  )
);

commit;
