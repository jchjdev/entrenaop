begin;
set local statement_timeout='60s';
-- Búsqueda fuera de la primera página, sin datos ni avisos persistentes.
do $$
declare
 coach uuid:=gen_random_uuid();other uuid:=gen_random_uuid();athlete uuid:=gen_random_uuid();relation uuid:=gen_random_uuid();
 exercise uuid;other_exercise uuid;w uuid;p uuid;variant uuid;assignment uuid:=gen_random_uuid();
 workouts uuid[]:='{}';program_ids uuid[]:='{}';recipe jsonb;content jsonb;page jsonb;next_page jsonb;cursor_row jsonb;answer jsonb;
 i int;total int;stamp timestamptz:=clock_timestamp();
begin
 insert into auth.users(id,email) values(coach,coach||'@library-search.invalid'),(other,other||'@library-search.invalid'),(athlete,athlete||'@library-search.invalid');
 insert into auth.mfa_factors(id,user_id,factor_type,status,created_at,updated_at)
 select gen_random_uuid(),u,'totp','verified',now(),now() from unnest(array[coach,other]) u;
 insert into public.trainer_access(trainer_id,enabled,client_limit,last_reason) values(coach,true,1,'Contrato de búsqueda'),(other,true,1,'Contrato de aislamiento');
 insert into public.trainer_client_relations(id,trainer_id,client_id) values(relation,coach,athlete);
 perform set_config('request.jwt.claim.sub',coach::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',coach,'role','authenticated','aal','aal2')::text,true);
 set local role authenticated;
 exercise:=public.save_trainer_exercise(gen_random_uuid(),' {"name":"Dominadas únicas","muscle_groups":["espalda"],"equipment":["barra"],"difficulty":"intermedio","exercise_type":"repeticiones"}');
 recipe:=jsonb_build_object('name','Serie','blocks',jsonb_build_array(jsonb_build_object('name','Bloque técnico','format','straight_sets','rounds',1,'rest_after_seconds',0,
  'exercises',jsonb_build_array(jsonb_build_object('exercise_id',exercise,'sets',jsonb_build_array(jsonb_build_object('target_reps',8,'rest_after_seconds',60)))))));
 for i in 1..61 loop
  w:=public.save_trainer_workout(gen_random_uuid(),jsonb_set(recipe,'{name}',to_jsonb(case when i=1 then 'Fuerza ágil 100%' else 'Serie '||i end)));
  workouts:=array_append(workouts,w);
  content:=jsonb_build_object('name',case when i=1 then 'Preparación ágil 100%' else 'Programa '||i end,'mode','phased','phases',jsonb_build_array(jsonb_build_object(
   'name','Base técnica','duration_weeks',1,'instructions','Dosis de ensayo','sessions',jsonb_build_array(jsonb_build_object('template_id',w,'name','Dominadas del programa')))));
  p:=public.save_trainer_program(gen_random_uuid(),content);program_ids:=array_append(program_ids,p);
 end loop;
 reset role;
 for i in 1..61 loop
  update public.workout_templates set created_at=stamp+make_interval(secs=>i) where id=workouts[i];
  update trainer_private.programs set created_at=stamp+make_interval(secs=>i) where id=program_ids[i];
 end loop;
 set local role authenticated;
 if exists(select 1 from jsonb_array_elements(public.list_trainer_workouts()) e where e->>'id'=workouts[1]::text) then raise exception 'Fixture no está fuera de la primera página';end if;
 answer:=public.search_trainer_workouts('AGIL 100%');
 if jsonb_array_length(answer)<>1 or answer->0->>'id'<>workouts[1]::text then raise exception 'No encuentra sesión antigua por tildes y términos literales';end if;
 answer:=public.search_trainer_programs('AGIL 100%');
 if jsonb_array_length(answer)<>1 or answer->0->>'id'<>program_ids[1]::text then raise exception 'No encuentra programa antiguo';end if;
 if jsonb_array_length(public.search_trainer_workouts('___'))<>0 or jsonb_array_length(public.search_trainer_programs('___'))<>0 then raise exception 'Interpreta comodines';end if;
 if jsonb_array_length(public.search_trainer_workouts('',true))<>0 then raise exception 'Clasifica fuerza como carrera';end if;
 if jsonb_array_length(public.search_trainer_workouts('',false,'amrap'))<>0 then raise exception 'Ignora formato';end if;
 page:=public.search_trainer_workouts('TECNICO DOMINADAS series convencionales',false,'straight_sets');
 if jsonb_array_length(page)<>50 then raise exception 'No busca dentro de bloques/ejercicios/formato';end if;
 cursor_row:=page->49;
 next_page:=public.search_trainer_workouts('TECNICO DOMINADAS',false,'straight_sets',(cursor_row->>'created_at')::timestamptz,(cursor_row->>'id')::uuid);
 if jsonb_array_length(next_page)<>11 or exists(select 1 from jsonb_array_elements(page) a join jsonb_array_elements(next_page) b on a->>'id'=b->>'id') then raise exception 'Cursor de sesiones incompleto o repetido';end if;
 page:=public.search_trainer_programs('base tecnica dominadas');cursor_row:=page->49;
 next_page:=public.search_trainer_programs('base tecnica dominadas',(cursor_row->>'created_at')::timestamptz,(cursor_row->>'id')::uuid);
 if jsonb_array_length(page)<>50 or jsonb_array_length(next_page)<>11 then raise exception 'No pagina los programas después de filtrar su contenido';end if;
 begin perform public.search_trainer_workouts('x',null,null,now(),null);raise exception 'Admite cursor parcial';exception when invalid_parameter_value then null;end;
 begin perform public.search_trainer_programs(repeat('a',513));raise exception 'Admite búsqueda desmedida';exception when invalid_parameter_value then null;end;
 perform public.assign_trainer_workout(assignment,relation,workouts[1],current_date,null);
 answer:=public.preview_trainer_assignment_change(assignment,0,current_date,null,jsonb_set(recipe,'{name}','"Variante oculta"'));
 answer:=public.change_trainer_assignment_reviewed(gen_random_uuid(),assignment,0,current_date,null,answer->>'fingerprint',jsonb_set(recipe,'{name}','"Variante oculta"'));
 variant:=(answer->>'template_id')::uuid;
 if jsonb_array_length(public.search_trainer_workouts('Variante oculta'))<>0 then raise exception 'Publica adaptación individual en la biblioteca';end if;
 perform public.trash_trainer_catalog_item(gen_random_uuid(),'session',workouts[1]);
 perform public.trash_trainer_catalog_item(gen_random_uuid(),'program',program_ids[1]);
 if jsonb_array_length(public.search_trainer_workouts('AGIL 100%'))<>0 or jsonb_array_length(public.search_trainer_programs('AGIL 100%'))<>0 then raise exception 'Devuelve papelera';end if;
 perform set_config('request.jwt.claim.sub',other::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',other,'role','authenticated','aal','aal2')::text,true);
 if public.search_trainer_workouts('DOMINADAS')<>'[]'::jsonb or public.search_trainer_programs('DOMINADAS')<>'[]'::jsonb then raise exception 'Filtra contenido de otra cuenta';end if;
 -- También una cuenta con factor inscrito necesita una sesión aal2 real.
 perform set_config('request.jwt.claims',jsonb_build_object('sub',coach,'role','authenticated','aal','aal1')::text,true);
 begin perform public.search_trainer_workouts('');raise exception 'Admite MFA pendiente';exception when insufficient_privilege then null;end;
 begin perform public.search_trainer_programs('');raise exception 'Admite MFA pendiente';exception when insufficient_privilege then null;end;
 reset role;
 if has_function_privilege('anon','public.search_trainer_workouts(text,boolean,text,timestamptz,uuid)','EXECUTE') or has_function_privilege('anon','public.search_trainer_programs(text,timestamptz,uuid)','EXECUTE') then raise exception 'Admite acceso anónimo';end if;
end $$;
select 'trainer_library_search: OK' as result;
rollback;
