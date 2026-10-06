# Catálogo de ejercicios de fuerza y rendimiento · v1

Fecha: 03/10/2026. **63 variantes de EntrenaOP creadas en la biblioteca de
Supabase de desarrollo y vinculadas a sus perfiles deportivos versionados.**

El contrato responsable es [CONTRATO_FUERZA_RENDIMIENTO_V1.md](CONTRATO_FUERZA_RENDIMIENTO_V1.md).
Los datos completos y las combinaciones válidas están en
[`strength_exercises_v1.json`](../supabase/catalogs/strength_exercises_v1.json).
El lector compartido rechaza combinaciones inválidas, códigos duplicados y
vocabulario desconocido. No selecciona ejercicios ni prescribe dosis.

Esta biblioteca conserva todas las familias de las pautas de Javier. Separa
banda y máquina para asistencia, especifica material concreto y añade una
tarea reactiva con señal externa. No incluye fotos o vídeos inventados, baremos
nuevos ni índices de fatiga. Los músculos, patrones y niveles técnicos son
clasificaciones editoriales iniciales, susceptibles de revisión.

## Ampliación operativa v2 · STR-017

El catálogo v1 permanece inmutable. `performance_exercises_v2.json` añade
`slalom_ball_course_16m`: circuito DEF/15/2026 de 16 × 2 m, siete conos y pelota,
medido como `TIME_FOR_COURSE`, con protocolo propio. Son 64 variantes con perfil
y ejercicio público en desarrollo; no se equipara esta tarea al shuttle 5–10–5.

## Inventario

