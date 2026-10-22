begin;
-- Un cliente anterior puede leer medidas antiguas, pero no debe borrar la
-- semántica nueva al publicar una revisión. Las recetas V1 siguen admitidas.
create function public.guard_running_step_revision_v2() returns trigger
language plpgsql security definer set search_path='' as $$
begin
 if new.previous_version_id is not null and new.previous_version_id is distinct from old.previous_version_id
  and exists(select 1 from public.workout_blocks b join public.workout_items i on i.block_id=b.id
    join public.workout_sets s on s.item_id=i.id where b.template_id=new.previous_version_id and s.running_step is not null)
  and not exists(select 1 from public.workout_blocks b join public.workout_items i on i.block_id=b.id
    join public.workout_sets s on s.item_id=i.id where b.template_id=new.id and s.running_step is not null)
 then raise exception 'Actualiza el creador antes de revisar una sesión con pasos de carrera V2.' using errcode='22023';end if;
 return new;
end $$;
revoke all on function public.guard_running_step_revision_v2() from public,anon,authenticated;
create trigger guard_running_step_revision_v2 before update of previous_version_id on public.workout_templates
 for each row execute function public.guard_running_step_revision_v2();
commit;
