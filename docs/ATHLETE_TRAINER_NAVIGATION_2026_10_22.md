# Navegación del alumno y preparador · TRN-025 · 22/10/2026

## Entrenar y Biblioteca: revisión del modelo · 02/11/2026

Javier informa de una cuenta Free con plan automático pausado, consulta del
programa y acceso Pro al intentar utilizarlo. Describe el mismo plan de nuevo en
Preparaciones, otra preparación pendiente y una promoción adicional para crear
un plan adaptativo. Cuestiona también las entradas a los guiados desde Entrenar
y Biblioteca. Reabre la organización conceptual; todavía no aprueba otro reparto.

Comprobado en el código directamente relacionado:

- Planes muestra todos los programas adaptativos cuyo estado no sea `draft`,
  incluidos pausados y completados; no es una lista exclusiva de programas en curso.
- Preparaciones vuelve a componer cada objetivo con el progreso del mismo programa.
- La promoción Pro aparece si no hay un programa `isCurrent`, por lo que un
  pausado puede coexistir con una invitación genérica a crear otro.
- Añadir en Tus programas guiados ya abre `/library?tab=programs`: hay una entrada
  alternativa al mismo catálogo, sin una segunda colección independiente.
- Biblioteca contiene Programas, Sesiones y Ejercicios, incluidas las plantillas
  personales reutilizables. No equivale al calendario ni a las sesiones pautadas.

La recomendación pendiente es mantener Biblioteca para explorar y crear contenido
reutilizable, y Entrenar para utilizar y gestionar lo elegido. Entrenar podría
abrir en Programas y permitir consultar Sesiones y Disponibilidad. Sesiones sería
la agenda o trabajo concreto, no otra copia del catálogo ni otro resumen semanal
como portada. Los guiados seguidos y el plan personalizado se organizan por estado,
con los pausados separados de lo que se puede continuar. Automático y adaptativo
deben tener un único nombre visible. Preparaciones describe objetivos, fecha y
pruebas: su gestión y consulta deben conservarse, evitando presentarlas como otra
colección de planes. La ubicación exacta de ese acceso sigue pendiente.

El requisito Pro se comunica antes de intentar activar o retomar el plan, sin
borrar ni ocultar la consulta legítima de lo conservado. Se recomienda una entrada
contextual al plan personalizado, evitando promociones genéricas repetidas junto
a un plan ya existente. Cambiar la presentación no cambia sus derechos comerciales.

La afirmación de poder añadir cualquier cantidad de guiados no se ha contrastado
en la cuenta: explorar no equivale a tener varios activos. COM-019/020 conserva
un programa guiado activo en Free y varios en Pro, con pausa e historial. Una
activación simultánea incompatible sería una incidencia separada que requiere
verificar el estado real, no una razón para modificar cuotas durante este rediseño.

## Revisión de Perfil y acceso profesional · 01/11/2026

Tras probar el reparto implementado, Javier rechaza la presencia del selector
Personal/Entrenador en la cabecera. Pide un acceso más discreto o trasladarlo a
Perfil, recuerda que la denominación visible es preparador y reabre la relación
entre Perfil y Ajustes. Esto revisa el criterio visual del selector aprobado
antes. Javier autoriza implementar la propuesta con una corrección expresa:
Dispositivos y conexiones permanece a mano en Perfil.

Se ha inspeccionado el vídeo aportado, de 26,92 segundos. Su Perfil conserva la
identidad y el historial; un engranaje abre Ajustes, donde se agrupan cuenta,
soporte, información legal y opciones de la aplicación. No se propone copiar sus
mensajes comerciales, restablecimientos ni funciones que EntrenaOP no tenga.

El código actual mezcla en Perfil identidad, edición de nombre y nacimiento,
evolución, conexiones, suscripción, versión y salida. El selector profesional se
compone por encima del shell y ocupa una franja adicional en las pantallas
principales de las cuentas habilitadas. Este es el diagnóstico comprobado.

