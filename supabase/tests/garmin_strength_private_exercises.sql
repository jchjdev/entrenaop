-- Datos sintéticos; la prueba no modifica cuentas ni deja planificaciones.
begin;
set local statement_timeout='60s';
do $$
declare trainer uuid:=gen_random_uuid(); other_trainer uuid:=gen_random_uuid(); pupil uuid:=gen_random_uuid();
 relation uuid:=gen_random_uuid(); ps uuid:=gen_random_uuid(); ts uuid:=gen_random_uuid();
 template uuid; scheduled uuid:=gen_random_uuid(); ex uuid; foreign_ex uuid; payload jsonb; preview jsonb; tampered jsonb;
begin
 insert into auth.users(id,email) values(trainer,trainer||'@private-strength.invalid'),
  (other_trainer,other_trainer||'@private-strength.invalid'),(pupil,pupil||'@private-strength.invalid');
 insert into auth.sessions(id,user_id,aal) values(ps,pupil,'aal1'),(ts,trainer,'aal2');
 insert into auth.mfa_factors(id,user_id,factor_type,status,created_at,updated_at)
  values(gen_random_uuid(),trainer,'totp','verified',now(),now());
 insert into public.trainer_access(trainer_id,enabled,client_limit,last_reason) values(trainer,true,5,'Fixture con ROLLBACK');
 insert into public.trainer_client_relations(id,trainer_id,client_id,accepted_at) values(relation,trainer,pupil,now());
 perform set_config('request.jwt.claim.sub',trainer::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',trainer,'role','authenticated','aal','aal2')::text,true);
 ex:=trainer_private.save_exercise(gen_random_uuid(),'{"name":"Isométrico privado","description":"Sin equivalencia de catálogo","muscle_groups":["core"],"equipment":[],"difficulty":"intermedio","exercise_type":"duración"}');
 insert into public.exercises(name,description,muscle_groups,equipment,difficulty,exercise_type,is_public,created_by,origin)
  values('Privado ajeno','No exportar',array['core'],array[]::text[],'intermedio','duración',false,other_trainer,'coach') returning id into foreign_ex;
 payload:=jsonb_build_object('name','Fuerza privada sintética','blocks',jsonb_build_array(jsonb_build_object(
  'name','Isométrico','format','straight_sets','rounds',1,'rest_after_seconds',0,'exercises',jsonb_build_array(jsonb_build_object(
  'exercise_id',ex,'sets',jsonb_build_array(jsonb_build_object('target_duration_seconds',5,'rest_after_seconds',0)))))));
 template:=trainer_private.save_trainer_workout(gen_random_uuid(),payload);
 perform trainer_private.assign_trainer_workout(scheduled,relation,template,current_date,null);
 if not device_private.device_training_template(template) then raise exception 'Rechaza ejercicio propio'; end if;
 preview:=device_private.training_source(pupil,pupil,scheduled);
 if preview->'snapshot'->>'sport'<>'strength'
  or preview->'snapshot'->'blocks'->0->'items'->0->>'exercise_name'<>'Isométrico privado'
  or preview->'snapshot'->'blocks'->0->'items'->0->'exercise_code' is distinct from 'null'::jsonb
  or (preview->'snapshot'->'blocks'->0->'items'->0->'sets'->0->>'target_duration_seconds')::integer<>5 then
  raise exception 'Pierde identidad, inventa equivalencia o cambia la dosis'; end if;
 if device_private.training_sync_target(pupil,scheduled)->>'mode'<>'sync' then raise exception 'No entra en el circuito común'; end if;
 -- La proyección interna tampoco acepta un ejercicio privado de otro autor.
 tampered:=jsonb_set(preview->'snapshot','{blocks,0,items,0,exercise_id}',to_jsonb(foreign_ex));
 begin
  perform device_private.strength_snapshot(tampered);
  raise exception 'Exporta un ejercicio privado ajeno';
 exception when invalid_parameter_value then null;
 end;
 tampered:=jsonb_set(preview->'snapshot','{blocks,0,format}','"superset"');
 begin
  perform device_private.strength_snapshot(tampered);
  raise exception 'Degrada una superserie a series convencionales';
 exception when invalid_parameter_value then null;
 end;
 if has_function_privilege('authenticated','device_private.strength_snapshot(jsonb)','EXECUTE')
  or has_function_privilege('service_role','device_private.strength_snapshot(jsonb)','EXECUTE')
  or has_function_privilege('anon','device_private.device_training_template(uuid)','EXECUTE') then
  raise exception 'Proyección privada expuesta'; end if;
end $$;
set constraints all immediate;
select 'garmin private strength contract passed' as result;
rollback;
