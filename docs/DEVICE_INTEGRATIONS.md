# Dispositivos y actividades · bloque común · INT-001

## Dispositivos y conexiones · INT-022

Desde el 28/10/2026, Perfil ofrece un único acceso **Dispositivos y conexiones**
(`/profile/connections`). Agrupa **Salud del móvil** y **Garmin**, y añade en Dev el primer recorrido de
[Apple Watch](DEVICE_APPLE_WATCH.md), conservando
los recorridos existentes de historial, permisos y gestión de Garmin. Los enlaces
anteriores y el retorno de autorización siguen siendo válidos. Volver desde una
conexión actualiza sus estados; cambiar de cuenta descarta el estado anterior.

La vista general no solicita permisos nativos, no lee actividades y no inicia
autorizaciones ni desconexiones. Salud muestra disponibilidad de lectura, que
no equivale a permiso concedido por HealthKit. En iPhone se accede al historial
y a la lectura explícita de Salud de Apple; en web se consulta el historial.
Health Connect sigue sin integrarse en la app principal de Android. Garmin
muestra el estado del contrato existente; si falla su consulta se indica estado
sin confirmar. La ausencia de Pro o servicio vigente impide sincronizar, pero
permite gestionar y retirar accesos. No se cambian contratos ni controles del
servidor. Los proveedores futuros tendrán entrada cuando estén implementados.

El contrato actual no devuelve una fecha de última sincronización: no se
sustituye por la caducidad del permiso ni por la hora de consulta. Las capturas
de widgets con datos ficticios están en
[`visual-audit/device-connections-2026-10-28/`](visual-audit/device-connections-2026-10-28/),
incluido texto al 150 %. Las pruebas cubren navegación de ida y vuelta,
aislamiento de cuenta, errores y ausencia de llamadas que cambien permisos.
Esta reorganización requiere una nueva compilación de la app instalada; los
cambios de Flutter no llegan al iPhone mediante la sincronización de Garmin.
El bloque de integraciones conserva sus límites y pruebas físicas pendientes.

Validación del 28/10/2026: `flutter analyze --no-pub` sin incidencias;
36 pruebas focalizadas y 1.388 pruebas de la raíz correctas, con una omitida;
tres capturas revisadas y compilación web release con `APP_ENV=development`
correcta. Es una compilación local, no una publicación ni actualización iOS.

## Evolución y alcance de las integraciones

**Actualización INT-012 · 23/10/2026:** Garmin ya recibe actividades FIT en Dev
y permite asociarlas con revisión explícita a una cita pendiente. La primera
carrera física queda completada desde la app web con resultados reales y sin
duplicar la ejecución. La edición de la biblioteca conserva la versión enviada;
Auto Lap se agrupa por su índice nativo. No amplía otros proveedores, fuerza o
producción. [Estado y límites actuales](DEVICE_GARMIN_ACTIVITY_RETURN.md).


## Decisión y estado · 21/10/2026

Javier aprueba trabajar las integraciones como un bloque común de la app del
deportista, ADMIN y el portal de entrenadores, empezando por carrera. Pide
conservar Clean Architecture, no entorpecer la arquitectura profesional en curso
y perseguir cobertura de Salud de Apple, Garmin, COROS, Suunto y Huawei.
Health Connect es la entrada de salud del ecosistema Android.

