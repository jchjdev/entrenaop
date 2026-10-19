# Compacto: cobertura del creador antes de cambiar la interfaz

Fecha de contraste: 19/10/2026. Decisión UI-059.

## Acuerdo y estado

Javier prefiere Compacto y pide coherencia en toda la app, conservar todas las
opciones y reutilizar los controles entre deportista y ADMIN. Solicita preview
antes de aplicar el cambio. En esta tarea solo se amplía la propuesta visual y
se registra el alcance; no se cambia código Flutter, guardado ni permisos.

La primera maqueta solo mostraba una superserie de ejemplo. Omitía el selector
de objetivo y otros formatos. Permitía variar series de una superserie de forma
independiente, aunque en el editor personal real dependen de las rondas. No es
una especificación funcional ni una implementación lista para trasladar.

## Fuente real y reutilización

- Deportista: `lib/features/workouts/presentation/pages/workout_editor_page.dart`
  y `running_workout_editor_page.dart`, con `WorkoutEditorCubit` y borradores.
- ADMIN: `admin_app/lib/features/workouts/presentation/admin_workout_editor_page.dart`,
  con modos de fuerza/carrera, versiones y contexto de calentamiento.
- Común: `packages/workout_editor_ui/lib/strength_set_fields.dart`,
  `running_step_fields.dart`, `workout_format_field.dart`,
  `workout_effort_field.dart`, `exercise_search_list.dart`, formateador temporal
  y `responsive_field_group.dart`.
- Modelos y validación deportiva: `packages/workout_core/`.
- Estilo y teclado: `packages/entrena_ui/`, incluido `EntrenaInputPolicy`.

Hoy se comparten modelos y controles, pero no hay una única pantalla completa
del creador. No se debe presentar lo contrario. El cambio de estilo debe
evolucionar los componentes existentes, sin crear otra implementación paralela.
Una eventual unificación de los contenedores requiere definir aparte estado,
acciones y adaptadores; esta elección estética no inicia esa refactorización.

## Inventario que debe conservarse

| Área | Opciones y comportamiento existente |
| --- | --- |
| Sesión | Nombre, descripción/indicaciones, duración estimada donde procede, edición existente, guardar y errores conservando entradas. Borrador recuperable en el editor personal y protecciones de salida. |
| Bloques | Nombre, formato, añadir/quitar, orden y traslado de ejercicios donde lo ofrece cada contenedor. Límites actuales, hasta diez bloques y cuarenta ejercicios en el personal. |
| Por series | Añadir/quitar series, objetivos independientes, igualar, repeticiones/tiempo/distancia, carga y descanso. RIR entero 0–10 o ausencia solo cuando corresponde. |
| Superserie | Dos ejercicios A1/A2, rondas, descanso entre rondas y objetivo de cada ejercicio en cada ronda. No inventar un contador independiente de series en el editor personal. |
| Circuito | Orden de estaciones, rondas, descanso entre rondas y transición entre estaciones en el editor personal, objetivos por ronda. |
| Intervalos de trabajo | Un ejercicio, número de intervalos, recuperación y objetivos por intervalo. La carrera conserva su recorrido específico. |
| Tabata | Ocho intervalos de 20 s/10 s, tiempos fijos y secuencia. Se conserva la representación distinta actual: el personal repite los movimientos hasta ocho; ADMIN dispone las posiciones. |
| EMOM | Vueltas, orden de minutos y objetivos por vuelta. Cada ejercicio ocupa un minuto; se conservan límites de duración/capacidad. |
| AMRAP | Límite global y objetivo por vuelta de cada movimiento, secuencia y reglas vigentes. No añadir descansos o contadores de series independientes. |
| Ejercicio | Selección/búsqueda de catálogo, filtros de origen y creación personal donde existen; cambiar, quitar, ordenar y mover entre bloques según el contenedor. |
| Carrera | Tramos por distancia o duración, repeticiones agrupadas, ritmo mínimo/máximo opcional, sin recuperación/pasiva/andando/trotando. Recuperación activa por duración o distancia y pasiva por tiempo. Añadir, ordenar, eliminar, repetir último en personal y crear pirámide. Estimación de duración existente. |
| ADMIN | Valores por defecto y personalizar cada serie; campos opcionales, originales/versiones y guardar/revisar según el contexto. Calentamientos reutilizan el editor existente con sus restricciones; no son un nuevo formato libre del selector convencional. Catálogo común y sesiones enlazadas desde programas conservados. |

El selector compartido ofrece siete formatos convencionales. `WorkoutBlockFormat`
contiene además `running`, `warmUp` y `coolDown`: no equivale a que existan diez
opciones libres en ese selector. No se deben añadir formatos a raíz de una
enumeración ni retirar contextos que no aparecían en la preview.

## Propuesta ampliada y sus límites

La preview de la conversación permite revisar Series, Formatos, Carrera y ADMIN.
El selector incluye los siete formatos; las rondas determinan el número de
objetivos donde corresponde, Tabata bloquea el tiempo y el RIR solo aparece con
repeticiones. Carrera muestra objetivo, ritmos y tipos/medidas de recuperación.
ADMIN ilustra los valores comunes y el acceso a la personalización por serie.

Es una maqueta local con datos de ejemplo. Las acciones de catálogo, guardado,
publicación y orden no sustituyen los flujos reales. No verifica todos sus casos,
validaciones, cambios de formato, decimales históricos o recuperación de errores.
Sus comprobaciones de ancho en navegador no acreditan Flutter ni teclado nativo.

## Implementación pendiente

1. Aplicar el lenguaje Compacto en el tema y controles compartidos, manteniendo
   callbacks, controladores, máscaras, opcionalidad y validaciones existentes.
   Conservar el acceso a todos los controles de los contenedores actuales.
2. Capturar los siete formatos, carrera y ADMIN desde Flutter real. Incluir
   nombres largos, vacíos, errores y texto ampliado; reordenar campos cuando no
   caben en lugar de encoger la letra o forzar cuatro columnas.
3. Verificar guardado/recarga, borradores y edición de valores por formato;
   aplicar la matriz del repositorio a ambas apps y paquetes compartidos.
4. Repetir en dispositivos físicos el toque exterior, paso entre campos,
   arrastre, diálogos y teclado numérico. Mantener la política UI-057.

La revisión general de la app debe conservar la identidad Compacto, con anchos
adecuados al dato y texto largo disponible. No se impone un ancho estrecho a
nombres/descripciones ni una altura fija que falle con accesibilidad.
