# Identidad visual de EntrenaOP

## Gesto de volver · UI-024 · 09/10/2026

Javier confirma el gesto habitual desde el borde como alternativa al botón de
volver, que se mantiene. Las consultas deben conservar scroll y selección al
regresar. Las sesiones y formularios deben respetar las opciones de salida,
los borradores y el bloqueo mientras se guarda. Javier precisa que también
Android debe ofrecer el gesto de la app, aunque use navegación de tres botones;
el gesto y botón del sistema siguen disponibles. No se acuerda un detector
horizontal global que compita con tarjetas deslizables o controles.

Implementado en la app del deportista: Android, iOS y navegador admiten deslizar
desde el borde inicial. Las consultas usan la transición interactiva de Cupertino;
si una ruta tiene `onExit`, el gesto solicita primero la salida a `go_router`
sin mover la pantalla antes de la confirmación. Cancelar conserva el contenido
y permite repetir el gesto. Los formularios con `PopScope` mantienen sus
protecciones. Android utiliza la misma transición de vuelta y conserva además
atrás del sistema; el gesto de la app no depende de los ajustes del teléfono.

La versión resuelta de `go_router` reconoce el `MaterialApp` de `material_ui`,
pero esta app usa el de Flutter. Su detección automática creaba páginas sin
transición. `materialAppRoute` define las páginas de Flutter explícitamente,
con las mismas claves, argumentos, destinos y guards. La composición fotográfica
y las pestañas no cambian. No se añaden paquetes ni se modifica el admin.

Las regresiones cubren el scroll al volver, cancelación del gesto interactivo,
formularios con/sin `PopScope`, guardado/fallo de borrador, bloqueo durante
guardado y salida/reanudación de una sesión con series confirmadas. Las rutas
reales de Disponibilidad vuelven a Perfil, incluida su URL anterior redirigida.
La primera verificación acreditó análisis limpio y 697 pruebas completas
correctas, con una omisión web existente; nueve regresiones del gesto también
correctas en Chrome. El banco web de Flutter
en Windows generó dos rutas incorrectas: CanvasKit con separadores incompatibles
y el selector de prueba con barras invertidas sin escapar. Para esa comprobación
se sirvieron los archivos locales del SDK y se normalizó el selector únicamente
en memoria del navegador aislado, sin modificar el SDK, la app ni las pruebas.
La ampliación Android ejecuta las mismas regresiones de borde para iOS y Android,
incluyendo cancelar/repetir, scroll, borradores y ocupación. También comprueba
el botón Atrás del sistema y salir/retomar una sesión con series en Android.
Análisis limpio, 51 regresiones relacionadas y 706 pruebas completas correctas,
con una omisión web existente, tras incorporar Android. El comportamiento web
conserva el mismo adaptador comprobado anteriormente en Chrome. Javier confirma
el 09/10/2026 que el gesto va muy fluido en su Android físico al ejecutar la
configuración de VS Code «EntrenaOP App · rendimiento (profile)». El tirón leve
observado en debug no se reproduce en esa prueba. Es una comprobación manual,
sin medición de tiempos de fotograma; no acredita iPhone físico ni una auditoría
de todos los recorridos autenticados. La nueva configuración
de rutas requiere hot restart para probarla. Javier continúa personalmente
la revisión pausada de preparación → Mi plan → Hoy.

UI-021, 08/10/2026: [Mi plan, elección de preparación y formularios](PLAN_COHERENCE_2026_10_08.md).
Preparaciones sustituye Tus preparaciones; sin programa, Elige una preparación.
Se conserva la identidad fotográfica y se corrigen separación/legibilidad de
campos sobre los widgets actuales. Las capturas de ese tramo usan fixtures y
no sustituyen la comprobación autenticada de portadas en dispositivo.

Mapa visual del código actual, 07/10/2026: [pantallas, estados, recorridos y
pendientes de app/admin](SCREEN_MAP_2026_10_07.md). Imágenes renderizadas desde
widgets reales con fixtures; distingue implementación, límites y propuestas.
No acredita por sí solo el recorrido autenticado en dispositivo ni cambia
decisiones deportivas o de interfaz.

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
colores de éxito, aviso, error o intensidad. Mi plan prioriza el programa con una
tarjeta acentuada y presenta la semana después; el perfil y las preparaciones usan superficies de
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
Biblioteca. Desde el cierre de Inicio/Mi plan de UI-008, el contenido disponible
y personal se gestiona en Biblioteca, sin repetir sus entradas en Mi plan.

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

