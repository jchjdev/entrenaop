begin;

-- El FIT ya se normaliza a CR10. El resultado histórico admite enteros 1–10:
-- se conserva la declaración decimal en la evidencia, sin redondearla.
create function device_private.garmin_recorded_effort(p_observation jsonb)
returns integer language plpgsql immutable security invoker set search_path='' as $$
declare effort numeric;
begin
 if jsonb_typeof(p_observation->'perceivedExertion') is distinct from 'number' then return null;end if;
 effort:=(p_observation->>'perceivedExertion')::numeric;
 if effort between 1 and 10 and trunc(effort)=effort then return effort::integer;end if;
 return null;
end $$;
revoke all on function device_private.garmin_recorded_effort(jsonb) from public,anon,authenticated,service_role;

create function device_private.enrich_garmin_execution_effort(p_owner uuid,p_activity uuid)
returns void language plpgsql security invoker set search_path='' as $$
declare a device_private.activity_observations; original device_private.activity_observations;
 receipt device_private.activity_confirmations; effort integer;
begin
 -- Solo la puerta del trabajador, con identidad/concesión/lease ya comprobados,
 -- invoca este auxiliar privado. Una nueva revisión no reabre la ejecución.
 select * into a from device_private.activity_observations where id=p_activity and owner_id=p_owner and channel='garmin';
 if not found then return;end if;
 effort:=device_private.garmin_recorded_effort(a.observation);
 if effort is null then return;end if;
 select * into receipt from device_private.activity_confirmations where owner_id=p_owner and external_id=a.external_id;
 if not found then return;end if;
 select * into original from device_private.activity_observations where id=receipt.activity_id and owner_id=p_owner;
 -- Una revisión con otros tiempos, series o mediciones exige su propio examen.
 -- Solo se permite añadir metadatos a la misma evidencia deportiva confirmada.
 if not found or (a.observation-'perceivedExertion'-'prescriptionStepIndices') is distinct from
  (original.observation-'perceivedExertion'-'prescriptionStepIndices') then return;end if;
 update public.workout_executions set final_rpe=effort where id=receipt.execution_id and user_id=p_owner
  and status='completed' and result_source='device' and final_rpe is null;
end $$;
revoke all on function device_private.enrich_garmin_execution_effort(uuid,uuid) from public,anon,authenticated,service_role;

do $$
declare definition text; anchor text;
begin
 definition:=pg_get_functiondef('device_private.garmin_automatic_result(text,uuid,jsonb)'::regprocedure);
 anchor:='finish_workout_observed_idempotent(operation,execution,null,';
 if (length(definition)-length(replace(definition,anchor,'')))/length(anchor)<>1 then
  raise exception 'Revisar cierre automático Garmin antes de incorporar esfuerzo';end if;
 definition:=replace(definition,anchor,
  'finish_workout_observed_idempotent(operation,execution,device_private.garmin_recorded_effort(a.observation),');
 anchor:=E'if found then\n  update device_private.activity_return_jobs';
 if (length(definition)-length(replace(definition,anchor,'')))/length(anchor)<>1 then
  raise exception 'Revisar replay Garmin antes de incorporar esfuerzo tardío';end if;
 execute replace(definition,anchor,E'if found then\n  perform device_private.enrich_garmin_execution_effort(p_owner,a.id);\n  update device_private.activity_return_jobs');
end $$;

commit;
