begin;
create function pg_temp.exposure_v3(p jsonb, day date, effort numeric default 4) returns jsonb language sql as $$
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
declare profile jsonb; iso jsonb; cod jsonb; ref jsonb; p jsonb; q jsonb; h jsonb:='[]';
 wk date:=date '2026-10-05'; months int; n int; path jsonb; selected jsonb; placement jsonb;
begin
 select definition into profile from public.exercise_training_profiles where code='push_up_standard' and definition_version=1;
 select definition into iso from public.exercise_training_profiles where code='front_plank_forearms' and definition_version=1;
 select definition into cod from public.exercise_training_profiles where code='slalom_ball_course_16m' and definition_version=1;
 ref:='{"id":"push","reference_kind":"performed_set","observed_on":"2026-10-04","current_capacity_confirmed":true,"reported_rir":3,"targets":[55],"rest_seconds":0,"frequency":2,"task":{"schema_version":1,"exercise_code":"push_up_standard","exercise_version":1,"protocol_key":"fixture","protocol_version":1,"setup_key":"standard:fixture","measurement":"REPS","load_mode":"bodyweight","policy_version":"reference_v2","target_value":55,"intent":"work"}}';
 p:=public.performance_task_v3(ref,profile,h,wk,wk+90);
 if p->>'phase'<>'base' or p->'dose'->'targets'<>'[27,27]'::jsonb then raise exception 'Inicio v3 inseguro: %',p; end if;
 h:=jsonb_build_array(pg_temp.exposure_v3(p,wk,3),pg_temp.exposure_v3(p,wk+2,3));
 q:=public.performance_task_v3(ref,profile,h,wk+7,wk+90,p,wk);
 if q->>'phase'<>'development' or q->>'outcome'<>'progress' or q->'block'->>'entered_on'<>(wk+7)::text then raise exception 'No transita por tolerancia: %',q; end if;
 q:=public.performance_task_v3(ref,profile,'[]',wk+7,wk+90,p,wk);
 if q->>'phase'<>'base' then raise exception 'Calendario inventa dominio'; end if;
 h:=jsonb_build_array(pg_temp.exposure_v3(p,wk,3),pg_temp.exposure_v3(p,wk+2,0));
 q:=public.performance_task_v3(ref,profile,h,wk+7,wk+90,p,wk);
 if q->>'phase'<>'base' or q->>'outcome'<>'reduce' then raise exception 'Ignora dificultad: %',q; end if;
 selected:=public.performance_select_v3(jsonb_build_array(
   p||'{"reference_id":"z","objective_key":"push","role":"support","exercise_code":"push_up_standard","phase":"development"}',
   p||'{"reference_id":"a","objective_key":"push","role":"support","exercise_code":"bench_press_barbell","phase":"development"}',
   p||'{"reference_id":"b","objective_key":"push","role":"support","exercise_code":"push_up_weighted","phase":"development"}'));
 if jsonb_array_length(selected)<>2 or selected->0->>'reference_id'<>'z' or selected->1->>'reference_id'<>'b' then raise exception 'Selección duplica apoyos o pierde especificidad: %',selected; end if;
 selected:=jsonb_build_array(selected->0||'{"required_for_objective":true}',selected->1||'{"required_for_objective":false}');
 placement:=public.performance_place_v3(selected,'{"1":60,"3":60,"5":60}','[]','[]',0,wk,wk+90);
 if not exists(select 1 from jsonb_each(placement->'days') d where jsonb_array_length(d.value->'work')=2) then raise exception 'No compone principal y apoyo conocido: %',placement; end if;
 p:=public.performance_task_v3(ref,profile,'[]',wk,wk+21);
 q:=p||jsonb_build_object('reference_id','push','optional',false,'block',(p->'block')||'{"comparable_tolerated_exposures":2}');
 selected:=public.performance_controls_v3(jsonb_build_array(jsonb_build_object('date',wk,'work',jsonb_build_array(q)),jsonb_build_object('date',wk+2,'work',jsonb_build_array(q))),
  '{"proposals":[{"reference_id":"push","phase":"development"}]}');
 if selected->0->'work'->0->'control'->>'kind'<>'submaximal_work' or selected->1->'work'->0 ? 'control'
 or selected->0->'work'->0->'dose' is distinct from p->'dose' then raise exception 'Control añade volumen, se repite o altera dosis'; end if;
 for months in select unnest(array[1,2,3,4,6,12]) loop
  path:=public.performance_program_path_v3(wk,(wk+make_interval(months=>months))::date,wk,'[]');
  if jsonb_array_length(path->'stages')<2 then raise exception 'Horizonte sin recorrido'; end if;
  h:='[]'; p:='{}';
  for n in 0..(((wk+make_interval(months=>months))::date-wk)/7) loop
   q:=public.performance_task_v3(ref,profile,h,wk+n*7,(wk+make_interval(months=>months))::date,p,wk);
   if q->>'status'<>'ready' or not public.valid_performance_prescription(q->'dose'->'task') then raise exception 'Falla horizonte %, semana %: %',months,n,q; end if;
   if q->'dose'->'task'->>'intent'='test' then raise exception 'Test máximo implícito'; end if;
   h:=h||jsonb_build_array(pg_temp.exposure_v3(q,wk+n*7,3),pg_temp.exposure_v3(q,wk+n*7+2,3)); p:=q;
  end loop;
 end loop;
 -- Los modelos conservan su unidad y su estímulo al recorrer la fecha real.
 for profile,ref in select iso,ref||jsonb_build_object('reported_rir',null,'reported_rpe',6,
    'task',(ref->'task')||'{"exercise_code":"front_plank_forearms","measurement":"DURATION"}')
   union all select cod,ref||jsonb_build_object('reported_rir',null,'targets','[13]'::jsonb,
    'task',(ref->'task')||'{"exercise_code":"slalom_ball_course_16m","measurement":"TIME_FOR_COURSE","target_value":13}') loop
  for months in select unnest(array[1,2,3,4,6,12]) loop
   h:='[]'; p:='{}';
   for n in 0..(((wk+make_interval(months=>months))::date-wk)/7) loop
    q:=public.performance_task_v3(ref,profile,h,wk+n*7,(wk+make_interval(months=>months))::date,p,wk);
    if q->>'status'<>'ready' or not public.valid_performance_prescription(q->'dose'->'task') then raise exception 'Unidad/contrato perdido %, mes %, semana %: %',profile->>'code',months,n,q; end if;
    if q->'dose'->'task'->>'intent'='test' then raise exception 'Plancha/COD convertidos en máximo'; end if;
    h:=h||jsonb_build_array(pg_temp.exposure_v3(q,wk+n*7,6),pg_temp.exposure_v3(q,wk+n*7+2,6)); p:=q;
   end loop;
   if p->>'phase'<>'taper' then raise exception 'No alcanza puesta a punto %, %',profile->>'code',months; end if;
  end loop;
 end loop;
 if has_function_privilege('authenticated','public.performance_select_v3(jsonb)','execute')
 or has_function_privilege('anon','public.performance_task_v3(jsonb,jsonb,jsonb,date,date,jsonb,date)','execute') then raise exception 'Política interna pública'; end if;
end $$;
select 'Fases por respuesta, apoyos limitados, contratos y seis horizontes: OK' result;
rollback;
