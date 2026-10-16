begin;

-- Las cargas manuales futuras también consumen recuperación.
create or replace function public.adaptive_control_prior_load_conflict_v1(test_day date,wk date) returns boolean
language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.scheduled_workouts sw
  where sw.user_id=auth.uid()
   and abs(public.workout_load_on_v1(sw)-test_day)<3 and sw.status not in ('cancelled','skipped')
   and (abs(public.workout_load_on_v1(sw)-test_day)<2 or sw.execution_id is null
    or exists(select 1 from public.running_week_sessions rs where rs.scheduled_workout_id=sw.id and rs.prescription->>'family'<>'E')
    or exists(select 1 from public.performance_week_work pw where pw.scheduled_workout_id=sw.id and pw.dose ? 'control')
    or exists(select 1 from public.workout_execution_sets es where es.execution_id=sw.execution_id and es.status='completed'
     and (es.actual_rpe>=8 or es.actual_rir<2 or (es.performance_result->>'rpe')::numeric>=8 or (es.performance_result->>'rir')::numeric<2))))
$$;

commit;
