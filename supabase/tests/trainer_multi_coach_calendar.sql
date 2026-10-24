-- Datos sintéticos y contratos reales. Nunca deja vínculos ni consentimiento.
begin;
set local statement_timeout='60s';
do $$
declare
 a uuid:=gen_random_uuid(); b uuid:=gen_random_uuid(); c uuid:=gen_random_uuid();
 x uuid:=gen_random_uuid(); y uuid:=gen_random_uuid(); z uuid:=gen_random_uuid();
 ra uuid; rb uuid; ry uuid:=gen_random_uuid(); rz uuid:=gen_random_uuid();
 ca text:=encode(extensions.gen_random_bytes(32),'hex'); cb text:=encode(extensions.gen_random_bytes(32),'hex');
 cc text:=encode(extensions.gen_random_bytes(32),'hex'); duplicate text:=encode(extensions.gen_random_bytes(32),'hex');
 exercise uuid; ta uuid; tb uuid; sa uuid:=gen_random_uuid(); sb uuid:=gen_random_uuid(); sy uuid:=gen_random_uuid();
 payload jsonb; j jsonb; recipe jsonb; rev bigint;
begin
 update public.trainer_access_settings set manual_access_enabled=true,max_active_trainers_per_client=2 where singleton;
 insert into auth.users(id,email) values(a,a||'@multi.invalid'),(b,b||'@multi.invalid'),(c,c||'@multi.invalid'),
  (x,x||'@multi.invalid'),(y,y||'@multi.invalid'),(z,z||'@multi.invalid');
 update public.profiles set full_name=case id when a then 'Preparador A' when b then 'Preparador B' else 'Alumno sintético' end where id in(a,b,c,x,y,z);
 insert into auth.mfa_factors(id,user_id,factor_type,status,created_at,updated_at)
  values(gen_random_uuid(),a,'totp','verified',now(),now()),(gen_random_uuid(),b,'totp','verified',now(),now()),(gen_random_uuid(),c,'totp','verified',now(),now());
 insert into public.trainer_access(trainer_id,enabled,client_limit,last_reason)
  values(a,true,5,'Contrato varios preparadores'),(b,true,5,'Contrato varios preparadores'),(c,true,5,'Contrato varios preparadores');
 insert into public.trainer_client_relations(id,trainer_id,client_id) values(ry,a,y),(rz,b,z);
 select id into strict exercise from public.exercises where is_public order by id limit 1;
 payload:=jsonb_build_object('name','Fuerza A','blocks',jsonb_build_array(jsonb_build_object(
  'name','Principal','format','straight_sets','rounds',1,'rest_after_seconds',0,
  'exercises',jsonb_build_array(jsonb_build_object('exercise_id',exercise,'sets',jsonb_build_array(jsonb_build_object('target_reps',10,'rest_after_seconds',60)))))));
 perform set_config('request.jwt.claim.sub',a::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',a,'role','authenticated','aal','aal2')::text,true);
 set local role authenticated;
 perform public.create_trainer_invitation(gen_random_uuid(),ca);
 perform public.create_trainer_invitation(gen_random_uuid(),duplicate);
 ta:=public.save_trainer_workout(gen_random_uuid(),payload);
 perform public.assign_trainer_workout(sy,ry,ta,current_date,'Solo para Y');
 perform set_config('request.jwt.claim.sub',b::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',b,'role','authenticated','aal','aal2')::text,true);
 perform public.create_trainer_invitation(gen_random_uuid(),cb);
 exercise:=public.save_trainer_exercise(gen_random_uuid(),'{"name":"Ejercicio privado B","description":"Descripción privada no compartida","muscle_groups":["espalda"],"equipment":["barra"],"difficulty":"intermedio","exercise_type":"repeticiones"}');
 payload:=jsonb_set(payload,'{blocks,0,exercises,0,exercise_id}',to_jsonb(exercise));
 tb:=public.save_trainer_workout(gen_random_uuid(),jsonb_set(payload,'{name}','"Carrera B"'));
 perform set_config('request.jwt.claim.sub',c::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',c,'role','authenticated','aal','aal2')::text,true);
 perform public.create_trainer_invitation(gen_random_uuid(),cc);
 perform set_config('request.jwt.claim.sub',x::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',x,'role','authenticated','aal','aal1')::text,true);
 ra:=public.accept_trainer_invitation(ca); rb:=public.accept_trainer_invitation(cb);
 if public.accept_trainer_invitation(ca)<>ra then raise exception 'Reintento no idempotente'; end if;
 if jsonb_array_length(public.list_my_trainer_relations(false))<>2 then raise exception 'No muestra ambos preparadores'; end if;
 begin perform public.accept_trainer_invitation(duplicate); raise exception 'Duplica pareja activa'; exception when unique_violation then null; end;
 begin perform public.accept_trainer_invitation(cc); raise exception 'Excede dos preparadores'; exception when check_violation then null; end;
 j:=public.get_my_trainer_calendar_sharing(x);
 if (j->>'enabled')::boolean or (j->>'active_trainers')::int<>2 then raise exception 'Compartición implícita'; end if;
 begin perform public.set_my_trainer_calendar_sharing(y,true,0); raise exception 'Concede por otro alumno'; exception when insufficient_privilege then null; end;
 perform set_config('request.jwt.claim.sub',a::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',a,'role','authenticated','aal','aal2')::text,true);
 if (public.get_trainer_access()->>'active_clients')::int<>2 then raise exception 'Cupo A incorrecto'; end if;
 perform public.assign_trainer_workout(sa,ra,ta,current_date,'Nota al alumno A');
 perform public.send_trainer_message(gen_random_uuid(),ra,'Privado A');
 if (public.get_trainer_shared_calendar(a,x,current_date,current_date)->>'shared')::boolean then raise exception 'Lee sin consentimiento'; end if;
 begin perform public.get_trainer_shared_workout(a,x,sa); raise exception 'Lee pauta sin consentimiento'; exception when insufficient_privilege then null; end;
 begin perform public.set_my_trainer_calendar_sharing(x,true,0); raise exception 'Coach concede consentimiento'; exception when insufficient_privilege then null; end;
 perform set_config('request.jwt.claim.sub',b::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',b,'role','authenticated','aal','aal2')::text,true);
 perform public.assign_trainer_workout(sb,rb,tb,current_date,'Nota al alumno B');
 perform public.send_trainer_message(gen_random_uuid(),rb,'Privado B');
 if (public.get_trainer_access()->>'active_clients')::int<>2 then raise exception 'Cupo B incorrecto'; end if;
 perform set_config('request.jwt.claim.sub',x::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',x,'role','authenticated','aal','aal1')::text,true);
 j:=public.set_my_trainer_calendar_sharing(x,true,0); rev:=(j->>'revision')::bigint;
 if not (j->>'enabled')::boolean then raise exception 'No activa consentimiento'; end if;
 if public.set_my_trainer_calendar_sharing(x,true,0)<>j then raise exception 'Reintento modifica consentimiento'; end if;
 j:=public.get_my_trainer_notices(x);
 if jsonb_array_length(j#>'{resources,conversations}')<>2 or j#>>'{resources,conversation_relation_id}' is not null then raise exception 'Elige conversación arbitraria'; end if;
 j:=public.get_my_schedule_coaches(x,array[sa,sb,sy]);
 if jsonb_array_length(j)<>2 or j::text not like '%Preparador A%' or j::text not like '%Preparador B%' then raise exception 'Autoría no acotada al alumno'; end if;
 perform set_config('request.jwt.claim.sub',a::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',a,'role','authenticated','aal','aal2')::text,true);
 j:=public.get_trainer_shared_calendar(a,x,current_date,current_date);
 if not (j->>'shared')::boolean or jsonb_array_length(j->'items')<>2 or jsonb_array_length(j->'coaches')<>2 then raise exception 'Calendario incompleto'; end if;
 if j::text like '%'||sy::text||'%' or j::text like '%Nota al alumno%' then raise exception 'Filtra ajenos o campos no permitidos'; end if;
 recipe:=public.get_trainer_shared_workout(a,x,sb);
 if recipe->>'name'<>'Carrera B' or jsonb_array_length(recipe->'workout_blocks')<>1 then raise exception 'No permite cotejar pauta'; end if;
 if recipe::text like '%video_url%' or recipe::text like '%image_url%' then raise exception 'Comparte medios'; end if;
 if recipe::text not like '%Ejercicio privado B%' or recipe::text like '%Descripción privada%' then raise exception 'Detalle privado de ejercicio incorrecto'; end if;
 if exists(select 1 from public.exercises where id=exercise) then raise exception 'Abre ejercicio privado ajeno'; end if;
 if exists(select 1 from public.workout_templates where id=tb) or exists(select 1 from public.trainer_assignments where scheduled_id=sb)
  or exists(select 1 from public.trainer_client_relations where id=rz) then raise exception 'Amplía RLS o carteras'; end if;
 begin perform public.get_trainer_shared_calendar(a,z,current_date,current_date); raise exception 'Accede a alumno ajeno'; exception when insufficient_privilege then null; end;
 begin perform public.get_trainer_shared_workout(a,x,sy); raise exception 'Pauta no pertenece al alumno seleccionado'; exception when insufficient_privilege then null; end;
 begin perform public.get_trainer_shared_calendar(b,x,current_date,current_date); raise exception 'Suplanta identidad'; exception when insufficient_privilege then null; end;
 perform set_config('request.jwt.claims',jsonb_build_object('sub',a,'role','authenticated','aal','aal1')::text,true);
 begin perform public.get_trainer_shared_calendar(a,x,current_date,current_date); raise exception 'Lee sin MFA'; exception when insufficient_privilege then null; end;
 reset role;
 update public.trainer_access set enabled=false where trainer_id=a;
 perform set_config('request.jwt.claims',jsonb_build_object('sub',a,'role','authenticated','aal','aal2')::text,true);
 set local role authenticated;
 begin perform public.get_trainer_shared_calendar(a,x,current_date,current_date); raise exception 'Lee sin acceso profesional'; exception when insufficient_privilege then null; end;
 reset role; update public.trainer_access set enabled=true where trainer_id=a;
 perform set_config('request.jwt.claim.sub',x::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',x,'role','authenticated','aal','aal1')::text,true);
 set local role authenticated;
 perform public.set_my_trainer_calendar_sharing(x,false,rev);
 perform set_config('request.jwt.claim.sub',b::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',b,'role','authenticated','aal','aal2')::text,true);
 if (public.get_trainer_shared_calendar(b,x,current_date,current_date)->>'shared')::boolean then raise exception 'Ignora revocación'; end if;
 perform set_config('request.jwt.claim.sub',x::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',x,'role','authenticated','aal','aal1')::text,true);
 perform public.set_my_trainer_calendar_sharing(x,true,rev+1);
 perform public.end_trainer_relation(ra);
 perform set_config('request.jwt.claim.sub',a::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',a,'role','authenticated','aal','aal2')::text,true);
 begin perform public.get_trainer_shared_calendar(a,x,current_date,current_date); raise exception 'Lee tras finalizar vínculo'; exception when insufficient_privilege then null; end;
 perform set_config('request.jwt.claim.sub',b::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',b,'role','authenticated','aal','aal2')::text,true);
 if not (public.get_trainer_shared_calendar(b,x,current_date,current_date)->>'shared')::boolean then raise exception 'Finalizar A afecta B'; end if;
 reset role;
 -- Citas sintéticas de un mismo día fuerzan paginación por ID, sin perderlas
 -- al coincidir fechas. No se crean ejecuciones ni resultados ficticios.
 insert into public.scheduled_workouts(id,user_id,template_id,template_name,template_version,scheduled_date,source,status)
  select gen_random_uuid(),x,tb,'Pauta sintética',1,current_date,'coach','planned' from generate_series(1,51);
 set local role authenticated;
 j:=public.get_trainer_shared_calendar(b,x,current_date,current_date);
 if jsonb_array_length(j->'items')<>50 or not (j->>'has_more')::boolean then raise exception 'Primera página incorrecta'; end if;
 recipe:=public.get_trainer_shared_calendar(b,x,current_date,current_date,
  (j#>>'{items,49,scheduled_date}')::date,(j#>>'{items,49,id}')::uuid);
 if jsonb_array_length(recipe->'items')<>3 or (recipe->>'has_more')::boolean then raise exception 'Cursor pierde citas con fecha repetida'; end if;
 if exists(select 1 from jsonb_array_elements(j->'items') p join jsonb_array_elements(recipe->'items') q on p->>'id'=q->>'id') then raise exception 'Cursor repite citas'; end if;
 perform set_config('request.jwt.claim.sub',x::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',x,'role','authenticated','aal','aal1')::text,true);
 perform public.end_trainer_relation(rb);
 if (public.get_my_trainer_calendar_sharing(x)->>'enabled')::boolean then raise exception 'Consentimiento heredado sin destinatarios'; end if;
 reset role;
 if has_function_privilege('authenticated','trainer_private.shared_calendar_access(uuid,uuid)','execute') then raise exception 'Helper expuesto'; end if;
 if exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public'
   and p.proname in('get_my_trainer_calendar_sharing','set_my_trainer_calendar_sharing','get_trainer_shared_calendar','get_trainer_shared_workout','get_my_schedule_coaches') and p.prosecdef) then raise exception 'Wrapper definer público'; end if;
end $$;
rollback;