**Acordado:** alcance común, separación de responsabilidades, comienzo por
contrato y acceso a proveedores, y aislamiento del trabajo profesional activo.
**Definido inicialmente:** contrato documental V1 y comprobación de las vías
públicas de acceso. **INT-002:** dominio puro de importación/asociación y pruebas
implementados en `device_activity_core`, sin consumo desde las apps.
**INT-003:** puentes HealthKit/Health Connect y lectura
explícita implementados en el ensayo aislado, con primera lectura física iPhone
desde Garmin Connect acreditada y distancia/duración contrastadas con Garmin
en dos carreras a precisión de pantalla; descarte y relectura sin repetición
confirmados por el titular. Revocar/restaurar lectura desde Salud retira/devuelve
las carreras en el ensayo. Pausas y Android físico pendientes. El puente
iOS y adaptador Dart se extraen a `device_health`.
**INT-004:** la app principal consume el plugin iOS desde Perfil → Carreras de
Salud, con lectura explícita, revisión y guardado privado por cuenta. El dominio
y los puertos permanecen separados de HealthKit y Supabase. Persistencia/RPC
aplicadas y probadas solo en Dev; revisiones inmutables, reintentos sin duplicar,
cuotas agregadas y aislamiento de cuentas comprobados con fixtures. Compilación
Android de la app principal correcta; Health Connect continúa en el ensayo,
sin elevar el mínimo Android. La CI de `37dcd14` compila iOS Simulator de la app
principal; la aceptación física del recorrido de lectura/guardado sigue pendiente.
[Contrato y evidencia](DEVICE_RUNNING_HISTORY.md).
Faltan conectores de producción, exportación, interfaces/autorización de ADMIN
y Trainer, y lectura Android en la app principal.
**Actualización Garmin · 22/10/2026:** Javier aporta el correo que confirma su
admisión al Garmin Connect Developer Program; después confirma aceptación de
condiciones y muestra `EntrenaOP Dev`, OAuth 2.0, Starter habilitado y credenciales
aprobadas con valores ocultos. Después activa Training desde API Tools; recargar
API Configuration acredita Activity y Training activadas y Approved, con cero
endpoints de recepción activos. Se implementa el adaptador OAuth de servidor
según especificación autenticada 2.0 y después el servicio de conexión por cuenta,
tokens cifrados y dos handlers Edge, con pantalla propia dentro de Perfil.
Javier autoriza después activar solo Dev: migración aplicada y funciones ACTIVE
v1, con contrato SQL repetido con ROLLBACK y CI correcta. Secretos cargados
directamente desde el helper local; la conexión real queda verificada desde
navegador, con lectura/envío autorizados, tokens cifrados e intento consumido.
La desconexión real queda también verificada: permisos desactivados y grant e
identidad eliminados tras retirada satisfactoria en Garmin. Se comprueban 401
sin sesión y 400 para callback inválido.
Salud y Trainer conservan sus contratos;
el bloque funcional sigue abierto.
INT-007 añade después el primer envío de carrera con servicio común para
algoritmo y asignaciones, y revisión en la app del deportista. Servidor activo
solo en Dev, con pruebas/CI correctas. Primera entrega y recepción/inicio en
fēnix 8 acreditados desde iPhone; revisión completa de pasos y alertas pendiente.
[Contrato](DEVICE_GARMIN_TRAINING.md).
[Contrato, evidencia y siguiente tramo](DEVICE_GARMIN_CONNECT.md).
[Estado de acceso](DEVICE_PROVIDER_ACCESS_2026_10_21.md),
[API y fronteras](../packages/device_activity_core/README.md).

La cobertura de todas las marcas es un objetivo del producto. Cada combinación
de reloj, firmware, teléfono, sistema y proveedor necesitará evidencia propia.
No se promete compatibilidad universal ni igualdad de funciones. Una conexión
que permite leer actividades no acredita envío de sesiones ni datos en directo.

- [Contrato de carrera V1](DEVICE_RUNNING_CONTRACT_V1.md).
- [Historial privado por cuenta e integración iOS](DEVICE_RUNNING_HISTORY.md).
- [Acceso a proveedores y expediente de alta](DEVICE_PROVIDER_ACCESS_2026_10_21.md).
- Fronteras actuales: [arquitectura](ARCHITECTURE.md),
  [sesiones profesionales](TRAINER_PRIVATE_WORKOUTS.md) y
  [continuidad de la cartera](TRAINER_CLIENT_LIFECYCLE.md).

## Recorrido objetivo

Sesión prevista y versionada → comprobación de compatibilidad → envío consentido
al proveedor → realización en el reloj → importación de la actividad → propuesta
de asociación → revisión y confirmación en EntrenaOP → consulta autorizada del
preparador cuando corresponda.

La primera vertical operativa será más pequeña: importar una carrera real desde
Salud de Apple o Health Connect, revisar sus datos y vincularla sin duplicados a
una sesión prevista. No requiere disponer previamente de una API Garmin ni de
envío al reloj. El registro manual existente sigue siendo utilizable.

## Responsabilidad de las tres aplicaciones

