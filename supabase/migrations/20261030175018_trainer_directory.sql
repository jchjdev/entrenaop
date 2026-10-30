begin;
-- La publicidad depende de una prestación comercial confirmada, nunca del cupo
-- ni de una concesión manual. El catálogo existente no recibe ese derecho.
alter table commerce_private.offers add column directory_enabled boolean not null default false;
create schema directory_private;
revoke all on schema directory_private from public;
grant usage on schema directory_private to anon,authenticated;
create table directory_private.settings(singleton boolean primary key default true check(singleton), enabled boolean not null default false);
insert into directory_private.settings default values;
create table directory_private.profiles(
 id uuid primary key default gen_random_uuid(), trainer_id uuid not null unique references public.profiles(id) on delete restrict,
 name text not null check(length(name) between 1 and 80), description text not null check(length(description) between 1 and 1200),
 specialties text[] not null, services text[] not null,
 mode text not null check(mode in ('online','presencial','ambas')), city text not null default '' check(length(city)<=80),
 visibility text not null check(visibility in ('app','web')), photo_path text,
 email text not null default '' check(length(email)<=254), website text not null default '' check(length(website)<=500),
 whatsapp text not null default '', price text not null default '' check(length(price)<=120),
 accepting boolean not null default true, published boolean not null default false,
 suspended boolean not null default false, revision integer not null default 1 check(revision>0),
 consent_at timestamptz, consent_version integer, updated_at timestamptz not null default now(),
 check(cardinality(specialties) between 1 and 8), check(cardinality(services) between 1 and 8),
 check(mode='online' or length(btrim(city))>0),
 check(email<>'' or website<>'' or whatsapp<>''),
 check(email='' or email ~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$'),
 check(website='' or website ~ '^https://[A-Za-z0-9.-]+(:[0-9]+)?([/?#][^[:space:]]*)?$'),
 check(whatsapp='' or whatsapp ~ '^[0-9]{8,15}$'),
 check(photo_path is null or photo_path ~ ('^'||trainer_id::text||'/[a-f0-9-]{36}\.jpg$')),
 check(not published or (photo_path is not null and consent_at is not null and consent_version=1))
);
create table directory_private.favorites(
 owner_id uuid not null references public.profiles(id) on delete cascade,
 profile_id uuid not null references directory_private.profiles(id) on delete cascade,
 primary key(owner_id,profile_id)
);
create index directory_favorites_profile on directory_private.favorites(profile_id);
create table directory_private.reports(
 id uuid primary key default gen_random_uuid(), reporter_id uuid not null references public.profiles(id) on delete restrict,
 profile_id uuid not null references directory_private.profiles(id) on delete restrict,
 reason text not null check(reason in ('explicit','harassment','impersonation','spam','misleading','other')),
 details text not null check(length(details)<=1000), status text not null default 'pending' check(status in ('pending','dismissed','actioned')),
 created_at timestamptz not null default now(), resolved_at timestamptz
);
create unique index directory_pending_report on directory_private.reports(reporter_id,profile_id) where status='pending';
create index directory_report_profile on directory_private.reports(profile_id);
create index directory_report_reporter_time on directory_private.reports(reporter_id,created_at);
create table directory_private.moderation_events(
 id bigint generated always as identity primary key, actor_id uuid not null references public.profiles(id) on delete restrict,
 report_id uuid not null references directory_private.reports(id) on delete restrict,
 suspended boolean not null, reason text not null check(length(reason) between 5 and 1000), created_at timestamptz not null default now()
);
create index directory_moderation_actor on directory_private.moderation_events(actor_id);
create index directory_moderation_report on directory_private.moderation_events(report_id);
alter table directory_private.settings enable row level security;
alter table directory_private.profiles enable row level security;
alter table directory_private.favorites enable row level security;
alter table directory_private.reports enable row level security;
alter table directory_private.moderation_events enable row level security;
revoke all on all tables in schema directory_private from public,anon,authenticated,service_role;

create function directory_private.eligible(p_trainer uuid) returns boolean
language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.trainer_access a where a.trainer_id=p_trainer and a.enabled and (a.valid_until is null or a.valid_until>statement_timestamp()))
 and exists(select 1 from commerce_private.orders o join commerce_private.offers f on f.id=o.offer_id
 where o.owner_id=p_trainer and o.paid_until>statement_timestamp() and f.directory_enabled)
