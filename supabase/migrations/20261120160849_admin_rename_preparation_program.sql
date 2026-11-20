begin;

create schema preparation_admin_private;
revoke all on schema preparation_admin_private from public, anon, authenticated;
grant usage on schema preparation_admin_private to authenticated;

create function preparation_admin_private.rename_program(
  p_program_id text, p_expected_name text, p_name text
) returns void language plpgsql security definer set search_path='' as $$
declare
  clean_name text := btrim(p_name);
  current_name text;
begin
  if auth.uid() is null or not public.is_admin()
    or (auth.jwt()->>'aal') is distinct from 'aal2' then
    raise insufficient_privilege;
  end if;
  if p_program_id is null or p_expected_name is null or clean_name is null
    or char_length(clean_name) not between 3 and 120 then
    raise invalid_parameter_value;
  end if;

  select name into current_name from public.preparation_programs
    where id=p_program_id for update;
  if not found then raise no_data_found; end if;
  -- Un reintento tras perder la respuesta confirma el mismo nombre.
  if current_name=clean_name then return; end if;
  if current_name<>p_expected_name then raise serialization_failure; end if;

  update public.preparation_programs set name=clean_name where id=p_program_id;
end $$;

create function public.admin_rename_preparation_program(
  p_program_id text, p_expected_name text, p_name text
) returns void language sql security invoker set search_path='' as $$
  select preparation_admin_private.rename_program(p_program_id,p_expected_name,p_name)
$$;

revoke all on function preparation_admin_private.rename_program(text,text,text),
  public.admin_rename_preparation_program(text,text,text) from public, anon, authenticated, service_role;
grant execute on function preparation_admin_private.rename_program(text,text,text),
  public.admin_rename_preparation_program(text,text,text) to authenticated;

commit;
