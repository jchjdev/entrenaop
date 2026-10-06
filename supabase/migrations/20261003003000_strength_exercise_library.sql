-- Materializa la biblioteca general: una variante no requiere una prueba oficial.
begin;

do $$
declare
  v_profile public.exercise_training_profiles%rowtype;
  v_draft record;
  v_count integer;
  v_type text;
  v_muscles text[];
  v_equipment text[];
  v_muscle_labels jsonb := '{
    "abdominals":"core","lateral_abdominals":"core","trunk_stabilizers":"core",
    "pectorals":"pecho","triceps":"tríceps","deltoids":"hombros",
    "anterior_deltoid":"hombros","shoulder_stabilizers":"hombros",
    "elbow_flexors":"bíceps","forearm_flexors":"antebrazos",
    "latissimus_dorsi":"espalda","scapular_retractors":"espalda",
    "spinal_extensors":"erectores espinales","quadriceps":"cuádriceps",
    "gluteals":"glúteos","gluteus_medius":"glúteos","hamstrings":"isquiotibiales",
    "gastrocnemius":"gemelos","soleus":"sóleo","plantar_flexors":"pantorrillas",
    "foot_stabilizers":"musculatura del pie","hip_flexors":"flexores de cadera"
  }';
  v_equipment_labels jsonb := '{
    "stable_support":"apoyo estable","weighted_vest":"chaleco lastrado",
    "barbell":"barra","bench":"banco","plates":"discos","rack":"rack",
    "dumbbell":"mancuerna","dumbbell_pair":"dos mancuernas",
    "adjustable_bench":"banco regulable","chest_press_machine":"máquina de press de pecho",
    "shoulder_press_machine":"máquina de press de hombros",
    "landmine_anchor":"anclaje landmine","pull_up_bar":"barra de dominadas",
    "neutral_grip_bar":"barra con agarre neutro","resistance_band":"banda de asistencia",
    "assisted_pull_up_machine":"máquina de dominadas asistidas",
    "dip_belt":"cinturón de lastre","lat_pulldown_machine":"máquina de jalón",
    "cable_row_machine":"polea de remo","row_machine":"máquina de remo de fuerza",
    "climbing_rope":"cuerda de trepa","anchored_rope":"cuerda anclada",
    "leg_press_machine":"prensa de piernas",
    "stable_step":"escalón estable","trap_bar":"barra hexagonal",
    "leg_curl_machine":"máquina de curl femoral","nordic_anchor":"anclaje para nordic",
    "cable_machine":"polea","stable_box":"cajón estable","cones":"conos",
    "measuring_tape":"cinta métrica","external_cue":"señal externa",
    "medicine_ball":"balón medicinal","kettlebell":"kettlebell"
  }';
begin
  if (select count(*) from public.exercise_training_profiles
      where catalog_version=1 and definition_version=1)<>63 then
    raise exception 'La biblioteca necesita las 63 definiciones de su catálogo.';
  end if;
  for v_profile in select * from public.exercise_training_profiles
      where catalog_version=1 and definition_version=1 order by code loop
    select count(*) into v_count from public.exercises
      where training_profile_code=v_profile.code and training_profile_version=v_profile.definition_version;
    if v_count>1 then raise exception 'Variante duplicada en la biblioteca: %',v_profile.code; end if;
    if v_count=1 then
      update public.exercises set is_public=true
      where training_profile_code=v_profile.code and training_profile_version=v_profile.definition_version;
      continue;
    end if;

    if exists(select 1 from jsonb_array_elements_text(
        (v_profile.definition->'primary_muscles')||(v_profile.definition->'secondary_muscles')) m
        where not v_muscle_labels ? m)
      or exists(select 1 from jsonb_array_elements_text(v_profile.definition->'required_equipment') e
        where not v_equipment_labels ? e) then
      raise exception 'Falta la traducción editorial de %.',v_profile.code;
    end if;
    select array_agg(distinct v_muscle_labels->>m order by v_muscle_labels->>m)
      into v_muscles from jsonb_array_elements_text(
        (v_profile.definition->'primary_muscles')||(v_profile.definition->'secondary_muscles')) m;
    select coalesce(array_agg(v_equipment_labels->>e order by v_equipment_labels->>e),array['peso corporal'])
      into v_equipment from jsonb_array_elements_text(v_profile.definition->'required_equipment') e;

    -- Tipo del formulario actual; no sustituye las mediciones del perfil.
    -- Saltos con REPS admiten series manuales, sin fingir un registro de altura.
    v_type:=case when exists(select 1 from jsonb_array_elements(v_profile.definition->'measurement_options') o
        where o->>'mode' in ('REPS','LOAD_REPS')) then 'repeticiones' else 'duración' end;
    select * into v_draft from public.normalize_exercise_draft(
      v_profile.definition->>'name',v_profile.definition->>'notes',null,
      v_muscles,v_equipment,
      case v_profile.definition->>'technical_level'
        when 'initial' then 'inicial' when 'intermediate' then 'intermedio' when 'advanced' then 'avanzado' end,
      v_type);
    insert into public.exercises(name,description,muscle_groups,equipment,difficulty,
        exercise_type,is_public,created_by,origin,training_profile_code,training_profile_version)
    values(v_draft.normalized_name,v_draft.normalized_description,v_draft.normalized_muscle_groups,
      v_draft.normalized_equipment,v_draft.normalized_difficulty,v_draft.normalized_exercise_type,
      true,null,'system',v_profile.code,v_profile.definition_version);
  end loop;
end $$;

commit;