$$;
create function directory_private.member() returns boolean
language sql stable security definer set search_path='' as $$
 select auth.uid() is not null and not coalesce((auth.jwt()->>'is_anonymous')::boolean,false)
 and exists(select 1 from auth.users where id=auth.uid() and email_confirmed_at is not null)
$$;
create function directory_private.can_read(p_id uuid,p_web_only boolean default false) returns boolean
language sql stable security definer set search_path='' as $$
 select exists(select 1 from directory_private.profiles p where p.id=p_id and p.published and not p.suspended
 and p.consent_version=1 and directory_private.eligible(p.trainer_id)
 and (select enabled from directory_private.settings where singleton)
 and (p.visibility='web' or (not coalesce(p_web_only,true) and directory_private.member())))
$$;
create function directory_private.profile_json(p directory_private.profiles) returns jsonb
language sql stable security definer set search_path='' as $$
 select jsonb_build_object('id',p.id,'name',p.name,'description',p.description,'specialties',p.specialties,'services',p.services,
 'mode',p.mode,'city',p.city,'visibility',p.visibility,'photo_path',p.photo_path,'email',p.email,'website',p.website,
 'whatsapp',p.whatsapp,'price',p.price,'accepting',p.accepting,
 'favorite',exists(select 1 from directory_private.favorites f where f.owner_id=auth.uid() and f.profile_id=p.id))
$$;
create function directory_private.search(p_query text,p_mode text,p_city text,p_favorites boolean,p_after uuid,p_web_only boolean) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare items jsonb; more boolean; last_id uuid;
begin
 if p_query is null or length(p_query)>120 or p_city is null or length(p_city)>80
 or (p_mode is not null and p_mode not in ('online','presencial','ambas')) then raise invalid_parameter_value; end if;
 if p_favorites and not directory_private.member() then raise insufficient_privilege;end if;
 with candidates as (
 select p.* from directory_private.profiles p where directory_private.can_read(p.id,p_web_only)
 and (p_after is null or p.id>p_after)
 and (p_mode is null or p.mode=p_mode or p.mode='ambas')
 and p.city ilike '%'||p_city||'%'
 and concat_ws(' ',p.name,p.description,array_to_string(p.specialties,' '),array_to_string(p.services,' ')) ilike '%'||p_query||'%'
 and (not p_favorites or exists(select 1 from directory_private.favorites f where f.owner_id=auth.uid() and f.profile_id=p.id))
 order by p.id limit 21), page as(select * from candidates order by id limit 20)
 select coalesce((select jsonb_agg(directory_private.profile_json(p) order by p.id) from page join directory_private.profiles p on p.id=page.id),'[]'::jsonb),
 (select count(*)>20 from candidates),(select id from page order by id desc limit 1) into items,more,last_id;
 return jsonb_build_object('items',items,'next',case when more then last_id else null end);
end $$;
create function directory_private.detail(p_id uuid,p_web_only boolean) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare p directory_private.profiles;
begin
 if not directory_private.can_read(p_id,p_web_only) then raise insufficient_privilege; end if;
 select * into strict p from directory_private.profiles where id=p_id;
 return directory_private.profile_json(p);
