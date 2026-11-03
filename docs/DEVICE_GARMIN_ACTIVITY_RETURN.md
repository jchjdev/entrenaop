# Retorno de carrera Garmin · INT-012 · 23/10/2026

## Series recortadas con identidad · 03/11/2026

Javier contrasta el cierre de una carrera anterior con una nueva que queda
recibida sin completar. La nueva observación conserva índice de paso, tipo y
mediciones para todas las fases, incluidas varias series muy recortadas. La
función `proposeLapMapping` exigía además proximidad a la distancia pautada y,
al fallar una serie, descartaba todo el mapa. No faltaban esas mediciones.

Se separa identidad y cumplimiento: si los grupos de vueltas tienen los índices
nativos continuos de la secuencia expandida y tipos compatibles, se acepta la
correspondencia aunque la distancia sea menor o mayor. Auto Lap conserva sus
segmentos y no se reparte un total entre pasos. Sin esa identidad se mantiene
la candidatura conservadora; no se relajan receta exacta, ambigüedad entre
citas, versión vigente, permisos, ventana de siete días, cobertura de vueltas
ni revisión de una grabación sin desplazamiento. No se cambia fuerza o Apple.

La ejecución conserva distancia/tiempo real frente a la pauta original. Una
serie registrada puede estar completada administrativamente y no haber cumplido
la distancia objetivo: el resultado profesional y su filtro de diferencias
conservan esa discrepancia. RPE sigue ausente hasta una valoración real. Los
datos sin correspondencia segura no se inventan para forzar un cierre.

Corrección exclusiva del servidor: no cambia el contrato SQL ni el binario iOS.
La validación de la carrera real usa la observación ya recibida, no un nuevo FIT
ni una nueva grabación. Los identificadores y mediciones privadas quedan fuera
de Git. La reconciliación de esa recepción previa se registra separada de la
ingesta automática de actividades futuras.

Pasan 268 pruebas de servidor y tipos estrictos. El contrato SQL de cierre
automático usa una serie sintética recortada frente a 400 m y verifica lectura
por el preparador, mediciones decimales, RPE ausente e idempotencia. También
pasan los contratos de retorno Garmin y lectura Apple/Garmin con ROLLBACK.
La simulación transaccional de la carrera real conserva todas sus vueltas y
mediciones y permite un cierre idempotente; se revierte antes del despliegue.

Desplegados solo en Dev `garmin-activity-ingest` v21 y `garmin-activities` v22,
activos y con el archivo modificado contrastado frente a la fuente. Los demás
archivos coinciden con la versión anterior y se conservan sus permisos HTTP.
La recepción existente se concilia una vez mediante el comando de cierre del
trabajador, con exclusión por cuenta, concesión vigente, candidatos sin cambios
y revisión exacta de evidencia/receta. No se descarga de nuevo el FIT ni se crea
una sesión de Auth ficticia. Se audita `stored_reconciliation` y la revisión de
código; no se presenta esta reparación de una recepción previa como una nueva
aceptación física del retorno automático.

La cita real y su única ejecución quedan completadas. Se comprueban las medidas
originales de cada tramo y recuperación, las tres series recortadas, RPE ausente,
una sola confirmación y una sola observación Garmin. La asignación conserva al
preparador autor vigente y genera una nueva revisión de resultado pendiente de
su lectura profesional. La prueba SQL acredita ese lector con datos recortados;
no se suplanta la sesión real del preparador ni se da por hecha su aceptación.
GitHub Actions del commit `abe1ed26` termina correctamente: servidor, consumidor
Flutter y compilación iOS Release sin firma. No se instala ni publica una app
nativa por ese ensayo.

## Pauta identificada en la bandeja · 03/11/2026

La bandeja propia de Trainer devolvía todas las actividades sin confirmación
como `unassigned`, incluso si el trabajador ya había guardado la pauta
coincidente. Esto confundía falta de asociación y revisión de intervalos.
`my_unassigned_device_activities` conserva su nombre por compatibilidad, pero
publica `review`, `scheduled_id` y el nombre de la pauta cuando los trabajos
terminados identifican una única cita del titular. Sin vínculo o con varias
citas distintas mantiene `unassigned`; un trabajo pendiente no acredita vínculo.
No se buscan similitudes de nombre/fecha ni se modifican actividades o citas.

