# Identidad visual de EntrenaOP

## Cierre sin notas vacías · 16/10/2026

Javier confirma que el RPE se ve bien y aporta un cierre con comillas vacías.
El bloque de sensaciones se mostraba para una cadena vacía porque solo se
comprobaba ausencia (`null`). El cierre y el detalle del historial ahora exigen
texto no vacío tras ignorar espacios. Se conservan las notas almacenadas y el
registro de tiempos y esfuerzo. La captura corresponde al cierre; no confirma
por sí sola todos los recorridos de RIR ni la repetición del incidente EMOM.
Análisis limpio y 58 pruebas relacionadas correctas para esta corrección.


## RIR entero y sujeciones sin RIR · UI-048 · 16/10/2026

El selector de esfuerzo existente se comparte entre deportista y ADMIN. RIR
ofrece 0–10 enteros y «No lo sé · Sin registrar», conservando el valor decimal
antiguo hasta una nueva elección. Se usa también en calibración, objetivos de
sesiones, rendimiento y corrección del historial.

Las tareas genéricas de duración no muestran ni generan RIR nuevo: el editor
lo excluye al publicar y el ejecutor al formar el resultado. Los borradores y
los resultados históricos se conservan sin transformaciones; la corrección de
otro dato mantiene cualquier RIR previo. El temporizador de una serie por
repeticiones no suprime RIR. No se incorpora RPE a sujeciones sin un protocolo
que lo defina. Reglas deportivas y adaptación conservadas; aceptación física
pendiente tras las pruebas automatizadas.


## RPE real entero y cierre de sesiones · UI-047 · 16/10/2026

Javier acuerda simplificar el RPE real a enteros del 1 al 10 en las pantallas de
entrenamiento. Se reutiliza `WorkoutEffortField` con una opción para elegir
enteros: serie ordinaria/carrera, resultado deportivo y corrección del historial.
La ausencia de esfuerzo sigue siendo un estado válido y no se preselecciona la
prescripción. RIR conserva su escala previa; los campos de calibración y edición
de prescripciones no forman parte de este cambio del ejecutor.

Los tipos numéricos de dominio y base de datos, las reglas de los motores y sus
umbrales permanecen vigentes. No se redondea en repositorios, codecs ni al guardar
otro campo. Un RPE histórico o borrador de 7,5 se sigue mostrando y se conserva
al corregir repeticiones/tiempo; elegir expresamente otro RPE ofrece solo enteros.
No se migra ni reinterpreta el historial. El RPE global de sesión ya era entero.

Javier comunica que, tras guardar un EMOM y verlo en historial, al repetirlo una
vez apareció la pantalla de registro anterior; no consigue reproducirlo después.
La revisión detecta dos condiciones comprobables relacionadas, sin afirmar que
sean la causa exacta de ese incidente:

- El cierre remoto aceptado dependía de releer la ejecución y de consultar el
  contador de cola. Fallar después de guardar devolvía la pantalla al formulario.
  `ActiveWorkoutCubit.finish` proyecta ahora el cierre aceptado/encolado y trata
  los fallos de limpieza o contador como advertencias. Un cierre ya confirmado
  no vuelve a enviarse; un rechazo real conserva el registro para reintentar.
- `startExecution` llamaba al servidor antes de sincronizar un cierre en cola.
  Como la RPC retoma ejecuciones abiertas, podía devolver el identificador de la
  sesión anterior. El repositorio sincroniza primero y comprueba que siga siendo
  la misma cuenta. Un fallo conserva la cola y no inicia otra ejecución.

Verificación: análisis limpio, 896 pruebas completas correctas con una omisión
existente y 85 específicas de ejecutor, formulario deportivo y repositorio. Incluyen elección entera, conservación de 7,5 al cambiar solo el
tiempo, rechazo real de cierre, fallo de lectura/limpieza/contador tras aceptación,
reapertura completada, orden cierre→inicio y cambio de cuenta. Sin cambios SQL,
paquetes compartidos, admin ni dependencias. La repetición física del incidente
EMOM queda pendiente.

## Circuito AMRAP y revisión del resultado · UI-046 · 16/10/2026

Javier aporta una grabación y una captura: AMRAP conserva la tarjeta anterior,
sus movimientos son texto sin foto ni acceso a técnica, el selector del parcial
desborda con nombres largos y el guardado devuelve un error genérico. Confirma
que tocar el móvil después de cada ejercicio sería inaceptable. Aprueba un
contador **opcional de vueltas completas**, visible junto a toda la secuencia,
y un registro manual al terminar para quien prefiera no tocar durante el bloque.

`WorkoutAmrapEntry` sustituye la tarjeta privada de la página. Presenta el
reloj compacto en horizontal, cada movimiento con foto, objetivo/carga/RIR y
consulta mediante la ficha compartida `ExerciseDetailSheet`. No señala un
ejercicio actual que la app no conoce ni exige marcas por movimiento. En el
formato móvil habitual el reloj queda visible y los controles +1/restar,
Terminar AMRAP y registros permanecen accesibles. Con pantalla baja o texto
ampliado también el reloj se desplaza; se conserva el tamaño del texto.

El modo horizontal es una opción de presentación de `WorkoutSetCountdown`;
reutiliza el reloj, persistencia, preparación, avisos, pausa, reinicio y
repetición existentes. Reiniciar el reloj no borra la cuenta de vueltas.
`WorkoutAmrapExerciseTile` se comparte entre circuito y selector del parcial.
Las fotos proceden del catálogo ya cargado por el Cubit, con alternativa si no
existen o fallan. Abrir la técnica conserva el circuito y no ofrece edición.

Javier pide después compactar las tarjetas y destacar Terminar AMRAP. La foto
pasa de 76 a 56 píxeles lógicos, con menos relleno y separación. La altura sigue
el contenido: nombres, repeticiones/carga/RIR pueden ocupar varias líneas sin
recortarse ni reducir la letra. La misma tarjeta compacta sirve en la revisión.
Terminar AMRAP usa el botón principal relleno, con icono de confirmación, letra
de 15 y un mínimo de 48 píxeles de alto; sumar una vuelta usa un botón secundario
de contorno. Javier pide recuperar el protagonismo del reloj: sus dígitos en
línea pasan de 46 a 60, con ajuste al ancho disponible que reserva la misma
medida también durante la preparación. El texto ampliado conserva el formato
apilado anterior. Los nombres de los ejercicios mantienen su tamaño.
El acceso a registros conserva su icono junto a la acción principal. Son cambios
de presentación, sin alterar el contador opcional ni el contrato de guardado.
Con el balance final de reloj y cierre, la batería general pasa con 886 pruebas
y una omisión existente; análisis limpio y 64 pruebas específicas correctas de
ejecutor y temporizador. Se comprueba también que el reloj conserva su alto al
pasar por preparación, reinicio y repetición. Las capturas finales de 390/412 px y 320 px con texto doble
mantienen las acciones accesibles y el acceso a técnica/revisión.

El 16/10/2026 se conecta Supabase y se aplican ambas migraciones únicamente a
`entrenaop-dev` (`sxbxfjqgoddzhtcyhalw`). Los identificadores generados por el
servidor son `20261016090723` y `20261016090736`; se renombran los dos archivos
locales para conservar un historial idéntico, sin reparar ni borrar registros
remotos. No cambia su SQL. La prueba transaccional pasa en ese proyecto, incluido
13/30 en el segundo movimiento y cuatro vueltas sin parcial. Al terminar quedan
cero usuarios y plantillas de prueba. Se comprueban fuente manual, ausencia de
marcas individuales inventadas, reintentos, inmutabilidad y rechazo entre cuentas;
`anon` no tiene ejecución y `authenticated` conserva el acceso protegido por
propiedad. Queda pendiente repetir el guardado desde el iPhone tras aplicar
la corrección.

