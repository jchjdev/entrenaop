# Entrega coordinada ADMIN y creador común · 21/10/2026

> Actualización ADM-008 · 21/10/2026: la propuesta de recuperación que figura
> más abajo es el diseño previo, conservado como contexto. Su implementación,
> contrato definitivo, validación y límites se describen en
> [Sesiones incompletas y pendientes](ADMIN_SESSION_RECOVERY_2026_10_21.md).
> Allí `phaseId` y `sessionWorks` ya están implementados de forma opcional;
> la integración profesional corresponde a Trainer. Las frases de «solo diseño»
> de este documento se refieren a aquel tramo anterior.

## Propiedad y alcance entregado · ADM-005

**Estado: implementación de este tramo terminada y verificada; lista para
integración selectiva conjunta.** Favoritos/recientes y recuperación adicional
se separan al final: **favoritos/recientes implementados y verificados para integrar**;
recuperación adicional todavía propuesta, sin implementación. SQL de preferencias
pertenece al tramo de seguridad coordinado; este chat no la crea ni aplica.

Este chat mantiene ADMIN, creadores y Compacto. Trainer mantiene `trainer_app/`,
sus adaptadores y RPC profesionales. Arquitectura/dispositivos se coordina aparte.
Base inspeccionada: `main` en `2948f12`; `.gitignore` y `devtools_options.yaml`
son cambios ajenos que no se incluyen. No hay ramas adicionales ni stage global.

Primer bloque acotado: crear un ejercicio sin abandonar la sesión, duplicar
posiciones/bloques sin compartir controles y mejorar búsqueda/filtros del selector.
No se crea otro editor ni se cambian prescripción, cuotas, identidad o permisos.

Archivos reservados por este bloque antes de editar:

- `packages/workout_editor_ui/lib/workout_editor_page.dart`
- `packages/workout_editor_ui/lib/exercise_search_list.dart`
- `packages/workout_editor_ui/test/workout_editor_page_test.dart`
- `packages/workout_editor_ui/test/exercise_search_list_test.dart` (nuevo)
- `admin_app/lib/features/exercises/presentation/admin_exercise_dialog.dart` (nuevo)
- `admin_app/lib/features/exercises/presentation/admin_exercises_page.dart`
- `admin_app/lib/features/exercises/data/admin_exercise_repository.dart`
- `admin_app/lib/features/workouts/presentation/admin_workout_editor_page.dart`
- `admin_app/lib/features/guided_programs/presentation/guided_session_workspace.dart`
- `admin_app/lib/features/guided_programs/presentation/admin_guided_pages.dart`
- `admin_app/lib/core/admin_router.dart`: únicamente inyección de ejercicio/vídeo
  en creadores; se preservan las rutas y la integración profesional existentes.
- Pruebas ADMIN de esos adaptadores y `docs/ADMIN_PROFESSIONAL_DELIVERY.md`.

Las actualizaciones de índice/roadmap se integrarán después por contenido, sin
reemplazar lo registrado en paralelo. No se editan `trainer_app/`, `lib/` del
deportista, SQL profesional, MFA, infraestructura de publicación ni cobros.

## Contratos aditivos

- `WorkoutEditorPage.onCreateExercise`: callback opcional del consumidor con
  `BuildContext`, que devuelve `WorkoutEditorExercise?` solo tras guardar. `null`
  significa cancelar; fallo conserva la receta y permite reintentar. No se lleva
  Supabase, ADMIN, rutas ni publicación al paquete compartido. El editor inserta
  o actualiza el resultado por ID en su catálogo y selecciona la posición actual.
- ADMIN extrae su diálogo de `ExerciseForm` a una función reutilizable con los
  repositorios actuales. Guardar ejercicio oficial devuelve su UUID confirmado;
  editar sigue con su identidad. No se identifica por nombre ni se crean permisos.
- `ExerciseSearchList` mantiene sus parámetros actuales y añade categorías de
  filtro opcionales aportadas por el consumidor. Usa la normalización existente
  de búsqueda. Los consumidores que no pasan filtros conservan su contrato.
- Duplicar copia en profundidad valores comunes, excepciones y campos inactivos
  de formatos, conservando los límites de cada formato. No duplica una identidad
  persistida ni una sesión por pulsar: solo edita el borrador abierto.

## Fronteras pendientes

Inventariar favoritos persistentes y recuperación de sesiones incompletas antes de
añadir almacenamiento: el creador común no debe decidir cuenta, audiencia, cuotas
ni destino. No presentar como implementada la recuperación ante pérdida total de
respuesta de creación ni sincronización de favoritos entre aplicaciones.

Vídeo: `ExerciseForm.videoFieldBuilder` ya permite aportar el campo de medios.
ADMIN conserva su subida oficial mediante adaptador; la autorización privada,
almacenamiento y cuotas profesionales pertenecen a Trainer. La extracción de UI
ampliada a continuación no concede acceso al backend administrativo.

### Ampliación coordinada: UI común de vídeo

Trainer encarga trasladar también la UI existente. Javier aclara después en este
chat que **solo Trainer ofrece enlace externo HTTPS y subida; ADMIN ofrece solo
subida**, sin borrar medios existentes ni cambiar permisos de servidor. Se aplica
con `ExerciseVideoField.allowExternalLinks`: `true` en el componente general y
`false` impuesto por el adaptador `AdminExerciseVideoField`. El adaptador oficial
no expone el control de enlace ni el texto HTTPS. Backend privado, SQL y
`exercise_video.ts` quedan fuera. Esta corrección expresa sustituye la propuesta
anterior de mostrar ambas opciones también en ADMIN; pendiente de incorporar al
índice global por su propietario al integrar.
API publicada antes de extraer:

- `workout_editor_ui/exercise_video_source.dart`: `ExerciseVideoSource`,
  `ExerciseVideoUpload(id, headers)` y `ExerciseVideoStatus(status, url)`.
  Contrato técnico inyectado: `create`, `upload`, `status`, `playback`, `thumbnail`;
  sin Flutter, SDK, cliente autenticado ni comprobaciones de autorización propias.
- `workout_editor_ui/exercise_video_field.dart`: `ExerciseVideoField`, con los
  parámetros actuales `controller`, `repository`, `onBusyChanged`, `pickVideo`,
  `onCoverReady`, `pickFrame`, `allowExternalLinks`; límites de presentación configurables con los
  valores oficiales actuales por defecto. Se monta en `videoFieldBuilder`.
- `workout_editor_ui/exercise_video_frame_picker.dart`, `_stub.dart`, `_web.dart`:
  conserva `pickExerciseVideoFrame(BuildContext, Uri)` y captura web actual.
- ADMIN mantiene imports/nombres `AdminVideoUpload`, `AdminVideoStatus` y
  `AdminExerciseVideoRepository` mediante alias. `AdminExerciseVideoField` es un
  adaptador que fuerza `allowExternalLinks: false`.
  `SupabaseAdminExerciseVideoRepository` conserva autorizaciones y cuotas
  oficiales y delega transporte validado; no se usa para contenido privado.
