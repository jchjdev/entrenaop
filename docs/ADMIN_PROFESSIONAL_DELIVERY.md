# Entrega coordinada ADMIN y creador común · 21/10/2026

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
