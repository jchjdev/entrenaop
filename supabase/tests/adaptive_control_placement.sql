begin;
select set_config('request.jwt.claim.sub',(select user_id::text from public.admin_permissions limit 1),true);
-- Aislamos la colocación: la decisión por evidencia y su lectura real tienen
-- cobertura independiente. Esta sustitución vive únicamente en el ROLLBACK.
create or replace function public.adaptive_control_candidates_v1(goal uuid,wk date,plan jsonb) returns jsonb
language sql stable security definer set search_path='' as $$
 select current_setting('entrenaop.control_placement_fixture')::jsonb
$$;
do $$ declare g uuid; wk date:=current_date-extract(isodow from current_date)::int+1;
 p jsonb; control jsonb; plan jsonb; actual jsonb; friday jsonb; course jsonb; plank jsonb; manual_template uuid; manual_session uuid;
begin
 insert into public.preparation_goals(user_id,program_id,target_date) values(auth.uid(),'fas_periodic_assessment',wk+60) returning id into g;
 course:=jsonb_build_object('reference_id',gen_random_uuid(),'objective_key','course','name','Circuito','optional',false,'model','course',
  'body_regions','["lower_body"]'::jsonb,'dose','{"task":{"measurement":"TIME_FOR_COURSE","target_value":14},"targets":[14,14],"rest_seconds":90}'::jsonb);
 plank:='{"reference_id":"plank","objective_key":"plank","name":"Plancha","optional":false,"body_regions":["trunk"],"dose":{"task":{"measurement":"DURATION","target_value":30},"targets":[30,30],"rest_seconds":75}}';
 control:=jsonb_build_object('objective_key','course','name','Circuito','reference_id',course->>'reference_id','profile','slalom_ball_course_16m',
  'measurement','TIME_FOR_COURSE','body_regions','["lower_body"]'::jsonb,'phase','specific','baseline_work',28,
  'task','{"exercise_code":"slalom_ball_course_16m","exercise_version":1,"protocol_key":"fixture","protocol_version":1,"setup_key":"standard:fixture","measurement":"TIME_FOR_COURSE","load_mode":"bodyweight","target_value":14,"intent":"practice"}'::jsonb,
  'decision','{"action":"control","reason":"phase_transfer","question":"Comprobar el recorrido."}'::jsonb);
 perform set_config('entrenaop.control_placement_fixture',jsonb_build_array(control)::text,true);
 plan:=jsonb_build_object('status','ready','already_published',false,'proposals','[]'::jsonb,
  'availability','{"1":60,"5":60}'::jsonb,'sessions',jsonb_build_array(
   jsonb_build_object('date',wk,'minutes',7,'standalone_minutes',14,'combined',true,'shared_total_minutes',37,'session_order','performance_first','work',jsonb_build_array(course)),
   jsonb_build_object('date',wk+4,'minutes',10,'standalone_minutes',14,'combined',true,'shared_total_minutes',40,'session_order','running_first','work',jsonb_build_array(plank))),
  'running',jsonb_build_object('sessions',jsonb_build_array(
    public.running_session_v1('T',0,595,30)||jsonb_build_object('date',wk),
    public.running_session_v1('E',0,595,30)||jsonb_build_object('date',wk+4))));
 actual:=public.apply_adaptive_protocol_controls_v1(g,wk,plan);
 if actual->'control_schedule'->'scheduled'->0->>'date'<>(wk+4)::text then raise exception 'No mueve el control fuera del día de calidad: %',actual; end if;
 select value into friday from jsonb_array_elements(actual->'sessions') s where (s->>'date')::date=wk+4;
 if friday->>'session_order'<>'performance_first' or friday->>'warm_up_seconds'<>'420'
  or (friday->>'minutes')::int+30<>(friday->>'shared_total_minutes')::int
  or public.preparation_shared_minutes_v2(friday,plan->'running'->'sessions'->1)<>(friday->>'shared_total_minutes')::int then
  raise exception 'Conserva un ahorro de calentamiento o una duración compartida incorrectos: %',friday; end if;
 if not exists(select 1 from jsonb_array_elements(friday->'work') w where w->>'objective_key'='plank') then raise exception 'Retira tronco al evaluar piernas sin esa demanda'; end if;
 if (friday->>'shared_total_minutes')::int>60 or jsonb_array_length(actual->'running'->'sessions')<>2 then raise exception 'Supera tiempo o duplica carrera'; end if;
 insert into public.workout_templates(name,origin,owner_user_id,visibility,status)
  values('Actividad manual de la fixture','user',auth.uid(),'private','published') returning id into manual_template;
 insert into public.scheduled_workouts(user_id,template_id,template_name,template_version,estimated_duration_minutes,scheduled_date,source,status)
  values(auth.uid(),manual_template,'Actividad manual',1,40,wk+5,'user','planned') returning id into manual_session;
 actual:=public.apply_adaptive_protocol_controls_v1(g,wk,plan);
 if jsonb_array_length(actual->'control_schedule'->'scheduled')<>0 then raise exception 'Ignora una carga manual futura adyacente al test'; end if;
 update public.scheduled_workouts set status='cancelled' where id=manual_session;
 actual:=public.apply_adaptive_protocol_controls_v1(g,wk,jsonb_set(plan,'{running,mode}','"global_deload"'));
 if jsonb_array_length(actual->'control_schedule'->'scheduled')<>0 or actual->'sessions'<>plan->'sessions'
  or actual->'running'->'sessions'<>plan->'running'->'sessions' then raise exception 'Añade un máximo durante recuperación global o modifica trabajo normal'; end if;
 actual:=public.apply_adaptive_protocol_controls_v1(g,wk,jsonb_set(plan,'{running,data_review_required}','true'));
 if actual->'control_schedule'->>'reason'<>'shared_recovery' then raise exception 'Programa un máximo con datos dudosos'; end if;
 -- V5 puede marcar n<frecuencia tras sustituir una salida por un test conocido.
 -- Eso no equivale a desconocer qué se hizo ni a fatiga del deportista.
 actual:=public.apply_adaptive_protocol_controls_v1(g,wk,
  jsonb_set(jsonb_set(plan,'{running,data_review_required}','true'),'{running,evidence}',
   jsonb_build_object('observations',jsonb_build_array(jsonb_build_object('date',wk-2,'signal','{"status":"tolerated"}'::jsonb)))));
 if jsonb_array_length(actual->'control_schedule'->'scheduled')<>1 then raise exception 'Un control conocido se interpreta como información perdida'; end if;
 update public.preparation_goals set target_date=wk+16 where id=g;
 actual:=public.apply_adaptive_protocol_controls_v1(g,wk,plan);
 if jsonb_array_length(actual->'control_schedule'->'scheduled')<>0 then raise exception 'Solo mira la fecha del lunes y pauta un máximo dentro de los últimos 14 días'; end if;
end $$;
select 'Colocación de control, separación de calidad, recuperación por región y coste compartido: OK' result;
rollback;
