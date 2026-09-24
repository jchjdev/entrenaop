# Arquitectura de EntrenaOP

## Estado observado

Instantánea comprobada en el repositorio el 22 de septiembre de 2026:

- Proyecto Flutter con destinos Android, iOS, web y Windows.
- Restricción de Dart en `pubspec.yaml`: `>=3.9.0 <4.0.0`.
- Dependencias declaradas para Bloc/Cubit, Equatable, `go_router`, GetIt,
  Supabase, vídeo, preferencias y utilidades.
- Estructura por funcionalidades para autenticación, panel de inicio,
  ejercicios, evaluación física, preparaciones, perfil, preferencias, agenda y
  entrenamientos. Se usan capas `domain`, `data` y `presentation` cuando existe
  una frontera que las justifica.
- Autenticación, router y contenedor de dependencias presentes.
- El repositorio contiene 38 migraciones SQL ordenadas: línea base y
  saneamiento, evaluación y preferencias, múltiples preparaciones, plantillas y
  ejecuciones, resultados y correcciones, idempotencia offline, creador
  personal versionado, agenda, formatos avanzados de fuerza y Carrera V1.
- La navegación autenticada dispone de un contenedor persistente con las áreas
  Inicio, Mi plan, Evolución y Perfil. En móvil utiliza una barra inferior y en
  pantallas amplias una navegación lateral.
- La URL y la clave pública de Supabase se inyectan por entorno. El desarrollo
  apunta a un proyecto aislado y no modifica producción.
- El catálogo remoto original de Supabase fue auditado y su línea base quedó
  reconstruida. Las migraciones del repositorio son la fuente reproducible del
  esquema; esta revisión local no acredita por sí sola qué revisiones están
  desplegadas en producción.
- El esquema heredado contiene cinco tablas de producto. Su campo
  `profiles.role` permanece temporalmente por compatibilidad, pero la migración
  crea `admin_permissions` como autoridad administrativa independiente y
  retira al cliente la capacidad de modificar `role`.

Esta sección es una instantánea, no sustituye una auditoría completa.

Los recorridos manuales de fuerza V1 y Carrera V1 mínima están implementados de
extremo a extremo: biblioteca y sesiones privadas, creadores especializados,
agenda, vista previa, ejecución guiada, cola de mutaciones, historial y
corrección auditada. El
recorrido adaptativo sigue abierto: aún no hay prescripciones generadas a partir
de evaluación, disponibilidad, preparaciones y resultados.

## Clean Architecture aplicada a EntrenaOP

Clean Architecture se utilizará para proteger las reglas del producto y hacer
posible su evolución, no como una plantilla que obligue a crear el mismo número
de archivos para cualquier operación.

Los criterios son:

- Organización principal por funcionalidad, con alta cohesión dentro de cada
  módulo.
- El dominio de entrenamiento, baremos y progresión no dependerá de Flutter,
  Supabase ni detalles de interfaz.
- Las dependencias apuntarán hacia las reglas de negocio. La presentación y la
  persistencia adaptarán sus datos al dominio, no al revés.
- Se introducirán contratos en fronteras reales: base de datos, almacenamiento,
  compras, salud, notificaciones o servicios externos.
- Un caso de uso tendrá sentido cuando exprese una acción u orquestación del
  producto; no se añadirá una clase que solo reenvíe una llamada por cumplir una
  estructura.
- Los estados de Bloc/Cubit representarán estados relevantes de la experiencia,
  incluyendo carga, éxito, vacío, error y recuperación cuando corresponda.
- Las reglas críticas se probarán sin widgets ni red. Las integraciones se
  cubrirán con pruebas en sus fronteras.

La escalabilidad buscada consiste en poder añadir oposiciones, formatos de
sesión, entrenadores, derechos comerciales y organizaciones sin reescribir el
núcleo ni reinterpretar el historial. No consiste en construir hoy módulos que
todavía no tienen un caso de uso definido.

## Organización objetivo

La organización modular por funcionalidades es el punto de partida:

```text
lib/
  core/
    di/
    errors/
    navigation/
    router/
    theme/
    utils/
  features/
    auth/
    dashboard/
    exercises/
    physical_assessment/
    preparation_goal/
    profile/
    training_plan/
    workout_schedule/
    workouts/
```

Los nombres y módulos futuros no se crearán hasta que su caso de uso lo exija.
La dependencia general debe orientarse hacia el dominio, sin impedir soluciones
más sencillas cuando una abstracción no aporte valor.

## Modelo de entrenamiento

No se modela cada formato con columnas aisladas en una única tabla rígida. La
jerarquía actual separa plantilla, bloques, posiciones y series, y mantiene la
ejecución y sus resultados aparte. La planificación adaptativa deberá producir
esta misma estructura sin reinterpretar el historial existente.

La primera parte comprobable de esa jerarquía ya se modela mediante
`workout_templates → workout_blocks → workout_items → workout_sets`. Una serie
puede prescribir repeticiones, duración o distancia, además de carga, RPE/RIR y
descanso. Las tablas heredadas `routines`, `routine_exercises` y `session_logs`
se conservan temporalmente, pero no son el núcleo del nuevo recorrido.

Cada `workout_item` representa una posición ordenada dentro del bloque, no la
identidad única de un ejercicio. Dos posiciones pueden referenciar el mismo
ejercicio y mantener objetivos distintos; esto permite repetir una carrera u
otro movimiento en diferentes estaciones de un circuito, EMOM o AMRAP.

Al comenzar una sesión, `workout_executions` y `workout_execution_sets` copian
la identidad y la prescripción vigente de cada serie. El cliente registra los
resultados mediante funciones autenticadas y no puede insertar ejecuciones
arbitrarias. Esta copia constituye el primer límite histórico entre una
plantilla editable y el entrenamiento que realmente se realizó.

La copia de ejecución incluye también la descripción y la URL de vídeo del
ejercicio. La sesión activa muestra siempre la explicación y carga el vídeo
solo cuando el usuario lo solicita, evitando consumo innecesario de datos.

Cada serie conserva por separado objetivo y resultado real (repeticiones,
tiempo, distancia, carga y esfuerzo aplicables). Una omisión usa el estado
`skipped`, por lo que nunca se contabiliza como una serie completada. PostgreSQL
comprueba que el resultado incluya la métrica principal prescrita y que solo el
propietario pueda resolver una serie pendiente de su sesión activa.

Carrera exige distancia y tiempo reales por tramo para derivar el ritmo, y la
medida real de la recuperación que se hubiera prescrito. El RPE se guarda al
cerrar la sesión; FC media y máxima son opcionales. Tanto sesión como parciales
conservan `result_source` (`manual` o `device`) para que una futura importación
no mezcle datos medidos con declaraciones manuales. El cumplimiento se deriva
de todos los parciales: tolerancia del 1 % en distancia, 2 % en duración y 5 %
en recuperación, además del rango de ritmo; nunca se decide por el promedio.

AMRAP constituye una excepción deliberada al resultado por serie: el bloque
tiene un límite temporal global y persiste un agregado inmutable con vueltas
completas, ejercicio parcial y repeticiones parciales. La ejecución conserva
también una instantánea del límite para que cambios posteriores en la plantilla
no reinterpreten el historial.

Una serie completada puede corregirse durante las 24 horas siguientes, con un
máximo de tres cambios. La operación exige un motivo y conserva en una tabla de
auditoría los valores anteriores y posteriores; Flutter no dispone de permisos
para modificar directamente el resultado ni su registro de correcciones.

Salir de la pantalla mantiene la ejecución en curso y permite recuperarla. El
abandono es una transición terminal distinta que conserva las series resueltas,
deja las pendientes sin falsearlas como omitidas y registra un motivo
estructurado. Esta diferencia será una entrada auditable para la adaptación.

Modificar una plantilla no debe cambiar sesiones ya realizadas ni el baremo con
el que se evaluaron.