| Espacio | Responsabilidad objetivo | Frontera |
| --- | --- | --- |
| Deportista | Autorizar conexión/lectura, conocer datos y destino, sincronizar, revisar actividades, asociar y confirmar resultados; envío cuando exista soporte. | El titular controla sus conexiones. Los permisos de salud se solicitan en el dispositivo compatible. |
| Entrenadores | Prescribir con el creador actual y comparar pauta con resultado confirmado de su servicio, mostrando procedencia, datos ausentes y estado de sincronización. | No conecta cuentas ajenas ni recibe acceso al historial general, tokens, datos diarios de salud o rutas del alumno. |
| ADMIN | Estado operativo de proveedores, disponibilidad y errores reducidos; comprobación de compatibilidad editorial de recetas oficiales. | Administrar el sistema no concede lectura general de actividades personales ni potestad para aceptar permisos por el alumno. |
| Servicios comunes | Normalización, compatibilidad, idempotencia, procedencia, propuestas de asociación y control de acceso. | Los detalles de un fabricante no se propagan al dominio deportivo ni a las pantallas profesionales. |

La conexión local de salud se hace desde iPhone/Android. ADMIN y Trainer web
consumirán únicamente datos ya sincronizados y autorizados; no intentarán leer
HealthKit o Health Connect desde el navegador. La app web del deportista tampoco
heredará esas capacidades nativas por compartir código Flutter.

## Arquitectura y aislamiento

El dominio de integraciones tendrá entidades, validación y políticas puras Dart,
sin Flutter, Supabase, HTTP, SDK de salud ni dependencias de `trainer_app/`.
Los puertos representan fronteras reales: lectura incremental de actividades,
almacenamiento, comprobación de capacidades y envío de una receta compatible.
Los casos de uso solo se introducirán donde haya orquestación o reglas propias.

Los adaptadores de HealthKit/Health Connect vivirán en la integración móvil;
OAuth y callbacks de fabricantes, renovación de credenciales y trabajos
asíncronos vivirán en servidor. El servidor volverá a validar identidad,
permisos, asociación y datos recibidos, también si proceden del teléfono.
Los modelos JSON, el transporte y los SDK pertenecen a datos/infraestructura.

La orquestación depende de los puertos; sus implementaciones se inyectan desde
la composición de cada aplicación/servicio. La presentación usa Bloc/Cubit para
estados de producto. El motor de carrera no importará SDK ni conocerá marcas.

INT-002 materializa el dominio en `packages/device_activity_core/`, sin
dependencias de ejecución; `test` y `lints` son herramientas de desarrollo
fijadas y su lockfile se versiona expresamente. No se mueven entidades ni se
añade la dependencia a las apps. La futura exportación reutilizará la receta de
`workout_core`; no habrá otro editor o planificador.

### Regla de convivencia con el trabajo profesional activo

- INT-001 documenta y INT-002 añade el paquete puro y su validación de CI, con
  referencias acotadas en los índices comunes. No modifica `trainer_app/`,
  `trainer_access`, creadores,
  asignaciones, migraciones, agenda, resultados o inyección de dependencias.
- No exige al bloque profesional añadir campos de dispositivo ni esperar a
  disponer de accesos externos. Sus pruebas y entregas conservan su alcance.
- La futura integración entrará desde el identificador de cita y la ejecución
  existentes, mediante un adaptador. No creará otra relación entrenador-alumno,
  otra agenda ni otro historial deportivo.
- Antes de conectar el resultado externo con la escritura real se contrastarán
  los contratos profesionales que estén vigentes entonces. No se fijan ahora
  cambios sobre archivos o RPC que otro trabajo está desarrollando.
- Los puntos de guardado de este tramo incluyen solo sus archivos revisados.
  La presencia de cambios simultáneos no autoriza incorporarlos al commit.

## Fases y condiciones de avance

