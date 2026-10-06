# Recorrido mínimo del motor de carrera de 2 km

> **Estado vigente (01/10/2026):** [Motor 2 km v5](MOTOR_CARRERA_2K_V5.md).
> Incluye motor común por programa, contexto de calidad declarada, reinicio
> del plan y laboratorio de 1.573 semanas. Las versiones antiguas descritas
> abajo son antecedentes; consultar v5 para el estado implementado.

Estado: **motor `running_2k_v5` aplicado en desarrollo para FAS, Tropa y
programas con prueba 2 km compatible**. Las descripciones del piloto v1–v6
que siguen son antecedentes históricos. Fecha de inspección: 01/10/2026.

Primer avance implementado: `TwoKilometrePerformance` calcula velocidad,
ritmo medio y brecha de velocidad sin asignar intensidades. El simulador muestra
esa brecha cuando se introduce una meta opcional. Ninguno de esos cálculos
altera todavía las sesiones propuestas ni se guarda como evaluación.

Segundo avance en desarrollo: ADMIN puede declarar la distancia y seleccionar
el protocolo `run_2000m_v1` en una prueba cronometrada de un borrador. Un vínculo
explícito `program_training_modules` asocia esa prueba al módulo
`running_2000m_v1`. PostgreSQL comprueba distancia de 2.000 m, unidad,
dirección favorable y protocolo; RLS permite leerlo a usuarios de programas
publicados y bloquea cambios después de publicar. La copia de versión conserva
la configuración. La asociación queda disponible para integrar el planificador,
pero no ocupa una tarjeta informativa en el detalle del deportista. Esto
**no** alimenta todavía el planificador ni crea sesiones.
El lector `GetRunningReferenceCandidatesUseCase` ya produce candidatos fechados
de la evaluación oficial y del control de Tropa, de la evaluación periódica
ligada a Mejora FAS y de intentos del mismo programa cuya prueba está vinculada
al módulo. Conserva identificador de intento, protocolo si el origen lo
versiona y versión de baremo. Los catálogos oficiales antiguos no conservan
protocolo deportivo: figura como ausente, nunca inventado. Entrega segundos
medidos, no puntos. El detalle de una preparación configurable muestra su
última marca vinculada, si existe. RUN-005 clasifica su ventana temporal. La
elección explícita y la confirmación de continuidad ya se guardan dentro de
la preparación. La lectura vuelve a resolver el intento y puede declararlo no
utilizable si caduca o cambia el contexto. La vista «Datos para empezar» ya
calcula a petición una primera semana provisional con esos datos. En FAS se
calcula en PostgreSQL y puede publicarse en la agenda con adaptación semanal;
en los demás programas sigue siendo una vista previa sin publicar.
La migración `20260929000000` se comprobó en Supabase de desarrollo el
29 de septiembre de 2026; no acredita producción.

Este documento traduce la propuesta deportiva de 2 km en un recorrido ejecutable.
El código y las migraciones citados describen lo existente. Las entradas y
reglas marcadas como pendientes no están implementadas ni validadas.

## Resultado que debe poder verse

En una preparación concreta, el deportista registra o confirma su referencia
de carrera y su disponibilidad. EntrenaOP muestra una semana propuesta con
sesiones completas, carga prevista y motivos. Al terminar o saltar sesiones,
registra lo sucedido. La siguiente propuesta explica si mantiene, reduce,
recalibra o progresa una variable. Una semana antigua conserva las reglas,
marcas y sesiones con las que se creó.

Si el usuario ya registró un 2 km oficial reciente y compatible dentro de
esa preparación, el mismo intento podrá aportar sus segundos al entrenamiento
y sus puntos a la evaluación normativa. No se repite la carrera ni se exige
Cooper/VAMEVAL para empezar. La ventana temporal y la elección explícita
siguen RUN-005. El piloto FAS ya conecta la marca elegida con semanas de
carrera publicadas; los demás programas aún no publican desde este recorrido.