## Identidad, acceso y negocio

- Supabase Auth representa la identidad.
- El perfil contiene datos personales de la aplicación.
- Los permisos administrativos se modelan por separado.
- La suscripción y sus derechos se derivan de una fuente fiable y no pueden ser
  autoasignados desde Flutter.
- El seguimiento se representa como servicio/relación entre entrenador y
  cliente, con ciclo de vida propio.
- RLS debe autorizar cada operación según el recurso; el acceso no se reduce a
  “cada usuario solo ve sus filas”.
- Las operaciones sensibles pueden requerir funciones o backend de confianza.
- Un usuario podrá actuar como deportista y entrenador al mismo tiempo.
- La futura pertenencia a una academia se representará como membresía de una
  organización, no como un nuevo valor excluyente de `role`.
- Los derechos comerciales tendrán vigencia y fuente verificable; no se
  inferirán de la interfaz que esté viendo el usuario.

Conceptualmente se mantendrán separados:

```text
identidad
├── perfil personal
├── permisos administrativos
├── derechos comerciales
├── relaciones entrenador-cliente
└── membresías de organización (futuro)
```

## Datos y algoritmo

- Flutter valida entrada y ofrece feedback temprano.
- PostgreSQL conserva la integridad mediante constraints, relaciones y tipos.
- `training_preferences` guarda disponibilidad, duración, continuidad y
  material. La señal de revisión profesional bloquea una futura planificación
  automática sin almacenar diagnósticos ni texto médico.
- `preparation_programs` identifica recorridos estables, tanto de acceso como
  de evaluación interna. Sus baremos viven en catálogos versionados separados.
  `preparation_goals` guarda las preparaciones que sigue cada usuario y sus
  fechas objetivo. Puede mantener varias activas, pero no duplicar el mismo
  programa mientras permanezca activo.
- El programa `fas_periodic_assessment` está habilitado en desarrollo con
  registro repetible e historial propios. La migración
  `20260923006000_fas_periodic_assessments.sql` conserva versión, fecha, edad,
  categoría y marcas por prueba. Cada test pertenece al usuario; la preparación
  es contexto opcional y su propiedad se valida mediante RPC cuando se aporta.
  RLS limita la lectura al propietario. Los mínimos de 20 puntos del anexo II
  de DEF/15/2026 viven en PostgreSQL. El cliente contiene además el catálogo
  íntegro y versionado de 0–100 puntos y un calculador de dominio puro. La
  simulación no persiste nada, pero el usuario puede guardar explícitamente el
  test fechado en su historial personal sin crear una preparación. Ninguno
  equivale a aptitud oficial y la norma no define una puntuación total. Tropa
  conserva su catálogo e historial, sin reutilización de sus marcas.
  La fecha de nacimiento del perfil alimenta la edad calculada para cada
  intento; un trigger de PostgreSQL rechaza edades que no coincidan con esa
  fecha. El usuario puede corregir el perfil, sin alterar las marcas
  históricas. La categoría del baremo sigue declarada por el usuario.
- Las preparaciones, la planificación y las sesiones personales son conceptos
  distintos. `scheduled_workouts` actúa como agenda global del usuario y puede
  reunir distintas fuentes; una futura planificación adaptativa atenderá
  varios objetivos sin sumar de forma ingenua planes incompatibles.
- Una marca física se guarda como hecho del usuario. Solo se reutiliza como
  resultado oficial entre preparaciones cuando prueba, unidad y protocolo son
  compatibles; en otros casos puede ser contexto del algoritmo, no puntuación.
- El entrenamiento distingue cuatro niveles: ejercicio, plantilla de sesión,
  prescripción privada y ejecución. Una plantilla pública puede servir como
  estructura, pero el algoritmo genera una nueva versión privada con origen
  `algorithm`; no modifica la plantilla ni una prescripción histórica.
- `workout_templates.origin` separa contenido de sistema, usuario, entrenador y
  algoritmo. La biblioteca muestra únicamente plantillas públicas publicadas;
  las prescripciones adaptativas y las sesiones personales permanecen privadas.
