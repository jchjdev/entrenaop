-- TRN-045: papelera por familia profesional y ejercicios oficiales.
-- No elimina asignaciones, resultados, imágenes ni vídeos de proveedores.
begin;

alter table public.exercises add column trashed_at timestamptz;
alter table trainer_private.programs add column trashed_at timestamptz;
alter table public.workout_templates drop constraint official_session_trash_state;
alter table public.workout_templates add constraint official_session_trash_state check (
 (trashed_at is null and trash_previous_status is null) or
 (trashed_at is not null and trash_previous_status is not null and trash_previous_status in ('draft','published','archived') and
  ((origin='system' and owner_user_id is null and status='archived' and visibility='private') or
   (origin='coach' and owner_user_id is not null and visibility='private'))));
create index exercises_trash_page on public.exercises(trashed_at desc,id desc) where trashed_at is not null;
create index trainer_programs_trash_page on trainer_private.programs(trainer_id,trashed_at desc,id desc) where trashed_at is not null;

-- Retirar del catálogo no rompe las recetas que el usuario ya puede consultar.
-- Las tablas de referencias conservan sus propias políticas de lectura.
create policy exercise_retained_official_read on public.exercises for select to authenticated using (
 origin='system' and not is_public and (
  exists(select 1 from public.workout_items i where i.exercise_id=exercises.id)
  or exists(select 1 from public.workout_execution_sets s where s.exercise_id=exercises.id)
  or exists(select 1 from public.routine_exercises r where r.exercise_id=exercises.id)));

create table trainer_private.catalog_trash (
 scope text not null check(scope in ('trainer','admin')),
 kind text not null check(kind in ('session','program','exercise')),
 id uuid not null,family_id uuid not null,owner_id uuid references public.profiles(id) on delete cascade,
 name text not null,ids uuid[] not null check(cardinality(ids)>0),
 trashed_at timestamptz not null,
 primary key(scope,kind,id),unique(scope,kind,family_id),
 check((scope='trainer' and owner_id is not null) or (scope='admin' and kind='exercise' and owner_id is null))
);
create index catalog_trash_owner_page on trainer_private.catalog_trash(owner_id,trashed_at desc,id desc);
create table trainer_private.catalog_operations (
 actor_id uuid not null references public.profiles(id) on delete cascade,operation_id uuid not null,request jsonb not null,result jsonb not null,
 primary key(actor_id,operation_id)
);
-- Sin FK a la receta eliminada: los reintentos conservan una respuesta estable.
create table trainer_private.catalog_deleted_writes (
 owner_id uuid not null references public.profiles(id) on delete cascade,kind text not null,operation_id uuid not null,result_id uuid not null,
 primary key(owner_id,kind,operation_id)
);
create table trainer_private.catalog_deleted_items (
 kind text not null,id uuid not null,owner_id uuid references public.profiles(id) on delete set null,deleted_at timestamptz not null default clock_timestamp(),
 primary key(kind,id)
);
create index catalog_deleted_items_owner on trainer_private.catalog_deleted_items(owner_id) where owner_id is not null;
alter table trainer_private.catalog_trash enable row level security;
alter table trainer_private.catalog_operations enable row level security;
alter table trainer_private.catalog_deleted_writes enable row level security;
alter table trainer_private.catalog_deleted_items enable row level security;
revoke all on trainer_private.catalog_trash,trainer_private.catalog_operations,
 trainer_private.catalog_deleted_writes,trainer_private.catalog_deleted_items from public,anon,authenticated;

create function trainer_private.catalog_json_has_ids(p_value jsonb,p_ids uuid[]) returns boolean
language sql immutable set search_path='' as $$
 select exists(select 1 from unnest(p_ids) x where strpos(lower(p_value::text),x::text)>0)
$$;

