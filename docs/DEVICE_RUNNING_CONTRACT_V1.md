# Contrato de dispositivos para carrera · V1 · INT-001

**21/10/2026 · especificación V1; dominio parcial implementado por INT-002.**
Desarrolla el [bloque común](DEVICE_INTEGRATIONS.md). Los nombres de entidades y
operaciones son vocabulario de diseño, no API publicada, tablas existentes ni
un compromiso de sus firmas definitivas. La versión del contrato debe quedar
separada de la versión de receta, del motor y de cada adaptador.

## 1. Fronteras existentes y cuatro conceptos distintos

| Concepto | Fuente y regla |
| --- | --- |
| Prescripción | Receta/versiones de `packages/workout_core/lib/workout_template.dart`: bloques de carrera, duración/distancia, ritmos y recuperación. Se reutiliza. |
| Cita prevista | `ScheduledWorkout`: fecha, origen, versión y ejecución. El origen sigue siendo biblioteca, usuario, preparación, algoritmo o entrenador; Garmin no es un origen de prescripción. |
| Actividad externa | Nueva observación recibida por un conector, con identidad y procedencia propias. No es por sí misma una ejecución completada ni una marca de evaluación oficial. |
| Resultado confirmado | Registro aceptado por el alumno mediante el contrato vigente de ejecución/corrección. Conserva vínculo a las observaciones utilizadas y sus revisiones. |

`WorkoutExecution` ya contiene métricas y fuente manual/dispositivo por sesión
y serie. Esa enumeración no representa proveedor, identidad externa, permiso,
fiabilidad ni deduplicación. No se ampliará para sustituir todos esos conceptos.
El flujo real de confirmación externa se diseñará antes de conectar escrituras:
no se iniciará/finalizará artificialmente una ejecución con RPC actuales solo
para simular que el reloj pasó por el ejecutor móvil.

## 2. Entidades del contrato

| Entidad | Datos mínimos y restricciones |
| --- | --- |
| `Connection` | ID interno, propietario, canal de adquisición, ámbito externo opaco, estado, capacidades y permisos por operación, fechas de autorización/última sincronización. Sin secretos en el dominio ni en vistas cliente. |
| `Capability` | Operación, plataforma, datos/pasos soportados, versión del adaptador, disponibilidad y razón. El soporte técnico se distingue del permiso del usuario y del derecho comercial. |
| `ExternalActivity` | ID interno, propietario, referencias externas, revisión, deporte, inicio/fin, tiempos diferenciados, distancia y métricas opcionales, procedencia, calidad/completitud y fecha de recepción. |
| `ActivitySegment` | Referencia de actividad/revisión, índice, intervalo temporal, tipo de segmento informado y métricas presentes. Una vuelta automática de 1 km no se etiqueta como repetición prescrita. |
| `ActivityAssociation` | Actividad/revisión y cita del mismo alumno, propuesta/confirmación, evidencia y resolución del titular. Asociación no equivale a completar la ejecución. |
| `ExportRequest` | Orden idempotente, propietario, cita y receta/versiones, destino autorizado, resultado de compatibilidad, estado de entrega y referencia externa cuando exista. |
| `ConfirmedResultEvidence` | Vínculo de resultado existente con actividad/revisión, campos aceptados y conversiones aplicadas. La importación posterior no modifica esa evidencia. |

El canal de adquisición admite Salud de Apple, Health Connect y adaptadores de
Garmin, COROS, Suunto y Huawei. La marca del reloj y la aplicación que escribió
el registro son datos de procedencia independientes y opcionales. Una carrera
Garmin llegada por Salud conserva ambos niveles; no se presenta como conexión
directa a Garmin. La procedencia no acredita la exactitud de la medición.

