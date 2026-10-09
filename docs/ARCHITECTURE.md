# Arquitectura de EntrenaOP

## Descarte confirmado de una sesión en curso · UI-022 · 09/10/2026

`discard_workout_execution(uuid,text)` valida cuenta, propiedad, confirmación y
estado en servidor. Bloquea los recursos, restaura la cita a `planned` con
ejecución nula y elimina la ejecución y sus resultados dependientes. Conserva
la cita, plantilla, preparación y pauta; rechaza resultados ya cerrados.
La tabla privada de descartes retiene únicamente identificadores y fecha para
repetir peticiones y acreditar el descarte de colas tardías de la misma cuenta.
No concede borrado directo ni lectura de esa tabla al cliente.

El repositorio requiere confirmación remota antes de limpiar la cola propia;
no encola el descarte ni sincroniza previamente los datos descartables. Una
mutación tardía fallida se retira solo si la RPC de consulta acredita ese
recurso descartado para la cuenta actual. El cubit conserva la sesión/borrador
ante error y limpia temporizadores al confirmar. La navegación mantiene el
guard y `go_router`. Migración `20261009000000`, solo desarrollo: 134
coincidentes y tres pruebas SQL transaccionales con `ROLLBACK` correctas.
[Contrato completo y límites](UX_REVIEW_2026_10_09.md).

## Retorno a la propuesta y contexto común · UI-021 · 08/10/2026

El repositorio de entrenamiento consulta la ejecución `in_progress` de la cuenta
actual en `scheduled_workouts`, con filtro explícito de usuario incluso si también
es administrador. Usa el contrato de lectura/RLS existente y no limita semana o
preparación, porque cualquiera puede bloquear la activación. La presentación
abre su ID mediante `go_router.push` y al volver recarga datos y propuesta sin
reinicializar el asistente. Flutter orienta; el servidor sigue validando la
activación. Mi plan resume el contexto de cuenta existente, sin otra persistencia
ni reglas de prescripción en el widget. Análisis y pruebas de app correctos;
133 migraciones coincidentes en desarrollo, sin cambios SQL.
[Contrato, recorrido y límites](PLAN_COHERENCE_2026_10_08.md).

## Portadas editoriales · UI-006 · 06/10/2026

La identidad fotográfica es independiente del contenido deportivo publicado.
`preparation_program_covers` enlaza una portada opcional por programa; la RPC
administrativa valida archivos, encuadre y revisión antes de actualizarla.
Storage público usa rutas inmutables y políticas de subida/limpieza administrativas.
No modifica baremos, planificación ni historial. Admin: contrato de dominio →
repositorio Supabase → Storage/RPC; el editor guarda únicamente tras confirmar.
Deportista: datasource resuelve rutas → modelo de programa con portada opcional →
presentación. `entrena_ui` comparte el tratamiento gráfico y `workout_editor_ui`
la optimización de fotografías, sin incorporar Supabase a los paquetes visuales.
Tarjeta y cabecera comparten fotografía pero tienen puntos de interés separados.
`set_admin_program_cover_v2` persiste ambos; la RPC anterior conserva la cabecera
de portadas existentes. La ampliación inicializa el punto de cabecera con el
anterior, sin alterar fotos ni reglas deportivas.
Migraciones `20261006003000` / `20261006004000` / `20261006005000` y pruebas SQL verificadas solo
en desarrollo. Numeración separada del trabajo paralelo; no cambia el SQL aplicado.
Detalles y límites:
[VISUAL_DESIGN.md](VISUAL_DESIGN.md).

## Estrategias y estado de fases v3 · 06/10/2026

`performance_block_v3`, `performance_task_v3` y `performance_select_v3` separan
estado, dosis y elección del repertorio. El coordinador v3 compara alternativas
con/sin apoyos y conserva las guardas comunes; el gestor automático continúa
publicando resultados versionados. Referencias activas únicas por preparación,
objetivo, variante y medición permiten series libres/temporales independientes.
Las RPC validan propiedad; helpers y materializadores nuevos no son públicos.

`AdaptiveProgramPath` traduce la instantánea, sin decidir progresiones.
Presentación separa fase real y previsión e inicia calibración de una variante
sin precargar capacidad. El calentamiento usa instrucciones copiadas al iniciar;
`ActiveWorkoutCubit` omite los pasos mediante las mutaciones/cola existentes.
Carrera v5 y su adaptador quedan sin redefinir. Detalle, generación de migración,
tests y límites: [ESTRATEGIAS_RENDIMIENTO_V3.md](ESTRATEGIAS_RENDIMIENTO_V3.md).

## Selección y pausa de programa · STR-027 · 04/10/2026

El dominio de Flutter incorpora `TrainingScope` en `PreparationTrainingRepository`.
La capa de datos traduce su selección a las RPC; presentación organiza los pasos
pertinentes sin ejecutar progresiones. El servidor conserva selección activa y
borrador por preparación, estado reanudable y un único generador por deportista
mediante índice parcial y bloqueo por perfil. La aceptación revalida propuesta,
pausa otros programas y cancela solo sesiones automáticas sin empezar en una
transacción. El historial y las marcas conservan sus identidades originales.