-- Las referencias se comprueban también fuera de las FK (trabajos sin finalizar,
-- programas serializados y snapshots de dispositivos). Los recibos cerrados no
-- son un trabajo pendiente; se conservan y no pueden resucitar recetas purgadas.
create function trainer_private.catalog_delete_block_reason(p_kind text,p_ids uuid[]) returns text
language plpgsql stable security definer set search_path='' as $$
declare target regclass; r record; hit boolean; extra text; resource_owner uuid;
begin
 target:=case p_kind when 'session' then 'public.workout_templates'::regclass
  when 'exercise' then 'public.exercises'::regclass when 'program' then 'trainer_private.programs'::regclass end;
 if target is null or cardinality(p_ids)=0 then raise invalid_parameter_value; end if;
 if p_kind='exercise' then select created_by into resource_owner from public.exercises where id=any(p_ids) limit 1;
 elsif p_kind='session' then select owner_user_id into resource_owner from public.workout_templates where id=any(p_ids) limit 1;
 else select trainer_id into resource_owner from trainer_private.programs where id=any(p_ids) limit 1;end if;
 for r in select c.conrelid child,a.attname col from pg_constraint c
  join pg_attribute parent_id on parent_id.attrelid=c.confrelid and parent_id.attname='id'
  join pg_attribute a on a.attrelid=c.conrelid and a.attnum=c.conkey[array_position(c.confkey,parent_id.attnum)]
  where c.contype='f' and c.confrelid=target loop
  extra:='';
  if p_kind='session' and r.col='template_id' and r.child in ('public.workout_blocks'::regclass,
   'public.program_workout_templates'::regclass,'trainer_private.workout_writes'::regclass) then continue; end if;
  if p_kind='program' and r.col='program_id' and r.child in ('trainer_private.program_sessions'::regclass,
   'trainer_private.program_writes'::regclass) then continue; end if;
  if r.child=target then extra:=' and not id=any($1)'; end if;
  if p_kind='exercise' and r.child='trainer_private.exercise_versions'::regclass then
   extra:=' and not exercise_id=any($1)'; end if;
  execute format('select exists(select 1 from %s where %I=any($1)%s)',r.child::regclass,r.col,extra) into hit using p_ids;
  if hit then return 'Tiene asignaciones, resultados o referencias de otras recetas. Se conserva para proteger el historial.'; end if;
 end loop;
 if exists(select 1 from trainer_private.session_works w join trainer_private.session_work_bodies b
   on (b.owner_id,b.context,b.hash)=(w.owner_id,w.context,w.state_hash)
   where (resource_owner is null or w.owner_id=resource_owner) and w.lifecycle='open' and (trainer_private.catalog_json_has_ids(w.origin,p_ids) or trainer_private.catalog_json_has_ids(b.body,p_ids)))
  or exists(select 1 from trainer_private.program_works w join trainer_private.program_work_bodies b
   on (b.owner_id,b.context,b.hash)=(w.owner_id,w.context,w.state_hash)
   where (resource_owner is null or w.owner_id=resource_owner) and w.lifecycle='open' and (w.base_program_id=any(p_ids) or trainer_private.catalog_json_has_ids(b.body,p_ids)))
  or (resource_owner is null and (exists(select 1 from admin_work_private.session_work w where not w.discarded and w.result_id is null
   and (trainer_private.catalog_json_has_ids(w.origin,p_ids) or trainer_private.catalog_json_has_ids(w.state,p_ids)))
  or exists(select 1 from public.admin_guided_work_drafts w where w.discarded_at is null and w.finalized_program_id is null
   and (w.base_program_id=any(p_ids) or trainer_private.catalog_json_has_ids(w.state,p_ids))))) then
  return 'Está usado en un trabajo guardado. Quita la referencia o termina ese trabajo antes de borrar.';
 end if;
 if exists(select 1 from trainer_private.programs p where (resource_owner is null or p.trainer_id=resource_owner) and not (p_kind='program' and p.id=any(p_ids))
   and trainer_private.catalog_json_has_ids(p.content,p_ids))
  or (resource_owner is null and exists(select 1 from public.guided_programs p where trainer_private.catalog_json_has_ids(p.content,p_ids))) then
  return 'Forma parte de una versión de programa que debe conservarse.';
 end if;
 -- Los snapshots de dispositivos pertenecen al alumno, no al autor de la
 -- receta. No se filtran por autor: incluso un vínculo terminado se conserva.
 for r in select n.nspname,c.relname,a.attname from pg_class c join pg_namespace n on n.oid=c.relnamespace
  join pg_attribute a on a.attrelid=c.oid and a.attnum>0 and not a.attisdropped
  where c.relkind='r' and n.nspname='device_private' and a.atttypid='jsonb'::regtype loop
  execute format('select exists(select 1 from %I.%I where trainer_private.catalog_json_has_ids(%I,$1))',r.nspname,r.relname,r.attname)
   into hit using p_ids;
  if hit then return 'Tiene un envío o snapshot de dispositivo que debe conservarse.'; end if;
 end loop;
 return null;
