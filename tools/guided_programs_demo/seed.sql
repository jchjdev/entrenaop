-- Datos de demostración solicitados por Javier. No es una migración ni un seed global.
-- Ejecutar mediante run.ps1, que fija exclusivamente el proyecto de desarrollo.
begin;
select pg_advisory_xact_lock(hashtextextended('entrenaop.guided_demo.v1',0));
select set_config('request.jwt.claim.sub',(
  select user_id::text from public.admin_permissions order by granted_at,user_id limit 1
),true);
set local role authenticated;

do $$
declare
  spec jsonb; movement jsonb; exercises jsonb; sets jsonb; payload jsonb;
  sessions jsonb := '{}'::jsonb; warmups jsonb := '{}'::jsonb;
  exercise uuid; template uuid; warmup uuid; program uuid; slots jsonb; phases jsonb;
  existing integer;
begin
  if not coalesce(public.is_admin(),false) then
    raise exception 'Se necesita un administrador existente; no se crean cuentas ni permisos.';
  end if;
  select count(*) into existing from public.guided_programs
    where content->>'demo_key' in ('guided-demo-v1-guide','guided-demo-v1-phased');
  -- La transacción publica ambos o ninguno. Repetir el script no duplica ni reedita versiones.
  if existing=2 then return; end if;
  if existing<>0 then raise exception 'Demo parcial: revisar el contenido antes de repetir.'; end if;

  for spec in select value from jsonb_array_elements($specs$[
    {"key":"push","name":"Demo · Activación de empuje","moves":[["push_up_incline",1,6,30]]},
    {"key":"pull","name":"Demo · Activación de tirón","moves":[["pull_up_assisted_band",1,5,45],["row_cable",1,8,30]]},
    {"key":"legs","name":"Demo · Activación de pierna","moves":[["squat_bodyweight",1,8,30],["glute_bridge",1,8,30]]}
  ]$specs$::jsonb) loop
    exercises := '[]'::jsonb;
    for movement in select value from jsonb_array_elements(spec->'moves') loop
      select id into strict exercise from public.exercises
        where is_public and training_profile_code=movement->>0;
      sets := jsonb_build_array(jsonb_build_object('target_reps',(movement->>2)::integer,
        'target_rir',4,'rest_after_seconds',(movement->>3)::integer));
      exercises := exercises||jsonb_build_array(jsonb_build_object('exercise_id',exercise,'sets',sets));
    end loop;
    payload := jsonb_build_object('name',spec->>'name','estimated_duration_minutes',4,
      'description','Calentamiento opcional de demostración. Realiza movimientos suaves; en la polea utiliza una carga ligera.',
      'blocks',jsonb_build_array(jsonb_build_object('name','Activación suave','format','straight_sets',
        'rounds',1,'rest_after_seconds',0,'exercises',exercises)));
    warmup := public.save_guided_warmup(payload);
    warmups := warmups||jsonb_build_object(spec->>'key',warmup);
  end loop;

  for spec in select value from jsonb_array_elements($specs$[
    {"key":"push","name":"Demo · Empuje","minutes":30,"warmup":"push",
     "description":"Banca, hombro y flexiones. Elige cargas que permitan terminar con unas 3 repeticiones en reserva.",
     "moves":[["bench_press_barbell",3,8,90],["overhead_press_dumbbell",2,10,90],["push_up_standard",2,8,90]]},
    {"key":"pull","name":"Demo · Tirón","minutes":25,"warmup":"pull",
     "description":"Dominadas con banda y remo. Ajusta la asistencia y la carga para dejar unas 3 repeticiones en reserva.",
     "moves":[["pull_up_assisted_band",3,6,120],["row_cable",3,10,90]]},
    {"key":"legs","name":"Demo · Pierna","minutes":25,"warmup":"legs",
     "description":"Sentadilla, puente y gemelos con peso corporal. Mantén una ejecución controlada y registra lo realizado.",
     "moves":[["squat_bodyweight",3,10,90],["glute_bridge",3,12,90],["calf_raise_bilateral",2,15,60]]},
    {"key":"base","name":"Demo · Dominadas · Base","minutes":20,"warmup":"pull",
     "description":"Dominadas asistidas y remo. Ajusta la banda para completar las repeticiones con margen.",
     "moves":[["pull_up_assisted_band",3,6,120],["row_cable",2,10,90]]},
    {"key":"progress","name":"Demo · Dominadas · Progreso","minutes":20,"warmup":"pull",
     "description":"Series cortas de dominadas pronas y remo. Comprueba que puedes realizar las repeticiones con control.",
     "moves":[["pull_up_pronated",3,3,120],["row_cable",2,10,90]]},
    {"key":"consolidation","name":"Demo · Dominadas · Consolidación","minutes":25,"warmup":"pull",
     "description":"Conserva los ejercicios y aumenta las repeticiones de dominadas. Registra tu resultado real sin forzar el objetivo.",
     "moves":[["pull_up_pronated",3,5,120],["row_cable",2,10,90]]}
  ]$specs$::jsonb) loop
    exercises := '[]'::jsonb;
    for movement in select value from jsonb_array_elements(spec->'moves') loop
      select id into strict exercise from public.exercises
        where is_public and training_profile_code=movement->>0;
      select jsonb_agg(jsonb_build_object('target_reps',(movement->>2)::integer,
        'target_rir',3,'rest_after_seconds',(movement->>3)::integer) order by n)
        into sets from generate_series(1,(movement->>1)::integer) n;
      exercises := exercises||jsonb_build_array(jsonb_build_object('exercise_id',exercise,'sets',sets));
    end loop;
    payload := jsonb_build_object('name',spec->>'name','estimated_duration_minutes',(spec->>'minutes')::integer,
      'description',spec->>'description','blocks',jsonb_build_array(jsonb_build_object(
        'name','Trabajo principal','format','straight_sets','rounds',1,'rest_after_seconds',0,'exercises',exercises)));
    template := public.create_admin_workout_draft(null,payload);
    perform public.publish_admin_workout_draft(template);
    sessions := sessions||jsonb_build_object(spec->>'key',jsonb_build_object(
      'template_id',template,'name',spec->>'name','warmup_id',warmups->>(spec->>'warmup'),
      'rest',jsonb_build_object('min_seconds',60,'max_seconds',180)));
  end loop;

  slots := jsonb_build_array(sessions->'push',sessions->'pull',sessions->'legs');
  program := public.save_guided_program(jsonb_build_object(
    'demo_key','guided-demo-v1-guide','name','Demo · Empuje, tirón y pierna','mode','guide',
    'description','Tres sesiones para probar una guía repetible. Conserva los ejercicios y registra tus pesos y repeticiones. Contenido de demostración para probar la app.',
    'audience','Personas que ya conocen los ejercicios básicos de gimnasio.',
    'equipment','Banco, barra y discos, mancuernas, barra de dominadas, banda de asistencia y polea de remo.',
    'phases',jsonb_build_array(jsonb_build_object('name','Rutina habitual','duration_weeks',null,
      'instructions','Realiza empuje, tirón y pierna en el orden que necesites y repite el ciclo. Ajusta las cargas para mantener el RIR indicado. Puedes omitir el calentamiento y ajustar el descanso entre 60 y 180 segundos.',
      'sessions',slots))));
  perform public.set_guided_program_status(program,'published');

  phases := jsonb_build_array(
    jsonb_build_object('name','1 · Base','duration_weeks',2,
      'instructions','Repite la sesión con asistencia. Cuando completes las series con control y margen, confirma el avance. Dos semanas es una referencia; el calendario no cambia de fase.',
      'sessions',jsonb_build_array(sessions->'base')),
    jsonb_build_object('name','2 · Progreso','duration_weeks',2,
      'instructions','Practica series cortas de dominadas pronas. Confirma el avance cuando puedas repetir las tres series con buena ejecución y margen. Puedes permanecer en esta fase el tiempo que necesites.',
      'sessions',jsonb_build_array(sessions->'progress')),
    jsonb_build_object('name','3 · Consolidación','duration_weeks',2,
      'instructions','Mantén los ejercicios y prueba cinco repeticiones por serie. Registra las que realmente hagas. Al completar esta etapa, confirma el final; después puedes repetir el programa.',
      'sessions',jsonb_build_array(sessions->'consolidation')));
  program := public.save_guided_program(jsonb_build_object(
    'demo_key','guided-demo-v1-phased','name','Demo · Mejora de dominadas','mode','phased',
    'description','Tres fases y una sesión por fase: base asistida, series cortas y consolidación. Repite cada sesión antes de confirmar el avance. Contenido de demostración para probar la app.',
    'audience','Personas familiarizadas con dominadas asistidas que pueden practicar algunas repeticiones libres para las fases posteriores.',
    'equipment','Barra de dominadas, banda de asistencia y polea de remo.','phases',phases));
  perform public.set_guided_program_status(program,'published');
end $$;

select content->>'name' as name,content->>'mode' as mode,status,
  jsonb_array_length(content->'phases') as phases,
  (select count(*) from public.guided_program_links l where l.program_id=p.id) as sessions
from public.guided_programs p
where content->>'demo_key' in ('guided-demo-v1-guide','guided-demo-v1-phased') order by name;
rollback; -- @demo-transaction-end
