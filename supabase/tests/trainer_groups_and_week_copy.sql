begin;
set local statement_timeout='90s';
-- Error posterior a una primera entrega para acreditar rollback de toda la tanda.
create function pg_temp.reject_bulk_fixture() returns trigger language plpgsql as $$
begin
 if new.user_id::text=current_setting('entrenaop.test_fail_client',true) then raise invalid_parameter_value; end if;
 return new;
end $$;
create trigger reject_bulk_fixture before insert on public.scheduled_workouts for each row execute function pg_temp.reject_bulk_fixture();
do $$
declare trainer uuid:=gen_random_uuid(); pupil uuid:=gen_random_uuid(); second_pupil uuid:=gen_random_uuid(); outsider uuid:=gen_random_uuid();
 rel uuid:=gen_random_uuid(); rel2 uuid:=gen_random_uuid(); group_id uuid:=gen_random_uuid(); group_op uuid:=gen_random_uuid();
 batch_op uuid:=gen_random_uuid(); copy_op uuid:=gen_random_uuid(); late_op uuid:=gen_random_uuid();
 exercise uuid; template uuid; revised uuid; program uuid; source_id uuid; execution uuid; new_id uuid; personal uuid;
 recipe jsonb; content jsonb; recipients jsonb; entries jsonb; response jsonb; original_receipt jsonb; snapshot jsonb; refreshed jsonb; page jsonb; too_many jsonb;
 week_start date:=current_date-(extract(isodow from current_date)::integer-1); source_week date;
 fingerprint text; batch_fingerprint text; late_fingerprint text; revision bigint;
