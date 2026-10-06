begin;
create function pg_temp.exposure(p jsonb, day date, effort numeric default 4) returns jsonb language sql as $$
select jsonb_build_object('completed_on',day,'status','completed','dose',p->'dose','sets',
 (select jsonb_agg(jsonb_build_object('status','completed','prescription',(p->'dose'->'task')||jsonb_build_object('target_value',v),
  'result',jsonb_strip_nulls(jsonb_build_object('value',case when p->'dose'->'task'->>'measurement'<>'PASS_FAIL' then v end,
   'succeeded',case when p->'dose'->'task'->>'measurement'='PASS_FAIL' then true end,
   'rir',case when p->'dose'->'task'->>'effort_mode'='rir' then effort end,
   'rpe',case when p->'dose'->'task'->>'effort_mode'='rpe' then effort end,
   'technique_valid',true,'tolerated',true,'conditions_confirmed',true,'stop_reason','none'))))
 from jsonb_array_elements(p->'dose'->'targets') v))
$$;
do $$
declare profile jsonb; iso jsonb; cod jsonb; pull jsonb; ref jsonb; plank jsonb; course jsonb;
 p jsonb; q jsonb; h jsonb; week date:=date '2026-10-05'; placement jsonb; months int; minutes int; calendar_end date; next_week date; previous jsonb;
