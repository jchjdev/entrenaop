begin;
create function pg_temp.frequency_exposure(p jsonb,day date) returns jsonb language sql as $$
select jsonb_build_object('completed_on',day,'status','completed','dose',p->'dose','sets',
 (select jsonb_agg(jsonb_build_object('status','completed','prescription',p->'dose'->'task',
 'result',jsonb_strip_nulls(jsonb_build_object('value',v,'succeeded',true,'rir',4,'rpe',6,
 'actual_duration_seconds',p->'dose'->'task'->'fixed_duration_seconds',
 'load_kg',p->'dose'->'task'->'external_load_kg',
 'technique_valid',true,'tolerated',true,'conditions_confirmed',true,'stop_reason','none'))))
 from jsonb_array_elements(p->'dose'->'targets') v))
$$;
do $$
declare profile jsonb; ref jsonb; p jsonb; q jsonb; h jsonb; fallback jsonb; name text; measurement text;
 wk date:=date '2026-10-05'; total numeric; after_total numeric;
begin
 for name,measurement in values ('push_up_standard','REPS'),('bench_press_barbell','LOAD_REPS'),('push_up_standard','REPS_IN_TIME'),('front_plank_forearms','DURATION'),('slalom_ball_course_16m','TIME_FOR_COURSE') loop
 select definition into profile from public.exercise_training_profiles where code=name and definition_version=1;
 ref:=jsonb_build_object('id',name,'role','specific','reference_kind','performed_set','observed_on',wk-1,
   'current_capacity_confirmed',true,'reported_rir',3,'reported_rpe',6,'targets','[40]'::jsonb,'frequency',1,'rep_min',4,'rep_max',6,
   'task',jsonb_build_object('schema_version',1,'exercise_code',name,'exercise_version',1,'protocol_key','fixture',
     'protocol_version',1,'setup_key','standard:fixture','measurement',measurement,'load_mode',case when measurement='LOAD_REPS' then 'external_load' else 'bodyweight' end,
     'external_load_kg',case when measurement='LOAD_REPS' then 30 end,'fixed_duration_seconds',case when measurement='REPS_IN_TIME' then 120 end,'target_value',40,'intent','work'));
 p:=public.performance_task_v4(ref,profile,'[]',wk,wk+90);
 h:=jsonb_build_array(pg_temp.frequency_exposure(p,wk),pg_temp.frequency_exposure(p,wk+7));
 -- Agilidad cambia de tarea tras consolidar técnica: no subir frecuencia a la vez.
 q:=public.performance_task_v4(ref,profile,h,wk+14,wk+90,p,wk);
 if name='slalom_ball_course_16m' then
   if q->'dose'->'task'->>'stimulus_code'<>p->'dose'->'task'->>'stimulus_code' and q->>'frequency'<>'1' then raise exception 'Cambia tarea y frecuencia juntas'; end if;
   -- Con el sector ya conocido, repartir intentos conserva su medición.
   p:=q;
   h:=jsonb_build_array(pg_temp.frequency_exposure(p,wk+14),pg_temp.frequency_exposure(p,wk+21));
   q:=public.performance_task_v4(ref,profile,h,wk+28,wk+90,p,wk);
   if q->>'frequency'<>'2' or jsonb_array_length(q->'dose'->'targets')*2<>jsonb_array_length(p->'dose'->'targets')
     or q->'dose'->'targets'->0 is distinct from p->'dose'->'targets'->0 then raise exception 'No distribuye intentos técnicos conocidos: %',q; end if;
   continue;
 end if;
 if q->>'frequency'<>'2' or q->>'outcome'<>'redistribute' then raise exception 'No redistribuye desde resultados: %',q; end if;
 select sum(value::numeric) into total from jsonb_array_elements_text(p->'dose'->'targets');
 select 2*sum(value::numeric) into after_total from jsonb_array_elements_text(q->'dose'->'targets');
 if after_total>total or q->'dose'->'task'->'target_rir' is distinct from p->'dose'->'task'->'target_rir'
   or q->'dose'->'task'->'external_load_kg' is distinct from p->'dose'->'task'->'external_load_kg'
   or q->'dose'->'task'->'fixed_duration_seconds' is distinct from p->'dose'->'task'->'fixed_duration_seconds' then raise exception 'Duplica volumen o intensidad'; end if;
 fallback:=public.performance_frequency_candidate_v1(q,1);
 if fallback->'dose' is distinct from p->'dose' or fallback->>'frequency'<>'1' then raise exception 'Una exposición queda a medias'; end if;
 h:=jsonb_build_array(pg_temp.frequency_exposure(q,wk+14),pg_temp.frequency_exposure(q,wk+16));
 fallback:=public.performance_task_v4(ref,profile,h,wk+21,wk+90,q,wk);
 if fallback->>'frequency'<>'2' then raise exception 'La referencia inicial reinicia la frecuencia'; end if;
 fallback:=public.performance_task_v4(ref,profile,h,wk+84,wk+90,q,wk);
 if fallback->>'frequency'='2' then raise exception 'Sube frecuencia en puesta a punto'; end if;
 h:=jsonb_build_array(pg_temp.frequency_exposure(p,wk),pg_temp.frequency_exposure(p,wk+7)||'{"abandonment_reason":"lack_of_time"}');
 fallback:=public.performance_task_v4(ref,profile,h,wk+14,wk+90,p,wk);
 if fallback->>'frequency'<>'1' then raise exception 'Promueve con falta de tiempo'; end if;
 h:=jsonb_build_array(pg_temp.frequency_exposure(p,wk),pg_temp.frequency_exposure(p,wk+2));
 if public.performance_task_v4(ref,profile,h,wk+7,wk+90,p,wk)->>'frequency'<>'1' then raise exception 'Dos cierres de una semana disparan frecuencia'; end if;
 h:=jsonb_build_array(pg_temp.frequency_exposure(p,wk),pg_temp.frequency_exposure(p,wk+7)||'{"abandonment_reason":"too_difficult"}');
 if public.performance_task_v4(ref,profile,h,wk+14,wk+90,p,wk)->>'frequency'<>'1' then raise exception 'Promueve con dificultad'; end if;
 end loop;
end $$;
rollback;
