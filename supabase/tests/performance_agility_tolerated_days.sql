begin read only;

do $$
declare
 wk date:=date '2026-10-19'; profile jsonb; reference jsonb; previous jsonb; dose jsonb;
 tolerated_sets jsonb; history jsonb; plan jsonb; scenario record;
begin
 select definition into strict profile from public.exercise_training_profiles
 where code='slalom_ball_course_16m' and definition_version=1;
 reference:='{"id":"fixture-cod","role":"specific","reference_kind":"performed_set",
  "observed_on":"2026-09-01","current_capacity_confirmed":true,"targets":[15.5],"frequency":1,
  "task":{"exercise_code":"slalom_ball_course_16m","exercise_version":1,
   "protocol_key":"def_15_2026_agility","protocol_version":1,"setup_key":"standard:fixture",
   "measurement":"TIME_FOR_COURSE","load_mode":"bodyweight","target_value":15.5,"intent":"practice"}}';
 previous:=public.performance_task_v5(reference,profile,'[]',wk-42,wk+90)||'{"phase":"development"}';
 dose:=previous->'dose';
 select jsonb_agg(jsonb_build_object('status','completed','prescription',dose->'task',
   'result','{"succeeded":true,"technique_valid":true,"conditions_confirmed":true,"tolerated":true,"stop_reason":"none"}'::jsonb))
 into tolerated_sets from jsonb_array_elements(dose->'targets');
 for scenario in select * from (values
  ('dos sesiones en un solo día',90,array[3,3],null::int,null::int,'COD-T01'),
  ('una sesión reciente y otra antigua',90,array[3,30],null,null,'COD-T01'),
  ('dos fechas distintas recientes',90,array[3,5],null,null,'COD-SP01'),
  ('dificultad posterior a dos días tolerados',90,array[5,7],3,null,'COD-T01'),
  ('dificultad en la misma fecha que una tolerada',90,array[3,5],3,null,'COD-T01'),
  ('esfuerzo o técnica sin acreditar en la última fecha',90,array[5,7],null,3,'COD-T01'),
  ('dos fechas distintas en especificidad',20,array[3,5],null,null,'COD-SP02'),
  ('dificultad posterior antes del recorrido completo',20,array[5,7],3,null,'COD-T01'),
  ('dificultad el mismo día antes del recorrido completo',20,array[3,5],3,null,'COD-T01')
 ) as cases(label,days_until_exam,good_ages,bad_age,unknown_age,expected) loop
  select jsonb_agg(jsonb_build_object('completed_on',wk-sample.age,'dose',dose,
    'status',case when sample.signal='difficulty' then 'abandoned' else 'completed' end,
    'abandonment_reason',case when sample.signal='difficulty' then 'too_difficult' end,
    'sets',case when sample.signal='tolerated' then tolerated_sets else '[]'::jsonb end)) into history
  from (
   select age,'tolerated' as signal from unnest(scenario.good_ages) age
   union all select scenario.bad_age,'difficulty' where scenario.bad_age is not null
   union all select scenario.unknown_age,'unknown' where scenario.unknown_age is not null
  ) sample;
  plan:=public.performance_task_v5(reference,profile,history,wk,wk+scenario.days_until_exam,previous,wk-42);
  if plan->>'status' is distinct from 'ready' or plan#>>'{dose,task,stimulus_code}' is distinct from scenario.expected then
   raise exception 'Agilidad (%): esperado %, recibido %',scenario.label,scenario.expected,plan#>>'{dose,task,stimulus_code}';
  end if;
 end loop;
end $$;

select 'Agilidad: progresión por dos fechas recientes sin respuestas adversas ni inconclusas' as result;
rollback;
