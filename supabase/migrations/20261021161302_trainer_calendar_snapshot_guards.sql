begin;

-- Los advisory ordenan escritores, pero no renuevan una instantánea REPEATABLE
-- READ. Esta fila privada permite detectar también altas nuevas en la agenda.
create table trainer_private.calendar_revisions (
 user_id uuid primary key,
 revision bigint not null default 0 check(revision>=0)
);
alter table trainer_private.calendar_revisions enable row level security;
revoke all on trainer_private.calendar_revisions from public,anon,authenticated;

-- Una FK aquí invertiría perfil→agenda y agenda→perfil al disparar el bump.
-- La limpieza va después de las cascadas RI_ConstraintTrigger_* del perfil;
-- ningún cliente puede insertar o conservar por sí mismo un contador huérfano.
create function trainer_private.clear_deleted_calendar_revision() returns trigger
language plpgsql security definer set search_path='' as $$
begin
 delete from trainer_private.calendar_revisions where user_id=old.id;
 return old;
end $$;
revoke all on function trainer_private.clear_deleted_calendar_revision() from public,anon,authenticated;
create trigger zz_trainer_calendar_revision_cleanup after delete on public.profiles
 for each row execute function trainer_private.clear_deleted_calendar_revision();

create function trainer_private.bump_calendar_revision() returns trigger
language plpgsql security definer set search_path='' as $$
declare members uuid[]; member uuid;
begin
 if tg_op='INSERT' then members:=array[new.user_id];
 elsif tg_op='DELETE' then members:=array[old.user_id];
 else members:=array[old.user_id,new.user_id]; end if;
 for member in select distinct x from unnest(members) x where x is not null order by x loop
  -- Durante ON DELETE CASCADE el perfil ya no existe. No se reconstruye su
  -- contador ni se impide el borrado con una nueva referencia al perfil.
  insert into trainer_private.calendar_revisions(user_id,revision)
   select id,1 from public.profiles where id=member
   on conflict(user_id) do update set revision=trainer_private.calendar_revisions.revision+1;
 end loop;
 if tg_op='DELETE' then return old; end if;
 return new;
end $$;
revoke all on function trainer_private.bump_calendar_revision() from public,anon,authenticated;
create trigger bump_trainer_calendar_revision after insert or update or delete on public.scheduled_workouts
 for each row execute function trainer_private.bump_calendar_revision();

-- Solo lo invocan motores que ya validaron propiedad y tomaron todos los locks
-- de clientes y acceso. Nunca se adquiere esta fila antes de modificar una cita
-- antigua: copia/creación únicamente insertan citas nuevas tras este bloqueo.
create function trainer_private.lock_calendar_revisions(p_client_ids uuid[]) returns void
language plpgsql security definer set search_path='' as $$
declare member uuid;
begin
 if not trainer_private.has_trainer_mfa() or p_client_ids is null
  or array_position(p_client_ids,null) is not null then raise insufficient_privilege; end if;
 -- Validar todo antes del primer INSERT evita sondas de FK o contadores ajenos.
 if exists(select 1 from unnest(p_client_ids) c where not exists(
  select 1 from public.trainer_clients p where p.trainer_id=auth.uid() and p.client_id=c)) then raise insufficient_privilege; end if;
 -- Las citas NUEVAS necesitan una FK al perfil. Fijarlo antes del contador
 -- impide calendario→perfil frente a borrado perfil→cascadas→calendario.
 for member in select distinct x from unnest(p_client_ids) x order by x loop
  perform 1 from public.profiles where id=member for key share;
  if not found then raise insufficient_privilege; end if;
 end loop;
 for member in select distinct x from unnest(p_client_ids) x order by x loop
  -- El no-op también bloquea una fila que no existía en el snapshot. Un INSERT
  -- concurrente invisible en RR causa 40001; DO NOTHING + SELECT no bastaría.
  insert into trainer_private.calendar_revisions(user_id,revision) values(member,0)
   on conflict(user_id) do update set revision=trainer_private.calendar_revisions.revision;
 end loop;
end $$;
revoke all on function trainer_private.lock_calendar_revisions(uuid[]) from public,anon,authenticated;

do $migration$
declare definition text; anchor text; replacement text;
begin
 definition:=pg_get_functiondef('trainer_private.copy_week(uuid,date,integer,text)'::regprocedure);
 anchor:=E' snapshot:=trainer_private.week_snapshot(p_week_start,p_offset_days);';
 replacement:=E' perform trainer_private.lock_calendar_revisions(locked_clients);\n'||anchor;
 if strpos(definition,anchor)=0 or strpos(definition,'lock_calendar_revisions')>0 then raise exception 'Revisar copy_week antes de proteger su snapshot.'; end if;
 execute replace(definition,anchor,replacement);

 definition:=pg_get_functiondef('trainer_private.create_recurrence(uuid,jsonb,uuid,date,integer,integer[],text,text)'::regprocedure);
 anchor:=E' plan:=trainer_private.recurrence_plan(p_recipients,p_template_id,p_week_start,p_weeks,p_weekdays,p_note);';
 -- La primera preparación valida todos los recursos sin tocar revisiones de
 -- UUID suministrados por un cliente. La segunda vuelve a leer tras los locks.
 replacement:=anchor||E'\n perform trainer_private.lock_calendar_revisions(array(select (r->>''client_id'')::uuid from jsonb_array_elements(plan->''recipients'') r));\n'||anchor;
 if strpos(definition,anchor)=0 or strpos(definition,'lock_calendar_revisions')>0 then raise exception 'Revisar create_recurrence antes de proteger su snapshot.'; end if;
 execute replace(definition,anchor,replacement);
