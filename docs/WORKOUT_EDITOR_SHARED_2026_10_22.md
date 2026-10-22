# Creador común de sesiones · INT-008 · 22/10/2026

Javier pide corregir los creadores de deportista, ADMIN y Trainer como un único
componente. ADMIN y Trainer ya consumían `WorkoutEditorPage` de
`packages/workout_editor_ui`; el deportista conservaba formularios propios de
carrera y fuerza, aunque reutilizaba algunos campos. Esta entrega sustituye
esos dos formularios por adaptadores al mismo creador.

## Responsabilidades

| Parte | Responsabilidad |
| --- | --- |
| `workout_core` | Receta tipada, validación y codificación ya existentes. |
| `workout_editor_ui/WorkoutEditorPage` | Formulario de carrera/fuerza, búsqueda, series, formatos, agrupación y protección de salida. |
| `WorkoutEditorSnapshot` | Estado de formulario incompleto y proyección común hacia la receta. Se mantiene schema 1. |
| `workoutEditorStateFromInput` | Adaptación de borradores personales anteriores al formulario común, conservando valores por serie. |
| `PersonalWorkoutEditor` | Catálogo personal autorizado, recuperación local, acceso Pro y guardado mediante el Cubit/repositorios existentes. |
| Adaptadores ADMIN/Trainer | Catálogos y permisos propios, publicación/revisión, trabajo durable y navegación existentes. |

Las rutas personales anteriores siguen existiendo; sus páginas solo montan el
adaptador personal. No se importan aplicaciones entre sí. El formulario no
consulta Supabase, no comprueba roles ni concede derechos; cada consumidor y
el servidor siguen siendo responsables de su acceso y persistencia.

La entrada personal de carrera/fuerza mantiene su modalidad. ADMIN y Trainer
conservan el selector existente. Una mejora del formulario común llega a las
tres aplicaciones; sus servicios, catálogos, cuotas y permisos siguen separados.

## Borradores y regresiones corregidas

- Los borradores personales previos siguen leyéndose con su receta tipada.
  Al recuperar uno, se adapta al mismo formulario sin perder series, ritmos,
  recuperaciones ni variaciones de carga/RIR/descanso.
- El almacén local por cuenta añade opcionalmente `editor` con los textos del
  formulario. Permite conservar campos incompletos; `input` mantiene la última
  proyección recuperable para compatibilidad y no se publica automáticamente.
- Las escrituras locales se serializan. Antes del guardado final se espera a
  las pendientes; una escritura antigua no resucita el borrador después de
  guardar la sesión y limpiarlo. Se conserva guardado al salir y al suspender.
- Un estado incompatible o de otra modalidad se conserva sin sobrescribirlo.
- Las excepciones por serie creadas durante build se observan desde su primer
  cambio: ya no dependen de otro rebuild para disparar el autoguardado.
- Al revisar una sesión o recuperar un borrador, una serie sin carga/RIR no
  hereda accidentalmente el valor de otra. Se adapta el valor común y las
  excepciones para conservar también la ausencia explícita.
- Búsqueda y creación de ejercicios propios siguen disponibles. Los filtros
  `EntrenaOP/Míos` son etiquetas del catálogo que aporta el consumidor, sin
  ampliar acceso. Las superseries mantienen posiciones A1/A2.
- Carrera incorpora en el creador común repetición del último tramo, recuento
  expandido y rango de duración estimada. El límite de cuarenta se comprueba
  sumando todas las tarjetas, no solo el contador de cada una.

Los borradores durables de ADMIN y Trainer mantienen su binding, revisión,
intención congelada, recibos y RPC. No se modifican tablas, migraciones, RLS,
sesiones publicadas, asignaciones, algoritmo o trabajo de dos preparadores.

## Límites y siguiente bloque

La unificación no cambia el contrato de carrera publicado: actualmente el
creador guarda un bloque `running` con tramos individuales. No se añaden
etiquetas que aparenten calentamiento/vuelta a la calma sin persistir esa
semántica. El siguiente bloque es ampliar esa representación de forma coherente
en modelo, validación/SQL, recuperación y ejecución, y comprobar su traducción
a Garmin con receta versionada. También debe preservar las sesiones antiguas.

La fuerza se crea y revisa con el mismo formulario, pero su exportación a Garmin
sigue pendiente del adaptador de ejercicios/series y de una matriz de capacidad.
No se habilita por esta entrega el envío de sesiones personales: INT-006 sigue
limitando el primer envío a pautas autorizadas del algoritmo o entrenador.

## Verificación y distribución

Se comprueban deportista, ADMIN, Trainer y paquete compartido, incluyendo
formatos, regreso al router, cuotas, selección/creación de ejercicios, borradores
y conversión reversible. Las pruebas se adaptan a los controles del formulario
compartido conservando sus casos de negocio; no se mantienen selectores de los
formularios retirados. Las pruebas nuevas cubren también escrituras pendientes
frente al guardado final y series con valores opcionales ausentes.

La CI de Garmin incluye ahora los cambios del creador/receta, sus regresiones y
la compilación iOS Release sin firma. No equivale a instalar la app en un móvil.
Para probar la nueva interfaz en iPhone: Fetch/Pull de `main` en el Mac,
`bash tools/prepare_iphone_dev.sh`, esquema Runner iPhone y ejecución en el
dispositivo. La recepción Garmin del bloque anterior no acredita esta nueva UI.

Resultado local del 22/10/2026: análisis limpios de raíz, ADMIN y Trainer;
1.279 pruebas raíz correctas (una omisión previa), 314 ADMIN (dos omisiones
previas), 170 Trainer y 155 del paquete común. Se mantienen los casos de edición
personal y se añaden recuperación de estados incompletos por cuenta, conversión
de todos los formatos, ausencia de valores por serie y suspensión durante un
guardado pendiente. Revisión de dos capturas sintéticas del widget real de
carrera a 390 px; pruebas responsivas también a 320 px y texto 2×.
