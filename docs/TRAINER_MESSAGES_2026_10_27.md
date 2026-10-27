# Avisos de conversación y retirada desde agenda · 27/10/2026

Javier pide poder retirar desde el calendario y saber cuándo escriben sus alumnos,
sin refrescar manualmente cada conversación. El alcance se limita a Trainer y al
componente de conversación compartido mediante parámetros opcionales.

## Comportamiento

- La tira del calendario abre un detalle con **Retirar sesión** cuando la pauta
  sigue pendiente y sin ejecución. Las fichas inferiores ofrecen la misma acción.
  Se confirma alumno/sesión y se reutiliza `cancel_trainer_assignment`: no se borra
  la receta ni se omiten las protecciones del servidor o la retirada de Garmin.
  Las retiradas se consultan con el filtro ya existente; archivo y borrado
  protegido conservan su circuito.
- Trainer consulta un resumen de mensajes sin leer cada 30 segundos en primer
  plano y al regresar a la ventana. Conversaciones muestra un globo con el total;
  la campana solo aparece si hay pendientes. Abre un listado por alumno y etapa
  con acceso directo a la conversación exacta, incluidas etapas anteriores.
  La bandeja limita el listado a 50 etapas; su total incluye todas.
- Cada conversación abierta consulta respuestas cada 15 segundos, sin indicador
  de carga continuo, conservando borrador, reintento idempotente y páginas ya
  cargadas. Las consultas no se solapan. Se pausan con la pestaña oculta o una
  ruta encima; vuelven al recuperar primer plano. El botón manual sigue disponible.
  Si llegan más de 50 mensajes sin solapamiento con lo cargado, se reinicia la
  página y su cursor para no ocultar un hueco de historial.
- Solo los mensajes recibidos y cargados en una conversación visible generan
  recibos. No se marca nada al abrir la campana ni al consultar el resumen. Se
  contabilizan los mensajes históricos que aún no tienen recibo. No existe envío
  push al navegador ni aviso con Trainer cerrado en esta entrega.

## Datos y aislamiento

`trainer_private.message_reads` guarda un recibo por preparador y mensaje,
con RLS activado y sin acceso directo de clientes. No se utiliza un cursor de
fecha: un envío concurrente con el mismo timestamp seguirá pendiente. Las RPC
públicas son invocadoras; las funciones privadas verifican identidad esperada,
MFA y autoría de la relación para todos los IDs antes de escribir. ADMIN ajeno,
otro preparador y el alumno no pueden consultar la bandeja ni generar recibos.
Los cuerpos de mensajes no se incluyen en el resumen.

Las migraciones `20261027180409` y `20261027180636` están aplicadas exclusivamente
en Supabase Dev (`sxbxfjqgoddzhtcyhalw`). La segunda indexa la FK de mensaje para
su limpieza en cascada. El contrato SQL `supabase/tests/trainer_message_inbox.sql`
termina con ROLLBACK y comprueba aislamiento, MFA, tabla cerrada, recibos
idempotentes, mensajes propios excluidos, llegada posterior y consulta histórica.
La prueba no deja mensajes ni cuentas de ensayo.

El refresco es optativo en `ConversationView`: Trainer y la conversación del
alumno lo activan con sus propios adaptadores. Se conserva la separación de
avisos del alumno y avisos del preparador; la app móvil requiere una nueva
instalación para recibir este cambio.

## Validación y publicación

Comprobaciones locales: análisis global, ADMIN, Trainer, componente visual y
adaptador móvil sin incidencias; batería completa de la raíz con 1.379 pruebas
correctas y una omisión previa; ADMIN 316 correctas y dos omisiones previas;
`entrena_ui` 31, `trainer_access` 21 y Trainer 264 correctas. Las pruebas de
Trainer cubren campana/acceso directo/lectura en 360 y 1.500 px, pausa oculta,
retirada desde la tira y bloqueo de sesiones iniciadas. Las del componente común
cubren además consulta lenta sin solapamiento, navegación que tapa la conversación,
conservación de borrador y paginación. La versión pública se acredita tras el
flujo automático y su verificador HTTPS.