La identidad externa se acota por propietario, canal, ámbito externo y ID del
registro. Para salud local el ámbito será el que el adaptador pueda identificar
de forma estable, sin usar nombre/email ni suponer un ID común entre iPhones.
Un cambio de cuenta EntrenaOP en el mismo móvil obliga a una nueva elección
explícita de importación; los permisos del sistema no identifican al propietario
EntrenaOP. Cursores, colas y selección de importación se aíslan por cuenta.

## 3. Unidades, fechas y datos incompletos

- Instantes con UTC y precisión de origen; conservar offset informado y zona
  cuando exista. La fecha de una cita es una fecha local de planificación y no
  se obtiene truncando UTC. Cambio de zona y horario de verano requieren casos
  de prueba. Una zona desconocida no se inventa usando la del servidor.
- Duraciones normalizadas en segundos con precisión suficiente para conservar
  fracciones; distancia en metros; pulso en latidos/minuto; ritmo en segundos/km.
  La conversión a los segundos enteros de resultados actuales necesitará una
  política explícita, versionada y visible antes de confirmar; no se introduce
  redondeo silencioso en esta especificación.
- Separar tiempo transcurrido, tiempo de temporizador y tiempo en movimiento.
  Si el proveedor ofrece solo uno, se conserva su significado. No se restaura
  una recuperación o tiempo de trabajo a partir de un total indiferenciado.
- Solo calcular ritmo con distancia positiva y tiempo compatible conocido;
  registrar qué tiempo se usó. No convertir un ritmo en FC ni FC en esfuerzo
  percibido; RPE/RIR y molestias siguen siendo declaración del usuario.
- Rechazar valores no finitos, distancias/duraciones negativas e intervalos
  invertidos. Ceros válidos no son nulos. Datos sospechosos se señalan para
  revisión con una regla versionada; no se filtran con umbrales inventados.
- Inicio, deporte o final no identificables impiden proponer un resultado de
  carrera completo. Se puede conservar un registro incompleto en cuarentena,
  sin llenar métricas ausentes ni enviarlo al motor.
- V1 admite resumen y segmentos disponibles. Series completas de sensores,
  trazas GPS y datos de salud diarios requieren otro alcance de datos/permisos.

## 4. Capacidades y permisos

**INT-006 · 22/10/2026 · regla comercial acordada; control de conexión aplicado en Dev:**
Salud y Health Connect permiten lectura/importación a todos, incluido Free.
La conexión directa a fabricantes y sus nuevas lecturas/importaciones exigen
Pro vigente o servicio profesional vigente del alumno. Esta aclaración de
Javier corrige la interpretación anterior que también restringía Salud.
El historial conservado sigue siendo consultable tras perder ese acceso.
Capacidad técnica, permiso del proveedor y derecho comercial son comprobaciones
independientes. La exportación añade las restricciones de origen de la sección 8.

Las capacidades se consultan por operación, no con un booleano «marca compatible»:

| Operación | Qué debe acreditar |
| --- | --- |
| Leer carrera | Actividades terminadas, campos disponibles y ventana temporal. |
| Leer segmentos/pulso | Si existen, alcance de permisos y fidelidad de cada canal. |
| Leer cambios | Cursor o estrategia de reconciliación, cambios y borrados. |
| Exportar carrera | Tipos de objetivo, bloques, repeticiones, recuperación, alertas y límites del destino. |
| Programar/revisar/retirar envío | Operaciones realmente admitidas, identidad externa y posible restricción de dispositivo. |
| Sincronizar en segundo plano | Soporte y autorización de la plataforma; no se deduce de leer en primer plano. |

El adaptador devuelve soportado, parcial, no soportado o aún no verificado con
razón. La autorización distingue no solicitada, concedida según lo observable,
parcial, revocada/denegada cuando sea detectable y desconocida. HealthKit puede
no permitir distinguir denegación de ausencia de datos de lectura: una lista
vacía nunca se comunica por sí sola como «permiso denegado».

