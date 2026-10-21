begin;

-- Variante interna para una cita antigua YA bloqueada. No pide perfil después
-- de scheduled: borrado de perfil y cascadas siguen el orden opuesto.
create function trainer_private.lock_calendar_revisions(p_client_ids uuid[],p_lock_profiles boolean) returns void
language plpgsql security definer set search_path='' as $$
declare member uuid;
begin
 if p_lock_profiles is null then raise invalid_parameter_value; end if;
 if p_lock_profiles then
  perform trainer_private.lock_calendar_revisions(p_client_ids);
  return;
 end if;
 if not trainer_private.has_trainer_mfa() or p_client_ids is null
  or array_position(p_client_ids,null) is not null then raise insufficient_privilege; end if;
 if exists(select 1 from unnest(p_client_ids) c where not exists(
  select 1 from public.trainer_clients p where p.trainer_id=auth.uid() and p.client_id=c)) then raise insufficient_privilege; end if;
 for member in select distinct x from unnest(p_client_ids) x order by x loop
  insert into trainer_private.calendar_revisions(user_id,revision) values(member,0)
   on conflict(user_id) do update set revision=trainer_private.calendar_revisions.revision;
 end loop;
end $$;
revoke all on function trainer_private.lock_calendar_revisions(uuid[],boolean) from public,anon,authenticated;

create function trainer_private.preview_assignment_change(p_id uuid,p_expected_revision bigint,p_date date,p_note text,p_recipe jsonb default null) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare a public.trainer_assignments; s public.scheduled_workouts; coincidence boolean; payload jsonb; result jsonb;
begin
 if not trainer_private.has_professional_read_access() then raise insufficient_privilege; end if;
 if p_id is null or p_expected_revision is null or p_expected_revision<0 or p_date is null or char_length(p_note)>500
  or (p_recipe is not null and jsonb_typeof(p_recipe)<>'object') then raise invalid_parameter_value; end if;
 select * into a from public.trainer_assignments where scheduled_id=p_id and trainer_id=auth.uid();
 if not found then raise insufficient_privilege; end if;
 if a.planning_revision<>p_expected_revision then raise serialization_failure; end if;
 if not exists(select 1 from public.trainer_client_relations where id=a.relation_id and ended_at is null) then raise insufficient_privilege; end if;
 select * into s from public.scheduled_workouts where id=p_id;
 if not found or s.status<>'planned' or s.execution_id is not null then raise exception 'Solo se puede editar una pauta pendiente sin iniciar.' using errcode='22023'; end if;
 select exists(select 1 from public.scheduled_workouts other where other.user_id=a.client_id and other.id<>p_id
  and other.scheduled_date=p_date and other.status in ('planned','in_progress')) into coincidence;
 result:=jsonb_build_object('id',p_id,'client_id',a.client_id,'relation_id',a.relation_id,'date',p_date,
  'planning_revision',a.planning_revision,'has_date_coincidence',coincidence);
 payload:=result||jsonb_build_object('source_date',s.scheduled_date,'source_template_id',s.template_id,
  'note',nullif(btrim(p_note),''),'recipe',p_recipe);
 return result||jsonb_build_object('fingerprint',encode(extensions.digest(payload::text,'sha256'),'hex'));
end $$;

