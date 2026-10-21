-- ADM-003: papelera reversible por familia. Nunca elimina recetas ni referencias.
begin;

alter table public.guided_programs add column trashed_at timestamptz;
alter table public.guided_programs add constraint guided_program_trash_not_published
  check (trashed_at is null or status <> 'published');
create index guided_program_trash_idx on public.guided_programs(trashed_at desc, family_id)
  where trashed_at is not null;

create function admin_ops_private.guard_guided_program_trash() returns trigger
language plpgsql security definer set search_path='' as $$
begin
  -- Compartido con guardado y publicación: familia antes de modificar una versión.
  perform pg_advisory_xact_lock(hashtextextended(new.family_id::text,0));
  if current_setting('entrenaop.guided_trash_operation',true) is distinct from 'true' then
    if (TG_OP='UPDATE' and old.trashed_at is not null) or new.trashed_at is not null
      or exists(select 1 from public.guided_programs p
        where p.family_id=new.family_id and p.trashed_at is not null) then
      raise exception 'El programa está en la papelera. Recupéralo antes de editar o publicar.' using errcode='22023';
    end if;
  end if;
  return new;
end $$;
revoke all on function admin_ops_private.guard_guided_program_trash() from public,anon,authenticated;
create trigger guard_guided_program_trash before insert or update on public.guided_programs
  for each row execute function admin_ops_private.guard_guided_program_trash();

create function admin_ops_private.guard_guided_work_trash() returns trigger
language plpgsql security definer set search_path='' as $$
declare p public.guided_programs;
begin
  -- La papelera no bloquea trabajos al retirar una familia: solo bloquea sus
  -- programas. Tomar SHARE aquí conserva ese orden sin invertir familia/trabajo.
  if new.base_program_id is not null then
    select * into p from public.guided_programs where id=new.base_program_id for share;
    if p.trashed_at is not null then
      raise exception 'El programa de origen está en la papelera. Recupéralo primero.' using errcode='22023';
    end if;
  end if;
  return new;
end $$;
revoke all on function admin_ops_private.guard_guided_work_trash() from public,anon,authenticated;
create trigger guard_guided_work_trash before insert or update on public.admin_guided_work_drafts
  for each row execute function admin_ops_private.guard_guided_work_trash();

create function admin_ops_private.guard_guided_cover_trash() returns trigger
language plpgsql security definer set search_path='' as $$
begin
  perform 1 from public.guided_programs where id=new.program_id and trashed_at is null for share;
  if not found then
    raise exception 'Recupera el programa de la papelera antes de cambiar su portada.' using errcode='22023';
  end if;
  return new;
end $$;
revoke all on function admin_ops_private.guard_guided_cover_trash() from public,anon,authenticated;
create trigger guard_guided_cover_trash before insert or update on public.guided_program_covers
  for each row execute function admin_ops_private.guard_guided_cover_trash();

create function public.trash_admin_guided_program(p_program_id uuid) returns void
language plpgsql security definer set search_path='' as $$
declare family uuid; stamp timestamptz:=clock_timestamp();
begin
  if auth.uid() is null or not coalesce(public.is_admin(),false) then raise insufficient_privilege; end if;
  select family_id into family from public.guided_programs where id=p_program_id;
  if not found then raise exception 'Programa no disponible.' using errcode='22023'; end if;
  perform pg_advisory_xact_lock(hashtextextended(family::text,0));
  if exists(select 1 from public.guided_programs where family_id=family and trashed_at is not null) then return; end if;
  perform set_config('entrenaop.guided_trash_operation','true',true);
  update public.guided_programs set trashed_at=stamp,
    status=case when status='published' then 'archived' else status end where family_id=family;
  perform set_config('entrenaop.guided_trash_operation','false',true);
end $$;