El coordinador v2.2 (ampliado por v3 el 06/10) excluye familias según la selección activa y conserva tiempo,
agenda y recuperación comunes. Carrera v5 mantiene sus reglas; su adaptador
lee resultados compatibles del usuario entre preparaciones, sin sustituir la
referencia propia. Retomar revisa el calendario actual y las guardas existentes.
Migración `20261004012000` aplicada y verificada solo en desarrollo.
Contratos y límites: [PROGRAMA_ADAPTATIVO.md](PROGRAMA_ADAPTATIVO.md).

## Gestor de programa · STR-023 · 04/10/2026

Tres responsabilidades dentro del servidor: estrategias deportivas, coordinador
de propuestas y ciclo de programa. El gestor no duplica reglas de carrera/fuerza.
`refresh_adaptive_programs` recupera la continuidad de programas propios antes
de consultar las sesiones desde Inicio o agenda. Devuelve estados tipados para
Flutter mediante `PreparationTrainingRepository`; Cubit y el caso de uso de
Inicio esperan esa recuperación antes de leer la agenda. El disparador de cierre
sigue siendo la vía inmediata. No hay selección de modo automático/manual,
ni se ejecuta cálculo deportivo en la pantalla.
Los mensajes de espera por fechas y las revisiones pendientes son datos del
servidor. Contrato y pruebas: [PROGRAMA_ADAPTATIVO.md](PROGRAMA_ADAPTATIVO.md).

## Continuidad de programa · STR-022 · 04/10/2026

`PreparationTrainingRepository` conserva la frontera de Flutter. El servidor
valida fecha/metas, guarda `adaptive_program_states` y publica la siguiente
decisión al cerrar todas las sesiones. Un error al adaptar no revierte el
resultado del entrenamiento. Publicación idempotente y cierre explícito;
las cancelaciones internas de sesiones mixtas no disparan continuidad.
Carrera reutiliza su formulario con disponibilidad común y sus controles de
2 km, incluidos FAS y programas compatibles. El motor v5 no se modifica.
Contrato, verificación y límites: [PROGRAMA_ADAPTATIVO.md](PROGRAMA_ADAPTATIVO.md).

## Coordinación de rendimiento v2.1 · 04/10/2026

PostgreSQL selecciona estímulos/dosis y conserva instantáneas versionadas.
Flutter presenta referencias/decisiones; `workout_core` comparte medición y
esfuerzo. En días mixtos, una plantilla ordena segmentos nativos de carrera y
bloques de rendimiento; ambas familias enlazan la misma sesión. El adaptador
extrae solo tramos y esfuerzo de carrera. `running_plan_v5` conserva sus reglas.
Contrato y límites: [MOTOR_FUERZA_RENDIMIENTO_V2.md](MOTOR_FUERZA_RENDIMIENTO_V2.md).

## Carrera: selección v5 verificada en desarrollo el 01/10/2026

Motor `running_2k_v5` aplicado en **entrenaop-dev**. FAS, Tropa y programas
con prueba vinculada al módulo 2 km usan un único planificador de servidor,
con sus propias marcas y baremos. Reutiliza agenda y ejecutor; no hay IA de
pago ni selector deportivo en Flutter. Incluye objetivos libre/tiempo/margen,
lectura de registros incompletos, contraste del RPE y vuelta gradual tras fatiga.
V3 corrigió encaje de calidad y repetición del foco; v4 añade dosis repartida
al pasar a dos calidades; v5 permite progresar minutos fáciles al mantenerlas.
Recomendaciones de disponibilidad sin modificar la elección.

Verificados 1.573 semanas sintéticas e integración SQL con ROLLBACK. En la
app, prueba del formulario y análisis Flutter limpios; la batería completa de 237
pruebas corresponde al cierre anterior. El visor v3 histórico compara 13 perfiles en seis
horizontes; el comparador controlado de 2/3/4/5 días sigue pendiente. Las simulaciones
no demuestran eficacia deportiva.

**Bloque deportivo todavía abierto. Único siguiente tramo:** incorporar con
prudencia la experiencia de calidad previa al alta; después aclarar el RPE alto
persistente y verificar el recorrido completo. Límites y evidencia en
[`MOTOR_CARRERA_2K_V5.md`](MOTOR_CARRERA_2K_V5.md). La interfaz se verificó por
widgets y el visor en navegador; falta el recorrido completo de la app
recompilada en navegador. Producción no modificada. Esta revisión localizada
no certifica los bloques ajenos ni sustituye su instantánea general anterior.


## Presencia web provisional

`website/` contiene una página HTML estática de presentación y su política de
privacidad. Se publica en el alojamiento PHP/HTML de Hostinger, con
`entrenaop.es` como dominio, de forma independiente y sin desplegar la
aplicación Flutter del deportista ni `admin_app/`.
La web describe el proyecto en desarrollo; no ofrece inicio de sesión ni
integración con Garmin.
Los archivos publicados están en `website/dist/` y en `public_html/` del sitio
EntrenaOP de Hostinger. La antigua publicación en Sites permanece privada como
copia de respaldo; su dominio personalizado está desvinculado. El manifiesto
`website/.openai/hosting.json` corresponde únicamente a esa copia antigua.