El simulador de Tropa existente puede servir para comprobar reglas deportivas
en aislamiento, pero no constituye el futuro formulario común de entrada. No
extenderemos automáticamente sus reglas a Mejora FAS ni transformaremos la
evaluación genérica de pruebas en una prescripción. El núcleo matemático deberá
ser independiente del programa;
cada programa declarará qué test, objetivo y prioridades aporta.

## Recorrido acordado para cualquier programa

La entrada a una preparación tendrá **un único recorrido principal**:

1. Presentar las pruebas y mediciones que ese programa necesita. El usuario
   introduce sus resultados o acepta expresamente una marca anterior sugerida
   con fecha, procedencia y protocolo compatible. Si ya hay un 2 km oficial
   utilizable, no se exige otro test máximo para comenzar.
2. Preguntar el contexto necesario para entrenar: disponibilidad, carrera y
   fuerza recientes, molestias y objetivo. Una evaluación puntuable puede
   aportar marcas, pero no sustituye estos datos de carga y disponibilidad.
3. Resolver cada marca con el baremo **de ese programa y versión** y entregar
   al planificador solo mediciones autorizadas, no puntos de otro programa.
4. Un coordinador único combina las propuestas de módulos deportivos, fuerza
   y prioridades de las pruebas; muestra una semana concreta y sus motivos.
5. La ejecución y el registro alimentan la siguiente decisión. La pantalla de
   preparación muestra el estado de ese recorrido y la semana publicada.

ADMIN configurará la relación `programa + versión → prueba/protocolo → módulo
de entrenamiento + versión de política`. La elección visible podría llamarse
«Preparación de carrera 2 km»; no basta un interruptor «usa simulador 2k» ni
buscar el texto «2 km» en la prueba. La definición debe comprobar unidad,
distancia, protocolo, vigencia y si el módulo sabe utilizar esa medición.
Varios programas pueden usar el mismo módulo sin copiar su código, mientras
conservan evaluaciones, baremos, prioridades e historiales independientes.
La primera configuración y sus permisos ya existen para nuevas pruebas de
programas administrados. Falta completar la evaluación deportiva del resultado,
el traspaso explícito de la marca al planificador y las prioridades de varios
módulos en una semana. Tropa y Mejora FAS conservan por ahora sus recorridos
anteriores; no se migraron implícitamente a este vínculo.

La reutilización de marcas exige compatibilidad de protocolo y confirmación
del usuario; nunca autocompleta una evaluación ni traslada puntos. La
calculadora FAS y sus tests personales mantienen la restricción ya acordada:
solo pueden alimentar Mejora FAS. Compartir un módulo deportivo no elimina
esa frontera de datos.

La limitación de salud guardada actualmente como
`requiresProfessionalReview` bloquea la generación automática. **No es una
petición al futuro servicio Pro** ni requiere que un entrenador revise a los
usuarios normales. El algoritmo puede reducir carga por fatiga ordinaria;
ante dolor o lesión declarada no debe fingir que diagnostica ni pautar
rehabilitación. Falta diseñar la reanudación segura y renombrar el campo
técnico para que no sugiera un flujo profesional inexistente.

## Qué muestran hoy las pantallas

En Tropa ya no se muestran ni se consultan automáticamente las evaluaciones
del historial general que solo coinciden por versión de catálogo. Ese bloque
se retiró porque no representa una marca aceptada para la preparación.
La evaluación de las cuatro pruebas se registra ahora dentro de Tropa y solo
los nuevos intentos vinculados se muestran en su detalle. La marca oficial de
2 km de esa evaluación aún no se convierte en ancla del planificador.
«Control específico · 2 km» guarda tests vinculados a esa preparación y
muestra la última marca y fecha en su tarjeta. La vista «Explorar una semana
de prueba» sigue existiendo como simulador técnico, pero se ha retirado del
detalle del deportista porque no guarda ni asigna sesiones. El bloque estático
«Laboratorio · semana de ejemplo» también se retiró. La agenda inferior solo
contiene entrenamientos ya programados mediante su vínculo a esta preparación.