end $$;

-- Solo se bloquean los recursos referenciados y sus familias. Una retirada no
-- detiene las escrituras de otros catálogos ni de otros usuarios.
create function trainer_private.catalog_lock_ids(p_ids uuid[],p_exclusive boolean default false) returns void
language plpgsql security definer set search_path='' as $$
declare item uuid; all_ids uuid[];
begin
 select array_agg(distinct x) into all_ids from (
  select unnest(p_ids) x
  union select family_id from public.workout_templates where id=any(p_ids)
  union select family_id from trainer_private.exercise_versions where exercise_id=any(p_ids)
  union select family_id from trainer_private.programs where id=any(p_ids)) refs;
 for item in select x from unnest(all_ids) x where x is not null order by x loop
  if p_exclusive then perform pg_advisory_xact_lock(hashtextextended('entrenaop:catalog:'||item::text,0));
  else perform pg_advisory_xact_lock_shared(hashtextextended('entrenaop:catalog:'||item::text,0)); end if;
 end loop;
 -- También fuerza un conflicto serializable si la instantánea RR precede a
 -- una purga/versión que terminó mientras se esperaba el advisory.
 perform 1 from public.workout_templates where id=any(p_ids) order by id for key share;
 perform 1 from public.exercises where id=any(p_ids) order by id for key share;
 perform 1 from trainer_private.programs where id=any(p_ids) order by id for key share;
end $$;

create function trainer_private.catalog_reference_lock() returns trigger
language plpgsql security definer set search_path='' as $$
declare ids uuid[]; body jsonb;
begin
 body:=case when tg_op='DELETE' then to_jsonb(old) else to_jsonb(new) end;
 select array_agg(distinct m[1]::uuid) into ids from regexp_matches(lower(body::text),
  '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}','g') m;
 perform trainer_private.catalog_lock_ids(ids);
 if tg_op<>'DELETE' and exists(select 1 from trainer_private.catalog_deleted_items where id=any(ids)) then
  raise exception 'Este trabajo hace referencia a contenido eliminado definitivamente. Actualízalo antes de guardarlo.' using errcode='22023';
 end if;
 if tg_op='DELETE' then return old; end if;
 return new;
end $$;
create function trainer_private.catalog_active_reference() returns trigger
language plpgsql security definer set search_path='' as $$
declare value uuid; previous uuid; target regclass; is_trashed boolean;
begin
 value:=(to_jsonb(new)->>tg_argv[0])::uuid;
 if tg_op='UPDATE' then previous:=(to_jsonb(old)->>tg_argv[0])::uuid; end if;
 if value is null or (tg_op='UPDATE' and value is not distinct from previous) then return new; end if;
 target:=tg_argv[1]::regclass;
 execute format('select trashed_at is not null from %s where id=$1',target) into is_trashed using value;
 if is_trashed or exists(select 1 from trainer_private.catalog_deleted_items where id=value) then
  raise exception 'El contenido está en la papelera o eliminado. Recupéralo antes de utilizarlo en una receta o asignación nueva.' using errcode='22023';
 end if;
 return new;
end $$;
create function trainer_private.catalog_guard_row() returns trigger
language plpgsql security definer set search_path='' as $$
declare resource_origin text;
begin
 if current_setting('entrenaop.catalog_lifecycle',true) is distinct from 'true' and
  ((tg_op='UPDATE' and (new.trashed_at is distinct from old.trashed_at or old.trashed_at is not null))
   or (tg_op='INSERT' and new.trashed_at is not null) or tg_op='DELETE') then
  if tg_table_name='exercises' then
   if tg_op='DELETE' then resource_origin:=old.origin;else resource_origin:=new.origin;end if;
  end if;
  if tg_table_name<>'exercises' or resource_origin in ('system','coach') then
   raise exception 'Utiliza la papelera para retirar o borrar este contenido; recupéralo antes de editarlo.' using errcode='22023';
  end if;
 end if;
 if tg_op='DELETE' then return old; end if;
 return new;
