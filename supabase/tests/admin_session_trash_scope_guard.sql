-- Mezcla real de ambos catálogos; todo el ensayo termina con ROLLBACK.
begin;
set local statement_timeout='45s';
do $$
declare administrator uuid:=gen_random_uuid();coach uuid:=gen_random_uuid();other uuid:=gen_random_uuid();
 official_a uuid;official_b uuid;private_a uuid;private_version uuid;private_b uuid;foreign_session uuid;exercise uuid;
 recipe jsonb;before_official jsonb;entry jsonb;admin_list jsonb;first_page jsonb;next_page jsonb;
 private_stamp timestamptz;first_position bigint;second_position bigint;
begin
 insert into auth.users(id,email) values(administrator,administrator||'@trash-scope.invalid'),(coach,coach||'@trash-scope.invalid'),(other,other||'@trash-scope.invalid');
 insert into auth.mfa_factors(id,user_id,factor_type,status,created_at,updated_at) values
  (gen_random_uuid(),administrator,'totp','verified',now(),now()),(gen_random_uuid(),coach,'totp','verified',now(),now()),(gen_random_uuid(),other,'totp','verified',now(),now());
 insert into public.admin_permissions(user_id) values(administrator);
 insert into public.trainer_access(trainer_id,enabled,client_limit,last_reason) values(coach,true,1,'Ensayo aislamiento'),(other,true,1,'Ensayo aislamiento');
 perform set_config('request.jwt.claim.sub',administrator::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',administrator,'role','authenticated','aal','aal2')::text,true);
 set local role authenticated;
 exercise:=public.create_admin_exercise('Ejercicio de aislamiento',p_muscle_groups=>array['piernas'],p_equipment=>array['ninguno']);
 recipe:=jsonb_build_object('name','Sesión de aislamiento','blocks',jsonb_build_array(jsonb_build_object('name','Fuerza','format','straight_sets','rounds',1,
  'exercises',jsonb_build_array(jsonb_build_object('exercise_id',exercise,'sets',jsonb_build_array(jsonb_build_object('target_reps',8,'rest_after_seconds',60)))))));
 official_a:=public.create_admin_workout_draft(null,recipe||jsonb_build_object('name','Oficial A'));
 official_b:=public.create_admin_workout_draft(null,recipe||jsonb_build_object('name','Oficial B'));
 perform public.trash_admin_session(official_a);
 perform public.trash_admin_session(official_b);
 select value into before_official from jsonb_array_elements(public.list_admin_session_trash()) where (value->>'id')::uuid=official_a;

 perform set_config('request.jwt.claim.sub',coach::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',coach,'role','authenticated','aal','aal2')::text,true);
 private_a:=public.save_trainer_workout(gen_random_uuid(),recipe||jsonb_build_object('name','Privada A'));
 private_version:=public.save_trainer_workout(gen_random_uuid(),recipe||jsonb_build_object('name','Privada A revisada'),private_a);
 private_b:=public.save_trainer_workout(gen_random_uuid(),recipe||jsonb_build_object('name','Privada B'));
 entry:=public.trash_trainer_catalog_item(gen_random_uuid(),'session',private_version);
 private_stamp:=(entry->>'trashed_at')::timestamptz;
 perform public.trash_trainer_catalog_item(gen_random_uuid(),'session',private_b);
 first_page:=public.list_trainer_catalog_trash('session',p_limit=>1);
 next_page:=public.list_trainer_catalog_trash('session',(first_page->0->>'trashed_at')::timestamptz,(first_page->0->>'id')::uuid,1);
 if jsonb_array_length(first_page)<>1 or jsonb_array_length(next_page)<>1
  or (first_page->0->>'id')::uuid<>private_b or (next_page->0->>'id')::uuid<>private_version then raise exception 'Cursor de familias privadas incorrecto';end if;
 if exists(select 1 from public.workout_templates where id in(private_a,private_version) and trashed_at is distinct from private_stamp)
  or not exists(select 1 from public.workout_templates where id=private_version and previous_version_id=private_a and version=2)
  or public.list_trainer_workouts()<>'[]'::jsonb then raise exception 'Se altera historia o catálogo activo privado';end if;

 perform set_config('request.jwt.claim.sub',other::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',other,'role','authenticated','aal','aal2')::text,true);
 foreign_session:=public.save_trainer_workout(gen_random_uuid(),recipe||jsonb_build_object('name','Privada de otro entrenador'));
 perform public.trash_trainer_catalog_item(gen_random_uuid(),'session',foreign_session);
 entry:=public.list_trainer_catalog_trash('session');
 if jsonb_array_length(entry)<>1 or (entry->0->>'id')::uuid<>foreign_session then raise exception 'El otro entrenador mezcla papeleras';end if;

 perform set_config('request.jwt.claim.sub',administrator::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',administrator,'role','authenticated','aal','aal2')::text,true);
 admin_list:=public.list_admin_session_trash();
 if exists(select 1 from jsonb_array_elements(admin_list) x where not exists(select 1 from public.workout_templates t
  where t.id=(x->>'id')::uuid and t.origin='system' and t.owner_user_id is null)) then raise exception 'ADMIN lista una receta privada';end if;
 if exists(select 1 from jsonb_array_elements(admin_list) x where (x->>'id')::uuid in(private_a,private_version,private_b,foreign_session)) then raise exception 'ADMIN revela IDs profesionales';end if;
 select value into entry from jsonb_array_elements(admin_list) where (value->>'id')::uuid=official_a;
 if entry is distinct from before_official or not entry ?& array['id','kind','name','trashed_at','revision','versions','work_count']
  or entry->'revision'<>'null'::jsonb or entry->>'kind'<>'session' then raise exception 'El contrato histórico ADMIN ha cambiado';end if;
 select ordinality into first_position from jsonb_array_elements(admin_list) with ordinality x(value,ordinality) where (value->>'id')::uuid=official_a;
 select ordinality into second_position from jsonb_array_elements(admin_list) with ordinality x(value,ordinality) where (value->>'id')::uuid=official_b;
 if first_position is null or second_position is null or second_position>=first_position then raise exception 'Se pierde el orden histórico por retirada';end if;
 begin perform public.restore_admin_session(private_version,private_stamp);raise exception 'ADMIN restaura una receta coach';exception when invalid_parameter_value then null;end;
 begin perform public.purge_admin_trash('session',private_version,private_stamp);raise exception 'ADMIN purga una receta coach';exception when serialization_failure then null;end;

 perform set_config('request.jwt.claim.sub',coach::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',coach,'role','authenticated','aal','aal2')::text,true);
 if public.list_trainer_catalog_trash('session',p_limit=>1)<>first_page
  or public.list_trainer_catalog_trash('session',(first_page->0->>'trashed_at')::timestamptz,(first_page->0->>'id')::uuid,1)<>next_page then
  raise exception 'ADMIN altera cursor o entradas de la familia profesional';end if;
 reset role;
end $$;
rollback;
