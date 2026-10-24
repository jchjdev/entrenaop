# Recuperación privada de sesiones profesionales

## Continuidad contextual · TRN-029 · 24/10/2026

La migración `20261024192459_trainer_contextual_session_recovery.sql` está
aplicada exclusivamente en Dev (`sxbxfjqgoddzhtcyhalw`). Amplía el contrato
anterior, ya aplicado, sin nuevas tablas ni permisos de catálogo. Las secciones
del 21/10 siguientes documentan la instantánea inicial, no el alcance vigente.

Trainer reutiliza el editor y checkpoints comunes para sesiones dentro de un
programa y adaptaciones individuales. El programa guarda primero el UUID del
trabajo hijo, fase y posición. Una sesión abierta no puede desaparecer del
programa; una sesión finalizada conserva su recibo hasta confirmar el enlace.
Si falla incorporar el resultado, «Retomar sesión» reintenta ese enlace sin
crear otra receta. Una vez enlazada, la composición permite quitarla o moverla.
Se impide retirar de biblioteca una versión todavía pendiente de enlace.

El origen de una adaptación añade `assignmentId` y `planningRevision`; es
inmutable y excluyente con el contexto de programa. Guardar campos no modifica
la pauta. Confirmar usa `preview_trainer_assignment_session_work` y
`finalize_trainer_assignment_session_work`, con propietario esperado, MFA,
revisión y huella del calendario/intención. Reutiliza el motor existente de
adaptación y conserva biblioteca, otras entregas e historial. Una cita iniciada,
una revisión posterior o un servicio finalizado bloquean la aplicación y
conservan el borrador. Una respuesta perdida se recupera por el recibo propio.
La finalización genérica de biblioteca rechaza adaptaciones.

La URL reserva el UUID de adaptación antes del primer autosave para conservarlo
al recargar. Los trabajos aparecen en Sesiones → Trabajos incompletos. Las sesiones hijas
abren su programa; las adaptaciones abren la pauta y el UUID guardado. No se
copia el editor ni se modifica código de ADMIN o del deportista.

Validación del 24/10: análisis Trainer limpio, compilación web release correcta
y batería completa de 199 pruebas;
contratos SQL contextual, biblioteca y programas ejecutados sobre Dev aplicado,
todos con `ROLLBACK`. El ensayo local
`tools/test_trainer_contextual_work_concurrency.py` acredita 48 contenciones
observadas en RC/RR: padre/hijo, descarte, finalización simultánea, inicio del
alumno y cierre del vínculo en ambos órdenes. Usa tablas/constructor deportivo
mínimos y motores de permisos/checkpoint/planificación reales; no sustituye el
contrato de recetas/RLS en Dev. Advisors de seguridad sin nuevos hallazgos
respecto a la línea base. Web publicada en Trainer Dev el 24/10 desde
`95c0e8c8`, verificada por HTTPS. La aceptación humana de pérdida de respuesta
en programa/adaptación sigue pendiente; los ensayos anteriores no la sustituyen.
Las etiquetas compartidas ya están implementadas y el transporte push está
preparado y desactivado en Dev; sus contratos y evidencias se documentan en
`TRAINER_EDITOR_PREFERENCES.md` y `TRAINER_PUSH_NOTIFICATIONS_2026_10_24.md`.
Este apartado acredita recuperación contextual, sin cobros ni Xcode.

Publicación: `95c0e8c8dc6615eb70da1448a6477759a9b6f476-20261024-2`;
ZIP `trainer-trn029-95c0e8c8-package.zip`, SHA-256
`afd81b5ce78f8d6513e63900ac62272209b7e88a660ffa19831ce34e06af79ee`.
`trainer_release.py verify` acredita revisión, entrada, hash del JavaScript,
cabeceras y MIME WebAssembly sobre `trainer.entrenaop.es`, con destino Dev.
Chrome acredita catálogo y trabajos incompletos existentes, sin mutarlos;
consola sin errores durante esta comprobación.

## Instantánea inicial · 21/10/2026

21/10/2026. Implementación local de biblioteca y nuevas versiones de sesión.
La migración `20261021201803_trainer_session_work_recovery.sql` está creada y
ensayada junto con los avisos sobre el esquema real de Dev dentro de una única
transacción terminada en `ROLLBACK`; sigue **pendiente de aplicar en Dev**.
No acredita publicación, prueba autenticada del
portal ni producción. La integración del router pertenece al responsable de
Trainer y se verifica junto al punto de guardado del bloque.

## Composición compartida y frontera de servidor

Trainer consume `WorkoutEditorPage`, `WorkoutEditorWorkRepository`,
`WorkoutEditorWorkBinding` y el controlador común de ADMIN; no importa código de
`admin_app/`. `TrainerSessionWorkEditor` carga el trabajo completo antes de montar
el formulario. Un fallo conserva el trabajo y ofrece recuperar de nuevo. La base
persistida manda sobre la query inicial; si existe snapshot no se sustituye por
otra lectura de su plantilla. Las referencias de ejercicios se resuelven con los
permisos actuales, conservando las referencias retiradas en el estado crudo.