Mejora FAS sigue mostrando su evaluación periódica propia. La evaluación
genérica de programas publicados conserva su registro y baremación. La pantalla
compartida «Datos para empezar» muestra ahora la última marca candidata del
programa con origen y fecha. Desde ella se captura, por preparación, la
disponibilidad por día, cuatro semanas de carrera, capacidad cómoda actual,
días reservados para fuerza y estado de salud fechado. La duración habitual
se precarga del perfil; el usuario elige los días concretos y puede ajustar
su duración. La marca elegida se vuelve a comprobar al calcular la semana.
En FAS se pueden publicar sesiones. La tarjeta aparece en Tropa, Mejora FAS y programas configurables con
marca de 2 km vinculada; para estos últimos todavía falta mostrarla si tienen
el módulo configurado pero ninguna marca guardada.

## Inventario de datos en el recorrido

| Dato o paso | Fuente comprobada | Estado y trabajo pendiente |
| --- | --- | --- |
| Preparación, programa y fecha objetivo | `preparation_goals` | Existe. Validar qué versión de programa se congela al prescribir. |
| Días totales y minutos por sesión | `training_preferences` | Existen y son globales. No indican días concretos ni reparto carrera/fuerza. |
| Días asignados a carrera y fuerza | `InitialRunningWeekInput` y simulador | Solo entrada manual para escenario. Requiere asignación conjunta persistente. |
| Día de la semana disponible | `running_intake_contexts` | Declarado por el deportista con minutos por día y días reservados a fuerza. Falta asignación conjunta y actualización con ejecución real. |
| Frecuencia reciente de carrera | `running_intake_contexts` | Cuatro semanas completas declaradas, incluidos los ceros. El piloto FAS las usa para la carga inicial. |
| Minutos o kilómetros recientes de carrera | `running_intake_contexts` y ejecuciones | Captura minutos semanales; falta cotejo con ejecuciones y evaluación de cambios de carga. |
| Carga aproximada de fuerza de pierna | Sesiones y ejecuciones de fuerza | No hay contrato común de carga para el coordinador. Pendiente. |
| Dolor, lesión, fatiga y recuperación | `running_intake_contexts` y motivos de abandono | Se pregunta dolor y limitación que requiere revisión, con fecha. Fatiga y recuperación aún no se capturan; ninguna de estas respuestas habilita por sí sola una pauta. |
| Test específico de 2 km | `preparation_running_tests` y `RunningTestResult` | Guarda fecha, tiempo, RPE, FC y parciales opcionales con protocolo `run_2000m_v1`. La validación técnica no acredita esfuerzo ni vigencia deportiva. |
| Referencia inicial 2 km, Cooper o VAMEVAL | Decisiones RUN-001/RUN-002/RUN-005 | Un 2 km oficial reciente del mismo programa puede iniciar una pauta provisional sin otro test. En ausencia de esa marca utilizable, Cooper será la opción principal y VAMEVAL continuo en pista la alternativa; solo se elegirá uno. La ventana 30/45 y la elección explícita de 2 km ya se aplican; faltan captura persistente de Cooper/VAMEVAL, protocolo reproducible de VAMEVAL y prescripción. No inventar equivalencias entre tests. |
| Referencia elegida | `running_reference_selections` | Guarda preparación, fuente, intento y confirmación de continuidad. No duplica la marca; la lectura la resuelve de nuevo y comprueba plazo, carga reciente y salud. RLS por propietario y preparación activa para escrituras. |
| Marca objetivo de 2 km | Objetivo del programa o dato explícito del usuario, por definir | La fecha existe, pero no hay un contrato único de marca objetivo. No deducirla de cualquier baremo o evaluación ajena. |
| Sesión prescrita | `workout_templates`, `scheduled_workouts` y `running_week_sessions` | FAS publica plantillas de origen `algorithm` con tramos registrables y agenda mediante función de confianza. El resto sigue pendiente. |
| Sesión realizada | `workout_executions`, series y `scheduled_workouts` | Guardan tiempo, distancia, RPE y FC opcional. La valoración actual `onTarget/changed/incomplete` no decide adaptación. |
| Decisión y razones | `running_week_decisions` | FAS guarda entrada, referencia, política, resultado y razones. La publicación es idempotente. Anulación por entrenador y coordinación multideporte siguen pendientes. |

