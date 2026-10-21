-- ADM-004: borrado explícito de la papelera; las referencias históricas no se purgan.
begin;
create table admin_ops_private.deleted_resources (
  kind text not null check(kind in ('program','work','session')),
  resource_id uuid not null,
  owner_id uuid,
  deleted_at timestamptz not null default clock_timestamp(),
  primary key(kind,resource_id)
);
alter table admin_ops_private.deleted_resources enable row level security;
revoke all on admin_ops_private.deleted_resources from public,anon,authenticated;

alter table public.workout_templates add column trashed_at timestamptz,
  add column trash_previous_status text;
alter table public.workout_templates add constraint official_session_trash_state check (
  (trashed_at is null and trash_previous_status is null) or
  (trashed_at is not null and trash_previous_status is not null and trash_previous_status in ('draft','published','archived')
    and origin='system' and owner_user_id is null and status='archived' and visibility='private'));
create index official_session_trash_idx on public.workout_templates(trashed_at desc) where trashed_at is not null;-- El cliente administra recetas oficiales por RPC; DELETE directo solo propio.-- Las funciones de autoría existentes son SECURITY DEFINER y conservan su edición.drop policy workout_templates_delete_owned on public.workout_templates;create policy workout_templates_delete_owned on public.workout_templatesfor delete to authenticated using (origin='user' and owner_user_id=(select auth.uid()));

create function admin_ops_private.guard_session_trash() returns trigger
language plpgsql security definer set search_path='' as $$
begin
  if current_setting('entrenaop.session_trash_operation',true) is distinct from 'true' and (
    new.trashed_at is not null or (TG_OP='UPDATE' and old.trashed_at is not null)) then
    raise exception 'La sesión está en la papelera. Recupérala antes de editar o publicar.' using errcode='22023';
  end if;
  return new;
end $$;
revoke all on function admin_ops_private.guard_session_trash() from public,anon,authenticated;
create trigger guard_session_trash before insert or update on public.workout_templates
for each row execute function admin_ops_private.guard_session_trash();

create function public.trash_admin_session(p_id uuid) returns void
language plpgsql security definer set search_path='' as $$
declare t public.workout_templates;
begin
  if auth.uid() is null or not coalesce(public.is_admin(),false) then raise insufficient_privilege; end if;
  select * into t from public.workout_templates where id=p_id and origin='system' and owner_user_id is null
    and exists(select 1 from public.program_workout_templates where template_id=p_id) for update;
  if not found then raise exception 'Sesión oficial no disponible.' using errcode='22023'; end if;
  if t.trashed_at is not null then return; end if;
  if exists(select 1 from public.guided_program_links where template_id=p_id)
    or exists(select 1 from public.guided_warmups where template_id=p_id) then
    raise exception 'La sesión sigue enlazada a programas o calentamientos. Quita esas referencias antes de moverla a la papelera.' using errcode='P0001';
  end if;
  if exists(select 1 from public.scheduled_workouts where template_id=p_id and status in ('planned','in_progress')) then
    raise exception 'Hay entrenamientos pendientes o en curso. Reprográmalos antes de retirar la sesión.' using errcode='22023';
  end if;
  perform set_config('entrenaop.session_trash_operation','true',true);
  update public.workout_templates set trashed_at=clock_timestamp(),trash_previous_status=status,
    status='archived',visibility='private',updated_at=clock_timestamp() where id=p_id;
  perform set_config('entrenaop.session_trash_operation','false',true);
end $$;

-- Sustituye el borrado inmediato antiguo de los borradores desde la ficha.
create or replace function public.remove_admin_workout(p_template_id uuid) returns void
language plpgsql security definer set search_path='' as $$
begin perform public.trash_admin_session(p_template_id); end $$;

create function public.restore_admin_session(p_id uuid,p_trashed_at timestamptz) returns void
language plpgsql security definer set search_path='' as $$
declare t public.workout_templates;
begin
  if auth.uid() is null or not coalesce(public.is_admin(),false) then raise insufficient_privilege; end if;
  select * into t from public.workout_templates where id=p_id and origin='system' and owner_user_id is null for update;
  if not found then raise exception 'La sesión ya no existe.' using errcode='22023'; end if;
  if p_trashed_at is null then raise invalid_parameter_value; end if;
  if t.trashed_at is null then return; end if;
  if t.trashed_at<>p_trashed_at then raise exception 'La papelera ha cambiado. Actualiza antes de recuperar.' using errcode='40001'; end if;
  perform set_config('entrenaop.session_trash_operation','true',true);
  update public.workout_templates set status=case when trash_previous_status='draft' then 'draft' else 'archived' end,
    trashed_at=null,trash_previous_status=null,updated_at=clock_timestamp() where id=p_id;
  perform set_config('entrenaop.session_trash_operation','false',true);
