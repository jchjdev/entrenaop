begin;

-- Conserva el validador original como núcleo de biblioteca. Se clona, sin
-- renombrar su OID, para no cambiar dependencias de las fachadas existentes.
do $clone$
declare definition text;
begin
 definition:=pg_get_functiondef('trainer_private.validate_session_work_origin(jsonb)'::regprocedure);
 execute replace(definition,'trainer_private.validate_session_work_origin(',
   'trainer_private.validate_library_session_origin_v1(');
 definition:=pg_get_functiondef('trainer_private.validate_program_work_state(jsonb)'::regprocedure);
 execute replace(definition,'trainer_private.validate_program_work_state(',
   'trainer_private.validate_program_work_state_v1(');
end $clone$;
revoke all on function trainer_private.validate_library_session_origin_v1(jsonb),
 trainer_private.validate_program_work_state_v1(jsonb) from public,anon,authenticated;

create or replace function trainer_private.validate_session_work_origin(p_origin jsonb) returns void
language plpgsql immutable set search_path='' as $$
declare key text; normalized jsonb; assignment boolean:=p_origin ? 'assignmentId';
begin
 perform trainer_private.session_work_fields(p_origin,
  array['baseId','programId','parentWorkId','phaseId','positionId','duplicate'],
  array['assignmentId','planningRevision'],'{}');
 normalized:=(p_origin-'assignmentId'-'planningRevision')||
  '{"programId":null,"parentWorkId":null,"phaseId":null,"positionId":null}'::jsonb;
 perform trainer_private.validate_library_session_origin_v1(normalized);
 if p_origin->'programId' is distinct from 'null'::jsonb or octet_length(p_origin::text)>4096 then raise invalid_parameter_value; end if;
 if p_origin->'parentWorkId'<>'null'::jsonb then
  if assignment then raise invalid_parameter_value; end if;
  foreach key in array array['parentWorkId','phaseId','positionId'] loop
   if jsonb_typeof(p_origin->key) is distinct from 'string' then raise invalid_parameter_value; end if;
   perform (p_origin->>key)::uuid;
  end loop;
 elsif p_origin->'phaseId' is distinct from 'null'::jsonb or p_origin->'positionId' is distinct from 'null'::jsonb then
  raise invalid_parameter_value;
 end if;
 if assignment then
  if jsonb_typeof(p_origin->'assignmentId') is distinct from 'string'
   or p_origin->'baseId'='null'::jsonb or p_origin->'duplicate'<>'false'::jsonb
   or jsonb_typeof(p_origin->'planningRevision') is distinct from 'number'
   or p_origin->>'planningRevision' !~ '^[0-9]{1,10}$'
   or (p_origin->>'planningRevision')::bigint>2147483646 then raise invalid_parameter_value; end if;
  perform (p_origin->>'assignmentId')::uuid;
 elsif p_origin ? 'planningRevision' then raise invalid_parameter_value;
 end if;
exception when invalid_text_representation or numeric_value_out_of_range then raise invalid_parameter_value;
end $$;

create or replace function trainer_private.validate_program_work_state(p_state jsonb) returns void
language plpgsql immutable set search_path='' as $$
declare phase jsonb; entry record; item jsonb; normalized jsonb; phases jsonb:='[]';
 phase_ids text[]:='{}'; positions text[]:='{}'; work_ids text[]:='{}'; work_positions text[];
