begin;
-- El mismo criterio de búsqueda que Biblioteca: normaliza ambos lados sin cambiar los nombres.
create function public.library_search_text(p_value text)
returns text language sql immutable parallel safe set search_path='' as $$
  select btrim(regexp_replace(replace(regexp_replace(
    translate(lower(normalize(coalesce(p_value,''),NFC)),
      'áàäâéèëêíìïîóòöôúùüûñ','aaaaeeeeiiiioooouuuun'),
    U&'[\0300-\036f]','','g'),'_',' '),'[[:space:]]+',' ','g'));
$$;
revoke all on function public.library_search_text(text) from public,anon,authenticated;
grant execute on function public.library_search_text(text) to authenticated;

create table public.guided_program_categories (
  id uuid primary key default gen_random_uuid(),
  name text not null check(length(btrim(name)) between 1 and 48),
  search_name text generated always as (public.library_search_text(name)) stored unique,
  is_active boolean not null default true,
  revision integer not null default 1 check(revision>0),
  check(search_name<>'')
);
create table public.guided_program_category_links (
  program_id uuid not null references public.guided_programs(id) on delete cascade,
  category_id uuid not null references public.guided_program_categories(id),
  is_primary boolean not null default false,
  primary key(program_id,category_id)
);
create unique index guided_program_category_primary_unique
  on public.guided_program_category_links(program_id) where is_primary;
create index guided_program_category_links_category_idx
  on public.guided_program_category_links(category_id,program_id);
alter table public.guided_program_categories enable row level security;
alter table public.guided_program_category_links enable row level security;
revoke all on public.guided_program_categories,public.guided_program_category_links from public,anon,authenticated;
grant select on public.guided_program_categories,public.guided_program_category_links to authenticated;
create policy guided_categories_read on public.guided_program_categories for select to authenticated using(true);
create policy guided_category_links_read on public.guided_program_category_links for select to authenticated
  using(exists(select 1 from public.guided_programs p where p.id=program_id));

create function public.save_guided_program_category(p_name text,p_id uuid default null,
  p_active boolean default true,p_expected_revision integer default null)
returns uuid language plpgsql security definer set search_path='' as $$
declare result uuid;
begin
  if auth.uid() is null or not coalesce(public.is_admin(),false) then
    raise exception 'Solo administración puede gestionar categorías.' using errcode='42501';
  end if;
  if p_active is null or length(btrim(coalesce(p_name,''))) not between 1 and 48
    or public.library_search_text(p_name)='' then
    raise exception 'Escribe una categoría de hasta 48 caracteres.' using errcode='22023';
  end if;
  if p_id is null then
    insert into public.guided_program_categories(name,is_active) values(btrim(p_name),p_active) returning id into result;
  else
    update public.guided_program_categories set name=btrim(p_name),is_active=p_active,revision=revision+1
      where id=p_id and revision=p_expected_revision returning id into result;
    if not found then raise exception 'La categoría ha cambiado. Recarga antes de guardar.' using errcode='40001'; end if;
  end if;
  return result;
end $$;
revoke all on function public.save_guided_program_category(text,uuid,boolean,integer) from public,anon,authenticated;
grant execute on function public.save_guided_program_category(text,uuid,boolean,integer) to authenticated;
insert into public.guided_program_categories(name) values
 ('Hipertrofia'),('Fuerza'),('Movilidad'),('Estiramientos'),('Resistencia'),('Potencia'),('Iniciación');

-- Conserva el nombre y los dos argumentos existentes; amplía solo parámetros opcionales.
drop function public.save_guided_program(jsonb,uuid);
create function public.save_guided_program(p_content jsonb,p_id uuid default null,
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


revoke all on function public.save_guided_program(jsonb,uuid,uuid[],uuid) from public,anon,authenticated;
grant execute on function public.save_guided_program(jsonb,uuid,uuid[],uuid) to authenticated;

drop function public.get_guided_program_catalog(text,text,integer,integer,boolean);
create function public.get_guided_program_catalog(p_query text default '',p_mode text default null,
  p_offset integer default 0,p_limit integer default 3,p_followed boolean default false,p_category_id uuid default null)
returns setof public.guided_programs language sql stable security invoker set search_path='' as $$
  select p.* from public.guided_programs p
  cross join lateral (select public.library_search_text(concat_ws(' ',p.content->>'name',p.content->>'description',
    (select string_agg(c.name,' ') from public.guided_program_category_links l
      join public.guided_program_categories c on c.id=l.category_id where l.program_id=p.id))) as text) haystack
  where p.status<>'draft' and (
    (p_followed and exists(select 1 from public.guided_program_follows f where f.program_id=p.id and f.user_id=auth.uid()
      and f.completed_at is null and f.abandoned_at is null))
    or (not p_followed and p.status='published' and not exists(
      select 1 from public.guided_programs newer where newer.family_id=p.family_id and newer.status='published' and newer.version>p.version
    ))
  ) and (p_mode is null or p.content->>'mode'=p_mode)
    and (p_category_id is null or exists(select 1 from public.guided_program_category_links l
      where l.program_id=p.id and l.category_id=p_category_id))
    and not exists(select 1 from regexp_split_to_table(public.library_search_text(left(coalesce(p_query,''),100)),' ') word
      where word<>'' and strpos(haystack.text,word)=0)
  order by p.created_at desc,p.id
  offset greatest(0,p_offset) limit greatest(1,least(25,p_limit));
$$;
revoke all on function public.get_guided_program_catalog(text,text,integer,integer,boolean,uuid) from public,anon,authenticated;
grant execute on function public.get_guided_program_catalog(text,text,integer,integer,boolean,uuid) to authenticated;
commit;