end $migration$;

-- La tanda anterior tenía preview pero no lo enlazaba al commit. El endpoint
-- nuevo es aditivo; el antiguo deja de ser una vía ejecutable por clientes.
do $migration$
declare definition text; anchor text; replacement text;
begin
 definition:=pg_get_functiondef('trainer_private.preview_batch(jsonb,uuid,date,uuid,jsonb,text,uuid,bigint)'::regprocedure);
 anchor:=E' return result||jsonb_build_object(''preview'',previews);';
 replacement:=E' result:=result||jsonb_build_object(''preview'',previews,''template_id'',p_template_id,''date'',p_date,''program_id'',p_program_id,''entries'',p_entries,''note'',nullif(btrim(p_note),''''),''group_id'',p_group_id,''group_revision'',p_group_revision);\n return result||jsonb_build_object(''fingerprint'',encode(extensions.digest(result::text,''sha256''),''hex''));';
 if strpos(definition,anchor)=0 then raise exception 'Revisar preview_batch antes de añadir su huella.'; end if;
 execute replace(definition,anchor,replacement);

 definition:=pg_get_functiondef('trainer_private.deliver_batch(uuid,jsonb,uuid,date,uuid,jsonb,text,uuid,bigint)'::regprocedure);
 if strpos(definition,'trainer_private.deliver_batch(')=0 or strpos(definition,'p_group_revision bigint)')=0 then raise exception 'Revisar firma de deliver_batch.'; end if;
 definition:=replace(definition,'trainer_private.deliver_batch(','trainer_private.deliver_batch_reviewed(');
 definition:=replace(definition,'p_group_revision bigint)','p_group_revision bigint, p_fingerprint text)');
 anchor:=E' if p_operation_id is null or jsonb_typeof(p_recipients)';
 if strpos(definition,anchor)=0 then raise exception 'Revisar validación de deliver_batch.'; end if;
 definition:=replace(definition,anchor,E' if p_operation_id is null or p_fingerprint is null or p_fingerprint !~ ''^[0-9a-f]{64}$'' or jsonb_typeof(p_recipients)');
 anchor:=E' payload:=jsonb_build_object(''kind'',''batch'',';
 if strpos(definition,anchor)=0 then raise exception 'Revisar ledger de deliver_batch.'; end if;
 definition:=replace(definition,anchor,E' payload:=jsonb_build_object(''kind'',''reviewed_batch'',''fingerprint'',p_fingerprint,');
 anchor:=E' plan:=trainer_private.prepare_batch(p_recipients,p_template_id,p_date,p_program_id,p_entries,p_note,p_group_id,p_group_revision);';
 replacement:=E' plan:=trainer_private.preview_batch(p_recipients,p_template_id,p_date,p_program_id,p_entries,p_note,p_group_id,p_group_revision);\n perform trainer_private.lock_calendar_revisions(array(select (r->>''client_id'')::uuid from jsonb_array_elements(plan->''recipients'') r));\n plan:=trainer_private.preview_batch(p_recipients,p_template_id,p_date,p_program_id,p_entries,p_note,p_group_id,p_group_revision);\n if plan->>''fingerprint''<>p_fingerprint then raise exception ''La planificación ha cambiado. Revisa destinatarios, fechas y coincidencias de nuevo.'' using errcode=''40001''; end if;';
 if strpos(definition,anchor)=0 then raise exception 'Revisar preparación de deliver_batch.'; end if;
 execute replace(definition,anchor,replacement);
end $migration$;

create function public.deliver_trainer_batch_reviewed(p_operation_id uuid,p_recipients jsonb,p_fingerprint text,
 p_template_id uuid default null,p_date date default null,p_program_id uuid default null,p_entries jsonb default null,
 p_note text default null,p_group_id uuid default null,p_group_revision bigint default null) returns jsonb
language sql security invoker set search_path='' as $$
 select trainer_private.deliver_batch_reviewed(p_operation_id,p_recipients,p_template_id,p_date,p_program_id,p_entries,p_note,p_group_id,p_group_revision,p_fingerprint)
$$;
revoke all on function trainer_private.deliver_batch(uuid,jsonb,uuid,date,uuid,jsonb,text,uuid,bigint),
 public.deliver_trainer_batch(uuid,jsonb,uuid,date,uuid,jsonb,text,uuid,bigint) from public,anon,authenticated;
revoke all on function trainer_private.deliver_batch_reviewed(uuid,jsonb,uuid,date,uuid,jsonb,text,uuid,bigint,text),
 public.deliver_trainer_batch_reviewed(uuid,jsonb,text,uuid,date,uuid,jsonb,text,uuid,bigint) from public,anon,authenticated;
grant execute on function trainer_private.deliver_batch_reviewed(uuid,jsonb,uuid,date,uuid,jsonb,text,uuid,bigint,text),
 public.deliver_trainer_batch_reviewed(uuid,jsonb,text,uuid,date,uuid,jsonb,text,uuid,bigint) to authenticated;

commit;
