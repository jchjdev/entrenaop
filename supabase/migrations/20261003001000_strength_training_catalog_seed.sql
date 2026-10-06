-- Generado a partir de supabase/catalogs/strength_exercises_v1.json.
-- Semilla de metadatos; no publica ejercicios que el ejecutor aún no mide.
begin;

insert into public.exercise_training_profiles(code,definition_version,catalog_version,definition)
select item->>'code',1,1,item from jsonb_array_elements($catalog$
[
  {
    "code": "push_up_incline",
    "name": "Flexión inclinada",
    "family": "push_up",
    "movement_patterns": [
      "horizontal_push"
    ],
    "movement_modes": [
      "dynamic"
    ],
    "body_regions": [
      "upper_body",
      "trunk"
    ],
    "laterality": "bilateral",
    "technical_level": "initial",
    "required_equipment": [
      "stable_support"
    ],
    "optional_equipment": [],
    "primary_muscles": [
      "pectorals",
      "triceps"
    ],
    "secondary_muscles": [
      "anterior_deltoid",
      "abdominals"
    ],
    "measurement_options": [
      {
        "mode": "REPS",
        "load_modes": [
          "bodyweight"
        ]
      }
    ],
    "progression_axes": [
      "reps",
      "sets",
      "rest",
      "technique",
      "lever"
    ],
    "notes": "Registrar altura del apoyo; cambiarla modifica la variante comparable."
  },
  {
    "code": "push_up_standard",
    "name": "Flexión estándar",
    "family": "push_up",
    "movement_patterns": [
      "horizontal_push"
    ],
    "movement_modes": [
      "dynamic"
    ],
    "body_regions": [
      "upper_body",
      "trunk"
    ],
    "laterality": "bilateral",
    "technical_level": "initial",
    "required_equipment": [],
    "optional_equipment": [
      "push_up_handles"
    ],
    "primary_muscles": [
      "pectorals",
      "triceps"
    ],
    "secondary_muscles": [
      "anterior_deltoid",
      "abdominals"
    ],
    "measurement_options": [
      {
        "mode": "REPS",
        "load_modes": [
          "bodyweight"
        ]
      },
      {
        "mode": "REPS_IN_TIME",
        "load_modes": [
          "bodyweight"
        ]
      }
    ],
    "progression_axes": [
      "reps",
      "sets",
      "rest",
      "technique",
      "density"
    ],
    "notes": "La amplitud, la posición y el criterio de repetición válida pertenecen al protocolo; la familia no garantiza equivalencia."
  },
  {
    "code": "push_up_weighted",
    "name": "Flexión lastrada con chaleco",
    "family": "push_up",
    "movement_patterns": [
      "horizontal_push"
    ],
    "movement_modes": [
      "dynamic"
    ],
    "body_regions": [
      "upper_body",
      "trunk"
    ],
    "laterality": "bilateral",
    "technical_level": "initial",
    "required_equipment": [
      "weighted_vest"
    ],
    "optional_equipment": [],
    "primary_muscles": [
      "pectorals",
      "triceps"
    ],
    "secondary_muscles": [
      "anterior_deltoid",
      "abdominals"
    ],
    "measurement_options": [
      {
        "mode": "LOAD_REPS",
        "load_modes": [
          "bodyweight_plus_external"
        ]
      }
    ],
    "progression_axes": [
      "load",
      "reps",
      "sets",
      "rest",
      "technique"
    ],
    "notes": "Guardar lastre externo; no estimar kilos efectivos a partir del peso corporal."
  },
  {
    "code": "bench_press_barbell",
    "name": "Press banca con barra",
    "family": "chest_press",
    "movement_patterns": [
      "horizontal_push"
    ],
    "movement_modes": [
      "dynamic"
    ],
    "body_regions": [
      "upper_body"
    ],
    "laterality": "bilateral",
    "technical_level": "intermediate",
    "required_equipment": [
      "bench",
      "barbell",
      "plates"
    ],
    "optional_equipment": [],
    "primary_muscles": [
      "pectorals",
      "triceps"
    ],
    "secondary_muscles": [
      "anterior_deltoid"
    ],
    "measurement_options": [
      {
        "mode": "LOAD_REPS",
        "load_modes": [
          "external_load"
        ]
      },
      {
        "mode": "MAX_LOAD",
        "load_modes": [
          "external_load"
        ]
      }
    ],
    "progression_axes": [
      "load",
      "reps",
      "sets",
      "rest",
      "technique"
    ],
    "notes": "La amplitud, la posición y el criterio de repetición válida pertenecen al protocolo; la familia no garantiza equivalencia."
  },
  {
    "code": "bench_press_dumbbell",
    "name": "Press banca con mancuernas",
    "family": "chest_press",
    "movement_patterns": [
      "horizontal_push"
    ],
    "movement_modes": [
      "dynamic"
    ],
    "body_regions": [
      "upper_body"
    ],
    "laterality": "bilateral",
    "technical_level": "initial",
    "required_equipment": [
      "bench",
      "dumbbell_pair"
    ],
    "optional_equipment": [],
    "primary_muscles": [
      "pectorals",
      "triceps"
    ],
    "secondary_muscles": [
      "anterior_deltoid"
    ],
    "measurement_options": [
      {
        "mode": "LOAD_REPS",
        "load_modes": [
          "external_load"
        ]
      }
    ],
    "progression_axes": [
      "load",
      "reps",
      "sets",
      "rest",
      "technique"
    ],
    "notes": "La amplitud, la posición y el criterio de repetición válida pertenecen al protocolo; la familia no garantiza equivalencia."
  },
  {
    "code": "incline_press_dumbbell",
    "name": "Press inclinado con mancuernas",
    "family": "chest_press",
    "movement_patterns": [
      "diagonal_push"
    ],
    "movement_modes": [
      "dynamic"
    ],
    "body_regions": [
      "upper_body"
    ],
    "laterality": "bilateral",
    "technical_level": "initial",
    "required_equipment": [
      "adjustable_bench",
      "dumbbell_pair"
    ],
    "optional_equipment": [],
    "primary_muscles": [
      "pectorals",
      "triceps"
    ],
    "secondary_muscles": [
      "anterior_deltoid"
    ],
    "measurement_options": [
      {
        "mode": "LOAD_REPS",
        "load_modes": [
          "external_load"
        ]
      }
    ],
    "progression_axes": [
      "load",
      "reps",
      "sets",
      "rest",
      "technique"
    ],
    "notes": "La amplitud, la posición y el criterio de repetición válida pertenecen al protocolo; la familia no garantiza equivalencia."
  },
  {
    "code": "chest_press_machine",
    "name": "Press horizontal en máquina",
    "family": "chest_press",
    "movement_patterns": [
      "horizontal_push"
    ],
    "movement_modes": [
      "dynamic"
    ],
    "body_regions": [
      "upper_body"
    ],
    "laterality": "bilateral",
    "technical_level": "initial",
    "required_equipment": [
      "chest_press_machine"
    ],
    "optional_equipment": [],
    "primary_muscles": [
      "pectorals",
      "triceps"
    ],
    "secondary_muscles": [
      "anterior_deltoid"
    ],
    "measurement_options": [
      {
        "mode": "LOAD_REPS",
        "load_modes": [
          "external_load"
        ]
      }
    ],
    "progression_axes": [
      "load",
      "reps",
      "sets",
      "rest",
      "technique"
    ],
    "notes": "La amplitud, la posición y el criterio de repetición válida pertenecen al protocolo; la familia no garantiza equivalencia."
  },
  {
    "code": "overhead_press_barbell",
    "name": "Press militar con barra",
    "family": "overhead_press",
    "movement_patterns": [
      "vertical_push"
    ],
    "movement_modes": [
      "dynamic"
    ],
    "body_regions": [
      "upper_body",
      "trunk"
    ],
    "laterality": "bilateral",
    "technical_level": "intermediate",
    "required_equipment": [
      "barbell",
      "plates"
    ],
    "optional_equipment": [],
    "primary_muscles": [
      "deltoids",
      "triceps"
    ],
    "secondary_muscles": [
      "abdominals"
    ],
    "measurement_options": [
      {
        "mode": "LOAD_REPS",
        "load_modes": [
          "external_load"
        ]
      }
    ],
    "progression_axes": [
      "load",
      "reps",
      "sets",
      "rest",
      "technique"
    ],
    "notes": "La amplitud, la posición y el criterio de repetición válida pertenecen al protocolo; la familia no garantiza equivalencia."
  },
  {
    "code": "overhead_press_dumbbell",
    "name": "Press militar con mancuernas",
    "family": "overhead_press",
    "movement_patterns": [
      "vertical_push"
    ],
    "movement_modes": [
      "dynamic"
    ],
    "body_regions": [
      "upper_body",
      "trunk"
    ],
    "laterality": "bilateral",
    "technical_level": "initial",
    "required_equipment": [
      "dumbbell_pair"
    ],
    "optional_equipment": [],
    "primary_muscles": [
      "deltoids",
      "triceps"
    ],
    "secondary_muscles": [
      "abdominals"
    ],
    "measurement_options": [
      {
        "mode": "LOAD_REPS",
        "load_modes": [
          "external_load"
        ]
      }
    ],
    "progression_axes": [
      "load",
      "reps",
      "sets",
      "rest",
      "technique"
    ],
    "notes": "La amplitud, la posición y el criterio de repetición válida pertenecen al protocolo; la familia no garantiza equivalencia."
  },
  {
    "code": "shoulder_press_machine",
    "name": "Press de hombro en máquina",
    "family": "overhead_press",
    "movement_patterns": [
      "vertical_push"
    ],
    "movement_modes": [
      "dynamic"
    ],
    "body_regions": [
      "upper_body",
      "trunk"
    ],
    "laterality": "bilateral",
    "technical_level": "initial",
    "required_equipment": [
      "shoulder_press_machine"
    ],
    "optional_equipment": [],
    "primary_muscles": [
      "deltoids",
      "triceps"
    ],
    "secondary_muscles": [
      "abdominals"
    ],
    "measurement_options": [
      {
        "mode": "LOAD_REPS",
        "load_modes": [
          "external_load"
        ]
      }
    ],
    "progression_axes": [
      "load",
      "reps",
      "sets",
      "rest",
      "technique"
    ],
    "notes": "La amplitud, la posición y el criterio de repetición válida pertenecen al protocolo; la familia no garantiza equivalencia."
  },
  {
    "code": "landmine_press_unilateral",
    "name": "Landmine press unilateral",
    "family": "landmine_press",
    "movement_patterns": [
      "diagonal_push"
    ],
    "movement_modes": [
      "dynamic"
    ],
    "body_regions": [
      "upper_body",
      "trunk"
    ],
    "laterality": "unilateral",
    "technical_level": "intermediate",
    "required_equipment": [
      "landmine_anchor",
      "barbell",
      "plates"
    ],
    "optional_equipment": [],
    "primary_muscles": [
      "deltoids",
      "triceps"
    ],
    "secondary_muscles": [
      "abdominals"
    ],
    "measurement_options": [
      {
        "mode": "LOAD_REPS",
        "load_modes": [
          "external_load"
        ]
      }
    ],
    "progression_axes": [
      "load",
      "reps",
      "sets",
      "rest",
      "technique"
    ],
    "notes": "Fijar anclaje, posición y uso unilateral o bilateral; el ángulo es diagonal."
  },
  {
    "code": "landmine_press_bilateral",
    "name": "Landmine press bilateral",
    "family": "landmine_press",
    "movement_patterns": [
      "diagonal_push"
    ],
    "movement_modes": [
      "dynamic"
    ],
    "body_regions": [
      "upper_body",
      "trunk"
    ],
    "laterality": "bilateral",
    "technical_level": "intermediate",
    "required_equipment": [
      "landmine_anchor",
      "barbell",
      "plates"
    ],
    "optional_equipment": [],
    "primary_muscles": [
      "deltoids",
      "triceps"
    ],
    "secondary_muscles": [
      "abdominals"
    ],
    "measurement_options": [
      {
        "mode": "LOAD_REPS",
        "load_modes": [
          "external_load"
        ]
      }
    ],
    "progression_axes": [
      "load",
      "reps",
      "sets",
      "rest",
      "technique"
    ],
    "notes": "Fijar anclaje, posición y uso unilateral o bilateral; el ángulo es diagonal."
  },
  {
    "code": "pull_up_pronated",
    "name": "Dominada prona",
    "family": "pull_up",
    "movement_patterns": [
      "vertical_pull"
    ],
    "movement_modes": [
      "dynamic"
    ],
    "body_regions": [
      "upper_body"
    ],
    "laterality": "bilateral",
    "technical_level": "intermediate",
    "required_equipment": [
      "pull_up_bar"
    ],
    "optional_equipment": [],
    "primary_muscles": [
      "latissimus_dorsi",
      "elbow_flexors"
    ],
    "secondary_muscles": [
      "scapular_retractors",
      "forearm_flexors"
    ],
    "measurement_options": [
      {
        "mode": "REPS",
        "load_modes": [
          "bodyweight"
        ]
      }
    ],
    "progression_axes": [
      "reps",
      "sets",
      "rest",
      "technique"
    ],
    "notes": "La amplitud, la posición y el criterio de repetición válida pertenecen al protocolo; la familia no garantiza equivalencia."
  },
  {
    "code": "pull_up_supinated",
    "name": "Dominada supina",
    "family": "pull_up",
    "movement_patterns": [
      "vertical_pull"
    ],
    "movement_modes": [
      "dynamic"
    ],
    "body_regions": [
      "upper_body"
    ],
    "laterality": "bilateral",
    "technical_level": "intermediate",
    "required_equipment": [
      "pull_up_bar"
    ],
    "optional_equipment": [],
    "primary_muscles": [
      "latissimus_dorsi",
      "elbow_flexors"
    ],
    "secondary_muscles": [
      "scapular_retractors",
      "forearm_flexors"
    ],
    "measurement_options": [
      {
        "mode": "REPS",
        "load_modes": [
          "bodyweight"
        ]
      }
    ],
    "progression_axes": [
      "reps",
      "sets",
      "rest",
      "technique"
    ],
    "notes": "La amplitud, la posición y el criterio de repetición válida pertenecen al protocolo; la familia no garantiza equivalencia."
  },
  {
    "code": "pull_up_neutral",
    "name": "Dominada neutra",
    "family": "pull_up",
    "movement_patterns": [
      "vertical_pull"
    ],
    "movement_modes": [
      "dynamic"
    ],
    "body_regions": [
      "upper_body"
    ],
    "laterality": "bilateral",
    "technical_level": "intermediate",
    "required_equipment": [
      "neutral_grip_bar"
    ],
    "optional_equipment": [],
    "primary_muscles": [
      "latissimus_dorsi",
      "elbow_flexors"
    ],
    "secondary_muscles": [
      "scapular_retractors",
      "forearm_flexors"
    ],
    "measurement_options": [
      {
        "mode": "REPS",
        "load_modes": [
          "bodyweight"
        ]
      }
    ],
    "progression_axes": [
      "reps",
      "sets",
      "rest",
      "technique"
    ],
    "notes": "La amplitud, la posición y el criterio de repetición válida pertenecen al protocolo; la familia no garantiza equivalencia."
  },
  {
    "code": "pull_up_assisted_band",
    "name": "Dominada asistida con banda",
    "family": "pull_up",
    "movement_patterns": [
      "vertical_pull"
    ],
    "movement_modes": [
      "dynamic"
    ],
    "body_regions": [
      "upper_body"
    ],
    "laterality": "bilateral",
    "technical_level": "initial",
    "required_equipment": [
      "pull_up_bar",
      "resistance_band"
    ],
    "optional_equipment": [],
    "primary_muscles": [
      "latissimus_dorsi",
      "elbow_flexors"
    ],
    "secondary_muscles": [
      "scapular_retractors",
      "forearm_flexors"
    ],
    "measurement_options": [
      {
        "mode": "REPS",
        "load_modes": [
          "assisted"
        ]
      }
    ],
    "progression_axes": [
      "reps",
      "sets",
      "rest",
      "technique",
      "assistance"
    ],
    "notes": "Identificar banda, montaje y agarre; no convertir la asistencia elástica en kilos constantes."
  },
  {
    "code": "pull_up_assisted_machine",
    "name": "Dominada asistida en máquina",
    "family": "pull_up",
    "movement_patterns": [
      "vertical_pull"
    ],
    "movement_modes": [
      "dynamic"
    ],
    "body_regions": [
      "upper_body"
    ],
    "laterality": "bilateral",
    "technical_level": "initial",
    "required_equipment": [
      "assisted_pull_up_machine"
    ],
    "optional_equipment": [],
    "primary_muscles": [
      "latissimus_dorsi",
      "elbow_flexors"
    ],
    "secondary_muscles": [
      "scapular_retractors",
      "forearm_flexors"
    ],
    "measurement_options": [
      {
        "mode": "REPS",
        "load_modes": [
          "assisted"
        ]
      }
    ],
    "progression_axes": [
      "reps",
      "sets",
      "rest",
      "technique",
      "assistance"
    ],
    "notes": "Registrar máquina y ajuste de asistencia; no comparar ajustes entre máquinas distintas."
  },
  {
    "code": "pull_up_weighted",
    "name": "Dominada prona lastrada",
    "family": "pull_up",
    "movement_patterns": [
      "vertical_pull"
    ],
    "movement_modes": [
      "dynamic"
    ],
    "body_regions": [
      "upper_body"
    ],
    "laterality": "bilateral",
    "technical_level": "intermediate",
    "required_equipment": [
      "pull_up_bar",
      "dip_belt",
      "plates"
    ],
    "optional_equipment": [],
    "primary_muscles": [
      "latissimus_dorsi",
      "elbow_flexors"
    ],
    "secondary_muscles": [
      "scapular_retractors",
      "forearm_flexors"
    ],
    "measurement_options": [
      {
        "mode": "LOAD_REPS",
        "load_modes": [
          "bodyweight_plus_external"
        ]
      }
    ],
    "progression_axes": [
      "load",
      "reps",
      "sets",
      "rest",
      "technique"
    ],
    "notes": "Registrar lastre y, si se conoce, masa corporal fechada; fijar agarre y amplitud."
  },
  {
    "code": "lat_pulldown",
    "name": "Jalón al pecho",
    "family": "vertical_pull_machine",
    "movement_patterns": [
      "vertical_pull"
    ],
    "movement_modes": [
      "dynamic"
    ],
    "body_regions": [
      "upper_body"
    ],
    "laterality": "bilateral",
    "technical_level": "initial",
    "required_equipment": [
      "lat_pulldown_machine"
    ],
    "optional_equipment": [],
    "primary_muscles": [
      "latissimus_dorsi",
      "elbow_flexors"
    ],
    "secondary_muscles": [
      "scapular_retractors"
    ],
    "measurement_options": [
      {
        "mode": "LOAD_REPS",
        "load_modes": [
          "external_load"
        ]
      }
    ],
    "progression_axes": [
      "load",
      "reps",
      "sets",
      "rest",
      "technique"
    ],
    "notes": "Registrar agarre y máquina; desarrolla capacidades útiles sin sustituir el protocolo de dominadas."
  },
  {
    "code": "supinated_flexed_arm_hang",
    "name": "Suspensión supina con barbilla sobre barra",
    "family": "flexed_arm_hang",
    "movement_patterns": [
      "vertical_pull"
    ],
    "movement_modes": [
      "isometric"
    ],
    "body_regions": [
      "upper_body"
    ],
    "laterality": "bilateral",
    "technical_level": "initial",
    "required_equipment": [
      "pull_up_bar"
    ],
    "optional_equipment": [],
    "primary_muscles": [
      "latissimus_dorsi",
      "elbow_flexors"
    ],
    "secondary_muscles": [
      "forearm_flexors",
      "scapular_retractors"
    ],
    "measurement_options": [
      {
        "mode": "DURATION",
        "load_modes": [
          "bodyweight"
        ]
      }
    ],
    "progression_axes": [
      "duration",
      "sets",
      "rest",
      "technique"
    ],
    "notes": "Definir posición y finalización válida; enlazar al protocolo oficial específico después de revisar su versión."
  },
  {
    "code": "dead_hang",
    "name": "Suspensión pasiva en barra",
    "family": "grip_hang",
    "movement_patterns": [
      "grip_hold"
    ],
    "movement_modes": [
      "isometric"
    ],
    "body_regions": [
      "upper_body"
    ],
    "laterality": "bilateral",
    "technical_level": "initial",
    "required_equipment": [
      "pull_up_bar"
    ],
    "optional_equipment": [],
    "primary_muscles": [
      "forearm_flexors"
    ],
    "secondary_muscles": [
      "shoulder_stabilizers"
    ],
    "measurement_options": [
      {
        "mode": "DURATION",
        "load_modes": [
          "bodyweight"
        ]
      }
    ],
    "progression_axes": [
      "duration",
      "sets",
      "rest",
      "technique"
    ],
    "notes": "Precisar suspensión pasiva, agarre y criterio de finalización; no equivale a suspensión con brazos flexionados."
  },
  {
    "code": "row_barbell",
    "name": "Remo con barra",
    "family": "row",
    "movement_patterns": [
      "horizontal_pull"
    ],
    "movement_modes": [
      "dynamic"
    ],
    "body_regions": [
      "upper_body"
    ],
    "laterality": "bilateral",
    "technical_level": "intermediate",
    "required_equipment": [
      "barbell",
      "plates"
    ],
    "optional_equipment": [],
    "primary_muscles": [
      "latissimus_dorsi",
      "scapular_retractors"
    ],
    "secondary_muscles": [
      "elbow_flexors"
    ],
    "measurement_options": [
      {
        "mode": "LOAD_REPS",
        "load_modes": [
          "external_load"
        ]
      }
    ],
    "progression_axes": [
      "load",
      "reps",
      "sets",
      "rest",
      "technique"
    ],
    "notes": "La amplitud, la posición y el criterio de repetición válida pertenecen al protocolo; la familia no garantiza equivalencia."
  },
  {
    "code": "row_dumbbell",
    "name": "Remo unilateral con mancuerna",
    "family": "row",
    "movement_patterns": [
      "horizontal_pull"
    ],
    "movement_modes": [
      "dynamic"
    ],
    "body_regions": [
      "upper_body"
    ],
    "laterality": "unilateral",
    "technical_level": "initial",
    "required_equipment": [
      "dumbbell",
      "stable_support"
    ],
    "optional_equipment": [],
    "primary_muscles": [
      "latissimus_dorsi",
      "scapular_retractors"
    ],
    "secondary_muscles": [
      "elbow_flexors"
    ],
    "measurement_options": [
      {
        "mode": "LOAD_REPS",
        "load_modes": [
          "external_load"
        ]
      }
    ],
    "progression_axes": [
      "load",
      "reps",
      "sets",
      "rest",
      "technique"
    ],
    "notes": "La amplitud, la posición y el criterio de repetición válida pertenecen al protocolo; la familia no garantiza equivalencia."
  },
  {
    "code": "row_cable",
    "name": "Remo en polea",
    "family": "row",
    "movement_patterns": [
      "horizontal_pull"
    ],
    "movement_modes": [
      "dynamic"
    ],
    "body_regions": [
      "upper_body"
    ],
    "laterality": "bilateral",
    "technical_level": "initial",
    "required_equipment": [
      "cable_row_machine"
    ],
    "optional_equipment": [],
    "primary_muscles": [
      "latissimus_dorsi",
      "scapular_retractors"
    ],
    "secondary_muscles": [
      "elbow_flexors"
    ],
    "measurement_options": [
      {
        "mode": "LOAD_REPS",
        "load_modes": [
          "external_load"
        ]
      }
    ],
    "progression_axes": [
      "load",
      "reps",
      "sets",
      "rest",
      "technique"
    ],
    "notes": "La amplitud, la posición y el criterio de repetición válida pertenecen al protocolo; la familia no garantiza equivalencia."
  },
  {
    "code": "row_machine",
    "name": "Remo en máquina",
    "family": "row",
    "movement_patterns": [
      "horizontal_pull"
    ],
    "movement_modes": [
      "dynamic"
    ],
    "body_regions": [
      "upper_body"
    ],
    "laterality": "bilateral",
    "technical_level": "initial",
    "required_equipment": [
      "row_machine"
    ],
    "optional_equipment": [],
    "primary_muscles": [
      "latissimus_dorsi",
      "scapular_retractors"
    ],
    "secondary_muscles": [
      "elbow_flexors"
    ],
    "measurement_options": [
      {
        "mode": "LOAD_REPS",
        "load_modes": [
          "external_load"
        ]
      }
    ],
    "progression_axes": [
      "load",
      "reps",
      "sets",
      "rest",
      "technique"
    ],
    "notes": "La amplitud, la posición y el criterio de repetición válida pertenecen al protocolo; la familia no garantiza equivalencia."
  },
  {
    "code": "rope_climb",
    "name": "Trepa de cuerda",
    "family": "rope_climb",
    "movement_patterns": [
      "rope_climb"
    ],
    "movement_modes": [
      "locomotor"
    ],
    "body_regions": [
      "upper_body",
      "lower_body",
      "trunk"
    ],
    "laterality": "bilateral",
    "technical_level": "advanced",
    "required_equipment": [
      "climbing_rope"
    ],
    "optional_equipment": [],
    "primary_muscles": [
      "latissimus_dorsi",
      "elbow_flexors",
      "forearm_flexors"
    ],
    "secondary_muscles": [
      "abdominals",
      "hip_flexors"
    ],
    "measurement_options": [
      {
        "mode": "TIME_FOR_DISTANCE",
        "load_modes": [
          "bodyweight"
        ]
      },
      {
        "mode": "PASS_FAIL",
        "load_modes": [
          "bodyweight"
        ]
      }
    ],
    "progression_axes": [
      "distance",
      "sets",
      "rest",
      "technique",
      "specificity"
    ],
    "notes": "Distancia, salida, llegada y uso de piernas son parte del protocolo; no asumir cuerda de 6 m en todas las tareas."
  },
  {
    "code": "rope_seated_pull",
    "name": "Tracción sentado en cuerda anclada",
    "family": "rope_pull",
    "movement_patterns": [
      "vertical_pull"
    ],
    "movement_modes": [
      "dynamic"
    ],
    "body_regions": [
      "upper_body",
      "trunk"
    ],
    "laterality": "bilateral",
    "technical_level": "initial",
    "required_equipment": [
      "anchored_rope"
    ],
    "optional_equipment": [],
    "primary_muscles": [
      "latissimus_dorsi",
      "elbow_flexors"
    ],
    "secondary_muscles": [
      "forearm_flexors",
      "abdominals"
    ],
    "measurement_options": [
      {
        "mode": "REPS",
        "load_modes": [
          "bodyweight"
        ]
      }
    ],
    "progression_axes": [
      "reps",
      "sets",
      "rest",
      "technique",
      "lever"
    ],
    "notes": "Fijar ángulo corporal y apoyo de pies; esta tarea de apoyo no sustituye una trepa."
  },
  {
    "code": "rope_hang",
    "name": "Suspensión en cuerda",
    "family": "grip_hang",
    "movement_patterns": [
      "grip_hold"
    ],
    "movement_modes": [
      "isometric"
    ],
    "body_regions": [
      "upper_body"
    ],
    "laterality": "bilateral",
    "technical_level": "intermediate",
    "required_equipment": [
      "climbing_rope"
    ],
    "optional_equipment": [],
    "primary_muscles": [
      "forearm_flexors"
    ],
    "secondary_muscles": [
      "elbow_flexors",
      "latissimus_dorsi"
    ],
    "measurement_options": [
      {
        "mode": "DURATION",
        "load_modes": [
          "bodyweight"
        ]
      }
    ],
    "progression_axes": [
      "duration",
      "sets",
      "rest",
      "technique"
    ],
    "notes": "Precisar agarre y posición de brazos; comparar solo el mismo montaje."
  },
  {
    "code": "farmer_carry",
    "name": "Farmer carry",
    "family": "loaded_carry",
    "movement_patterns": [
      "carry"
    ],
    "movement_modes": [
      "locomotor"
    ],
    "body_regions": [
      "upper_body",
      "lower_body",
      "trunk"
    ],
    "laterality": "bilateral",
    "technical_level": "initial",
    "required_equipment": [
      "dumbbell_pair"
    ],
    "optional_equipment": [],
    "primary_muscles": [
      "forearm_flexors",
      "trunk_stabilizers"
    ],
    "secondary_muscles": [
      "quadriceps",
      "gluteals"
    ],
    "measurement_options": [
      {
        "mode": "DISTANCE",
        "load_modes": [
          "external_load"
        ]
      },
      {
        "mode": "DURATION",
        "load_modes": [
          "external_load"
        ]
      }
    ],
    "progression_axes": [
      "load",
      "distance",
      "duration",
      "sets",
      "rest",
      "technique"
    ],
    "notes": "Registrar kilos por mano y recorrido; distancia y duración son mediciones alternativas."
  },
  {
    "code": "squat_bodyweight",
    "name": "Sentadilla con peso corporal",
    "family": "squat",
    "movement_patterns": [
      "squat"
    ],
    "movement_modes": [
      "dynamic"
    ],
    "body_regions": [
      "lower_body"
    ],
    "laterality": "bilateral",
    "technical_level": "initial",
    "required_equipment": [],
    "optional_equipment": [],
    "primary_muscles": [
      "quadriceps",
      "gluteals"
    ],
    "secondary_muscles": [
      "trunk_stabilizers"
    ],
    "measurement_options": [
      {
        "mode": "REPS",
        "load_modes": [
          "bodyweight"
        ]
      }
    ],
    "progression_axes": [
      "reps",
      "sets",
      "rest",
      "technique"
    ],
    "notes": "La amplitud, la posición y el criterio de repetición válida pertenecen al protocolo; la familia no garantiza equivalencia."
  },
  {
    "code": "goblet_squat",
    "name": "Goblet squat con mancuerna",
    "family": "squat",
    "movement_patterns": [
      "squat"
    ],
    "movement_modes": [
      "dynamic"
    ],
    "body_regions": [
      "lower_body"
    ],
    "laterality": "bilateral",
    "technical_level": "initial",
    "required_equipment": [
      "dumbbell"
    ],
    "optional_equipment": [],
    "primary_muscles": [
      "quadriceps",
      "gluteals"
    ],
    "secondary_muscles": [
      "trunk_stabilizers"
    ],
    "measurement_options": [
      {
        "mode": "LOAD_REPS",
        "load_modes": [
          "external_load"
        ]
      }
    ],
    "progression_axes": [
      "load",
      "reps",
      "sets",
      "rest",
      "technique"
    ],
    "notes": "La amplitud, la posición y el criterio de repetición válida pertenecen al protocolo; la familia no garantiza equivalencia."
  },
  {
    "code": "back_squat",
    "name": "Sentadilla trasera con barra",
    "family": "squat",
    "movement_patterns": [
      "squat"
    ],
    "movement_modes": [
      "dynamic"
    ],
    "body_regions": [
      "lower_body"
    ],
    "laterality": "bilateral",
    "technical_level": "intermediate",
    "required_equipment": [
      "rack",
      "barbell",
      "plates"
    ],
    "optional_equipment": [],
    "primary_muscles": [
      "quadriceps",
      "gluteals"
    ],
    "secondary_muscles": [
      "trunk_stabilizers"
    ],
    "measurement_options": [
      {
        "mode": "LOAD_REPS",
        "load_modes": [
          "external_load"
        ]
      }
    ],
    "progression_axes": [
      "load",
      "reps",
      "sets",
      "rest",
      "technique"
    ],
    "notes": "La amplitud, la posición y el criterio de repetición válida pertenecen al protocolo; la familia no garantiza equivalencia."
  },
  {
    "code": "front_squat",
    "name": "Sentadilla frontal con barra",
    "family": "squat",
    "movement_patterns": [
      "squat"
    ],
    "movement_modes": [
      "dynamic"
    ],
    "body_regions": [
      "lower_body"
    ],
    "laterality": "bilateral",
    "technical_level": "intermediate",
    "required_equipment": [
      "rack",
      "barbell",
      "plates"
    ],
    "optional_equipment": [],
    "primary_muscles": [
      "quadriceps",
      "gluteals"
    ],
    "secondary_muscles": [
      "trunk_stabilizers"
    ],
    "measurement_options": [
      {
        "mode": "LOAD_REPS",
        "load_modes": [
          "external_load"
        ]
      }
    ],
    "progression_axes": [
      "load",
      "reps",
      "sets",
      "rest",
      "technique"
    ],
    "notes": "La amplitud, la posición y el criterio de repetición válida pertenecen al protocolo; la familia no garantiza equivalencia."
  },
  {
    "code": "leg_press",
    "name": "Prensa de piernas",
    "family": "squat",
    "movement_patterns": [
      "squat"
    ],
    "movement_modes": [
      "dynamic"
    ],
    "body_regions": [
      "lower_body"
    ],
    "laterality": "bilateral",
    "technical_level": "initial",
    "required_equipment": [
      "leg_press_machine"
    ],
    "optional_equipment": [],
    "primary_muscles": [
      "quadriceps",
      "gluteals"
    ],
    "secondary_muscles": [
      "trunk_stabilizers"
    ],
    "measurement_options": [
      {
        "mode": "LOAD_REPS",
        "load_modes": [
          "external_load"
        ]
      }
    ],
    "progression_axes": [
      "load",
      "reps",
      "sets",
      "rest",
      "technique"
    ],
    "notes": "La amplitud, la posición y el criterio de repetición válida pertenecen al protocolo; la familia no garantiza equivalencia."
  },
  {
    "code": "split_squat",
    "name": "Split squat",
    "family": "unilateral_squat",
    "movement_patterns": [
      "unilateral_knee_dominant"
    ],
    "movement_modes": [
      "dynamic"
    ],
    "body_regions": [
      "lower_body"
    ],
    "laterality": "unilateral",
    "technical_level": "initial",
    "required_equipment": [],
    "optional_equipment": [],
    "primary_muscles": [
      "quadriceps",
      "gluteals"
    ],
    "secondary_muscles": [
      "trunk_stabilizers"
    ],
    "measurement_options": [
      {
        "mode": "REPS",
        "load_modes": [
          "bodyweight"
        ]
      }
    ],
    "progression_axes": [
      "reps",
      "sets",
      "rest",
      "technique"
    ],
    "notes": "Registrar lado, apoyos y amplitud; las repeticiones se cuentan por lado según protocolo."
  },
  {
    "code": "bulgarian_split_squat",
    "name": "Sentadilla búlgara",
    "family": "unilateral_squat",
    "movement_patterns": [
      "unilateral_knee_dominant"
    ],
    "movement_modes": [
      "dynamic"
    ],
    "body_regions": [
      "lower_body"
    ],
    "laterality": "unilateral",
    "technical_level": "intermediate",
    "required_equipment": [
      "stable_support"
    ],
    "optional_equipment": [],
    "primary_muscles": [
      "quadriceps",
      "gluteals"
    ],
    "secondary_muscles": [
      "trunk_stabilizers"
    ],
    "measurement_options": [
      {
        "mode": "REPS",
        "load_modes": [
          "bodyweight"
        ]
      }
    ],
    "progression_axes": [
      "reps",
      "sets",
      "rest",
      "technique"
    ],
    "notes": "Registrar lado, apoyos y amplitud; las repeticiones se cuentan por lado según protocolo."
  },
  {
    "code": "lunge",
    "name": "Zancada alterna",
    "family": "unilateral_squat",
    "movement_patterns": [
      "unilateral_knee_dominant"
    ],
    "movement_modes": [
      "dynamic"
    ],
    "body_regions": [
      "lower_body"
    ],
    "laterality": "alternating",
    "technical_level": "initial",
    "required_equipment": [],
    "optional_equipment": [],
    "primary_muscles": [
      "quadriceps",
      "gluteals"
    ],
    "secondary_muscles": [
      "trunk_stabilizers"
    ],
    "measurement_options": [
      {
        "mode": "REPS",
        "load_modes": [
          "bodyweight"
        ]
      }
    ],
    "progression_axes": [
      "reps",
      "sets",
      "rest",
      "technique"
    ],
    "notes": "Registrar lado, apoyos y amplitud; las repeticiones se cuentan por lado según protocolo."
  },
  {
    "code": "step_up",
    "name": "Step-up",
    "family": "unilateral_squat",
    "movement_patterns": [
      "unilateral_knee_dominant"
    ],
    "movement_modes": [
      "dynamic"
    ],
    "body_regions": [
      "lower_body"
    ],
    "laterality": "unilateral",
    "technical_level": "initial",
    "required_equipment": [
      "stable_step"
    ],
    "optional_equipment": [],
    "primary_muscles": [
      "quadriceps",
      "gluteals"
    ],
    "secondary_muscles": [
      "trunk_stabilizers"
    ],
    "measurement_options": [
      {
        "mode": "REPS",
        "load_modes": [
          "bodyweight"
        ]
      }
    ],
    "progression_axes": [
      "reps",
      "sets",
      "rest",
      "technique",
      "box_height"
    ],
    "notes": "Registrar lado, apoyos y amplitud; las repeticiones se cuentan por lado según protocolo."
  },
  {
    "code": "deadlift_conventional",
    "name": "Peso muerto convencional",
    "family": "deadlift",
    "movement_patterns": [
      "hinge"
    ],
    "movement_modes": [
      "dynamic"
    ],
    "body_regions": [
      "lower_body",
      "trunk"
    ],
    "laterality": "bilateral",
    "technical_level": "intermediate",
    "required_equipment": [
      "barbell",
      "plates"
    ],
    "optional_equipment": [],
    "primary_muscles": [
      "gluteals",
      "hamstrings"
    ],
    "secondary_muscles": [
      "spinal_extensors",
      "forearm_flexors"
    ],
    "measurement_options": [
      {
        "mode": "LOAD_REPS",
        "load_modes": [
          "external_load"
        ]
      }
    ],
    "progression_axes": [
      "load",
      "reps",
      "sets",
      "rest",
      "technique"
    ],
    "notes": "Fijar altura de salida, amplitud y posición; las variantes no comparten automáticamente una referencia de carga."
  },
  {
    "code": "deadlift_trap_bar",
    "name": "Peso muerto con trap bar",
    "family": "deadlift",
    "movement_patterns": [
      "hinge"
    ],
    "movement_modes": [
      "dynamic"
    ],
    "body_regions": [
      "lower_body",
      "trunk"
    ],
    "laterality": "bilateral",
    "technical_level": "intermediate",
    "required_equipment": [
      "trap_bar",
      "plates"
    ],
    "optional_equipment": [],
    "primary_muscles": [
      "gluteals",
      "hamstrings"
    ],
    "secondary_muscles": [
      "spinal_extensors",
      "forearm_flexors"
    ],
    "measurement_options": [
      {
        "mode": "LOAD_REPS",
        "load_modes": [
          "external_load"
        ]
      }
    ],
    "progression_axes": [
      "load",
      "reps",
      "sets",
      "rest",
      "technique"
    ],
    "notes": "Fijar altura de salida, amplitud y posición; las variantes no comparten automáticamente una referencia de carga."
  },
  {
    "code": "romanian_deadlift",
    "name": "Peso muerto rumano",
    "family": "deadlift",
    "movement_patterns": [
      "hinge"
    ],
    "movement_modes": [
      "dynamic"
    ],
    "body_regions": [
      "lower_body",
      "trunk"
    ],
    "laterality": "bilateral",
    "technical_level": "intermediate",
    "required_equipment": [
      "barbell",
      "plates"
    ],
    "optional_equipment": [],
    "primary_muscles": [
      "gluteals",
      "hamstrings"
    ],
    "secondary_muscles": [
      "spinal_extensors",
      "forearm_flexors"
    ],
    "measurement_options": [
      {
        "mode": "LOAD_REPS",
        "load_modes": [
          "external_load"
        ]
      }
    ],
    "progression_axes": [
      "load",
      "reps",
      "sets",
      "rest",
      "technique"
    ],
    "notes": "Fijar altura de salida, amplitud y posición; las variantes no comparten automáticamente una referencia de carga."
  },
  {
    "code": "hip_thrust_barbell",
    "name": "Hip thrust con barra",
    "family": "hip_extension",
    "movement_patterns": [
      "hip_extension"
    ],
    "movement_modes": [
      "dynamic"
    ],
    "body_regions": [
      "lower_body"
    ],
    "laterality": "bilateral",
    "technical_level": "intermediate",
    "required_equipment": [
      "bench",
      "barbell",
      "plates"
    ],
    "optional_equipment": [],
    "primary_muscles": [
      "gluteals"
    ],
    "secondary_muscles": [
      "hamstrings",
      "trunk_stabilizers"
    ],
    "measurement_options": [
      {
        "mode": "LOAD_REPS",
        "load_modes": [
          "external_load"
        ]
      }
    ],
    "progression_axes": [
      "load",
      "reps",
      "sets",
      "rest",
      "technique"
    ],
    "notes": "La amplitud, la posición y el criterio de repetición válida pertenecen al protocolo; la familia no garantiza equivalencia."
  },
  {
    "code": "glute_bridge",
    "name": "Puente de glúteos",
    "family": "hip_extension",
    "movement_patterns": [
      "hip_extension"
    ],
    "movement_modes": [
      "dynamic"
    ],
    "body_regions": [
      "lower_body"
    ],
    "laterality": "bilateral",
    "technical_level": "initial",
    "required_equipment": [],
    "optional_equipment": [],
    "primary_muscles": [
      "gluteals"
    ],
    "secondary_muscles": [
      "hamstrings",
      "trunk_stabilizers"
    ],
    "measurement_options": [
      {
        "mode": "REPS",
        "load_modes": [
          "bodyweight"
        ]
      }
    ],
    "progression_axes": [
      "reps",
      "sets",
      "rest",
      "technique"
    ],
    "notes": "La amplitud, la posición y el criterio de repetición válida pertenecen al protocolo; la familia no garantiza equivalencia."
  },
  {
    "code": "leg_curl",
    "name": "Curl femoral en máquina",
    "family": "knee_flexion",
    "movement_patterns": [
      "knee_flexion"
    ],
    "movement_modes": [
      "dynamic"
    ],
    "body_regions": [
      "lower_body"
    ],
    "laterality": "bilateral",
    "technical_level": "initial",
    "required_equipment": [
      "leg_curl_machine"
    ],
    "optional_equipment": [],
    "primary_muscles": [
      "hamstrings"
    ],
    "secondary_muscles": [
      "gastrocnemius"
    ],
    "measurement_options": [
      {
        "mode": "LOAD_REPS",
        "load_modes": [
          "external_load"
        ]
      }
    ],
    "progression_axes": [
      "load",
      "reps",
      "sets",
      "rest",
      "technique"
    ],
    "notes": "Fijar modelo de máquina y posición; no mezclar cargas de montajes distintos."
  },
  {
    "code": "nordic_hamstring",
    "name": "Nordic hamstring",
    "family": "knee_flexion",
    "movement_patterns": [
      "knee_flexion"
    ],
    "movement_modes": [
      "dynamic"
    ],
    "body_regions": [
      "lower_body"
    ],
    "laterality": "bilateral",
    "technical_level": "advanced",
    "required_equipment": [
      "nordic_anchor"
    ],
    "optional_equipment": [],
    "primary_muscles": [
      "hamstrings"
    ],
    "secondary_muscles": [
      "gastrocnemius"
    ],
    "measurement_options": [
      {
        "mode": "REPS",
        "load_modes": [
          "bodyweight"
        ]
      }
    ],
    "progression_axes": [
      "reps",
      "sets",
      "rest",
      "technique",
      "rom"
    ],
    "notes": "Distinguir descenso excéntrico de repetición completa y asistencia; esta entrada representa repetición completa sin asistencia."
  },
  {
    "code": "calf_raise_bilateral",
    "name": "Elevación de gemelos bilateral",
    "family": "calf_raise",
    "movement_patterns": [
      "plantar_flexion"
    ],
    "movement_modes": [
      "dynamic"
    ],
    "body_regions": [
      "lower_body"
    ],
    "laterality": "bilateral",
    "technical_level": "initial",
    "required_equipment": [],
    "optional_equipment": [],
    "primary_muscles": [
      "gastrocnemius",
      "soleus"
    ],
    "secondary_muscles": [
      "foot_stabilizers"
    ],
    "measurement_options": [
      {
        "mode": "REPS",
        "load_modes": [
          "bodyweight"
        ]
      }
    ],
    "progression_axes": [
      "reps",
      "sets",
      "rest",
      "technique",
      "rom"
    ],
    "notes": "La amplitud, la posición y el criterio de repetición válida pertenecen al protocolo; la familia no garantiza equivalencia."
  },
  {
    "code": "calf_raise_unilateral",
    "name": "Elevación de gemelo unilateral",
    "family": "calf_raise",
    "movement_patterns": [
      "plantar_flexion"
    ],
    "movement_modes": [
      "dynamic"
    ],
    "body_regions": [
      "lower_body"
    ],
    "laterality": "unilateral",
    "technical_level": "initial",
    "required_equipment": [
      "stable_support"
    ],
    "optional_equipment": [],
    "primary_muscles": [
      "gastrocnemius",
      "soleus"
    ],
    "secondary_muscles": [
      "foot_stabilizers"
    ],
    "measurement_options": [
      {
        "mode": "REPS",
        "load_modes": [
          "bodyweight"
        ]
      }
    ],
    "progression_axes": [
      "reps",
      "sets",
      "rest",
      "technique",
      "rom"
    ],
    "notes": "La amplitud, la posición y el criterio de repetición válida pertenecen al protocolo; la familia no garantiza equivalencia."
  },
  {
    "code": "front_plank_forearms",
    "name": "Plancha frontal sobre antebrazos",
    "family": "front_plank",
    "movement_patterns": [
      "core_anti_extension"
    ],
    "movement_modes": [
      "isometric"
    ],
    "body_regions": [
      "trunk"
    ],
    "laterality": "bilateral",
    "technical_level": "initial",
    "required_equipment": [],
    "optional_equipment": [],
    "primary_muscles": [
      "abdominals"
    ],
    "secondary_muscles": [
      "shoulder_stabilizers",
      "gluteals"
    ],
    "measurement_options": [
      {
        "mode": "DURATION",
        "load_modes": [
          "bodyweight"
        ]
      }
    ],
    "progression_axes": [
      "duration",
      "sets",
      "rest",
      "technique"
    ],
    "notes": "Fijar apoyos y posición válida; detener el tiempo al perder el criterio técnico. No usar RIR."
  },
  {
    "code": "front_plank_high",
    "name": "Plancha frontal con brazos extendidos",
    "family": "front_plank",
    "movement_patterns": [
      "core_anti_extension"
    ],
    "movement_modes": [
      "isometric"
    ],
    "body_regions": [
      "trunk"
    ],
    "laterality": "bilateral",
    "technical_level": "initial",
    "required_equipment": [],
    "optional_equipment": [],
    "primary_muscles": [
      "abdominals"
    ],
    "secondary_muscles": [
      "shoulder_stabilizers",
      "gluteals"
    ],
    "measurement_options": [
      {
        "mode": "DURATION",
        "load_modes": [
          "bodyweight"
        ]
      }
    ],
    "progression_axes": [
      "duration",
      "sets",
      "rest",
      "technique"
    ],
    "notes": "Variante distinta de apoyo en antebrazos; no comparar tiempos como si fueran el mismo protocolo."
  },
  {
    "code": "dead_bug",
    "name": "Dead bug",
    "family": "core_anti_extension",
    "movement_patterns": [
      "core_anti_extension"
    ],
    "movement_modes": [
      "dynamic"
    ],
    "body_regions": [
      "trunk"
    ],
    "laterality": "alternating",
    "technical_level": "initial",
    "required_equipment": [],
    "optional_equipment": [],
    "primary_muscles": [
      "abdominals"
    ],
    "secondary_muscles": [
      "hip_flexors"
    ],
    "measurement_options": [
      {
        "mode": "REPS",
        "load_modes": [
          "bodyweight"
        ]
      }
    ],
    "progression_axes": [
      "reps",
      "sets",
      "rest",
      "technique",
      "lever"
    ],
    "notes": "Definir alternancia y una repetición por lado; la extensión de palancas cambia la dificultad."
  },
  {
    "code": "side_plank",
    "name": "Plancha lateral",
    "family": "core_lateral",
    "movement_patterns": [
      "core_lateral"
    ],
    "movement_modes": [
      "isometric"
    ],
    "body_regions": [
      "trunk"
    ],
    "laterality": "unilateral",
    "technical_level": "initial",
    "required_equipment": [],
    "optional_equipment": [],
    "primary_muscles": [
      "lateral_abdominals"
    ],
    "secondary_muscles": [
      "gluteus_medius",
      "shoulder_stabilizers"
    ],
    "measurement_options": [
      {
        "mode": "DURATION",
        "load_modes": [
          "bodyweight"
        ]
      }
    ],
    "progression_axes": [
      "duration",
      "sets",
      "rest",
      "technique"
    ],
    "notes": "Registrar lado, apoyo y posición; el resultado pertenece a cada lado."
  },
  {
    "code": "suitcase_carry",
    "name": "Suitcase carry",
    "family": "loaded_carry",
    "movement_patterns": [
      "carry"
    ],
    "movement_modes": [
      "locomotor"
    ],
    "body_regions": [
      "upper_body",
      "lower_body",
      "trunk"
    ],
    "laterality": "unilateral",
    "technical_level": "initial",
    "required_equipment": [
      "dumbbell"
    ],
    "optional_equipment": [],
    "primary_muscles": [
      "lateral_abdominals",
      "forearm_flexors"
    ],
    "secondary_muscles": [
      "quadriceps",
      "gluteals"
    ],
    "measurement_options": [
      {
        "mode": "DISTANCE",
        "load_modes": [
          "external_load"
        ]
      },
      {
        "mode": "DURATION",
        "load_modes": [
          "external_load"
        ]
      }
    ],
    "progression_axes": [
      "load",
      "distance",
      "duration",
      "sets",
      "rest",
      "technique"
    ],
    "notes": "Registrar mano que carga, kilos externos y recorrido."
  },
  {
    "code": "pallof_press",
    "name": "Pallof press en polea",
    "family": "core_anti_rotation",
    "movement_patterns": [
      "core_anti_rotation"
    ],
    "movement_modes": [
      "dynamic"
    ],
    "body_regions": [
      "trunk"
    ],
    "laterality": "unilateral",
    "technical_level": "initial",
    "required_equipment": [
      "cable_machine"
    ],
    "optional_equipment": [],
    "primary_muscles": [
      "abdominals"
    ],
    "secondary_muscles": [
      "shoulder_stabilizers"
    ],
    "measurement_options": [
      {
        "mode": "LOAD_REPS",
        "load_modes": [
          "external_load"
        ]
      }
    ],
    "progression_axes": [
      "load",
      "reps",
      "sets",
      "rest",
      "technique"
    ],
    "notes": "Fijar lado, posición y geometría de polea; esta entrada representa repeticiones, no una retención temporal."
  },
  {
    "code": "squat_jump",
    "name": "Squat jump",
    "family": "vertical_jump",
    "movement_patterns": [
      "plyometric_vertical"
    ],
    "movement_modes": [
      "plyometric"
    ],
    "body_regions": [
      "lower_body"
    ],
    "laterality": "bilateral",
    "technical_level": "intermediate",
    "required_equipment": [],
    "optional_equipment": [],
    "primary_muscles": [
      "quadriceps",
      "gluteals",
      "plantar_flexors"
    ],
    "secondary_muscles": [
      "trunk_stabilizers"
    ],
    "measurement_options": [
      {
        "mode": "HEIGHT",
        "load_modes": [
          "bodyweight"
        ]
      },
      {
        "mode": "REPS",
        "load_modes": [
          "bodyweight"
        ]
      }
    ],
    "progression_axes": [
      "reps",
      "sets",
      "rest",
      "technique"
    ],
    "notes": "En práctica se cuentan repeticiones; medir altura o distancia exige método y protocolo comparables. No inferir potencia a partir del resultado."
  },
  {
    "code": "countermovement_jump",
    "name": "Countermovement jump",
    "family": "vertical_jump",
    "movement_patterns": [
      "plyometric_vertical"
    ],
    "movement_modes": [
      "plyometric"
    ],
    "body_regions": [
      "lower_body"
    ],
    "laterality": "bilateral",
    "technical_level": "intermediate",
    "required_equipment": [],
    "optional_equipment": [],
    "primary_muscles": [
      "quadriceps",
      "gluteals",
      "plantar_flexors"
    ],
    "secondary_muscles": [
      "trunk_stabilizers"
    ],
    "measurement_options": [
      {
        "mode": "HEIGHT",
        "load_modes": [
          "bodyweight"
        ]
      },
      {
        "mode": "REPS",
        "load_modes": [
          "bodyweight"
        ]
      }
    ],
    "progression_axes": [
      "reps",
      "sets",
      "rest",
      "technique"
    ],
    "notes": "En práctica se cuentan repeticiones; medir altura o distancia exige método y protocolo comparables. No inferir potencia a partir del resultado."
  },
  {
    "code": "standing_broad_jump",
    "name": "Salto horizontal desde parado",
    "family": "horizontal_jump",
    "movement_patterns": [
      "plyometric_horizontal"
    ],
    "movement_modes": [
      "plyometric"
    ],
    "body_regions": [
      "lower_body"
    ],
    "laterality": "bilateral",
    "technical_level": "intermediate",
    "required_equipment": [],
    "optional_equipment": [],
    "primary_muscles": [
      "quadriceps",
      "gluteals",
      "plantar_flexors"
    ],
    "secondary_muscles": [
      "trunk_stabilizers"
    ],
    "measurement_options": [
      {
        "mode": "DISTANCE",
        "load_modes": [
          "bodyweight"
        ]
      },
      {
        "mode": "REPS",
        "load_modes": [
          "bodyweight"
        ]
      }
    ],
    "progression_axes": [
      "reps",
      "sets",
      "rest",
      "technique"
    ],
    "notes": "En práctica se cuentan repeticiones; medir altura o distancia exige método y protocolo comparables. No inferir potencia a partir del resultado."
  },
  {
    "code": "pogo_jumps",
    "name": "Pogo jumps",
    "family": "reactive_jump",
    "movement_patterns": [
      "plyometric_vertical"
    ],
    "movement_modes": [
      "plyometric"
    ],
    "body_regions": [
      "lower_body"
    ],
    "laterality": "bilateral",
    "technical_level": "intermediate",
    "required_equipment": [],
    "optional_equipment": [],
    "primary_muscles": [
      "plantar_flexors"
    ],
    "secondary_muscles": [
      "quadriceps",
      "trunk_stabilizers"
    ],
    "measurement_options": [
      {
        "mode": "REPS",
        "load_modes": [
          "bodyweight"
        ]
      },
      {
        "mode": "REACTIVE_METRICS",
        "load_modes": [
          "bodyweight"
        ]
      }
    ],
    "progression_axes": [
      "reps",
      "sets",
      "rest",
      "contact_time",
      "technique"
    ],
    "notes": "Métricas reactivas solo con instrumento y protocolo válidos; un temporizador manual no mide contacto."
  },
  {
    "code": "drop_jump",
    "name": "Drop jump",
    "family": "reactive_jump",
    "movement_patterns": [
      "plyometric_vertical"
    ],
    "movement_modes": [
      "plyometric"
    ],
    "body_regions": [
      "lower_body"
    ],
    "laterality": "bilateral",
    "technical_level": "advanced",
    "required_equipment": [
      "stable_box"
    ],
    "optional_equipment": [],
    "primary_muscles": [
      "plantar_flexors",
      "quadriceps",
      "gluteals"
    ],
    "secondary_muscles": [
      "trunk_stabilizers"
    ],
    "measurement_options": [
      {
        "mode": "REPS",
        "load_modes": [
          "bodyweight"
        ]
      },
      {
        "mode": "REACTIVE_METRICS",
        "load_modes": [
          "bodyweight"
        ]
      }
    ],
    "progression_axes": [
      "reps",
      "sets",
      "rest",
      "box_height",
      "contact_time",
      "technique"
    ],
    "notes": "Altura de caída es una condición, no una progresión automática. RSI requiere altura y tiempo de contacto medidos de forma compatible."
  },
  {
    "code": "lateral_bound",
    "name": "Salto lateral unilateral",
    "family": "lateral_jump",
    "movement_patterns": [
      "plyometric_lateral"
    ],
    "movement_modes": [
      "plyometric"
    ],
    "body_regions": [
      "lower_body"
    ],
    "laterality": "alternating",
    "technical_level": "intermediate",
    "required_equipment": [],
    "optional_equipment": [],
    "primary_muscles": [
      "gluteals",
      "quadriceps",
      "plantar_flexors"
    ],
    "secondary_muscles": [
      "trunk_stabilizers"
    ],
    "measurement_options": [
      {
        "mode": "DISTANCE",
        "load_modes": [
          "bodyweight"
        ]
      },
      {
        "mode": "REPS",
        "load_modes": [
          "bodyweight"
        ]
      }
    ],
    "progression_axes": [
      "reps",
      "sets",
      "rest",
      "technique"
    ],
    "notes": "Registrar lado, aterrizaje válido y método de distancia."
  },
  {
    "code": "shuttle_5_10_5",
    "name": "Shuttle 5-10-5 en metros",
    "family": "planned_course",
    "movement_patterns": [
      "change_of_direction"
    ],
    "movement_modes": [
      "locomotor"
    ],
    "body_regions": [
      "lower_body",
      "trunk"
    ],
    "laterality": "bilateral",
    "technical_level": "intermediate",
    "required_equipment": [
      "cones",
      "measuring_tape"
    ],
    "optional_equipment": [],
    "primary_muscles": [
      "quadriceps",
      "gluteals",
      "plantar_flexors"
    ],
    "secondary_muscles": [
      "trunk_stabilizers"
    ],
    "measurement_options": [
      {
        "mode": "TIME_FOR_COURSE",
        "load_modes": [
          "bodyweight"
        ]
      }
    ],
    "progression_axes": [
      "sets",
      "rest",
      "technique",
      "specificity"
    ],
    "notes": "Recorrido de 5, 10 y 5 metros; no equivale al protocolo en yardas. Definir líneas, salida, giros y cronometraje."
  },
  {
    "code": "reactive_direction_drill",
    "name": "Cambio de dirección ante señal",
    "family": "reactive_course",
    "movement_patterns": [
      "reactive_agility"
    ],
    "movement_modes": [
      "locomotor"
    ],
    "body_regions": [
      "lower_body",
      "trunk"
    ],
    "laterality": "bilateral",
    "technical_level": "intermediate",
    "required_equipment": [
      "cones",
      "external_cue"
    ],
    "optional_equipment": [],
    "primary_muscles": [
      "quadriceps",
      "gluteals",
      "plantar_flexors"
    ],
    "secondary_muscles": [
      "trunk_stabilizers"
    ],
    "measurement_options": [
      {
        "mode": "TIME_FOR_COURSE",
        "load_modes": [
          "bodyweight"
        ]
      },
      {
        "mode": "PASS_FAIL",
        "load_modes": [
          "bodyweight"
        ]
      }
    ],
    "progression_axes": [
      "sets",
      "rest",
      "technique",
      "specificity"
    ],
    "notes": "Debe existir señal externa y decisión; fijar aciertos, errores y comparabilidad del conjunto de estímulos. No asignar un baremo oficial."
  },
  {
    "code": "medicine_ball_chest_throw",
    "name": "Lanzamiento frontal de balón medicinal",
    "family": "medicine_ball_throw",
    "movement_patterns": [
      "ballistic_throw"
    ],
    "movement_modes": [
      "dynamic"
    ],
    "body_regions": [
      "upper_body",
      "trunk"
    ],
    "laterality": "bilateral",
    "technical_level": "intermediate",
    "required_equipment": [
      "medicine_ball"
    ],
    "optional_equipment": [],
    "primary_muscles": [
      "pectorals",
      "triceps"
    ],
    "secondary_muscles": [
      "abdominals"
    ],
    "measurement_options": [
      {
        "mode": "DISTANCE",
        "load_modes": [
          "external_load"
        ]
      },
      {
        "mode": "REPS",
        "load_modes": [
          "external_load"
        ]
      }
    ],
    "progression_axes": [
      "load",
      "reps",
      "sets",
      "rest",
      "technique"
    ],
    "notes": "Fijar masa del balón, salida y uso del cuerpo; distancia no es potencia en vatios."
  },
  {
    "code": "kettlebell_swing",
    "name": "Kettlebell swing bilateral",
    "family": "ballistic_hinge",
    "movement_patterns": [
      "hinge"
    ],
    "movement_modes": [
      "dynamic"
    ],
    "body_regions": [
      "lower_body",
      "trunk"
    ],
    "laterality": "bilateral",
    "technical_level": "intermediate",
    "required_equipment": [
      "kettlebell"
    ],
    "optional_equipment": [],
    "primary_muscles": [
      "gluteals",
      "hamstrings"
    ],
    "secondary_muscles": [
      "trunk_stabilizers",
      "forearm_flexors"
    ],
    "measurement_options": [
      {
        "mode": "LOAD_REPS",
        "load_modes": [
          "external_load"
        ]
      }
    ],
    "progression_axes": [
      "load",
      "reps",
      "sets",
      "rest",
      "technique"
    ],
    "notes": "Fijar variante de swing y amplitud; intención explosiva pertenece a la prescripción."
  }
]
$catalog$::jsonb) item;

