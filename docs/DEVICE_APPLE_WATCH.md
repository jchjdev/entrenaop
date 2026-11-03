# Apple Watch · WorkoutKit · INT-023

## Tipos de fase y ritmo pertinente · 03/11/2026

La lista recibida de Salud deja de tratar todas las actividades nativas como
intervalos de carrera. La proyección privada añade el tipo **según la pauta**,
sin afirmar que Apple haya enviado una etiqueta de descanso. HealthKit utiliza
el mismo deporte para trabajo y recuperación; no se leen claves privadas.

Es una ayuda de presentación que no modifica el mapa de series ni el cierre
automático. Si existe un mapa confirmado, se respeta: permite varias vueltas por
fase y un orden revisado, sin etiquetar las vueltas que dejó sin asociar. Sin
mapa confirmado, la interpretación solo admite igual número de fases o una
única omisión, con un máximo de cien. Enumera las correspondencias en orden y conserva un tipo
únicamente si todas las compatibles coinciden. Una fase pautada por tiempo no
puede contener un temporizador mayor que el objetivo más dos segundos de
frontera; adelantar con Lap es válido. No compara velocidad, distancia objetivo
ni rendimiento. Una actividad global, varias omisiones, un conflicto o tipos
ambiguos quedan sin identificar. No cambia los datos registrados, no atribuye
series ni inventa medidas ausentes.

La tarjeta común usa «fases registradas», nombre e icono por tipo y color en
calentamiento/carrera/enfriamiento. Descanso, recuperación libre y fase dudosa
omiten ritmo; una recuperación con objetivo de ritmo explícito sí lo conserva.
El ritmo global sigue siendo el cociente de los totales del reloj. Garmin ya
aporta intensidad e índice FIT y su resultado distingue recuperación y trabajo;
este cambio no sustituye esa correspondencia nativa por una inferencia Apple.

La grabación existente se consulta dentro de una transacción con ROLLBACK:
identifica calentamiento, primeras carreras/recuperaciones y enfriamiento;
conserva sin tipo las fases finales ambiguas. La recuperación de pocos metros
ya no ofrece ritmo. No se modifica la observación ni la ejecución Garmin que
ya cerró esa pauta. `apple_recorded_phase_labels.sql` cubre coincidencia,
omisión, ambigüedad, fronteras, ritmo de fartlek y aislamiento del helper.