| Fase | Entrega | Condición para darla por comprobada |
| --- | --- | --- |
| 0 · documentada | Contrato, capacidades, acceso público y expediente de alta. | Vías públicas revisadas, sin acreditar credenciales operativas. |
| 1 · implementada por INT-002 | Dominio puro y políticas de importación/asociación. | 56 pruebas de duplicados, datos incompletos, versiones, tiempos y reintentos; sin dependencia de Trainer. |
| 2 | Lectura de carrera desde Salud de Apple y Health Connect. | Prueba real por plataforma, permisos parciales/revocados, cierre de sesión y lectura incremental; sin perder registro manual. |
| 3 | Resultado confirmado e integración autorizada en las tres apps. | Una actividad real queda vinculada una sola vez; alumno y preparador ven solo lo que permite su contrato; ADMIN solo diagnóstico. |
| 4 | Envío de sesiones y conectores directos de fabricantes. | Credenciales aprobadas, receta compatible y envío/recepción reales; pruebas por combinación de dispositivo y proveedor. |

La comprobación documental de altas se puede completar mientras avanza Trainer.
La implementación transversal de las fases siguientes se incorporará en un
orden acordado con los bloques abiertos, sin convertir integraciones en un
segundo desarrollo transversal simultáneo. El orden recomendado sigue siendo
contrato → dominio → lectura móvil → confirmación autorizada → envío. Las altas
externas pueden tramitarse aparte sin bloquear la lectura local de salud.

## Límites y decisiones que siguen pendientes

El objetivo V1 son actividades de carrera y resultados útiles para sesiones ya
previstas. GPS/mapas en directo, app propia para cada reloj, sensores Bluetooth,
lectura de sueño o salud diaria, diagnóstico y modificación del algoritmo no
se incluyen en la primera vertical. La ausencia de un dato se conserva como
ausencia, nunca como cero, incumplimiento o dato inventado.

### Acceso comercial confirmado · INT-006 · 22/10/2026

Javier confirma que Salud de Apple y Health Connect están disponibles para
todos los usuarios, incluido Free. Corrige expresamente la interpretación
anterior que los reservaba al pago. Las conexiones directas a Garmin, COROS,
Suunto y Huawei se reservan a Pro vigente o al acceso incluido del alumno con
servicio profesional vigente. No se exige Pro adicional al alumno ni se le
concede todo Pro por tener esa relación. Se utilizan derechos efectivos del
servidor, no un pago declarado desde Flutter ni la mera existencia de un vínculo
histórico. Las concesiones Pro autorizadas conservan el contrato comercial actual.

Salud/Health Connect ofrecen una entrada básica también para usuarios Free;
una lectura por esos canales no equivale a una conexión directa a la API Garmin.
La capacidad Starter comunicada se refiere a usuarios Garmin conectados, no al
total de cuentas Pro ni al origen de las sesiones. No se presupone cómo libera
Garmin una plaza tras una baja ni se fijan aquí tarifas de ampliación.

| Operación | Regla acordada |
| --- | --- |
| Leer/importar/sincronizar desde Salud o Health Connect | Todos los usuarios, incluido Free, con consentimiento y capacidad real del canal. |
| Conectar y leer/importar/sincronizar directamente con fabricantes | Pro vigente o servicio profesional vigente, además de consentimiento y capacidad real del canal. |
| Enviar una sesión del algoritmo | Acceso comercial y derecho vigente a consumir esa prescripción del algoritmo, receta compatible y permiso de envío del titular. |
| Enviar una asignación del entrenador | Servicio profesional y autorización sobre la asignación concreta; sin Pro personal adicional. El entrenador no concede el consentimiento Garmin del alumno. |
| Enviar otras sesiones/programas compatibles | Posible ampliación futura para usuarios con acceso; no se habilita en la primera fase ni se excluye permanentemente. |
| Consultar historial ya conservado al perder acceso | Se mantiene; no se borran carreras por dejar Pro o el servicio profesional. |

La primera fase limita la exportación a algoritmo/entrenador para acotar el
desarrollo y validar la traducción de recetas; esa restricción no supone por sí
misma ahorrar plazas Garmin. La procedencia se acredita desde la prescripción y
asignación autorizadas del servidor, nunca desde una etiqueta enviada por el
cliente o desde quien creó originalmente una plantilla reutilizada.

La pérdida de acceso comercial detiene nuevas operaciones directas con
fabricantes y envíos; Salud/Health Connect siguen disponibles en Free. Los
trabajos pendientes deberán revalidar acceso y generación antes de actuar.
No implica borrar historial ni retirar silenciosamente sesiones ya entregadas
al proveedor. Desconexión y borrado conservan recorridos propios.

