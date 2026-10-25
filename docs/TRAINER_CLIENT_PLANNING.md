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
  pruebas raíz (una omisión previa), 316 ADMIN (dos omisiones previas). La
  batería final Trainer supera 236 pruebas. La revisión publicada se anota al
  activar la release.
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

No se presenta una compilación local como aceptación física móvil. La publicación
se registra después de contrastar manifiesto, hashes y recorrido autenticado.
