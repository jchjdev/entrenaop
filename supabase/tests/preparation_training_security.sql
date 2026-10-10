begin;
-- El ensayo deportivo necesita derechos Pro explícitos, siempre con ROLLBACK.
insert into public.pro_access_grants(user_id,source,ends_at,reason)
select candidate.id,'development_manual',now()+interval '1 day','Fixture SQL de programa adaptativo'
from public.profiles candidate where not public.has_pro_access(candidate.id);

select set_config('request.jwt.claim.sub',(select user_id::text from public.admin_permissions limit 1),true);
select set_config('test.performance_owner',auth.uid()::text,true);
do $$
declare g uuid; r uuid; obj jsonb;
begin
 select id into g from public.preparation_goals where user_id=auth.uid() and status='active' limit 1;
 if g is null then insert into public.preparation_goals(user_id,program_id,target_date)
   values(auth.uid(),'fas_periodic_assessment',current_date+90) returning id into g; end if;
 perform set_config('test.performance_goal',g::text,true);
 perform public.save_performance_context('{"1":60,"4":60}','{}',false,true);
 obj:=jsonb_build_object('goal_code','push_up_standard','goal_version',1,'goal_measurement','REPS',
   'task','{"exercise_code":"push_up_standard","exercise_version":1,"protocol_key":"floor_v1","protocol_version":1,"setup_key":"Suelo y recorrido completo","measurement":"REPS","load_mode":"bodyweight","target_value":8,"target_rir":3,"intent":"work"}'::jsonb,
   'targets','[8,8]'::jsonb,'observed_on',current_date,'current_capacity_confirmed',true,'reported_rir',3,'rest_seconds',120,'frequency',2);
 r:=public.save_performance_reference(g,obj);
 begin
   perform public.save_performance_reference(g,obj||'{"program_objective_key":"legacy:abdominal_plank"}');
   raise exception 'Permite atribuir una referencia a otra prueba';
 exception when invalid_parameter_value then null; end;
 if has_function_privilege('authenticated','public.calculate_running_week_constrained(uuid,date,boolean,boolean,jsonb)','execute')
   or has_function_privilege('authenticated','public.performance_task_v1(jsonb,jsonb,jsonb,date,date,jsonb)','execute')
   or has_function_privilege('anon','public.publish_preparation_week(uuid,date,jsonb)','execute') then raise exception 'Privilegios excesivos'; end if;
end $$;
set local role authenticated;
do $$
begin
 if not exists(select 1 from public.performance_training_references where user_id=auth.uid()) then raise exception 'No puede leer datos propios'; end if;
 begin
   update public.performance_training_references set active=false where user_id=auth.uid();
   raise exception 'Escritura directa sin RPC';
 exception when insufficient_privilege then null; end;
end $$;
select set_config('request.jwt.claim.sub',gen_random_uuid()::text,true);
do $$
begin
 if exists(select 1 from public.performance_training_contexts)
   or exists(select 1 from public.performance_training_references)
   or exists(select 1 from public.preparation_week_decisions)
   or exists(select 1 from public.performance_week_work) then raise exception 'RLS expone datos ajenos'; end if;
 begin
   perform public.get_preparation_training_setup(current_setting('test.performance_goal')::uuid);
   raise exception 'Lee una preparación ajena';
 exception when insufficient_privilege then null; end;
 begin
   perform public.set_admin_performance_strategy(gen_random_uuid(),'push_up_standard',1,'REPS','Nota de revisión','{}');
   raise exception 'Un deportista configura estrategia administrativa';
 exception when insufficient_privilege then null; end;
end $$;
reset role;
select 'Propiedad, RLS real, RPC obligatorias y permisos administrativos: OK' as result;
rollback;