begin
 select definition into profile from public.exercise_training_profiles where code='push_up_standard' and definition_version=1;
 select definition into iso from public.exercise_training_profiles where code='front_plank_forearms' and definition_version=1;
 select definition into cod from public.exercise_training_profiles where code='slalom_ball_course_16m' and definition_version=1;
 select definition into pull from public.exercise_training_profiles where code='pull_up_pronated' and definition_version=1;
 ref:='{"id":"push","reference_kind":"performed_set","observed_on":"2026-10-04","current_capacity_confirmed":true,"reported_rir":3,"targets":[55],"rest_seconds":0,"frequency":2,
 "task":{"schema_version":1,"exercise_code":"push_up_standard","exercise_version":1,"protocol_key":"fixture","protocol_version":1,"setup_key":"standard:fixture","measurement":"REPS","load_mode":"bodyweight","policy_version":"reference_v2","target_value":55,"intent":"work"}}';
 p:=public.performance_task_v2(ref,profile,'[]',week,week+90);
 if p->>'status'<>'ready' or p->'dose'->'targets'<>'[27,27]'::jsonb or (p->'dose'->'task'->>'target_rir')::int<>3 then raise exception 'Copia máximo o suma RIR: %',p; end if;
 if not public.valid_performance_prescription(p->'dose'->'task') then raise exception 'Contrato v2 rechazado: %',p; end if;
 q:=public.performance_task_v2(ref-'reference_kind',profile,'[]',week,week+90);
 if q->>'status'<>'needs_calibration' then raise exception 'Interpreta una referencia ambigua'; end if;
 q:=public.performance_task_v2(ref||'{"reference_kind":"capacity_test","targets":[2]}',profile,'[]',week,week+90);
 if q->'dose'->'targets'<>'[1,1]'::jsonb then raise exception 'Principiante sin alternativa razonable'; end if;
 if q->'dose'->'task'->>'effort_mode'<>'none' or q->'dose'->'task'->>'instructions' like '%tres repeticiones de margen%' then
  raise exception 'La práctica técnica exige un margen imposible'; end if;
 h:=jsonb_build_array(pg_temp.exposure(p,week),pg_temp.exposure(p,week+3));
 q:=public.performance_task_v2(ref,profile,h,week+7,week+90,p);
 if q->>'outcome'<>'progress' or q->'dose'->'targets'<>'[28,27]'::jsonb then raise exception 'No progresa tras dos exposiciones: %',q; end if;
 h:=jsonb_build_array(pg_temp.exposure(p,week,7),pg_temp.exposure(p,week+3,7));
 q:=public.performance_task_v2_1(ref,profile,h,week+7,week+90,p);
 if q->>'adaptation_rule'<>'repeated_very_easy_bounded_volume_v1'
  or (select sum(value::numeric) from jsonb_array_elements_text(q->'dose'->'targets'))>59
  or q->'dose'->'targets'='[28,27]'::jsonb then raise exception 'No adapta dos respuestas muy fáciles dentro de la cota: %',q; end if;
 h:=jsonb_build_array(pg_temp.exposure(p,week,1));
 q:=public.performance_task_v2(ref,profile,h,week+7,week+90,p);
 if q->>'outcome'<>'reduce' or (q->'dose'->'targets'->>0)::int>=27 then raise exception 'No reduce ante dificultad'; end if;
 h:=jsonb_build_array(pg_temp.exposure(p,week,null),pg_temp.exposure(p,week+3,null));
 q:=public.performance_task_v2(ref,profile,h,week+7,week+90,p);
 if q->>'outcome'='progress' then raise exception 'Dato desconocido produce progreso'; end if;
 plank:=jsonb_set(ref||'{"id":"plank","reference_kind":"capacity_test","reported_rir":null}', '{task}',(ref->'task')||'{"exercise_code":"front_plank_forearms","measurement":"DURATION"}');
 q:=public.performance_task_v2(plank,iso,'[]',week,week+90);
 if q->'dose'->'targets'<>'[27,27]'::jsonb or q->'dose'->'task'->>'effort_mode'<>'rpe'
  or q->'dose'->'task' ? 'target_rir' or not public.valid_performance_prescription(q->'dose'->'task') then raise exception 'Isometría confundida con repeticiones: %',q; end if;
 if not public.valid_performance_result('{"rpe":7}',q->'dose'->'task')
  or public.valid_performance_result('{"rpe":11}',q->'dose'->'task') then raise exception 'RPE no validado'; end if;
 course:=jsonb_set(ref||'{"id":"cod","reference_kind":"official_test","targets":[13.25],"reported_rir":null,"frequency":1}', '{task}',(ref->'task')||'{"exercise_code":"slalom_ball_course_16m","measurement":"TIME_FOR_COURSE"}');
 q:=public.performance_task_v2(course,cod,'[]',week,week+90);
 if q->'dose'->'task'->>'exercise_code'<>'cod_braking_10m' or q->'dose'->'task'->>'measurement'<>'PASS_FAIL'
  or not public.valid_performance_prescription(q->'dose'->'task') then raise exception 'Base pauta examen completo o inventa sector: %',q; end if;
 if not exists(select 1 from public.exercises where training_profile_code=q->'dose'->'task'->>'exercise_code' and is_public and origin='system') then raise exception 'Ejercicio no existe en biblioteca'; end if;
 q:=public.performance_task_v2(course,cod,'[]',week,week+20);
 if q->'dose'->'task'->>'stimulus_code'<>'COD-SP02' then raise exception 'Falta integración específica'; end if;
 -- Otra familia usa el mismo contrato, sin añadir ramas al coordinador.
 if pull is null then select definition into pull from public.exercise_training_profiles where code like 'pull_up%' limit 1; end if;
 q:=public.performance_task_v2(jsonb_set(ref||'{"targets":[8]}','{task,exercise_code}',pull->'code'),pull,'[]',week,week+90);
 if q->'dose'->'targets'<>'[4,4]'::jsonb then raise exception 'No reutiliza la estrategia en tirones'; end if;
 foreach months in array array[1,2,3,4,6,12] loop
  calendar_end:=(week+make_interval(months=>months))::date; next_week:=week; h:='[]'; previous:='{}';
  while next_week<calendar_end loop
   q:=public.performance_task_v2(ref,profile,h,next_week,calendar_end,previous);
   if q->>'status'<>'ready' or q<>public.performance_task_v2(ref,profile,h,next_week,calendar_end,previous) then raise exception 'Horizonte de % meses no determinista o inválido',months; end if;
   if calendar_end-next_week<=7 and (q->>'phase'<>'taper' or jsonb_array_length(q->'dose'->'targets')<>1) then raise exception 'Sin puesta a punto de calendario'; end if;
   h:=h||jsonb_build_array(pg_temp.exposure(q,next_week),pg_temp.exposure(q,next_week+3));
   previous:=q; next_week:=next_week+7;
  end loop;
 end loop;
 foreach minutes in array array[25,35,60] loop
  p:=p||'{"role":"specific","objective_key":"push"}';
  q:=public.performance_task_v2(plank,iso,'[]',week,week+90)||'{"role":"specific","objective_key":"plank"}';
  placement:=public.performance_place_v2(jsonb_build_array(p,q),jsonb_build_object('1',minutes,'3',minutes,'5',minutes),'[]','[]',0,week,week+90);
  if exists(select 1 from jsonb_each(placement->'days') d where (d.value->>'minutes')::int>minutes) then raise exception 'Supera tiempo de % minutos',minutes; end if;
  if exists(select 1 from jsonb_array_elements(placement->'missing') m where (m->>'scheduled')::int=0) then raise exception 'Pierde un objetivo compatible: %',placement; end if;
 end loop;
 q:=public.performance_task_v2(ref,profile,'[]',week,week+5,p);
 if jsonb_array_length(q->'dose'->'targets')<>1 or (q->>'frequency')::int<>1 then raise exception 'No reduce en puesta a punto'; end if;
 if has_function_privilege('authenticated','public.performance_task_v2(jsonb,jsonb,jsonb,date,date,jsonb)','execute') then raise exception 'Expone política interna'; end if;
end $$;
select 'Banco v2: semántica, submáximos, feedback, calendario, cobertura y extensión: OK' as result;
rollback;
