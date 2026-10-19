# Programas guiados oficiales

## Acuerdo e implementación por bloques · 17/10/2026

Javier autoriza implementar PRG-001 conservando Biblioteca, preparaciones
adaptativas y ejecutores actuales. ADMIN elige rutina o recorrido por
fases en el mismo creador. Ambos contienen sesiones para entrenar y registrar
resultados. El autor define duración y condiciones de cada fase; el usuario
confirma el avance, sin consumo automático de etapas por calendario.

ADMIN crea calentamientos reutilizables y los adjunta opcionalmente a cada
sesión. El deportista puede omitirlos. Los descansos configurables conservan
pauta y ajuste personal separados; el ajuste genérico se limita a bloques
convencionales, sin alterar formatos temporizados ni el motor adaptativo.

## Bloque 1 · Autoría en ADMIN

**UI-056 · 19/10/2026:** el trabajo incompleto se guarda por administrador y se
recupera desde su URL o Continuar trabajando. Conserva campos inválidos y
sesiones pendientes. Guardar en catálogo aplica las validaciones previas y
registra el resultado para reintentar sin duplicar versiones; publicar continúa
siendo independiente. [Contrato y límites](ADMIN_DRAFT_RECOVERY_2026_10_19.md).

**UI-055 · 19/10/2026:** creación y reutilización de sesiones desde cada fase del
programa. Se usa el editor existente, se revisa y publica explícitamente y se
incorpora la identidad publicada a la fase original. Pendientes visibles durante
el montaje, recuperación de borradores desde el selector y creación de
calentamientos adjuntos sin cambiar de catálogo manualmente.
[Auditoría, comportamiento y límites](ADMIN_AUTHORING_2026_10_19.md).

Implementados catálogo y creador común, orden de fases/sesiones, duración,
condiciones, selección de sesiones oficiales generales publicadas, calentamiento
por sesión y límites de descanso entre series. Una guía usa una fase repetible
sin plazo. Publicación y retirada son explícitas; editar una publicación crea
un borrador nuevo. Las sesiones se crean y publican desde el editor existente.

El creador de calentamientos reutiliza campos, ejercicios públicos y series
convencionales del editor. Guarda una versión oficial privada con bloques
`warm_up`; no aparece como sesión suelta. Revisarla conserva las referencias
previas. No se adjunta otro calentamiento a una sesión que ya incluya uno.

### Contrato e integración

**Catálogo compartido confirmado por Javier · UI-054 · 19/10/2026.** Las sesiones
oficiales generales publicadas siguen disponibles sueltas y pueden formar parte
de uno o varios programas guiados. No se introduce contenido exclusivo del
programa. ADMIN muestra los usos de cada versión de sesión a partir de
`guided_program_links`, con nombre, versión y estado del programa. Conserva
visibles borradores y retirados para distinguirlos de publicaciones vigentes;
repetir una sesión en varias fases de la misma versión no duplica el indicador.
El enlace abre el editor de esa versión y al volver se recargan los usos.
La búsqueda de sesiones incluye los nombres de los programas asociados. Un fallo
al consultar usos se muestra como error de carga, no como ausencia de vínculos.

El catálogo administrativo guiado separa información y acciones: modalidad,
versión, estado, número de sesiones/fases, descripción breve y categorías antes
del pie de edición, portada y publicación. Retirar una publicación permanece en
Más opciones. Búsqueda sin tildes en nombre, descripción, público, material y
categorías, combinable con modalidad y estado. Se conservan todas las versiones,
las rutas y las operaciones vigentes. Sin nuevas dependencias ni migraciones.

- `workout_core/guided_program.dart`: entidades y validación pura.
  `guided_program_codec.dart`: adaptación JSON fuera de las entidades.
- `admin_app/lib/features/guided_programs/`: repositorio, adaptador y pantallas.
  Los widgets no consultan Supabase directamente.
- `guided_programs`: documento editorial versionado. `guided_program_links`
  acredita sesiones/calentamientos con claves foráneas y posiciones.
- `guided_warmups`: familia, versión y plantilla privada.
- `save_guided_program`, `save_guided_warmup`, `set_guided_program_status`:
  transacciones administrativas con `search_path` vacío y grants explícitos.
  Las tablas conceden al cliente solo lectura con RLS.