## Cuenta: recuperación y confirmaciones (08/10/2026)

UI-013 reutiliza `AuthPageShell`, logotipo, colores y campos actuales. Acceso
ofrece «Olvidé mi contraseña» conservando el correo escrito. Registro y acceso
con correo pendiente llevan a «Confirma tu correo»; la solicitud de recuperación
lleva a «Revisa tu correo». Los mensajes permanecen en pantalla, con instrucciones
y reenvío visible limitado; no dependen de un aviso que desaparece.

La sesión de recuperación validada por el SDK abre «Crea una nueva contraseña».
El fallo conserva los campos, el éxito los limpia y muestra «Contraseña
actualizada». Terminar/cancelar vuelve al acceso cerrando la sesión local. Una URL
sin esa sesión no habilita el formulario y permite solicitar otro enlace.
La guarda organiza el recorrido; la autorización sigue en Supabase Auth.

Tres recorridos de captura cubren siete estados a 390/1100 px y 320 px con texto
2×, desplazable y sin errores de disposición. Son widgets reales con datos de
prueba; no acreditan correo ni dispositivo autenticados. No cambia las tarjetas,
portadas, Inicio/Mi plan, catálogo, motores ni negocio. Capturas y límites en
[REFRESH_ACCOUNT_2026_10_08.md](REFRESH_ACCOUNT_2026_10_08.md).

## Biblioteca y estabilidad de fotografías (08/10/2026)

UI-012 conserva la composición y el tratamiento fotográfico aprobado. El fallo
se reproduce en web al salir y volver a una ruta: `CachedNetworkImageProvider`
redecodifica el mismo elemento HTML, que se vacía cuando Flutter libera la imagen
anterior. Las portadas web usan ahora `NetworkImage`, con caché HTTP del navegador;
en móvil se mantiene la caché en disco. No cambian URL, encuadres, fotografías
guardadas, tarjetas ni cabeceras. La reproducción local compara ambos proveedores
con el mismo PNG y confirma cinco retornos con la imagen corregida conservada.

Biblioteca mantiene pestañas, listas y filtros. El detalle de un ejercicio con
vídeo ofrece «Ver vídeo» y «Abrir enlace original». El reproductor carga solo al
pulsar, tiene pausa/progreso y se libera al cerrar; un fallo permite reintentar y
conserva el enlace. «Editar ejercicio» solo aparece para contenido propio privado.
Abre el formulario compartido en una ruta de trabajo sin la barra inferior,
protege el borrador y presenta errores persistentes sin cubrir Guardar. Al
guardar vuelve a la colección y consulta de nuevo conservando búsqueda y filtros.
El cambio de cuenta renueva colección y editor. La creación existente se mantiene.

La fotografía personal se conserva por defecto; cambiarla o quitarla es una
decisión explícita del formulario y se guarda junto al contenido en servidor.
No se añade borrado de ejercicios vinculados a sesiones ni se modifica su
historial. Detalle, capturas actuales y límites en
[REFRESH_LIBRARY_2026_10_08.md](REFRESH_LIBRARY_2026_10_08.md).

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

### Refresco al regresar (UI-008, 07/10/2026)

Se cierra el pendiente 2 del primer tramo: Inicio, Perfil, Mi semana y la raíz
de Evolución refrescan al volver a mostrarse, desde otra sección o una tarea.
Las ramas conservan sus widgets, posición y selección; no se reinicia la barra.
La agenda conserva semana y día aunque la consulta anterior estuviera vacía.
Inicio y el historial siguen mostrando su última consulta durante el refresco.
El historial ofrece un error con reintento sin retirar resultados ya cargados.
Respuestas antiguas no sustituyen cargas más recientes ni emiten tras cerrar
los Cubits de Inicio, agenda o historial. Se evitan recargas duplicadas de los
botones que antes esperaban el retorno manualmente.

