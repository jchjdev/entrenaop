# Garmin Connect · integración directa · INT-005

**Actualización INT-012 · 23/10/2026:** Garmin ya recibe actividades FIT en Dev
y permite asociarlas con revisión explícita a una cita pendiente. La primera
carrera física queda completada desde la app web con resultados reales y sin
duplicar la ejecución. La edición de la biblioteca conserva la versión enviada;
Auto Lap se agrupa por su índice nativo. No amplía otros proveedores, fuerza o
producción. [Estado y límites actuales](DEVICE_GARMIN_ACTIVITY_RETURN.md).


## Estado comprobado · 22/10/2026

La aplicación existente `EntrenaOP Dev` utiliza OAuth 2.0 y Starter. Javier ha
activado Training desde API Tools → API Configuration. Después de recargar esa
página se comprueba **Activity y Training: Enabled y Approved**. Health, Women's
Health y Courses están desactivadas. Activity informa cero endpoints activos.
No se crea otra aplicación ni se borra la existente.

El selector de APIs de Edit está deshabilitado: no sirve para ampliar el acceso.
La configuración se realiza en [API Configuration](https://apis.garmin.com/tools/apiConfiguration).
El [caso del foro de mayo de 2026](https://developerportal.garmin.com/node/2496#comment-2349)
orientó esta comprobación, pero la evidencia actual es la página autenticada
recargada, no la extrapolación del antiguo modelo Evaluation/Production.

Habilitar una API en la aplicación no conecta una cuenta de deportista ni
acredita entrega de carreras o de sesiones al reloj. El usuario puede conceder
solo algunos permisos. Los valores de Client ID y Client Secret se introducen
después con el helper local y se cargan directamente en secretos Edge Dev;
no se imprimen ni se versionan. La autorización real posterior queda comprobada
con tokens cifrados, identidad persistida y permisos efectivos; todavía no se
reciben actividades por esta conexión directa.

## Primer tramo implementado: adaptador OAuth de servidor

`supabase/functions/_shared/garmin/oauth.ts` utiliza HTTP y Web Crypto nativos,
sin paquetes nuevos. No importa Flutter, dominio deportivo ni código de Trainer.
Se contrasta con la especificación autenticada
[OAuth2 PKCE 2.0](https://developerportal.garmin.com/sites/default/files/OAuth2PKCE%202.0.pdf),
páginas 2–6, y con OAuth2 Tools del portal el 22/10/2026.

- Genera `state` y verifier independientes, aleatorios de 256 bits; PKCE S256.
- Construye la autorización en `https://connect.garmin.com/oauth2Confirm` sin
  exponer verifier ni secreto. El retorno HTTPS es configuración del servidor.
- Valida endpoint y state del callback; rechaza parámetros duplicados, retorno
  distinto y mezclas de código/error. **Esta validación no consume un intento
  persistente ni impide por sí sola reutilizar un callback válido.**
- Canjea código/verifier y renueva tokens desde servidor en
  `https://diauth.garmin.com/di-oauth2-service/oauth/token`, con Basic y formulario.
  La renovación devuelve el refresh token nuevo; no hay reintentos automáticos.
- Consulta identidad y permisos en `/partner-gateway/rest/user/id` y
  `/partner-gateway/rest/user/permissions` de `https://apis.garmin.com`.
  `ACTIVITY_EXPORT` acredita lectura autorizada y `WORKOUT_IMPORT` envío autorizado;
  los scopes genéricos del token no sustituyen esa consulta.
- Rechaza tokens/respuestas inválidos, limita la respuesta a 64 KiB y el tiempo
  de petición a diez segundos; no sigue redirecciones ni propaga cuerpos/secretos
  en errores. No interpreta un 400 genérico como revocación del usuario.

Este adaptador lo consumen ahora el servicio de conexión y dos handlers Edge
descritos a continuación. **Publicados y configurados solo en Dev; recorrido
nominal de conexión y desconexión real comprobado desde navegador.** Salud
conserva su persistencia y su acceso Free independientes.

## Segundo tramo implementado: conexión y retirada reales comprobadas

Javier autoriza conectar, autorizar y desconectar Garmin, y aclara que otro chat
está reorganizando Inicio, la pantalla de entrenador y la ubicación de Perfil.
Se conserva su punto de guardado `c53536c7`. Solo se añade una tarjeta dentro
de Perfil y la ruta interna `/profile/garmin`; no se mueve Perfil ni se altera
la navegación general o Trainer.

| Capa | Responsabilidad |
| --- | --- |
| Dominio Dart `lib/features/device_connections/domain` | Estado, problemas y puerto de conexión; sin Supabase, HTTP o SDK de Garmin. |
| Datos Dart | Invocación de la función con cuenta esperada, validación del contrato y descarte de respuestas de otra sesión. |
| Presentación | Cubit/página con autorización externa, recarga al volver a la app, permisos efectivos y confirmación explícita de desconexión. |
| Servicio de aplicación del servidor `connection.ts` | Coordina puertos de proveedor, persistencia y cifrado. No recibe secretos de Garmin desde Flutter ni modifica historial o prescripción. |
| Adaptadores `oauth.ts`, `cipher.ts`, `http.ts` | OAuth/HTTP, AES-GCM y Auth/RPC de Supabase respectivamente. |

La migración local `20261022113416_garmin_account_connection.sql` crea una tabla
privada con RLS, sin permisos de tabla para clientes ni `service_role`. La única
fachada RPC es INVOKER y solo admite `service_role`; el comando privado DEFINER
verifica los invariantes con `search_path` vacío. Los clientes no pueden declarar
propietario, permisos o tokens directamente en SQL.

- `garmin-connection` verifica el JWT contra Auth, cuenta esperada y sesión
  persistente viva. Los inicios exigen Pro efectivo o vínculo activo con un
  preparador cuyo acceso esté vigente. Ser administrador no lo sustituye.
- Se conserva una conexión por cuenta, con generaciones crecientes. Un intento
  dura diez minutos, tiene state aleatorio cuya huella se guarda, verifier
  cifrado y consumo único. Hay treinta segundos mínimos entre nuevos inicios.
- El callback reclama el intento atómicamente. El grant se guarda cifrado antes
  de consultar identidad/permisos; estos se comprueban antes de marcar conexión
  operativa. Una identidad Garmin solo puede pertenecer a una cuenta EntrenaOP.
- AES-GCM usa clave de 32 bytes y nonce nuevo por cifrado. Sus datos autenticados
  incluyen finalidad, propietario y generación/huella del intento; mover un
  ciphertext a otra cuenta o generación impide abrirlo. No se guardan claves
  de cifrado o de cliente en tablas ni en Flutter.
- Desconectar funciona también tras perder Pro: bloquea operaciones nuevas y
  reclama un trabajo de revocación exclusivo de dos minutos. Si el access token
  caducó, renueva y guarda primero el refresh token rotado. Verifica identidad
  y exclusividad antes de `DELETE /partner-gateway/rest/user/registration`.
- Solo una respuesta satisfactoria del proveedor confirma la revocación y limpia
  los tokens. Los fallos permanecen visibles como revocación pendiente; no se
  permite reconectar a ciegas mientras sigue pendiente una retirada.
- Cancelar antes de canjear descarta el intento. Si ya había canje en curso, su
  respuesta no vuelve a activar la conexión y solo puede preparar su retirada.
- El callback devuelve texto plano UTF-8 fijo sin parámetros OAuth y sin redirecciones
  elegidas por el navegador. El usuario vuelve a EntrenaOP y la pantalla recarga
  estado; no se introduce ahora un esquema nuevo de enlaces profundos móviles.

El historial de carreras permanece intacto. Salud y Health Connect mantienen
el acceso para todos de INT-006. Este tramo no recibe actividades, no exporta
recetas y no modifica programas/asignaciones profesionales.

## Activación Dev y aceptación del recorrido nominal

Los handlers están cerrados por defecto con `GARMIN_ENVIRONMENT=DISABLED` y solo
aceptan configuración DEVELOPMENT contra `sxbxfjqgoddzhtcyhalw`. Requieren los
secretos Edge `GARMIN_CLIENT_ID`, `GARMIN_CLIENT_SECRET` y
`GARMIN_TOKEN_ENCRYPTION_KEY`; no van en `dart-define` ni en el repositorio.
`tools/prepare_garmin_dev_secrets.py` permite introducir las credenciales en
Terminal y preparar `.dart_tool/garmin-dev/secrets.env`, ignorado por Git. Solo
la primera instalación usa `--first-setup`; una actualización sin la clave local
previa se detiene y requiere recuperarla en vez de reemplazarla automáticamente.
No envía nada y conserva la clave de cifrado existente; no debe regenerarse
si ya existen tokens cifrados. Javier lo ejecuta con las credenciales de
`EntrenaOP Dev` y confirma que el archivo está preparado; se comprueba que Git
lo ignora y se cargan directamente sus cuatro valores en secretos Edge Dev,
sin imprimirlos. El archivo local se conserva para mantener la clave de cifrado.

Javier autoriza el 22/10/2026 la activación y los ajustes de esta prueba solo en
desarrollo. Se comprueba el destino `entrenaop-dev` (`sxbxfjqgoddzhtcyhalw`), se
aplica únicamente `20261022113416_garmin_account_connection.sql` y se publican
`garmin-connection` y `garmin-oauth-callback`, ambas ACTIVE, versión 1. El historial
de migraciones queda sincronizado. El contrato SQL vuelve a pasar con ROLLBACK;
después se comprueban cero conexiones y cero usuarios sintéticos. Los endpoints
reales responden inicialmente 503 por configuración ausente. Tras cargar los
cuatro secretos Garmin, la función de cuenta rechaza una petición sin sesión
con 401 y el callback sin parámetros rechaza con 400. Se comprueban los cuatro
nombres remotos, sin leer sus valores. La cuenta de Javier tiene Pro efectivo
y acceso Garmin; no se cambia su derecho comercial. La autorización real se
comprueba después en el recorrido descrito a continuación. El asesor de seguridad solo señala para
esta tabla privada RLS sin políticas, intencional al carecer de acceso directo:
se mantiene la fachada exclusiva de servidor. No se modifica producción.

**Único siguiente bloque recomendado:** traducir una prescripción autorizada y
versionada de carrera a Training API, enviarla al calendario Garmin y comprobar
su llegada al reloj. El recorrido nominal de cuenta queda aceptado en navegador;
denegación, cancelación y pérdida de acceso comercial mantienen cobertura
automatizada, sin aceptación manual adicional acreditada en esta sesión.

### Primer intento real y diagnóstico · 22/10/2026

Javier comunica un retorno fallido que muestra HTML sin renderizar y caracteres
mal decodificados. Se contrasta la [limitación de HTML en Edge](https://supabase.com/docs/guides/functions/development-tips):
el dominio estándar transforma HTML en texto. Se cambia el retorno a
`text/plain; charset=utf-8`, manteniendo el callback registrado y sin reflejar
parámetros OAuth. La comprobación HTTP remota confirma texto español UTF-8
legible y 400 para un callback sin parámetros.

El estado observado tras ese intento es desconectado, sin grant o identidad
Garmin conservados. Ese estado no identifica por sí solo la causa del fallo ni
acredita que el usuario haya completado el consentimiento. Para el siguiente
intento se añade diagnóstico de etapa y código cerrado; nunca incluye URL,
state, código OAuth, cuentas, tokens, cuerpos de respuesta ni objetos Error.
Hay cobertura de fallo en canje, identidad, permisos y persistencia, y de la
ausencia de datos privados en mensajes y logs. Ambos handlers se publican en
Dev, versión 4, sin modificar el esquema, las credenciales o Flutter. La causa
del primer fallo no queda identificada; no se atribuye al cambio de presentación
una corrección del protocolo OAuth. No se reutiliza el código ya consumido.

### Autorización real comprobada · 22/10/2026

Javier aporta el retorno «Conexión completada» y la pantalla de EntrenaOP
«Cuenta conectada», con lectura de actividades y envío de sesiones autorizados.
Se contrasta en Dev: estado `connected`, generación 2, `can_read=true`,
`can_send=true`, grant cifrado e identidad Garmin persistidos. La huella del
intento, verifier y claim han quedado limpiados: el intento no es reutilizable.
No se leen ni documentan los valores de tokens o identidad externa.

Después Javier confirma que «Desconectar Garmin» deja la pantalla desconectada.
Dev acredita generación 2 en `disconnected`, ambos permisos desactivados,
tokens/caducidades e identidad externa eliminados e intentos/leases limpiados.
Ese borrado se produce exclusivamente tras una respuesta satisfactoria de
`DELETE /user/registration`, conforme al código desplegado y las regresiones
de retirada fallida; no se hace ninguna limpieza manual para simular el resultado.

Esta evidencia acepta el recorrido nominal conectar/autorizar/desconectar por
cuenta desde navegador. No acredita recepción de actividades, exportación de
recetas, instalación móvil o ejecución en el reloj. La
[CI 39780738347](https://github.com/jchjdev/entrenaop/actions/runs/39780738347)
finaliza correctamente para `4d9dfb215458885518dff3f80a51ea8122793eb8`.

El envío de una primera sesión compatible con Training API será el siguiente
bloque recomendado. No requiere esperar a otros fabricantes,
pero sí traducción de receta, orden/versiones autorizadas y comprobación física.
Javier autoriza después INT-007: [primer envío común de carrera](DEVICE_GARMIN_TRAINING.md),
activo solo en Dev con servidor reutilizable por entrenadores. Después se
acreditan primera entrega y recepción/inicio en fēnix 8 desde iPhone; la revisión
completa de pasos/alertas sigue abierta en ese documento.

### Límites operativos que no acredita esta entrega

Una respuesta incierta del canje o renovación puede dejar revocación pendiente
sin credenciales utilizables; requiere revisión del acceso en Garmin y soporte,
sin marcarla como retirada confirmada ni repetir el canje automáticamente.
Los cambios de permisos/revocación hechos fuera de EntrenaOP todavía no tienen
webhook ni conciliación periódica; la pantalla muestra la última evidencia
guardada. Esos endpoints COMMON se incorporarán al preparar recepción.
Eliminar Auth borra los secretos locales por CASCADE, pero todavía no acredita
retirada en Garmin antes de borrar la cuenta; ese recorrido de limpieza externa
debe resolverse antes de producción. La clave de cifrado tiene versión de
formato, sin rotación automatizada de claves en esta entrega.

## Validación de este tramo

`node --test tests/*_test.ts` desde `supabase/functions`: 93 pruebas correctas,
veintidós de Garmin entre protocolo y conexión. TypeScript 5.9.3 comprueba tipos
estrictos de los cuatro módulos de servidor, sin dependencias nuevas en la app.
La CI `garmin-connection.yml` repite Node/tipos y el consumidor Flutter con su
regresión de Salud, sin cuentas, secretos o despliegues.

Comprobación remota del 22/10/2026: [ejecución 39777384514](https://github.com/jchjdev/entrenaop/actions/runs/39777384514)
correcta para `655a6c5cbe64df3cad72fea6952f88d6a9df160d`, con ambos trabajos
`backend` y `consumer` terminados satisfactoriamente. Incluye análisis Flutter
global, pruebas de conexión y regresión de Salud, pruebas Node y tipos estrictos.
Esta evidencia valida el código preparado; no acredita despliegue ni conexión
con una cuenta Garmin real.

Flutter: diez pruebas nuevas y dieciséis de regresión de Salud correctas;
análisis del módulo y global limpios. La batería raíz final con la entrada y
ruta Garmin sobre el punto de navegación compartido pasa 1270 pruebas con una
omisión previa. No se verifica ADMIN
porque no cambia su código ni paquetes compartidos.

PostgreSQL local real: migración y contrato transaccional, dos callbacks
concurrentes, callback/desconexión en ambos órdenes RC/RR, identidad externa
única entre cuentas y trabajo de revocación exclusivo. El contrato también se
ejecuta sobre Dev con el DDL dentro de `BEGIN`/`ROLLBACK`: se confirma después que
la tabla no existe y quedan cero usuarios `@garmin.invalid` en aquella preparación.
Tras la autorización de activación, la migración queda aplicada, las funciones
publicadas y se repite correctamente el contrato con ROLLBACK, sin conexiones
ni fixtures restantes en esa comprobación inicial. Después se acredita la
autorización y retirada reales descritas arriba; la recepción de actividades
sigue pendiente. INT-007 acredita después el primer envío y recepción en reloj,
con la fidelidad completa de instrucciones y alertas aún en revisión.