- Reservados esos cinco archivos nuevos, los adaptadores ADMIN de vídeo/frame
  picker y sus pruebas. `workout_editor_ui/pubspec.yaml` incorpora únicamente
  `video_player: 2.14.0` y `web: 1.1.1`, ya usados/resueltos en las apps. Verificar
  las resoluciones de consumidores antes de integrar; sin actualizaciones globales.

No se editan `workout_core/trainer_progress.dart`,
`trainer_access/trainer_followup.dart`, sus pruebas ni documentos de coordinación.

El formulario ADMIN también suprime el fallback de URL cuando no se inyecta
repositorio de vídeo; informa de que la subida no está disponible y conserva el
valor previo. `ExerciseVideoTransport` pertenece al subagente de Trainer; ADMIN
consume sus métodos `upload`/`thumbnail` manteniendo las comprobaciones de cuenta.
El puerto requiere `http: 1.6.0`, versión ya resuelta, añadida sin actualizar SDK.

## Verificación y estado

API lista para integrar en Trainer sin editar sus páginas desde este chat:

- `onCreateExercise(BuildContext)` ya conecta catálogo vacío o existente,
  cancelación/error y selección del UUID confirmado; conserva objetivos y series.
- Duplicar posición/bloque, búsqueda normalizada y filtros de músculo/material
  están implementados en el creador común. No hay almacenamiento de favoritos nuevo.
- Vídeo común y adaptador ADMIN conectados a `ExerciseVideoTransport`; ADMIN
  **solo subida**, Trainer `allowExternalLinks: true` (predeterminado) para ambas.
  Se conserva la URL previa aunque ADMIN no la edite, y también cuando no se
  inyecta proveedor. Trainer debe mantener un adaptador con autorización propia.
- Dependencias directas del paquete: `video_player: 2.14.0`, `web: 1.1.1`,
  `http: 1.6.0`, existentes en caché/consumidores. Raíz y ADMIN resuelven offline.

Comprobaciones terminadas el 21/10/2026:

- Primeras baterías completas: raíz **1175 correctas/una omisión previa**,
  ADMIN **303 correctas/dos omisiones previas** y editor UI **77 correctas**,
  incluido el transporte aportado por su propietario.
- Tras compactar el selector y añadir cancelación contextual: creador/filtros
  **44 correctas**, editor ADMIN **19 correctas** y regresión final de catálogo y
  creadores ADMIN **75 correctas**. Subida exclusiva ADMIN **9 correctas**.
- Análisis de ADMIN y editor UI sin incidencias. El análisis global anterior fue
  correcto; Trainer continuó editando después y mantiene la responsabilidad de
  cerrar sus comprobaciones globales. Su prueba dirigida de transporte ya pasa
  **7 casos** tras corregir los errores transitorios de compilación/dependencia.
- Compilación web ADMIN Dev final correcta con CSP, sin mapas de fuente ni CDN
  de recursos. Sin despliegue al subdominio desde este bloque.
- Selector real revisado en captura a **320 px y texto 2×**: filtros plegados,
  lista desplazable y acción de creación accesible. Campo ADMIN revisado en
  captura sin entrada HTTPS. No sustituye la aceptación física en dispositivos.

Código y API de este tramo estables para el punto de guardado conjunto. No hay
migraciones propias ni cambios de permisos. No se acredita el cierre global del
bloque profesional. Favoritos persistentes y recuperación adicional de borradores
tienen la propuesta siguiente; no se presentan como implementados.

### Rutas para integración selectiva

Además de las rutas reservadas arriba, este tramo incluye:

- `admin_app/lib/features/exercises/data/admin_exercise_video_repository.dart`
- `admin_app/lib/features/exercises/presentation/admin_exercise_video_field.dart`
- Los tres archivos `exercise_video_frame_picker*.dart` del mismo directorio.
- `admin_app/test/features/exercises/presentation/admin_exercise_video_field_test.dart`
- `admin_app/test/features/exercises/presentation/admin_exercises_page_test.dart`
- `admin_app/test/features/programs/presentation/admin_programs_page_test.dart`
- `admin_app/test/features/workouts/presentation/admin_workout_editor_page_test.dart`
- `packages/workout_editor_ui/pubspec.yaml`
- `packages/workout_editor_ui/lib/exercise_video_source.dart`
- `packages/workout_editor_ui/lib/exercise_video_field.dart`
- Los tres archivos `exercise_video_frame_picker*.dart` del paquete compartido.
- `packages/workout_editor_ui/test/exercise_video_field_test.dart`

El transporte común y sus auxiliares/tests, los adaptadores/lockfiles de Trainer,
SQL profesional y documentos globales pertenecen a sus propietarios. Revisarlos
conjuntamente como dependencias, sin atribuirlos a este tramo ni hacer stage global.

Sin commit propio: Trainer coordina el punto de guardado conjunto; no se toca el
índice hasta su ventana de integración. Se preservan los archivos en desarrollo
de los demás chats y no se publica ni se modifica producción.

## Siguiente propuesta común · sin implementar

**Confirmación para el checkpoint conjunto:** favoritos/recientes y recuperación
adicional **no están iniciados en código**. Solo se ha escrito este inventario y
propuesta. El tramo anterior permanece estable, sin nuevas ediciones de fuente
por este chat desde las comprobaciones finales. No se reservan ni se modifican
`professional_assessment.dart`, su codec/tests ni `assessment_capture_fields.dart`.

### Manifiesto final del tramo entregado

Rutas de fuente, pruebas y documentación a revisar selectivamente por el
integrador (no es una instrucción de stage global):

```text
admin_app/lib/core/admin_router.dart
admin_app/lib/features/exercises/data/admin_exercise_repository.dart
admin_app/lib/features/exercises/data/admin_exercise_video_repository.dart
admin_app/lib/features/exercises/presentation/admin_exercise_dialog.dart
admin_app/lib/features/exercises/presentation/admin_exercise_video_field.dart
admin_app/lib/features/exercises/presentation/admin_exercises_page.dart
admin_app/lib/features/exercises/presentation/exercise_video_frame_picker.dart
admin_app/lib/features/exercises/presentation/exercise_video_frame_picker_stub.dart
admin_app/lib/features/exercises/presentation/exercise_video_frame_picker_web.dart
admin_app/lib/features/guided_programs/presentation/admin_guided_pages.dart
admin_app/lib/features/guided_programs/presentation/guided_session_workspace.dart
admin_app/lib/features/workouts/presentation/admin_workout_editor_page.dart
admin_app/test/features/exercises/presentation/admin_exercise_video_field_test.dart
admin_app/test/features/exercises/presentation/admin_exercises_page_test.dart
admin_app/test/features/programs/presentation/admin_programs_page_test.dart
admin_app/test/features/workouts/presentation/admin_workout_editor_page_test.dart
packages/workout_editor_ui/lib/exercise_search_list.dart
packages/workout_editor_ui/lib/workout_editor_page.dart
packages/workout_editor_ui/lib/exercise_video_source.dart
packages/workout_editor_ui/lib/exercise_video_field.dart
packages/workout_editor_ui/lib/exercise_video_frame_picker.dart
packages/workout_editor_ui/lib/exercise_video_frame_picker_stub.dart
packages/workout_editor_ui/lib/exercise_video_frame_picker_web.dart
packages/workout_editor_ui/pubspec.yaml
packages/workout_editor_ui/test/workout_editor_page_test.dart
packages/workout_editor_ui/test/exercise_search_list_test.dart
packages/workout_editor_ui/test/exercise_video_field_test.dart
docs/ADMIN_PROFESSIONAL_DELIVERY.md
```