Estados de conexión: sin configurar, autorización requerida, operativa para las
capacidades conocidas, requiere reautorización, desconectada o no disponible.
Una conexión operativa puede devolver cero actividades; no acredita cobertura
de todos los relojes de una marca. El estado del último trabajo de sincronización
se modela aparte para no confundir un fallo de red con pérdida de autorización.

## 5. Importación e idempotencia

1. Resolver propietario actual y permiso antes de leer o enviar una página.
2. Leer ventana/página incremental con cursor por cuenta/conexión y ámbito.
3. Normalizar y validar en el adaptador y volver a validar al persistir en
   servidor. Un payload procedente del móvil es entrada no confiable.
4. Aplicar una transacción idempotente por identidad externa y revisión.
   Mismo registro/revisión no duplica; una revisión nueva conserva procedencia
   y hace obsoletas las propuestas basadas en la anterior.
5. Confirmar cursor solo cuando toda la página haya quedado guardada o sus
   registros rechazados hayan quedado identificados para recuperación explícita.
   Si el cursor caduca, reconciliar con solapamiento sin duplicar.
6. Ofrecer actividades nuevas/actualizadas para revisión; no confirmar resultados
   ni cambiar automáticamente una cita o el plan.

Los adaptadores distinguen lectura periódica/local y notificación de servidor.
Un webhook se autentica según el proveedor y sus datos se verifican antes de
escribir. Se deduplican eventos; no se confía en IDs de alumno recibidos del
fabricante. Límites de peticiones usan reintento con espera progresiva; errores
de permiso requieren intervención y no un bucle de reintentos.

Una respuesta incierta al persistir conserva ID de orden y contenido. Reintentar
no crea otra actividad. Al desconectar/cambiar cuenta se detienen trabajos y se
invalida su generación; una respuesta tardía no se aplica a otra identidad.

Los borrados externos retiran la observación de propuestas nuevas y conservan
una marca mínima según el contrato de retención, sin borrar automáticamente
resultados confirmados. La eliminación a petición del titular será un recorrido
propio. Antes de persistir datos reales se fijará qué evidencia puede conservarse
y durante cuánto tiempo; esta especificación no concede retención indefinida.

## 6. Duplicados entre canales

Identidad externa exacta permite idempotencia dentro de un canal. Entre canales
pueden existir IDs distintos para la misma carrera. Fecha, duración, distancia,
origen conocido e identificadores compartidos sirven para proponer coincidencias,
sin asumir que sean prueba suficiente para fusionar dos actividades.

Cuando la identidad común sea comprobable se conservan referencias alternativas
de una actividad canónica. Cuando haya duda se muestra coincidencia pendiente y
el titular resuelve. No se suman las dos versiones en el progreso confirmado ni
se importan de nuevo registros que EntrenaOP hubiera exportado al almacén de
salud, si más adelante se implementa esa escritura. No se elige «el dato mayor»
ni una prioridad fija de marcas para sobreescribir mediciones.

## 7. Asociación y confirmación

V1 admite una actividad canónica por cita y una cita por actividad confirmada.
Recortar actividades, repartir una carrera entre varias sesiones o agrupar
varios archivos será un alcance posterior explícito. Dos confirmaciones
simultáneas deben resolverse atómicamente en servidor.

Una referencia de exportación devuelta por el proveedor es una evidencia fuerte
si se comprueba propietario y cita. Fecha/deporte/métricas pueden proponer una
candidata, sin asociación automática. Si coinciden plan automático y entrenador,
el alumno elige conforme a TRN-014; no se sustituye una pauta por la otra.

Confirmar exige la revisión mostrada, cita/versiones todavía válidas y propietario
autorizado. Si cambió la actividad o el resultado desde la vista previa, se pide
revisar otra vez. El servidor conserva campos confirmados, fuente y evidencia.
Una actualización posterior queda pendiente y no reescribe el historial.

Para registrar cumplimiento por repeticiones debe existir correspondencia
explícita entre pasos prescritos y segmentos observados, revisable por el alumno.
Si solo hay un resumen, se ofrece ese resumen y se mantienen pendientes los
parciales que exige el contrato vigente. No se reparte el total entre seis series
ni se da por correcta una recuperación que el reloj no identifica.