create function public.restore_admin_guided_program(p_family_id uuid,p_trashed_at timestamptz) returns void
language plpgsql security definer set search_path='' as $$
declare first_stamp timestamptz; last_stamp timestamptz;
begin
  if auth.uid() is null or not coalesce(public.is_admin(),false) then raise insufficient_privilege; end if;
  if p_family_id is null or p_trashed_at is null then raise exception 'Recuperación inválida.' using errcode='22023'; end if;
  perform pg_advisory_xact_lock(hashtextextended(p_family_id::text,0));
  select min(trashed_at),max(trashed_at) into first_stamp,last_stamp from public.guided_programs where family_id=p_family_id;
  -- Repetir una respuesta perdida no crea versiones ni vuelve a publicar.
  if first_stamp is null then return; end if;
  if first_stamp<>p_trashed_at or last_stamp<>p_trashed_at then
    raise exception 'La papelera ha cambiado. Actualiza antes de recuperar.' using errcode='40001';
  end if;
  perform set_config('entrenaop.guided_trash_operation','true',true);
  update public.guided_programs set trashed_at=null where family_id=p_family_id;
  perform set_config('entrenaop.guided_trash_operation','false',true);
end $$;

-- El descarte existente ya era lógico; ahora queda recuperable, con revisión
-- nueva para que una pestaña anterior no pueda sobrescribir el trabajo restaurado.
create or replace function public.discard_admin_guided_work(p_id uuid,p_revision bigint) returns void
language plpgsql security definer set search_path='' as $$
declare v public.admin_guided_work_drafts;
begin
  if auth.uid() is null or not coalesce(public.is_admin(),false) then raise insufficient_privilege; end if;
  select * into v from public.admin_guided_work_drafts where id=p_id for update;
  if not found or v.owner_id<>auth.uid() then raise insufficient_privilege; end if;
  if v.discarded_at is not null and v.revision=p_revision+1 then return; end if;
  if v.revision is distinct from p_revision or v.finalized_program_id is not null then
    raise exception 'El trabajo ha cambiado. Actualiza antes de moverlo a la papelera.' using errcode='40001';
  end if;
  update public.admin_guided_work_drafts set discarded_at=clock_timestamp(),revision=revision+1 where id=p_id;
end $$;

create function public.restore_admin_guided_work(p_id uuid,p_revision bigint) returns void
language plpgsql security definer set search_path='' as $$
declare v public.admin_guided_work_drafts;
begin
  if auth.uid() is null or not coalesce(public.is_admin(),false) then raise insufficient_privilege; end if;
  select * into v from public.admin_guided_work_drafts where id=p_id for update;
  if not found or v.owner_id<>auth.uid() then raise insufficient_privilege; end if;
  if v.finalized_program_id is not null then raise exception 'Este trabajo ya se guardó en el catálogo.' using errcode='40001'; end if;
  if v.discarded_at is null and v.revision=p_revision+1 then return; end if;
  if v.discarded_at is null or v.revision is distinct from p_revision then
    raise exception 'La papelera ha cambiado. Actualiza antes de recuperar.' using errcode='40001';
  end if;
  update public.admin_guided_work_drafts set discarded_at=null,revision=revision+1,updated_at=clock_timestamp() where id=p_id;
end $$;

create function public.list_admin_guided_program_trash() returns jsonb
language plpgsql stable security definer set search_path='' as $$
begin
  if auth.uid() is null or not coalesce(public.is_admin(),false) then raise insufficient_privilege; end if;
  return coalesce((select jsonb_agg(to_jsonb(q) order by q.trashed_at desc,q.id) from (
    select distinct on(p.family_id) 'program'::text kind,p.family_id id,p.content->>'name' name,p.trashed_at,
      null::bigint revision,(select count(*) from public.guided_programs v where v.family_id=p.family_id) versions,
      (select count(*) from public.admin_guided_work_drafts w join public.guided_programs b on b.id=w.base_program_id
        where b.family_id=p.family_id and w.owner_id=auth.uid() and w.discarded_at is null and w.finalized_program_id is null) work_count
      from public.guided_programs p where p.trashed_at is not null order by p.family_id,p.version desc
    ) q),'[]'::jsonb) || coalesce((select jsonb_agg(jsonb_build_object(
      'kind','work','id',w.id,'name',coalesce(nullif(btrim(w.state->>'name'),''),'Programa sin nombre'),
      'trashed_at',w.discarded_at,'revision',w.revision,'versions',0,'work_count',1) order by w.discarded_at desc,w.id)
      from public.admin_guided_work_drafts w left join public.guided_programs p on p.id=w.base_program_id
      where w.owner_id=auth.uid() and w.discarded_at is not null and w.finalized_program_id is null
        and p.trashed_at is null),'[]'::jsonb);
end $$;

