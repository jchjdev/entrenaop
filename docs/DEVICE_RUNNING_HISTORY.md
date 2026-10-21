# Historial privado de carreras · primer consumidor · 21/10/2026

## Autorización, alcance y estado

Javier autoriza conectar Salud a EntrenaOP y guardar historial por cuenta,
después del punto de guardado profesional y sin pisar Trainer. Se consume el
plugin `device_health`, sin importar `labs`; Android conserva mínimo 24 y su
lector sigue en el ensayo. Las pantallas web/Android pueden mostrar historial
propio guardado, sin acreditar lectura nativa disponible allí.

Implementado en `lib/features/device_activities`, con dependencia al dominio
puro `device_activity_core` y al adaptador nativo `device_health`. Trainer integra
la composición estable por cuenta, `/profile/activities` y la tarjeta «Carreras
de Salud». La UI depende de puertos; Supabase y HealthKit quedan en adaptadores.
Configuración iOS aditiva: HealthKit y descripción de lectura, sin cambiar firma,
identificador o vibración. No hay acceso de Trainer/ADMIN al historial privado.

Migración CLI `20261021171215_device_running_history.sql`, revisada con Trainer
y Arquitectura, aplicada solo a `entrenaop-dev` (`sxbxfjqgoddzhtcyhalw`). Prueba
SQL transaccional repetida sobre el esquema aplicado, con `ROLLBACK`. Se registró
como aplicada después de contrastar el DDL real; en ese momento coincidían 196
versiones y la ajena `20261021172219` seguía pendiente. Trainer la aplicó después
y comunicó 197 versiones coincidentes y 26 contratos transaccionales correctos,
incluido Salud, sobre el esquema conjunto. No acredita producción,
compilación iOS de la app principal ni instalación física de esta integración.

## Identidad y conservación

Una conexión lógica única por propietario y canal, creada en servidor, devuelve
su UUID como namespace estable EntrenaOP. No identifica AppleID, HealthStore,
Garmin ni una instalación. Logout, reinstalación o retirada de permisos OS no
la recrean. No se deducen cuentas a partir de la app escritora.

La lectura local mantiene generación/ámbito efímeros. Antes de guardar se
proyecta explícitamente a propietario y conexión del servidor, conservando el
UUID externo canónico, revisión, precisión y procedencia. El servidor deriva
propietario de `auth.uid()` y rechaza un titular esperado distinto, incluso si
el token cambia entre la selección y la petición. Scope/owner del payload no
conceden derechos ni se aceptan como autoridad.

El historial y sus revisiones permanecen mientras el titular los conserve en su
cuenta. Puede borrar el historial importado o eliminar la cuenta: se eliminan
observaciones y revisiones, sin afectar los registros originales de Salud. La
retirada de permiso OS y cerrar sesión no borran el historial ya guardado.
No se conserva indefinidamente una copia de registros eliminados.

## Lectura, selección y revisiones

La apertura carga historial guardado. Solo una acción explícita consulta Salud,
con ventana de siete días y límites del lector existente. Leer no sube carreras.
Guardar seleccionadas es la acción explícita de subida a la cuenta mostrada.
Los campos técnicos se presentan como kilómetros, duración y fecha del
dispositivo, sin inventar zona original ni precisión que no exista.

Identidad persistida: propietario + conexión/canal + UUID externo. Un UUID
distinto aunque tenga fechas/métricas parecidas sigue siendo otro objeto;
no se fusiona automáticamente ni se promete deduplicación de copias entre
iPhones o canales. Los UUID de HealthKit se normalizan a minúsculas sin cambiar
su significado. La aplicación escritora se conserva como procedencia.

Cada revisión guarda un snapshot inmutable y una huella canónica del servidor:

- Misma identidad, revisión y contenido: no duplica.
- Misma revisión con contenido distinto: colisión, rechazo del lote.
- Revisión nueva: comparación de anterior y candidata y confirmación explícita
  con la huella actual esperada. El guardado de otra persona/dispositivo que
  cambie esa huella provoca conflicto, no sobrescritura silenciosa.
- A → B → relectura de A: A histórica no vuelve a ser actual automáticamente;
  se devuelve conflicto/versión histórica. Restaurar queda fuera de este corte.