El reparto autorizado es:

- Conservar **Perfil** en la barra: identidad compacta, acceso a editar datos y
  protagonismo para Mi evolución. La información deportiva no se oculta en Ajustes.
- Mantener **Dispositivos y conexiones** como acceso directo en Perfil, sin
  introducir un paso por Ajustes para Salud del móvil, Apple Watch o Garmin.
- Abrir **Ajustes** desde un engranaje en Perfil para suscripción,
  opciones de cuenta, información de la app y cerrar sesión. Se reutilizan los
  recorridos existentes; no se añaden opciones sin funcionamiento.
- Sustituir la franja global por una fila discreta **Entrar como preparador** en
  Perfil, visible sólo para cuentas habilitadas. Entrar requiere dos toques desde
  una sección personal; el espacio profesional ofrece **Volver a mi entrenamiento**
  y conserva su última pantalla. Se utiliza preparador en los textos visibles.
- Conservar los avisos del preparador recibido en la pestaña Preparador. Los de
  deportistas propios se identifican en el acceso profesional; un indicador en
  Perfil permite advertirlos desde otras secciones sin recuperar la franja global.

El coste de esta recomendación es perder el cambio profesional en un único toque
desde cualquier sección personal. La ganancia es recuperar espacio de contenido
y separar la actividad personal del trabajo profesional. El cambio no concede
permisos, modifica datos ni altera avisos, lecturas o procesos deportivos.
Se verifican entrada, retorno, borradores y cuentas con y sin acceso profesional.

### Implementación y comprobación del ajuste

`/profile/edit` y `/profile/settings` son tareas raíz con retorno al origen y
alternativa a Perfil en entrada directa. Editar conserva nombre y nacimiento;
la foto sigue editable en el avatar de portada, con el mismo control y sus
reintentos. Perfil no consulta nacimiento. La renovación transitoria de la misma
cuenta conserva identidad, foto y consultas; una cuenta distinta descarta sus
estados anteriores. El texto ampliado utiliza tarjetas adaptables a ancho completo.

El acceso profesional conserva la última sección personal distinta de Perfil y
la pila profesional, incluidos chat, agenda y borradores. Si se accede directamente
al espacio profesional, el retorno lleva a Perfil. El retorno también permanece
disponible durante la comprobación inicial de acceso; nunca monta datos privados
antes de verificar autorización y MFA. Los diálogos de salida y los envíos en
curso conservan sus guardas en la primera y en las siguientes salidas de una rama.

Análisis final limpio. Baterías completas: deportista **1.623 correctas y una
omisión previa**, ADMIN **368 y dos omisiones previas**, Trainer **432** y
`entrena_ui` **64**. Se reproducen las regresiones antes de corregir el registro
de guardas y la sustitución de conversaciones. Las ocho comprobaciones visuales
producen nueve capturas reales de Perfil, Ajustes y edición, a 320/390 px y texto
1×/2×, en `visual-audit/profile-workspace-2026-11-01/`; incluyen acceso profesional
y su contador. Las etiquetas se leen sin partir palabras; el correo largo se
divide para conservarlo completo. El generador sigue siendo
`tools/athlete_navigation_visual_test.dart`, con `ATHLETE_CAPTURE_DIR` para elegir
la carpeta. Son datos ficticios y no acreditan instalación en iPhone.

## Reorganización aprobada · 01/11/2026

Javier aprueba implementar el reparto revisado, conservando la estética y los
procesos que funcionan. Esta sección sustituye las propuestas y posiciones
históricas descritas más abajo.