update public.exercises set training_profile_code='push_up_standard',training_profile_version=1
where id='20000000-0000-4000-8000-000000000001' and origin='system';
update public.exercises set training_profile_code='squat_bodyweight',training_profile_version=1
where id='20000000-0000-4000-8000-000000000003' and origin='system';

-- Javier autoriza sustituir los datos de ensayo ambiguos de desarrollo.
-- Se define la variante sin borrar plantillas ni romper sus claves foráneas.
update public.exercises set name='Plancha frontal sobre antebrazos',
  description='Apoya antebrazos y puntas de los pies; conserva pelvis, tronco y cabeza alineados. Finaliza al perder la posición válida.',
  training_profile_code='front_plank_forearms',training_profile_version=1
where id='20000000-0000-4000-8000-000000000002' and origin='system';

-- Identidad normativa y protocolo revisados; no hay asociación por nombre.
insert into public.program_test_training_bindings(
  test_id,program_id,profile_code,profile_version,measurement_mode,review_note)
select t.id,t.program_id,
  case when t.code='pull_ups_men' then 'pull_up_pronated' else 'supinated_flexed_arm_hang' end,
  1,case when t.code='pull_ups_men' then 'REPS' else 'DURATION' end,
  'Revisión de la definición versionada CNP del anexo II: agarre, posición y unidad compatibles. Conserva protocolo y baremo propios.'
from public.program_assessment_tests t
join public.program_assessment_scoring_rules r on r.program_id=t.program_id
join public.preparation_programs p on p.id=t.program_id
where not p.enabled and r.scoring_version='boe_a_2026_15055_anexo_ii_v1'
  and r.source_url='https://www.boe.es/buscar/doc.php?id=BOE-A-2026-15055'
  and (
    (t.code='pull_ups_men' and t.unit='repetitions' and t.better_direction='higher'
      and t.protocol_notes='Agarre prono, brazos extendidos al inicio y barbilla por encima de la barra. Sin balanceo ni impulso. Un intento; solo cuentan repeticiones válidas según anexo II.')
    or (t.code='bar_hang_women' and t.unit='seconds' and t.better_direction='higher'
      and t.protocol_notes='Agarre supino y suspensión estática con barbilla por encima de la barra. La prueba termina cuando baja, toca la barra o incumple las reglas. Un intento según anexo II.')
  );

commit;
