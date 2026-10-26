begin;
set local statement_timeout='30s';
do $$
declare me uuid:=gen_random_uuid(); other uuid:=gen_random_uuid(); old_role text; raw jsonb;
begin
 insert into auth.users(id,email,raw_user_meta_data) values
  (me,me||'@profile-name.invalid','{"full_name":"Antes","preference":"keep"}'),
  (other,other||'@profile-name.invalid','{"full_name":"Otra persona"}');
 insert into public.trainer_access(trainer_id,enabled,client_limit,last_reason) values(other,true,1,'Fixture nombre');
 insert into public.trainer_client_relations(trainer_id,client_id) values(other,me);
 select role into old_role from public.profiles where id=me;
 perform set_config('request.jwt.claim.sub',me::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',me,'role','authenticated','aal','aal1')::text,true);
 set local role authenticated;
 if public.update_my_profile_name(me,'  Javier   Charlez  ')<>'Javier Charlez' then raise exception 'No normaliza el nombre'; end if;
 if not exists(select 1 from public.profiles where id=me and full_name='Javier Charlez' and role=old_role) then raise exception 'Cambia otra identidad o permisos'; end if;
 perform public.update_my_profile_name(me,'Javier Charlez');
 begin perform public.update_my_profile_name(other,'Intruso'); raise exception 'Edita otra cuenta'; exception when insufficient_privilege then null; end;
 begin perform public.update_my_profile_name(me,'   '); raise exception 'Acepta vacío'; exception when invalid_parameter_value then null; end;
 begin perform public.update_my_profile_name(me,repeat('a',101)); raise exception 'Acepta demasiado largo'; exception when invalid_parameter_value then null; end;
 begin perform public.update_my_profile_name(me,E'Javier\nCharlez'); raise exception 'Acepta control'; exception when invalid_parameter_value then null; end;
 perform set_config('request.jwt.claims',jsonb_build_object('sub',me,'role','authenticated','is_anonymous',true)::text,true);
 begin perform public.update_my_profile_name(me,'Anon'); raise exception 'Permite identidad anónima'; exception when insufficient_privilege then null; end;
 reset role;
 select raw_user_meta_data into raw from auth.users where id=me;
 if raw->>'full_name'<>'Javier Charlez' or raw->>'preference'<>'keep' then raise exception 'Metadata inconsistente o destruida'; end if;
 if not exists(select 1 from public.trainer_clients where trainer_id=other and client_id=me and display_name='Javier Charlez') then raise exception 'La cartera conserva nombre anterior'; end if;
 if not exists(select 1 from public.profiles where id=other and full_name='Otra persona') then raise exception 'Modifica otro perfil'; end if;
 if has_function_privilege('anon','public.update_my_profile_name(uuid,text)','execute')
  or has_schema_privilege('anon','profile_private','usage') then raise exception 'Edición anónima expuesta'; end if;
end $$;
select 'profile_name_editing: OK' as result;
rollback;
