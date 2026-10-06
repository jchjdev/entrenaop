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
 q:=public.performance_task_v2(ref,profile,'[]',week,week+90,p||'{"weeks_since_review":99}');
 if (q->>'review_due')::boolean then raise exception 'Pide revisión solo por contador de semanas'; end if;
 q:=public.performance_task_v2(ref,profile,'[]',week,week+20,p);
 if not (q->>'review_due')::boolean or q->>'review_reason' not like '%No exige un test%' then raise exception 'No distingue transición y test'; end if;
 h:=jsonb_build_array(pg_temp.exposure(p,week,0));
 q:=public.performance_task_v2(ref,profile,h,week+7,week+90,p);
 if q->>'outcome'<>'reduce' or not (q->>'review_due')::boolean or q->>'review_reason' not like '%No añadir un test%' then raise exception 'Dificultad reciente sin revisión de dosis'; end if;
 if q->'dose'->'task'->>'intent'='test' then raise exception 'Convierte una reducción en máximo'; end if;
end $$;
select 'Revisión por señales y fase, nunca por contador ni test máximo implícito: OK' as result;
rollback;
