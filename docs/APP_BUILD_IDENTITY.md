# Identificación de la app instalada · 22/10/2026

Javier no encuentra conversación/avisos y pide poder distinguir la versión
instalada de la que debe probar. La grabación muestra Perfil sin «Mi preparador»
ni «Carreras de Salud», accesos incondicionales presentes en main. Es compatible
con una compilación anterior; la grabación no permite recuperar su SHA exacto.
Publicar Trainer o ADMIN no actualiza la app instalada en el teléfono.

## Qué se muestra

Perfil → Versión de la app, encima de Cerrar sesión: versión y número reales del
paquete, entorno y revisión corta. Al abrir: revisión completa, modo, fecha UTC de
preparación y si había cambios locales. Copiar datos de versión copia únicamente
esa información técnica, sin usuario, correo, tokens, configuración o métricas.
En móvil no necesita red, no consulta otra cuenta y no añade permisos.

`package_info_plus: 10.2.2` lee versión/build reales y respeta las opciones de
Flutter `--build-name`/`--build-number`; no duplica la versión de pubspec en Dart.
La base sube a `1.0.0+2`. Requisitos contrastados con Flutter 3.47.5, Dart3.13,
AGP9.1/Gradle9.3.1/Kotlin2.4/Java17 e iOS15 existentes, sin elevar mínimos.
El lock añade solo el plugin y sus tres dependencias nuevas, sin actualizar las
versiones existentes. [Contrato oficial del plugin](https://pub.dev/packages/package_info_plus).

Si falla el plugin se muestra versión no disponible. Sin metadatos de fuente se
muestra revisión/fecha sin identificar. Nunca se deduce «última versión» de un
contador o SHA, ni se anuncia una actualización sin catálogo de distribución.
Este tramo no incorpora un servicio remoto de actualizaciones.

## Compilar o instalar con identidad

Desde la raíz, con Dart del SDK Flutter en PATH:

```sh
flutter pub get --enforce-lockfile
dart run tools/run_app.dart run --release -d ID_DEL_IPHONE --dart-define=APP_ENV=development
```

Para Android: `dart run tools/run_app.dart build apk --debug`.
`--dry-run` calcula la identidad sin ejecutar Flutter. La herramienta imprime
solo SHA/UTC/estado de fuentes, nunca los demás argumentos, que pueden contener
configuración. Rechaza sustituir las tres claves APP de identidad, también desde
un archivo de defines. Mantiene las demás opciones de Flutter.

El estado de fuentes cubre app, paquetes, assets, plataformas, pubspec/lock y
herramienta. Documentos, capturas y WIP de otros portales no etiquetan la app como
modificada. Un SHA con cambios locales no acredita igualdad con ese commit.
Cambiar defines o plugins exige una ejecución/compilación nueva; hot reload no
actualiza los datos nativos del paquete.

La CI existente de Salud utiliza el estampado al compilar la app principal iOS;
el laboratorio conserva su procedimiento. Para instalación física sigue vigente
[el recorrido principal](DEVICE_RUNNING_HISTORY.md#siguiente-prueba-con-el-iphone),
abriendo `ios/Runner.xcworkspace` desde la raíz, no el laboratorio. Esta entrega
no acredita instalación física ni publicación en tiendas.

## Verificación local

Análisis raíz limpio; diez pruebas focales correctas y batería completa raíz
con 1.251 correctas/una omisión previa. Tras colocar la tarjeta encima de Cerrar
sesión se repiten los cuatro casos de Perfil/diálogo y el análisis de las siete
fuentes/test/herramienta, limpios. La captura usa widgets reales a390px y texto
1,5, tema EntrenaOP y datos ficticios; no acredita instalación física.
[Diálogo](visual-audit/app-build-identity-2026-10-22/profile-version.png).
Se comprueban la versión nativa sobrescrita, metadatos desconocidos, copia solo
técnica, error seguro del lector y rechazo de sustitución del estampado desde
parámetros o JSON (ruta Windows incluida). Dry-run real correcto.
No se repiten baterías completas por la captura o el cambio de posición.

## Artefacto Android verificado

Fuente `661b279753d6121139a1933bccdc327e5c4ff0da`, preparada
`2026-10-22T02:23:04.679782Z`, `APP_SOURCE_DIRTY=false`. El comando real
`dart run tools/run_app.dart build apk --debug --no-pub --dart-define=APP_ENV=development`
compila correctamente. `aapt dump badging` contrasta bundle
`com.entrenaOp.entrenaop`, versionName1.0.0/versionCode2, mínimo24/target36;
los mínimos no se modifican.

APK local ignorado: `build/app/outputs/flutter-apk/app-debug.apk`,186.725.184bytes,
SHA-256 `9b66a2c43230e0b7aaa339b548bd7879afca1e98831e130fb768d83669283b73`.
No instalado ni distribuido por esta comprobación. La advertencia de herramientas
SDK XML3/4 no impide la compilación; no se actualiza el SDK como parte del cambio.
La CI iOS existente se dispara con el push de pubspec; su ejecución y la
instalación física se acreditarán por separado. No se declara iOS verificado por
haber compilado Android, ni se confunde un APK debug con una distribución iPhone.