La visión acordada para la web pública es que sirva de puerta de entrada a la
aplicación del deportista y a espacios diferenciados para administración y
entrenadores. Podrán tener despliegues independientes y enlazarse desde la web
principal bajo el mismo dominio. La app del deportista ya tiene destino web y
`admin_app/` es una aplicación Flutter web separada; todavía no se han publicado
en subdominios ni existe un portal de entrenadores. Los nombres de las rutas,
la experiencia de acceso y la posible reutilización de interfaz se decidirán
al implementar cada espacio. Los permisos administrativos y las relaciones
entrenador-cliente seguirán siendo contratos distintos en el backend.

`website/next/` contiene un borrador local de la futura web de presentación.
Resume el recorrido que existe en desarrollo, anuncia iPhone y Android sin
ofrecer descargas y reserva entradas visibles pero desactivadas para
administración y entrenadores. No reemplaza `website/dist/` ni está desplegado.
Antes de habilitar esos accesos habrá que publicar cada panel y verificar sus
permisos y rutas reales.

## Desarrollo iOS en macOS · IOS-001 · 08/10/2026

La configuración nativa está adaptada a Flutter 3.47.5/Dart 3.13.4: mínimo
iOS 15, ciclo de vida `UIScene` y plugins mediante Swift Package Manager.
El registro de plugins ocurre al inicializar el motor implícito. Se conservan
`FlutterDeepLinkingEnabled=false` y el esquema `es.entrenaop` para Supabase.
Compilación y arranque comprobados en iPhone 17 Pro con iOS 26.3.1, usando solo
Supabase de desarrollo; análisis limpio y 591 pruebas correctas (una exclusiva
web omitida). No acredita aún un recorrido autenticado ni correo real en iOS.
Herramientas, comandos y límites en [IOS_DEVELOPMENT.md](IOS_DEVELOPMENT.md).

## Estado observado

Instantánea contrastada en código, análisis, pruebas y Supabase de desarrollo
el 6 de octubre de 2026. Alcance y limitaciones en
[AUDIT_2026_10_06.md](AUDIT_2026_10_06.md); no acredita producción ni recorridos
autenticados en dispositivos:

- Aplicación Flutter del deportista con destinos Android, iOS, web y Windows, y
  aplicación Flutter web independiente en `admin_app/` para autoría oficial.
- Toolchain instalado y verificado: Flutter 3.47.5 y Dart 3.13.4; Dart
  `>=3.13.0 <4.0.0`, coherente en ambas aplicaciones y paquetes compartidos.
- Dependencias declaradas para Bloc/Cubit, Equatable, `go_router`, GetIt,
  Supabase, vídeo, preferencias y utilidades.
- Estructura por funcionalidades para autenticación, panel de inicio,
  ejercicios, biblioteca, herramientas de carrera, evaluación física y por
  programa, preparaciones, perfil, contexto, agenda y entrenamientos.
  Se usan capas `domain`, `data` y `presentation` cuando existe
  una frontera que las justifica.
- Autenticación, router y contenedor de dependencias presentes.
- El árbol local contiene 131 migraciones SQL ordenadas: línea base y
  saneamiento, evaluación y preferencias, múltiples preparaciones, plantillas y
  ejecuciones, resultados y correcciones, idempotencia offline, creador
  personal versionado, agenda, formatos avanzados de fuerza, Carrera V1,
  autoría administrativa, evaluación periódica FAS 2027 y configurable,
  carrera 2 km v5, rendimiento v3, coordinación, ciclo adaptativo,
  contexto compartido y portadas editoriales. El historial de desarrollo
  coincide; 81 migraciones aún no estaban en Git al comenzar la auditoría.
- `packages/workout_core/` comparte contratos y validación de sesiones y
  ejercicios entre ambas aplicaciones; `packages/workout_editor_ui/` comparte
  sus formularios y controles de edición sin mezclar navegación, persistencia
  ni permisos.
- `packages/entrena_ui/` concentra tema, tokens semánticos, tarjetas de marca
  y wordmark de ambas aplicaciones. Solo depende de Flutter y no contiene
  navegación, persistencia, permisos ni reglas de negocio. La densidad y la
  composición de cada pantalla siguen perteneciendo a su aplicación.
- La navegación autenticada dispone de un contenedor persistente con las áreas
  Inicio, Mi plan, Biblioteca, Evolución y Perfil. En móvil utiliza una barra
  inferior, con Biblioteca en el centro; en pantallas amplias, navegación lateral.
  Biblioteca agrupa contenido público de EntrenaOP y contenido personal; Mi plan
  conserva planificación y prescripción. Los editores y repositorios existentes
  se reutilizan. La consulta nueva de ejercicios usa un Cubit y el caso de uso
  de lectura actual, sin acceder a Supabase desde las pantallas. Las URLs antiguas
  de sesiones se conservan dentro de la rama de Biblioteca (UI-003).
- La URL y la clave pública de Supabase se inyectan por entorno. El desarrollo
  apunta a un proyecto aislado y no modifica producción.
