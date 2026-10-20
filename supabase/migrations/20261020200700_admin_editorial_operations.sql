-- Historial editorial y diagnóstico: datos oficiales, sin acceso directo desde Flutter.
create schema admin_ops_private;
revoke all on schema admin_ops_private from public, anon, authenticated;

create table admin_ops_private.editorial_events (
  id bigint generated always as identity primary key,
  transaction_id bigint not null,
  resource_type text not null check(resource_type in ('session','program','warmup','exercise')),
  resource_id uuid not null,
  actor_id uuid,
  occurred_at timestamptz not null default clock_timestamp(),
  before_data jsonb,
  after_data jsonb,
  finalized boolean not null default false,
  unique(transaction_id,resource_type,resource_id)
);
create index editorial_events_resource on admin_ops_private.editorial_events(resource_type,resource_id,id desc);
alter table admin_ops_private.editorial_events enable row level security;
revoke all on admin_ops_private.editorial_events from public,anon,authenticated;

create table admin_ops_private.restorations (
  request_id uuid primary key,
  actor_id uuid not null,
  event_id bigint not null references admin_ops_private.editorial_events(id),
  use_before boolean not null,
  resource_id uuid not null
);
alter table admin_ops_private.restorations enable row level security;
revoke all on admin_ops_private.restorations from public,anon,authenticated;

