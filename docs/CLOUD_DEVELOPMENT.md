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
14/10/2026, con los scripts guardados y acceso **Solo yo**. La restauración
del SDK en una tarea nueva todavía no se ha comprobado y se verifica al iniciar
el primer trabajo posterior; las instrucciones de inicio recogen ese control.

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
