begin;

create table directory_private.specialties (
  id text primary key default gen_random_uuid()::text,
  name text not null check (length(btrim(name)) between 2 and 60),
  normalized_name text generated always as (directory_private.normalized_location(name)) stored unique,
  aliases text[] not null default '{}'
);

insert into directory_private.specialties(id,name,aliases) values
 ('strength','Fuerza','{}'),
 ('hypertrophy','Hipertrofia',array['ganar musculo']),
 ('calisthenics','Calistenia','{}'),
 ('running','Carrera',array['running','correr']),
 ('trail','Carrera de montaña (trail)',array['carrera de montana','trail','trail running']),
 ('swimming','Natación','{}'),
 ('cycling','Ciclismo','{}'),
 ('triathlon','Triatlón','{}'),
 ('mobility','Movilidad','{}'),
 ('hybrid','Entrenamiento híbrido','{}'),
 ('general_fitness','Preparación física general','{}'),
 ('opposition','Pruebas físicas de oposición',array['oposiciones','pruebas fisicas de oposicion']),
 ('hyrox','HYROX','{}'),
 ('yoga','Yoga','{}'),
 ('pilates','Pilates','{}');

create table directory_private.specialty_suggestions (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles(id) on delete cascade,
  name text not null check (length(btrim(name)) between 2 and 60),
  details text not null default '' check (length(details)<=500),
  normalized_name text generated always as (directory_private.normalized_location(name)) stored,
  state text not null default 'pending' check (state in ('pending','approved','declined')),
  specialty_id text references directory_private.specialties(id),
  note text not null default '' check (length(note)<=500),
  created_at timestamptz not null default now(),
  reviewed_at timestamptz,
  reviewed_by uuid references public.profiles(id) on delete set null,
  check ((state='approved')=(specialty_id is not null)),
  check ((state='pending')=(reviewed_at is null))
);
create unique index directory_specialty_suggestions_pending_name
  on directory_private.specialty_suggestions(owner_id,normalized_name) where state='pending';
create index directory_specialty_suggestions_owner
  on directory_private.specialty_suggestions(owner_id,created_at desc,id desc);
create index directory_specialty_suggestions_queue
  on directory_private.specialty_suggestions(created_at,id) where state='pending';
create index directory_specialty_suggestions_specialty
  on directory_private.specialty_suggestions(specialty_id);
create index directory_specialty_suggestions_reviewer
  on directory_private.specialty_suggestions(reviewed_by);
alter table directory_private.specialties enable row level security;
alter table directory_private.specialty_suggestions enable row level security;
revoke all on table directory_private.specialties,directory_private.specialty_suggestions from public,anon,authenticated,service_role;

create function directory_private.specialty_matches(s directory_private.specialties, label text)
returns boolean language sql immutable set search_path='' as $$
  select directory_private.normalized_location(btrim(label))=s.normalized_name
    or directory_private.normalized_location(btrim(label))=any(s.aliases)
$$;

alter table directory_private.profiles
  add column specialty_ids text[] not null default '{}',
  add column legacy_specialties text[] not null default '{}',
  add constraint directory_specialty_count check (cardinality(specialty_ids)<=8);

-- Los textos sin equivalencia se conservan. Solo una coincidencia inequívoca entra
-- en el filtro sin que el dueño tenga que editar una ficha ya publicada.
update directory_private.profiles p set
  specialty_ids=array(select s.id from directory_private.specialties s
    where exists(select 1 from unnest(p.specialties) label
      where directory_private.specialty_matches(s,label)) order by s.id),
  legacy_specialties=array(select label from unnest(p.specialties) label
    where not exists(select 1 from directory_private.specialties s
      where directory_private.specialty_matches(s,label))),
  specialties=array(
    select coalesce(s.name,entry.label)
    from unnest(p.specialties) with ordinality entry(label,position)
    left join lateral (
      select name from directory_private.specialties s
      where directory_private.specialty_matches(s,entry.label) order by id limit 1
    ) s on true
    group by coalesce(s.name,entry.label) order by min(entry.position)
  );
