# device_activity_core

Dominio Dart de importación y asociación de carrera de EntrenaOP (INT-002).
No tiene dependencias de ejecución, Flutter, SDK de relojes, HTTP, base de datos
ni importaciones de las tres aplicaciones. `test` 1.31.1 y `lints` 6.1.0 son
herramientas de desarrollo fijadas; se conserva el lockfile propio. Compatible
con el SDK del repositorio: Dart 3.13.4 / Flutter 3.47.5.

## Qué se puede usar

| API | Responsabilidad |
| --- | --- |
| `ExternalActivity`, `ActivityMetrics`, `ActivitySegment` | Observaciones inmutables, unidades, precisión en microsegundos, tiempos separados y validación explícita. |
| `PlanActivityImport` | Calcular una transición incremental por conexión, propietario, generación, cursor y revisión, incluyendo cuarentena y recibos de órdenes. |
| `FindActivityDuplicates` | Proponer coincidencias con evidencia y política/tolerancias explícitas. No fusiona actividades. |
| `proposeRunningSessions` | Proponer citas propias de la fecha local conocida, conservando todas las alternativas. |
| `reviewRunningActivity` | Fijar primaria, alias elegidos por el titular y estado de la cita revisada. |
| `ConfirmActivityAssociation` | Confirmar la asociación uno a uno, validar la vista previa y conservar la evidencia. No registra resultados deportivos. |

La adquisición (Salud/Health Connect/fabricante) no es el origen de la pauta.
`RunningSessionTarget` es una proyección acotada de una cita existente: no copia
el planificador, recetas de entrenamiento ni reglas comerciales/profesionales.
No se ha añadido este paquete a los pubspec de las aplicaciones.

## Importación: transición y persistencia son fronteras distintas

El llamador entrega un estado y una página normalizada; el caso de uso devuelve
un plan inmutable sin modificar los argumentos. `nextState` incluye registros,
marcas de borrado, cursor, cuarentena, recibos y un checkpoint incrementado.
Un reintento de una orden ya aplicada devuelve el mismo estado; reutilizar esa
orden con otro contenido falla, incluso después de procesar otras páginas.
La fecha de recepción no cambia el significado de una observación repetida.

Los tokens de revisión se comparan por igualdad, nunca lexicográficamente.
Para sustituir una revisión distinta se requiere una fecha de modificación del
origen demostrablemente posterior; no se usa la hora de recepción. Sin orden
demostrable, o si el mismo token trae otros datos, se conserva lo anterior y se
marca recuperación pendiente. Una cuarentena igual/más reciente o de orden
desconocido impide ofrecer el dato anterior en `state.activities`.

Una actualización posterior y válida puede superar una cuarentena fechada; se
conserva su referencia histórica para recuperación/auditoría. La recuperación
de revisiones sin orden demostrable necesita un recorrido explícito posterior.
Cambiar una conexión de cuenta o reconciliar un cursor caducado requiere una
generación nueva. El adaptador debe gestionar ese reinicio y detener trabajos
anteriores; el dominio solo detecta y rechaza callbacks de la generación antigua.

**Obligación del futuro adaptador:** cargar estado autoritativo, autenticar la
cuenta y volver a comprobar permisos/generación al persistir. Debe aplicar todo
el plan con compare-and-swap de `expectedCheckpoint`, en una única transacción.
Si falla la transacción, no avanzar el cursor. Un cambio concurrente exige cargar
el estado de nuevo y recalcular. Las pruebas puras no acreditan concurrencia en
PostgreSQL, RLS ni ejecución de webhooks.

Los recibos representados aquí son el contrato de idempotencia, no una política
de retención. El almacenamiento real deberá conservarlos de forma duradera y
definir una firma canónica/versionada para solicitudes sin exponer payloads en
logs. Cuarentena conserva identidad, revisión y problemas; recuperar el contenido
requiere lectura del origen o almacenamiento privado autorizado. Su retención,
borrado y límites operativos se concretarán antes de persistir datos reales.

