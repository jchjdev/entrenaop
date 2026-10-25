# Avisos push del alumno · TRN-029 · 24/10/2026

## Estado comprobado · 25/10/2026

Firebase `EntrenaOP Dev` (`entrenaop-dev`) creado en Spark, sin facturación,
Analytics ni servicios opcionales. App Android `com.entrenaOp.entrenaop`,
ID `1:861343584982:android:33a528b3742adbcdf2ef77`, emisor `861343584982`.
Configuración pública versionada en `config/firebase_dev.json`, usada también
por los recursos nativos de Gradle; no se necesita descargar google-services.json.

Transporte activado solo en Supabase Dev (`sxbxfjqgoddzhtcyhalw`). Función
`student-push` versión 7, JWT de plataforma obligatorio y hash
`8f1358b2ad69815c0a0d81a4bae74911819e46404005a6a0ddafd0c14a704c18`.
Se conservan las migraciones `20261024201618` y `20261024212322`; se añade
`20261025201351_student_push_dispatch_tickets.sql` para el programador seguro.
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