Javier reafirma que las pantallas deben navegar mediante `go_router`. Se corrigen
los retornos que aún usaban `Navigator.pop` al guardar/salir del editor de
sesiones y guardar datos de carrera. `Navigator` se conserva únicamente para
los diálogos y paneles modales; no se añaden `MaterialPageRoute` ni pilas paralelas.

Comprobación: análisis de raíz limpio y 482 pruebas completas correctas. Router
real con `StatefulShellRoute`, cambio de rama, tarea raíz y regreso, conservación
de texto/scroll, selección de semana y respuestas fuera de orden. No acredita
conexión real ni reanudación del proceso. Comparación con el informe anterior y
único siguiente tramo en `REFRESH_STATUS_2026_10_07.md`: guardado editorial admin.

### Guardado editorial (UI-008, 07/10/2026)

Se cierra el pendiente 1 del primer tramo para pruebas, calificación, tramos,
mínimos, importación y clonación; se incluye también el diálogo de vinculación
de estrategia. Todos conservan campos tras un fallo de persistencia y cierran
al confirmarse el guardado. La petición bloquea edición, foco por teclado,
salida y envíos duplicados. Cancelar sin cambios no avisa; con cambios ofrece
seguir editando o descartar, y revertir los campos elimina el aviso.

La confirmación al cambiar la medición conserva sus condiciones y el bloqueo
por módulo. Cancelar esa revisión vuelve al formulario con los valores intactos.
La importación mantiene revisión y sustitución atómica del contrato existente;
cancelar o fallar no descarta el texto. Guardar y recargar son pasos distintos:
un fallo posterior de consulta no presenta el guardado como fallido ni habilita
el mismo formulario otra vez. Clonación conserva los controles durante la
animación de cierre. Título/botón y selector de mínimos se adaptan a 320 px y
texto 2×. No se modifican las reglas del motor ni los repositorios/SQL.

Verificación: análisis de ambas apps sin incidencias; 482 pruebas completas
de raíz, 85 de admin (una captura optativa omitida) y seis de `entrena_ui`.
Pruebas con repositorios simulados, incluidos fallo/reintento de cada formulario,
doble envío/atrás, descarte y revisión cancelados, recarga posterior fallida y
pantalla estrecha. Sigue pendiente el recorrido autenticado en dispositivo.
El siguiente tramo UX es Inicio/Mi plan; los pendientes 3–7 siguen abiertos.

### Inicio/Mi plan (UI-008, 07/10/2026)

Se cierra el pendiente 3: la raíz de Mi plan prioriza programa en curso, semana
natural y pendientes. Los borradores, pausas y programas finalizados conservan
su estado y acceso, sin anunciarse como programa en curso. Las preparaciones
se gestionan desde sus tarjetas; un programa activo/revisión se abre directamente,
sin pasar por el detalle de gestión. Biblioteca conserva sesiones personales y
contenido público, y Mi semana conserva el alta de entrenamientos extra.

Inicio conserva su orden, calendario seleccionado y favoritos. Ambas raíces
comparten la tarjeta de siguiente paso y los nombres de estado. La tarjeta no
recarga por su cuenta al volver: cada raíz conserva una única frontera de
refresco. Las sesiones se consultan por fecha/ID y las ejecuciones se retoman por
ID; el resumen no inicia ni genera una prescripción de Flutter.

Análisis limpio, 505 pruebas de raíz y ocho recorridos de captura correctos.
Texto 2× comprobado a 320 × 480 y 1100 × 480; router real, errores y cambios de
identidad con repositorios simulados. Las [20 capturas actuales](REFRESH_PLAN_2026_10_07.md)
complementan el atlas inicial y no acreditan sesión autenticada en dispositivo.
No cambia SQL, admin, paquetes compartidos o motores. Pendientes 4–7 abiertos;
el único siguiente tramo UX es Evolución/Marcas e historial navegable.

### Retirada del bloque de simulación · COM-003 · 07/10/2026