- No se admite una sesión privada de oposición como contenido libre. Retirar
  una sesión de un programa publicado se rechaza para no romper ese programa.

Migración `20261017101000_guided_program_authoring.sql`, aplicada únicamente
a `entrenaop-dev`. Prueba instalada `guided_program_authoring.sql` con ROLLBACK:
autoría, guía/fases, descansos inválidos, referencias, versiones y permisos.
La prueba no persiste datos. Las demos autorizadas posteriormente se detallan
al final de este documento.

Validación: análisis de raíz y ADMIN limpios; 927 pruebas raíz y 111 ADMIN
correctas, con sus omisiones existentes. Los avisos del asesor para las tres
RPC autenticadas son deliberados: la autorización administrativa se comprueba
dentro y está cubierta por SQL. Los avisos anteriores de Auth y otras funciones
no se corrigen dentro de este alcance.

El punto de guardado del bloque de autoría es `68f8d43`. El siguiente bloque,
descrito debajo, completa el recorrido del deportista sobre este contrato.

## Bloque 2 · Biblioteca, seguimiento y entrenamiento

Biblioteca incorpora Programas, Sesiones y Ejercicios. Conserva Sesiones como
entrada inicial, las colecciones oficiales/propias, sus accesos de creación y
los componentes visuales existentes. Programas ofrece búsqueda, filtro por
rutinas/fases o iniciados y dos resultados por página, sin carga infinita. El
selector admite desplazamiento cuando el texto ampliado no cabe.

La ficha permite seguir una versión, ver información/material, explorar fases,
entrenar sus sesiones y consultar su estado reciente. La guía repite su secuencia.
El recorrido por fases avanza solo mediante confirmación explícita; presenta
duración/condiciones del autor sin evaluarlas como reglas deportivas automáticas.
No permite avanzar con una ejecución en curso. Reenviar la misma confirmación
no consume otra fase. Al completar se puede repetir con un seguimiento nuevo,
conservando el anterior y sus resultados.

`GuidedProgramRepository`, sus Cubit y el adaptador Supabase separan lectura,
persistencia y presentación. Las rutas tienen identidad en la URL y la vista de
sesión y el ejecutor usan el navegador raíz, sin barra de secciones. La vista
previa existente incorpora puntos opcionales para ajustes e inicio guiado. Una
sesión de otra fase o de un programa todavía no seguido se puede consultar,
pero no iniciar como entrenamiento de ese programa.

### Nombres e Inicio · PRG-002 · acuerdo del 18/10/2026

Javier confirma **Rutinas** para el filtro, **Rutina** para la etiqueta de la
tarjeta y **Por fases** para la otra modalidad. ADMIN utiliza los mismos nombres.
Se conservan los identificadores persistidos `guide`/`phased`, las versiones y
las sesiones publicadas. El botón se llama **Iniciar programa** y sigue creando
el seguimiento explícito antes de permitir entrenar; no arranca una sesión.

Inicio/Hoy incorpora **Tus programas**, con acceso a las fichas de los tres
últimos programas iniciados activos (sin completar ni abandonar), mostrando la fase actual cuando
corresponda. La consulta pasa por `GuidedProgramRepository`, filtra propietario
y seguimiento activo en servidor, tiene orden estable y límite de tres, y usa
las RLS existentes. No agenda sesiones ni cambia el calendario o los ejecutores.
Se actualiza al volver a Inicio y al refrescar, incluso si el resumen principal
responde antes del siguiente frame. Un cambio de cuenta descarta respuestas
anteriores y el componente se identifica por usuario. Un fallo ofrece reintento
sin bloquear el resumen de preparaciones. El estado vacío se revisa debajo.

El paginador de Biblioteca solo aparece si hay otra página o se está más allá
de la primera. En la última página conserva el acceso de vuelta. No se añade
desplazamiento infinito.

Verificado el 18/10/2026: análisis limpios en raíz y ADMIN, 943 pruebas completas
de la app y 111 de ADMIN correctas, con sus omisiones anteriores. Regresiones
de navegación/actualización, fase, texto 2× a 320 px, paginación y consulta por
propietario con respuesta pendiente al cambiar de cuenta. Sin cambios de SQL,
dependencias o producción; queda la aceptación física de Javier.

