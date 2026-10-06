-- Programa construido por ADMIN → evaluación propia → motor común → ejecutor.
-- Solo fixtures transaccionales; no persiste ningún cambio.
begin;
select set_config('request.jwt.claim.sub',(select user_id::text from public.admin_permissions limit 1),true);
update public.profiles set fecha_nacimiento='2000-01-01' where id=auth.uid();
update public.preparation_goals set status='archived',archived_at=now() where user_id=auth.uid() and status='active';
update public.scheduled_workouts set scheduled_date=scheduled_date-365 where user_id=auth.uid() and scheduled_date>=current_date;
set local role authenticated;
do $$
declare program text; t uuid; g uuid; a uuid; p jsonb; wk date:=current_date+8-extract(isodow from current_date)::int; e uuid;
begin
 program:=public.create_admin_preparation_program('Ensayo motor común 2 km','access');
 perform public.save_admin_program_scoring_rule_v3(program,'lab_generic_v1','https://www.boe.es/',
   'Fuente ficticia de ensayo','pass_fail','none',1,0,0,'assessment_date',null,'Ingreso',null,null);
 t:=public.create_admin_program_assessment_test_v5(program,'run2k','Carrera 2 km','seconds','lower',
   'Carrera continua cronometrada en pista.', 'both','run2k',1,1,18,60,1,'none',2000,'run_2000m_v1');
 perform public.save_admin_program_pass_standard(t,null,'men',18,60,475);
 perform public.save_admin_program_pass_standard(t,null,'women',18,60,510);
 perform public.set_admin_program_training_module(t,'running_2000m_v1');
 perform public.publish_admin_program_assessment(program);
 insert into public.preparation_goals(user_id,program_id,target_date) values(auth.uid(),program,current_date+90) returning id into g;
 a:=public.save_program_assessment_attempt(g,'men','2000-01-01',current_date,
   jsonb_build_array(jsonb_build_object('test_id',t,'mark',478)));
 insert into public.running_reference_selections(preparation_goal_id,reference_source,reference_record_id)
 values(g,'programAssessment',a::text);
 insert into public.running_intake_contexts(preparation_goal_id,context_version,available_minutes_by_weekday,
 reserved_strength_weekdays,running_days_last_four_weeks,running_minutes_last_four_weeks,recent_weeks_end_on,
 reports_pain,requires_professional_review,health_observed_at,comfortable_continuous_minutes,goal_mode,official_margin_seconds)
 values(g,'running_initial_context_v2','{"1":45,"4":45}','{}',array[2,2,2,2],array[50,50,50,50],
 current_date-extract(isodow from current_date)::int,false,false,now(),60,'official_margin',10);
 p:=public.calculate_running_week(g,wk);
 if (p->'goal'->>'seconds')::numeric<>465 or p->'goal'->'standard'->>'scope'<>'test_minimum_not_global_pass'
   or p->>'policy_version'<>'running_2k_v5' or jsonb_array_length(p->'sessions')<>2 then
   raise exception 'Programa genérico no resuelve su pauta y mínimo: %',p; end if;
 p:=public.publish_running_week(g,wk);
 perform public.save_performance_context('{"1":45,"4":45}','{}',false,true);
 -- El acceso común también sirve cuando este programa solo tiene carrera.
 if public.preview_preparation_week_revision(g,wk)->>'status'<>'ready'
   or jsonb_array_length(public.preview_preparation_week_revision(g,wk)->'sessions')<>0 then
   raise exception 'El coordinador exige fuerza a una preparación de solo carrera'; end if;
 select public.start_scheduled_workout(scheduled_workout_id) into e from public.running_week_sessions
   where decision_id=(p->>'decision_id')::uuid limit 1;
 if e is null or not exists(select 1 from public.workout_execution_sets where execution_id=e) then
   raise exception 'No usa el ejecutor común'; end if;
 -- La simulación no puede tomar una fuente FAS prestada por cambiar el selector.
 update public.running_reference_selections set reference_source='fasPeriodicAssessment' where preparation_goal_id=g;
 begin
   perform public.preview_running_initial_week(g,wk);
   raise exception 'Acepta fuente ajena al programa';
 exception when others then if sqlerrm<>'Reference source does not belong to this running program' then raise; end if; end;
 if has_function_privilege('authenticated','public.resolve_program_running_reference(uuid)','execute') then
   raise exception 'Adaptador interno expuesto'; end if;
end $$;
reset role;
select 'ADMIN → programa con módulo 2k → mínimo propio → publicación → ejecutor: OK' as result;
rollback;
