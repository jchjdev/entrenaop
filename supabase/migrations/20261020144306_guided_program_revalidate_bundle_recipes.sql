-- UI-062: una receta en borrador puede cambiar después de guardar el montaje.
-- Validar al activar el programa revierte también la publicación de sus sesiones.
create function public.validate_guided_bundle_activation()
returns trigger language plpgsql security definer set search_path='' as $$
declare link record; slot jsonb;
begin
  if new.status='published' and old.status<>'published' then
    for link in select * from public.guided_program_links where program_id=new.id loop
      slot:=new.content->'phases'->link.phase_index->'sessions'->link.session_index;
      if link.warmup_id is not null and exists(
        select 1 from public.workout_blocks where template_id=link.template_id and format='warm_up'
      ) then
        raise exception 'Una sesión ya contiene calentamiento. Quita el calentamiento adjunto antes de publicar.' using errcode='22023';
      end if;
      if slot->'rest'->>'min_seconds' is not null and not exists(
        select 1 from public.workout_blocks where template_id=link.template_id and format='straight_sets'
      ) then
        raise exception 'Una sesión ya no admite el ajuste genérico de descanso. Revisa el programa antes de publicar.' using errcode='22023';
      end if;
    end loop;
  end if;
  return new;
end $$;
revoke all on function public.validate_guided_bundle_activation() from public,anon,authenticated;
create trigger validate_guided_bundle_activation
before update of status on public.guided_programs
for each row execute function public.validate_guided_bundle_activation();