Javier pide recuperar el estado anterior a `308ae18` y abordar el negocio en
un chat aparte. La reversión restaura las pantallas y recorridos de `82d74df`,
incluidos los accesos previos de Inicio y el catálogo previo al bloque. Retira
el selector temporal Free/Pro, sus guardas y la ficha básica. Las propuestas
siguientes permanecen pendientes; las maquetas descartadas no son el diseño
vigente ni autorizan sustituir las tarjetas fotográficas actuales.
Restauración contrastada con `82d74df`: código y pruebas idénticos, análisis
limpio, 505 pruebas completas correctas y compilación web debug válida.
No se modifica Supabase ni producción.

### Límite para continuar el refresh · UI-010 · 07/10/2026

Javier plantea continuar por los pendientes de fiabilidad y recorridos sin
volver a mezclar el refresh con Free/Pro. Inicio/Mi plan ya está cerrado y la
base restaurada mantiene sus tarjetas fotográficas y catálogo actuales.
El siguiente bloque recomendado era Evolución/Marcas; UI-011 implementa la
consulta de resultados e historial descrita debajo. Las mejoras comerciales de descubrimiento y ficha se desarrollarán
aparte, con derechos reales de cuenta y recorridos definidos antes de adaptar
las vistas. Las composiciones rechazadas en UI-009 y el selector retirado en
COM-002 no se recuperan como solución del refresh.

Los cambios se revisarán por un recorrido concreto y con imágenes del código
real, identificando datos simulados y límites de verificación. Una necesidad
de cambiar las áreas apartadas requiere explicar primero la ampliación del
alcance. La delimitación inicial solo modificó documentación.

### Resultados por preparación e historial consultable · UI-011 · 07/10/2026

Marcas abre resultados, conservando tema, portadas disponibles, versiones y
formularios de registro existentes. Tropa y FAS reutilizan sus tarjetas; los
resultados configurables muestran snapshot, puntos e intentos nulos. Los
controles de carrera incluyen tiempo, esfuerzo, frecuencia cardíaca, parciales
y notas cuando estén guardados. La consulta no inicia un programa.

Evolución añade un grupo plegable de filtros (preparación, fechas y estado) y
«Cargar más sesiones». El contador indica sesiones cargadas, no un total global;
la actividad reciente explicita que pertenece a la consulta visible. Un vacío
con filtros tiene su propio mensaje y se puede limpiar. Refrescar o regresar
conserva criterios y profundidad, con reintento sin perder datos. Las tarjetas
de entrenamientos permiten texto grande en pantalla estrecha sin desbordarse.
Cambiar cuenta renueva los resultados; un baremo FAS desconocido mantiene sus
marcas, sin calcular puntos con otra versión.

Análisis limpio, 537 pruebas completas y nueve capturas de recorridos correctas.
Las 22 imágenes proceden de widgets reales con datos ficticios y fuentes
legibles del runner. No equivalen a revisión autenticada en dispositivo.
[Imágenes, esquema y límites](REFRESH_EVOLUTION_2026_10_07.md).
No cambia Inicio/Mi plan, sus tarjetas fotográficas, catálogo, gestión de
preparaciones, derechos comerciales, SQL o motores. Las comparativas nuevas
siguen pendientes. El siguiente bloque UX es Biblioteca, con vídeo y gestión
de ejercicios propios, respetando autoría, versiones e historial.

### Formularios legibles · UI-017 · 08/10/2026

El tipo de nuevo programa admin y Dificultad/Medición habitual del formulario
de ejercicios muestran la selección completa en varias líneas. En poco ancho o
texto ampliado, indicación/controles de foto pasan bajo la vista previa 16:9;
en el resto siguen superpuestos. Conserva colores, imagen y encuadre, sin tocar
tarjetas o portadas de Inicio/Mi plan. Opciones y guardado mantienen sus reglas.
Análisis limpio en app/admin/paquete y 591, 91 y 8 pruebas completas correctas,
con omisiones existentes; seis recorridos y 12 imágenes revisadas.
[Imágenes, regresiones y límites](REFRESH_FORMS_2026_10_08.md).
El siguiente bloque es la comprobación autenticada de los recorridos actuales,
pendiente de sesión disponible. No cierra todo el pulido transversal.

### Tipo histórico y filtros · UI-016 · 08/10/2026