end $$;
create trigger catalog_guard_exercises before insert or update or delete on public.exercises
 for each row execute function trainer_private.catalog_guard_row();
create trigger catalog_guard_programs before insert or update or delete on trainer_private.programs
 for each row execute function trainer_private.catalog_guard_row();

-- Se descubren las FK actuales: una nueva relación no queda desprotegida por
-- omisión en la lista de comprobación de borrado.
do $$ declare r record; begin
 for r in select distinct c.conrelid tbl from pg_constraint c where c.contype='f'
  and c.confrelid in ('public.exercises'::regclass,'public.workout_templates'::regclass,'trainer_private.programs'::regclass)
  union select unnest(array['public.exercises'::regclass,'public.workout_templates'::regclass,'trainer_private.programs'::regclass,
   'trainer_private.session_works'::regclass,'trainer_private.session_work_bodies'::regclass,
   'trainer_private.program_works'::regclass,'trainer_private.program_work_bodies'::regclass,
   'admin_work_private.session_work'::regclass,'public.admin_guided_work_drafts'::regclass,'public.guided_programs'::regclass])
  union select c.oid from pg_class c join pg_namespace n on n.oid=c.relnamespace
   where c.relkind='r' and n.nspname='device_private' and exists(select 1 from pg_attribute a where a.attrelid=c.oid and a.atttypid='jsonb'::regtype and a.attnum>0 and not a.attisdropped)
 loop
  execute format('create trigger aa_catalog_reference_lock before insert or update or delete on %s for each row execute function trainer_private.catalog_reference_lock()',r.tbl::regclass);
 end loop;
end $$;
do $$ declare definition text; item text; anchor text; replacement text; begin
 -- La reconciliación de un creador cerrado tampoco puede devolver un UUID
 -- purgado como si aún hubiera contenido editable detrás del recibo.
 for item,anchor,replacement in values
  ('trainer_private.finalize_trainer_session_work(uuid,uuid,bigint)','perform trainer_private.session_work_identity(p_expected_owner);','session'),
  ('trainer_private.reopen_trainer_session_work(uuid,uuid,bigint)','perform trainer_private.session_work_identity(p_expected_owner);','session'),
  ('trainer_private.finalize_trainer_program_work(uuid,uuid,bigint,jsonb)','perform trainer_private.program_work_identity(p_expected_owner);','program') loop
  definition:=pg_get_functiondef(item::regprocedure);
  if strpos(definition,anchor)=0 then raise exception 'Revisar recibo de creador: %',item; end if;
  execute replace(definition,anchor,anchor||format(' if exists(select 1 from trainer_private.catalog_deleted_writes where owner_id=auth.uid() and kind=%L and operation_id=p_id) then raise exception ''El contenido de este trabajo fue eliminado definitivamente.'' using errcode=''P0001''; end if;',replacement));
 end loop;
end $$;
create trigger catalog_item_active before insert or update on public.workout_items for each row
 execute function trainer_private.catalog_active_reference('exercise_id','public.exercises');
create trigger catalog_routine_item_active before insert or update on public.routine_exercises for each row
 execute function trainer_private.catalog_active_reference('exercise_id','public.exercises');
create trigger catalog_program_session_active before insert or update on trainer_private.program_sessions for each row
 execute function trainer_private.catalog_active_reference('template_id','public.workout_templates');
create trigger catalog_schedule_active before insert or update on public.scheduled_workouts for each row
 execute function trainer_private.catalog_active_reference('template_id','public.workout_templates');
create trigger catalog_delivery_active before insert or update on trainer_private.program_deliveries for each row
 execute function trainer_private.catalog_active_reference('program_id','trainer_private.programs');
create trigger catalog_template_previous_active before insert or update on public.workout_templates for each row
 execute function trainer_private.catalog_active_reference('previous_version_id','public.workout_templates');
create trigger catalog_program_previous_active before insert or update on trainer_private.programs for each row
 execute function trainer_private.catalog_active_reference('previous_id','trainer_private.programs');
create trigger catalog_exercise_previous_active before insert or update on trainer_private.exercise_versions for each row
 execute function trainer_private.catalog_active_reference('previous_id','public.exercises');

