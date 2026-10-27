# EntrenaOP Connect IQ · Dev

La versión preparada es **EntrenaOP Dev 1.2**, con **MENU → Estado de avisos**
para diagnosticar la prueba de segundo plano. Compilación estricta sin avisos y
quince regresiones Monkey C correctas; instalación física pendiente. La versión
instalada continúa en 1.1, con la OP oficial y avisos opcionales de cambios.
El paquete 1.1 se ha copiado y releído por USB el 27/10;
Javier confirma inicio en 1.1, la OP naranja y cambio de receta a 3×6 a 22,5 kg
con descanso 1:15 dentro de Fuerza nativa. Tras actualizar dos veces y reabrir,
confirma una sola entrada en la lista de EntrenaOP, sin errores; no acredita
limpieza de copias antiguas en la biblioteca nativa. Los avisos físicos siguen
pendientes. La vinculación y descarga privada de **1.0** están
aceptadas el 27/10.
El transporte sintético 0.2 descrito más abajo también está aceptado.

## Vincular y recibir sesiones privadas

1. Compilar con `./connect_iq/build-dev.ps1`; con el simulador oficial abierto,
   ejecutar `./connect_iq/test-dev.ps1` (quince regresiones). Instalar solo
   `bin/entrenaop-dev-fenix847mm.prg` por USB en `GARMIN/APPS` y verificar relectura.
2. Desconectar USB, abrir EntrenaOP en el reloj con Garmin Connect/móvil e Internet
   disponibles. El reloj solicita un código de ocho caracteres, válido diez minutos.
3. En EntrenaOP actualizado, **Perfil → Garmin → Vincular app EntrenaOP del reloj**,
   introducir código, revisar la cuenta y confirmar **Vincular este reloj**.
4. Volver al reloj: comprueba el vínculo, actualiza las sesiones compatibles de
   fuerza y permite abrir una en Fuerza nativa. START abre la lista; menú ofrece
   Actualizar. Si Garmin tarda, esperar o salir; no repetir solicitudes en curso.
5. Repetir apertura/actualización para comprobar ausencia de duplicados. Cambiar
   o retirar una cita debe impedir abrir su copia desde EntrenaOP tras comprobar
   el manifiesto vigente. Revocar el reloj desde Perfil debe bloquear nuevas
   descargas. Las copias nativas ya importadas pueden permanecer en el reloj.

Sin Pro ni servicio activo no se puede vincular, descargar ni sincronizar. Se
puede retirar el permiso propio aunque ya no se tenga ese acceso comercial.
Credencial revocable de 90 días, máximo cinco relojes; no hay tokens Garmin ni
claves administrativas en el reloj. La comprobación opcional cada 15 minutos
está desactivada inicialmente y solo detecta cambios, sin importar/borrar FIT.
La publicación e instalación desde Connect IQ Store todavía están pendientes.

En 1.1, **MENU → Activar avisos de cambios** activa también la consulta cada 15
minutos y permite un diálogo por huella nueva. Aceptarlo abre EntrenaOP, que
actualiza e importa en primer plano. Rechazarlo no produce otro aviso por la
misma huella; Actualizar sigue disponible. No hay avisos sin activación expresa,
ante respuesta inválida, HTTP fallido o revisión ya instalada. Desactivar la
consulta desactiva también los avisos. Garmin decide cuándo ejecutar el servicio;
no se garantiza puntualidad ni descarga con la app cerrada. Las copias FIT
retiradas permanecen en la biblioteca nativa; la lista de EntrenaOP solo muestra
las vigentes. Una lista de una sesión no demuestra limpieza de esa biblioteca.

La prueba de avisos 1.1 sigue sin aceptación física: Javier confirma No molestar
apagado y recepción de una notificación del iPhone, que no acredita el diálogo
propio. Dev registra consultas y respuestas 200. En 1.2, Estado de avisos muestra
consulta/avisos activados, último paso, antigüedad y HTTP; registra desde inicio de
la consulta hasta respuesta, cambio ya instalado/avisado, app activa o solicitud
del diálogo. No expone credenciales, recetas ni hashes. «Aviso solicitado» solo
acredita que la API aceptó la petición, no que el usuario lo vio. Un error al pedir
aviso conserva el reintento y el callback sale también ante fallos de procesamiento.

El servidor Dev usa ahora `ciq-private-2`: la lista conserva el título de sesión,
pero Garmin puede mostrar `EOP<serial>` como nombre nativo. Este alias ASCII
corto evita depender de títulos largos en la comprobación exacta de instalación.
El formato lleva producto FIT 2 y es estable entre reintentos. El ajuste llegó al
PRG 1.0 al actualizar las sesiones, sin volver a instalar por USB.
Tras el error físico «FIT no confirmado: 200», Javier confirma «sesiones listas»
con este ajuste y confirma después Fuerza nativa con el press banca 3×5 a 20 kg y
descanso de 1:00. Confirma después la receta cambiada a 3×6 a 22,5 kg con 1:15
desde 1.1 y una sola entrada tras dos actualizaciones y reapertura. Aceptación
física privada del 27/10; retirada/revocación, Store y avisos físicos siguen pendientes.

Pruebas servidor: `node --test supabase/functions/tests/garmin_ciq_test.ts`.
SQL: `supabase/tests/garmin_ciq_account_and_downloads.sql` (ROLLBACK, solo Dev).
Contrato y evidencia: `docs/DEVICE_GARMIN_TRAINING.md`, INT-017.

