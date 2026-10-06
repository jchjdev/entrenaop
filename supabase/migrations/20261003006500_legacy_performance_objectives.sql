begin;
-- Protocolo añadido sin reinterpretar ninguna de las 63 variantes de catálogo v1.
insert into public.exercise_training_profiles(code,definition_version,catalog_version,definition)
values('slalom_ball_course_16m',1,2,$profile${"code": "slalom_ball_course_16m", "name": "Circuito de agilidad de 16 m con pelota", "family": "slalom_ball_course", "movement_patterns": ["change_of_direction"], "movement_modes": ["locomotor"], "body_regions": ["lower_body", "trunk"], "laterality": "bilateral", "technical_level": "intermediate", "required_equipment": ["cones", "measuring_tape", "tennis_ball", "chalk"], "optional_equipment": [], "primary_muscles": ["quadriceps", "gluteals", "plantar_flexors"], "secondary_muscles": ["trunk_stabilizers"], "measurement_options": [{"mode": "TIME_FOR_COURSE", "load_modes": ["bodyweight"]}], "progression_axes": ["sets", "rest", "technique", "specificity"], "notes": "Recorrido DEF/15/2026: salida sentado de espaldas, manos en rodillas; señal de salida, eslalon de siete conos alternos en corredor de 16 × 2 m, recoger pelota y volver recto por dentro. Desplazar conos, perder la pelota o alterar el recorrido invalida el intento. Registrar tiempo bruto; el baremo aplica su propio redondeo."}$profile$::jsonb);
insert into public.exercises(name,description,muscle_groups,equipment,difficulty,exercise_type,is_public,created_by,origin,training_profile_code,training_profile_version)
values('Circuito de agilidad de 16 m con pelota','Recorrido DEF/15/2026: salida sentado de espaldas, manos en rodillas; señal de salida, eslalon de siete conos alternos en corredor de 16 × 2 m, recoger pelota y volver recto por dentro. Desplazar conos, perder la pelota o alterar el recorrido invalida el intento. Registrar tiempo bruto; el baremo aplica su propio redondeo.',array['cuádriceps','glúteos','core'],array['conos','cinta métrica','pelota de tenis','tiza'],'intermedio','duración',true,null,'system','slalom_ball_course_16m',1);

create table public.performance_legacy_objectives (
 program_id text not null references public.preparation_programs(id),
 objective_key text not null, name text not null, profile_code text not null,
 profile_version int not null, measurement text not null, protocol_key text not null,
 protocol_version int not null, parameters jsonb not null, instructions text not null,
 max_age_exclusive int, primary key(program_id,objective_key),
 foreign key(profile_code,profile_version) references public.exercise_training_profiles(code,definition_version)
);
alter table public.performance_legacy_objectives enable row level security;
revoke all on public.performance_legacy_objectives from public,anon,authenticated;
grant select on public.performance_legacy_objectives to authenticated;
create policy performance_legacy_read on public.performance_legacy_objectives for select to authenticated using(true);
insert into public.performance_legacy_objectives
select program_id,objective_key,name,profile_code,1,measurement,protocol_key,1,parameters,instructions,
 case when program_id='fas_periodic_assessment' and objective_key='legacy:agility_speed_circuit' then 45 end
from (values('fas_periodic_assessment'),('armed_forces_troop_entry')) programs(program_id)
cross join (values
 ('legacy:upper_body_push_ups_2_min','Flexiones en dos minutos','push_up_standard','REPS_IN_TIME','def_15_2026_push_ups','{"fixed_duration_seconds":120}'::jsonb,'Ventana máxima de 120 s. Manos bajo los hombros, piernas juntas y cuerpo alineado; barbilla sobre almohadilla de 10 cm y extensión simultánea completa. Una sola pausa en posición inicial; una segunda pausa termina la prueba. Trabajo submáximo: no es una marca máxima oficial.'),
 ('legacy:abdominal_plank','Plancha abdominal','front_plank_forearms','DURATION','def_15_2026_plank','{}'::jsonb,'Antebrazos apoyados, codos bajo hombros, piernas juntas y cuerpo alineado, pies y manos fijos. Trabajo: terminar al perder la postura; no convertir segundos inválidos en tiempo de referencia.'),
 ('legacy:agility_speed_circuit','Circuito de agilidad y velocidad','slalom_ball_course_16m','TIME_FOR_COURSE','def_15_2026_agility','{}'::jsonb,'Recorrido DEF/15/2026: salida sentado de espaldas, manos en rodillas; señal de salida, eslalon de siete conos alternos en corredor de 16 × 2 m, recoger pelota y volver recto por dentro. Desplazar conos, perder la pelota o alterar el recorrido invalida el intento. Registrar tiempo bruto; el baremo aplica su propio redondeo.')
) objectives(objective_key,name,profile_code,measurement,protocol_key,parameters,instructions);
commit;