end $$;

create function public.list_admin_session_trash() returns jsonb
language plpgsql stable security definer set search_path='' as $$
begin
  if auth.uid() is null or not coalesce(public.is_admin(),false) then raise insufficient_privilege; end if;
  return coalesce((select jsonb_agg(jsonb_build_object('kind','session','id',t.id,'name',t.name,
    'trashed_at',t.trashed_at,'revision',null,'versions',t.version,'work_count',0) order by t.trashed_at desc)
    from public.workout_templates t where t.trashed_at is not null),'[]'::jsonb);
end $$;

create function public.purge_admin_trash(p_kind text,p_id uuid,p_trashed_at timestamptz,p_revision bigint default null)
returns void language plpgsql security definer set search_path='' as $$
declare ids uuid[]; works uuid[]; w public.admin_guided_work_drafts; t public.workout_templates; first_stamp timestamptz; last_stamp timestamptz;
begin
  if auth.uid() is null or not coalesce(public.is_admin(),false) then raise insufficient_privilege; end if;
  if p_id is null or p_trashed_at is null or p_kind is null or p_kind not in ('program','work','session') then raise invalid_parameter_value; end if;
  if exists(select 1 from admin_ops_private.deleted_resources where kind=p_kind and resource_id=p_id
    and (kind<>'work' or owner_id=auth.uid())) then return; end if;
  if p_kind='program' then
    perform pg_advisory_xact_lock(hashtextextended(p_id::text,0));
    select array_agg(id),min(trashed_at),max(trashed_at) into ids,first_stamp,last_stamp
      from public.guided_programs where family_id=p_id;
    if ids is null or first_stamp is distinct from p_trashed_at or last_stamp is distinct from p_trashed_at
      or exists(select 1 from public.guided_programs where id=any(ids) and trashed_at is null) then
      raise exception 'El programa ya no está en ese lote de papelera. Actualiza antes de borrar.' using errcode='40001'; end if;
    if exists(select 1 from public.guided_program_follows where program_id=any(ids)) then
      raise exception 'Este programa tiene seguimientos. Se conserva en la papelera para proteger el historial.' using errcode='P0001'; end if;
    if exists(select 1 from public.admin_guided_work_drafts where (base_program_id=any(ids) or finalized_program_id=any(ids))
      and (owner_id<>auth.uid() or (finalized_program_id is not null and not finalized_program_id=any(ids)))) then
      raise exception 'Existen trabajos ajenos o de otro programa. No se puede borrar esta familia.' using errcode='P0001'; end if;
    select array_agg(id) into works from public.admin_guided_work_drafts
      where base_program_id=any(ids) or finalized_program_id=any(ids);
    insert into admin_ops_private.deleted_resources(kind,resource_id,owner_id)
      select 'work',id,owner_id from public.admin_guided_work_drafts where id=any(works);
    delete from public.admin_guided_work_drafts where id=any(works);
    delete from public.guided_program_covers where program_id=any(ids);
    insert into admin_ops_private.deleted_resources(kind,resource_id) select 'program',unnest(ids);
    -- Solo se eliminan enlaces propiedad del programa; jamás workout_templates.
    delete from public.guided_programs where id=any(ids);
  elsif p_kind='work' then
    select * into w from public.admin_guided_work_drafts where id=p_id for update;
    if not found or w.owner_id<>auth.uid() then raise insufficient_privilege; end if;
    if w.discarded_at is distinct from p_trashed_at or w.discarded_at is null
      or w.revision is distinct from p_revision or w.finalized_program_id is not null then
      raise exception 'El trabajo ha cambiado. Actualiza antes de borrar.' using errcode='40001'; end if;
    insert into admin_ops_private.deleted_resources(kind,resource_id,owner_id) values('work',p_id,auth.uid());
    delete from public.admin_guided_work_drafts where id=p_id;
  else
    select * into t from public.workout_templates where id=p_id and origin='system' and owner_user_id is null for update;
    if not found or t.trashed_at is null or t.trashed_at is distinct from p_trashed_at then
      raise exception 'La sesión ya no está en ese lote de papelera. Actualiza antes de borrar.' using errcode='40001'; end if;
    if exists(select 1 from public.guided_program_links where template_id=p_id)
      or exists(select 1 from public.guided_warmups where template_id=p_id)
      or exists(select 1 from public.workout_templates where previous_version_id=p_id) then
      raise exception 'La sesión está referenciada por programas, calentamientos u otras versiones. Se conserva.' using errcode='P0001'; end if;
    if exists(select 1 from public.workout_executions where template_id=p_id)
      or exists(select 1 from public.scheduled_workouts where template_id=p_id)
      or exists(select 1 from public.guided_program_runs where template_id=p_id) then
      raise exception 'La sesión tiene entrenamientos o resultados registrados. Se conserva para proteger el historial.' using errcode='P0001'; end if;
    if exists(select 1 from public.admin_guided_work_drafts where jsonb_path_exists(state,'$.** ? (@ == $id)',jsonb_build_object('id',p_id::text))) then
      raise exception 'La sesión está usada en un trabajo guardado. Quita esa referencia antes de borrarla.' using errcode='P0001'; end if;
    insert into admin_ops_private.deleted_resources(kind,resource_id) values('session',p_id);
    delete from public.workout_templates where id=p_id;
  end if;
