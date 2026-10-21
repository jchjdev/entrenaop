# Dispositivos y actividades · bloque común · INT-001

## Decisión y estado · 21/10/2026

Javier aprueba trabajar las integraciones como un bloque común de la app del
deportista, ADMIN y el portal de entrenadores, empezando por carrera. Pide
conservar Clean Architecture, no entorpecer la arquitectura profesional en curso
y perseguir cobertura de Salud de Apple, Garmin, COROS, Suunto y Huawei.
Health Connect es la entrada de salud del ecosistema Android.

**Acordado:** alcance común, separación de responsabilidades, comienzo por
contrato y acceso a proveedores, y aislamiento del trabajo profesional activo.
**Definido en esta entrega:** contrato documental V1 y comprobación de las vías
públicas de acceso. **No implementado:** conectores, importación, exportación,
pantallas, nuevas tablas o permisos. No hay reloj ni cuenta externa conectados
por esta entrega y no se declara cerrado el bloque funcional.

La cobertura de todas las marcas es un objetivo del producto. Cada combinación
de reloj, firmware, teléfono, sistema y proveedor necesitará evidencia propia.
No se promete compatibilidad universal ni igualdad de funciones. Una conexión
que permite leer actividades no acredita envío de sesiones ni datos en directo.

- [Contrato de carrera V1](DEVICE_RUNNING_CONTRACT_V1.md).
- [Acceso a proveedores y expediente de alta](DEVICE_PROVIDER_ACCESS_2026_10_21.md).
- Fronteras actuales: [arquitectura](ARCHITECTURE.md),
  [sesiones profesionales](TRAINER_PRIVATE_WORKOUTS.md) y
  [continuidad de la cartera](TRAINER_CLIENT_LIFECYCLE.md).

## Recorrido objetivo

Sesión prevista y versionada → comprobación de compatibilidad → envío consentido
al proveedor → realización en el reloj → importación de la actividad → propuesta
de asociación → revisión y confirmación en EntrenaOP → consulta autorizada del
preparador cuando corresponda.

La primera vertical operativa será más pequeña: importar una carrera real desde
Salud de Apple o Health Connect, revisar sus datos y vincularla sin duplicados a
una sesión prevista. No requiere disponer previamente de una API Garmin ni de
envío al reloj. El registro manual existente sigue siendo utilizable.

## Responsabilidad de las tres aplicaciones

| Espacio | Responsabilidad objetivo | Frontera |
| --- | --- | --- |
| Deportista | Autorizar conexión/lectura, conocer datos y destino, sincronizar, revisar actividades, asociar y confirmar resultados; envío cuando exista soporte. | El titular controla sus conexiones. Los permisos de salud se solicitan en el dispositivo compatible. |
| Entrenadores | Prescribir con el creador actual y comparar pauta con resultado confirmado de su servicio, mostrando procedencia, datos ausentes y estado de sincronización. | No conecta cuentas ajenas ni recibe acceso al historial general, tokens, datos diarios de salud o rutas del alumno. |
| ADMIN | Estado operativo de proveedores, disponibilidad y errores reducidos; comprobación de compatibilidad editorial de recetas oficiales. | Administrar el sistema no concede lectura general de actividades personales ni potestad para aceptar permisos por el alumno. |
| Servicios comunes | Normalización, compatibilidad, idempotencia, procedencia, propuestas de asociación y control de acceso. | Los detalles de un fabricante no se propagan al dominio deportivo ni a las pantallas profesionales. |

La conexión local de salud se hace desde iPhone/Android. ADMIN y Trainer web
consumirán únicamente datos ya sincronizados y autorizados; no intentarán leer
HealthKit o Health Connect desde el navegador. La app web del deportista tampoco
heredará esas capacidades nativas por compartir código Flutter.

## Arquitectura y aislamiento

El dominio de integraciones tendrá entidades, validación y políticas puras Dart,
sin Flutter, Supabase, HTTP, SDK de salud ni dependencias de `trainer_app/`.
Los puertos representan fronteras reales: lectura incremental de actividades,
almacenamiento, comprobación de capacidades y envío de una receta compatible.
Los casos de uso solo se introducirán donde haya orquestación o reglas propias.

Los adaptadores de HealthKit/Health Connect vivirán en la integración móvil;
OAuth y callbacks de fabricantes, renovación de credenciales y trabajos
asíncronos vivirán en servidor. El servidor volverá a validar identidad,
permisos, asociación y datos recibidos, también si proceden del teléfono.
Los modelos JSON, el transporte y los SDK pertenecen a datos/infraestructura.

La orquestación depende de los puertos; sus implementaciones se inyectan desde
la composición de cada aplicación/servicio. La presentación usa Bloc/Cubit para
estados de producto. El motor de carrera no importará SDK ni conocerá marcas.