| Destino inferior | Recorrido implementado |
| --- | --- |
| Inicio | Calendario compacto, sesión del día, preparaciones, guiados, herramientas y favoritos existentes; tarjeta compacta de novedades. |
| Entrenar | Planes como primera cara; desplazamiento sincronizado por toque o gesto entre Planes, Preparaciones y Disponibilidad. Ver semana abre el calendario común. |
| Biblioteca | Catálogo, consulta y creación existentes. Cambia únicamente la cabecera compartida de navegación. |
| Preparador | Búsqueda, conversaciones, recursos, avisos y gestión/historial del vínculo. Indicador de novedades en la pestaña. |
| Perfil | Identidad compacta, Mi evolución, Dispositivos y conexiones, acceso profesional y engranaje de Ajustes. |

### Contratos conservados

- Se mantienen las URLs de agenda, resultados, preparaciones, dispositivos y
  tareas profesionales. Perfil ocupa la rama histórica 3 junto a Evolución;
  `/profile` es su entrada y `/assessment/history` conserva sus hijos. La barra
  presenta las ramas `[0, 1, 2, 4, 3]`; el trabajo profesional permanece en la 5.
- Cambiar de sección conserva su pantalla y volver a tocar la entrada activa
  recupera su raíz. La revisión posterior sustituye el selector superior por el
  acceso profesional en Perfil y mantiene la memoria de los espacios. Los
  borradores siguen protegidos por las guardas existentes.
- Entrenar recibe opcionalmente `tab` y `date`; Ver semana utiliza la fecha
  correspondiente. El editor `/profile/preferences` conserva días, minutos,
  material, validación y guardado. El alias `/plan/preferences` sigue funcionando.
- Planes muestra los automáticos iniciados, pausados y finalizados con estado
  explícito. Los programas guiados seguidos utilizan el catálogo completo
  existente, sin heredar el límite de tres del resumen de Inicio. Preparaciones
  conserva objetivos, pruebas y configuraciones pendientes.
- El contador de Preparador utiliza el total del servidor, independiente de la
  página o filtro. Abrir la sección no confirma lecturas. La recepción, resolución
  y confirmación de avisos conservan sus contratos. Los avisos profesionales se
  mantienen separados en el espacio de preparador; se retira la campana superior personal.
- La búsqueda de preparadores sigue accesible sin recursos. Un error no se
  interpreta como ausencia de vínculo ni borra historial. La presentación vacía
  ofrece búsqueda e historial tras una respuesta confirmada.
- Perfil se fija a la identidad: renovar la misma sesión conserva su estado y
  cambiar de cuenta sustituye sus consultas pendientes. Volver de una tarea
  refresca los datos personales como antes.

### Consulta del entrenamiento antes de empezar

Javier confirma después que la consulta completa es imprescindible y autoriza
cerrarla en el mismo recorrido. La card y Ver entrenamiento abren la pauta
exacta, sin empezar. La acción de inicio es explícita y conserva el ejecutor,
comprobando que no se sustituya por contenido cambiado después de consultarlo.
Esta ampliación sustituye el límite inicial que dejaba únicamente metadatos.
No cambia reglas deportivas ni concede acceso al programa privado completo.
[Contrato y validación de la vista previa](SCHEDULED_WORKOUT_PREVIEW_2026_11_01.md).

### Comprobación y distribución

`flutter analyze` queda limpio. La batería completa de raíz termina con
**1.577 pruebas correctas y una omisión previa**. Incluye identidad, respuestas tardías, Perfil/Evolución, enlaces
históricos, retorno del editor con borrador y fecha, catálogo seguido completo,
lectura explícita de avisos, inicio por botón y cambio profesional conservando
pantalla y borradores. El editor de nombre permite desplazarse en el diálogo
para conservar sus controles a 320 px con texto 2×.

Las **14 comprobaciones visuales** generan 15 capturas de widgets reales con
datos ficticios y sin red; se reproducen con
`tools/athlete_navigation_visual_test.dart` y se guardan en
`visual-audit/athlete-navigation-2026-11-01/`. Cubren Inicio, las tres caras de
Entrenar, Perfil, Preparador y selector profesional, incluidos 320 px y texto 2×.
La revisión visual incluye correcciones del espacio disponible para identidad y
Evolución y del contador profesional junto a su etiqueta. No acredita instalación
de esta versión en el iPhone: requiere recompilar e instalar desde Mac.