### Tarjetas de Inicio · ajuste confirmado el 18/10/2026

En el primer ajuste Javier corrige la presentación: **Tus programas** aparece debajo de
**Preparaciones**, con tarjetas cuadradas de 250 × 250, el mismo tono de progreso,
espaciado y acabado de las tarjetas de preparación. Se recorre lateralmente en
una fila, sin apilar los programas ni añadir una lista vertical. Cada tarjeta
presenta modalidad, nombre, número de sesiones o fase actual y acceso a la ficha.

Sin seguimientos activos se muestra una tarjeta **Añadir programa**, en lugar
de ocultar la sección. La cabecera también permite **Añadir**. Ambas entradas
abren `/library?tab=programs`; Biblioteca selecciona Programas, conservando
Sesiones como entrada predeterminada del acceso habitual. No se confunde una
carga pendiente o fallida con un catálogo vacío. Se conservan consulta, límite
de tres, seguimiento, historial y ejecutores.

La revisión incluye capturas de widgets reales a 390 px, 320 px con texto 2×
y escritorio. Se comprueban tamaño cuadrado, alineación lateral, desplazamiento,
navegación, posición bajo Preparaciones y altura completa de las líneas del
nombre para evitar recorte vertical con texto ampliado.
Verificado: análisis limpio y 947 pruebas completas correctas con la omisión
web existente. ADMIN, SQL, dependencias y contratos deportivos no cambian.

### Portadas compartidas · PRG-004 · implementadas el 18/10/2026

Javier confirma reutilizar la tarjeta de Preparaciones en Inicio y Biblioteca,
retirar la composición duplicada de programas y conservar las tarjetas de
sesiones dentro de rutinas/fases. `EntrenaProgramCard`, en `entrena_ui`, contiene
la composición editorial común sobre `EntrenaCard`: fotografía, contraste,
encuadre, etiqueta, nombre, detalle y acción. Preparaciones adapta sus datos a
ese componente; `GuidedProgramCard` es únicamente el adaptador de programas,
reutilizado en el carrusel de Inicio y el catálogo paginado de Biblioteca.
El estado Añadir se conserva. PRG-006, descrito debajo, sustituye el formato
cuadrado inicial de 250 × 250 por la composición compacta de Preparaciones.

`editorialCoverProvider`, en `core/presentation/images`, conserva exactamente
la caché móvil y el proveedor web corregido que antes pertenecían a
Preparaciones. `EditorialCover`, en `workout_core`, es el valor puro compartido;
la portada es opcional y no se serializa en la prescripción versionada.
La ficha de programa utiliza el encuadre independiente de cabecera.

ADMIN reutiliza `ProgramCoverEditor` y el repositorio de portadas en
`features/editorial_covers/`, con el mismo selector/optimizador existente en
`workout_editor_ui`. El catálogo de programas ofrece **Portada** para cada
programa guardado, sin exigir crear una revisión del entrenamiento. La vista
previa usa la misma tarjeta compartida. El adaptador distingue preparación y
programa, conservando el formato de archivos, límites, rutas inmutables,
retirada, errores retenidos y control de revisión.

Migración `20261018073544_guided_program_covers.sql`, solo desarrollo:
`guided_program_covers.program_id` referencia por FK la primera versión de la
familia. Las versiones consultan la misma portada por `family_id`; modificarla
no cambia sesiones, seguimientos o resultados. El bucket existente
`program-covers-public` admite el prefijo `guided/<familia>/<identificador>/`,
con subida administrativa y limpieza que protege portadas vigentes de ambos
recursos. `set_admin_guided_program_cover` valida administrador, raíz, archivos,
pareja de formatos, encuadres y revisión esperada. Los metadatos de borradores
son administrativos; publicaciones y versiones seguidas conservan sus lecturas
bajo RLS. La app resuelve las fotos por lote de familias, no una consulta por
cada tarjeta, y mantiene las guardas de cambio de cuenta.

