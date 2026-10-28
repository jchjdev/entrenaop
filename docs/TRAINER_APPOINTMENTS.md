# Citas con alumnos · TRN-041 · 28/10/2026

## Petición y estado

Javier confirma implementar citas en la agenda, arrastre y avisos al alumno;
Google Calendar queda para después. Migración aplicada exclusivamente en Dev
el 28/10/2026. Análisis limpio y baterías correctas: 1.442 pruebas de la app
(una omitida por plataforma), 299 de Trainer y 316 de ADMIN (dos omitidas por
plataforma). Once contratos SQL con ROLLBACK pasan con el esquema nuevo.
La publicación HTTPS del portal se acredita al terminar el flujo automático.

## Recorrido implementado

- Mantener la agenda actual y sus vistas Mes/Semana/Día/Lista. Incorporar
  «Crear cita» y filtros Todo/Entrenamientos/Citas, conservando los filtros por
  alumno y estado. No sustituir el arrastre deportivo ya implementado.
- En el mes, tiras que distingan texto, icono y color: «Cita · 11:00 · Isabel ·
  Revisión técnica». En la semana, franja sin hora para sesiones y rejilla
  horaria para citas; las sesiones no adquieren hora obligatoria.
- Pulsar una cita abre sus datos y acciones. Arrastrar cambia día/hora,
  conservando duración; modificar por campos ofrece una alternativa accesible.
  En móvil, lista del día con los mismos datos y edición.
- Campos: alumno activo, motivo (120 caracteres), fecha, hora, duración de 15 a
  720 min, zona IANA y lugar/enlace (500 caracteres). El servidor advierte antes
  de conservar citas del autor solapadas; no expone las de otros preparadores.
- La rejilla usa la zona de preferencias del autor (Madrid por defecto),
  convertida en servidor; el arrastre mantiene zona original y duración.
  Rechaza horas civiles inexistentes por cambio de horario. Las citas nocturnas
  se dividen entre días en la semana. Las sesiones siguen en su franja sin hora.
- En la app: Preparador → Citas, próximas/en curso, historial/canceladas y
  detalle desde el aviso. No añade otro bloque a Inicio ni altera Mi plan.
  No inicia el ejecutor, no crea resultados y no se envía a relojes.

## Avisos y recordatorios

Crear, cambiar y cancelar emiten avisos agrupados por cita. Los reintentos del
mismo intento no crean eventos ni notificaciones duplicados. Se reutilizan el
canal personal `other`, agrupación, descanso y control de envíos existentes;
la push no publica motivo, ubicación ni enlaces en la pantalla bloqueada.

El preparador puede sugerir 30 min o 24 h antes. El alumno empieza sin
recordatorio y decide desde la cita; no se cambia su preferencia de recordatorio
diario deportivo. Un trabajo por minuto en Dev encola cada revisión una vez,
con margen de 10 min. Mover, cancelar o apagar el recordatorio invalida un aviso
antiguo al despacharlo. Una cita vencida o relación inactiva no genera un
recordatorio tardío. El descanso puede aplazar o descartar una push ya inútil.

`get_my_trainer_notice_groups_v2` admite el nuevo tipo y recurso. Los feeds
anteriores lo excluyen. El cliente nuevo usa el feed anterior si falta v2.
Solo una instalación actualizada que declare capacidad para su binding vigente
y tenga el canal personal consentido recibe estas push. Reanudar o cambiar de
cuenta revalida la asociación. El listado del alumno refresca al reanudar o
recibir avisos; no añade sondeo permanente.

## Calendarios externos y privacidad

No se conecta Google Calendar ni se exporta `.ics`. Una futura conexión necesita
OAuth, fuente de verdad, permisos, conflictos y revocación; no condiciona esta
agenda.

Solo autor y alumno consultan la cita. El autor necesita MFA también para
leerla; nuevas citas/cambios necesitan servicio vigente y vínculo activo. Se
permite cancelar una cita propia con MFA aunque el servicio haya terminado.
El historial se conserva en consulta. El alumno no modifica cita/participantes;
solo su recordatorio con revisión de cita y preferencia. Compartir citas con
otro preparador requeriría una decisión futura explícita.

## Validación y límites

- Migración `20261028212741_trainer_student_appointments.sql`; permisos y reglas
  verificados mediante `supabase/tests/trainer_student_appointments.sql`, con
  `ROLLBACK`, antes de aplicarla.
- El contrato SQL cubre participantes, MFA, alumno común entre entrenadores,
  revisiones, reintentos, advertencia de solapamiento, arrastre entre zonas,
  consentimiento, apps antiguas, cancelación, relación inactiva y hueco DST.
- Pruebas Flutter de arrastre real con ratón entre días/horas, conservación de
  sesiones, recordatorio optativo, refresco y lectura móvil con texto ampliado.
- El contrato antiguo `trainer_calendar_snapshot_guards.sql` ya fallaba antes
  de esta migración: la vinculación múltiple incrementa la revisión del alumno.
  Su fixture ahora parte de esa revisión y sigue verificando ausencia de
  escrituras de preview/rechazo y el incremento exacto por cada alta de sesión.
- Consulta paginada a 100; el calendario muestra recuento parcial y permite
  cargar más. Una nueva fecha debe estar dentro de los próximos tres años.
- No hay recurrencias, confirmación/rechazo del alumno ni cobro por cita.
- Aceptación física de la push en móvil con la nueva versión pendiente del
  recorrido manual; no se genera otra APK automáticamente ni se compila Xcode.
