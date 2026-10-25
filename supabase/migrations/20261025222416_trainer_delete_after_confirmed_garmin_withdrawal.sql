begin;

-- Un vínculo histórico no es una operación viva. Se conserva su recibo aunque
-- se elimine la cita, pero solo una retirada remota confirmada permite hacerlo.
create or replace function trainer_private.assignment_delete_block(p_id uuid) returns text
language plpgsql stable security definer set search_path='' as $$
declare s public.scheduled_workouts;a public.trainer_assignments;
begin
 select * into a from public.trainer_assignments where scheduled_id=p_id;
 select * into s from public.scheduled_workouts where id=p_id;
 if a.scheduled_id is null or s.id is null then return 'missing';end if;
 if s.execution_id is not null or a.result_revision>0
  or exists(select 1 from trainer_private.assignment_reviews where assignment_id=p_id)
  or exists(select 1 from trainer_private.review_writes where assignment_id=p_id)
  or exists(select 1 from device_private.activity_confirmations where scheduled_id=p_id) then return 'results';end if;
 if exists(select 1 from device_private.training_deliveries where scheduled_id=p_id
    and (owner_id is distinct from a.client_id or status<>'cancelled' or lease_id is not null or lease_until is not null or error_code is not null))
  or exists(select 1 from device_private.training_sync_jobs where scheduled_id=p_id
    and (owner_id is distinct from a.client_id or state<>'done' or lease_id is not null or lease_until is not null))
  -- IDs antiguos distintos no quedan acreditados por cancelar solo el último.
  or exists(select 1 from device_private.training_delivery_versions v join device_private.training_deliveries d on d.id=v.delivery_id
    where d.scheduled_id=p_id and ((v.workout_id is not null and v.workout_id is distinct from d.workout_id)
     or (v.schedule_id is not null and v.schedule_id is distinct from d.schedule_id)))
  -- Si desapareció el recibo no se inventa una confirmación de retirada.
  or (exists(select 1 from trainer_private.assignment_lifecycle where assignment_id=p_id and external_reference)
    and not exists(select 1 from device_private.training_deliveries where scheduled_id=p_id and owner_id=a.client_id and status='cancelled')) then return 'garmin';end if;
 if exists(select 1 from trainer_private.messages where assignment_id=p_id)
  or exists(select 1 from public.exercise_video_assets where assignment_id=p_id)
  or exists(select 1 from public.running_week_sessions where scheduled_workout_id=p_id)
  or exists(select 1 from public.performance_week_work where scheduled_workout_id=p_id) then return 'references';end if;
 if s.status<>'cancelled' then return 'notWithdrawn';end if;
 return null;
end $$;

-- Ahora importan también las transiciones cancelled→cancelling y done→pending.
-- Toda actualización externa participa en la misma versión/lock del borrado.
drop trigger retain_assignment_external_reference on device_private.training_deliveries;
create trigger retain_assignment_external_reference before insert or update on device_private.training_deliveries
 for each row execute function trainer_private.retain_assignment_external_reference();
drop trigger retain_assignment_external_reference on device_private.training_sync_jobs;
create trigger retain_assignment_external_reference before insert or update on device_private.training_sync_jobs
 for each row execute function trainer_private.retain_assignment_external_reference();
drop trigger retain_assignment_external_reference on device_private.activity_confirmations;
create trigger retain_assignment_external_reference before insert or update on device_private.activity_confirmations
 for each row execute function trainer_private.retain_assignment_external_reference();

-- Los recibos permanecen. Scan/take deben ignorar las citas borradas en lugar
-- de volver a crearles trabajo o bloquear el escaneo de los demás alumnos.
do $$declare definition text;anchor text;begin
 definition:=pg_get_functiondef('device_private.garmin_training_sync_command(text,jsonb)'::regprocedure);
 anchor:='t:=device_private.training_sync_target(p.owner_id,x.id);';
 if strpos(definition,anchor)=0 then raise exception 'Revisar scan de Garmin antes de migrar';end if;
 definition:=replace(definition,anchor,'if exists(select 1 from trainer_private.assignment_lifecycle_writes where assignment_id=x.id and action=''delete'') then continue;end if; '||anchor);
 anchor:='select q.* into j from device_private.training_sync_jobs q where';
 if strpos(definition,anchor)=0 then raise exception 'Revisar take de Garmin antes de migrar';end if;
 definition:=replace(definition,anchor,anchor||' not exists(select 1 from trainer_private.assignment_lifecycle_writes w where w.assignment_id=q.scheduled_id and w.action=''delete'') and');
 execute definition;
 definition:=pg_get_functiondef('device_private.training_sync_valid(uuid,jsonb)'::regprocedure);
 anchor:='and j.target=device_private.training_sync_target(p_owner,j.scheduled_id)';
 if strpos(definition,anchor)=0 then raise exception 'Revisar validación Garmin antes de migrar';end if;
 definition:=replace(definition,anchor,'and not exists(select 1 from trainer_private.assignment_lifecycle_writes w where w.assignment_id=j.scheduled_id and w.action=''delete'') '||anchor);
 execute definition;
 definition:=pg_get_functiondef('trainer_private.change_assignment_lifecycle(uuid,uuid,uuid,bigint,text)'::regprocedure);
 definition:=replace(definition,'No se puede borrar: conserva vínculos con Garmin. Puedes archivarla.',
  'No se puede borrar: Garmin no tiene la retirada confirmada o conserva operaciones pendientes. Puedes archivarla.');
 execute definition;
end $$;
commit;
