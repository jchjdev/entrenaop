begin;
set local statement_timeout='30s';
do $$
declare
 t uuid:=gen_random_uuid(); p uuid:=gen_random_uuid(); other uuid:=gen_random_uuid();
 r uuid:=gen_random_uuid(); r2 uuid:=gen_random_uuid(); foreign_message uuid:=gen_random_uuid(); m1 uuid:=gen_random_uuid(); m2 uuid:=gen_random_uuid(); mine uuid:=gen_random_uuid(); result jsonb;
begin
 insert into auth.users(id,email) values(t,t||'@inbox.invalid'),(p,p||'@inbox.invalid'),(other,other||'@inbox.invalid');
 insert into auth.mfa_factors(id,user_id,factor_type,status,created_at,updated_at) values
 (gen_random_uuid(),t,'totp','verified',now(),now()),(gen_random_uuid(),other,'totp','verified',now(),now());
 insert into public.admin_permissions(user_id) values(other);
 insert into public.trainer_client_relations(id,trainer_id,client_id,accepted_at) values(r,t,p,now()),(r2,other,p,now());
 insert into trainer_private.messages(id,relation_id,sender_id,body) values(m1,r,p,'Primera'),(mine,r,t,'Propio'),(foreign_message,r2,p,'Ajeno');
 perform set_config('request.jwt.claim.sub',t::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',t,'role','authenticated','aal','aal2')::text,true);
 set local role authenticated;
 result:=public.get_trainer_message_inbox(t);
 if (result->>'total_unread')::int<>1 or result->'conversations'->0->>'relation_id'<>r::text then raise exception 'Resumen incorrecto'; end if;
 if result::text like '%Primera%' then raise exception 'Resumen revela el cuerpo'; end if;
 begin perform public.read_trainer_messages(t,array[mine]); raise exception 'Lee propios'; exception when insufficient_privilege then null; end;
 begin perform public.get_trainer_message_inbox(other); raise exception 'Cambia titular'; exception when insufficient_privilege then null; end;
 begin perform 1 from trainer_private.message_reads; raise exception 'Tabla expuesta'; exception when insufficient_privilege then null; end;
 begin perform public.read_trainer_messages(t,array[m1,foreign_message]); raise exception 'Lote mixto admitido'; exception when insufficient_privilege then null; end;
 if (public.get_trainer_message_inbox(t)->>'total_unread')::int<>1 then raise exception 'Lote mixto escribe parcialmente'; end if;
 begin perform public.read_trainer_messages(t,array_fill(m1,array[51])); raise exception 'Lote excesivo admitido'; exception when invalid_parameter_value then null; end;
 if has_function_privilege('anon','public.get_trainer_message_inbox(uuid)','execute') or has_function_privilege('anon','public.read_trainer_messages(uuid,uuid[])','execute') then raise exception 'Acceso anónimo'; end if;
 perform public.read_trainer_messages(t,array[m1,m1]);
 perform public.read_trainer_messages(t,array[m1]);
 if (public.get_trainer_message_inbox(t)->>'total_unread')::int<>0 then raise exception 'Lectura no idempotente'; end if;
 reset role;
 -- Igual timestamp: la llegada posterior no puede quedar leída por un cursor.
 insert into trainer_private.messages(id,relation_id,sender_id,body) values(m2,r,p,'Segunda');
 set local role authenticated;
 if (public.get_trainer_message_inbox(t)->>'total_unread')::int<>1 then raise exception 'Absorbe llegada posterior'; end if;
 perform set_config('request.jwt.claims',jsonb_build_object('sub',t,'role','authenticated','aal','aal1')::text,true);
 begin perform public.get_trainer_message_inbox(t); raise exception 'Consulta sin MFA'; exception when insufficient_privilege then null; end;
 begin perform public.read_trainer_messages(t,array[m2]); raise exception 'Lectura sin MFA'; exception when insufficient_privilege then null; end;
 perform set_config('request.jwt.claim.sub',other::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',other,'role','authenticated','aal','aal2')::text,true);
 if (public.get_trainer_message_inbox(other)->>'total_unread')::int<>1 or public.get_trainer_message_inbox(other)->'conversations'->0->>'relation_id'<>r2::text then raise exception 'Otro preparador recibe etapa ajena'; end if;
 begin perform public.read_trainer_messages(other,array[m2]); raise exception 'ADMIN lee ajenos'; exception when insufficient_privilege then null; end;
 perform set_config('request.jwt.claim.sub',p::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',p,'role','authenticated','aal','aal1')::text,true);
 begin perform public.get_trainer_message_inbox(p); raise exception 'Alumno recibe bandeja'; exception when insufficient_privilege then null; end;
 reset role;
 update public.trainer_client_relations set ended_at=now(),ended_by=t where id=r;
 perform set_config('request.jwt.claim.sub',t::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',t,'role','authenticated','aal','aal2')::text,true);
 set local role authenticated;
 if (public.get_trainer_message_inbox(t)->>'total_unread')::int<>1 then raise exception 'Baja pierde avisos'; end if;
 perform public.read_trainer_messages(t,array[m2]);
 if (public.get_trainer_message_inbox(t)->>'total_unread')::int<>0 then raise exception 'No lee histórico'; end if;
 reset role;
end $$;
rollback;
