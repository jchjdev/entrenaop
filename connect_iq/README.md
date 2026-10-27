# EntrenaOP Connect IQ · Dev

**Ensayo 1.5 · INT-020:** menú **Prueba: descarga en fondo**, solo con una sesión
lista. Armar una vez y salir a la esfera antes de cambiar la receta en Dev.
Solicita una revisión nueva en segundo plano, sin avisos ni intents; espera
un cambio durante un máximo de 30 min y pide un solo FIT. Durante el ensayo,
abrir la app/START solo comprueba la biblioteca local, sin descargar. MENU →
Terminar prueba devuelve el modo habitual. HTTP 200 no demuestra instalación.
Treinta y ocho pruebas por variante correctas. Javier confirma EOP1000000144 en
Fuerza nativa antes de abrir EntrenaOP, con receta nueva correcta: descarga e
importación en fondo aceptadas en su fēnix 8 de 47 mm. Pendiente terminar el modo
de prueba; la sincronización silenciosa continua aún no está implementada.
[Protocolo](../docs/DEVICE_GARMIN_TRAINING.md#ensayo-silencioso-en-segundo-plano--int-020).

**Corrección 1.4.1 · 27/10/2026:** timeout -300 identificado como transporte;
Javier recupera la sesión con Connect abierto y confirma que abre Fuerza con
contenido. Publicada 1.4.1 en la misma beta privada (Internal: 3), con reintento
manual y autorización nueva, mensajes
medidos y partidos dentro del círculo. Treinta pruebas por variante y firma
correctas; timeout revisado visualmente en el simulador oficial. Garmin confirma
envío al fēnix y Javier responde **TODO EN ORDEN** al comprobar 1.4.1, textos
completos y apertura: instalación, presentación y apertura físicas aceptadas.
Reintento ante otro timeout, cancelación y reapertura repetida no ensayados de
nuevo en esta versión.

**Beta 1.4.0 · 27/10/2026 · INT-019:** actualización registrada en la misma ficha
privada de Store (Internal: 2, firma Verified). La lista se sustituye por
**Abriendo Fuerza**, con una autorización/un intento nativo, descarte de respuestas
al salir y MENU → **Estado de apertura**. Los errores nativos no invalidan una
descarga correcta. Conserva UUID, credencial, permisos y avisos. Veinticinco
pruebas por variante y firma del paquete correctas. Pendiente instalar por
sincronización y repetir apertura/cancelación físicamente; la excepción original
de 1.3 no quedó identificada. [Detalle](store/BETA.md#actualización-140--apertura-controlada).

**Beta privada instalada desde Store (27/10/2026):** `build-dev.ps1 -Variant Beta -Package`
exporta EntrenaOP Beta 1.3.0 con identidad independiente y servidor Dev. Dieciséis
pruebas correctas en cada variante y verificador de firma del SDK integrado en
el build. Ficha creada en Garmin como BETA, inicialmente Pending Scan; visible
únicamente para la cuenta Garmin que la subió. Descarga habilitada después y
solicitud de instalación confirmada por Garmin para el fēnix 8 de 47 mm en la
próxima sincronización. Javier confirma después **Beta 1.3** abierta en el reloj
y código de vinculación nuevo. Instalación e inicio desde Store aceptados;
vinculación posterior confirmada en la cuenta secundaria de pruebas. La lista
vacía inicial correspondía a una cuenta con solo carrera. Se pauta allí fuerza
3×5 a 20 kg y 60 s; Javier confirma una sesión y dosis/descanso correctos en Fuerza.
Transporte privado y apertura desde Beta Store aceptados. Javier confirma después
el bloqueo físico al revocar Beta. Vínculo nuevo activo y lista recuperada;
tras un fallo de apertura local, reiniciar el reloj recupera Fuerza y Javier
confirma otra apertura sin reiniciar. Beta operativa con avisos activados.
La excepción original sigue sin identificar; espera y diagnóstico de apertura
eran el siguiente ajuste recomendado; implementados después en 1.4, con
aceptación física de esa actualización todavía pendiente.
[Ficha y pasos pendientes](store/BETA.md).
El vínculo Dev se ha revocado desde Perfil; servidor bloquea estado, manifiesto
y descarga. La prueba física de revocación se acepta después en Beta.

La variante de las pruebas anteriores es **EntrenaOP Dev 1.3**, con OP oficial y **MENU → Estado de
avisos**. Compilación estricta sin avisos y dieciséis pruebas Monkey C correctas;
paquete copiado y releído por USB con hash idéntico. El 27/10 Javier confirma en
fēnix 8 **app cerrada → aviso → aceptar → actualización sin errores → una sola
sesión en la lista de EntrenaOP**. Queda aceptado ese recorrido en Dev.

También están aceptados vínculo privado, apertura en Fuerza nativa, cambio a
3×6 a 22,5 kg con descanso 1:15 y repetición de Actualizar/reapertura sin duplicar
la lista vigente. Esto no acredita limpieza de copias antiguas en la biblioteca
nativa. Revocación y Store se aceptan después en Beta 1.3; otros relojes siguen
pendientes. El transporte sintético 0.2 está conservado como evidencia histórica.

## Vincular y recibir sesiones privadas

1. Compilar con `./connect_iq/build-dev.ps1`; con el simulador oficial abierto,
   ejecutar `./connect_iq/test-dev.ps1` (25 regresiones). Instalar solo
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
6. Para los avisos, **MENU → Activar avisos de cambios** y salir a la esfera con
   el móvil/Connect e Internet disponibles. La consulta queda programada cada 15
   minutos desde la salida. Si detecta una revisión nueva, pide abrir EntrenaOP;
   aceptar descarga en primer plano. Actualizar sigue como recuperación manual.

Sin Pro ni servicio activo no se puede vincular, descargar ni sincronizar. Se
puede retirar el permiso propio aunque ya no se tenga ese acceso comercial.
Credencial revocable de 90 días, máximo cinco relojes; no hay tokens Garmin ni
claves administrativas en el reloj. La comprobación opcional cada 15 minutos
está desactivada inicialmente y solo detecta cambios, sin importar/borrar FIT.
La variante Beta ya se instala desde la ficha privada de Connect IQ Store.

Desde 1.1, **MENU → Activar avisos de cambios** activa también la consulta cada 15
minutos y permite un diálogo por huella nueva. Aceptarlo abre EntrenaOP, que
actualiza e importa en primer plano. Rechazarlo no produce otro aviso por la
misma huella; Actualizar sigue disponible. No hay avisos sin activación expresa,
ante respuesta inválida, HTTP fallido o revisión ya instalada. Desactivar la
consulta desactiva también los avisos. Garmin decide cuándo ejecutar el servicio;
no se garantiza puntualidad ni descarga con la app cerrada. Las copias FIT
retiradas permanecen en la biblioteca nativa; la lista de EntrenaOP solo muestra
las vigentes. Una lista de una sesión no demuestra limpieza de esa biblioteca.

La prueba inicial de avisos no conseguía el diálogo pese a No molestar apagado y
recepción de notificaciones del iPhone. Dev registraba consultas y respuestas 200.
En 1.2, Estado de avisos muestra
consulta/avisos activados, último paso, antigüedad y HTTP; registra desde inicio de
la consulta hasta respuesta, cambio ya instalado/avisado, app activa o solicitud
del diálogo. No expone credenciales, recetas ni hashes. «Aviso solicitado» solo
acredita que la API aceptó la petición, no que el usuario lo vio. Un error al pedir
aviso conserva el reintento y el callback sale también ante fallos de procesamiento.

En 1.3 se retira `AppBase.isActive()` como indicador de primer plano: en el ensayo
cerrado devolvió verdadero y bloqueó el diálogo. Se sigue el patrón BackgroundTimer
del SDK: al abrir se cancela el evento temporal, y al salir se programa cada 900 s
solo si sigue activada la consulta y existe vínculo sin código pendiente. Activar
desde el menú conserva el consentimiento, pero el temporizador arranca al salir.
La instancia de fondo no reprograma al terminar. No cambia la validación de permisos
ni revisiones ni se amplía el alcance a importar FIT con la app cerrada. El diálogo
corregido y la actualización tras aceptarlo están aceptados físicamente el 27/10;
no se acredita todavía rechazo del diálogo o repetición de avisos en el dispositivo.

El servidor Dev usa ahora `ciq-private-2`: la lista conserva el título de sesión,
pero Garmin puede mostrar `EOP<serial>` como nombre nativo. Este alias ASCII
corto evita depender de títulos largos en la comprobación exacta de instalación.
El formato lleva producto FIT 2 y es estable entre reintentos. El ajuste llegó al
PRG 1.0 al actualizar las sesiones, sin volver a instalar por USB.
Tras el error físico «FIT no confirmado: 200», Javier confirma «sesiones listas»
con este ajuste y confirma después Fuerza nativa con el press banca 3×5 a 20 kg y
descanso de 1:00. Confirma después la receta cambiada a 3×6 a 22,5 kg con 1:15
desde 1.1 y una sola entrada tras dos actualizaciones y reapertura. Aceptación
física privada del 27/10; retirada/revocación y Store se aceptan después en Beta.

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

En las primeras pruebas la respuesta llegó después del aviso de sesenta segundos.
El aviso no cancela la importación: una respuesta tardía puede instalar y
confirmar el entrenamiento. La instancia bloquea nuevas solicitudes hasta recibir
respuesta o salir. El aviso actual conserva el callback y permite esperar o salir;
no se conoce todavía la causa de la latencia inicial.

Quedan pendientes limpieza de copias nativas antiguas, pérdida de conexión,
retirada/revocación, otros relojes, rechazo/repetición de avisos y retorno por esta vía. No
presentar Descargar/Abrir como sincronización automática terminada ni exigir
este puente para toda la fuerza.

La vinculación segura y entrega privada ya están implementadas y aceptadas;
el aviso opcional y la actualización al aceptar también están aceptados en 1.3.
El único siguiente ensayo recomendado es revocar el vínculo propio y comprobar
el bloqueo en el reloj. El bloque general sigue abierto: no prometer recepción
inmediata, importación con la app cerrada ni sondeo permanente.

Contrato y evidencia: `docs/DEVICE_GARMIN_TRAINING.md`, INT-016 e INT-017.
