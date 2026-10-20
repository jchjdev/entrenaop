-- UI-062: guardar recetas sin publicarlas y publicar el conjunto de forma atómica.
create or replace function public.save_guided_program(p_content jsonb,p_id uuid default null,
  p_category_ids uuid[] default null,p_primary_category_id uuid default null)
returns uuid language plpgsql security definer set search_path='' as $$
declare v_id uuid:=p_id; v_family uuid; v_version integer; v_status text;
  v_phase jsonb; v_session jsonb; v_pi integer:=0; v_si integer;
  v_template uuid; v_warmup uuid; v_min integer; v_max integer;
  v_categories uuid[]:=p_category_ids; v_primary uuid:=p_primary_category_id;
begin
  if auth.uid() is null or not coalesce(public.is_admin(),false) then
    raise exception 'Solo administración puede editar programas.' using errcode='42501';
  end if;
  if p_content is null or jsonb_typeof(p_content) <> 'object'
    or length(coalesce(btrim(p_content->>'name'),'')) not between 1 and 80
    or coalesce(p_content->>'mode','') not in ('guide','phased')
    or jsonb_typeof(p_content->'phases') is distinct from 'array'
    or jsonb_array_length(p_content->'phases') not between 1 and 24
    or (p_content->>'mode'='guide' and jsonb_array_length(p_content->'phases')<>1)
    or octet_length(p_content::text)>262144 then
    raise exception 'Revisa el contenido y la organización del programa.' using errcode='22023';
  end if;
  if p_id is null then v_id:=gen_random_uuid(); v_family:=v_id; v_version:=1;
  else
    select family_id into v_family from public.guided_programs where id=p_id;
    if not found then raise exception 'Programa no disponible.' using errcode='22023'; end if;
    perform pg_advisory_xact_lock(hashtextextended(v_family::text,0));
    select version,status into v_version,v_status from public.guided_programs where id=p_id for update;
    if v_status<>'draft' then
      v_id:=gen_random_uuid();
      select max(version)+1 into v_version from public.guided_programs where family_id=v_family;
    end if;
  end if;
  insert into public.guided_programs(id,family_id,version,content)
    values(v_id,v_family,v_version,p_content)
    on conflict(id) do update set content=excluded.content;
  delete from public.guided_program_links where program_id=v_id;
  for v_phase in select value from jsonb_array_elements(p_content->'phases') loop
    if length(coalesce(btrim(v_phase->>'name'),'')) not between 1 and 80
      or jsonb_typeof(v_phase->'sessions') is distinct from 'array'
      or jsonb_array_length(v_phase->'sessions') not between 1 and 64 then
      raise exception 'Cada fase necesita nombre y sesiones.' using errcode='22023';
    end if;
    if p_content->>'mode'='phased' and (
      coalesce((v_phase->>'duration_weeks')::integer,0) not between 1 and 104
      or btrim(coalesce(v_phase->>'instructions',''))='') then
      raise exception 'Indica duración y condiciones de avance.' using errcode='22023';
    end if;
    v_si:=0;
    for v_session in select value from jsonb_array_elements(v_phase->'sessions') loop
      v_template:=(v_session->>'template_id')::uuid;
      v_warmup:=nullif(v_session->>'warmup_id','')::uuid;
      -- No se reutiliza contenido privado de una oposición como sesión libre.
      perform 1 from public.workout_templates t join public.program_workout_templates l on l.template_id=t.id
        where t.id=v_template and t.origin='system' and t.owner_user_id is null and t.status in ('draft','published')
          and ((t.status='published' and t.visibility='public') or (t.status='draft' and t.visibility='private')) and l.catalog_scope='general' for share of t;
      if not found or btrim(coalesce(v_session->>'name',''))='' then
        raise exception 'Selecciona una sesión oficial general en borrador o publicada.' using errcode='22023';
      end if;
      if v_warmup is not null then
        perform 1 from public.guided_warmups where id=v_warmup and status='published' for share;
        if not found then raise exception 'Calentamiento no disponible.' using errcode='22023'; end if;
        if exists(select 1 from public.workout_blocks where template_id=v_template and format='warm_up') then
          raise exception 'Esta sesión ya contiene calentamiento; no adjuntes otro.' using errcode='22023';
        end if;
      end if;
      v_min:=(v_session->'rest'->>'min_seconds')::integer;
      v_max:=(v_session->'rest'->>'max_seconds')::integer;
      if (v_min is null)<>(v_max is null) or v_min<0 or v_max>3600 or v_min>v_max then
        raise exception 'Revisa los límites de descanso.' using errcode='22023';
      end if;
      if v_min is not null and not exists(select 1 from public.workout_blocks where template_id=v_template and format='straight_sets') then
        raise exception 'Solo los bloques convencionales admiten este ajuste de descanso.' using errcode='22023';
      end if;
      insert into public.guided_program_links values(v_id,v_pi,v_si,v_template,v_warmup);
      v_si:=v_si+1;
    end loop;
    v_pi:=v_pi+1;
  end loop;
  -- Las categorías son metadatos relacionados, fuera de la receta deportiva.
  -- Las llamadas antiguas conservan la clasificación al editar o crear revisión.
  if v_categories is null then
    select coalesce(array_agg(category_id),'{}'::uuid[]),
      (array_agg(category_id) filter(where is_primary))[1]
      into v_categories,v_primary from public.guided_program_category_links where program_id=p_id;
  end if;
  if cardinality(v_categories)>8 or array_position(v_categories,null) is not null
    or cardinality(v_categories)<>(select count(distinct x) from unnest(v_categories) x)
    or (cardinality(v_categories)>0 and (v_primary is null or not v_primary=any(v_categories)))
    or (cardinality(v_categories)=0 and v_primary is not null) then
    raise exception 'Selecciona hasta ocho categorías distintas y una principal.' using errcode='22023';
  end if;
  perform 1 from public.guided_program_categories where id=any(v_categories) order by id for share;
  if (select count(*) from public.guided_program_categories where id=any(v_categories))<>cardinality(v_categories)
    or exists(select 1 from public.guided_program_categories c where c.id=any(v_categories) and not c.is_active
      and not exists(select 1 from public.guided_program_category_links l where l.program_id=p_id and l.category_id=c.id)) then
    raise exception 'Una categoría ya no está disponible. Recarga la lista.' using errcode='22023';
  end if;
  delete from public.guided_program_category_links where program_id=v_id;
  insert into public.guided_program_category_links(program_id,category_id,is_primary)
    select v_id,x,x=v_primary from unnest(v_categories) x;
  return v_id;
