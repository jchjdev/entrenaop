-- Reinicio por preparación: sesiones automáticas y sus resultados desaparecen;
-- marcas oficiales y contexto permanecen. Todo termina con ROLLBACK.
-- Todas las modificaciones, incluidas las del usuario de ensayo, se revierten.
begin;
-- El ensayo deportivo necesita derechos Pro explícitos, siempre con ROLLBACK.
insert into public.pro_access_grants(user_id,source,ends_at,reason)
select candidate.id,'development_manual',now()+interval '1 day','Fixture SQL de programa adaptativo'
from public.profiles candidate where not public.has_pro_access(candidate.id);

select set_config('request.jwt.claim.sub',(select user_id::text from public.admin_permissions limit 1),true);
update public.profiles set fecha_nacimiento=date '1996-01-01' where id=auth.uid();
update public.preparation_goals set status='archived',archived_at=now() where user_id=auth.uid() and status='active';
-- Evitar que la agenda ficticia preexistente ocupe días de este ensayo.
update public.scheduled_workouts set scheduled_date=scheduled_date-365
 where user_id=auth.uid() and scheduled_date>=current_date;
do $$
declare g uuid; a uuid;
begin
 insert into public.preparation_goals(user_id,program_id,target_date)
 values(auth.uid(),'fas_periodic_assessment',current_date+90) returning id into g;
 insert into public.fas_periodic_assessments(user_id,preparation_goal_id,catalog_version,category,age_at_assessment,age_band,is_pre_effective_reference)
 values(auth.uid(),g,'es_def_15_2026_periodic_2027_v1','men',30,'26_30',true) returning id into a;
 insert into public.fas_periodic_marks(assessment_id,test_id,value) values(a,'run_2000_m',478000);
 insert into public.running_reference_selections(preparation_goal_id,reference_source,reference_record_id)
 values(g,'fasPeriodicAssessment',a::text);
 insert into public.running_intake_contexts(preparation_goal_id,context_version,available_minutes_by_weekday,
 reserved_strength_weekdays,running_days_last_four_weeks,running_minutes_last_four_weeks,recent_weeks_end_on,
 reports_pain,requires_professional_review,health_observed_at,comfortable_continuous_minutes,target_2k_seconds,goal_mode,quality_weeks_last_four)
 values(g,'running_initial_context_v3','{"1":45,"3":45,"6":45}','{}',array[3,3,3,3],array[110,110,110,110],
 current_date-extract(isodow from current_date)::integer,false,false,now(),60,465,'time',2);
end $$;
set local role authenticated;
do $$
declare g uuid; wk date:=current_date+8-extract(isodow from current_date)::integer;
 p jsonb; again jsonb; next jsonb; cleared jsonb; sw record; es record; e uuid; seconds integer; meters numeric; pace numeric;
 generated_templates uuid[];
