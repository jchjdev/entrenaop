-- Compara publicaciones de la misma preparación y semana con las mismas referencias oficiales.
begin;
set local timezone='UTC';
set local statement_timeout='120s';

create function pg_temp.published_blocks(goal uuid, ignore_carry boolean) returns jsonb language sql as $$
 select coalesce(jsonb_agg(day_work order by day_work->>'date'),'[]'::jsonb)
 from (select jsonb_build_object('date',sw.scheduled_date,'blocks',jsonb_agg(jsonb_build_object(
    'name',b.name,'format',b.format,'sets',x.sets) order by b.order_index)) day_work
  from public.scheduled_workouts sw join public.workout_blocks b on b.template_id=sw.template_id
  cross join lateral (select jsonb_agg((to_jsonb(ws)-array['id','item_id'])||jsonb_build_object(
    'exercise',wi.exercise_id,'notes',wi.notes) order by wi.order_index,ws.order_index) sets
   from public.workout_items wi join public.workout_sets ws on ws.item_id=wi.id where wi.block_id=b.id) x
  where sw.preparation_goal_id=goal and sw.status='planned'
   and (not ignore_carry or not exists(select 1 from public.performance_week_work pw
    where pw.scheduled_workout_id=sw.id and pw.block_order=b.order_index
     and pw.dose#>>'{task,exercise_code}'='farmer_carry'))
  group by sw.id,sw.scheduled_date) sessions
$$;

create function pg_temp.check_personal(availability jsonb, should_fit boolean) returns jsonb language plpgsql as $$
declare
 u uuid:=gen_random_uuid(); g uuid; a uuid; push_up_id uuid; plank_id uuid; carry_id uuid; replacement_id uuid;
 wk date:=current_date-extract(isodow from current_date)::int+8; target date:=wk+90;
 baseline jsonb; extra jsonb; legacy_preview jsonb; baseline_blocks jsonb; extra_blocks jsonb; carry jsonb; second_goal jsonb;
 carry_block record;
begin
 insert into auth.users(id,email) values(u,u||'@running-control-days.invalid');
 perform set_config('request.jwt.claim.sub',u::text,true);
 update public.profiles set fecha_nacimiento='1996-01-01' where id=u;
 insert into public.pro_access_grants(user_id,source,starts_at,ends_at,reason)
 values(u,'development_manual',now()-interval '1 day',now()+interval '1 day','Fixture de cobertura del plan combinado');
 insert into public.preparation_goals(user_id,program_id,target_date) values(u,'fas_periodic_assessment',target) returning id into g;
  insert into public.fas_periodic_assessments(user_id,preparation_goal_id,catalog_version,category,age_at_assessment,age_band,is_pre_effective_reference,completed_at)
  values(u,g,'es_def_15_2026_periodic_2027_v1','men',30,'26_30',true,now()-interval '2 days') returning id into a;
  insert into public.fas_periodic_marks values(a,'run_2000_m',595000);
  insert into public.running_reference_selections(preparation_goal_id,reference_source,reference_record_id) values(g,'fasPeriodicAssessment',a::text);
 insert into public.running_intake_contexts(preparation_goal_id,context_version,available_minutes_by_weekday,
  reserved_strength_weekdays,running_days_last_four_weeks,running_minutes_last_four_weeks,recent_weeks_end_on,
  reports_pain,requires_professional_review,health_observed_at,comfortable_continuous_minutes,target_2k_seconds,goal_mode)
 values(g,'running_initial_context_v3',availability,'{}',array[4,4,4,4],array[160,160,160,160],
  wk-1,false,false,now(),60,500,'time');
 perform public.save_performance_context(availability,array['cones','measuring_tape','tennis_ball','chalk','bench','barbell','plates','dumbbell_pair'],false,true);
 push_up_id:=public.save_performance_reference(g,jsonb_build_object('goal_code','push_up_standard','goal_version',1,
    'goal_measurement','REPS_IN_TIME','program_objective_key','legacy:upper_body_push_ups_2_min',
    'task','{"exercise_code":"push_up_standard","exercise_version":1,"protocol_key":"floor_v1","protocol_version":1,"setup_key":"Suelo y recorrido completo","measurement":"REPS","load_mode":"bodyweight","target_value":7,"target_rir":3,"intent":"work"}'::jsonb,
    'reference_kind','repeated_work','targets','[7,6]'::jsonb,'observed_on',current_date,
    'current_capacity_confirmed',true,'reported_rir',3,'rest_seconds',120,'frequency',2));
 plank_id:=public.save_performance_reference(g,jsonb_build_object('goal_code','front_plank_forearms','goal_version',1,
      'goal_measurement','DURATION','program_objective_key','legacy:abdominal_plank',
      'task','{"exercise_code":"front_plank_forearms","exercise_version":1,"protocol_key":"def_15_2026_plank","protocol_version":1,"setup_key":"Suelo antideslizante y codos bajo hombros","measurement":"DURATION","load_mode":"bodyweight","target_value":50,"intent":"work"}'::jsonb,
      'reference_kind','repeated_work','targets','[50,45]'::jsonb,'observed_on',current_date,
      'current_capacity_confirmed',true,'reported_rpe',7,'rest_seconds',90,'frequency',2));
 perform public.save_performance_reference(g,jsonb_build_object('goal_code','slalom_ball_course_16m','goal_version',1,
    'goal_measurement','TIME_FOR_COURSE','program_objective_key','legacy:agility_speed_circuit','equipment_confirmed',true,
    'task','{"exercise_code":"slalom_ball_course_16m","exercise_version":1,"protocol_key":"def_15_2026_agility","protocol_version":1,"setup_key":"Siete conos y corredor medido de 16 por 2 metros","measurement":"TIME_FOR_COURSE","load_mode":"bodyweight","target_value":14.3,"intent":"practice"}'::jsonb,
    'reference_kind','repeated_work','targets','[14.3,14.5]'::jsonb,'observed_on',current_date,
    'current_capacity_confirmed',true,'rest_seconds',180,'frequency',1));

 perform public.save_adaptive_program_preferences(g,target,'{}','full');
 baseline:=public.preview_adaptive_program_activation(g,wk);
 if baseline->>'status' is distinct from 'ready' then
  raise exception 'La semana sin extra debe estar lista: %',baseline->'pending';
 end if;
 begin
  perform public.activate_adaptive_program(g,wk,baseline);
  baseline_blocks:=pg_temp.published_blocks(g,false);
  raise exception using errcode='P1234',message='Deshacer solo la primera publicación';
 exception when sqlstate 'P1234' then null;
 end;
 if baseline_blocks='[]' then raise exception 'La publicación inicial no materializó la semana'; end if;
 carry:=jsonb_build_object('goal_code','farmer_carry','goal_version',1,'goal_measurement','DURATION',
  'task','{"exercise_code":"farmer_carry","exercise_version":1,"protocol_key":"fixture_carry","protocol_version":1,"setup_key":"Dos mancuernas y pasillo llano","measurement":"DURATION","load_mode":"external_load","external_load_kg":20,"intent":"work","target_value":30}'::jsonb,
  'reference_kind','repeated_work','targets','[30,30]'::jsonb,
  'observed_on',current_date,'current_capacity_confirmed',true,'rest_seconds',90,'frequency',1);
 carry_id:=public.save_performance_reference(g,carry);
 replacement_id:=public.save_performance_reference(g,carry);
 if exists(select 1 from public.performance_training_references where id=carry_id and active) then
  raise exception 'Editar el mismo objetivo debe conservar una sola referencia activa de esa variante'; end if;
 second_goal:=carry||jsonb_build_object('goal_measurement','DISTANCE','task',(carry->'task')||'{"measurement":"DISTANCE"}'::jsonb,
  'targets','[20,20]'::jsonb);
 begin
  perform public.save_performance_reference(g,second_goal);
  raise exception 'El servidor aceptó dos objetivos personales';
 exception when sqlstate '22023' then
  if sqlerrm not like 'Ya tienes un objetivo personal%' then raise; end if;
 end;
 begin
  perform public.save_performance_reference(g,second_goal||'{"replace_personal_objective":true}'::jsonb);
  if not exists(select 1 from public.performance_training_references where id=replacement_id and not active) then
   raise exception 'Cambiar el objetivo debe conservar la referencia anterior inactiva'; end if;
  -- Simula dos objetivos que ya estaban activos antes del límite.
  update public.performance_training_references set active=true where id=replacement_id;
  legacy_preview:=public.preview_adaptive_program_activation(g,wk);
  if legacy_preview->>'status' is distinct from 'ready'
   or legacy_preview->'sessions' is distinct from baseline->'sessions'
   or not exists(select 1 from jsonb_array_elements(legacy_preview->'pending') item
    where item->>'status'='personal_objective_deferred' and item->>'reason' like 'Elige qué objetivo%') then
   raise exception 'Dos extras antiguos deben poder resolverse sin bloquear la semana oficial'; end if;
  raise exception using errcode='P1234',message='Recuperar el objetivo de la comparación';
 exception when sqlstate 'P1234' then null;
 end;
 extra:=public.preview_adaptive_program_activation(g,wk);
 if extra->>'status' is distinct from 'ready' or extra->'running' is distinct from baseline->'running'
  or extra->'control_schedule' is distinct from baseline->'control_schedule' then
  raise exception 'El objetivo personal alteró la semana de carrera o sus controles: %',extra->'pending'; end if;
 perform public.activate_adaptive_program(g,wk,extra);
 extra_blocks:=pg_temp.published_blocks(g,true);
 if extra_blocks is distinct from baseline_blocks then
  raise exception 'El objetivo personal alteró fechas, dosis o el orden de bloques oficiales'; end if;
 select pw.block_order,sw.scheduled_date,sw.template_id into carry_block
 from public.performance_week_work pw join public.scheduled_workouts sw on sw.id=pw.scheduled_workout_id
 where sw.preparation_goal_id=g and pw.reference_id=replacement_id;
 if should_fit then
  if carry_block.block_order is null then raise exception 'El farmer carry con hueco se aplazó: %',extra->'pending'; end if;
  if not exists(select 1 from jsonb_array_elements(extra->'sessions') s where s->>'date'=carry_block.scheduled_date::text
    and s->>'session_order'='performance_first' and s->>'combined'='true') then
   raise exception 'La fixture necesita fuerza antes de carrera para probar que el extra va detrás de ambas'; end if;
  if exists(select 1 from public.workout_blocks b where b.template_id=carry_block.template_id
   and b.order_index>carry_block.block_order and b.format<>'cool_down' and b.name<>'Vuelta a la calma compartida') then
   raise exception 'El farmer carry debe ser el último bloque de trabajo'; end if;
 elsif carry_block.block_order is not null or not exists(select 1 from jsonb_array_elements(extra->'pending') item
  where item->>'status'='personal_objective_deferred') then
  raise exception 'El farmer carry sin hueco debe aplazarse con aviso';
 end if;
 return jsonb_build_object('week',wk,'same_official_blocks',true,'extra_date',carry_block.scheduled_date,
  'mixed',exists(select 1 from public.workout_blocks b where b.template_id=carry_block.template_id and b.format='running'),
  'order',(select s->>'session_order' from jsonb_array_elements(extra->'sessions') s where s->>'date'=carry_block.scheduled_date::text));
end $$;

select pg_temp.check_personal('{"1":45,"3":45,"5":45,"6":45}',false) as deferred,
 pg_temp.check_personal('{"1":100,"3":100,"5":100,"7":100}',true) as scheduled;
rollback;
