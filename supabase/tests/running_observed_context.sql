begin;
select set_config('request.jwt.claim.sub',(select user_id::text from public.admin_permissions limit 1),true);
do $$
declare g uuid; other_g uuid; u uuid:=auth.uid(); snap jsonb; health timestamptz:=now()-interval '31 days';
begin
 insert into public.preparation_goals(user_id,program_id,target_date) values(u,'fas_periodic_assessment',current_date+90) returning id into g;
 insert into public.running_intake_contexts(preparation_goal_id,context_version,available_minutes_by_weekday,
 reserved_strength_weekdays,running_days_last_four_weeks,running_minutes_last_four_weeks,recent_weeks_end_on,
 reports_pain,requires_professional_review,health_observed_at,comfortable_continuous_minutes,goal_mode)
 values(g,'running_initial_context_v3','{"1":60,"4":45}','{}',array[2,1,0,0],array[60,30,0,0],
 current_date-extract(isodow from current_date)::int-7,false,false,health,30,'improve');
 snap:=public.get_running_intake_context_observed(g);
 if snap->'recent_load_sources'->>0<>'unknown' or snap->'running_minutes_last_four_weeks'->>1<>'60'
   or (snap->>'health_observed_at')::timestamptz<>health then raise exception 'No alinea declaraciones o renueva salud: %',snap; end if;
 if (select recent_weeks_end_on from public.running_intake_contexts where preparation_goal_id=g)<>current_date-extract(isodow from current_date)::int-7 then raise exception 'Sobrescribe declaración original'; end if;
 perform set_config('request.jwt.claim.sub',gen_random_uuid()::text,true);
 begin perform public.get_running_intake_context_observed(g); raise exception 'Acceso cruzado';
 exception when insufficient_privilege then null; end;
 if has_function_privilege('anon','public.get_running_intake_context_observed(uuid)','execute')
 or has_function_privilege('authenticated','public.running_context_observed_v1(uuid,date)','execute') then raise exception 'Permisos de helpers'; end if;
end $$;
rollback;
