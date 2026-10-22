# Entrega profesional coordinada · 21/10/2026

## Coordinación detenida · 22/10/2026

Javier ordena detener subagentes y coordinación entre chats, incluidos mensajes,
avisos y reservas. Se comunica la instrucción a Dispositivos, ADMIN y Arquitectura.
Trainer continúa directamente con Javier. Los permisos de coordinación descritos
abajo son históricos y quedan revocados hasta nueva petición expresa. Las tareas
que Javier encargue por separado en otros chats siguen siendo independientes.
El estado posterior y la propuesta de navegación del deportista se registran en
[la revisión del 22/10](TRAINER_STUDENT_UX_2026_10_22.md).

## Alcance autorizado y estado de esta hoja

Javier autoriza en el chat de entrenadores ejecutar los dieciséis puntos de la
propuesta profesional y coordinar varios chats y subagentes. Ratifica después
en el chat de coordinación Clean Architecture, conservación del trabajo y uso
de Harbiz como referencia sin perder capacidades propias. La autorización de
alcance no convierte propuestas en funciones implementadas ni fija condiciones
comerciales todavía pendientes.

Esta hoja organiza contratos, propiedad de archivos y comprobaciones; no crea
API, tablas, permisos ni nuevos estados de producto. Desarrolla el
[alcance profesional](TRAINER_PLATFORM.md), sin sustituir
[DECISIONS](DECISIONS.md), el [roadmap](ROADMAP.md) ni los contratos de dominio.
El responsable Trainer incorporará allí la autorización y los cierres reales.

Primera publicación de este bloque, conservada como evidencia histórica:
fuentes `a2c467fe9a1a2a1c854304f7701879b509827aee`, portal
`https://trainer.entrenaop.es/`, release
`a2c467fe9a1a2a1c854304f7701879b509827aee-20261021-8`; evidencia guardada en
`6937aec` y ajuste de formato en `dd5443b`. Sus diez
migraciones nuevas están aplicadas en Dev y `exercise-video` desplegada allí.
[Identidad, validación y límites de la publicación](TRAINER_PROFESSIONAL_RELEASE_2026_10_21.md).
Se conservan aparte los cambios previos de `.gitignore` y `devtools_options.yaml`.
Esta revisión contrasta Git, documentos y entregas de los responsables; no vuelve
a ejecutar Flutter/SQL ni consulta el estado remoto de Supabase. Las cifras se
atribuyen abajo a su evidencia. El estado previo a la publicación queda superado;
no debe leerse como el estado actual del portal.

Continuación TRN-021 / INT-004 validada, guardada y subida en
`37dcd14b3e2a1df0f23cfc117e2e42d5d8791ca0`, fuente contrastada: historial
privado de Salud y trabajos incompletos de programas están
implementados y sus dos migraciones aplicadas solo en Dev. Trainer confirma 197
migraciones coincidentes, cero pendientes y 26 contratos juntos con `ROLLBACK`
sobre el esquema aplicado. Trainer confirma remoto coincidente y 69 archivos
revisados, conservando fuera los dos cambios ajenos. La reconstrucción web desde
ese commit y el ZIP sellado están terminados. Javier autoriza expresamente el
acceso a Hostinger/gestor y Trainer publica la release
`37dcd14b3e2a1df0f23cfc117e2e42d5d8791ca0-20261021-9`, extrayendo únicamente en
`public_html/trainer`. La revisión automática había bloqueado autorizar el origen
de archivos, que muestra una raíz privada; ese bloqueo queda histórico y resuelto
por la autorización específica. `trainer_release.py verify` acredita por HTTPS
manifiesto, hash del JavaScript, entrada, cabeceras y MIME. Trainer comprueba en
Chrome, conservando la sesión MFA, Programas/Trabajos incompletos y la nueva ruta
UUID/editor común: carga sin errores y vuelve a lista vacía tras salir sin escribir.
Coordinación registra ese recorrido y comprueba la presencia de sus capturas,
sin repetir la navegación. Dispositivos confirma ambas CI
terminadas con éxito: Salud `39649281298`, incluida app principal iOS Simulator
y ensayo iOS/Android; ADMIN `39649281484`, validación, despliegue Dev y retención.
Estas CI y la publicación web no acreditan aceptación física de la integración
principal.
[Programas](TRAINER_PROGRAM_WORK_DRAFTS.md), [Salud](DEVICE_RUNNING_HISTORY.md).
[Evidencia de la publicación de recuperación](TRAINER_RECOVERY_RELEASE_2026_10_21.md)
registra fuente `37dcd14`, release terminada en `-9` y hashes exactos. Capturas del
recorrido comunicado: [lista publicada](visual-audit/trainer-recovery-2026-10-21/programas-dev-publicado.png)
y [creador publicado](visual-audit/trainer-recovery-2026-10-21/creador-dev-publicado.png).

## Responsables y reservas

| Responsable | Chat | Propiedad del trabajo |
| --- | --- | --- |
| Trainer e integración de la entrega | `01a14f87-3bfa-73c0-b1fb-0318218ff120` | Portal profesional, contratos profesionales de servidor y coordinación de recepción en deportista; integración de documentación global y punto de guardado conjunto. |
| ADMIN y creadores | `01a15299-0bf1-7dd2-814a-d5618807c8b9` | ADMIN, Compacto, fiabilidad editorial y mejoras del editor común, coordinando cambios con sus consumidores. |
| Arquitectura transversal | `01a15ef5-affc-7dc0-9901-167eb1e1c076` | Esta hoja, mapa de contratos, dependencias y revisión de fronteras. No abre otra implementación del portal ni de los creadores. |
| Dispositivos | `01a15eaa-3459-7722-b08e-0f52379e07d7` | Responsable de conexiones e integración de relojes/Salud, con `packages/device_activity_core/`, `labs/health_read_probe/`, `docs/DEVICE_*.md` y su workflow específico `.github/workflows/health-read-probe.yml`. La conexión con las apps requiere acordar las fronteras compartidas. |

