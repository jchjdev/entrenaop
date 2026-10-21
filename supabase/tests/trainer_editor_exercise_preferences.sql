begin;
set local statement_timeout='60s';
do $$
declare owner uuid:=gen_random_uuid();other uuid:=gen_random_uuid();pupil uuid:=gen_random_uuid();exercise uuid;own_exercise uuid;revised uuid;foreign_exercise uuid;
 favorite_op uuid:=gen_random_uuid();selection_op uuid:=gen_random_uuid();admin_op uuid:=gen_random_uuid();recency_op uuid:=gen_random_uuid();removed uuid:=gen_random_uuid();
 draft jsonb;entry jsonb;receipt jsonb;selected jsonb;snapshot jsonb;oldest jsonb;newest jsonb;other_public uuid;candidate record;
begin
 insert into auth.users(id,email) values(owner,owner||'@editor-preferences.invalid'),(other,other||'@editor-preferences.invalid'),(pupil,pupil||'@editor-preferences.invalid');
 insert into auth.mfa_factors(id,user_id,factor_type,status,created_at,updated_at) values
  (gen_random_uuid(),owner,'totp','verified',now(),now()),(gen_random_uuid(),other,'totp','verified',now(),now()),(gen_random_uuid(),pupil,'totp','verified',now(),now());
 insert into public.admin_permissions(user_id) values(owner),(other);
 insert into public.trainer_access(trainer_id,enabled,client_limit,last_reason) values(owner,true,1,'Fixture preferencias'),(other,true,1,'Aislamiento preferencias');
 select id into exercise from public.exercises where is_public and id<>'20000000-0000-4000-8000-000000000004' order by id limit 1;
 select id into other_public from public.exercises where is_public and id<>exercise and id<>'20000000-0000-4000-8000-000000000004' order by id limit 1;
 if exercise is null or other_public is null then raise exception 'Se requieren dos ejercicios públicos';end if;
 draft:=jsonb_build_object('name','Ejercicio propio de preferencias','description','Controla la bajada','video_url',null,
  'muscle_groups',jsonb_build_array('espalda'),'equipment',jsonb_build_array('barra'),'difficulty','intermedio','exercise_type','repeticiones','image_path',null);
 perform set_config('request.jwt.claim.sub',other::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',other,'role','authenticated','aal','aal2')::text,true);
 set local role authenticated;
 foreign_exercise:=public.save_trainer_exercise(gen_random_uuid(),draft);
 perform set_config('request.jwt.claim.sub',owner::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',owner,'role','authenticated','aal','aal2')::text,true);
 own_exercise:=public.save_trainer_exercise(gen_random_uuid(),draft);
 snapshot:=public.get_editor_exercise_preferences('trainer_private');
 if snapshot<>'{"entries":[],"recent_limit":20,"favorite_limit":500}'::jsonb then raise exception 'Snapshot inicial no es vacío y acotado';end if;
 receipt:=public.set_editor_exercise_favorite(favorite_op,'trainer_private',exercise,true,0);
 if receipt->>'exercise_id'<>exercise::text or receipt->>'favorite'<>'true' or (receipt->>'favorite_revision')::bigint<>1 or receipt->'last_selected_at'<>'null'::jsonb then raise exception 'CAS inicial incorrecto';end if;
 if public.set_editor_exercise_favorite(favorite_op,'trainer_private',exercise,true,0)<>receipt then raise exception 'Reintento no recupera recibo';end if;
 begin perform public.set_editor_exercise_favorite(favorite_op,'trainer_private',exercise,false,0);raise exception 'Orden cambia contenido';exception when invalid_parameter_value then null;end;
 begin perform public.record_editor_exercise_selection(favorite_op,'trainer_private',exercise);raise exception 'Orden favorita reutilizada como selección';exception when invalid_parameter_value then null;end;
 begin perform public.set_editor_exercise_favorite(gen_random_uuid(),'trainer_private',exercise,false,0);raise exception 'CAS obsoleto aceptado';exception when serialization_failure then null;end;
 selected:=public.record_editor_exercise_selection(selection_op,'trainer_private',exercise);
 if selected->>'favorite'<>'true' or (selected->>'favorite_revision')::bigint<>1 or selected->'last_selected_at'='null'::jsonb then raise exception 'Seleccionar cambia favorito o no fija instante';end if;
 entry:=public.set_editor_exercise_favorite(gen_random_uuid(),'trainer_private',exercise,false,1);
 if entry->'last_selected_at'<>selected->'last_selected_at' or (entry->>'favorite_revision')::bigint<>2 then raise exception 'Favorito pisa selección';end if;
 if public.record_editor_exercise_selection(selection_op,'trainer_private',exercise)<>selected then raise exception 'Selección reintentada no conserva recibo';end if;
 entry:=public.record_editor_exercise_selection(gen_random_uuid(),'trainer_private',exercise);
 if entry->>'favorite'<>'false' or (entry->>'favorite_revision')::bigint<>2 then raise exception 'Reintento viejo reinicia favorito';end if;
 entry:=public.set_editor_exercise_favorite(admin_op,'admin_official',exercise,true,0);
 if (entry->>'favorite_revision')::bigint<>1 then raise exception 'Contextos comparten CAS';end if;
 snapshot:=public.get_editor_exercise_preferences('admin_official');
 if jsonb_array_length(snapshot->'entries')<>1 or snapshot->'entries'->0->>'favorite'<>'true' then raise exception 'Snapshot admin incorrecto';end if;
 begin perform public.set_editor_exercise_favorite(gen_random_uuid(),'admin_official',own_exercise,true,0);raise exception 'ADMIN usa privado como catálogo oficial';exception when insufficient_privilege then null;end;
 begin perform public.set_editor_exercise_favorite(gen_random_uuid(),'trainer_private',foreign_exercise,true,0);raise exception 'ADMIN amplía permiso al privado de otro';exception when insufficient_privilege then null;end;
 begin perform public.record_editor_exercise_selection(gen_random_uuid(),'trainer_private',gen_random_uuid());raise exception 'UUID ajeno crea preferencia';exception when insufficient_privilege then null;end;
 begin perform public.get_editor_exercise_preference('trainer_private',foreign_exercise);raise exception 'Lookup revela preferencia privada ajena';exception when insufficient_privilege then null;end;
 if public.get_editor_exercise_preference('trainer_private',other_public)<>
  jsonb_build_object('exercise_id',other_public,'favorite',false,'favorite_revision',0,'last_selected_at',null) then raise exception 'Lookup inicial no es canónico';end if;
 begin perform public.record_editor_exercise_selection(gen_random_uuid(),'trainer_private','20000000-0000-4000-8000-000000000004');raise exception 'Referencia running entra en selector';exception when insufficient_privilege then null;end;
 begin perform public.get_editor_exercise_preferences('inventado');raise exception 'Contexto libre aceptado';exception when invalid_parameter_value then null;end;

 -- La preferencia pertenece al ID concreto. Revisar no la traslada ni permite
 -- seleccionar otra vez la versión retirada desde el selector general.
 perform public.set_editor_exercise_favorite(gen_random_uuid(),'trainer_private',own_exercise,true,0);
 revised:=public.save_trainer_exercise(gen_random_uuid(),jsonb_set(draft,'{name}','"Versión nueva"'),own_exercise);
 snapshot:=public.get_editor_exercise_preferences('trainer_private');
 if exists(select 1 from jsonb_array_elements(snapshot->'entries') p where p->>'exercise_id' in(own_exercise::text,revised::text)) then raise exception 'Traslada favorito o expone versión retirada';end if;
 begin perform public.record_editor_exercise_selection(gen_random_uuid(),'trainer_private',own_exercise);raise exception 'Selecciona versión retirada';exception when insufficient_privilege then null;end;
 entry:=public.set_editor_exercise_favorite(gen_random_uuid(),'trainer_private',own_exercise,false,1);
 if entry->>'favorite'<>'false' or (entry->>'favorite_revision')::bigint<>2 then raise exception 'No permite desmarcar referencia propia retirada';end if;
 -- Sin FK a ejercicios se conserva el CAS de una referencia ya retirada del
 -- catálogo; ni siquiera su ID aparece en el snapshot autorizado.
 reset role;
 insert into editor_private.exercise_preferences(user_id,context,exercise_id,favorite,favorite_revision) values(owner,'trainer_private',removed,true,7);
 set local role authenticated;
 snapshot:=public.get_editor_exercise_preferences('trainer_private');
 if exists(select 1 from jsonb_array_elements(snapshot->'entries') p where p->>'exercise_id'=removed::text) then raise exception 'Expone ID retirado del catálogo';end if;
 entry:=public.set_editor_exercise_favorite(gen_random_uuid(),'trainer_private',removed,false,7);
 if (entry->>'favorite_revision')::bigint<>8 then raise exception 'Referencia retirada reinicia CAS';end if;

 -- Veintiuna selecciones públicas distintas dejan solo veinte timestamps,
 -- sin borrar favoritos, CAS ni recibos. Usa el catálogo real de Dev.
 oldest:=public.record_editor_exercise_selection(recency_op,'trainer_private',exercise);
 for candidate in select id from public.exercises where is_public and id<>exercise and id<>'20000000-0000-4000-8000-000000000004' order by id limit 20 loop
  newest:=public.record_editor_exercise_selection(gen_random_uuid(),'trainer_private',candidate.id);
 end loop;
 snapshot:=public.get_editor_exercise_preferences('trainer_private');
 if (select count(*) from jsonb_array_elements(snapshot->'entries') p where p->'last_selected_at'<>'null'::jsonb)<>20 then raise exception 'Recientes no respeta veinte';end if;
 if public.record_editor_exercise_selection(recency_op,'trainer_private',exercise)<>oldest then raise exception 'Evicción altera recibo confirmado';end if;
 reset role;
 if (select last_selected_at from editor_private.exercise_preferences where user_id=owner and context='trainer_private' and exercise_id=exercise) is not null then raise exception 'Reintento reinserta selección evictada';end if;
 if (select favorite_revision from editor_private.exercise_preferences where user_id=owner and context='trainer_private' and exercise_id=exercise)<>2 then raise exception 'Evicción reinicia CAS';end if;
 set local role authenticated;
 snapshot:=public.get_editor_exercise_preferences('trainer_private');
 if exists(select 1 from jsonb_array_elements(snapshot->'entries') p where p->>'exercise_id'=exercise::text) then raise exception 'Snapshot disperso conserva tombstone sin favorito/recencia';end if;
 entry:=public.get_editor_exercise_preference('trainer_private',exercise);
 if (entry->>'favorite_revision')::bigint<>2 or entry->>'favorite'<>'false' then raise exception 'Lookup pierde CAS de tombstone';end if;
 begin perform public.set_editor_exercise_favorite(gen_random_uuid(),'trainer_private',exercise,true,0);raise exception 'CAS sparse reinicia desde0';exception when serialization_failure then null;end;
 entry:=public.set_editor_exercise_favorite(gen_random_uuid(),'trainer_private',exercise,true,(entry->>'favorite_revision')::bigint);
 if (entry->>'favorite_revision')::bigint<>3 then raise exception 'Preflight no recupera CAS para nuevoeditor';end if;
 perform public.set_editor_exercise_favorite(gen_random_uuid(),'trainer_private',exercise,false,3);
 reset role;
 -- Los retirados conservados también ocupan el límite técnico de favoritos.
 insert into editor_private.exercise_preferences(user_id,context,exercise_id,favorite,favorite_revision)
  select owner,'trainer_private',gen_random_uuid(),true,1 from generate_series(1,500);
 set local role authenticated;
 begin perform public.set_editor_exercise_favorite(gen_random_uuid(),'trainer_private',other_public,true,0);raise exception 'Supera500favoritos';exception when program_limit_exceeded then null;when serialization_failure then
  -- Puede haber sido seleccionado entre los veinte; seleccionar no altera CAS.
  raise exception 'Selección cambió CAS antes de agotar cuota';end;
 if public.set_editor_exercise_favorite(favorite_op,'trainer_private',exercise,true,0)<>receipt then raise exception 'Cuota rompe recibo confirmado';end if;

 perform set_config('request.jwt.claim.sub',other::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',other,'role','authenticated','aal','aal2')::text,true);
 if jsonb_array_length(public.get_editor_exercise_preferences('trainer_private')->'entries')<>0
  or jsonb_array_length(public.get_editor_exercise_preferences('admin_official')->'entries')<>0 then raise exception 'Cruza preferencias entre usuarios';end if;
 perform set_config('request.jwt.claim.sub',pupil::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',pupil,'role','authenticated','aal','aal2')::text,true);
 begin perform public.get_editor_exercise_preferences('trainer_private');raise exception 'Alumno recibe contexto profesional';exception when insufficient_privilege then null;end;
 begin perform public.get_editor_exercise_preferences('admin_official');raise exception 'Alumno recibe contexto editorial';exception when insufficient_privilege then null;end;
 perform set_config('request.jwt.claim.sub',owner::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',owner,'role','authenticated','aal','aal1')::text,true);
 begin perform public.get_editor_exercise_preferences('trainer_private');raise exception 'Lee sin MFA';exception when insufficient_privilege then null;end;
 begin perform public.set_editor_exercise_favorite(gen_random_uuid(),'admin_official',exercise,false,1);raise exception 'Escribe sin MFA';exception when insufficient_privilege then null;end;
 reset role;
 update public.trainer_access set enabled=false where trainer_id=owner;
 perform set_config('request.jwt.claims',jsonb_build_object('sub',owner,'role','authenticated','aal','aal2')::text,true);
 set local role authenticated;
 if jsonb_array_length(public.get_editor_exercise_preferences('trainer_private')->'entries')=0 then raise exception 'Desactivar borra consulta propia';end if;
 begin perform public.record_editor_exercise_selection(gen_random_uuid(),'trainer_private',exercise);raise exception 'Acceso inactivo crea selección';exception when insufficient_privilege then null;end;
 begin perform 1 from editor_private.exercise_preferences;raise exception 'Tabla privada accesible';exception when insufficient_privilege then null;end;
 reset role;
 if has_function_privilege('authenticated','editor_private.lock_owner(text)','EXECUTE')
  or has_function_privilege('authenticated','editor_private.can_select_exercise(text,uuid)','EXECUTE')
  or has_function_privilege('anon','public.get_editor_exercise_preferences(text)','EXECUTE') then raise exception 'Helpers o anon expuestos';end if;
end $$;
select 'trainer_editor_exercise_preferences: OK' as result;
rollback;