**Pendiente de implementación:** proteger en servidor las operaciones directas
con fabricantes y el envío conforme a este acceso comercial. No se debe añadir
un bloqueo Pro a la lectura/importación de Salud de INT-004 ni a Health Connect.
INT-006 no afirma controles comerciales ya aplicados y no modifica ahora
Trainer/Flutter/SQL.

Antes de almacenar datos reales quedarán concretados el inventario mínimo de
datos, información/consentimiento de subida y comunicación al preparador,
retención y borrado, condiciones de los proveedores y permisos de servidor.
Revocar conexión detiene importaciones nuevas; desconexión y eliminación de
datos ya guardados son acciones distintas que deben explicarse al titular.
La baja profesional conserva el contrato de TRN-015/016 y no abre datos nuevos.

## Evidencia de la definición inicial · INT-001

Inspección localizada de `workout_core`, `WorkoutExecution`, `ScheduledWorkout`,
contratos profesionales y configuración nativa. El código distingue
`WorkoutResultSource.manual/device`, sin conector ni identidad externa. La cita
ya conserva origen, versión y ejecución. No se han ejecutado Flutter ni SQL al
tratarse de una entrega exclusivamente documental. Se revisan diff, enlaces
locales y estado de Git; no se actualizan instantáneas generales ni se atribuyen
pruebas de otros bloques a esta entrega.

## Evidencia del dominio puro · INT-002 · 21/10/2026

`device_activity_core` implementa entidades inmutables, validación y conservación
de precisión, planes de importación por conexión/generación/cursor, recibos
idempotentes, revisiones ordenables por fecha de origen, cuarentena, borrados,
candidatos de duplicados y vista previa/asociación con primaria y alias explícitos.
Una actualización dudosa no sobreescribe ni se ofrece como resultado revisable.
Asociar fija evidencia y cita/versiones; no crea ejecución ni resultados.

Dart 3.13.4 resuelve el lockfile; formatter y análisis sin incidencias. Pasan
56 pruebas puras y 1144 pruebas de raíz (una omisión previa), con Flutter analyze
limpio. La comprobación de imports confirma ausencia de dependencias externas
en `lib/`. Ocho escenarios Bash verifican el detector real de alcance de CI.
El workflow incorpora resolución y ejecución del paquete; el cambio limitado a este dominio,
documentación e integración CI no publica ADMIN Dev. No se modifica configuración
de despliegue de Trainer ni se reclama validación de apps no modificadas.

Los planes deben persistirse en servidor con comprobación atómica de checkpoint,
identidad, permisos y revisión actual; esa implementación queda pendiente.
Tolerancias de similitud se inyectan con versión y no constituyen reglas
deportivas aprobadas. Resolver avisos de duplicados, cuarentenas de orden
desconocido, retención y datos reales requiere su flujo de integración.

**Único siguiente tramo técnico recomendado:** ensayo móvil aislado de lectura
de carrera desde Salud de Apple y Health Connect, contrastando SDK, permisos y
una actividad real antes de conectar almacenamiento o pantallas profesionales.

## Ensayo móvil preparado · INT-003 · 21/10/2026

Se implementa el ensayo independiente en `labs/health_read_probe`, con puentes
mínimos a SDK oficiales y consulta explícita de siete días. Mantiene el dominio
puro y no incorpora dependencias ni conexiones a deportista, ADMIN o Trainer.
Android compila y las pruebas con muestras pasan; CI confirma además ambos
builds nativos, incluido iOS Simulator. Javier aporta primera lectura física
positiva de Salud en iPhone y contrasta distancia/duración con Garmin en dos carreras.
Javier confirma además descarte al volver de Garmin y relectura sin repetición.
La CI `124fa76` compila el plugin iOS y el ensayo Android; el plugin sigue sin
consumirse en la app principal. La revocación y restauración desde Salud están
contrastadas por Javier. La fase móvil permanece abierta por pausas,
reinstalación del plugin y Android físico pendientes.

Javier usa iPhone y Garmin Connect: queda acreditado el recorrido
Connect → Salud → ensayo, con permisos del titular y límites de los
datos que Garmin comparte. Android no necesita bloquear la primera integración
iOS; se mantiene su ensayo sin elevar el mínimo Android de la app principal.
El eventual voluntario con Huawei debe comprobar primero su llegada a
Health Connect. [Contrato local, fuentes y protocolo](DEVICE_HEALTH_READ_PROBE.md).

