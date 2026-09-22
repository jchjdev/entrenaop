-- El vínculo estuvo brevemente disponible desde el cliente. Cada deportista
-- reclasifica sus propias entradas antiguas de biblioteca o personales como
-- sesiones libres al volver a cargar la agenda. Las prescripciones futuras del
-- algoritmo o de un entrenador conservan siempre su vínculo oficial.

begin;

create function public.cleanup_own_legacy_preparation_links()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  affected_rows integer;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  update public.scheduled_workouts as scheduled
  set preparation_goal_id = null
  where scheduled.user_id = auth.uid()
    and scheduled.preparation_goal_id is not null
    and scheduled.source in ('library', 'user');

  get diagnostics affected_rows = row_count;
  return affected_rows;
end;
$$;

revoke all on function public.cleanup_own_legacy_preparation_links()
from public, anon;
grant execute on function public.cleanup_own_legacy_preparation_links()
to authenticated;

commit;