create function admin_ops_private.snapshot(p_kind text,p_id uuid) returns jsonb
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
    select jsonb_build_object('name',p.content->>'name','status',p.status,'version',p.version,
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

-- Captura una sola instantánea anterior por recurso/transacción. La actualización
-- diferida ve la receta completa al final, no cada inserción intermedia de series.
create function admin_ops_private.capture() returns trigger
language plpgsql security definer set search_path='' as $$
declare ids uuid[]; v_id uuid; kind text; old_row jsonb; new_row jsonb;
begin
  if TG_OP<>'INSERT' then old_row:=to_jsonb(old); end if;
  if TG_OP<>'DELETE' then new_row:=to_jsonb(new); end if;
  if TG_TABLE_NAME='workout_templates' then
    kind:='session'; ids:=array[(old_row->>'id')::uuid,(new_row->>'id')::uuid];
    if coalesce(new_row->>'origin',old_row->>'origin')<>'system' or
       coalesce(new_row->>'owner_user_id',old_row->>'owner_user_id') is not null then
      return case when TG_OP='DELETE' then old else new end;
    end if;
  elsif TG_TABLE_NAME='workout_blocks' then
    kind:='session'; ids:=array[(old_row->>'template_id')::uuid,(new_row->>'template_id')::uuid];
  elsif TG_TABLE_NAME='workout_items' then
    kind:='session'; select array_agg(distinct template_id) into ids from public.workout_blocks
      where id in ((old_row->>'block_id')::uuid,(new_row->>'block_id')::uuid);
  elsif TG_TABLE_NAME='workout_sets' then
    kind:='session'; select array_agg(distinct b.template_id) into ids
      from public.workout_items i join public.workout_blocks b on b.id=i.block_id
      where i.id in ((old_row->>'item_id')::uuid,(new_row->>'item_id')::uuid);
  elsif TG_TABLE_NAME='guided_program_category_links' then
    kind:='program'; ids:=array[(old_row->>'program_id')::uuid,(new_row->>'program_id')::uuid];
  else
    kind:=case TG_TABLE_NAME when 'guided_programs' then 'program'
      when 'guided_warmups' then 'warmup' when 'exercises' then 'exercise' end;
    ids:=array[(old_row->>'id')::uuid,(new_row->>'id')::uuid];
    if kind='exercise' and coalesce(new_row->>'origin',old_row->>'origin')<>'system' then
      return case when TG_OP='DELETE' then old else new end;
    end if;
  end if;
  for v_id in select distinct v from unnest(ids) v where v is not null loop
    if TG_WHEN='BEFORE' then
      -- Las tablas hijas también contienen sesiones personales: nunca se auditan.
      if kind='session' and TG_TABLE_NAME<>'workout_templates' and not exists(
        select 1 from public.workout_templates where id=v_id and origin='system' and owner_user_id is null
      ) then continue; end if;
      if not exists(select 1 from admin_ops_private.editorial_events
        where transaction_id=txid_current() and resource_type=kind and resource_id=v_id) then
        insert into admin_ops_private.editorial_events(transaction_id,resource_type,resource_id,actor_id,before_data)
        values(txid_current(),kind,v_id,auth.uid(),admin_ops_private.snapshot(kind,v_id));
      else
        update admin_ops_private.editorial_events set finalized=false
        where transaction_id=txid_current() and resource_type=kind and resource_id=v_id and finalized;
      end if;
    else
      update admin_ops_private.editorial_events set
        after_data=admin_ops_private.snapshot(kind,v_id),finalized=true
      where transaction_id=txid_current() and resource_type=kind and resource_id=v_id and not finalized;
    end if;
  end loop;
  return case when TG_OP='DELETE' then old else new end;
end $$;
revoke all on function admin_ops_private.capture() from public,anon,authenticated;

do $$ declare tab text; begin
  foreach tab in array array['workout_templates','workout_blocks','workout_items','workout_sets',
    'guided_programs','guided_program_category_links','guided_warmups','exercises'] loop
    execute format('create trigger editorial_before before insert or update or delete on public.%I for each row execute function admin_ops_private.capture()',tab);
    execute format('create constraint trigger editorial_after after insert or update or delete on public.%I deferrable initially deferred for each row execute function admin_ops_private.capture()',tab);
  end loop;
end $$;

create function public.admin_editorial_history(p_kind text default null,p_before_id bigint default null)
returns jsonb language plpgsql stable security definer set search_path='' as $$
begin
  if auth.uid() is null or not coalesce(public.is_admin(),false) then raise insufficient_privilege; end if;
  return coalesce((select jsonb_agg(jsonb_build_object('id',e.id,'resource_type',e.resource_type,
    'resource_id',e.resource_id,'occurred_at',e.occurred_at,
    'name',coalesce(e.after_data->>'name',e.before_data->>'name','Recurso retirado'),
    'action',case when e.before_data is null then 'created' when e.after_data is null then 'removed' else 'updated' end)
    order by e.id desc) from (select * from admin_ops_private.editorial_events
      where (p_kind is null or resource_type=p_kind) and (p_before_id is null or id<p_before_id)
      and before_data is distinct from after_data order by id desc limit 50) e),'[]'::jsonb);
end $$;

create function public.admin_editorial_event(p_event_id bigint) returns jsonb
language plpgsql stable security definer set search_path='' as $$
begin
  if auth.uid() is null or not coalesce(public.is_admin(),false) then raise insufficient_privilege; end if;
  return (select jsonb_build_object('resource_type',resource_type,'resource_id',resource_id,
    'before',before_data,'after',after_data,'occurred_at',occurred_at)
    from admin_ops_private.editorial_events where id=p_event_id and before_data is distinct from after_data);
end $$;

create function public.restore_admin_editorial_event(p_event_id bigint,p_request_id uuid,p_use_before boolean default false)
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
    return saved.resource_id;
  end if;
  select * into event from admin_ops_private.editorial_events where id=p_event_id;
  if not found then raise no_data_found; end if;
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

create function public.admin_account_support(p_user_id uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
begin
  if auth.uid() is null or not coalesce(public.is_admin(),false) or
     not coalesce(public.can_manage_pro_accounts(),false) then raise insufficient_privilege; end if;
  if not exists(select 1 from auth.users where id=p_user_id) then raise no_data_found; end if;
  return jsonb_build_object('checked_at',now(),
    'last_sign_in_at',(select last_sign_in_at from auth.users where id=p_user_id),
    'programs',coalesce((select jsonb_agg(jsonb_build_object('id',f.program_id,'name',p.content->>'name',
      'version',p.version,'phase_index',f.phase_index,'started_at',f.started_at,
      'state',case when f.completed_at is not null then 'completed' when f.abandoned_at is not null then 'abandoned'
        when f.paused_at is not null then 'paused' else 'active' end) order by f.started_at desc)
      from (select * from public.guided_program_follows where user_id=p_user_id order by started_at desc limit 50) f
      join public.guided_programs p on p.id=f.program_id),'[]'::jsonb));
end $$;

create function public.admin_operations_status() returns jsonb
language plpgsql stable security definer set search_path='' as $$
begin
  if auth.uid() is null or not coalesce(public.is_admin(),false) then raise insufficient_privilege; end if;
  return jsonb_build_object('checked_at',now(),'database','reachable',
    'history_events',(select count(*) from admin_ops_private.editorial_events where before_data is distinct from after_data),
    'failed_videos',(select count(*) from public.exercise_video_assets where status='failed'),
    'backups','unverified','service_logs','not_connected');
end $$;

create function public.admin_catalog_quality() returns jsonb
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
      from public.guided_programs p left join public.guided_program_covers c on c.program_id=p.id
      where p.status<>'archived' and c.card_image_path is null
    union all select 'program',p.id,p.content->>'name','draft_program','pending','Programa pendiente de revisión/publicación.'
      from public.guided_programs p where p.status='draft'
    union all select 'session',t.id,t.name,'draft_session','pending','Sesión guardada en borrador.'
      from public.workout_templates t where t.origin='system' and t.owner_user_id is null and t.status='draft'
    union all select 'program',p.id,p.content->>'name','unavailable_session','error','El programa referencia una sesión retirada o no disponible.'
      from public.guided_programs p where p.status<>'archived' and exists(
        select 1 from jsonb_array_elements(p.content->'phases') phase,
          jsonb_array_elements(phase->'sessions') slot left join public.workout_templates t on t.id=(slot->>'template_id')::uuid
        where t.id is null or t.status not in ('draft','published'))
    union all select 'program',p.id,p.content->>'name','unavailable_warmup','error','El programa referencia un calentamiento retirado o no disponible.'
      from public.guided_programs p where p.status<>'archived' and exists(
        select 1 from jsonb_array_elements(p.content->'phases') phase,
          jsonb_array_elements(phase->'sessions') slot left join public.guided_warmups w on w.id=(slot->>'warmup_id')::uuid
        where slot->>'warmup_id' is not null and (w.id is null or w.status<>'published'))
    union all select 'video',a.id,'Vídeo '||left(a.id::text,8),'video_failed','error',
      'El último estado registrado del vídeo es '||a.status||'.'
      from public.exercise_video_assets a where a.status in ('failed','rejected')
  ) q),'[]'::jsonb);
end $$;

revoke all on function public.admin_editorial_history(text,bigint), public.admin_editorial_event(bigint),
  public.restore_admin_editorial_event(bigint,uuid,boolean), public.admin_account_support(uuid),
  public.admin_operations_status(), public.admin_catalog_quality() from public,anon;
grant execute on function public.admin_editorial_history(text,bigint), public.admin_editorial_event(bigint),
  public.restore_admin_editorial_event(bigint,uuid,boolean), public.admin_account_support(uuid),
  public.admin_operations_status(), public.admin_catalog_quality() to authenticated;