`WorkoutEditorSnapshot` conserva ambas modalidades, su orden, textos inválidos,
formatos y excepciones por serie. El editor común genera la receta usando
exclusivamente `projectWorkoutEditorSnapshot`, valida el dominio y guarda
`state.intent` antes de llamar a finalizar. El controlador confirma cualquier
guardado incierto antes del siguiente estado. La intención queda congelada con
el raw: recargar conserva UUID, revisión e intención. El recibo confirmado evita
crear otra versión aunque falle el retorno al destino.

SQL valida la forma y los límites del snapshot; el motor existente valida la
receta de `intent`, el origen profesional, ejercicios públicos o privados propios
y versionado. **SQL no demuestra equivalencia entre raw e intent ni reproduce la
conversión de Flutter.** Un autor que invoque directamente las RPC podría guardar
raw e intent distintos; solo puede finalizar su receta válida propia y ambos
cuerpos quedan congelados, retenidos y auditables juntos. Este contrato no
pretende conceder a `raw` autoridad deportiva.

## Identidad, origen y RPC

Todas las RPC exigen `p_expected_owner uuid`, sin valor predeterminado, igual a
`auth.uid()`, AAL2 y TOTP verificado. No permiten elegir propietario; ser ADMIN
no amplía acceso. El transporte además fija la sesión por identidad. Consultar
trabajos propios y recuperar recibos finales confirmados sigue permitido tras
deshabilitar el acceso profesional. Guardar, descartar o reabrir un trabajo
abierto, incluidos sus reintentos parciales, requieren acceso vigente.

El origen inmutable de esta entrega es:

```json
{
  "baseId": null,
  "programId": null,
  "parentWorkId": null,
  "phaseId": null,
  "positionId": null,
  "duplicate": false
}
```

`baseId` es UUID o null. Una base inicial debe ser una receta publicada propia
de origen `coach`. Revisarla exige que siga publicada al ejecutar el motor;
duplicarla utiliza sus campos como inicio sin archivar la base. `duplicate: true`
requiere base. Los otros cuatro IDs deben ser null: esta migración rechaza hijos
de programa, publicación oficial y adaptación de pautas. `state.context` debe ser
exactamente `{}`; no acepta `showInLibrary` ni campos de ADMIN.

| RPC | Parámetros además de `p_expected_owner` | Respuesta |
| --- | --- | --- |
| `list_trainer_session_work` | Ninguno | Hasta 100 abiertos, metadata y resumen de nombre/intención |
| `get_trainer_session_work` | `p_id uuid` | Trabajo completo propio abierto o cerrado; null si no existe |
| `save_trainer_session_work` | `p_id uuid`, `p_revision bigint`, `p_origin jsonb`, `p_state jsonb` | Recibo histórico y revisión/lifecycle actual |
| `discard_trainer_session_work` | `p_id uuid`, `p_revision bigint` | Recibo histórico y revisión/lifecycle actual |
| `reopen_trainer_session_work` | `p_id uuid`, `p_revision bigint` | Recibo de reapertura o finalización ya confirmada |
| `finalize_trainer_session_work` | `p_id uuid`, `p_revision bigint` | UUID exacto de la receta finalizada |

Un trabajo completo contiene `id`, `context: trainer_private`, `origin`, `state`,
`revision`, `result_id`, `lifecycle`, `updated_at` y `discarded_at`. El listado
recorta `state` a `editor.nameText` (160 caracteres) e indicador `intent: true`;
carece de schema y no sirve como checkpoint. El límite se aplica antes de
agregar los cuerpos. Recuperar usa siempre `get`.

El estado completo es `{schema: 1, editor: {...}, context: {}, intent?: {...}}`.
El validador limita 40 segmentos, 100 bloques, 100 ejercicios por bloque, 4096
ejercicios totales, 20 excepciones por ejercicio y 10000 caracteres por campo.
Rechaza enums, claves, índices repetidos, tipos y esquemas incompatibles sin
sobrescribir la copia previa. Los valores numéricos todavía inválidos se guardan
como texto; no se parsean durante la recuperación.

## CAS, recibos y finalización

Cada acción nueva aceptada avanza exactamente una revisión, incluso guardar el
mismo estado. El UUID se genera una vez al abrir la ruta de trabajo. El ledger
está separado del motor legacy y se identifica por propietario, contexto, trabajo,
acción y revisión esperada. Comprueba JSONB exacto y SHA-256. Reutilizar una clave
con otro contenido devuelve `22023` y el mensaje estable
`El reintento no coincide con la petición de trabajo original.`; revisión
obsoleta o cierre incompatible devuelve `40001`. Las revisiones esperadas están
acotadas a 0..2147483646.

Guardar, descartar y reabrir devuelven:

```json
{
  "receipt": {"work": {}},
  "current_revision": 1,
  "current_lifecycle": "open"
}
```

