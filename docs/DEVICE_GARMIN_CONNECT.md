# Garmin Connect · integración directa · INT-005

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
solo algunos permisos. No se han leído ni conservado valores de Client ID,
Client Secret, tokens o datos deportivos de cuentas Garmin en esta revisión.

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
descritos a continuación. **No están desplegados ni configurados con claves
reales.** Salud conserva su persistencia y su acceso Free independientes.

## Segundo tramo implementado: conexión por cuenta, pendiente de activar

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
- El callback devuelve texto fijo sin parámetros OAuth y sin redirecciones
  elegidas por el navegador. El usuario vuelve a EntrenaOP y la pantalla recarga
  estado; no se introduce ahora un esquema nuevo de enlaces profundos móviles.

El historial de carreras permanece intacto. Salud y Health Connect mantienen
el acceso para todos de INT-006. Este tramo no recibe actividades, no exporta
recetas y no modifica programas/asignaciones profesionales.

## Activación y aceptación real pendientes

Los handlers están cerrados por defecto con `GARMIN_ENVIRONMENT=DISABLED` y solo
aceptan configuración DEVELOPMENT contra `sxbxfjqgoddzhtcyhalw`. Requieren los
secretos Edge `GARMIN_CLIENT_ID`, `GARMIN_CLIENT_SECRET` y
`GARMIN_TOKEN_ENCRYPTION_KEY`; no van en `dart-define` ni en el repositorio.
`tools/prepare_garmin_dev_secrets.py` permite introducir las credenciales en
Terminal y preparar `.dart_tool/garmin-dev/secrets.env`, ignorado por Git. Solo
la primera instalación usa `--first-setup`; una actualización sin la clave local
previa se detiene y requiere recuperarla en vez de reemplazarla automáticamente.
No envía nada y conserva la clave de cifrado existente; no debe regenerarse
si ya existen tokens cifrados. No se ha ejecutado con secretos reales.

**Único siguiente tramo:** autorizar la activación exclusivamente Dev, aplicar
solo esta migración, cargar secretos y publicar `garmin-connection` y
`garmin-oauth-callback`. Después comprobar con cuenta real: Pro/alumno habilitado
→ Conectar Garmin → autorizar permisos → volver a Perfil → estado y permisos
correctos → desconectar → comprobar retirada en Garmin. Repetir denegación,
cancelación y acceso comercial perdido. No se declara cerrado el recorrido hasta
esa aceptación; compilar/probar con fixtures no la sustituye.

El envío de una primera sesión compatible con Training API será otro bloque
después de aceptar la conexión real. No requiere esperar a otros fabricantes,
pero sí traducción de receta, orden/versiones autorizadas y comprobación física.

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

`node --test tests/*_test.ts` desde `supabase/functions`: 91 pruebas correctas,
veinte de Garmin entre protocolo y conexión. TypeScript 5.9.3 comprueba tipos
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
la tabla no existe y quedan cero usuarios `@garmin.invalid`. No se ha aplicado
la migración ni desplegado las funciones. No hay prueba contra Garmin real.
