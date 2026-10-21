# Grupos, entrega conjunta y copia semanal · 21/10/2026

Contrato de servidor implementado en la nueva migración
`20261021153508_trainer_groups_and_week_copy.sql`. Se ha ensayado junto a su
dependencia operacional en Supabase Dev dentro de una transacción terminada
con `ROLLBACK` y después se ha aplicado en Dev con sus dependencias.
Los 24 contratos del conjunto vuelven a pasar sobre el esquema aplicado,
sin datos de ensayo persistentes. La publicación de interfaz se acredita aparte.

## Grupos de cartera

Un grupo pertenece a una identidad profesional y contiene exclusivamente
clientes de su cartera. Puede conservar personas inactivas; eso no las reactiva
ni permite asignarles entrenamientos. Cada cambio de nombre o miembros incrementa
su revisión. No hay categorías oficiales, permisos administrativos ni Pro nuevo.

- `save_trainer_group(p_operation_id uuid, p_id uuid,
  p_expected_revision bigint, p_name text, p_client_ids uuid[])` devuelve
  `{id, revision}`. Crear usa revisión esperada cero y UUID propio estable.
  Nombre de 1–100 caracteres; hasta 100 miembros explícitos sin duplicados.
  Grupo vacío permitido. Reintento idéntico devuelve el recibo original, aunque
  después haya nuevas revisiones; cambiar el contenido de la orden se rechaza.
- `list_trainer_groups(p_before_at timestamptz = null,
  p_before_id uuid = null)` devuelve hasta 50 grupos propios, con `id`, `name`,
  `revision`, `updated_at` y `members`. Cada miembro incluye `client_id`,
  `client_name` y `relation_id` activo o null. Cursor por fecha e ID, ambos juntos.

No se fija un nuevo límite comercial de número de grupos ni se añaden aquí
archivo/borrado de grupos. La membresía se protege además mediante claves
foráneas compuestas contra la cartera del mismo preparador.

## Envío conjunto explícito y atómico

`preview_trainer_batch` y `deliver_trainer_batch_reviewed` reciben los mismos
parámetros de contenido; entregar añade delante `p_operation_id uuid` y exige
`p_fingerprint text` devuelto por la vista previa:

```text
p_recipients jsonb,
p_template_id uuid = null,
p_date date = null,
p_program_id uuid = null,
p_entries jsonb = null,
p_note text = null,
p_group_id uuid = null,
p_group_revision bigint = null
```

`p_recipients` es una lista explícita de `{client_id, relation_id}`. Se elige una
sesión con fecha o un programa con sus entradas existentes `{phase, session,
date}`. La orden no admite las dos modalidades a la vez. No transforma grupos
en destinatarios de manera oculta al confirmar. Si se aporta grupo, su revisión
y el conjunto exacto de miembros deben seguir coincidiendo: en caso contrario
se exige volver a revisar el envío. Todos los vínculos deben estar activos y ser
del preparador; cada alumno sigue teniendo un único preparador activo.

La previsualización devuelve `fingerprint`, `recipients`, `assignment_count` y `preview` por
alumno con nombre, fechas y `coincidences`. Las coincidencias indican únicamente
presencia por fecha de otras citas pendientes/en curso, incluidas las propias;
no revelan nombres ni recetas personales. No constituye una reserva, diagnóstico
de carga o comprobación de solapamiento horario. El servidor vuelve a validar
destinatarios y recetas al entregar. También exige la misma huella de fechas y
coincidencias: un cambio obliga a revisar de nuevo antes de crear ninguna cita.
Los planes existentes se conservan. La migración posterior
`20261021161302_trainer_calendar_snapshot_guards.sql` revoca ambas capas del
envío antiguo sin huella; no queda disponible como bypass desde clientes.

La entrega devuelve:

```text
{
  recipients: [{
    client_id, relation_id,
    assignment_ids: [...],
    program_delivery_id: UUID o null
  }],
  assignment_count
}
```

La tanda es **atómica**: un fallo en cualquier destinatario revierte todas las
citas y su recibo. No hay estados de éxito parcial ocultos. Límite técnico por
orden: **100 alumnos y 256 citas totales**, sumando todos los destinatarios.
Se reutilizan el motor de asignación y los programas privados existentes; no se
crea otro ejecutor. Las sesiones sueltas deben estar publicadas en la biblioteca
privada del preparador; las recetas ya fijadas por un programa conservan su versión.

