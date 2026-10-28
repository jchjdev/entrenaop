# Avisos push del alumno · TRN-029 · 24/10/2026

## Avisos al preparador · TRN-037 · 28/10/2026

En la app: **Entrenador → Resumen → Avisos de mis alumnos**. Solo se presenta en
cuentas profesionales y dispositivos con transporte nativo configurado. No es
push del navegador: Trainer web conserva su bandeja y sus globos de mensajes.
Activación expresa, con permiso del sistema, y dos categorías: mensajes y vídeos.
Guardar exige cuenta fijada, MFA y acceso profesional vigente; las revisiones
evitan sobrescribir ajustes guardados en otro dispositivo.

Los mensajes de todos sus alumnos se agrupan en un único trabajo por teléfono;
los vídeos, en otro. Espera un minuto desde la última llegada, con tope de dos
desde la primera pendiente y al menos diez minutos entre envíos del mismo tipo.
El programador existente revisa cada minuto: no es una alarma de tiempo exacto.
Comparten zona horaria y descanso (inicialmente Madrid, 22:00–08:00) con los avisos
personales; el consentimiento de ambas bandejas es independiente. Activar el
profesional por primera vez conserva los avisos personales previos o los deja
apagados si no existían. Desactivar el canal personal conserva el profesional.
Los clientes antiguos mantienen su consentimiento previo en instalaciones activas.

Antes de enviar se comprueba nuevamente acceso del preparador, vínculo activo,
cuenta/instalación, consentimiento y fuente pendiente de las últimas 24 horas.
Leer los mensajes desde web o móvil los excluye; un vídeo solo avisa cuando
está listo y compartido. Retirarlo, corregirlo o pulsar **Marcar vídeo como visto**
lo excluye. Abrir una lista no declara vistos todos sus vídeos ni los considera
corregidos. Volver a compartir el mismo archivo no crea otra push. Para mí no
produce avisos profesionales propios. Activar ajustes o registrar otro teléfono
no genera un volcado de avisos antiguos.