Se consulta el asesor de seguridad. La advertencia de función SECURITY DEFINER
accesible por autenticados es esperada para esta RPC con propiedad comprobada;
no se amplían grants. El asesor también enumera avisos ajenos a esta corrección,
sin convertir este cambio en una auditoría global. [Referencia del aviso del asesor](https://supabase.com/docs/guides/database/database-linter?lint=0029_authenticated_security_definer_function_executable).

`WorkoutAmrapReview` abre un panel al terminar. Permite introducir o corregir
vueltas, indicar si empezó otra y elegir el movimiento con foto y nombre
completo; desaparece el desplegable de ancho insuficiente. El resumen explica
que los movimientos anteriores de esa vuelta están completos y declara las
repeticiones del seleccionado. Por ejemplo, cinco vueltas y cuatro sentadillas
conservan las flexiones y plancha de la sexta. Si acaba justo entre movimientos,
se elige el siguiente con cero; cero en el primero equivale a ninguna vuelta
adicional. Terminar el tiempo no confirma automáticamente ningún resultado.
Cerrar el panel conserva la revisión y vuelve al circuito. El teclado pertenece
al panel y se retira con Hecho, cerrar y guardar; no contrae además el circuito
de fondo. Los errores se muestran en zonas desplazables para no colapsar la
cabecera con texto ampliado.

`WorkoutAmrapDraft` es dominio puro: valida enteros, límites y parcial contra
la prescripción. `WorkoutAmrapDraftStore` es el puerto local y su adaptador de
preferencias/codec vive en datos, separado de los widgets. Cuenta, ejecución y
bloque delimitan las claves. Conserva incluso campos a medio escribir, serializa
las escrituras y no sustituye contenido ilegible por un cero. El Cubit calcula
los incrementos desde su último estado para no perder pulsaciones consecutivas;
los toques nunca envían series ni resultados al motor. Salir para retomar
conserva el borrador. Cerrar conservando lo realizado exige revisar antes una
cuenta AMRAP pendiente; descartar conserva la confirmación destructiva vigente.

Los registros agrupan AMRAP por bloque, con secuencia y resultado conjunto,
en lugar de presentar cada movimiento como una serie que debe resolverse. La
cabecera del bloque activo explica ejercicios por vuelta y el historial conserva
también el caso de terminar entre movimientos. En sesiones que incluyen AMRAP,
la barra de progreso y los cierres cuentan bloques resueltos; los movimientos de
un AMRAP no se anuncian como series independientes. Las sesiones sin AMRAP
conservan su progreso por series o tramos. **No se añade un corrector del
agregado ya confirmado**: la revisión es editable antes de guardar, y el contrato
de corrección posterior requiere su propio diseño auditable.

El guardado valida antes de enviar y distingue el rechazo remoto de una pérdida
de conexión que usa la cola vigente. Un resultado aceptado o encolado se proyecta
sin exigir una segunda lectura remota; fallar al limpiar reloj/borrador o contar
pendientes no lo transforma en «no guardado» ni permite volver a enviarlo.
`WorkoutAmrapSaveFailure` mantiene la referencia del rechazo remoto sin filtrar
SQL a la interfaz; el adaptador registra código y mensaje técnico sin el payload.
La migración `20261016090723_amrap_review_and_retry.sql` admite parciales de cero,
serializa por ejecución y reconoce el mismo resultado repetido incluso con un
recibo nuevo. Un resultado diferente no sobrescribe el agregado confirmado.

La primera prueba aislada aceptaba 5 vueltas y 4/10, pero omitía las migraciones
posteriores de carrera y su restricción de fuente. Por ello no acreditaba el
guardado sobre el esquema vigente. Javier aporta después el rechazo `23514` en
iPhone, seleccionando el segundo movimiento con 13/30. Al cargar también las
migraciones de carrera se reproduce `workout_execution_sets_completed_source_check`:
la función AMRAP completaba sus filas sin rellenar `result_source`.

`20261016090736_amrap_manual_result_source.sql` sustituye la función para
declarar `result_source='manual'` en las filas resueltas, manteniendo el agregado
como única marca deportiva. No elimina la restricción, inventa repeticiones por
movimiento ni modifica permisos. Conserva serialización y reintentos. Se añade
una migración nueva para respetar el historial de entornos donde la anterior
ya esté aplicada.

Verificación local: regresiones de dominio y preferencias, envío/cola, recuperación
del contador, pulsaciones consecutivas, fallo y reintento sin perder datos,
lectura/limpieza fallidas tras aceptación, fichas sin editar, teclado y nombres
largos. Capturas de widgets reales en 390×844 y 412×915 con escala 1,2 y áreas
seguras 47/34; también 320×568 con texto doble. En las dos medidas habituales
se comprueba que las tres tarjetas completas caben sobre el contador. Las fotos
de las capturas son una referencia local repetida, no cambios al catálogo.
La prueba `supabase/tests/amrap_review_and_retry.sql` comprueba guardado,
parciales de cero, normalización, reintentos, rechazos y permisos con ROLLBACK
en PostgreSQL aislado mediante PGlite, con autenticación ficticia. La regresión
ampliada incluye las migraciones reales de carrera `20260922003000` a
`20260922008000`, el contrato de rendimiento `20261003004000` y las dos
migraciones AMRAP del 16/10. Antes de la segunda migración reproduce `23514`;
después pasa también 13/30, exige fuente manual y comprueba que no se inventan
resultados individuales. Ese banco local se completa después con la prueba
transaccional remota descrita arriba.

Cierre técnico local del 16/10/2026: `flutter analyze --no-pub` limpio y
`flutter test --no-pub` completo con **886 pruebas correctas** y la omisión web
preexistente. El recorrido de selección repetida conserva las repeticiones
introducidas; no restablece el parcial por volver a tocar el mismo movimiento.
Se revisa el diff completo, incluidos archivos nuevos, y su formato. Sin cambios
en dependencias de la aplicación, paquetes compartidos ni admin.

Verificación remota del 16/10/2026: migraciones aplicadas y prueba SQL con
ROLLBACK correcta en **Supabase de desarrollo**. Javier confirma después que
el balance visual ya se ve muy bien en el iPhone. Falta confirmar el guardado
AMRAP desde el dispositivo. No se consulta ni modifica producción.

## Evolución: etiquetas y acciones sin recortar · UI-045 · 16/10/2026

Javier aporta dos capturas del iPhone que muestran problemas de presentación
pendientes tras UI-044: la parte superior de Preparación desaparece al abrir
los filtros y Guardar queda recortado en el calendario. La revisión anterior
comprobó el idioma y la excepción al consultar, pero no detectó esos recortes.

El primer campo no reservaba espacio para su etiqueta flotante fuera del borde;
el recorte del panel expandido la cortaba. Los filtros añaden margen superior
para que la etiqueta completa quede dentro de su área pintada. El calendario
usa un tema local: la tipografía del rango cabe en los 64 px reservados por
Flutter, la barra de acciones dispone de 72 px y el botón reduce únicamente
su relleno vertical. La cabecera deja de invadir Guardar. Se mantienen colores,
escala nativa del calendario, entrada manual, elección/cancelación y consultas.
No cambia el tema compartido, dependencias, navegación, dominio ni datos.

Las nuevas regresiones comprueban etiquetas flotantes transformadas contra los
recortes reales de sus ancestros, el área completa de Guardar y el alto pintado
de la cabecera frente a su reserva. También comprueban que las fechas elegidas
no se eliden y que Guardar permite aplicar el rango. Se usan áreas seguras de
47/34 px, alto 844 px y escenarios de 390 px con texto normal y 1,2, y 320 px con
texto doble. Las capturas del widget real incluyen fuentes e iconos del SDK;
no equivalen a una nueva comprobación física del iPhone.

Verificación del 16/10/2026: análisis limpio, 17 pruebas de filtros y 867 pruebas
completas de raíz correctas, con la omisión web preexistente. Las regresiones
fallan contra la versión anterior: Preparación sobresale del recorte del panel
y la cabecera mide 82 px frente a los 64 reservados con texto 1,2. Se revisan
capturas de filtros, calendario inicial y rango seleccionado en los tres
escenarios. No hay cambios en paquetes compartidos ni admin.

Instalación del 16/10/2026: el código `2690d7b` se compila en Release con
`APP_ENV=development` y se instala por reemplazo en Iphone-JVR (iPhone 12),
sin desinstalar ni cambiar su identificador. Firma estricta y binario AOT
verificados; `devicectl` confirma el arranque sin la sesión de Flutter. No se
incluye clave Test Store ni configuración de producción. Se conservan los
cambios locales previos de Xcode/SPM. Javier dispone de esta versión para
comprobar Preparación y Guardar; la aceptación visual sigue pendiente.

## Evolución: idioma y pantalla gris al filtrar · UI-044 · 16/10/2026

La grabación de Javier muestra el calendario en inglés y, tras seleccionar
11–16 de octubre y guardar, un bloque gris que sustituye el contenido de
Evolución (aproximadamente desde el segundo 20). Se reproduce con una consulta
pendiente, después de desplazar la pantalla y aplicar el rango: los desplegables
sin clave propia leen la posición del ListView como si fuera un booleano de
apertura (`double` no convertible a `bool?`). El cambio de estado de carga
reconstruía los paneles y hacía visible esa colisión de `PageStorage`.

Otros historiales y Filtrar historial guardan su apertura en claves distintas
de la posición del scroll; el contenedor de filtros conserva su identidad al
cambiar entre carga, resultados y error. El calendario y los controles oficiales
de la aplicación del deportista usan castellano de España, aunque el dispositivo
esté en inglés. `flutter_localizations` pasa de transitiva a dependencia directa
del SDK: no cambia ninguna versión ni añade un plugin nativo. No se modifican
los criterios de consulta, paginación, reglas deportivas, datos ni permisos.

Las regresiones recorren abrir/cancelar calendario, seleccionar y guardar fechas
con red pendiente o fallida, conservar filtros abiertos, limpiar un resultado
vacío o fallido y recargar con los dos paneles abiertos de forma independiente.
Otra prueba monta la app real con idioma del dispositivo en inglés y comprueba
los controles y meses en castellano. El calendario se verifica con la fuente
real incluida en el SDK; se mantienen las comprobaciones de texto doble y
pantalla estrecha. Queda repetir el recorrido en el iPhone con la app actualizada.

Verificación del 16/10/2026: `flutter analyze` limpio en raíz y admin;
18 pruebas específicas correctas, 861 pruebas completas de raíz y 109 del admin
correctas, con una omisión preexistente en cada batería. Se revisa una captura
del calendario en castellano con fuente real. El lockfile conserva todas las
versiones y solo cambia el carácter directo de la dependencia del SDK.

## Semanas por gesto y Biblioteca ajustada · UI-043 · 16/10/2026

Javier pide cuatro correcciones a partir de tres grabaciones cortas y una
captura del iPhone. En el primer vídeo (00:00–00:08) la semana permanece en
19–25 oct al deslizar la fila de días; el domingo queda fuera del ancho visible.
El segundo (00:00–00:06) muestra desplazamiento vertical en las dos pestañas de
la portada de Biblioteca. El tercero (00:00–00:08) muestra iconos en las listas
y la foto existente al abrir Sonrisa feliz. La captura confirma «Ver los míos»
en la tarjeta Mis sesiones.

`WeekSwipeRegion` separa el gesto de presentación de los datos: izquierda avanza
una semana, derecha retrocede y ambos reutilizan `changeWeek`, igual que las
flechas. Requiere desplazamiento suficiente o una pasada rápida; mover en
vertical no cambia de semana. Los primeros/últimos 24 px quedan fuera para
conservar volver desde el borde. La fila de días deja de tener un scroll
horizontal competidor: los siete ocupan el ancho y, si el texto ampliado no
cabe, pasan a filas adicionales sin reducir la letra. Se mantienen selección,
flechas, recarga y protección existente frente a respuestas fuera de orden.

Biblioteca conserva Sesiones/Ejercicios, los gestos entre pestañas y los
destinos oficiales/personales. Se acorta el texto de cabecera y las frases
decorativas, se retira el rótulo EntrenaOP repetido sobre Sesiones EntrenaOP y
se ajustan márgenes. Las dos tarjetas comparten el alto útil real de la pestaña
mediante `SliverFillRemaining`; en escritorio siguen en columnas paralelas.
No se calculan alturas a partir del nombre de un móvil; se conserva la escala
de texto elegida por el usuario y la cabecera usa una jerarquía más compacta.
Cuando caben no existe recorrido vertical; texto doble o un espacio muy corto
conservan desplazamiento para acceder a todos los controles. La tarjeta personal
de sesiones usa «Ver las mías»; la de ejercicios conserva «Ver los míos».

Cada entrada de las listas de ejercicios, tanto personal como oficial, muestra
la misma `thumbnailUrl` ya utilizada por su ficha, inicialmente en una miniatura
de 72 px; UI-050 fija finalmente 80×60 px tras descartar UI-049.
Mantiene proporción y muestra un icono durante carga, ante error o si no existe
foto. Tocar la tarjeta conserva el panel compartido, con permisos de edición
intactos. No se inventan fotos ni se publica contenido en el catálogo.

Las regresiones comprueban gesto en ambas direcciones, flechas, selección de
domingo, scroll vertical y exclusión del borde; los días ampliados continúan
accesibles. Biblioteca se comprueba con AppShell y áreas reservadas reales a
390 × 844 y 412 × 915 con texto 1,2: todos los botones son pulsables y la
extensión vertical es cero. Incluye texto doble y escritorio, rutas personales
y creación. Las fotos se decodifican desde un cliente HTTP local de prueba y
se comprueba también el error de imagen, sin acceso externo ni escrituras.
Las capturas opcionales usan fuentes reales y una imagen local de referencia.
Queda repetir los recorridos en el iPhone/Samsung actualizados desde main.

Verificación del 16/10/2026: análisis limpio, 37 pruebas relacionadas correctas,
857 pruebas completas de raíz correctas con la omisión web preexistente y cinco
escenarios de captura verificados con fuentes reales. Se revisan ambos tamaños
con AppShell, ambas pestañas, semana tras el gesto y miniaturas oficiales y
personales. Sin cambios en paquetes compartidos, admin, dependencias, SQL,
motores ni producción; publicación directamente en main.

## Calentamiento visible y salida del teclado · UI-042 · 16/10/2026

Javier comparte capturas del iPhone: durante «Prepárate…» los controles del
calentamiento quedan parcialmente fuera del área desplazable, el campo de
reinicio toca las acciones y el teclado REINICIAR permanece sobre Movimientos.
Confirma que la distribución de Sonrisa feliz ya le encaja.

El reloj compacto reserva una línea de estado en reposo, preparación, trabajo,
pausa, final y repetición. El paso de un estado a otro no añade alto a la tarjeta.
El botón reserva el espacio de su etiqueta más larga, también cuando necesita
dos líneas con texto ampliado; Cancelar y Repetir no reducen su altura.
Las indicaciones específicas extensas se muestran en dos líneas con acceso al
panel existente; allí se conservan completas bajo «Indicaciones de esta serie»,
separadas de la descripción del ejercicio. Se reduce el espacio antes del reloj.
La foto mantiene el crecimiento adaptable de UI-041 y las acciones siguen fijas.

El diálogo de reinicio de ensayos elimina el desplazamiento anidado dentro de
EntrenaDialog y añade separación bajo el campo. No abre el teclado hasta tocar
el campo; Hecho solo lo cierra, sin ejecutar un reinicio. Cancelar y confirmar
retiran el foco y ocultan el teclado nativo antes de cerrar el diálogo; se repite
la retirada tras el cierre para evitar restaurar un campo anterior. Cambiar de
paso en Mi programa también cierra el teclado, y desplazar sus formularios lo
descarta. El reinicio de planificación de carrera reutiliza el mismo cierre.
Se mantienen las confirmaciones explícitas, los datos conservados y las
operaciones existentes; no hay cambios de reglas de programa ni de servidor.

Todo el cambio reside en presentación, incluido `dismiss_keyboard.dart`. Las
regresiones cubren alto del reloj antes/durante/después de preparación, reinicio
y repetición, y cierre del teclado con Hecho, cancelar y confirmar antes de
volver a «Lo que necesitas preparar». Se simula el área del teclado en el
diálogo y se comprueba que el campo y las acciones no se solapan. Las capturas
incluyen calentamiento sin foto, sesión combinada con carrera, preparación a
un segundo, reinicio, indicaciones completas y texto doble; no equivalen a una
prueba del teclado nativo en iPhone. Queda repetir el recorrido físico actualizado.

Verificación final del 16/10/2026: análisis limpio, 851 pruebas completas
correctas con la omisión web preexistente, diez escenarios de captura del
ejecutor y el recorrido de reinicio/Movimientos capturado con fuentes reales.
La regresión del reloj comprueba su tamaño natural dentro de un desplazamiento,
incluyendo etiquetas de dos líneas. No se modifican paquetes compartidos,
admin, dependencias, SQL, motores ni producción. Publicación directamente en
main conforme al acuerdo de sincronización.

## Foto adaptable al alto disponible · UI-041 · 16/10/2026

Javier aporta una captura del ejecutor en iPhone 12: la foto tiene poca altura
y queda una zona vacía entre el reloj y la acción fija. La causa es la altura
fija de 110 px en series por tiempo y 140 px en repeticiones, sin asignación del
espacio restante. El criterio pasa a reservar primero el contenido y las
acciones, y entregar el hueco libre a la imagen.

`WorkoutExecutionFrame` permite que su contenido ocupe el alto útil real y
`WorkoutExerciseHeader` expande su imagen dentro de ese espacio. El formulario
activa esta distribución solo cuando hay una foto en la serie en curso. No se
usan nombres de dispositivos ni estimaciones de la altura de campos o textos.
La medida intrínseca se limita a este contenido con imagen flexible; el resto
de paneles conserva su distribución. En pantallas pequeñas se conserva un
mínimo visual de 128 px y se permite desplazar el contenido. Las acciones
permanecen accesibles con teclado o texto ampliado.

La imagen mantiene su proporción y se muestra completa. Tocar la foto o ⓘ
continúa abriendo la ficha compartida de consulta. Solo cambian componentes de
presentación; dominio, persistencia, registro diferido, controles y estado de
los relojes conservan sus contratos.

Las comprobaciones de distribución cubren crecimiento de la imagen con 100 px
adicionales de alto, proximidad del reloj a la acción, título largo/texto doble
y teclado. Las capturas del ejecutor real usan 390 × 844 con áreas reservadas
de 47/34 px y texto normal/ampliado, 412 × 915, 320 px con texto doble y
escritorio; incluyen tiempo, repeticiones y consulta/edición de datos. Son
renders con datos ficticios y la imagen local de referencia, sin publicación
de contenido. No acreditan instalación ni prueba física en Samsung/iPhone.

Verificación del 16/10/2026: análisis limpio, tres regresiones de distribución,
siete escenarios de capturas revisados y batería completa de raíz con 850
pruebas correctas y la omisión web preexistente. Sin cambios en paquetes
compartidos, admin, dependencias, SQL, motores o producción. El siguiente paso
es actualizar desde main y comprobar la misma sesión en el iPhone de Javier.

## Pantalla de entrenamiento modular · UI-040 · 15/10/2026

Javier autoriza implementar UI-037/038/039 y precisa que «repetir» significa
conservar la posibilidad de reiniciar el temporizador, no repetir su objetivo
en varios bloques grandes. Exige Clean Architecture y facilidad para rediseñar,
retirar o sustituir componentes. Implementación y comprobación técnica terminadas;
aceptación en móvil actualizado pendiente.

La pantalla usa «Entrenamiento en curso», cabecera/progreso compactos, foto
cuando existe y acceso a técnica. El formulario ordinario se separa en
`WorkoutSetEntry`; distribución, cabecera y descanso en
`workout_execution_layout.dart`; campos en `workout_result_fields.dart`, esfuerzo
en `workout_effort_field.dart` y listado agrupado en `WorkoutSessionRecords`.
Estos widgets no acceden a preferencias ni a Supabase. Los textos de
presentación se comparten en `workout_execution_labels.dart`.

`ExerciseDetailSheet` reutiliza la ficha de biblioteca: ofrece edición solo
cuando el llamador proporciona esa acción. Desde el entrenamiento se abre como
consulta, sin abandonar la sesión ni cambiar los controles del reloj. Respeta
nombre/descripción/vídeo de la prescripción y usa el catálogo para la imagen y
metadatos accesorios. El reproductor existente sigue bajo demanda; no se
implementan subida, alojamiento ni creación de vídeos.

En repeticiones se mantiene un resultado compacto visible; durante el trabajo
por tiempo se prioriza el reloj y el resultado se revisa al terminar. La acción
«Terminar serie» queda en una franja fija que reserva espacio. Con poco alto,
teclado o ampliación extrema, la zona de acciones también permite desplazarse
sin desbordar. Inicio, pausa, reinicio y repetición del reloj se conservan; el
reinicio compacto devuelve a cero la medición propuesta, sin acreditar el
objetivo como realizado. El final del reloj no confirma automáticamente la serie.

Terminar una serie ordinaria crea primero un borrador recuperable del
dispositivo y empieza el descanso cuando corresponde. El progreso distingue
series terminadas de datos por confirmar. El descanso anticipa el siguiente
paso y los registros muestran su tiempo restante al editar. Confirmar valida
los valores y utiliza el registro idempotente/cola existente, sin reiniciar el
descanso. No se permite finalizar o abandonar conservando lo realizado mientras
haya series terminadas con datos sin confirmar; salir para retomar conserva los
borradores. Los formularios específicos de rendimiento y el agregado AMRAP
conservan sus contratos y reglas; el panel no ofrece corrección por serie de un
agregado AMRAP inmutable.

Los retoques posteriores a un resultado ya enviado se mantienen como borrador
local y se consolidan al cerrar con un motivo de revisión durante el
entrenamiento. Cada escritura en un campo no consume una corrección. Se
conservan el corrector auditable, su necesidad de conexión y sus límites de
24 horas/tres cambios. Un fallo impide el cierre y conserva lo editado para
reintentar. Los datos sin confirmar y los retoques todavía no sincronizados se
recuperan en el mismo dispositivo; no se promete recuperarlos desde otro.

Las capturas de `tools/visual_workout_execution_capture.dart` usan el ejecutor
real con repositorios ficticios, fuentes e iconos reales, móvil de 390 px,
320 px con texto al doble y escritorio. La imagen opcional se proporciona por
`WORKOUT_CAPTURE_IMAGE` y no se incorpora al catálogo ni a los recursos de la
aplicación. No acreditan una sesión autenticada ni instalación en iPhone.

Verificación del 15/10/2026: `flutter analyze --no-pub` sin incidencias y batería
completa de raíz con 811 pruebas correctas y una omisión web preexistente.
Regresiones de terminar sin datos, validación, confirmación sin reiniciar
descanso, recuperación local, esfuerzo cero/ausente, consolidación de retoques,
fallo y reintento del cierre, consulta de técnica y edición al acabar el
descanso. La mezcla de registro diferido/directo no crea un descanso tras la
última serie. Compilación web correcta; cuatro escenarios de captura correctos
con vistas de repeticiones, tiempo, descanso, técnica, registros, edición,
teclado simulado, texto ampliado y escritorio. No se modifican paquetes
compartidos, dependencias, SQL, motores ni producción. El único siguiente
recorrido recomendado de este bloque es comprobar estas vistas con fotos
propias/oficiales y una sesión autenticada en móvil actualizado.

## Descansar y completar los datos · UI-039 · 15/10/2026

Javier responde «sí, eso puede ser una opción» a terminar la serie, empezar el
descanso y poder completar o corregir sus datos durante ese tiempo, y reafirma
que los datos deben poder modificarse. Se recoge como dirección de diseño;
no se interpreta como cierre de todos los detalles ni como flujo implementado.

El recorrido propuesto conserva el resultado editable antes de terminar y
permite completar/corregir después durante la sesión. El reloj de descanso debe
seguir visible al editar. Se distinguirá el objetivo de lo realmente declarado:
los datos pendientes no pueden tratarse silenciosamente como resultados
confirmados. Queda por concretar su persistencia y recuperación, cuándo se
confirman, cómo se revisan al cerrar y qué datos puede usar la adaptación.

También sigue pendiente definir la edición habitual de una sesión abierta
frente al corrector auditable del historial y sus límites actuales. Los formatos
de intervalos, EMOM y AMRAP requieren sus reglas propias; esta dirección no
aprueba completar una serie por el mero final del reloj ni avanzar
automáticamente. No se cambia código ni SQL en esta anotación.

## Nombre y distribución del entrenamiento · UI-038 · 15/10/2026

Javier aprueba el nombre de trabajo «pantalla de entrenamiento» y el título
«Entrenamiento en curso» dentro de la aplicación. La aprobación es de diseño;
el título y la distribución todavía no se han cambiado en código.

También aprueba como base el esquema presentado en la conversación:

- Cabecera compacta con nombre de sesión, progreso y opciones.
- Nombre del ejercicio y posición dentro del entrenamiento.
- Imagen visible y acceso a la ficha de técnica de UI-037.
- Objetivo y esfuerzo prescrito, con una indicación específica si existe.
- Resultado en una zona compacta, sin declarar automáticamente el esfuerzo real.
- Acción «Guardar serie» fija abajo, reservando su espacio.

Se confirma asimismo la propuesta de UI-037: panel de consulta desde la imagen
o el acceso de técnica, conservación de campos y del estado del temporizador al
cerrarlo, edición de ejercicios propios desde la biblioteca y vídeo pendiente.
Corregir resultados durante la sesión y después es un requisito distinto de
editar la definición del ejercicio. El mecanismo concreto de corrección durante
una sesión todavía está por implementar y contrastar.

Quedan por concretar dimensiones finales y adaptación para repeticiones,
tiempo, descanso y los demás formatos existentes. El esquema no cierra las
reglas de avance con datos pendientes. UI-039 concreta posteriormente la
dirección de diseño para empezar el descanso antes de confirmar todos los datos.
Esta anotación registra las aprobaciones y no modifica la aplicación.

### Contraste con los cuatro clips aportados el 15/10/2026

Evidencia revisada, sin nuevas decisiones de implementación. Se han podido
descargar las dos partes recortadas de Calisteniapp
(`20-12-57_1_1_1(1)`, 97,64 s; `20-12-57_1_2(1)`, 87,60 s) y los vídeos de
EntrenaOP `22` (52,72 s, ejercicio por tiempo) y `21` (26,69 s, repeticiones).
Las referencias temporales siguientes corresponden a cada clip recortado,
no al reloj global de la sesión mostrado dentro de la grabación.

- Calisteniapp, primera parte, 00:58–01:12: imagen protagonista, objetivo y
  reloj próximos, posición de serie y acceso a información; el panel de
  registros permanece accesible abajo. Desde 01:14 se abre el detalle técnico
  y después su vídeo. La descripción no ocupa la pantalla de ejecución.
- Calisteniapp, segunda parte, 00:12–00:26: el panel muestra las series del
  ejercicio y permite introducir peso y esfuerzo mientras el descanso sigue
  contando en su cabecera. Se ve pasar el peso a 50 kg y el esfuerzo a 90 %RM.
  Esto acredita edición durante el descanso; no demuestra la política completa
  de corrección de sesiones cerradas, persistencia, offline o límites internos.
- Calisteniapp, segunda parte, 00:26–00:34 y 01:14–01:26: los ejercicios se
  pliegan en el panel de registros y se puede consultar la técnica de otro
  ejercicio. La pantalla de descanso anticipa el siguiente ejercicio/serie.
  El clip incluye gestos de navegación; no se atribuye cada avance a una
  transición automática ni se deduce la política de autoplay.
- EntrenaOP `22`, 00:10–00:16 y 00:44–00:50: se necesita desplazar el contenido
  para alcanzar los controles y el registro, también al llegar al siguiente
  intervalo. Se repiten objetivo de 20 s, reloj y tiempo realizado en bloques
  separados. En 00:26–00:32 el selector de RIR ocupa casi toda la pantalla.
- EntrenaOP `22`, 00:34–00:42, y `21`, desde 00:12: el descanso muestra el reloj
  y las salidas de sesión, sin imagen/objetivo del siguiente paso ni acceso
  visible a revisar las series realizadas. `21`, 00:00–00:10, confirma el mismo
  desplazamiento para registrar repeticiones y esfuerzo.

La comparación refuerza la estructura aprobada y añade una recomendación aún
pendiente: acceso persistente a «Series y registros», con panel ampliable para
consultar/corregir resultados y un reloj de descanso visible al editar. Los
campos de la serie actual pueden seguir compactos en la pantalla principal;
no es necesario trasladar toda la interacción a un panel obligatorio. Se
conserva la ficha de consulta de UI-037 y se propone mantener la imagen sin
superponer texto sobre ella. RIR/RPE se mostrarían según la prescripción, sin
introducir el selector intercambiable RIR/RPE/%RM del referente como nueva
regla deportiva. La modalidad guiada de intervalos debe concretarse por
separado; no se adopta el avance automático como consecuencia del diseño.

Límite técnico comprobado: el corrector actual de resultados completados exige
motivo, opera en línea y admite hasta tres correcciones en 24 horas. Está
reflejado en el repositorio de entrenamientos, las migraciones y
`docs/ARCHITECTURE.md`. Facilitar edición habitual durante una sesión no se
resuelve conectando ese corrector sin cambios de criterio. Igualmente, terminar
una serie con la métrica principal pendiente requeriría revisar el contrato de
registro, recuperación de borradores, cola offline y qué datos usa la adaptación.
Separar «terminar y descansar» de «confirmar datos» era la propuesta pendiente
al revisar los clips; UI-039 recoge después la respuesta de Javier. El detalle
del contrato y su implementación siguen pendientes.

## Ficha durante el entrenamiento y registro corregible · UI-037 · 15/10/2026

Dirección confirmada por Javier; implementación pendiente. La captura de su
ejercicio personal muestra la ficha existente como panel inferior con esquinas
redondeadas, título, cierre, imagen y descripción. Javier confirma que le gusta
este formato sin ocupar toda la pantalla. Se conserva como referencia para
consultar el ejercicio desde el entrenamiento; no se sustituye por una pantalla
completa obligatoria. Javier indica que la ficha todavía está incompleta.

Javier aclara que, al abrirse desde una sesión, el panel será exclusivamente de
consulta y no ofrecerá editar el ejercicio, aunque sea personal. El botón de
la captura pertenece al acceso desde la biblioteca y a un ejercicio creado por
el usuario; no se extiende esa edición a los ejercicios oficiales de EntrenaOP.
También aclara que el vídeo es una tarea futura todavía sin resolver. Los
campos y componentes presentes en el código no acreditan que la carga y
reproducción estén resueltas en el recorrido real. Esta revisión no cierra ni
implementa la gestión de vídeo.

También pide poder registrar los datos al momento y completarlos o corregirlos
después, para evitar que un error quede registrado sin posibilidad de arreglo.
El código ya ofrece correcciones en el historial; queda por concretar cómo
acceder a la revisión durante una sesión en curso y qué datos pueden quedar
pendientes. UI-039 concreta posteriormente la dirección de diseño para iniciar
el descanso antes de confirmar todos los datos. No se acuerda el avance
automático ni completar una serie solo porque termine el reloj.

Propuesta confirmada posteriormente en UI-038: reutilizar el panel desde la
imagen o un acceso de técnica, mostrar el vídeo cuando exista y conservar los campos y el
estado del entrenamiento al cerrarlo. Si falta material multimedia, la consulta
debe seguir siendo útil con el contenido disponible. UI-038 confirma una
distribución base del registro; el tamaño final de la imagen y las transiciones
entre trabajo, registro y descanso siguen en revisión. No se modifica código,
SQL ni motores en este acuerdo documental.

## Series originales; ampliaciones solo en Carreras · UI-034 · 15/10/2026

Javier corrige el alcance de UI-032/033: quiere Series como antes y las
ampliaciones exclusivamente bajo Carreras. Series continúa siendo el grupo
inicial y conserva ritmo objetivo, distancia de serie en metros enteros entre
1 y 2.000, atajos originales y parciales. No muestra selector m/km, selector de
cálculo ni campo de tiempo objetivo. Ritmo va primero; el resultado recupera
«Tiempo de la serie» y los pasos/tramos se expresan en metros. Se conserva el
ejemplo inicial de 400 m a 3:40/km → 1:28.

Carreras conserva distancias libres hasta 100 km, 5 km/10 km/media/maratón,
unidades m/km y Calcular tiempo/Calcular ritmo con horas y precisión exacta de
objetivo. El selector Series/Carreras va al principio de la tarjeta. Ambos grupos
conservan por separado distancia, ritmo y parcial; la selección de unidades y
modo inverso pertenece solo a Carreras. Cambiar de grupo no arrastra kilómetros
o un objetivo inverso a Series, ni borra la serie que el usuario estaba usando.
Carreras abre con 5 km; Series mantiene sus 400 m originales.

El cambio es de presentación y estado temporal de formulario. Se reutiliza el
servicio de dominio ya probado sin modificar el cálculo, las dependencias,
paquetes compartidos, admin, SQL o producción. La precisión del inverso de
Carreras y el redondeo acumulado de los parciales se conservan.

Verificación: análisis limpio, 37 pruebas específicas y 831 de raíz correctas,
con la omisión web existente y código 0. Se comprueban ausencia de ambos
selectores en Series, límite de 2.000 m, entrada original, campos y parciales
independientes, regreso desde Carreras en modo inverso y conservación del
inverso/unidades de Carreras. Capturas de widgets reales con el tema y fuentes
disponibles en Linux revisadas en 390 px y 320 px con texto al doble. Queda
pendiente la aceptación del recorrido corregido en el dispositivo actualizado.

## Calculadora de ritmos: tiempo objetivo · UI-033 · 15/10/2026

UI-034 limita esta ampliación a Carreras; Series vuelve al funcionamiento original.

Tras actualizar Windows, Javier confirma que aparecen Series/Carreras y pide
obtener el ritmo a partir de una distancia y un tiempo final. Aprueba mostrar
un selector «Cálculo», con «Calcular tiempo» como opción inicial y
«Calcular ritmo» como alternativa. La distancia y sus atajos van primero;
después aparece el selector y un único campo activo: ritmo o tiempo objetivo.

El modo inicial conserva el ejemplo de 400 m a 3:40/km y destaca el tiempo final.
El inverso empieza con el tiempo vacío, sin error ni resultado hasta completarlo,
y destaca «Ritmo necesario». Solo el campo activo alimenta el cálculo; cambiar
el modo conserva ambos borradores y cierra el teclado. No se sincronizan dos
campos editables entre sí. Las distancias y los parciales de UI-032 se conservan.

Tiempo objetivo utiliza la entrada de reloj existente: `4500` → `45:00`,
`620` → `06:20`, `33000` → `03:30:00`; también se permite escribir o pegar los
dos puntos. La ayuda explica min:seg y horas:min:seg. Vaciar el campo deja el
resultado pendiente; cero o segundos/minutos internos inválidos muestran error.
Ejemplos: 10 km en 45:00 → 4:30/km; 2 km en 6:20 → 3:10/km.

La operación inversa reside en `RunningPaceCalculator`, independiente de Flutter.
El resultado conserva el ritmo como segundos por kilómetro con decimales;
los parciales se calculan proporcionalmente desde los segundos objetivo y la
última meta conserva ese entero exacto. Redondear el ritmo para mostrarlo no
recalcula el tiempo final. Cuando corresponde, se muestra «≈» y una nota breve
que explica que el ritmo está aproximado al segundo y que los parciales
conservan el objetivo. El resumen muestra distancia y tiempo objetivo.
No se prescriben ritmos ni se predice rendimiento; no cambia el backend.

Verificación en Linux cloud: análisis sin incidencias y 830 pruebas de raíz
correctas, con la omisión web existente y código 0. Las 36 pruebas específicas
incluyen ambos ejemplos, horas, redondeo de ritmo con conservación del objetivo,
media maratón con tramo final decimal, entradas inválidas, borradores, cambio
de distancia/unidad y ambos modos en 320/390/1.000 px. Capturas de widgets reales
con el tema de EntrenaOP y fuentes disponibles en Linux revisadas en 390 px y
320 px con texto al doble; el selector permite varias líneas cuando hace falta.
No cambian dependencias, paquetes compartidos, admin, SQL ni producción.
La aceptación física del modo nuevo queda pendiente tras actualizar la app.

## Calculadora de ritmos: series y carreras · UI-032 · 15/10/2026

UI-034 conserva las ampliaciones de este apartado solo en Carreras y restablece
el límite y la entrada originales de Series.

Javier aprueba ampliar la herramienta conservando entrada libre y atajos.
«Series» es el grupo inicial y conserva todas las distancias anteriores, de
100 a 2.000 m, con el ejemplo de 400 m a 3:40/km. «Carreras» muestra 5 km,
10 km, Media maratón y Maratón. Se utilizan 21.097,5 m y 42.195 m exactos,
incluido el último tramo incompleto; no se redondean a 21 o 42 km.

El campo permite metros o kilómetros, coma o punto decimal, con resolución de
0,1 m (cuatro decimales en km). Cambiar la unidad o el grupo convierte el valor
sin cambiar la distancia; editarlo sigue funcionando aunque no coincida con un
atajo. El límite operativo elegido para esta ampliación es de 1 m a 100 km,
mostrado en la ayuda y validado también en el dominio.

Los parciales automáticos de pista se conservan hasta 2.000 m; por encima se
utiliza 1 km, con selección manual cada 1 o 5 km cuando cabe un paso intermedio.
Al cambiar la distancia se descarta un parcial manual incompatible. Los tiempos
se muestran en minutos y segundos y pasan a horas:minutos:segundos desde una
hora; se redondea cada paso acumulado para que los tramos sumen el tiempo final.
El resultado se llama «Tiempo total» y los textos abarcan tanto series como
carreras. La herramienta calcula un tiempo a ritmo constante: no predice una
marca posible ni prescribe ritmos de entrenamiento.

El cálculo, la validación de distancia y la selección automática de parciales
permanecen en dominio, sin dependencias de Flutter. La presentación conserva
entrada, conversión de unidades y formato. Con poco ancho o texto ampliado,
los parciales pasan de tres columnas a bloques verticales para conservar
la lectura de etiquetas y tiempos.

Verificación en Linux cloud: `flutter analyze --no-pub` limpio y
`flutter test --no-pub --reporter expanded` con 816 pruebas correctas y la
omisión web existente (código 0 en ambos). Las 22 pruebas de ritmos cubren las
cuatro distancias, la suma de tramos redondeados, el último medio metro de la
media maratón, límites, entrada libre, cambios de unidad/parcial y distribución
en 320/390/1.000 px. Capturas de widgets reales con el tema y fuentes
disponibles en Linux revisadas en 390 px y en 320 px con texto al doble.

Javier confirma que aparecen Series/Carreras tras incorporar `0d3f436` desde
Windows; esa confirmación no acredita todavía el nuevo modo inverso UI-033.
La comprobación física en Android/iPhone se realiza después de traer el commit
y volver a instalar desde cada equipo, según `docs/CLOUD_DEVELOPMENT.md`.

## Fotos de ejercicios y acción fija · UI-030 · 14/10/2026

Javier pide adaptar dos comportamientos de su referencia de Calisthenia App,
conservando la identidad de EntrenaOP. La vista previa de una sesión muestra
una miniatura de 64 × 64 junto al nombre cuando el ejercicio tiene foto. La
numeración y las posiciones de circuito/superserie siguen visibles; sin foto
se conserva el indicador de posición. Una descarga fallida utiliza un icono
neutro, sin impedir consultar instrucciones ni empezar.

La acción principal permanece en una franja inferior fija con área segura.
El contenido reserva su espacio: no es un botón superpuesto al último ejercicio.
Se conserva «Empezar sesión» para fuerza y «Registrar resultado» para carrera.
Durante el inicio se deshabilita para evitar doble pulsación y, si falla,
ofrece reintentar sin perder la sesión. Las vistas dedicadas y el retorno
al origen de UI-028 no cambian.

Las fotos son información accesoria del catálogo actual, no parte de la
prescripción histórica. Se consultan por ejercicio sin retrasar la sesión,
reutilizando los permisos y las URLs públicas/firmadas existentes. No se
añaden fotos a ejercicios que todavía no las tengan ni se modifica el admin.

Verificación: análisis sin incidencias, 791 pruebas de raíz correctas y una
omisión web existente; web compilada. Regresiones de carga tardía/fallida,
reintento, doble inicio y navegación; capturas de la vista actual al inicio
y al final en 390 px, 320 px con texto al doble y escritorio de 1000 px.
Las capturas de distribución no incluyen fotos reales; la conexión de URL
y el fallback se prueban con datos ficticios. Queda la aceptación en un
dispositivo actualizado con ejercicios oficiales y propios que tengan foto.

## Agilidad y calculadora FAS en iPhone · UI-031 · 14/10/2026

Javier corrige la uniformidad de UI-029: la agilidad de Tropa y FAS se introduce
siempre en segundos decimales. El ejemplo es `00,00`; `15,27` representa
15,27 segundos. Se admite también punto decimal y se conservan las cifras
introducidas y el cursor al corregirlas. No se convierte a reloj ni se fuerza
un redondeo de la marca original. El control deslizante de FAS sigue trabajando
con décimas, conforme a su resolución anterior.

Javier confirma el funcionamiento corregido pero pide conservar la distribución
anterior mostrada en Android. La calculadora recupera las cuatro tarjetas en
dos columnas en el ancho del iPhone 12 y las unidades dentro del campo. Los
valores parten de tamaño 20 y se ajustan al ancho real disponible tras reservar
la unidad, el cursor y el padding; puntos por prueba 16 y resumen 28. Se conserva
la proporción anterior de las tarjetas en dos columnas. Solo se usa una columna
con menos de 330 px disponibles o texto ampliado a 1,6 o más. La escala
se mide sobre una fuente de 16 puntos, conservando dos columnas y H/M
horizontales con ampliación moderada. El umbral anterior de 1,2 activaba una
columna en el iPhone físico de Javier y se corrige en IOS-007.

Al volver, abrir historial, seleccionar fecha, guardar o usar un deslizador se
cierra el teclado; arrastrar la lista o tocar fuera del campo también permite
descartarlo.

Verificación: análisis limpio y 799 pruebas de raíz correctas, con la omisión
web existente. Las regresiones comprueban escritura decimal por dígitos y
corrección intermedia sin mover el cursor, guardado en milisegundos en Tropa/FAS,
tarjetas en dos columnas a 390 px, campos sin desplazamiento horizontal en
390/320/800 px, texto a 1,3 (dos columnas) y al doble,
y retorno mediante `go_router` con el teclado oculto. Cuatro capturas de widgets
con fuentes reales revisadas en 390/320 px, texto a 1,3 y al doble; compilación iOS
Release de desarrollo sin firma correcta. Posteriormente Xcode firma la
versión, se instala por reemplazo y arranca sin depurador en Iphone-JVR
(`docs/IOS_DEVELOPMENT.md`). En IOS-007 Device Hub acredita en el iPhone
físico cuatro tarjetas en dos columnas, H/M horizontales y valores completos
de plancha/carrera `05:50` y agilidad `12,05 s`. La aceptación estética de
Javier sigue pendiente; la distribución y el arranque están observados.
Se conservan baremos, cálculo,
contratos de datos y el formato de las demás duraciones.

## Entrada uniforme de tiempos · UI-029 · 14/10/2026

Los campos de duración/ritmo expresados en segundos utilizan reloj `00:00`
(minutos:segundos). Teclear `30` muestra `00:30`; `130` muestra `01:30`;
`1130` muestra `11:30`. No se necesita escribir dos puntos en el teclado móvil.
Los dos puntos explícitos y el pegado siguen admitidos. La entrada larga
conserva el soporte de horas del control existente.

Las mediciones precisas admiten coma o punto en la fracción, por ejemplo
`00:15.250`. No se redondea el valor deportivo al presentarlo. Los valores
precargados se convierten desde segundos reales: 90 se muestra como `01:30`,
no se pasa por la máscara abreviada como si fuese texto tecleado.

Áreas cubiertas:

- Tropa: plancha y carrera; FAS: duración de plancha y tiempo de carrera en
  cálculo y registro periódico. Agilidad conserva segundos decimales (UI-031).
- Evaluaciones de cualquier programa y sus intentos, conservando resolución.
- Referencias, metas y resultados de rendimiento, contacto y penalizaciones.
- Carrera: meta, margen oficial, control 2 km y parciales, calculadora de ritmos,
  simulador, creación de sesiones, trabajo/recuperación y corrección de historial.
- Fuerza: duración de serie, descanso de serie/estación/ronda y límite AMRAP.
- Admin: los mismos editores, simulación de evaluación, mínimos, extremos de
  baremos y resolución temporal de pruebas; registros/referencias del laboratorio.
  La importación de baremos acepta reloj además de segundos numéricos antiguos.

El componente compartido vive en `workout_editor_ui`. `StrengthSetFields`
conserva su contrato de callbacks en segundos cuando ese era su contrato:
la máscara es de presentación. No se cambian motor, esquema, RPC, permisos,
datos anteriores ni unidades almacenadas. Se mantienen límites y restricciones
enteras previas, incluida la plancha entera de la calculadora y los minutos
completos del límite AMRAP personal. Disponibilidad y estimaciones que preguntan
minutos completos siguen preguntando minutos; no son campos de segundos.

Verificación del 14/10/2026: análisis limpio en deportista y admin; 781 pruebas
de raíz, 109 del admin y nueve de `workout_editor_ui` correctas, con las dos
omisiones optativas existentes. Ambas webs compilan. Las pruebas nuevas
comprueban escritura por dígitos, borrado completo, pegado/reemplazo, fracciones,
equivalencia del resultado real de Tropa y del editor compartido, importación
de relojes y corrección de una entrada inválida sin colapsar el laboratorio.
No acredita teclado físico Android/iOS ni instalación de una versión nueva
en el móvil. Sin cambios SQL, no se ejecutan baterías SQL nuevas.

## Pro: recorrido y contratación · COM-004/006 · 10/10/2026

Los precios de lanzamiento de COM-004 están acordados: 3,99 €/mes y 29,99 €/año
por el mismo acceso Pro. Javier aprueba la composición y el recorrido y pide
implementar primero la interfaz, después conectar pagos. La fase inicial se
describe en [Pro y pagos](PRO_LAUNCH.md): añade descubrimiento y oferta con compra
deshabilitada, conserva tarjetas fotográficas y accesos de desarrollo y no
recupera COM-002/003. La autorización comercial de servidor queda pendiente.

La oferta explicará el beneficio de la planificación adaptativa con las marcas,
objetivo, disponibilidad, material y resultados del usuario. No anunciará como
incluidas capacidades cuyo reparto comercial esté pendiente, seguimiento humano
ni pruebas gratuitas que no se hayan acordado.

Se propone una pantalla dedicada con cierre visible, tres beneficios breves y
dos opciones legibles: mensual a 3,99 €/mes y anual a 29,99 €/año. Destacar el anual
por ahorro no debe ocultar la alternativa mensual. El anual mostrará «Ahorra
37 % respecto a 12 mensualidades», con 2,50 €/mes como dato secundario; doce
mensualidades suman 47,88 €, por lo que el ahorro exacto es 17,89 €. El total
anual será más relevante que su equivalente mensual. Referencia:
[instrucciones de Apple](https://developer.apple.com/app-store/subscriptions/).

El botón y las condiciones deben corresponder a la modalidad elegida. Si se
habilita la renovación automática aceptada en el diseño, se explicarán importe,
periodicidad y que cancelar la renovación conserva el acceso durante el periodo
contratado. La
pantalla deberá ofrecer restauración de compras, condiciones y privacidad.
El diseño aceptado incluye renovación automática; no acredita integración con
una tienda ni sustituye sus condiciones contractuales definitivas.

Desde una función Pro, el usuario podrá entender qué ofrece antes de contratar.
La propuesta conserva una sola app y las cinco secciones actuales. Mi plan
permite consultar las preparaciones y usar la agenda incluida; el acceso al
programa adaptativo lleva la etiqueta «Pro» y el candado en su acción. La ficha
mantiene la fotografía y los datos propios de la preparación. Consultarla no
obliga a contratar. «Ver un ejemplo» muestra contenido didáctico identificado,
sin presentar una semana generada para ese usuario ni iniciar un programa.

«Crear mi plan · Pro» abre directamente la pantalla común de contratación,
conservando la preparación y el punto de origen, sin encadenar otro diálogo de
venta. Cerrar o seguir con Free devuelve a ese punto. Con Pro verificado, la
misma acción continúa la configuración existente y la venta desaparece; comprar
no sustituye completar los datos y aceptar la propuesta de entrenamiento.
Perfil ofrece el estado de suscripción y su gestión. Una compra pendiente o un
fallo al comprobar el acceso muestra su estado y permite reintentar o restaurar,
sin clasificar automáticamente al usuario como Free ni pedirle pagar otra vez.

La generación y adaptación se protegerán en servidor; el candado es su señal
visual. Mi semana, sesiones manuales incluidas e historial no quedan cubiertos
por un bloqueo global de Mi plan. Una contratación confirmada devolverá al punto
de origen para continuar la revisión; no activará ni sustituirá un programa sin
la aceptación correspondiente. Este recorrido está aprobado; la conexión y los
derechos de servidor quedan para la fase siguiente.

El posible descuento militar de COM-005 queda aplazado expresamente por Javier
y fuera del diseño inicial. Las maquetas de conversación no prueban código real,
accesibilidad, derechos comerciales ni compras. COM-006 incorpora la interfaz
Flutter, con su alcance y verificación en PRO_LAUNCH.md.

## Barra móvil y vista de sesión dedicada · UI-028 · 10/10/2026

Javier aporta una captura de su iPhone 12 donde Biblioteca y Evolución casi
se tocan. Las cinco pestañas conservan sus nombres, iconos, selección y
destinos. La barra reserva 6 px a cada lado de cada etiqueta y mide la más
ancha con el estilo seleccionado para adaptar el tamaño solo cuando falta
espacio. Se conserva el límite de ampliación propio de NavigationBar; el
texto del contenido no se reduce. Los nombres permanecen completos en una
línea, con las mismas áreas táctiles, etiquetas accesibles y tooltips.

La petición de ocultar la barra se aplica a «Vista de la sesión», tanto en
Biblioteca como en la sesión inicial. Estas consultas se abren en el navegador
raíz mediante go_router, conservando sus URLs y los hijos de edición/ejecución.
No muestran barra inferior ni rail. «Volver» recupera el origen de la pila;
una entrada directa de la sesión inicial, sin página anterior, abre Biblioteca.
El ejecutor ya era una pantalla dedicada y conserva su protección de salida.
Este criterio amplía UI-007 a la vista previa sin añadir un aviso de cambios
pendientes a una consulta ni modificar datos o reglas del entrenamiento.

Verificación: análisis limpio, 65 pruebas relacionadas y 752 completas correctas
con la omisión web existente. Regresiones a 320/390 px y texto 1×/2× comprueban
etiquetas completas y separadas al seleccionar Biblioteca/Evolución. El router
real verifica vista previa sin barra/rail, enlaces directos y retorno conservando
búsqueda en móvil/escritorio. Tres capturas adicionales de widgets actuales con
fuentes e iconos reales se revisan a 390 px (1×/1,3×) y 320 px (2×), sin cuentas
ni red. Xcode compila, instala y ejecuta también la versión Release sin depurador
en el iPhone 12 de Javier con Supabase de desarrollo; el esquema compartido
vuelve a Debug después. La revisión visual de estos dos ajustes en el dispositivo
por Javier queda pendiente; no se confunde con las capturas de widgets.

## Accesos depurados · UI-026 · 10/10/2026

Las tarjetas fotográficas de preparación mantienen su diseño y ofrecen una
única entrada «Ver preparación», confirmada por Javier. Este cambio sustituye
solo el nombre y la duplicación de accesos que UI-009 pedía conservar; no
reactiva ninguna composición comercial descartada. Programa, fecha, marcas y
resultados siguen en el detalle. El programa activo conserva su entrada
contextual. Favoritos: Mis sesiones, Mis ejercicios y Disponibilidad; las
herramientas y pestañas conservan sus destinos sin repetirse como favoritos.
Biblioteca conserva su pestaña y Herramientas sus dos tarjetas.
[Recorrido, preferencias antiguas y verificación](UX_REVIEW_2026_10_09.md).

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

**UI-027 · 10/10/2026:** Javier pide sustituir el texto normal «EntrenaOP Pro»
de la cabecera de contratación por el wordmark existente, con «Pro» plateado e
inclinado como distintivo independiente. Precisa que la tipografía de marca
se reserva para referencias a EntrenaOP, no para todos los textos. Precios,
botones, explicaciones y títulos funcionales mantienen el tema actual.

`ProBrandTitle` reutiliza `EntrenaWordmark`, adapta su variante al fondo y
escala la composición al espacio de la cabecera. «Pro» usa cursiva y un tono
plateado, con una variante más oscura para conservar contraste en fondo claro.
La composición tiene una única etiqueta accesible «EntrenaOP Pro».
No se modifica el paquete compartido ni el PNG de marca. En el repositorio no
se ha encontrado una fuente instalable de la marca: los recursos disponibles
son imágenes, no un alfabeto tipográfico. Javier intentará localizar la fuente;
su incorporación futura quedaría restringida a usos de marca y requerirá
comprobar el archivo y su licencia. No se atribuye un nombre de fuente a partir
de la apariencia del logo ni se presenta la cursiva de Pro como esa fuente.

Las ocho pruebas de Pro existentes verifican navegación y ausencia de
desbordamiento a 320 px con texto doble; se revisa la captura real de la cabecera,
esperando la decodificación del PNG antes de capturar. Análisis limpio y 726
pruebas completas correctas con la omisión web existente. El cambio se limita a
presentación en la app del deportista, sin modificar fuentes globales, paquetes,
admin, algoritmos, datos o derechos comerciales.

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

## Botones y decisiones de continuidad (15/10/2026 · UI-036)

Javier confirma que continuar el entrenamiento debe ser la acción más visible
en las decisiones de salida. `entrena_ui` mantiene Material 3 como base de
interacción y accesibilidad y define una familia común para deportista y admin:
radio de 16 px, iconos de 20 px y espaciados coherentes. Las acciones rellenas y
con borde tienen altura mínima de 52 px; el texto puede aumentar su altura.
Los enlaces conservan un objetivo táctil mínimo de 48 px.

El naranja sólido identifica la acción principal. Los secundarios usan texto
claro, superficie oscura y borde neutro; dejan de repetir el naranja del botón
principal. El foco de teclado sigue visible. El descarte usa el color semántico
de error en texto/borde y un fondo tenue, con estado deshabilitado diferenciado.
No se añaden paquetes, efectos ornamentales ni colores por pantalla.

`EntrenaDialog` limita las decisiones a 480 px de ancho en escritorio, deja
márgenes laterales de 20 px en móvil y permite desplazar el contenido con texto
ampliado. `EntrenaDialogActions` presenta la acción principal primero, con
altura mínima de 56 px; las alternativas comparten ancho y separación de 10 px.
Los formularios administrativos grandes conservan su composición propia.

En fuerza y carrera, la salida ofrece **Continuar**, **Salir y retomar después**,
**Finalizar y conservar lo realizado** y **Descartar sesión**, en ese orden.
Se retira la bandera. El descarte y el cierre anticipado vuelven a ofrecer
Continuar como acción principal; el cierre anticipado sigue exigiendo un motivo.
Cambian los textos y la presentación, pero el cierre no se convierte en sesión
completada y el descarte mantiene su confirmación y requisito de conexión.
Se conservan las series, borradores y descansos al cancelar o ante un fallo.
UI-036 actualiza los textos visuales anteriores de UI-020/UI-022.

Los avisos de **Sonido y vibración** muestran dos pruebas con igual tamaño y
separación. Se mantiene el resumen de primer plano/volumen y el detalle de
intervalos y permisos Android pasa a «Cómo funcionan los avisos». Probar sigue
sin guardar preferencias; cancelar no cambia las guardadas. Patrones, permisos
y sincronización de avisos se conservan.

La misma jerarquía se aplica a la salida protegida de formularios, recuperar
borradores, eliminar bloques, reiniciar ensayos y los descartes/borrados de
portadas, pruebas, mínimos y sesiones del admin. Biblioteca hereda los botones
secundarios sin una excepción local naranja. Las rutas, autorizaciones y
operaciones de servidor se mantienen.

Validación del resultado consolidado: análisis limpio en raíz y admin; 850
pruebas correctas en la ejecución conjunta de app (835), entrena_ui (6) y editor
(9), y 109 correctas en admin. Se conservan una omisión web de raíz y una captura
optativa omitida del admin. Se comprueban navegación, continuación, descarte,
fallos/reintentos, guardado de preferencias, recuperación de borradores y texto
al doble. Los botones de prueba reservan la altura de la etiqueta más larga,
también durante «Probando…», para mantener el mismo tamaño sin cortar texto.

Revisados doce renders con fuentes e iconos reales a 390 px, 320 px con texto al
doble y 1100 px. Se conservan [salida](visual-audit/buttons-2026-10-15/salida-390.png),
[descarte](visual-audit/buttons-2026-10-15/descarte-390.png),
[cierre anticipado](visual-audit/buttons-2026-10-15/finalizar-390.png),
[avisos](visual-audit/buttons-2026-10-15/avisos-390.png) y
[escritorio](visual-audit/buttons-2026-10-15/salida-1100.png), con manifiesto de
procedencia y huellas de código. La aceptación en dispositivos actualizados
queda pendiente; las capturas usan widgets reales y datos ficticios, sin cuentas remotas.

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
3. Preparaciones, conservando su papel central y una entrada «Ver preparación».
4. Herramientas para tus pruebas: Ritmos y PAEF/PAFAS visibles simultáneamente.
5. Favoritos personales, si el usuario los utiliza. Biblioteca conserva su
   pestaña y no se repite como tarjeta de Inicio desde UI-026 (10/10/2026).

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
El bloque de Inicio conserva un acceso estable a las herramientas; Biblioteca
tiene su pestaña. Desde el cierre de Inicio/Mi plan de UI-008, el contenido disponible
y personal se gestiona en Biblioteca, sin repetir sus entradas en Mi plan.

UI-026 depura los favoritos a Mis sesiones, Mis ejercicios y Disponibilidad;
permite elegirlos y ordenarlos, sin añadir un cuarto destino por rellenar. No
reorganizan los bloques de Inicio ni son el único acceso a ninguna función.
`HomeFavoritesRepository` separa el contrato de su adaptador local con
`shared_preferences`, ya disponible en el proyecto. La clave incluye la cuenta:
no comparte selección entre usuarios del dispositivo. No hay sincronización
entre dispositivos ni cambios en Supabase. Cancelar no guarda; un error al
guardar conserva la selección anterior. Una selección vacía se respeta.

Herramientas tiene un destino propio `/tools`, sin ocupar una pestaña principal;
se mantiene para enlaces y Perfil y conserva el retorno al origen. Inicio
muestra directamente Ritmos y PAEF/PAFAS sin un «Ver todas» que repita esas dos
tarjetas. Conservan sus pantallas y cálculos existentes. Crear ejercicio sigue
disponible dentro de Mis ejercicios y Biblioteca. La sesión inicial de
EntrenaOP tiene un acceso opcional en Biblioteca, identificado como demostración.
Mis sesiones usa `/plan/library?tab=personal` y abre directamente la pestaña
personal, sin mezclarla con las sesiones públicas.
Mis ejercicios usa `/library/exercises?tab=personal`. Al leer los favoritos
antiguos, Crear ejercicio pasa a Mis ejercicios y se retiran Mi semana, Marcas
y pruebas, Ritmos, PAEF/PAFAS y Biblioteca; se conserva el orden restante, la
selección vacía y la separación por cuenta. No se rellenan huecos automáticamente.

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

Desde UI-035 (15/10/2026), la portada `/library` presenta dos pestañas:
**Sesiones** a la izquierda, seleccionada al abrir, y **Ejercicios** a la derecha.
Usan el mismo componente y estilo que EntrenaOP/Mis sesiones, con indicador
naranja. Se cambia tocando el título o deslizando lateralmente, sin recorrer las
tarjetas de sesiones para llegar a ejercicios. La cabecera y el selector
permanecen visibles; cada panel conserva su desplazamiento vertical de forma
independiente. Cada pestaña separa el catálogo EntrenaOP de la colección del
usuario. Solo sesiones EntrenaOP
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

Verificación de UI-035 (15/10/2026): `flutter analyze` sin incidencias y 800
pruebas de raíz correctas, con una omisión web preexistente. Se comprueban el
cambio por toque y deslizamiento, móvil de 320 px, escritorio de 1100 px, texto
al doble, los cuatro accesos a colecciones y crear/cancelar/guardar ejercicios y
sesiones. La prueba de rutas usa también el creador real de ejercicios.
La aceptación visual en el móvil actualizado queda pendiente.

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

El título de las calculadoras es «Herramientas». UI-026 (10/10/2026) aplica la
retirada de la tarjeta grande de Biblioteca en Inicio por duplicar su pestaña,
y depura los favoritos. Conserva los destinos y las imágenes existentes.

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

## Portadas legibles en las listas de ejercicios · UI-049 · 18/10/2026

Descartada por Javier; el criterio vigente es UI-050, descrito a continuación.

Javier compara ADMIN y app y pide ampliar la foto de la tarjeta. La portada
seleccionada y guardada en ADMIN es la misma que consulta la app mediante
image_path/thumbnailUrl; no existe otra portada independiente en el listado.

Las listas oficial y personal pasan de 72×72 a 128×96 px, con imagen completa
sin recortes. Bajo 300 px de ancho útil o con escala de texto superior a 1,5×,
la imagen pasa encima del texto a ancho disponible y proporción 16:9. El título,
el acceso al detalle y los permisos se conservan. La ampliación usa la imagen
ya disponible; no carga ni reproduce el vídeo.

Comprobada en web a 390 px con la portada elegida de las flexiones. Las doce
pruebas del listado pasan, incluida la foto común en lista/ficha, el error de
imagen y el caso de 320 px con texto doble. Aceptación en móvil físico pendiente.

## Tarjeta compacta y portada limpia · UI-050 · 18/10/2026

Javier descarta la ampliación y apilado de UI-049: prefiere la estética anterior
con un aumento discreto, como ADMIN. Se restaura la fila con foto a la izquierda,
texto y flecha, sin variante apilada. Miniatura de 80×60 px, radio de 10 px y
BoxFit.cover como ADMIN; la ficha conserva la imagen completa.

Javier pide después retirar la descripción de la tarjeta para reducir su alto.
El listado conserva foto, nombre, «Ver ejercicio» y flecha, con margen vertical
de 10 px. El alto normal queda determinado por la foto de 60 px más los márgenes;
los nombres largos y texto ampliado pueden crecer sin cortarse. La descripción
completa se conserva al abrir la ficha. Análisis limpio y doce pruebas de listado
correctas, incluyendo esta separación y el caso de 320 px con texto doble.

En la portada del vídeo se retiran el texto central, el fondo circular y la
capa oscura global. Solo aparece Play blanco con fondo transparente y sombra
discreta en la esquina inferior derecha. Durante la carga aparece el indicador
y ante fallo el icono de reintento en esa esquina. La portada completa sigue
pulsable y conserva las etiquetas del lector de pantalla. No cambian audio,
reproducción bajo demanda, controles posteriores, datos ni permisos.
