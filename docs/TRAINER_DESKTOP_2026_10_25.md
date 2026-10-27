# Escritorio profesional · TRN-030 · 25/10/2026

## Acuerdo y alcance

Javier aprueba implementar en Trainer y ADMIN la propuesta de escritorio y sus
recorridos, con arrastrar y soltar y componentes compartidos. Se conserva Flutter,
el creador único y los adaptadores de autoría. Los portales y sus permisos siguen
separados; no existe un selector que conceda acceso de uno al otro. El selector
del prototipo solo servía para explorar ambos diseños.

Firebase, recepción push y cobros reales continúan pospuestos. Los datos,
ventanas y estados ficticios del prototipo no son contratos nuevos ni funciones
que puedan darse por implementadas en el producto.

El trabajo se realiza sin agentes ni coordinación con otros chats, sobre main,
preservando cambios existentes. La publicación se limita a Dev y requiere
validación y comprobación de la versión servida.

## Composición y comportamiento

- Marco de escritorio, navegación y distribución reutilizables en `entrena_ui`.
  Cada consumidor aporta destinos y comprobaciones. La navegación por teclado,
  semántica y tamaño de ventana también forman parte del recorrido.
- Las pantallas de gestión ocupan el área disponible mediante listas, rejillas
  y paneles complementarios. Acceso, TOTP y formularios cortos conservan una
  anchura cómoda; no se estiran sus campos por el mero tamaño del monitor.
- La ficha del alumno reúne planificación, resultados, técnica, evolución,
  formularios, conversación, notas privadas e historial mediante URLs
  recuperables. Una pestaña no omite los guards de trabajo sin guardar.
- El creador común mantiene catálogo, composición y propiedades accesibles en
  escritorio sin duplicar modelos ni controladores. Carrera conserva sus bloques
  y recuperaciones; fuerza conserva identidad, variantes y series.
- Los arrastres del editor modifican el borrador; los de calendario preparan una
  intención que reutiliza previsualización y confirmación existentes. Ningún
  arrastre aplica una asignación sin revisión ni confirma por su cuenta un cambio
  de fecha, destinatario o receta.
- Las fases y posiciones de programa conservan sus UUID, referencias y trabajos
  hijos. No se pierden checkpoints o enlaces pendientes al reordenar.
- Las pautas compartidas del otro preparador son de solo lectura. Ver el
  calendario de un alumno no permite acceder a otras carteras ni editar su autoría.
- Se conserva una alternativa mediante botones/teclado para los gestos de
  arrastre. Una operación ocupada, incierta o desautorizada impide otro envío.

## Implementación y evidencia

Estado: implementado, validado y publicado en ambos portales Dev;
revisión final compartida `6fe1d35c5e17bbd2ad4641fe0563a8a7949db27b`.
Pasada visual actual completada; aceptación humana del recorrido pendiente.
Las publicaciones anteriores quedan debajo como evidencia histórica.

- [x] Marco y distribución comunes; catálogos y gestión en ambos portales.
- [x] Ficha profesional y accesos visibles a conversación, técnica e informes.
- [x] Creadores compartidos de fuerza/carrera y programas con sus arrastres.
- [x] Agenda y biblioteca contextual con asignación y movimiento revisados.
- [x] Revisión del resto de pantallas y diálogos, ventana estrecha y texto ampliado.
- [x] Análisis, regresiones, baterías de consumidores, compilación y publicación Dev.

Los guards, modelos y RPC existentes son la fuente de verdad. Si una integración
necesita ampliar su contrato o servidor se explicará antes y se añadirá su prueba
SQL transaccional. No se ensancha RLS para facilitar una interfaz.

## Verificación prevista

Raíz, ADMIN y Trainer: análisis y baterías completas al cerrar la entrega.
`workout_editor_ui` y los nuevos componentes comunes: pruebas de interacción
relevantes. Se comprueban arrastre con cancelación/confirmación, identidad y
conservación de campos, navegación con trabajo pendiente, solo lectura de pautas
compartidas y composición en escritorio/ventana estrecha. Se verifica publicación
por revisión, entorno, archivos y HTTPS; recepción push, pagos e instalación iOS
no forman parte de esta aceptación.

