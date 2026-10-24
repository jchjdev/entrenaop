begin;
set local statement_timeout='90s';
do $$
declare owner uuid:=gen_random_uuid();other uuid:=gen_random_uuid();exercise uuid;op uuid:=gen_random_uuid();receipt jsonb;
begin
 insert into auth.users(id,email) values(owner,owner||'@labels.invalid'),(other,other||'@labels.invalid');
 insert into auth.mfa_factors(id,user_id,factor_type,status,created_at,updated_at)
  values(gen_random_uuid(),owner,'totp','verified',now(),now()),(gen_random_uuid(),other,'totp','verified',now(),now());
 insert into public.admin_permissions(user_id) values(owner);
 insert into public.trainer_access(trainer_id,enabled,client_limit,last_reason) values(owner,true,1,'Etiquetas'),(other,true,1,'Aislamiento');
 select id into strict exercise from public.exercises where is_public order by id limit 1;
 perform set_config('request.jwt.claim.sub',owner::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',owner,'role','authenticated','aal','aal2')::text,true);
 set local role authenticated;
 receipt:=public.set_editor_exercise_labels(auth.uid(),'trainer_private',op,exercise,array['Técnica','Iniciación'],0);
 if public.set_editor_exercise_labels(auth.uid(),'trainer_private',op,exercise,array['Técnica','Iniciación'],0) is distinct from receipt then raise exception 'Duplica respuesta perdida';end if;
 begin perform public.set_editor_exercise_labels(auth.uid(),'trainer_private',op,exercise,array['Otra'],0);raise exception 'Reutiliza operación con otra intención';exception when invalid_parameter_value then null;end;
 begin perform public.set_editor_exercise_labels(auth.uid(),'trainer_private',gen_random_uuid(),exercise,array['Otra'],0);raise exception 'Pisa revisión concurrente';exception when serialization_failure then null;end;
 if public.get_editor_exercise_labels(auth.uid(),'admin_official')<>'[]'::jsonb then raise exception 'Mezcla contextos de una cuenta';end if;
 perform public.set_editor_exercise_labels(auth.uid(),'admin_official',gen_random_uuid(),exercise,array['Editorial'],0);
 begin perform public.set_editor_exercise_labels(auth.uid(),'trainer_private',gen_random_uuid(),exercise,array['Técnica','técnica'],1);raise exception 'Duplica etiquetas';exception when invalid_parameter_value then null;end;
 begin perform public.set_editor_exercise_labels(auth.uid(),'trainer_private',gen_random_uuid(),exercise,array['mal,formato'],1);raise exception 'Acepta separador ambiguo';exception when invalid_parameter_value then null;end;
 begin perform public.set_editor_exercise_labels(auth.uid(),'trainer_private',gen_random_uuid(),exercise,array[null::text],1);raise exception 'Acepta null';exception when invalid_parameter_value then null;end;
 begin perform public.set_editor_exercise_labels(auth.uid(),'trainer_private',gen_random_uuid(),exercise,array[['dos','dimensiones']],1);raise exception 'Acepta array no plano';exception when invalid_parameter_value then null;end;
 begin perform public.set_editor_exercise_labels(auth.uid(),'trainer_private',gen_random_uuid(),exercise,array_fill('X'::text,array[9]),1);raise exception 'Supera ocho';exception when invalid_parameter_value then null;end;
 perform public.set_editor_exercise_labels(auth.uid(),'trainer_private',gen_random_uuid(),exercise,'{}',1);
 if public.get_editor_exercise_labels(auth.uid(),'trainer_private')->0->>'revision' is distinct from '2' then raise exception 'Borrar etiquetas reinicia CAS';end if;
 perform set_config('request.jwt.claim.sub',other::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',other,'role','authenticated','aal','aal2')::text,true);
 if public.get_editor_exercise_labels(auth.uid(),'trainer_private')<>'[]'::jsonb then raise exception 'Filtra etiquetas ajenas';end if;
 begin perform public.get_editor_exercise_labels(owner,'trainer_private');raise exception 'La cuenta B consulta como A';exception when insufficient_privilege then null;end;
 begin perform public.set_editor_exercise_labels(owner,'trainer_private',gen_random_uuid(),exercise,array['Cambio de cuenta'],0);raise exception 'La cuenta B escribe como A';exception when insufficient_privilege then null;end;
 begin perform public.get_editor_exercise_labels(auth.uid(),'admin_official');raise exception 'Concede ADMIN al entrenador';exception when insufficient_privilege then null;end;
 begin perform count(*) from editor_private.exercise_labels;raise exception 'Permite lectura directa';exception when insufficient_privilege then null;end;
 reset role;
 insert into editor_private.exercise_preference_owners(user_id,context) values(other,'trainer_private');
 insert into editor_private.exercise_labels(user_id,context,exercise_id)
  select other,'trainer_private',gen_random_uuid() from generate_series(1,5000);
 set local role authenticated;
 begin perform public.set_editor_exercise_labels(auth.uid(),'trainer_private',gen_random_uuid(),exercise,array['Límite'],0);raise exception 'Supera el presupuesto de etiquetas';exception when program_limit_exceeded then null;end;
 perform set_config('request.jwt.claims',jsonb_build_object('sub',other,'role','authenticated','aal','aal1')::text,true);
 begin perform public.get_editor_exercise_labels(auth.uid(),'trainer_private');raise exception 'Lee sin MFA';exception when insufficient_privilege then null;end;
 reset role;
 if has_function_privilege('anon','public.get_editor_exercise_labels(uuid,text)','execute') then raise exception 'Lectura anónima';end if;
end $$;
select 'editor_private_exercise_labels: OK' as result;
rollback;
