# Vídeos privados profesionales y técnica del alumno · 21/10/2026

**TRN-046 · 29/10/2026 · Dev:** las demostraciones propias admiten una
solicitud de eliminación desde Vídeos. El servidor protege referencias de
versiones, papelera, borradores, asignaciones e historial; las técnicas ligadas a
una ejecución quedan protegidas. El barrido no elimina demostraciones listas o
en proceso solo porque no estén enlazadas. Sí admite reservas nunca iniciadas,
fallidas o rechazadas con al menos 24 horas, respetando las credenciales de
subida vigentes. Bunny debe confirmar eliminación y ausencia antes de liberar
presupuesto y plaza; el activo permanece como tumba para impedir su reactivación.
Una creación de resultado incierto sin GUID confirmado conserva cuota.
[Contrato y estado](TRAINER_PLATFORM.md#limpieza-protegida-de-medios--trn-046).

**Integración Dev · 21/10/2026:** migración aplicada dentro del conjunto profesional
de diez; 195 migraciones locales/remotas coinciden. Los 24 contratos relacionados
vuelven a pasar con ROLLBACK sobre el esquema aplicado, sin datos de ensayo
persistentes. La publicación web/móvil se acredita por separado.

## Alcance y relación con VID-005

Javier autoriza el desarrollo de los dieciséis puntos de la plataforma profesional,
incluido subir demostraciones y enviar ejecución técnica para recibir correcciones.
Se amplía VID-005 únicamente para adjuntos técnicos de ejecuciones asignadas:
no se habilita una videoteca personal genérica del deportista. ADMIN, preparación
profesional y alumno conservan permisos independientes incluso cuando una misma
cuenta participa en los tres contextos.

El preparador conserva ambas opciones: subir archivo gestionado o pegar una URL
HTTPS externa. El enlace externo continúa validándose por el contrato existente;
no se descarga, importa ni vuelve a alojar. La privacidad de ese alojamiento depende
de su proveedor y no se presenta como una garantía de EntrenaOP.

Implementación del backend en `20261021151727_trainer_private_videos.sql` y
`supabase/functions/_shared/exercise_video.ts`. Esta entrega del agente no aplica
migraciones ni despliega funciones: las consultas de validación terminan con ROLLBACK.
La interfaz y su integración se realizan en el trabajo principal.

## Contextos y autorización

- `official`: administración del catálogo oficial; conserva entrada 20 MiB,
  duración 10 s y MP4 de hasta 5 MiB. La cuota oficial sigue siendo veinte
  reservas por hora y administrador.
- `trainer_exercise`: activo del preparador, reutilizable exclusivamente en
  sus ejercicios profesionales. Autoría con MFA y acceso profesional vigente;
  biblioteca histórica propia con MFA. El alumno lo reproduce por el ejercicio
  de la receta autorizada o su ejecución histórica.
- `client_technique`: alumno dueño, asignación propia, ejecución de esa asignación
  y serie opcional de esa misma ejecución. El servidor deriva el preparador y
  exige servicio activo y acceso profesional vigente para reservar/subir.
  Reproduce el alumno dueño y el preparador de esa asignación con MFA mientras
  esté compartido; el historial no se concede al siguiente preparador.

ADMIN ajeno no puede consultar estado, firmar reproducción/portada ni vincular
el activo a un ejercicio propio. La reproducción siempre verifica el recurso;
ningún bypass global de ADMIN se aplica a medios privados. Solo el autor puede
consultar procesamiento o generar portada. Un clip técnico no puede convertirse
en la demostración de un ejercicio, tampoco por su propio alumno.

Finalizar el vínculo retiene el historial ya compartido; impide nuevas reservas
y nuevas credenciales de subida/recuperación. También impide nuevas respuestas
compartidas del preparador; un acceso profesional desactivado o caducado conserva
lectura con MFA, pero no autoriza respuestas nuevas. Un recibo de respuesta ya
confirmada se recupera con la misma identidad/MFA y payload tras la baja, sin
crear otra respuesta. Cada vídeo pertenece a su episodio de servicio: volver a
aceptar al alumno no reabre la conversación del episodio anterior.
El alumno puede retirar y volver a
compartir cada clip conservando el archivo y las respuestas. La retirada corta
nuevas firmas del preparador, no elimina el objeto ni revoca una firma ya emitida.
La firma de reproducción dura quince minutos; las credenciales TUS una hora.

## Límites técnicos provisionales y presupuesto conservador

Cada preparador tiene presupuestos **separados** para demostraciones y clips de
alumnos: máximo 100 activos y 2 GiB reservados en cada contexto. Los valores viven
en `trainer_private.video_limits`, sin escrituras de cliente. Son límites técnicos
provisionales, no tarifas ni ampliaciones comerciales.

Entrada declarada hasta 100 MiB, duración hasta 180 s y MP4 final hasta 50 MiB.
Cada reserva consume el `source_limit` completo, por defecto 100 MiB, aunque el
cliente declare un byte. Así, con 2 GiB se admiten veinte reservas completas antes
de alcanzar el presupuesto; el techo de cien activos sigue siendo independiente.
Cambiar límites no altera los fijados para activos existentes.

Al finalizar se exige `storageSize` entero positivo reportado por Bunny no superior
a la reserva, además de duración y HEAD del MP4 final. El valor verificado se guarda
en `provider_storage_bytes`; SQL impide un privado listo sin esa comprobación. La
reserva cubre conservadoramente el almacenamiento informado por el proveedor,
incluidas sus representaciones: un archivo de entrada que cumpla el límite puede
ser rechazado si su resultado ocupa más. No se usa el tamaño declarado como prueba.

El TUS directo no permite ligar el tamaño a su firma actual: estas comprobaciones
acotan lo admitido/listo, **no garantizan detener antes de la transferencia una
subida manipulada**. Un proxy verificador o un límite equivalente del proveedor
sería necesario para esa garantía previa. No se amplían capacidades del proveedor
ni se prometen límites de tráfico facturado. Activos fallidos, rechazados,
abandonados y versiones anteriores siguen consumiendo reserva; no hay purga
automática ni liberación ficticia de bytes.

## Reserva, creación externa y estados

La reserva conserva operación, dueño, contexto y payload. El reintento idéntico
devuelve el mismo activo y no consume otra reserva; reutilizar la operación con
otros datos se rechaza. Los bloqueos serializan presupuesto por preparador/contexto;
una actualización del registro de límites también invalida snapshots RR anteriores.

Una creación se reclama una sola vez en servidor: `reserved → creating → created`;
un fallo incierto produce `uncertain`. Un reintento sobre creación ya aceptada
renueva credenciales del mismo ID mientras esté `uploading`. Nunca se emite otra
credencial de subida para `processing`, `ready`, `failed` o `rejected`.

En `creating/uncertain`, el servidor busca en Bunny el título exacto
`EntrenaOP <assetId>`, exige misma biblioteca, resultado completo y una coincidencia.
Así recupera un objeto cuya respuesta se perdió sin repetir POST. Cero resultados,
varios o una página incompleta mantienen `video_creation_uncertain`; se conserva
el activo y su reserva para reconciliación posterior. El error incluye `asset_id`
y la operación cuando procede; no exige al usuario averiguar el ID de Bunny.

La búsqueda utiliza el listado documentado en el
[SDK oficial de Bunny](https://github.com/BunnyWay/bunny-stream-android/blob/main/docs/guides/manage-videos.md#list-and-read).
Solo consulta metadatos: no importa URLs externas ni crea un segundo objeto.

`ready`, `failed` y `rejected` son finales. No hay vuelta de `processing` a
`uploading`. Después de listo, un privado conserva proveedor, URL, duración,
tamaños y contexto; sustituirlo exige otro activo y versión del ejercicio.
Las consultas simultáneas de procesamiento devuelven el estado persistido final,
evitando una respuesta tardía `processing` tras `ready`.

## API para adaptadores

Edge `exercise-video` mantiene `expected_user_id` en cada petición:

- `create`: `scope`, `operation_id`, `bytes`; para técnica también `assignment_id`,
  `execution_id` y opcional `execution_set_id`. No acepta `trainer_id`/`client_id`
  como fuente de autoridad. ADMIN antiguo puede omitir operación; los scopes
  privados la exigen. Los adaptadores nuevos deben conservarla ante errores.
- `recover`: `id`; reconcilia por título exacto sin que el usuario conozca el ID externo.
- `status`: `id`; verifica preparación, duración, almacenamiento y MP4.
- `playback`/`thumbnail`: referencia estable `url`; firma temporal tras autorización.

`create` devuelve credenciales TUS y `scope`, `source_limit`, `duration_limit`,
`playback_limit`. `playback` añade `scope`, `playback_limit`, `duration_limit` a
`url`, `expires`, `cache_key` y `bytes`. El adaptador nativo debe mantener una cota
de 5 MiB para oficiales y de hasta 50 MiB solo para scopes privados reconocidos;
no aceptar una cota arbitraria enviada por el cliente.

RPC públicas invoker, con implementaciones privadas autorizadas:

```
reserve_exercise_video_upload(p_scope,p_operation_id,p_library_id,p_cdn_host,
  p_source_bytes,p_assignment_id=null,p_execution_id=null,p_execution_set_id=null)
get_exercise_video_asset(p_id,p_action='status')
authorize_exercise_video_asset(p_id,p_action)
get_trainer_video_usage()
list_trainer_exercise_videos(p_before_at=null,p_before_id=null)
set_client_technique_shared(p_operation_id,p_id,p_shared)
add_trainer_video_feedback(p_operation_id,p_id,p_second,p_body)
list_client_technique_videos(p_assignment_id)
get_client_technique_context(p_execution_id)
```

`get_exercise_video_asset` devuelve metadatos de un activo autorizado, alcance y
límites sin la reclamación interna. La lista de técnica incluye respuestas,
instante y autor; filtra clips retirados al preparador, pero conserva la vista
del alumno. Respuestas hasta 2.000 caracteres y un instante comprendido en la
duración verificada. Límite técnico configurable de cien comentarios por clip,
en `video_limits.feedback_limit`; no es un precio. Se serializa con la misma
frontera de alumno/acceso/activo y una actualización que invalida snapshots RR.
La lista devuelve `can_feedback`, `feedback_limit` y `feedback_count`, y el panel
impide iniciar otra respuesta si no está habilitada o se agotó la cuota.
Compartición y respuesta son idempotentes por operación.
Las funciones claim/complete/uncertain quedan restringidas a `service_role`.
El listado de demostraciones pagina cincuenta activos propios e incluye reservas
inciertas para poder encontrarlas tras recargar. Los contadores separan ambos
presupuestos y no revelan los clips individuales que un alumno haya retirado.

## Adaptadores y consumo

`ExerciseVideoTransport` comparte entre portales TUS, recuperación del offset,
validación de destino, prohibición de redirecciones y portada JPEG acotada. No
decide permisos ni contexto. `ExerciseVideoClient` comparte el protocolo mediante
callbacks, sin importar Supabase ni otras aplicaciones. `SupabaseTrainerVideoRepository`
implementa el puerto `ExerciseVideoSource`; comprueba identidad antes/después de llamadas y fragmentos,
retiene la operación de reserva tras error incierto y exige los mismos bytes
declarados al reintentar. Un archivo posterior a una reserva confirmada usa otra
operación. No depende de `admin_app`.

El reproductor del deportista valida scope y cota procedentes de la respuesta
autenticada, antes de abrir su caché. Compatibilidad con respuestas oficiales
anteriores: ausencia de scope significa exclusivamente official y cinco MiB.
Los scopes desconocidos se rechazan; privados exigen cota explícita hasta cincuenta
MiB. Conserva proyecto/usuario/activo en la clave y comprueba cambios de cuenta
después de obtener el controlador. Los enlaces externos conservan su camino
existente; no se vuelven recursos de la caché gestionada.

La caché nativa admite clips privados mayores conservando veinte archivos y un
máximo global de cien MiB, mediante recuento de bytes y retirada de los más antiguos.
No se multiplica el almacenamiento local a un GiB por admitir privados de cincuenta
MiB. Web mantiene la caché del navegador, sin promesa de reproducción sin conexión.

`TrainerMediaPage` muestra ambos presupuestos y sus reservas conservadoras, lista
demostraciones con paginación y permite comprobar procesamiento o continuar una
reserva usando el archivo original después de recargar. Admite un callback para
seleccionar un vídeo listo. `TrainerTechniquePage` consulta exclusivamente los
clips compartidos de una asignación y envía una respuesta desde un instante
seleccionado en la reproducción o escrito en el formulario. El formulario retiene
operación y contenido ante un fallo incierto; notas internas siguen separadas.

La app integra `WorkoutTechniqueSection` en el detalle histórico. Primero comprueba
que la ejecución pertenece a una cita coach propia: sin ella no consulta el circuito
profesional ni muestra un apartado vacío. El alumno sube un archivo mediante el
mismo campo con enlaces deshabilitados y elige opcionalmente una serie realizada
de esa ejecución. Puede comprobar o continuar una reserva tras recargar y retirar
o restablecer la compartición. Tras la baja conserva archivos y respuestas, sin
ofrecer envío nuevo. El servidor vuelve a comprobar todos los permisos y contexto.
Al quedar listo un clip se muestra confirmación: no se utiliza el botón de retirar
referencia de un editor como si borrara o dejara de compartir un archivo ya enviado.

## Validación y límites de aceptación

Pruebas HTTP con proveedor simulado y contrato SQL transaccional cubren los tres
alcances, ADMIN ajeno, MFA, vinculación a ejecución/serie, reserva conservadora,
reintento, recuperación ambigua, estados finales, bajas, retirada reversible y
respuesta temporal. Se contrasta también el contrato Bunny previo para conservar
los límites oficiales. No acreditan subida/reproducción real, credenciales TUS
contra abuso en el proveedor, instalación móvil ni aceptación humana de dos cuentas.
No se habilita producción, se suben archivos reales ni se modifican secretos.

Resultados focalizados: 27 pruebas HTTP, siete del adaptador/transportes, cuatro
de las páginas de medios/correcciones, cuatro del repositorio técnico del alumno,
cuatro de su sección contextual y nueve de autorización/caché del deportista
correctas. Se conservan seis regresiones de historial y quince de vídeo de ADMIN;
las 78 pruebas previas del paquete común pasan y tres nuevas comprueban reproducción
bajo demanda y descarte de autorización tardía al cambiar/cerrar el recurso.
Nueve contratos SQL pasan juntos
con migración temporal y ROLLBACK: vídeo privado, Bunny oficial, ejercicios,
sesiones, programas, cartera, MFA, relaciones y cuotas personales. El runner
`tools/test_trainer_video_concurrency.py` acredita 36 contenciones observadas en
PostgreSQL17 local: demostraciones y alumnos distintos compartiendo presupuesto,
última reserva, operación idéntica, cuota/reintento de comentarios y snapshots
READ COMMITTED/REPEATABLE READ.
Utiliza las RPC reales con catálogo mínimo; RLS y contenido completo se verifican
en el contrato SQL de Dev. No equivale a dos cuentas humanas con archivos reales.