La tarjeta compartida identifica el estado y permite desplegar la pauta. La
bandeja explica dónde continuar: app del deportista → Garmin → Actividades
recibidas → Sesión de tu semana → Revisar datos y sesión. Confirmar requiere
revisar/asignar vueltas y aceptar «Completar sesión con estos datos». La tarjeta
de consulta profesional no equivale a esa confirmación. Un retorno recibido y
vinculado puede consultarse por el preparador autor sin completar la semana.

La migración `20261103130118` mantiene las fachadas y permisos propios. Las
pruebas SQL cubren pauta identificada, actividad sin vínculo, trabajo pendiente,
ambigüedad entre citas, aislamiento de cuentas y exclusión tras confirmar,
siempre con ROLLBACK. La prueba de interfaz distingue ambos estados, muestra
el nombre de la pauta al desplegar y no anuncia un cierre inexistente.

Migración aplicada y cotejada solo en Dev. Los dos contratos SQL pasan de nuevo
contra el despliegue con ROLLBACK; los asesores de seguridad conservan los mismos
avisos previos. Pasan los tres análisis, 1.740 pruebas raíz (una omisión previa),
370 ADMIN (dos omisiones previas), 446 Trainer y las cuatro pruebas focales de
tarjetas compartidas. Trainer y ADMIN Dev sirven por HTTPS la revisión `1fce79ee`,
versión `0.2.2+4`; se cotejan manifiesto, versión del paquete y proyecto Dev.
Los cuatro workflows de este commit terminan correctamente. La comprobación
visual en la cuenta propia muestra la carrera vinculada con «Pendiente de
revisión» y «Pauta identificada», mientras el rodaje sin vínculo sigue pendiente
de asociar. No se confirma ninguna de las actividades durante la consulta.
La app del deportista queda en GitHub como `1.4.3+10`; no se acredita instalada
en el iPhone por publicar la web.

## Lectura profesional antes del cierre · 03/11/2026

Se contrasta la consulta de Javier sobre la carrera de pista. La relación con
su preparador autor sigue activa y este conserva acceso profesional. El resultado
Apple está asociado a la cita; `training_progress` incluye sus datos mediante
`apple_results_for_schedule`, que autoriza al titular y al preparador autor con
relación vigente. Esta lectura no acredita que la cita esté completada.

La actividad Garmin está recibida y vinculada de forma inequívoca, pero exige
revisión de intervalos y no tiene confirmación ni ejecución. Se corrige la
proyección que antes solo añadía `apple_results` a la planificación profesional:
`device_private.results_for_schedule` reúne Apple y Garmin, y lo usan tanto
`my_scheduled_device_results` como `training_progress`. Este último publica el
campo común `device_results` y conserva `apple_results` filtrado para clientes
anteriores. Ambos campos proceden de una sola lectura con los mismos permisos.

El preparador autor necesita identidad concordante, acceso profesional, sesión
MFA viva y relación vigente para esa asignación. Otro preparador del mismo
alumno no obtiene la evidencia de una pauta ajena por esta vía. Tampoco se
devuelve historial sin vínculo, datos internos Garmin, FIT o coordenadas. La
lectura compartida de resultados completados conserva su contrato y opt-in
independientes. No se amplían grants a las tablas ni al lector privado.

El DTO `DeviceTrainingProgress` usa `deviceResults`, lee el contrato anterior
durante el despliegue y no suma dos veces ambos campos. `workout_editor_ui`
presenta cada proveedor con la misma tarjeta plegable; Garmin en revisión se
identifica por su nombre. El deportista, ADMIN y Trainer consumen esa misma
implementación. Recibir/mostrar no crea ejecución, no completa una cita ni
inventa RPE. `get_trainer_assignment_result` sigue reservado a ejecuciones.

Migración `20261103124136` aplicada y cotejada solo en Dev. Se comprueba que la
carrera existente conserva una observación Apple asociada y una Garmin en
revisión, sin ejecución. Pasan los tres análisis, 1.740 pruebas raíz (una omisión
previa), 370 ADMIN (dos omisiones previas), 445 Trainer y cuatro pruebas focales
de tarjetas compartidas. Los contratos SQL Apple/Garmin, cierre automático y
retorno Garmin terminan con ROLLBACK. Cubren la agenda profesional real con los
dos proveedores, otro preparador vigente, sesión revocada, relación retirada,
actividad privada sin pauta y ausencia de cierre o filtración de metadatos.
La publicación de esta lectura y del ajuste posterior de la bandeja se contrasta
por separado en Trainer y ADMIN Dev (`1fce79ee`, `0.2.2+4`), sin tocar producción.