## Asociación y duplicados

La vista previa conserva la actividad primaria, las observaciones alternativas
seleccionadas y la revisión/receta/ejecución/resultado de la cita. Confirmar exige
que esos datos sigan iguales. Una actividad borrada, ausente o revisada invalida
la vista previa. Un resultado ya confirmado conserva su evidencia aunque lleguen
datos nuevos; reintentar su misma orden devuelve la confirmación original.

Las referencias seleccionadas como alias quedan reservadas junto a la primaria
para una única cita. No se combinan sus métricas ni se elige la mayor distancia.
Los candidatos calculados por similitud/origen son avisos: no prueban que dos
carreras sean la misma. El futuro flujo de revisión debe resolver esos avisos y
seleccionar explícitamente alias o actividades distintas antes de confirmar.
El dominio no descubre copias que el adaptador no le haya aportado.

El llamador debe usar las observaciones revisables (`state.activities`) y cargar
las asociaciones autoritativas de todas las conexiones del alumno para comprobar
la cardinalidad. El adaptador de confirmación debe comprobar en la misma
transacción actividad, cita, derecho vigente y `expectedCheckpoint`; un plan
calculado sobre un snapshot antiguo no puede guardarse a ciegas.

Asociar conserva `executionId` cuando existe. No crea ejecuciones ni confirma
series, RPE, cumplimiento, marcas oficiales o adaptaciones del motor. Tampoco
autoriza a un preparador a leer nada: MFA, vínculo y permisos de consulta serán
responsabilidad del contrato de servidor vigente. Los segmentos de vuelta
automática siguen siendo vueltas; no se asignan a series prescritas.

## Fechas, mediciones y permisos

Se exigen instantes UTC y se conservan offsets de inicio/final. Solo se propone
una fecha cuando existe el offset de inicio; no se infiere una zona a partir de
la máquina ni se implementa una base IANA. Resolver zonas y cambios de horario
es responsabilidad del adaptador. El dominio conserva las diferencias de los
instantes y los offsets aportados sin reinterpretarlas.

La base del ritmo (transcurrido/temporizador/movimiento) debe elegirse de forma
explícita y queda reflejada en el resultado. No se sustituye por otro tiempo si
falta. Los datos ausentes permanecen nulos; valores no finitos/negativos se
rechazan. No hay umbrales fisiológicos, reparto de totales entre series ni
conversión silenciosa a segundos enteros de resultados existentes.

`queryAllowed` permite ejecutar la consulta, incluida una lectura cuyo permiso
HealthKit no puede observarse completamente. Una lista vacía no lo transforma
en «denegado». Todos los estados son entradas del contrato; no suplantan una
autorización del sistema o del servidor.

## Verificación

Desde este directorio:

```sh
dart pub get --enforce-lockfile
dart format --output=none --set-exit-if-changed lib test
dart analyze --fatal-infos
dart test
bash tool/test_ci_scope.sh
```

La batería cubre 56 casos, incluidos reordenación de revisiones, reintentos
antiguos, cuarentena, borrados, aislamiento de cuentas y canales, precisión,
medianoche/offset desconocido/cambio de horario, alias, cardinalidad y vistas
previas obsoletas. No acredita conexiones a proveedores ni uso en las apps.

Ocho escenarios ejecutan el detector real de alcance del workflow con Bash y
entradas Git controladas, sin publicar nada ni alterar referencias.
El workflow de ADMIN resuelve y verifica también este paquete. Un cambio
limitado al paquete aislado, documentación y esa integración de CI no publica
ADMIN Dev; los cambios de aplicaciones conservan su publicación previa.

Contrato completo y fases: [dispositivos](../../docs/DEVICE_INTEGRATIONS.md) y
[carrera V1](../../docs/DEVICE_RUNNING_CONTRACT_V1.md).