El resultado confirmado podrá entrar en los recorridos de evaluación/adaptación
que ya lo admitan. Importar no modifica baremos, no acredita un test oficial y
no activa automáticamente una nueva política del algoritmo.

## 8. Exportación de carrera

INT-007 implementa la primera vertical de envío con servicio común de servidor,
receta/cita verificadas y cliente del deportista. La aceptación de calendario y
reloj se acredita aparte. [Contrato implementado](DEVICE_GARMIN_TRAINING.md).

**INT-006:** la primera fase envía únicamente prescripciones del algoritmo o
asignaciones del preparador que el titular pueda consumir con sus derechos
vigentes. Tener Pro no basta para exportar cualquier programa guiado o sesión
personal. Otras sesiones compatibles podrán habilitarse después para usuarios
con acceso Pro/profesional; es una ampliación posible, no implementada ahora.
El origen se verifica en servidor sobre la prescripción/asignación concreta:
no se confía en una etiqueta del móvil ni se confunde autor de la plantilla con
prescriptor. Consentimiento del alumno, versiones y compatibilidad siguen siendo
necesarios; no se añade una suscripción Pro al alumno profesional para su pauta.

El adaptador parte de la receta existente: bloque/serie, objetivo por distancia
o duración, intervalo de ritmo opcional, recuperación pasiva/andando/trotando,
duración/distancia de recuperación y orden. La vista de compatibilidad declara
representación exacta, limitación informativa o incompatibilidad que bloquea.

No se omiten pasos o recuperación, no se convierte distancia en tiempo estimado
y no se sustituyen ritmos por zonas para encajar un proveedor. La compatibilidad
incluye pausas abiertas, repeticiones/límites y el tratamiento de la recuperación
final. Una adaptación material requiere una receta/versionada propia antes de
enviar, conservando la original.

La orden fija propietario, cita, versión de receta y destino consentido. Enviar
requiere derecho actual para consumir esa pauta; el preparador no autoriza por
el alumno el acceso a su reloj. La edición de biblioteca no actualiza envíos
anteriores. Cambiar la cita o retirar una pauta genera una revisión/retirada
explícita cuando el proveedor lo soporte, nunca una eliminación fingida.

Estados: pendiente, enviando, aceptada por proveedor, fallo recuperable,
requiere intervención, resultado incierto o retirada confirmada. «Aceptada por
proveedor» no significa «disponible en reloj» ni «realizada». Una respuesta
incierta obliga a reconciliar por identidad externa antes de reenviar. Sin
idempotencia o consulta suficientes del proveedor no se promete envío único.

## 9. Puertos y errores

Puertos conceptuales: catálogo de capacidades, lectura de cambios de actividad,
repositorio de observaciones, servicio de asociación/confirmación y exportador
de prescripción. OAuth, cursor nativo, FIT/JSON y códigos HTTP se traducen en
datos y errores de frontera; no entran en las entidades ni en el motor.

Los errores de dominio distinguen no soportado, requiere autorización,
datos incompletos/inválidos, coincidencia ambigua, versión obsoleta y conflicto.
La infraestructura añade indisponibilidad temporal, límite de peticiones y
resultado remoto incierto. La presentación ofrece acción concreta según el
error; los registros operativos guardan códigos e IDs técnicos acotados, sin
tokens, salud, coordenadas, formularios ni payloads completos.

## 10. Permisos y continuidad profesional

El titular ve sus actividades y controla su conexión. Los secretos OAuth de
fabricantes se almacenarán únicamente en servidor, cifrados y fuera de lecturas
cliente; permisos de HealthKit/Health Connect son autorizaciones del sistema
local, no tokens que se entregan al preparador.