exception when foreign_key_violation then
  raise exception 'Hay referencias que deben conservarse. No se ha borrado nada; actualiza la papelera.' using errcode='P0001';
end $$;

create function public.load_admin_guided_work(p_id uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare w public.admin_guided_work_drafts;
begin
  if auth.uid() is null or not coalesce(public.is_admin(),false) then raise insufficient_privilege; end if;
  if exists(select 1 from admin_ops_private.deleted_resources where kind='work' and resource_id=p_id and owner_id=auth.uid()) then
    return jsonb_build_object('permanently_deleted',true); end if;
  select * into w from public.admin_guided_work_drafts where id=p_id;
  if not found then return null; end if;
  if w.owner_id<>auth.uid() then raise insufficient_privilege; end if;
  return to_jsonb(w)||jsonb_build_object('base_program',(select jsonb_build_object('trashed_at',trashed_at)
    from public.guided_programs where id=w.base_program_id));
end $$;

create or replace function admin_ops_private.guard_guided_work_trash() returns trigger
language plpgsql security definer set search_path='' as $$
declare p public.guided_programs; refs uuid[];
begin
  if exists(select 1 from admin_ops_private.deleted_resources where kind='work' and resource_id=new.id) then
    raise exception 'Este trabajo se ha borrado definitivamente.' using errcode='22023'; end if;
  if new.base_program_id is not null then
    select * into p from public.guided_programs where id=new.base_program_id for share;
    if p.trashed_at is not null then raise exception 'El programa de origen está en la papelera. Recupéralo primero.' using errcode='22023'; end if;
  end if;
  select array_agg(distinct (v#>>'{}')::uuid) into refs from jsonb_path_query(new.state,'$.** ? (@.type() == "string")') v
    where (v#>>'{}') ~ '^[a-fA-F0-9]{8}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{12}$';
  -- Estas referencias JSON no tienen FK: bloquear la receta y comprobar sus
  -- lápidas evita guardar un enlace mientras otra petición la elimina.
  perform id from public.workout_templates where id=any(refs) order by id for key share;
  if exists(select 1 from admin_ops_private.deleted_resources where kind='session' and resource_id=any(refs)) then
    raise exception 'El trabajo contiene una sesión borrada definitivamente.' using errcode='22023'; end if;
  return new;
end $$;

revoke all on function public.trash_admin_session(uuid),public.restore_admin_session(uuid,timestamptz),
  public.list_admin_session_trash(),public.purge_admin_trash(text,uuid,timestamptz,bigint),public.load_admin_guided_work(uuid) from public,anon,authenticated;
grant execute on function public.trash_admin_session(uuid),public.restore_admin_session(uuid,timestamptz),
  public.list_admin_session_trash(),public.purge_admin_trash(text,uuid,timestamptz,bigint),public.load_admin_guided_work(uuid) to authenticated;

-- El historial conserva la auditoría, sin resucitar recursos purgados.
create or replace function public.restore_admin_editorial_event(p_event_id bigint,p_request_id uuid,p_use_before boolean default false)
returns uuid language plpgsql security definer set search_path='' as $$
declare event admin_ops_private.editorial_events; saved admin_ops_private.restorations; data jsonb; result uuid;
begin
  if auth.uid() is null or not coalesce(public.is_admin(),false) then raise insufficient_privilege; end if;
  if p_request_id is null or p_use_before is null then raise invalid_parameter_value; end if;
  perform pg_advisory_xact_lock(hashtextextended(p_request_id::text,22));
  select * into saved from admin_ops_private.restorations where request_id=p_request_id;
  if found then
    if saved.actor_id<>auth.uid() or saved.event_id<>p_event_id or saved.use_before<>p_use_before then
      raise exception 'Este reintento pertenece a otra recuperación.' using errcode='22023';
    end if;
    if exists(select 1 from admin_ops_private.deleted_resources where resource_id=saved.resource_id and kind in ('program','session')) then
      raise exception 'El recurso recuperado se borró definitivamente.' using errcode='22023'; end if;
    return saved.resource_id;
  end if;
  select * into event from admin_ops_private.editorial_events where id=p_event_id;
  if not found then raise no_data_found; end if;
  if exists(select 1 from admin_ops_private.deleted_resources where kind=event.resource_type and resource_id=event.resource_id) then
    raise exception 'Este recurso se borró definitivamente y no se puede recuperar desde el historial.' using errcode='22023'; end if;
  data:=case when p_use_before then event.before_data else event.after_data end;
  if data is null then raise exception 'Ese estado no contiene un recurso recuperable.' using errcode='22023'; end if;
  if event.resource_type='session' then
    if jsonb_path_exists(data,'$.payload.blocks[*].exercises[*].sets[*].performance_prescription ? (@ != null)')
      or jsonb_path_exists(data,'$.payload.blocks[*].exercises[*].sets[*].target_rpe ? (@ != null)')
      or jsonb_path_exists(data,'$.payload.blocks[*].exercises[*].notes ? (@ != null && @ != "")') then
      raise exception 'Esta receta contiene una prescripción especial y necesita revisión específica antes de recuperarla.' using errcode='22023';
    end if;
    result:=public.create_admin_workout_draft(case when data->>'catalog_scope'='program' then data->>'program_id' else null end,
      jsonb_set(data->'payload','{name}',to_jsonb(left(data->>'name',105)||' · recuperada')));
    update public.workout_templates set show_in_library=coalesce((data->>'show_in_library')::boolean,false) where id=result;
  elsif event.resource_type='program' then
    result:=public.save_guided_program(jsonb_set(data->'payload','{name}',to_jsonb(left(data->>'name',105)||' · recuperado')),null,
      array(select jsonb_array_elements_text(data->'category_ids')::uuid),(data->>'primary_category_id')::uuid);
  else
    raise exception 'La recuperación como borrador está disponible para sesiones y programas.' using errcode='22023';
  end if;
  insert into admin_ops_private.restorations values(p_request_id,auth.uid(),p_event_id,p_use_before,result);
  return result;
end $$;

create or replace function admin_ops_private.snapshot(p_kind text,p_id uuid) returns jsonb
language plpgsql security invoker set search_path='' as $$
declare result jsonb;
begin
  if p_kind='session' then
    select jsonb_build_object('name',t.name,'status',t.status,'version',t.version,
      'trashed_at',t.trashed_at,'show_in_library',t.show_in_library,'program_id',l.program_id,'catalog_scope',l.catalog_scope,
      'payload',jsonb_build_object('name',t.name,'description',t.description,
        'estimated_duration_minutes',t.estimated_duration_minutes,'blocks',coalesce((
          select jsonb_agg(jsonb_build_object('name',b.name,'format',b.format,'rounds',b.rounds,
            'time_cap_seconds',b.time_cap_seconds,'rest_after_seconds',b.rest_after_seconds,
            'exercises',coalesce((select jsonb_agg(jsonb_build_object('exercise_id',i.exercise_id,'notes',i.notes,
              'sets',coalesce((select jsonb_agg(to_jsonb(s)-'id'-'item_id'-'order_index' order by s.order_index)
                 from public.workout_sets s where s.item_id=i.id),'[]'::jsonb)) order by i.order_index)
              from public.workout_items i where i.block_id=b.id),'[]'::jsonb)) order by b.order_index)
          from public.workout_blocks b where b.template_id=t.id),'[]'::jsonb))) into result
    from public.workout_templates t left join public.program_workout_templates l on l.template_id=t.id
    where t.id=p_id and t.origin='system' and t.owner_user_id is null;
  elsif p_kind='program' then
    select jsonb_build_object('name',p.content->>'name','status',p.status,'version',p.version,'trashed_at',p.trashed_at,
      'payload',p.content,'category_ids',coalesce((select jsonb_agg(l.category_id order by l.category_id)
        from public.guided_program_category_links l where l.program_id=p.id),'[]'::jsonb),
      'primary_category_id',(select l.category_id from public.guided_program_category_links l
         where l.program_id=p.id and l.is_primary)) into result
    from public.guided_programs p where p.id=p_id;
  elsif p_kind='warmup' then
    select jsonb_build_object('name',w.name,'status',w.status,'version',w.version,
      'payload',admin_ops_private.snapshot('session',w.template_id)->'payload') into result
    from public.guided_warmups w where w.id=p_id;
  elsif p_kind='exercise' then
    select to_jsonb(e)-'created_by'-'created_at' into result
    from public.exercises e where e.id=p_id and e.origin='system';
  end if;
  return result;
end $$;
revoke all on function admin_ops_private.snapshot(text,uuid) from public,anon,authenticated;



commit;
