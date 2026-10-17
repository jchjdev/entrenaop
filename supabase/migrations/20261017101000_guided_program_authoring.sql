-- Catálogo editorial independiente de pruebas/baremos. El documento conserva
-- orden y contenido; los enlaces relacionales acreditan sus referencias.
begin;

create table public.guided_warmups (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null,
  version integer not null check (version > 0),
  name text not null check (length(btrim(name)) between 1 and 80),
  template_id uuid not null unique references public.workout_templates(id),
  status text not null default 'published' check (status in ('published','archived')),
  unique(family_id,version)
);
create table public.guided_programs (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null,
  version integer not null check (version > 0),
  status text not null default 'draft' check (status in ('draft','published','archived')),
  content jsonb not null check (jsonb_typeof(content) = 'object'),
  created_at timestamptz not null default now(),
  unique(family_id,version)
);
create table public.guided_program_links (
  program_id uuid not null references public.guided_programs(id) on delete cascade,
  phase_index integer not null check (phase_index >= 0),
  session_index integer not null check (session_index >= 0),
  template_id uuid not null references public.workout_templates(id),
  warmup_id uuid references public.guided_warmups(id),
  primary key(program_id,phase_index,session_index)
);
create index guided_program_links_template_idx on public.guided_program_links(template_id);
create index guided_program_links_warmup_idx on public.guided_program_links(warmup_id);
create index guided_programs_catalog_idx on public.guided_programs(status,created_at desc);

alter table public.guided_warmups enable row level security;
alter table public.guided_programs enable row level security;
alter table public.guided_program_links enable row level security;
revoke all on public.guided_warmups,public.guided_programs,public.guided_program_links from public,anon,authenticated;
grant select on public.guided_warmups,public.guided_programs,public.guided_program_links to authenticated;
create policy guided_warmups_read on public.guided_warmups for select to authenticated
using (public.is_admin() or status='published');
create policy guided_programs_read on public.guided_programs for select to authenticated
using (public.is_admin() or status='published');
create policy guided_program_links_read on public.guided_program_links for select to authenticated
using (exists(select 1 from public.guided_programs p where p.id=program_id));

create function public.save_guided_warmup(p_payload jsonb,p_previous_id uuid default null)
returns uuid language plpgsql security definer set search_path='' as $$
declare v_template uuid; v_id uuid := gen_random_uuid(); v_family uuid; v_version integer;
begin
  if auth.uid() is null or not coalesce(public.is_admin(),false) then
    raise exception 'Solo administración puede crear calentamientos.' using errcode='42501';
  end if;
  if p_previous_id is null then v_family:=v_id; v_version:=1;
  else
    select family_id into v_family from public.guided_warmups where id=p_previous_id;
    if not found then raise exception 'Calentamiento no disponible.' using errcode='22023'; end if;
    perform pg_advisory_xact_lock(hashtextextended(v_family::text,0));
    select max(version)+1 into v_version from public.guided_warmups where family_id=v_family;
  end if;
  if jsonb_typeof(p_payload->'blocks') is distinct from 'array' or exists(
    select 1 from jsonb_array_elements(p_payload->'blocks') b
    where coalesce(b->>'format','straight_sets') <> 'straight_sets'
  ) then raise exception 'El calentamiento usa bloques convencionales.' using errcode='22023'; end if;
  perform set_config('entrenaop.creating_official_template','true',true);
  v_template:=public.create_personal_workout_template(p_payload);
  perform set_config('entrenaop.creating_official_template','false',true);
  if exists(select 1 from public.workout_blocks b join public.workout_items i on i.block_id=b.id
    join public.exercises e on e.id=i.exercise_id where b.template_id=v_template and not e.is_public) then
    raise exception 'Utiliza ejercicios públicos en el calentamiento.' using errcode='22023';
  end if;
  update public.workout_blocks set format='warm_up' where template_id=v_template;
  update public.workout_templates set origin='system',owner_user_id=null,status='published',visibility='private'
    where id=v_template;
  insert into public.guided_warmups(id,family_id,version,name,template_id)
    values(v_id,v_family,v_version,btrim(p_payload->>'name'),v_template);
  return v_id;
end $$;

create function public.save_guided_program(p_content jsonb,p_id uuid default null)
returns uuid language plpgsql security definer set search_path='' as $$
declare v_id uuid:=p_id; v_family uuid; v_version integer; v_status text;
  v_phase jsonb; v_session jsonb; v_pi integer:=0; v_si integer;
  v_template uuid; v_warmup uuid; v_min integer; v_max integer;
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
        where t.id=v_template and t.origin='system' and t.status='published'
          and t.visibility='public' and l.catalog_scope='general' for share of t;
      if not found or btrim(coalesce(v_session->>'name',''))='' then
        raise exception 'Selecciona una sesión oficial general publicada.' using errcode='22023';
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
  return v_id;
end $$;

create function public.set_guided_program_status(p_id uuid,p_status text)
returns void language plpgsql security definer set search_path='' as $$
declare v_program public.guided_programs; v_link record;
begin
  if auth.uid() is null or not coalesce(public.is_admin(),false) then
    raise exception 'Solo administración puede publicar programas.' using errcode='42501';
  end if;
  if p_status not in ('published','archived') or p_status is null then
    raise exception 'Estado no permitido.' using errcode='22023';
  end if;
  select * into v_program from public.guided_programs where id=p_id for update;
  if not found or (p_status='published' and v_program.status<>'draft') then
    raise exception 'No existe un borrador publicable.' using errcode='22023';
  end if;
  if p_status='published' then
    for v_link in select * from public.guided_program_links where program_id=p_id loop
      perform 1 from public.workout_templates where id=v_link.template_id and status='published' for share;
      if not found then raise exception 'Una sesión ya no está publicada.' using errcode='22023'; end if;
      if v_link.warmup_id is not null then
        perform 1 from public.guided_warmups where id=v_link.warmup_id and status='published' for share;
        if not found then raise exception 'Un calentamiento ya no está disponible.' using errcode='22023'; end if;
      end if;
    end loop;
  end if;
  update public.guided_programs set status=p_status where id=p_id;
end $$;

revoke all on function public.save_guided_warmup(jsonb,uuid), public.save_guided_program(jsonb,uuid),
  public.set_guided_program_status(uuid,text) from public,anon,authenticated;
grant execute on function public.save_guided_warmup(jsonb,uuid), public.save_guided_program(jsonb,uuid),
  public.set_guided_program_status(uuid,text) to authenticated;

-- Una retirada desde el catálogo de sesiones no puede romper un programa que
-- aún se ofrece a los deportistas. Primero debe retirarse o revisarse éste.
create function public.protect_guided_template_retirement()
returns trigger language plpgsql security definer set search_path='' as $$
begin
  if old.status='published' and new.status<>'published' and exists(
    select 1 from public.guided_program_links l join public.guided_programs p on p.id=l.program_id
    where l.template_id=old.id and p.status='published'
  ) then
    raise exception 'Esta sesión pertenece a un programa publicado. Revisa o retira primero ese programa.' using errcode='22023';
  end if;
  return new;
end $$;
revoke all on function public.protect_guided_template_retirement() from public,anon,authenticated;
create trigger protect_guided_template_retirement before update of status on public.workout_templates
for each row execute function public.protect_guided_template_retirement();
commit;
