-- Recibos idempotentes para poder reintentar operaciones guardadas sin
-- duplicarlas cuando la conexión se corta después de confirmar en PostgreSQL.

begin;

create table public.workout_mutation_receipts (
  id uuid primary key,
  user_id uuid not null references public.profiles (id) on delete cascade,
  mutation_kind text not null,
  resource_id uuid not null,
  created_at timestamptz not null default now(),
  constraint workout_mutation_receipts_kind_check
    check (mutation_kind in ('complete_set', 'skip_set', 'finish', 'abandon'))
);

create index workout_mutation_receipts_user_created_idx
  on public.workout_mutation_receipts (user_id, created_at desc);

alter table public.workout_mutation_receipts enable row level security;
revoke all on table public.workout_mutation_receipts from anon, authenticated;
grant select on table public.workout_mutation_receipts to authenticated;

create policy workout_mutation_receipts_select_own
on public.workout_mutation_receipts
for select
to authenticated
using (user_id = (select auth.uid()) or (select public.is_admin()));

create or replace function public.complete_workout_set_idempotent(
  p_operation_id uuid,
  p_result_id uuid,
  p_actual_reps integer default null,
  p_actual_duration_seconds integer default null,
  p_actual_distance_meters numeric default null,
  p_actual_load_kg numeric default null,
  p_actual_rpe numeric default null,
  p_actual_rir numeric default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if exists (
    select 1 from public.workout_mutation_receipts
    where id = p_operation_id and user_id = auth.uid()
      and mutation_kind = 'complete_set' and resource_id = p_result_id
  ) then return; end if;

  perform public.complete_workout_set(
    p_result_id,
    p_actual_reps,
    p_actual_duration_seconds,
    p_actual_distance_meters,
    p_actual_load_kg,
    p_actual_rpe,
    p_actual_rir
  );
  insert into public.workout_mutation_receipts
    (id, user_id, mutation_kind, resource_id)
  values (p_operation_id, auth.uid(), 'complete_set', p_result_id);
end;
$$;

create or replace function public.skip_workout_set_idempotent(
  p_operation_id uuid,
  p_result_id uuid
)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if exists (
    select 1 from public.workout_mutation_receipts
    where id = p_operation_id and user_id = auth.uid()
      and mutation_kind = 'skip_set' and resource_id = p_result_id
  ) then return; end if;
  perform public.skip_workout_set(p_result_id);
  insert into public.workout_mutation_receipts
    (id, user_id, mutation_kind, resource_id)
  values (p_operation_id, auth.uid(), 'skip_set', p_result_id);
end;
$$;

create or replace function public.finish_workout_execution_idempotent(
  p_operation_id uuid,
  p_execution_id uuid,
  p_final_rpe integer,
  p_notes text default null
)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if exists (
    select 1 from public.workout_mutation_receipts
    where id = p_operation_id and user_id = auth.uid()
      and mutation_kind = 'finish' and resource_id = p_execution_id
  ) then return; end if;
  perform public.finish_workout_execution(p_execution_id, p_final_rpe, p_notes);
  insert into public.workout_mutation_receipts
    (id, user_id, mutation_kind, resource_id)
  values (p_operation_id, auth.uid(), 'finish', p_execution_id);
end;
$$;

create or replace function public.abandon_workout_execution_idempotent(
  p_operation_id uuid,
  p_execution_id uuid,
  p_reason text
)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if exists (
    select 1 from public.workout_mutation_receipts
    where id = p_operation_id and user_id = auth.uid()
      and mutation_kind = 'abandon' and resource_id = p_execution_id
  ) then return; end if;
  perform public.abandon_workout_execution(p_execution_id, p_reason);
  insert into public.workout_mutation_receipts
    (id, user_id, mutation_kind, resource_id)
  values (p_operation_id, auth.uid(), 'abandon', p_execution_id);
end;
$$;

revoke all on function public.complete_workout_set_idempotent(
  uuid, uuid, integer, integer, numeric, numeric, numeric, numeric
) from public, anon, authenticated;
revoke all on function public.skip_workout_set_idempotent(uuid, uuid)
from public, anon, authenticated;
revoke all on function public.finish_workout_execution_idempotent(
  uuid, uuid, integer, text
) from public, anon, authenticated;
revoke all on function public.abandon_workout_execution_idempotent(
  uuid, uuid, text
) from public, anon, authenticated;

grant execute on function public.complete_workout_set_idempotent(
  uuid, uuid, integer, integer, numeric, numeric, numeric, numeric
) to authenticated;
grant execute on function public.skip_workout_set_idempotent(uuid, uuid)
to authenticated;
grant execute on function public.finish_workout_execution_idempotent(
  uuid, uuid, integer, text
) to authenticated;
grant execute on function public.abandon_workout_execution_idempotent(
  uuid, uuid, text
) to authenticated;

commit;
