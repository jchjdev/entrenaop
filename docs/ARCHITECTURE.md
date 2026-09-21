# Arquitectura de EntrenaOP

## Estado observado

Instantánea comprobada en el repositorio el 19 de septiembre de 2026:

- Proyecto Flutter con destinos Android, iOS, web y Windows.
- Restricción de Dart en `pubspec.yaml`: `>=3.5.0 <4.0.0`.
- Dependencias declaradas para Bloc/Cubit, Equatable, `go_router`, GetIt,
  Supabase, vídeo, preferencias y utilidades.
- Estructura por funcionalidades con capas `domain`, `data` y `presentation` en
  autenticación y ejercicios.
- Autenticación, router y contenedor de dependencias presentes.
- La funcionalidad de ejercicios ya contiene entidad, contrato, casos de uso,
  modelo, datasource, repositorio y Cubit; cualquier documento que la describa
  como pendiente está desactualizado.
- La navegación autenticada dispone de un contenedor persistente con las áreas
  Inicio, Mi plan, Evolución y Perfil. En móvil utiliza una barra inferior y en
  pantallas amplias una navegación lateral.
- La URL y la clave pública de Supabase se inyectan por entorno. El desarrollo
  apunta a un proyecto aislado y no modifica producción.
- El catálogo remoto de Supabase ya está auditado. La línea base reconstruida y
  la primera migración de seguridad se encuentran en `supabase/migrations/`;
  todavía no se han aplicado a producción.
- El esquema heredado contiene cinco tablas de producto. Su campo
  `profiles.role` permanece temporalmente por compatibilidad, pero la migración
  crea `admin_permissions` como autoridad administrativa independiente y
  retira al cliente la capacidad de modificar `role`.

Esta sección es una instantánea, no sustituye una auditoría completa.

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
      domain/
      data/
      presentation/
    exercises/
    training/
    oppositions/
    clients/
    chat/
```

Los nombres y módulos futuros no se crearán hasta que su caso de uso lo exija.
La dependencia general debe orientarse hacia el dominio, sin impedir soluciones
más sencillas cuando una abstracción no aporte valor.

## Modelo de entrenamiento

No debe modelarse cada formato con columnas aisladas en una única tabla rígida.
El diseño tendrá que expresar una jerarquía versionada, por ejemplo:
planificación → sesión → bloques → ejercicios/intervalos → prescripción, junto a
un registro separado del resultado realizado. La forma definitiva se decidirá
tras concretar los casos de PAEF/PAFA.

La primera parte comprobable de esa jerarquía ya se modela mediante
`workout_templates → workout_blocks → workout_items → workout_sets`. Una serie
puede prescribir repeticiones, duración o distancia, además de carga, RPE/RIR y
descanso. Las tablas heredadas `routines`, `routine_exercises` y `session_logs`
se conservan temporalmente, pero no son el núcleo del nuevo recorrido.

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
- Las preparaciones, la planificación y las sesiones personales son conceptos
  distintos. Una futura planificación podrá atender varios objetivos sin sumar
  de forma ingenua planes incompatibles.
- Una marca física se guarda como hecho del usuario. Solo se reutiliza como
  resultado oficial entre preparaciones cuando prueba, unidad y protocolo son
  compatibles; en otros casos puede ser contexto del algoritmo, no puntuación.
- Estas preferencias son entradas de contexto, no una prescripción. No generan
  una rutina hasta que las reglas deportivas estén validadas y versionadas.
- Los eventos o resultados históricos deben ser inmutables o estar versionados
  cuando su modificación altere decisiones pasadas.
- Cada recomendación relevante del algoritmo debe guardar versión, entradas,
  salida, razones y cualquier anulación manual.
- La primera versión será determinista antes de estudiar técnicas menos
  explicables.

## Sesión activa y funcionamiento sin conexión

La sesión activa es una frontera de fiabilidad. Los temporizadores y las
mutaciones pendientes se persisten localmente para sobrevivir a un reinicio y
sincronizarse al recuperar la conexión. Esta solución se ha validado en la
sesión convencional antes de generalizarla a otros formatos.

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
de uso propio. Su estado siguiente solo puede ser completar evaluación,
completar disponibilidad, solicitar revisión profesional o esperar reglas
deportivas validadas. No calcula un porcentaje de progreso ni presenta una
prescripción que el dominio todavía no pueda justificar.

## Verificación

Después de cambios materiales se ejecutarán análisis estático y pruebas
relevantes. Tienen prioridad las pruebas de dominio, progresión, permisos,
versionado, persistencia de sesión y regresiones observadas.