`InitialRunningWeekPreviewPlanner` añade una decisión de vista previa común a
los programas con referencia de 2 km. Se calcula de nuevo con contexto y marca
guardados. Usa la semana actual solo si todavía es lunes; en otro caso muestra
la siguiente semana completa. Consulta la agenda global de esa semana y ocupa
solo días de al menos 30 minutos que no estén reservados a
fuerza ni ocupados en la agenda global. Su límite de minutos es el menor entre
la última semana y la media entera de las cuatro semanas recientes; nunca
aumenta la frecuencia sobre la última semana. Con al menos dos días en cada
semana reciente y espacio para dos sesiones incluye una calidad controlada;
en otros casos propone solo carrera fácil o devuelve un motivo de bloqueo.
La sesión de calidad usa el borrador de 4 × 2 minutos por esfuerzo percibido,
sin estimar umbral desde el 2 km. Javier confirmó la estructura de una calidad
más carrera fácil; los minutos concretos y el contenido siguen siendo una
propuesta deportiva para revisar antes de publicar. FAS usa el cálculo servidor
descrito a continuación; los otros programas mantienen esta vista previa.

### Piloto FAS: publicación y ejecución

`calculate_fas_running_week` resuelve la marca FAS de 2 km elegida, comprueba
vigencia, contexto actualizado, salud y días libres de la agenda global. El
servidor elige carrera fácil, calidad controlada o caminar/trotar. Con cuatro
semanas sin carrera, la capacidad cómoda declarada separa retorno (al menos
30 min) de inicio gradual (15 min); una capacidad ausente o cero bloquea la
pauta. En el retorno ofrece hasta dos días fáciles separados, sin exigir un
mes entero de carrera fácil. Es una dosis piloto `fas_running_week_v1`, no un
umbral fisiológico universal ni un ritmo calculado del 2 km.

La versión `fas_running_week_v2` distingue explícitamente carga previa y
disponibilidad futura. Los minutos de cada una de las cuatro semanas son el
total realmente corrido; los minutos por día indican cuánto tiempo cabe en
agenda. El caso de dos días y 50 minutos recientes, con 45 minutos disponibles
por día y 60 minutos de carrera cómoda declarada, propone inicialmente dos
salidas fáciles de 30 minutos. El aumento de diez minutos es una decisión
conservadora para este piloto, no una regla validada de porcentaje universal.
La persona ve la propuesta antes de publicarla y las ejecuciones gobiernan
la adaptación posterior. Una semana v1 ya publicada no se reescribe: si quedó
en una salida de 45 minutos y fue difícil, la siguiente puede recuperar dos
salidas fáciles de 25 minutos, sin calidad. La fecha objetivo se guarda en la
preparación, pero esta versión todavía no periodiza según esa fecha.

`publish_fas_running_week` conserva la entrada, referencia y motivos en
`running_week_decisions`, y crea plantillas de origen `algorithm` con bloques,
ejercicios, segmentos de carrera y entradas de `scheduled_workouts`. La
operación es atómica e idempotente por preparación y semana. «Mi semana» abre
estas sesiones mediante `start_scheduled_workout` en
`/plan/week/active/:id`, el mismo ejecutor de rutinas personales y de
biblioteca. Allí se registran parciales, recuperación y esfuerzo. No existe
un ejecutor paralelo del algoritmo.

