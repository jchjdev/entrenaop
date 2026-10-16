begin;
select set_config('request.jwt.claim.sub',(select user_id::text from public.admin_permissions limit 1),true);
do $$
declare g uuid; rid uuid; main jsonb; candidate jsonb; all_proposals jsonb; task jsonb; observed jsonb;
 t uuid; b uuid; i uuid; ex uuid; execution uuid; es uuid; old_user uuid:=auth.uid(); wk date:=current_date+8-extract(isodow from current_date)::int;
 before_count int; result jsonb; again jsonb; placement jsonb; old_ref jsonb; other_goal uuid; known uuid;
begin
 insert into public.preparation_goals(user_id,program_id,target_date)
 values(auth.uid(),'fas_periodic_assessment',current_date+120) returning id into g;
 perform public.save_performance_context('{"1":60,"3":60,"5":60}',array['bench','barbell','plates'],false,true);
 rid:=public.save_performance_reference(g,jsonb_build_object('goal_code','push_up_standard','goal_version',1,
  'goal_measurement','REPS','reference_kind','performed_set','observed_on',current_date,'current_capacity_confirmed',true,
  'targets','[12]'::jsonb,'reported_rir',3,'frequency',1,
  'task','{"exercise_code":"push_up_standard","exercise_version":1,"protocol_key":"fixture","protocol_version":1,"setup_key":"standard:fixture","measurement":"REPS","load_mode":"bodyweight","target_value":12,"intent":"work"}'::jsonb));
 main:=jsonb_build_object('status','ready','reference_id',rid,'objective_key','push_up_standard:REPS',
  'role','specific','exercise_code','push_up_standard','phase','development','frequency',1,'outcome','maintain',
  'model','repetitions','body_regions','["upper_body"]'::jsonb,'movement_patterns','["horizontal_push"]'::jsonb,
  'dose','{"targets":[6,6],"rest_seconds":90,"task":{"exercise_code":"push_up_standard","measurement":"REPS","load_mode":"bodyweight"}}'::jsonb);
 select count(*) into before_count from public.performance_training_references where preparation_goal_id=g;
 all_proposals:=public.performance_support_candidates_v1(g,wk,jsonb_build_array(main));
 select value into candidate from jsonb_array_elements(all_proposals) p where p->>'support_entry'='guided';
 if candidate is null or candidate->>'exercise_code'<>'bench_press_barbell' then raise exception 'No elige apoyo desde material: %',all_proposals; end if;
 if (select count(*) from public.performance_training_references where preparation_goal_id=g)<>before_count then raise exception 'Calcular escribe referencias'; end if;
 again:=public.performance_support_candidates_v1(g,wk,jsonb_build_array(main));
 if again is distinct from all_proposals then raise exception 'La misma entrada produce otra selección'; end if;
 task:=candidate->'dose'->'task';
 if task ? 'external_load_kg' or not public.valid_performance_prescription(task) then raise exception 'Inventa kilos o no admite práctica sin carga: %',task; end if;
 if not public.valid_performance_prescription(task||'{"target_value":8.0,"target_rir":3.0,"protocol_version":1.0}') then
  raise exception 'La serialización numérica de Flutter cambia la identidad de la práctica'; end if;
 if public.valid_performance_prescription(task||'{"policy_version":"performance_v3"}')
   or public.valid_performance_prescription(task||'{"measurement":"MAX_LOAD"}')
   or public.valid_performance_prescription(task||'{"external_load_kg":0}') then raise exception 'Relaja carga ordinaria o máxima'; end if;
 if public.performance_work_seconds_v2(candidate->'dose')<>360 then raise exception 'No reserva preparación y familiarización'; end if;
 if jsonb_array_length(public.performance_select_v4(all_proposals))<>2 then raise exception 'No selecciona primera práctica junto al principal'; end if;
 -- El apoyo no vuelve obligatoria una preparación: si solo cabe el principal,
 -- se retira y conserva su cobertura, sin pasarse del tiempo declarado.
 placement:=public.performance_place_v4(public.performance_select_v4(all_proposals)||'[]'::jsonb,
   '{"1":14}','[]','[]',0,wk,wk+120);
 if exists(select 1 from jsonb_each(placement->'days') d where (d.value->>'minutes')::int>14) then raise exception 'Desborda la sesión'; end if;
 if (select count(*) from jsonb_each(placement->'days') d,jsonb_array_elements(d.value->'work') w)<>1
  or exists(select 1 from jsonb_each(placement->'days') d,jsonb_array_elements(d.value->'work') w where w->>'support_entry'='guided') then
  raise exception 'El apoyo desplaza al principal con poco tiempo'; end if;
 if jsonb_array_length(public.performance_support_candidates_v1(g,wk,jsonb_build_array(main||'{"phase":"base"}')))<>1
  or jsonb_array_length(public.performance_support_candidates_v1(g,wk,jsonb_build_array(main||'{"phase":"specific"}')))<>1
  or jsonb_array_length(public.performance_support_candidates_v1(g,wk,jsonb_build_array(main||'{"outcome":"reduce"}')))<>1 then
  raise exception 'Añade novedad en fase o respuesta incompatible'; end if;
 perform public.save_performance_context('{"1":60}','{}',false,true);
 if jsonb_array_length(public.performance_support_candidates_v1(g,wk,jsonb_build_array(main)))<>1 then raise exception 'Ignora material'; end if;
 perform public.save_performance_context('{"1":60,"3":60,"5":60}',array['bench','barbell','plates'],false,true);
 perform public.persist_automatic_support_v1(g,candidate);
 if not exists(select 1 from public.performance_training_references where id=(candidate->>'reference_id')::uuid
   and reference->>'reference_kind'='guided_pending' and reference->>'observed_on' is null) then raise exception 'Confunde práctica pendiente con capacidad'; end if;
 if exists(select 1 from jsonb_array_elements(public.get_preparation_training_setup(g)->'references') reference_row
   where reference_row->'reference'->>'reference_kind'='guided_pending') then raise exception 'Presenta práctica pendiente como marca medida'; end if;
 -- Registro real con el mismo ejecutor/RPC que utiliza la app.
 insert into public.workout_templates(name,origin,owner_user_id,visibility,status,version)
 values('Primera práctica de apoyo','user',auth.uid(),'private','published',1) returning id into t;
 insert into public.workout_blocks(template_id,order_index,name,format) values(t,0,'Primera práctica','straight_sets') returning id into b;
 select id into ex from public.exercises where training_profile_code='bench_press_barbell' and training_profile_version=1 and is_public limit 1;
 insert into public.workout_items(block_id,exercise_id,order_index) values(b,ex,0) returning id into i;
 insert into public.workout_sets(item_id,order_index,performance_prescription) values(i,0,task);
 execution:=public.start_workout_execution(t);
 select id into es from public.workout_execution_sets where execution_id=execution;
 result:='{"value":8,"rir":3,"load_kg":40,"technique_valid":true,"conditions_confirmed":true,"tolerated":true,"stop_reason":"none"}';
 perform public.complete_performance_set_idempotent(gen_random_uuid(),es,result);
 perform public.finish_workout_execution(execution,5,null,null,null,'manual');
 observed:=public.performance_support_observed_v1('bench_press_barbell',1,'LOAD_REPS','external_load',wk);
 if observed->'result'->>'load_kg'<>'40' or observed->>'source_id'<>execution::text then raise exception 'No recupera ejecución real'; end if;
 if public.performance_support_observed_v1('bench_press_barbell',1,'LOAD_REPS','external_load',wk-7) is null then raise exception 'Ignora registro real de esta misma semana'; end if;
 all_proposals:=public.performance_support_candidates_v1(g,wk,jsonb_build_array(main));
 select value into candidate from jsonb_array_elements(all_proposals) p where p->>'support_entry'='observed';
 if candidate is null or candidate->'dose'->'task'->>'external_load_kg'<>'40' then raise exception 'No pasa de práctica a apoyo personalizado: %',all_proposals; end if;
 if candidate->'automatic_reference'->'reference'->'automatic_support'->'observation'->>'source_id'<>execution::text then raise exception 'Sin trazabilidad'; end if;
 perform public.persist_automatic_support_v1(g,candidate);
 if (select count(*) from public.performance_training_references where preparation_goal_id=g and active)<>2
  or not exists(select 1 from public.performance_training_references where id=(candidate->>'reference_id')::uuid
     and reference->>'reference_kind'='performed_set') then raise exception 'Duplica o no promueve referencia'; end if;
 old_ref:=candidate->'automatic_reference'->'reference';
 if not public.performance_support_source_valid_v1(old_ref) then raise exception 'No conserva un origen válido'; end if;
 -- Datos incompletos/dificultad/carga ausente nunca se convierten en capacidad.
 perform public.correct_performance_set_result(es,'No conocía el margen real',result-'rir');
 if public.performance_support_source_valid_v1(old_ref) then raise exception 'Ignora corrección del origen'; end if;
 if exists(select 1 from jsonb_array_elements(public.get_preparation_training_setup(g)->'references') reference_row
   where reference_row->>'id'=candidate->>'reference_id') then raise exception 'Sigue presentando como válida una referencia corregida'; end if;
 if public.performance_support_observed_v1('bench_press_barbell',1,'LOAD_REPS','external_load',wk) is not null then raise exception 'Inventa RIR ausente'; end if;
 perform public.correct_performance_set_result(es,'Prueba de carga desconocida',result-'load_kg');
 if public.performance_support_observed_v1('bench_press_barbell',1,'LOAD_REPS','external_load',wk) is not null then raise exception 'Inventa carga'; end if;
 perform public.correct_performance_set_result(es,'Prueba de dificultad',result||'{"rir":1}');
 if public.performance_support_observed_v1('bench_press_barbell',1,'LOAD_REPS','external_load',wk) is not null then raise exception 'Acepta dificultad'; end if;
 -- Puede aprovechar una referencia propia de otra preparación: no hace falta
 -- repetir una práctica vigente y completa del mismo ejercicio.
 insert into public.preparation_goals(user_id,program_id,target_date)
 values(auth.uid(),'armed_forces_troop_entry',current_date+120) returning id into other_goal;
 known:=public.save_performance_reference(other_goal,jsonb_build_object('goal_code','bench_press_barbell','goal_version',1,
  'goal_measurement','MAX_LOAD','reference_kind','performed_set','observed_on',current_date,'current_capacity_confirmed',true,
  'targets','[8]'::jsonb,'reported_rir',3,'frequency',1,
  'task','{"exercise_code":"bench_press_barbell","exercise_version":1,"protocol_key":"bench_work","protocol_version":1,"setup_key":"standard:bench_work","measurement":"LOAD_REPS","load_mode":"external_load","external_load_kg":30,"target_value":8,"intent":"work"}'::jsonb));
 all_proposals:=public.performance_support_candidates_v1(g,wk,jsonb_build_array(main));
 select value into candidate from jsonb_array_elements(all_proposals) p where p->>'support_entry'='observed';
 if candidate->'dose'->'task'->>'external_load_kg' is distinct from '30' then raise exception 'Repite referencia que ya existe'; end if;
 if not public.performance_support_source_valid_v1(candidate->'automatic_reference'->'reference') then raise exception 'Invalida referencia importada por campos de presentación'; end if;
 if public.performance_support_observed_v1('bench_press_barbell',1,'LOAD_REPS','external_load',wk+21) is not null then raise exception 'Reutiliza referencia antigua'; end if;
 update public.performance_training_references set active=false where preparation_goal_id=g and reference->'task'->>'exercise_code'='bench_press_barbell';
 if jsonb_array_length(public.performance_support_candidates_v1(g,wk,jsonb_build_array(main)))<>1 then raise exception 'Reactiva apoyo que el usuario dejó de utilizar'; end if;
 perform public.save_performance_context('{"1":60}',array['weighted_vest'],false,true);
 all_proposals:=public.performance_support_candidates_v1(g,wk,jsonb_build_array(main));
 select value into candidate from jsonb_array_elements(all_proposals) p where p->>'support_entry'='guided';
 if candidate->>'exercise_code' is distinct from 'push_up_weighted'
  or not public.valid_performance_prescription(candidate->'dose'->'task') then raise exception 'Exige masa o lastre antes de la familiarización'; end if;
 -- Los apoyos de control y fuerza unilateral usan su propia unidad.
 rid:=public.save_performance_reference(g,jsonb_build_object('goal_code','front_plank_forearms','goal_version',1,
  'goal_measurement','DURATION','reference_kind','performed_set','observed_on',current_date,'current_capacity_confirmed',true,
  'targets','[20]'::jsonb,'frequency',1,
  'task','{"exercise_code":"front_plank_forearms","exercise_version":1,"protocol_key":"fixture","protocol_version":1,"setup_key":"standard:fixture","measurement":"DURATION","load_mode":"bodyweight","target_value":20,"intent":"work"}'::jsonb));
 main:=main||jsonb_build_object('reference_id',rid,'objective_key','front_plank_forearms:DURATION','exercise_code','front_plank_forearms','model','isometric');
 all_proposals:=public.performance_select_v4(public.performance_support_candidates_v2(g,wk,jsonb_build_array(main)));
 if not exists(select 1 from jsonb_array_elements(all_proposals) p where p->>'exercise_code'='front_plank_high'
    and p->'dose'->'task'->>'measurement'='DURATION' and p->'dose'->'task'->>'effort_mode'='rpe'
    and not (p->'dose'->'task') ? 'target_rir') then raise exception 'No introduce el apoyo isométrico con su propia unidad'; end if;
 rid:=public.save_performance_reference(g,jsonb_build_object('goal_code','shuttle_5_10_5','goal_version',1,
  'goal_measurement','TIME_FOR_COURSE','reference_kind','performed_set','observed_on',current_date,'current_capacity_confirmed',true,
  'targets','[10]'::jsonb,'frequency',1,
  'task','{"exercise_code":"shuttle_5_10_5","exercise_version":1,"protocol_key":"fixture","protocol_version":1,"setup_key":"standard:fixture","measurement":"TIME_FOR_COURSE","load_mode":"bodyweight","target_value":10,"intent":"practice"}'::jsonb));
 main:=main||jsonb_build_object('reference_id',rid,'objective_key','shuttle_5_10_5:TIME_FOR_COURSE','exercise_code','shuttle_5_10_5','model','course');
 all_proposals:=public.performance_select_v4(public.performance_support_candidates_v1(g,wk,jsonb_build_array(main)));
 if not exists(select 1 from jsonb_array_elements(all_proposals) p where p->>'exercise_code'='split_squat'
    and p->'dose'->'task'->>'measurement'='REPS') then raise exception 'Descarta apoyo unilateral por no llevar kilos'; end if;
 perform set_config('request.jwt.claim.sub',gen_random_uuid()::text,true);
 if public.performance_support_observed_v1('bench_press_barbell',1,'LOAD_REPS','external_load',wk) is not null then raise exception 'Lee otro usuario'; end if;
 begin
  perform public.performance_support_candidates_v1(g,wk,jsonb_build_array(main));
  raise exception 'Acepta preparación ajena';
 exception when insufficient_privilege then null; end;
 perform set_config('request.jwt.claim.sub',old_user::text,true);
 if has_function_privilege('authenticated','public.persist_automatic_support_v1(uuid,jsonb)','execute')
  or has_function_privilege('authenticated','public.performance_support_candidates_v1(uuid,date,jsonb)','execute') then raise exception 'Expone escritura interna'; end if;
end $$;
select 'Apoyo autónomo, práctica guiada, registro, referencia derivada, incertidumbre y propiedad: OK' result;
set local role authenticated;
do $$ begin
 if not public.valid_performance_prescription('{"schema_version":1,"exercise_code":"bench_press_barbell","exercise_version":1,"protocol_key":"support_work_v1:bench_press_barbell","protocol_version":1,"setup_key":"standard:support_v1:bench_press_barbell","measurement":"LOAD_REPS","load_mode":"external_load","intent":"work","policy_version":"support_familiarization_v1","target_value":8,"effort_mode":"rir","target_rir":3,"stimulus_code":"SUPPORT-F01"}') then
  raise exception 'El CHECK no funciona con los permisos reales del cliente'; end if;
end $$;
reset role;
rollback;
