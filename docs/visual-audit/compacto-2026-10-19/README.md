# Compacto · capturas de Flutter · 19/10/2026

Muestras de widgets reales del deportista y ADMIN con `EntrenaTheme.dark` y
los controles de `workout_editor_ui`. Datos ficticios; sin escrituras remotas.
Los montajes solo añaden títulos, agrupan pantallas y reducen su escala.

| Muestra | Contenido |
| --- | --- |
| [Editor y carrera](app-editor-carrera.jpg) | Editor personal con dos series y cuatro celdas, y editor de carrera; 390 px, texto normal. |
| [Formularios](app-formularios.jpg) | Acceso y registro de marca de 2 km; 390 px, texto normal. |
| [ADMIN](admin-editor.jpg) | Valores por defecto y personalización por serie; 1100 px, texto normal. RIR 2,5 es un valor histórico que se conserva al guardar. |
| [Texto doble](texto-ampliado.jpg) | Campos personales y administrativos a 320 px con texto al doble. La página se desplaza para conservar controles y valores legibles. |

Las imágenes individuales se generan con estas pruebas y el indicador
`--dart-define=CAPTURE_PERFORMANCE_REVIEW=true`:

- Raíz: `test/core/presentation/app_input_layout_audit_test.dart`.
- Raíz: `test/features/workouts/presentation/workout_editor_cubit_test.dart`.
- Desde `admin_app/`: `test/features/workouts/presentation/compact_workout_editor_test.dart`.

Salida: `build/performance_v2_review/` en cada aplicación. Se recorren los siete
formatos, carrera y calentamientos, y se comprueban etiquetas/valores tras
desplazar a los campos. Las pruebas de ADMIN guardan la prescripción original y
contrastan sus valores. Los tests usan la política de entrada común.

No son capturas de un móvil físico: falta la aceptación nativa de iPhone y
Android. [Informe, matriz completa y límites](../../COMPACT_FORMS_2026_10_19.md).
