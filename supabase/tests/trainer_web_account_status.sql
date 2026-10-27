begin;
do $$
declare u uuid:=gen_random_uuid(); trainer uuid:=gen_random_uuid(); result jsonb;
begin
 insert into auth.users(id,email,email_confirmed_at,raw_user_meta_data) values
  (u,u||'@account-status.invalid',now(),'{"role":"admin","professional":true,"pro":true}'),
  (trainer,trainer||'@account-status.invalid',now(),'{}');
 insert into public.trainer_access(trainer_id,enabled,client_limit,last_reason) values(trainer,true,5,'Fixture de registro');
 perform set_config('request.jwt.claim.sub',u::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',u,'role','authenticated','aal','aal1')::text,true);
 set local role authenticated;
 result:=public.get_my_trainer_account_status(u);
 if result<>'{"enabled":false,"professional_account":false}'::jsonb then raise exception 'Registro concede permisos o revela datos'; end if;
 begin perform public.get_my_trainer_account_status(trainer);raise exception 'Lee otra cuenta';exception when insufficient_privilege then null;end;
 begin perform public.get_trainer_access();raise exception 'El alta evita MFA';exception when insufficient_privilege then null;end;
 if has_function_privilege('anon','public.get_my_trainer_account_status(uuid)','execute') then raise exception 'Abierto a anónimos';end if;
 reset role;
 insert into public.trainer_access(trainer_id,enabled,client_limit,last_reason) values(u,true,5,'Alta manual por ADMIN');
 set local role authenticated;
 result:=public.get_my_trainer_account_status(u);
 if result<>'{"enabled":true,"professional_account":true}'::jsonb then raise exception 'No detecta alta profesional';end if;
 begin perform public.get_trainer_access();raise exception 'Alta administrativa evita MFA';exception when insufficient_privilege then null;end;
 reset role;
 update public.trainer_access set enabled=false where trainer_id=u;
 set local role authenticated;
 if public.get_my_trainer_account_status(u)<>'{"enabled":false,"professional_account":true}'::jsonb then raise exception 'Baja pierde continuidad';end if;
 perform set_config('request.jwt.claims',jsonb_build_object('sub',u,'role','authenticated','aal','aal1','is_anonymous',true)::text,true);
 begin perform public.get_my_trainer_account_status(u);raise exception 'Admite sesión anónima';exception when insufficient_privilege then null;end;
 reset role;
 update auth.users set email_confirmed_at=null where id=u;
 perform set_config('request.jwt.claims',jsonb_build_object('sub',u,'role','authenticated','aal','aal1')::text,true);
 set local role authenticated;
 begin perform public.get_my_trainer_account_status(u);raise exception 'Admite correo sin confirmar';exception when insufficient_privilege then null;end;
 reset role;
end $$;
rollback;