begin
 if p_state is null or octet_length(p_state::text)>524288 or jsonb_typeof(p_state->'phases') is distinct from 'array' then raise invalid_parameter_value; end if;
 for phase in select value from jsonb_array_elements(p_state->'phases') loop
  if phase ? 'phaseId' then
   if jsonb_typeof(phase->'phaseId') is distinct from 'string' or phase->>'phaseId'=any(phase_ids) then raise invalid_parameter_value; end if;
   perform (phase->>'phaseId')::uuid; phase_ids:=array_append(phase_ids,phase->>'phaseId');
   for item in select value from jsonb_array_elements(phase->'sessions') loop
    if jsonb_typeof(item->'positionId') is distinct from 'string' or item->>'positionId'=any(positions) then raise invalid_parameter_value; end if;
    perform (item->>'positionId')::uuid; positions:=array_append(positions,item->>'positionId');
   end loop;
  end if;
  if phase ? 'sessionWorks' then
   if not(phase ? 'phaseId') or jsonb_typeof(phase->'sessionWorks') is distinct from 'object'
    or (select count(*) from jsonb_object_keys(phase->'sessionWorks'))>256 then raise invalid_parameter_value; end if;
   work_positions:='{}';
   for entry in select * from jsonb_each(phase->'sessionWorks') loop
    perform entry.key::uuid;
    if entry.key=any(work_ids) then raise invalid_parameter_value; end if;
    work_ids:=array_append(work_ids,entry.key);
    if cardinality(work_ids)>4096 then raise invalid_parameter_value; end if;
    perform trainer_private.validate_session_work_origin(entry.value);
    if entry.value->>'phaseId' is distinct from phase->>'phaseId'
     or entry.value->'parentWorkId'='null'::jsonb or entry.value ? 'assignmentId'
     or entry.value->>'positionId'=any(work_positions) then raise invalid_parameter_value; end if;
    work_positions:=array_append(work_positions,entry.value->>'positionId');
   end loop;
  end if;
  phases:=phases||jsonb_build_array(phase-'phaseId'-'sessionWorks');
 end loop;
 normalized:=jsonb_set(p_state,'{phases}',phases);
 perform trainer_private.validate_program_work_state_v1(normalized);
exception when invalid_text_representation or numeric_value_out_of_range then raise invalid_parameter_value;
end $$;

create function trainer_private.check_session_work_parent(p_id uuid,p_origin jsonb) returns void
language plpgsql security definer set search_path='' as $$
declare parent trainer_private.program_works; body jsonb; phase jsonb; slot jsonb;
begin
 if p_origin->'parentWorkId'='null'::jsonb then return; end if;
 -- El mismo acceso profesional ya bloqueado ordena los presupuestos de ambos
 -- creadores. El contador del padre fuerza 40001 ante un snapshot RR antiguo.
 perform trainer_private.lock_program_work_owner(auth.uid());
 select * into parent from trainer_private.program_works where owner_id=auth.uid()
  and context='trainer_private' and id=(p_origin->>'parentWorkId')::uuid for update;
 if not found or parent.lifecycle<>'open' then raise exception 'El programa no está disponible para incorporar esta sesión.' using errcode='40001'; end if;
 select b.body into body from trainer_private.program_work_bodies b where b.owner_id=parent.owner_id and b.context=parent.context and b.hash=parent.state_hash;
 select value into phase from jsonb_array_elements(body->'phases') where value->>'phaseId'=p_origin->>'phaseId';
 if phase is null or phase->'sessionWorks'->p_id::text is distinct from p_origin then
  raise exception 'La posición del programa ha cambiado. El trabajo se conserva.' using errcode='40001'; end if;
 select value into slot from jsonb_array_elements(phase->'sessions') where value->>'positionId'=p_origin->>'positionId';
 if not(p_origin->>'duplicate')::boolean and p_origin->'baseId'<>'null'::jsonb then
  if slot->>'id' is distinct from p_origin->>'baseId' then raise serialization_failure; end if;
 elsif slot is not null then raise serialization_failure;
 end if;
end $$;
revoke all on function trainer_private.check_session_work_parent(uuid,jsonb) from public,anon,authenticated;

