-- Fuerza propia en martes y viernes bloquea la calidad de carrera.
begin;
set local statement_timeout='40s';

do $$
declare
 u uuid:=gen_random_uuid(); g uuid; mark_id uuid; template uuid; block uuid;
 ex uuid; tuesday uuid; friday uuid; wk date:=current_date-extract(isodow from current_date)::int+8;
 availability jsonb:='{"1":45,"3":45,"4":45,"6":45}';
 original jsonb; moved jsonb; suggestion jsonb; outsider uuid:=gen_random_uuid();
begin
 insert into auth.users(id,email) values(u,u||'@strength-preview.invalid');
 perform set_config('request.jwt.claim.sub',u::text,true);
 update public.profiles set fecha_nacimiento='1996-01-01' where id=u;
 insert into public.pro_access_grants(user_id,source,starts_at,ends_at,reason)
 values(u,'development_manual',now()-interval '1 day',now()+interval '1 day','Fixture agenda y carrera');
 insert into public.preparation_goals(user_id,program_id,target_date)
 values(u,'fas_periodic_assessment',wk+100) returning id into g;
 insert into public.fas_periodic_assessments(user_id,preparation_goal_id,catalog_version,category,age_at_assessment,age_band,is_pre_effective_reference,completed_at)
 values(u,g,'es_def_15_2026_periodic_2027_v1','men',30,'26_30',true,now()-interval '5 days')
 returning id into mark_id;
 insert into public.fas_periodic_marks values(mark_id,'run_2000_m',550000);
 insert into public.running_reference_selections(preparation_goal_id,reference_source,reference_record_id)
 values(g,'fasPeriodicAssessment',mark_id::text);
 insert into public.running_intake_contexts(preparation_goal_id,context_version,available_minutes_by_weekday,
  reserved_strength_weekdays,running_days_last_four_weeks,running_minutes_last_four_weeks,recent_weeks_end_on,
  reports_pain,requires_professional_review,health_observed_at,comfortable_continuous_minutes,target_2k_seconds,goal_mode)
 values(g,'running_initial_context_v3',availability,'{}',array[3,3,3,3],array[100,100,100,100],
  current_date-extract(isodow from current_date)::int,false,false,now(),45,515,'time');
 perform public.save_performance_context(availability,'{}',false,true);
 perform public.save_adaptive_program_preferences(g,wk+100,'{}','running');

 insert into public.workout_templates(name,origin,owner_user_id,visibility,status,estimated_duration_minutes)
 values('Fuerza de piernas','user',u,'private','published',35) returning id into template;
 insert into public.workout_blocks(template_id,order_index,name,format)
 values(template,0,'Fuerza de piernas','straight_sets') returning id into block;
 select e.id into strict ex from public.exercises e join public.exercise_training_profiles ep
  on ep.code=e.training_profile_code and ep.definition_version=e.training_profile_version
 where ep.definition->'body_regions' ? 'lower_body' order by e.id limit 1;
 insert into public.workout_items(block_id,exercise_id,order_index) values(block,ex,0);
 tuesday:=public.schedule_workout(template,wk+1,time '18:00');
 friday:=public.schedule_workout(template,wk+4,time '18:00');

 original:=public.preview_adaptive_program_activation(g,wk);
 if original->>'status' is distinct from 'ready'
   or jsonb_array_length(original->'running'->'sessions') is distinct from 3
   or exists(select 1 from jsonb_array_elements(original->'running'->'sessions') s where s->>'family'<>'E') then
  raise exception 'El bloqueo debe dejar tres rodajes: %',original->'running';
 end if;
 suggestion:=public.preview_preparation_strength_move(g,wk,'activation');
 if suggestion->>'scheduled_id' is distinct from tuesday::text
   or suggestion->>'from_date' is distinct from (wk+1)::text
   or suggestion->>'to_date' is distinct from (wk+2)::text
   or (select scheduled_date from public.scheduled_workouts where id=tuesday) is distinct from wk+1
   or (select scheduled_date from public.scheduled_workouts where id=friday) is distinct from wk+4
   or exists(select 1 from public.preparation_week_decisions where preparation_goal_id=g) then
  raise exception 'La alternativa debe mover solo hipotéticamente la fuerza del martes: %',suggestion;
 end if;
 if not exists(select 1 from jsonb_array_elements(suggestion->'agenda') s
    where s->>'date'=(wk+2)::text and s->>'name'='Fuerza de piernas')
   or not exists(select 1 from jsonb_array_elements(suggestion->'agenda') s
    where s->>'date'=(wk+4)::text and s->>'name'='Fuerza de piernas') then
  raise exception 'La semana alternativa debe incluir las dos citas de fuerza';
 end if;
 perform set_config('request.jwt.claim.sub',outsider::text,true);
 begin
  perform public.preview_preparation_strength_move(g,wk,'activation');
  raise exception 'La vista previa no puede exponer preparaciones ajenas';
 exception when insufficient_privilege then null;
 end;
 perform set_config('request.jwt.claim.sub',u::text,true);
 perform public.reschedule_workout(tuesday,wk+2,time '18:00');
 moved:=public.preview_adaptive_program_activation(g,wk);
 if moved->>'status' is distinct from 'ready'
   or jsonb_array_length(moved->'running'->'sessions') is distinct from 3
   or not exists(select 1 from jsonb_array_elements(moved->'running'->'sessions') s
     where s->>'family' in ('T','V','S') and (s->>'date')::date=wk) then
  raise exception 'Al mover martes a miércoles debe recuperarse la calidad el lunes: %',moved->'running';
 end if;
 if suggestion->'running' is distinct from moved#>'{running,sessions}'
   or suggestion->'performance' is distinct from moved->'sessions'
   or public.preview_preparation_strength_move(g,wk,'activation') is not null then
  raise exception 'La alternativa debe coincidir con la semana recalculada y desaparecer al mover la cita';
 end if;
end $$;
select 'La vista previa pasa de tres rodajes a una sesión de calidad y dos rodajes al mover la fuerza' as result;
rollback;
