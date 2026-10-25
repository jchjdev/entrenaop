# Sincronización automática de carrera · INT-010 · 22/10/2026

Javier autoriza publicar, modificar y cancelar automáticamente las carreras del
entrenador y del algoritmo, exclusivamente en desarrollo. Se reutiliza la
prescripción independiente del proveedor y la conexión vinculada a la cuenta.
No se modifican los RPC, pantallas o contratos de publicación de Trainer.

## Revisión operativa · 25/10/2026

La cuenta de ensayo consultada en Dev conserva conexión y permiso Training,
pero no tiene una preferencia de sincronización automática registrada. El
trabajador global está habilitado y cron activo; esto no activa el consentimiento
de una cuenta. La entrega puntual de fuerza aceptada anteriormente no constituye
una autorización automática para las siguientes asignaciones.

Recorrido vigente: publicar una receta → asignarla al alumno con fecha → el
alumno activa «Sincronización automática» en Perfil → Conexión con Garmin →
Sesiones en Garmin → el servidor procesa las citas compatibles de hoy y los
próximos catorce días → Garmin confirma su calendario → Connect sincroniza
con el reloj. Una receta guardada sin cita no inicia ese recorrido. Las citas
pasadas no se recuperan al activar el automático. «Enviado» acredita Garmin,
no una recepción confirmada por el dispositivo físico.