create function trainer_private.catalog_require_access(p_scope text,p_write boolean) returns void
language plpgsql security definer set search_path='' as $$
begin
 if auth.uid() is null then raise insufficient_privilege; end if;
 if p_scope='trainer' then
  if p_write then perform trainer_private.require_authoring_access();
  elsif not trainer_private.has_trainer_mfa() then raise insufficient_privilege; end if;
 elsif p_scope='admin' then
  if not coalesce(public.is_admin(),false) or (auth.jwt()->>'aal') is distinct from 'aal2'
   or not exists(select 1 from auth.mfa_factors where user_id=auth.uid() and status='verified') then raise insufficient_privilege; end if;
 else raise invalid_parameter_value;
 end if;
end $$;

create function trainer_private.list_catalog_trash(p_scope text,p_kind text,p_before_at timestamptz,p_before_id uuid,p_limit integer) returns jsonb
language plpgsql stable security definer set search_path='' as $$
begin
 perform trainer_private.catalog_require_access(p_scope,false);
 if (p_before_at is null)<>(p_before_id is null) or (p_kind is not null and p_kind not in ('session','program','exercise')) then raise invalid_parameter_value; end if;
 return (select coalesce(jsonb_agg(jsonb_build_object('id',x.id,'name',x.name,'kind',x.kind,'trashed_at',x.trashed_at,'revision',null,
  'delete_block_reason',trainer_private.catalog_delete_block_reason(x.kind,x.ids)) order by x.trashed_at desc,x.id desc),'[]')
  from (select * from trainer_private.catalog_trash where scope=p_scope and (p_scope='admin' or owner_id=auth.uid())
   and (p_kind is null or kind=p_kind) and (p_before_at is null or (trashed_at,id)<(p_before_at,p_before_id))
   order by trashed_at desc,id desc limit greatest(1,least(coalesce(p_limit,50),100))) x);
end $$;

create function trainer_private.change_catalog_trash(p_scope text,p_action text,p_operation_id uuid,p_kind text,p_id uuid,p_trashed_at timestamptz) returns jsonb
language plpgsql security definer set search_path='' as $$
declare prior trainer_private.catalog_operations; entry trainer_private.catalog_trash; owner uuid;
 family uuid; ids uuid[]; title text; item record; stamp timestamptz; reason text; affected integer;
 request jsonb; result jsonb; context_before text:=current_setting('entrenaop.catalog_lifecycle',true);
 session_context text:=current_setting('entrenaop.session_trash_operation',true);
