# Avisos push del alumno · TRN-029 · 24/10/2026

## Estado comprobado

Preparación implementada en la app y Supabase Dev (`sxbxfjqgoddzhtcyhalw`),
con envío desactivado. Migración `20261024201618_student_push_delivery.sql`
aplicada, ampliada por `20261024212322_student_push_retained_transfer_limit.sql`;
función `student-push` versión 1, JWT de plataforma activado y hash
`c002ce33a737df171a1cdef64df8be5bfcae6ae27794591d1d6c14e7846fd21f`.
Sin proyecto Firebase configurado, dispositivos, trabajos pendientes ni Cron.
La llamada pública sin credenciales devuelve HTTP 401. No acredita recepción
real, configuración APNs ni instalación iOS. CI acredita compilación iOS
Release y simulador sin firmar, con push desactivada; Javier instala desde Xcode.

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

La configuración preparada solo habilita el transporte nativo en Dev, iOS y
Android. El servidor debe autorizarlo y declarar el mismo proyecto Firebase.
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

## Activación pendiente

1. Crear/configurar un proyecto Firebase de Dev y sus apps Android/iOS con los
   identificadores reales del producto. Fijar sus identificadores públicos en
   `PUSH_FIREBASE_PROJECT_ID`, `PUSH_FIREBASE_SENDER_ID`,
   `PUSH_FIREBASE_ANDROID_APP_ID`, `PUSH_FIREBASE_ANDROID_API_KEY`,
   `PUSH_FIREBASE_IOS_APP_ID` y `PUSH_FIREBASE_IOS_API_KEY`.
2. Compilar con esos valores y `PUSH_ENABLED=true`, `APP_ENV=development`.
   Android genera los recursos nativos de Firebase desde los mismos defines:
   el SDK puede arrancar y recibir alertas con Flutter cerrado. No requiere
   guardar otra copia de configuración en Google Services JSON. La build normal
   carece de esos recursos y sigue sin activar push. iOS configura opciones desde
   Dart y prepara el delegado de notificaciones antes de inicializar Flutter.
3. Con Apple Developer de pago, habilitar la capacidad Push Notifications y su
   perfil/entitlement apropiado en Xcode, y configurar la clave APNs en Firebase.
   No se añade ahora un entitlement que rompa la firma personal gratuita.
4. Configurar solo en secretos de la función `FCM_SERVICE_ACCOUNT_JSON`,
   `STUDENT_PUSH_WORKER_SECRET` y `STUDENT_PUSH_ENABLED=true`. La cuenta de servicio
   necesita el permiso de envío de Cloud Messaging. Comprobar el proyecto antes
   de habilitar `push_private.settings` y nunca introducir su clave en la app.
5. Programar la invocación del worker desde servidor con ambas credenciales
   guardadas en Vault/secretos. No hay todavía un Cron que envíe trabajo real.
6. Probar en dispositivos: permiso denegado/aceptado, primer plano, segundo plano,
   app cerrada, pulsación, cambio A→B, baja, FID renovado, falta de red y reintento.
   Comprobar recepción antes de presentar la función como activada.

No se necesitan publicación ni pago de Google Play para el ensayo Android.
Los cobros de EntrenaOP/entrenador/alumno siguen fuera de este tramo.

## Evidencia y fuentes

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