Se propone materializar el dominio en un paquete específico cuando empiece su
implementación, con el nombre y las dependencias comprobados entonces. Esta
entrega no crea paquetes vacíos ni mueve entidades de los módulos existentes.
Se reutilizará la receta de `workout_core`; no habrá otro editor o planificador.

### Regla de convivencia con el trabajo profesional activo

- Este tramo solo modifica documentación propia y referencias acotadas en los
  índices comunes. No modifica `trainer_app/`, `trainer_access`, creadores,
  asignaciones, migraciones, agenda, resultados o inyección de dependencias.
- No exige al bloque profesional añadir campos de dispositivo ni esperar a
  disponer de accesos externos. Sus pruebas y entregas conservan su alcance.
- La futura integración entrará desde el identificador de cita y la ejecución
  existentes, mediante un adaptador. No creará otra relación entrenador-alumno,
  otra agenda ni otro historial deportivo.
- Antes de conectar el resultado externo con la escritura real se contrastarán
  los contratos profesionales que estén vigentes entonces. No se fijan ahora
  cambios sobre archivos o RPC que otro trabajo está desarrollando.
- Los puntos de guardado de este tramo incluyen solo sus archivos revisados.
  La presencia de cambios simultáneos no autoriza incorporarlos al commit.

## Fases y condiciones de avance

| Fase | Entrega | Condición para darla por comprobada |
| --- | --- | --- |
| 0 · actual | Contrato, capacidades, acceso público y expediente de alta. | Documentos coherentes con el código y fuentes oficiales; distinguir acceso documental de credenciales operativas. |
| 1 | Dominio puro y políticas de importación/asociación. | Pruebas de duplicados, datos incompletos, versiones, tiempos y reintentos; sin dependencia de Trainer. |
| 2 | Lectura de carrera desde Salud de Apple y Health Connect. | Prueba real por plataforma, permisos parciales/revocados, cierre de sesión y lectura incremental; sin perder registro manual. |
| 3 | Resultado confirmado e integración autorizada en las tres apps. | Una actividad real queda vinculada una sola vez; alumno y preparador ven solo lo que permite su contrato; ADMIN solo diagnóstico. |
| 4 | Envío de sesiones y conectores directos de fabricantes. | Credenciales aprobadas, receta compatible y envío/recepción reales; pruebas por combinación de dispositivo y proveedor. |

La comprobación documental de altas se puede completar mientras avanza Trainer.
La implementación transversal de las fases siguientes se incorporará en un
orden acordado con los bloques abiertos, sin convertir integraciones en un
segundo desarrollo transversal simultáneo. El orden recomendado sigue siendo
contrato → dominio → lectura móvil → confirmación autorizada → envío. Las altas
externas pueden tramitarse aparte sin bloquear la lectura local de salud.

## Límites y decisiones que siguen pendientes

El objetivo V1 son actividades de carrera y resultados útiles para sesiones ya
previstas. GPS/mapas en directo, app propia para cada reloj, sensores Bluetooth,
lectura de sueño o salud diaria, diagnóstico y modificación del algoritmo no
se incluyen en la primera vertical. La ausencia de un dato se conserva como
ausencia, nunca como cero, incumplimiento o dato inventado.

Free, Pro y acceso profesional mantienen sus derechos actuales. No se acuerda
todavía qué conexiones o capacidades serán comerciales, ni se exige una compra
adicional para consumir una pauta profesional ya autorizada.

Antes de almacenar datos reales quedarán concretados el inventario mínimo de
datos, información/consentimiento de subida y comunicación al preparador,
retención y borrado, condiciones de los proveedores y permisos de servidor.
Revocar conexión detiene importaciones nuevas; desconexión y eliminación de
datos ya guardados son acciones distintas que deben explicarse al titular.
La baja profesional conserva el contrato de TRN-015/016 y no abre datos nuevos.

## Evidencia de esta entrega

Inspección localizada de `workout_core`, `WorkoutExecution`, `ScheduledWorkout`,
contratos profesionales y configuración nativa. El código distingue
`WorkoutResultSource.manual/device`, sin conector ni identidad externa. La cita
ya conserva origen, versión y ejecución. No se han ejecutado Flutter ni SQL al
tratarse de una entrega exclusivamente documental. Se revisan diff, enlaces
locales y estado de Git; no se actualizan instantáneas generales ni se atribuyen
pruebas de otros bloques a esta entrega.

**Único siguiente tramo técnico recomendado:** dominio puro de importación y
asociación de carrera con pruebas del contrato V1, en archivos propios. No exige
modificar la arquitectura profesional ni tener aprobadas las APIs de marcas.