- El catálogo remoto original de Supabase fue auditado y su línea base quedó
  reconstruida. Las migraciones del repositorio son la fuente reproducible del
  esquema; esta revisión local no acredita por sí sola qué revisiones están
  desplegadas en producción.
- La línea base heredada contenía cinco tablas de producto; desarrollo tiene
  ahora 51 tablas públicas, todas con RLS. El campo heredado
  `profiles.role` permanece temporalmente por compatibilidad, pero la migración
  crea `admin_permissions` como autoridad administrativa independiente y
  retira al cliente la capacidad de modificar `role`.

Esta sección es una instantánea, no sustituye una auditoría completa.

Los recorridos manuales de fuerza V1 y Carrera V1 mínima están implementados de
extremo a extremo: biblioteca y sesiones privadas, creadores especializados,
agenda, vista previa, ejecución guiada, cola de mutaciones, historial y
corrección auditada. El
recorrido adaptativo 2 km ya genera prescripciones en desarrollo a partir de
marca, contexto, disponibilidad y resultados. La coordinación con rendimiento
y la continuidad automática están implementadas; el bloque deportivo mantiene
los límites descritos en `PROGRAMA_ADAPTATIVO.md`.

## Clean Architecture aplicada a EntrenaOP

Javier reafirma el 03/10/2026 que este es el criterio permanente del proyecto.
Los contratos deportivos compartidos conservan entidades y validaciones puras;
sus codecs JSON y adaptadores de Supabase pertenecen a la capa de datos.

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

UI-016 añade `session_type` y `session_type_policy` a esa instantánea. El trigger
de inserción clasifica los bloques de la plantilla según `block_format_v1`:
`running`, `strength` o `mixed`, excluyendo calentamiento y vuelta a la calma
como trabajo adicional. La familia sin carrera se presenta como fuerza y
acondicionamiento. Ambos campos quedan inmutables mediante trigger y `CHECK`;
no amplía permisos de escritura. Las ejecuciones anteriores conservan `NULL`,
incluidas las que estaban en curso, sin backfill ni inferencia al leer o reanudar.
El detalle y sus pruebas se registran en `HISTORY_SESSION_TYPE_2026_10_08.md`.

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
UI-019 corrige la visibilidad del abandono: depende de la ejecución en curso,
no de que queden series pendientes, y sigue disponible esperando el cierre final.
UI-022 añade Salir sin guardar como descarte explícito de la ejecución en curso,
incluidas sus series registradas, mediante una RPC distinta del abandono.
UI-020 ofrece desde la flecha seguir, retomar o abandonar con la misma operación
y motivo que el botón inferior. `WorkflowDraftGuard.confirmExit` es opcional y
se ejecuta después de los controles existentes de guardado/borrador; los demás
formularios conservan su confirmación predeterminada. Un fallo de abandono no
autoriza al router a salir. Los tiempos escritos por el reloj o por el objetivo
se convierten de segundos a min:seg; el resultado mantiene segundos reales,
sin aplicar a esos valores el formateador de dígitos destinado al teclado.
Estado, alcance y regresiones de salidas en
[SESSION_CONTROLS_2026_10_08.md](SESSION_CONTROLS_2026_10_08.md).

Modificar una plantilla no debe cambiar sesiones ya realizadas ni el baremo con
el que se evaluaron.

## Identidad, acceso y negocio

### Recuperación y confirmación · UI-013 · 08/10/2026

`AuthSessionChange` diferencia perfil autenticado y sesión de recuperación.
El datasource conserva `AuthChangeEvent.passwordRecovery` del SDK; el Cubit lo
presenta y `go_router` mantiene la ruta de contraseña hasta terminar/cancelar.
El arranque escucha `initialSession` en un único flujo, sin una consulta paralela
que pudiera restaurar el perfil y saltarse el recorrido. Lecturas/respuestas
anteriores se descartan al cambiar o cerrar la identidad; renovar la misma
recuperación no reemplaza guardado ni confirmación.

Solicitud, reenvío y actualización usan Supabase Auth/PKCE; el servidor autoriza
el cambio. El nuevo marcador de preferencias guarda propietario y éxito visible,
solo para restaurar la interfaz con la sesión actual del SDK. No almacena la
nueva contraseña ni tokens del enlace; no modifica la persistencia de sesión
del SDK. La guarda de página no representa una restricción de permisos de
Supabase. Terminar/cancelar usa `SignOutScope.local`.

`AuthRedirect` resuelve el retorno por entorno: origen/path web sin parámetros,
callback móvil `es.entrenaop://auth-callback/` y override `AUTH_REDIRECT_URL`.
HTTP local se permite únicamente en desarrollo; se rechazan credenciales,
consulta o fragmento en el destino. Android/iOS entregan el callback al SDK,
con la interpretación automática de Flutter desactivada. La configuración
parcial en `tools/account_access_dev/supabase/config.toml` declara únicamente
retornos de desarrollo y conserva las demás propiedades remotas. No se cambia
RLS, rol, derechos comerciales ni producción. Pruebas del SDK con HTTP simulado
y configuración remota comprobada. Compilación y arranque iOS comprobados en
IOS-001; el recorrido de correo real en iOS y dispositivo físico sigue pendiente.
Alcance y límites en
[REFRESH_ACCOUNT_2026_10_08.md](REFRESH_ACCOUNT_2026_10_08.md).