-- Reutiliza exactamente el controlador y motores existentes de edición. Las
-- anclas detienen la migración si cambia su orden de bloqueo o su ledger.
do $migration$
declare definition text; anchor text; replacement text;
begin
 -- CLI Windows conserva CRLF en los cuerpos almacenados; el parche multilinea
 -- contrasta el mismo código tras normalizar exclusivamente sus saltos de línea.
 definition:=replace(pg_get_functiondef('trainer_private.change_assignment(uuid,uuid,bigint,date,text,jsonb)'::regprocedure),E'\r\n',E'\n');
 if strpos(definition,'trainer_private.change_assignment(')=0 or strpos(definition,'p_recipe jsonb DEFAULT NULL::jsonb)')=0 then raise exception 'Revisar firma del editor de pauta.'; end if;
 definition:=replace(definition,'trainer_private.change_assignment(','trainer_private.change_assignment_reviewed(');
 definition:=replace(definition,'p_recipe jsonb DEFAULT NULL::jsonb)','p_fingerprint text, p_recipe jsonb DEFAULT NULL::jsonb)');
 anchor:=' payload jsonb; result jsonb;';
 if strpos(definition,anchor)=0 then raise exception 'Revisar variables del editor de pauta.'; end if;
 definition:=replace(definition,anchor,' payload jsonb; result jsonb; plan jsonb;');
 anchor:=' a:=trainer_private.lock_assignment(p_id);';
 replacement:=E' if not trainer_private.has_trainer_mfa() then raise insufficient_privilege; end if;\n select * into a from public.trainer_assignments where scheduled_id=p_id and trainer_id=auth.uid();\n if not found then raise insufficient_privilege; end if;\n perform pg_advisory_xact_lock(hashtextextended(''trainer-client:''||a.client_id::text,0));\n -- Adaptar crea una receta cuyo propietario es el preparador. Su FK se fija\n -- antes de access/scheduled/calendar para no invertir el borrado del propietario.\n perform 1 from public.profiles where id=auth.uid() for key share;\n if not found then raise insufficient_privilege; end if;\n'||anchor;
 if strpos(definition,anchor)=0 then raise exception 'Revisar bloqueo del editor de pauta.'; end if;
 definition:=replace(definition,anchor,replacement);
 anchor:=' if p_operation_id is null or p_expected_revision';
 if strpos(definition,anchor)=0 then raise exception 'Revisar validación del editor de pauta.'; end if;
 definition:=replace(definition,anchor,E' if p_operation_id is null or p_fingerprint is null or p_fingerprint !~ ''^[0-9a-f]{64}$'' or p_expected_revision');
 anchor:=E' payload:=jsonb_build_object(''assignment_id'',p_id,';
 if strpos(definition,anchor)=0 then raise exception 'Revisar ledger del editor de pauta.'; end if;
 definition:=replace(definition,anchor,E' payload:=jsonb_build_object(''fingerprint'',p_fingerprint,''assignment_id'',p_id,');
 anchor:=E' if not found then raise exception ''Solo se puede editar una pauta pendiente sin iniciar.'' using errcode=''22023''; end if;';
 replacement:=E' if not found then raise exception ''La pauta ya se ha iniciado o cambiado. Revisa la agenda.'' using errcode=''40001''; end if;\n perform trainer_private.lock_calendar_revisions(array[a.client_id],false);\n plan:=trainer_private.preview_assignment_change(p_id,p_expected_revision,p_date,p_note,p_recipe);\n if plan->>''fingerprint''<>p_fingerprint then raise exception ''La planificación ha cambiado. Revisa fecha y coincidencias de nuevo.'' using errcode=''40001''; end if;';
 if strpos(definition,anchor)=0 then raise exception 'Revisar estado del editor de pauta.'; end if;
 definition:=replace(definition,anchor,replacement);
 -- Dos UPDATE consecutivos de la misma cita fuerzan una nueva comprobación
 -- FK del perfil en el segundo, aunque user_id no cambie. La contención real
 -- mostró scheduled/calendar→pupil profile. Una sola escritura evita ese orden.
 anchor:=E'  update public.scheduled_workouts set template_id=t.id,template_name=t.name,template_version=t.version,\n   estimated_duration_minutes=t.estimated_duration_minutes where id=p_id;\n end if;\n update public.scheduled_workouts set scheduled_date=p_date where id=p_id;';
 replacement:=E' end if;\n update public.scheduled_workouts set scheduled_date=p_date,\n  template_id=case when p_recipe is null then s.template_id else t.id end,\n  template_name=case when p_recipe is null then s.template_name else t.name end,\n  template_version=case when p_recipe is null then s.template_version else t.version end,\n  estimated_duration_minutes=case when p_recipe is null then s.estimated_duration_minutes else t.estimated_duration_minutes end\n where id=p_id;';
 if strpos(definition,anchor)=0 then raise exception 'Revisar escritura única del editor de pauta.'; end if;
 execute replace(definition,anchor,replacement);
end $migration$;

create function public.preview_trainer_assignment_change(p_id uuid,p_expected_revision bigint,p_date date,p_note text,p_recipe jsonb default null) returns jsonb
language sql stable security invoker set search_path='' as $$select trainer_private.preview_assignment_change(p_id,p_expected_revision,p_date,p_note,p_recipe)$$;
create function public.change_trainer_assignment_reviewed(p_operation_id uuid,p_id uuid,p_expected_revision bigint,p_date date,p_note text,p_fingerprint text,p_recipe jsonb default null) returns jsonb
language sql security invoker set search_path='' as $$select trainer_private.change_assignment_reviewed(p_operation_id,p_id,p_expected_revision,p_date,p_note,p_fingerprint,p_recipe)$$;
revoke all on function trainer_private.change_assignment(uuid,uuid,bigint,date,text,jsonb),
 public.change_trainer_assignment(uuid,uuid,bigint,date,text,jsonb) from public,anon,authenticated;
revoke all on function trainer_private.preview_assignment_change(uuid,bigint,date,text,jsonb),
 trainer_private.change_assignment_reviewed(uuid,uuid,bigint,date,text,text,jsonb),
 public.preview_trainer_assignment_change(uuid,bigint,date,text,jsonb),
 public.change_trainer_assignment_reviewed(uuid,uuid,bigint,date,text,text,jsonb) from public,anon,authenticated;
grant execute on function trainer_private.preview_assignment_change(uuid,bigint,date,text,jsonb),
 trainer_private.change_assignment_reviewed(uuid,uuid,bigint,date,text,text,jsonb),
 public.preview_trainer_assignment_change(uuid,bigint,date,text,jsonb),
 public.change_trainer_assignment_reviewed(uuid,uuid,bigint,date,text,text,jsonb) to authenticated;

commit;