El consumidor conserva UUID, destinatarios, orden de la lista y contenido durante
un reintento incierto. Tras confirmar, repetir la orden devuelve los mismos IDs
incluso si después cambia el grupo o una pauta. Cambiar datos bajo el mismo UUID
se rechaza. Los UUID de grupos, envíos y copias comparten el registro de órdenes
de esta ampliación y no deben reutilizarse para otra operación.

## Copiar una semana completa

- `preview_trainer_week(p_week_start date, p_offset_days integer)` recibe un
  lunes y un desplazamiento múltiplo de siete distinto de cero. Devuelve
  `fingerprint`, `week_start`, `offset_days`, `items` y `excluded_count`.
- Cada elemento incluye la pauta original, alumno, vínculo, receta fijada,
  fecha de origen, `target_date`, revisión e indicaciones. Solo son elegibles
  pendientes sin ejecución de vínculos activos. La vista previa explica cuántas
  pautas quedan excluidas por su estado o vínculo.
  `has_date_coincidence` indica únicamente si hay otra pauta pendiente/en curso
  en la fecha destino. No revela sus nombres, recetas ni horarios.
- `copy_trainer_week(p_operation_id uuid, p_week_start date,
  p_offset_days integer, p_fingerprint text)` exige la misma huella preparada.
  Devuelve `assignments` con `{source_assignment_id, assignment_id, client_id,
  relation_id, date}` y `assignment_count`.

Se consulta **toda la semana**, sin depender de la página de 100 citas cargada
por el portal ni de sus filtros visuales. La huella incluye también pautas
excluidas y estado de vínculo: una pauta nueva, inicio, baja o edición posterior
obliga a revisar de nuevo. Si el conjunto cambió, no se copia ninguna cita.
La señal de coincidencia también forma parte de la huella; no reserva la agenda
del alumno ni sustituye ninguna pauta personal.
No se confirma una copia vacía. Se aplican los mismos límites de 100 alumnos y
256 citas; una semana mayor debe dividirse en envíos explícitos.

Las originales se conservan. La copia crea citas independientes manteniendo
receta e indicaciones, también si la versión fijada se archivó en la biblioteca.
Ese acceso a recetas archivadas solo lo utiliza el motor interno y exige la
misma propiedad. No se reconstruyen desde la receta más reciente ni se crea
silenciosamente otro seguimiento del programa; sus indicaciones se mantienen.
El recibo confirmado sigue siendo recuperable mediante su orden original,
aunque después alguien empiece una pauta.

Las fechas son civiles SQL `date`. El cliente debe serializar sus componentes
con `agendaDate`, sin convertirlos a UTC ni sumar horas para cambiar días.

## Aislamiento y bloqueos

Todas las lecturas profesionales exigen MFA y propiedad. Escribir exige además
acceso profesional vigente. ADMIN ajeno y alumnos no reciben lectura de grupos,
órdenes ni recetas de otros preparadores. Las tablas privadas tienen RLS sin
grants de cliente; la API pública es invoker y las funciones internas controlan
identidad y recursos. El helper de preparación no es ejecutable por authenticated.

Las mutaciones adquieren primero los advisory de clientes en orden UUID y luego
el acceso profesional compartido. Los motores existentes reutilizan esos locks.
Modificar grupos invalida `membership_version`, de modo que una transacción
REPEATABLE READ que preparó una membresía antigua debe reintentar. Al copiar se
recomprueba el conjunto de clientes después del bloqueo y se rechaza si apareció
uno nuevo, evitando adquirir locks adicionales fuera del orden establecido.

## Verificación y límites de la evidencia

`supabase/tests/trainer_groups_and_week_copy.sql` acredita propiedad/MFA,
versiones de grupo, destinatarios fijados, límites 100/256, recibos estables,
entrega de sesión y programa, un fallo inducido después de la primera entrega
con rollback completo y copia de **101 pautas** con recetas archivadas. Comprueba
invalidación de huella tras inicio/baja y conservación de originales.

La prueba termina con ROLLBACK. Esta verificación acredita el contrato SQL de Dev;
no acredita interfaz integrada, instalación móvil ni uso humano con varias cuentas.
`tools/test_trainer_planning_concurrency.py` ejecuta las RPC y triggers reales
en PostgreSQL 17 temporal: 276 contenciones y 30 solapes independientes correctos
en READ COMMITTED y REPEATABLE READ, con tres repeticiones por caso. Incluye
cambio de grupo frente a entrega, coincidencias nuevas, inicio frente a copia,
copia de 101 citas, reintentos estables y perfiles bloqueados/borrados. Su motor
deportivo mínimo no sustituye la prueba de permisos y recetas completa en Dev.
No se cambian cobros, precios, algoritmo o producción.
