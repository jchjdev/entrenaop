begin;

-- El ensayo es individual y temporal. No concede un plan comercial ni cambia
-- las ofertas: la publicación normal sigue exigiendo contratación elegible.
create table directory_private.dev_pilot_members (
  trainer_id uuid primary key references public.profiles(id) on delete cascade,
  source_order_id uuid not null references commerce_private.orders(id) on delete cascade,
  valid_until timestamptz not null,
  enabled boolean not null default true,
  reason text not null check(length(btrim(reason)) between 5 and 500),
  created_at timestamptz not null default statement_timestamp(),
  check(valid_until > created_at)
);
create index directory_pilot_source_order on directory_private.dev_pilot_members(source_order_id);
alter table directory_private.dev_pilot_members enable row level security;
revoke all on directory_private.dev_pilot_members from public,anon,authenticated,service_role;

create function directory_private.pilot_until(p_trainer uuid) returns timestamptz
language sql stable security definer set search_path='' as $$
  select least(m.valid_until,o.paid_until)
  from directory_private.dev_pilot_members m
  join commerce_private.orders o on o.id=m.source_order_id
  where m.trainer_id=p_trainer and m.enabled
    and least(m.valid_until,o.paid_until)>statement_timestamp()
    and o.paid_until is not null
    -- El emisor procede del JWT verificado, nunca de metadatos editables.
    and auth.jwt()->>'iss'='https://sxbxfjqgoddzhtcyhalw.supabase.co/auth/v1'
$$;

create function directory_private.commercial_eligible(p_trainer uuid) returns boolean
language sql stable security definer set search_path='' as $$
  select exists(select 1 from public.trainer_access a where a.trainer_id=p_trainer
    and a.enabled and (a.valid_until is null or a.valid_until>statement_timestamp()))
  and exists(select 1 from commerce_private.orders o
    join commerce_private.offers f on f.id=o.offer_id
    where o.owner_id=p_trainer and o.paid_until>statement_timestamp() and f.directory_enabled)
$$;

create or replace function directory_private.eligible(p_trainer uuid) returns boolean
language sql stable security definer set search_path='' as $$
  select directory_private.commercial_eligible(p_trainer) or (
    directory_private.pilot_until(p_trainer) is not null
    and exists(select 1 from public.trainer_access a where a.trainer_id=p_trainer
      and a.enabled and (a.valid_until is null or a.valid_until>statement_timestamp())))
$$;

-- Conserva el historial de aceptación aunque se pause o edite el borrador.
create table directory_private.publication_acceptances (
  profile_id uuid not null references directory_private.profiles(id) on delete cascade,
  profile_revision integer not null,
  consent_version integer not null check(consent_version=2),
  visibility text not null check(visibility in('app','web')),
  accepted_at timestamptz not null,
  primary key(profile_id,profile_revision)
);
alter table directory_private.publication_acceptances enable row level security;
revoke all on directory_private.publication_acceptances from public,anon,authenticated,service_role;
-- Las fichas antiguas permanecen guardadas, pero no se sirven sin aceptar V2.
alter table directory_private.profiles drop constraint profiles_check3;
alter table directory_private.profiles add constraint directory_publication_consent
  check(not published or (photo_path is not null and consent_at is not null and consent_version in(1,2)));

create or replace function directory_private.can_read(p_id uuid,p_web_only boolean default false) returns boolean
language sql stable security definer set search_path='' as $$
  select exists(select 1 from directory_private.profiles p
    where p.id=p_id and p.published and not p.suspended and p.consent_version=2
      and directory_private.eligible(p.trainer_id)
      and (select enabled from directory_private.settings where singleton)
      and (directory_private.commercial_eligible(p.trainer_id) or p.visibility='app')
      and (p.visibility='web' or (not coalesce(p_web_only,true) and directory_private.member())))
$$;