## Verificación local completada · 25/10/2026

- Análisis sin incidencias en raíz, ADMIN, Trainer, `workout_editor_ui` y
  `entrena_ui`; formato y diff comprobados.
- 1.349 pruebas del deportista, una omisión previa; 315 de ADMIN, dos omisiones
  previas; 205 de Trainer; 217 del editor compartido y 27 de interfaz común.
- Compilaciones web Release de ambos portales con CSP, recursos locales,
  sin mapas de fuentes y configuración exclusiva de Dev.
- Siete pruebas del paquete Trainer y 36 de publicación/operaciones de ADMIN.
  No hay cambios de dependencias, esquema, migraciones ni configuración push.
- Gestos de ratón reales en pruebas: cancelar un arrastre conserva la receta;
  añadir ejercicio conserva dosis anterior y espera guardado; fases y sesiones
  se componen desde el catálogo; soltar en agenda abre elección y revisión;
  cancelar no asigna. Mover fecha pasa por el callback de revisión existente.
- Las pestañas conservan controladores/notas y el guard impide abandonarlos
  sin decidir. El scroll de biblioteca y el del editor son independientes.
  Cambiar a ventana estrecha conserva el editor embebido montado.
- Capturas de widgets reales con datos de ensayo, revisadas a 1.920×1.100:
  `trainer_app/build/performance_v2_review/trainer-desktop-{library,program,agenda}.png`.
  Son evidencia local de presentación; no se publican clientes ficticios.

## Límites de esta entrega

Las búsquedas y filtros identifican el catálogo o alumnos ya cargados y conservan
la paginación. La semana tiene desplazamiento horizontal cuando siete columnas
legibles no caben. En ventana estrecha y con texto ampliado continúan los botones
alternativos y el flujo vertical. Los metadatos del programa se despliegan a
petición en escritorio. Las sesiones con enlaces pendientes no se trasladan entre
fases; se resuelve primero su guardado, conservando los trabajos hijos.

Conversaciones e informes son accesos a los alumnos autorizados y al historial
del servicio, no una bandeja nueva con contadores de mensajes inventados. Las
fichas y conversaciones se identifican por cuenta y recurso para no reutilizar
el estado de otro alumno. La evolución se carga al entrar en su área, sin
consultarla también al abrir solo notas o etapas.

Los permisos y la autoría son los existentes. El calendario compartido sigue
siendo de lectura respecto a otro preparador. No se crean cobros, avisos push,
notificaciones simuladas ni cambios de cuotas a través de la interfaz. La
aceptación humana del recorrido publicado queda para Javier.

### Revisión de accesibilidad tras publicar el primer paquete

La comprobación real con la sesión Dev detectó que el `Navigator` ocultaba en
semántica las pestañas pintadas antes, aunque funcionaban visualmente. El marco
común y la navegación de alumno pintan ahora primero la ruta y después su
cabecera, con el mismo orden visual. Se añaden regresiones de recorrido semántico
para las ocho áreas y las acciones del marco. La revisión `527f2c5d` publicada
en Trainer acredita también esta corrección; la primera fue `a2162024`.

## Primera publicación y recorrido comprobado · 25/10/2026

Trainer Dev sirve la revisión `527f2c5d067d3f444d2cf0497eb55214e21ad74c`,
publicación `527f2c5d067d3f444d2cf0497eb55214e21ad74c-20261025-1`.
El publicador contrasta manifiesto, entrada, SHA-256 del JavaScript, cabeceras
de acceso y MIME de WebAssembly por HTTPS. ZIP:
`450aa3ebc91e78498fc5f786376ff75c817edb41e89c4845467f0d3db7563394`.
Los recursos se copiaron completos antes de activar entrada y manifiesto;
se conservan las publicaciones anteriores.