begin
 select id into g from public.preparation_goals where user_id=auth.uid() and status='active' and program_id='fas_periodic_assessment';
 p:=public.publish_fas_running_week(g,wk);
 if (p->>'declared_prior_quality_weeks')::int<>2
    or (p->'input_snapshot'->>'declared_prior_quality_weeks')::int<>2 then
   raise exception 'La declaración previa no quedó auditada en la decisión'; end if;
 if (p->'quality_entry'->>'exposures_42d')::int<>0 then
   raise exception 'Las series declaradas contaron como ejecuciones verificadas'; end if;
 if p->>'policy_version'<>'running_2k_v5' or jsonb_array_length(p->'sessions')<>3 then raise exception 'No publica v5 tres sesiones: %',p; end if;
 again:=public.publish_fas_running_week(g,wk);
 if again->>'decision_id'<>p->>'decision_id' or (again->>'already_published')::boolean is not true then raise exception 'No idempotente'; end if;
 for sw in select w.id,rs.prescription from public.scheduled_workouts w
   join public.running_week_sessions rs on rs.scheduled_workout_id=w.id
   where rs.decision_id=(p->>'decision_id')::uuid loop
   e:=public.start_scheduled_workout(sw.id);
   begin
     perform public.reset_running_plan(g);
     raise exception 'El reinicio permitió borrar una sesión activa';
   exception when others then
     if sqlerrm<>'Finish or abandon the active session before resetting' then raise; end if;
   end;
   if (select count(*) from public.workout_execution_sets where execution_id=e)<>jsonb_array_length(sw.prescription->'segments') then
     raise exception 'Se perdieron tramos al iniciar'; end if;
   for es in select * from public.workout_execution_sets where execution_id=e order by set_order loop
     pace:=coalesce((es.target_pace_min_seconds_per_km+es.target_pace_max_seconds_per_km)/2.0,330);
     seconds:=coalesce(es.target_duration_seconds,round(es.target_distance_meters*pace/1000)::integer);
     meters:=coalesce(es.target_distance_meters,seconds*1000/pace);
     perform public.complete_workout_set(p_result_id=>es.id,p_actual_duration_seconds=>seconds,
       p_actual_distance_meters=>meters,p_actual_recovery_duration_seconds=>es.recovery_duration_seconds,p_result_source=>'manual');
   end loop;
   perform public.finish_workout_execution(e,(sw.prescription->>'rpe_ceiling')::integer-1,null,null,null,'manual');
 end loop;
 next:=public.preview_fas_running_next_week(g);
 if (next->>'simulation')::boolean is not true or next->>'outcome'<>'progress' then raise exception 'No interpreta resultados: %',next; end if;
 if (select count(*) from jsonb_array_elements(next->'evidence'->'observations') o where o->'signal'->>'status'='tolerated')<>3 then
   raise exception 'Los resultados del ejecutor no llegan al cerebro'; end if;
 if (select count(*) from public.running_week_decisions where preparation_goal_id=g)<>1 then raise exception 'Simulación publicó'; end if;
 begin
   perform public.publish_fas_running_week(g,wk+7);
   raise exception 'Publica antes del cierre';
 exception when others then if sqlerrm<>'Close the previous week before adapting' then raise; end if; end;
 -- El usuario no puede invocar el motor con un estado inventado para publicar.
 if has_function_privilege('authenticated','public.running_plan_v1(jsonb)','execute') then raise exception 'Motor puro expuesto'; end if;
 if has_function_privilege('authenticated','public.running_plan_v2(jsonb)','execute') then raise exception 'Motor v2 expuesto'; end if;
 if has_function_privilege('authenticated','public.running_plan_v4(jsonb)','execute') then raise exception 'Motor v4 expuesto'; end if;
 update public.running_intake_contexts set target_2k_seconds=null,goal_mode='official_margin',official_margin_seconds=10 where preparation_goal_id=g;
 next:=public.preview_fas_running_next_week(g);
 if next->'goal'->>'mode'<>'official_margin' or (next->'goal'->>'seconds')::numeric<>704 then
   raise exception 'No resuelve umbral propio y margen: %',next->'goal'; end if;
 select array_agg(x.template_id) into generated_templates from public.scheduled_workouts x
   where x.preparation_goal_id=g and x.source='algorithm';
 cleared:=public.reset_running_plan(g);
 if (cleared->>'decisions')::int<>1 or (cleared->>'sessions')::int<>3
   or (cleared->>'executions')::int<>3 then
   raise exception 'Reinicio incompleto: %',cleared; end if;
 if exists(select 1 from public.running_week_decisions where preparation_goal_id=g)
   or exists(select 1 from public.scheduled_workouts where preparation_goal_id=g and source='algorithm')
   or exists(select 1 from public.workout_executions where template_id=any(generated_templates))
   or exists(select 1 from public.workout_templates where id=any(generated_templates)) then
   raise exception 'Persisten decisiones o sesiones automáticas'; end if;
 if not exists(select 1 from public.running_intake_contexts where preparation_goal_id=g)
   or not exists(select 1 from public.fas_periodic_assessments where preparation_goal_id=g)
   or not exists(select 1 from public.running_reference_selections where preparation_goal_id=g) then
   raise exception 'El reinicio borró el contexto o una marca'; end if;
 again:=public.publish_fas_running_week(g,wk);
 if (again->>'already_published')::boolean is true then
   raise exception 'No se puede pautar desde cero tras reiniciar'; end if;
 cleared:=public.reset_running_plan(g);
 if (cleared->>'decisions')::int<>1 then raise exception 'Segundo reinicio falló'; end if;
 cleared:=public.reset_running_plan(g);
 if (cleared->>'decisions')::int<>0 then raise exception 'Reinicio vacío no es idempotente'; end if;
 perform set_config('request.jwt.claim.sub',gen_random_uuid()::text,true);
 begin
   perform public.publish_fas_running_week(g,wk);
   raise exception 'Acceso cruzado';
 exception when insufficient_privilege then null; end;
 if exists(select 1 from public.running_week_decisions where preparation_goal_id=g) then raise exception 'RLS no aísla'; end if;
end $$;
reset role;
select 'reinicio → nueva publicación; sesión activa, datos ajenos y RLS: OK' as integration;
rollback;
