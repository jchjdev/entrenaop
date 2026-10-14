# Desarrollo iOS en macOS

## Herramientas y configuración

- Usar Flutter **3.47.5** con Dart **3.13.4**, la versión contrastada al
  trasladar el proyecto de Windows al Mac. `pubspec.lock` conserva las versiones
  de los paquetes; preparar el proyecto con `flutter pub get --enforce-lockfile`.
- Xcode debe estar seleccionado con `xcode-select`, tener completada su
  preparación inicial y disponer de la plataforma iOS requerida. Consultar
  `flutter doctor -v` y `xcodebuild -showdestinations -workspace
  ios/Runner.xcworkspace -scheme Runner` si no aparece ningún destino.
- La aplicación requiere **iOS 15 o posterior**, mínimo del SDK actual. El
  proyecto usa `UIScene` y registra los plugins al inicializar el motor implícito.
- Los plugins nativos actuales usan **Swift Package Manager**, integrado por
  Flutter en `Runner`. Los paquetes y frameworks generados dentro de
  `ios/Flutter/ephemeral/` no se versionan. No es necesario crear un Podfile.
  CocoaPods 1.16.2 queda disponible si un plugin futuro lo requiere.
- Mantener `FlutterDeepLinkingEnabled=false` y el esquema `es.entrenaop`:
  el SDK de Supabase recibe los callbacks mediante `app_links`, que admite
  `UIScene`. El callback configurado se define en `AuthRedirect`.

No hace falta configurar un equipo de firma para ejecutar en un simulador.
La instalación en dispositivos físicos requiere la firma descrita más abajo.

## Ejecutar con Supabase de desarrollo

Desde la raíz:

```sh
flutter pub get --enforce-lockfile
flutter devices
flutter run -d <identificador-del-simulador> --dart-define=APP_ENV=development
```

La configuración por defecto de `AppConfig` apunta a `entrenaop-dev`
(`sxbxfjqgoddzhtcyhalw`). No inyectar parámetros de producción para estas pruebas.
En VS Code, seleccionar el simulador y usar
`EntrenaOP App · dispositivo seleccionado`. El SDK elegido por VS Code debe
coincidir con el de la terminal (`flutter --version`).

Para compilar sin arrancar el simulador:

```sh
flutter build ios --simulator --debug --dart-define=APP_ENV=development
```

## Instalar en un iPhone físico

1. Conectar el iPhone al Mac, desbloquearlo y confiar en el ordenador. El modo
   desarrollador debe estar activado en Ajustes → Privacidad y seguridad.
2. Completar la licencia y preparación inicial de Xcode. Añadir la cuenta Apple
   en Xcode → Settings → Accounts.
3. Abrir `ios/Runner.xcworkspace`, seleccionar el target Runner y revisar
   Signing & Capabilities: firma automática y el equipo personal de Javier.
   El identificador de equipo del proyecto no es una credencial; los
   certificados, claves privadas y perfiles permanecen fuera del repositorio.
4. Preparar las dependencias con el lockfile y comprobar `flutter devices`.

Para instalar una versión que pueda abrirse desde el icono sin el depurador ni
el Mac conectado, usar release **con el entorno de desarrollo explícito**:

```sh
flutter pub get --enforce-lockfile
flutter run --release -d <identificador-del-iphone> --dart-define=APP_ENV=development
```

Si aparece la pantalla negra que indica que las apps Flutter debug solo pueden
arrancar desde las herramientas, la app instalada sigue siendo debug. La
instalación permanece en el teléfono, pero hay que sustituirla por Release para
abrirla sin depurador. Lanzar después la configuración de compras debug vuelve
a sustituir la misma app: Git y la selección de modo no actualizan por sí solos
la versión instalada. Reinstalar con el mismo identificador conserva normalmente
los datos locales; no desinstalar para cambiar de modo. El acceso Pro se consulta
en Supabase también en Release; la compra Test Store solo se prueba en debug.

Para trasladar cambios de Windows al iPhone: guardar y subir a GitHub desde
Windows; en GitHub Desktop del Mac, usar Fetch origin y Pull origin; finalmente,
reinstalar en Release con `APP_ENV=development`. Si la subida de Windows se
rechaza porque el remoto tiene commits del Mac, integrar allí `origin/main`, conservar ambos trabajos y
subir sin force push. Un commit que solo existe en Windows todavía no se puede
descargar desde el Mac.