| Código | Variante | Familia | Medición compatible |
| --- | --- | --- | --- |
| `push_up_incline` | Flexión inclinada | `push_up` | `REPS` |
| `push_up_standard` | Flexión estándar | `push_up` | `REPS`, `REPS_IN_TIME` |
| `push_up_weighted` | Flexión lastrada con chaleco | `push_up` | `LOAD_REPS` |
| `bench_press_barbell` | Press banca con barra | `chest_press` | `LOAD_REPS`, `MAX_LOAD` |
| `bench_press_dumbbell` | Press banca con mancuernas | `chest_press` | `LOAD_REPS` |
| `incline_press_dumbbell` | Press inclinado con mancuernas | `chest_press` | `LOAD_REPS` |
| `chest_press_machine` | Press horizontal en máquina | `chest_press` | `LOAD_REPS` |
| `overhead_press_barbell` | Press militar con barra | `overhead_press` | `LOAD_REPS` |
| `overhead_press_dumbbell` | Press militar con mancuernas | `overhead_press` | `LOAD_REPS` |
| `shoulder_press_machine` | Press de hombro en máquina | `overhead_press` | `LOAD_REPS` |
| `landmine_press_unilateral` | Landmine press unilateral | `landmine_press` | `LOAD_REPS` |
| `landmine_press_bilateral` | Landmine press bilateral | `landmine_press` | `LOAD_REPS` |
| `pull_up_pronated` | Dominada prona | `pull_up` | `REPS` |
| `pull_up_supinated` | Dominada supina | `pull_up` | `REPS` |
| `pull_up_neutral` | Dominada neutra | `pull_up` | `REPS` |
| `pull_up_assisted_band` | Dominada asistida con banda | `pull_up` | `REPS` |
| `pull_up_assisted_machine` | Dominada asistida en máquina | `pull_up` | `REPS` |
| `pull_up_weighted` | Dominada prona lastrada | `pull_up` | `LOAD_REPS` |
| `lat_pulldown` | Jalón al pecho | `vertical_pull_machine` | `LOAD_REPS` |
| `supinated_flexed_arm_hang` | Suspensión supina con barbilla sobre barra | `flexed_arm_hang` | `DURATION` |
| `dead_hang` | Suspensión pasiva en barra | `grip_hang` | `DURATION` |
| `row_barbell` | Remo con barra | `row` | `LOAD_REPS` |
| `row_dumbbell` | Remo unilateral con mancuerna | `row` | `LOAD_REPS` |
| `row_cable` | Remo en polea | `row` | `LOAD_REPS` |
| `row_machine` | Remo en máquina | `row` | `LOAD_REPS` |
| `rope_climb` | Trepa de cuerda | `rope_climb` | `TIME_FOR_DISTANCE`, `PASS_FAIL` |
| `rope_seated_pull` | Tracción sentado en cuerda anclada | `rope_pull` | `REPS` |
| `rope_hang` | Suspensión en cuerda | `grip_hang` | `DURATION` |
| `farmer_carry` | Farmer carry | `loaded_carry` | `DISTANCE`, `DURATION` |
| `squat_bodyweight` | Sentadilla con peso corporal | `squat` | `REPS` |
| `goblet_squat` | Goblet squat con mancuerna | `squat` | `LOAD_REPS` |
| `back_squat` | Sentadilla trasera con barra | `squat` | `LOAD_REPS` |
| `front_squat` | Sentadilla frontal con barra | `squat` | `LOAD_REPS` |
| `leg_press` | Prensa de piernas | `squat` | `LOAD_REPS` |
| `split_squat` | Split squat | `unilateral_squat` | `REPS` |
| `bulgarian_split_squat` | Sentadilla búlgara | `unilateral_squat` | `REPS` |
| `lunge` | Zancada alterna | `unilateral_squat` | `REPS` |
| `step_up` | Step-up | `unilateral_squat` | `REPS` |
| `deadlift_conventional` | Peso muerto convencional | `deadlift` | `LOAD_REPS` |
| `deadlift_trap_bar` | Peso muerto con trap bar | `deadlift` | `LOAD_REPS` |
| `romanian_deadlift` | Peso muerto rumano | `deadlift` | `LOAD_REPS` |
| `hip_thrust_barbell` | Hip thrust con barra | `hip_extension` | `LOAD_REPS` |
| `glute_bridge` | Puente de glúteos | `hip_extension` | `REPS` |
| `leg_curl` | Curl femoral en máquina | `knee_flexion` | `LOAD_REPS` |
| `nordic_hamstring` | Nordic hamstring | `knee_flexion` | `REPS` |
| `calf_raise_bilateral` | Elevación de gemelos bilateral | `calf_raise` | `REPS` |
| `calf_raise_unilateral` | Elevación de gemelo unilateral | `calf_raise` | `REPS` |
| `front_plank_forearms` | Plancha frontal sobre antebrazos | `front_plank` | `DURATION` |
| `front_plank_high` | Plancha frontal con brazos extendidos | `front_plank` | `DURATION` |
| `dead_bug` | Dead bug | `core_anti_extension` | `REPS` |
| `side_plank` | Plancha lateral | `core_lateral` | `DURATION` |
| `suitcase_carry` | Suitcase carry | `loaded_carry` | `DISTANCE`, `DURATION` |
| `pallof_press` | Pallof press en polea | `core_anti_rotation` | `LOAD_REPS` |
| `squat_jump` | Squat jump | `vertical_jump` | `HEIGHT`, `REPS` |
| `countermovement_jump` | Countermovement jump | `vertical_jump` | `HEIGHT`, `REPS` |
| `standing_broad_jump` | Salto horizontal desde parado | `horizontal_jump` | `DISTANCE`, `REPS` |
| `pogo_jumps` | Pogo jumps | `reactive_jump` | `REPS`, `REACTIVE_METRICS` |
| `drop_jump` | Drop jump | `reactive_jump` | `REPS`, `REACTIVE_METRICS` |
| `lateral_bound` | Salto lateral unilateral | `lateral_jump` | `DISTANCE`, `REPS` |
| `shuttle_5_10_5` | Shuttle 5-10-5 en metros | `planned_course` | `TIME_FOR_COURSE` |
| `reactive_direction_drill` | Cambio de dirección ante señal | `reactive_course` | `TIME_FOR_COURSE`, `PASS_FAIL` |
| `medicine_ball_chest_throw` | Lanzamiento frontal de balón medicinal | `medicine_ball_throw` | `DISTANCE`, `REPS` |
| `kettlebell_swing` | Kettlebell swing bilateral | `ballistic_hinge` | `LOAD_REPS` |

## Decisiones de representación

- Flexiones estándar y lastradas son variantes de familia, no cargas mecánicas
  calculadas a partir del peso corporal.
