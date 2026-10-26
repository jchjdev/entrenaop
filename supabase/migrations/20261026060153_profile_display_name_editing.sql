begin;

create schema profile_private;
revoke all on schema profile_private from public,anon,authenticated;
grant usage on schema profile_private to authenticated;

-- El nombre es presentación, nunca identidad ni autorización. La operación
-- fija la cuenta y no acepta otros campos de perfil, Auth o permisos.
create function profile_private.update_name(p_expected_owner uuid,p_name text)
returns text language plpgsql security definer set search_path='' as $$
declare normalized text:=btrim(regexp_replace(p_name,'[[:space:]]+',' ','g'));
begin
 if auth.uid() is null or auth.uid() is distinct from p_expected_owner
  or coalesce((auth.jwt()->>'is_anonymous')::boolean,false) then raise insufficient_privilege; end if;
 if normalized is null or char_length(normalized) not between 1 and 100
  or p_name ~ '[[:cntrl:]]' then
  raise exception 'Escribe un nombre de entre 1 y 100 caracteres, sin saltos de línea.' using errcode='22023'; end if;
 -- Mismo orden que las operaciones del alumno; no sustituye identidades ni
 -- versiones deportivas. Las carteras muestran el nombre corregido.
 perform pg_advisory_xact_lock(hashtextextended('trainer-client:'||auth.uid()::text,0));
 perform 1 from public.profiles where id=auth.uid() for update;
 if not found then raise insufficient_privilege; end if;
 update public.profiles set full_name=normalized,updated_at=clock_timestamp() where id=auth.uid();
 update auth.users set raw_user_meta_data=jsonb_set(coalesce(raw_user_meta_data,'{}'::jsonb),
  '{full_name}',to_jsonb(normalized)),updated_at=clock_timestamp() where id=auth.uid();
 if not found then raise insufficient_privilege; end if;
 update public.trainer_clients set display_name=normalized,updated_at=clock_timestamp()
  where client_id=auth.uid() and display_name is distinct from normalized;
 return normalized;
end $$;
revoke all on function profile_private.update_name(uuid,text) from public,anon,authenticated;
grant execute on function profile_private.update_name(uuid,text) to authenticated;
create function public.update_my_profile_name(p_expected_owner uuid,p_name text)
returns text language sql security invoker set search_path='' as $$
 select profile_private.update_name(p_expected_owner,p_name);
$$;
revoke all on function public.update_my_profile_name(uuid,text) from public,anon,authenticated;
grant execute on function public.update_my_profile_name(uuid,text) to authenticated;

commit;