El desplegable existente del historial de Evolución añade «Tipo de entrenamiento»
entre Preparación y Estado: Todos los tipos, Carrera, Fuerza y acondicionamiento,
Mixta y Sin clasificar. La tarjeta incluye el tipo junto a la fecha. Campos con
selección en varias líneas evitan el recorte a 320 px con texto doble. Se conservan
tema, tarjetas, composición y accesos actuales.

El tipo procede de la ejecución al iniciarse, sin reclasificar el historial desde
una plantilla actual. Filtros, páginas y refresco conservan la consulta; los fallos
mantienen resultados y ofrecen reintento. Análisis limpio, 591 pruebas completas
y 25 específicas correctas (una exclusiva web omitida), tres recorridos de captura
y 15 imágenes revisadas. [Recorrido, imágenes y límites](HISTORY_SESSION_TYPE_2026_10_08.md).
El siguiente bloque es el pulido localizado de textos/estados/accesos. Comparación
configurable y recorrido autenticado global siguen pendientes; MAIL-001 ya recoge
recepción y recuperación web confirmadas. Las notas siguientes conservan el
estado del cierre original; no vuelven a abrir trabajos completados después.

### Comparación de marcas · UI-015 · 08/10/2026

Javier pide continuar Evolución. «Marcas y resultados» conserva la cabecera,
registro e historial actuales y añade un desplegable de comparación. Prueba,
origen y dos fechas preceden a las marcas y su cambio; usa `EntrenaCard`, colores
de mejora/retroceso y texto de dirección favorable. No añade puntuaciones de
progreso ni cambia composiciones de Inicio/Mi plan o fotografías.

Los selectores admiten varias líneas y muestran completo el nombre/fecha con
texto doble; origen queda bajo la prueba y la versión guardada se consulta al
tocar su información. La comparación usa valores originales compatibles,
separa controles de carrera y conserva prueba/fechas al recargar o fallar.
Cada resultado conserva expansión propia, sin compartir el estado del scroll.
Otra versión o un snapshot configurable incompleto no producen una comparación
inferida; el historial permanece consultable.

Análisis limpio, 579 pruebas completas correctas (una exclusiva web omitida)
y seis recorridos visuales, con 19 imágenes revisadas. La prueba de texto grande
comprueba altura real del párrafo/campo además de ausencia de overflow.
[Imágenes, esquema, criterio y límites](MEASUREMENT_COMPARISON_2026_10_08.md).
Filtro deportivo y comparativas configurables siguen pendientes; el siguiente
bloque es definir el dato histórico del tipo antes de implementar su filtro.
Correo real y recorrido autenticado siguen pendientes.

### Detalle administrativo por secciones · UI-014 · 08/10/2026

Javier pide continuar el refresh mientras no puede probar el correo desde el
móvil. Se adelanta el detalle admin del pendiente 7, conservando tema y controles.
Un índice fijo permite saltar a Contenido, Evaluación o Entrenamiento sin cambiar
de página ni desmontar sus secciones. La portada y publicación quedan en el primer
grupo; calificación, pruebas y baremos en el segundo; sesiones y preparación
deportiva en el tercero. Los laboratorios mantienen sus rutas separadas.

Publicado muestra «Ver baremo de la prueba», coherente con su consulta. Módulos
y cobertura de fuerza admiten reintento; el mensaje distingue pruebas ausentes
de las ya vinculadas. Acciones de edición se distribuyen en varias filas cuando
es necesario; los selectores y las acciones de fuerza admiten texto grande.
El estado desplegado de cada prueba se conserva con su propia clave.

Análisis admin limpio, 89 pruebas y seis recorridos de captura correctos;
una captura optativa existente omitida. 24 imágenes de widgets actuales en
390/1100 px y 320 px con texto doble, con tema compartido y datos ficticios.
[Imágenes, esquema y alcance](REFRESH_ADMIN_2026_10_08.md).
No modifica Inicio/Mi plan, fotos del deportista, SQL, permisos, motores, vídeos
ni Free/Pro. El recorrido real del correo, las comparativas de Evolución y el
resto del pulido transversal permanecen pendientes.

### Revisión abierta: colección, catálogo y futuro Pro · 07/10/2026

