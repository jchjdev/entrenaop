-- Distingue una pausa reversible de un abandono definitivo y conserva el
-- motivo como una señal estructurada para el historial y el futuro algoritmo.

begin;

alter table public.workout_executions
add column abandonment_reason text;

alter table public.workout_executions
add constraint workout_executions_abandonment_reason_check
check (
  (
    status = 'abandoned'
    and abandonment_reason in (
      'lack_of_time',
      'too_difficult',
      'discomfort',
      'other'
    )
  )
  or (status <> 'abandoned' and abandonment_reason is null)
);

create or replace function public.abandon_workout_execution(
  p_execution_id uuid,
  p_reason text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if p_reason not in (
    'lack_of_time',
    'too_difficult',
    'discomfort',
    'other'
  ) then
    raise exception 'Invalid workout abandonment reason';
  end if;

  update public.workout_executions as execution
  set
    status = 'abandoned',
    completed_at = now(),
    abandonment_reason = p_reason
  where execution.id = p_execution_id
    and execution.user_id = auth.uid()
    and execution.status = 'in_progress';

  if not found then
    raise exception 'Active workout execution not found';
  end if;
end;
$$;

revoke all on function public.abandon_workout_execution(uuid, text)
from public, anon, authenticated;
grant execute on function public.abandon_workout_execution(uuid, text)
to authenticated;

commit;