Al preparar la semana siguiente una vez cerrada la anterior, se leen las
ejecuciones. Una sesión difícil o una semana incompleta mantiene la carga;
dos sesiones difíciles, con RPE de al menos 8 o duración inferior al 70 % de
la prevista, reducen; una semana completa y tolerada progresa una variable.
Desde `fas_running_week_v3`, una reducción de dos salidas de 30 min conserva
dos salidas de 25 min. Si ambas vuelven a resultar difíciles en ese suelo,
se solicita un contexto actualizado después de las ejecuciones antes de
ofrecer otra semana. Así no se repite una dosis mínima sin nueva información.
La falta de tiempo no cuenta como sobrecarga. Las molestias detienen la nueva
propuesta. La capacidad cómoda actual declarada también limita la duración
de las siguientes carreras; si baja de 30 min, solicita revisar el contexto.
La semana publicada permanece intacta. Aún faltan fuerza y la
coordinación de varias preparaciones; la siguiente semana se solicita y
publica desde la preparación, no aparece automáticamente al terminar sesión.
Para comprobar una política nueva sin alterar el historial, la preparación
ofrece una simulación de semana inicial sobre el mismo cálculo servidor. La
simulación descuenta solo las sesiones automáticas de esa preparación en la
semana comparada y no se puede publicar sobre una decisión ya existente. No
representa el ajuste posterior a las ejecuciones de la semana publicada.
Una segunda simulación de FAS sí lee las ejecuciones de la última semana
publicada para prever la siguiente. Exige que todas estén terminadas o
saltadas, utiliza el mismo cálculo de adaptación y omite solo la espera hasta
el domingo anterior a la nueva semana. No publica ni modifica la agenda; la
semana real se recalcula al solicitarla tras el cierre y puede diferir si el
usuario corrige resultados, actualiza contexto o aparece alguna limitación.
El catálogo automático FAS actual contiene carrera fácil, caminar/trotar
y calidad controlada de 4 × 2 o 5 × 2 minutos. No programa fartlek,
pirámides, series por distancia ni una zona 2 calculada por frecuencia cardíaca. En
la base `recent`, si la primera semana no incluye calidad, la política v4
puede introducir una única calidad controlada de 4 × 2 min tras dos semanas
completadas y toleradas, con dos salidas disponibles y al menos 32 min en la
primera. Es una regla provisional de producto, no un umbral fisiológico
validado. Antes, la política v3 solo aumentaba minutos fáciles en esa rama.
La v4 también corrige los tramos de la calidad para que trabajo,
recuperaciones, calentamiento y vuelta a la calma sumen la duración anunciada.
La v5 guarda una variante concreta en cada nueva sesión y permite pasar de
4 × 2 a 5 × 2 después de dos calidades comparables toleradas en ocho semanas,
si la semana previa progresa y la dosis cabe en la disponibilidad y capacidad
declaradas. Es una progresión provisional de una repetición, sin cambiar
simultáneamente la velocidad o recuperación; el tiempo final lo valida el
publicador y la plantilla sigue usando el ejecutor existente. Las decisiones
previas no se reescriben. La v6 exige además que los cuatro tramos de trabajo
de cada calidad anterior estén registrados con sus dos minutos completos;
no basta completar la sesión a nivel global. La especificación y sus límites deportivos se
documentan en `ESPECIFICACION_CEREBRO_CARRERA_2K.md`.
La distancia, la FC y la fecha objetivo no
intervienen en la adaptación semanal actual. Esta limitación debe corregirse
antes de tratar el piloto como un plan completo para 2 km.
En semanas consecutivas se reutiliza la disponibilidad y salud declaradas
durante un máximo de 30 días y se usan las ejecuciones, sin obligar a volver
a rellenar cuatro semanas cada lunes. Entre los días 31 y 45 de antigüedad
de una marca, la continuidad sí exige cuatro semanas actuales y confirmación.

## Corrección del inicio cuando falta carrera reciente

La vista previa v1 bloqueaba una persona con cero minutos en las cuatro semanas
porque su techo inicial es el mínimo entre última semana y media de cuatro.
Ese cero describe **carga reciente**, no capacidad actual ni experiencia previa.
Una marca de 2 km reciente acredita el rendimiento en esa distancia; tampoco
acredita por sí sola tolerancia a varios días de carrera. Ambos datos deben
convivir, sin convertir a quien vuelve de una pausa en principiante ni imponer
por defecto un mes completo de sesiones fáciles. La corrección PLAN-007 ya
pregunta la capacidad cómoda actual y ofrece una rama de retorno en FAS.

