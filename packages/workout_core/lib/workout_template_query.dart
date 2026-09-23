/// Campos necesarios para mostrar una plantilla completa en móvil y panel.
const workoutTemplateSelect = '''
  id,
  name,
  description,
  estimated_duration_minutes,
  version,
  workout_blocks (
    id,
    order_index,
    name,
    format,
    rounds,
    time_cap_seconds,
    rest_after_seconds,
    workout_items (
      id,
      order_index,
      notes,
      exercises (id, name, description),
      workout_sets (
        id,
        order_index,
        target_reps,
        target_duration_seconds,
        target_distance_meters,
        target_load_kg,
        target_rpe,
        target_rir,
        target_pace_min_seconds_per_km,
        target_pace_max_seconds_per_km,
        recovery_type,
        recovery_duration_seconds,
        recovery_distance_meters,
        rest_after_seconds
      )
    )
  )
''';