- Las sesiones personales convencionales se crean mediante
  `create_personal_workout_template(jsonb)`. La función valida de nuevo el
  borrador y guarda plantilla, bloque, ejercicios y series en una única
  transacción; el cliente no encadena inserciones parciales.
- Los ejercicios propios se crean mediante `create_personal_exercise`. La
  función toma `auth.uid()` como propietario y fija en servidor `origin = user`
  e `is_public = false`; el cliente solo proporciona contenido descriptivo. El
  catálogo consulta contenido público y ejercicios propios, dejando que RLS
  descarte cualquier otro registro privado.
- `WorkoutEditorDraftStore` persiste localmente una instantánea completa del
  editor con espera corta entre cambios. La clave `new` separa una sesión aún
  no creada y cada plantilla existente usa su propio identificador. Guardar la
  sesión elimina el borrador; un dato local corrupto también se descarta sin
  impedir abrir el creador. Esta primera versión no sincroniza borradores entre
  dispositivos ni escribe en Supabase en cada pulsación.
- El borrador personal contiene de uno a diez bloques. Pueden ser
  convencionales, superseries, circuitos, intervalos de trabajo, Tabata, EMOM o
  AMRAP. Los formatos gobernados por rondas exigen una serie por ejercicio y
  ronda; Supabase vuelve a validar esa simetría. Los intervalos de trabajo
  admiten un solo ejercicio y no modelan carrera. Tabata materializa ocho
  posiciones de 20 segundos y 10 de pausa, repitiendo la secuencia de
  movimientos elegida cuando sea necesario.
- EMOM representa una secuencia de estaciones de un minuto. Cada ejercicio
  ocupa un minuto y las vueltas repiten el orden completo; la duración del
  bloque es `vueltas × ejercicios` y queda limitada a sesenta minutos. Al
  resolver una estación, el cliente calcula el tiempo restante hasta el
  siguiente minuto en vez de añadir un descanso completo.
- `workout_execution_sets.block_format` conserva el formato ejecutado. El
  cliente ordena los bloques agrupados o temporizados por ronda y después por
  ejercicio. En circuitos, el descanso prescrito en cada estación representa
  la transición a la siguiente; el descanso del bloque se usa al terminar la
  ronda. Superseries conservan únicamente la pausa final de la ronda.
- La carrera no se fuerza dentro de los intervalos de fuerza-resistencia. El
  formato `running` usa un único ítem estable y una lista ordenada de series que
  actúan como tramos. Cada tramo tiene exactamente un objetivo por distancia o
  duración, un ritmo exacto o rango opcional y recuperación propia pasiva,
  andando o trotando. Ritmo y recuperación se copian a
  `workout_execution_sets`; el resultado real exige distancia y duración y
  permite derivar el ritmo sin almacenarlo como una segunda verdad.
- Repeticiones y pirámides son ayudas del creador. La RPC recibe y valida la
  lista expandida, y los `CHECK` más un trigger relacional impiden usar campos
  de carrera en bloques de fuerza. El ejercicio de sistema `Carrera` sirve como
  ancla de la jerarquía, no como sustituto de los intervalos existentes.
- Especializar fuerza y carrera no crea dos planificadores aislados. Ambos
  motores propondrán estímulos dentro de su dominio y un coordinador de carga
  trabajará sobre la semana completa: objetivos simultáneos, fatiga,
  disponibilidad, proximidad entre sesiones y pruebas de cada preparación. El
  resultado seguirá siendo una prescripción versionada en la agenda común y
  podrá ser de fuerza, carrera o combinada.
- Duplicar una sesión copia atómicamente toda su jerarquía. Retirarla de la
  biblioteca significa archivarla, no borrar resultados históricos.
- `workout_templates.family_id`, `version` y `previous_version_id` relacionan
  las revisiones. Editar una sesión personal crea una plantilla nueva y archiva
  la anterior; las ejecuciones conservan tanto su referencia como su snapshot.