## Propiedad y coordinación transversal · 21/10/2026

Javier confirma que este chat lleva la conexión e integración con relojes y
almacenes de salud: acceso a proveedores, adaptadores, permisos de conexión,
sincronización, normalización, duplicados y futura entrega de entrenamientos
cuando el canal la permita. La coordinación con otros chats permite integrar
esa capacidad en las tres apps, sin trasladar aquí su navegación ni sus editores.

Este tramo mantiene como propias `packages/device_activity_core/`,
`labs/health_read_probe/`, `docs/DEVICE_*.md` y el workflow aislado del ensayo.
El chat profesional conserva Trainer y sus contratos; ADMIN conserva sus
creadores. El responsable transversal consolida la coordinación en
`docs/PROFESSIONAL_DELIVERY_COORDINATION.md`. Los índices comunes y los archivos
de otro responsable no se editan simultáneamente desde este bloque.

La siguiente frontera desarrolla INT-001/002 y es una propuesta para contrastar
con los contratos profesionales vigentes antes de implementarla. No crea DTO,
tabla, permiso, estado de sesión ni endpoints nuevos por quedar descrita aquí.
La importación, la asociación y la confirmación siguen siendo operaciones distintas.

| Paso de integración | Contrato y responsable | Regla de frontera |
| --- | --- | --- |
| Adquirir una carrera | Dispositivos adapta la lectura al `ExternalActivity` existente. | Identidad, revisión, tiempos, unidades y origen explícitos. El permiso local de Salud no acredita autorización para subir o compartir datos. |
| Persistir observaciones privadas | Dispositivos y responsable de servidor acuerdan la transacción antes de incorporar infraestructura. | El servidor obtiene el propietario de la identidad autenticada y valida conexión/generación/checkpoint. El preparador y ADMIN no reciben este almacén personal. |
| Proyectar una cita | El dueño de planificación entrega una proyección al `RunningSessionTarget` existente mediante adaptador. | Conserva propietario, cita, receta/versión, revisión, estado y ejecución/revisión de resultado. No se copia la agenda ni se modifica la receta desde el conector. |
| Revisar y asociar | Dispositivos entrega candidatura y revisión; el alumno elige cita, actividad primaria y posibles alias. | La semejanza no fusiona ni decide. Una orden idempotente se vuelve a validar contra versiones y permisos actuales. Asociar conserva evidencia y no completa la sesión. |
| Confirmar resultado | El responsable de ejecución/resultados acuerda con dispositivos la escritura autorizada existente o su extensión necesaria. | Hace falta acción explícita del alumno y comprobación atómica de propiedad, cita, versiones, resultado y continuidad profesional. No se simula una ejecución del móvil para introducir datos del reloj. |
| Mostrar al preparador | Trainer consume la proyección autorizada del resultado confirmado de su servicio. | Solo campos necesarios y procedencia legible; quedan fuera cuenta externa, tokens, rutas, salud diaria y actividades personales sin compartir/asociar. El rol de entrenador no abre el historial completo. |
| Mostrar a ADMIN | ADMIN consume capacidades y diagnóstico operativo reducido. | Administrar un proveedor no concede acceso a carreras personales ni permite consentir por el alumno. |
| Entregar al reloj | Dispositivos adapta una receta ya fijada y autorizada, cuando exista acceso al proveedor y compatibilidad comprobada. | No se crea otro editor. Envío solicitado, aceptado por proveedor y disponible en reloj son evidencias distintas; una respuesta incierta no provoca reenvíos duplicados. |

### Contrato que debe acordarse antes de escribir resultados

La orden debe conservar un identificador idempotente y las revisiones mostradas
de la actividad y de la cita/receta/ejecución/resultado. La respuesta confirmada
debe devolver identidad y revisión del resultado y la evidencia usada; el
transporte y sus nombres concretos se decidirán con su propietario. El hash del
snapshot HealthKit no demuestra cuál de dos revisiones distintas es posterior.
Los cambios de origen, las métricas ausentes y la precisión original se conservan;
una proyección al modelo deportivo actual no puede redondear o atribuir segmentos
silenciosamente para hacer encajar una receta.