Dependencia de integración: transporte/cliente/preview común de vídeo y sus pruebas
son de Trainer; no incluirlos de forma aislada o atribuir su cierre a ADMIN. La
revisión conjunta posterior comunicada por Trainer tiene cifras más recientes que
las baterías propias indicadas arriba y debe registrarse por su propietario.

### Inventario y propuesta

Inventario localizado del 21/10/2026:

- `GuidedWorkRepository` y `GuidedWorkController`, en
  `packages/workout_editor_ui/lib/guided_program_work.dart`, ya soportan trabajos
  de programa, revisión optimista y escrituras serializadas. El adaptador ADMIN
  existente conserva esa recuperación; no crear otra copia paralela del programa.
- El creador personal usa `WorkoutEditorDraftStore` y su adaptador por usuario en
  `lib/features/workouts/data/services/shared_preferences_workout_editor_draft_store.dart`.
  Guarda una receta tipada y fecha. Es una referencia de comportamiento existente,
  no una dependencia que deba importar el paquete compartido ni un contrato que
  pueda sustituirse sin migración explícita.
- `WorkoutEditorPage` conserva actualmente campos crudos e inactivos en memoria
  para detectar cambios, pero no ofrece un puerto de recuperación persistente.
  `WorkoutDraftCodec` trata la receta de dominio; no basta para recuperar un campo
  incompleto o valores de formatos temporalmente ocultos.
- La búsqueda localizada en catálogos de ejercicio de las tres apps y en el
  selector común no encontró favoritos/recientes persistentes. El selector actual
  sí conserva búsqueda normalizada y filtros de músculo/material.

### Un recorrido recomendado

1. Añadir un puerto opcional de preferencias del catálogo al selector común.
   Operaciones propuestas: leer favoritos/recientes, marcar/desmarcar favorito y
   registrar una selección real. Guardar únicamente IDs estables y fecha de uso;
   nada de nombres de clientes, URLs de medios ni copias del catálogo. Mostrar
   favoritos/recientes solo tras intersectarlos con el catálogo autorizado actual,
   manteniendo búsqueda/filtros y sin resolver recursos privados desde un ID
   persistido. Un fallo de preferencias permite seguir creando la sesión y ofrece
   reintento; no puede bloquear el guardado deportivo ni fingir sincronización.
2. Añadir un puerto opcional de recuperación al creador, con snapshot versionado
   del estado editable. Incluir texto crudo, modalidad, posiciones, campos comunes,
   excepciones por serie y valores inactivos para volver de formato sin pérdida.
   El guardado de recuperación admite campos incompletos; la validación de receta
   sigue siendo obligatoria al guardar la sesión real. Los datos adicionales del
   consumidor se recuperan mediante un contrato propio explícito, no un volcado
   arbitrario de widgets, repositorios o mapas ajenos.
3. El consumidor aporta un contexto inmutable de entorno, cuenta, espacio de
   trabajo/audiencia, tipo de editor, trabajo y recurso/versión base. Los adaptadores
   construyen claves con todos esos componentes. No deducir identidad desde el
   editor ni usar solo el ID de sesión: una sesión dentro de un programa necesita
   distinguir el trabajo/posición que se está editando. Los IDs y metadatos de
   contexto separan almacenamiento; nunca acreditan autorización por sí mismos.
4. Al volver a entrar, ofrecer restaurar o descartar tras comprobar identidad,
   contexto, esquema y revisión base. Un cambio en el servidor produce conflicto
   visible y conserva ambos estados; no sobrescribir automáticamente ni convertir
   una recuperación en publicación. Serializar escrituras con revisión esperada,
   conservar la petición incierta y limpiar solo la revisión recuperable que quedó
   confirmada al guardar. Descartar es explícito. Un formato ilegible no se destruye
   silenciosamente. El coordinador conjunto debe cerrar retención/cuotas antes de
   implantar almacenamiento remoto.
5. Adaptadores separados para ADMIN, Trainer y deportista. Puertos sin Supabase,
   credenciales ni rol ADMIN en `workout_editor_ui`; respetar el borrador personal
   existente y el checkpoint de programa. Al salir/cambiar de cuenta se cancelan
   suscripciones y operaciones pendientes, se desmonta el editor y se rechazan
   respuestas del contexto anterior antes de aplicarlas o escribirlas. Ningún estado
   global compartido entre cuentas. No persistir URLs firmadas, tokens, bytes de
   vídeos/fotos, headers de subida ni claves: solo IDs estables de recursos y receta.

Antes de implementar, acordar estos contratos con el propietario Trainer y
registrar la decisión global por su propietario. No se reservan todavía rutas
nuevas ni se crean tablas/RPC. Cualquier SQL de preferencias/recuperación requiere
coordinación previa con Trainer para identidad, RLS, concurrencia y pruebas.

Pruebas exigibles al siguiente tramo: cuentas A/B y Dev/otros entornos aislados,
respuesta tardía tras salir, restauración incompleta y por formato, revisión
concurrente, pérdida de respuesta al guardar, corrupción/esquema incompatible,
IDs retirados del catálogo, ausencia de puertos (compatibilidad) y fallo de
preferencias sin impedir editar/guardar. Verificar snapshots sin medios firmados
ni secretos y filtros/favoritos a 320 px con texto 2×. Estas pruebas no están
acreditadas por la batería del tramo entregado.

## Punto 6 · contrato concreto propuesto para coordinar antes de editar código

El coordinador pide continuar primero con favoritos/recientes. **Propuesta de
persistencia: backend por cuenta y contexto**, para reabrir el navegador y cambiar
de dispositivo sin perder preferencias. No se promete modo offline ni se añade
un segundo almacenamiento local silencioso. Compartir solo puertos, modelos y
controlador de presentación; cada app aporta su adaptador. No se ha implementado
este contrato ni creado/aplicado SQL. La recuperación adicional espera al acuerdo
de persistencia de su snapshot independiente.

### Archivos propuestos y propietarios

- Nuevos propios: `packages/workout_core/lib/exercise_catalog_preferences.dart`
  y su prueba; DTO inmutable de preferencias y puerto puro, sin Flutter/Supabase.
- Nuevo propio:
  `packages/workout_editor_ui/lib/exercise_preferences_controller.dart` y su
  prueba; carga, errores, mutaciones serializadas y descarte de respuestas tardías.
- Propios existentes: `exercise_search_list.dart`, `workout_editor_page.dart` y
  sus pruebas. Parámetros nuevos opcionales `idOf` y `preferences` en la lista,
  y `exercisePreferences` en el editor. Ausencia del puerto conserva la UI actual.