Javier mantiene «Tus preparaciones» como colección de las elegidas, pero pide
revisar cómo se descubre lo que aún no se ha añadido. Prefiere una tarjeta
«+ Añadir» naranja translúcida frente al botón del encabezado, y plantea también
mostrar preparaciones consultables antes de añadirlas. La composición definitiva
está abierta: una tarjeta al final de un carrusel fuera de pantalla no resolvería
el problema de descubrimiento. La propuesta que combinaba esa entrada con un
pequeño bloque de catálogo queda descartada por redundante. La corrección
vigente se limita a reorganizar los accesos, según UI-009, conservando el diseño
actual.

El título preferido para las calculadoras es «Herramientas». Se revisa la tarjeta
grande de Biblioteca en Inicio por duplicar la pestaña central; se recomienda
retirarla y conservar el destino propio y los favoritos opcionales. Esta revisión
todavía no modifica las pantallas ni las imágenes de los cierres anteriores.

Javier confirma la frontera: ritmos, PAEF/PAFAS, sesiones propias limitadas,
ejercicios con límite por concretar y algunas sesiones de EntrenaOP son Free.
Los programas con algoritmos de generación/adaptación son Pro. El número de
sesiones propias (dos o tres), el alcance/límite de ejercicios y las sesiones
incluidas quedan pendientes. La composición visual y la ficha informativa previa
a seguir/iniciar una preparación todavía deben confirmarse.

Pro requiere diseño comercial separado: oferta, beneficios, presentación, precios,
contratación y derechos de servidor. Los algoritmos actuales no acreditan ese
producto comercial. Las fichas y categorías distinguirán cobertura publicada de
futura, sin presentar candados o cobros como operativos antes de implementar ese
contrato. Reparto confirmado y propuestas pendientes en `PRODUCT.md`, COM-001.

### Corrección de prioridad: descubrir otro programa con acceso completo · 07/10/2026

Javier acepta la dirección visual de la primera maqueta, pero aclara que la
vista a resolver primero es la actual con programa activo y acceso completo,
futuro Pro. La futura entrada de Free no sustituye ese trabajo. El usuario debe
ver qué otros programas hay, entender por qué le interesan y empezar su
preparación desde una ficha, conservando sus preparaciones actuales.

Javier rechaza la maqueta Pro que sustituía las tarjetas actuales por una
tarjeta genérica de Mejora FAS en curso y añadía tanto «+ Añadir preparación»
como «Explora programas». La corrección explícita es reorganizar los accesos,
sin cambiar el aspecto de la app. Se conservan las tarjetas fotográficas
actuales, incluidos encuadre, estado, nombre, fecha y «Gestionar preparación»;
no se sustituyen por «Ver mi programa» ni por otro resumen genérico.

La propuesta corregida conserva las tarjetas de la captura real aportada por
Javier y deja una única entrada al catálogo dentro de «Tus preparaciones».
La tarjeta «+ Añadir preparación», antes solicitada, sustituiría el botón del
encabezado. Situarla debajo de la colección permite que sea visible sin
desplazar el carrusel; esa ubicación concreta es propuesta, no implementación.
Se elimina el bloque adicional «Explora programas». La muestra se limita a
este acceso y no propone cambios de estilo, distribución ni pantallas para el
resto de la aplicación.

Catálogo y ficha deben ofrecer descubrir/preparar para quien ya tiene acceso;
el programa actual aparece como tal y abre su recorrido. No se repite un mensaje
de compra de Pro. Se descarta el tono defensivo «Free sigue siendo útil» en
favor de comunicar capacidades y beneficios concretos.

El recorrido de catálogo debe permitir consultar otro programa, añadirlo sin
pausar el actual, revisar sus datos y ver el cambio explícito de programa activo.
Respeta STR-026/027: varias preparaciones guardadas y un generador. Al confirmar otro,
el anterior queda pausado, conserva datos/resultados y sus sesiones automáticas
pendientes sin empezar salen de la agenda. Los datos incompletos o una ejecución
en curso impiden activar. Retomar necesita revisión con fecha/contexto actuales.

La revisión de accesos sigue pendiente de implementación. No cambia Flutter,
rutas, motores, permisos o SQL. La maqueta anterior queda como exploración
descartada de composición y no acredita una cuenta con suscripción ni una
propuesta real del servidor. UI-009 y el recorrido responsable quedan
registrados en `PRODUCT.md`.