Antes de subir datos reales se concretarán finalidad, datos mínimos, información
y autorización del alumno para ese destino, retención y borrado. Los permisos
del sistema de salud y el acceso profesional son fronteras distintas. Las reglas
vigentes de relación, asignación, MFA y continuidad profesional siguen siendo
la autoridad. Una pauta retirada o una baja no se eluden con una importación
tardía; una actividad corregida no cambia automáticamente un resultado confirmado.
Si no existe autorización para comunicarla al preparador, permanece en el ámbito
personal del alumno. Tampoco se concede acceso privado general a ADMIN.

La integración deberá verificar con servidor dos confirmaciones simultáneas,
reintento tras respuesta perdida, cita o receta revisada, ejecución ya existente,
relación finalizada, otro preparador, alumno ajeno, retirada del permiso local y
borrado/corrección externa. Estas comprobaciones de servidor aún no están
implementadas por el paquete puro ni por el ensayo móvil.

### Qué puede avanzar y qué requiere evidencia externa

| Trabajo | Sin móvil | Evidencia pendiente |
| --- | --- | --- |
| Dominio, precisión, cuarentena, duplicados y revisión/asociación | Implementados y probados en el paquete puro. | Persistencia atómica, permisos y confirmación real se validarán en su integración. |
| Puentes locales, permiso mínimo y compilación nativa | Implementados en el ensayo y compilados en CI; preparación de iPhone disponible. | Firma/provisión, diálogo real, carrera de Connect en Salud, lectura y revocación en iPhone; recorrido equivalente Android. |
| Contrato con planificación/resultados y privacidad profesional | Se puede contrastar con sus propietarios y probar con muestras sin conectar las apps. | Acuerdo coordinado antes de cambiar contratos, datos o dependencias; aceptación del recorrido con alumno y preparador. |
| Conectores de Garmin, COROS, Suunto y Huawei | Se pueden preparar expedientes, matrices de capacidad y adaptadores con muestras documentadas. Garmin ya tiene Activity y Training activadas y adaptador OAuth probado con fixtures. | Garmin: autorización persistente por cuenta y actividad real antes de exponer el conector. COROS, Suunto y Huawei: alta/credenciales pendientes. |
| Envío de receta al proveedor/reloj | Se pueden comprobar compatibilidad y traducción pura de la receta. | Acceso al canal de envío, recepción real en el reloj y ejecución; leer desde Salud no prueba ese envío. |

**Siguiente entrega operativa:** instalar el ensayo en el iPhone cuando Javier
pueda conectarlo al Mac y acreditar la carrera de Connect ya visible en Salud.
En paralelo solo avanzan preparación y contratos aislados; este documento no
habilita una integración en Trainer ni anuncia soporte universal de relojes.

## Avance con otros proveedores sin móvil · 21/10/2026

Javier autoriza seguir con proveedores y pruebas independientes del iPhone.
El ensayo incorpora un adaptador FIT acotado y un lector local de terminal,
con dependencia exclusiva en datos/infraestructura del laboratorio. Recibe la
identidad del adquirente y entrega `ExternalActivity`; el dominio puro y las
dependencias de las tres apps permanecen intactos. No hay conexiones API nuevas.

Garmin, COROS y Suunto documentan FIT como formato de actividades. Se comprueban
estructura, CRC, precisión, procedencia, vueltas y límites con muestras sintéticas;
no se convierten metadatos de fabricante en identidad autenticada ni una lectura
en sesión completada. Huawei mantiene su propio expediente: no se presupone
que exporte este mismo formato o que su carrera llegue a Salud/Health Connect.

Pasan 43 pruebas del ensayo y CI confirma Android e iOS Simulator tras la
dependencia para `0e38be8`. La ejecución `39629315392` figura correcta, aunque
el job iOS sigue `in_progress` con todos sus pasos correctos; se conserva esa
discrepancia sin acreditar el cierre global del job. La cobertura
FIT es deliberadamente parcial y necesita archivos reales representativos;
en concreto, timestamps comprimidos y campos developer se rechazan. Lectura
física de Salud y conexión/credenciales de los proveedores siguen pendientes.
[Implementación, ejecución sin móvil y evidencia](DEVICE_FIT_READ_PROBE.md).