HealthKit no informa aquí de fecha de modificación. La hora de recepción y
el hash no se utilizan como orden de versiones. Esta importación manual
revisada no simula el pipeline incremental `PlanActivityImport`, sus cursores
o checkpoints. No crea asociaciones, citas, ejecuciones ni resultados.

## Transacción, reintentos y borrado

Un lote de hasta 200 selecciones se valida y guarda atómicamente. La operación
tiene UUID estable y queda ligada a conexión, generación de historial,
selección, payload normalizado y revisiones esperadas. La respuesta incierta
conserva el mismo sobre para reintentar; cambiar el contenido exige otra orden.
Replay exacto devuelve el recibo sin mover ninguna revisión actual. Reutilizar
la orden con otro contenido se rechaza. Un recibo viejo nunca sustituye la
consulta canónica del historial en el cliente.

La conexión se bloquea durante la escritura para serializar creación de
identidades, revisiones y recibos. No hay cola automática/offline duradera ni
reintentos al abrir o reanudar la pantalla. Cuenta/generación distintas invalidan
respuestas tardías y cualquier selección anterior.

Borrar historial elimina todos sus snapshots y recibos de importación e
incrementa la generación del servidor, conservando el namespace. Una orden
anterior al borrado no puede resucitar carreras. Solo se conserva un recibo
mínimo del propio borrado, sin actividades ni métricas, para que su replay no
borre importaciones posteriores. Se elimina con el siguiente borrado o con la
cuenta. Lectura vacía, parcial o permiso revocado nunca representan un borrado.

## Servidor y permisos

Hay cuatro tablas en `device_private`: límites, conexiones, revisiones de
carreras y recibos, con RLS y sin acceso directo del cliente. Las cuatro fachadas
públicas SQL son `SECURITY INVOKER`; solo las cuatro entradas privadas elevan
privilegios y comprueban titular/conexión. Se concede uso del esquema y ejecución
de esas entradas, sin tablas ni helpers. Consultas y escrituras se limitan al dueño.
No hay política especial para ADMIN, preparadores, seguimiento o Premium.
No se introducen secretos de proveedores ni se expone historial a Trainer.

Los límites técnicos iniciales, configurables únicamente en servidor por
cuenta, son 20.000 identidades, 32 revisiones por identidad, 50.000 recibos de
importación y 50 MiB de presupuesto lógico agregado. No representan espacio
físico PostgreSQL ni derechos Premium. Cada lote admite hasta 200 registros y
512 KiB, con allowlist estricta de campos y tipos. Alcanzar un límite rechaza
el lote íntegro, sin purga automática ni reducción de precisión.

Los bytes lógicos corresponden al JSON canónico de snapshots y recibos. Se
reserva además un slot fijo de 512 bytes por conexión para el recibo mínimo de
borrado, dentro del presupuesto. Se conserva en la propia conexión, máximo uno
por canal: así borrar sigue siendo posible aunque se haya agotado el cupo de
recibos de importación. Contadores y cuotas se bloquean por propietario antes
de la conexión, también entre dos canales. Las mutaciones bloquean primero el
usuario Auth con `FOR KEY SHARE`: evita el ciclo FK/CASCADE al abrir otro canal
mientras se elimina la cuenta. Replays no consumen cuota otra vez.

Una petición de guardado ya autorizada puede terminar en la cuenta anterior
tras cerrar sesión. El fencing del cliente no revierte una transacción ya
enviada: evita que su respuesta o selección se apliquen a la cuenta siguiente.

Solo se guardan campos explícitos del resumen: UUID/revisión, inicio/fin,
temporizador, distancia, escritor y metadatos opcionales de origen. No payload
bruto, nombre de actividad, GPS, datos clínicos o series diarias. Se conservan
ausencia frente a cero y microsegundos; todos los tipos y límites se validan de
nuevo en PostgreSQL. La normalización tiene versión propia.

## Verificación de cierre