El recorrido de entrada recomendado es progresivo dentro de la preparación:

Las preferencias globales guardan días semanales, duración normal, experiencia
general y material. El formulario de carrera precarga la duración normal,
pero pide los días concretos. Si el usuario declara que no corrió en cuatro
semanas, registra cuatro ceros expresos sin exigir ocho cifras. En los demás
casos aún pide los cuatro pares semanales para limitar la carga.

1. Mostrar objetivo, pruebas pertinentes y marcas existentes elegibles. La
   elección del intento sigue siendo explícita.
2. Precargar días totales y duración habitual desde las preferencias generales;
   pedir solo los días concretos que puede entrenar y permitir ajustar minutos
   excepcionales. No deducir días de fuerza a partir del material disponible.
3. Preguntar capacidad de **carrera fácil continua** actual y continuidad
   reciente de carrera por separado. Un 2 km rápido no responde a la primera
   pregunta y «entreno con continuidad» en el perfil no responde a la segunda.
   El detalle semanal exacto puede pedirse cuando afecte a la dosis o para
   mejorarla, sin fabricar cuatro semanas de ceros cuando se desconoce.
4. Revisar molestias y limitaciones, presentar un resumen de los datos y una
   semana propuesta con motivos, duración, contenido y estado de publicación.

El vídeo de referencia muestra un recorrido legible de información del
programa, pocas preguntas sucesivas, resumen y sesiones visibles. Se toma ese
principio de orientación, sin copiar su estructura de fases, sus preguntas ni
su prescripción de calistenia. Ya existe el contrato persistente de capacidad
declarada v2 y una primera dosis piloto. Quedan por contrastar los umbrales
deportivos y mejorar la captura de semanas variables. No se pueden sustituir esos
campos por ceros ficticios ni usar la experiencia general como prueba de base
de carrera.

## Contrato de entrada propuesto

El objeto de dominio `RunningInitialContext` (`running_initial_context_v2`)
ya representa preparación concreta, disponibilidad por día, días reservados a
fuerza, semanas recientes de carrera, respuesta de salud fechada y una sola
referencia inicial (2 km oficial, Cooper o VAMEVAL) con protocolo. Su inspección
distingue cero
carrera de historial ausente, señala dolor/revisión y rechaza referencias de
otra preparación. Su disponibilidad, carga reciente y salud se guardan en
`running_intake_contexts` con RLS por preparación; la referencia sigue en sus
registros de origen; la elección explícita persiste origen e identificador en
`running_reference_selections` y FAS la revalida antes de publicar.
Tampoco decide vigencia deportiva, calcula ritmos ni publica una semana.
Es una base de captura, no un planificador listo.

El coordinador semanal entrega al componente de carrera un contexto ya ligado
a usuario, preparación, programa y semana. Cada dato conserva procedencia y
fecha; la ausencia es explícita, no cero.

1. **Disponibilidad:** días totales, días concretos, minutos máximos por día,
   huecos reservados a fuerza y otras preparaciones. Los días mixtos requieren
   una regla aprobada; hasta entonces no se asignan automáticamente.
2. **Estado reciente:** días y minutos de carrera de varias semanas, fuente
   declarada o registrada, sesiones omitidas, carga de pierna y recuperación.
3. **Salud:** dolor/molestia actual, necesidad de revisión y fecha de la
   respuesta. Dolor declarado bloquea la propuesta automática vigente.
4. **Rendimiento:** ancla con tipo de test, protocolo, versión, fecha, resultado,
   incidencias y estado `medido`, `estimado` o `inferido`. Solo un 2 km válido
   produce `current2kSpeedMps = 2000 / seconds` sin conversión adicional.
5. **Destino:** fecha de prueba y marca objetivo de 2 km si procede, con fuente.
   La marca objetivo no reemplaza la capacidad actual.
6. **Historial de decisiones:** versión de política, semana previa, estímulo
   trabajado, variable progresada y resultados comparables.

