# Ejercicios privados profesionales · TRN-019 · 21/10/2026

## Colecciones de ejercicios en lote

ADMIN y Trainer llaman «Colecciones» a esta organización en la biblioteca y
en el creador de sesiones. En la carpeta de un ejercicio se pueden marcar o
desmarcar varias colecciones y crear una nueva antes de guardar. La interfaz
lee las pertenencias privadas existentes y guarda en el mismo registro por
ejercicio.

En Ejercicios, «Crear colección o añadir a una existente» activa las casillas
de las tarjetas.
La selección se conserva al buscar y filtrar dentro del catálogo. «Añadir a
colección» permite elegir una existente o escribir un nombre nuevo, conservando
las demás colecciones de cada ejercicio. ADMIN y Trainer comparten este flujo.

Se comprueba el límite de ocho colecciones por ejercicio antes de guardar. El guardado
usa las revisiones y recibos por ejercicio del servidor. Si se interrumpe,
el diálogo muestra cuántos cambios se confirmaron y permite reintentar los
pendientes con el mismo envío. Las colecciones aparecen en el filtro al
guardarse.

En Ejercicios, el menú de tres puntos junto a cada colección permite
renombrarla o eliminarla. Se actualizan todos los ejercicios accesibles de esa
colección en el contexto actual, incluidas las referencias oficiales y
privadas de Trainer aunque estén en pestañas distintas. Renombrar conserva
los miembros y requiere un nombre libre. Eliminar quita la pertenencia a esa
colección y conserva los ejercicios y sus demás colecciones. Si se interrumpe
el guardado, se muestra el avance y se pueden reintentar los envíos pendientes.

## Ficha actualizada y conservación al iniciar

Si el preparador cambia solo la descripción, la foto o el vídeo, el ejercicio
conserva su ID y la edición no consume una versión. Las pautas pendientes que
usan ese ID muestran el texto al abrir la sesión y la foto y el vídeo en
«Ver ficha». Las ediciones que también cambian nombre, tipo, músculos, material
o dificultad crean otra versión. Las pautas asociadas a una versión previa
siguen apuntando a esa versión.

Al iniciar se fijan el texto, la ruta privada de la foto y el vídeo, incluidos
los campos vacíos. Para las ejecuciones existentes se conserva la foto que
mostraban al instalar la migración. Solo el dueño de la ejecución puede
obtener la imagen histórica por ese vínculo. El control de referencias de
medios protege los archivos que usa el historial. La app del deportista
1.23.0 incorpora la consulta de la ficha pendiente y la foto congelada.

## Ejercicios oficiales y filtros compartidos

Las ejecuciones con ejercicios oficiales fijan los mismos campos que las de
ejercicios privados. En las ejecuciones anteriores se conservan el texto y el
vídeo ya guardados y se fija la foto que consultaban en el catálogo. Las pautas
pendientes leen la ficha vigente. Las fotos oficiales gestionadas conservan su
ruta pública y la limpieza protege las referencias del historial.

ADMIN y Trainer comparten el componente de filtros y sus reglas. Cada catálogo
genera las opciones con los músculos y materiales de sus ejercicios. Al
recargar tras crear o editar un ejercicio, el filtro incorpora los valores que
se hayan añadido. Cada filtro de colecciones usa las pertenencias de los
ejercicios de su catálogo.

## Filtros rápidos y nombres musculares · 12/11/2026

Las dos pestañas de Ejercicios en Trainer ofrecen filtros visibles por músculo
y material. Se combinan con el buscador y las colecciones. Los filtros se
reinician al cambiar de catálogo y la búsqueda se conserva.

Las tarjetas, fichas y selector de Trainer agrupan alias conocidos. Por ejemplo,
«pantorrillas» y «gemelo» se presentan como «gemelos», «isquios» como
«isquiotibiales» y «pectorales» como «pecho». «Sóleo» conserva su grupo propio.
El buscador de la biblioteca
admite también los alias anteriores. Esta presentación no reescribe ejercicios,
versiones ni recetas ya pautadas. El buscador tiene espacio propio tras el botón
de limpieza para que no se solape su etiqueta.

## Limpieza protegida de imágenes · TRN-046 · Dev

