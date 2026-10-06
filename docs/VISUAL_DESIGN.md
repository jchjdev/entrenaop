# Identidad visual de EntrenaOP

Estado contrastado: 04/10/2026. La identidad compartida está aplicada en
desarrollo a la aplicación del deportista y al panel de administración.

## Promesa visual

EntrenaOP debe sentirse deportiva, directa y enérgica sin convertir cada
pantalla en un escaparate. La interfaz prioriza la siguiente acción, reduce el
ruido y usa la marca para orientar, no para decorar indiscriminadamente.

Material 3 se conserva como base de comportamiento, accesibilidad y controles.
No define por sí solo la identidad. La aplicación obtiene colores, tipografía,
formas, botones, campos, navegación, diálogos y tarjetas convencionales desde
un único tema en `packages/entrena_ui/lib/src/entrena_theme.dart`. Ambas apps
dependen de este paquete Flutter local, sin nuevas dependencias externas.
Los archivos históricos de `lib/core/theme/` y los widgets de marca de
`lib/core/presentation/widgets/` reexportan el paquete para conservar los imports.
El paquete solo contiene presentación: no conoce Supabase, permisos,
navegación ni reglas de entrenamiento.

## Marca

- La cabecera de la aplicación usa solo el wordmark `EntrenaOP` derivado del
  logotipo entregado por Javier.
- No incluye el corredor ni el texto «Preparación física para oposiciones».
- Las variantes para fondo claro y oscuro usadas por ambas apps viven en
  `packages/entrena_ui/assets/branding/`; se cargan como recursos del paquete.
- El naranja identifica marca y acción principal; no debe ser el único medio
  para comunicar un estado.
- Los PNG actuales son recursos raster derivados de la composición completa.
  Si se dispone del original vectorial, se sustituirán conservando nombre,
  proporción y variantes para evitar cambios en las pantallas consumidoras.

### Icono de aplicación y web (06/10/2026)

Javier entrega `icono app OP.png` y autoriza las adaptaciones necesarias para
Android, iOS y web. El original se conserva sin cambios en
`assets/branding/entrenaop_app_icon.png`, pero no se usa para generar los iconos:
Javier descarta expresamente el marco blanco al comprobar el favicon.
El maestro corregido es `assets/branding/entrenaop_app_icon_full_bleed.png`:
monograma naranja OP y fondo oscuro extendido hasta los cuatro bordes y esquinas,
sin marco claro ni silueta redondeada incorporada. Las máscaras del sistema
definen las esquinas. No sustituye el wordmark de las cabeceras interiores.

Se ha usado la herramienta integrada de edición de imágenes para extender el
fondo, conservando el diseño de las letras y las diagonales. El prompt completo
queda en `assets/branding/entrenaop_app_icon_full_bleed.prompt.txt`; su criterio
es eliminar únicamente el marco y prolongar el fondo oscuro, sin rediseñar OP.

- Android: cinco densidades de icono tradicional y variante adaptable desde
  API 26, con fondo oscuro `#090A0D`. La capa de 108 dp centra
  el arte a 72 dp para conservar las letras dentro de la zona segura de 66 dp.
- iOS/iPadOS: todos los tamaños del catálogo `AppIcon`, incluido 1024 px para
  distribución. PNG RGB opacos, sin canal alfa; se conserva el catálogo y su
  referencia en Xcode.
- Web: favicon de 48 px, iconos instalables de 192/512 px y variantes maskable
  con margen adicional oscuro. El favicon lleva `v=op2` en la URL para invalidar
  el anterior. Título, nombre y colores del manifiesto identifican EntrenaOP.

`tools/generate_app_icons.ps1` reproduce los 26 PNG con System.Drawing en
Windows, sin paquetes nuevos ni modificaciones de dependencias. Ejecutar con
`powershell -File tools/generate_app_icons.ps1`. Su comprobación es
`powershell -File tools/verify_app_icons.ps1`: dimensiones, referencias,
opacidad de iOS, ausencia de píxeles blancos y letras dentro de las zonas
seguras de Android/web. Comprueba además que rechaza el marco del PNG original,
para cubrir expresamente esta regresión. La regeneración no necesita el archivo
original externo al repositorio.

