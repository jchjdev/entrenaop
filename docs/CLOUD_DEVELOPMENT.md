# Desarrollo de EntrenaOP en Codex Cloud

## Alcance autorizado · DEV-003 · 14/10/2026

Javier autoriza preparar y comprobar un entorno privado de Codex Cloud para
`jchjdev/entrenaop`, con las versiones existentes, sin actualizar paquetes ni
tocar producción. Esta preparación no cambia todavía el flujo de guardado
de DEV-002 ni da por aceptada una migración completa del desarrollo a la nube.

El entorno se llama **EntrenaOP Dev** y solo selecciona este repositorio.
La configuración de instalación y la habilidad de inicio se guardan en el
propio entorno de Codex Cloud. Cada tarea dispone de su checkout independiente.
El Mac conserva la compilación, instalación y comprobación física de iPhone.

## Instalación y dependencias

- Flutter **3.47.5 stable** y Dart **3.13.4**, desde el repositorio oficial de
  Flutter y su etiqueta exacta. Se comprueban las versiones reales antes de
  resolver dependencias; no se sustituye el SDK por el más reciente.
- SDK y cachés del entorno bajo `/workspace/toolchains/`, fuera del repositorio.
  La activación se conserva en `/workspace/toolchains/activate.sh`, incluyendo
  `ANALYZER_STATE_LOCATION_OVERRIDE` para la caché escribible del analizador.
- `flutter pub get --enforce-lockfile` en la raíz y en `admin_app/`. Un fallo
  de resolución detiene la preparación; no se reescribe ningún lockfile.
- Solo esos dos lockfiles están versionados. El editor compartido se analiza
  y prueba desde la raíz, utilizando la resolución de la app y sin ejecutar
  una resolución independiente dentro de los paquetes locales.
- Los archivos versionados se comprueban antes y después. Las descargas y
  cachés generadas no conceden autorización para modificar manifiestos,
  paquetes, pruebas o código de producto.

La red usa el ajuste de gestores de paquetes y el dominio adicional
`storage.googleapis.com` para los artefactos oficiales de Flutter. El entorno
queda privado para Javier, sin secretos de red ni variables con credenciales.
Esta validación no requiere copiar los `.env` de Windows o del Mac ni conectar
Supabase o RevenueCat: utiliza los fixtures de las pruebas automatizadas.

## Matriz de comprobación

Desde la raíz del repositorio:

```sh
flutter analyze --no-pub
flutter analyze --no-pub packages/workout_editor_ui
flutter test --no-pub --reporter expanded
flutter test --no-pub packages/workout_editor_ui/test --reporter expanded
```

Desde `admin_app/`:

```sh
flutter analyze --no-pub
flutter test --no-pub --reporter expanded
```

Registrar el SHA probado, las versiones reales, la salida y el código de
salida de cada comando, el número de pruebas y las omisiones. Conservar la
omisión web de la raíz y la captura optativa del admin ya existentes; no añadir
omisiones ni reducir pruebas para obtener un resultado correcto. Las capturas
optativas que usan fuentes de Windows no forman parte de esta comprobación Linux.

## Estado comprobado

Preparación validada sobre `7b2ebb285a32b7e17bf5e048c12be5fb316840c2`, que
incluye el merge `d7d16aa` y las correcciones posteriores de FAS/iPhone.
Flutter 3.47.5 stable corresponde al commit oficial
`6a19cca56475dbfba1478ee68d7bd0c2ef891da1` y contiene Dart 3.13.4 para Linux x64.
Los dos lockfiles se han resuelto sin cambios y el script completo de instalación
se ha repetido correctamente, con código de salida 0.

| Comprobación | Resultado | Código de salida |
| --- | --- | --- |
| Análisis de raíz | Sin incidencias | 0 |
| Análisis de admin | Sin incidencias | 0 |
| Análisis de editor compartido desde raíz | Sin incidencias | 0 |
| Pruebas de raíz | 799 correctas y una omisión web preexistente | 0 |
| Pruebas de admin | 109 correctas y una captura optativa omitida | 0 |
| Pruebas de editor compartido desde raíz | Nueve correctas, sin omisiones | 0 |

