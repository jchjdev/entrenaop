-- Tipo histórico al iniciar: una edición posterior no reinterpreta la sesión.
begin;

alter table public.workout_executions
  add column session_type text,
  add column session_type_policy text,
  add constraint workout_execution_session_type_snapshot_check check (
    (session_type is null and session_type_policy is null)
    or (
      session_type is not null and session_type in ('running', 'strength', 'mixed')
      and session_type_policy is not null
      and session_type_policy = 'block_format_v1'
    )
  );

comment on column public.workout_executions.session_type is
  'Tipo copiado en servidor al iniciar. NULL conserva el historial anterior sin reclasificarlo.';
comment on column public.workout_executions.session_type_policy is
  'block_format_v1: bloques running y otros bloques de trabajo; excluye warm_up y cool_down de la combinación.';

create function public.snapshot_workout_execution_session_type() returns trigger
language plpgsql set search_path = '' as $$
declare has_running boolean; has_other_work boolean;
begin
  if tg_op = 'INSERT' then
    select coalesce(bool_or(b.format = 'running'), false),
      coalesce(bool_or(b.format not in ('running', 'warm_up', 'cool_down')), false)
    into has_running, has_other_work
    from public.workout_blocks b where b.template_id = new.template_id;
    -- Acondicionamiento es la familia general ya utilizada en Biblioteca.
    new.session_type := case
      when has_running and has_other_work then 'mixed'
      when has_running then 'running'
      else 'strength'
    end;
    new.session_type_policy := 'block_format_v1';
  elsif new.session_type is distinct from old.session_type
    or new.session_type_policy is distinct from old.session_type_policy then
    raise exception 'El tipo histórico de una ejecución es inmutable.';
  end if;
  return new;
end $$;

create trigger snapshot_workout_execution_session_type before insert or update
on public.workout_executions for each row
execute function public.snapshot_workout_execution_session_type();
revoke all on function public.snapshot_workout_execution_session_type()
  from public, anon, authenticated;

create index workout_executions_user_type_history_idx
  on public.workout_executions(user_id, session_type, started_at desc, id desc)
  where status <> 'in_progress';

commit;
