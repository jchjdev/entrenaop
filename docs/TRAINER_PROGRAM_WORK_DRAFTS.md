# Trabajos incompletos de programas Trainer

21/10/2026. Persistencia privada del estado del editor compartido, conforme a
TRN-020. Migración nueva `20261021172219_trainer_program_work_drafts.sql`.
El servidor está aplicado en Dev y verificado junto al historial de Salud:
197 migraciones coincidentes y 26 contratos transaccionales con ROLLBACK sobre
el esquema aplicado. Producción no se ha consultado ni modificado. La interfaz
común y su adaptador están validados; la publicación se acredita por separado.

## Identidad y recorrido

El propietario efectivo siempre es `auth.uid()` y el contexto está cerrado a
`trainer_private`. Las cinco RPC requieren `p_expected_owner uuid`, sin valor
predeterminado: debe coincidir con la identidad autenticada antes de consultar,
bloquear o recuperar un recibo. Esta barrera evita que el estado capturado para
A termine en la cuenta B si cambia la sesión antes del envío HTTP; no permite
elegir propietario. Todas requieren AAL2 y TOTP verificado. Ser ADMIN no amplía
el acceso a trabajos ajenos.

El UUID del trabajo se genera una sola vez en el cliente. La primera escritura
usa revisión 0 y fija esquema 1 y `base_program_id` para toda su vida. La base,
si existe, debe ser un programa publicado propio en ese instante. Las lecturas
propias siguen disponibles tras deshabilitar el acceso profesional. Guardar o
descartar, incluidos sus reintentos, requieren acceso profesional vigente.

Un trabajo tiene `lifecycle` igual a `open`, `discarded` o `finalized`. Cada
acción nueva aceptada avanza exactamente una revisión, incluso guardar el mismo
estado. Un reintento exacto conserva la revisión y el recibo originales. Un
trabajo cerrado no se reabre. Descartar conserva su estado y su retención.

## RPC

| RPC | Parámetros adicionales a `p_expected_owner` | Respuesta |
| --- | --- | --- |
| `list_trainer_program_work` | Ninguno | Hasta 100 trabajos abiertos, ordenados por fecha e ID descendentes; estado resumido |
| `get_trainer_program_work` | `p_id uuid` | Trabajo completo propio, abierto o cerrado; `null` si no existe en la cuenta |
| `save_trainer_program_work` | `p_id uuid`, `p_revision bigint`, `p_state jsonb`, `p_base_program_id uuid = null` | Recibo inmutable y estado actual del control de revisión |
| `discard_trainer_program_work` | `p_id uuid`, `p_revision bigint` | Recibo inmutable y estado actual del control de revisión |
| `finalize_trainer_program_work` | `p_id uuid`, `p_revision bigint`, `p_content jsonb` | UUID del programa finalizado |

La forma del trabajo completo es:

```json
{
  "id": "uuid",
  "context": "trainer_private",
  "state": {},
  "revision": 1,
  "base_program_id": null,
  "finalized_program_id": null,
  "updated_at": "fecha del servidor",
  "discarded_at": null,
  "lifecycle": "open"
}
```

El listado devuelve la misma metadata, pero `state` contiene exclusivamente
`{"name":"primeros 160 caracteres del nombre sin recortar"}`. Es un índice de
recuperación, no un checkpoint editable. Recuperar exige `get`, que conserva
exactamente todo el estado crudo. El servidor limita las filas antes de agregar
y extrae solo el nombre; no construye hasta 100 estados completos para después
descartarlos. El resumen carece de `schema`, por lo que no puede guardarse como
si fuese el estado completo.

Guardar y descartar devuelven:

```json
{
  "receipt": {"work": {}},
  "current_revision": 1,
  "current_lifecycle": "open"
}
```

`receipt.work` es la respuesta histórica exacta de esa petición; no se sustituye
por la última versión de otra pestaña. El adaptador solo confirma un guardado
cuando ese recibo sigue siendo la revisión actual y abierta. Si otra pestaña
avanzó o cerró el trabajo, devuelve conflicto y conserva los cambios locales.
El descarte confirma solo un recibo actual con estado `discarded`.

