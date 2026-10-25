begin;
-- La misma receta y autoridad sirven a lectura y envío. Los bloqueos se toman
-- únicamente desde la fachada de escritura; PostgREST consulta STABLE en READ ONLY.
do $$declare definition text;begin
 definition:=pg_get_functiondef('device_private.training_source(uuid,uuid,uuid)'::regprocedure);
 if (length(definition)-length(replace(definition,'for share','')))/length('for share')<>2 then
  raise exception 'Revisar los bloqueos de la fuente de prescripción';end if;
 definition:=replace(definition,'device_private.training_source(', 'device_private.training_source_snapshot(');
 definition:=replace(definition,' for share','');
 execute definition;
end $$;
alter function device_private.training_source_snapshot(uuid,uuid,uuid) stable;
revoke all on function device_private.training_source_snapshot(uuid,uuid,uuid) from public,anon,authenticated,service_role;
create or replace function device_private.training_source(p_actor uuid,p_owner uuid,p_schedule uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
begin
 perform 1 from public.scheduled_workouts where id=p_schedule and user_id=p_owner for share;
 perform 1 from public.workout_templates t join public.scheduled_workouts s on s.template_id=t.id
  where s.id=p_schedule and s.user_id=p_owner for share of t;
 return device_private.training_source_snapshot(p_actor,p_owner,p_schedule);
end $$;
-- El objetivo consultado reutiliza la misma política de selección, con la fuente
-- sin bloqueos. No concede autorización para efectos externos ni reclama cola.
do $$declare definition text;begin
 definition:=pg_get_functiondef('device_private.training_sync_target(uuid,uuid)'::regprocedure);
 if strpos(definition,'device_private.training_source(p_owner,p_owner,p_schedule)')=0 then
  raise exception 'Revisar la fuente del objetivo automático';end if;
 definition:=replace(definition,'device_private.training_sync_target(', 'device_private.training_progress_target(');
 definition:=replace(definition,'device_private.training_source(p_owner,p_owner,p_schedule)',
  'device_private.training_source_snapshot(p_owner,p_owner,p_schedule)');
 execute definition;
 definition:=pg_get_functiondef('device_private.training_progress(uuid,uuid,uuid)'::regprocedure);
 if strpos(definition,'device_private.training_sync_target(p_owner,p_schedule)')=0 then
  raise exception 'Revisar la consulta de progreso';end if;
 execute replace(definition,'device_private.training_sync_target(p_owner,p_schedule)',
  'device_private.training_progress_target(p_owner,p_schedule)');
end $$;
alter function device_private.training_progress_target(uuid,uuid) stable;
revoke all on function device_private.training_progress_target(uuid,uuid) from public,anon,authenticated,service_role;
commit;
