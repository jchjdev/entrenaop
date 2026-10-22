# Sincronización automática de carrera · INT-010 · 22/10/2026

Javier autoriza publicar, modificar y cancelar automáticamente las carreras del
entrenador y del algoritmo, exclusivamente en desarrollo. Se reutiliza la
prescripción independiente del proveedor y la conexión vinculada a la cuenta.
No se modifican los RPC, pantallas o contratos de publicación de Trainer.

## Comportamiento

La cuenta activa «Sincronización automática» en Perfil → Garmin → Carreras en
Garmin. Requiere conexión con permiso de escritura y derechos Pro o servicio
profesional vigentes, comprobados por el servidor. La opción empieza apagada y
se liga a la generación de conexión: reconectar no autoriza otra cuenta Garmin.
Desactivarla detiene nuevos pasos externos; no equivale a cancelar la agenda.

La primera entrega Dev usa una ventana móvil de catorce días, contando desde
hoy en Europe/Madrid. Son candidatas las citas `planned` sin ejecución, de
origen `coach` o `algorithm`, con receta publicada y versión coherente. Las
sesiones de fuerza o de biblioteca no se exportan por esta vertical. La receta
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

## Evidencia y siguiente recorrido

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