create index directory_profiles_specialty_ids on directory_private.profiles using gin(specialty_ids);

create function directory_private.selected_specialty_ids(p_data jsonb, p directory_private.profiles)
returns text[] language plpgsql stable set search_path='' as $$
declare ids text[];
begin
  if p_data ? 'specialty_ids' then
    if jsonb_typeof(p_data->'specialty_ids') is distinct from 'array'
      or jsonb_array_length(p_data->'specialty_ids') not between 1 and 8 then raise invalid_parameter_value; end if;
    ids:=array(select value from jsonb_array_elements_text(p_data->'specialty_ids'));
    if cardinality(ids)<>(select count(*) from directory_private.specialties where id=any(ids)) then
      raise invalid_parameter_value;
    end if;
    return ids;
  end if;
  -- Clientes anteriores pueden guardar otros campos de una ficha existente.
  if p.id is not null then return p.specialty_ids; end if;
  ids:=array(select s.id from directory_private.specialties s
    where exists(select 1 from jsonb_array_elements_text(p_data->'specialties') label
      where directory_private.specialty_matches(s,label)) order by s.id);
  if cardinality(ids) not between 1 and 8 then raise invalid_parameter_value; end if;
  return ids;
end $$;

-- Extiende el guardado vigente dentro de su bloqueo de propietario. Mantiene
-- consentimiento, moderación, publicación, foto y clientes anteriores.
do $migration$
declare source text;
begin
  source:=pg_get_functiondef('directory_private.save(uuid,integer,jsonb,boolean,boolean)'::regprocedure);
  if strpos(source,'tags:=array(select jsonb_array_elements_text(p_data->''specialties''));')=0
    or strpos(source,'name,description,specialties,services,')=0
    or strpos(source,'btrim(p_data->>''description''),tags,svc,')=0
    or strpos(source,'specialties=excluded.specialties,services=excluded.services')=0 then
    raise exception 'Revisar el contrato de guardado del directorio';
  end if;
  source:=replace(source,'tags text[];','tags text[]; ids text[];');
  source:=replace(source,'tags:=array(select jsonb_array_elements_text(p_data->''specialties''));',$patch$
    ids:=directory_private.selected_specialty_ids(p_data,p);
    tags:=case when p.id is not null and not (p_data ? 'specialty_ids') then p.specialties
      else array(select s.name from unnest(ids) with ordinality choice(id,position)
        join directory_private.specialties s on s.id=choice.id order by choice.position) end;$patch$);
  source:=replace(source,'name,description,specialties,services,','name,description,specialties,specialty_ids,services,');
  source:=replace(source,'btrim(p_data->>''description''),tags,svc,','btrim(p_data->>''description''),tags,ids,svc,');
  source:=replace(source,'specialties=excluded.specialties,services=excluded.services',
    'specialties=excluded.specialties,specialty_ids=excluded.specialty_ids,services=excluded.services');
  execute source;
  source:=pg_get_functiondef('directory_private.profile_json(directory_private.profiles)'::regprocedure);
  if strpos(source,'''specialties'',p.specialties')=0 then raise exception 'Revisar el JSON del directorio'; end if;
  execute replace(source,'''specialties'',p.specialties',$patch$'specialties',p.specialties,
    'specialty_ids',p.specialty_ids,'legacy_specialties',case when p.trainer_id=auth.uid() then p.legacy_specialties else '{}'::text[] end$patch$);
end $migration$;

create function directory_private.search_with_specialties(p_query text,p_mode text,p_city text,p_favorites boolean,
  p_after uuid,p_web_only boolean,p_specialty_ids text[]) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare items jsonb; more boolean; last_id uuid;