## Segunda prueba de recepción automática · 03/11/2026

A petición de Javier se crea una nueva autoasignación técnica privada de carrera,
distinta de la anterior para evitar dos recetas candidatas idénticas. Tiene
5 s de calentamiento, tres series de 8 s con 4 s de descanso y 5 s de enfriamiento,
todo temporizado (46 s). Está marcada PRUEBA, puede grabarse sin desplazamiento
y no es una pauta de entrenamiento físico.

La conciliación automática Dev crea la entrega y Garmin confirma entrenamiento
y calendario del día, con trabajo terminado y sin errores. No se cambia la
preferencia de sincronización ni se reenvía la prueba anterior. La recepción se
comprueba después de que Javier termine: aviso nuevo, trabajo `done/stored`,
sin error ni metadatos de recuperación manual. Se usa exclusivamente el trabajador
normal, sin exportar archivos, solicitar reenvío ni reparar evidencia. La receta
queda vinculada y en revisión; no se crea ejecución ni se completa la cita.

La observación conserva las tres series y descansos temporizados exactos, además
de una vuelta posterior al enfriamiento sin índice de receta. No se recorta esa
grabación adicional para ajustar el total a la pauta. Trainer Dev muestra la
actividad nueva y sus nueve vueltas en la bandeja propia, contrastado en el
navegador. Los identificadores, mediciones privadas y captura quedan fuera de
Git. La nueva grabación tiene distancia medida positiva: acredita recepción
automática, pero no sustituye una aceptación específica de cero metros.

Javier informa de que encuentra la prueba en la biblioteca del fēnix pero no
como entrenamiento del día. Se contrasta el calendario de Connect: la receta
está en el día correcto y el recibo de programación conserva esa misma fecha.
La presentación física del calendario queda pendiente de diagnosticar. No se
confunde este límite con falta de recepción de la actividad. Durante la revisión
no se fuerza la sincronización reloj–Connect; la aceptación observada comprende
el aviso desde Connect, la ingesta y su consulta en Trainer, sin garantizar
sincronización instantánea o disponibilidad permanente del enlace del teléfono.

## Grabaciones sin desplazamiento · 03/11/2026

Tras actualizar la app de escritorio vuelve a estar disponible el acceso al
navegador. Se contrasta en Connect la prueba sin desplazamiento y Javier confirma
que la hizo parado en la oficina. La validación anterior exigía distancia
positiva; un FIT sintético de distancia cero reproduce ese rechazo.

El dominio y los dos checks de persistencia admiten cero medido, manteniendo
rechazo de negativos, ausencia en carrera, magnitudes excesivas y las restantes
reglas de tiempos, vueltas y pulso. No se calcula un ritmo de cero metros. El
conciliador guarda la actividad antes de revisar y conserva la asociación de
receta si es inequívoca; una carrera sin desplazamiento no cierra automáticamente
la pauta, aunque sus tiempos coincidan. No cambia el editor ni el binario iOS.

Migración `20261103115055` aplicada y cotejada solo en Dev. Receptores
`garmin-activity-ingest` v20 y `garmin-activities` v21 activos, con los dos archivos
modificados contrastados frente al despliegue. Pasan 265 pruebas de servidor,
tipos estrictos y contratos SQL transaccionales de cero metros, retorno Garmin,
cierre automático y retorno Apple, todos con ROLLBACK. Las nuevas fixtures son
sintéticas y no reproducen mediciones o identificadores de la grabación real.

La exportación automática del navegador no genera archivo. El primer FIT adjunto
pertenece a otra actividad; después Javier descarga el original correcto. El
lector corregido valida su integridad, sus nueve vueltas y la referencia exacta
de la pauta enviada. El archivo original y sus mediciones quedan fuera de Git.

Se recupera únicamente esa evidencia mediante mantenimiento administrativo en
Dev, en una transacción: se comprueban propietario, conexión y generación
vigentes, permiso de lectura, revisión enviada, cita pendiente y ventana de
asociación. Se guarda la observación original con su hash canónico, se conserva
el enlace de receta y se deja revisión pendiente, sin ejecución ni confirmación.
`metadata.recovery` conserva método `user_exported_original_fit`, huella SHA-256
del FIT, revisión del lector, error anterior y momento de recuperación. No se
simula una concesión, sesión de usuario, lease del trabajador o nuevo callback.

