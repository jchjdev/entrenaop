# EntrenaOP Connect IQ · Dev

La versión actual es **EntrenaOP Dev 1.0**, con vinculación de cuenta aprobada en
INT-017. Servidor privado desplegado en Dev, análisis y pruebas correctos; PRG
copiado y releído en el fēnix. La aceptación física de sesiones privadas sigue
pendiente. El transporte sintético 0.2 descrito más abajo sí está aceptado.

## Vincular y recibir sesiones privadas (1.0)

1. Compilar con `./connect_iq/build-dev.ps1`; con el simulador oficial abierto,
   ejecutar `./connect_iq/test-dev.ps1` (ocho regresiones). Instalar solo
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

## Límites y siguiente tramo

En la prueba física la respuesta llegó después del aviso de sesenta segundos.
El aviso no cancela la importación: una respuesta tardía puede instalar y
confirmar el entrenamiento. La instancia bloquea nuevas solicitudes hasta recibir
respuesta o salir. La invitación actual a reabrir debe pulirse para evitar
reintentos innecesarios; no se conoce todavía la causa de la latencia.

Quedan pendientes duplicados/reinicios repetidos, pérdida de conexión, cambios y
retirada, otros relojes, background y retorno de resultados por esta vía. No
presentar Descargar/Abrir como sincronización automática terminada ni exigir
este puente para toda la fuerza.

El único siguiente tramo es vinculación segura y descargas de instantáneas
autorizadas por usuario/revisión, con caducidad, revocación y recuperación. No
llevar tokens Garmin o credenciales administrativas al reloj ni sustituir el
OAuth existente. La experiencia objetivo es vincular una vez y mantener sesiones
al día con Actualizar como recuperación manual. Background/Mobile SDK requieren
prueba específica; no prometer recepción inmediata ni sondeo permanente.

Contrato y evidencia: `docs/DEVICE_GARMIN_TRAINING.md`, INT-016.