begin
  if p_query is null or length(p_query)>120 or p_city is null or length(p_city)>80
    or (p_mode is not null and p_mode not in ('online','presencial','ambas')) then raise invalid_parameter_value; end if;
  if p_favorites and not directory_private.member() then raise insufficient_privilege; end if;
  with candidates as (
    select p.* from directory_private.profiles p where directory_private.can_read(p.id,p_web_only)
      and (p_after is null or p.id>p_after)
      and (p_mode is null or p.mode=p_mode or p.mode='ambas')
      and (coalesce(cardinality(p_specialty_ids),0)=0 or p.specialty_ids && p_specialty_ids)
      and directory_private.matches_words(directory_private.location_text(p),p_city)
      and directory_private.matches_words(concat_ws(' ',p.name,p.description,
        array_to_string(p.specialties,' '),array_to_string(p.services,' '),directory_private.location_text(p)),p_query)
      and (not p_favorites or exists(select 1 from directory_private.favorites f where f.owner_id=auth.uid() and f.profile_id=p.id))
    order by p.id limit 21), page as (select * from candidates order by id limit 20)
  select coalesce((select jsonb_agg(directory_private.profile_json(p) order by p.id) from page
    join directory_private.profiles p on p.id=page.id),'[]'::jsonb),
    (select count(*)>20 from candidates),(select id from page order by id desc limit 1) into items,more,last_id;
  return jsonb_build_object('items',items,'next',case when more then last_id else null end);
end $$;

create or replace function directory_private.search(p_query text,p_mode text,p_city text,p_favorites boolean,
  p_after uuid,p_web_only boolean) returns jsonb
language sql stable security definer set search_path='' as $$
  select directory_private.search_with_specialties(p_query,p_mode,p_city,p_favorites,p_after,p_web_only,'{}')
$$;

create function directory_private.specialty_catalog() returns jsonb
language sql stable security definer set search_path='' as $$
  select coalesce(jsonb_agg(jsonb_build_object('id',id,'name',name) order by normalized_name,id),'[]'::jsonb)
  from directory_private.specialties
$$;

create function directory_private.suggest_specialty(p_owner uuid,p_name text,p_details text) returns void
language plpgsql security definer set search_path='' as $$
declare v_name text:=btrim(p_name); v_details text:=btrim(coalesce(p_details,''));
begin
  perform commerce_private.assert_owner(p_owner,true);
  if not trainer_private.has_professional_session()
    or not exists(select 1 from public.trainer_access where trainer_id=p_owner) then raise insufficient_privilege; end if;
  if v_name is null or length(v_name) not between 2 and 60 or length(v_details)>500 then raise invalid_parameter_value; end if;
  if exists(select 1 from directory_private.specialties s where directory_private.specialty_matches(s,v_name)) then
    raise unique_violation;
  end if;
  insert into directory_private.specialty_suggestions(owner_id,name,details) values(p_owner,v_name,v_details)
    on conflict(owner_id,normalized_name) where state='pending' do nothing;
end $$;

create function directory_private.specialty_suggestions_for(p_owner uuid,p_pending boolean) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare result jsonb;
begin
  perform commerce_private.assert_owner(p_owner,true);
  if p_pending and not public.can_manage_pro_accounts() then raise insufficient_privilege; end if;
  select coalesce(jsonb_agg(j),'[]'::jsonb) into result from (
    select jsonb_build_object('id',r.id,'name',r.name,'details',r.details,'state',r.state,'note',r.note,
      'approved_name',s.name,'proposer',case when p_pending then coalesce(nullif(btrim(p.full_name),''),'Preparador') end) j
    from directory_private.specialty_suggestions r
    join public.profiles p on p.id=r.owner_id
    left join directory_private.specialties s on s.id=r.specialty_id
    where (p_pending and r.state='pending') or (not p_pending and r.owner_id=p_owner)
    order by case when p_pending then r.created_at end asc,r.created_at desc,r.id limit 50
  ) page;
  return result;
end $$;

create function directory_private.review_specialty(p_owner uuid,p_id uuid,p_approve boolean,p_existing text,
  p_name text,p_note text) returns void
