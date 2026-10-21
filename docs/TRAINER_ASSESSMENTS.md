# Pruebas y simulacros privados del preparador

Contrato implementado el 21/10/2026. La migración nueva y su prueba se han
ensayado primero en EntrenaOP Dev con `ROLLBACK` y después se ha aplicado
la migración en Dev, junto al conjunto profesional de diez migraciones.
Veinticuatro contratos vuelven a pasar con ROLLBACK sobre el esquema aplicado.
No acredita publicación de la interfaz ni producción.

## Recorrido y frontera

El preparador crea una batería privada versionada, la pauta a un cliente de su
servicio y consulta sus marcas. El deportista revisa las instrucciones, confirma
el protocolo, inicia la entrega, guarda un borrador y finaliza sus intentos. El
resultado conserva la batería y los protocolos que recibió, aunque se revisen
después. El contenido privado no se publica en EntrenaOP.

Es un circuito tipado propio de evaluación. No crea ejecuciones ficticias de
sesiones ni escribe en el historial deportivo personal. Reutiliza el parser de
tiempos existente y un componente común de captura; no copia calculadores de
baremos ni el motor adaptativo. El ejecutor de sesiones actual no aplica por sí
solo las políticas oficiales de intentos, por lo que no se utiliza para fingir
esa garantía.

## Protocolos y marcas admitidos

Captura escalar de repeticiones enteras, segundos y metros, con dirección
favorable, resolución decimal, instrucciones, máximo de intentos y política de
repetición (`none`, `always`, `invalid_only`). Los segundos admiten el formato
deportivo existente, incluido `1:30,25`. No se redondean marcas para hacerlas
encajar en una resolución. Ausencia, intento nulo y marca válida cero son
estados distintos; un nulo no lleva valor numérico.

Cada protocolo privado tiene identidad estable. El servidor deriva su versión
y huella de las condiciones completas, conserva las revisiones y evita que el
cliente fabrique la huella. Cambiar condiciones impide comparar retrospectivamente
ese protocolo como si fuera el anterior.

La primera fuente oficial es `program_assessment_tests` de programas publicados
(`preparation_programs.enabled`). Solo se ofrece si puede capturarse íntegramente:
categoría universal `both`, edades 0–120, unidad/resolución compatibles y política
de intentos soportada. El servidor lee la definición y fija su instantánea,
incluidos definición, distancia, protocolo de medición, categoría, edad e intentos.
El cliente envía exclusivamente el identificador de fuente oficial y el ID local.
Una misma fuente oficial no puede añadirse varias veces bajo IDs diferentes para
ampliar artificialmente sus intentos.

No se importan todavía protocolos condicionados por contexto personal, ni los
catálogos heredados que carecen de un adaptador completo a este contrato. Las
pruebas que requieren otra captura no se degradan a texto libre. Las fuentes
excluidas pueden producir un catálogo vacío, que la interfaz explica.

**Se registran marcas, no puntos ni aptitud oficial.** El snapshot fija
`scoring_available=false`. La futura puntuación requiere cálculo autoritativo,
fuente normativa y contexto confirmado completo; el acceso profesional no permite
leer por defecto objetivos, edad o preparación personal del alumno.

## Estados, cuotas y seguridad

Entrega: `planned → in_progress → completed`; una pendiente puede pasar a
`withdrawn`. Finalizar el vínculo retira las pendientes y conserva el historial
propio. Una prueba ya iniciada puede terminarse tras la baja. Desactivar acceso o
caducar impide nuevas pautas e inicios. Las entregas cerradas son de consulta;
las correcciones posteriores al cierre requieren un contrato adicional explícito.

El servidor valida autoría con MFA y acceso profesional activo. La consulta
histórica del preparador exige propietario y MFA; el alumno solo recibe sus
entregas, sin otra compra obligatoria. ADMIN ajeno no obtiene acceso por ser
ADMIN. Las tablas viven en `trainer_private`, con RLS y sin acceso directo de
clientes. Las fachadas RPC validan participantes; los helpers de snapshot y
validación no reciben permisos de ejecución de clientes.

Las escrituras fijan operación, payload y revisión esperada. Reintentar una
operación confirmada no duplica la batería, entrega ni resultado. Los resultados
parciales y finales conservan un registro de revisiones. La UI retiene los datos
ante error, congela la operación incierta y protege los borradores al navegar.

Límites técnicos provisionales, sin decisión de precios: 100 versiones totales
de batería por preparador (configurable en servidor), 40 pruebas por batería,
10 intentos por prueba, título 120 caracteres, descripción 1.000, instrucciones
10–2.000 por protocolo, resolución entre 0,000001 y 1.000.000.000, marca entre
0 y 1.000.000.000. Payload entrante máximo 128 KiB y snapshot 192 KiB. La cuota
incluye versiones históricas para evitar crecimiento ilimitado por revisiones.