begin
 perform trainer_private.catalog_require_access(p_scope,true);
 if p_operation_id is null or p_id is null or p_kind is null or p_kind not in ('session','program','exercise') or p_action is null or p_action not in ('trash','restore','purge')
  or (p_scope='admin' and p_kind<>'exercise') or (p_action<>'trash' and p_trashed_at is null) then raise invalid_parameter_value; end if;
 if p_kind='exercise' and p_id='20000000-0000-4000-8000-000000000004'::uuid and p_action in ('trash','purge') then
  raise exception 'El ejercicio técnico de carrera es parte del motor y no se puede retirar ni borrar.' using errcode='22023';
 end if;
 request:=jsonb_build_object('scope',p_scope,'action',p_action,'kind',p_kind,'id',p_id,'trashed_at',p_trashed_at);
 perform pg_advisory_xact_lock(hashtextextended('entrenaop:catalog-operation:'||auth.uid()::text||':'||p_operation_id::text,0));
 select * into prior from trainer_private.catalog_operations where actor_id=auth.uid() and operation_id=p_operation_id;
 if found then
  if prior.request is distinct from request then raise exception 'El reintento no coincide con la operación original.' using errcode='22023'; end if;
  return prior.result;
 end if;
 owner:=case when p_scope='trainer' then auth.uid() end;
 if p_action='trash' then
  if p_kind='exercise' then
   if p_scope='admin' then
    select e.id,e.name into family,title from public.exercises e where e.id=p_id and e.origin='system' and e.created_by is null;
    ids:=array[family];
   else
    select v.family_id,e.name into family,title from trainer_private.exercise_versions v join public.exercises e on e.id=v.exercise_id
     where v.exercise_id=p_id and v.trainer_id=owner;
    select array_agg(exercise_id) into ids from trainer_private.exercise_versions where family_id=family and trainer_id=owner;
   end if;
  elsif p_kind='session' then
   select t.family_id,t.name into family,title from public.workout_templates t where t.id=p_id and t.owner_user_id=owner and t.origin='coach'
    and not exists(select 1 from trainer_private.assignment_variants v where v.template_id=t.id);
   select array_agg(id) into ids from public.workout_templates where family_id=family and owner_user_id=owner and origin='coach';
  else
   select p.family_id,p.content->>'name' into family,title from trainer_private.programs p where p.id=p_id and p.trainer_id=owner;
   select array_agg(id) into ids from trainer_private.programs where family_id=family and trainer_id=owner;
  end if;
  if family is null or ids is null then raise insufficient_privilege; end if;
  perform trainer_private.catalog_lock_ids(ids||array[family],true);
  -- Se relee después de adquirir la familia: una revisión concurrente que ya
  -- hubiera terminado también debe formar parte de esta misma papelera.
  if p_kind='exercise' and p_scope='trainer' then
   select array_agg(exercise_id) into ids from trainer_private.exercise_versions where family_id=family and trainer_id=owner;
  elsif p_kind='session' then
   select array_agg(id) into ids from public.workout_templates where family_id=family and owner_user_id=owner and origin='coach';
  elsif p_kind='program' then
   select array_agg(id) into ids from trainer_private.programs where family_id=family and trainer_id=owner;
  end if;
  perform trainer_private.catalog_lock_ids(ids,true);
  select * into entry from trainer_private.catalog_trash where scope=p_scope and kind=p_kind and family_id=family for update;
  if not found then
   stamp:=clock_timestamp();
   insert into trainer_private.catalog_trash(scope,kind,id,family_id,owner_id,name,ids,trashed_at)
    values(p_scope,p_kind,p_id,family,owner,coalesce(title,'Sin título'),ids,stamp) returning * into entry;
  end if;
 else
  select * into entry from trainer_private.catalog_trash where scope=p_scope and kind=p_kind and id=p_id
   and (p_scope='admin' or owner_id=owner);
  if not found then raise exception 'La papelera ha cambiado. Actualiza antes de continuar.' using errcode='40001'; end if;
  perform trainer_private.catalog_lock_ids(entry.ids||array[entry.family_id],true);
  select * into entry from trainer_private.catalog_trash where scope=p_scope and kind=p_kind and id=p_id
   and (p_scope='admin' or owner_id=owner) for update;
  if not found then raise exception 'La papelera ha cambiado. Actualiza antes de continuar.' using errcode='40001'; end if;
  if entry.trashed_at is distinct from p_trashed_at then raise exception 'La papelera ha cambiado. Actualiza antes de continuar.' using errcode='40001'; end if;
 end if;
 perform set_config('entrenaop.catalog_lifecycle','true',true);
 perform set_config('entrenaop.session_trash_operation','true',true);
 if p_action='trash' then
  if p_kind='exercise' then
   update public.exercises set trashed_at=entry.trashed_at,is_public=false where id=any(entry.ids);
  elsif p_kind='session' then
   update public.workout_templates set trashed_at=entry.trashed_at,trash_previous_status=coalesce(trash_previous_status,status) where id=any(entry.ids);
  else update trainer_private.programs set trashed_at=entry.trashed_at where id=any(entry.ids);
  end if;
 elsif p_action='restore' then
  if p_kind='exercise' then update public.exercises set trashed_at=null,is_public=false where id=any(entry.ids);
  elsif p_kind='session' then update public.workout_templates set trashed_at=null,trash_previous_status=null where id=any(entry.ids);
  else update trainer_private.programs set trashed_at=null where id=any(entry.ids); end if;
  delete from trainer_private.catalog_trash where scope=p_scope and kind=p_kind and id=p_id;
 else
  reason:=trainer_private.catalog_delete_block_reason(p_kind,entry.ids);
  if reason is not null then raise exception '%',reason using errcode='P0001'; end if;
  insert into trainer_private.catalog_deleted_items(kind,id,owner_id) select p_kind,unnest(entry.ids),owner;
  if p_kind='exercise' then
   insert into trainer_private.catalog_deleted_writes select trainer_id,'exercise',operation_id,exercise_id
    from trainer_private.exercise_versions where exercise_id=any(entry.ids);
   select count(*) into affected from trainer_private.exercise_versions where exercise_id=any(entry.ids);
   -- Se conservan reservas y ficheros: SQL no borra objetos Storage/proveedor.
   for item in select exercise_id from trainer_private.exercise_versions where exercise_id=any(entry.ids) order by version desc loop
    delete from trainer_private.exercise_versions where exercise_id=item.exercise_id;
    delete from public.exercises where id=item.exercise_id;
   end loop;
   if p_scope='admin' then delete from public.exercises where id=any(entry.ids);
   else update trainer_private.exercise_limits set exercise_used=greatest(0,exercise_used-affected) where trainer_id=owner; end if;
  elsif p_kind='session' then
   insert into trainer_private.catalog_deleted_writes select trainer_id,'session',operation_id,template_id from trainer_private.workout_writes where template_id=any(entry.ids);
   delete from trainer_private.workout_writes where template_id=any(entry.ids);
   for item in select id from public.workout_templates where id=any(entry.ids) order by version desc loop
    delete from public.workout_templates where id=item.id;
   end loop;
  else
   insert into trainer_private.catalog_deleted_writes select trainer_id,'program',operation_id,program_id from trainer_private.program_writes where program_id=any(entry.ids);
   delete from trainer_private.program_writes where program_id=any(entry.ids);
   for item in select id from trainer_private.programs where id=any(entry.ids) order by version desc loop
    delete from trainer_private.programs where id=item.id;
   end loop;
  end if;
  delete from trainer_private.catalog_trash where scope=p_scope and kind=p_kind and id=p_id;
 end if;
 perform set_config('entrenaop.catalog_lifecycle',coalesce(context_before,''),true);
 perform set_config('entrenaop.session_trash_operation',coalesce(session_context,''),true);
 result:=jsonb_build_object('id',entry.id,'kind',p_kind,'trashed_at',case when p_action='trash' then entry.trashed_at end,
  'status',case p_action when 'trash' then 'trashed' when 'restore' then 'restored' else 'purged' end);
 insert into trainer_private.catalog_operations values(auth.uid(),p_operation_id,request,result);
 return result;