create function trainer_private.guard_program_session_continuity() returns trigger
language plpgsql security definer set search_path='' as $$
declare body jsonb; old_body jsonb; phase jsonb; entry record; child trainer_private.session_works; kept boolean;
begin
 select b.body into body from trainer_private.program_work_bodies b where b.owner_id=new.owner_id and b.context=new.context and b.hash=new.state_hash;
 for phase in select value from jsonb_array_elements(body->'phases') loop
  for entry in select * from jsonb_each(coalesce(phase->'sessionWorks','{}'::jsonb)) loop
   if entry.value->>'parentWorkId' is distinct from new.id::text then raise invalid_parameter_value; end if;
   if exists(select 1 from trainer_private.session_works w where w.owner_id=new.owner_id and w.id=entry.key::uuid
    and w.origin is distinct from entry.value) then raise invalid_parameter_value; end if;
  end loop;
 end loop;
 if tg_op='INSERT' then return new; end if;
 select b.body into old_body from trainer_private.program_work_bodies b where b.owner_id=old.owner_id and b.context=old.context and b.hash=old.state_hash;
 -- Solo se protegen enlaces pendientes del estado anterior: una sesión ya
 -- incorporada puede quitarse o moverse después sin quedar fijada para siempre.
 for phase in select value from jsonb_array_elements(old_body->'phases') loop
  for entry in select * from jsonb_each(coalesce(phase->'sessionWorks','{}'::jsonb)) loop
   select * into child from trainer_private.session_works where owner_id=old.owner_id and context=old.context and id=entry.key::uuid;
   if not found or child.lifecycle='discarded' then continue; end if;
   if new.lifecycle='discarded' and child.lifecycle='finalized' then continue; end if;
   select exists(select 1 from jsonb_array_elements(body->'phases') p where p->>'phaseId'=entry.value->>'phaseId'
     and p->'sessionWorks'->entry.key=entry.value) into kept;
   if new.lifecycle='open' and kept then continue; end if;
   if child.lifecycle='finalized' and exists(select 1 from jsonb_array_elements(body->'phases') p,
       jsonb_array_elements(p->'sessions') s where p->>'phaseId'=entry.value->>'phaseId'
       and s->>'positionId'=entry.value->>'positionId' and s->>'id'=child.result_id::text) then continue; end if;
   raise exception 'Hay una sesión incompleta o un enlace pendiente. Retómala o descártala antes de cambiar el programa.' using errcode='40001';
  end loop;
 end loop;
 return new;
end $$;
revoke all on function trainer_private.guard_program_session_continuity() from public,anon,authenticated;
create trigger ab_guard_program_session_continuity before insert or update on trainer_private.program_works
 for each row execute function trainer_private.guard_program_session_continuity();

create function trainer_private.guard_session_pending_program_link() returns trigger
language plpgsql security definer set search_path='' as $$
begin
 if old.origin='coach' and old.status='published' and new.status<>'published' and exists(
  select 1 from trainer_private.session_works w join trainer_private.program_works p
   on p.owner_id=w.owner_id and p.id=(w.origin->>'parentWorkId')::uuid and p.lifecycle='open'
  join trainer_private.program_work_bodies b on b.owner_id=p.owner_id and b.context=p.context and b.hash=p.state_hash,
   jsonb_array_elements(b.body->'phases') phase
  where w.result_id=old.id and w.lifecycle='finalized' and phase->'sessionWorks' ? w.id::text
 ) then raise exception 'La sesión conserva un enlace pendiente a un programa. Confírmalo antes de revisarla.' using errcode='40001'; end if;
 return new;
end $$;
revoke all on function trainer_private.guard_session_pending_program_link() from public,anon,authenticated;
create trigger guard_session_pending_program_link before update of status on public.workout_templates
 for each row execute function trainer_private.guard_session_pending_program_link();

create function trainer_private.check_session_work_assignment(p_origin jsonb) returns void
language plpgsql stable security definer set search_path='' as $$
begin
 if not trainer_private.has_trainer_mfa() or not exists(
  select 1 from public.trainer_assignments a join public.scheduled_workouts s on s.id=a.scheduled_id
   join public.trainer_client_relations r on r.id=a.relation_id
  where a.scheduled_id=(p_origin->>'assignmentId')::uuid and a.trainer_id=auth.uid()
   and r.ended_at is null and a.planning_revision=(p_origin->>'planningRevision')::bigint
   and s.template_id=(p_origin->>'baseId')::uuid and s.status='planned' and s.execution_id is null
 ) then raise exception 'La pauta ha cambiado, se ha iniciado o ya no está activa. El borrador se conserva.' using errcode='40001'; end if;
end $$;
revoke all on function trainer_private.check_session_work_assignment(jsonb) from public,anon,authenticated;