## Comparación y agenda

La comparación del portal usa solo resultados completados del mismo alumno y
preparador, con fechas de finalización estrictamente ordenadas y misma huella,
unidad, dirección y resolución. Compara la mejor marca válida en unidades
originales; todos los intentos nulos no generan un cero ni una mejora ficticia.
La interfaz identifica que la selección procede de las entregas cargadas; hay
paginación explícita para acceder al resto, sin presentar un agregado global.

La lectura de agenda devuelve eventos `kind=assessment`, separados de las
sesiones y sin notas internas. Su fecha es la fecha civil pautada. El puerto
`ProfessionalAssessmentEventRepository.listAssessmentEvents` existe en ambos
adaptadores Supabase; no altera el puerto de captura. Las páginas son de 200,
ordenadas por fecha e ID descendentes, con cursor compuesto. Un consumidor debe
seguir leyendo o señalar incompletitud cuando recibe una página completa.
El periodo máximo por consulta es de 366 días, con fin exclusivo.

## API e integración

RPC autenticadas:

- `list_trainer_assessment_catalog()`.
- `save_trainer_assessment(p_operation_id,p_payload,p_previous_id?,p_expected_revision=0)`.
- `get_trainer_assessment(p_id)` y `list_trainer_assessments()`.
- `assign_trainer_assessment(p_operation_id,p_relation_id,p_assessment_id,p_date)`.
- `write_trainer_assessment(p_operation_id,p_id,p_expected_revision,p_action,p_payload)`;
  acciones `start` (confirmación de protocolos), `save` y `finish` (respuestas).
- `get_trainer_assessment_delivery(p_id)`.
- `list_trainer_assessment_deliveries(p_client_id?,p_before_at?,p_before_id?)`,
  páginas de 50. Sin cliente solicita las entregas propias del deportista;
  con cliente solicita la cartera propia del preparador.
- `list_trainer_assessment_events(p_start,p_end_exclusive,p_as_trainer=true,p_before_date?,p_before_id?)`.

Portal: `/assessments`, `/assessments/new`, `/assessments/:id/revise`,
`/clients/:id/assessments` y `/clients/:id/assessments/:delivery`.
App: `/my-trainer/assessments` y `/my-trainer/assessments/:id`.
La entrada contextual solo se muestra cuando hay entregas reales, incluidas
históricas. Los editores y la captura registran el guard de borrador compartido.

Implementación: dominio y codec en `packages/workout_core/`, captura común en
`packages/workout_editor_ui/lib/assessment_capture_fields.dart`, repositorios y
páginas propios de cada aplicación. No dependen de `admin_app`.

## Pendiente explícito del algoritmo profesional

Los procedimientos personales de planificación dependen de `auth.uid()`,
`preparation_goals`, contexto y referencias personales. No se invocan suplantando
al alumno ni se copian al portal. La futura frontera deberá recibir contexto
autorizado y resultados del servicio, generar una propuesta determinista
versionada, permitir revisión del preparador y materializar solo su pauta.
Antes de extraer lógica se necesitan pruebas de paridad de dosis, recuperación,
explicaciones y carrera V5, además de aislamiento respecto al historial personal.
Esta entrega no implementa ni promete esa extracción.

## Validación

`supabase/tests/trainer_assessments.sql` termina con `ROLLBACK` y cubre aislamiento
de cuentas/ADMIN, MFA, versiones y huellas, fuente oficial elegible/incompatible,
snapshot, duplicado oficial, cuota, grants, operaciones estables, conflictos de
revisión, nulo frente a cero, precisión e intentos, baja durante ejecución y
ausencia de ejecuciones deportivas ficticias. Se ensaya junto a la migración de
formularios, de la que reutiliza el validador privado de textos.

Pruebas Flutter de dominio, captura común, editor profesional y captura del
alumno verifican formatos, comparación compatible, versiones, confirmación de
protocolo, reintentos estables y consulta bloqueada al finalizar. La auditoría
independiente de seguridad se coordina antes del cierre global del bloque.

`tools/test_trainer_assessment_concurrency.py --pg-bin <PostgreSQL17/bin>`
crea un clúster local efímero sin admitir DSN externos. Usa las RPC y triggers
reales, identidad de ambos participantes y tablas de catálogo mínimas. Comprueba
36 contenciones observadas entre conexiones independientes: inicio/baja y
guardado/cierre en ambos órdenes; mismo operation ID con payload idéntico o
alterado; todo ello con READ COMMITTED y REPEATABLE READ, tres repeticiones.
Los conflictos se rechazan o recuperan en una transacción nueva sin duplicar
revisiones ni perder la marca confirmada. Este ensayo complementa el test Dev
de snapshots/RLS completos; no lo sustituye y no conecta a Dev ni producción.