- Nuevo propio:
  `admin_app/lib/features/exercises/data/admin_exercise_preferences_repository.dart`
  y prueba. El adaptador verifica la cuenta antes y después de cada await.
  `AdminWorkoutEditorPage`, workspace y adaptador guiado solo propagan el puerto
  opcional. La inyección superior se coordina con el dueño del router: **no se
  modifica `admin_router.dart` en este tramo nuevo**, tampoco main/shell.
- Trainer crea/injecta su adaptador en archivo nuevo
  `trainer_app/lib/trainer_exercise_preferences_repository.dart`, su prueba y
  las páginas consumidoras bajo su propiedad. No se editan desde ADMIN.
- Tabla/RPC/migración CLI y prueba SQL: propietario coordinador Trainer, nombre y
  contrato por acordar antes de reservar fecha/archivo. No SQL aplicado desde aquí.
- Documento propio actualizado; docs raíz siguen reservados a sus propietarios.
  No nuevas dependencias de Flutter/Dart: las apps ya tienen cliente de backend.

### Puerto y semántica propuesta

Nombres orientativos, pendientes de aceptación del coordinador:

```dart
abstract interface class ExerciseCatalogPreferences {
  Future<ExercisePreferenceSnapshot> read();
  Future<ExercisePreferenceEntry> setFavorite(
    String exerciseId,
    bool favorite, {
    required int expectedFavoriteRevision,
  });
  Future<void> recordSelection(String exerciseId);
}
```

El puerto se construye ya vinculado a contexto y cuenta; no permite pasar otro
userId por operación. Snapshot/entrada contienen ID estable, favorito, revisión
de favorito y fecha de selección. El adaptador fija el proyecto/entorno del
cliente y el servidor obtiene identidad autenticada. Los contextos propuestos
son catálogo oficial ADMIN y biblioteca profesional del propietario; el mismo
usuario en ambas superficies no mezcla sus preferencias. Un futuro contexto de
cliente solo se añade mediante contrato y autorización propios, no texto libre
proporcionado por la UI.

Servidor: propietario+contexto+ejercicio como clave lógica, lectura privada y
mutaciones limitadas a esos datos. La operación verifica acceso efectivo al
contexto y al ejercicio; favorito no concede lectura de receta ni medio. ADMIN
conserva sus requisitos administrativos/MFA y Trainer sus permisos privados.
La revisión CAS del favorito evita que dos pestañas sobrescriban decisiones sin
avisar. Registrar selección actualiza únicamente la fecha de servidor y no el
favorito/revisión, evitando conflictos artificiales. Escrituras diferentes deben
combinarse. RPC atómicas, grants/RLS y pruebas transaccionales se acuerdan con el
coordinador antes de implementar. No vaciar favoritos porque se retire un ID del
catálogo visible: ocultarlo de resultados sin borrar la preferencia ajena a esa
lectura.

UI: selección Todo/Favoritos/Recientes integrada con búsqueda y filtros actuales;
estrella accesible por fila. Recientes se ordenan por fecha y ofrecen un número
acotado de resultados (propuesta inicial: 20; límite técnico a acordar). Registrar
solo al seleccionar un ejercicio realmente aceptado por el editor, incluido el
creado contextualmente; abrir o filtrar no registra uso. Persistencia fallida
muestra error/reintento, sin deshacer la selección deportiva ni bloquear guardar.
El controlador invalida su generación al cambiar puerto/cuenta/contexto o salir;
el adaptador comprueba también identidad tras cada respuesta. Ningún singleton
con catálogo/preferencias de varias cuentas. Solo intersectar IDs con el catálogo
autorizado actual; jamás descargar recursos adicionales por el historial.

### Límites para autorizar la implementación siguiente

Primera entrega: favoritos/recientes sincronizados y sus pruebas; sin routers,
main, shell, cambios de cuotas/precios, borradores nuevos ni publicación. No Git.
El coordinador debe confirmar persistencia/contrato y reservar SQL para completar
integración real; hasta entonces no iniciar cambios de fuente parciales que
aparenten guardar sin backend. Pruebas: CRUD/lectura por cuenta y contexto,
desautorización durante await, CAS en dos pestañas, selección vs búsqueda, fallo
con reintento sin duplicar evento, catálogo retirado, ausencia del puerto y 320 px
con texto 2×. Los recientes son preferencias de autoría, no historial deportivo.

### Contrato Dart confirmado para adaptadores · punto 6 en implementación

El coordinador acepta backend y contextos cerrados `admin_official` /
`trainer_private`. La propuesta anterior de primera entrega está ahora autorizada;
borradores nuevos siguen sin iniciar. Archivo de contrato estable:
`packages/workout_core/lib/exercise_catalog_preferences.dart`.

```dart
enum ExercisePreferenceContext { adminOfficial, trainerPrivate }
// Cada valor se traduce explícitamente al contexto SQL cerrado en el adaptador.
ExercisePreferenceEntry({
  required String exerciseId,
  required bool favorite,
  required int favoriteRevision,
  DateTime? lastSelectedAt,
});
ExercisePreferenceSnapshot({
  required Iterable<ExercisePreferenceEntry> entries,
  int recentLimit = 20,
  int favoriteLimit = 500,
});
abstract interface class ExerciseCatalogPreferences {
  String newOperationId();
  Future<ExercisePreferenceSnapshot> read();
  Future<ExercisePreferenceEntry> setFavorite(
    String exerciseId, bool favorite, {
    required int expectedRevision,
    required String operationId,
  });
  Future<ExercisePreferenceEntry> recordSelection(
    String exerciseId, {required String operationId},
  );
}
```

Mapeo coordinado: `get_editor_exercise_preferences(p_context)` devuelve
`entries`, `recent_limit`, `favorite_limit`; cada entrada contiene `exercise_id`,
`favorite`, `favorite_revision`, `last_selected_at`.
`set_editor_exercise_favorite(p_operation_id,p_context,p_exercise_id,p_favorite,p_expected_revision)`
y `record_editor_exercise_selection(p_operation_id,p_context,p_exercise_id)`
devuelven entrada canónica. Ambas mutaciones retienen el mismo operationId/payload
al reintentar. La selección también devuelve entrada, evitando lectura extra para
obtener la fecha confirmada. El controlador descarta respuestas tras dispose.

Resolver con seguridad antes de cerrar adaptador: una revisión CAS obsoleta debe
aportar entrada vigente mediante `ExercisePreferenceConflict(current)` o detalle
equivalente de servidor. Un ejercicio desmarcado que ya no esté en recientes puede
no figurar en snapshot; no debe dejar la UI reintentando indefinidamente revisión
0. El recibo replay anterior tampoco debe sobrescribir un favorito más reciente
de otra pestaña; el adaptador/controlador debe conservar la revisión mayor.

SQL y adaptador técnico compartido pertenecen al agente de seguridad; Trainer
conecta su adaptador e inyección; este chat implementa puerto/controlador/UI y
propagación ADMIN, sin routers/main/shell ni Git. El coordinador reserva la nueva
migración CLI; ninguna SQL se crea/aplica desde este chat.

### Entrega de favoritos/recientes · fuente estable y matriz terminada