Con la sesión profesional Dev existente se comprobó el catálogo de sesiones,
la revisión de una receta y la ficha real del alumno: ocho áreas accesibles,
planificación en rejilla, resultados filtrados, conversación dentro de la ficha
y evolución cargada en su pestaña. Estas comprobaciones no asignaron sesiones,
no guardaron recetas ni enviaron mensajes. También se arrastró una sesión de
la biblioteca a un día de la semana en Chrome: abrió la elección de alumno,
con revisión deshabilitada hasta elegirlo; cancelar volvió a la agenda sin
asignar. Las demás variantes se ensayaron en las pruebas de widgets; queda la
aceptación humana del trabajo real publicado.

ADMIN Dev sirve la misma revisión de fuentes, publicación
`527f2c5d067d3f444d2cf0497eb55214e21ad74c-40186938110-1`. El run
`40186938110` terminó correctamente: validación, publicación y retención de
paquetes. Se repitió la verificación HTTPS del manifiesto, entrada, cabeceras,
WebAssembly y JavaScript; SHA-256:
`2a7a6a8988a7bbcaa637051aef218880662d4761cc67324d3cce25c583d6efe3`.
El primer intento `40185961549` había restaurado la publicación anterior al
fallar su comprobación; no se tomó ese intento por entrega. El paquete local
de contingencia no se activó: la publicación final de ADMIN procede de CI.
Con la sesión administrativa existente se comprobó la carga de Pendientes y
la navegación al catálogo de programas guiados, con rejilla, cabecera y
barra lateral accesibles. No se editó ni publicó contenido durante la revisión.

Los cambios ajenos de `.gitignore` y `devtools_options.yaml` se conservan sin
incluirlos en esta entrega. Sin modificaciones de datos, permisos, cuotas,
dependencias ni migraciones.

Siguiente recorrido único: aceptación con Javier de crear/reordenar una receta,
componer un programa, revisar una asignación desde agenda y consultar resultado,
técnica y notas en los portales publicados. Push y cobros continúan fuera de este
bloque; no se acredita recepción física ni instalación iOS.

## Ajuste visual solicitado tras probar la publicación

Javier señala que la primera entrega reproduce la estructura pero todavía no
el acabado de la preview. Se aproxima la apariencia profesional mediante un
tema de escritorio compartido: superficies planas sin el adorno de las tarjetas
táctiles, radios menores, títulos y acciones ligeros, navegación por grupos y
pestañas subrayadas. Biblioteca y detalle reservan menos ancho; la semana
ajusta el mínimo de columna al texto para mostrar más días sin recortar datos.
El tema solo se aplica desde el marco profesional y sus editores. El cambio a
ventana estrecha conserva el editor y recupera las medidas táctiles. No cambian
permisos, rutas, guardados, operaciones de agenda ni estados del servicio.

Estado de esta revisión: publicada y verificada en ambos portales Dev.
Análisis limpios de raíz, Trainer, ADMIN e interfaz común. Baterías: 1.349,
205, 315 y 27 pruebas respectivamente (omisiones previas sin cambios). Se
mantienen las regresiones de arrastre, cancelación, semántica y controladores
al redimensionar. Capturas actualizadas de widgets reales con fuente cargada,
sin datos personales ni imágenes del prototipo usadas como interfaz.

La comprobación en Chrome detecta además cabecera y accesos heredados de móvil
duplicados en Alumnos. En escritorio se elimina ese segundo logo y el atajo de
sesiones ya disponible en la navegación; se conserva Actualizar en la cabecera
de página y Cerrar sesión en Mi cuenta. El estado de acceso activo utiliza una
superficie discreta. La ventana estrecha conserva sus accesos anteriores.
Análisis Trainer limpio y 205 pruebas correctas tras este ajuste localizado.

### Publicación comprobada del ajuste visual · 25/10/2026

ADMIN: fuentes `e57c55ac3d131f984600d2afb66bed0a45b81463`, publicación
`e57c55ac3d131f984600d2afb66bed0a45b81463-40188943836-1`. El run
`40188943836` completa validación, despliegue y retención con éxito. HTTPS
contrasta manifiesto, entrada, cabeceras, WebAssembly y SHA-256 de JavaScript:
`7e9b4b01f36449aabb5ef76ab6da95c3ff1af6f4c93003f2207f7aa7623fc49d`.
El catálogo real de programas carga con navegación y acciones accesibles.