La notificación contiene solo EntrenaOP y un texto genérico de categoría; no
incluye nombres, textos, URL ni identificadores de alumnos. Al pulsar, el servidor
resuelve la conversación/sesión propia más reciente que sigue pendiente. Si la
sesión requiere MFA o ya no queda esa novedad, abre la bandeja profesional tras
su protección habitual. Una respuesta tardía de otra cuenta se descarta.
FCM usa tres claves de colapso: alumno, mensajes profesionales y vídeos
profesionales. El sistema puede sustituir un aviso anterior del mismo tipo.
Una lectura/revocación posterior a la petición ya enviada a FCM no puede retirar
con certeza una notificación entregada; los permisos se vuelven a comprobar al abrir.
[Colapso oficial de FCM](https://firebase.google.com/docs/cloud-messaging/customize-messages/collapsible-message-types).

Los canales personales se guardan por instalación y cuenta propietaria: apagar
el personal en un teléfono no lo apaga en otro. El consentimiento profesional
por cuenta solo entrega en instalaciones activas que ya dieron permiso al sistema.
Renovar una dirección conserva los canales; una activación personal explícita
sí puede encender el personal. La renovación idempotente usa la asociación que
realmente devuelve el servidor, que puede ser distinta de la UUID solicitada.
El contrato inicial de preferencias por cuenta se conserva como compatibilidad;
su setter global se revoca y no gobierna el despacho de dispositivos.

La migración deja el envío profesional deshabilitado hasta desplegar el worker
compatible. Dev ya tiene worker v9, JWT obligatorio, respuesta pública 401 y
`coach_enabled=true`; no hay preparadores suscritos automáticamente. No se añade otro programador, proyecto Firebase ni credencial.
El worker anterior se amplía manteniendo ticket efímero, JWT y secretos existentes.
Las nuevas tablas son privadas, con RLS y sin permisos de lectura directa.


### Validación del 28/10/2026

Análisis limpios de raíz, Trainer y ADMIN; 1.421 pruebas raíz, 286 Trainer,
316 ADMIN y sus omisiones previas. Transporte: 12 pruebas Node y TypeScript
5.9.3 estricto. Siete contratos SQL pasan en Dev con ROLLBACK, incluidas las dos
nuevas baterías de avisos profesionales y canales por teléfono. Incluyen fuentes
reales de mensaje/vídeo, aislamiento/MFA, dos alumnos agrupados, lectura anterior
al envío, llegada durante reclamación, pausa, revocación, compartición y dos
instalaciones de una cuenta con consentimientos distintos. Se comprueba además
renovación sin reactivar canales, respuesta idempotente y cambio de titular.
Historial Dev: 240 migraciones coincidentes. No hay Android conectado en la
comprobación; falta aceptar físicamente la entrega profesional y su apertura.
No se configura APNs ni se modifica producción.

### Publicación comprobada

Código `dd1c4ffe8f3fea9653a5db019546836403fc9628`, guardado en main y remoto.
Trainer y ADMIN publicados automáticamente, runs `40691325832` y `40691325878`,
ambos correctos; manifiestos públicos de esa revisión, hashes de JavaScript,
cabeceras y MIME WebAssembly verificados. Las comprobaciones de transporte y
Garmin también terminan correctamente, incluida compilación iOS sin firma.
Los paquetes compartidos conservan 218 pruebas del editor y 22 de acceso.

APK Dev privada **1.0.0-beta.2+3**, compilada desde fuentes sin modificar y firma
beta fijada verificada: `build/android-beta/trainer-push-dd1c4ffe/`.
SHA-256 APK: `643d78a7a2a04c49bbe3d441972c2744f09d2a2e7ed9ac983aa6d032b7302dd0`.
El manifiesto local acredita Dev, Firebase Dev y push habilitada; no se instala
porque no hay teléfono conectado. Compilar iOS no acredita APNs ni recepción.

### Comprobación manual pendiente

1. Actualizar la app Android y activar Avisos de mis alumnos en Entrenador.
2. Enviar varios mensajes desde un alumno, dejar el móvil en segundo plano y
   comprobar un aviso agrupado; pulsarlo y verificar conversación/MFA.
3. Repetir leyendo primero desde Trainer web: no debe llegar la push pendiente.
4. Compartir un vídeo listo; verificar aviso y acceso a su sesión. Marcarlo visto
   o corregirlo antes del envío debe excluirlo. Subida fallida o no compartida no avisa.
5. Desactivar solo mensajes: vídeos siguen activados. Desactivar avisos personales
   no apaga los profesionales. Cambiar de cuenta nunca abre el alumno de la anterior.
6. Probar descanso y regreso a primer plano sin multiplicar avisos. iPhone requiere
   todavía la configuración APNs/Apple pendiente; no se da por probado por compilar.

## Agrupación y recordatorios · 25/10/2026

En la app: **Preparador → Avisos del preparador → Recordatorios y descanso**.
La activación push sigue siendo por cuenta/dispositivo. Las preferencias horarias
son por cuenta y se guardan explícitamente con revisión: un dispositivo con datos
antiguos no sobrescribe los cambios de otro. Se conserva el consentimiento y las
credenciales anteriores de la instalación.

- Planificación y mensajes: un grupo de bandeja por preparador y tipo. Se muestra
  el nombre, novedades sin leer y total histórico; los eventos originales no se
  borran. El contador de campana representa grupos pendientes. La campana vacía
  sigue oculta. Leer toma la generación mostrada, sin absorber mensajes posteriores.
- Planificación: espera cinco minutos desde el último cambio, con tope de quince
  desde el primero pendiente. Tras un envío espera al menos treinta minutos para
  otro del mismo preparador/tipo. Treinta sesiones generan un grupo, no treinta
  push. Abrir lleva a la agenda propia y mantiene las sesiones individuales.
- Conversación: agrupa durante un minuto, con tope de dos desde el primer mensaje
  pendiente; tras enviar espera al menos cinco minutos. Los mensajes conservan su
  conversación y su lectura explícita. Formularios, pruebas y técnica mantienen
  entradas propias; su cola push común agrupa treinta segundos, tope dos minutos
  y separación mínima de cinco. No se revela contenido privado en la push.
- Recordatorios: **apagados por defecto**, mismo día o día anterior, a las **09:00**
  inicialmente. Hora editable. Uno por fecha de entrenamiento y dispositivo para
  todo el alumno, sumando sus preparadores. Solo sesiones profesionales pendientes,
  sin ejecución, con servicio/acceso vigente; completadas y canceladas se omiten.
  Haber recibido un aviso de planificación no sustituye el recordatorio elegido.
- Zona inicial **Europe/Madrid**, editable por nombre IANA, incluida Canarias/UTC.
  Se conserva la elegida aunque el teléfono viaje; no se adivina desde el UTC offset.
  Descanso inicial **22:00–08:00**, editable o desactivable. Se rechaza una hora de
  recordatorio dentro del descanso. Los mensajes/planificación se difieren hasta
  terminarlo. Si cambia mientras el worker tiene el trabajo, se aplaza sin gastar
  reintentos. Se comprueban los dos cambios de horario estacional de Madrid.

El programador existente se ejecuta cada minuto. El recordatorio tiene margen de
hasta dos horas, sin pasar la medianoche local, y no recupera horarios anteriores
al guardado de preferencias. No garantiza una alarma exacta: conexión y entrega
normal de FCM pueden retrasarla. Se revalida antes de enviar: revisión horaria,
sesiones, vínculo, instalación y lease. El recordatorio enviado no se repite por
cambiar preferencias o volver a ejecutar el programador; uno descartado antes de
enviarse puede reactivarse si vuelve a haber entrenamiento en su ventana.
Abrirlo resuelve una fecha autorizada en servidor y navega a la agenda propia;
no acepta una URL privada o destinatario suministrados en el payload.

`notice_jobs` y `job_notices` sustituyen el despacho por instalación por una cola
por instalación/cuenta/grupo, con generación y lease. Una novedad que llega durante
el envío queda pendiente para el siguiente. El protocolo anterior se conserva
para compatibilidad, sin despachar la cola antigua. La nueva bandeja usa fachadas
propias; las API planas y sus datos siguen disponibles. La migración presenta el
historial sin crear notificaciones retroactivas. Las altas nuevas de dispositivo
no vuelcan las novedades antiguas a la nueva cola. Configurar recordatorios no
concede Pro ni habilita automáticamente notificaciones del teléfono.

Validación del 25/10: análisis raíz limpio, **1.365 pruebas** correctas y una
omisión previa; **10 pruebas Node** y TypeScript 5.9.3 estricto. **42 carreras
RC/RR** en PostgreSQL17 local: inserciones, dos guardados con revisión, lectura
con mensaje posterior, evento durante envío y reclamaciones SKIP LOCKED. El
clúster mínimo prueba concurrencia; no sustituye RLS/autoría real de Dev.
`trainer_notification_policy.sql`, `trainer_student_notices.sql`,
`student_push_delivery.sql` y `student_push_scheduler.sql` pasan en Dev con
ROLLBACK. El nuevo contrato usa autoría real de treinta sesiones y dos mensajes,
reintento idempotente, lectura con generación, preferencias propias y cancelación.

Migración aplicada selectivamente y cotejada en el historial Dev. Worker v8
publicado con JWT obligatorio, petición pública 401 y manual protegida 200,
contadores a cero durante el descanso. El horario se pausa para la transición y
vuelve a activarse cada minuto. Asesores: cuatro INFO nuevos de RLS sin políticas
en tablas privadas sin concesión directa, ningún WARN nuevo. APK Firebase Dev
compilada e instalada sobre el Samsung SM-A326B conservando datos. La instalación
no acredita todavía recepción/apertura física de la nueva agrupación ni de los
recordatorios; no se envía una prueba nocturna saltándose el descanso. Apple/APNs,
badges nativos, producción y cobros siguen pendientes. No hay paquetes nuevos.

## Plan de pruebas físicas · 26/10/2026 · pendiente

Javier probará mañana en el Samsung. No se envían pruebas nocturnas ni se da por
aceptada la política por sus pruebas automáticas. Para el primer repaso bastan
los casos 1–5; 6–8 pueden hacerse después. Trainer y teléfono deben usar la misma
cuenta de alumno y el mismo entorno Dev. Usar sus sesiones de prueba, sin borrar
resultados reales ni forzar la detención de Android.

Preparación: abrir la APK instalada en el Samsung, comprobar **Preparador →
Avisos del preparador** activado y permiso concedido en Android. Revisar los avisos
anteriores y marcarlos leídos si ya están revisados. Mantener **Europe/Madrid** y
hacer las pruebas fuera de 22:00–08:00. Volver a la pantalla de inicio del teléfono
para dejar EntrenaOP en segundo plano; mantener conexión. Con la app en primer
plano se refresca la bandeja, sin alerta de sistema adicional: es intencionado.

| Caso | Acción | Resultado esperado |
| --- | --- | --- |
| 1. Lote de planificación | Desde Trainer pautar cinco sesiones seguidas para el alumno, en fechas visibles; no abrir ni leer la bandeja del teléfono mientras se agrupa. | Un aviso de planificación, no cinco; normalmente desde cinco minutos después del último cambio. La bandeja tiene un grupo y la agenda conserva las cinco sesiones. |
| 2. Mensajes | Enviar tres mensajes consecutivos desde la conversación profesional. | Un aviso de mensajes tras aproximadamente un minuto; abrir lleva a la bandeja y desde el grupo se entra en la conversación correcta con los tres mensajes. |
| 3. Ya leído | Enviar otro mensaje y marcar su grupo como leído en la app antes de que toque enviarse. | No vuelve a avisar por ese mensaje. Abrir la conversación por sí solo no equivale a marcar el grupo de avisos como leído. |
| 4. Recordatorio de hoy | Tener dos sesiones profesionales pendientes hoy. Elegir «El mismo día» y una hora de dentro de diez minutos, fuera del descanso; guardar y dejar la app en segundo plano. | Un recordatorio para hoy, no uno por sesión o preparador. Pulsarlo abre la agenda propia del día. No se exige exactitud al segundo. |
| 5. Recordatorio de mañana | Tener sesiones pendientes mañana. Elegir «El día anterior» y una hora posterior de dentro de diez minutos; guardar antes de esa hora. | Un recordatorio de entrenamiento para mañana; pulsarlo abre la fecha de mañana. La fecha no debe haber recibido ya otro recordatorio. |
| 6. Retirada antes del aviso | En una fecha que aún no haya recibido recordatorio, configurar el caso correspondiente y retirar todas sus sesiones profesionales antes de la hora elegida. | No llega el recordatorio. Una tarjeta «Retirada» visible no cuenta como entrenamiento pendiente. Si queda otra sesión válida del día, sí corresponde un recordatorio. |
| 7. Descanso | Configurar temporalmente descanso desde un minuto antes de la hora actual hasta cinco minutos después; la hora del recordatorio debe quedar fuera. Enviar mensajes y mantener la app en segundo plano. | Ninguna alerta durante el descanso; al terminar puede llegar un único aviso agrupado si sigue sin leer. Restaurar después 22:00–08:00. |
| 8. Repetición y cuentas | Tras el primer aviso de planificación, modificar varias pautas dentro de los treinta minutos siguientes. Después salir de la cuenta del alumno y entrar con otra cuenta. | No hay otra alerta inmediata por cada cambio; las novedades siguen pendientes para el siguiente envío. No deben mostrarse recursos privados del alumno anterior en la nueva cuenta. |

Los mensajes tienen separación mínima de cinco minutos y la planificación de
los mismos preparadores/tipos, treinta. No confundir esas pausas con un fallo.
Los recordatorios son uno por **fecha de entrenamiento y dispositivo**: cambiar
hora o modalidad no debe volver a notificar una fecha ya enviada. El modo «día
anterior» a las 09:00 recuerda las sesiones de mañana a las 09:00 de hoy; no resta
24 horas a una hora individual de entrenamiento.

Si falla algo, anotar caso, alumno, hora de la acción y del aviso, modalidad/zona,
si la app estaba abierta o en segundo plano, y qué abrió al pulsar. Una captura o
un vídeo corto basta; no enviar contraseñas, claves ni archivos de credenciales.
No hace falta probarlo todo mañana ni dejar el teléfono esperando por la noche.

## Actualizar iPhone y activar sus push · estado del 25/10/2026

La interfaz, agenda y avisos internos pueden llegar al iPhone recompilando main
por el circuito existente: GitHub Desktop Fetch/Pull, `bash tools/prepare_iphone_dev.sh`
y ejecutar «Runner iPhone» desde Xcode, conservando la app instalada. Eso no activa
push remotas: el preparador normal deja `PUSH_ENABLED` apagado, y la configuración
Firebase Dev actual tiene Android, no un registro Apple terminado.

Para push reales falta reactivar Apple Developer Program, registrar la app iOS
con el bundle ID comprobado, crear/configurar la clave APNs en Firebase, habilitar
las capacidades y un perfil de firma compatible, proporcionar los valores públicos
iOS del adaptador y compilar/instalar para probar permiso, recepción y apertura.
No exige publicar en App Store ni contratar ahora la cuenta: Javier conserva el
aplazamiento acordado. El contador nativo/badge es un recorrido independiente.
El SDK Firebase fijado requiere Xcode 26.2 o posterior; revisar la instalación del
Mac si aún tiene otra versión. [Preparación](IOS_DEVELOPMENT.md).
Fuentes: [configuración Flutter/APNs](https://firebase.google.com/docs/cloud-messaging/flutter/get-started),
[capacidades Apple](https://developer.apple.com/help/account/reference/supported-capabilities-ios),
[cuenta personal y programa](https://developer.apple.com/help/account/basics/about-your-developer-account),
[requisitos del SDK](https://firebase.google.com/support/release-notes/ios).

## Estado comprobado · 25/10/2026

Firebase `EntrenaOP Dev` (`entrenaop-dev`) creado en Spark, sin facturación,
Analytics ni servicios opcionales. App Android `com.entrenaOp.entrenaop`,
ID `1:861343584982:android:33a528b3742adbcdf2ef77`, emisor `861343584982`.
Configuración pública versionada en `config/firebase_dev.json`, usada también
por los recursos nativos de Gradle; no se necesita descargar google-services.json.

Transporte activado solo en Supabase Dev (`sxbxfjqgoddzhtcyhalw`). Función
`student-push` versión 8, JWT de plataforma obligatorio y hash
`ce14d4e01ce9ea92c960866bd0886c0bfad150b8de200e0335605ae6ec016f39`.
Se conservan las migraciones `20261024201618` y `20261024212322`; se añade
`20261025201351_student_push_dispatch_tickets.sql` para el programador seguro.
Se aplica después `20261025204610_trainer_notification_groups_and_reminders.sql`.
No se modifica producción ni los proyectos Firebase anteriores de Javier.

APK debug compilada con Firebase Dev e instalada conservando datos en el Samsung
SM-A326B. Javier activa los avisos, el servidor registra un Android y FCM acepta
HTTP 200 la notificación «Prueba de notificación del preparador». Javier confirma
que ese texto aparece en el teléfono. Esto acredita la primera recepción física
de transporte Android, no todos los recorridos de mensajes, lecturas o cuentas.
Apple/APNs y el indicador nativo del icono continúan pendientes.

El Cron `entrenaop-student-push-dev` está activo cada minuto; llama a
`push_private.dispatch_due_dev()` y solo hace HTTP con trabajo elegible.
Primera ejecución automática comprobada: consume el ticket, worker HTTP 200 y
`skipped=1` al no existir avisos recientes sin leer. No quedan trabajos pendientes.
La prueba de transporte directa no crea una conversación ni un aviso ficticio.

Firebase no es un requisito universal de push: iPhone admite APNs directo. El
adaptador preparado usa FCM para ambas plataformas, sin Firebase Auth, Firestore,
Storage ni Analytics. Las cuentas, permisos, historial y avisos permanecen en
Supabase. APNs directo requeriría otro adaptador de transporte, aún no construido,
sin rehacer la planificación ni los creadores.

## Activación, indicadores y pagos · acuerdo del 25/10/2026

Javier aplaza Apple Developer y las cuotas de las tiendas hasta pulir más la app.
Diciembre de 2026 es orientativo; no se fija lanzamiento ni se inicia ningún pago.
El ensayo Android puede prepararse con Firebase Spark y una instalación de prueba,
sin pagar Google Play. La prueba física iOS queda para disponer del acceso Apple
y su configuración APNs, antes de dar el recorrido por aceptado.

FCM figura sin coste en la tarifa oficial de Firebase y Spark no requiere un
método de pago. Usar solo este transporte no obliga a contratar Blaze. El backend
sigue consumiendo recursos de Supabase según su plan; no se presenta toda la
infraestructura como gratuita. Apple anuncia 99 USD anuales (importe local según
región) y Google Play, 25 USD de registro único; son cuotas de distribución
separadas del envío push. Fuentes contrastadas el 25/10/2026:
[Firebase](https://firebase.google.com/pricing),
[Apple](https://developer.apple.com/help/account/membership/program-enrollment),
[Google Play](https://support.google.com/googleplay/android-developer/answer/6112435?hl=es).

Los avisos internos y la campana no necesitan FCM. Las alertas remotas permiten
recibir novedades sin mantener la app abierta; en iOS FCM se apoya en APNs.
El número del icono iOS requiere permiso de badge y sincronización explícita
con pendientes/lecturas; cero elimina el indicador. Android ofrece un punto
asociado a notificaciones activas en launchers compatibles; algunos muestran
números y el comportamiento no es universal entre fabricantes.
[Badge iOS](https://developer.apple.com/documentation/usernotifications/unmutablenotificationcontent/badge),
[Indicadores Android](https://developer.android.com/develop/ui/views/notifications/badges).

El código actual pide permiso de badge, pero el payload del worker no envía
`aps.badge` y no hay sincronización nativa de contador/reset. Esa parte queda
pendiente, separada del transporte ya preparado. No se acredita un globo
funcionando ni recepción física por tener las dependencias instaladas.

## Alerta de clave cliente · 25/10/2026

GitHub detectó la clave Google del cliente en `config/firebase_dev.json:7`
([alerta 1](https://github.com/jchjdev/entrenaop/security/secret-scanning/1)).
Se comprobó en Google Cloud que es «Android key (auto created by Firebase)» y
mantiene las restricciones automáticas a 25 APIs de Firebase; no incluye la
API de Gemini Developer/Generative Language. La clave no está restringida a una
firma Android concreta; las restricciones por aplicación son un endurecimiento
adicional, no se presentan como configuradas. No se amplían permisos ni APIs.

La [documentación oficial](https://firebase.google.com/docs/projects/api-keys)
considera estas claves de cliente públicas por diseño cuando están restringidas
a servicios Firebase: identifican el proyecto, pero no conceden acceso de IAM ni
el envío FCM del servidor. Se contrastó el contenido completo del commit
`b3b6a797`: no contiene la clave privada real, el secreto del worker ni el JWT de
servicio del invocador; `.dart_tool/push-dev` sigue fuera de Git.

La alerta se cierra como «Won't fix», con esa justificación y el enlace oficial,
porque la distribución de esta configuración es intencionada. No se marca como
revocada ni se desactiva Secret scanning o la detección de otras credenciales.

## App y consentimiento

`PUSH_ENABLED` es falso por defecto. Sin configuración completa no se inicializa
el transporte desde Dart, no se solicita permiso ni se muestra un control vacío.
Firebase auto-init queda apagado también en Android e iOS. Los avisos internos
siguen funcionando y la campana conserva su condición de contador positivo.

La configuración del transporte solo habilita las plataformas nativas en Dev;
el ensayo configurado actualmente es Android. El servidor debe autorizarlo y declarar el mismo proyecto Firebase.
Solo entonces aparece «Avisos del preparador» en Preparador. Activarlo solicita
permiso y conserva una elección independiente por cuenta. El permiso del teléfono
no activa notificaciones para otra cuenta. Desactivar/salir revoca la asociación
propia e intenta invalidar también el registro del proveedor.

Las transiciones se serializan y comprueban la cuenta tras cada espera. El alta
normal fija el bearer y `p_expected_owner`; la revocación al salir fija el bearer
anterior y exige continuidad de la instalación. Una operación antigua no puede
reasociar ni desactivar una asociación posterior de B. Una respuesta perdida se
reconcilia consultando la asociación actual, sin duplicar dispositivos.

FlutterFire 17 usa FID mediante `register`, `onRegistered` y `unregister`.
Los manifiestos habilitan explícitamente `firebase_messaging_installation_id_enabled`
y `FirebaseMessagingInstallationIdEnabled`, sin activar auto-init.
En el primer registro, el consentimiento precede a habilitar auto-init. Solo
después se espera APNs (hasta diez segundos); esperar con auto-init apagado
bloquearía el primer registro con este SDK. Tres regresiones con SDK simulado
cubren esa secuencia, el tiempo de espera y Android sin consulta APNs.
El campo interno `token` representa esa dirección de entrega, no un permiso.
En primer plano se refrescan los avisos; un evento durante una lectura fuerza
un snapshot posterior. Pulsar una alerta abre los avisos de la cuenta conectada,
sin marcar leído ni aceptar una URL/identificador privado del payload. Los
recursos siguen resolviéndose mediante sus permisos habituales.

## Cola, permisos y coste

Las cuatro tablas de `push_private` tienen RLS y ningún acceso directo del
cliente. El esquema se incluye en el alcance de copias cifradas de Dev; el
control de esquemas de la primera CI detectó y corrigió esa omisión. Solo las
RPC propias aceptan identidades de alumno. Reclamar, preparar,
confirmar y retirar direcciones inválidas son operaciones exclusivas del worker.
Las asociaciones incluyen un secreto aleatorio de instalación, almacenado como
hash en servidor, y una versión opaca para impedir altas/bajas antiguas.
Límites técnicos: cinco dispositivos activos, veinte registros conservados por
cuenta y treinta cambios de asociación por hora. Recibir una instalación de
otra cuenta también consume un registro conservado del destino. La regresión
reprodujo el salto de ese límite sobre la versión inicial; pasa tras la ampliación
transaccional aplicada en Dev, sin mover datos al rechazarse el alta. No amplían Pro ni cuotas de
creación del alumno. La eliminación del perfil conserva la cascada de estos datos.

La cola mantiene una fila por dispositivo y reúne novedades durante cinco
segundos. Un aviso nuevo avanza su generación incluso durante otro envío.
`SKIP LOCKED`, lease de dos minutos y confirmación de la generación reclamada
evitan dobles reclamaciones y pérdidas de novedades. Un lease caducado no puede
acusar entrega. El worker procesa como máximo cinco trabajos por llamada,
revalida asociación, acceso activo y avisos recientes sin leer antes de enviar,
y limita reintentos a ocho con espera creciente. Un FID inválido se retira con
CAS, sin desactivar un registro posterior.

El payload es únicamente EntrenaOP / «Tienes novedades pendientes.» y el tipo
cerrado `student_notices`. No incluye nombres, mensajes, resultados, respuestas,
vídeos, URLs ni cuentas. APNs/Android agrupan las alertas. El transporte es al
menos una vez: si se pierde la confirmación tras enviar puede repetirse una
alerta, y una notificación ya encolada por el sistema operativo no se puede
retirar retroactivamente. Esto no concede acceso a datos de otra cuenta.

El worker exige JWT de plataforma, la credencial de servicio y un secreto de
worker de 64 caracteres hexadecimales. La revisión automática rechazó publicar
con JWT desactivado mientras faltaba configurar el secreto; se mantuvo la barrera
y se añadió comprobación explícita de la credencial de servicio. Los tokens de
usuario no pueden disparar envíos. La credencial Firebase solo existe en secretos
del servidor; OAuth se firma con WebCrypto. Respuestas y registros no exponen
direcciones de entrega, credenciales ni cuerpos privados.

## Configuración y aceptación

1. **Android configurado:** `flutter run --dart-define-from-file=config/firebase_dev.json`
   o «EntrenaOP Avisos · Android Dev» en VS Code. Los valores son identificadores
   públicos del cliente, no credenciales administrativas. La ejecución habitual
   conserva `PUSH_ENABLED=false`. iOS no se activa por este archivo Android.
2. **Servidor configurado:** `FCM_SERVICE_ACCOUNT_JSON`, `STUDENT_PUSH_WORKER_SECRET`,
   `STUDENT_PUSH_CALLER_KEY`, `STUDENT_PUSH_SCHEDULER_JWT` y
   `STUDENT_PUSH_ENABLED=true` solo en secretos Dev. La invocación manual exige
   la clave estable y el secreto adicional; el worker consulta la base de datos
   con su clave interna inyectada. No se supone que ambas claves sean idénticas.
3. **Programador configurado:** el JWT público del proyecto está en Vault como
   `student_push_dev_public_jwt`; la migración genera un ticket aleatorio de
   256 bits, guarda solo su hash y limita su uso a 55 segundos. El worker exige
   el JWT configurado y consume el ticket mediante una RPC exclusiva de servicio,
   antes de reclamar como máximo cinco trabajos. Reutilizar, caducar o alterar
   el ticket devuelve 401. No admite destinatarios ni contenido en la invocación.
   La configuración operativa está en
   `supabase/operations/student_push_dev_schedule.sql`, con destino Dev explícito.
   El primer horario provisional se pausó antes de tener dispositivos; ningún
   secreto permanente se depositó en la cola HTTP. Los secretos de Vault del
   montaje provisional quedan privados y sin referencia en el horario vigente.
4. **Cuenta técnica:** `entrenaop-push-dev@entrenaop-dev.iam.gserviceaccount.com`,
   solo rol `roles/firebasecloudmessaging.admin` en este Firebase. Clave RSA
   generada localmente y certificado público registrado con confirmación de
   Javier. Caduca el 25/10/2027; renovar antes del vencimiento. La parte privada
   permanece fuera de Git y de la app. No reutiliza Firebase Admin SDK ni claves
   de sus proyectos antiguos.
5. **Aceptación pendiente:** evento real desde Trainer → cola → alerta → apertura
   en la cuenta correcta; permiso denegado, app cerrada, primer plano, cambio A→B,
   baja, renovación de registro, falta de red y reintento. Los contratos de
   aislamiento están probados; no sustituye esas comprobaciones físicas.
6. **Apple pendiente:** con Apple Developer, habilitar capacidad/perfil Push y
   configurar APNs. No se añaden ahora entitlements que rompan la firma gratuita.
   El contador/reset del icono necesita implementación explícita separada.

No se necesitan publicación ni pago de Google Play para este ensayo Android.
Los cobros de EntrenaOP/entrenador/alumno siguen fuera de este tramo.

### Validación de esta activación

Análisis raíz limpio y batería completa: 1.353 pruebas correctas, una omisión
previa. APK debug compilada con los valores reales, recursos Firebase nativos
comprobados e instalación sobre la existente correcta. Ocho pruebas Node del
worker y comprobación TypeScript 5.9.3 estricta correctas. La regresión de claves
internas/estables falla con la conexión anterior y pasa con el ajuste.

`student_push_delivery.sql` y `student_push_scheduler.sql` pasan en Dev con
ROLLBACK, también con el Android real registrado. El primero aísla temporalmente
los trabajos ya existentes y restaura sus fechas al terminar; no consume avisos
reales durante la prueba. El segundo comprueba permisos, caducidad, uso único,
contenido de encabezados y ausencia de despachos duplicados/apagados. Aplicación
selectiva de la migración de tickets, sin ejecutar la migración Garmin ajena.

El asesor de seguridad mantiene la información esperada de RLS sin políticas
en tablas privadas; no hay nuevos permisos de ejecución de estos trabajadores
para anon/authenticated. Las llamadas sin credenciales o sin secreto devuelven
401; la llamada manual correcta devuelve 200 con contadores. El horario real
acredita JWT público + ticket + RPC + cola sin exponer credenciales permanentes.

## Evidencia de la preparación del 24/10/2026 y fuentes

Análisis raíz limpio y 1.349 pruebas completas correctas, con una omisión
previa; incluyen las tres regresiones APNs. APK debug recompilada después
de esos ajustes, con envío apagado.
Nueve pruebas del coordinador/almacenamiento y tres de arranque nativo correctas,
más la regresión del refresco durante una lectura; las 29 pruebas previas de
push/navegación/hub también pasaron. Cinco pruebas
Node ejecutan autenticación, revalidación, reintentos, OAuth RSA y payload FID
contra proveedores simulados. Tipos TypeScript estrictos correctos; el workflow
`student-push.yml` repite esas pruebas sin secretos, envíos ni despliegues.
El [workflow de push](https://github.com/jchjdev/entrenaop/actions/runs/40133604374)
acredita esas pruebas y tipos en GitHub. El [ensayo de copias](https://github.com/jchjdev/entrenaop/actions/runs/40133604352)
pasa sus controles y restauración aislada con el nuevo alcance; no ejecuta una
operación sobre Dev por ser un evento push. Las 36 pruebas Python de publicación
y operaciones también pasan localmente. El contrato SQL sobre Dev termina con
`ROLLBACK`.
El ensayo PostgreSQL17 local acredita 66 carreras RC/RR de cambios de cuenta,
altas/bajas, cascada de instalación, avisos durante envío y reclamaciones
concurrentes, repetidas después de ampliar el límite. Usa tablas mínimas y no
acredita todo el borrado de cuenta.

APK debug compilada con las dependencias fijadas `firebase_core 5.1.0` y
`firebase_messaging 17.0.1`, sin actualizar paquetes anteriores. Sus podspecs
declaran iOS 15; Android compila con el mínimo actual de Flutter. El SDK Apple
Firebase 13.1.1 requiere Xcode 26.2/Swift 6.2.3: las primeras comprobaciones
iOS de CI rechazaron Xcode 16.4, predeterminado en macos-15. Los dos workflows
iOS seleccionan explícitamente el Xcode 26.2 ya instalado, sin otra acción ni
modificar la firma. La [CI de Release](https://github.com/jchjdev/entrenaop/actions/runs/40133604391)
y la [CI de simulador y ensayo](https://github.com/jchjdev/entrenaop/actions/runs/40133604358)
pasan sobre `46351527`, con el SDK integrado y envío desactivado. La corrección
Dart posterior del orden APNs tiene las tres regresiones anteriores y batería
raíz; no es una recepción física ni otra compilación iOS sobre ese ajuste.
La recepción física y la instalación firmada siguen pendientes de configuración.
Ensayo Android con identificadores públicos ficticios: genera los cuatro recursos
nativos esperados y compila; después se recompila sin defines, restaurando la APK
habitual con envío apagado. El contrato anterior de avisos internos sigue pasando
en Dev y todas las migraciones locales/remotas coinciden. Advisors sin nuevos
WARN respecto a la línea base; las cuatro tablas privadas solo añaden INFO de RLS
sin políticas de acceso directo, deliberadamente revocado.

Fuentes primarias consultadas:

- [Configuración Flutter/FCM](https://firebase.google.com/docs/cloud-messaging/flutter/get-started).
- [Registro FID y mantenimiento](https://firebase.google.com/docs/cloud-messaging/manage-tokens).
- [Contrato HTTP de mensajes](https://firebase.google.com/docs/reference/fcm/rest/v1/projects.messages).
- [Recursos nativos Android](https://firebase.google.com/docs/android/google-services-plugin-and-file).
- [Requisitos del SDK Apple Firebase](https://firebase.google.com/support/release-notes/ios).
- [Xcode disponible en macos-15](https://github.com/actions/runner-images/blob/main/images/macos/macos-15-Readme.md).
- [Cambios FlutterFire 17](https://pub.dev/packages/firebase_messaging/changelog).