Las instrucciones se han enviado a los tres chats desde coordinación.
Dispositivos confirma expresamente sus rutas; la asignación de cada archivo
concreto de código compartido debe confirmarse antes de escribirlo. Los
subagentes son ejecutores de tareas acotadas dentro del responsable, sin
autoridad para reasignar rutas de otro chat.

Dispositivos concreta en `DEVICE_INTEGRATIONS.md` la frontera propuesta:
adquisición → observación privada → proyección de cita como `RunningSessionTarget`
→ revisión/asociación → confirmación autorizada → resultado profesional permitido.
El adaptador de planificación es del responsable de esa funcionalidad; el conector
no escribe en su agenda ni abre el historial personal al preparador. El preflight
Mac permanece dentro del ensayo, sin instalar, firmar ni leer Salud automáticamente.
La primera lectura física positiva en el iPhone de Javier está registrada en
`0515a76`: la captura aportada acredita consulta no vacía de carreras de Garmin
Connect desde Salud en la app de ensayo. Coordinación contrasta el registro
documental, sin volver a inspeccionar la captura privada. No es acceso directo
a la API Garmin ni integración en las apps principales. Dispositivos comunica
después comparación compatible con Connect para dos carreras a la precisión de
pantalla; el ritmo es derivado, no una serie leída del proveedor. Javier autoriza
compartir el resumen técnico sin métricas exactas ni capturas. Confirma descarte
de lista al volver de Garmin, relectura sin duplicados y desaparición/reaparición
de carreras al revocar/restaurar lectura en Salud. Esta aceptación corresponde
al lector instalado anterior a la extracción del plugin; no acredita estabilidad
general, prueba física Android ni la integración principal.
[Evidencia y límites](DEVICE_HEALTH_READ_PROBE.md).

Dispositivos retira su propuesta de `@garmin/fitsdk` tras revisar condiciones de
licencia que requieren autorización específica; no lo instala ni utiliza.
Se cancelan las reservas de `labs/device_provider_probe/` y
`.github/workflows/device-provider-probe.yml`, ambos inexistentes al comprobar
esta actualización. No hay eliminación de archivos.

La investigación offline de FIT continúa dentro de `labs/health_read_probe/`.
Se reservan expresamente su `pubspec.yaml` y `pubspec.lock` a Dispositivos para
evaluar `fit_tool: 1.0.5`. Dispositivos comunica su adopción solo en el ensayo,
licencia BSD-3-Clause contrastada, 18 pruebas FIT con binarios sintéticos,
43 pruebas totales y análisis limpio. Se comprueba aquí la dependencia fijada y
la existencia del adaptador en `lib/data/`, muestras y CLI local; no se repiten
esas pruebas desde coordinación. El lector limita bytes/mensajes y verifica
estructura/CRC antes de decodificar; rechaza timestamps comprimidos y campos
developer. Los binarios sintéticos no acreditan archivos reales de fabricantes.
El CLI no persiste actividades ni muestra métricas por defecto. Dispositivos
registra APK compilado y pasos de CI iOS correctos, manteniendo el estado exacto
del job en su evidencia. La aceptación FIT con archivos reales sigue pendiente.
No añade dependencias a las apps habituales o al dominio puro, ni cambia SQL o
CI de ADMIN. No acredita cobertura de Garmin/COROS/Suunto ni acceso a sus API.
La conexión futura con las aplicaciones necesita su contrato y reserva propios.
El lector de Salud actual pertenece a la app de ensayo, no a EntrenaOP móvil
distribuida.

### Revisión inicial de conexión y evolución posterior

Al abrir la coordinación, Dispositivos propuso `packages/device_health/` y una feature nueva
`lib/features/device_activities/` para lectura/lista explícita local. Arquitectura
recomienda la frontera, pendiente de concretar el contrato y reservar con Trainer
pubspec/lockfile, router/perfil, DI y archivos nativos. Esta revisión no concede
por sí sola esas reservas ni acreditaba integración implementada. Los párrafos
iniciales conservan esa justificación histórica; el estado posterior de extracción
y las reservas nuevas se indican expresamente más abajo.

Dispositivos contrasta después minSdk 24 en Flutter 3.47.5 y mínimo 26 en su
dependencia Health Connect 1.1.0. Arquitectura recomienda comenzar el plugin
con implementación nativa iOS para conservar el soporte Android actual. Android
mantiene su lector probado en el laboratorio; la API de la app informa que esa
integración aún no está habilitada, sin confundirlo con incompatibilidad de todos
los dispositivos. No se eleva el mínimo global ni se usa `overrideLibrary`.
Es una recomendación de integración pendiente de coordinar con Trainer; no se
declara implementada ni se elimina el trabajo Android existente.

La extracción ya está presente en `packages/device_health/`, con puerto puro
en `src/domain`, adaptador separado y plugin solo iOS. El ensayo consume el
paquete y conserva Kotlin Health Connect con el mismo nombre de canal que Dart.
Dispositivos comunica 16 pruebas de paquete, 30 de ensayo, análisis limpios y APK
correcto; coordinación revisa código/frontera, sin repetir esas ejecuciones.
[Entrega, API y límites](DEVICE_HEALTH_APP_HANDOFF.md).