Trainer: fuentes `007d7f3ba9684d57440294a1b5d575b18b62809c`, publicación
`007d7f3ba9684d57440294a1b5d575b18b62809c-20261025-1`. Mismas comprobaciones
HTTPS; SHA-256 JavaScript
`7c83cfe248b54d20b564ae8e6fba89cb832a3092e8fdcbf047c081f72ad0038e`.
ZIP `0a7781c6b2cebde884e6fe796458a3985a7151b02a6fe4f88c386f0f7007e41c`.
La limpieza propia de Trainer no cambia los componentes ya publicados en ADMIN;
se sube a main después de terminar el despliegue administrativo.

Chrome acredita las tarjetas y pestañas reales de alumno, el tablero con los
siete días visibles a 1.646 px y la página Alumnos sin logo/atajos duplicados,
con Actualizar e invitaciones disponibles. No se guardan recetas ni pautas ni
se envían mensajes. La revisión visual aproxima la preview; no supone aceptar
por Javier cada detalle estético ni cerrar futuras mejoras de fluidez.


## Revisión completa de pantallas y creadores · 25/10/2026

La primera entrega y su ajuste de tema no completaban el parecido funcional con
la preview en los creadores. Esta revisión cambia la composición real, usando los
mismos adaptadores de ADMIN y Trainer, sin copiar formularios ni recetas.

| Área revisada | Composición y comportamiento |
| --- | --- |
| Inicio, alumnos e invitaciones | Resumen de trabajo, cartera en tarjetas y detalle por áreas; invitaciones separadas. |
| Agenda | Biblioteca contextual; mes/semana/día/lista, filtros y revisión antes de asignar o mover. |
| Sesiones de fuerza | Biblioteca, lienzo compacto ordenable y propiedades de la posición seleccionada; configuración del bloque desplegable. |
| Sesiones de carrera | Biblioteca de tramos, lienzo ordenable y propiedades/repeticiones/recuperación en el lateral. |
| Programas | Biblioteca, fases configurables, sesiones resumidas y estructura; guardado fijo y validación que revela campos plegados. |
| Ejercicios | Tarjetas con etiquetas, búsqueda de ancho legible y creador compartido con medios/ficha en dos columnas. |
| Formularios y pruebas | Tarjetas de catálogo; preguntas y protocolos en columnas, acciones de guardado fijas. |
| Revisiones | Tarjetas de resultados con acceso a la consulta existente. |
| Grupos, envíos y semanas | Distribución adaptable; conserva destinatarios, previsualización y confirmación. |
| Vídeos | Demostraciones separadas de técnica de alumnos, límites desplegables y recuperación existente. |
| Conversaciones e informes | Directorios de alumnos autorizados en tarjetas; escritura fija al pie e historial con burbujas de ancho legible. |
| Cuenta y herramientas | Acceso profesional y seguridad separados; calculadora flotante y sesión existentes. |
| ADMIN | El mismo editor de sesión/programa/ejercicio y sus estados oficiales, más los catálogos y gestión existentes. |

La batería de revisión recorre las 15 secciones de Trainer, cinco pantallas de
edición y el diálogo de ejercicio con el marco real a 1.600×1.000; genera 21 capturas optativas de widgets reales. Los
datos son fixtures de prueba: no se publican clientes ficticios. Las regresiones
comprueban selección de ejercicio, dosis, cambio de ancho, orden, fases plegadas,
validación, guardado y reintento incierto en conversación. Los tests de ADMIN
abren explícitamente «Ver contenido» en escritorio y siguen comprobando receta,
versiones, lecturas, publicación conjunta y ausencia de duplicados.

No cambia esquema, permisos, cuotas, dependencias ni la presentación móvil del
deportista. El cierre de esta pasada visual se distingue de la aceptación humana
y de los cobros/push pendientes. Publicación y comprobación de revisión final se
registran al terminar la validación.