create or replace function directory_private.own(p_expected_owner uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare p directory_private.profiles;
begin
  perform commerce_private.assert_owner(p_expected_owner,true);
  select * into p from directory_private.profiles where trainer_id=p_expected_owner;
  return jsonb_build_object(
    'profile',case when p.id is not null then directory_private.profile_json(p) else null end,
    'revision',coalesce(p.revision,0),'eligible',directory_private.eligible(p_expected_owner),
    'published',coalesce(p.published,false),'blocked',coalesce(p.suspended,false),
    'consent',coalesce(p.consent_version=2,false),
    'enabled',(select enabled from directory_private.settings where singleton),
    'pilot_until',directory_private.pilot_until(p_expected_owner),
    'web_allowed',directory_private.commercial_eligible(p_expected_owner));
end $$;

create or replace function directory_private.save(p_expected_owner uuid,p_revision integer,p_data jsonb,p_published boolean,p_consent boolean) returns jsonb
language plpgsql security definer set search_path='' as $$
declare p directory_private.profiles; tags text[]; svc text[]; photo text;
  v_visibility text; accepted boolean;
begin
  perform commerce_private.assert_owner(p_expected_owner,true);
  perform pg_advisory_xact_lock(hashtextextended('directory-owner:'||p_expected_owner::text,0));
  select * into p from directory_private.profiles where trainer_id=p_expected_owner for update;
  if p_revision is distinct from coalesce(p.revision,0) then raise serialization_failure;end if;
  if p_published is null or p_consent is null or p_data is null or jsonb_typeof(p_data)<>'object' then raise invalid_parameter_value;end if;
  accepted:=p_consent and coalesce(p_data->>'consent_version'='2',false);
  if p_published and (not accepted or not directory_private.eligible(p_expected_owner)
    or not (select enabled from directory_private.settings where singleton)) then raise insufficient_privilege;end if;
  if not exists(select 1 from public.trainer_access where trainer_id=p_expected_owner) then raise insufficient_privilege;end if;
  v_visibility:=p_data->>'visibility';
  if p_published and v_visibility='web' and not directory_private.commercial_eligible(p_expected_owner)
    then raise insufficient_privilege;end if;
  tags:=array(select jsonb_array_elements_text(p_data->'specialties'));
  svc:=array(select jsonb_array_elements_text(p_data->'services'));
  if exists(select 1 from unnest(tags||svc) t where length(btrim(t)) not between 1 and 60) then raise invalid_parameter_value;end if;
  photo:=nullif(p_data->>'photo_path','');
  if photo is not null and not exists(select 1 from storage.objects where bucket_id='trainer-directory' and name=photo
    and name ~ ('^'||p_expected_owner::text||'/[a-f0-9-]{36}\.jpg$')) then raise invalid_parameter_value;end if;
  insert into directory_private.profiles as target(trainer_id,name,description,specialties,services,mode,city,visibility,photo_path,email,website,whatsapp,price,accepting,published,consent_at,consent_version)
  values(p_expected_owner,btrim(p_data->>'name'),btrim(p_data->>'description'),tags,svc,p_data->>'mode',btrim(p_data->>'city'),v_visibility,photo,
    btrim(p_data->>'email'),btrim(p_data->>'website'),btrim(p_data->>'whatsapp'),btrim(p_data->>'price'),(p_data->>'accepting')::boolean,p_published,
    case when accepted then statement_timestamp() end,case when accepted then 2 end)
  on conflict(trainer_id) do update set name=excluded.name,description=excluded.description,specialties=excluded.specialties,services=excluded.services,
    mode=excluded.mode,city=excluded.city,visibility=excluded.visibility,photo_path=excluded.photo_path,email=excluded.email,website=excluded.website,
    whatsapp=excluded.whatsapp,price=excluded.price,accepting=excluded.accepting,published=excluded.published,
    consent_at=excluded.consent_at,consent_version=excluded.consent_version,revision=target.revision+1,updated_at=statement_timestamp()
  returning * into p;
  if p_published and accepted then
    insert into directory_private.publication_acceptances
      (profile_id,profile_revision,consent_version,visibility,accepted_at)
    values(p.id,p.revision,p.consent_version,p.visibility,p.consent_at);
  end if;
  return directory_private.own(p_expected_owner);
end $$;

-- GET autenticado y operaciones propias; no se firman URLs que eludan una
-- retirada posterior. La política previa permitía firmarlas al propietario.
alter policy directory_photo_read on storage.objects using(
  bucket_id='trainer-directory' and directory_private.photo_read(name)
  and (storage.allow_any_operation(array['object.get','object.get_authenticated','object.get_authenticated_info'])
    or (split_part(name,'/',1)=auth.uid()::text
      and storage.allow_any_operation(array['object.list','object.delete','object.delete_many']))));

revoke all on function directory_private.pilot_until(uuid),directory_private.commercial_eligible(uuid)
  from public,anon,authenticated,service_role;
commit;
