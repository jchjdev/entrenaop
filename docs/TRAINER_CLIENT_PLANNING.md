# Planificación desde la ficha del alumno · TRN-031

## Recorrido acordado el 25/10/2026

La tarjeta del alumno abre su planificación. En escritorio, la biblioteca privada,
el calendario y el detalle trabajan en contexto; con menos ancho se usan los
mismos botones de asignación y el detalle se abre en una ventana desplazable.
Las sesiones y programas se eligen para ese alumno y día, sin otro selector de
cliente. Arrastrar prepara la misma confirmación que pulsar; no escribe una pauta
por sí mismo. Crear abre el editor y checkpoint existentes mediante `push`,
conserva el calendario debajo y devuelve el ID confirmado para revisar la pauta.
El programa recibe el mismo retorno contextual, sin copiar su creador.

La ficha conserva resultados, técnica, evolución, formularios, conversación,
notas e historial. Objetivos tiene ruta propia. Resultados/técnica se normalizan
a rutas propias conservando los enlaces anteriores; cambiar de área abandona la
ruta correctamente y consulta la protección de salida. Un guardado de objetivo
incierto solo permite permanecer o confirmar la misma operación antes de salir.
Adaptadores equivalentes de la misma cuenta no descartan ese contenido.

## Uso: oposición y marcas objetivo

La oposición se introduce como título del objetivo del servicio, no como una
selección de convocatoria oficial con baremos automáticos. En Alumnos → ficha →
Objetivos → Definir objetivo se escribe el título, se elige la fecha opcional y
se puede guardar sin metas ni baterías.

Para incorporar marcas se prepara una batería reutilizable: un conjunto de
pruebas con condiciones explícitas. En Pruebas y simulacros → Crear batería se
escribe el título (por ejemplo, «Evaluación Policía Nacional»), se definen las
pruebas privadas, sus instrucciones, unidad, dirección favorable, resolución e
intentos, y se pulsa Guardar versión. No hace falta asignarla ni que el alumno
la complete para fijar una meta.

Después, en Objetivos del alumno, se selecciona una Prueba de tus baterías,
se pulsa Añadir meta y se escribe su valor (por ejemplo, carrera 1000 m en
`3:50` o diez dominadas). Guardar objetivo conserva metas distintas para cada
alumno aunque reutilicen el protocolo. Asignar la batería es un paso posterior
para evaluar; las entregas completadas alimentan última/anterior/mejor marca.
Los tiempos admiten `m:ss` o segundos. Una marca objetivo no es un resultado
real del alumno ni una puntuación oficial.

## Calendario y permisos

La semana usa fechas civiles, también al cambiar de horario o mes. Las pautas
propias y compartidas se reúnen por ID de cita, nunca por nombre o posición.
La consulta propia filtra alumno y periodo en servidor; no recorre toda la cartera
ni el historial para encontrar una semana. Cada página devuelve hasta 50 citas,
cursor compuesto fecha/ID e indicador de continuación. La interfaz identifica
una semana parcial y ofrece cargar el resto de cada fuente.

La compartición sigue el contrato de [varios preparadores](TRAINER_MULTI_COACH_2026_10_24.md).
Solo se consultan calendario y recetas ajenas cuando el alumno lo permite, el
vínculo está activo y el profesional tiene acceso vigente y MFA. Si no comparte,
la ficha muestra las pautas propias. Una consulta fallida/revocada elimina las
pautas ajenas; las respuestas tardías de otro alumno no se incorporan a la ficha.
No se comparten cartera, medios, conversaciones, notas ni resultados de otro
preparador. Una selección ajena no tiene acciones de edición ni arrastre.

Mover usa la previsualización y huella existentes; adaptar abre la recuperación
privada y no modifica la biblioteca. Una ejecución iniciada no se mueve/adapta.
Los resultados y la técnica se abren únicamente sobre pautas propias. Comentar
una pauta obtiene su vínculo real en servidor y conserva ese contexto.
Varias pautas ese día producen un aviso para revisar la carga, no un diagnóstico
de interferencia ni una sustitución automática del plan personal/EntrenaOP.

## Objetivo de oposición del servicio

Una pareja preparador/alumno conserva un objetivo vigente por revisión:
título de convocatoria/preparación de hasta 120 caracteres, fecha civil opcional
y hasta 40 metas. La fecha no se deduce de información personal ni de un texto.
Cada meta selecciona un protocolo propio ya guardado en una batería. El servidor
fija su instantánea completa: unidad, dirección, resolución, versión y huella.
No permite cambiar unidad o fabricar huellas enviando JSON. Los tiempos reutilizan
`parsePerformanceTime`; cero válido, ausencia e intento nulo siguen separados.