El recibo conserva metadata y estado de aquella petición. Nunca se sustituye por
el head de otra pestaña. El adaptador solo confirma una escritura si el recibo
sigue siendo actual, tiene el mismo origen y contiene el estado enviado. Un
recibo viejo conserva el conflicto y la petición local. Los cuerpos y recibos
históricos son inmutables.

Finalizar toma exclusivamente la intención ya guardada, llama
`trainer_private.save_trainer_workout(workId, intent, previousId)` y cierra el
trabajo en la misma transacción. Resultado, versión, archivo de base, presupuesto
y recibo son atómicos. Dos trabajos no crean sucesores publicados de la misma
base. Un fallo conserva base y trabajo sin efectos provisionales. Una operación
legacy con el mismo UUID produce conflicto incluso con receta idéntica; una
colisión invisible bajo RR revierte la subtransacción y devuelve `40001`.

Una intención no se borra con `save` ni con descarte. Tras un error definitivo,
reabrir bloquea y reconcilia el trabajo: si finalizó para esa revisión devuelve
su recibo; en otro caso retira únicamente la intención y avanza la revisión.
Un finalizador antiguo no actúa después de esa reapertura. Reintentar una
reapertura antigua devuelve su recibo histórico y nunca cancela una intención
posterior. Un trabajo descartado o finalizado no se reabre como trabajo editable.

El prefijo de bloqueos de biblioteca es perfil propio `KEY SHARE` → acceso
profesional → presupuesto de sesiones → trabajo → base/motor. El presupuesto
serializa trabajos distintos y su contador invalida snapshots RR antiguos.
Este orden no se generaliza a adaptación, cuyo motor conserva el orden de
cliente/perfil/acceso/cita/asignación/agenda y requiere su integración propia.

## Límites técnicos y conservación

Son límites independientes de los de programas, precios o plazas comerciales:

- 100 trabajos abiertos por propietario.
- 512 KiB por snapshot JSONB, contabilizados en servidor.
- 64 MiB lógicos retenidos: cuerpos de estado y petición, intenciones, recibos,
  metadata y trabajos abiertos, descartados y finalizados.
- 1200 acciones nuevas por hora; un replay exacto no añade acción.

Se reserva 4096 bytes de metadata y margen por fila; no representa espacio físico
exacto de PostgreSQL. Los cuerpos idénticos se deduplican dentro de propietario y
contexto. El estado y la envoltura de petición pueden ser cuerpos distintos y
ambos cuentan. Descartar libera plaza activa, sin liberar bytes. Finalizar no
requiere otra plaza. No existe purga automática. Los límites pueden reducirse por
cuenta; ampliarlos requiere revisar el contrato y migración.

Las tablas `trainer_private.session_work_limits`, `session_work_bodies`,
`session_works` y `session_work_operations` tienen RLS y ningún permiso directo
para `anon`/`authenticated`. Sus FK diferidas conservan la cascada de cuenta sin
reconstruir presupuestos al borrar el propietario.

## Verificación y límites de la entrega

El ensayo `tools/test_trainer_session_work_concurrency.py` utiliza PostgreSQL 17
efímero local y no admite DSN externos. Carga MFA, motor `save_trainer_workout` y
migración reales; usa un constructor deportivo de catálogo mínimo. Pasaron el
contrato SQL con `ROLLBACK` y 108 contenciones observadas: RC/RR, primeras
escrituras, CAS/recibos, cuotas, finalize/reopen, dos trabajos con una base,
colisión legacy, revocación y cascada de propietario en ambos órdenes. El
constructor mínimo no acredita todas las validaciones deportivas del esquema
real. El ensayo combinado de `supabase/tests/trainer_session_work_recovery.sql`
y avisos pasó después sobre EntrenaOP Dev (`sxbxfjqgoddzhtcyhalw`) con motores y
catálogo reales: DDL y contratos dentro de un `BEGIN`/`ROLLBACK` único y ningún
`COMMIT`, sin registrar migraciones ni dejar datos. El rechazo deportivo de cero
bloques comprueba el `P0001` y mensaje reales del constructor, además de la
conservación de raw, intención, revisión, lifecycle, base y presupuesto. El
constructor mínimo local reproduce ese mismo error; no se amplía la captura a
cualquier fallo para dar la prueba por superada.

Las regresiones Dart verifican identidad A→B en seis RPC, envelopes, congelación
del envío y recibos antiguos. Las de widgets verifican recuperación, autosave,
intención generada por el helper único, reload incierto y resultado confirmado
sin segunda versión. Análisis Trainer limpio y batería completa de 163 pruebas
correctas sobre el estado local contrastado; los 21 casos nuevos son 11 del
adaptador y 10 de presentación. La ruta real nueva y la matriz final tras su
integración se registran en el cierre del responsable, sin presentar esta
evidencia local como Dev.

Quedan fuera hijos de programa, adaptación individual, cambio de cuotas de
programas y publicación. La recuperación de hijos exige ampliar aditivamente su
validador de programa y proteger el enlace padre por CAS; esta entrega no activa
`recoverableSessions` en el adaptador profesional.