La implementación posterior sustituye las notas anteriores de «sin iniciar»
únicamente para favoritos/recientes. Borradores adicionales no se han iniciado y
quedan después del checkpoint, por acuerdo del coordinador. No ampliar ese alcance
durante el pase final.

- Puerto puro y DTO inmutables en `workout_core/exercise_catalog_preferences.dart`.
  `recordSelection` devuelve entrada canónica, igual que `setFavorite`.
- `ExercisePreferencesController` es por instancia, cuenta/contexto del puerto y
  vida del editor. Conserva UUID/payload al reintentar, serializa operaciones y
  bloquea siguientes acciones del mismo ejercicio ante respuesta incierta; permite
  seguir cambiando otros ejercicios. Fusiona favorito por revisión mayor y fecha
  por máximo confirmado. Conflicto CAS presenta estado vigente y permite nueva
  decisión; las revisiones desmarcadas se conservan sin resucitar fechas retiradas
  del snapshot acotado. Errores/lecturas y respuestas tras dispose están cubiertos.
- Selector con menú Todos/Favoritos/Recientes y estrella por fila, compatible con
  búsqueda/filtros. Solo muestra datos del catálogo autorizado recibido. La lista
  no registra selecciones por abrir/buscar; el editor registra una sola vez al
  aceptar la posición o el ejercicio creado. Un fallo de preferencias no deshace
  la receta ni bloquea su guardado. Pantalla antigua si no se inyecta puerto.
- Parámetros estables: `WorkoutEditorPage.exercisePreferences` recibe
  `ExerciseCatalogPreferences?`; `ExerciseSearchList.preferences` recibe
  `ExercisePreferencesController?` y necesita `idOf` cuando se aporta controlador.
  El editor posee y descarta su controlador; la lista solo suscribe/desuscribe.
  El consumidor mantiene estable el adaptador durante el mismo contexto y desmonta
  el editor/pila al cambiar identidad. ADMIN ya reconstruye router al cambiar UID.
- ADMIN: `SupabaseAdminExercisePreferencesRepository(client, userId)` extiende
  `ExercisePreferencesClient`; contexto `adminOfficial`, UUID v4 existente,
  guardas de identidad y traducción de `40001`. Main crea una instancia por router
  autenticado y router la inyecta en los siete creadores de sesión/programa,
  incluida la propagación al workspace y calentamientos. **Inyección real lista**,
  no parámetro opcional desconectado. La reapertura de main/router de ADMIN fue
  autorizada expresamente por el coordinador para esta conexión y nada más.
- Cliente común y su RPC puntual para CAS de desmarcadas fuera del snapshot,
  SQL/ledger y adaptador/inyección Trainer pertenecen al coordinador/seguridad.
  No se modifican desde este chat. El cliente normaliza la revisión antes del
  primer envío y la conserva para posteriores reintentos del mismo operationId.
- No almacenamiento offline nuevo, dependencias nuevas, cambios de receta,
  permisos de publicación ni historial deportivo. Preferencias no son borradores.

Rutas adicionales a integrar selectivamente sobre el manifiesto anterior:

```text
packages/workout_core/lib/exercise_catalog_preferences.dart
packages/workout_editor_ui/lib/exercise_preferences_controller.dart
packages/workout_editor_ui/test/exercise_preferences_controller_test.dart
admin_app/lib/features/exercises/data/admin_exercise_preferences_repository.dart
admin_app/test/features/exercises/data/admin_exercise_preferences_repository_test.dart
admin_app/lib/main.dart
```

Rutas ya incluidas que reciben esta ampliación: `exercise_search_list.dart`,
`workout_editor_page.dart`, sus pruebas, `admin_workout_editor_page.dart`,
`guided_session_workspace.dart`, `admin_guided_pages.dart` y `admin_router.dart`.
No ediciones en Trainer, atleta, documentos globales ni archivos de evaluaciones.
Sin Git de escritura ni despliegue propio.

Comprobación dirigida previa: **57** casos de creador/selector/controlador y
capturas reales (antes de los tres casos límite últimos); controlador final **11**;
protocolo/selector/controlador **20** (antes de esos tres casos); adaptador ADMIN
y creador **21**. Los análisis finales de raíz, ADMIN y UI son limpios.
La batería ADMIN conjunta encontró una aserción de prueba obsoleta: generar un
UUID ya no requiere identidad. Se sustituyó por verificar que tras salir se
rechazan realmente lectura y ambas escrituras, sin enviar peticiones. No se
relajó la guarda del adaptador. La repetición completa ya ha pasado.

**Cierre del tramo propio, 21/10/2026:**

| Comprobación | Resultado | Evidencia local ignorada |
| --- | --- | --- |
| Batería raíz | 1204 correctas, 1 omisión previa | `.dart_tool/adm006-root-all.log` |
| Batería ADMIN repetida tras corregir la prueba | 306 correctas, 2 omisiones previas | `.dart_tool/adm006-admin-all-final.log` |
| Batería UI común | 110 correctas | `.dart_tool/adm006-shared-all.log` |
| Análisis raíz / ADMIN / UI | Sin incidencias | `.dart_tool/adm006-{root,admin,shared}-analyze.log` |
| Build web ADMIN Dev | Correcto, CSP y sin CDN/maps | `.dart_tool/adm006-admin-build.log` |
| Captura final selector con preferencias/filtros/creación 320 px texto 2× | Correcta, revisada visualmente | `.dart_tool/adm006-picker-success-capture.log` |

La última modificación posterior a la batería completa solo amplía el caso de
captura existente para inyectar preferencias también en su escenario satisfactorio;
ese caso se repitió y pasó. No cambia fuente ni número de casos de la matriz.
Capturas de widgets reales, sin datos personales:

- `packages/workout_editor_ui/build/performance_v2_review/exercise-picker-320-2x.png`
- `packages/workout_editor_ui/build/performance_v2_review/exercise-picker-preferences-error-320-2x.png`
- `packages/workout_editor_ui/build/performance_v2_review/exercise-preferences-320-2x.png`

Diff de rutas propias revisado, incluidos archivos nuevos y conexión main/router.
Fuente congelada para checkpoint conjunto; no quedan fallos conocidos propios.
SQL/ledger y cliente compartido tienen su propietario y validación independientes;
su prueba en Dev y el recorrido autenticado completo deben cerrarse en la entrega
conjunta. No atribuir a estas pruebas simuladas una comprobación real de permisos
Dev, aceptación física ni publicación en el subdominio. Borradores adicionales no
iniciados. Sin stage, commit, push, despliegue ni cambios de producción desde aquí.

## Publicación ADMIN Dev comprobada · 21/10/2026