La comparación usa evaluaciones completadas propias del mismo alumno, huella,
unidad, dirección y resolución. Muestra la última evaluación y la anterior para
entender el cambio; el mejor registro consultado queda como referencia distinta.
Si la última evaluación solo tuvo intentos nulos no se rescata una marca antigua
como actual. Solo se consideran las últimas 200 evaluaciones completadas del
servicio y se declara cuando el historial es parcial. No se interpreta como
aptitud oficial, puntuación, diagnóstico o marca de otro protocolo.

Los objetivos no forman parte del consentimiento de calendario y no se abren
al otro preparador. Tampoco sustituyen los objetivos personales del deportista.
Esta entrega gestiona el objetivo en el portal profesional; la app del alumno
mantiene su agenda, ejecución, historial y sección Preparador existentes.

## Datos y continuidad

`trainer_private.client_goal_versions` conserva revisiones y recibos por
operación, sin SELECT/INSERT directos para clientes. RLS está activado y los
privilegios de tabla revocados. Las fachadas públicas son invoker; los internos
definer tienen `search_path` vacío, identidad esperada y MFA. Consultar exige
cartera propia; escribir exige además servicio y acceso vigentes. Una baja o
pérdida de acceso conserva lectura histórica propia, pero no permite metas nuevas.
Un reintento confirmado recupera su recibo sin duplicar revisión. Una revisión
obsoleta no sustituye la nueva.

RPC de esta entrega: `list_trainer_client_agenda`, `list_trainer_goal_protocols`,
`get_trainer_client_goal` y `save_trainer_client_goal`, todas con propietario
esperado. No se modifica ADMIN, el motor deportivo ni el contrato comercial.
Las migraciones y los contratos transaccionales se verifican solo en Dev.

## Validación y publicación

Comprobación del 25/10/2026:

- Análisis limpio en deportista, ADMIN y Trainer. Baterías completas: 1.353
  pruebas raíz (una omisión previa), 316 ADMIN (dos omisiones previas) y 236
  Trainer.
- Contrato `supabase/tests/trainer_client_goals.sql` correcto con `ROLLBACK`,
  primero sobre DDL transaccional y después sobre las dos migraciones aplicadas
  en Dev: `20261025181351` y `20261025183412`. Historial local/remoto cotejado.
  Comprueba propietario/MFA, cartera, aislamiento entre colegas/alumnos,
  protocolos ajenos, recibos, revisión obsoleta, ceros/nulos, última/anterior/PB,
  muestra parcial de 200 evaluaciones y paginación de 55 citas sin duplicados.
- Pruebas de interfaz: retorno del editor, alumno/fecha conservados, arrastre con
  confirmación, lectura ajena, retirada por revocación, respuesta tardía de otro
  alumno y texto doble. El guard de objetivos conserva el envío incierto también
  al reconstruir un adaptador equivalente y solo sale tras confirmar el recibo.
- Capturas optativas de widgets reales con datos ficticios a 390, 1.440 y
  1.920 px, con selección propia/ajena y objetivos. Se conservaron en el build
  local, fuera de Git. La cabecera del objetivo se reorganiza con poco ancho o
  texto grande; no depende de reducir la tipografía.
- La tabla privada con RLS sin política directa produce un aviso INFO esperado:
  carece de privilegios directos y se accede por funciones con guardas. No se
  amplían las advertencias de seguridad preexistentes del proyecto.

Publicación Trainer Dev desde `04a1f87c2f503c6b656b02014e94fe39c670e769`:
release `04a1f87c2f503c6b656b02014e94fe39c670e769-20261025-1`.
ZIP SHA-256 `66001fe5d0f04ec105d9f9e87a0d7d2aa3e5dcf5aef5f3555947e365fb89e8ca`;
JavaScript SHA-256 `0e9f3772403e53fc9dd711533a50f3c5dc735029b4ec50b073db2e2a75b7c999`.
El paquete acredita fuentes relevantes limpias y proyecto Dev. Se extrae en un
staging privado, se copia únicamente su carpeta versionada a las releases de
Trainer y se verifica el asset por HTTPS antes de activar `index.html` y
`build-info.json`. Se conservan las versiones anteriores y la configuración.
`trainer_release.py verify` confirma revisión, entorno, manifiesto, JavaScript,
entrada, cabeceras y MIME WebAssembly.

