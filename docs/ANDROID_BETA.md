# Beta Android privada

**Actualización del 30/10/2026 · beta.5+3 instalada:** tras la petición expresa
de Javier durante sus pruebas, se actualiza el mismo Samsung A13 con el acceso
directo a retirada de sesiones desde el menú de la agenda (`c1c538b6`). Variante
debug compatible con su firma antigua, Supabase/Firebase Dev, firma y versión
verificadas antes del reemplazo. Android confirma instalación correcta y
arranque nativo, conservando la fecha de primera instalación; no se desinstala
ni se borran datos. APK `EntrenaOP-1.0.0-beta.5-3-legacy-debug.apk`, SHA-256
`bb150b1ef5c54c6a9ee6b16da3142423cf7465fca1baa4ddad18724059751cea`.
El código está publicado en main para compilar iOS; esta instalación no acredita
el recorrido físico en iPhone.

**Instalación del 30/10/2026 · planificación móvil TRN-048:** a petición de
Javier se compila `1.0.0-beta.4+3`, desde `5b6fca4a`, con Supabase/Firebase Dev.
La release conserva la firma beta estable y supera su verificación, pero el
Samsung A13 (SM-A137F, Android 12) tenía `1.0.0+1` firmada con la antigua clave
debug. Android rechaza correctamente reemplazarla por la release de otra firma.

Se comprueba que la clave debug local coincide con la instalación antigua y se
compila una variante **debug de compatibilidad**, sin cambiar la firma de
distribución ni su configuración. Esta variante se instala mediante reemplazo:
Android confirma éxito, `beta.4+3` y la misma fecha de primera instalación del
09/10. No se desinstala ni se borran datos. Arranque nativo correcto y proceso
activo, sin errores de arranque detectados; los recorridos funcionales en ese
teléfono quedan para la prueba de Javier.

La APK instalada es `EntrenaOP-1.0.0-beta.4-3-legacy-debug.apk`, SHA-256
`05911e1ad4d0719b28bbb0345a921e07b29fe0b7c8529f507fb116ce93f45e91`.
No equivale a una release firmada con la identidad beta estable. Las siguientes
actualizaciones de este A13 deben contemplar esa firma antigua; esta excepción
no modifica el circuito de distribución estable ni acredita push o enlaces en
este dispositivo.