Pruebas de dominio/Cubit/adaptador para proyección de ámbitos, selección,
persistencia, reintentos iguales, cuenta A/B, respuesta tardía, revocación y
lectura vacía sin borrar historial. Pruebas SQL transaccionales con `ROLLBACK`
para permisos, otra cuenta/ADMIN sin acceso, colisiones, CAS, A → B → A, lote
inválido sin parcial, replay tras revisión nueva y borrado sin resurrección.
Concurrencia local real para creación de conexión, doble guardado y CAS.

Comprobaciones del 21/10/2026:

- 16 pruebas de feature correctas: proyección, DTO, persistencia, revisión,
  incertidumbre/replay, A/B, permisos, lectura vacía, reanudación y borrado.
  Si una identidad reaparece en otra página por un cambio concurrente, la UI
  vuelve a consultar el historial canónico y descarta selecciones antiguas, sin
  ordenar revisiones opacas por momento de recepción ni mostrar dos versiones.
  Widget a 320 px y texto 2 prueba el cierre real del diálogo con `go_router` y
  los componentes comunes de confirmación.
- `flutter analyze` raíz limpio; batería raíz de 1.219 pruebas correctas y una
  omisión previa. Los cambios posteriores de diálogo y paginación pasan las 16
  pruebas de feature; la matriz del punto de guardado conjunto se contrasta aparte.
- APK debug de la app principal compilado. Android conserva mínimo 24 y todavía
  no conecta Health Connect desde esta app; el puente continúa aislado en el ensayo.
- `supabase/tests/device_running_history.sql` pasa en PostgreSQL 17 aislado y en
  Dev aplicado. Permisos, otra cuenta/ADMIN, allowlist, tipos, precisión,
  atomismo, revisión/CAS/A → B → A, replay y borrado comprobados con fixtures
  sintéticas. Tras `ROLLBACK`, Dev queda sin conexiones ni snapshots del ensayo.
- `tools/test_device_running_history_concurrency.py` observa bloqueos reales de
  sesiones SQL diferentes: namespace, doble orden, CAS y cuota agregada en RC;
  namespace, doble orden, CAS y cuota en RR, con `40001` y reintento posterior.
  Abrir segundo canal frente a eliminar Auth en ambos órdenes RC/RR no produce
  deadlock ni resurrección. El esquema mínimo local no acredita los demás
  triggers de borrado de cuenta de Dev ni una prueba física.
- Advisors de seguridad antes/después idénticos: 54 INFO RLS sin política,
  2 WARN funciones anónimas, 148 WARN funciones autenticadas y 1 WARN protección
  de contraseñas. Ningún hallazgo nuevo de esta migración; no se han reparado
  áreas ajenas. [Interpretación del linter](https://supabase.com/docs/guides/database/database-linter).

La CI de Salud compilará también la app principal iOS Simulator sin firma ni
publicación al guardar este bloque. Hasta ver su resultado no se acredita esa
compilación. La lectura física anterior del ensayo no acredita por sí sola
guardado ni lectura de la app principal. Bloque de dispositivos abierto.

## Siguiente prueba con el iPhone

Después de guardar el bloque y actualizar `main` en el Mac, ejecutar desde la
raíz `flutter pub get --enforce-lockfile`. Abrir `ios/Runner.xcworkspace` y
comprobar firma y HealthKit de la app principal. No activar datos clínicos ni
entrega en segundo plano. Conectar el iPhone, elegir su identificador físico
en `flutter devices` e instalar con `flutter run --release -d ID_DEL_IPHONE
--dart-define=APP_ENV=development`.

Iniciar sesión en la propia cuenta y abrir Perfil → Carreras de Salud. Leer,
revisar y guardar una selección; cerrar/reabrir y comprobar que sigue guardada.
Releer para contrastar que no se duplica. Revocar lectura impide nuevas lecturas
pero conserva lo guardado. Cambiar a una segunda cuenta no debe mostrar carreras
de la primera. Borrar historial requiere confirmación y conserva originales de
Salud. Estas comprobaciones siguen pendientes hasta realizarse en la app principal.

Fuentes: [UUID de un objeto HealthKit](https://developer.apple.com/documentation/healthkit/hkobject/uuid),
[RLS de Supabase](https://supabase.com/docs/guides/database/postgres/row-level-security).