El contrato SQL se ha ejecutado contra Dev con ROLLBACK, incluyendo además dos
preparadores con el mismo alumno, lote mixto sin escritura parcial, límite de
50 IDs y denegación anónima. `supabase migration list --linked` confirma que
ambas migraciones coinciden con el historial remoto, sin diferencias. El asesor
solo señala para la nueva tabla su RLS privado sin políticas (sin grants
directos) y el índice de limpieza todavía sin uso: no se abren políticas para
silenciar esos INFO. Las comprobaciones no envían mensajes de ensayo a usuarios
reales ni acreditan recepción física desde dos dispositivos.


Publicación Dev verificada el 27/10/2026: fuentes
`743e06b2e202532d4885e5c48ee18d74e952e406`. Trainer: run `40558232070`, release
`743e06b2e202532d4885e5c48ee18d74e952e406-40558232070-1`; ADMIN: run `40558232095`,
release `743e06b2e202532d4885e5c48ee18d74e952e406-40558232095-1`. Ambos manifiestos
HTTPS corresponden a development y `sxbxfjqgoddzhtcyhalw`; los verificadores de
cada portal comprueban identidad, revisión, entrada, SHA-256 y cabeceras. La app
del deportista está preparada en fuentes; esta publicación web no acredita una
nueva instalación móvil ni la prueba humana de conversación entre dispositivos.


## Globos por alumno y preparación de iPhone · ampliación del 27/10/2026

Javier confirma el contador global y pide también un globo en cada alumno.
Las tarjetas de Conversaciones y Alumnos comparten el mismo resumen consultado
por TrainerShell, mediante `TrainerMessageInboxScope`. No arrancan temporizadores
ni consultas por tarjeta. El globo desaparece con cero pendientes, se actualiza
con la lectura y abre la etapa pendiente más reciente, aunque sea histórica.
La tarjeta de Conversaciones abre también esa etapa cuando tiene mensajes.
La ficha de Alumnos conserva su acceso habitual; su globo abre el chat aparte.

La migración `20261027183209` añade al JSON autorizado un resumen completo por
alumno: contador acumulado de todas sus etapas y UUID de la más reciente con
pendientes. Conserva firma, identidad esperada, MFA y grants. No cambia tablas,
recibos ni mensajes. Las cincuenta etapas máximas de la bandeja global no
recortan el contador por alumno. El contrato transaccional añade 55 etapas del
mismo alumno y comprueba ambas proyecciones y el acceso correcto.

La app del deportista ya contiene el refresco optativo a 15 segundos y clave
por relación. Dos regresiones sobre su pantalla real verifican borrador,
respuestas automáticas, pausa/reanudación y separación de preparadores. El flujo
`tools/prepare_iphone_dev.sh` y su ensayo sin firma conservan Release Dev,
metadatos de revisión, lockfile y esquema Runner iPhone. Javier actualiza el
Mac, compila e instala con Xcode; esta tarea no modifica firma ni configura
APNs/Apple Developer. Los push reales de iPhone siguen aplazados.


Validación de la ampliación: análisis global, Trainer y ADMIN sin incidencias;
raíz 1.381 pruebas correctas y una omisión previa, Trainer 269, ADMIN 316 y dos
omisiones previas, y `trainer_access` 22. Cinco nuevas regresiones verifican los
globos en Alumnos/Conversaciones a 360 y 1.500 px, su actualización sin reconsultar
cada tarjeta, desaparición a cero y navegación a la etapa histórica pendiente.
El contrato SQL ampliado termina correctamente con ROLLBACK en Dev y el historial
de migraciones coincide. El ensayo `tools/test_prepare_iphone_dev.sh` pasa con
herramientas simuladas; el XML del esquema confirma Run Release y PosixSpawn.
No se presenta ese ensayo como una compilación nativa de iOS.


Publicación de la ampliación comprobada por HTTPS el 27/10/2026: revisión
`4de7eb70f8502475be0e6b2251da9e9e9b81c4fa`, Trainer run `40562080685` y ADMIN run
`40562079954`, validación y despliegues correctos. Releases
`4de7eb70f8502475be0e6b2251da9e9e9b81c4fa-40562080685-1` y
`4de7eb70f8502475be0e6b2251da9e9e9b81c4fa-40562079954-1`; ambos verificadores
confirman revisión, identidad Dev, entrada, hash de recursos y cabeceras contra
`sxbxfjqgoddzhtcyhalw`. La prueba física del chat y la instalación en iPhone siguen
siendo el recorrido de aceptación de Javier indicado en IOS_DEVELOPMENT.md.