Chrome con la sesión profesional existente acredita Alumnos → ficha → semana,
biblioteca de seis sesiones, selección del 28/10 y confirmación de una receta
con ese día ya elegido, sin otro selector de alumno. Se vuelve sin confirmar;
no se crean pautas de ensayo. El editor de objetivo muestra convocatoria, fecha
y la indicación de crear una batería cuando todavía no hay protocolos propios.
Resultados conserva las sesiones completadas del alumno. Consola sin errores ni
avisos en el recorrido. Las ventanas temporales de Hostinger se cierran al terminar.
La vista ajena se acredita con contratos SQL/widget, no como aceptación humana
con dos cuentas reales: el alumno comprobado aún no comparte su calendario.

No se presenta la comprobación web como aceptación física móvil. Siguiente
recorrido único: Javier define un objetivo, crea o arrastra una pauta y confirma
su planificación con el alumno y el otro preparador en la web publicada.

La incorporación del modelo puro compartido activa la publicación automática de
ADMIN sin modificar su interfaz. Run `40222767612`: validación, despliegue y
retención correctos. ADMIN Dev confirma por HTTPS la misma revisión de fuentes,
release `04a1f87c2f503c6b656b02014e94fe39c670e769-40222767612-1` y JavaScript SHA-256
`3ace39c409ddcc76f75500e1f18ff58908fa062929a217a2f24ff1021b493bd2`. No se usa una subida manual de ADMIN.

## Cierre de respuestas del formulario · corrección del 25/10/2026

Javier detecta la pantalla vacía al regresar de un formulario respondido. Se
reproduce en Chrome: el diálogo está en el Navigator raíz y Cerrar usaba el
contexto de la página del ShellRoute, eliminando la última página del alumno.
El botón se vincula al contexto del propio diálogo. La regresión con navegación
anidada falla antes de la corrección y comprueba después dos aperturas/cierres,
conservación de ficha/ruta y regreso a Planificación. Sin cambios de datos,
permisos o componentes de ADMIN. Análisis limpio y batería Trainer completa:
237 pruebas correctas. Publicada en Trainer Dev la fuente
`19c7f83fca3c3d637d2324a1e0cfb0ac38c8786c`, release
`19c7f83fca3c3d637d2324a1e0cfb0ac38c8786c-20261025-1`.
ZIP SHA-256 `6f8cbe620623f91c1224897dceec11400a98e4f9ec21b001b5521183e3f7ce92`;
JavaScript SHA-256 `6045f90ce7804147532d6d21fb06aedee0181528a2b1dcf6946b5a1f26ffcbd6`.
Verificador HTTPS correcto. Chrome reproduce antes el fallo y después acredita
abrir la respuesta existente, cerrar conservando la ficha y volver a Planificación,
sin modificar respuestas ni asignaciones. No hay errores del portal; un aviso de
conexión de una extensión del navegador queda fuera de esta corrección.

## Archivo y borrado de asignaciones · 25/10/2026

Javier confirma implementar archivo recuperable, filtro y borrado protegido. El
alcance son las **citas asignadas**, no las plantillas de la biblioteca. Retirar
cancela una pauta pendiente y conserva su tarjeta. El diálogo ahora lo explica.

En ficha del alumno, Agenda y listado de pautas se usan los mismos filtros y
acciones. **Habitual** conserva todas las no archivadas, incluidas las retiradas;
**Retiradas** muestra las canceladas no archivadas; **Archivadas** muestra las
archivadas propias; **Todas** incluye ambos grupos. El filtro se aplica en SQL
antes del límite/cursor. Agenda lo combina con alumno/estado. Resultados y técnica
conservan la consulta histórica completa. La proyección compartida no puede
reintroducir una cita propia que la consulta filtrada haya excluido.

Seleccionar una pauta propia retirada permite **Archivar sesión**, **Restaurar en
calendario** o **Borrar definitivamente**. Archivar solo cambia visibilidad privada
del autor en Trainer. El alumno y los otros preparadores conservan la retirada;
no se altera cita, receta, fecha, resultados, consentimientos ni estado Garmin.
Restaurar la devuelve a la vista habitual **todavía retirada**. No vuelve a
asignarla, no reactiva recordatorios ni genera push de planificación.

Borrar exige confirmación explícita en la interfaz y las siguientes condiciones
en el servidor, con identidad esperada y MFA profesional:

- Cita propia y retirada. No borra pautas pendientes, en curso, realizadas o ajenas.
- Sin ejecución, revisión de resultados, recibo de revisión ni resultado registrado.
- Sin referencia Garmin: entrega de cualquier estado (también retirada/incierta),
  sus versiones, confirmación de actividad o cola de sincronización de cualquier
  estado. Nunca se borran esas referencias para permitir el borrado.