### Separación de responsabilidades

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
- `program_assessment_tests` guarda las definiciones que el administrador crea
  para programas borrador: nombre, unidad, dirección favorable, protocolo,
  orden y columna H/M aplicable. `program_assessment_scoring_rules` conserva
  fuente, versión y regla global; `program_assessment_score_bands` guarda los
  tramos de marca y puntos por columna. Las RPC limitan la autoría al admin y
  evitan intervalos solapados. La simulación calcula puntos y aprobado sin
  persistir marcas. El borrador CNP 2026 contiene el anexo II del BOE como
  primer ejemplo completo, todavía no publicado ni conectado a la captura del
  deportista. Los catálogos oficiales existentes de Tropa y FAS permanecen
  independientes.
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
  Una RPC permite asociar expresamente un test personal de los últimos 30 días
  a una preparación activa del mismo usuario y del programa FAS. Conserva las
  marcas y la fecha y rechaza test ajenos, antiguos o ya asociados. Este límite
  es provisional y específico de la asociación FAS.
  La fecha de nacimiento del perfil alimenta la edad calculada para cada
  intento; un trigger de PostgreSQL rechaza edades que no coincidan con esa
  fecha. El usuario puede corregir el perfil, sin alterar las marcas
  históricas. La categoría del baremo sigue declarada por el usuario.
- Las preparaciones, la planificación y las sesiones personales son conceptos
  distintos. `scheduled_workouts` actúa como agenda global del usuario y puede
  reunir distintas fuentes; una futura planificación adaptativa atenderá
  varios objetivos sin sumar de forma ingenua planes incompatibles.
- Fuerza/rendimiento usa reglas puras en PostgreSQL y adaptadores autenticados,
  junto a un repositorio de aplicación que no expone Supabase a presentación.
  `performance_v1_1` prescribe desde calibración y ejecuciones; el coordinador
  solicita a `running_2k_v5` propuestas restringidas por agenda, tiempo y regiones.
  Perfil/protocolo/montaje, dosis y resultados conservan versiones y evidencia.
  La publicación conjunta es transaccional e idempotente, usando plantillas,
  agenda, ejecutor, cola offline e historial existentes. RLS permite lectura
  propia y exige RPC para escribir. ADMIN vincula estrategias revisadas a pruebas
  de programas borrador; FAS/Tropa conservan adaptadores de sus catálogos.
  Hay 64 perfiles públicos: catálogo v1 de 63 variantes y ampliación v2 del
  circuito de 16 m. Los laboratorios Dart anteriores son experimentales, no
  otra autoridad de prescripción. Se reserva la agenda global, sin afirmar
  optimización simultánea de todos los programas. Detalle:
  `docs/MOTOR_FUERZA_RENDIMIENTO_V1.md`.
- STR-019 conserva instrucciones propias del elemento de sesión en
  `workout_execution_sets.item_instructions`: el servidor las copia al iniciar
  y rechaza su modificación. La presentación las mantiene al registrar resultados;
  los históricos anteriores quedan sin ese dato, sin reconstruirlo desde una
  plantilla editada. El calentamiento nuevo se construye en servidor desde los
  patrones del trabajo y se puede revisar antes de publicar. Las capacidades
  opcionales de prescripción `records_stimulus_responses` y
  `records_penalty_seconds` delimitan los campos del ejecutor; un recorrido
  fijo no recibe preguntas reactivas por compartir unidad de cronometraje.
  No se han activado el banco externo de estímulos ni una nueva dosis deportiva.
- Una marca física se guarda como hecho del usuario dentro de su contexto de
  evaluación. Al entrar en otro programa, una marca previa pertinente solo se
  puede sugerir si prueba, unidad, protocolo y vigencia son compatibles. El
  usuario ve fecha y procedencia y decide si la usa; no hay autocompletado
  silencioso ni traslado de una puntuación oficial entre baremos. Un test
  guardado en la calculadora FAS pertenece exclusivamente a Mejora FAS. La RPC
  de asociación comprueba el identificador del programa; ningún otro programa
  puede usar ese test aunque comparta pruebas o unidades.
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
- Su edición usa `update_personal_exercise` (UI-012, 08/10/2026). La función
  valida `auth.uid()`, autoría, origen usuario y privacidad; reutiliza la
  normalización editorial y actualiza únicamente contenido descriptivo. La
  imagen se sube primero a una ruta nueva privada; la función comprueba ruta y
  objeto y guarda contenido e imagen juntos. `p_replace_image = false` conserva
  la foto; con `true` admite sustitución o retirada. Nunca recibe permisos,
  propietario ni URLs firmadas. No modifica plantillas, dosis ni instantáneas
  de ejecución. No ofrece borrado de ejercicios ni revisiones concurrentes;
  prevalece el último guardado. No se eliminan imágenes antiguas o de una
  operación incierta: la limpieza de objetos huérfanos queda aparte.