Trainer Dev se verifica en el navegador con la cuenta titular: «Para mí» →
«Mi planificación» → «Mis actividades recibidas» muestra la prueba Garmin,
distancia cero, duración, pulso y nueve vueltas disponibles. La bandeja conserva
su estado pendiente de asociar/confirmar; recibir no cierra la semana. Esta
recuperación manual acredita el original y su lectura en Trainer. No equivale
a un reenvío oficial ni acredita una recepción automática nueva después de la
corrección. El siguiente contraste será con una actividad posterior normal.

## Prueba del contador en el reloj · 03/11/2026

Javier encuentra la prueba corta en el fēnix y confirma que la vista previa
agrupa «repetir ×3» y la ejecución muestra 1/3, 2/3 y 3/3. La entrega de la
pauta anterior del preparador precede al exportador con repeticiones nativas;
su presentación plana no acredita un fallo del creador o de la prescripción.

Tras finalizar y guardar, el receptor Dev recibe automáticamente el aviso de la
prueba. El trabajo termina en revisión con `invalid_activity` durante la lectura
y validación, sin observación deportiva persistida. Esto acredita el contador
y la llegada del aviso, no la importación de resultados ni el cierre de la cita.
Se necesita contrastar el FIT original para identificar la condición exacta;
no se deduce del código genérico si fallan distancia, tiempos, pulso o vueltas.
En la primera revisión el control del navegador no estaba disponible por un fallo
del componente nativo de Windows, reproducido tras reintento y reinicio del intérprete. No se han
reprocesado callbacks consumidos ni cambiado mediciones o estados para simular
recepción. La comprobación Apple del contador continúa pendiente.

## Recibido y vinculado sin completar · 03/11/2026

Una actividad válida puede estar importada y corresponder a su receta, pero
necesitar revisión porque se avanzaron fases antes de cumplirlas. El trabajador
conserva esa asociación en su recibo privado, únicamente tras identificar una
receta vigente inequívoca, comprobar propietario, versión y ventana temporal,
con los mismos permisos y lease de la recepción. No crea una ejecución ni cambia
los resultados para hacerlos coincidir con los objetivos.

`my_scheduled_device_results` reúne los resúmenes Apple y Garmin de las citas
propias solicitadas (máximo 200), con sesión viva y sin acceso directo a tablas
privadas. Garmin puede aparecer como `review` aunque la pauta continúe pendiente.
Mi semana utiliza una lista común de resultados y ofrece acceso a revisar Garmin.
Las ambigüedades sin vínculo fiable siguen fuera de la pauta, en actividades
recibidas; no se asocian por nombre o fecha. Un resultado confirmado en otra cita
no se muestra en una segunda por un enlace pendiente anterior.

Los bucles FIT de repeticiones fijas se expanden de forma acotada para calcular
la referencia deportiva. Se conservan unidades, objetivos y orden; no se aceptan
bucles condicionales, anidados, índices inválidos o expansiones de más de 100
pasos. El compilador de referencia de entrega usa dosis plana y reconoce tanto
el envío anterior como el formato repetido. Las mediciones no se expanden ni
se inventan a partir de ese contrato.

La carrera de prueba ya recibida se vincula administrativamente después de
contrastar con el compilador la referencia exacta de su snapshot y su ventana;
conserva revisión pendiente y no se completa. Sus identificadores y mediciones
no se incorporan al repositorio. Se crea aparte una autoasignación técnica de
3 × (10 s libres + 5 s de descanso), con calentamiento/enfriamiento manuales,
marcada PRUEBA. Garmin confirma su calendario; la programación y comprobación
física Apple quedan pendientes del iPhone actualizado.

Migración `20261103110209` aplicada únicamente en Dev y cotejada con el historial.
Pruebas SQL Garmin y Apple con ROLLBACK correctas, incluida consulta propia,
rechazo de otra identidad y ausencia de cierre por vincular. Análisis sin
incidencias; 1.737 pruebas de raíz correctas y una omisión anterior, 115 focales y
263 de servidor. Los tipos TypeScript y el FIT generado por el SDK oficial
comprueban equivalencia de referencias antes/después de repetir. Versión móvil
`1.4.1+8`. La aceptación física de los relojes sigue pendiente.

## Contexto del recorrido inicial