Las máscaras pueden recortar el fondo o las esquinas; no deben cortar las
letras. Referencias de plataforma: [iconos adaptables de Android](https://developer.android.com/develop/ui/views/launch/icon_design_adaptive)
y [zona segura de iconos maskable](https://web.dev/articles/maskable-icon).
No se cambian identificadores, firma, algoritmos, datos ni recursos del admin.
Los recursos iOS se comprueban en Windows; la compilación y revisión en un
dispositivo iOS requieren macOS/Xcode. Los iconos nativos no se actualizan
mediante hot reload: requieren recompilar e instalar la aplicación.

Verificación de esta pasada: análisis sin incidencias, 437 pruebas de raíz
correctas y 30 referencias/tamaños de iconos comprobados. Compilaciones Android
debug y web correctas; el APK contiene iconos tradicionales y adaptable, y la
salida web conserva los cinco PNG y el enlace al favicon. Revisados visualmente
el maestro corregido y el icono web reducido, sin el marco blanco. No se instala
en dispositivos, no se compila iOS ni se publica en producción en esta tarea.

## Portadas de preparaciones: implementadas en desarrollo (06/10/2026)

Javier aprueba la maqueta del editor y recuerda que su destino es el admin web.
La disposición principal del editor es de escritorio: controles y selección de
imagen junto a la previsualización. Móvil/Escritorio cambia la tarjeta del
deportista que se previsualiza, no la plataforma en la que se administra.

Las fotografías dan identidad a preparaciones y cabeceras, no a todas las
tarjetas. El tratamiento oscuro y el contraste pertenecen al sistema visual;
nombre, fecha, estado y acciones conservan legibilidad. El admin puede subir,
sustituir o quitar una imagen y ajustar el punto de interés. Una preparación
sin imagen o con carga fallida conserva la superficie actual.

Tras probar el editor, Javier pide que tarjeta y cabecera no se arrastren entre
sí. El selector Tarjeta/Cabecera elige qué encuadre ajustar con el punto y los
controles horizontal/vertical. Se conserva una fotografía común y dos puntos
independientes; Móvil/Escritorio solo cambia la previsualización de tarjeta.
Guardar persiste ambos y volver a abrir recupera cada posición por separado.

El acceso está en Programas → detalle de una preparación → Imagen de preparación.
Subir, quitar y encuadrar son cambios locales hasta pulsar Guardar portada.
Cerrar con cambios exige confirmación; un error conserva el borrador. Un conflicto
con otra edición exige recargar, sin sobrescribirla. El editor se adapta a ventanas
estrechas, pero su distribución principal sigue siendo de escritorio.

### Almacenamiento y caché confirmados e implementados

Las fotografías se guardan en el bucket público `program-covers-public`, separado
del de ejercicios. Solo se admite contenido editorial no sensible: incluso la
imagen de un borrador es accesible si se conoce su URL. RLS exige administración
para subir y limpiar; no permite sobrescritura ni borrar una portada vigente.
`preparation_program_covers` guarda rutas, puntos de interés y revisión por programa,
no por deportista. Su lectura autenticada incluye programas publicados; un admin
también ve borradores. No contiene ni modifica reglas deportivas.

`set_admin_program_cover_v2` comprueba administración, revisión esperada, ambos encuadres,
preparación y existencia de ambos JPEG. Bloquea la preparación durante la escritura
para serializar también la primera portada. Quitar conserva una fila sin imágenes
y aumenta la revisión, evitando que una edición antigua las reponga por accidente.
`focal_x/y` se mantienen como encuadre de tarjeta; `header_focal_x/y` contienen
el de cabecera. La migración `20261006005000` inicializa la cabecera con el punto
anterior para no cambiar las portadas existentes. La RPC antigua delega en v2:
conserva la cabecera independiente de una portada existente y solo replica el
punto de tarjeta en altas de editores antiguos. No se retocan ni vuelven a subir
las imágenes al cambiar un encuadre.

El selector genera dos JPEG manteniendo la proporción: lado máximo 800 px / 180 KiB
para tarjetas y 1600 px / 500 KiB para cabeceras. No amplía imágenes pequeñas,
normaliza orientación, aplana transparencia sobre el fondo de marca y elimina
EXIF/GPS. Original recomendado: horizontal 1920×1080; límite 12 MiB / 24 megapíxeles.
No se guarda ni sirve el original. Storage limita cada archivo a 512 KiB.

Cada subida usa `official/<programa>/<versión aleatoria>/card.jpg` y `header.jpg`,
con caché HTTP de un año. Sustituir cambia las URLs, no un archivo ya cacheado.
La app usa `CachedNetworkImageProvider` existente: caché de archivos en plataformas
nativas y HTTP del navegador en web. La imagen es decorativa, no bloquea acciones
y falla silenciosamente conservando texto y superficie. No se promete conservación
permanente ni primera descarga sin conexión. Guardar no fuerza una actualización
en tiempo real: se refleja en la siguiente lectura del catálogo de preparaciones.

Los recursos de marca permanentes siguen incluidos en la aplicación. Empaquetar
todas las portadas como assets impediría que el admin cambiara por sí solo esos
archivos del paquete instalado; exigiría otra compilación/distribución. No se
propone una segunda colección de portadas hardcodeadas por preparación.

Supabase Storage dispone de [CDN](https://supabase.com/docs/guides/storage/cdn/fundamentals).
Al sustituir imágenes se crea una ruta nueva y se actualiza la
referencia, no sobrescribir un archivo servido desde caché, siguiendo su
[guía de subidas](https://supabase.com/docs/guides/storage/uploads/standard-uploads).
No se necesita contratar transformaciones en servidor: el admin optimiza al subir.
Después de guardar se intenta limpiar archivos anteriores mediante la API; un
fallo de limpieza no deshace la portada y puede dejar objetos huérfanos. No hay
recolector automático en esta pasada. Las URLs públicas antiguas pueden continuar
en cachés; retirar una portada no es un mecanismo de borrado de datos sensibles.

### Arquitectura y verificación

`ProgramCoverRepository` es un contrato de dominio del admin sin Flutter/Supabase;
su implementación realiza Storage + RPC. El editor solo controla el borrador.
`workout_editor_ui` reutiliza `image` / `image_picker` existentes para optimizar;
`entrena_ui` comparte imagen, velo y encuadre sin depender de Supabase ni de la caché.
En el deportista, el datasource resuelve rutas públicas y el modelo añade portada
opcional al programa. Inicio, selección de preparación y cabecera usan el mismo
componente; no hay consultas por tarjeta ni cambios de algoritmo.

Migraciones `20261006003000` y `20261006004000` aplicadas solo en desarrollo.
Se renumeraron únicamente sus registros ya aplicados, conservando el SQL y los
datos, para no colisionar con la nueva migración paralela de disponibilidad.
Prueba SQL transaccional con ROLLBACK: administración/deportista, lectura de
borradores, subida, rutas, foco, escritura obligatoria por RPC, conflictos y
protección/retirada de archivos. Pruebas del optimizador, transporte Storage/RPC,
modelo y editor; captura real de Flutter con fotografía de ejemplo y fuentes.
La foto de ejemplo se usa solo en la revisión local, no se sube automáticamente.
Quedan imágenes definitivas y recorrido autenticado en dispositivos; no se
despliega producción.

Verificación de esta pasada: 25 pruebas focalizadas del deportista, 67 del admin
(una captura optativa omitida en la batería normal) y 5 del editor compartido,
correctas; captura con foto ejecutada y revisada. Análisis del admin y de ambos
paquetes visuales sin incidencias; compilaciones web del deportista y admin
correctas. La batería de raíz terminó con 443 correctas y un fallo en
`training_context_page_test.dart` (selector de material «conos»). El análisis de
raíz detectó cuatro avisos en disponibilidad/preparación, fuera de esta tarea.
Son archivos en modificación paralela y no se corrigen ni se dan por validados
aquí. Las pruebas SQL terminan en ROLLBACK; no quedan portadas de prueba.

Verificación posterior de encuadres independientes (06/10/2026): migración
`20261006005000` aplicada solo en desarrollo y ambas pruebas SQL correctas con
ROLLBACK. Regresiones de selección, previsualización, guardado, reapertura,
compatibilidad con editores/catálogos antiguos, validación y conflictos. La
cabecera del deportista usa expresamente su propio punto; su prueba pasa.
Análisis de raíz y admin sin incidencias, batería completa final de raíz con 453
correctas y admin con 68 (captura optativa omitida). La regresión de cabecera
está incluida en el cierre; la captura optativa se ejecuta aparte, correcta.
Compilaciones web del deportista y admin correctas. El build del admin mantiene
el aviso de fuente Cupertino ya existente, sin impedir la compilación.
Esta comprobación posterior deja atrás el fallo/avisos de la pasada anterior.
Captura real con la foto FAS generada, seleccionando cabecera y previsualizando
escritorio; también ventana estrecha con texto ampliado.

## Superficies y tarjetas

Las tarjetas comparten una misma familia en vez de competir entre sí:

- `Card` cubre contenido convencional y hereda forma, borde y superficie del
  tema global.
- `EntrenaCardTone.neutral` presenta contenido con personalidad discreta.
- `EntrenaCardTone.accent` queda reservada para la acción o sesión principal.
- `EntrenaCardTone.progress` agrupa progreso, preparaciones y estados.
- `EntrenaCardTone.quiet` contiene información auxiliar o límites del sistema.

El pequeño trazo inclinado de las tarjetas de marca recoge la sensación de
avance del wordmark. No se añaden diagonales, gradientes ni naranja a todos los
elementos: la repetición excesiva eliminaría la jerarquía que se quiere crear.

## Criterios de aplicación

- Una pantalla debe tener una acción visual principal como máximo.
- Las acciones frecuentes pueden estar a mano, pero no todas deben competir al
  mismo nivel.
- Los objetivos táctiles mantienen al menos 48 px y el texto conserva contraste
  legible sobre las superficies oscuras.
- Los nuevos componentes usan el tema o los tokens semánticos. No introducen
  colores de marca literales salvo que el propio componente sea el responsable
  de la identidad.
- Las pantallas antiguas con colores escritos localmente se migran al tocarlas o
  por recorridos completos. No se realiza una sustitución mecánica que pueda
  borrar significados de éxito, aviso, error o intensidad.

## Despliegue visual

La portada fue la pantalla piloto: wordmark, tema global y familia de tarjetas.
El recorrido de acceso y registro comparte ahora un marco adaptable con marca,
campos, validación y jerarquía comunes. En escritorio separa presentación y
formulario; en móvil conserva una única columna y prioriza la tarea.

Plan, agenda, biblioteca, edición y ejecución de sesiones, evaluación,
evolución y perfil heredan ahora las superficies y controles comunes. Se han
retirado excepciones neutras locales, sin sustituir indiscriminadamente los
colores de éxito, aviso, error o intensidad. Mi plan prioriza la semana con una
única tarjeta acentuada; el perfil y las preparaciones usan superficies de
progreso.

Javier confirma que el admin debe compartir la identidad. Su acceso incluye el
wordmark, formulario desplazable y aviso de permisos; el panel principal usa
accesos de marca adaptables y estados de publicación con texto e icono. Los
catálogos, editores, baremos, simuladores y laboratorios reciben los mismos
campos, tarjetas, etiquetas, menús, tablas y diálogos a través del tema.
Se conserva la densidad de trabajo del admin; no se traslada la composición
promocional del acceso del deportista ni se cambian rutas o permisos.

Comprobación de esta pasada: análisis y baterías de pruebas de ambas apps,
pruebas de adaptación a 360 y 1100 px y revisión de capturas renderizadas
de Mi plan, acceso admin y panel admin a 360 y 1200 px con fuentes reales y
repositorios simulados. Esto no acredita una revisión manual de cada estado
con datos reales: las tablas extensas y las sesiones con contenido excepcional
deberán seguir revisándose al trabajar sus recorridos.

## Organización acordada del deportista (05/10/2026)

Javier aprueba la maqueta de tres situaciones y su implementación: primer
acceso, entrenamiento hoy y ausencia de sesión programada. Los datos de aquella
maqueta son ficticios; la aplicación usa ahora las sesiones reales de la agenda.
Inicio y navegación auxiliar están aplicados en desarrollo; el detalle de las
tendencias de Evolución permanece pendiente.

Inicio mantiene este orden:

1. Calendario compacto, conservando su posición superior.
2. Sesión del día o siguiente paso necesario, con la tarjeta principal de marca.
3. Tus preparaciones, conservando su papel central y sus acciones de gestión.
4. Herramientas para tus pruebas: Ritmos y PAEF/PAFAS visibles simultáneamente.
5. Biblioteca de entrenamientos, con acceso propio y menor protagonismo.
6. Favoritos personales, si el usuario los utiliza.

El calendario selecciona una fecha y la tarjeta debe describir esa fecha; al
volver a hoy recupera la sesión correspondiente. Sin sesión programada no
implica descanso prescrito. La demostración inicial de EntrenaOP no debe
presentarse como si fuera la sesión asignada al usuario. Los estados de sesión
en curso, terminada, planificación pendiente de revisión y ausencia de plan
se presentan con su propio estado y acción. Retomar abre la ejecución existente;
terminada abre su resultado. Ver una sesión pendiente abre su día y enfoca esa
sesión en la agenda, donde se conserva el inicio vinculado al programa.
Consultar Inicio no inicia una ejecución ni convierte una plantilla suelta en
sesión pautada.

Las preparaciones seguidas no equivalen a programas que generan sesiones:
mostrar activo, pausado o pendiente exige consultar el estado real. Se respeta
el programa generador único y la conservación de otras preparaciones e
historiales de STR-026/027/028; esta reorganización no cambia esas reglas.

No se incorpora un carrusel de herramientas ni rotación automática. La quinta
pestaña confirmada posteriormente en UI-003 es Biblioteca, no Herramientas.
El bloque de Inicio conserva un acceso estable a las herramientas y a la
Biblioteca; Mi plan mantiene también enlaces al contenido disponible y personal.

Los favoritos permiten elegir hasta cuatro destinos y ordenarlos. No
reorganizan los bloques de Inicio ni son el único acceso a ninguna función.
`HomeFavoritesRepository` separa el contrato de su adaptador local con
`shared_preferences`, ya disponible en el proyecto. La clave incluye la cuenta:
no comparte selección entre usuarios del dispositivo. No hay sincronización
entre dispositivos ni cambios en Supabase. Cancelar no guarda; un error al
guardar conserva la selección anterior. Una selección vacía se respeta.

Herramientas tiene un destino propio `/tools`, sin ocupar una pestaña principal;
se abre desde Inicio o Perfil y conserva el retorno al origen. Ritmos y
PAEF/PAFAS conservan sus pantallas y cálculos existentes. Crear ejercicio sigue
disponible en Biblioteca aunque se quite de favoritos. La sesión inicial de
EntrenaOP tiene un acceso opcional en Biblioteca, identificado como demostración.
Mis sesiones usa `/plan/library?tab=personal` y abre directamente la pestaña
personal, sin mezclarla con las sesiones públicas.

### Disponibilidad general: conservar y hacer útil

Hecho contrastado en código: `running_context_form_page.dart` usa la duración
general para rellenar minutos cuando no existe contexto previo; el simulador
de carrera consume días y duración. `preparation_training_page.dart` carga
disponibilidad y material del contexto del programa, sin usar las preferencias
generales para rellenar ese primer formulario. No es correcto afirmar que las
preferencias no se usan en ningún sitio.

Javier confirma conservarlas. La recomendación pendiente de concretar es
tratarlas como base del perfil para iniciar una preparación: sugerir frecuencia,
duración y material y pedir confirmación de los días concretos. Un número de
días no permite deducir lunes/miércoles/viernes. Las elecciones del programa
prevalecen sobre la base; cambiar el perfil no debe modificar silenciosamente
la semana activa ni sobrescribir preparaciones. Implementar esta relación
requiere contrastar el contrato de planificación con el trabajo del algoritmo.

Límite reafirmado por Javier en esta revisión: este chat no modifica algoritmos
ni consumidores de las preferencias. Reubicar un acceso en Perfil debe
conservar formulario, persistencia y contratos actuales; el aprovechamiento
adicional de esos datos se resolverá en el trabajo de dominio del otro chat.

La ubicación real del formulario pasa a `/profile/preferences`, con la pestaña
Perfil seleccionada. `/plan/preferences` se conserva como redirección para
enlaces anteriores. El formulario, su Cubit y repositorio no se modifican.
No se añade prellenado ni sincronización nueva con los programas.

### Evolución y evaluaciones

Se acuerda ampliar Evolución más allá del listado de sesiones: actividad real,
marcas comparables y contexto de las preparaciones del usuario. No mostrar
porcentajes inventados, prescripciones ni puntuaciones trasladadas entre
protocolos. Las tendencias deben conservar unidad, prueba y condiciones de
comparación. Se aplica una primera base: sesiones completadas y días con
entrenamiento de los últimos siete días según el historial cargado, accesos a
marcas de las preparaciones seguidas, pruebas FAS personales y otros historiales
consultables. No se presenta esta actividad como mejora física ni adherencia a
un plan. El detalle de las tendencias e indicadores sigue pendiente de diseño.

Las marcas de una preparación, la calculadora PAEF/PAFAS y el historial personal
de pruebas FAS son funciones distintas. El acceso a marcas debe nombrar la
preparación y explicar para qué se piden; no se presenta una evaluación Tropa
como requisito universal. La maqueta no cambia vigencia, baremos ni permisos.

### Verificación de esta implementación

Análisis Flutter, batería completa del deportista y pruebas específicas de
selección de fecha, sesiones pendientes/en curso/terminadas, revisión pendiente,
favoritos por cuenta, orden, cancelación, fallo al guardar, redirección de
disponibilidad y pestaña personal de Biblioteca. Pruebas de adaptación a 320 y
1100 px y con texto ampliado al doble. Revisión de capturas de Flutter con
fuentes e iconos reales para primer acceso, sesión de hoy, día sin sesión y
escritorio, con repositorios simulados. No acredita una revisión con cuentas
reales ni añade validación de algoritmos, base de datos o producción.

## Biblioteca central (05/10/2026)

Javier confirma la variante «Por contenido»: la navegación queda como Inicio,
Mi plan, **Biblioteca**, Evolución y Perfil. En móvil Biblioteca es el tercer
icono, con la misma jerarquía que los otros destinos; no es un botón global de
creación. En escritorio ocupa el mismo orden en la navegación lateral.

La portada `/library` presenta dos secciones, Sesiones y Ejercicios. Cada una
separa el catálogo EntrenaOP de la colección del usuario. Solo sesiones EntrenaOP
lleva la acción principal acentuada; las tarjetas personales mantienen botones
visibles «Ver los míos» y «Crear sesión» / «Crear ejercicio», con disposición
vertical cuando el ancho o la escala de texto lo requieren. En escritorio las
tarjetas de cada sección comparten fila. No se añaden calculadoras, baremos,
agenda ni prescripciones a este centro de contenido.

Se reutilizan el selector de fuerza/carrera y los editores existentes. Guardar
desde una tarjeta personal abre su colección. El nuevo acceso al creador de
ejercicios devuelve el identificador al guardar; el acceso anterior
`/exercises/new` conserva el formulario abierto para creación consecutiva.

`/library/exercises` abre el catálogo y `?tab=personal` abre Mis ejercicios.
`ExerciseLibraryCubit` carga mediante `GetExercisesUseCase`, que conserva el
repositorio y adaptador actuales. La presentación distingue ejercicios públicos
de origen sistema y ejercicios de origen usuario cuyo autor es la cuenta actual.
No etiqueta contenido público ajeno como EntrenaOP ni como propio. Esta selección
no sustituye la autorización de servidor: no se cambian consultas, RLS ni datos.
El controlador se renueva al cambiar la identidad y descarta lecturas anteriores
o posteriores a su cierre. La pantalla ofrece carga, vacío, reintento, consulta de
detalle y recarga después de crear.

Los enlaces `/plan/library`, su pestaña personal, sus editores, detalles y
ejecuciones, y `/plan/starter-session` conservan sus URLs por compatibilidad,
pero ahora pertenecen a la rama de Biblioteca. Volver a pulsar el destino activo
recupera la portada. Inicio y el favorito Biblioteca llevan a `/library`; el
favorito Mis sesiones continúa abriendo directamente su colección. La
demostración no se convierte en la sesión prescrita del día.

No se modifican algoritmos ni reglas deportivas, contratos de sesión o
ejercicio, persistencia, permisos, dependencias ni el admin. Se mantiene la
separación entre dominio, datos y presentación, reafirmada por Javier.

Verificación: análisis y batería completa de la raíz; pruebas de los cinco
destinos, enlaces de sesiones anteriores, colecciones públicas/personales,
creador real de ejercicios y retorno a su lista, reintentos, aislamiento entre
cuentas, y adaptación a 320/1100 px con texto ampliado. Las pruebas usan
repositorios simulados; no acreditan catálogo remoto ni producción. Revisadas
también capturas de Flutter con fuentes e iconos reales: portada a 320/390 y
1100 px, catálogo de ejercicios y colección personal. Las 423 pruebas de la
raíz pasan en esta comprobación; el análisis no presenta incidencias.

### Búsqueda y filtros de Biblioteca (05/10/2026)

Javier solicita buscadores y filtros en ambas bibliotecas. El campo de búsqueda
permanece visible y los criterios adicionales se despliegan con «Filtros».
Se muestra el número de resultados sobre el total de la colección, cuántos
filtros están activos y una acción para limpiar texto y criterios. Un resultado
vacío por filtros no se presenta como un catálogo sin contenido.

- Sesiones: nombre/descripción, tipo Carrera o Fuerza y acondicionamiento y
  duración estimada (<30, 30–45, >45 minutos). Las sesiones sin duración conocida
  no pasan un filtro temporal; no se inventa ese dato. El resumen actual solo
  aporta `isRunning`, no los formatos de bloques, por lo que no se ofrecen
  todavía filtros Circuito/EMOM/Superserie. El acceso auxiliar de demostración
  se reserva para la vista sin búsqueda y no se cuenta como otro resultado.
- Ejercicios: nombre/descripción y etiquetas de grupo muscular/material en la
  búsqueda; filtros por grupo muscular, tipo/medición, material y dificultad.
  Sus opciones salen de la colección ya autorizada, no de categorías inventadas.
  `exerciseType` puede describir medición (repeticiones/tiempo), por lo que no se
  confunde siempre con una disciplina deportiva.

Los criterios se combinan con AND; el texto ignora tildes, mayúsculas y espacios
sobrantes. Cada pestaña conserva sus propios criterios durante la visita, sin
aplicarlos a otra colección. Guardar contenido desde un listado limpia los
criterios de la colección personal para que el nuevo elemento no quede oculto.
No se guardan filtros en preferencias ni se envían consultas por cada letra.

La selección es presentación pura sobre las entidades ya cargadas mediante
Cubit → caso de uso → repositorio. `LibrarySearchControls` comparte únicamente
controles visuales; los filtros de sesiones/ejercicios son helpers de
presentación sin Flutter ni acceso a datos. No cambian dominio, SQL, RLS,
algoritmos, clasificación ni datos guardados. La rejilla de sesiones adapta su
altura y las acciones al texto ampliado; los campos se apilan en móvil.

Regresiones de búsqueda sin tildes, límites de duración, combinación de filtros,
origen, cambio de pestaña, limpieza y retorno del creador, sin nuevas lecturas
por filtrado. Adaptación a 320 px con escala de texto 2×; análisis y batería
completa de raíz. Las verificaciones usan repositorios simulados.
Revisadas capturas reales de Flutter con fuentes e iconos cargados y filtros
abiertos/cerrados. Esta pasada termina con 433 pruebas de raíz correctas y
análisis sin incidencias; no acredita datos reales de producción.

### Consulta y pantallas dedicadas (UI-007, 06/10/2026)

Javier confirma el criterio observado en su vídeo: consulta con navegación de
secciones; configurar o entrenar en una pantalla dedicada. Cambiar de sección
conserva su pantalla y posición; pulsar el destino activo vuelve a su raíz.
No se sustituye ese comportamiento por un reinicio general de pestañas.

Configuración del programa y su contexto, registro de marcas, creación de
ejercicios, editores de sesiones y ejecutor usan el navegador raíz. No muestran
barra inferior ni rail, conservando sus enlaces y el retorno a la colección o
preparación correspondiente. La configuración usa el mismo material/días en
Perfil y «Mi programa», con selector y retirada efectivos. El pie del bloque
de carrera ofrece «Continuar con el programa» como botón principal.

Las salidas se tratan según el estado real:

- Formulario: si no cambia nada o ya se guardó, vuelve; si hay cambios pendientes,
  ofrece «Seguir aquí» o «Salir sin guardar».
- Editor: guarda el borrador válido antes de salir y mantiene la recuperación
  existente. Si los campos incompletos impiden guardarlo, avisa del descarte de
  esos cambios; un fallo de almacenamiento mantiene al usuario en el editor.
- Sesión: «Salir y retomar después» conserva las series confirmadas y no llama
  a abandonar/finalizar. Los campos sin confirmar no se registran. La acción de
  abandonar conserva su cierre explícito independiente.

El guard de `GoRoute.onExit` también intercepta cambios de ubicación, sin
poner un aviso de pérdida genérico en todas las pantallas. No se afirma que
intercepte el cierre del navegador/proceso. Los formularios de evaluación
oficial existentes quedaron fuera de UI-007; se incorporan en UI-008.

Regresiones: navegación de pestañas móvil/escritorio, rutas reales fuera de
barra, cancelar salida conservando campos, guardar borrador antes de navegar,
crear y guardar sin aviso falso, salir/retomar conservando series. Los tests
utilizan repositorios simulados; la igualdad y permisos del contexto se
comprueban además mediante fixtures SQL contra desarrollo con `ROLLBACK`.

### Refresh de fiabilidad y claridad (UI-008, 06/10/2026)

Javier aprueba el informe general y reafirma la separación entre estado de
interfaz y dominio. Se mantiene la identidad actual, el calendario arriba,
Tus preparaciones y Biblioteca como tercer destino. No se modifica el motor.

Primer tramo implementado y verificado:

- Admin utiliza rutas `go_router` para programas, sesiones, ejercicios,
  simulación, baremos y laboratorio. Las URLs contienen IDs y se pueden
  resolver sin haber visitado el listado. Errores de acceso o recurso ausente
  ofrecen salida y los errores de carga ofrecen reintento. Cambiar el ID renueva
  la lectura y evita enseñar un programa anterior con una URL distinta.
- Tropa, evaluación periódica FAS y evaluación de programa se abren sin barra
  y protegen campos pendientes mediante el mismo guard de salida de UI-007.
  No se permite editar o salir mientras se guarda; un guardado confirmado
  elimina el aviso de descarte, sin borrar los resultados anteriores.
- El formulario de referencia conserva datos y muestra error hasta confirmar
  `saveReference`. Admin hace lo mismo al crear un programa y crear/editar
  ejercicios. El componente visual compartido no conoce repositorios y evita
  doble envío o cierre por atrás durante la petición.
- Evaluación de programa distingue persistencia de recarga: si el historial
  falla después del guardado, mantiene «Guardado en esta preparación» y no
  habilita un segundo envío del mismo formulario.
- Al cerrar una sesión, «Volver» recupera el origen de la pila; una entrada
  directa ofrece Mi semana. «Ver resultado» abre la ejecución concreta en
  Evolución. Mientras haya operaciones de sincronización pendientes, ese acceso
  permanece deshabilitado para no abrir un resultado aún ausente en servidor.
  Tanto finalización como abandono admiten scroll, notas largas y texto 2×.
- Admin tiene búsqueda de programas por nombre/tipo/estado, sesiones por
  nombre/carrera/fuerza y ejercicios por nombre/grupo/material/tipo. Ignora
  tildes y combina términos; la recarga del listado mantiene búsqueda y filtro.
  El laboratorio tiene una página separada. Títulos y acciones de pruebas y
  tramos pueden ocupar varias filas; carga de regla, sesión y baremo ofrece
  reintento y la simulación explica una regla ausente o no cargada.

Pendientes expresamente aprobados, todavía no implementados en este tramo:

1. Extender guardado retenido a formularios editoriales de pruebas, reglas,
   tramos, mínimos, importación y clonación; revisar salida de cada diálogo.
2. Refresco coordinado de Inicio, Perfil, agenda y Evolución al cambiar datos,
   sin reiniciar ramas ni perder selección/filtros/posición.
3. Mi plan centrado en programa en curso, semana y pendientes; retirar accesos
   redundantes que ya corresponden a Biblioteca y simplificar intermediarios.
4. «Marcas» por preparación debe abrir resultados y controles, no gestión.
   Evolución separará actividad de mediciones, con filtros por preparación,
   fechas/tipo y consulta de entrenamientos antiguos. Solo habrá comparaciones
   cuando protocolo, contexto y datos las permitan, nunca porcentajes ficticios.
5. Biblioteca: consulta útil de vídeo, gestión de ejercicios propios y etiquetas
   más coherentes conservando los contratos, autoría e historial existentes.
6. Mensajes persistentes y siguientes pasos de confirmación/recuperación de
   cuenta. Se revisarán los contratos y redirecciones de Supabase antes de
   ampliar autenticación; no se cambiará seguridad ni producción a ciegas.
7. Limpieza transversal de terminología, contraste, botones y formularios densos;
   detalle admin dividido en secciones reconocibles.

Este avance no acredita el cierre de todo el refresh ni de los pendientes
deportivos. No cambia SQL, políticas de acceso, datos reales o producción.

Verificación del primer tramo el 06/10/2026: análisis limpio en ambas apps,
474 pruebas de raíz, 74 del admin (una omitida por su condición existente) y
cinco de `entrena_ui`; ambas compilaciones web correctas. Las regresiones
comprueban fallo/reintento sin perder campos, doble envío, descarte cancelado,
retorno por router, pérdida de autenticación, URL directa sin permiso e identidad
del recurso al cambiar el ID. El cierre se prueba a 320 × 480 con texto 2× y
notas largas. Se utilizan repositorios simulados: no acredita el recorrido
autenticado en el dispositivo de Javier ni el cierre del navegador/proceso.
No se han ejecutado pruebas SQL nuevas porque no cambia ese contrato.
