begin;
select set_config('request.jwt.claim.sub',(select user_id::text from public.admin_permissions limit 1),true);
update public.preparation_goals set status='archived',archived_at=now() where user_id=auth.uid() and status='active';
update public.profiles set fecha_nacimiento='1996-01-01' where id=auth.uid();
do $$
declare g uuid; r uuid; prog text; young uuid; women uuid; common_test uuid; setup jsonb;
begin
 insert into public.preparation_goals(user_id,program_id,target_date)
 values(auth.uid(),'fas_periodic_assessment',current_date+90) returning id into g;
 r:=public.save_performance_reference(g,jsonb_build_object('goal_code','slalom_ball_course_16m','goal_version',1,'goal_measurement','TIME_FOR_COURSE','program_objective_key','legacy:agility_speed_circuit',
   'task','{"exercise_code":"slalom_ball_course_16m","exercise_version":1,"protocol_key":"def_15_2026_agility","protocol_version":1,"setup_key":"Circuito medido de 16 por 2 metros","measurement":"TIME_FOR_COURSE","load_mode":"bodyweight","target_value":15.5,"intent":"practice"}'::jsonb,
   'targets','[15.5]'::jsonb,'observed_on',current_date,'current_capacity_confirmed',true,'rest_seconds',180,'frequency',1));
 if jsonb_array_length(public.get_preparation_training_setup(g)->'objectives')<>3 then raise exception 'No ofrece circuito aplicable'; end if;
 update public.profiles set fecha_nacimiento='1966-01-01' where id=auth.uid();
 setup:=public.get_preparation_training_setup(g);
 if jsonb_array_length(setup->'objectives')<>2 or jsonb_array_length(setup->'references')<>0 then raise exception 'Sigue pautando circuito exento'; end if;
 if not exists(select 1 from public.performance_training_references where id=r and active) then raise exception 'Destruye la referencia anterior'; end if;

 prog:=public.create_admin_preparation_program('Contexto temporal de fuerza','access');
 young:=public.create_admin_program_assessment_test_v5(prog,'young','Solo menores de cuarenta','repetitions','higher','Recorrido completo de referencia.','men','young',1,1,18,39,1,'none',null,null);
 women:=public.create_admin_program_assessment_test_v5(prog,'women','Columna mujeres','repetitions','higher','Recorrido completo de referencia.','women','women',2,1,18,99,1,'none',null,null);
 common_test:=public.create_admin_program_assessment_test_v5(prog,'common','Prueba común','repetitions','higher','Recorrido completo de referencia.','both','common',3,1,18,99,1,'none',null,null);
 perform public.set_admin_performance_strategy(young,'push_up_standard',1,'REPS','Revisión explícita de prueba temporal.','{}');
 perform public.set_admin_performance_strategy(women,'push_up_standard',1,'REPS','Revisión explícita de prueba temporal.','{}');
 perform public.set_admin_performance_strategy(common_test,'push_up_standard',1,'REPS','Revisión explícita de prueba temporal.','{}');
 insert into public.preparation_goals(user_id,program_id,target_date) values(auth.uid(),prog,current_date+90) returning id into g;
 -- El resultado oficial ya resuelto es la fuente de categoría y edad.
 insert into public.program_assessment_attempts(user_id,preparation_goal_id,program_id,scoring_version,category,birth_date,assessed_on,marks,result)
 values(auth.uid(),g,prog,'fixture','men','1981-01-01',current_date,'[]','{"age":45}');
 setup:=public.get_preparation_training_setup(g);
 if jsonb_array_length(setup->'objectives')<>1 or setup->'objectives'->0->>'test_id'<>common_test::text then raise exception 'Confunde edad o columna: %',setup->'objectives'; end if;
 if setup->>'has_running'<>'false' then raise exception 'Añade carrera a un programa sin carrera'; end if;
end $$;
select 'Pruebas aplicables por contexto, exención y conservación del historial: OK' as result;
rollback;