language plpgsql security definer set search_path='' as $$
declare target directory_private.specialty_suggestions; v_id text; v_name text:=btrim(p_name); v_note text:=btrim(coalesce(p_note,''));
begin
  perform commerce_private.assert_owner(p_owner,true);
  if not public.can_manage_pro_accounts() then raise insufficient_privilege; end if;
  if p_approve is null or length(v_note)>500
    or (not p_approve and (p_existing is not null or p_name is not null or v_note=''))
    or (p_approve and ((p_existing is null)=(p_name is null))) then raise invalid_parameter_value; end if;
  select * into target from directory_private.specialty_suggestions where id=p_id for update;
  if not found then raise no_data_found; end if;
  if target.state<>'pending' then raise serialization_failure; end if;
  if p_approve then
    if p_existing is not null then
      select id into strict v_id from directory_private.specialties where id=p_existing;
    else
      if length(v_name) not between 2 and 60 then raise invalid_parameter_value; end if;
      if exists(select 1 from directory_private.specialties s where directory_private.specialty_matches(s,v_name)) then
        raise unique_violation;
      end if;
      insert into directory_private.specialties(name) values(v_name) returning id into v_id;
    end if;
  end if;
  update directory_private.specialty_suggestions set
    state=case when p_approve then 'approved' else 'declined' end,
    specialty_id=v_id,note=v_note,reviewed_by=p_owner,reviewed_at=statement_timestamp() where id=p_id;
end $$;

create function public.directory_search_with_specialties(p_query text,p_mode text,p_city text,p_favorites boolean,
  p_after uuid,p_web_only boolean,p_specialty_ids text[]) returns jsonb language sql stable security invoker set search_path='' as $$
  select directory_private.search_with_specialties(p_query,p_mode,p_city,p_favorites,p_after,p_web_only,p_specialty_ids)
$$;
create function public.directory_specialty_catalog() returns jsonb language sql stable security invoker set search_path='' as $$
  select directory_private.specialty_catalog()
$$;
create function public.directory_suggest_specialty(p_owner uuid,p_name text,p_details text) returns void language sql security invoker set search_path='' as $$
  select directory_private.suggest_specialty(p_owner,p_name,p_details)
$$;
create function public.directory_specialty_suggestions(p_owner uuid,p_pending boolean) returns jsonb language sql stable security invoker set search_path='' as $$
  select directory_private.specialty_suggestions_for(p_owner,p_pending)
$$;
create function public.directory_review_specialty(p_owner uuid,p_id uuid,p_approve boolean,p_existing text,p_name text,p_note text)
returns void language sql security invoker set search_path='' as $$
  select directory_private.review_specialty(p_owner,p_id,p_approve,p_existing,p_name,p_note)
$$;

revoke all on function directory_private.specialty_matches(directory_private.specialties,text),
  directory_private.selected_specialty_ids(jsonb,directory_private.profiles),
  directory_private.search_with_specialties(text,text,text,boolean,uuid,boolean,text[]),
  public.directory_search_with_specialties(text,text,text,boolean,uuid,boolean,text[]),
  directory_private.specialty_catalog(),public.directory_specialty_catalog(),
  directory_private.suggest_specialty(uuid,text,text),public.directory_suggest_specialty(uuid,text,text),
  directory_private.specialty_suggestions_for(uuid,boolean),public.directory_specialty_suggestions(uuid,boolean),
  directory_private.review_specialty(uuid,uuid,boolean,text,text,text),public.directory_review_specialty(uuid,uuid,boolean,text,text,text)
  from public,anon,authenticated,service_role;
grant execute on function directory_private.search_with_specialties(text,text,text,boolean,uuid,boolean,text[]),
  public.directory_search_with_specialties(text,text,text,boolean,uuid,boolean,text[]),
  directory_private.specialty_catalog(),public.directory_specialty_catalog() to anon,authenticated;
grant execute on function directory_private.suggest_specialty(uuid,text,text),public.directory_suggest_specialty(uuid,text,text),
  directory_private.specialty_suggestions_for(uuid,boolean),public.directory_specialty_suggestions(uuid,boolean),
  directory_private.review_specialty(uuid,uuid,boolean,text,text,text),public.directory_review_specialty(uuid,uuid,boolean,text,text,text) to authenticated;

commit;
