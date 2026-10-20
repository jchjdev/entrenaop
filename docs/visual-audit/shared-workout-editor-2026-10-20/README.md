# Creador compartido · TRN-007 · 20/10/2026

Capturas nuevas de widgets reales tras extraer el creador a `workout_editor_ui`.
El consumidor es `AdminWorkoutEditorPage`, con repositorio de prueba y receta
sintética. No muestran cuentas, permisos ni datos remotos.

- [Series a 320 px con texto 2×](mobile-fields.png): valores completos, herencia
  de objetivos por serie y RIR decimal histórico conservado. La página está
  desplazada; los campos fuera del borde se consultan mediante scroll.
- [Carrera a 1100 px](desktop-running.png): tramos, rango de ritmo,
  recuperación, pirámide, estimación y guardado de revisión.

Generadas y revisadas con:

```powershell
cd admin_app
flutter test --no-pub --dart-define=CAPTURE_PERFORMANCE_REVIEW=true test/features/workouts/presentation/compact_workout_editor_test.dart --name 'ADMIN Compacto (straightSets calentamiento false a 320|running calentamiento false a 1100)'
```

Ambos casos comprueban también el guardado de la receta. La batería completa de
ADMIN incluye los siete formatos, carrera y calentamiento con anchos de 390,
320 y 1100 px y escalas 1×/2×. Las capturas no acreditan teclado nativo, un panel
de entrenadores ni un recorrido autenticado de asignación.
