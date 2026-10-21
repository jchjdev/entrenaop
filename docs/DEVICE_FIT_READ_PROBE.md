# Lectura FIT offline de carrera · ensayo · 21/10/2026

## Alcance y estado real

Javier autoriza avanzar con otros proveedores y lo comprobable sin móvil.
Se incorpora un adaptador experimental a `labs/health_read_probe/lib/data/`,
separado del dominio puro y de los puentes nativos de Salud/Health Connect.
No se cambia ninguna de las tres apps, servidor, agenda, permisos profesionales
ni resultados. La app habitual de EntrenaOP sigue sin mostrar estas conexiones.

El formato FIT sirve como frontera de recepción documentada para Garmin, COROS
y Suunto. Este ensayo valida archivos locales; no conecta cuentas, tramita
altas ni acredita acceso a sus APIs. La marca que aparece en un archivo puede
ser distinta del proveedor que lo entrega. Tampoco se deduce el propietario
a partir del fabricante, número de serie o nombre del archivo.

La lectura de Salud sigue disponible en la segunda app de ensayo, cuyo
[protocolo de instalación y prueba](DEVICE_HEALTH_READ_PROBE.md) requiere el
iPhone y el Mac. Este lector de archivos es una herramienta adicional para
avanzar sin teléfono, sin convertir la importación manual en función del producto.

## Qué se puede ejecutar ahora

Con Flutter 3.47.5 / Dart 3.13.4, desde `labs/health_read_probe`:

```sh
flutter pub get --enforce-lockfile
dart run tool/read_fit.dart garmin /ruta/a/carrera.fit
```

Se puede indicar `coros` o `suunto` en lugar de `garmin`. Es un proveedor declarado
para el ensayo, sin verificar; no simula una sesión autenticada ni una cuenta.
Por defecto la salida solo contiene modo offline, ausencia de verificación,
número de carreras y vueltas. No incluye ruta del archivo, IDs, fechas,
distancia o pulso. Para consultar explícitamente las métricas locales:

```sh
dart run tool/read_fit.dart garmin /ruta/a/carrera.fit --show-metrics
```

Esa opción muestra en la terminal fechas UTC y las métricas presentes; no hace
subidas, exportaciones ni escrituras de resultados. No publicar esa salida si
se prueba con datos personales. Los archivos `.fit`/`.FIT` están ignorados por
Git dentro del ensayo. No se versionan datos de carreras reales.

Código de salida: `64` para argumentos inválidos, `65` para FIT rechazado y
`66` para fallo de lectura local. Los errores contienen códigos, sin excepciones
del códec, contenido del archivo ni rutas personales.

## Contrato de datos y límites deliberados

El adaptador recibe bytes, una `ActivityIdentity` del adquirente y recepción UTC.
Devuelve el `ExternalActivity` existente. En una integración futura la identidad
deberá proceder del contexto autenticado y autorizado; el CLI utiliza un ámbito
ficticio y una huella de archivo que no deben persistirse como una conexión real.

Se requiere un archivo de actividad con una sola sesión de carrera, inicio y fin
presentes. Se conservan duración transcurrida, temporizador, distancia y pulso
resumido únicamente cuando están informados. Los tiempos FIT se convierten
según su unidad; las duraciones conservan milisegundos originales en `Duration`
y la distancia conserva decimales. Ausencia sigue siendo ausencia y cero sigue
siendo cero. No se calculan totales a partir de muestras de otras fuentes.

Las vueltas manuales y automáticas conservan su naturaleza; no se convierten
en pasos de una receta. Un disparador de vuelta no reconocido queda como
desconocido. Una vuelta fuera del intervalo de la sesión rechaza la lectura.
No se importan trazados GPS, números de serie, identidad personal, campos diarios
de salud ni nombres de actividades.

La revisión es la huella SHA-256 de los bytes, independiente de la recepción.
No se usa `time_created` como fecha de modificación. No se inventan zona horaria,
offset original, app escritora, tiempo en movimiento ni correspondencia con una
cita. Leer un archivo no asocia ni completa sesiones y no confirma un resultado.

Antes de invocar al códec se comprueban firma y tamaño exacto del contenedor,
versión principal admitida, CRC de archivo y CRC de cabecera cuando procede,
definiciones y límites de registros y vueltas. No se admiten archivos concatenados,
truncados o con bytes sobrantes. Límites del ensayo:

- Un MiB por archivo; la herramienta también limita la lectura por fragmentos.
- Diez mil registros, incluidas definiciones, y quinientas vueltas.
- Cabeceras de doce/catorce bytes y endianidad little/big.
- Una sesión de carrera; multideporte o varias sesiones se rechazan explícitamente.
- Los timestamps comprimidos y campos developer todavía se rechazan como
  `unsupportedEncoding`. No se anuncia soporte FIT universal.

