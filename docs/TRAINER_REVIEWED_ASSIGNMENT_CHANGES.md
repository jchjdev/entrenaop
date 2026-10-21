# Mover y adaptar con revisión vigente · 21/10/2026

La migración `20261021162516_trainer_reviewed_assignment_changes.sql` enlaza la
revisión de una edición individual con su confirmación. `preview_trainer_schedule`
continúa siendo una consulta de presencia; por sí sola no autoriza una edición
ni garantiza que su aviso siga vigente al confirmar.

```text
preview_trainer_assignment_change(
  p_id uuid, p_expected_revision bigint, p_date date, p_note text,
  p_recipe jsonb = null
) -> {
  fingerprint, id, client_id, relation_id, date,
  planning_revision, has_date_coincidence
}

change_trainer_assignment_reviewed(
  p_operation_id uuid, p_id uuid, p_expected_revision bigint,
  p_date date, p_note text, p_fingerprint text, p_recipe jsonb = null
) -> {id, planning_revision, template_id}
```

El preview exige acceso profesional vigente, MFA, pauta propia pendiente sin
ejecución y vínculo activo. La coincidencia es un booleano por fecha que excluye
solo la cita editada: incluye otras pautas del mismo preparador y planes
personales, sin revelar nombres, recetas o resultados ajenos. La huella liga
fecha, revisión, nota y receta propuestas con esa señal y la versión de origen.
Una revisión propia obsoleta causa 40001; una pauta ya iniciada no se edita.

El endpoint antiguo y su función interna quedan revocados a authenticated.
La mutación nueva conserva el controlador y los motores existentes de autoría,
validación y adaptación privada. El ledger incluye la huella y devuelve el
recibo original antes de exigir una nueva revisión, incluso tras un inicio.
Ante respuesta incierta se conserva el mismo UUID, payload y huella; un 40001
definitivo exige revisar de nuevo y utilizar otro UUID al volver a confirmar.

## Orden de bloqueo comprobado

La edición valida primero autoría y MFA, toma el advisory del alumno y fija el
perfil del preparador con KEY SHARE antes del acceso profesional. Esto evita
que el FK del nuevo template de una adaptación pida después el perfil de su
propietario frente a un borrado concurrente. Después se reutiliza
`lock_assignment`: acceso → cita antigua → asignación. Solo entonces se toma
la revisión privada de agenda, **sin bloquear el perfil del alumno**.

La cita antigua ya está bloqueada antes del contador y la mutación no pide
otra cita después. Un escritor personal de otra cita puede bloquear esa otra
fila y su contador; reviewed no intenta bloquear esa fila. Descartar conserva
su orden real de perfil del alumno → cita → ejecución → series; reviewed no
pide ese perfil después de la cita, evitando un ciclo nuevo.

La adaptación escribe receta y fecha en **un único UPDATE** de la cita. El
runner detectó que los dos UPDATE anteriores provocaban una comprobación FK
implícita del perfil del alumno en el segundo, aunque no cambiase `user_id`.
La carrera de perfil bloqueado se conserva como regresión y pasa tras fusionar
las escrituras. Los triggers conservan revisión de resultados y el historial.

## Evidencia y límites

`supabase/tests/trainer_reviewed_assignment_changes.sql` termina con ROLLBACK y
comprueba payload/huella, coincidencia nueva, receta privada, recibo tras inicio,
revisionado propio y aislamiento de alumno, ADMIN ajeno, MFA y helpers privados.
La prueba operacional existente migra al endpoint nuevo conservando sus
invariantes de movimiento, adaptación, biblioteca, ledger y revisión.

El runner local instala los RPC de edición, inicio, descarte y publicación y
los triggers reales; solo la construcción deportiva de recetas/ejecuciones es
mínima. Contrasta READ COMMITTED y REPEATABLE READ con ambos órdenes: el runner
completo termina con 276 contenciones y 30 solapes independientes correctos,
tres repeticiones por caso, sin deadlocks ni duplicados. Incluye publicación
de biblioteca y descarte mediante sus RPC reales. El borrado
de perfiles con historial continúa protegido por sus FK existentes; las
carreras no implementan ni acreditan un flujo general de eliminación de cuentas
o anonimización. La migración sí se ha aplicado en Dev dentro del conjunto
profesional de diez, con 24 contratos revalidados mediante ROLLBACK;
no se ha aplicado en producción.
