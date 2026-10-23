# Retorno de carrera Garmin · INT-012 · 23/10/2026

Este documento conserva el bloque de carrera aceptado. INT-013 amplía después
el mismo servicio a series convencionales de fuerza mediante observación V2,
sin alterar la evidencia V1 ni la aceptación física de carrera.
[Cobertura actual de fuerza](DEVICE_GARMIN_TRAINING.md#fuerza--recorrido-solicitado-int-013).

Javier solicita recibir la actividad realizada, asociarla a la cita de su semana
y completarla con mediciones reales. La recepción guarda evidencia; completar
requiere revisión del titular. No se atribuyen vueltas por nombre o fecha ni se
reparten totales para rellenar series. La carrera física ya realizada será la
aceptación externa; su esfuerzo global lo declara el alumno, separado del reloj.

## Arquitectura y recorrido

El dominio de servidor `device_activity` valida la observación y propone
correspondencias conservadoras. Su servicio usa puertos de persistencia,
cuenta, cifrado y archivo. El adaptador Garmin verifica el FIT con su SDK oficial
`@garmin/fitsdk` 21.218.0, fijado con integridad en pnpm; solo el servidor depende
del SDK. El dominio no conoce HTTP, Supabase, Flutter ni el fabricante.

`garmin-activity-ingest` persiste la notificación antes del ACK y procesa el
archivo fuera de esa respuesta. Un trabajador periódico Dev recupera trabajo
pendiente mediante tickets efímeros de un solo uso, como el envío existente.
Los tokens OAuth y el lease de renovación se comparten con envío/desconexión;
una renovación o descarga incierta no se repite a ciegas.

`garmin-activities` verifica Auth; SQL comprueba la sesión viva. Solo el backend
puede ejecutar `garmin_activity_command`. La app tiene dominio/repositorio,
adaptador Supabase y Cubit independientes en `device_activity_results`.
Perfil → Garmin → Carreras recibidas permite elegir una cita y revisar vueltas,
recuperaciones, pasos no realizados, zona horaria y esfuerzo global. Confirmar
informa de su incorporación al historial y al seguimiento del entrenador.
Una respuesta perdida conserva el identificador y contenido de la operación.

La confirmación SQL bloquea al alumno y a la cita, fija las revisiones de
actividad y prescripción y reutiliza `start_scheduled_workout`,
`complete_workout_set`, `skip_workout_set` y
`finish_workout_observed_idempotent`. El trigger existente completa la semana;
Trainer consulta el resultado existente, sin una segunda ejecución ni un nuevo
flujo profesional. Se conservan autoridades del algoritmo, relación/servicio
profesional, asignación y plantilla publicadas. Una cita cancelada, modificada,
iniciada o de otra cuenta exige revisión o impide completar.

## Datos, precisión y seguridad

- Cola, observaciones y recibos en `device_private`, con RLS y sin acceso directo
  para cliente ni `service_role`. Solo funciones específicas conceden operaciones.
- Identidad Garmin resuelta desde la conexión verificada. La recepción exige
  permiso de lectura y acceso comercial vigente en servidor; desconectar o perder
  el acceso no borra el historial recibido. No cambia INT-006 para Salud/Health Connect.
- Evidencia inmutable por propietario, actividad externa y revisión. Una misma
  actividad no completa dos citas, ni una corrección externa sobrescribe un cierre.
- Se guardan resumen y vueltas con su precisión original. No se guardan FIT,
  coordenadas, ruta GPS ni muestras crudas. Los callbacks cifrados se vacían tras
  uso o revisión; las entradas resueltas de cola se purgan después de siete días.
- El resultado heredado conserva segundos enteros. INT-014 añade tiempo nativo
  numérico por serie y recuperación para mostrarlo y calcular el ritmo sin ese
  redondeo. Una corrección manual lo descarta; el enriquecimiento de ejecuciones
  anteriores exige evidencia original y marcas de dispositivo coincidentes.
  La evidencia conserva decimales; los totales
  `observed_timer_seconds`, `observed_elapsed_seconds` y `observed_distance_meters`
  de la ejecución son numéricos y conservan la medición. No se presenta el tiempo
  entre actividad y confirmación como duración entrenada.
- `started_at` y `performed_at` de la nueva ejecución proceden de la actividad;
  `completed_at` sigue siendo confirmación. Se rechazan reloj futuro y zona inválida.
- El portal no ofrece firma ni cabecera propia en este formulario. Se configura
  una capacidad aleatoria de 256 bits, exclusiva del receptor, en una ruta opaca.
  El portal elimina los parámetros query al guardar: no usar query para operar.
  La URL completa es secreta y puede quedar en logs del intermediario: no copiarla
  a Git, capturas, analítica o mensajes. Una filtración exige rotación coordinada.
- Solo se descargan callbacks HTTPS de `apis.garmin.com` y del recurso exacto
  `activityFile`, sin redirecciones, después de verificar identidad y permiso OAuth.

## Límites de esta primera entrega

Carrera con una única sesión FIT; máximo 4 MiB, 2.000 vueltas, dos días de duración
y 100 pasos exportables. Máximo cinco trabajos por tick y 100 activos por cuenta.
No acredita soporte universal de relojes/deportes. Fuerza Garmin y otros
proveedores permanecen fuera de este bloque. El contrato de observación puede
recibir futuros adaptadores sin mover reglas al SDK ni duplicar resultados.

Las sugerencias automáticas requieren intensidades y distancias compatibles.
Si Auto Lap divide un paso, solo se agrupan vueltas contiguas cuando el FIT
identifica explícitamente el mismo índice nativo y la secuencia completa encaja
con los pasos. La revisión permite elegir varias vueltas consecutivas: se suman
sus mediciones originales, sin repartir totales ni incluir las pausas como trabajo.
Si falta información, se eligen las vueltas explícitamente o se marca el paso
como no realizado. No se crean recuperaciones inexistentes. Una vuelta solo
puede usarse una vez. No hay asociación automática sin revisión.

No incluye corrección/borrado de resultados ya confirmados por una modificación
posterior en Garmin, importación de fuerza, conciliación cruzada con Salud,
agrupación de vueltas no consecutivas ni completar sesiones ya iniciadas en la
app. El historial local de Salud no completa citas mediante este nuevo endpoint.
La baja/borrado de cuenta y revocación remota conservan los pendientes de INT-005.

Starter entrega por Push y no incluye backfill histórico Enterprise. Para la
aceptación se usará el reenvío oficial de una actividad posterior a la conexión,
si Garmin la tiene disponible. No se reconstruye un payload a partir de capturas.

## Operación Dev y comprobaciones

Proyecto único: `sxbxfjqgoddzhtcyhalw`. Migración
`20261023091748_garmin_activity_return.sql`, ampliaciones
`20261023102552_garmin_activity_lap_groups.sql` y
`20261023103429_garmin_activity_prescribed_version.sql`, dos funciones Edge con mapa de imports
por función y trabajador `garmin-activity-return-dev` de un minuto. El preparador
`tools/prepare_garmin_activity_dev.py` conserva el secreto local ignorado; el
script `tools/enable_garmin_activity_return_dev.sql` activa solo el trabajador.
Los comandos de despliegue deben nombrar las dos funciones y el proyecto Dev;
no desplegar todas las funciones ni usar producción.

Comprobaciones realizadas: contrato real en Dev con ROLLBACK, privacidad,
propiedad/sesión, permiso profesional retirado, revisión obsoleta, vueltas
duplicadas, atomicidad tras error, precisión, cierre de semana y reintento sin
duplicación. PostgreSQL local prueba un único lease de descarga y dos
confirmaciones simultáneas; sus cierres deportivos son fronteras mínimas, no
sustituyen el contrato completo probado contra Dev. Las funciones desplegadas
rechazan peticiones sin autorización con 401 y el trabajador responde 200.

El asesor de seguridad señala RLS sin políticas en las tablas privadas, cierre
intencional mediante RPC, además de avisos globales ajenos al bloque. No se
presenta el proyecto entero como auditado ni libre de avisos.

**Aceptación real completada en Dev · 23/10/2026:** ruta secreta guardada y reenvío oficial realizado.
El FIT real ya está recibido y contiene Auto Lap en preparación/cierre y las
cinco repeticiones. La pauta enviada conserva su versión anterior archivada:
la nueva fuente de resultados admite ese caso solo con recibo `sent` y snapshot
exacto, asignación aún vigente y revisión coincidente. No se relaja la fuente de
nuevos envíos ni se modifica la autoría Trainer. La confirmación se realiza
desde la app web con la valoración declarada del alumno. Se comprueban cita
completada, siete resultados resueltos, cinco trabajos con sus recuperaciones,
preparación/cierre agregados y un único recibo. La UI del historial muestra los
resultados reales. La consulta profesional existente recibe la misma ejecución
y revisión; su contrato con MFA se prueba en SQL con datos sintéticos.

Validación local final: análisis raíz y Trainer limpios; raíz 1.302 pruebas
correctas y una omisión previa, Trainer 171; servidor 145 y tipos estrictos
correctos. Web Release Dev compilada. PostgreSQL local comprueba concurrencia
con las tres migraciones; el contrato completo Dev termina con ROLLBACK,
incluidas versión archivada sin recibo y revisión de asignación diferente.
Las tres migraciones constan aplicadas y ambos receptores están activos en Dev.

El iPhone debe actualizar su código desde main para disponer del nuevo menú.
La sesión completada ya es un dato de la cuenta y puede refrescarse con el flujo
existente. Los dos totales nuevos del visor Trainer están en código; publicar
una nueva versión web de Trainer no se acredita por desplegar funciones Edge.
La compilación iOS en CI no sustituye probar este nuevo menú en el teléfono.
La evidencia real, los identificadores y las métricas exactas quedan fuera de Git.

Fuentes oficiales: [Activity API 2.0](https://developerportal.garmin.com/sites/default/files/Activity_API%202.0_0.pdf),
[SDK FIT JavaScript](https://github.com/garmin/fit-javascript-sdk),
[dependencias Edge](https://supabase.com/docs/guides/functions/dependencies).


## Punto de guardado y CI · 23/10/2026

Código funcional `4160082f` subido y contrastado con `origin/main`. CI
[39942562157](https://github.com/jchjdev/entrenaop/actions/runs/39942562157)
correcta: servidor, consumidor y compilación iOS Release sin firma ni publicación.
La comprobación visual final acredita «Completada» y «Ver resultado» en la cita
de la semana, y totales del reloj en el historial. El receptor deja una
observación, una confirmación y el callback consumido vacío, sin error pendiente.
Nuevo menú físico iPhone y publicación de los dos totales nuevos en Trainer Dev
siguen pendientes de distribución/aceptación; no impiden consultar la ejecución
ya completada por el contrato profesional existente.