El único siguiente bloque recomendado es aceptar en iPhone la semana de Inicio,
el gesto entre las tres caras, editar Disponibilidad y volver, los avisos del
preparador y el cambio profesional desde Perfil con una pauta de Ervi.

## Revisión global abierta · 01/11/2026

Javier indica que la incoherencia alcanza más recorridos y botones que los dos
ejemplos de la revisión transversal. El acceso a Perfil en la cabecera no le
gusta y se reabre su ubicación. La elección del 22/10 describe la implementación
actual y el acuerdo anterior; ya no debe interpretarse como aceptación definitiva
de la posición superior de Perfil.

El código actual confirma solapamientos: Perfil incluye preparaciones,
herramientas y Mi preparador; el hub Preparador y la gestión del vínculo ofrecen
accesos a formularios y conversación; Inicio y Mi plan presentan semana y
preparaciones. Mi plan utiliza como primera referencia el programa automático
aunque las pautas profesionales también sean el entrenamiento del usuario.
En las cuentas profesionales, el selector superior añade además el acceso al
trabajo con alumnos propios. El código separa esos espacios, pero hay que revisar
si esa diferencia se entiende en la interfaz.

### Propuesta visual pendiente de revisión con Javier

Repartir las tareas entre cinco entradas inferiores, con un destino principal
por tarea. Los accesos contextuales pueden llevar a ese mismo destino conservando
fecha, pauta y origen; no deben crear otro resumen independiente.

| Entrada propuesta | Contenido principal |
| --- | --- |
| Inicio | Conservar calendario, cards de preparaciones, programas y herramientas; revisar su orden. Sesión del día y tarjeta compacta de novedades del preparador. |
| Entrenar | Calendario personal común y accesos internos a planes, preparaciones y disponibilidad. El origen distingue pautas del preparador, automáticas y personales. |
| Biblioteca | Descubrir, consultar y crear sesiones y ejercicios; programas guiados. |
| Preparador | Personas con quienes se entrena, conversaciones, formularios, citas y gestión de vínculos. Las pautas abren el calendario personal común. |
| Perfil | Probar Evolución junto a identidad, foto, cuenta, preferencias, conexiones, suscripción y ajustes. |

Esta propuesta devuelve Perfil abajo y retira su acceso repetido de la cabecera.
Evolución deja de ser una entrada inferior independiente y se prueba dentro de
Perfil, a sugerencia de Javier. Sustituye la primera propuesta de alojarla en
Entrenar. Mantendría accesos contextuales desde resultados. La distribución y
los nombres continúan pendientes de aceptación.

### Referencia visual y ajuste de la propuesta · 01/11/2026

Javier descarta la simplificación visual de Inicio del primer prototipo: quiere
conservar sus cards y su identidad. Valora la idea de pendientes, pero recuerda
que la tarjeta actual de novedades del preparador ya cubre parte de esa función.
El prototipo revisado conserva esa tarjeta compacta y recupera calendario,
preparaciones, programas seguidos y herramientas, sin añadir otro resumen de
pendientes equivalente.

El vídeo aportado muestra una barra inferior estable y, dentro de Correr, una
fila horizontal de accesos que abre páginas con retorno. También permite
desplazar semanas. La referencia justifica explorar esos dos niveles de
navegación; no implica unir Mi plan y Preparador, que Javier señala como asuntos
distintos, ni sustituir la estética de EntrenaOP.

La propuesta interactiva prueba esa fila dentro de Entrenar: Mi semana, Mis
planes, Preparaciones y Disponibilidad. La semana reúne las sesiones fechadas;
Mis planes permite distinguir el plan automático y los programas guiados que se
siguen; Preparaciones reúne los objetivos y sus pruebas. Preparador conserva la
relación, conversación y seguimiento. Biblioteca permite descubrir contenido;
seguir un programa tiene su acceso principal en Mis planes. Los accesos desde
Inicio llevan a esos mismos destinos conservando el origen.