Validación local de esta revisión: análisis limpio en raíz, ADMIN, Trainer,
`workout_editor_ui` y `entrena_ui`; 1.349 pruebas raíz (una omisión previa), 315
ADMIN (dos omisiones previas), 207 Trainer, 218 editor y 28 interfaz común.
La selección lateral, validación de fases plegadas y reintento en conversación
tienen regresiones explícitas. Tras ordenar los campos del formulario de
ejercicio se repiten sus ocho pruebas, correctas. Diff y archivos nuevos revisados;
los cambios previos de configuración local quedan fuera del guardado.


### Ajuste tras comprobar ADMIN con datos reales

La revisión `6b0fe679ff47463559890debf114dc8b09dcf524` se publica y verifica
por HTTPS en ambos portales: Trainer `-20261025-1` y ADMIN run `40195158619`,
con validación, despliegue y retención correctos. Chrome acredita los editores
de sesión, programa y ejercicio con la cuenta real, sin guardar recetas/pautas.

Esa comprobación detecta que las categorías oficiales dejan las sesiones demasiado
abajo. En escritorio se pliega la clasificación conservando categorías/principal,
con una regresión que crea y guarda una sesión sin perderlas. La biblioteca limita
nombre y descripción a dos líneas y conserva su texto completo al pasar el cursor.
Se aclara el origen privado/oficial y el singular de sesiones/fases en la estructura.
El modo compacto conserva el ancho de su selector y los márgenes anteriores.

Se repiten las baterías completas de raíz (1.349, una omisión previa), ADMIN
(315, dos omisiones previas), Trainer (207), editor (218) e interfaz común (28).
La nueva regresión se añade después y pasan las 25 pruebas de autoría oficial.
Análisis limpios en los cinco proyectos. No cambian contratos ni datos deportivos.
La revisión de publicación que sustituye a `6b0fe679` se acredita a continuación.


## Publicación final comprobada · 25/10/2026

Ambos portales Dev sirven las fuentes
`6fe1d35c5e17bbd2ad4641fe0563a8a7949db27b`.

- Trainer: release `6fe1d35c5e17bbd2ad4641fe0563a8a7949db27b-20261025-1`;
  JavaScript SHA-256
  `9c9f647aa8c9358ddb7246b36127401a54d210a44c1bd4c999d46517af113515`;
  ZIP `35ab22b33c7c48351f77c11d05cd1b85a279a7de20483e4e2eedfb033c1e1d2f`.
- ADMIN: release `6fe1d35c5e17bbd2ad4641fe0563a8a7949db27b-40196467093-1`;
  JavaScript SHA-256
  `db5e1dbe09239b1d66c29efe20929c2fc30686bc23bf21e705b98a308aea2e83`.
  El job validate del run `40196467093` termina correctamente: análisis, 1.349
  pruebas raíz y 316 ADMIN, con una/dos omisiones previas; Release compilado.

El job deploy de ese run falla al conectar por FTPS (`OSError`, errno 101),
antes de transferir contenido; retención queda omitida. No se presenta el run
como publicación automática correcta. Se descarga mediante el conector GitHub
el artefacto original `12600657150`, cotejado con su digest
`82d66c126e95f4eeae59c83126d6dbefec7ac625691b64fbf1ba4fff6717b1aa`.
Se publica ese mismo paquete, sin recompilar ni alterar su manifiesto, mediante
el administrador de archivos autorizado de Hostinger. Primero se copia la
carpeta versionada a `public_html/admin/releases`, se verifica su JavaScript por
HTTPS y después se sustituyen solo index y build-info en `public_html/admin`.
Trainer utiliza el mismo orden en su propio directorio. Se conservan versiones
anteriores; no se cambian permisos, robots, cabeceras ni producción.

