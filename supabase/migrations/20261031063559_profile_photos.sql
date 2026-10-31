begin;

-- Foto personal privada: el campo antiguo avatar_url no concede acceso ni se
-- reutiliza como enlace externo. La identidad y el directorio son independientes.
create table profile_private.photos(
 owner_id uuid primary key references public.profiles(id) on delete cascade,
 path text, revision bigint not null default 1 check(revision>0),
 check(path is null or path ~ ('^'||owner_id::text||'/[a-f0-9-]{36}\.jpg$'))
);
alter table profile_private.photos enable row level security;
revoke all on profile_private.photos from public,anon,authenticated,service_role;

create function profile_private.photo_member() returns boolean
language sql stable security definer set search_path='' as $$
 select auth.uid() is not null and not coalesce((auth.jwt()->>'is_anonymous')::boolean,false)
 and exists(select 1 from auth.users where id=auth.uid() and email_confirmed_at is not null)
$$;
create function profile_private.photo_visible(p_person uuid) returns boolean
language sql stable security definer set search_path='' as $$
 select profile_private.photo_member() and (auth.uid()=p_person or exists(
  select 1 from public.trainer_client_relations r join public.trainer_access a on a.trainer_id=r.trainer_id
  where r.ended_at is null and a.enabled and (a.valid_until is null or a.valid_until>statement_timestamp())
  and ((r.trainer_id=auth.uid() and r.client_id=p_person and trainer_private.has_trainer_mfa())
   or (r.client_id=auth.uid() and r.trainer_id=p_person))))
$$;
create function profile_private.visible_photo_path(p_person uuid) returns text
language sql stable security definer set search_path='' as $$
 select path from profile_private.photos where owner_id=p_person and profile_private.photo_visible(p_person)
$$;
create function profile_private.my_photo(p_expected_owner uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare p profile_private.photos;
begin
 if not profile_private.photo_member() or auth.uid() is distinct from p_expected_owner then raise insufficient_privilege;end if;
 select * into p from profile_private.photos where owner_id=auth.uid();
 return jsonb_build_object('path',p.path,'revision',coalesce(p.revision,0));
end $$;
create function profile_private.set_photo(p_expected_owner uuid,p_path text,p_revision bigint) returns jsonb
language plpgsql security definer set search_path='' as $$
declare p profile_private.photos;
begin
 if not profile_private.photo_member() or auth.uid() is distinct from p_expected_owner then raise insufficient_privilege;end if;
 perform pg_advisory_xact_lock(hashtextextended('profile-photo:'||auth.uid()::text,0));
 select * into p from profile_private.photos where owner_id=auth.uid() for update;
 if p_revision is distinct from coalesce(p.revision,0) then raise serialization_failure;end if;
 if p_path is not null and (p_path !~ ('^'||auth.uid()::text||'/[a-f0-9-]{36}\.jpg$') or not exists(
  select 1 from storage.objects where bucket_id='profile-photos' and name=p_path)) then raise invalid_parameter_value;end if;
 insert into profile_private.photos as target(owner_id,path) values(auth.uid(),p_path)
 on conflict(owner_id) do update set path=excluded.path,revision=target.revision+1;
 return profile_private.my_photo(p_expected_owner);
end $$;
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
 values('profile-photos','profile-photos',false,512000,array['image/jpeg']);
create function profile_private.photo_upload(p_path text) returns boolean
language plpgsql security definer set search_path='' as $$
begin
 if not profile_private.photo_member() then return false;end if;
 perform pg_advisory_xact_lock(hashtextextended('profile-photo:'||auth.uid()::text,0));
 return p_path ~ ('^'||auth.uid()::text||'/[a-f0-9-]{36}\.jpg$') and
 (select count(*) from storage.objects where bucket_id='profile-photos' and split_part(name,'/',1)=auth.uid()::text)<3;
end $$;
create function profile_private.photo_read(p_path text) returns boolean
language sql stable security definer set search_path='' as $$
 select profile_private.photo_member() and (
 (split_part(p_path,'/',1)=auth.uid()::text and storage.allow_any_operation(array[
  'object.get_authenticated','object.get_authenticated_info','object.list','object.delete']))
 or (storage.allow_any_operation(array['object.get_authenticated','object.get_authenticated_info'])
  and exists(select 1 from profile_private.photos where path=p_path and profile_private.photo_visible(owner_id))))
$$;
create function profile_private.photo_delete(p_path text) returns boolean
language sql stable security definer set search_path='' as $$
 select profile_private.photo_member() and split_part(p_path,'/',1)=auth.uid()::text
 and not exists(select 1 from profile_private.photos where path=p_path)
$$;
create policy profile_photo_read on storage.objects for select to authenticated
 using(bucket_id='profile-photos' and profile_private.photo_read(name));
create policy profile_photo_upload on storage.objects for insert to authenticated
 with check(bucket_id='profile-photos' and profile_private.photo_upload(name));
create policy profile_photo_delete on storage.objects for delete to authenticated
 using(bucket_id='profile-photos' and profile_private.photo_delete(name));

create function public.get_my_profile_photo(p_expected_owner uuid) returns jsonb
language sql stable security invoker set search_path='' as $$select profile_private.my_photo(p_expected_owner)$$;
create function public.set_my_profile_photo(p_expected_owner uuid,p_path text,p_revision bigint) returns jsonb
language sql security invoker set search_path='' as $$select profile_private.set_photo(p_expected_owner,p_path,p_revision)$$;
revoke all on function profile_private.photo_member(),profile_private.photo_visible(uuid),
 profile_private.visible_photo_path(uuid),profile_private.my_photo(uuid),profile_private.set_photo(uuid,text,bigint),
 profile_private.photo_upload(text),profile_private.photo_read(text),profile_private.photo_delete(text),
 public.get_my_profile_photo(uuid),public.set_my_profile_photo(uuid,text,bigint) from public,anon,authenticated;
grant execute on function profile_private.visible_photo_path(uuid),profile_private.my_photo(uuid),
 profile_private.set_photo(uuid,text,bigint),profile_private.photo_upload(text),profile_private.photo_read(text),
 profile_private.photo_delete(text),public.get_my_profile_photo(uuid),public.set_my_profile_photo(uuid,text,bigint) to authenticated;

-- Campos opcionales en los lectores existentes; no cambian orden ni paginación.
create or replace function public.list_trainer_clients(p_state text default 'active',p_before_at timestamptz default null,p_before_client_id uuid default null)
returns jsonb language sql stable security invoker set search_path='' as $$
 select coalesce(jsonb_agg(item||jsonb_build_object('profile_photo_path',profile_private.visible_photo_path((item->>'person_id')::uuid)) order by position),'[]'::jsonb)
 from jsonb_array_elements(trainer_private.list_trainer_clients(p_state,p_before_at,p_before_client_id)) with ordinality as rows(item,position)
$$;
create or replace function public.get_trainer_client_workspace(p_client_id uuid) returns jsonb
language sql stable security invoker set search_path='' as $$
 select body||jsonb_build_object('client',body->'client'||jsonb_build_object('profile_photo_path',profile_private.visible_photo_path(p_client_id)))
 from (select trainer_private.get_trainer_client_workspace(p_client_id) as body) as result
$$;
commit;