La ventana temporal RUN-005 se calcula por días civiles desde la medición:
0–30 días permite sugerir la marca, 31–45 días exige confirmar continuidad y
revisar las últimas cuatro semanas, y desde el día 46 la marca queda solo en
historial para este fin. Una fecha futura se rechaza. La elección y, cuando
procede, la confirmación condicional ya se guardan en «Datos para empezar».
Una semana sin carrera dentro del historial reciente o una molestia impiden
elegir una marca de 31–45 días. La compatibilidad de programa,
protocolo y resultado, el estado de salud y la carga reciente son comprobaciones
adicionales. Un rango permitido por SQL no equivale a una prueba válida para
prescribir. Si faltan datos esenciales,
el motor devuelve `needsInput` con razones específicas. Puede ofrecer una
familiarización por esfuerzo percibido cuando sea apropiada, pero nunca
fabrica un tiempo de 2 km a partir de Cooper o VAM.

## Contrato de salida propuesto

### Cerebro deportivo propio: criterio acordado y trabajo pendiente

La traducción inicial del planteamiento multi-ritmo de Javier a estado,
selección de estímulos, progresión y laboratorio está en
`ESPECIFICACION_CEREBRO_CARRERA_2K.md`. Es un borrador de diseño, no una política
deportiva publicada.

Javier descarta depender de una API externa facturada por cada planificación.
El conocimiento deportivo propio debe residir en un estado del deportista, un
catálogo pequeño de sesiones con propósito y dosis ajustables, y políticas
versionadas que seleccionen, coordinen y validen propuestas. Las decisiones
deben conservar sus entradas, motivos y versión y generar las sesiones mediante
el ejecutor existente. La conversación en lenguaje natural puede ser una capa
adicional; no define por sí sola la dosis ni acredita eficacia deportiva.

Se evaluará un modelo de pesos abiertos operado por EntrenaOP o en el dispositivo
para proponer y explicar opciones dentro de contratos estructurados. Esto evita
la factura de un proveedor de modelos por solicitud, pero sigue teniendo costes
de hardware, operación, distribución y evaluación. Aún no se ha elegido modelo,
licencia, lugar de ejecución ni entrenamiento adicional. Ninguna propuesta de
ese modelo se publicará sin comprobar reglas deportivas, disponibilidad,
seguridad, coherencia del contenido y trazabilidad. El piloto FAS actual no
contiene esta capa: solo conoce carrera fácil, caminar/trotar y una calidad fija
de 4 × 2 min; no elige entre 200 m, 400 m, fartlek y otras sesiones.

Antes de integrar una IA generativa hay que acordar el estado deportivo mínimo,
definir el catálogo versionado de carrera de 2 km, construir escenarios de
varias semanas con respuestas distintas y fijar criterios verificables para
comparar decisiones con revisión deportiva. Una simulación consistente prueba
las reglas de software, no demuestra por sí sola mejoras reales de rendimiento.

### Ciclo de adaptación acordado

El piloto FAS toma una nueva decisión cuando se consulta una semana futura
después de cerrar la anterior; lee entonces los registros de sus sesiones.
Dolor o limitación declarados bloquean la propuesta en esa consulta.
Una sola sesión peor de lo previsto se conserva como observación; no reduce
automáticamente la semana siguiente ni invalida la marca de referencia.
Acumula evidencia comparable de varias sesiones y distingue motivo de
omisión, esfuerzo, cambios voluntarios, ejecución incompleta y disponibilidad
real. El resultado posible para una semana futura es mantener, reducir,
progresar una variable o solicitar un dato/revisión. No duplica una sesión
omitida en el siguiente hueco ni modifica retrospectivamente la semana ya
realizada. Los umbrales implementados son v1 y requieren revisión deportiva.

`WorkoutExecution` ya conserva series planeadas y realizadas, RPE final y
motivo de abandono; `ScheduledWorkout` identifica sesiones completadas,
abandonadas u omitidas. `assessRunningExecution` solo clasifica coincidencia
con la prescripción como `onTarget`, `changed` o `incomplete`; `changed` no
equivale a mala tolerancia. FAS liga las ejecuciones de sus sesiones a la
decisión versionada siguiente. La interpretación de otras modalidades queda
pendiente.

