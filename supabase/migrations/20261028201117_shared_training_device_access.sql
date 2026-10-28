-- Una sola política comercial para todos los transportes de entrenamiento.
create function device_private.training_device_access(p_owner uuid) returns boolean
language sql stable security definer set search_path='' as $$
 select public.has_pro_access(p_owner) or exists(
  select 1 from public.trainer_client_relations r join public.trainer_access a on a.trainer_id=r.trainer_id
  where r.client_id=p_owner and r.ended_at is null and a.enabled
   and (a.valid_until is null or a.valid_until>statement_timestamp())
 );
$$;
revoke all on function device_private.training_device_access(uuid) from public,anon,authenticated,service_role;
create or replace function device_private.garmin_access(p_owner uuid) returns boolean
language sql stable security definer set search_path='' as $$select device_private.training_device_access(p_owner)$$;
do $$declare d text;begin
 d:=pg_get_functiondef('device_private.apple_training_command(uuid,text,jsonb)'::regprocedure);
 if strpos(d,'device_private.garmin_access(p_owner)')=0 then raise exception 'Revisar política comercial Apple';end if;
 execute replace(d,'device_private.garmin_access(p_owner)','device_private.training_device_access(p_owner)');
end $$;