exception when foreign_key_violation then
 raise exception 'Hay referencias que deben conservarse. No se ha borrado nada; actualiza la papelera.' using errcode='P0001';
end $$;

-- Filtros sobre el SELECT original, antes de paginar; no se alteran las lecturas
-- por ID que necesitan agenda, ejecución e historial.
do $$ declare definition text; item text; anchor text; replacement text; begin
 for item,anchor,replacement in values
  ('trainer_private.list_exercises()','where v.trainer_id=auth.uid()','where v.trainer_id=auth.uid() and e.trashed_at is null'),
  ('trainer_private.list_trainer_programs(timestamptz,uuid)','where trainer_id=auth.uid() and status=''published''','where trainer_id=auth.uid() and trashed_at is null and status=''published'''),
  ('trainer_private.list_trainer_workouts(timestamptz,uuid)','where t.owner_user_id=auth.uid()','where t.trashed_at is null and t.owner_user_id=auth.uid()')
 loop
  definition:=pg_get_functiondef(item::regprocedure);
  if strpos(definition,anchor)=0 then raise exception 'Revisar filtro de papelera: %',item; end if;
  execute replace(definition,anchor,replacement);
 end loop;
 -- Los recibos de autoría eliminados no se recrean ni devuelven UUID inexistente.
 for item,anchor in values ('trainer_private.save_exercise(uuid,jsonb,uuid)','exercise'),
  ('trainer_private.save_trainer_workout(uuid,jsonb,uuid)','session'),
  ('trainer_private.save_trainer_program(uuid,jsonb,uuid)','program') loop
  definition:=pg_get_functiondef(item::regprocedure);
  replacement:=E'perform trainer_private.require_authoring_access();\n perform trainer_private.catalog_lock_ids(array[p_previous_id]);\n'
   ||format(' if exists(select 1 from trainer_private.catalog_deleted_writes where owner_id=auth.uid() and kind=%L and operation_id=p_operation_id) then raise exception ''El contenido de esta operación fue eliminado definitivamente.'' using errcode=''P0001''; end if;',anchor);
  if strpos(definition,'perform trainer_private.require_authoring_access();')=0 then raise exception 'Revisar autoría: %',item; end if;
  execute replace(definition,'perform trainer_private.require_authoring_access();',replacement);
 end loop;