La revisión detectó que `register(with:)` no publicaba la instancia mediante
`registrar.publish(instance)`: Flutter condiciona a esa publicación la llamada
a `detachFromEngine(for:)`. Dispositivos lo corrigió y coordinación comprobó la
llamada en el código guardado. Sigue pendiente verificar el ciclo nativo en
ejecución. Dispositivos comunica compilación iOS correcta del plugin guardado en
`124fa76` mediante CI `39637024250`, job `119350196386` terminado con éxito;
comunica después éxito de ambos jobs, iOS y Android, de esa ejecución.
Coordinación registra esa entrega sin repetir la compilación. La reinstalación
física de la integración principal sigue pendiente; el código de conexión y
persistencia ya está implementado en la continuación descrita a continuación.
La lectura positiva anterior no acredita esa instalación.
[Contrato de desmontaje Flutter](https://api.flutter.dev/ios-embedder/protocol_flutter_plugin-p.html).

Tras autorizar Javier la integración principal y el historial privado por cuenta,
Dispositivos implementa ese tramo por separado. Trainer libera pubspec/lockfile raíz
y configuración iOS aditiva; conserva router/perfil/DI. La migración local
`20261021171215_device_running_history.sql` pertenece a Dispositivos y ya está
aplicada en Dev, tras contrastar el DDL real antes de registrar su historial. No
pertenece a la release profesional anterior de 195 migraciones. Su contrato SQL
se repitió sobre el esquema aplicado; junto con programas hay ahora 197 versiones
coincidentes y 26 contratos correctos, según Trainer. APK debug principal compilado
y 16 pruebas dirigidas de Salud correctas. La CI
[39649281298](https://github.com/jchjdev/entrenaop/actions/runs/39649281298)
termina con éxito y acredita también app principal iOS Simulator; la instalación
física de esta integración sigue pendiente. Dispositivos registra asimismo CI
[ADMIN 39649281484](https://github.com/jchjdev/entrenaop/actions/runs/39649281484)
correcta, incluidos despliegue Dev y retención del mismo commit de fuentes.
La conexión lógica por cuenta/canal, el guardado explícito y las revisiones
inmutables mantienen el aislamiento del historial personal respecto a Trainer
y ADMIN. El namespace persistente no identifica AppleID ni HealthStore; los
ámbitos efímeros de lectura no deben convertirse en claves persistidas.

La app no debe importar código de `labs`. El puente debe alojarse en un plugin
Flutter interno con implementaciones Kotlin/Swift, consumido tanto por el ensayo
como por EntrenaOP. La lógica/puertos puros permanecen independientes de Flutter
y SDK; la feature consume la interfaz tipada mediante un adaptador. Flutter
distingue estos plugins, que incluyen implementaciones de plataforma, de un
paquete Dart ordinario.
[Guía oficial de plugins](https://docs.flutter.dev/packages-and-plugins/developing-packages).

El contraste del código detecta dos diferencias a resolver antes de conectar:
el ensayo usa `FlutterFragmentActivity` y minSdk 28; la app principal usa
`FlutterActivity`, mínimo de Flutter y callbacks propios de avisos/vibración.
Su `AppDelegate` también conserva el puente de vibración y no hay actualmente
`ios/Runner/Runner.entitlements`. Preservar esas integraciones y añadir permisos/
capabilities de salud sin sustituir archivos completos ni elevar mínimos sin
explicarlo. El SDK Health Connect admite Android 26 y el servicio requiere 28;
hay que contrastar compatibilidad real del plugin/dependencia y la configuración
actual antes de decidir el mínimo global.
[Requisitos oficiales](https://developer.android.com/health-and-fitness/health-connect/get-started).

En la app, lectura y respuestas pendientes quedan ligadas a identidad/generación
actual; cambiar cuenta o cerrar sesión invalida datos locales y descarta respuestas
tardías. El permiso del sistema no identifica una cuenta EntrenaOP. Importar no
completa una cita ni comparte datos con el preparador. La lectura/lista es un
primer tramo útil, pero no cierra por sí sola el objetivo de Javier de conservar
sus métricas: la persistencia personal necesita su contrato de propiedad,
deduplicación, retención y confirmación, separado de agenda/resultados.

| Rutas o recurso | Regla de reserva |
| --- | --- |
| `trainer_app/` y contratos SQL profesionales nuevos | Trainer; un archivo nuevo de migración y sus pruebas por cambio, coordinando su orden antes de aplicar. |
| `admin_app/` | ADMIN; la gestión comercial profesional mantiene el contrato acordado con Trainer y no amplía lectura privada. |
| `packages/workout_editor_ui/` | ADMIN coordina las mejoras comunes. Trainer confirma los adaptadores afectados; no se mantienen dos copias del creador. |
| `packages/workout_core/`, `packages/trainer_access/`, `packages/entrena_ui/` | Compartidos: reserva explícita del archivo y consumidores antes de editar. No quedan concedidos en bloque a dos chats. |
| `lib/`, `test/`, configuración y compilación del deportista | Trainer asigna archivos concretos a su integración o subagente. El chat de dispositivos conserva su ensayo aislado hasta acordar la conexión. |
| Migraciones, funciones y contratos SQL compartidos | Un propietario por archivo; Trainer coordina las dependencias con ADMIN/dispositivos. No editar migraciones aplicadas para sustituir historial. |
| `docs/DECISIONS.md`, `docs/ROADMAP.md`, `docs/ARCHITECTURE.md`, `docs/PRODUCT.md` | Actualización integrada por Trainer en este tramo; los demás entregan propuestas y evidencia para evitar escrituras simultáneas. |
| CI, herramientas de publicación, configuración y lockfiles | Reserva puntual antes de editar. Un cambio de dispositivos no debe provocar una publicación ajena ni alterar dependencias de otras apps. |
| `docs/PROFESSIONAL_DELIVERY_COORDINATION.md` | Solo arquitectura transversal durante este tramo. |

Trainer confirma además estas reservas concretas: `lib/features/trainers/`,
`docs/TRAINER_OPERATIONAL_WORKFLOW.md` y nuevas RPC operacionales de revisión,
agenda, adaptación, grupos y mensajes. Sus subagentes tienen asignados los nuevos
`trainer_progress.dart` y pruebas en `workout_core`, y `trainer_followup.dart` y
pruebas en `trainer_access`; esos archivos quedan fuera de la reserva genérica
del resto. La revisión de seguridad del backend de vídeo ya está cerrada por
Trainer, con 36 ejecuciones de concurrencia correctas. La reserva inicial por
confirmar pertenece al arranque de la coordinación y ya no describe un bloqueo
actual. El contrato sigue sin conceder acceso ADMIN general a privados.

ADMIN concreta sus archivos y el contrato aditivo de creación contextual en
[su hoja de entrega](ADMIN_PROFESSIONAL_DELIVERY.md). El callback opcional
`WorkoutEditorPage.onCreateExercise` devuelve un ejercicio guardado o cancelación;
el consumidor mantiene navegación, guardado y permisos. Trainer conectará su
adaptador a ese contrato, sin editar simultáneamente el editor compartido.

Antes de cada tarea: objetivo verificable, propietario, archivos, contrato
consumido, dependencias y comprobación de cierre. Una reserva se libera al
entregar el diff revisado, sus resultados y sus pendientes. Un mensaje enviado
no prueba que otro chat haya terminado ni que una reserva haya sido aceptada.

## Clean Architecture y conservación

Las dependencias apuntan hacia las reglas del dominio. Flutter, navegación,
Supabase, Storage y SDK de dispositivos/proveedores son detalles externos.
Modelos y políticas puros no importan esos detalles; los adaptadores traducen
DTO, errores, unidades e identidad al contrato de aplicación. La presentación
gestiona interacción y estado sin conceder permisos ni decidir integridad.

Se reutilizan `workout_core` para recetas/validación y `workout_editor_ui` para
los creadores. `device_activity_core` conserva su dominio independiente. Un
adaptador de interfaz puede depender de Flutter, como ocurre en el editor
compartido; eso no lo convierte en dominio. La nueva lógica de planificación,
seguimiento o automatización debe poder probarse sin montar pantallas ni
conectar un proveedor. No se crean capas o paquetes por plantilla, ni se
refactoriza globalmente el código existente para esta entrega.

Una modificación material de arquitectura, datos, seguridad, contrato o
comportamiento acordado se explica antes de aplicarla y se registra en el
documento responsable. El permiso general para avanzar no sustituye decisiones
comerciales ni autoriza operaciones destructivas.

Se conserva el trabajo ajeno y el historial: revisiones nuevas para contenido
entregado, referencias exactas desde las pautas y las instantáneas existentes
de ejecución. Ninguna mejora de biblioteca, adaptación individual, baja,
automatización o importación reescribe retrospectivamente resultados.
Sin eliminación de archivos/datos, reseteos, sobrescrituras de historial Git o
reducción de pruebas para ocultar fallos. Los flujos existentes de papelera no
autorizan a los agentes a purgar datos durante este desarrollo.

## Mapa de los dieciséis puntos

Estado comunicado por Trainer y contrastado con los documentos de dominio el
21/10/2026. Las funciones integradas del portal forman parte de la publicación
Dev identificada arriba; el código del deportista y la publicación de ADMIN
mantienen sus hitos propios. La aceptación física conjunta sigue pendiente.
Esta tabla no declara cerrados los dieciséis puntos.

| Nº | Recorrido | Estado local y límites pendientes | Responsable y criterio observable |
| --- | --- | --- | --- |
| 1 | Inicio operativo | Publicado y consultado en Chrome en Dev; pendiente aceptación conjunta. | Trainer: avisos llevan a la acción y explican periodo/completitud; depende de 8/9/11. |
| 2 | Ficha completa | Ficha y contexto profesional integrados localmente. | Trainer + deportista: solo datos permitidos; notas internas separadas de indicaciones visibles. |
| 3 | Calendario editable | Agenda editable, eventos y previsualización integrados; batería final de concurrencia correcta. | Trainer + deportista: confirmar fechas/cambios, tratar inicio concurrente y conservar el plan automático. |
| 4 | Adaptación individual | Cambios individuales revisados implementados sin modificar biblioteca; regresiones finales correctas. | Trainer: receta/versiones y destinatario inequívocos; pauta anterior y ejecución iniciada preservadas. |
| 5 | Creador ágil | Creación contextual y recuperación de programas Trainer publicadas en Dev; lista/ruta/editor comprobados en Chrome sin escribir contenido de ensayo. Recuperación de sesiones incompletas sigue pendiente. | ADMIN + adaptadores Trainer: mismo creador, capacidades conservadas, reintento sin duplicados. |
| 6 | Biblioteca eficiente | Backend y consumidores de favoritos/recientes integrados y probados; selector Trainer publicado y consultado en Chrome, sin escribir preferencias de ensayo. Etiquetas no acreditadas por esta entrega. | ADMIN en componentes comunes, Trainer en sus datos: preferencias por identidad/contexto sin abrir contenido privado. |
| 7 | Grupos y envío conjunto | Grupos, envío y copia semanal integrados localmente. | Trainer: destinatarios explícitos, aislamiento individual y resultado recuperable por destinatario conforme al contrato de grupos. |
| 8 | Evolución | Evolución y contexto de resultados integrados en ficha/informes; pendiente aceptación conjunta. | Trainer + deportista: periodo, origen, unidades, omisiones y cobertura explicados; ausencia no equivale a cero. |
| 9 | Bandeja de revisión | Revisión y seguimiento vinculados implementados localmente. | Trainer + deportista: revisar una versión identificada, reintentar sin duplicar y conservar respuestas anteriores. |
| 10 | Vídeos en ambas direcciones | Demostraciones privadas, técnica del alumno y componentes comunes integrados; seguridad revisada y función desplegada en Dev, portal publicado. Faltan subida/reproducción con archivos reales y aceptación móvil. | Trainer coordina servidor y recepción; ADMIN aporta herramienta reutilizable. Aplican autorización, cuotas y conservación del contrato de vídeos privados. |
| 11 | Formularios | Plantillas, asignación y respuestas integradas en Trainer/deportista. | Trainer + deportista: plantilla y respuesta versionadas, destinatario autorizado y conservación tras revisión. |
| 12 | Comunicación | Conversación profesional integrada localmente; notificaciones push pendientes. | Trainer + deportista: distinguir mensajes compartidos/notas internas, reintentos y política de notificaciones. |
| 13 | Automatizaciones controladas | Recurrencia finita de hasta doce semanas integrada; no acredita automatización profesional general ni motor adaptativo. | Trainer: acción explícita/auditable, idempotencia, cancelación y aprobación cuando proceda; sin finalizar vínculos por defecto. |
| 14 | Cobros y servicio | Núcleo comercial simulado entregado con 21 pruebas; sin proveedor conectado, derechos reales ni políticas comerciales resueltas. | Trainer + ADMIN comercial: separar ambos circuitos y Pro; proveedor, condiciones, conciliación y pruebas antes de activar pagos. |
| 15 | Informes | Informe de periodo y exportación CSV integrados localmente. | Trainer: mismas métricas autorizadas de 8, periodo/fuentes y revisión previa al compartir; sin datos privados ajenos. |
| 16 | Preparación específica y relojes | Pruebas/simulacros tipados integrados. Historial personal de Salud implementado y aplicado en Dev; instalación principal pendiente. Motor profesional, puntuación/contexto oficial completo y conectores directos siguen pendientes. | Trainer + dispositivos: reglas deportivas versionadas, anulación profesional definida y actividad externa confirmada sin alterar retrospectivamente el motor. |

### Evidencia de integración comunicada por Trainer

Las cifras de este apartado describen la release `a2c467f` salvo la continuación
TRN-021 / INT-004 identificada al final; se mantienen ambas para distinguir sus
fuentes, publicaciones y límites de aceptación.

- Trainer confirma diez migraciones nuevas ya aplicadas permanentemente en Dev,
  con 195 entradas coincidentes en el historial local/remoto, y los 24 contratos
  SQL repetidos correctamente sobre el esquema aplicado. Los scripts de prueba
  terminan con `ROLLBACK`; no dejan datos de prueba ni revierten las
  migraciones ya aplicadas. La evidencia anterior solo transaccional queda
  superada por esta comprobación comunicada por el responsable.
- `exercise-video` desplegada en Dev y portal Trainer publicado desde la
  compilación del commit guardado. La verificación HTTPS contrasta revisión,
  release, SHA del JavaScript, entrada, cabeceras y MIME de WebAssembly. El
  recorrido en Chrome conserva la sesión MFA y no guarda contenido de ensayo.
  No acredita producción, dos cuentas ni archivos reales.
- Baterías finales de la publicación: raíz 1.204 correctas/una omisión previa;
  ADMIN 306/dos previas; Trainer 101; editor común 110; `entrena_ui` 19 y
  `trainer_access` 20. Análisis de raíz, ADMIN, Trainer y editor limpios y ambos
  portales compilados para web Dev. Estas cifras sustituyen las parciales
  anteriores a la integración final de preferencias.
- Planificación: Trainer confirma también las 306 ejecuciones correctas de la
  variante final de fixture personal sin advisory lock.
  Assessments, vídeo y preferencias: 36 ejecuciones correctas por batería,
  comunicadas por Trainer.
- Comercio: 21 pruebas del núcleo simulado entregadas por arquitectura. No
  concede acceso real, cobra dinero ni acredita un adaptador persistente.

Continuación TRN-021 / INT-004: las migraciones `20261021171215` y
`20261021172219` ya están aplicadas en Dev y los 26 contratos conjuntos han pasado
sobre sus 197 versiones coincidentes. Los asesores posteriores no añaden WARN ni
ERROR; los cuatro INFO nuevos de trabajos corresponden a tablas privadas cerradas,
sin atribuir la ausencia de avisos a todo el proyecto. Trainer comunica 108
contenciones locales RC/RR de programas y la regresión ampliada de Salud correcta.
La matriz final comunicada por Trainer sobre las fuentes congeladas es: raíz
1.220 correctas/una omisión previa, Trainer 137, ADMIN 306/dos omisiones previas,
editor común 124 (catorce regresiones nuevas) y `trainer_access` 20; Salud conserva
16 dirigidas correctas. Coordinación contrasta también el final del log
`build/trainer-recovery-athlete-tests-final.log`. Análisis raíz/Trainer/ADMIN/editor
limpios, 42 archivos Dart sin cambios de formato y compilación web Trainer Dev
correcta, según Trainer. Incluye el guard previo al callback `onSaved`, probado.
El commit de esta continuación es `37dcd14b3e2a1df0f23cfc117e2e42d5d8791ca0`,
guardado y subido según Trainer, con reconstrucción y ZIP sellado terminados.
Publicación Dev completada tras autorización expresa de Javier, release `-9`
verificada por HTTPS y recorrido de lectura en Chrome acreditado por Trainer.
La comprobación no guarda un programa ni acredita recuperación tras recargar
trabajo real, dos cuentas, vídeo real o instalación móvil.

Trainer ha cerrado el punto de guardado/publicación descrito, sin cerrar el
alcance completo. Permanecen pendientes la aceptación física con dos cuentas y
archivos reales y la distribución móvil, además de las dependencias funcionales
abiertas de la tabla. ADMIN ya completa su flujo CI de despliegue Dev sobre
`37dcd14`, según Dispositivos; la prueba humana de sus nuevos recorridos conserva
su evidencia propia. El siguiente
tramo de recuperación de programas Trainer está implementado y aplicado en Dev,
validado, guardado y publicado desde `37dcd14`. La aceptación humana del guardado
y recuperación de un programa propio sigue siendo un hito distinto.

## Contratos entre aplicaciones

1. **Contenido y destinatario.** Catálogo oficial ADMIN, biblioteca profesional
   y creación personal tienen propiedad, cuotas y permisos diferentes. Compartir
   formularios no los fusiona. El alumno consume lo asignado sin otra compra Pro;
   no adquiere creación personal ilimitada. Véanse
   [sesiones](TRAINER_PRIVATE_WORKOUTS.md),
   [programas](TRAINER_PRIVATE_PROGRAMS.md) y
   [ejercicios](TRAINER_PRIVATE_EXERCISES.md).
2. **Pauta y cambio.** Reutilizar receta, cita y ejecución existentes. Cada
   operación identifica versión esperada, destinatario, fecha local e identidad.
   Traslado, sustitución o adaptación deben definir qué ocurre con una cita
   iniciada, retirada, completada o modificada en otra pestaña antes de añadir
   escrituras. Reintento conserva orden/payload; conflicto no sobrescribe.
3. **Resultados y seguimiento.** El preparador consulta resultados de sus
   propias asignaciones, no todo el historial personal del alumno. Las métricas
   derivan de lecturas autorizadas y declaran paginación/incompletitud. Finalizar
   un vínculo conserva el historial propio y no abre datos nuevos ajenos:
   [cartera y etapas](TRAINER_CLIENT_LIFECYCLE.md).
4. **Medios.** Distinguir demostración de ejercicio y técnica enviada por el
   alumno. Cada archivo necesita dueño, versión, finalidad y lector autorizado;
   las URLs firmadas no son identidad persistente. Cambiar un vídeo no invalida
   recetas anteriores. Las cuotas, reservas fallidas, conservación y recuperación
   deben acordarse; los límites de imágenes no autorizan vídeo ilimitado.
5. **Revisión, formularios y comunicación.** Definir audiencia, recurso/versión
   de referencia, estado persistente y comportamiento tras baja. ADMIN no recibe
   acceso general a conversaciones, respuestas o bibliotecas privadas. Una
   notificación o una marca visual local no acredita entrega ni revisión.
6. **Identidad y seguridad.** MFA y autorización en servidor según el recurso;
   separar identidad, ADMIN, Pro, acceso profesional, cupo, vínculo y pago.
   Cambiar cuenta invalida trabajos/respuestas pendientes y aísla cachés/colas.
   Ningún cliente concede derechos por su propio estado de interfaz.
7. **Dispositivos.** Prescripción, actividad importada, asociación y resultado
   confirmado son conceptos distintos. Importar no completa citas ni modifica
   el algoritmo. Mantener procedencia, unidades, permisos, revisiones y deduplicación;
   la vista profesional consume solo evidencia autorizada del resultado. Fuentes:
   [contrato de carrera](DEVICE_RUNNING_CONTRACT_V1.md) y
   [fases de dispositivos](DEVICE_INTEGRATIONS.md).
8. **Comercio.** Preparador → EntrenaOP y alumno → preparador tienen estados
   separados del Pro personal. Una redirección de pago no concede derechos.
   Condiciones no elegidas no provocan suspensión, baja ni pérdida de historial:
   [pagos](TRAINER_PAYMENTS.md).

Los contratos anteriores delimitan diseño y comprobación; esta hoja no inventa
nombres de RPC, tablas, estados ni esquemas definitivos. Se concretan junto al
código afectado antes de implementar cada ampliación.

## Secuencia de integración y cierre

Se mantiene una entrega funcional principal con tareas independientes en paralelo,
no dieciséis bloques grandes abiertos sin integración. Trainer ordena dependencias
y publica el siguiente tramo concreto en el roadmap al cerrar el anterior.
La preparación aislada de dispositivos puede continuar sin modificar la entrega
profesional activa.

Primer punto de control: cerrar la aceptación pendiente de TRN-019 mediante
ejercicio con foto → sesión/programa → pauta → app instalada del alumno →
ejecución → resultado autorizado → revisión que conserva la receta anterior.
La preparación de código, contratos y pruebas puede avanzar sin móvil; la prueba
humana con dos cuentas mantiene su estado pendiente hasta realizarla. La lectura
física del ensayo de Salud ya tiene evidencia propia; reinstalar el plugin nuevo
y comprobarlo en la app principal son hitos distintos aún pendientes.

Después se integran creación/medios, adaptación/calendario, revisión/evolución,
formularios/comunicación/automatizaciones e informes, respetando dependencias de
la matriz. Cobros reales y conexión de relojes tienen sus requisitos específicos;
su falta no bloquea mejoras independientes ni justifica simularlos como operativos.

Cada cierre aporta:

- Diff revisado, incluidos archivos nuevos, e integración con consumidores.
- Análisis y pruebas de las apps/paquetes afectados según `AGENTS.md`; los cambios
  comunes cubren también Trainer y sus adaptadores.
- Si cambia SQL/RLS: historial de migraciones contrastado con Dev y contrato SQL
  transaccional que termina con `ROLLBACK`; concurrencia real cuando la regla la
  requiera. No basta una prueba de widgets para acreditar aislamiento servidor.
- Recorrido funcional y recuperación de errores, identidad, móvil estrecho/texto
  ampliado y preservación del historial, en lo correspondiente al cambio.
- Evidencia separada de validación técnica, aceptación humana, distribución móvil,
  publicación web Dev y producción. Cada hito conserva sus permisos; no se concede
  autorización nueva de despliegue desde esta hoja.
- Decisiones/documentos sincronizados y un siguiente tramo concreto.

El punto de guardado se coordina con Trainer para evitar commits simultáneos.
Mantener `main`, cotejar el remoto antes de integrar y no incluir cambios ajenos
sin revisión. Una comprobación fallida se comunica y corrige; el bloque no se
declara cerrado ni se rebaja su verificación para guardar.

## Recuperación de creadores: primer tramo acordado y propuesta posterior

### Primer checkpoint de programas Trainer acordado

Tras publicar, Trainer acepta la revisión focalizada y asigna backend nuevo a
`professional_security_review`, adaptador/interfaz Trainer a `progress_domain`
y revisión independiente a `followup_domain`. Esta hoja no concede reservas
adicionales: sus propietarios las coordina Trainer. No se duplica editor ni
puerto. La composición ADMIN permanece propia; las correcciones generales de
posiciones repetidas y normalización se realizan una vez en el paquete común y
ADMIN cierra su matriz con ambos consumidores. El backend
`20261021172219_trainer_program_work_drafts.sql` ya está aplicado en Dev; la
interfaz está integrada, validada y publicada desde `37dcd14`; el recorrido de
Chrome acredita carga/lista/salida sin guardar, no aceptación de escritura real.

Se reutilizan `GuidedWorkRepository`, `GuidedWorkController` y la página común.
La clave de operación parcial es propietario/contexto/workId/acción/revisión
esperada; no hace falta añadir un UUID al puerto existente. El payload canónico
incluye estado y origen inmutable. Cada orden nueva aceptada consume una revisión
una sola vez; un replay idéntico recupera su recibo sin mutar HEAD. Otra carga
con la misma clave se rechaza. Si una orden nueva no cambia contenido, tampoco
puede dejar su slot de revisión consumido pero reutilizable para otro payload.

Servidor devuelve recibo confirmado y revisión/ciclo actuales. El adaptador
Trainer lanza conflicto si el recibo ya no corresponde al HEAD abierto, evitando
que el controlador marque como actual un estado histórico. La finalización
bloquea el trabajo, valida revisión/contenido/origen, usa workId como operación
estable del guardado de programa y registra resultado/cierre en la misma
transacción. Recarga consulta `finalizedProgramId`; no crea otra versión por
perder una respuesta. Se conserva también el rechazo existente a revisar una
versión base que otro trabajo ya retiró.

Política acordada por Trainer: el propietario con MFA puede recuperar el recibo
de una finalización ya confirmada aunque se haya revocado el acceso profesional;
no se ejecutan efectos nuevos. Guardados y finalizaciones nuevos exigen acceso
vigente. Los límites propuestos deben contar historial y recibos retenidos,
además de estados actuales, y comprobarse atómicamente; no se convierten en
tarifas ni justifican purgar trabajo automáticamente.

El controlador compara snapshots con representación canónica de mapas, sin
alterar el orden de listas ni el texto crudo. La composición común incorpora
`positionId` y `replacementPositions` para distinguir dos posiciones de una
misma receta al reintentar una sustitución, conservando lectura del estado
anterior. Eso no acredita recuperación de campos de una sesión hija incompleta.
El listado de trabajos devuelve estado resumido; abrir el editor carga el trabajo
completo por su ID. El helper de RPC fija la sesión al propietario y las cinco
RPC nuevas verifican `p_expected_owner` antes de leer, bloquear o recuperar recibo.

### Propuesta posterior para sesiones y trabajos anidados

La revisión siguiente se conserva como propuesta para ampliar después a sesiones
y trabajos hijos. Su API genérica/UUID explícito no reemplaza el acuerdo más
acotado del primer checkpoint ni obliga a cambiar el puerto ADMIN existente.
No acredita la API genérica implementada. Las posiciones de sesión ya tienen la
corrección aditiva indicada arriba; las identidades de fase y la durabilidad del
hijo incompleto requieren su tramo propio.

ADMIN prepara únicamente el diseño del puerto común de recuperación de sesiones.
Arquitectura revisará ese contrato y sus fronteras cuando se entregue; no se abre
su implementación ni se conceden nuevas reservas mientras las fuentes del bloque
actual sigan congeladas.
Trainer confirma en su revisión que faltan `phaseId`/`childWorkId` y que el
callback común `openSession` todavía no recibe el binding del trabajo hijo. Esas
carencias deben resolverse en la API opcional propuesta; `positionId` por sí solo
no acredita durabilidad de una sesión incompleta dentro del programa.

### Base histórica de la propuesta y reutilización

Este inventario describe lo observado antes del primer checkpoint; la inyección
Trainer y las posiciones ya han evolucionado como se indica arriba. No debe
interpretarse la carencia inicial como estado actual del código.

- `GuidedWorkRepository` y `GuidedWorkController`, en
  `packages/workout_editor_ui/lib/guided_program_work.dart`, ya permiten cargar,
  guardar trabajo incompleto, serializar cambios y conservar una petición
  incierta. `GuidedProgramEditorPage` guarda un snapshot `schema: 1` tras 700 ms
  y antes de abrir una sesión; distingue trabajo de guardado final validado.
- ADMIN conecta ese puerto con `SupabaseAdminGuidedWorkRepository`. Su contrato
  existente conserva trabajos privados, CAS y finalización atómica; no contiene
  un ledger general por operación para cada guardado parcial. Su deduplicación
  parcial compara revisión y estado actual. No atribuirle garantías de replay
  arbitrario ni ampliar sus RPC históricas silenciosamente.
- `TrainerProgramEditorPage` usa la misma composición, pero no inyecta todavía
  `workRepository`/`work`. La recuperación de programas debe conectar ese camino,
  mediante un adaptador profesional, sin duplicar página ni controlador.
- `WorkoutEditorPage` solo mantiene `_draftStamp` en memoria. Su `onSave` recibe
  `CreatePersonalWorkoutInput` después de `_input()` y `validateWorkoutDraft`:
  no admite estados incompletos. `additionalStateStamp` detecta cambios externos,
  pero no permite restaurar sus valores.
- Los workspaces de sesión de ADMIN y Trainer separan sesión guardada de enlace
  confirmado y permiten reintentar ese enlace en memoria. El programa conserva
  IDs de sesiones pendientes cuando dispone de checkpoint; no guarda los campos
  incompletos de la sesión hija antes de crearla. Las fases y posiciones del
  snapshot actual carecen de identidad estable distinta del ID de la receta.
- El borrador personal de la app usa `WorkoutEditorDraftStore` y almacenamiento
  local por usuario. No sustituirlo ni importar su implementación al editor común.
  Es un contrato distinto, basado en receta tipada y no en campos crudos.

### Puerto opcional y DTO propuestos

Añadir modelos puros de estado editable junto al editor compartido, sin imports
Flutter/Supabase, y mantener los widgets/controladores como presentación. Este
estado de formulario no necesita convertirse en una entidad deportiva de
`workout_core`. Propuesta mínima, con nombres pendientes de acordar:

```text
EditorWorkScope = entorno + propietario + contexto + tipoEditor + workId
                + recurso/versiónBase + parentWorkId/phaseId/slotId opcionales
                + assignmentId/serviceEpisodeId opcionales para adaptación

EditorWork<S> = scope + schemaVersion + revision + state:S + updatedAt
              + lifecycle + pendingSubmission? + finalizedResult?

SavePartial<S> = operationId + expectedRevision + state:S

EditorWorkRepository<S>:
  list(filtro acotado)
  load(workId)
  savePartial(workId, SavePartial<S>) -> EditorWork<S>
  discard(workId, operationId, expectedRevision) -> recibo
```

El adaptador queda ligado a scope inmutable y sesión/generación actual; el
servidor deriva propietario/contexto permitido de Auth y recurso. Los IDs del DTO
no conceden permisos. La generación de sesión es una barrera local, no una
credencial persistida. Retirar permiso impide nuevas escrituras aunque exista
un recibo anterior, conforme al contrato específico que se acuerde.

Para sesiones, `WorkoutEditorSnapshotV1` conserva nombre, descripción, duración
textual, modalidad y ambas ramas de carrera/fuerza, incluidas las inactivas.
Incluye orden y claves estables de bloques/segmentos/ejercicios, IDs de ejercicios,
enums, texto crudo de todos los campos, series personalizadas y excepciones por
serie. Un valor como `pendiente`, vacío o numéricamente inválido se puede guardar;
un JSON mal formado, esquema desconocido o estado excesivo se rechaza sin borrar
la copia anterior. Restaurar no ejecuta la validación final de receta.

Los campos específicos del consumidor requieren DTO explícito/versionado, por
ejemplo `showInLibrary` en ADMIN; no usar `additionalStateStamp` como contenido
recuperable ni permitir un mapa arbitrario de objetos. El snapshot persiste
referencias estables de ejercicios, recetas, calentamientos y activos de medios;
no persiste catálogos, URLs firmadas, tokens, headers, bytes ni credenciales. Las
referencias se resuelven otra vez con los permisos actuales; una retirada se
muestra como referencia no disponible, sin eliminar automáticamente su posición.

El puerto de la página será opcional, con estado inicial cargado por el
consumidor y controlador propio por montaje. Sin puerto se conserva el recorrido
actual. Para programas se reutiliza el checkpoint existente, adaptándolo al
contrato reforzado si se necesita ledger: no introducir otro autosave paralelo.
El lector `schema: 1` se conserva; añadir claves de fase/posición exige versión
nueva o una conversión explícita y estable que preserve el trabajo original.

### Escrituras, finalización y límites de contexto

Cada operación parcial conserva UUID, revisión esperada y payload exacto antes
de enviarse; un fallo incierto se resuelve antes de transmitir cambios nuevos.
El ledger de servidor acota identidad, contexto, trabajo y operación: replay
idéntico devuelve su recibo y cambiar payload con el mismo UUID se rechaza. Un
recibo antiguo no rebaja la revisión actual ni autoriza sobrescribirla. CAS
obsoleto presenta conflicto y conserva ambos estados; no mezcla campos por sí
solo. Desmontaje/logout invalida callbacks y timers; la confirmación tardía de A
no actualiza ni escribe en el contexto de B.

Guardar trabajo parcial no crea sesión ni publica/asigna/adapta nada. El guardado
final permanece en el adaptador del contexto, aplica la validación deportiva y
registra resultado/finalización del trabajo en la misma transacción que la
mutación autorizada, usando el ledger existente o uno compatible. No hacer
`onSave` seguido de un `clear` cliente como garantía de cierre. La petición final
incierta necesita identidad y payload recuperables al recargar; no puede vivir
solo en `_operation`, `_finalAttempt` o `_pending` en memoria. Reabrir primero
reconcilia esa petición y muestra el resultado, sin crear otra versión.

- **Sesión nueva o revisión:** `workId` estable desde su apertura, con origen y
  versión esperada. No usar `null` ni únicamente `previousId` como clave global.
- **Sesión dentro de programa:** guardar primero un `phaseId`/`slotId` estable y
  el `childWorkId` en el checkpoint padre, antes de abrir el hijo. Finalizar el
  hijo conserva el resultado ligado a esa posición; el enlace al padre se puede
  reintentar con CAS sin crear otra sesión. Recargar permite retomar el hijo
  incompleto o el resultado pendiente de incorporar. Eliminar/reordenar una
  posición concurrentemente produce conflicto explícito; no reinsertar al final.
  Es una coordinación recuperable entre dos trabajos, no atomicidad global.
- **Adaptación individual:** scope distinto de biblioteca, ligado a pauta,
  episodio de servicio y revisión/receta base. Restaurar campos no conserva como
  válida una previsualización antigua: se consulta de nuevo la pauta y el
  fingerprint antes de confirmar una operación aún no enviada. Si ya existe un
  envío incierto se reconcilia primero su recibo, sin generar otro UUID/payload.
  Pauta iniciada, cambiada o servicio terminado mantienen el conflicto de negocio;
  nunca se guarda la adaptación como revisión de la biblioteca para sortearlo.

Antes de SQL, Trainer debe concretar retención, límite de trabajos/tamaño y
comportamiento tras revocar acceso, y registrar el acuerdo en los documentos
responsables. Los 512 KiB de ADMIN actual son un límite existente, no un nuevo
límite profesional aprobado. No se propone purga automática ni borrado físico.

Validación del futuro tramo: round-trip de campos incompletos e inactivos;
compatibilidad sin puerto y de esquemas anteriores; conflicto y replay tras
respuesta perdida/recarga; aislamiento de cuentas/contextos/entornos y callbacks
tardíos; doble posición de una misma receta; hijo finalizado sin enlace; padre
reordenado/posición retirada; catálogo retirado; adaptación cruzada con inicio o
baja; finalización repetida sin versiones duplicadas. Solo se ha realizado esta
revisión de código/documentos: no hay nuevas pruebas ejecutadas ni persistencia
implementada por esta propuesta.

## Uso de Harbiz y decisiones aún abiertas

Harbiz y su guía ayudan a observar pasos, errores y tareas repetitivas. Cada idea
debe resolver una necesidad verificable de EntrenaOP. Conservar formatos,
personalización, accesibilidad, versiones, historial y permisos propios si la
alternativa observada es peor. No copiar interfaces/datos/contenido por inercia
ni añadir funciones sin un recorrido útil y un criterio de cierre.

Siguen pendientes proveedor y condiciones comerciales. El vídeo profesional ya
tiene límites técnicos provisionales y contrato de acceso/conservación en
[su documento responsable](TRAINER_PRIVATE_VIDEOS.md); no equivalen a tarifas ni
a una política comercial definitiva. Cada categoría nueva de datos requiere su
contrato de compartición. Los números de cupo citados como ejemplos no son tarifas aprobadas.
Garmin directo y otras capacidades de relojes necesitan acceso y pruebas reales;
la cobertura objetivo no acredita compatibilidad universal. Registrar cada
decisión pendiente en el contrato responsable, sin bloquear el resto del trabajo.