Las ocho pruebas adicionales de raíz respecto a la integración `d7d16aa`
corresponden a las nuevas regresiones de FAS. El checkout cloud terminó limpio
y sus archivos versionados intactos, sin commits ni pushes del preparador.
Los registros de comandos y resultados se conservan bajo
`/workspace/entrenaop-setup/logs/`. La interfaz confirma **Publicado** el
14/10/2026, con los scripts guardados y acceso **Solo yo**. El primer trabajo
posterior del 15/10/2026 encuentra el SDK y las cachés disponibles; se comprueban
Flutter 3.47.5/Dart 3.13.4 reales y se valida la ampliación UI-032 con análisis
limpio y 816 pruebas de raíz correctas, más la omisión web existente. No se
repite la instalación ni se actualizan dependencias en esa tarea.

El primer intento no tenía permiso de descarga; se guardó la red limitada
desde el panel. El manifiesto de archivos Linux devolvió después 404, por lo
que la instalación utiliza la etiqueta oficial exacta del SDK. El analizador
necesitó una ubicación escribible para su caché en este entorno.

No se han realizado despliegues, compras, migraciones o pruebas SQL remotas.
El resultado de Flutter no acredita tiendas reales, recorridos físicos de
Android/iPhone ni las pruebas de servidor de la matriz de `AGENTS.md`.

## Uso posterior

Seleccionar **EntrenaOP Dev** en Codex Cloud. Comprobar
el SHA y el estado de Git de cada tarea; no asumir que una tarea anterior ya
incluye nuevos commits ni resetearla a la instantánea de esta preparación.
Seguir `AGENTS.md` y la matriz correspondiente al alcance real del cambio.

Guía del producto: [entornos de Codex Cloud](https://learn.chatgpt.com/docs/environments/cloud-environments).

## Actualizar los equipos después de un trabajo en la nube · 15/10/2026

GitHub transporta los cambios entre la nube, Windows y el Mac. La app instalada
en un ordenador o teléfono solo cambia al volver a compilarla e instalarla.
Este primer trabajo de producto en la nube es la ampliación de ritmos UI-032;
se conserva DEV-002 para guardar y subir el bloque validado.

En **cada equipo** que vaya a seguir desarrollando o instalar la app:

1. Abrir el repositorio existente de EntrenaOP en GitHub Desktop. Guardar y
   revisar primero cualquier cambio local; no descartarlo para actualizar.
2. Seleccionar `main`, pulsar **Fetch origin** y después **Pull origin** si hay
   cambios. Comprobar en History que aparece el commit indicado al entregar el
   trabajo. Si se entrega en una rama/PR, integrar primero ese trabajo en `main`.
3. Desde la raíz del proyecto, con Flutter 3.47.5 y Dart 3.13.4, ejecutar:

   ```sh
   flutter pub get --enforce-lockfile
   flutter devices
   ```

4. Volver a ejecutar la aplicación para el destino deseado. Para Android,
   emulador o Windows, seleccionar el destino en VS Code y ejecutar
   **EntrenaOP App · dispositivo seleccionado**. Para web local, detener la
   sesión anterior y ejecutar **EntrenaOP Chrome · puerto fijo**.
5. Para actualizar el **iPhone**, hacerlo desde el Mac con el teléfono conectado,
   desbloqueado y la firma de Xcode existente:

   ```sh
   flutter run --release -d <identificador-del-iphone> --dart-define=APP_ENV=development
   ```

   Obtener el identificador con `flutter devices`. Instalar por reemplazo,
   conservando el identificador de la app, sin desinstalarla. Release permite
   abrirla después desde el icono sin el depurador. El esquema **Runner iPhone**
   y los detalles de firma están en `docs/IOS_DEVELOPMENT.md`.

En terminal, si `main` no tiene cambios locales y sigue `origin/main`, los pasos
de GitHub Desktop equivalen a `git switch main` y `git pull --ff-only origin main`.
Si hay cambios locales o Git informa de ramas divergentes, conservar ambos
trabajos e integrarlos antes de seguir; no usar reset ni force push.

No hay que copiar el SDK, las cachés ni la carpeta del proyecto desde la nube.
Los archivos locales `.env` siguen en cada equipo. Este cambio de calculadora
no añade dependencias ni requiere migraciones, parámetros nuevos, publicación
en tiendas o cambios de backend. La compilación y la instalación física de iOS
siguen haciéndose en el Mac; la nube Linux no acredita ese recorrido.