Las comprobaciones HTTPS finales contrastan revisión, entorno, entrada activa,
SHA-256, cabeceras y MIME WebAssembly de ambos portales. Chrome confirma fuerza
con propiedades/dosis reales y guardado fijo; programa privado y oficial con
recetas resumidas; formulario de ejercicio en dos columnas y un único vídeo;
cartera e invitaciones, catálogos y gestión administrativa. La revisión final
comprueba la clasificación oficial plegada con sus categorías conservadas, el
origen Oficial/Privada y la biblioteca compacta. La calculadora se desplaza en
Chrome y se cierra sin modificar el trabajo. No se guardan recetas ni asignaciones,
no se conceden accesos y no se envían mensajes durante esa revisión.

La galería optativa genera 21 capturas finales de las 15 secciones, cinco
pantallas de edición y el diálogo de ejercicio. Se repite correctamente tras
el último ajuste. Permanecen los límites de producto ya descritos: búsquedas
sobre lo cargado, permisos existentes y cobros/push pospuestos. El fallo del
transporte FTPS queda registrado; su reparación no forma parte del acabado.
El estado del sistema también muestra fallos previos de copias Dev del 23 al 25;
esta tarea de presentación no los modifica ni acredita una copia nueva.


## Pulido tras contraste final Harbiz/Garmin · 25/10/2026