Javier autoriza expresamente integrar y publicar para probar favoritos/recientes
con su cuenta. La entrega conjunta queda en `a2c467f`, con formato posterior en
`dd5443b6c245f0f8d29f40a94c62e0823d5d9363`. La publicación automática de esta última
revisión en `admin.entrenaop.es` termina correctamente:
[ejecución 39641421696](https://github.com/jchjdev/entrenaop/actions/runs/39641421696).

Comprobación independiente del manifiesto HTTPS: revisión exacta, entorno
`development`, proyecto `sxbxfjqgoddzhtcyhalw` y release
`dd5443b6c245f0f8d29f40a94c62e0823d5d9363-39641421696-1`.
También se verifican SHA-256 del JavaScript servido, entrada, cabeceras y MIME de
WebAssembly mediante el comprobador del publicador. El intento anterior sobre
`a2c467f` no acredita publicación: falló su transporte y su reintento fue detenido
correctamente porque main había avanzado. Se conserva la trazabilidad de la
revisión realmente publicada, sin activar una compilación local pendiente.

Chrome abre una pestaña nueva con la sesión Dev existente de Javier, sin cerrar
su laboratorio. En `/sessions/new`, modo Fuerza, el selector remoto carga los 72
ejercicios autorizados sin aviso de error de preferencias, muestra estrellas y
el menú Todos/Favoritos/Recientes. Se deja abierto para la prueba del propietario.
No se guarda/publica una sesión ni se alteran sus favoritos/recientes durante
esta comprobación de lectura/UI. La prueba humana de marcar y retomar queda para
Javier; no atribuirla al mero despliegue. Producción permanece intacta.

Evidencia local de esta comprobación (ignorada):
`.dart_tool/adm006-deployed-build-info.json` y
`.dart_tool/admin-pref-deployment/hosted-favorites-recents.png`.
Este registro posterior se conserva pendiente de integrar en la siguiente ventana
Git coordinada; este chat no interviene en el índice del nuevo tramo de borradores.

## Contrato aditivo de posiciones pendientes · corrección compartida verificada

**Nombres definitivos para el contrato de servidor: `positionId` y
`replacementPositions`, camelCase; `schema` permanece 1.** No alias snake_case.

Claves exactas para coordinar el validador del trabajo Trainer, **sin alias**:

- Se conserva `schema: 1` y todas las claves existentes del snapshot.
- Cada objeto de `phases[].sessions[]` añade `positionId: String` (UUID v4 estable
  de la posición; no es el ID de la receta ni se copia al duplicarla).
- Cada fase añade `replacementPositions: Map<String,String>` con
  `nuevoTemplateId -> positionId` para una revisión guardada pendiente de enlace.
- Se conserva `replacements: Map<String,String>` con
  `nuevoTemplateId -> templateIdAnterior`, también en nuevos guardados, para
  mantener la lectura de trabajos previos y la referencia de origen. Creaciones
  pendientes sin sustitución no incluyen esa entrada.
- Al restaurar objetos antiguos sin `positionId`, se genera uno por posición y
  se incluye en el siguiente guardado, antes de abrir otra edición contextual.
  No se regeneran IDs que ya están guardados ni se usan índices como identidad.
- Retomar una sustitución nueva exige coincidencia única de `positionId` en su
  fase. Si falta o es ambigua, no busca silenciosamente por templateId ni añade
  una sesión. Ofrece elegir explícitamente una posición y conserva pendiente al
  cancelar. Si ya no hay posiciones, conserva el pendiente y avisa.
- Para legado sin `replacementPositions`, se sustituye automáticamente solo si
  `templateIdAnterior` aparece exactamente una vez. Si se repite, se pide elegir.
- `pending`, ambos mapas y los ajustes originales se conservan hasta resolver la
  posición; se limpian juntos al enlazar. No se cambia `GuidedSession.input()` ni
  la receta final de publicación. Quitar/ordenar/deshacer conserva la identidad
  del objeto de posición. Regresión principal: `[S,S] -> [S,T]` tras guardar la
  revisión de la segunda, fallar el enlace, recargar y Retomar.

Propiedad: `packages/workout_editor_ui/lib/guided_program_editor_page.dart`, nueva
prueba `packages/workout_editor_ui/test/guided_program_recovery_test.dart` y esta
hoja. No SQL ADMIN ni edición de contratos/rutas/repositorios Trainer. Las nuevas
claves son metadatos de composición; no contienen medios, tokens ni permisos.

Ampliación localizada acordada: `guided_program_work.dart` y nueva prueba
`guided_program_work_test.dart`. Comparación JSON canónica con claves de mapas
ordenadas recursivamente, conservando orden de listas y textos crudos. Evita que
el orden de claves de JSONB provoque un guardado ficticio; incorporar positionId
ausente sigue siendo un cambio real que se conserva antes de abrir sesión hija.

### Handoff estable de la corrección de posiciones

Implementación y nombres definitivos, sin nuevos cambios de fuente pendientes:

```text
packages/workout_editor_ui/lib/guided_program_editor_page.dart
packages/workout_editor_ui/lib/guided_program_work.dart
packages/workout_editor_ui/test/guided_program_recovery_test.dart
packages/workout_editor_ui/test/guided_program_work_test.dart
docs/ADMIN_PROFESSIONAL_DELIVERY.md
```

La recuperación también pide elección si la posición existe pero ya contiene otra
revisión diferente de la fuente y del destino pendientes. No pisa esa decisión
posterior automáticamente. Se neutralizan los textos de checkpoint y versión del
editor para los dos consumidores, manteniendo sus adaptadores y guardados propios.

Validación final del 21/10/2026:

- **12 regresiones nuevas correctas:** fallo real de carga tras guardar la revisión
  de la segunda `[S,S]`, recarga/Retomar como `[S,T]` tanto oficial como profesional;
  preservación de calentamiento/descansos/IDs; legado ambiguo con cancelación y
  selección explícita; legado único; posición eliminada/reordenada/cambiada;
  metadatos persistidos antes de abrir hija; JSONB distinto orden sin RPC;
  normalización real de IDs; listas y texto crudo conservados.
- **Baterías completas:** raíz **1219 correctas/1 omisión previa**, ADMIN **306
  correctas/2 omisiones previas**, UI compartida **122 correctas**. Evidencias
  `.dart_tool/adm007-{root,admin,shared}-all.log`.
- **Tres análisis sin incidencias:** raíz
  `.dart_tool/adm007-root-analyze-final.log`, ADMIN
  `.dart_tool/adm007-admin-analyze.log`, UI
  `.dart_tool/adm007-shared-analyze-final.log`.
- Formato y diff propios revisados, incluidos los dos archivos de prueba nuevos.
  Un aviso final de llaves de estilo en un helper de prueba se corrigió sin cambiar
  su semántica y se repitieron los análisis. No se han reducido pruebas existentes.

Fuente congelada para el checkpoint coordinado. No SQL ni nuevos adaptadores de
cuenta desde este tramo; el backend y pruebas Dev pertenecen al coordinador.
La corrección todavía no está publicada en ADMIN: la comprobación remota anterior
acredita favoritos/recientes sobre `dd5443b`, no esta ampliación posterior.
Sin cambios propios en Git de escritura, Trainer, Health ni documentos globales.

### Borde de reintento del callback ya aplicado · ampliación acotada

Se confirma y corrige el caso W2: la sesión T ya está enlazada en memoria, el
guardado del enlace puede haberse confirmado en servidor pero perder su respuesta,
y el editor hijo vuelve a llamar a `onSaved(T)`. Si `appliedId == id`, ahora solo
se llama a `_saveWork()` y se retorna. El checkpoint confirma la petición incierta
congelada; no vuelve a añadir T a `pending`, no recarga el catálogo ni crea W3
con T simultáneamente aplicada y pendiente.

Dos regresiones adicionales, creación y revisión, registran todos los payloads
enviados a un repositorio con recibos por revisión/payload. W2 se confirma antes
de simular pérdida de respuesta; el catálogo se interrumpe justo antes del retry.
Se comprueba que confirmar no necesita catálogo, que los dos últimos envíos son
iguales, que ningún payload persiste T aplicada y pendiente, y que tras recargar
queda una sola T, sin acción Retomar ni mapas de sustitución. **14 regresiones
dirigidas correctas** en `.dart_tool/adm007-callback-retry.log`.

No cambian las claves del snapshot, el contrato SQL ni el controlador canónico.
Archivos de esta ampliación: `guided_program_editor_page.dart`,
`guided_program_recovery_test.dart` y esta hoja; siguen congelados para el
checkpoint conjunto. El coordinador ejecutará la batería raíz final junto con
los últimos cambios de Devices; no se duplica desde este chat.

Cierre tras el guard del callback: UI común **124 correctas** y ADMIN **306
correctas/2 omisiones previas**; análisis raíz, ADMIN y UI sin incidencias.
Evidencias finales:

```text
.dart_tool/adm007-retry-shared-all.log
.dart_tool/adm007-retry-admin-all.log
.dart_tool/adm007-retry-shared-analyze.log
.dart_tool/adm007-retry-admin-analyze.log
.dart_tool/adm007-retry-root-analyze.log
```

Source/API estables, diff revisado, sin fallos propios pendientes. El manifiesto
de integración sigue siendo los dos archivos de fuente, los dos de pruebas y
esta hoja indicados arriba. Sin Git de escritura ni publicación de este arreglo
desde este chat.

## Propuesta de recuperación de sesiones · inspección, sin código ni Git

Propuesta posterior al checkpoint `37dcd14`. No amplía lo acreditado como
implementado/publicado. El coordinador mantiene contratos profesionales,
persistencia, migraciones y publicación. Este apartado prepara el contrato común
para revisión antes de modificar fuentes.

### Hechos del creador actual

- `WorkoutEditorPage` guarda campos crudos solo en sus controladores privados.
  `_input()` valida/convierte únicamente la receta activa y descarta ramas ocultas;
  no sirve como snapshot de un trabajo incompleto.
- `_draftStamp` tampoco es un codec de recuperación: omite `automaticSlot` y
  variaciones vacías, y `additionalStateStamp` es una firma sin los valores del
  consumidor. No copiarlo como payload de almacenamiento.
- Carrera conserva sus tramos al pasar a fuerza y fuerza conserva bloques,
  excepciones y campos AMRAP al cambiar de formato. `automaticSlot` distingue los
  huecos generados de Tabata que se pueden retirar sin borrar contenido real.
- `_save()` espera `onSave(input)`, pero `onSaved(String)` es síncrono. El workspace
  conserva `_savedId` solo en memoria mientras confirma el enlace al programa.
  Tras cerrar el navegador no hay una identidad persistente del trabajo de sesión.
- Ya existen el checkpoint de programas y `sessions[].positionId`. Las fases no
  tienen identidad estable y una creación nueva todavía no tiene posición hasta
  incorporarse. Es necesario resolver ese destino antes de abrir un trabajo hijo.
- El editor personal del deportista conserva su propio store por usuario con
  receta tipada. Se mantiene su API y almacenamiento; esta propuesta no lo migra
  ni lo importa dentro del paquete compartido.

### Recorrido principal recomendado

1. El consumidor obtiene/genera **una vez** el UUID de trabajo y fija entorno,
   propietario esperado, contexto, tipo sesión/calentamiento y base/versionado.
   Carga el trabajo antes de habilitar edición. Catálogo y medios se consultan
   otra vez desde el consumidor autorizado.
2. Autosave guarda el snapshot crudo completo y contexto tipado con CAS, sin
   exigir una receta deportiva válida. UI distingue pendiente/guardando/guardado,
   fallo recuperable y conflicto. Un dato ilegible o incompatible se conserva y
   se informa; no se restaura como formulario vacío ni se sobrescribe en silencio.
3. Guardar valida mediante `_input()` y las reglas actuales. Primero se conserva
   una intención de finalización con snapshot y contenido validado **congelados y
   recuperables**; después el servidor crea la versión y fija el recibo del trabajo
   en la misma transacción. Una respuesta perdida se comprueba/reintenta con la
   identidad, revisión y payload originales, incluso después de reiniciar la app.
4. Una versión guardada se muestra como tal. Si falta el enlace al programa,
   recuperar actúa sobre el recibo existente; no llama a crear/revisar de nuevo.
   Se confirma el enlace con CAS y destino inequívoco. Solo ese acuse retira la
   referencia pendiente del padre; no borra el recibo ni las sesiones reutilizadas.
5. Este guardado produce borrador oficial en ADMIN o versión privada en Trainer.
   No publica contenido, asigna alumnos ni sustituye la revisión conjunta actual.

Estados de presentación propuestos: cargando, editando, guardando trabajo,
conflicto, finalización sin confirmar, versión guardada/enlace pendiente y enlace
confirmado. Mientras una finalización es incierta se congela esa petición; no se
permite enviar otra receta como si fuera el mismo intento. Descartar trabajo es
explícito y no elimina versiones de sesión ya guardadas.

### Snapshot crudo propuesto, separado del sobre de trabajo

Schema nuevo propio del formulario de sesiones, inicialmente `schema: 1`, sin
reutilizar ni reinterpretar el schema de programas. Campos propuestos:

| Nivel | Campos |
| --- | --- |
| Raíz | `schema`, `nameText`, `descriptionText`, `durationText`, `activeMode`, `segments`, `blocks` |
| `segments[]` | `countText`, `targetText`, `paceText`, `paceMaxText`, `recoveryTimeText`, `byDistance`, `recoveryByDistance`, `recoveryType` |
| `blocks[]` | `nameText`, `format`, `roundsText`, `restText`, `capText`, `exercises` |
| `exercises[]` | `exerciseId`, `targetType`, `automaticSlot`, `customSets`, `countText`, `targetText`, `restText`, `loadText`, `rirText`, `amrapRepetitionsText`, `amrapRirText`, `variations` |
| `variations[]` | `setIndex`, `targetText`, `restText`, `loadText`, `rirText` |

Se conservan textos sin parsear, espacios, entradas incompletas, las dos ramas
de modalidad, valores ocultos por formato y el orden de todas las listas. Las
variaciones completamente vacías se omiten de forma canónica y se regeneran por
`customSets`/cantidad al renderizar; mostrar campos que heredan no debe ensuciar el
trabajo. Las variaciones con cualquier texto, incluido espacio, sí se conservan.

No hacen falta UUID nuevos por serie/bloque para un checkpoint completo con CAS:
no hay mezcla automática entre ediciones concurrentes. Los UUID estables necesarios
son el trabajo, referencias de receta/ejercicio y el destino externo del programa.
El codec valida forma, enums, límites técnicos y versión, sin normalizar dosis ni
exigir repeticiones/ritmos válidos durante autosave. Los límites técnicos exactos
se acuerdan con backend antes de SQL; no se inventan precios ni cuotas comerciales.

No se guardan catálogo, miniaturas, URLs de reproducción firmadas, bytes de medios,
tokens, cabeceras, widgets, foco/selección del cursor ni errores de infraestructura.
Los campos libres siguen siendo texto privado del propietario y no van a logs.

### Puerto y consumidores: responsabilidades a cerrar

- Puerto tipado de trabajo de sesión: cargar, guardar con revisión, preparar y
  confirmar finalización, consultar recibo y descartar. El sobre fija `workId`,
  revisión, base de receta/versionado, lifecycle y recibo final. El servidor obtiene
  propietario real y exige expected_owner; el adaptador fija sesión antes del await.
- `WorkoutEditorPage` recibe un **binding opcional**. Sin él conserva exactamente
  `onSave`, `onSaved` y el guard actual. Con él se usa exclusivamente la ruta de
  trabajo/finalización, sin ejecutar también el guardado legado.
- Los datos adicionales pertenecen a un contexto tipado del consumidor: por ejemplo,
  el bool de visibilidad de ADMIN. Se capturan y restauran por callbacks/codec del
  binding, sin un mapa libre ni conocimiento de roles dentro de UI. El payload
  completo (raw + contexto) se congela antes del primer envío; un reintento no puede
  releer un bool cambiado. `additionalStateStamp` solo sigue siendo una firma.
- El binding aporta acuse asíncrono de versión guardada/enlace confirmado. No se
  convierte el callback síncrono actual en una confirmación que no acredita.
- Cada instancia está ligada a cuenta/contexto; cambios de identidad desmontan el
  editor e invalidan respuestas tardías. Ni caché global ni mezcla entre cuentas.

### Destino del programa: prerequisito explícito

Para editar una posición existente se usa el `positionId` actual. Para crear una
sesión dentro de una fase propongo reservar el `positionId` antes de abrirla y
añadir identidad estable `phaseId` a la fase. Registrar en el padre una referencia
duradera del trabajo hijo, separada de `pending` (que ya significa templateId).
Nombre propuesto: `pendingSessionWorks`, mapa `sessionWorkId -> positionId` dentro
de la fase identificada; **estas dos claves nuevas son propuesta, no definitivas**.

Abrir el trabajo hijo y registrar esa referencia debe confirmarse con revisión
del padre antes de editar. El trabajo queda ligado a padre/fase/posición/acción y
base inmutables. Recuperar consulta también hijos finalizados si falta su enlace;
un listado limitado a abiertos no basta. El programa no puede finalizar con hijos
sin resolver. Posición/fase ausente, cambio posterior o revisión concurrente
requieren resolución explícita, conservando hijo y recibo; nunca firstWhere por
templateId ni índice de fase. Los trabajos antiguos sin identidad de fase se
normalizan antes de abrir un hijo; no se crea un destino artificial por nombre.

Esto afecta el contrato validado de trabajo profesional y su guardado en servidor:
debe acordarse con el coordinador/seguridad antes de crear una migración nueva.
No modificar la migración aplicada ni ADMIN SQL desde esta propuesta. La UI anterior
no conocerá las referencias nuevas; backend debe impedir que un cliente viejo las
borre mediante un guardado completo o exigir versión de capacidades para ese trabajo.

### Archivos exactos propuestos y compatibilidad

| Archivo | Alcance previsto |
| --- | --- |
| Nuevo `packages/workout_editor_ui/lib/workout_editor_snapshot.dart` | DTO raw tipado y codec versionado puro, sin Flutter/Supabase |
| Nuevo `packages/workout_editor_ui/lib/workout_editor_work.dart` | Puerto, sobre, recibos y binding opcional de contexto tipado |
| Nuevo `packages/workout_editor_ui/lib/editor_work_checkpoint.dart` | Extraer únicamente mecanismo canónico de checkpoint/reintento compartido |
| Nuevo `packages/workout_editor_ui/lib/workout_editor_work_controller.dart` | Orquestar autosave, intención final y acuse sobre el mecanismo común |
| `packages/workout_editor_ui/lib/guided_program_work.dart` | Mantener API pública; delegación interna al mecanismo común, sin otra versión del controlador de programas |
| `packages/workout_editor_ui/lib/workout_editor_page.dart` | Exportar/restaurar raw, escuchar campos y conectar binding; mismo editor visual |
| `packages/workout_editor_ui/lib/guided_program_editor_page.dart` y `guided_program_editor_adapter.dart` | Identidad/destino del hijo y apertura recuperable aditiva, manteniendo el método legado |
| `admin_app/lib/features/workouts/presentation/admin_workout_editor_page.dart` | Contexto oficial tipado y propagación opcional |
| `admin_app/lib/features/guided_programs/presentation/guided_session_workspace.dart` y `admin_guided_pages.dart` | Recibo del hijo y confirmación del enlace, preservando posición |
| Nuevo `admin_app/lib/features/workouts/data/admin_workout_work_repository.dart` | Adaptador oficial tras acordar servidor; sin RPC profesionales |
| Nuevos tests UI `workout_editor_snapshot_test.dart`, `editor_work_checkpoint_test.dart`, `workout_editor_work_controller_test.dart` | Roundtrip, escrituras/concurrencia y finalización incierta |
| Tests existentes `workout_editor_page_test.dart`, `guided_program_work_test.dart`, `guided_program_recovery_test.dart` y tests ADMIN afectados | Compatibilidad de la ruta sin puerto y programa padre |

La extracción del mecanismo requiere una regresión de paridad del checkpoint de
programas antes de conectarlo a sesiones. Es una propuesta explícita de cambio
interno; no está autorizada ni implementada por haberla escrito aquí. No se duplica
el editor, la conversión de receta ni el controlador de programas. Se reutilizan
validadores/codecs de dominio para el contenido final, conservando el raw aparte.

Trainer conserva repositorios/rutas/main y contratos SQL con su propietario.
Routers/main de ADMIN no se tocarían hasta acordar entradas/IDs estables con el
coordinador. Sin paquetes nuevos, cambios de algoritmo o cambios comerciales.

Pruebas exigibles: roundtrip de cada formato y rama oculta/automaticSlot; entradas
incompletas; orden y excepciones; visibilidad adicional; autosave fallido/retry con
payload idéntico; reinicio antes/durante/después de finalizar; recibo previo y head
distinto; `[S,S]` con destino exacto; hijo finalizado/enlace perdido; fase quitada;
cuenta/contexto/entorno distintos; ausencia del puerto. Matriz raíz/ADMIN/UI y
contratos SQL/RPC reales coordinados antes de acreditar la funcionalidad.

**Resultado de este tramo: inspección y diseño solamente.** No se han editado
fuentes, tests, dependencias, SQL, rutas ni Git para recuperación de sesiones.
