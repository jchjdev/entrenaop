-- Proyección de carga: no escribe declaraciones ni renueva la confirmación de salud.
create function public.running_context_observed_v1(goal uuid,as_of date) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare ctx public.running_intake_contexts%rowtype; u uuid; last_sunday date:=as_of-extract(isodow from as_of)::int;
 ending date; declared_index int; n int; days int; minutes int; declared_days int; declared_minutes int;
 day_values jsonb:='[]'; minute_values jsonb:='[]'; sources jsonb:='[]'; source text;
begin
 select user_id into u from public.preparation_goals where id=goal and user_id=auth.uid();
 if u is null then raise exception 'Preparación no disponible.' using errcode='42501'; end if;
 select * into ctx from public.running_intake_contexts where preparation_goal_id=goal;
 if not found then return null; end if;
 for n in 0..3 loop
   ending:=last_sunday-n*7;
   declared_index:=case when ctx.recent_weeks_end_on>=ending and (ctx.recent_weeks_end_on-ending)%7=0 then (ctx.recent_weeks_end_on-ending)/7+1 end;
   declared_days:=ctx.running_days_last_four_weeks[declared_index]; declared_minutes:=ctx.running_minutes_last_four_weeks[declared_index];
   -- Un cierre parcial conserva los segundos observados. Recuperaciones no son carrera.
   -- Son datos de carga del deportista; no convierten marcas entre preparaciones.
   select count(distinct public.workout_performed_on_v1(e))::int,coalesce(ceil(sum(s.actual_duration_seconds)/60.0),0)::int into days,minutes
   from public.workout_executions e join public.workout_execution_sets s on s.execution_id=e.id
   where e.user_id=u and e.status in ('completed','abandoned') and s.block_format='running'
     and s.status='completed' and s.actual_duration_seconds>0
     and public.workout_performed_on_v1(e) between ending-6 and ending;
   -- Una declaración de esa misma semana puede incluir trabajo fuera de la app.
   -- max evita sumar dos veces las mismas sesiones; la edición permite completar lo externo.
   source:=case when days>0 and declared_days is not null then 'observed_and_declared'
     when days>0 then 'observed' when declared_days is not null then 'declared' else 'unknown' end;
   day_values:=day_values||to_jsonb(greatest(days,coalesce(declared_days,0)));
   minute_values:=minute_values||to_jsonb(greatest(minutes,coalesce(declared_minutes,0)));
   sources:=sources||to_jsonb(source);
 end loop;
 return to_jsonb(ctx)||jsonb_build_object('running_days_last_four_weeks',day_values,'running_minutes_last_four_weeks',minute_values,
   'recent_weeks_end_on',last_sunday,'recent_load_sources',sources,'observed_load_policy_version','running_observed_context_v1');
end $$;
revoke all on function public.running_context_observed_v1(uuid,date) from public,anon,authenticated;

create function public.get_running_intake_context_observed(p_goal_id uuid) returns jsonb
language sql stable security definer set search_path='' as $$
 select public.running_context_observed_v1(p_goal_id,current_date)
$$;
revoke all on function public.get_running_intake_context_observed(uuid) from public,anon;
grant execute on function public.get_running_intake_context_observed(uuid) to authenticated;