Las cinco baterías SQL relacionadas terminan con ROLLBACK: nueva portada por
familia, portada de Preparaciones, encuadres independientes, autoría y recorrido
guiado. Cubren permisos, conflictos, referencias a otra familia, archivos
pendientes, limpieza de imágenes vigentes, retirada y seguimiento. Los 158
identificadores de migración coinciden con desarrollo. No quedan usuarios u
objetos ficticios. El asesor solo añade el
[aviso previsto de RPC autenticada](https://supabase.com/docs/guides/database/database-linter?lint=0029_authenticated_security_definer_function_executable)
para el guardado administrativo, protegido y probado; no concede ejecución
anónima. Sin avisos de rendimiento nuevos relacionados con esta ampliación.

Análisis limpios de raíz y ADMIN; baterías completas con 949 y 118 pruebas
correctas respectivamente, conservando sus omisiones anteriores. Cubren lectura
por familia con identificadores distintos, descarte por cambio de cuenta,
portada fuera de la receta, reutilización de tarjeta y editor, guardado,
subida parcial, conflictos, sustitución y retirada de imagen.

Revisadas capturas con fotografía real a 390 px, 320 px con texto 2× y
escritorio, además de Biblioteca y su paginador. No se asignan fotografías a
las demos sin selección editorial; ADMIN permite elegirlas. Sin dependencias
nuevas ni cambios de motores, ejecutores, sesiones o producción. La aceptación
autenticada en dispositivos queda pendiente de las pruebas de Javier.

### Corrección de proporciones · PRG-006 · 18/10/2026

Javier aporta una captura de Inicio en la que la preparación es compacta y los
programas tienen un gran espacio vacío bajo el título. El componente compartido
seguía teniendo una variante `square` activada solo para programas: compartir
la clase no había unificado la presentación. Se elimina esa variante y su
dimensión fija del paquete `entrena_ui`, así como el selector correspondiente
del editor de portadas y del catálogo de ADMIN.

Preparaciones y Programas usan ahora una sola composición compacta: misma
tipografía, relleno, separación entre etiqueta/título/detalle/acción y acabado.
La altura sigue al contenido y al tamaño de texto; no hay un área expandida que
separe el título del detalle. Inicio y Biblioteca conservan los 250 px de ancho,
y el carrusel de programas alinea las tarjetas por arriba. Se mantiene debajo
de Preparaciones y conserva Añadir, navegación, portadas y encuadres. Las demos
sin fotografía asignada conservan el fondo de marca; no se les asigna una foto
para ocultar la diferencia. Sesiones y ejecutores no cambian.

Verificación: análisis limpios de raíz y ADMIN; 955 pruebas completas raíz,
118 ADMIN y seis del paquete visual correctas, con las omisiones existentes.
Se refuerzan las regresiones de Inicio y de la vista previa de ADMIN para medir
la separación real entre título y detalle, además de comprobar el tipo de widget.
Capturas revisadas con fotografía de preparación y programas sin foto a 390 px,
320 px con texto 2× y escritorio; Biblioteca y el desplazamiento conservados.
Sin SQL, cambios de datos, dependencias o producción. Aceptación móvil pendiente.

### Ancho, clasificación y búsqueda · PRG-007 · implementado el 18/10/2026

Javier valida Inicio y autoriza el resto de la propuesta, incluidas varias
categorías con una principal. `GuidedProgramCard` mantiene su ancho de 250 px en
el carrusel. Biblioteca calcula el ancho disponible: una tarjeta por fila en
móvil y dos columnas desde 640 px útiles. Se conserva la composición compacta,
las portadas y la paginación; no se incorpora otro diseño de Mi plan.

La categoría principal aparece como etiqueta junto a Rutina/Por fases; con
texto ampliado puede pasar a otra línea. La ficha muestra todas las categorías.
El filtro Categoría es independiente de estructura/iniciados y de la búsqueda;
cambiarlo vuelve a la primera página y conserva los otros criterios. Si falla
la carga de categorías, el catálogo sigue disponible y ofrece reintentar las
opciones. Inicio conserva el carrusel y su posición bajo Preparaciones.

ADMIN → Programas guiados → **Categorías** permite crear, renombrar y desactivar
categorías sin código. El creador permite seleccionar hasta ocho, marcar una
principal y crear otra desde el mismo formulario. La primera seleccionada es
principal hasta que el autor elija otra; quitarla elige una de las restantes.
Renombrar conserva el identificador. Desactivar impide nuevas asignaciones,
conserva las existentes y su búsqueda; el autor puede mantener o quitar una
categoría desactivada que ya pertenecía al programa. Los formularios conservan
los campos ante errores y bloquean el doble envío mientras guardan.

`GuidedProgramCategory`, categorías y principal pertenecen al contrato puro de
`workout_core`, pero quedan fuera del JSON deportivo, igual que la portada.
`guided_program_categories` contiene nombre, clave normalizada única, actividad
y revisión; `guided_program_category_links` relaciona cada versión con sus
categorías, con claves foráneas y una sola principal. Una revisión copia la
clasificación anterior cuando la llamada no aporta nuevas categorías. Editar
una publicación sigue creando borrador; no cambia la receta ni la clasificación
de la versión publicada. Renombrar la categoría actualiza su etiqueta común.

`save_guided_program` amplía sus parámetros opcionales con categorías/principal;
los argumentos anteriores siguen funcionando. Valida y guarda borrador,
sesiones y clasificación en la misma transacción: un fallo no deja un guardado
parcial. `save_guided_program_category` exige administrador y revisión esperada
al editar, evitando sobrescrituras silenciosas. Las tablas conceden solo lectura
al cliente; las asignaciones siguen la visibilidad de cada programa bajo RLS.
El catálogo de nombres es legible por cuentas autenticadas, incluso para
conservar etiquetas de categorías desactivadas. No hay permisos anónimos nuevos.

`library_search_text` aplica en PostgreSQL el criterio de Biblioteca: NFC,
minúsculas, sustitución de tildes y diacríticos combinados, guiones bajos como
espacios y espacios repetidos normalizados. Sesiones y Ejercicios conservan
`librarySearchText`/`matchesLibrarySearch`. El servidor busca todas las palabras
entre nombre, descripción y categorías antes de ordenar y paginar. Las tildes
se conservan en nombres y etiquetas; `%` no funciona como comodín de usuario.
Las lecturas de portadas y clasificación se resuelven por lotes en paralelo,
conservando la guarda por cambio de cuenta del resumen de Inicio.

Migración `20261018165441_guided_program_categories_and_search.sql`, solo en
desarrollo. Incluye Hipertrofia, Fuerza, Movilidad, Estiramientos, Resistencia,
Potencia e Iniciación como catálogo inicial editable. Las cinco baterías SQL de
categorías, autoría, recorrido, abandono y portadas terminan con ROLLBACK. Cubren
autorización, referencias, principal, duplicados normalizados, ediciones
concurrentes, borradores privados, atomicidad, revisión y compatibilidad de las
llamadas anteriores. Las búsquedas se contrastan con/sin tildes, texto Unicode
descompuesto, palabras de varias fuentes, filtro y páginas. Historial de 163
migraciones coincidente en la comprobación de desarrollo; sin usuarios de
prueba persistentes. El asesor solo presenta los avisos previstos de RPC
autenticadas SECURITY DEFINER, protegidas por comprobación administrativa y
grants explícitos; sin avisos de rendimiento nuevos relacionados.

Las demos de desarrollo ya muestran categorías: Empuje/tirón/pierna lleva
Hipertrofia principal y Fuerza; dominadas lleva Fuerza principal e Iniciación.
`tools/guided_programs_demo/run.ps1 -Classify` ensaya con ROLLBACK; con `-Publish`
asigna únicamente en el proyecto fijo de desarrollo y conserva clasificaciones
existentes. Se verifican ensayo, aplicación y repetición. No crea versiones ni
altera sesiones, seguimientos, cargas o resultados.

Análisis limpios de raíz y ADMIN; 965 pruebas raíz y 130 ADMIN correctas, con sus
omisiones anteriores, y seis pruebas del paquete visual. Se comprueban por HTTP
los parámetros y el guardado único, además de codec/validación, filtro, selección
múltiple, principal, creación y gestión desde ADMIN y errores retenidos.
Capturas de Biblioteca revisadas a 390 px, 320 px con texto 2× y escritorio; el
gestor administrativo y su diálogo admiten móvil estrecho con texto 2× mediante
desplazamiento. Sin dependencias nuevas, cambios de ejecutores o producción.
Queda la aceptación autenticada de Javier en dispositivos.

### Dejar un programa · PRG-005 · implementado el 18/10/2026

Javier solicita poder abandonar los programas. La ficha ofrece **Dejar programa**
con confirmación explícita. El seguimiento abandonado desaparece de Inicio y del
filtro **Programas iniciados**, que ahora solo muestra seguimientos activos,
sin completar ni abandonar. El catálogo general conserva las publicaciones.
La ficha mantiene el estado **Has dejado este programa** y permite **Volver a
iniciar programa** si esa versión sigue publicada: crea un seguimiento desde
la primera fase, conservando el anterior y sus ejecuciones. Las sesiones del
seguimiento abandonado se pueden explorar, pero no iniciar desde sus enlaces.

`guided_program_follows.abandoned_at` distingue el abandono del cierre por
cumplimiento; un CHECK impide ambos estados terminales simultáneos. El índice
único de seguimientos activos excluye ambos. `abandon_guided_program` comprueba
identidad y propietario, conserva fase, fecha de inicio y resultados, y es
idempotente por identificador de seguimiento. Reintentar un abandono antiguo
no afecta a otro seguimiento nuevo ni convierte uno completado en abandonado.
No hay permisos de escritura directa del cliente sobre los seguimientos.

Si existe una ejecución en curso, la ficha explica que debe terminarse o
abandonarse en el ejecutor antes de dejar el programa. El servidor repite esa
comprobación con el mismo bloqueo por usuario que el inicio guiado. El inicio
y el reinicio consultan únicamente el seguimiento activo; así no seleccionan
por error uno antiguo completado o abandonado. Se conservan los reintentos de
operaciones de entrenamiento anteriores y todos los contratos del ejecutor.
Un error al guardar mantiene el seguimiento visible y permite reintentar.

Migraciones `20261018111646_guided_program_abandonment.sql` y
`20261018112305_guided_program_active_catalog.sql`, aplicadas solo en desarrollo.
Las cuatro baterías SQL de abandono, recorrido, autoría y portadas terminan
con ROLLBACK. Cubren propietario, ausencia de usuario, permisos, rutina sin
entrenamientos, sesión abierta, conservación de pesos/repeticiones, fase,
reintentos, nuevo seguimiento, finalización y contenido retirado. Los 160
identificadores de migración coinciden con desarrollo.

Análisis Flutter limpio y 955 pruebas completas correctas, con la omisión web
existente. Se comprueban confirmación/cancelación y reinicio a 320 px con texto
normal y 2×, errores sin retirada optimista, pulsaciones durante el guardado,
sesión abierta y bloqueo del inicio por URL tras abandono. El adaptador interpreta
el estado de abandono, conserva las referencias a resultados y filtra antes del
límite del resumen de Inicio. El asesor añade únicamente el aviso previsto de
RPC autenticada SECURITY DEFINER, con propiedad y grants comprobados;
sin avisos de rendimiento nuevos relacionados. ADMIN, paquetes compartidos,
ejecutores y producción no cambian. Queda la aceptación autenticada de Javier
en móvil.

### Preparación de la ejecución

`start_guided_program_session` comprueba propietario, fase, sesión y descanso
permitido. Materializa una plantilla privada compatible con el contrato actual:
copia todos los campos de bloques, posiciones y series, antepone el calentamiento
seleccionado y aplica el descanso personal solo a bloques convencionales. La
pauta editorial y sus referencias no cambian. La plantilla usa origen
`algorithm` para la materialización de servidor, sin llamar al motor adaptativo
ni consumir una familia personal de Free.

El inicio usa `start_workout_execution`; omitir el calentamiento utiliza el
registro de omisión existente. Fuerza, EMOM, AMRAP y carrera conservan sus formatos,
relojes y registro. No se ha modificado el código de los ejecutores. Las series,
cierre, abandono, descarte, correcciones, avisos y cola offline siguen sus
recorridos actuales. La preparación de una sesión nueva requiere conexión.

`guided_program_follows` conserva versión y fase propias; `guided_program_runs`
enlaza operación, ajustes y ejecución. Ambas tablas tienen RLS por propietario
y solo conceden lectura al cliente. Las RPC verifican autorización en servidor.
Una operación incierta mantiene identidad y ajustes al reintentar; otra pestaña
retoma la ejecución abierta. Se sincronizan cierres pendientes antes del inicio
y se rechaza un cambio de cuenta durante esa sincronización. Al volver del
ejecutor se comprueba el estado antes de permitir otra operación nueva.

Migraciones `20261017102449_guided_program_follow_through.sql` y
`20261017105005_guided_program_read_indexes.sql`, solo desarrollo. La segunda
indexa el historial por propietario y resuelve la comprobación administrativa
una sola vez por consulta en las políticas de lectura.
La prueba instalada `guided_program_follow_through.sql` termina con ROLLBACK:
permisos, límites, reintentos, calentamiento, series reales, cierre habitual,
confirmaciones, repetición, descarte, EMOM, cierre AMRAP y tramos/ritmos de carrera.
También pasan las regresiones de autoría, sesiones oficiales, clasificación
histórica, descarte y revisión AMRAP. Las pruebas no dejan usuarios o contenido.

### Verificación y límites del recorrido

Análisis de raíz limpio, 937 pruebas completas correctas y la omisión web
existente. ADMIN conserva su análisis limpio y sus 111 pruebas correctas del
bloque 1, con su omisión existente; el bloque 2 no cambia sus archivos. Capturas
de widgets reales revisadas a 390 px, 320 px con texto doble y escritorio.
Compilación web correcta. Los 157 identificadores de migración coinciden entre
Git y desarrollo.
Los avisos de RPC autenticadas del asesor son los accesos de servidor previstos,
con propiedad/permisos comprobados; no hay concesión de ejecución anónima nueva.

El catálogo definitivo se llena desde ADMIN con contenido revisado. Por petición
de Javier se publican dos programas demo solo en desarrollo, descritos más abajo.
No añade progresión automática de cargas,
coordinación con preparaciones adaptativas, generación de agenda ni política
comercial nueva. Retirar un programa conserva seguimiento e historial; retirar
también sus sesiones puede impedir nuevas vistas previas de ese contenido.
La eficacia deportiva y la aceptación en dispositivos no quedan acreditadas
por las pruebas técnicas. Sin cambios en producción.

**Único siguiente bloque recomendado:** aceptación del recorrido en móvil con
las demos y revisión de autoría en ADMIN, incluyendo calentamiento, ajuste de descanso,
retorno/reanudación, cierre y confirmación de fase, antes de ampliar el catálogo.

### Demos publicadas para aceptación · 17/10/2026

Javier solicita dos programas sencillos para probar la app sin acceso a ADMIN.
Solo en `entrenaop-dev` se publican **Demo · Empuje, tirón y pierna**, guía
repetible de tres sesiones, y **Demo · Mejora de dominadas**, tres fases con una
sesión cada una: Base, Progreso y Consolidación. Las duraciones de dos semanas
son orientativas y el usuario confirma el avance. Se reutilizan ejercicios
públicos existentes; no se añaden movimientos ni se prescriben pesos fijos.
Ambos permiten calentamiento opcional y descanso de 60 a 180 segundos.

La carga reproducible e idempotente queda en
`tools/guided_programs_demo/`, fuera de migraciones y seeds globales, con destino
de desarrollo fijo y RPC de autoría/publicación existentes. No cambia el código
de las aplicaciones, sus ejecutores, cuentas, permisos o seguimientos reales.
Los nombres y descripciones identifican el carácter de demostración; no
acreditan revisión deportiva definitiva.

Comprobados autoría con ROLLBACK, publicación, repetición sin duplicados y
catálogo visible como deportista. La batería `verify.sql` inicia y termina las
seis sesiones, alterna calentamiento incluido/omitido, aplica descanso elegido,
conserva las sesiones fuente y confirma las tres fases; termina con ROLLBACK.
157 migraciones coincidentes; sin cambios en producción. La aceptación física
queda a cargo de las pruebas que Javier va a realizar.
