# Apple Watch · WorkoutKit · INT-023

Javier autoriza el 28/10/2026 comenzar Apple Watch después de acreditar el
recorrido Garmin. Garmin conserva sus funciones, evidencias y límites. No se
reabre el editor ni se convierte la receta común en un contrato de fabricante.

## Prueba física comunicada · 31/10/2026

Javier identifica el reloj de Isabel como Apple Watch SE de segunda generación,
con watchOS 26.6 según el dispositivo. Confirma que EntrenaOP muestra
«Programación autorizada» y comunica que, tras enviar manualmente una carrera
existente, ve una fecha futura y sus pasos durante la prueba del reloj.
Es evidencia comunicada de autorización y recepción de la pauta; no se da por
comprobado el comportamiento completo de fases, avisos, cambios o retirada.

La ejecución se declara ficticia. Javier confirma después su aparición en Fitness
del iPhone emparejado. Después confirma que leyó la actividad de Salud y guardó
la observación en EntrenaOP.
No acredita un entrenamiento deportivo real ni completa la cita semanal.
Se conserva la separación entre pauta programada, actividad registrada por Apple
y observación importada en el historial propio. La importación manual no
asocia la actividad Apple a la cita ni registra sus resultados por pasos.
Se abre desde Apple Watch → «Leer
actividades de Salud» → «Leer carreras de Salud»; requiere autorizar lectura de
entrenamientos, revisar la actividad y pulsar «Guardar seleccionadas». Importar
esta observación no da por completada una sesión ni convierte la prueba ficticia
en un resultado deportivo real.

## Retorno automático de pautas propias · 31/10/2026

Javier pide eliminar la selección/guardado repetitivos y compartir con el
preparador los datos de la actividad, como en el recorrido Garmin. El primer
retorno automático de Apple se implementa solo en Dev:

- Activación inicial por cuenta en Apple Watch, con petición separada de lectura
  de Entrenamientos y frecuencia cardiaca. Programar con WorkoutKit no concede
  lectura de Salud. HealthKit no permite acreditar lectura concedida a partir
  de una consulta vacía.
- El arranque, regreso a primer plano y comprobación periódica mientras la app
  permanece abierta disparan un caso de uso puro, con exclusión y comprobación
  de cuenta/sesión después de cada espera. No se promete entrega con la app
  cerrada; no se han activado observadores ni permisos de ejecución en segundo
  plano. El guardado requiere la preferencia vigente también en servidor.
- Se leen como máximo 200 carreras de los últimos 14 días. Solo se devuelven
  actividades cuyo `HKWorkout.workoutPlan.id` corresponde a una pauta exportada
  de la cuenta. Se compara además su contenido con la receta compilada por el
  mismo adaptador de envío. No se enlaza por nombre, fecha, aplicación escritora
  ni proximidad de métricas. Un getter de `workoutPlan` que no resuelva queda
  acotado y no provoca una asociación supuesta.
- El servidor revalida dueño, derechos, consentimiento, referencia de entrega
  y revisión/fuente actual. Identidad de importación: cuenta + UUID HealthKit.
  Releer no duplica; una medición ausente que llega después enriquece el resumen.
  Se conservan revisiones y una contradicción queda para revisar sin reemplazar
  silenciosamente el resultado aceptado.
- La semana del deportista y el detalle de la pauta en Trainer utilizan tarjetas
  compartidas y plegables con tiempo `m:ss`, distancia y FC cuando existen. Solo
  el preparador de esa asignación con acceso profesional y relación vigente
  recibe el resumen; no obtiene el historial general de Salud. El deportista
  conserva acceso a sus resultados anteriores al desactivar la recogida.
- El estado es resultado recibido, pendiente de revisión o prueba. Los totales
  no completan automáticamente cada paso ni inventan RPE, vueltas, series o
  alertas cumplidas. Incorporar resultados por intervalos y cerrar la ejecución
  exige un bloque posterior con evidencia física de esas mediciones.
- Las pruebas se identifican separadamente y no crean ejecuciones deportivas.
  La actividad ficticia de esta comprobación queda señalada en Dev mediante una
  referencia privada; sus identificadores y métricas no se guardan en Git.

Persistencia: `apple_result_preferences`, `apple_result_test_markers`,
`apple_activity_results` y `apple_activity_revisions`, privadas y con RLS. RPC
autenticadas con sesión vigente; ninguna concesión comercial depende del móvil.
El endpoint Dev `apple-training` añade acciones `results.*` sin cambiar OAuth,
colas ni confirmaciones de Garmin. La lectura básica/manual de Salud sigue Free.