- `WorkoutEditorDraftStore` persiste localmente una instantánea completa del
  editor con espera corta entre cambios. La clave v2 incluye propietario y
  distingue `new`, `new-running` y cada plantilla existente. El adaptador se
  crea por editor y conserva su propietario durante guardados tardíos. Guardar
  la sesión elimina su borrador; un dato ilegible se conserva sin ofrecerlo al
  editor. Los borradores v1 sin propietario permanecen intactos para recuperación
  explícita: no se asignan a la primera cuenta que inicia sesión. No sincroniza borradores entre
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
- `GetPreparationDetailUseCase` compone la preparación, la última evaluación de
  Tropa expresamente vinculada, el control de 2 km propio y la agenda sin
  inventar una prescripción. La evaluación configurable y Mejora FAS tienen
  recorridos e historiales propios. El inicio comprueba el registro de cada
  preparación activa por separado; esa comprobación no valida la vigencia
  deportiva de las marcas.
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

El panel básico de autoría ya existe. La vertical 2 km usa un solo planificador
de servidor, versionado y auditable, para FAS, Tropa y programas con un módulo
compatible. Materializa las sesiones en `workout_templates`,
`scheduled_workouts` y el ejecutor común; Flutter no decide la progresión.
Una declaración de series previas queda en el contexto y en la instantánea de
entrada, pero no sustituye ejecuciones verificadas. El reinicio transaccional
por preparación elimina decisiones y sesiones automáticas sin tocar marcas,
contexto ni sesiones personales; requiere cuenta propietaria y sesión no activa.
Fuerza/rendimiento v2 ya participa en el coordinador común. Las preparaciones
guardadas pueden pausarse/retomarse con un único generador; la prescripción
simultánea de varios programas sigue pendiente. Contrato vigente:
[PROGRAMA_ADAPTATIVO.md](PROGRAMA_ADAPTATIVO.md).

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

**Aislamiento local corregido el 06/10/2026:** cada mutación captura su
propietario al registrarse y se persiste en una cola v2 por cuenta. El adaptador
serializa lecturas/escrituras; un fallo offline que termina tras cambiar de
cuenta conserva la operación del propietario original. La sincronización se
detiene antes del siguiente envío si cambia la identidad y retira el recibo
únicamente de la cola original. Una lectura sin sesión no expone pendientes.
Los permisos y la idempotencia remotos permanecen en PostgreSQL.

La cola v1 se conserva íntegra. Su recuperación consulta mediante RLS el
propietario exacto de la ejecución (o de la ejecución de la serie); sin red o
sin correspondencia no se mezcla con la cola actual. Un marcador por cuenta
evita recuperar otra vez una operación ya enviada. Los datos ilegibles no se
sobrescriben con una cola vacía. Los borradores se separan también por cuenta;
los v1 carecen de prueba de propiedad y requieren recuperación explícita,
todavía sin interfaz de importación. Pruebas de cambio A/B, concurrencia,
migración y guardados tardíos en `workout_account_isolation_test.dart`.

Los avisos usan preferencias locales independientes. UI-018 sustituye
SystemSound.alert (ignorado en Android/iOS/web) por WAV originales empaquetados
y audioplayers 6.8.1. Un adaptador de audio reutiliza el reproductor, precarga,
evita acumulación y aísla fallos. HAPT-001 sustituye en Android los efectos de
teclado de HapticFeedback por pulsos finitos del motor mediante un canal nativo,
con permiso normal VIBRATE, ajustes de notificación/No molestar y cancelación al
salir de primer plano. iOS/web conservan HapticFeedback de Flutter.
El ejecutor emite hitos de preparación, inicio, mitad, diez segundos y final;
UI-019 añade un pitido breve a tres, dos y un segundo del final del trabajo,
reutilizando el WAV de preparación, sin reproducir segundos pasados al restaurar;
no cambia prescripción ni confirmación de resultados. El descanso restaurado
conserva duración original y tiempo ya transcurrido. El diálogo permite probar
sonido o vibración sin guardar preferencias; VIBRATE no exige diálogo. Samsung
cancela los avisos clasificados como notificación si la app tiene sus
notificaciones bloqueadas. La prueba manual solicita POST_NOTIFICATIONS en
Android 13+ y espera la decisión; los hitos del reloj no abren peticiones.
Un bloqueo conocido se comunica como fallo, con ayuda para los ajustes de la
app, y no impide el sonido ni la ejecución. Verificación
en pruebas, Chromium y APK debug. IOS-002 acredita compilación y reproducción
del banco iOS en simulador y escucha confirmada por Javier: la ejecución antigua
carecía del plugin y los WAV; actualizar/reconstruir fue suficiente, sin cambios
en el contexto de audio. Javier confirma después vibración física en Samsung
SM-A326B/Android 13 tras conceder el permiso de notificaciones. Percibe un pequeño
adelanto sobre el sonido, aceptable y sin medir; no se garantiza sincronización
física exacta. La primera sesión activa ofrece el permiso en Android 13+ si
falta y la vibración está activada; el usuario elige Permitir avisos o Ahora no.
Una marca local recuerda la oferta para no repetirla; la petición se conserva
también en la prueba manual. Una denegación o fallo permite continuar, sin
modificar preferencias ni resultados. El nuevo recorrido de entrada está
verificado en pruebas, pendiente de un Android físico sin permiso.
iPhone físico, auriculares y convivencia con otros
sonidos conservan sus verificaciones pendientes.
No garantiza ejecución en segundo plano. Contrato, recursos y límites en
[WORKOUT_AUDIO_2026_10_08.md](WORKOUT_AUDIO_2026_10_08.md).

