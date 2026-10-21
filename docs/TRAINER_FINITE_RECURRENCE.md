# Series profesionales finitas · 21/10/2026

**Integración Dev · 21/10/2026:** migración aplicada dentro del conjunto profesional
de diez; 195 migraciones locales/remotas coinciden. Los 24 contratos relacionados
vuelven a pasar con ROLLBACK sobre el esquema aplicado, sin datos de ensayo
persistentes. La publicación web/móvil se acredita por separado.

Ampliación acordada para facilitar tareas repetidas sin crear procesos que
generen entrenamientos indefinidamente. Se planifica una sesión privada durante
**1–12 semanas**, eligiendo un lunes inicial y días de la semana **1–7**. El
preparador revisa destinatarios, todas las fechas y coincidencias antes de crear.
No hay cron, algoritmo nuevo, progresión automática ni envío externo.

## Contrato y límites

Se conserva una versión concreta de sesión para todas las citas de la serie.
Se materializan juntas mediante el motor existente, como máximo **100 alumnos
y 256 citas totales** por orden. Por ejemplo, lunes y miércoles durante dos
semanas para dos alumnos crea ocho citas. Cada alumno continúa usando agenda,
ejecutor e historial actuales; Pro y las cuotas personales no se modifican.

El límite de semanas no define un nuevo plan comercial. Si la selección supera
256 citas, se debe reducir alumnos, semanas o días; no se crea una parte de la
serie ni se añaden semanas silenciosamente.

RPC públicas, con delegación invoker y controles profesionales en servidor:

```text
preview_trainer_recurrence(
  p_recipients jsonb, p_template_id uuid, p_week_start date,
  p_weeks integer, p_weekdays integer[], p_note text = null
) -> {fingerprint, assignment_count, recipients, preview, ...}

create_trainer_recurrence(
  p_operation_id uuid, p_recipients jsonb, p_template_id uuid,
  p_week_start date, p_weeks integer, p_weekdays integer[],
  p_note text, p_fingerprint text
) -> {series_id, assignment_count, recipients: [...assignment_ids]}

list_trainer_recurrences(p_before_at timestamptz = null, p_before_id uuid = null)
  -> hasta 50 series propias, con fechas, versión, recuento total y pendientes

preview_trainer_recurrence_withdrawal(p_series_id uuid, p_from_date date)
  -> {fingerprint, items, excluded_count}

withdraw_trainer_recurrence(
  p_operation_id uuid, p_series_id uuid, p_from_date date, p_fingerprint text
) -> {cancelled_count}
```

Los destinatarios son explícitos `{client_id, relation_id}`. Se reutiliza
`prepare_batch` para validar cartera, vínculo activo y propiedad de sesión;
no se expande un grupo durante la confirmación. Los días se ordenan, sin admitir
duplicados, ausencias o valores fuera del intervalo. La receta debe continuar
disponible al confirmar; revisar la biblioteca después no reescribe las citas
ya creadas.

El preview muestra los nombres propios de la cartera y las fechas calculadas.
De otras citas solo se muestra presencia por fecha, sin nombres ni recetas
personales. La huella incluye esa presencia, destinatarios, receta y parámetros.
Si cambian las coincidencias entre revisar y confirmar, se exige revisar otra
vez. El preview no reserva agenda ni evalúa carga deportiva u horarios.

## Retirada controlada

Retirar una serie exige **una fecha civil explícita** y una segunda vista previa
del conjunto actual. Solo cambia a retiradas las citas de esa serie desde la
fecha elegida, incluida ella, que sigan pendientes y sin ejecución.

No se interrumpe una sesión iniciada, no se borra historial y no se finaliza el
vínculo del alumno. Tampoco se tocan sesiones sueltas, programas ni citas de
otra serie. El preview explica los registros excluidos por su estado. Si alguien
empieza o termina una sesión después del preview, cambia la huella y no se
retira ninguna cita hasta revisar de nuevo.

Todas las mutaciones bloquean clientes en orden UUID antes del acceso
profesional compartido, como los envíos conjuntos. Crear reutiliza el motor
interno de receta fijada; retirar vuelve a comprobar estado y ejecución justo
al actualizar. Las lecturas exigen propiedad y MFA; escribir requiere además
acceso profesional vigente. Las tablas privadas tienen RLS y no reciben grants
de cliente. ADMIN ajeno y alumnos no acceden a las series profesionales.

## Reintentos y aplicación

UUID y payload se conservan mientras el resultado de una creación o retirada
sea incierto. Repetir devuelve el recibo original; no recalcula nuevas fechas ni
da por retiradas citas distintas. Una respuesta definitiva de validación o
revisión permite volver a preparar con un UUID nuevo. Las fechas viajan como
componentes civiles con `trainerCalendarDate`, sin conversión UTC.

El portal incorpora `TrainerRecurrencePage` y dos diálogos propios de la tarea,
reutilizando catálogo, modelos de destinatarios, resumen de entrega y lector
`WorkoutTemplateContent`. La creación de sesiones sigue en el editor compartido.
La selección requiere fechas/días explícitos y una revisión antes de confirmar;
tras respuesta incierta los datos quedan congelados para el reintento.

## Evidencia y límites

Migración nueva `20261021155333_trainer_finite_recurrence.sql`, creada con CLI.
`supabase/tests/trainer_finite_recurrence.sql` pasa en Dev junto a sus dependencias
dentro de una transacción terminada en ROLLBACK. Acredita límites, fechas,
presencia sin revelar recetas personales, huellas, recibos, receta histórica,
retirada desde fecha, conservación de iniciada/completada y cita independiente,
ausencia de baja e aislamiento de alumno/ADMIN/MFA.

Siete pruebas de widgets/dominio cubren preview obligatorio, payload inmutable,
UUID y huellas estables al reintentar, nueva revisión tras conflicto y tamaños
320/1200 px con texto 2×. No se acredita despliegue, instalación móvil o aceptación
humana. `tools/test_trainer_planning_concurrency.py` acredita las contenciones
reales específicas de creación, coincidencias, retirada/inicio/baja y corrección
independiente, en READ COMMITTED y REPEATABLE READ con tres repeticiones. La
migración posterior `20261021161302_trainer_calendar_snapshot_guards.sql` añade
revisión privada de agenda para rechazar también snapshots RR antiguos,
incluyendo agendas sin contador previo. Los casos de dos preparadores con
carteras distintas terminan sin bloqueo mutuo. No sustituye la prueba de RLS y
recetas completas en Dev ni acredita publicación persistente.