- Dominada asistida distingue banda de máquina; no se inventan kilos de
  asistencia elástica. La lastrada conserva el lastre separado.
- La plancha frontal de antebrazos, la de brazos extendidos y la suspensión
  supina conservan posición y protocolo propios; los tiempos no se mezclan.
- La trepa no presupone distancia ni uso permitido de piernas. El protocolo
  de 6 m será una configuración explícita.
- Squat jump, CMJ y salto horizontal admiten repeticiones de práctica y una
  medición del resultado. Estas opciones no convierten altura/distancia en
  potencia calculada.
- Pogo y drop jump solo admiten métricas de contacto con instrumentos y
  protocolos adecuados. Altura de cajón describe una condición de tarea.
- El shuttle usa metros de forma explícita; no equivale a yardas ni a un
  circuito oficial. El ejercicio reactivo exige señal externa y decisión.
- Nordic representa una repetición completa sin asistencia; una variante
  excéntrica o asistida necesitará configuración explícita. No se compararán
  recuentos bajo criterios distintos.
- El catálogo representa versiones concretas de material: goblet con mancuerna,
  farmer con dos mancuernas, Pallof en polea y lanzamiento frontal de balón.
  No convierte una alternativa en equivalente sin definirla.

## Enlaces existentes e integración

Se ha contrastado el catálogo remoto de desarrollo. Flexiones y Sentadilla
con peso corporal están enlazadas por sus UUID. La plancha de ensayo se ha
definido como **Plancha frontal sobre antebrazos**, con apoyo y finalización
explícitos, y conserva su UUID. Los identificadores candidatos del JSON son
procedencia editorial; la referencia operativa vive en `exercises`.

Las 63 definiciones viven en `exercise_training_profiles`, versionadas e
inmutables. Las 63 variantes tienen su entrada en `exercises` con origen
`system`, visibilidad pública y sin propietario personal; aparecen en el filtro
«EntrenaOP» del selector y en ADMIN. Se han creado las 60 entradas que faltaban
mediante `20261003003000_strength_exercise_library.sql`. Los grupos musculares
y el material editorial se presentan en castellano; los códigos deportivos
permanecen estables. El ejercicio administrativo de ensayo «Patada de Tríceps»
y los ejercicios personales no reciben metadatos inferidos. `Carrera` conserva
su recorrido independiente.

El tipo editorial actual del formulario ofrece repeticiones o duración. Cuando
una variante admite repeticiones/carga se utiliza ese tipo; en los demás casos,
duración. Este campo permite el uso manual básico, sin sustituir las capacidades
del perfil ni fingir que existen campos de altura, distancia, validez o
reactividad en el ejecutor. Ampliar esos registros sigue siendo el siguiente
tramo; su ausencia no impide disponer de los ejercicios en la biblioteca.

Las pruebas pronas de dominadas y suspensión supina del borrador CNP 2026
están vinculadas por identidad normativa y protocolo a sus perfiles. No se
publica el programa ni se cambian sus baremos. Estos enlaces son opcionales:
dominadas y suspensión se leen desde la biblioteca aunque no exista ningún
programa o vínculo de evaluación. El motor deportivo general no requiere
una prueba oficial; el adaptador del programa podrá aportar una referencia.

## Cobertura de las pautas originales

| Apartados | Cobertura y límite de esta entrega |
| --- | --- |
| A–J | Identidad, familia, patrones/modos, regiones, material, músculos, carga, medición y ejes representados en catálogo/lector. |
| K–N | Contrato de prescripción/resultado, descanso y RPE documentado; ampliación operativa del registro pendiente. |
| O | Reutilización de pruebas y baremos definida; enlaces deportivos sin materializar. |
| P | Formatos actuales conservados; no se usan como adaptación. |
| Q–R | Biblioteca candidata completa y separación de metadatos oficiales del flujo personal. |
| S | Progresión, fatiga, periodización y selección automática siguen en la fase deportiva posterior. |
| T | Frontera con carrera definida; no se cambia la política actual. |
| U | Doce combinaciones cubiertas por pruebas de contrato; recorridos de UI completos pendientes de la ampliación del ejecutor. |
| V | Informe previo revisado con Javier; trabajo por entregas verificables, sin cerrar aún el bloque funcional. |