begin
 insert into auth.users(id,email) values(trainer,trainer||'@trainer-groups.invalid'),(pupil,pupil||'@trainer-groups.invalid'),
  (second_pupil,second_pupil||'@trainer-groups.invalid'),(outsider,outsider||'@trainer-groups.invalid');
 insert into auth.mfa_factors(id,user_id,factor_type,status,created_at,updated_at) values
  (gen_random_uuid(),trainer,'totp','verified',now(),now()),(gen_random_uuid(),outsider,'totp','verified',now(),now());
 insert into public.admin_permissions(user_id) values(outsider);
 insert into public.trainer_access(trainer_id,enabled,client_limit,last_reason) values(trainer,true,2,'Fixture grupos');
 insert into public.trainer_client_relations(id,trainer_id,client_id,accepted_at) values(rel,trainer,pupil,now()),(rel2,trainer,second_pupil,now());
 select id into exercise from public.exercises where is_public and id<>'20000000-0000-4000-8000-000000000004' order by id limit 1;
 recipe:=jsonb_build_object('name','Sesión de grupo','blocks',jsonb_build_array(jsonb_build_object('name','Fuerza','format','straight_sets','rounds',1,'rest_after_seconds',0,
  'exercises',jsonb_build_array(jsonb_build_object('exercise_id',exercise,'sets',jsonb_build_array(jsonb_build_object('target_reps',8,'rest_after_seconds',60)))))));
 recipients:=jsonb_build_array(jsonb_build_object('client_id',pupil,'relation_id',rel),jsonb_build_object('client_id',second_pupil,'relation_id',rel2));
 perform set_config('request.jwt.claim.sub',trainer::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',trainer,'role','authenticated','aal','aal2')::text,true);
 set local role authenticated;
 template:=public.save_trainer_workout(gen_random_uuid(),recipe);
 response:=public.save_trainer_group(group_op,group_id,0,'Convocatoria de ensayo',array[pupil,second_pupil]);
 if (response->>'revision')::bigint<>1 or public.save_trainer_group(group_op,group_id,0,'Convocatoria de ensayo',array[pupil,second_pupil])<>response then raise exception 'Grupo no idempotente'; end if;
 page:=public.list_trainer_groups();
 if jsonb_array_length(page)<>1 or jsonb_array_length(page->0->'members')<>2 then raise exception 'Lista de grupos/membresía incorrecta'; end if;
 begin perform public.save_trainer_group(gen_random_uuid(),gen_random_uuid(),0,'Ajeno',array[outsider]); raise exception 'Grupo admite cuenta fuera de cartera'; exception when insufficient_privilege then null; end;
 begin perform public.save_trainer_group(gen_random_uuid(),group_id,0,'Revisión vieja',array[pupil]); raise exception 'Grupo admite revisión vieja'; exception when serialization_failure then null; end;
 begin perform public.list_trainer_groups(now(),null); raise exception 'Cursor de grupo parcial'; exception when invalid_parameter_value then null; end;
 response:=public.preview_trainer_batch(recipients,p_template_id=>template,p_date=>week_start+1,p_group_id=>group_id,p_group_revision=>1);
 batch_fingerprint:=response->>'fingerprint';
 if (response->>'assignment_count')::integer<>2 or jsonb_array_length(response->'preview')<>2 then raise exception 'Preview de grupo incorrecta'; end if;
 original_receipt:=public.deliver_trainer_batch_reviewed(batch_op,recipients,batch_fingerprint,p_template_id=>template,p_date=>week_start+1,p_group_id=>group_id,p_group_revision=>1);
 if (original_receipt->>'assignment_count')::integer<>2 or jsonb_array_length(original_receipt->'recipients')<>2 then raise exception 'Entrega grupal incompleta'; end if;
 if public.deliver_trainer_batch_reviewed(batch_op,recipients,batch_fingerprint,p_template_id=>template,p_date=>week_start+1,p_group_id=>group_id,p_group_revision=>1)<>original_receipt then raise exception 'Duplica envío grupal'; end if;
 perform public.save_trainer_group(gen_random_uuid(),group_id,1,'Grupo reducido',array[pupil]);
 begin perform public.deliver_trainer_batch_reviewed(gen_random_uuid(),recipients,batch_fingerprint,p_template_id=>template,p_date=>week_start+2,p_group_id=>group_id,p_group_revision=>1);
  raise exception 'Expande grupo tras cambiar sus miembros'; exception when serialization_failure then null; end;
 if public.deliver_trainer_batch_reviewed(batch_op,recipients,batch_fingerprint,p_template_id=>template,p_date=>week_start+1,p_group_id=>group_id,p_group_revision=>1)<>original_receipt then raise exception 'Cambiar grupo invalida recibo ya confirmado'; end if;
 begin perform public.preview_trainer_batch(recipients,p_template_id=>template,p_date=>week_start+2,p_group_id=>group_id,p_group_revision=>2);
  raise exception 'Destinatarios distintos a los miembros revisados'; exception when serialization_failure then null; end;

 -- Un fallo tardío revierte las dos entregas y su recibo; el mismo UUID puede
 -- reintentarse después de resolver el fallo, sin duplicados parciales.
 late_fingerprint:=public.preview_trainer_batch(recipients,p_template_id=>template,p_date=>week_start+90)->>'fingerprint';
 perform set_config('entrenaop.test_fail_client',greatest(pupil,second_pupil)::text,true);
 begin perform public.deliver_trainer_batch_reviewed(late_op,recipients,late_fingerprint,p_template_id=>template,p_date=>week_start+90);
  raise exception 'Entrega parcial admitida'; exception when invalid_parameter_value then null; end;
 perform set_config('entrenaop.test_fail_client','',true);
 if jsonb_array_length(public.list_trainer_agenda(week_start+90,week_start+90))<>0 then raise exception 'Fallo tardío dejó citas'; end if;
 response:=public.deliver_trainer_batch_reviewed(late_op,recipients,late_fingerprint,p_template_id=>template,p_date=>week_start+90);
 if (response->>'assignment_count')::integer<>2 then raise exception 'No recupera orden fallida'; end if;
 begin perform public.deliver_trainer_batch_reviewed(late_op,recipients,late_fingerprint,p_template_id=>template,p_date=>week_start+91);
  raise exception 'Reutiliza orden para otro día'; exception when invalid_parameter_value then null; end;
 select jsonb_agg(recipients->0) into too_many from generate_series(1,101);
 begin perform public.preview_trainer_batch(too_many,p_template_id=>template,p_date=>week_start+2);
  raise exception 'Más de cien destinatarios'; exception when invalid_parameter_value then null; end;

 content:=jsonb_build_object('name','Programa de grupo','mode','phased','phases',jsonb_build_array(jsonb_build_object('name','Base','duration_weeks',1,'instructions','Revisar resultados',
  'sessions',jsonb_build_array(jsonb_build_object('template_id',template,'name','Fuerza')))));
 program:=public.save_trainer_program(gen_random_uuid(),content);
 entries:=jsonb_build_array(jsonb_build_object('phase',0,'session',0,'date',week_start+14),jsonb_build_object('phase',0,'session',0,'date',week_start+16));
 batch_fingerprint:=public.preview_trainer_batch(recipients,p_program_id=>program,p_entries=>entries)->>'fingerprint';
 response:=public.deliver_trainer_batch_reviewed(gen_random_uuid(),recipients,batch_fingerprint,p_program_id=>program,p_entries=>entries);
 if (response->>'assignment_count')::integer<>4 or jsonb_array_length(response->'recipients'->0->'assignment_ids')<>2
  or response->'recipients'->0->>'program_delivery_id' is null then raise exception 'Programa no entrega recibo por alumno'; end if;
 select jsonb_agg(jsonb_build_object('phase',0,'session',0,'date',week_start+i)) into too_many from generate_series(1,129) i;
 begin perform public.preview_trainer_batch(recipients,p_program_id=>program,p_entries=>too_many);
  raise exception 'Más de 256 citas totales'; exception when invalid_parameter_value then null; end;

 -- Ciento una pautas: se copia la semana completa, no la primera página visible.
 source_week:=week_start+28;
 for i in 1..101 loop perform public.assign_trainer_workout(gen_random_uuid(),rel,template,source_week+(i%7),'Original '||i); end loop;
 revised:=public.save_trainer_workout(gen_random_uuid(),jsonb_set(recipe,'{name}','"Biblioteca revisada"'),template);
 perform set_config('request.jwt.claim.sub',pupil::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',pupil,'role','authenticated','aal','aal1')::text,true);
 personal:=public.create_personal_workout_template(jsonb_set(recipe,'{name}','"Secreto de destino"'));
 perform public.schedule_workout(personal,source_week+7);
 perform set_config('request.jwt.claim.sub',trainer::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',trainer,'role','authenticated','aal','aal2')::text,true);
 snapshot:=public.preview_trainer_week(source_week,7);
 if jsonb_array_length(snapshot->'items')<>101 or (snapshot->>'excluded_count')::integer<>0 then raise exception 'Preview copia solo página visible'; end if;
 if not exists(select 1 from jsonb_array_elements(snapshot->'items') e where (e->>'has_date_coincidence')::boolean)
  or snapshot::text like '%Secreto de destino%' then raise exception 'Coincidencia ausente o revela receta personal'; end if;
 fingerprint:=snapshot->>'fingerprint'; source_id:=(snapshot->'items'->0->>'id')::uuid;
 response:=public.copy_trainer_week(copy_op,source_week,7,fingerprint);
 if (response->>'assignment_count')::integer<>101 then raise exception 'Copia no abarca semana completa'; end if;
 new_id:=(response->'assignments'->0->>'assignment_id')::uuid;
 if public.get_trainer_assignment(new_id)->>'template_id'<>template::text then raise exception 'Copia no conserva receta retirada fijada'; end if;
 if public.get_trainer_assignment(source_id)->>'scheduled_date'<>snapshot->'items'->0->>'date' then raise exception 'Copia mueve original'; end if;
 if public.copy_trainer_week(copy_op,source_week,7,fingerprint)<>response then raise exception 'Copia duplicada al reintentar'; end if;
 if public.preview_trainer_week(source_week,7)->>'fingerprint'=fingerprint then raise exception 'Cambios de coincidencias no invalidan huella'; end if;
 begin perform public.copy_trainer_week(copy_op,source_week,14,fingerprint); raise exception 'Reintento cambia copia'; exception when invalid_parameter_value then null; end;
 begin perform public.preview_trainer_week(source_week,0); raise exception 'Copia sobre semana original'; exception when invalid_parameter_value then null; end;
 begin perform public.preview_trainer_week(source_week,1); raise exception 'Copia desplaza días de semana'; exception when invalid_parameter_value then null; end;
 begin perform public.preview_trainer_week(source_week+1,7); raise exception 'Origen no empieza en lunes'; exception when invalid_parameter_value then null; end;
 refreshed:=public.preview_trainer_week(source_week,14);

 reset role;
 update public.trainer_access set enabled=false where trainer_id=trainer;
 set local role authenticated;
 begin perform public.preview_trainer_batch(recipients,p_template_id=>revised,p_date=>week_start+2);
  raise exception 'Acceso deshabilitado previsualiza agenda ajena en lote'; exception when insufficient_privilege then null; end;
 begin perform public.preview_trainer_week(source_week,14);
  raise exception 'Acceso deshabilitado previsualiza coincidencias para copia'; exception when insufficient_privilege then null; end;
 if jsonb_array_length(public.list_trainer_groups())<>1
  or public.get_trainer_assignment(source_id)->>'id'<>source_id::text then
  raise exception 'Deshabilitar acceso elimina grupos o pautas propias'; end if;
 reset role;
 update public.trainer_access set enabled=true where trainer_id=trainer;
 set local role authenticated;

 perform set_config('request.jwt.claim.sub',pupil::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',pupil,'role','authenticated','aal','aal1')::text,true);
 execution:=public.start_scheduled_workout(source_id);
 begin perform public.list_trainer_groups(); raise exception 'Alumno lee grupos'; exception when insufficient_privilege then null; end;
 perform set_config('request.jwt.claim.sub',trainer::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',trainer,'role','authenticated','aal','aal2')::text,true);
 begin perform public.copy_trainer_week(gen_random_uuid(),source_week,14,refreshed->>'fingerprint'); raise exception 'Copia tras inicio sin revisar'; exception when serialization_failure then null; end;
 if public.copy_trainer_week(copy_op,source_week,7,fingerprint)<>response then raise exception 'Inicio invalida recibo original confirmado'; end if;
 refreshed:=public.preview_trainer_week(source_week,14);
 if jsonb_array_length(refreshed->'items')<>100 or (refreshed->>'excluded_count')::integer<>1 then raise exception 'No explica exclusión de iniciada'; end if;
 perform public.end_trainer_relation(rel);
 begin perform public.copy_trainer_week(gen_random_uuid(),source_week,14,refreshed->>'fingerprint'); raise exception 'Copia con vínculo cambiado'; exception when serialization_failure then null; end;
 refreshed:=public.preview_trainer_week(source_week,14);
 if jsonb_array_length(refreshed->'items')<>0 then raise exception 'Baja conserva pendientes copiables'; end if;
 begin perform public.copy_trainer_week(gen_random_uuid(),source_week,14,refreshed->>'fingerprint'); raise exception 'Copia vacía se confirma'; exception when invalid_parameter_value then null; end;
 if jsonb_array_length(public.list_trainer_agenda(source_week+14,source_week+20))<>0 then raise exception 'Rechazo deja copia parcial'; end if;

 perform set_config('request.jwt.claims',jsonb_build_object('sub',trainer,'role','authenticated','aal','aal1')::text,true);
 begin perform public.list_trainer_groups(); raise exception 'Grupos sin MFA'; exception when insufficient_privilege then null; end;
 begin perform public.preview_trainer_week(source_week,7); raise exception 'Copia sin MFA'; exception when insufficient_privilege then null; end;
 perform set_config('request.jwt.claim.sub',outsider::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',outsider,'role','authenticated','aal','aal2')::text,true);
 if jsonb_array_length(public.list_trainer_groups())<>0 then raise exception 'ADMIN ve grupos ajenos'; end if;
 begin perform public.preview_trainer_week(source_week,7); raise exception 'ADMIN sin acceso profesional previsualiza coincidencias'; exception when insufficient_privilege then null; end;
 begin perform public.preview_trainer_batch(recipients,p_template_id=>revised,p_date=>week_start+2); raise exception 'ADMIN previsualiza destinatarios ajenos'; exception when insufficient_privilege then null; end;
 begin perform 1 from trainer_private.group_members; raise exception 'Tabla de miembros expuesta'; exception when insufficient_privilege then null; end;
 if has_function_privilege('anon','public.copy_trainer_week(uuid,date,integer,text)','EXECUTE')
  or has_function_privilege('authenticated','trainer_private.prepare_batch(jsonb,uuid,date,uuid,jsonb,text,uuid,bigint)','EXECUTE') then raise exception 'Helper o anon expuesto'; end if;
 reset role;
end $$;
select 'trainer_groups_and_week_copy: OK' as result;
rollback;
