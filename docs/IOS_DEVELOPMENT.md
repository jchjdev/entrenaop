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