end $$;

create function public.list_trainer_catalog_trash(p_kind text default null,p_before_at timestamptz default null,p_before_id uuid default null,p_limit integer default 50) returns jsonb
language sql stable security invoker set search_path='' as $$select trainer_private.list_catalog_trash('trainer',p_kind,p_before_at,p_before_id,p_limit)$$;
create function public.trash_trainer_catalog_item(p_operation_id uuid,p_kind text,p_id uuid) returns jsonb
language sql volatile security invoker set search_path='' as $$select trainer_private.change_catalog_trash('trainer','trash',p_operation_id,p_kind,p_id,null)$$;
create function public.restore_trainer_catalog_item(p_operation_id uuid,p_kind text,p_id uuid,p_trashed_at timestamptz) returns jsonb
language sql volatile security invoker set search_path='' as $$select trainer_private.change_catalog_trash('trainer','restore',p_operation_id,p_kind,p_id,p_trashed_at)$$;
create function public.purge_trainer_catalog_item(p_operation_id uuid,p_kind text,p_id uuid,p_trashed_at timestamptz) returns jsonb
language sql volatile security invoker set search_path='' as $$select trainer_private.change_catalog_trash('trainer','purge',p_operation_id,p_kind,p_id,p_trashed_at)$$;
create function public.list_admin_exercise_trash(p_before_at timestamptz default null,p_before_id uuid default null,p_limit integer default 50) returns jsonb
language sql stable security invoker set search_path='' as $$select trainer_private.list_catalog_trash('admin','exercise',p_before_at,p_before_id,p_limit)$$;
create function public.trash_admin_exercise(p_operation_id uuid,p_id uuid) returns jsonb
language sql volatile security invoker set search_path='' as $$select trainer_private.change_catalog_trash('admin','trash',p_operation_id,'exercise',p_id,null)$$;
create function public.restore_admin_exercise(p_operation_id uuid,p_id uuid,p_trashed_at timestamptz) returns jsonb
language sql volatile security invoker set search_path='' as $$select trainer_private.change_catalog_trash('admin','restore',p_operation_id,'exercise',p_id,p_trashed_at)$$;
create function public.purge_admin_exercise(p_operation_id uuid,p_id uuid,p_trashed_at timestamptz) returns jsonb
language sql volatile security invoker set search_path='' as $$select trainer_private.change_catalog_trash('admin','purge',p_operation_id,'exercise',p_id,p_trashed_at)$$;

do $$ declare f regprocedure; begin
 for f in select p.oid::regprocedure from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where (n.nspname='trainer_private' and p.proname in ('catalog_json_has_ids','catalog_delete_block_reason','catalog_lock_ids','catalog_reference_lock',
   'catalog_active_reference','catalog_guard_row','catalog_require_access','list_catalog_trash','change_catalog_trash'))
   or (n.nspname='public' and p.proname in ('list_trainer_catalog_trash','trash_trainer_catalog_item','restore_trainer_catalog_item',
    'purge_trainer_catalog_item','list_admin_exercise_trash','trash_admin_exercise','restore_admin_exercise','purge_admin_exercise')) loop
  execute format('revoke all on function %s from public,anon,authenticated',f);
 end loop;
end $$;
grant execute on function trainer_private.list_catalog_trash(text,text,timestamptz,uuid,integer),trainer_private.change_catalog_trash(text,text,uuid,text,uuid,timestamptz),
 public.list_trainer_catalog_trash(text,timestamptz,uuid,integer),public.trash_trainer_catalog_item(uuid,text,uuid),
 public.restore_trainer_catalog_item(uuid,text,uuid,timestamptz),public.purge_trainer_catalog_item(uuid,text,uuid,timestamptz),
 public.list_admin_exercise_trash(timestamptz,uuid,integer),public.trash_admin_exercise(uuid,uuid),
 public.restore_admin_exercise(uuid,uuid,timestamptz),public.purge_admin_exercise(uuid,uuid,timestamptz) to authenticated;

commit;