- Sin conversación ligada, vídeo técnico ni dependencia de planificación interna.

El botón bloqueado explica el motivo y permite archivar la retirada. La
comprobación se repite después de tomar los bloqueos, aunque haya cambiado desde
que se abrió el diálogo. Solo se elimina cita/asignación y metadatos dependientes
sin resultados; se conserva la plantilla. Los avisos originales conservan su
historial/lectura; su destino ya inexistente resuelve como no disponible. La cola
push revalida existencia/estado y no envía planificación de una cita retirada o
borrada. La generación de los grupos y los recordatorios existentes se conservan.

### Persistencia y concurrencia

Migración `20261025214951_trainer_assignment_archive_and_guarded_deletion.sql`:
`trainer_private.assignment_lifecycle` almacena archivo/revisión y un marcador
monotónico de referencia externa; `assignment_lifecycle_writes` conserva recibos
idempotentes y la identidad de citas eliminadas. Son tablas privadas con RLS y
sin concesiones directas. Una identidad eliminada no puede volver a asignarse por
reintentar la operación original. Un fallo de conexión conserva el ID de operación
en las acciones de interfaz para reintentar sin duplicar el cambio.

Se reutiliza el bloqueo alumno → cita → asignación del motor existente, después
el estado privado. Los triggers de entrega/cola/confirmación Garmin escriben ese
estado: una referencia que gana la carrera impide borrar; si gana el borrado, el
enlace tardío se rechaza. Bajo REPEATABLE READ el cambio de versión provoca
reintento en vez de leer un snapshot antiguo. El marcador permanece aunque una
operación posterior retire una fila externa: no se pierde evidencia de su vínculo.

Las fachadas filtradas son aditivas, ligadas al propietario esperado. Reutilizan
las proyecciones actuales; `device_training` sigue solo en citas propias y usa
`training_progress`/fuente sin bloqueos. Las consultas STABLE siguen funcionando
en transacciones READ ONLY de PostgREST. No se toca ADMIN ni el editor compartido.

### Verificación del bloque

Análisis Trainer limpio y **244 pruebas** correctas, incluidas seis nuevas de
archivo/filtro, confirmación, reintento, propietario, protección y pantalla 320px
con texto doble. **60 carreras RC/RR** sobre PostgreSQL17 local prueban ambas
órdenes frente a entrega, cola, actividad, resultados, recibos y revisión obsoleta.
El clúster mínimo comprueba bloqueos, no sustituye las políticas reales.

En Dev pasan con ROLLBACK `trainer_assignment_lifecycle.sql`,
`garmin_training_progress.sql`, `trainer_notification_policy.sql`,
`trainer_student_notices.sql` y `trainer_private_workouts.sql`. Incluyen autoría y
resultado reales, protección de otras cuentas/MFA, historial, supresión de push
huérfana, 55 archivadas antes del límite, paginación y lectura READ ONLY. La
migración está aplicada/cotejada solo en Dev; asesores sin WARN nuevo, con dos INFO
esperados de RLS sin políticas en tablas privadas sin permisos directos.

### Publicación y revisión de Trainer Dev

El [run 40238901174](https://github.com/jchjdev/entrenaop/actions/runs/40238901174)
completa validación, compilación, artefacto y transferencia automática sin gestor
de archivos. Fuente `2b9ea1b80e5f53ec2cc530d4b43576a2bdf6cce3`, entorno de
desarrollo y proyecto `sxbxfjqgoddzhtcyhalw` confirmados por HTTPS. El verificador
comprueba identidad, hash JavaScript, entrada, cabeceras y MIME WebAssembly.

Chrome acredita la ficha cargada con los cuatro filtros, Retiradas excluyendo las
realizadas y Archivadas vacío sin error. Al seleccionar retiradas aparecen las
acciones; una con resultados muestra «Tiene una ejecución o resultados. Puedes
archivarla» y otra con Garmin «Conserva vínculos con Garmin. Puedes archivarla»,
con borrar deshabilitado y archivo disponible. Se deja el filtro Habitual.
No se han eliminado ni archivado citas reales del usuario durante esta revisión.
Archivo/restauración/borrado completos están comprobados con fixtures y ROLLBACK;
la aceptación humana del recorrido sigue pendiente.

Release: `/releases/2b9ea1b80e5f53ec2cc530d4b43576a2bdf6cce3-40238901174-1/`.
JavaScript SHA-256: `9d3688fc621ffdfb7d3f1357c527dba70d6ebc0ee08c1a0aa496b26544666f64`.
