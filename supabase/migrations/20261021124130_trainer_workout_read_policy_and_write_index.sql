begin;
create index workout_writes_template on trainer_private.workout_writes(template_id);
alter table public.workout_templates add constraint trainer_workout_visibility check(origin<>'coach' or visibility='private');

-- Una sola política permisiva por rol/lectura, conservando el catálogo anónimo
-- y la frontera restrictiva profesional añadida en la migración anterior.
alter policy workout_templates_select_public on public.workout_templates to anon
 using(origin<>'coach' and visibility='public' and status='published');
drop policy workout_templates_select_owned_or_admin on public.workout_templates;
drop policy trainer_template_read on public.workout_templates;
create policy workout_templates_select_accessible on public.workout_templates for select to authenticated
 using((origin='coach' and trainer_private.can_read_coach_template(id)) or
   (origin<>'coach' and ((visibility='public' and status='published')
    or owner_user_id=(select auth.uid()) or (select public.is_admin()))));
commit;