**Validación técnica · 31/10:** análisis de raíz, ADMIN y Trainer sin incidencias;
batería completa de raíz (1.547 correctas y una omitida), ADMIN (365 correctas y
dos omitidas) y Trainer (415 correctas); ocho pruebas focalizadas de retorno y
dos de la tarjeta compartida. Servidor: 230 pruebas y TypeScript estricto.
Contrato SQL transaccional aplicado en Dev con ROLLBACK, incluidos consentimiento,
cuenta/sesión, replay, enriquecimiento, conflictos, pruebas y acceso profesional;
regresiones de programación Apple, retorno y progreso Garmin correctas. Las
261 migraciones coinciden. Endpoint Apple Dev v6 ACTIVE, JWT obligatorio y sus
tres archivos contrastados con el código local. Índices de las nuevas referencias
comprobados; tablas privadas con RLS y sin acceso directo. La compilación nativa
de esta ampliación se valida en CI antes de pedir instalarla.
Falta contrastar el nuevo lector y la referencia
de la actividad en el iPhone recompilado; la importación manual ya comprobada
no acredita esta nueva recogida automática.

## Primer recorrido de desarrollo

- Carrera exterior pautada por entrenador o algoritmo, en los próximos 14 días.
- iPhone con iOS 18 y Apple Watch con watchOS 11 o posteriores. La app mantiene
  su mínimo general iOS 15: esta función consulta disponibilidad antes de pedir
  autorización. Un Series 2 no es compatible. El Ultra es candidato a la prueba,
  pendiente de conocer sus versiones y disponer del iPhone emparejado.
- WorkoutKit programa en Entreno de Apple, sin app watchOS propia ni credenciales
  de una API cloud. La autorización es explícita y propia de este teléfono.
- Calentamiento/enfriamiento en extremos, trabajo, recuperaciones, final por
  tiempo/distancia/avance manual y alertas de ritmo. El primer adaptador conserva
  el orden expandido de la receta y la recuperación final realmente pautada.
  Apple clasifica caminar/trotar/descanso como recuperación: su nombre mantiene
  la indicación. No se presentan como perfiles deportivos independientes.
- Mismo UUID por cuenta y cita para reprogramar fechas y revisiones. Solo se
  retiran los planes de esta app identificados por el servidor autenticado.
  No se usa `removeAllWorkouts`. Se valida la receta completa antes de retirar
  la revisión anterior y se comprueban identidad, fecha, contenido y ausencia de copias en el calendario
  local después de la operación. No se reprograman planes que Apple ya marca hechos.

## Fronteras y permisos

`features/apple_watch/domain` contiene modelos, puertos y orquestación sin SDK.
La composición está en el router; presentación recibe el servicio. Los adaptadores
usan Supabase y el canal nativo existente; `AppleWorkoutBridge` encapsula WorkoutKit,
separado del lector HealthKit. No se añade una dependencia de terceros.

La función `apple-training` solo se activa en el proyecto Dev conocido con
`APPLE_WORKOUTS_ENVIRONMENT=DEVELOPMENT`. Mantiene `verify_jwt=true`; PostgREST
comprueba el bearer del usuario y SQL exige sesión viva, cuenta esperada y ausencia
de identidad anónima. No utiliza credenciales Garmin ni `service_role` para RPC.
El servidor comparte una política comercial entre transportes: Pro o servicio de
entrenador vigente. La lectura básica de Salud conserva el acceso Free acordado.

El servidor obtiene la receta de la misma fuente autorizada que Garmin. Se reutiliza
el compilador deportivo TypeScript, sin importar el adaptador Garmin. La revisión
se contrasta antes de preparar; un intento con arrendamiento de 90 segundos evita
escritores simultáneos, y el ACK exige revisión, intento y sesión originales. Un
cambio de cuenta o fallo nativo impide registrar éxito. Los recibos solo acreditan
programación local; no recepción física ni ejecución. Los registros privados tienen
RLS y las citas con referencia Apple conservan protección de borrado y opción de
archivo profesional. La comprobación se coordina con Arquitectura; se mantienen
íntegras las condiciones existentes de resultados y Garmin.

## Recorrido y límites