- Una entrada de `scheduled_workouts` fija el identificador de plantilla y una
  instantánea visible de nombre, versión y duración. Las escrituras se realizan
  mediante RPC y su estado se sincroniza desde la ejecución; el cliente no
  puede adjudicarse sesiones de otro usuario.
- `scheduled_workouts.preparation_goal_id` conecta opcionalmente una sesión con
  una preparación activa. No sustituye a `source`: la primera propiedad expresa
  para qué objetivo se entrena y la segunda conserva quién originó la plantilla
  (`system`, usuario, algoritmo o entrenador). La RPC disponible al deportista
  programa exclusivamente sesiones libres con vínculo nulo; asignar el objetivo
  queda reservado a servicios de confianza. PostgreSQL también impide al
  deportista reprogramar o retirar una sesión oficial ya pautada.
- `GetPreparationDetailUseCase` compone preparaciones, evaluaciones y agenda sin
  inventar una prescripción. Selecciona la evaluación más reciente cuyo catálogo
  coincide con el catálogo vigente del programa y filtra la semana por el
  identificador estable de la preparación.
- Al comenzar, la ejecución copia la prescripción efectiva por serie. El
  historial no cambia aunque después evolucione la plantilla o el algoritmo.
- Estas preferencias son entradas de contexto, no una prescripción. No generan
  una rutina hasta que las reglas deportivas estén validadas y versionadas.
- Los eventos o resultados históricos deben ser inmutables o estar versionados
  cuando su modificación altere decisiones pasadas.
- Cada recomendación relevante del algoritmo debe guardar versión, entradas,
  salida, razones y cualquier anulación manual.
- La primera versión será determinista antes de estudiar técnicas menos
  explicables.

### Autoría oficial y generación adaptativa

El futuro plan oficial separará dos responsabilidades que no deben confundirse:

1. **Autoría deportiva:** Javier define programas, fases, criterios de avance,
   límites y sesiones base. Ese contenido se publica en versiones inmutables.
   Al principio puede cargarse mediante migraciones o datos revisados en Git.
   `admin_app/` es una aplicación Flutter web independiente dentro del mismo
   repositorio. Crea programas y sesiones oficiales en borrador. El paquete
   Dart puro `packages/workout_core/` comparte modelo, validaciones,
   estimación de carrera, serialización y lectura de plantillas entre panel y
   app del opositor; no comparte navegación ni guardado personal. El paquete
   Flutter `packages/workout_editor_ui/` comparte campos de tramos de carrera,
   búsqueda de ejercicios, selector de formatos y campos de series de fuerza.
   La organización de bloques y repeticiones aún se adapta en cada pantalla;
   la publicación y la edición personal siguen siendo responsabilidades
   distintas. La función
   `create_admin_workout_draft` exige `admin_permissions`, crea la sesión
   privada y registra su destino en `program_workout_templates` en una
   transacción. El destino `general` puede publicarse en la biblioteca abierta;
   el destino `program` permanece privado aunque esté publicado, reservado para
   la futura prescripción de esa preparación. Ninguno crea agenda.
   La edición de borradores reemplaza la versión privada; revisar una sesión
   publicada crea otra versión en borrador y conserva el historial. La retirada
   de sesiones publicadas archiva, mientras que un borrador sin referencias
   puede borrarse físicamente.
   Una sesión con agenda pendiente o en curso no puede retirarse hasta resolver
   esas citas, pues su ejecución todavía necesita leer la plantilla.
   La app del deportista no importa código administrativo y no puede publicar
   ni asignar estas sesiones. Aún faltan fases y reglas.
2. **Prescripción individual:** un servicio de confianza ejecuta reglas
   deterministas y versionadas sobre preparación, marcas, disponibilidad e
   historial. Selecciona o materializa la sesión privada correspondiente, la
   registra con origen `algorithm` y la coloca en la agenda con sus entradas y
   razones auditables.