El ledger se identifica por propietario, contexto, UUID de trabajo, acción y
revisión esperada. Compara tanto JSONB exacto como SHA-256 de la petición; una
clave ya usada con otro contenido devuelve `22023` y el mensaje estable
`El reintento no coincide con la petición de trabajo original.`. El cliente
congela la petición al enviarla y no cambia su payload tras una respuesta
incierta. Una revisión obsoleta o un cierre incompatible devuelve `40001`.
Las revisiones esperadas admitidas son 0..2147483646.

## Estado crudo y finalización

El guardado acepta campos todavía incompletos, preservando sus cadenas crudas,
orden de fases y sesiones. Valida esquema, tipos y tamaños acotados: 64 fases,
256 sesiones o pendientes por fase, 4096 referencias totales y 65536 caracteres
por campo de texto. Trainer conserva `categories: []` y `primary: null`.
El esquema 1 admite `session.positionId` y `phase.replacementPositions` del
editor común, conservándolos sin reinterpretarlos; los snapshots antiguos pueden
omitirlos y mantienen el mapa legado `replacements`. No admite alias alternativos
sin contrato. Una sustitución pendiente por posición también impide finalizar.

Finalizar no acepta un programa arbitrario enviado junto al trabajo. El servidor
deriva el contenido desde el último snapshot guardado y exige igualdad JSONB
con `p_content`, antes de ejecutar el motor de programas existente. Bloquea
pendientes y sustituciones sin resolver. El modo guía produce una fase
`Entrenamiento` con duración nula; las semanas ocultas no se interpretan. En
modo por fases convierte semanas con las reglas de `int.tryParse` de Dart web:
espacios Unicode admitidos, signo y decimal o hexadecimal, sin separadores ni
espacios internos. El recorte de texto incluye U+0085; el parseo entero web lo
excluye. Las cantidades enormes se rechazan fuera del dominio técnico, sin
replicar el redondeo de enteros de JavaScript. Los descansos desactivados ignoran
sus campos crudos; los activados exigen enteros válidos. El validador existente
de programas aplica después sus rangos y permisos sobre las sesiones propias.

La finalización y `save_trainer_program` se ejecutan en la misma transacción,
usando el UUID estable del trabajo como `operation_id`. El cambio de versión,
archivo de la base, recibo final y cierre del trabajo son atómicos. Dos trabajos
con la misma base no crean dos sucesores publicados. Un fallo conserva la base
y el trabajo abiertos, sin programa provisional ni consumo de cuota adicional.

Un recibo final propio, exacto y confirmado se recupera con identidad y MFA,
incluso tras deshabilitar el acceso o archivar la base durante su propia
finalización. No vuelve a ejecutar el motor. Un intento nuevo sigue requiriendo
derechos vigentes. Una escritura legacy previa con el mismo UUID, aunque tenga
idéntico contenido, produce conflicto explícito: no se adopta como recibo de
este trabajo. La carrera con una escritura legacy invisible bajo aislamiento
RR revierte cualquier efecto provisional y devuelve `40001`.

## Presupuestos y conservación

Son límites técnicos iniciales, independientes de precios o plazas de alumnos:

- 100 trabajos abiertos por propietario.
- 512 KiB por snapshot, sobre la representación JSONB contabilizada en servidor.
- 64 MiB lógicos retenidos por propietario, incluyendo todos los cuerpos,
  versiones de estado conservadas por recibos, peticiones finales, metadata y
  trabajos abiertos, descartados y finalizados.
- 1200 acciones nuevas por hora; un reintento exacto no añade otra acción.