end $$;

create or replace function public.set_guided_program_status(p_id uuid,p_status text)
returns void language plpgsql security definer set search_path='' as $$
declare v_program public.guided_programs; v_link record; v_template public.workout_templates;
begin
  if auth.uid() is null or not coalesce(public.is_admin(),false) then
    raise exception 'Solo administración puede publicar programas.' using errcode='42501';
  end if;
  if p_status not in ('published','archived') or p_status is null then
    raise exception 'Estado no permitido.' using errcode='22023';
  end if;
  -- El mismo orden de bloqueo que guardar: familia y después versión.
  select * into v_program from public.guided_programs where id=p_id;
  if not found then raise exception 'Programa no disponible.' using errcode='22023'; end if;
  perform pg_advisory_xact_lock(hashtextextended(v_program.family_id::text,0));
  select * into v_program from public.guided_programs where id=p_id for update;
  if p_status='published' and v_program.status<>'draft' then
    raise exception 'No existe un borrador publicable.' using errcode='22023';
  end if;
  if p_status='published' then
    if not exists(select 1 from public.guided_program_links where program_id=p_id) then
      raise exception 'El programa necesita sesiones.' using errcode='22023';
    end if;
    -- Una receta puede repetirse en fases o en varios programas. Se publica una
    -- sola vez y se bloquea por identidad para conservar su versión compartida.
    for v_template in select t.* from public.workout_templates t
      where t.id in (select template_id from public.guided_program_links where program_id=p_id)
      order by t.id for update
    loop
      if v_template.origin<>'system' or v_template.owner_user_id is not null
        or v_template.status not in ('draft','published') or not exists(
          select 1 from public.program_workout_templates
          where template_id=v_template.id and catalog_scope='general'
        ) then
        raise exception 'Una sesión ya no está disponible para este programa.' using errcode='22023';
      end if;
      if not exists(select 1 from public.workout_blocks where template_id=v_template.id)
        or exists(select 1 from public.workout_blocks b where b.template_id=v_template.id
          and (not exists(select 1 from public.workout_items i where i.block_id=b.id)
            or exists(select 1 from public.workout_items i where i.block_id=b.id
              and not exists(select 1 from public.workout_sets s where s.item_id=i.id)))) then
        raise exception 'Una sesión contiene bloques o ejercicios vacíos.' using errcode='22023';
      end if;
      if v_template.status='draft' then
        perform public.publish_admin_workout_draft(v_template.id);
      elsif v_template.visibility<>'public' then
        raise exception 'Una sesión publicada ya no está disponible.' using errcode='22023';
      end if;
    end loop;
    for v_link in select * from public.guided_program_links where program_id=p_id loop
      if v_link.warmup_id is not null then
        perform 1 from public.guided_warmups where id=v_link.warmup_id and status='published' for share;
        if not found then raise exception 'Un calentamiento ya no está disponible.' using errcode='22023'; end if;
      end if;
    end loop;
  end if;
  -- Toda excepción anterior revierte también las publicaciones de sesiones.
  update public.guided_programs set status=p_status where id=p_id;