Flutter se limita a recoger contexto, mostrar la explicación, iniciar la sesión
y registrar el resultado real. No publica reglas, no asigna
`preparation_goal_id` y no decide progresiones. El panel administrativo tampoco
debe convertirse en una planificación manual diaria para todos los usuarios:
servirá para diseñar, validar, publicar y, en una fase profesional, anular una
decisión concreta dejando auditoría.

La primera vertical adaptativa no necesita esperar al panel. Debe validar antes
el modelo versionado y el motor con un único programa de Tropa y Marinería; así
el panel se construirá sobre reglas reales y no fijará prematuramente una
interfaz equivocada.

## Sesión activa y funcionamiento sin conexión

La sesión activa es una frontera de fiabilidad. Los temporizadores y las
mutaciones pendientes se persisten localmente para sobrevivir a un reinicio y
sincronizarse al recuperar la conexión. La misma base se usa ya en sesiones
convencionales, superseries, circuitos, intervalos, Tabata, EMOM y AMRAP.

El servidor seguirá siendo la autoridad para permisos, derechos comerciales,
asignaciones y datos consolidados. El soporte local no debe convertirse en una
forma de eludir reglas de negocio o seguridad.

Los temporizadores de series usan una instantánea local con fase, instante de
inicio y tiempo acumulado. Así pueden reconstruirse después de salir de la
pantalla o reiniciar la aplicación sin escribir continuamente en Supabase. La
instantánea se elimina al completar, omitir o abandonar la serie.

Completar u omitir una serie y finalizar o abandonar una sesión pasan por una
cola persistente. Cada mutación conserva un UUID estable y el servidor registra
un recibo dentro de la misma transacción que el cambio. Así, un reintento tras
una respuesta perdida no aplica dos veces la operación. Flutter muestra el
resultado de forma optimista y avisa mientras existan cambios pendientes. Las
validaciones y los permisos siguen ejecutándose en PostgreSQL; las correcciones
históricas permanecen deliberadamente en línea por ser una operación auditada.

El límite es deliberado: la cola no replica el catálogo ni la agenda y no
permite arrancar offline una sesión nunca cargada. Tampoco sincroniza entre
dispositivos los borradores del editor o las instantáneas de temporizador.

Los avisos acústicos y hápticos usan capacidades de Flutter y preferencias
locales, sin introducir permisos ni dependencias nativas adicionales. Los
eventos del temporizador no contienen reglas de negocio y pueden silenciarse de
forma independiente desde la sesión activa.

## Navegación y presentación

`go_router` gestiona las rutas. El área autenticada usa
`StatefulShellRoute.indexedStack` para conservar el estado independiente de
Inicio, Mi plan, Evolución y Perfil. `AppShell` representa esos destinos como
`NavigationBar` en móvil y `NavigationRail` en pantallas amplias. La evaluación
inicial queda fuera del contenedor porque es un flujo concentrado y temporal.

Evolución es una sección, no un sinónimo de valoración física. Su raíz muestra
por ahora el historial de sesiones terminadas y ofrece acceso al historial de
evaluaciones físicas mediante una ruta anidada. Esta jerarquía permite añadir
más adelante resumen de progreso, marcas y comparación con baremos sin cambiar
la navegación principal ni mezclar datos de distinta naturaleza.

`go` sustituye la ubicación, `push` apila un flujo temporal y `pop` vuelve; se
elige cada operación según la experiencia de usuario.

El panel de Inicio compone datos de evaluación y preferencias mediante un caso
de uso propio. También lee la semana natural de la agenda para presentar siete
días compactos y abrir la fecha elegida sin duplicar las acciones de edición de
`Mi semana`. Su estado siguiente solo puede ser completar evaluación,
completar disponibilidad, solicitar revisión profesional o esperar reglas
deportivas validadas. No calcula un porcentaje de progreso ni presenta una
prescripción que el dominio todavía no pueda justificar.

## Verificación

Después de cambios materiales se ejecutarán análisis estático y pruebas
relevantes. Tienen prioridad las pruebas de dominio, progresión, permisos,
versionado, persistencia de sesión y regresiones observadas.