## Evidencia histórica del transporte 0.2

Primer transporte FIT aceptado físicamente el 26/10/2026 en el fēnix 8 de 47 mm
de Javier. Una muestra sintética pública se descarga sin USB y se abre en Fuerza
nativa con nombres, notas, repeticiones, carga, tiempos y descansos correctos.
No acredita todavía vinculación de cuenta, entrega privada ni automatización.

## Compilar y probar en Windows

Necesita PowerShell 7, Java, SDK Connect IQ 9.3.0 y perfil oficial `fenix847mm`
descargado con SDK Manager. El SDK local está en `.dart_tool/ciq-sdk`. El script
prefiere el Java de Android Studio y admite `-JavaPath` y `-SdkPath` explícitos.
Solo se declara el fēnix 8 AMOLED de 47/51 mm en este prototipo.

```powershell
./connect_iq/build-dev.ps1
# Con el simulador oficial abierto:
./connect_iq/test-dev.ps1
node --test supabase/functions/tests/garmin_ciq_probe_test.ts
node connect_iq/verify-dev.ts
```

El build genera una clave RSA local en `.dart_tool/ciq-dev` solo si falta.
Conservarla para las siguientes compilaciones; una clave existente se pasa con
`-DeveloperKeyPath`. Claves, SDK y binarios permanecen fuera de Git.
`-Test` compila un PRG aparte con las dos regresiones Monkey C. `test-dev.ps1`
exige un resumen con pruebas ejecutadas y cero fallos/errores: el runner de
Windows puede devolver código 1 incluso cuando imprime PASSED.

## Instalar y repetir el ensayo

1. Copiar el PRG instalable de `bin/` a `GARMIN/APPS` por USB/MTP y releerlo para
   comprobar su hash. Nunca instalar el PRG de pruebas. No copiar el FIT por USB.
2. Desconectar USB, mantener móvil/reloj enlazados, Internet y Garmin Connect
   disponible. Abrir **EntrenaOP Dev 0.2** y pulsar START una vez para descargar.
3. Esperar **Entrenamiento instalado**. Pulsar START para abrir Fuerza nativa y,
   en el selector de apertura, elegir **Solo una vez** para esta prueba.
4. Revisar **EntrenaOP IQ prueba 01**: Dominada con pausa, 6 repeticiones a 7,5 kg,
   descanso 1:30, 5 repeticiones sin carga prescrita, descanso 1:00 y Front lever
   isométrico de 0:07. Notas: Prueba de título propio / Prueba de tiempo.

No hace falta realizar actividad física ni completar una cita. No se borran
entrenamientos del usuario. MTP puede omitir un reemplazo sobre el mismo nombre:
conservar el PRG pendiente en un respaldo local antes de copiar el nuevo y
verificar siempre la relectura. Las fuentes de 0.2 son la versión probada; hash
del PRG físico aceptado de 105.852 bytes:
`40c92969006f91a0a421dffa53ebc21a33565a540d9aa41fb2d903d121c84e48`.

## Servidor y criterios de éxito

`garmin-ciq-probe/workout.fit` sirve una muestra inventada pública de 713 bytes.
Reutiliza el generador `dc48764e`, con identidad/fecha constantes. No consulta
cuentas, citas, plantillas, resultados, Auth o SQL, ni admite identificadores o
recetas del cliente. Exige URL exacta de `entrenaop-dev` y
`GARMIN_ENVIRONMENT=DEVELOPMENT`; fuera de ese entorno responde 503.

La verificación HTTP exige versión `ciq-probe-1`, tipo FIT, igualdad de bytes y
rechazo de POST o parámetros. El reloj exige contenido instalado con nombre e
identidad coincidentes en `getAppWorkouts()`. Un HTTP 200 o iterador vacío no es
instalación válida. `equals()` compara el nombre por texto; no usar `==`.

El servidor pasa 166 pruebas y tipos estrictos. El compilador Monkey C estricto
no muestra avisos y las dos regresiones pasan. El simulador devuelve un iterador
vacío; la aceptación de importación y presentación corresponde al dispositivo
físico, donde Javier confirmó también los dos descansos.

## Límites actuales

En la prueba física la respuesta llegó después del aviso de sesenta segundos.
El aviso no cancela la importación: una respuesta tardía puede instalar y
confirmar el entrenamiento. La instancia bloquea nuevas solicitudes hasta recibir
respuesta o salir. La invitación actual a reabrir debe pulirse para evitar
reintentos innecesarios; no se conoce todavía la causa de la latencia.

Quedan pendientes limpieza de copias nativas antiguas, pérdida de conexión,
retirada/revocación, otros relojes, avisos y retorno de resultados por esta vía. No
presentar Descargar/Abrir como sincronización automática terminada ni exigir
este puente para toda la fuerza.

La vinculación segura y entrega privada ya están implementadas y aceptadas;
el siguiente ensayo es el aviso opcional con la app cerrada; después,
retirada/revocación. La experiencia objetivo
es vincular una vez y mantener sesiones al día con Actualizar como recuperación
manual. Los avisos de 1.1 requieren instalación y prueba física; no prometer
recepción inmediata, importación con la app cerrada ni sondeo permanente.

Contrato y evidencia: `docs/DEVICE_GARMIN_TRAINING.md`, INT-016.
