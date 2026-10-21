# Cartera del preparador y continuidad del alumno · TRN-015 · 21/10/2026

## Decisión confirmada

Javier acepta conservar resultados y consulta de lo realizado para el alumno,
retirar lo pendiente y no permitir repetir contenido privado cuando termina el
servicio. Corrige que el preparador pierda todo historial: el cliente debe
permanecer inactivo en su cartera y retomar su ficha si vuelve. Precios y
pasarela se posponen hasta cerrar la infraestructura general.

Se separan ficha, etapas del servicio y situación de pago. Una cuenta EntrenaOP
identifica a la persona; el pago no concede permisos administrativos ni cambia
Pro personal. La baja no borra la cuenta, no transforma el trabajo profesional
en contenido público y no concede lectura de nuevos datos personales ajenos.

## Contrato de estados

| Situación | Cartera del preparador | Servicio y cupo |
| --- | --- | --- |
| Activo | Una ficha con la etapa actual y sus etapas previas | Un vínculo aceptado activo; ocupa plaza. |
| Inactivo | La misma ficha y su historial del servicio | Sin etapa activa; no ocupa plaza ni admite nuevas pautas. |
| Archivado | Ficha fuera de las listas habituales, recuperable | Solo se puede archivar inactivos; no borra etapas ni reactiva el servicio. |
| Vuelve | Se conserva la ficha y se añade una nueva etapa | Invitación nueva, aceptación del alumno y comprobación atómica del cupo. |

El estado activo deriva de los vínculos, no de un interruptor independiente de
la ficha. Una nueva aceptación desarchiva la ficha; recuperarla manualmente la
devuelve a Inactivos y no ocupa plaza. El alumno mantiene un único preparador
activo; puede constar en carteras históricas de preparadores anteriores. Cada
uno conserva únicamente sus etapas y, cuando exista, su propio trabajo asignado.

Archivar es reversible. El borrado definitivo de la información del preparador
es otra acción pendiente de diseñar: no equivale a borrar la cuenta del alumno,
los resultados que conserva ni registros de pagos. Esta entrega no purga datos.

## Implementación comprobada en Dev

- `trainer_clients`: una ficha por preparador/alumno, sin duplicar al volver.
  Nombre de referencia actualizado solo al aceptar otra etapa; no se sigue el
  perfil actual de un cliente inactivo. Fechas, archivo y clave compuesta.
- Los vínculos existentes siguen siendo etapas inmutables al terminar. Un
  trigger conserva/actualiza la ficha al aceptar o finalizar. El backfill recoge
  vínculos previos sin habilitar ni reabrir servicios.
- Listas paginadas de activos/inactivos/archivados y consulta paginada de etapas
  por cliente. El panel permite desactivar, archivar y recuperar con confirmación.
- RLS de propietario más TOTP/AAL2. El cliente no escribe directamente fichas.
  Ni otro preparador ni ADMIN obtiene acceso por su rol administrativo.
- El archivo comparte orden de bloqueos con aceptar/finalizar: alumno → acceso
  del preparador → ficha. La última aceptación no puede dejar un activo archivado.
- Migración `20261021115014_trainer_client_portfolio.sql`, aplicada solo en Dev.

La entrega de cartera almacena **el historial de etapas del vínculo**.
TRN-016 incorpora después las pautas y la consulta de los resultados propios
del servicio. [Sesiones privadas y resultados](TRAINER_PRIVATE_WORKOUTS.md).

## Derechos tras la baja, aplicados por TRN-016

El alumno conserva los resultados y la receta/versiones de lo que realizó para
consulta. No puede iniciar nuevas repeticiones desde contenido del preparador
al terminar el servicio. Se retiran pautas pendientes; una ejecución ya iniciada
se conserva conforme al criterio previo de no interrumpirla por la baja.

El preparador conserva consulta del trabajo de sus propias etapas, incluso con
la ficha inactiva. No recibe el historial personal general, resultados de otro
preparador ni datos nuevos fuera de su servicio. TRN-016 implementa estos
derechos para sesiones privadas, asignaciones y resultados en Dev.

Cancelación/caducidad del acceso comercial del preparador, impago y reducción
de paquete conservan reglas propias pendientes. No se crean estados de pago
ficticios ni se deduce impago de que un vínculo esté inactivo.

## Verificación

Análisis limpio de raíz, ADMIN, panel y `trainer_access`. Baterías: 1144 pruebas
raíz (una omisión previa), 301 ADMIN (dos previas), nueve panel y tres contrato
compartido aprobadas. Capturas de widgets con dos alumnos ficticios en escritorio,
390 px y 320 px/texto 2×; no se modifica la maqueta de ADMIN.

Tres SQL contra Dev terminan con ROLLBACK. El contrato nuevo cubre baja, ficha
retenida, nombre de referencia, archivo, recuperación sin reactivar, vuelta con
etapa nueva y ficha única, aislamiento, MFA, cursores y escrituras directas
rechazadas. Las regresiones antiguas fijan dentro de sus transacciones el estado
del gate que prueban: ya no presuponen que el piloto real esté deshabilitado.

Veintiuna carreras con conexiones reales en PostgreSQL 17.6 local desechable:
las quince de aceptación anteriores más tres por cada orden archivo/aceptación.
Se observan los bloqueos antes de confirmar al ganador. No equivale a carreras
por HTTP/GoTrue remoto; Dev se verifica con los SQL transaccionales.

Los asesores no señalan nuevos WARN de los objetos de cartera. Conservan avisos
de objetos anteriores fuera de este alcance; la cartera solo tiene INFO de un
[índice nuevo aún sin uso](https://supabase.com/docs/guides/database/database-linter?lint=0005_unused_index).
No se elimina ese índice: cubre la clave foránea del alumno.

La ampliación está publicada en `trainer.entrenaop.es`, conectada solo a Dev:
revisión `029a46ce7a638ac5954c9e85cd4ea7034636e144`, publicación
`029a46ce7a638ac5954c9e85cd4ea7034636e144-20261021-2`. El verificador HTTPS
comprueba manifiesto, hash del JavaScript, entrada, cabeceras y MIME WebAssembly.
Chrome conserva la sesión validada, muestra 0/5 plazas y resuelve las listas de
activos, inactivos y archivados sin errores de consola. No hay alumnos reales:
las transiciones con datos se acreditan mediante SQL y pruebas de widgets,
no mediante una aceptación humana nueva.
[Captura publicada](visual-audit/trainer-portfolio-2026-10-21/published-clients.png).

TRN-016 implementa y verifica después sesión privada → asignación versionada →
ejecución existente → resultados autorizados. La purga definitiva y los cobros
siguen pendientes; la aceptación humana con dos cuentas se acredita aparte.