La eliminación definitiva encola la imagen gestionada anterior. La vista
«Archivos y almacenamiento» permite revisar imágenes sin referencias de al menos
24 horas, incluidas las abandonadas antes de existir esta cola. Todas las
versiones, papelera, borradores abiertos, recetas e instantáneas conservadas
protegen sus referencias. El trabajador elimina mediante Storage API y confirma
ausencia antes de decrementar `image_used` una sola vez. La reserva permanece como
tumba: el mismo identificador no permite volver a subir ni consumir otra cuota.
Los fallos conservan reserva y se reintentan. No se habilita DELETE de archivos
al cliente ni se exige suscripción activa para limpiar recursos propios.
[Contrato, permisos y evidencia](TRAINER_PLATFORM.md#limpieza-protegida-de-medios--trn-046).

## Colecciones y selección dentro del creador · 29/10/2026

TRN-043 conecta `catalogScope` («EntrenaOP»/«Míos») en el adaptador de Trainer,
incluidos los ejercicios creados desde la receta. El buscador común muestra
origen y foto, conserva filtros de músculos/material y permite seleccionar sin
cambiar de pantalla. La biblioteca lateral profesional usa esas mismas fotos,
un filtro de origen y las etiquetas guardadas; conserva el arrastre al bloque.
El componente de biblioteca permite aportar icono o miniatura por elemento,
reutilizado para distinguir fuerza/carrera en Trainer y en sus bibliotecas de
agenda y planificación individual.

Las colecciones son vistas de `editor_private.exercise_labels`, privadas por
cuenta y contexto. No duplican ejercicios ni cambian su clasificación oficial.
Trainer y ADMIN usan el mismo componente con recuentos, «Todos» y «Sin colección».
El botón de etiquetas de cada ejercicio permite crear una colección al asignar
su nombre; un ejercicio admite hasta ocho, según el contrato existente. No se
persisten colecciones vacías ni subcarpetas; quitar la última pertenencia hace
desaparecer la colección. Las colecciones de un entrenador no se comparten con
sus alumnos, otros entrenadores ni con el contexto administrativo de su cuenta.
También se pueden organizar referencias oficiales en Trainer: solo se guardan
metadatos personales, sin editar el catálogo. La organización sigue referida al
ID del ejercicio; las revisiones privadas conservan sus IDs inmutables.

No se añaden dependencias, migraciones, políticas ni rutas de servidor. Los
clientes conservan idempotencia y comprobación de revisión en el guardado de
etiquetas, y el servidor conserva MFA y autorización por referencia.
Verificación local: análisis limpio en raíz, Trainer y ADMIN; 1.442 pruebas de
raíz correctas (una omitida), 303 de Trainer, 317 de ADMIN (dos omitidas) y 219
del editor compartido. Incluye miniaturas y filtro de origen en la biblioteca
lateral, agrupación y vista sin colección, conservación de la receta y los
recorridos existentes de arrastre y guardado.
La comprobación de la web detectó que las preferencias se cargaban solo al
abrir el buscador. El editor las solicita también al entrar y escucha sus
cambios; agrupa las notificaciones fuera de la construcción del diálogo para
no provocar reconstrucciones durante su apertura. La regresión exige que el
filtro de colecciones esté visible sin abrir primero el buscador.

## Biblioteca visual y catálogo oficial · 29/10/2026

TRN-042 añade las vistas «Mis ejercicios» y «EntrenaOP» en el portal.
Las tarjetas muestran la fotografía existente y un icono si no hay imagen o no
se puede descargar. Al pulsar se abre una ficha con imagen ampliable, técnica,
grupos musculares, material, dificultad y vídeo bajo demanda. El botón de
edición solo aparece en ejercicios privados y conserva el guardado versionado;
alcanzar la cuota no impide consultar las fichas.

El catálogo se carga al abrir su vista, paginado de 500 en 500, exclusivamente
con `origin='system'` e `is_public=true`, bajo los permisos existentes. Fotos
oficiales usan el bucket público; las privadas conservan firmas por lotes de
quince minutos y se renuevan con «Actualizar». No se persisten URL firmadas.
La búsqueda incluye nombre, músculos y material; las etiquetas privadas solo
se muestran en la biblioteca propia. Fallar el catálogo oficial permite
reintentar y volver al contenido propio sin perderlo.

El creador de sesiones utiliza el mismo lector del catálogo y referencias
oficiales existentes, sin copiar ejercicios ni alterar cuotas, asignaciones o
versiones históricas. ADMIN y la app del deportista no cambian. No se añaden
dependencias, migraciones ni permisos. Comprobación de Dev: 73 ejercicios
oficiales publicados, uno con foto; el cambio no inventa imágenes para el resto.
Análisis de Trainer limpio y 302 pruebas correctas, incluida paginación de 501
entradas, cambio de cuenta, separación de bibliotecas, lectura con cuota agotada,
conservación de las fotos y reutilización en el selector de sesiones.

## Contrato

Javier autoriza continuar ejercicios propios reutilizando el creador de ADMIN,
incorporarlos a sesiones/programas y pautarlos a alumnos. Confirma para el piloto
500 ejercicios y 1.000 imágenes de hasta 500 KB por preparador, configurables
en servidor e independientes del cupo de alumnos y de Free/Pro personal.
Las versiones conservadas cuentan dentro de los 500 ejercicios. Las reservas
de imágenes también cuentan: una subida abandonada no permite recursos infinitos.

`ExerciseForm` ya estaba en `workout_editor_ui`; Trainer lo consume directamente,
con el mismo borrador, validación y optimización de fotos que ADMIN. No se mueve
ni copia su formulario. Los vídeos se añaden mediante URL HTTPS externa; no se
habilita la subida profesional de archivos a Bunny ni se promete privacidad del
alojamiento externo. La interfaz lo explica.

## Versiones, propiedad y permisos

`exercises.origin='coach'`, propietario obligatorio y `is_public=false` separan
el contenido profesional de los ejercicios personales y del catálogo oficial.
Una edición que cambia la definición del ejercicio crea un ID nuevo y retira
la versión anterior de la selección general. La sesión conserva el ID exacto
del ejercicio y el programa conserva el de la sesión.
El selector conserva versiones antiguas que ya formen parte de la receta editada.

La autoría requiere acceso profesional activo y MFA. Las lecturas propias
requieren MFA, aun si el acceso ha caducado. El alumno solo consulta el ejercicio
presente en una receta autorizada asignada o en su ejecución histórica. No puede
copiarlo a una sesión personal, editarlo ni consultar el resto de la biblioteca.
Tener ADMIN no concede acceso a contenido profesional ajeno. Un trigger también
cierra la inyección de IDs privados mediante escrituras heredadas de items.

`trainer_private.exercise_versions` mantiene familia, versión, operación y
payload; los reintentos idénticos devuelven el mismo ID y los distintos se
rechazan. El formulario conserva el envío tras un error incierto y permite
reintentarlo sin alterar su contenido. La identidad se comprueba antes y después
de cada operación remota.

## Imágenes y cuotas

Bucket privado `trainer-exercise-images`, JPEG y límite de 512.000 bytes.
La reserva idempotente tiene ruta `propietario/operación.jpg`. Solo su dueño con
MFA y acceso activo puede subirla; no existen permisos de sobrescritura o
borrado de estas imágenes. El alumno obtiene firma mediante acceso al recurso
asignado. Una edición conserva, sustituye con otra ruta o retira la imagen.
Las versiones y ejecuciones que referencian una foto anterior la conservan.
No se guardan firmas en SQL.

Los contadores condicionados de `exercise_limits` y el bloqueo de autoría hacen
cumplir cuotas bajo concurrencia. Cada ejercicio/version guardado consume una
unidad y su payload de reintento queda limitado a 8 KiB.
Cada reserva nueva consume una imagen; reintentar no consume otra.
TRN-046 amplía la recuperación de reservas fallidas o abandonadas mediante la
limpieza protegida descrita arriba. Los límites pueden ajustarse en servidor;
no hay interfaz de ampliación ni compra. No son tarifas comerciales.

Las firmas del portal se solicitan por lotes, sin una petición por cada foto.
Al reintentar una subida se comprueban sus bytes, sin sobrescribir ni eliminar
un objeto cuya confirmación pudiera haberse perdido.

## App del deportista y distribución

La app reconoce `ExerciseOrigin.coach` y firma la foto en el bucket profesional
cuando carga la técnica del ejercicio recibido. La biblioteca personal pide
solo catálogo público y ejercicios de origen `user` propios, aunque la identidad
también sea ADMIN/preparador. El ejecutor conserva sus instantáneas y carga la
imagen de la versión inmutable. Se reutilizan agenda, técnica, resultados e
historial; no se crea otra biblioteca vacía para usuarios sin entrenador.

El código móvil se actualiza en esta entrega. La instalación física es un hito
distinto: Windows solo detecta escritorio, Chrome y Edge el 21/10/2026; no hay
teléfono conectado. No se acredita instalación iOS/Android ni prueba humana de
dos cuentas. Producción permanece fuera del alcance.

## Referencia de Harbiz

Javier permite revisar su sesión y crear pruebas. Se contrastan creador real,
URL/imagen/sin medio, instrucciones, categorías y etiquetas; no se guarda
contenido de prueba ni se modifican clientes reales en esta revisión.
[Guía de ejercicios](https://intercom.help/harbiz-help/es/articles/10050939-como-crear-y-buscar-ejercicios-en-la-plataforma)
y [rutinas/asignación](https://intercom.help/harbiz-help/es/articles/6492199-como-crear-y-asignar-rutinas-de-entrenamiento).
Favoritos, filtros y etiquetas internas son propuestas posteriores, no funciones
presentadas como implementadas. Aprender de Harbiz no autoriza retroceder en
creadores, contratos o capacidades ya existentes de EntrenaOP.

## Verificación

Antes de publicación: catorce contratos SQL transaccionales sobre Dev con
ROLLBACK, incluido ejercicio → programa → pauta → ejecución y permisos;
69 contenciones observadas sobre PostgreSQL 17 local desechable (24 nuevas de
cuota/reintento, en READ COMMITTED y REPEATABLE READ). Baterías del deportista
y ADMIN completas correctas: 1145 raíz (una omisión previa), 301 ADMIN (dos
previas), 33 portal y seis del publicador. Seis capturas de widgets reales
revisadas, incluida pantalla estrecha y texto 2×. Análisis del alcance modificado,
portal, ADMIN y global final limpios. El primer análisis global detectó trabajo
ajeno en curso de `labs/health_read_probe`; se conservó aparte y el último análisis
global ya pasa. La compilación web Dev del deportista pasa; no se publica.
Las pruebas SQL simulan metadatos de Storage: no sustituyen
la aceptación física de dos cuentas ni el almacenamiento de un JPEG por HTTPS.

## Publicación Dev comprobada

Fuentes `cb435e288a0453283c4804a88bd9d852a49e8fd1`, subidas a main.
Versión web `cb435e288a0453283c4804a88bd9d852a49e8fd1-20261021-7`,
publicada únicamente en `public_html/trainer` de Hostinger. Se conserva el ZIP
fuera de la carpeta pública y los recursos de versiones anteriores.

- ZIP SHA-256: `4feabfb8ad901904512a41c792403ad58440e805dd871bc30705d4fedcbf7991`.
- JavaScript SHA-256: `95b38970c895053ae4f78bdb5d644db59e77b437df47194c75d850bd3db84310`.
- Verificador HTTPS correcto: revisión, hash, entrada de versión, cabeceras y
  MIME de WebAssembly.
- Dev: 185 migraciones locales/remotas coincidentes. Asesores sin avisos WARN
  nuevos de este tramo; tablas privadas con RLS y sin permisos directos.
- Chrome con la sesión existente: cinco destinos accesibles, uso 0/500 y
  0/1.000, biblioteca y formulario común completos, cero errores de consola.
  Se abre/cierra sin guardar datos ficticios. Capturas `published-library.png`
  y `published-editor.png` en `docs/visual-audit/trainer-exercises-2026-10-21/`.

No se acredita todavía una subida real de JPEG ni el recorrido humano de dos
cuentas en un teléfono. La compilación del deportista está en
`build/athlete-trainer-exercises-web/` (local, no distribuida). La publicación
web no instala la app en el móvil ni habilita producción.