El contrato futuro contempla estados `blocked`, `needsInput`, `proposed` y
`reviewRequired`; el piloto FAS aún no persiste esa máquina de estados. Si hay propuesta, cada sesión contiene: intención E/T/V/S/R,
calentamiento, tramos de trabajo, recuperaciones, vuelta a la calma, duración
total, indicaciones de esfuerzo, fuente/confianza del ritmo si lo hubiera y
motivo. La semana separa minutos fáciles, minutos de calidad y exposiciones
breves neuromusculares; también informa qué variable cambió respecto a la
semana comparable anterior.

El piloto FAS guarda preparación, referencia, política, plantillas y semana.
Una corrección de resultado no cambia la decisión ya publicada; la siguiente
consulta de semana futura puede leerla. La revisión formal de una semana
futura ya publicada queda pendiente.

## Secuencia de la primera vertical

1. **Contrato y casos de dominio.** Implementar el cálculo de velocidad y gap
   del 2 km, procedencia del ancla y estados de datos sin fijar todavía zonas,
   ritmos ni aumentos. Probar los casos A-D y entradas incompletas.
2. **Captura de contexto mínimo.** Separar días totales de días de carrera;
   capturar días concretos, carga reciente de carrera y fuerza de pierna,
   molestias y fecha de la respuesta. Mostrar qué dato falta antes de proponer.
3. **Semana inicial completa en simulador.** Usar un catálogo pequeño de
   sesiones revisadas, respetar minutos disponibles y conservar como máximo
   una calidad controlada inicialmente. Mostrar motivos y tiempo fácil/duro.
4. **Interpretación de la ejecución.** Convertir series y sesiones existentes
   en observaciones comparables. Distinguir sesión perdida, cambio voluntario,
   ejecución incompleta y fatiga; una observación aislada no progresa el plan.
5. **Segunda semana y adaptación.** Política versionada para mantener, reducir
   o progresar una sola variable. Pruebas con sesión fallida, semana perdida,
   nueva marca y reducción de disponibilidad. Descarga y taper son decisiones
   distintas y configurables.
6. **Publicación oficial.** Tras validar el recorrido en simulación,
   un servicio de confianza verifica propietario, programa, disponibilidad y
   duplicados; guarda la decisión auditable y publica plantillas y agenda en una
   transacción. Flutter no concede sesiones oficiales por sí mismo.

Los pasos 1–6 tienen un piloto de carrera FAS en desarrollo. La fuerza, la
coordinación multideporte, la descarga, el taper y la revisión de semanas ya
publicadas siguen pendientes. La dosis, la intensidad y la progresión actuales
requieren revisión deportiva; ningún porcentaje del piloto es constante
fisiológica universal.

## Casos de aceptación del recorrido

Una fecha objetivo a más de 365 días permanece guardada. La preparación
explica que la pauta de carrera se decide semana a semana con los datos
actuales: la fecha no equivale a una planificación cerrada de varios años.
La regresión v5 verifica que una fecha de 2029 permite proponer una semana en
fase general. Las trayectorias sintéticas llegan a un año; no acreditan la
idoneidad deportiva de mantener este proceso durante tres años.

- Con 11:00 actual y 7:30 objetivo, el sistema muestra un gap de velocidad de
  46,67 % y no prescribe automáticamente el ritmo objetivo.
- Dos días **totales** con fuerza reservada no se convierten en dos días de
  carrera más fuerza.
- Sin pulsómetro puede existir propuesta guiada por esfuerzo y conversación.
- Sin base reciente suficiente la primera semana no contiene calidad.
- Dolor o revisión profesional bloquean una nueva prescripción automática.
- Una sesión omitida no se repone de forma automática en un día duro contiguo.
- Cambiar de cuatro a dos días obliga a redistribuir la semana completa.
- Un nuevo 2 km válido cambia el ancla futura y conserva las decisiones previas.
- Cualquier semana oficial permite reconstruir qué datos y versión de reglas
  produjeron cada sesión.