Después se exige CRC correcto y reconstrucción byte a byte equivalente. Si el
códec pierde información necesaria para reconstruir, se rechaza la lectura.
Los diagnósticos del códec se suprimen solo durante esa operación mediante una
zona Dart, sin cambiar el logger global de la aplicación.

## Dependencia, licencia y compatibilidad comprobadas

Solo el ensayo adopta `fit_tool: 1.0.5`, códec comunitario publicado por Stages
Cycling con licencia BSD-3-Clause. No es el SDK oficial de Garmin ni concede
acceso a Garmin Connect. Se necesita para interpretar el binario sin trasladar
el protocolo al dominio puro. Su antigüedad y perfil FIT 21.60 justifican el
alcance conservador, el pin exacto y las pruebas de entradas no admitidas; no
se propone aún como dependencia de producción.

Resuelve con Dart 3.13.4 pese a su intervalo histórico de SDK; se verifican
`pubspec.yaml`, lockfile y compilación Android real. Añade `csv` 5.1.1, `fixnum`
1.1.1 y `logger` 1.4.0 al ensayo, sin actualizar las dependencias de las apps ni
añadir paquetes al dominio. La compilación Android contiene el aviso de licencia
de Stages Cycling en los `NOTICES` generados por Flutter. La compilación iOS tras
esta dependencia se comprobará en el workflow aislado; no se acredita por la
mera resolución de Pub ni por un build previo.

Se evaluaron alternativas antes de elegir: el port Dart `fit_sdk` 0.3.0 puede
terminar la decodificación sin error ante una definición ausente, según su código.
El paquete oficial JavaScript `@garmin/fitsdk` publica un acuerdo propio que
requiere aceptación del titular; no se instala ni utiliza en este bloque.
No se crea otro laboratorio Node ni se acepta ese acuerdo en nombre de Javier.

## Comprobaciones realizadas

Dieciocho pruebas FIT con binarios sintéticos construidos sin usar el codificador
del paquete elegido. La comprobación CRC usa una implementación bit a bit y el
vector CRC-16/ARC de `123456789`. Se prueban endianidad, cabecera CRC, precisión,
métricas ausentes, vueltas, identidad independiente del fabricante, revisiones,
archivos corruptos/incompletos, límites, múltiples sesiones y doscientas entradas
malformadas deterministas. Los tres fabricantes de las muestras son etiquetas
sintéticas; no son archivos obtenidos de relojes reales.

En total pasan 43 pruebas del ensayo, con análisis limpio y APK Debug compilado.
También se ejecuta el CLI sobre una muestra sintética válida con/sin métricas y
otra corrupta: resumen reducido correcto y rechazo con código `65`. Las pruebas
previas de HealthKit/Health Connect permanecen incluidas. Los cuatro escenarios
Bash del preparador se conservan en CI. No se atribuyen a este bloque las pruebas
de apps que otros chats están modificando.

## Estado por proveedor y siguiente paso

| Proveedor | Avance sin móvil | Lo que falta para conexión real |
| --- | --- | --- |
| Garmin | Lectura FIT offline y ensayo de entrada Salud/Health Connect. | API Connect no concedida; lectura real Garmin → Salud pendiente y Training API para envío. |
| COROS | Recepción FIT documentada por su Partner API; adaptador de formato probado con muestras sintéticas. | Elegibilidad, acuerdo y credenciales propias; OAuth, webhook y archivo real de la cuenta autorizada. |
| Suunto | Cloud API documenta FIT y resúmenes; mismo adaptador de formato, sin copiar dominio. | Admisión, claves de suscripción/OAuth y archivo real. La subida de actividad realizada no acredita envío de prescripción. |
| Huawei | Health Kit y requisitos públicos revisados; no se fuerza su información al formato FIT. | Modalidad/región/permisos y esquema exacto de carreras autorizadas. Su compatibilidad con el canal local también necesita prueba real. |

Siguiente entrega técnica: contrastar los casos FIT no admitidos y muestras
representativas antes de reutilizar el adaptador en un conector autenticado.
Las altas se preparan con datos empresariales reales; envío de solicitudes y
aceptación de acuerdos requieren la acción específica del titular. Ninguna
cuenta se conecta usando contraseñas de reloj o endpoints privados.

## Fuentes primarias

- [Garmin: formato FIT](https://developer.garmin.com/fit/overview/).
- [COROS: Partner API y descarga FIT](https://support.coros.com/hc/en-us/articles/53181766856724-Partner-API-Access).
- [Suunto: Cloud API y formato de actividades](https://apizone.suunto.com/).
- [Huawei: Health Kit](https://developer.huawei.com/consumer/en/hms/huaweihealth/).
- [fit_tool 1.0.5](https://pub.dev/packages/fit_tool/versions) y código/licencia del paquete resuelto localmente.
- [Licencia del SDK oficial JavaScript, no adoptado](https://github.com/garmin/fit-javascript-sdk/blob/main/LICENSE.txt).
