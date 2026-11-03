begin;

-- Terminar de entrenar y registrar todos los resultados son hechos distintos.
-- Las series sin registrar conservan su estado y sus valores ausentes.
alter table public.workout_executions
  add column completed_without_full_recording boolean not null default false,
  add constraint workout_unrecorded_completion_check check (
    not completed_without_full_recording or
    (status = 'completed' and result_source is not distinct from 'manual' and abandonment_reason is null)
  );

alter table public.workout_mutation_receipts
  drop constraint workout_mutation_receipts_kind_check,
  add constraint workout_mutation_receipts_kind_check check (
    mutation_kind in ('complete_set', 'complete_amrap', 'skip_set', 'finish', 'abandon', 'finish_unrecorded')
  );

-- La lectura respeta RLS. La autoría pública o personal no cambia el permiso:
-- lo conceden las sesiones independientes y los programas de una fase repetible.
create function public.can_finish_workout_without_full_recording(p_execution_id uuid)
returns boolean language sql stable security invoker set search_path = '' as $$
  select exists (
    select 1 from public.workout_executions e
    join public.workout_templates t on t.id = e.template_id
    where e.id = p_execution_id and e.user_id = auth.uid()
      and not exists (
        select 1 from public.scheduled_workouts s where s.execution_id = e.id
          and (s.source in ('preparation','algorithm','coach') or s.preparation_goal_id is not null)
      )
      and (
        (t.origin in ('system','user') and not exists (
          select 1 from public.guided_program_runs r where r.execution_id = e.id
        )) or exists (
          select 1 from public.guided_program_runs r
          join public.guided_program_follows f on f.id = r.follow_id and f.user_id = e.user_id
          join public.guided_programs p on p.id = f.program_id
          where r.execution_id = e.id and r.user_id = e.user_id
            and p.content->>'mode' = 'guide' and jsonb_array_length(p.content->'phases') = 1
        )
      )
  )
$$;

-- Mutación explícita: no relaja el contrato de los cierres normales ni las
-- comprobaciones Pro del inicio. El bloqueo y el recibo permiten reintentos.
create function public.finish_workout_without_full_recording_idempotent(
  p_operation_id uuid, p_execution_id uuid,
  p_performed_at timestamptz, p_utc_offset_minutes integer
)
returns void language plpgsql security definer set search_path = '' as $$
declare e public.workout_executions; receipt public.workout_mutation_receipts;
begin
  if auth.uid() is null then
    raise exception 'Debes iniciar sesión.' using errcode = '42501';
  end if;
  if p_operation_id is null or p_execution_id is null or p_performed_at is null or p_utc_offset_minutes is null then
    raise exception 'Revisa el cierre solicitado.' using errcode = '22023';
  end if;
  perform pg_advisory_xact_lock(hashtextextended(p_operation_id::text, 41));
  select * into receipt from public.workout_mutation_receipts where id = p_operation_id;
  if found then
    if receipt.user_id <> auth.uid() or receipt.resource_id <> p_execution_id
      or receipt.mutation_kind <> 'finish_unrecorded' then
      raise exception 'La operación ya pertenece a otro cierre.' using errcode = '22023';
    end if;
    return;
  end if;
  select * into e from public.workout_executions
    where id = p_execution_id and user_id = auth.uid() for update;
  if not found or not public.can_finish_workout_without_full_recording(p_execution_id) then
    raise exception 'Este cierre no está disponible para esta sesión.' using errcode = '42501';
  end if;
  if not (e.status = 'completed' and e.completed_without_full_recording) then
    if e.status <> 'in_progress' or not exists (
      select 1 from public.workout_execution_sets where execution_id = e.id and status = 'pending'
    ) then
      raise exception 'La sesión ha cambiado. Vuelve a cargarla.' using errcode = '22023';
    end if;
    perform public.set_workout_performed_clock_v1(e.id, p_performed_at, p_utc_offset_minutes);
    update public.workout_executions set status = 'completed', completed_at = now(),
      completed_without_full_recording = true, result_source = 'manual'
      where id = e.id;
  end if;
  insert into public.workout_mutation_receipts(id, user_id, mutation_kind, resource_id)
    values(p_operation_id, auth.uid(), 'finish_unrecorded', e.id);
end;
$$;

revoke all on function public.can_finish_workout_without_full_recording(uuid),
  public.finish_workout_without_full_recording_idempotent(uuid,uuid,timestamptz,integer)
  from public, anon, authenticated, service_role;
grant execute on function public.can_finish_workout_without_full_recording(uuid),
  public.finish_workout_without_full_recording_idempotent(uuid,uuid,timestamptz,integer)
  to authenticated;

notify pgrst, 'reload schema';
commit;