## Navegación y presentación

`go_router` gestiona las rutas de la app del deportista y del admin. Los diálogos
conservan el mecanismo modal de Flutter.
El área autenticada del deportista usa
`StatefulShellRoute.indexedStack` para conservar el estado independiente de
Inicio, Mi plan, Biblioteca, Evolución y Perfil. `AppShell` representa esos destinos como
`NavigationBar` en móvil y `NavigationRail` en pantallas amplias. La evaluación
inicial queda fuera del contenedor porque es un flujo concentrado y temporal.

Evolución separa actividad, evaluaciones/controles e historial de entrenamientos.
UI-011 añade `/assessment/history/preparations/:goalId`: el router compone
`PreparationMarksData` mediante repositorios existentes de Tropa, FAS,
evaluación configurable y controles de carrera. La página consulta hechos
guardados; el botón de registro abre las tareas existentes en el navegador raíz
y reconsulta al retornar. Los widgets no consultan Supabase ni activan programas.

`WorkoutHistoryQuery`, en dominio, expresa preparación, tipo histórico,
fechas civiles, estado, límite y cursor. El caso de uso y repositorio transmiten esos criterios al
datasource; este conserva propietario y exclusión de ejecuciones en curso.
El orden descendente `(started_at, id)` y el cursor evitan desplazamientos por
inserciones recientes y ordenan empates. Se solicita una fila adicional para
detectar otra página. Refrescar reconsulta páginas pequeñas hasta la profundidad
ya abierta; no depende de aumentar un único límite de respuesta del servidor.
La fecha final incluye el día civil completo, convirtiendo sus límites a UTC.

El filtro de preparación usa el vínculo existente
`scheduled_workouts.execution_id` y `preparation_goal_id`, mediante una relación
PostgREST interna. No añade campos a la ejecución ni consulta su plantilla
vigente para reinterpretar datos históricos. La lista ofrece preparaciones
no archivadas; el historial general conserva también ejecuciones sin vínculo.
UI-016 filtra el tipo copiado en la ejecución antes de ordenar/paginar;
`unclassified` representa `session_type is null`, sin consultar la plantilla.
La política de clasificación se conserva en el modelo al actualizar resultados.

Las páginas y controladores de resultados se identifican por cuenta y recurso.
Renovar la misma cuenta conserva estado; sustituirla descarta la consulta local.
Raíz, historial físico y detalle de ejecución ignoran consultas antiguas y no
emiten después de cerrarse. El historial FAS conserva resultados y expansión
al fallar el refresco. Sus puntos reutilizan el catálogo local de la versión
almacenada; otra versión permite ver marcas, pero no calcular puntos con un
baremo distinto. Los resultados configurables muestran puntuación e intentos
del snapshot. UI-011 no incorporaba una regla comparativa nueva.

UI-015 añade `MeasurementSeries`/`MeasurementSample`, datos de lectura sin
persistencia nueva. El adaptador `preparationMeasurementHistory` agrupa marcas
por origen, prueba, versión, columna/hito cuando corresponde, unidad y dirección;
no consulta una definición editorial mutable. FAS resuelve dirección/unidad
exclusivamente en el catálogo íntegro de la versión almacenada. Controles válidos
`run_2000m_v1` forman series independientes. El widget elige IDs de prueba/fechas,
conserva selección y expansión durante el refresco y deriva únicamente la vista;
el cálculo puro exige fecha anterior estricta y pertenencia a la misma serie.
El comparador anterior de Tropa también verifica el contexto y cada marca/estándar.
Las tarjetas usan `PageStorageKey` propio por resultado, separado del scroll.
Los programas configurables no tienen comparación mientras su snapshot carezca
de unidad/protocolo/dirección completos; no se completan desde el catálogo actual.
No cambia consultas, rutas, RLS, puntos ni algoritmos prescriptivos. Alcance y
regresiones en `docs/MEASUREMENT_COMPARISON_2026_10_08.md`.

`go` sustituye la ubicación, `push` apila un flujo temporal y `pop` vuelve; se
elige cada operación según la experiencia de usuario.

UI-008 incorpora `SectionRefreshBoundary` a Inicio, Mi plan, Perfil, Mi semana
y la raíz de Evolución. Observa la ubicación de `go_router` y pide una nueva
consulta al volver a mostrar esa pantalla, desde otra rama o tras una tarea.
No remonta la rama ni almacena datos de dominio. Los Cubits de Inicio, agenda
e historial conservan la última consulta y descartan respuestas anteriores a
la carga vigente; tampoco emiten después de cerrarse. La agenda mantiene día y
semana seleccionados, incluso si la última consulta no tenía sesiones.

