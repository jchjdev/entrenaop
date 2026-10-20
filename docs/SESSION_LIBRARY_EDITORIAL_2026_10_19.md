# Sesiones sueltas, reutilización y búsqueda · PRG-009

## Acuerdo del 19/10/2026

Javier confirma una marca administrativa por sesión para decidir si aparece en
Sesiones de EntrenaOP. Publicar una sesión y ofrecerla como entrenamiento suelto
son decisiones distintas. Se conserva el catálogo común y la posibilidad de
reutilizar la misma versión en varios programas guiados, sin copias por programa.
No se ocultan sesiones automáticamente por modalidad o dificultad.

También solicita buscar por los ejercicios que contiene cada sesión y retirar
los chips de categorías que no tienen programas publicados disponibles. Estos
chips pertenecen a Programas; no se inventa clasificación editorial de sesiones.

## Autoría y publicación

**Actualización UI-062 · 20/10/2026:** al crear desde un programa, la sesión se
guarda e incorpora como borrador dentro de su panel. La revisión final publica
el conjunto en una única operación atómica; ya no exige la publicación previa
de cada sesión. El catálogo independiente conserva su confirmación propia.
La marca de sesión suelta mantiene el contrato descrito aquí.
[Recorrido vigente](PROGRAM_AUTHORING_WORKSPACE_2026_10_20.md).

- El creador de sesiones sueltas comienza con Mostrar en Sesiones de EntrenaOP
  activado. Desde Crear nueva sesión dentro de un programa guiado comienza
  desactivado; la elección es editable antes de guardar.
- La ficha de revisión permite cambiar la marca de borradores o publicaciones
  generales. Se guarda inmediatamente, con error visible y reintento. Se bloquean
  salidas y acciones incompatibles mientras se guarda.
- El diálogo de publicación independiente indica si se ofrecerá como sesión
  suelta. Desde un programa se puede publicar con el conjunto al revisarlo.
- El listado administrativo indica su visibilidad y conserva los programas que
  utilizan la sesión. El selector de programas ofrece todas las versiones
  publicadas del catálogo común, incluidas las que no se anuncian sueltas.
- Una revisión deportiva conserva la marca de su versión fuente. Cambiar la
  marca no crea una revisión ni modifica bloques, series, enlaces o ejecuciones.

### Visibilidad a simple vista en ADMIN

Javier solicita ver la marca sin abrir cada sesión. Las tarjetas de sesiones del
creador de programas y las filas del selector comparten el indicador del listado
administrativo: «Visible como sesión suelta» u «Oculta como sesión suelta».
Los borradores indican qué ocurrirá al publicar, las sesiones retiradas no se
presentan como visibles y la falta de metadatos se muestra como visibilidad no
disponible. No se deduce que una sesión es oculta solo porque no se pudo cargar.

Javier precisa que también debe poder cambiarse desde la propia tarjeta. Cada
sesión general publicada del programa ofrece «Mostrar en Sesiones de EntrenaOP»
con un interruptor que guarda inmediatamente mediante la misma operación de la
ficha de revisión; se conservan ambos controles. No exige guardar el programa.
Durante la petición se bloquean cambios simultáneos y salida; el valor se confirma
tras guardar. El error queda junto al control y permite reintentar. Se conserva
la comparación con el valor esperado y se recarga el catálogo ante un error del
servidor para recoger posibles cambios de otra pestaña.

La marca pertenece a la versión compartida de la sesión: todas sus referencias
dentro del montaje se actualizan juntas, sin modificar fases, ejercicios ni
registros. Al volver de revisar una sesión se recarga el catálogo y se actualiza
la marca de su tarjeta. Una sesión oculta sigue siendo seleccionable y reutilizable
en programas. Selector y listado conservan su indicador informativo. Se reutilizan
los resúmenes ya cargados, sin consultas por tarjeta ni cambios de permisos.

`workout_templates.show_in_library` es una propiedad editorial de esa versión,
independiente de `visibility` y `status`. Se inicia en true para conservar el
comportamiento de los datos existentes. La migración no decide qué sesiones
previas debe retirar Javier del escaparate. Los calentamientos privados y las
plantillas privadas de preparaciones conservan sus contratos de acceso.