revoke all on function public.trash_admin_guided_program(uuid),public.restore_admin_guided_program(uuid,timestamptz),
  public.restore_admin_guided_work(uuid,bigint),public.list_admin_guided_program_trash() from public,anon,authenticated;
grant execute on function public.trash_admin_guided_program(uuid),public.restore_admin_guided_program(uuid,timestamptz),
  public.restore_admin_guided_work(uuid,bigint),public.list_admin_guided_program_trash() to authenticated;

-- Las entradas en papelera quedan en el historial y fuera de avisos editoriales.
create or replace function admin_ops_private.snapshot(p_kind text,p_id uuid) returns jsonb
language plpgsql security invoker set search_path='' as $$
declare result jsonb;
begin
  if p_kind='session' then
    select jsonb_build_object('name',t.name,'status',t.status,'version',t.version,
      'show_in_library',t.show_in_library,'program_id',l.program_id,'catalog_scope',l.catalog_scope,
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


-- La portada pertenece a la familia, también al revisar versiones posteriores.
create or replace function public.admin_catalog_quality() returns jsonb
language plpgsql stable security definer set search_path='' as $$
begin
  if auth.uid() is null or not coalesce(public.is_admin(),false) then raise insufficient_privilege; end if;
  return coalesce((select jsonb_agg(to_jsonb(q) || case when q.resource_type='session' then
    jsonb_build_object('program_id',(select program_id from public.program_workout_templates
      where template_id=q.resource_id and catalog_scope='program')) else '{}'::jsonb end
    order by case q.severity when 'error' then 0 when 'attention' then 1 else 2 end,q.name,q.code) from (
    select 'exercise'::text resource_type,e.id resource_id,e.name,'incomplete_exercise'::text code,'attention'::text severity,
      'Faltan descripción o grupos musculares.'::text message
      from public.exercises e where e.origin='system' and e.id<>'20000000-0000-4000-8000-000000000004'::uuid
      and (nullif(btrim(e.description),'') is null or cardinality(e.muscle_groups)=0)
    union all select 'exercise',e.id,e.name,'missing_media','attention','Sin vídeo ni imagen asignados.'
      from public.exercises e where e.origin='system' and e.id<>'20000000-0000-4000-8000-000000000004'::uuid
      and nullif(e.video_url,'') is null and nullif(e.image_path,'') is null
    union all select 'program',p.id,p.content->>'name','missing_cover','attention','Sin portada de tarjeta.'
      from public.guided_programs p left join public.guided_program_covers c on c.program_id=p.family_id
      where p.trashed_at is null and p.status<>'archived' and c.card_image_path is null
    union all select 'program',p.id,p.content->>'name','draft_program','pending','Programa pendiente de revisión/publicación.'
      from public.guided_programs p where p.trashed_at is null and p.status='draft'
    union all select 'session',t.id,t.name,'draft_session','pending','Sesión guardada en borrador.'
      from public.workout_templates t where t.origin='system' and t.owner_user_id is null and t.status='draft'
    union all select 'program',p.id,p.content->>'name','unavailable_session','error','El programa referencia una sesión retirada o no disponible.'
      from public.guided_programs p where p.trashed_at is null and p.status<>'archived' and exists(
        select 1 from jsonb_array_elements(p.content->'phases') phase,
          jsonb_array_elements(phase->'sessions') slot left join public.workout_templates t on t.id=(slot->>'template_id')::uuid
        where t.id is null or t.status not in ('draft','published'))
    union all select 'program',p.id,p.content->>'name','unavailable_warmup','error','El programa referencia un calentamiento retirado o no disponible.'
      from public.guided_programs p where p.trashed_at is null and p.status<>'archived' and exists(
        select 1 from jsonb_array_elements(p.content->'phases') phase,
          jsonb_array_elements(phase->'sessions') slot left join public.guided_warmups w on w.id=(slot->>'warmup_id')::uuid
        where slot->>'warmup_id' is not null and (w.id is null or w.status<>'published'))
    union all select 'video',a.id,'Vídeo '||left(a.id::text,8),'video_failed','error',
      'El último estado registrado del vídeo es '||a.status||'.'
      from public.exercise_video_assets a where a.status in ('failed','rejected')
  ) q),'[]'::jsonb);
end $$;

commit;