El presupuesto incluye una reserva de metadata de 4096 bytes y un margen por
fila; no representa el uso físico exacto de PostgreSQL. Los cuerpos inmutables
idénticos se deduplican dentro del propietario. Cada nuevo recibo y sus metadatos
siguen teniendo coste, aunque el contenido no cambie. Descartar libera una plaza
activa, pero **no libera bytes retenidos**. No existe purga automática ni una
promesa de creación comercial ilimitada. Los `CHECK` actuales permiten ajustar
estos máximos a la baja por cuenta; superarlos requiere una migración revisada.
Finalizar no necesita una plaza activa adicional, pero respeta los límites de
bytes y tasa. Los errores conservan el trabajo; la UI debe mantener el estado
local pendiente en vez de presentarlo como guardado.

Las tablas viven en `trainer_private`, con RLS y sin acceso directo de clientes.
La escritura bloquea perfil propio `KEY SHARE`, acceso profesional, presupuesto
del propietario y trabajo, en ese orden. Una actualización del presupuesto
serializa también trabajos distintos e invalida snapshots RR anteriores a otra
escritura. Los cuerpos y recibos son inmutables; sus claves foráneas diferidas
permiten el borrado por cascada de la cuenta sin reconstruir presupuestos.

## Evidencia y límites

El contrato `supabase/tests/trainer_program_work_drafts.sql` pasó en EntrenaOP
Dev con la migración temporal y `ROLLBACK`; después se aplicó únicamente esta
migración con CLI, tras comprobar que era la única pendiente. Se repitieron
los 26 contratos sobre el esquema aplicado con ROLLBACK. Incluye
aislamiento entre cuentas y ADMIN, barrera de identidad A→B, MFA, revisión cero,
no-op, recibos antiguos, cierre, bases compartidas, fallo atómico de finalización,
colisiones legacy, cuotas, tasa, revocación, grants y listado resumido sin cuerpo
privado mientras `get` preserva el snapshot íntegro.

`tools/test_trainer_program_work_concurrency.py` levanta PostgreSQL 17 efímero
local y carga los motores reales con un catálogo mínimo. Comprueba bloqueos
observados en 108 contenciones, RC y RR con tres repeticiones por caso: primeras escrituras con fila
de presupuesto ausente, CAS, recibos, presupuestos de activos/bytes/tasa,
finalización frente a descarte, misma base, revocación, colisión legacy y borrado
de perfil en ambas direcciones. No acepta DSN externos ni modifica Dev o
producción. La aceptación Flutter y la integración de navegación pertenecen al
adaptador y al portal, verificados por sus responsables.

El análisis de seguridad posterior conserva las advertencias previas y añade
solo cuatro INFO de RLS sin políticas en las nuevas tablas privadas cerradas.
No se conceden permisos directos por ese aviso. Evidencia local ignorada:
`build/trainer-recovery-db-push*.log`,
`build/trainer-recovery-migrations-applied.log` y
`build/trainer-recovery-contracts-applied.log`.

El portal conecta biblioteca, ruta estable por UUID, recuperación y descarte
confirmado al editor común. La base persistida manda sobre la query inicial;
un trabajo finalizado abre exactamente su programa confirmado. Renovar sesión
no reconstruye repositorios ni borra campos. Los metadatos `positionId` y
`replacementPositions` evitan sustituir por error la primera posición de una
sesión repetida; el legado ambiguo pide elegir. El controlador compara mapas
canónicos sin alterar listas ni texto. Reintentar un enlace ya aplicado confirma
su snapshot sin volver a guardar la sesión como pendiente.

Matriz final: Trainer 137 pruebas, ADMIN 306 con dos omisiones previas, UI común
124 y raíz 1220 con una omisión previa. Los análisis correspondientes son limpios
y la compilación web Dev de Trainer es correcta. Regresión del router real:
UUID/controlador/texto conservados, autosave a 700 ms y recuperación tras salir.
Trainer Dev se publica desde `37dcd14`, release terminada en `-20261021-9`:
HTTPS contrasta identidad/archivos/cabeceras y Chrome comprueba biblioteca y
editor con la sesión MFA existente, sin crear trabajos de prueba.
[Evidencia de publicación](TRAINER_RECOVERY_RELEASE_2026_10_21.md).
La aceptación humana de recuperación con contenido y la distribución móvil
siguen siendo comprobaciones distintas.