Los programas del prototipo son ficticios. Este reparto no concede al deportista
acceso al programa privado completo de un profesional: se mantiene el contrato
de sesiones asignadas. Tampoco modifica niveles de suscripción ni permisos.

La propuesta se revisa con datos de ejemplo, fila horizontal, cambio de semanas,
detalle de sesión y Evolución en Perfil; no modifica rutas ni pantallas de
Flutter. La aceptación de estos recorridos precede a su implementación.

### Impresiones del segundo prototipo · 01/11/2026

Javier valora la dirección visual y concreta estos criterios para la siguiente
revisión, todavía sin autorizar su implementación en Flutter:

- Conservar la semana compacta de Inicio. Repetirla como primera cara de
  Entrenar resulta redundante, aunque el calendario completo debe seguir
  accesible.
- Mantener Planes, Preparaciones y Disponibilidad como apartados internos y
  explorar el desplazamiento del contenido sincronizado con sus accesos.
- Reutilizar la presentación y el editor actuales de disponibilidad y material;
  la simplificación del prototipo no sustituye días, minutos, material ni sus
  reglas de guardado.
- Conservar Biblioteca como está durante este bloque.
- Preparador debe ofrecer búsqueda cuando no existe vínculo y mostrar en su
  pestaña el indicador de novedades, en lugar de depender de la campana superior.
- Perfil sigue la dirección deseada. El cambio al trabajo profesional necesita
  conservar la rapidez del selector actual; enterrarlo en Perfil añade pasos.
- El alcance es presentación, ubicación y continuidad de navegación. Se
  conservan los procesos deportivos, datos, permisos y la arquitectura existente.

La recomendación pendiente de Javier es abrir Entrenar en Planes, con
Preparaciones y Disponibilidad como las otras caras del desplazamiento. Un
acceso visible a Ver semana abriría el calendario existente, compartiendo destino
y fecha con el acceso desde Inicio. Así se mantiene su función de agenda sin
repetir el resumen semanal como portada de dos secciones.

Se recomienda conservar el selector de espacio visible en las pantallas
principales, con una presentación más ligera que respete el tamaño de texto y
recupere el destino anterior. Los avisos recibidos del preparador pertenecen al
espacio personal; los de alumnos propios, al profesional. Mover el indicador no
debe alterar recepción, autorización ni confirmación de lectura. Las pruebas
deben cubrir retorno, fecha, borradores y cuentas con y sin seguimiento.

El trabajo con alumnos propios mantendría un espacio profesional con agenda,
alumnos y mensajes. Su entrada y retorno deben ser explícitos y conservar el
contexto. «Mi preparador» describe el servicio que recibe la persona;
«Espacio de entrenador» describe su actividad profesional. La posición final
del cambio de espacio sigue abierta, especialmente por la frecuencia de uso.

Revisar después los botones con la misma regla: tocar una sesión permite
consultar su receta; empezar requiere una acción explícita. Este comportamiento
se propone y todavía no está implementado. Cada pantalla debe distinguir su
acción principal de editar, añadir, gestionar o configurar.

El siguiente paso es validar el reparto con los recorridos de un usuario sin
preparador, un alumno con pautas y una cuenta que también trabaja con alumnos.
La implementación transversal comienza después de concretar esa estructura.
Esta revisión documental no modifica Flutter, datos, permisos ni rutas.

## Elección del 22/10 e implementación actual

Preparador abajo, Perfil arriba e Inicio despejado. La campana se oculta por
completo con cero avisos sin leer, para que no parezca un control de sonido.
Mantener avisos, historial y las planificaciones coexistentes. Sin agentes ni
coordinación con otros chats.

## Implementación

- El shell conserva Inicio, Mi plan, Biblioteca y Evolución. Añade Preparador
  ante vínculos actuales/anteriores o recursos/avisos profesionales propios.
  No muestra una quinta pestaña comercial o vacía a usuarios sin seguimiento.
