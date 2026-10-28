# Apple Watch · WorkoutKit · INT-023

Javier autoriza el 28/10/2026 comenzar Apple Watch después de acreditar el
recorrido Garmin. Garmin conserva sus funciones, evidencias y límites. No se
reabre el editor ni se convierte la receta común en un contrato de fabricante.

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

El transporte parte del iPhone emparejado. Esta entrega requiere abrir y revisar:
**no implementa sincronización automática desde la nube ni mientras la app está
cerrada**. Los recibos preparados sin ACK se conservan como pendientes, nunca como
éxito; ante una operación incierta se revisa antes de repetir. La fuerza y las
métricas avanzadas no se exportan en este bloque.

La actividad terminada se puede leer mediante el recorrido existente de Salud,
con autorización, revisión y guardado de observaciones por cuenta. Esto no añade
importación de intervalos de Apple, asociación automática por identidad de plan,
ni cierre automático de la cita semanal. No se empareja por nombre/fecha a ciegas
ni se inventan RPE o resultados.

Para la futura asociación exacta existe la propiedad pública asíncrona
`HKWorkout.workoutPlan`, disponible desde iOS 17/watchOS 10 al importar WorkoutKit.
Se investigará como enriquecimiento opcional, con ausencia/error/límite de espera
separados de la lectura de métricas; no se usará metadata privada ni se bloqueará
el historial para obtener el plan. Esta primera entrega todavía no la consulta.

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
**Siguiente recorrido único:** en el Ultra y su iPhone emparejado, autorizar,
programar una carrera con fases/series/recuperaciones, comprobarla en Entreno,
modificarla y retirarla; después ejecutar y contrastar lo que devuelve Salud.
El bloque permanece abierto hasta esa aceptación física.

## Referencias oficiales

- [WorkoutKit](https://developer.apple.com/documentation/workoutkit).
- [Plan asociado a una actividad de Salud](https://developer.apple.com/documentation/healthkit/hkworkout/workoutplan).
- [WorkoutScheduler](https://developer.apple.com/documentation/workoutkit/workoutscheduler).
- [Paso con nombre: iOS 18/watchOS 11](https://developer.apple.com/documentation/workoutkit/WorkoutStep/init(goal:alert:displayName:)).
- [Diseño y programación de entrenamientos, WWDC23](https://developer.apple.com/videos/play/wwdc2023/10016/).
