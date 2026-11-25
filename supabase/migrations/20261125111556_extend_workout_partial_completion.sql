begin;

-- La procedencia de la ejecución prevalece sobre la plantilla reutilizada.
-- Un cierre ya autorizado conserva el permiso aunque se deje el programa.
create or replace function public.can_finish_workout_without_full_recording(p_execution_id uuid)
returns boolean language sql stable security invoker set search_path = '' as $$
  select exists (
    select 1
    from public.workout_executions e
    join public.workout_templates t on t.id = e.template_id
    where e.id = p_execution_id and e.user_id = auth.uid()
      and (e.completed_without_full_recording or (
        not exists (
          select 1 from public.scheduled_workouts s
          where (s.execution_id = e.id or s.repeat_execution_id = e.id)
            and (s.source in ('preparation', 'algorithm') or s.preparation_goal_id is not null)
        )
        and (t.origin in ('system', 'user', 'coach') or exists (
          select 1 from public.guided_program_runs r
          join public.guided_program_follows f on f.id = r.follow_id and f.user_id = e.user_id
          where r.execution_id = e.id and r.user_id = e.user_id
        ))
      ))
  )
$$;

-- Se reutilizan las validaciones deportivas y los recibos existentes. Solo
-- se amplía dónde puede registrarse un resultado manual todavía pendiente.
do $migration$
declare change record; definition text;
begin
  for change in select * from (values
    ('public.finish_workout_without_full_recording_idempotent(uuid,uuid,timestamptz,integer)'::regprocedure,
     $old$if e.status <> 'in_progress' or not exists (
      select 1 from public.workout_execution_sets where execution_id = e.id and status = 'pending'
    ) then$old$,
     $new$if e.status <> 'in_progress' then$new$),
    ('public.complete_workout_set(uuid,integer,integer,numeric,numeric,numeric,numeric,integer,numeric,text)'::regprocedure,
     $old$and execution.status = 'in_progress'$old$,
     $new$and (execution.status = 'in_progress' or (
      execution.status = 'completed' and execution.completed_without_full_recording
      and p_result_source = 'manual'
      and public.can_finish_workout_without_full_recording(execution.id)
    ))$new$),
    ('public.complete_performance_set_idempotent(uuid,uuid,jsonb)'::regprocedure,
     $old$where id=s.execution_id and status='in_progress'$old$,
     $new$where id=s.execution_id and (status='in_progress' or (
      status='completed' and completed_without_full_recording
      and public.can_finish_workout_without_full_recording(id)
    ))$new$),
    ('public.complete_amrap_block_idempotent(uuid,uuid,integer,integer,integer,integer)'::regprocedure,
     $old$if v_status <> 'in_progress' or p_block_order is distinct from (
      select min(s.block_order) from public.workout_execution_sets s
      where s.execution_id=p_execution_id and s.status='pending'
    ) or not exists ($old$,
     $new$if not (
      (v_status = 'in_progress' and p_block_order = (
        select min(s.block_order) from public.workout_execution_sets s
        where s.execution_id=p_execution_id and s.status='pending'
      )) or (v_status = 'completed' and exists (
        select 1 from public.workout_executions e where e.id=p_execution_id
          and e.completed_without_full_recording
          and public.can_finish_workout_without_full_recording(e.id)
      ))
    ) or not exists ($new$)
  ) as changes(signature, old_text, new_text)
  loop
    definition := pg_get_functiondef(change.signature);
    if strpos(definition, change.old_text) = 0 then
      raise exception 'Revisar el contrato de cierre parcial en %', change.signature;
    end if;
    execute replace(definition, change.old_text, change.new_text);
  end loop;
end;
$migration$;

notify pgrst, 'reload schema';
commit;