Este documento conserva el bloque de carrera aceptado. INT-013 amplía después
el mismo servicio a series convencionales de fuerza mediante observación V2,
sin alterar la evidencia V1 ni la aceptación física de carrera.
[Cobertura actual de fuerza](DEVICE_GARMIN_TRAINING.md#fuerza--recorrido-solicitado-int-013).
El endpoint de lectura conserva V1 para el cliente anterior; el nuevo pide V2
explícitamente para recibir fuerza. La evidencia permanece en la misma cuenta.

Javier solicita recibir la actividad realizada, asociarla a la cita de su semana
y completarla con mediciones reales. La recepción guarda evidencia; completar
requería revisión del titular en la primera entrega. La ampliación autónoma del
01/11 descrita al final permite cerrar coincidencias acreditadas. No se atribuyen
vueltas por nombre o fecha ni se reparten totales para rellenar series. La carrera física ya realizada será la
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


## Revisión de presentación · 25/10/2026

Las actividades recibidas de deportes todavía no compatibles se explican como
tales, separadas de errores técnicos que requieren revisión. No completan citas.
Desde la consulta de entregas se puede abrir la revisión de actividades recibidas.
Se conserva el cierre explícito: importar no completa automáticamente la semana,
ni inventa RPE, repeticiones o pesos. El estado «Resultados del reloj incorporados»
solo procede de una confirmación de la actividad para esa cita concreta.

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


## Desfase de fronteras FIT y reenvío real · 01/11/2026

Se reproduce `invalid_activity` con el FIT original de una carrera física. Una
frontera entre vueltas presenta un desfase inferior a dos segundos entre la
marca horaria y la duración acumulada. El SDK valida el archivo y las sumas
coinciden con la sesión; el rechazo procedía del margen de 1,1 segundos del
dominio. Se admite un máximo de dos segundos, conservando marcas y mediciones
sin normalizarlas. Se exige además que los inicios no retrocedan y se mantienen
los controles de temporizador, duración, distancia, sumas y tamaño.

Dos regresiones sintéticas reproducen el límite y rechazan tanto 2,001 segundos
como el retroceso de una vuelta corta. Pasan 234 pruebas Node, tipos estrictos
y el contrato SQL de retorno en Dev con ROLLBACK; 268 migraciones locales/remotas
coinciden. No cambia el esquema, Flutter, las credenciales ni producción.
`garmin-activity-ingest` v17 y `garmin-activities` v18 quedan activos en Dev;
la lectura posterior acredita el módulo publicado exacto. Los demás archivos
desplegados y los controles de autenticación se conservan.

Summary Resender genera un callback nuevo y la vía oficial guarda la carrera
con sus ocho vueltas, sin repetir el callback consumido ni reconstruir datos.
El FIT local y las mediciones/identificadores exactos quedan fuera de Git.
La [documentación FIT de Garmin](https://developer.garmin.com/fit/articles/cookbook/decoding_activity_files.html)
distingue las marcas temporales y los campos de resumen.

La importación queda acreditada. La consulta previa de Trainer exigía confirmar
Garmin contra una pauta; la bandeja descrita a continuación permite consultar
esta prueba sin restaurar ni completar su pauta archivada. No concede al
preparador acceso al historial no asociado de alumnos ni empareja por nombre/fecha.


## Bandeja privada de recepción en Trainer · 01/11/2026

«Para mí» → «Mi planificación» incorpora «Mis actividades recibidas», plegable,
con tarjetas de resumen reutilizadas de `workout_editor_ui`. El puerto y DTO
pertenecen a `workout_core`; el adaptador Supabase y la composición quedan en
Trainer. El DTO distingue proveedor y ausencia de pauta, conserva compatibilidad
con Apple y no permite que una actividad sin asociar declare ejecución o pauta.
Se muestran tiempo, distancia y pulso disponibles; las vueltas Garmin no se
confunden con los intervalos nativos Apple. No se muestra RPE ausente.

La fachada `public.my_unassigned_device_activities` es invoker y delega en un
lector privado con propietario igual a `auth.uid()` y `p_expected_owner`.
Solo authenticated puede ejecutarla; no concede acceso directo a tablas. Dev
aplica `20261101181643_device_activity_inbox`, sin cambiar datos existentes.
Devuelve como máximo 30 actividades, una revisión reciente por identidad externa,
y excluye las ya confirmadas. Conserva lectura del historial propio aunque no
haya una conexión o un servicio de pago vigente: esto no concede nuevas
importaciones. No devuelve identidad del proveedor, tokens, revisiones ni FIT/GPS.

La bandeja solo se presenta en el contexto propio. No amplía lo que un
preparador puede consultar de alumnos: sus resultados confirmados y los retornos
Apple con referencia de su pauta conservan sus contratos existentes. No hay
emparejamiento por fecha/nombre, restauración de pautas ni cierre de Core.

El futuro de lectura y sus resultados se sustituyen al cambiar repositorio o
cuenta; una respuesta tardía no recupera las mediciones anteriores. Se cubren
carga al desplegar, ausencia de datos, credenciales cruzadas y visibilidad solo
propia. Baterías locales: raíz 1561 correctas/una omisión previa, ADMIN 368/dos
omisiones y Trainer 428 correctas; análisis de las tres apps y tres regresiones
de la tarjeta compartida correctos. El contrato SQL propio pasa con ROLLBACK
antes y después de aplicar la migración. Sin avisos nuevos del asesor de
seguridad para estas funciones. Las 269 migraciones locales/remotas coinciden.

Trainer Dev publica `a1997319` y la comprobación por HTTPS acredita esa revisión,
entorno development y proyecto Dev. En la sesión real de «Para mí», al desplegar
la bandeja y su tarjeta aparecen nombre, fecha, tiempo, distancia, pulso y ocho
vueltas de la carrera recibida oficialmente. La pauta original sigue archivada
sin completar y el esfuerzo ausente no se muestra. La captura privada y las
mediciones exactas quedan fuera de Git. Es aceptación de consulta propia, no de
acceso por otro preparador ni de asociación/cierre automático.

[CI y publicación Trainer](https://github.com/jchjdev/entrenaop/actions/runs/41337673132),
[ADMIN](https://github.com/jchjdev/entrenaop/actions/runs/41337673185) y
[servidor, consumidor e iOS Release sin firma](https://github.com/jchjdev/entrenaop/actions/runs/41337673288)
correctos. ADMIN también publica la misma revisión y Dev comprobado por HTTPS.
No es necesario reinstalar el iPhone para esta corrección de servidor/web.

## Conciliación automática y esfuerzo pendiente · 01/11/2026

El receptor Dev conserva primero el FIT y concilia exactamente la revisión
guardada, bajo el mismo lease y generación de conexión. Una repetición antigua
no toma otra observación posterior del mismo identificador. El cierre del
servidor se apoya en la autorización Garmin vigente, sin crear una sesión Auth
ficticia ni necesitar que la app esté abierta. Se restauran los claims del
trabajador tanto al terminar como ante errores.

El adaptador normaliza el contenido exportable de los pasos nativos: orden,
tipo, terminación, objetivo, variante conocida y peso. Convierte explícitamente
las unidades FIT/API y no usa nombre o fecha como identidad. El dominio compara
esa referencia con versiones actuales y anteriores enviadas. Dos citas con la
misma pauta, una versión retirada o datos insuficientes quedan para revisión.
Los ejercicios sin equivalencia verificada y los conjuntos sin repeticiones o
peso requeridos tampoco se completan automáticamente.

Una coincidencia única solo se cierra si la cita, los permisos y la versión
siguen vigentes y todas sus filas tienen evidencia nativa, sin intervalos activos
sobrantes ni repartos estimados. Se admite realizarla hasta siete días después,
según el día local observado. Se reutilizan inicio, correspondencias y cierre
Core, conservando precisión, totales y pulso. El RPE ausente queda NULL; añadirlo
después es una operación del titular que no reabre ni duplica el entrenamiento.

Si falla la conciliación, la recepción sigue guardada y no se vuelve a consumir
el callback. El recibo hace idempotente un reintento incluso tras perder la
respuesta. La cancelación, desconexión y cambios de pauta conservan sus barreras.

Dev: migraciones `20261101195418` y `20261101204224` aplicadas. Los seis contratos
SQL iniciales de Apple, Garmin, fuerza, cierre autónomo y RPE pasan con ROLLBACK.
La migración adicional `20261101212131` aplica el mismo margen a la confirmación
manual y conserva la barrera de reloj futuro del cierre automático. Su prueba
acepta el séptimo día y rechaza el octavo y una fecha anterior; los siete contratos
pasan con ROLLBACK. Los tipos TypeScript estrictos y 241 pruebas de servidor
pasan; el FIT real conserva su
referencia nativa sin publicar sus métricas. No se restaura su pauta archivada.
`garmin-activity-ingest` v18 y `garmin-activities` v19 están activos, conservando
la autenticación propia y todos los módulos remotos ajenos al cambio.