Si macOS solicita acceso de `codesign` al llavero, Javier introduce la contraseña
directamente en el Mac. Un rechazo de acceso a la clave puede producir
`errSecInternalComponent`; no copiar contraseñas al chat ni modificar los
controles del llavero para evitar el aviso. La ejecución desde Xcode permite
completar los avisos interactivos: seleccionar temporalmente Release en
Product → Scheme → Edit Scheme → Run y desactivar Debug executable. Después,
devolver el esquema compartido a Debug para conservar el flujo de desarrollo.

El equipo personal gratuito de Apple tiene perfiles de siete días: renovar la
instalación desde el Mac cuando caduque. No se necesita publicar en App Store
para esta prueba. Si el iPhone solicita confiar en el desarrollador, hacerlo
en Ajustes → General → VPN y gestión de dispositivos.

## Compras de prueba en iPhone · RevenueCat Test Store

Las compras de COM-013/014 se prueban en **móvil debug con Supabase Dev**.
La versión Release instalada para abrir desde el icono mantiene estas compras
deshabilitadas. Test Store de RevenueCat no equivale a App Store ni procesa
cobros reales; la integración Flutter requiere una compilación debug para esa
clave. [Restricciones oficiales de Test Store](https://www.revenuecat.com/docs/test-and-launch/sandbox/test-store).

Git transporta el código, `pubspec.lock` y la configuración de lanzamiento de
VS Code, pero `.gitignore` excluye `.env.*`. Hay que copiar también el archivo
local `.env.revenuecat-dev.json` de Windows a la raíz del proyecto del Mac.
Contiene `APP_ENV=development` y `REVENUECAT_TEST_API_KEY`, la clave pública
de SDK de Test Store; no debe contener claves privadas del proveedor ni la
clave de servicio de Supabase. No guardar el archivo real en Git.

Si la consola de Windows está conectada al Mac por SSH, usar `exit` o abrir
otra PowerShell **de Windows** antes de copiar. La ruta `E:\Dev\Flutter\...`
solo existe en Windows. En la configuración de Javier:

```powershell
scp "E:\Dev\Flutter\entrenaop\.env.revenuecat-dev.json" jvrmini@javiers-mac-mini.local:/Users/jvrmini/development/projects/entrenaop/.env.revenuecat-dev.json
```

Usar el mismo destino SSH que permite entrar en el Mac. Una conexión
Windows → Mac no permite al Mac leer automáticamente los archivos de Windows.
Conservar el punto inicial del nombre y la extensión `.json`, sin `.txt`.
Finder oculta los archivos con punto: `⌘⇧.` permite verlos.

Después de incorporar el código y copiar el archivo:

1. En el Mac, ejecutar `flutter pub get --enforce-lockfile` desde la raíz.
2. Seleccionar el **iPhone físico**, no el simulador, en la barra de VS Code.
3. Elegir **EntrenaOP Compras · móvil debug Dev** y pulsar F5.
4. Mantener el iPhone desbloqueado durante la instalación y aceptar, si aparece,
   el acceso a red local necesario para conectar el depurador de Flutter.
5. Abrir Perfil → Mi suscripción para comprobar el catálogo y acceso propio.
   Una cuenta con Pro gratuito puede ocultar la transición Free → compra.

La configuración de compras selecciona, **solo en macOS**, el arranque a través
de Xcode mediante `FLUTTER_LLDB_DEBUGGING=false`. Es una opción soportada por
Flutter 3.47.5; no cambia Windows, el modo debug ni la firma. El arranque directo
con LLDB se cerró antes de entrar en Flutter en la comprobación IOS-004.

Si aparece `Timed out waiting for CONFIGURATION_BUILD_DIR to update`, detener
la sesión, cerrar Xcode y volver a pulsar F5. Flutter lo abre de nuevo con la
configuración generada. Esta secuencia permitió completar el arranque comprobado;
no se fijan rutas de salida a mano en el proyecto ni se cambia a Release.
Si la pila de llamadas muestra un hilo detenido **en entry**, usar Continuar
para reanudarlo; comprobar también el hilo auxiliar `_compute` si aparece pausado.
Esto es distinto de una excepción de la aplicación, que debe investigarse.

La primera compilación resuelve y descarga el SDK nativo mediante Swift Package
Manager; puede tardar varios minutos. No crear un Podfile ni actualizar paquetes
para resolver una descarga pendiente. Detener y lanzar de nuevo incorpora el
plugin; hot reload por sí solo no lo registra. No cambiar a Release ni reutilizar
el procedimiento anterior de instalación sin depurador para probar Test Store.
[Contrato de compras y aceptación pendiente](PRO_LAUNCH.md).

## Verificación

El **08/10/2026** se comprobó en este Mac:

- Flutter 3.47.5/Dart 3.13.4, Xcode 26.2 (17C52) y CocoaPods 1.16.2.
- Instalación de componentes adicionales de Xcode con autorización
  administrativa e instalación del runtime iOS 26.3.1 (23D8133), seleccionado
  por `xcodebuild -downloadPlatform iOS`.
- Compilación y arranque en iPhone 17 Pro con `APP_ENV=development`:
  pantalla de acceso visible e inicialización de Supabase completada.
- Respuesta correcta de `/auth/v1/health` en Supabase de desarrollo.
- `flutter analyze` sin incidencias y **591 pruebas correctas**; una prueba
  exclusiva de web omitida en la ejecución nativa.
- Los `pubspec` y lockfiles de la app y del panel permanecen sin cambios.

La terminal y VS Code de este Mac apuntan al SDK nuevo instalado en una carpeta
separada. Se conserva el SDK antiguo y una copia de los ajustes anteriores.

Antes de cerrar cambios iOS, ejecutar `flutter analyze` y la batería de pruebas
de la raíz, además de compilar y comprobar el arranque en el simulador. En una
copia nueva, preparar también las dependencias de `admin_app/` con su lockfile:
el análisis desde la raíz incluye ese proyecto anidado.

El arranque no acredita por sí solo el login, un correo real de recuperación,
la reproducción de vídeo ni la selección de fotografías. Estos recorridos
requieren una comprobación funcional específica y no implican producción.

## Avisos del temporizador · UI-018

Javier comunica el 08/10/2026 una revisión superficial positiva en el simulador
de guardado, Evolución y fotos; no acredita todos los recorridos autenticados.
La recuperación por correo nativa puede esperar, sin requerir abrir un buzón
en el simulador.

UI-018 añade audioplayers 6.8.1 y WAV locales. El paquete Darwin 6.5.0 incluye
SPM con mínimo iOS 13, dentro del mínimo iOS 15 del proyecto. Esa revisión de
configuración no acredita la compilación ni la reproducción con el plugin nuevo.
Tras actualizar el repositorio, ejecutar pub get con lockfile, detener la app
y arrancarla de nuevo: hot reload no registra plugins nuevos. Comprobar
Sesión → Avisos del temporizador → Probar sonido, seguido de un intervalo de
40 segundos y descanso; registrar compilación, avisos y errores si los hubiera.
Existe un banco sin cuenta ni Supabase:

```sh
flutter run -d <simulador> -t tools/workout_cue_probe.dart
```

La configuración mezcla los pitidos con otro audio usando playback/mixWithOthers.
Volumen/silencio y convivencia con vídeo, música y auriculares necesitan prueba
nativa. No se habilita una garantía de avisos con pantalla bloqueada o app
suspendida. [Contrato y comprobaciones actuales](WORKOUT_AUDIO_2026_10_08.md).

## Comprobación posterior del audio · IOS-002 · 08/10/2026

Investigación coordinada con «Prepara EntrenaOP para iOS», autorizada por Javier.
La copia limpia del Mac y la app instalada seguían en `98e037e`; faltaban el
plugin de audio y los cinco WAV. Se revisó el diff de los dos commits nuevos,
avanzó hasta `774361b` y preparó las dependencias con lockfile. No se modificó
código ni se añadió otro commit en el Mac.

- Banco `tools/workout_cue_probe.dart` compilado y arrancado en iPhone 17 Pro,
  iOS 26.3.1, con audioplayers_darwin 6.5.0 registrado por SPM.
- Cinco WAV empaquetados e idénticos a los del repositorio. Reproducción de
  preparación, inicio, mitad, diez segundos, cuenta final 3/2/1, final y descanso.
- Javier confirma **«Sí, ahora suena»** al probarlo. Sin errores de audio.
- Análisis limpio y **621 pruebas correctas**, con una exclusiva web omitida.
- App principal relanzada con Supabase de desarrollo, árbol limpio en 774361b.
- Vibración activada, generadores hápticos nativos de Flutter y llamadas sin
  errores. Esto no acredita una vibración física en el simulador.

La causa comprobada fue la versión antigua ejecutada, no la configuración
playback/mixWithOthers. Mantener actualizados Git y el ejecutable: hot reload no
incorpora un plugin nuevo. La escucha y vibración en dispositivo real, volumen/
silencio, música, auriculares y una sesión de entrenamiento siguen pendientes.

## Instalación física · IOS-003 · 10/10/2026

Tras incorporar los cambios de Windows hasta `b590295`, se comprueba Xcode
27.0 (27A266a), licencia y preparación inicial completadas. Flutter detecta
el iPhone 12 de Javier con iOS 27.0.1, conectado por cable, emparejado y con
modo desarrollador activado. Javier inicia sesión en Apple y selecciona su
equipo personal; se comprueba un certificado Apple Development válido.

Xcode actualiza el formato del proyecto y conserva SPM. La firma automática
usa el equipo personal en Debug, Release y Profile. No se añaden paquetes ni
se cambian lockfiles, certificados o claves en Git. El esquema compartido
vuelve a Debug tras instalar la app en Release sin depurador y con
`APP_ENV=development`. Xcode acredita la ejecución en el iPhone y CoreDevice
lista EntrenaOP entre sus aplicaciones instaladas.

La primera compilación desde la herramienta de terminal falló al firmar por
`errSecInternalComponent`; la ejecución interactiva desde Xcode compiló,
firmó e instaló correctamente. No se modificaron los controles del llavero.
El análisis está limpio, las 742 pruebas de la raíz pasan con una exclusiva
web omitida y la compilación de desarrollo para simulador es correcta. La
misma versión arranca en el simulador iPhone 17 Pro/iOS 26.3.1; Device Hub
muestra Inicio, con la sesión de desarrollo ya conservada en ese dispositivo.

Javier comunica que **la vibración no funciona en el iPhone**. Queda como
incidencia física pendiente, sin atribuir todavía la causa a permisos ni
ajustes y sin acreditar el conjunto de avisos del temporizador. Los
«colapsos» que anuncia quedan pendientes de descripción o logs, sin
inventar reproducciones. El arranque no acredita login, recuperación por
correo, una sesión de gimnasio ni funcionamiento con auriculares o en
segundo plano. [Seguimiento de avisos](WORKOUT_AUDIO_2026_10_08.md).

## Corrección de vibración física · HAPT-002 · 10/10/2026

Se sustituye la ruta de efectos de interfaz iOS por pulsos finitos de Core
Haptics, sin paquetes ni permisos nuevos. Xcode instala la corrección en el
mismo iPhone 12 con Supabase de desarrollo. Javier confirma los dos pulsos
de «Probar vibración» y la consola registra el patrón de 420 ms sin error.
En una prueba posterior, Javier confirma también que la vibración y el
sonido se perciben sincronizados en el iPhone.
El análisis, las 744 pruebas Flutter (una exclusiva web omitida) y tres
pruebas nativas de los patrones pasan. El esquema vuelve a Debug tras la
instalación Release sin depurador. Quedan pendientes la sesión real con
todos sus hitos, auriculares y los «colapsos» todavía no descritos.
[Contrato, implementación y límites](WORKOUT_AUDIO_2026_10_08.md).

## Preparación de compras en el Mac · IOS-004 · 14/10/2026

El Mac está en `d5016de`, coincidente con GitHub al comenzar, con un archivo
de resolución SPM local previo conservado. Falta inicialmente el JSON de
compras y VS Code tiene seleccionado el simulador. Javier copia el archivo
desde Windows por SCP; se verifican sus dos campos, entorno development,
clave pública Test Store y exclusión de Git, sin mostrar su valor.

`flutter pub get --enforce-lockfile` prepara los paquetes resueltos, sin
actualizar `pubspec` ni lockfiles. El plugin purchases_flutter 10.15.2 usa
SPM con PurchasesHybridCommon 19.10.0 y RevenueCat iOS 5.94.0; su mínimo
iOS 13 queda dentro del mínimo iOS 15 del proyecto. El iPhone 12/iOS 27.0.1
está emparejado, conectado y con modo desarrollador habilitado. Se conserva
Flutter 3.47.5, Dart 3.13.4 y Xcode 27.0, así como el equipo y la firma existentes.

La primera compilación debug firma e instala, pero el lanzador LLDB directo
se cierra con SIGKILL en dyld antes de ejecutar Flutter. La firma local supera
la comprobación estricta y permite depuración. No se obtiene un informe Runner
que permita atribuir la causa del SIGKILL. La vía Xcode conecta en otro intento,
pero un arranque posterior agota la espera de CONFIGURATION_BUILD_DIR. Se
selecciona Xcode para esta configuración macOS y se reabre el IDE: F5 compila
en 15,9 s, conecta con el servicio de Dart y se acredita la inicialización de
Supabase Dev. Se reanudan los hilos detenidos en entry. Device Hub muestra
Inicio de la app actual en el iPhone físico, con la sesión conservada.
Javier confirma que Perfil → Mi suscripción muestra su acceso Pro existente.
Esto acredita la carga del panel, sin probar una nueva compra.

Análisis limpio, 45 pruebas Pro y 776 pruebas completas correctas, con la
omisión web existente. No se modifican código de la app, SDK, datos de cuentas,
compras ni producción. Los archivos locales de resolución de Swift Package
Manager se conservan separados del ajuste de lanzamiento/documentación.
Esta comprobación acredita preparación, compilación y arranque; la compra,
restauración y conciliación desde este iPhone quedan pendientes de aceptación.

## Uso desde el icono del iPhone · IOS-005 · 14/10/2026

Javier muestra la pantalla de Flutter que impide arrancar una app debug desde
el icono. Se instala Release con `APP_ENV=development`, sin incluir la clave de
Test Store. La configuración de compras debug se conserva.

La compilación por SSH encuentra `errSecInternalComponent` al firmar. La
compilación interactiva desde Xcode termina correctamente, instala y ejecuta
Release en el iPhone 12. Se cierra la ejecución de Xcode y CoreDevice vuelve a
abrir el mismo bundle sin LLDB: Device Hub muestra Inicio. Se verifica el
snapshot AOT y la firma estricta fuera del sandbox; la comprobación inicial
dentro del sandbox no podía leer la cadena del certificado. El esquema
compartido vuelve íntegramente a Debug, sin cambios de firma ni de llavero.

La comprobación adicional de F5 en Release compila en 99,7 s, pero queda en
«Installing and launching…»; se detiene la sesión y no se incorpora esa nueva
configuración como un flujo validado. Para esta instalación se acredita el
recorrido interactivo desde Xcode y el arranque posterior sin depurador.

El análisis está limpio y pasan las 45 pruebas de Pro, incluido el contrato
que deshabilita Test Store fuera de debug. No se cambian paquetes, derechos
de cuentas ni producción. La fuente instalada en esta comprobación es
`9aedb1f`: el cambio de contadores `00:00`, que Javier identifica como el
commit local de Windows `c6dd045`, todavía no está publicado en GitHub al
comprobarlo. Su incorporación y reinstalación quedan pendientes de esa subida.

## Integración de Windows y macOS · 14/10/2026

Javier autoriza integrar ambas líneas sin perder cambios. Windows conserva
`c6dd045` (entrada uniforme de tiempos) y `c1e97cb` (fotos y acción fija en la
vista de sesión); GitHub contiene `9aedb1f` y `a24ac6d`, procedentes del trabajo
de macOS. Los cuatro comparten la base `d5016de`. Se integran mediante merge
sin conflictos, conservando los cuatro commits y el ajuste macOS de arranque
de compras, sin sustituir el código de tiempos ni la vista de sesión.

La combinación pasa análisis en raíz, admin y `workout_editor_ui`, y sus
baterías completas: 791, 109 y nueve pruebas respectivamente. Las dos omisiones
web preexistentes se conservan. Se verifican las regresiones automatizadas de
tiempos y Pro, sin modificar compras, derechos de cuentas ni datos de servidor.
El archivo local previo `devtools_options.yaml` permanece sin incluir.

Después de la subida de esta integración, descargarla en el Mac mediante
Fetch origin y Pull origin. Si su copia tiene cambios locales o otra divergencia,
revisarlos e integrarlos antes de continuar, conservando ambos trabajos. Ejecutar
`flutter pub get --enforce-lockfile` y reinstalar para que el iPhone incorpore
los tiempos y las fotos. Release con `APP_ENV=development` permite abrir desde
el icono y consultar Pro; la configuración de compras móvil debug Dev permite
probar Test Store. Esta validación en Windows no acredita una reinstalación ni
una compra nueva en el iPhone. Free/Pro mantiene su aceptación física pendiente.

## Actualización del Mac y del iPhone · IOS-006 · 14/10/2026

Se contrasta GitHub y se actualiza `main` del Mac desde `a24ac6d` hasta
`d7d16aa` mediante fast-forward. Ya incorpora `c6dd045` (entrada `00:00`),
`c1e97cb` (fotos y acción fija) y los dos commits previos de macOS. Se conserva
sin cambios la configuración local previa de `project.pbxproj` y los dos
archivos de resolución de Swift Package Manager; no se incluyen en este punto
documental ni se sustituye trabajo ajeno.

En el Mac pasan los tres análisis y las baterías completas: 791 pruebas de
la app, 109 del admin y nueve del editor compartido, con las dos omisiones web
preexistentes. Se mantienen los lockfiles de las apps; el editor, que no versiona
su lockfile, prepara sus dependencias solo desde la caché existente.

La firma por SSH vuelve a fallar con `errSecInternalComponent`. Se prepara
temporalmente Runner en Release sin depurador, con `APP_ENV=development` y sin
clave Test Store, y Javier ejecuta desde Xcode y confirma que la app abre.
La nueva aplicación supera la verificación estricta de firma y contiene el
snapshot AOT; CoreDevice termina el proceso anterior y vuelve a abrir el bundle
sin LLDB. El esquema compartido vuelve íntegramente a su estado Debug previo.

El iPhone ya tiene el código integrado `d7d16aa`, en lugar de la instalación
anterior que no incluía los tiempos y las fotos. Se solicita comprobar la
entrada `130` → `01:30` y el panel de acceso Pro en el teléfono; esa comprobación
visual sigue pendiente de respuesta. Release consulta el acceso Pro de Supabase
Dev; una compra nueva o restauración de Test Store sigue requiriendo debug Dev
y no se acredita por esta instalación. No se modifican datos de cuentas,
compras ni producción.

## Corrección de agilidad y calculadora FAS · UI-031 · 14/10/2026

El código `1e6273e` corrige la entrada de agilidad de Tropa y FAS a segundos
decimales, reduce los números de la calculadora y cierra el teclado al volver.
Análisis limpio, 798 pruebas raíz correctas con la omisión web existente y
17 pruebas específicas correctas sobre el código final. Tres capturas de
widgets con fuentes reales revisadas en 390/320 px y texto al doble.

Xcode compiló Release de desarrollo a las 21:19 (hora local), con cero errores.
Se verificó la firma completa del paquete y el snapshot Dart AOT. El paquete
firmado se instaló por reemplazo con `devicectl` en Iphone-JVR y se relanzó
correctamente sin depurador. `Generated.xcconfig` conserva `APP_ENV=development`
sin clave de Test Store; Pro continúa consultándose en Supabase Dev y no se
habilitan compras Release. Los tres ajustes temporales del esquema se
restauraron a Debug, preservando los cambios locales anteriores del proyecto
y los lockfiles SPM. No se desinstaló la app ni se modificó producción.

Queda la confirmación física de escritura/corrección de agilidad, tamaño de los
campos y teclado cerrado al volver al menú; la instalación y el arranque sí
están comprobados. El detalle de la corrección está en `docs/VISUAL_DESIGN.md`.

Javier confirma que el funcionamiento corregido es correcto, pero aporta la
referencia de Android y rechaza cambiar la disposición. Se recuperan las
cuatro tarjetas en dos columnas en 390 px y las unidades dentro del campo,
ajustando el tamaño de la marca al espacio disponible. Se conserva el arreglo
de segundos decimales y teclado. Análisis limpio, 798 pruebas de raíz correctas
con la omisión web y tres capturas nuevas revisadas. Xcode recompila Release
Dev a las 21:27, con cero errores; firma y snapshot AOT verificados, instalación
y estado Running Runner on Iphone-JVR comprobados. Los ajustes temporales del
esquema vuelven a Debug. La aceptación visual de esta distribución final en el
iPhone sigue pendiente; no se confunde con la confirmación funcional anterior.