- Perfil sale de las ramas inferiores y conserva `/profile`, preferencias,
  vínculo y actividades como rutas raíz. El icono superior abre Perfil con
  retorno al origen; una entrada directa puede volver a Inicio.
- Los cuatro destinos y Preparador incorporan el mismo acceso superior a Perfil
  y la campana condicional. La campana abre `/my-trainer?view=notices`.
- Inicio conserva entrenamiento, calendario, preparaciones y contenido general.
  Sustituye las tarjetas profesionales repetidas por una tarjeta compacta con el
  total de novedades del servidor. Sin novedades, tampoco aparece esa tarjeta.
- Preparador separa Resumen y Avisos. Resumen conserva sesiones, formularios,
  conversación, pruebas y técnica cuando existen, y siempre permite consultar
  vínculo e historial, incluso sin recursos. Avisos conserva filtros, paginación,
  destino autorizado y confirmación explícita de lectura.
- Se mantienen las URLs de formularios, conversación, técnica y agenda. Las
  tareas continúan sin barra cuando corresponde. No cambia el ejecutor ni la
  convivencia del plan automático con pautas profesionales.

## Carga e identidad

`StudentNavigationController` comparte el resumen de avisos entre cabecera,
Inicio y pestaña. Consulta vínculos mediante el repositorio existente; solo busca
los terminados si no hay uno activo. No descarga respuestas, vídeos ni todas las
páginas del historial para decidir si mostrar una pestaña.

Agrupa refrescos simultáneos y actualiza al reanudar, refrescar Inicio o volver
de gestionar el vínculo. El hub incorpora sus nuevos totales tras consultar o
marcar avisos. Una respuesta antigua no revierte una lectura posterior. Un fallo
de conexión conserva lo ya conocido en esa sesión; no simula que no quedan
avisos. No hay sondeo continuo ni nueva sincronización en segundo plano.

El estado pertenece a una identidad y se descarta al cambiar de cuenta o salir.
La renovación transitoria de sesión conserva las ramas, sus filtros y scroll;
la prueba existente de Evolución detectó y permitió corregir esa regresión.
La visibilidad de navegación no concede permisos: los destinos siguen validando
sus recursos en servidor.

## Comprobación

- Pruebas focales de shell, rutas, avisos e identidad correctas; incluye volver
  de Resumen a Avisos y seleccionar Preparador desde la campana.
- Seis pruebas de rutas de Evolución correctas tras la corrección de renovación.
- Batería completa final de raíz: **1.270 correctas, una omisión previa**.
- Análisis focal y análisis global final de Flutter limpios, incluido el
  generador de capturas. Los avisos temporales de trabajo ajeno observados durante
  el desarrollo ya no aparecen en el análisis final.
- Cinco escenarios visuales con widgets reales, datos ficticios y sin red:
  Inicio con/sin avisos, 320 px con texto 2×, Preparador e historial sin recursos.
  `tools/athlete_navigation_visual_test.dart` los reproduce. Perfil se comprueba
  accesible en cabecera y la campana ausente a cero.

No cambia ADMIN, creadores compartidos, dependencias, Supabase ni producción.
No implementa push ni pagos. Este cambio es de la app del deportista y no requiere
publicar otra vez `trainer.entrenaop.es`.

## Distribución y siguiente paso

Pruebas y capturas no acreditan instalación en el iPhone. El siguiente paso es
compilar e instalar la revisión nueva y aceptar inicio, campana, pestaña,
conversación e historial con la cuenta vinculada. Los otros pendientes de los
dieciséis puntos mantienen su estado en `TRAINER_STUDENT_UX_2026_10_22.md`.

![Inicio con novedades](visual-audit/athlete-navigation-2026-10-22/inicio.png)
![Inicio sin campana](visual-audit/athlete-navigation-2026-10-22/sin-avisos.png)