Crear el borrador guarda receta y marca de forma atómica en la RPC existente.
La nueva `set_admin_workout_library_visibility` exige administrador y el requisito
MFA vigente, valida el recurso general oficial y compara el valor esperado para
rechazar ediciones obsoletas. No concede permisos a deportistas ni acceso anónimo.
Las RLS y las reglas de ejecución no se relajan. Estar fuera del listado no es
una prohibición de lectura por enlace ni una nueva barrera comercial.

## Catálogo y búsqueda

El listado público exige publicación pública y show_in_library. Leer por identidad
para entrenar desde un programa conserva el camino existente. Las sesiones propias
mantienen su separación por propietario y no aplican la marca del escaparate oficial.

Los resúmenes incorporan los nombres de los ejercicios mediante la relación
bloques → items → ejercicios, en la misma consulta. No cargan series ni hacen una
consulta por tarjeta. El modelo compartido conserva nombres únicos y admite los
resúmenes anteriores sin ese campo. La búsqueda combina nombre, descripción y
ejercicios, manteniendo palabras sin orden, mayúsculas/tildes ignoradas y filtros
de tipo y duración. No añade un ranking, sinónimos ni una clasificación inferida.

La RPC `get_guided_program_catalog_categories` ofrece categorías activas con
alguna versión publicada vigente, con las mismas condiciones de vigencia del
catálogo general. Omite categorías vacías, de borradores y de versiones superadas.
ADMIN conserva todas las categorías para preparar publicaciones futuras. La fila
deslizable y el resto del catálogo directo PRG-008 se mantienen; la búsqueda actual
no hace desaparecer chips que tengan contenido fuera de esos criterios.

## Verificación y límites

Migración `20261019130022_workout_library_editorial_visibility.sql` aplicada solo
al proyecto enlazado de desarrollo. Prueba SQL nueva con ROLLBACK para permisos,
concurrencia, creación/revisión, reutilización en dos programas, inicio desde un
programa y conservación de una ejecución en curso. Comprueba categorías vacías,
de borradores y de versiones superadas. Cuatro regresiones SQL existentes de
autoría, sesiones oficiales, ejecución y categorías se ejecutan con ROLLBACK,
añadiendo únicamente contexto MFA a copias de prueba en build/.

Pruebas Flutter de consulta HTTP/nombres de ejercicios, compatibilidad del resumen,
opciones reales del catálogo, elección inicial, persistencia y error de visibilidad,
revisión y creación contextual. Se verifican raíz y ADMIN por el contrato compartido
de workout_core: análisis limpios, 1.092 pruebas raíz y 225 ADMIN correctas con
sus omisiones preexistentes. Historial local/Dev cotejado: 166 migraciones, sin
pendientes. Capturas reales de la opción en ADMIN a 390 px y 320 px con texto 2×.
La revisión de seguridad conserva los avisos existentes; la nueva RPC administrativa
usa el patrón de función con privilegios controlados, sin EXECUTE anónimo y con
permiso/MFA, recurso oficial y valor esperado comprobados por la prueba SQL.
Aceptación física del nuevo flujo pendiente; no se modifica
producción, no se migran automáticamente las elecciones editoriales existentes
y no se cambia la planificación adaptativa ni los ejecutores.

Ampliación de interfaz del 19/10/2026: análisis de ADMIN limpio y batería completa
con 227 pruebas correctas y las dos omisiones preexistentes. Las regresiones
comprueban el estado visible en el programa, su actualización al volver de la
revisión, la reutilización de sesiones ocultas y la distinción de borradores.
El selector con contenido se comprueba a 320 px, texto 2× y teclado abierto.
Este ajuste solo utiliza datos existentes de ADMIN: no requiere migraciones ni
modifica la aplicación del deportista.

Ampliación del interruptor en tarjetas: análisis ADMIN limpio y 229 pruebas
correctas, con las dos omisiones preexistentes. Se comprueban guardado inmediato
sin guardar el programa, valores esperados al ocultar/mostrar, sincronización
de referencias repetidas, bloqueo de cambios durante la petición y error con
reintento. La regresión de guardado recuperable espera a terminar el desplazamiento
antes de pulsar el botón; conserva sus comprobaciones de identidad e idempotencia.
Sin cambios de esquema, RPC ni permisos.