Trainer recibe solo los campos confirmados asociados a sus propias pautas,
mediante el contrato profesional vigente y con MFA. No recibe actividades sin
asociar, datos de otros preparadores, identificadores externos de cuenta o salud
diaria. ADMIN recibe disponibilidad/errores agregados o reducidos, sin lectura
personal por el mero rol administrativo. Se verificará en servidor/RLS, no solo
ocultando botones.

La baja profesional no se evade importando una carrera para una pauta retirada.
No se crean ejecuciones nuevas sin autorización vigente. Las ejecuciones ya
iniciadas y resultados históricos conservan TRN-015/016. Una llegada tardía queda
para revisión del alumno y no amplía el historial que puede consultar el antiguo
preparador. El alcance de una corrección tardía se contrastará con el contrato
profesional vigente antes de implementar su comunicación.

## 11. Casos de aceptación exigidos a la implementación

1. Una carrera continua con datos completos y otra sin pulso se importan con
   unidades correctas; no se rellena la ausencia con cero.
2. Repetir página/evento, caducar cursor o reintentar una respuesta incierta no
   duplica actividades ni confirmaciones; una revisión exige nueva revisión.
3. Garmin directo y Garmin vía Salud generan coincidencia resoluble sin doble
   contabilización; dos carreras cercanas no se fusionan por una heurística.
4. Seis series con segmentos compatibles se pueden revisar; con solo total no
   se inventan parciales ni recuperación. Vueltas automáticas no son series.
5. Medianoche, cambio de zona, horario de verano, tiempos en movimiento y
   precisión fraccionaria mantienen su significado.
6. Permisos parciales, lectura vacía HealthKit, desconexión, cuenta distinta y
   callbacks tardíos no filtran datos ni atribuyen permiso inexistente.
7. Alumno y cita de distintas cuentas, otro preparador y ADMIN sin autorización
   son rechazados; MFA y continuidad tras baja conservan el contrato existente.
8. Una cita con ejecución existente no crea otra; confirmar dos veces o contra
   revisión obsoleta se resuelve sin sobreescribir resultados.
9. Un envío incompatible explica el bloqueo; un envío aceptado y otro incierto
   no se muestran como disponibles en reloj sin evidencia.
10. Sin proveedor, sin red o en web no compatible siguen disponibles el registro
    manual y los recorridos actuales de las tres aplicaciones.

INT-002 implementa y prueba los casos puros de importación y asociación, sin
conectarlos a las aplicaciones. Móvil, servidor, permisos y exportación siguen
necesitando sus pruebas de integración antes de habilitar cada capacidad.

## 12. Correspondencia implementada · INT-002

El paquete [device_activity_core](../packages/device_activity_core/README.md)
implementa `ExternalActivity`/segmentos/métricas, identidad y revisiones,
`ActivityImportState`/páginas/planes y `ActivityAssociationReview`/estado/planes.
`RunningSessionTarget` proyecta una cita sin copiar su agenda ni recetas.
`FindActivityDuplicates` recibe tolerancias y versión y solo devuelve candidatos;
primaria y alias se eligen explícitamente en la revisión. El dominio no modifica
derechos, resultados confirmados o ejecución por asociar una observación.

Las transiciones incluyen un checkpoint que debe comprobar el adaptador de
persistencia en una transacción. No se entrega un repositorio en memoria como
si fuera persistencia real ni se crean interfaces vacías para futuros SDK.
La cuarentena identifica registros recuperables y bloquea propuestas cuando
cuestiona la revisión actual. Diferentes tokens sin fecha de modificación
ordenable requieren recuperación, no una prioridad arbitraria entre canales.

La versión de políticas puras de importación/asociación es 1. Los tiempos usan
`Duration` con precisión de microsegundos, sin conversión al entero del resultado
deportivo actual. Las observaciones ya elegidas se conservan como evidencia de
asociación; no se implementa todavía `ConfirmedResultEvidence`, escritura de
resultados, SDK, conexiones, OAuth, exportación, SQL ni comunicación con Trainer.