La revisión final autorizada se recoge en el [contraste de referencias](audits/harbiz-2026-10-21.md#revisión-final-del-25102026).
Se añaden a Trainer el resumen por fechas y el cambio de inicio de una pauta,
y tarjetas de mediciones disponibles en la ejecución. El desplazamiento usa
días civiles y no modifica recetas ni duración de fases. Tras un envío incierto
se conservan y bloquean las fechas; el reintento mantiene la misma operación.
La actividad distingue temporizador y transcurrido, conserva centésimas y calcula
ritmo global solo en carrera con datos suficientes. No hay nuevas métricas API,
consultas, permisos ni cambios en ADMIN o en la app móvil.

Análisis Trainer limpio y batería completa: 210 pruebas correctas. Regresiones
nuevas sobre fechas alrededor del cambio de hora, reintento de tanda, precisión
del reloj y ausencia/origen de métricas. Se revisan además capturas de widgets
reales con datos ficticios a 390 y 1440 píxeles y el resumen de la pauta;
no se guardan imágenes de salud ni de clientes reales en el repositorio.
El detalle conserva comparación de versiones y filtro compartidos. La
publicación Dev de esta revisión se acreditará después de compilarla.

ADMIN sí queda publicado automáticamente mediante el circuito reparado, con
validación, despliegue, retención y HTTPS correctos; evidencia en
[hosting ADMIN](ADMIN_HOSTING_2026_10_19.md#publicación-automática-acreditada).


### Publicación del pulido comprobada

Trainer Dev sirve revisión `63573854661c36df9a39fb839d631943cb93e6bf`, release
`63573854661c36df9a39fb839d631943cb93e6bf-20261025-1`, desde fuentes guardadas.
ZIP SHA-256 `a621ba61b84d05266781dc85ac6483f1fdc7de9a6a8ac08e17920e5b2ccc4399`;
JavaScript SHA-256 `a54dc2c5bc884f05f2c8057e7c26766e60d0d2ed6a34235165c105a2a62e7bb6`.
La compilación web Release termina correctamente. Se publica desde staging
privado nuevo: primero recursos en `public_html/trainer/releases`, cotejo del
JavaScript por HTTPS y después solo `index.html` y `build-info.json` en el portal.
Se conservan versiones y archivos ajenos, sin utilizar las credenciales ADMIN.

`trainer_release.py verify` contrasta entorno Dev, revisión, hash, entrada,
cabeceras y MIME WebAssembly. Chrome con la sesión existente acredita agenda,
resultado ya registrado con las tarjetas disponibles y diálogo de programa con
resumen de fecha, cambio de inicio y confirmación. Se cierra sin confirmar ni
cambiar pautas; no se modifican resultados. Cero errores o avisos de consola
capturados en ese recorrido. La versión de ADMIN continúa siendo la publicación
automática `e790a6af` antes acreditada; este pulido solo cambia Trainer.


## Agenda mensual con eventos · 27/10/2026

Javier pide sustituir los números de sesiones por un calendario de trabajo con
entradas legibles y arrastre, tomando como referencia Google/iOS Calendar.
`TrainerMonthCalendar` muestra una rejilla semanal de lunes a domingo. Cada tira
incluye alumno y sesión; el color se deriva de la identidad del alumno de forma
estable y el estado dispone de icono, texto accesible y tooltip completo. Las
pautas retiradas/archivadas se atenúan y tachan cuando el filtro permite verlas;
las completadas llevan su señal de finalización. El color no identifica permisos,
intensidad, diagnóstico ni una categoría deportiva inferida del nombre.

Se muestran dos entradas por celda y «+N más» abre el listado de ese día, con
nombre completo y estado. Las pruebas y simulacros llevan su icono propio y usan
el mismo color del alumno. La vista semanal reutiliza las tiras compactas. No se
inventa una hora: las pautas actuales están asignadas a fechas civiles.

Pulsar una sesión abre su detalle con alumno, fecha, versión e indicaciones y
los accesos existentes a planificación, resultado, movimiento y adaptación.
Las opciones dependen del estado: una ejecución iniciada no ofrece mover o
adaptar. El arrastre desde una tira mensual reutiliza el callback revisado de
movimiento y conserva el ID de la cita; el servidor sigue comprobando autoridad,
revisión y coincidencias. En móvil se mantiene la pulsación larga. Arrastrar una
sesión de biblioteca conserva el selector de alumno y la confirmación compacta.

La rejilla respeta los filtros, la carga por páginas y sus advertencias de
completitud. Los días del mes adyacente se muestran atenuados; pulsarlos consulta
su periodo antes de habilitar destinos de arrastre, sin afirmar que están vacíos.
Con poco ancho o texto ampliado, el tablero permite desplazamiento horizontal
sin comprimir nombres en columnas ilegibles. No hay dependencias, migraciones,
permisos ni cambios en ADMIN por esta presentación local.

La pauta de programas conserva el programa recibido del creador/ficha sin volver
a consultar el catálogo. Su botón de confirmación y la vuelta al alumno quedan
en un pie fijo, con independencia de la longitud de la lista de sesiones. Se
mantienen fases, fechas editables, cambio conjunto del inicio, repetición finita,
límite de envío, UUID de reintento y coexistencia con el plan del alumno. La
separación inicial de dos días continúa siendo una propuesta editable.

Validación: regresiones de calendario, filtros, paginación, texto ampliado,
arrastre a fecha, ejecución iniciada y selección de alumno; nuevas pruebas de
excedente, navegación a mes adyacente, detalle protegido y confirmación visible
de un programa de veinte sesiones sin consultar otra biblioteca. Se inspecciona
una captura del widget real con datos sintéticos locales; no se generan citas
ni registros de alumnos para las comprobaciones. La publicación Dev y la prueba
física de los avisos son comprobaciones independientes.


Comprobación local del 27/10: `flutter analyze` sin incidencias y batería completa
de Trainer con 256 pruebas correctas. Las siete nuevas comprueban excedente,
navegación, arrastre mensual, ejecución iniciada, presentación del tablero y
confirmación/cambio de programas sin consulta redundante. Se adaptan las
comprobaciones de paginación y filtros a las entradas ahora visibles en el mes,
conservando cursores y pruebas de texto ampliado existentes.


Publicación Dev comprobada el 27/10/2026: fuentes
`553b373e5a22dad25c96e3bce504974dc2a230f8`, run `40541898947`, validación y
despliegue correctos. `trainer.entrenaop.es/build-info.json` confirma esa revisión,
release `553b373e5a22dad25c96e3bce504974dc2a230f8-40541898947-1`, entorno development
y proyecto `sxbxfjqgoddzhtcyhalw`. El verificador HTTPS comprueba identidad, entrada,
hashes de recursos y cabeceras. La aceptación del uso real del calendario queda
para Javier; no se han movido citas personales durante la comprobación.
