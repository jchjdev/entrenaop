# Citas con alumnos · TRN-041 · 28/10/2026

## Petición y estado

Javier solicita poder agendar citas con alumnos, moverlas como las sesiones y
recibir avisos. Plantea Google Calendar, sin decidir aún si conectarlo. Esta
entrega propone el diseño; no crea tablas, permisos, citas reales ni envíos.

## Propuesta visual

- Mantener la agenda actual y sus vistas Mes/Semana/Día/Lista. Incorporar
  «Crear cita» y filtros Todo/Entrenamientos/Citas, conservando los filtros por
  alumno y estado. No sustituir el arrastre deportivo ya implementado.
- En el mes, tiras que distingan texto, icono y color: «Cita · 11:00 · Isabel ·
  Revisión técnica». En la semana, franja sin hora para sesiones y rejilla
  horaria para citas; las sesiones no adquieren hora obligatoria.
- Pulsar una cita abre sus datos y acciones. Arrastrar cambia día/hora,
  conservando duración; modificar por campos ofrece una alternativa accesible.
  En móvil, lista del día con los mismos datos y edición.
- Campos propuestos: alumno, motivo, fecha, hora, duración, lugar/enlace y
  recordatorio. La zona horaria debe ser explícita y el servidor comprobar
  solapamientos; no basta con mover visualmente la ficha.
- En la app, la cita aparecería en Preparador y agenda, con acceso a sus
  detalles. No inicia el ejecutor deportivo, no crea un resultado y no se envía
  a Garmin como un entrenamiento.

## Avisos propuestos

Creación, cambio y cancelación deben producir una sola actualización coherente,
reutilizando preferencias, deduplicación y colas existentes. El recordatorio
queda separado del aviso de cambio. La vista permite elegir sin recordatorio,
30 minutos antes o día anterior como ejemplos de diseño; valores/defaults,
confirmación por el alumno y política de cambios aún no están acordados.

## Calendarios externos y privacidad

Se recomienda empezar con la agenda propia y una descarga `.ics` opcional para
añadir una cita a calendarios externos. No equivale a sincronización: moverla
después en EntrenaOP no modifica necesariamente la copia externa. Una conexión
bidireccional Google necesita OAuth, fuente de verdad, permisos, resolución de
conflictos y bajas de consentimiento; no se activa en esta entrega.

Otro entrenador no debe ver el resto de alumnos del autor. Compartir citas del
alumno común exige concretar qué se comparte; no heredar automáticamente notas
privadas, ubicación o enlaces de una cita del calendario deportivo conjunto.

## Siguiente paso propuesto

Validar este diseño y concretar aceptación del alumno, recordatorios y
visibilidad entre preparadores antes de implementar el recurso de cita. El
bloque comercial sandbox continúa siendo el trabajo principal de esta entrega.