**Actualización del 29/10/2026 · beta.3+3 instalada:** Javier pide preparar e
instalar esta APK para cerrar la prueba de avisos profesionales. La release Dev
`560d9021` conserva firma, sesión y datos de beta.2 mediante reemplazo, con
identidad y permisos releídos. Mensajes agrupados, supresión tras lectura web y
apertura de conversación en caliente y técnica sin proceso previo comprobados en
Samsung. El receptor de invitaciones ya está incluido, pero su aceptación física
por enlace sigue pendiente. [Evidencia y huella](TRAINER_PUSH_NOTIFICATIONS_2026_10_24.md#cierre-del-recorrido-android--29102026).

**TRN-038 · 28/10/2026:** el código incorpora recepción nativa de enlaces de
invitación y aceptación ligada al correo confirmado. No se genera otra APK por
este ajuste: la beta.2 anterior no incorpora el nuevo receptor. Javier compila
las actualizaciones habituales; las APK se prepararán para cambios importantes
o petición expresa, conservando las comprobaciones automáticas.

La beta del deportista utiliza Supabase y Firebase de desarrollo. Se distribuye
como APK release firmada, sin publicar en Google Play ni activar cobros reales.
La primera versión de este circuito es **1.0.0-beta.1, compilación 3**.
La APK declara Android 7.0/API 24 como mínimo y target API 36.

## Frecuencia de preparación · acuerdo del 28/10/2026

Javier acepta la APK beta.2 ya preparada para probar los avisos profesionales.
A partir de aquí, se preparan nuevas APK para actualizaciones importantes o
cuando lo solicite expresamente. Las pruebas manuales habituales en su iPhone
y Android las realiza él con su circuito de desarrollo. Los ajustes pequeños
no disparan por sí solos compilación, firma, instalación ni distribución de APK.
Se mantienen análisis, pruebas automáticas y validaciones necesarias del alcance;
el acuerdo cambia la frecuencia de empaquetado, no los controles del repositorio.

## Firma y actualizaciones

Identificador Android conservado: `com.entrenaOp.entrenaop`. El certificado
público estable está fijado por SHA-256 en
`config/android_beta_certificate.sha256`. La herramienta rechaza otra firma.

En Windows, el material privado se conserva en
`%USERPROFILE%/.android/entrenaop-beta-signing/`: `entrenaop-beta.p12`,
`key.properties` y el certificado público `certificate.der`. La carpeta tiene
acceso restringido al usuario que la creó. No distribuir el almacén ni las
contraseñas junto con la APK. Hacer una copia privada cifrada en otra ubicación;
la carpeta local por sí sola no es una copia de seguridad independiente.

Para actualizar, reutilizar el mismo certificado e incrementar la compilación
en `pubspec.yaml`, que mantiene versión numérica para iOS. El helper añade
`-beta.1` solo al nombre Android; `-BetaNumber 2` selecciona la siguiente etiqueta.
No regenerar la clave al cambiar de ordenador. La identidad
de esta beta no decide todavía la firma ni la distribución de producción.

Las instalaciones antiguas firmadas con debug no admiten esta actualización
directamente. No desinstalar una copia anterior sin revisar primero sus datos
locales y borradores. Una primera instalación del compañero no tiene ese conflicto.

Gradle lee `ENTRENAOP_ANDROID_SIGNING_PROPERTIES` o `android/key.properties`.
Este último y los almacenes Android ya están excluidos de Git. Una tarea release
sin configuración privada falla; no vuelve a la clave debug. Debug conserva su
circuito habitual sin exigir este almacén.

## Compilar y verificar

Desde la raíz, con Flutter/Android SDK y la clave privada disponibles:

```powershell
./tools/build_android_beta.ps1
```

En otro equipo puede indicarse la configuración privada existente:

```powershell
./tools/build_android_beta.ps1 -SigningPropertiesPath 'RUTA_PRIVADA/key.properties'
```

La herramienta usa `tools/run_app.dart` para registrar revisión, fecha y estado
de las fuentes; compila release con `config/firebase_dev.json`; comprueba la
firma con `apksigner`, el paquete, ausencia de debuggable, permisos de Internet y
notificaciones, y recursos nativos de Firebase Dev. Conserva la APK y un manifiesto
JSON con versión, entorno, revisión y huellas en `build/android-beta/`. El APK
incluye las arquitecturas que genera Flutter por defecto, sin exigir conocer
el procesador del teléfono para compartirlo.

No compilar mientras otro proceso modifica las fuentes del deportista. Si Git
cambia durante la build, la herramienta exige repetirla para no atribuirla a una
revisión equivocada. Los cambios de otras áreas permanecen separados.

## Instalar y probar

1. Enviar únicamente la APK como documento por WhatsApp. Abrirla en Android y
   autorizar la instalación desde esa fuente cuando el sistema lo solicite.
   Mantener Play Protect activo.
2. Acceder con la misma cuenta que en Trainer. La APK conserva sesión, pero
   necesita red para los recorridos del servidor; no depende del PC de Javier.
3. En Perfil, comprobar versión, compilación, entorno Dev y revisión.
4. En Preparador, activar Avisos del preparador y conceder permiso Android.
   Los recordatorios son optativos y se guardan en Recordatorios y descanso.
5. Completar una sesión, interrumpir/retomar otra y consultar resultados e
   historial. Comprobar sonido, vibración y comportamiento con pantalla bloqueada.
6. Probar mensajes y planificación desde otra cuenta relacionada. «Para mí»
   no genera conversación ni avisos de autoplanificación. La recepción agrupada,
   recordatorios y apertura requieren su aceptación física propia.

[Política y guion de avisos](TRAINER_PUSH_NOTIFICATIONS_2026_10_24.md).

## Entrenamiento propio y fēnix 7 Solar

Javier concreta que el compañero usará principalmente **carrera** y confirma
mantener esta entrega. La primera prueba se centra en crear/asignarse una carrera,
conectar Garmin una vez y sincronizar con el reloj. Por su poca soltura
informática, las instrucciones de entrega deben ser breves y evitar añadir
configuración de Connect IQ o pruebas de fuerza a este recorrido. La APK se
conserva; no se da por acreditada la recepción física en su reloj.

Javier confirma este reloj para el compañero. El recorrido propuesto es
Trainer → Para mí → crear y asignarse una sesión con fecha → app del deportista
→ Perfil → Conexión con Garmin → autorizar su propia cuenta Garmin → activar
Sincronización automática → sincronizar Garmin Connect con su reloj.
Guardar una receta sin asignarla no la envía. El automático considera hoy y
los próximos catorce días; el envío manual conserva su acceso propio.

La consulta de Dev del 27/10 confirma acceso profesional vigente, ficha propia
creada y permiso efectivo para Garmin de la cuenta indicada por Javier, sin Pro
personal. No se conceden derechos ni se conecta Garmin en nombre del compañero.

El fēnix 7 Solar admite entrenamientos desde Connect, pero la llegada de una
receta EntrenaOP debe comprobarse en ese dispositivo. Carrera y fuerza usan
las capacidades del adaptador actual: no se garantiza cualquier formato del
editor. En fuerza, los ejercicios sin equivalencia nativa conservan nombre y
notas en la descripción; el título del paso puede aparecer como «Ir».
Superseries, circuitos, EMOM y AMRAP no se habilitan por instalar esta APK.

La app complementaria Connect IQ actual solo incluye `fenix847mm`; su beta Store
solo es visible para la cuenta Garmin que la subió. No sirve todavía como
instalación por enlace para este fēnix 7. Ampliar ese soporte/distribución es un
recorrido posterior; no condiciona el transporte existente por Training API.

[Contrato de Garmin](DEVICE_GARMIN_TRAINING.md),
[sincronización](DEVICE_GARMIN_AUTOMATIC_SYNC.md) y
[planificación propia](TRAINER_SELF_TRAINING.md).
Compatibilidad contrastada con el
[manual de fēnix 7 Standard/Solar/Pro](https://www8.garmin.com/manuals/webhelp/GUID-C001C335-A8EC-4A41-AB0E-BAC434259F92/EN-AU/GUID-3AA7B50B-EBE5-4A29-A15A-316849BA9BDB.html).

## Validación del 27/10/2026

Análisis raíz sin incidencias y batería completa: **1.381 pruebas correctas y
una omisión existente**. Nueve comprobaciones de identidad de firma correctas,
incluidos los formatos de Build Tools 36/37 y rechazo de otra firma/múltiples
firmantes. La herramienta y el grafo real de tareas Gradle rechazan una
configuración privada ausente. APK release compilada y verificada: un firmante
con el certificado fijado, paquete/versión correctos, sin debuggable, permisos y
recursos Firebase Dev presentes. El JSON junto al archivo conserva la huella y
la revisión de cada compilación.

Servidor push Dev habilitado para `entrenaop-dev` y programador activo cada
minuto, comprobados sin escrituras. La build avisa de la futura migración KGP de
`firebase_core` y de diferencias entre versiones de herramientas SDK; no impiden
esta compilación y no se actualizan paquetes como parte del piloto. Instalación
en el teléfono del compañero, push reales de esta build y llegada a su fēnix 7
pendientes de aceptación física. No había teléfono ni emulador disponibles para
acreditar un arranque nativo nuevo.
