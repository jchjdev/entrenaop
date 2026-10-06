begin;
do $$
declare a uuid:=gen_random_uuid(); b uuid:=gen_random_uuid(); g uuid; snapshot jsonb; program jsonb;
begin
 insert into auth.users(id,email) values(a,'context-a-'||a||'@example.invalid'),(b,'context-b-'||b||'@example.invalid');
 perform set_config('request.jwt.claim.sub',a::text,true);
 insert into public.training_preferences(user_id,available_days_per_week,session_duration_minutes,experience_level,equipment,requires_professional_review)
 values(a,5,45,'consistent',array['gym','free_weights'],false);
 snapshot:=public.get_training_context_settings();
 if snapshot->'context'<>'null'::jsonb then raise exception 'Las preferencias antiguas inventan contexto'; end if;
 if (snapshot->'previous_preferences'->>'available_days_per_week')::int<>5 then raise exception 'Pierde preferencias antiguas'; end if;
 if not (snapshot->'equipment_options' ? 'cones') or not (snapshot->'equipment_options' ? 'pull_up_bar') then raise exception 'Material sin catálogo'; end if;
 if snapshot->'equipment_options' ? 'gym' then raise exception 'Gimnasio convertido en material específico'; end if;
 perform public.save_performance_context('{"1":45,"4":60}',array['cones','pull_up_bar'],false,true);
 insert into public.preparation_goals(user_id,program_id,target_date) values(a,'fas_periodic_assessment',current_date+90) returning id into g;
 snapshot:=public.get_training_context_settings(); program:=public.get_preparation_training_setup(g);
 if snapshot->'context' is distinct from program->'context' then raise exception 'Perfil y programa leen contextos distintos'; end if;
 perform public.save_performance_context('{"2":60,"5":45}',array['pull_up_bar'],true,true);
 snapshot:=public.get_training_context_settings(); program:=public.get_preparation_training_setup(g);
 if snapshot->'context' is distinct from program->'context' or snapshot->'context'->'equipment' ? 'cones'
   or snapshot->'context'->'availability'->>'2'<>'60' then raise exception 'Retirar material o actualizar disponibilidad no persiste'; end if;
 perform set_config('request.jwt.claim.sub',b::text,true);
 snapshot:=public.get_training_context_settings();
 if snapshot->'context'<>'null'::jsonb or snapshot->'previous_preferences'<>'null'::jsonb then raise exception 'Lee datos de otra cuenta'; end if;
 if has_function_privilege('anon','public.get_training_context_settings()','execute') then raise exception 'Lectura anónima'; end if;
 perform set_config('request.jwt.claim.sub','',true);
 begin
   perform public.get_training_context_settings();
   raise exception 'Sin sesión puede leer el contexto';
 exception when insufficient_privilege then null;
 end;
end $$;
select 'shared_training_context_settings: OK' as result;
rollback;