La fuerza ya participa en el automático mediante INT-013, con sus capacidades
actuales: series convencionales de banca con barra, flexiones y dominadas
pronadas identificadas por el catálogo. No equivale a exportar cualquier ejercicio
o formato del creador; superseries, circuitos, EMOM y AMRAP siguen fuera de esta
traducción. [Contrato de fuerza](DEVICE_GARMIN_TRAINING.md#fuerza--recorrido-solicitado-int-013).

Revisión sin escrituras de preferencias, citas o resultados: se contrastan
conexión, derechos, preferencia, recibos, cola y cron de Dev. Pasan cuarenta
pruebas existentes de servidor sobre envío, sincronización y fuerza y diez
pruebas del consumidor de entregas. No acredita una nueva llegada al reloj.
La identificación de la sesión comunicada por Javier y la prueba física de una
cita futura con el automático activado siguen pendientes. En esa comprobación
inicial, el interruptor estaba dentro del envío manual y solo había contadores
agregados. El ajuste siguiente mejora su descubrimiento; el diagnóstico por cita
en Trainer sigue pendiente. Esa limitación no debe confundirse con un envío hecho.

## Acceso visible al automático · 25/10/2026

Perfil → Conexión con Garmin muestra directamente «Sincronización automática»
cuando la cuenta está conectada, con derecho vigente y permiso de envío. Expresa
el estado activado/desactivado o sin confirmar; durante la consulta no admite
cambios. «Envío manual y estado de sesiones» abre el recorrido anterior como
acción secundaria. Los permisos se consultan en un desplegable; las actividades
recibidas y la desconexión permanecen disponibles.

`TrainingSyncPanel` reutiliza `TrainingSyncRepository` desde conexión y envío,
sin duplicar preferencias, SQL o permisos. El router compone el adaptador para
la misma cuenta. Una nueva generación descarta el panel anterior; las respuestas
tardías no modifican otra conexión. Una escritura sin respuesta fiable muestra
estado sin confirmar y exige volver a consultar, sin anunciar éxito ni repetir
la escritura. No se activa el automático al conectar, al abrir la página o al
instalar esta actualización.

La ayuda plegable explica biblioteca frente a asignación, fechas de hoy y los
próximos catorce días, cambios/cancelaciones y el paso Garmin → reloj. Desactivar
no retira lo ya enviado. No se presenta la aceptación de Garmin como acuse del
dispositivo físico.

Validación local: análisis completo sin incidencias, 1.353 pruebas del deportista
correctas y una omisión previa. Cuatro regresiones nuevas cubren acceso directo
en móvil sin consentimiento implícito, permisos, respuesta perdida y consulta
posterior, cambio de generación y 320 px con texto doble. La captura de widgets
reales con datos de ejemplo se revisa fuera de Git. No hay escrituras de prueba
en cuentas reales. La instalación y aceptación de esta pantalla en el iPhone
requieren actualizar main y reinstalar con el preparador Dev y Xcode habituales.

## Comportamiento

La cuenta activa «Sincronización automática» directamente en Perfil → Conexión
con Garmin; también sigue disponible dentro del envío manual. Requiere conexión
con permiso de escritura y derechos Pro o servicio
profesional vigentes, comprobados por el servidor. La opción empieza apagada y
se liga a la generación de conexión: reconectar no autoriza otra cuenta Garmin.
Desactivarla detiene nuevos pasos externos; no equivale a cancelar la agenda.

La primera entrega Dev usa una ventana móvil de catorce días, contando desde
hoy en Europe/Madrid. Son candidatas las citas `planned` sin ejecución, de
origen `coach` o `algorithm`, con receta publicada y versión coherente. Las
sesiones de biblioteca no se exportan por esta vertical. INT-013 incorpora
después la fuerza convencional compatible descrita arriba. La receta
se normaliza y se comprueban sus capacidades antes de crear un objeto remoto.

El conciliador revisa transacciones confirmadas, sin triggers HTTP ni cambios
en el flujo profesional. Detecta fecha, versión y retirada; las citas ya
entregadas siguen siendo observadas aunque se muevan fuera de la ventana.
Cancelación, omisión y borrado de una cita futura retiran su calendario y el
workout creado por EntrenaOP. El reset real del plan adaptativo también se
detecta aunque haya borrado la cita. Una decisión sustituida no produce nuevos
envíos. Las citas comenzadas o históricas no se reescriben ni se retiran.

La actualización conserva `workoutId` y `scheduleId`: PUT de la receta y PUT
del calendario. La retirada usa DELETE primero del calendario y después del
workout propio; un 404 al repetir DELETE acredita que ya no existe. Nunca se
borran actividades completadas del deportista ni se buscan objetos por nombre.
La aceptación en la API acredita el calendario Garmin; Garmin Connect debe
sincronizar con el reloj. No acredita recepción física, transiciones o avisos.

## Fronteras y recuperación

`TrainingSyncService` pertenece al dominio de entrega, sin Flutter, Supabase o
cron. Depende de puertos de cola, concesión cifrada y ciclo de vida del
proveedor. Para la primera creación reutiliza `TrainingDeliveryService`.
`GarminTrainingClient` traduce los PUT/DELETE a los recursos de Training API V2
2.0 documentados localmente; no introduce tipos de Garmin en el creador.

Preferencias, cola, generaciones, versiones y permisos viven en
`device_private`, con RLS y sin acceso directo de cliente ni service role.
Las fachadas RPC de servidor tienen grants explícitos; las funciones con
privilegios permanecen en el esquema privado. El endpoint manual verifica Auth
y sesión viva; solo el trabajador puede presentar una orden reclamada para
autorizar la entrega sin una sesión móvil abierta. No reenvía campos de prueba
del cuerpo de una petición de Flutter.

La cola tiene identidad por cuenta/cita, epoch, lease de tres minutos y
reintentos con espera exponencial hasta una hora. Cada nueva escritura vuelve
a contrastar preferencia, generación, conexión y objetivo actual. La conexión
comparte su lease entre envío manual, automático y desconexión. Se pueden
guardar hechos ya aceptados y liberar el lease aunque cambie la autorización
durante HTTP; eso no permite iniciar el siguiente paso externo.

Las versiones previas del recibo se conservan antes de modificarlo. Un POST de
creación incierto sin identificador no se repite: queda en revisión. PUT y
DELETE sobre identificadores conocidos se pueden reintentar después de perder
una respuesta. Un refresh ambiguo frena la concesión. Cambiar de generación con
efectos anteriores, un objeto desaparecido al actualizar o una receta no
representable también requieren revisión. Reabrir una cita cuyo workout ya se
retiró exige resolver esa revisión; no se crea una copia silenciosa.

## Planificador y operación Dev

`garmin-training-sync` verifica proyecto Dev y `GARMIN_ENVIRONMENT=DEVELOPMENT`
antes de operar. Cron invoca una vez por minuto mediante pg_net. El conciliador
revisa hasta 200 cuentas por tick y el trabajador procesa hasta cuatro órdenes,
con límite de tiempo entre trabajos. Es una cola eventual, sin promesa de
entrega instantánea; una acumulación retrasa el procesamiento.

La extensión pg_net pertenece a `supabase_admin` y sus concesiones SQL son
administradas por la plataforma. La invocación no deja un secreto permanente
en su cola: cada dispatch genera 32 bytes aleatorios, guarda solo su hash y
vence a los 55 segundos. El endpoint consume el ticket una sola vez de forma
atómica. La petición no admite un propietario, receta o acción remota elegidos
por quien la invoque. La siguiente ejecución reemplaza la capacidad anterior.

Las migraciones crean infraestructura sin activar cuentas ni programar trabajo
por defecto. La operación explícita es:

```powershell
supabase db query --linked --project-ref sxbxfjqgoddzhtcyhalw --file tools/enable_garmin_training_sync_dev.sql
```

La ruta contiene solo instrucciones, sin secretos. La activación global no
enciende preferencias de usuarios. Para detener el trabajador sin modificar
recibos, desactivar el job `garmin-training-sync-dev` y
`device_private.training_sync_worker.enabled` mediante operación de servidor.
No ejecutar esa configuración contra producción.

## Revisión del ciclo completo · 25/10/2026

Javier prioriza Garmin: envío automático, cambios, retiradas y vuelta de
resultados. Huawei, Suunto, COROS y Apple Watch se posponen. La receta común
del editor conserva su independencia del proveedor.

La consulta autenticada del deportista añade `progress` a su listado actual.
La agenda profesional añade `device_training` exclusivamente a sus propias
asignaciones; no expone el estado de otra relación por compartir calendario.
Ambos clientes presentan el mismo modelo puro y tarjetas plegables. La consulta
no reclama trabajos, modifica consentimiento ni llama al fabricante. Su ventana
es de siete días anteriores a treinta posteriores, con máximo de sesenta citas;
el número mostrado corresponde a citas consultadas, no al total histórico.

El estado se calcula con cita, revisión, recibo, generación, preferencia y cola.
Un trabajo terminado sin entrega no aparece como enviado. Cambios pendientes,
retirada pendiente y retirada confirmada son estados distintos. Una cita pasada
retirada conserva su entrega histórica; una creación incierta requiere revisión
antes de cualquier copia. Completar manualmente no acredita resultados del reloj:
se exige una confirmación de actividad asociada a esa misma cita.

El trabajador conserva también el motivo de un recibo fallido devuelto por el
servicio de entrega. Los rechazos permanentes requieren revisión; los fallos
transitorios mantienen el reintento. Tras mover una entrega, el adaptador verifica
fecha y referencia del calendario antes de guardar la revisión nueva; el ACK
del PUT no basta. Se conservan los mismos identificadores.

Migración `20261025202144` aplicada selectivamente solo en Dev y cotejada con
el historial. Contratos transaccionales correctos, con ROLLBACK: progreso y
autoridad profesional, publicación automática/algoritmo, carrera, fuerza,
recepción de actividades, dispatch y conexión. Análisis limpios y baterías
completas: 1.358 pruebas raíz (una omisión previa), 238 Trainer y 316 ADMIN
(dos omisiones previas). Servidor: 154 pruebas y comprobación TypeScript estricta
correctas. No se amplían permisos públicos ni se incorporan dependencias.

Prueba real: una cita futura creada desde Trainer se entrega por el trabajador
sin envío manual. Javier confirma su presencia en el calendario del fēnix tras
sincronizar Connect. Cambio de fecha, retirada y nueva vuelta de resultados
siguen pendientes; no se presentan como aceptados por esa primera confirmación.

La prueba del portal detecta que PostgREST ejecuta la agenda STABLE en una
transacción READ ONLY: reutilizar la fuente con FOR SHARE hacía fallar su refresco,
aunque la asignación ya estaba guardada. La migración `20261025203348` extrae la
misma receta/autoridad a una función privada de snapshot sin bloqueos. El envío
conserva los bloqueos previos y delega en ese snapshot. La proyección usa la misma
política de selección sobre el snapshot de lectura; no puede autorizar escrituras.
Se añade regresión con una cita pendiente en transacción READ ONLY, además del
recorrido real con rol authenticated. Ambos pasan y las regresiones de envío,
publicación automática, fuerza y retorno siguen correctas.

La CI de Trainer detecta además que el runner limpio no resolvía las dependencias
de pruebas de proyectos anidados antes del análisis raíz. Se alinea su resolución
con ADMIN/Garmin, conservando lockfiles, análisis y todas las pruebas. La publicación
de esta revisión se registrará tras comprobarla.

## Evidencia anterior y siguiente recorrido

Las migraciones `20261022194351`, `20261022200041` y `20261022200710` están
aplicadas solo en Dev y cotejadas con el historial. Trabajador y envío están
desplegados. Cron acredita respuestas 200 con cero trabajos y ninguna cuenta
activada; las fixtures terminan con ROLLBACK y no dejan usuarios sintéticos.
Versiones observadas: `garmin-training` ACTIVE v6 y `garmin-training-sync`
ACTIVE v1. No se despliegan cambios de Trainer o ADMIN.
Código funcional `37a32d8315e725f1b5035d38acfd936d134016a1`, subido a main.
La [CI 39847659243](https://github.com/jchjdev/entrenaop/actions/runs/39847659243)
termina correctamente en backend, consumidor Flutter e iOS Release sin firma.

Validación local: análisis Flutter limpio, batería raíz 1.294 correctas y una
omisión previa; 128 pruebas de servidor correctas y tipos estrictos. Los
contratos SQL Dev cubren la publicación profesional, cambios, retirada,
autorización persistente, publicación real del algoritmo y reset. Pasan además
las regresiones de cuenta y envío manual. PostgreSQL aislado acredita una sola
toma entre dos trabajadores y exclusión real entre envío manual y automático.
La prueba de dispatch comprueba ticket falso, consumido y caducado, más el
freno global. ADMIN, Trainer y los paquetes compartidos no cambian en este tramo.

El asesor añade la información esperada de RLS sin políticas para las cuatro
tablas privadas sin acceso directo. También informa
[extension_in_public](https://supabase.com/docs/guides/database/database-linter?lint=0014_extension_in_public)
para los metadatos de pg_net: la extensión gestionada pertenece a
`supabase_admin`, no es reubicable y no contiene funciones miembro en `public`.
Se conserva ese aviso documentado; no se alteran catálogos del sistema para
ocultarlo. La invocación usa tickets efímeros consumibles, nunca un secreto
permanente en la cola administrada.

**Siguiente recorrido único:** actualizar el iPhone desde main, activar la
opción en la cuenta Dev y comprobar en Connect/fēnix una cita nueva del
entrenador; después cambiar receta/fecha y cancelarla, comprobando que se
conservan referencias y se retira su calendario. Repetir con una semana del
algoritmo. La recepción física y los nuevos pasos Lap/fartlek siguen pendientes;
las fixtures y el cron vacío no se presentan como pruebas del reloj.

Fuentes de infraestructura: [planificación de funciones](https://supabase.com/docs/guides/functions/schedule-functions)
y [pg_net](https://supabase.com/docs/guides/database/extensions/pg_net).
