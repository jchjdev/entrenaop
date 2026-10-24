# Avisos profesionales del alumno · 21/10/2026

Actualización TRN-029 · 24/10/2026: la app nativa y Dev preparan transporte push
opcional sobre esta misma bandeja, con consentimiento por cuenta, agrupación y
payload genérico. Está desactivado y la recepción real sigue pendiente de
Firebase/APNs. La descripción siguiente es la instantánea anterior.
[Estado, evidencia y activación](TRAINER_PUSH_NOTIFICATIONS_2026_10_24.md).

## Recorrido y límites

El alumno dispone de una entrada contextual a los recursos de su preparador en
Inicio y una bandeja con acceso a mensajes, formularios, pruebas y técnica.
La presencia de un vínculo vacío no crea esta sección: el servidor comprueba
que hay contenido propio real. Mi preparador conserva la gestión del vínculo.
Las pautas mantienen la agenda y sus ejecutores actuales.

La bandeja guarda avisos de mensajes recibidos del preparador, formularios y
pruebas entregados, comentarios sobre técnica y pautas nuevas o cambiadas. No
anuncia notas privadas de revisión, resultados del alumno ni mensajes enviados
por él. Los títulos se derivan de tipos cerrados en Flutter: el registro de
aviso no contiene cuerpos, respuestas, métricas, nombres privados ni URLs.

No implementa notificaciones push ni recepción con la app cerrada. No registra
dispositivos, credenciales, Firebase, envío por correo ni nuevos proveedores.
La consulta al entrar, actualizar o volver a la sección recupera el estado
persistente del servidor. Una futura entrega push deberá conservar el payload
genérico y resolver el recurso con la identidad vigente.

## Contrato persistente

`trainer_private.student_notices` pertenece exclusivamente al alumno indicado
por `owner_id`. Los triggers derivan esa identidad de la relación y del recurso
de origen. Las tablas privadas tienen RLS y carecen de grants directos para
`anon` y `authenticated`; no hay inserción, cambio de propietario o borrado
libre desde Flutter. Las fachadas públicas son SECURITY INVOKER y delegan en
helpers privados comprobados, con `search_path` vacío y EXECUTE explícito.

Las cuatro RPC exigen sesión no anónima y `p_expected_owner = auth.uid()`:

- `get_my_trainer_notices`: página de 50, filtro por tipo, cursor compuesto
  `created_at/id`, `has_more`, total exacto de avisos propios sin leer y
  existencia de recursos. El total no se calcula desde la página ni cambia
  al filtrar un tipo; incluye avisos históricos cuyo destino se haya retirado.
- `ack_my_trainer_notice`: marca solo el ID indicado. Es idempotente y conserva
  la primera fecha; no consume un aviso posterior ni modifica su recurso.
- `resolve_my_trainer_notice`: vuelve a comprobar recurso y propiedad, devuelve
  un tipo y un identificador autorizados, o `null` si desapareció el destino.
  Las pautas incluyen su fecha para abrir la cita en agenda.
- `list_my_trainer_technique`: página de 50 ejecuciones propias enlazadas a una
  cita `coach` propia y a su asignación. Orden y cursor `started_at/id`.

El índice técnico admite enviar un vídeo antes de recibir comentarios; no
convierte todo el historial personal en historial profesional. Reutiliza el
contexto, subida, permisos, cuotas y comentarios de técnica ya existentes.

Los eventos se insertan en la misma transacción que su fuente. La clave única
`owner_id/kind/source_id/source_revision` evita duplicados; el ID de mensaje,
entrega o comentario ya identifica su operación. Una revisión de planificación
produce otro aviso; cambiar resultados o revisión interna no lo produce.
Abrir la bandeja o resolver un destino no marca lectura. Leer el aviso tampoco
completa un formulario, prueba o entrenamiento.

El adaptador fija el token mediante `authenticatedTrainerRpc`, comprueba la
identidad antes y después de cada petición y envía el propietario esperado.
Una respuesta tardía de A no puede presentarse como datos de B ni confirmar
lectura en su interfaz. Un acuse enviado antes del cambio puede haber llegado
al servidor de A; el reintento mantiene el mismo ID.

## Histórico, baja y borrado

El backfill anuncia únicamente formularios aún respondibles y pruebas pendientes
que se pueden iniciar o continuar. Los mensajes, pautas y comentarios anteriores
se incorporan como antecedentes, sin afirmar que se haya observado una lectura
humana previa. Los formularios ya contestados/inactivos y pruebas terminadas o
retiradas tampoco aparecen como novedades.

La baja normal conserva relación e historial: se siguen consultando mensajes,
formularios, pruebas y técnica propios con sus capacidades actuales. El servidor
de origen decide `can_respond`, `can_start`, `can_edit`, subida y envío. Una pauta
retirada sin ejecución devuelve destino no disponible; no recupera acceso a una
receta privada por conservar un aviso. Retirar la compartición de un vídeo no
oculta la revisión al alumno dueño.

La FK del aviso hacia la relación usa ON DELETE CASCADE. El borrado físico de
esa relación retira solo sus avisos y no añade un bloqueo a la eliminación de
cuentas; finalizar el vínculo mediante `ended_at` no activa esa cascada. Esta
migración no implementa ni amplía la purga de recursos o cuentas existentes.

## Evidencia y estado

Migración nueva: `20261021201558_trainer_student_notices.sql`. La revisión del
historial Dev confirma que está aplicada y las 200 migraciones coinciden.
El ensayo previo de esquema y datos terminó en ROLLBACK; tras aplicar se repite
el contrato con ROLLBACK, sin dejar sus fixtures.

`tools/build_student_notice_contract.py` genera
`build/student-notices-contract-rollback.sql`: prepara datos anteriores a la
migración para comprobar el backfill, ejecuta únicamente el DDL de avisos y el
contrato SQL. El lote ha pasado contra Dev `sxbxfjqgoddzhtcyhalw` el 21/10/2026.
El contrato cubre aislamiento, sesión anónima, propietario esperado, grants/RLS,
reintentos, lectura individual con eventos posteriores, filtro, total exacto,
53 mensajes con fechas empatadas en páginas 50/3, técnica sin feedback, baja,
destino retirado y cascada sin afectar avisos de otra relación.

`tools/test_student_notice_profile_contention.py` acredita cuatro contenciones
locales PG17.6: feedback/borrado de perfil, ambos órdenes y aislamiento RC/RR,
con timeout corto y ROLLBACK de ambas operaciones. Conserva las FK de propietario
y relación: el borrado con historial protegido se rechaza por las restricciones
existentes y la escritura pendiente continúa después del rollback, sin ciclo ni
avisos residuales. El arnés usa RPC/trigger reales y tablas mínimas; no sustituye
el contrato completo de permisos ejecutado en Dev.

Siete pruebas HTTP del adaptador comprueban total canónico, cursor, tipos
cerrados, destino retirado, fecha de agenda e identidad A/B antes y durante
lectura/acuse. La validación Flutter global y la aceptación visual/móvil se
registran en el cierre general. No se acredita aún recepción push, instalación
en dispositivo. La migración se aplicó únicamente en Dev tras el ensayo conjunto.