end $$;
create function directory_private.own(p_expected_owner uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare p directory_private.profiles;
begin
 perform commerce_private.assert_owner(p_expected_owner,true);
 select * into p from directory_private.profiles where trainer_id=p_expected_owner;
 return jsonb_build_object('profile',case when p.id is not null then directory_private.profile_json(p) else null end,
 'revision',coalesce(p.revision,0),'eligible',directory_private.eligible(p_expected_owner),'published',coalesce(p.published,false),
 'blocked',coalesce(p.suspended,false),'consent',coalesce(p.consent_version=1,false),
 'enabled',(select enabled from directory_private.settings where singleton));
end $$;
create function directory_private.save(p_expected_owner uuid,p_revision integer,p_data jsonb,p_published boolean,p_consent boolean) returns jsonb
language plpgsql security definer set search_path='' as $$
declare p directory_private.profiles; tags text[]; svc text[]; photo text; v_visibility text;
begin
 perform commerce_private.assert_owner(p_expected_owner,true);
 perform pg_advisory_xact_lock(hashtextextended('directory-owner:'||p_expected_owner::text,0));
 select * into p from directory_private.profiles where trainer_id=p_expected_owner for update;
 if p_revision is distinct from coalesce(p.revision,0) then raise serialization_failure; end if;
 if p_published is null or p_consent is null or p_data is null or jsonb_typeof(p_data)<>'object' then raise invalid_parameter_value;end if;
 if p_published and (not p_consent or not directory_private.eligible(p_expected_owner)
 or not (select enabled from directory_private.settings where singleton)) then raise insufficient_privilege;end if;
 if not exists(select 1 from public.trainer_access where trainer_id=p_expected_owner) then raise insufficient_privilege;end if;
 v_visibility:=p_data->>'visibility';
 if p_published and (p.visibility is distinct from v_visibility or not coalesce(p.published,false)) and not p_consent then raise insufficient_privilege;end if;
 tags:=array(select jsonb_array_elements_text(p_data->'specialties'));
 svc:=array(select jsonb_array_elements_text(p_data->'services'));
 if exists(select 1 from unnest(tags||svc) t where length(btrim(t)) not between 1 and 60) then raise invalid_parameter_value;end if;
 photo:=nullif(p_data->>'photo_path','');
 if photo is not null and not exists(select 1 from storage.objects where bucket_id='trainer-directory' and name=photo
 and name ~ ('^'||p_expected_owner::text||'/[a-f0-9-]{36}\.jpg$')) then raise invalid_parameter_value;end if;
 insert into directory_private.profiles as target(trainer_id,name,description,specialties,services,mode,city,visibility,photo_path,email,website,whatsapp,price,accepting,published,consent_at,consent_version)
 values(p_expected_owner,btrim(p_data->>'name'),btrim(p_data->>'description'),tags,svc,p_data->>'mode',btrim(p_data->>'city'),v_visibility,photo,
 btrim(p_data->>'email'),btrim(p_data->>'website'),btrim(p_data->>'whatsapp'),btrim(p_data->>'price'),(p_data->>'accepting')::boolean,p_published,
 case when p_consent then statement_timestamp() end,case when p_consent then 1 end)
 on conflict(trainer_id) do update set name=excluded.name,description=excluded.description,specialties=excluded.specialties,services=excluded.services,
 mode=excluded.mode,city=excluded.city,visibility=excluded.visibility,photo_path=excluded.photo_path,email=excluded.email,website=excluded.website,
 whatsapp=excluded.whatsapp,price=excluded.price,accepting=excluded.accepting,published=excluded.published,
 consent_at=excluded.consent_at,consent_version=excluded.consent_version,revision=target.revision+1,updated_at=statement_timestamp();
 return directory_private.own(p_expected_owner);
end $$;
create function directory_private.favorite(p_expected_owner uuid,p_id uuid,p_value boolean) returns void
language plpgsql security definer set search_path='' as $$
begin
 perform commerce_private.assert_owner(p_expected_owner);
 if p_value is null then raise invalid_parameter_value;end if;
 if p_value then
  if not directory_private.can_read(p_id,false) then raise insufficient_privilege;end if;
  insert into directory_private.favorites values(p_expected_owner,p_id) on conflict do nothing;
 else delete from directory_private.favorites where owner_id=p_expected_owner and profile_id=p_id;end if;
end $$;
create function directory_private.report(p_expected_owner uuid,p_id uuid,p_reason text,p_details text) returns void
language plpgsql security definer set search_path='' as $$
begin
 perform commerce_private.assert_owner(p_expected_owner);
 perform pg_advisory_xact_lock(hashtextextended('directory-report:'||p_expected_owner::text,0));
 if not directory_private.can_read(p_id,false) or exists(select 1 from directory_private.profiles where id=p_id and trainer_id=p_expected_owner) then raise insufficient_privilege;end if;
 if exists(select 1 from directory_private.reports where reporter_id=p_expected_owner and profile_id=p_id and status='pending') then return;end if;
 if (select count(*) from directory_private.reports where reporter_id=p_expected_owner and created_at>statement_timestamp()-interval '1 day')>=10 then raise check_violation;end if;
 insert into directory_private.reports(reporter_id,profile_id,reason,details) values(p_expected_owner,p_id,p_reason,btrim(p_details));
end $$;
create function directory_private.reports(p_expected_owner uuid,p_after uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
begin
 perform commerce_private.assert_owner(p_expected_owner,true);
 if not public.can_manage_pro_accounts() then raise insufficient_privilege;end if;
 return coalesce((select jsonb_agg(j order by id) from (
 select r.id,jsonb_build_object('id',r.id,'profile',directory_private.profile_json(p),'reason',r.reason,'details',r.details,'status',r.status,'suspended',p.suspended) j
 from directory_private.reports r join directory_private.profiles p on p.id=r.profile_id where p_after is null or r.id>p_after order by r.id limit 50) s),'[]'::jsonb);
end $$;
create function directory_private.moderate(p_expected_owner uuid,p_report_id uuid,p_suspend boolean,p_reason text) returns void
language plpgsql security definer set search_path='' as $$
declare target uuid;
begin
 perform commerce_private.assert_owner(p_expected_owner,true);
 if not public.can_manage_pro_accounts() then raise insufficient_privilege;end if;
 if p_suspend is null or length(btrim(p_reason)) not between 5 and 1000 then raise invalid_parameter_value;end if;
 select profile_id into strict target from directory_private.reports where id=p_report_id for update;
 update directory_private.profiles set suspended=p_suspend,revision=revision+1,updated_at=statement_timestamp() where id=target;
 update directory_private.reports set status=case when p_suspend then 'actioned' else 'dismissed' end,resolved_at=statement_timestamp() where id=p_report_id;
 insert into directory_private.moderation_events(actor_id,report_id,suspended,reason) values(p_expected_owner,p_report_id,p_suspend,btrim(p_reason));
end $$;
-- Fotos privadas: ni enlaces públicos ni enlaces firmados que mantengan acceso
-- tras ocultar la ficha. La descarga comprueba la visibilidad en cada petición.
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
 values('trainer-directory','trainer-directory',false,512000,array['image/jpeg']);
create function directory_private.photo_read(p_path text) returns boolean
language sql stable security definer set search_path='' as $$
 select exists(select 1 from directory_private.profiles p where p.photo_path=p_path and directory_private.can_read(p.id,false))
 or (directory_private.member() and (split_part(p_path,'/',1)=auth.uid()::text or public.can_manage_pro_accounts()))
$$;
create function directory_private.photo_upload(p_path text) returns boolean
language plpgsql security definer set search_path='' as $$
begin
 perform commerce_private.assert_owner(auth.uid(),true);
 perform trainer_private.require_authoring_access();
 perform pg_advisory_xact_lock(hashtextextended('directory-photo:'||auth.uid()::text,0));
 return p_path ~ ('^'||auth.uid()::text||'/[a-f0-9-]{36}\.jpg$') and
 (select count(*) from storage.objects where bucket_id='trainer-directory' and split_part(name,'/',1)=auth.uid()::text)<3;
end $$;
create function directory_private.photo_delete(p_path text) returns boolean
language sql stable security definer set search_path='' as $$
 select directory_private.member() and trainer_private.has_trainer_mfa() and split_part(p_path,'/',1)=auth.uid()::text
 and not exists(select 1 from directory_private.profiles where photo_path=p_path)
$$;
create policy directory_photo_read on storage.objects for select to anon,authenticated
 using(bucket_id='trainer-directory' and directory_private.photo_read(name));
create policy directory_photo_upload on storage.objects for insert to authenticated
 with check(bucket_id='trainer-directory' and directory_private.photo_upload(name));
create policy directory_photo_delete on storage.objects for delete to authenticated
 using(bucket_id='trainer-directory' and directory_private.photo_delete(name));

create function public.directory_search(p_query text default '',p_mode text default null,p_city text default '',p_favorites boolean default false,p_after uuid default null,p_web_only boolean default true) returns jsonb
language sql stable security invoker set search_path='' as $$select directory_private.search(p_query,p_mode,p_city,p_favorites,p_after,p_web_only)$$;
create function public.directory_profile(p_id uuid,p_web_only boolean default true) returns jsonb
language sql stable security invoker set search_path='' as $$select directory_private.detail(p_id,p_web_only)$$;
create function public.directory_own(p_expected_owner uuid) returns jsonb language sql stable security invoker set search_path='' as $$select directory_private.own(p_expected_owner)$$;
create function public.directory_save(p_expected_owner uuid,p_revision integer,p_data jsonb,p_published boolean,p_consent boolean) returns jsonb language sql security invoker set search_path='' as $$select directory_private.save(p_expected_owner,p_revision,p_data,p_published,p_consent)$$;
create function public.directory_favorite(p_expected_owner uuid,p_id uuid,p_value boolean) returns void language sql security invoker set search_path='' as $$select directory_private.favorite(p_expected_owner,p_id,p_value)$$;
create function public.directory_report(p_expected_owner uuid,p_id uuid,p_reason text,p_details text) returns void language sql security invoker set search_path='' as $$select directory_private.report(p_expected_owner,p_id,p_reason,p_details)$$;
create function public.directory_reports(p_expected_owner uuid,p_after uuid default null) returns jsonb language sql stable security invoker set search_path='' as $$select directory_private.reports(p_expected_owner,p_after)$$;
create function public.directory_moderate(p_expected_owner uuid,p_report_id uuid,p_suspend boolean,p_reason text) returns void language sql security invoker set search_path='' as $$select directory_private.moderate(p_expected_owner,p_report_id,p_suspend,p_reason)$$;
revoke all on all functions in schema directory_private from public,anon,authenticated;
grant execute on function directory_private.search(text,text,text,boolean,uuid,boolean),directory_private.detail(uuid,boolean),directory_private.photo_read(text) to anon,authenticated;
grant execute on function directory_private.own(uuid),directory_private.save(uuid,integer,jsonb,boolean,boolean),directory_private.favorite(uuid,uuid,boolean),directory_private.report(uuid,uuid,text,text),directory_private.reports(uuid,uuid),directory_private.moderate(uuid,uuid,boolean,text),directory_private.photo_upload(text),directory_private.photo_delete(text) to authenticated;
revoke all on function public.directory_search(text,text,text,boolean,uuid,boolean),public.directory_profile(uuid,boolean),public.directory_own(uuid),public.directory_save(uuid,integer,jsonb,boolean,boolean),public.directory_favorite(uuid,uuid,boolean),public.directory_report(uuid,uuid,text,text),public.directory_reports(uuid,uuid),public.directory_moderate(uuid,uuid,boolean,text) from public,anon,authenticated;
grant execute on function public.directory_search(text,text,text,boolean,uuid,boolean),public.directory_profile(uuid,boolean) to anon,authenticated;
grant execute on function public.directory_own(uuid),public.directory_save(uuid,integer,jsonb,boolean,boolean),public.directory_favorite(uuid,uuid,boolean),public.directory_report(uuid,uuid,text,text),public.directory_reports(uuid,uuid),public.directory_moderate(uuid,uuid,boolean,text) to authenticated;
commit;