Referencia: [actividades de HealthKit](https://developer.apple.com/documentation/healthkit/dividing-a-healthkit-workout-into-activities).

Validación previa a publicar la vista: análisis de las tres apps sin incidencias;
baterías completas raíz/Trainer/ADMIN, 1747/449/370 correctas (omisiones previas
1/0/2), y ocho contratos SQL transaccionales con ROLLBACK. Migración aplicada
exclusivamente en Dev y asesores de seguridad sin avisos nuevos. Las versiones
de esta corrección son deportista `1.5.2+13`, Trainer `0.3.2+8` y ADMIN `0.3.2+7`.

**Ritmo en las grabaciones · 03/11/2026:** el resumen del reloj y cada intervalo
identificado donde el ritmo es pertinente, con tiempo y distancia observados
positivos, muestran el ritmo calculado en
minutos y segundos por kilómetro. Se usa el temporizador original sin redondear
y la distancia medida, nunca la pauta o el tiempo con pausas. Sin metros o con
distancia cero no se muestra ritmo. El redondeo del resultado conserva el cambio
de minuto. La tarjeta común sirve al deportista y a los paneles profesionales.

Corrección `8854e6a6` publicada y cotejada por HTTPS, versión y SHA-256 en
Trainer Dev `0.3.1+7` y ADMIN Dev `0.3.1+6`. Se contrasta visualmente el ritmo
medio y el de los intervalos de la grabación existente, con el campo oculto
cuando falta distancia. Raíz `1.5.1+12` guardada para la siguiente instalación
del iPhone. Análisis de las tres apps y baterías completas correctos
(1745/449/370; omisiones existentes 1/0/2); también CI de servidor, consumidores,
iOS Release y ensayo de Salud Android/iOS. No cambian las medidas ni la pauta.

## Resultado parcial y grabaciones por dispositivo · 03/11/2026

La relectura de la grabación existente no añade las medidas ausentes. La
corrección separa la finalización acreditada de una sesión y la atribución de
sus intervalos a las series de la pauta. Si el mapa completo no es seguro, la
recepción automática puede cerrar la pauta mediante su referencia WorkoutKit
exacta, conservando totales e intervalos originales. Las series quedan sin
detalle individual; no se consideran completadas, omitidas ni evidencias de
progresión. El resultado explica esa limitación y no calcula una valoración
por serie a partir del total.

Se mantienen identidad y sesión viva, permiso, pauta vigente, revisión de
fuente, ventana de cero a siete días, exclusión de pruebas y conflictos, y
transacción idempotente. Un resultado global sin fases nativas continúa en
revisión. El cierre con series sin atribución exige un recibo Apple privado;
la finalización manual ordinaria sigue rechazando series pendientes. Si otra
grabación ya completó la cita, no se crea otra ejecución ni se cambia su fuente.

`my_execution_device_details` ofrece al titular su consulta acotada. Los
lectores profesionales amplían sus resultados después de las comprobaciones
existentes de autoría o consentimiento compartido. Las tarjetas comunes de
grabaciones son plegables y muestran cada intervalo con tiempo y solo las
medidas existentes. No publican identificadores nativos, referencias privadas,
metadatos, localización ni credenciales. Las distancias ausentes siguen siendo
NULL. Apple y Garmin conservan sus medidas independientes.

La comprobación de medidas contempla también pasos por tiempo: el formato
canónico de carrera exige distancia observada aunque no sea el objetivo de
finalización. Si falta, o una recuperación registrada no cabe en sus campos
canónicos (por ejemplo, subsegundo o cero metros), se conserva el cierre parcial
y el intervalo nativo íntegro, sin convertir ausencias en cero ni rechazar
todo el entrenamiento. Los valores cero realmente registrados se conservan.

Se reproduce también la grabación real existente en una copia de pauta y
cuentas sintéticas, dentro de una transacción con ROLLBACK: cierra la sesión,
conserva todos los intervalos y medidas, deja las series sin atribución y permite
su consulta por el autor. La observación original y la ejecución de Garmin
mantienen sus huellas e identidad. No se crea otra ejecución real de la cita.

Trainer Dev `0.3.0+6` y ADMIN Dev `0.3.0+5`, revisión `801a393c`, están publicados
y cotejados mediante HTTPS, versión, SHA-256 y proyecto exclusivamente Dev.
Se abre la sesión real en Para mí → Ver resultados: la grabación Apple ofrece
su lista plegable, se contrasta su último intervalo y se comprueba que los
intervalos sin distancia no muestran metros inventados. La grabación Garmin
permanece independiente. La app del deportista incorpora el mismo componente
en `1.5.0+11`, guardado en GitHub; su instalación física no se sustituye por la
publicación web. Esto no acredita fuerza Apple ni una nueva prueba física de
segundo plano o del contador nativo.

CI de la revisión de cliente publicada: servidor y consumidor correctos,
compilación iOS Release Dev sin firma correcta, y ensayo de Salud Android e
iOS con la app del deportista correctos. GitHub canceló inicialmente los dos
trabajos Mac antes de adquirir servidor por falta de capacidad; se reintentaron
solo esos trabajos y terminaron correctamente, sin retirar comprobaciones.
[Verificación de integración](https://github.com/jchjdev/entrenaop/actions/runs/41691587175),
[ensayo de Salud](https://github.com/jchjdev/entrenaop/actions/runs/41691587171).

## Comprobación con la grabación existente · 03/11/2026

Javier recuerda que la carrera usada para validar Garmin se grabó también con
Apple Watch y pide aprovecharla. Se consulta la observación Apple existente:
recepción posterior a su finalización, referencia a la pauta correcta, recogida
activada y datos de tiempo, distancia total, pulso e intervalos conservados. No
se exige repetir la carrera ni se modifica la ejecución ya cerrada con Garmin.

La observación Apple contiene una fase menos de las que espera la receta y
varios intervalos cortos sin distancia. `apple_automatic_mapping` devuelve NULL
ante ese número distinto de fases. Esta comprobación acredita recepción y
vinculación, pero no cierre autónomo Apple ni correspondencia individual segura
de todas sus fases. No se distribuye la distancia total para llenar ausencias ni
se interpretan distancias ausentes como cero. Se solicita una relectura desde el
iPhone para contrastar posibles mediciones tardías de Salud; los datos originales
y los resultados Garmin permanecen protegidos.

Estado del código contrastado: el observador de Salud en segundo plano sí está
implementado, conectado al arranque, al plugin y al coordinador, con entitlement
nativo. La pantalla informa si esa instalación lo ha podido activar. La hora de
recepción por sí sola no acredita que el teléfono estuviera en segundo plano.
Los apartados históricos de primer plano describen etapas anteriores. Fuerza
Apple sigue sin implementar: exportador y lector actuales solo admiten carrera.

**Repeticiones nativas · 03/11/2026:** `repeatBlocks` es una proyección opcional
del compilador común. El canal conserva todos los pasos y construye bloques
WorkoutKit con sus vueltas, en vez de un único bloque con una vuelta. Al leer
resultados se compara exactamente con composición nueva y anterior para
conservar las pautas ya enviadas. Sin metadatos se mantiene el formato anterior.
Omitir la recuperación final necesita separar el último trabajo en Apple;
no se añade una recuperación ficticia. La aceptación visual del contador sigue
pendiente. [Contrato](RUNNING_STEPS_V2.md#repeticiones-nativas-al-exportar--03112026).

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

## Recepción real y consulta en Trainer · 01/11/2026

Javier completa una carrera real registrándola con Garmin y Apple Watch para
comparar las integraciones. Confirma y muestra su registro en Fitness, con sus
fases e información deportiva. La doble grabación es un ensayo, no un nuevo
requisito de uso simultáneo de fabricantes.

Tras activar la recogida automática en el iPhone actualizado, Dev recibe la
actividad real y la prueba ficticia anterior, conservadas por separado. La
referencia de WorkoutKit enlaza ambas a la pauta original; HealthKit entrega
las tres actividades internas y sus mediciones. Se contrasta el resumen real
en el servidor y en Trainer → Para mí → Planificación → Todas → pauta original:
fecha de ejecución, tiempo, distancia, FC y número de intervalos. La tarjeta
plegable mantiene la prueba ficticia identificada. Esta comprobación utiliza
la misma cuenta en su espacio profesional propio; no acredita una aceptación
física con otro alumno y otro preparador.

La pauta original estaba archivada y anulada; el resultado se conserva como
recibido y pendiente de revisión para incorporarlo a una ejecución. Se verifica
la consulta profesional sin restaurar la pauta ni completar una sesión.
Javier aclara que la aceptación de este ensayo es ver los datos en Trainer,
no cerrar la cita. La importación manual de Salud es otro recorrido: que muestre
un registro de Garmin no acredita el retorno de la conexión directa Garmin.

En la primera comprobación, el aviso directo de la nueva actividad Garmin llega
a Dev, pero el importador lo deja en revisión con `invalid_activity`. Los registros anteriores y las
pruebas Garmin aceptadas no acreditaban este archivo nuevo. Se localiza después
la validación que falla mediante el original autenticado de Garmin Connect;
la corrección y el reenvío oficial se acreditan a continuación.
No se reintenta un callback de descarga ya consumido ni se inventan sus vueltas.
Identificadores privados, métricas exactas y capturas del ensayo quedan fuera de Git.

La recepción real de Apple está comprobada en servidor y consulta propia de
Trainer. El ensayo del retorno directo Garmin también queda comprobado después
de la corrección siguiente. No requiere otra carrera ni completar la pauta
archivada. La consulta sobre una pauta vigente por otro alumno y preparador
es la siguiente aceptación de retorno; los recorridos Apple de cierre,
fases/avisos, cambios y retirada conservan sus aceptaciones pendientes.

**Actualización posterior del 01/11:** el FIT original identifica el rechazo por
un desfase acotado de fronteras. Se corrige el validador y un reenvío oficial ya
acredita recepción de todas sus vueltas en Dev. Se implementa una bandeja privada
en Trainer/Para mí para consultar este retorno sin cerrar la pauta archivada.
[Corrección, consulta y validación actual](DEVICE_GARMIN_ACTIVITY_RETURN.md#bandeja-privada-de-recepción-en-trainer--01112026).
Trainer Dev publica `a1997319`; la sesión real muestra la carrera Garmin en
«Mis actividades recibidas», con tiempo, distancia, pulso y ocho vueltas. La
pauta archivada sigue sin completar. CI de Trainer, ADMIN y Garmin/iOS correctas.
La aceptación de consulta propia de ambos proveedores queda acreditada; esto
no certifica el recorrido completo Apple ni otro contexto alumno/preparador.

### Sesiones realizadas otro día · margen acordado

Javier plantea que una sesión pendiente pueda completarse al realizarla días
después de la fecha prevista, con un límite razonable. Se conservarían la fecha
pautada y la fecha real, tomando la realización y no la llegada de la sincronización.
Javier confirma el 01/11 el margen de hasta siete días posteriores. Aún no se ha
implementado un nuevo límite. Una anulación o sustitución explícita se distingue
de una sesión simplemente pendiente. El criterio será común a los proveedores;
queda concretar y validar su efecto en planificación e historial antes de aplicarlo.

## Retorno automático de pautas propias · 31/10/2026

Javier pide eliminar la selección/guardado repetitivos y compartir con el
preparador los datos de la actividad, como en el recorrido Garmin. El primer
retorno automático de Apple se implementa solo en Dev:

- Activación inicial por cuenta en Apple Watch, con petición separada de lectura
  de Entrenamientos, frecuencia cardiaca, distancia y esfuerzo registrado. Programar con WorkoutKit no concede
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
  utiliza ahora la revisión descrita en el siguiente apartado; su aceptación
  física sigue pendiente.
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
comprobados; tablas privadas con RLS y sin acceso directo.

**Publicación técnica comprobada:** `b2497f26` pasa
[iOS Release y consumidor](https://github.com/jchjdev/entrenaop/actions/runs/41222195025),
[Salud Android/iOS](https://github.com/jchjdev/entrenaop/actions/runs/41222194981),
[Trainer Dev](https://github.com/jchjdev/entrenaop/actions/runs/41222195784) y
[ADMIN Dev](https://github.com/jchjdev/entrenaop/actions/runs/41222195015).
Los manifiestos HTTPS de Trainer y ADMIN acreditan exactamente esa revisión,
entorno development y Supabase `sxbxfjqgoddzhtcyhalw`. El lector conserva una clase
separada en el archivo Swift ya registrado en CocoaPods, para mantener el flujo
habitual GitHub Desktop → Xcode del Mac al incorporar este código nativo.

Falta contrastar el nuevo lector y la referencia
de la actividad en el iPhone recompilado; la importación manual ya comprobada
no acredita esta nueva recogida automática.


## Intervalos y cierre de la cita · 31/10/2026

Javier pide entregar conjuntamente la recogida y el cierre, para instalar una
sola actualización desde GitHub Desktop y Xcode cuando el Mac quede disponible.
El nuevo adaptador lee las actividades internas de HealthKit con tiempo,
distancia y pulsaciones medidos, además de marcadores públicos y esfuerzo
registrado cuando existen. No reparte totales ni convierte la actividad por
defecto que cubre toda una receta con varias fases en una serie.

Desde el resultado recibido se abre su pauta exacta. La revisión común muestra
pasos plegables, permite asignar intervalos en orden mediante una acción expresa
y exige revisar la correspondencia. El esfuerzo entero registrado se propone;
si falta, se pide al confirmar. Un dato ausente conserva null. Una carrera que
requiere distancia no se acredita con un intervalo que carece de esa medición.
Sin intervalos utilizables se conserva el resumen, sin cerrar falsamente pasos.

El adaptador Apple implementa el mismo puerto de revisión y confirmación que
utiliza Garmin. El servidor vuelve a comprobar cuenta/sesión, derechos, referencia,
fuente y revisión; crea y termina la ejecución mediante los contratos comunes,
con tiempos originales. El cierre queda en semana, historial y seguimiento del
preparador vigente. Una distancia o FC que llega después, o un intervalo nuevo
ya cerrado, enriquece los intervalos existentes por su UUID sin perder las muestras anteriores. Se
revalida la combinación completa; modificar una medición existente sí señala
revisión y no altera el resultado aceptado.
El recibo privado de confirmación hace idempotente el reintento;
una actividad ficticia o un conflicto no pueden completar la semana.

La recogida al abrir/reanudar sigue siendo automática con consentimiento; el
cierre requiere esta revisión. No se añade ejecución con la app cerrada, envío
Apple automático desde nube ni fuerza. «Revisar permisos de Salud» permite pedir
las categorías nuevas tras actualizar. La lectura manual básica sigue Free.

**Validación técnica:** análisis de raíz, ADMIN y Trainer sin incidencias;
1.553 pruebas correctas y una omitida en raíz, 365 y dos omitidas en ADMIN,
420 en Trainer, 33 focalizadas de Apple/revisión y dos de tarjeta compartida.
232 pruebas de servidor y TypeScript estricto correctos. Cinco contratos SQL
con ROLLBACK: cierre Apple, retorno Apple, programación Apple, retorno Garmin y
progreso Garmin. Las 267 migraciones locales/remotas coinciden en Dev. Endpoint
Apple v7 ACTIVE con JWT obligatorio y fuente contrastada. La tabla privada de
confirmaciones tiene RLS y no permite acceso directo; su INFO sin políticas es
intencional, como en el resto del almacenamiento privado.

**Compilación y publicación de esta entrega:** `bbbef362` supera
[iOS Release y consumidor](https://github.com/jchjdev/entrenaop/actions/runs/41227035559)
y [Salud Android/iOS](https://github.com/jchjdev/entrenaop/actions/runs/41227035635).
La revisión conjunta `9ee9acfa` incluye ese código y las mejoras del otro chat;
[Trainer Dev](https://github.com/jchjdev/entrenaop/actions/runs/41227859256) y
[ADMIN Dev](https://github.com/jchjdev/entrenaop/actions/runs/41228571275) quedan
publicados y contrastados por HTTPS con esa revisión, entorno development y
proyecto `sxbxfjqgoddzhtcyhalw`. El ajuste posterior de enriquecimiento solo cambia
SQL; no añade otra actualización nativa ni necesita republicar las webs.
Las primeras publicaciones de `bbbef362` se detuvieron al avanzar main; sus
pruebas habían pasado. No se fuerza una publicación obsoleta.

**Aceptación física pendiente al 31/10:** nueva lectura de la referencia/intervalos
desde el iPhone, mediciones por fase y cierre de una sesión real. El apartado del
01/11 actualiza la aceptación del retorno y su consulta en Trainer. La prueba ficticia
anterior permanece separada y no acredita ese cierre. Siguiente recorrido único:
una sola instalación y contrastar lo que Salud entrega antes de confirmar una
actividad real. Las fases/avisos, cambios y retirada conservan sus pruebas físicas
pendientes; no se dan por verificadas mediante la CI.

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

Perfil → Dispositivos y conexiones → Apple Watch → «Sincronizar agenda
automáticamente». Se autoriza una vez por cuenta/instalación y se comprueba al
abrir/volver a EntrenaOP y cada minuto en primer plano. Se conserva revisar carrera
→ Programar para el envío puntual. El permiso del sistema y el derecho comercial
son independientes. Las actualizaciones automáticas usan la misma referencia.
La retirada manual desactiva el envío automático para que no se reponga la cita;
las cancelaciones de agenda se retiran sin apagarlo, incluso tras vencer el servicio.
El permiso puede revisarse en Ajustes; esta primera entrega no revoca permisos del
sistema desde Flutter.

## Agenda automática desde el iPhone · 03/11/2026

El material aportado muestra una carrera de hoy pendiente de programación, mientras
otras tienen recibos anteriores. Tras pulsar «Programar» aparece en Entreno del
reloj. Acredita la carencia del disparador automático anterior; no demuestra un
fallo de transporte de Apple ni permite medir el retraso de su transferencia.

- `SyncAppleTraining` concilia el catálogo autenticado existente con la fecha,
  receta y referencia locales de WorkoutKit; el adaptador no concede derechos.
- `AppleTrainingCoordinator` vive durante la sesión autenticada, fuera de la
  pantalla Apple, y separa autorización de envío y recogida de resultados.
- Preferencia local independiente por propietario e instalación, inicialmente
  apagada. Abrir una pantalla no solicita permisos ni activa envíos. El permiso
  de WorkoutKit del teléfono no se hereda como consentimiento de otra cuenta.
- Nuevas pautas, revisiones y reprogramaciones mantienen el UUID de la cita. Un
  recibo `submitted` sin pauta en este iPhone se reconcilia de nuevo; un calendario
  local idéntico no se reescribe. Lo ya completado en Apple o iniciado en EntrenaOP
  no vuelve a programarse.
- Las retiradas explícitas se procesan antes de altas; una ausencia en la lista
  limitada no basta para cancelar. Se confirma cada origen individualmente y se
  retira su antigua referencia si ha dejado de estar disponible o entra fuera de
  la ventana de programación. El historial de actividades no se borra.
- Una receta incompatible no impide el resto. Los fallos quedan pendientes y
  visibles; ningún fallo nativo se registra como envío confirmado. Cambiar de
  cuenta, desactivar o suspender primer plano corta la siguiente escritura/ACK.
- Sin push de agenda ni tarea de envío en segundo plano: si el iPhone no vuelve
  a ejecutar EntrenaOP no se descarga la nueva pauta del servidor. La transferencia
  final de WorkoutKit a Entreno depende de Apple y conectividad del reloj.

No hay migraciones, endpoints ni cambios de editor/proveedor Garmin. El cambio
incluye versión visible de la app. La compilación iOS se acredita por separado
en CI; ni las pruebas ni un ACK sustituyen la aceptación física de esta entrega.

Validación local: análisis global sin incidencias, batería de raíz de 1.731
pruebas correctas con una omisión anterior; 43 pruebas focales de Apple tras
añadir la prueba del interruptor, y 16 del paquete de Salud. Se cubren nueva cita,
calendario local ausente, contenido/fecha modificados, cancelación con derecho
vencido, límite del catálogo, completadas, denegación, receta incompatible,
desactivación, concurrencia y cambio de cuenta. Versión `1.3.0+6`.

La [CI de `35e35533`](https://github.com/jchjdev/entrenaop/actions/runs/41602603873)
finaliza correctamente en servidor, consumidor y compilación iOS Release sin
firma. Falta instalar y comprobar en el reloj la nueva conciliación automática;
la programación manual del material inicial no acredita ese recorrido.

El envío parte del iPhone emparejado y requiere ejecutar EntrenaOP:
**no implementa sincronización automática desde la nube ni mientras la app está
cerrada**. Los recibos preparados sin ACK se conservan como pendientes, nunca como
éxito; ante una operación incierta se revisa antes de repetir. La fuerza y las
métricas avanzadas no se exportan en este bloque.

La actividad terminada conserva el recorrido manual de Salud y añade la
recogida automática de pautas propias descrita arriba. Se guardan los intervalos
medidos disponibles; la revisión y el cierre explícito incorporan sus resultados
a la ejecución semanal. Un total no completa por sí solo los pasos.

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
**Siguiente recorrido único:** el apartado de intervalos y cierre describe la
única actualización del iPhone y la comprobación física pendiente. La lectura
manual de la actividad ficticia en Fitness/Salud ya fue comunicada. Quedan la
nueva lectura automática, la ejecución real de fases/avisos, el cambio y la
retirada de la pauta. La recepción comunicada no cierra esas comprobaciones.
El bloque permanece abierto hasta esa aceptación física.

## Referencias oficiales

- [Actividades e intervalos de HealthKit](https://developer.apple.com/documentation/healthkit/dividing-a-healthkit-workout-into-activities).
- [Mediciones por actividad](https://developer.apple.com/documentation/healthkit/hkworkoutactivity/statistics(for:)).
- [Esfuerzo registrado](https://developer.apple.com/documentation/healthkit/hkquantitytypeidentifier/workouteffortscore).
- [WorkoutKit](https://developer.apple.com/documentation/workoutkit).
- [Plan asociado a una actividad de Salud](https://developer.apple.com/documentation/healthkit/hkworkout/workoutplan).
- [WorkoutScheduler](https://developer.apple.com/documentation/workoutkit/workoutscheduler).
- [Paso con nombre: iOS 18/watchOS 11](https://developer.apple.com/documentation/workoutkit/WorkoutStep/init(goal:alert:displayName:)).
- [Diseño y programación de entrenamientos, WWDC23](https://developer.apple.com/videos/play/wwdc2023/10016/).


## Recogida por avisos de Salud · 01/11/2026

Javier pide terminar el recorrido autónomo. Se añade un puerto de avisos del
sistema, separado del lector y repositorio: el observador nativo de HealthKit
solo despierta el mismo caso de uso autenticado. No crea otro almacén de tokens,
no refresca sesiones por su cuenta y no guarda mediciones en preferencias.
El AppDelegate prepara el observador al arrancar, antes de la hidratación Auth;
solo se registra si la recogida ya estaba activada. Se incorpora el entitlement
HealthKit Background Delivery, conservando el mínimo iOS general y la barrera
iOS 18 para el lector de pautas Apple.

Un aviso durante otra consulta espera y vuelve a leer para recoger datos
posteriores. Cambiar/salir de cuenta invalida la respuesta anterior. El apagado
retira el observador y sus avisos; destruir el motor conserva la preferencia para
un arranque posterior. El aviso al sistema siempre se acusa en un plazo acotado,
y un fallo conserva un marcador de relectura, nunca un resultado importado falso.
La app muestra si la instalación ha podido activar el segundo plano. Una versión
anterior conserva la recogida al abrir la app.

La entrega depende de iOS, permisos, sesión/red y disponibilidad de los datos
protegidos. No se promete inmediatez ni ejecución ilimitada con cierre forzado.
Es necesario actualizar una vez el iPhone para incorporar el código nativo y
contrastar el retorno con la app en segundo plano. La compilación sin firma y
las pruebas no sustituyen esa aceptación física. Fuerza Apple continúa fuera
del alcance implementado; las recetas de carrera incluyen sus fases y series.

Javier confirma que el RPE ausente no debe bloquear un cierre acreditado: queda
pendiente para añadirlo después. El cierre SQL automático ya está aplicado en
Dev: exige referencia WorkoutKit, pauta vigente y correspondencia completa de
fases nativas. El día local de realización debe estar entre la fecha prevista y
los siete días posteriores; la llegada tardía del aviso no cambia ese día.
El mismo margen se aplica al confirmar manualmente la asociación. Fuera de él,
la actividad se conserva sin completar esa pauta.

Una prueba, un conflicto, una pauta cancelada/archivada o intervalos insuficientes
conservan revisión. Se reutilizan los comandos de ejecución, sin distribuir el
total entre series. La operación es idempotente; un fallo no deja una ejecución
parcial ni descarta la observación. El titular puede añadir después un esfuerzo
de 1 a 10 a su resultado de dispositivo, sin volver a cerrar la sesión. Repetir
el mismo valor es seguro; otro valor no sobrescribe una valoración existente.
Un esfuerzo posterior de Salud solo rellena el campo si continúa vacío.

Las métricas opcionales que Salud entrega después (pulso, distancia total o de
recuperación) también pueden rellenar campos vacíos de una ejecución acreditada,
sin volver a cerrarla. Se conserva en el recibo privado la correspondencia de
fases confirmada; no se reconstruye para recibos antiguos. Una distancia total
nunca se distribuye entre series y una corrección manual o una medida existente
prevalece. Los conflictos permanecen en revisión. La carrera sigue necesitando
tiempo y distancia medidos antes del primer cierre; esta ampliación no relaja
ese contrato. `apple_activity_late_metrics.sql` comprueba el enriquecimiento,
el replay, el historial previo y la conservación de correcciones con ROLLBACK.

Validación del 01/11: compilación iOS Release sin firma y CI de Salud correctas
en `f7621d6e`; contratos SQL de retorno, cierre automático, permisos, replay y
RPE diferido correctos con ROLLBACK antes y después del despliegue. La raíz pasa
`flutter analyze` y 1.601 pruebas (una exclusión previa). Esto no sustituye la
aceptación física del nuevo segundo plano ni amplía Apple a fuerza.

Referencias: [observadores](https://developer.apple.com/documentation/healthkit/executing-observer-queries)
y [entitlement y entrega](https://developer.apple.com/documentation/healthkit/hkhealthstore/enablebackgrounddelivery(for:frequency:withcompletion:)).

Validación local de este tramo: análisis raíz sin incidencias y 1.565 pruebas
correctas con la omisión previa; cuatro regresiones cubren aviso en segundo
plano, aviso durante una lectura, reautorización y respuesta tras salir de cuenta.
La compilación iOS sin firma de ese punto ya ha terminado correctamente en CI.
El cierre SQL y la asociación posteriores se describen arriba; la compartición
adicional de resultados entre preparadores sigue pendiente.