UI-007 conserva el estado de cada rama de consulta y abre configuración de
programa/contexto, registro de marcas, creación de ejercicios, edición y
ejecución de sesiones en el navegador raíz. `_workflowRoute` mantiene URLs y
aplica `GoRoute.onExit` mediante un registro local al router. Cada página aporta
sus cambios actuales, guardado de borrador o estado de ejecución; el registro
no almacena widgets ni decide progresión. Los avisos distinguen descarte,
borrador recuperable y salida de una sesión sin abandonarla. Los formularios
de evaluación oficial no se reorganizaron en UI-007; UI-008 amplía la protección
a los formularios de Tropa, FAS y evaluación de programa.

UI-008 reutiliza el guard visual mediante `entrena_ui`, sin añadir dependencias
de dominio. El registro de salidas vive en cada router; los campos y snapshots
temporales pertenecen a sus pantallas. `RetainedSaveDialog` espera un callback
de persistencia y conserva el formulario y el error recuperable; no recibe un
cliente Supabase ni decide permisos. Los diálogos siguen usando el mecanismo
modal de Flutter, no se convierten en páginas con URL.

La ampliación editorial del 07/10 reutiliza el mismo componente para pruebas,
calificación, mínimos/tramos, importación, clonación y vinculación de estrategia.
`RetainedSaveCancelled` distingue la revisión previa cancelada de un fallo de
persistencia: conserva el formulario y no presenta un éxito o error falsos.
La recarga de las consultas ocurre después de cerrar por éxito. Los futuros de
recarga observan errores desde su creación para que un fallo inmediato no quede
sin manejar antes de la siguiente suscripción de `FutureBuilder`; este conserva
su presentación de error. Los valores y reglas enviados al repositorio no cambian.

El admin usa `MaterialApp.router` y `go_router` (misma versión resuelta que la
app del deportista). Sus rutas identifican programas, sesiones y pruebas por
ID y recargan mediante repositorios, sin depender de `extra`. Se comprueba
acceso antes de resolver páginas editoriales; los recursos se verifican contra
su catálogo/programa. El guard de sesión redirige al acceso al cerrar sesión,
pero nunca sustituye RLS ni los permisos de las RPC existentes. Cambiar un ID
de URL renueva el loader; volver a un listado conserva búsqueda y selección.
Renovar el token de la misma cuenta conserva navegación; cambiar identidad
recrea el router del admin para no reutilizar consultas ni formularios de otra
cuenta. La fuente `cupertino_icons`, ya usada por el deportista, se incluye
también en admin para los iconos de las dependencias adaptables de navegación.

UI-014 organiza el detalle admin con un índice de scroll y tres grupos en la
misma página. Las secciones permanecen montadas; pulsar el índice no crea rutas,
reinicia consultas ni descarta formularios. Los destinos a sesiones, baremos y
simulación conservan go_router y sus comprobaciones. Cada prueba tiene su propia
`PageStorageKey`, distinta de la del scroll: el estado desplegado no puede leer
la posición numérica del contenedor como un booleano. Los reintentos renuevan
únicamente las consultas afectadas. Los selectores adaptables y el texto «Ver
baremo» de publicados no alteran mediciones, persistencia ni permisos existentes.

STR-033 aporta `TrainingContext` y su repositorio en `training_plan`. Su
adaptador de datos lee la RPC propia `get_training_context_settings` y escribe
con el contrato existente `save_performance_context`. Perfil y programa
comparten `TrainingContextFields` de presentación y el contexto por usuario;
las preferencias generales antiguas solo aportan ayuda inicial. El cuestionario
integrado de carrera reutiliza disponibilidad sin duplicar la dosis ni el
planificador; sus mediciones específicas conservan su contrato.

El panel de Inicio compone datos de evaluación, contexto actual y preferencias
legadas mediante un caso de uso propio. El contexto actual tiene prioridad
sobre el registro antiguo; un programa ya iniciado conduce a su continuidad
automática. También lee la semana natural de la agenda para presentar siete
días compactos y abrir la fecha elegida sin duplicar las acciones de edición de
`Mi semana`. Sin programa iniciado, sus pasos cubren elegir preparación,
completar evaluación/disponibilidad, solicitar revisión profesional o esperar
reglas deportivas validadas. No calcula un porcentaje de progreso ni presenta una
prescripción que el dominio todavía no pueda justificar.

Mi plan reutiliza `GetPreparationOverviewUseCase` y `DashboardCubit` sin añadir
consultas a Supabase en widgets ni un coordinador nuevo. `TrainingHubEntry`
instancia el Cubit al visitar `/plan`, evitando la consulta de resumen cuando se
entra directamente a una ruta hija. Tras esa visita conserva la instancia; su
frontera de refresco consulta al volver. El router observa `AuthCubit` y la clave
incluye el usuario: cambiar identidad cierra el Cubit anterior, mientras renovar
la sesión de la misma cuenta lo mantiene. La comprobación de permisos sigue
perteneciendo al servidor. `PreparationNextStepCard` y los nombres de estado son
presentación compartida entre Inicio/Mi plan; los criterios de dominio se mantienen.

## Verificación

Después de cambios materiales se ejecutarán análisis estático y pruebas
relevantes. Tienen prioridad las pruebas de dominio, progresión, permisos,
versionado, persistencia de sesión y regresiones observadas.
