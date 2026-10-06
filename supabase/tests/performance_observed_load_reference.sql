begin;
select set_config('request.jwt.claim.sub',(select user_id::text from public.admin_permissions limit 1),true);
update public.preparation_goals set status='archived',archived_at=now() where user_id=auth.uid() and status='active';
do $$
declare g uuid; rid uuid; r jsonb; p jsonb; profile jsonb; wk date:=current_date+8-extract(isodow from current_date)::int;
begin
 insert into public.preparation_goals(user_id,program_id,target_date) values(auth.uid(),'fas_periodic_assessment',current_date+90) returning id into g;
 rid:=public.save_performance_reference(g,jsonb_build_object('goal_code','bench_press_barbell','goal_version',1,'goal_measurement','MAX_LOAD',
  'reference_kind','performed_set','observed_on',current_date,'current_capacity_confirmed',true,'targets','[12]'::jsonb,'reported_rir',3,'frequency',1,
  'task','{"exercise_code":"bench_press_barbell","exercise_version":1,"protocol_key":"bench_work","protocol_version":1,"setup_key":"standard:bench_work","measurement":"LOAD_REPS","load_mode":"external_load","external_load_kg":40,"target_value":12,"intent":"work"}'::jsonb));
 select reference into r from public.performance_training_references where id=rid;
 if r->'targets'<>'[12]'::jsonb or (r->>'rep_max')::int<>6 then raise exception 'Confunde medición y rango futuro'; end if;
 select definition into profile from public.exercise_training_profiles where code='bench_press_barbell' and definition_version=1;
 p:=public.performance_task_v2_1(r,profile,'[]',wk,wk+90);
 if p->>'status'<>'ready' or p->'dose'->'targets'<>'[6,6]'::jsonb then raise exception 'No pauta carga desde la medición real: %',p; end if;
end $$;
select 'Serie con carga observada fuera de la futura horquilla: OK' as result;
rollback;