Perfil → Dispositivos y conexiones → Apple Watch → Autorizar → revisar carrera →
Programar. El permiso del sistema y el derecho comercial son independientes.
Para un cambio se revisa y programa de nuevo la misma cita. Para retirarla se usa
su tarjeta en «Programadas desde EntrenaOP», también después de vencer el servicio.
El permiso puede revisarse en Ajustes; esta primera entrega no revoca permisos del
sistema desde Flutter.

El envío parte del iPhone emparejado y requiere abrir y revisar:
**no implementa sincronización automática desde la nube ni mientras la app está
cerrada**. Los recibos preparados sin ACK se conservan como pendientes, nunca como
éxito; ante una operación incierta se revisa antes de repetir. La fuerza y las
métricas avanzadas no se exportan en este bloque.

La actividad terminada conserva el recorrido manual de Salud y añade la
recogida automática de pautas propias descrita arriba. Aún no se importan sus
intervalos ni se completa automáticamente la cita semanal.

La asociación exacta utiliza la propiedad pública asíncrona
`HKWorkout.workoutPlan`, disponible desde iOS 17/watchOS 10 al importar WorkoutKit.
Ausencia, error o agotamiento del límite de espera quedan separados de la lectura
manual de Salud. No se usa metadata privada ni se bloquea el historial para
obtener el plan. Una referencia ausente no se reemplaza por nombre o fecha.

## Validación y siguiente paso

Contrato SQL transaccional con `ROLLBACK`: ámbito de cuenta, sesión revocada,
acceso comercial, pauta obsoleta, exclusión, ACK ajeno, estabilidad del UUID,
retirada tras vencer servicio y protección de borrado. Se ejecutan además las
regresiones SQL de conexión Garmin y ciclo de vida profesional. Pruebas Dart de
fallos, permisos, concurrencia y cambio de cuenta; pruebas HTTP de configuración,
bearer, receta del servidor, rechazo de incompatibilidad y ausencia de filtraciones.
La CI existente incorpora el nuevo adaptador, compila iOS sin firmar y comprueba
que WorkoutKit se enlaza débilmente para conservar el arranque en iOS anteriores.

Validación del 28/10 sobre el `main` compartido: análisis raíz sin incidencias;
1.437 pruebas correctas y una omitida, incluidas las nueve de Apple; 191 pruebas
HTTP/servidor del punto inicial y tipos TypeScript estrictos correctos. Tres
contratos SQL con ROLLBACK correctos. Las 247 migraciones locales/remotas coinciden
con Dev tras integrar también el punto comercial del otro chat.

La función `apple-training` está ACTIVE, versión 5, con JWT de plataforma
activado; su fuente desplegada coincide con la versionada. Sin JWT o con bearer
inválido responde 401. Una sesión real conservada en el navegador integrado
carga correctamente su planificación desde la nueva función; en web se informa
de que la programación requiere el iPhone. No se han copiado credenciales ni
programado sesiones Apple desde el navegador.

[CI del código `c83fc433`](https://github.com/jchjdev/entrenaop/actions/runs/40766803421):
servidor, consumidor Flutter e iOS release sin firma correctos, incluida la prueba
del enlace débil de WorkoutKit. Los primeros cambios están guardados en
`57271990`; el ajuste de comprobación del contenido y de sesiones ya realizadas,
en `c83fc433`. No se modifica el mínimo iOS general.

El asesor de seguridad solo señala para la nueva tabla el aviso
[INFO de RLS sin políticas](https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy):
es intencional en el esquema privado, sin acceso directo de clientes y con acceso
mediante el comando autenticado. No se añaden políticas de lectura a la tabla.

No se acredita instalación ni recepción Apple con una compilación o un ACK.
**Siguiente recorrido único:** contrastar la actividad ficticia en Fitness/Salud
del iPhone emparejado con el SE de segunda generación y su lectura desde
EntrenaOP. Después quedan la ejecución real de fases/avisos, el cambio y la
retirada de la pauta. La recepción comunicada no cierra esas comprobaciones.
El bloque permanece abierto hasta esa aceptación física.

## Referencias oficiales

- [WorkoutKit](https://developer.apple.com/documentation/workoutkit).
- [Plan asociado a una actividad de Salud](https://developer.apple.com/documentation/healthkit/hkworkout/workoutplan).
- [WorkoutScheduler](https://developer.apple.com/documentation/workoutkit/workoutscheduler).
- [Paso con nombre: iOS 18/watchOS 11](https://developer.apple.com/documentation/workoutkit/WorkoutStep/init(goal:alert:displayName:)).
- [Diseño y programación de entrenamientos, WWDC23](https://developer.apple.com/videos/play/wwdc2023/10016/).