do $extend$
declare definition text; anchor text;
begin
 definition:=replace(pg_get_functiondef('trainer_private.save_trainer_session_work(uuid,uuid,bigint,jsonb,jsonb)'::regprocedure),E'\r\n',E'\n');
 anchor:=' select snapshot_limit into lim from trainer_private.session_work_limits where owner_id=auth.uid();';
 if strpos(definition,anchor)=0 then raise exception 'Revisar el guardado de sesiones antes de ampliar sus contextos.'; end if;
 definition:=replace(definition,anchor,
  ' perform trainer_private.check_session_work_parent(p_id,p_origin);
 if work.id is null and p_origin ? ''assignmentId'' then perform trainer_private.check_session_work_assignment(p_origin); end if;
'||anchor);
 anchor:='and status=''published'' for share;';
 if strpos(definition,anchor)=0 then raise exception 'Revisar la base de las sesiones profesionales.'; end if;
 execute replace(definition,anchor,
  'and (status=''published'' or ((p_origin->''parentWorkId''<>''null''::jsonb or p_origin ? ''assignmentId'') and status=''archived'')) for share;');

 definition:=replace(pg_get_functiondef('trainer_private.finalize_trainer_session_work(uuid,uuid,bigint)'::regprocedure),E'\r\n',E'\n');
 anchor:=' if not found then raise insufficient_privilege;end if;';
 if strpos(definition,anchor)=0 then raise exception 'Revisar la finalización profesional.'; end if;
 definition:=replace(definition,anchor,anchor||'
 if work.origin ? ''assignmentId'' then raise exception ''Confirma la adaptación mediante su revisión de coincidencias.'' using errcode=''22023''; end if;');
 anchor:=' previous:=case when (work.origin->>''duplicate'')::boolean then null else (work.origin->>''baseId'')::uuid end;';
 if strpos(definition,anchor)=0 then raise exception 'Revisar el versionado de sesión.'; end if;
 execute replace(definition,anchor,
  ' perform trainer_private.check_session_work_parent(p_id,work.origin);
 previous:=case when (work.origin->>''duplicate'')::boolean then null else (work.origin->>''baseId'')::uuid end;
 if work.origin->''parentWorkId''<>''null''::jsonb and previous is not null and not exists(
   select 1 from public.workout_templates where id=previous and status=''published'') then previous:=null; end if;');

 definition:=replace(pg_get_functiondef('trainer_private.program_work_projection(jsonb)'::regprocedure),E'\r\n',E'\n');
 anchor:='  if jsonb_array_length(phase->''pending'')>0 then';
 if strpos(definition,anchor)=0 then raise exception 'Revisar la composición profesional.'; end if;
 execute replace(definition,anchor,
  '  if coalesce(phase->''sessionWorks'',''{}''::jsonb)<>''{}''::jsonb then raise exception ''Hay sesiones incompletas o enlaces pendientes en este programa.'' using errcode=''22023''; end if;
'||anchor);
end $extend$;

create function trainer_private.preview_assignment_session_work(p_expected_owner uuid,p_id uuid,p_revision bigint) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare work trainer_private.session_works; state jsonb; assignment public.trainer_assignments; scheduled public.scheduled_workouts;
begin
 perform trainer_private.session_work_identity(p_expected_owner);
 select * into work from trainer_private.session_works where owner_id=auth.uid() and context='trainer_private' and id=p_id;
 if not found or not(work.origin ? 'assignmentId') then raise insufficient_privilege; end if;
 if work.lifecycle<>'open' or work.revision is distinct from p_revision then raise serialization_failure; end if;
 perform trainer_private.check_session_work_assignment(work.origin);
 select b.body into state from trainer_private.session_work_bodies b where b.owner_id=work.owner_id and b.context=work.context and b.hash=work.state_hash;
 if not(state ? 'intent') then raise invalid_parameter_value; end if;
 select * into assignment from public.trainer_assignments where scheduled_id=(work.origin->>'assignmentId')::uuid and trainer_id=auth.uid();
 select * into scheduled from public.scheduled_workouts where id=assignment.scheduled_id;
 return trainer_private.preview_assignment_change(assignment.scheduled_id,assignment.planning_revision,
  scheduled.scheduled_date,assignment.note,state->'intent');
end $$;

create function trainer_private.finalize_assignment_session_work(p_expected_owner uuid,p_id uuid,p_revision bigint,p_fingerprint text) returns uuid
language plpgsql security definer set search_path='' as $$
declare work trainer_private.session_works; prior trainer_private.session_work_operations;
 assignment public.trainer_assignments; scheduled public.scheduled_workouts;
 request jsonb; state jsonb; request_hash text; receipt jsonb; result uuid;
begin
 perform trainer_private.session_work_identity(p_expected_owner);
 if p_id is null or p_revision is null or p_revision not between 0 and 2147483646
  or p_fingerprint is null or p_fingerprint !~ '^[0-9a-f]{64}$' then raise invalid_parameter_value; end if;
 select * into work from trainer_private.session_works where owner_id=auth.uid() and context='trainer_private' and id=p_id;
 if not found or not(work.origin ? 'assignmentId') then raise insufficient_privilege; end if;
 request:=jsonb_build_object('action','finalize_assignment','origin',work.origin,'schema',work.schema_version,'fingerprint',p_fingerprint);
 select * into prior from trainer_private.session_work_operations where owner_id=auth.uid() and context='trainer_private'
  and work_id=p_id and action='finalize' and expected_revision=p_revision;
 if found then perform trainer_private.check_session_work_request(prior,request); return (prior.receipt->>'result_id')::uuid; end if;
 select * into assignment from public.trainer_assignments where scheduled_id=(work.origin->>'assignmentId')::uuid and trainer_id=auth.uid();
 if not found then raise insufficient_privilege; end if;
 -- Igual orden que mover/adaptar/finalizar el servicio: alumno→perfil del
 -- autor→acceso→presupuesto→pauta. No pedir el advisory después de access.
 perform pg_advisory_xact_lock(hashtextextended('trainer-client:'||assignment.client_id::text,0));
 perform trainer_private.lock_session_work_owner(p_expected_owner);
 select * into work from trainer_private.session_works where owner_id=auth.uid() and context='trainer_private' and id=p_id for update;
 select * into prior from trainer_private.session_work_operations where owner_id=auth.uid() and context='trainer_private'
  and work_id=p_id and action='finalize' and expected_revision=p_revision;
 if found then perform trainer_private.check_session_work_request(prior,request); return (prior.receipt->>'result_id')::uuid; end if;
 if work.lifecycle<>'open' or work.revision<>p_revision then raise serialization_failure; end if;
 perform trainer_private.check_session_work_assignment(work.origin);
 select b.body into state from trainer_private.session_work_bodies b where b.owner_id=work.owner_id and b.context=work.context and b.hash=work.state_hash;
 if not(state ? 'intent') then raise invalid_parameter_value; end if;
 select * into scheduled from public.scheduled_workouts where id=assignment.scheduled_id;
 perform trainer_private.change_assignment_reviewed(p_id,assignment.scheduled_id,(work.origin->>'planningRevision')::bigint,
  scheduled.scheduled_date,assignment.note,p_fingerprint,state->'intent');
 result:=assignment.scheduled_id;
 request_hash:=trainer_private.session_work_store_body(request);
 update trainer_private.session_works set lifecycle='finalized',result_id=result,revision=revision+1,updated_at=clock_timestamp()
  where owner_id=auth.uid() and context='trainer_private' and id=p_id returning * into work;
 receipt:=trainer_private.session_work_receipt(work);
 insert into trainer_private.session_work_operations(owner_id,work_id,action,expected_revision,request_hash,request_body_hash,receipt)
  values(auth.uid(),p_id,'finalize',p_revision,trainer_private.session_work_hash(request),request_hash,receipt);
 return result;
end $$;

create function public.preview_trainer_assignment_session_work(p_expected_owner uuid,p_id uuid,p_revision bigint) returns jsonb
language sql stable security invoker set search_path='' as $$select trainer_private.preview_assignment_session_work(p_expected_owner,p_id,p_revision)$$;
create function public.finalize_trainer_assignment_session_work(p_expected_owner uuid,p_id uuid,p_revision bigint,p_fingerprint text) returns uuid
language sql volatile security invoker set search_path='' as $$select trainer_private.finalize_assignment_session_work(p_expected_owner,p_id,p_revision,p_fingerprint)$$;
revoke all on function trainer_private.preview_assignment_session_work(uuid,uuid,bigint),
 trainer_private.finalize_assignment_session_work(uuid,uuid,bigint,text),
 public.preview_trainer_assignment_session_work(uuid,uuid,bigint),public.finalize_trainer_assignment_session_work(uuid,uuid,bigint,text)
 from public,anon,authenticated;
grant execute on function trainer_private.preview_assignment_session_work(uuid,uuid,bigint),
 trainer_private.finalize_assignment_session_work(uuid,uuid,bigint,text),
 public.preview_trainer_assignment_session_work(uuid,uuid,bigint),public.finalize_trainer_assignment_session_work(uuid,uuid,bigint,text)
 to authenticated;

commit;
