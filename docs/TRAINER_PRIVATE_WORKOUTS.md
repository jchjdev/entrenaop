# Sesiones privadas, pautas y resultados · TRN-016 · 21/10/2026

## Recorrido implementado

Javier pide aprovechar Harbiz e implementar el recorrido con nuestros creadores.
El preparador entra en Mis sesiones privadas, crea una receta con el editor
compartido y abre Planificación y resultados de un alumno. Selecciona sesión y
fecha, consulta la receta concreta, añade indicaciones y confirma. El alumno
recibe la pauta en su agenda, ejecuta y registra resultados mediante el motor
existente. El preparador consulta el resultado desde esa pauta, sin corregirlo
en nombre del alumno.

La biblioteca y las pautas tienen paginación. Revisar crea otra versión y archiva
la anterior: no actualiza las pautas existentes. Crear no asigna ni publica en
el catálogo oficial. Se utilizan ejercicios públicos; las subidas profesionales
y sus cuotas no se implementan aquí.

## Reutilización y datos

`trainer_workout_repository.dart` aporta catálogo, guardado, identidad y RPC al
`WorkoutEditorPage` de `workout_editor_ui`. Se reutilizan modelos, validación y
codec de `workout_core`, formatos convencionales y carrera. No hay otro editor.

El lector existente de ADMIN se traslada como `WorkoutTemplateContent` al mismo
paquete. `AdminWorkoutContent` conserva su API como adaptador. Biblioteca y
confirmación profesional utilizan ese lector, no una maqueta ilustrativa.
Sus dependencias transitivas se fijan a las versiones verificadas en ADMIN.

`workout_templates` conserva origen `coach`, dueño preparador, visibilidad
privada, familia y versión. Los constructores/validaciones SQL existentes se
reutilizan mediante contexto interno autorizado, siguiendo el patrón oficial
previo: la receta nace fuera de la cuota personal. `trainer_assignments` fija
etapa aceptada, participantes e indicaciones y enlaza con `scheduled_workouts`.
La cita conserva versión, estado y ejecución; no se crea otro historial.

La app carga solo sus propias citas incluso si la identidad también es ADMIN.
Mi semana muestra las indicaciones y el origen ENTRENADOR y no ofrece la pauta
como cita personal reprogramable. Inicio/agenda conservan TRN-014. Sin pautas no
se añade una sección profesional nueva en Inicio. El historial y la corrección
de resultados del alumno siguen siendo los existentes.

## Permisos, reintentos y baja

Autoría/asignación exigen MFA y acceso profesional vigente en servidor. Consultar
biblioteca, cartera y resultados propios exige MFA; no se inventan reglas
comerciales de pérdida del historial. El consumo asignado no exige Pro y el
vínculo no amplía las cuotas personales Free de 8 ejercicios y 4 sesiones.

Las RPC públicas nuevas son invoker; las operaciones privilegiadas viven en
`trainer_private`. El cliente no escribe recetas coach ni sus hijos directamente.
ADMIN ajeno tampoco obtiene lectura de recetas, citas ni ejecuciones coach por
su permiso general. El resultado profesional se entrega desde su asignación,
sin abrir el historial global del alumno. El motor interno de inicio no tiene
EXECUTE para authenticated.

El alumno inicia desde su cita activa, nunca pasando el ID a inicio suelto,
duplicación o programación personal. Solo ve recetas asignadas o realizadas.
La baja retira pendientes, permite terminar lo iniciado y conserva consulta de
lo realizado y el historial propio del preparador. Descartar después de la baja
no reabre una pauta. Volver requiere la aceptación prevista en TRN-015.

Cada guardado/asignación conserva su UUID de orden al reintentar; reenviar otros
datos con ese UUID se rechaza. El formulario bloquea datos tras una respuesta
incierta. No hay recuperación persistente del borrador profesional al recargar.

Asignación e inicio respetan el bloqueo por alumno existente. Asignar incrementa
la versión interna de membresía: una baja REPEATABLE READ con snapshot anterior
debe reintentar y ver la pauta antes de retirar pendientes. No cambia cupos ni
la revisión administrativa del acceso.

## Verificación · 21/10/2026

Aplicadas solo a Dev `20261021122051_trainer_private_workouts_and_assignments.sql`
y `20261021124130_trainer_workout_read_policy_and_write_index.sql`. Coinciden
181 migraciones locales/remotas. Doce contratos SQL pasan con ROLLBACK: recorrido
nuevo, acceso/cartera/MFA, cuotas, autoría ADMIN, visibilidad, papelera, tipo
histórico, descarte, AMRAP e instrucciones. El contrato nuevo vuelve a pasar
después de aplicar. Cero usuarios, pautas y recetas coach de ensayo restantes.

El runner local acredita 33 contenciones reales en PostgreSQL 17.6: 21 anteriores
y 12 asignación/baja, ambos órdenes y READ COMMITTED/REPEATABLE READ. Para estas
últimas utiliza las RPC reales y catálogo/citas mínimos; recetas, RLS y resultados
completos se verifican en Dev. No equivale a dos móviles por HTTP.

Análisis limpio; 1144 pruebas deportista (una omisión previa), 301 ADMIN (dos
previas), 15 panel y 67 paquete común correctas. Seis regresiones nuevas cubren
reintento, vista previa concreta, receta al revisar, espera de confirmación,
consulta inactiva, resultado AMRAP y 320/1200 px con texto 2×. Agenda prueba indicaciones/acciones.
Ocho capturas reales de widgets cubren biblioteca, ficha, asignación y resultados.
[Ficha de ensayo](visual-audit/trainer-private-workouts-2026-10-21/client-desktop.png).

Los asesores no señalan WARN nuevos. Se corrige la FK nueva sin índice y se
consolida la lectura de plantillas conservando el catálogo anónimo. Quedan INFO
esperados de [índices recientes sin uso](https://supabase.com/docs/guides/database/database-linter?lint=0005_unused_index)
y [RLS sin políticas](https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy)
en el registro privado sin grants. Los avisos anteriores ajenos a este cambio
permanecen fuera de alcance.

La publicación web del panel se acredita por separado. Los cambios del deportista
todavía no están distribuidos; no hay aceptación humana con dos cuentas ni
ejecución en dispositivos. No se declara desplegado en producción.

No incluye programas privados, recurrencia, calendario mensual del preparador,
mensajería, edición de pautas empezadas, purga definitiva, subidas privadas,
algoritmo profesional ni cobros. El único siguiente recorrido recomendado es
programas privados con composición reutilizada y asignación versionada.
