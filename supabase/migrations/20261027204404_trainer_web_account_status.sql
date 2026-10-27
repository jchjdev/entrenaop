-- Antes de MFA solo se revela el estado mínimo de la cuenta propia.
create function trainer_private.my_account_status(p_expected_owner uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
begin
 if auth.uid() is null or auth.uid() is distinct from p_expected_owner
  or coalesce((auth.jwt()->>'is_anonymous')::boolean,false)
  or not exists(select 1 from auth.users where id=auth.uid() and email_confirmed_at is not null)
 then raise insufficient_privilege; end if;
 return jsonb_build_object(
  'professional_account',exists(select 1 from public.trainer_access where trainer_id=auth.uid())
    or exists(select 1 from public.trainer_client_relations where trainer_id=auth.uid()),
  'enabled',exists(select 1 from public.trainer_access where trainer_id=auth.uid() and enabled
    and (valid_until is null or valid_until>statement_timestamp())));
end $$;
create function public.get_my_trainer_account_status(p_expected_owner uuid) returns jsonb
language sql security invoker set search_path='' as $$select trainer_private.my_account_status(p_expected_owner)$$;
revoke all on function trainer_private.my_account_status(uuid),public.get_my_trainer_account_status(uuid) from public,anon,authenticated;
grant execute on function trainer_private.my_account_status(uuid),public.get_my_trainer_account_status(uuid) to authenticated;