end $$;

revoke all on function public.save_guided_program(jsonb,uuid,uuid[],uuid),
  public.set_guided_program_status(uuid,text) from public,anon;
grant execute on function public.save_guided_program(jsonb,uuid,uuid[],uuid),
  public.set_guided_program_status(uuid,text) to authenticated;



create or replace function public.revise_admin_workout(
  p_template_id uuid,
  p_payload jsonb
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  source record;
  old_link public.program_workout_templates%rowtype;
  old_status text;
  old_version integer;
  old_family uuid;
  old_previous uuid;
  new_template_id uuid;
begin
  if (select auth.uid()) is null or not (select public.is_admin()) then
    raise exception 'No tienes permiso para revisar sesiones oficiales.'
      using errcode = '42501';
  end if;

  select link.program_id, link.catalog_scope, template.status,
         template.version, template.family_id, template.previous_version_id
  into source
  from public.program_workout_templates as link
  join public.workout_templates as template on template.id = link.template_id
  where template.id = p_template_id
    and template.origin = 'system'
    and template.owner_user_id is null
    and template.status in ('draft', 'published')
  for update of template;
  if not found then
    raise exception 'La sesión no admite una revisión.' using errcode = '22023';
  end if;
  old_link.program_id := source.program_id;
  old_link.catalog_scope := source.catalog_scope;
  old_status := source.status;
  old_version := source.version;
  old_family := source.family_id;
  old_previous := source.previous_version_id;

  if old_status = 'draft' and (
    exists (select 1 from public.scheduled_workouts where template_id = p_template_id)
    or exists (select 1 from public.workout_executions where template_id = p_template_id)
  ) then
    raise exception 'Un borrador ya usado no se puede reemplazar.'
      using errcode = '22023';
  end if;
  if old_status = 'published' and exists (
    select 1 from public.workout_templates
    where family_id = old_family and status = 'draft'
  ) then
    raise exception 'Ya hay una nueva versión en borrador de esta sesión.'
      using errcode = '22023';
  end if;

  new_template_id := public.create_admin_workout_draft(
    case when old_link.catalog_scope = 'program' then old_link.program_id else null end,
    p_payload
  );
  -- La revisión deportiva conserva la elección editorial de la sesión fuente.
  update public.workout_templates set show_in_library=(select show_in_library from public.workout_templates where id=p_template_id) where id=new_template_id;
  update public.program_workout_templates
  set program_id = old_link.program_id,
      catalog_scope = old_link.catalog_scope
  where template_id = new_template_id;

  -- Los programas en montaje ya pueden enlazar este borrador. Conservamos su
  -- identidad y la marca editorial; la receta nueva se valida con el creador
  -- existente antes de sustituir bloques, todo dentro de esta transacción.
  if old_status = 'draft' then
    delete from public.workout_blocks where template_id=p_template_id;
    update public.workout_blocks set template_id=p_template_id where template_id=new_template_id;
    update public.workout_templates t set
      name=n.name, description=n.description,
      estimated_duration_minutes=n.estimated_duration_minutes, updated_at=now()
    from public.workout_templates n where t.id=p_template_id and n.id=new_template_id;
    delete from public.workout_templates where id=new_template_id;
    return p_template_id;
  else
    update public.workout_templates
    set family_id = old_family,
        previous_version_id = p_template_id,
        version = old_version + 1
    where id = new_template_id;
  end if;
  return new_template_id;
end;
$$;
