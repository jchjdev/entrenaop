begin;
-- Conserva la lectura pública anónima y evalúa una sola política permisiva
-- autenticada. La frontera restrictiva profesional continúa siendo obligatoria.
alter policy exercises_select_public on public.exercises to anon using(is_public is true);
drop policy exercises_select_own on public.exercises;
drop policy trainer_exercise_read on public.exercises;
create policy exercises_select_accessible on public.exercises for select to authenticated
 using((origin='coach' and trainer_private.can_read_exercise(id)) or
  (origin<>'coach' and (is_public is true or created_by=(select auth.uid()) or (select public.is_admin()))));
commit;
