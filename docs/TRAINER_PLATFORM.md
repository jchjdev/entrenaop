# Plataforma para preparadores · alcance acordado · 21/10/2026

## Inventario y siguiente bloque · 29/10/2026

### Agenda y seguimiento directo · 31/10/2026

Javier aprueba pulir Agenda → alumno → resultados empezando por la asignación
directa y el detalle lateral. El recorrido de biblioteca/arrastre reúne alumno,
sesión seleccionada, fecha e indicaciones en una sola confirmación. Si Agenda
está filtrada por alumno, se verifica su vínculo activo y se preselecciona sin
abrir otro selector. No se cambia silenciosamente a otro alumno si ese vínculo
terminó. La selección mantiene paginación explícita y búsqueda entre los alumnos
cargados; «Para mí» usa el vínculo existente, sin crear otro ni ocupar plaza.
La sesión/versión elegida no vuelve a consultar la biblioteca salvo al pulsar
«Cambiar sesión». Una respuesta incierta congela los datos y conserva el UUID
para reintentar. Cancelar no escribe ni recarga Agenda.

Las sesiones del calendario abren un panel a la derecha, con receta de la
versión asignada y resultados cargados bajo demanda mediante los lectores
existentes. En pantallas estrechas se presenta como hoja inferior. Se conserva
el detalle completo para revisión, técnica y conversación. Mover, adaptar y
retirar mantienen sus operaciones y confirmaciones; no se ofrecen para sesiones
ya iniciadas. Las sesiones recibidas de otro preparador utilizan el mismo panel
en solo lectura y su lector autorizado, sin acciones de edición.

La agenda queda montada bajo el panel. Cerrar no reinicia su periodo, filtros ni
desplazamiento. Abrir ficha o resultado completo usa navegación apilada; al
volver se actualizan los datos conservando el contexto. La ficha de la lista
también ofrece «Ver detalle». No se modifican ADMIN, la app del deportista,
datos, permisos, dependencias ni algoritmos en este tramo.

Validación local del 31/10: análisis Trainer limpio y 374 pruebas correctas,
incluidas 12 regresiones del recorrido. Se comprueban cancelación sin escritura
ni recarga, destinatario inactivo, reintento con el mismo UUID, retirada con
confirmación, receta/resultados dentro del panel y vuelta a la misma semana,
filtros y scroll. Las capturas de los componentes reales se revisan en claro y
oscuro, 320/1440 px y texto 2×; ambas pestañas caben sin desbordamientos. La
aceptación de Javier en el portal publicado queda como siguiente comprobación.

Publicación automática Dev comprobada el 31/10: revisión `86474cbb`,
[ejecución 41145285326](https://github.com/jchjdev/entrenaop/actions/runs/41145285326)
correcta en validación, compilación y despliegue. Verificación HTTPS independiente
del manifiesto, identidad Dev (`sxbxfjqgoddzhtcyhalw`), revisión, SHA-256 del
JavaScript, entrada activa, cabeceras sin caché y MIME WebAssembly. La publicación
no incluye cambios de ADMIN ni genera una nueva versión móvil.

### Ficha, resultados y revisión continua · 31/10/2026

Se completa el recorrido propuesto, junto a la asignación directa y el panel
de Agenda ya publicados. La cabecera de planificación muestra nombre, estado
del servicio, semana seleccionada, pautas visibles de fuerza/carrera y realizadas.
Muestra una pendiente con acceso a su receta y permite desplegar más. Objetivo
de oposición y fecha conservan el lector/editor existentes, con marcas
desplegables en la vista compacta; en escritorio aprovechan las columnas del
espacio profesional. Una semana incompleta o con fallo de lectura compartida
se identifica como parcial. No se presume que lo no cargado no exista.

El acceso de pendientes consulta la bandeja autorizada existente. El contador es
por alumno y, si quedan páginas, se expresa como mínimo cargado. La bandeja
admite filtro por alumno manteniendo el cursor bruto de servidor y carga
explícita. Un listado parcial sin coincidencias no se presenta como ausencia de
resultados. Cambiar entre áreas del alumno sustituye solo la ficha superior,
conserva el origen de navegación y respeta sus guardas de salida. La entrada
directa mantiene su comportamiento por URL, sin inventar una agenda anterior.

`ReviewExecutionSummary`, en `workout_core`, proyecta las instantáneas de revisión
existentes. Separa posiciones completadas, omitidas y sin completar; entre las
completadas distingue medidas comparables dentro de pauta, diferencias, medidas
ausentes, condiciones a revisar y ausencia de referencia. Reutiliza las
tolerancias del revisor y el tiempo observado de dispositivo; cero repeticiones
no es una ausencia. No asigna calificaciones. Los AMRAP se cuentan por bloques
con rondas registradas o sin agregado, excluyendo su receta de las series
ejecutadas. `WorkoutExecutionSummary`, en `workout_editor_ui`, coloca este resumen
antes de métricas, gráficos y detalle, con el mismo componente para Trainer y
consulta profesional móvil. El filtro de diferencias no altera el resumen de
la ejecución completa.

El detalle identifica al alumno y la fecha de pauta; contrasta el alumno de la
URL con el contexto autorizado y la ejecución. Permite comentar por la relación
confirmada o revisar con nota interna privada. «Revisar y siguiente» conserva el
diálogo retenido, UUID y revisión observada. Solo después de confirmar se recarga
el resultado: si hay una corrección nueva sin revisar, permanece abierto y avisa.
Desde la ficha continúa con ese alumno; desde la bandeja general conserva el
alcance global. Nunca marca la siguiente pauta automáticamente. Sustituir el
detalle mantiene debajo la agenda, ficha o bandeja inicial. Si una página de
100 no contiene un siguiente compatible, se ofrece continuar cargando con su
cursor original; solo una página final permite informar de fin de selección.
El fallo de carga posterior no deshace ni repite un guardado confirmado.

El diálogo de revisión y el detalle estrecho admiten desplazamiento con texto
ampliado. No se modifican algoritmos, derechos, datos del alumno, esquema,
contratos SQL ni dependencias. Los cambios de fotos de perfil en curso se
mantienen aparte; no forman parte de este bloque.

Validación local del 31/10: análisis limpios de raíz, Trainer, ADMIN y editor
compartido. Baterías completas: raíz 1.517 pruebas correctas (una omisión previa),
Trainer 390 y ADMIN 365 (dos omisiones previas). Se valida en una copia aislada
de `dd7521c8`, conservando el trabajo paralelo. Siete casos de dominio y cuatro
de presentación compartida cubren mediciones ausentes, cero, temporizador,
tolerancias y AMRAP. Dieciséis regresiones nuevas de Trainer cubren guardado,
correcciones, paginación, alcance por alumno/global, comentario, guardas de salida,
retorno al origen, objetivo compacto y conservación del contenido/scroll al
recargar. Capturas de la ficha real y resultados revisadas; móvil/escritorio,
temas claro/oscuro y texto ampliado comprobados en los componentes afectados.
La aceptación humana en los dispositivos y el portal publicado sigue siendo
el siguiente recorrido; no se genera una APK en este bloque.

Publicación Dev comprobada el 31/10: código
`10ef594e7d16fe2a198b0759aa9a6062219db8c4`. Finalizan correctamente
[Trainer](https://github.com/jchjdev/entrenaop/actions/runs/41179229902),
[ADMIN](https://github.com/jchjdev/entrenaop/actions/runs/41179229793) y la
[verificación del consumidor e iOS sin firma](https://github.com/jchjdev/entrenaop/actions/runs/41179230966).
Se verifica independientemente por HTTPS cada manifiesto, entrada activa,
SHA-256 del JavaScript, cabeceras y MIME de WebAssembly. Ambos portales sirven
`development`, proyecto `sxbxfjqgoddzhtcyhalw`, con la revisión indicada:

- Trainer: release `10ef594e7d16fe2a198b0759aa9a6062219db8c4-41179229902-1`,
  SHA-256 `b5b19797ea934ea53df03bb2c6efcd2a86dc2d84d1b59729a0259e2d29f3560f`.
- ADMIN: release `10ef594e7d16fe2a198b0759aa9a6062219db8c4-41179229793-1`,
  SHA-256 `fea2ce41fae698c393f1a7c8c18cc9e24bf1007f50bae9d44453b695f02d9966`.

La aceptación de Javier sigue pendiente; la app compartida necesita su próxima
compilación/instalación. No se publica producción ni se genera APK.

### Planificación de grupos y revisión por alumno · 31/10/2026

El envío de programas propone fechas en una sola acción, reutilizando el mismo
planificador civil del envío individual: una pasada de las fases elegidas, cada
dos días. Es una propuesta editable; no desarrolla las semanas de duración ni
prescribe cargas. Se confirma antes de reemplazar fechas elegidas y se preservan
las de fases que no se están proponiendo. Revisar muestra sesiones/fechas con
acceso a la receta común y las coincidencias por cada destinatario. El envío
conserva el límite de 100 alumnos/256 pautas, huella revisada, UUID y atomicidad.

El recibo ofrece **Ver y adaptar planificación** por alumno. La ficha abre la
primera fecha del envío y se apila sobre el recibo, para regresar y seguir con
otro destinatario de la misma tanda confirmada. La URL admite fecha civil
canónica en el rango del selector existente; una fecha inválida usa la entrada
normal. La adaptación mantiene sus operaciones y versiones individuales; no
edita la plantilla común ni las pautas de los demás alumnos. Los resultados
continúan en la bandeja de revisión existente.

El contrato SQL `trainer_group_planning_journey.sql` conecta dos alumnos, tres
sesiones por alumno, coincidencia previa, reintento, adaptación individual,
consulta aislada, ejecución y revisión. Comprueba una cola de planificación por
alumno y su espera de agrupación. Las cuentas, sesiones y colas temporales se
revierten; no se invoca al despachador ni se acredita recepción física de push.
Se conservan las pruebas de grupos/copia, operación individual y política de
avisos. No se modifica esquema, RLS, servidores, credenciales ni suscripciones.

Validación local del 31/10: análisis limpios de raíz y Trainer; 401 pruebas de
Trainer correctas, incluidas seis nuevas regresiones del recorrido. Treinta
pruebas centradas en grupos/programas y capturas reales de revisión/recibo
correctas; selección y recibo con texto doble a 320 px. Los cuatro contratos SQL
`trainer_group_planning_journey`, `trainer_groups_and_week_copy`,
`trainer_operational_workflow` y `trainer_notification_policy` terminan
correctamente con ROLLBACK en `entrenaop-dev`; después quedan cero cuentas del
ensayo nuevo. CLI contrastó 255 migraciones locales/remotas coincidentes antes
de la ampliación del piloto del directorio en curso, que queda fuera de este bloque.
La web privada queda documentada como propuesta, sin configurar otro dominio.

Publicación del recorrido confirmada el 31/10 en Trainer Dev: revisión
`56054fc5adda18aeb05d7e02e051b0966b3ce426`,
[ejecución automática 41185995965](https://github.com/jchjdev/entrenaop/actions/runs/41185995965)
con validación, compilación y publicación correctas. Una comprobación HTTPS
independiente confirma `trainer.entrenaop.es`, entorno `development`, proyecto
`sxbxfjqgoddzhtcyhalw`, manifiesto y recursos coherentes. SHA-256 de `main.dart.js`:
`0744213ba57d156410148725ae79ebd75a78634e1ec5fabe1ee82bfb5d7b4187`.
No se publica la copia comercial ni se incluyen los cambios en curso del
directorio en esta entrega.

**Siguiente aceptación humana:** preparar una semana para dos cuentas del piloto,
adaptar una, realizarla y revisar, observando los avisos del teléfono. El circuito
automatizado no sustituye esa comprobación con Javier y Ervi.

### Búsqueda completa de biblioteca · 31/10/2026

Javier pide encontrar sesiones y programas sin cargar primero las páginas
anteriores. El portal web consulta la biblioteca completa en servidor y pagina
las coincidencias, con el mismo cursor por fecha e ID. La navegación sin consulta
mantiene su lector anterior. No descarga las recetas completas para buscar.

Las sesiones admiten todos los términos, sin distinguir tildes o mayúsculas,
en nombre, descripción, bloques, ejercicios y etiquetas de formato. Modalidad
y formato se filtran antes del límite de página. Los programas buscan nombre,
descripción, fases y nombres de sesiones. Los caracteres de comodín son literales.
Las RPC exigen la misma cuenta y MFA que las listas existentes, limitan cada
respuesta a 50 filas y excluyen papelera, versiones no publicadas y adaptaciones
individuales de la biblioteca general de sesiones.

Se conecta a bibliotecas, Agenda, ficha del alumno, asignación individual,
envíos por grupos y recurrencias finitas. Se agrupan pulsaciones durante 300 ms
y se descartan respuestas anteriores; el texto, la receta elegida y los cursores
se conservan por su contexto. Las bibliotecas y los paneles admiten continuación
al desplazarse. Los borradores mantienen su recuperación separada. El componente
compartido ofrece callbacks opcionales; sus consumidores locales conservan la
búsqueda anterior. Este tramo no cambia los lectores propios del modo móvil.

La migración `20261031091005_trainer_library_search.sql` se aplica solo a Dev.
`trainer_library_search.sql` comprueba 61 sesiones y 61 programas, búsquedas
fuera de la primera página, contenido, tildes, comodines literales, filtros,
cursores sin duplicados, MFA, aislamiento, papelera y variantes. Termina con
ROLLBACK y cero cuentas temporales. El contrato previo de papelera también pasa.

Validación del 31/10: análisis limpios de raíz, Trainer y ADMIN; baterías completas
con 1.526 pruebas correctas de la app (una omisión previa), 411 de Trainer y 365
de ADMIN (dos omisiones previas). Quince regresiones de búsqueda/retorno y captura
del componente real correctas. Historial Dev contrastado: 257 migraciones
coincidentes, sin pendientes. El asesor de seguridad no añade avisos sobre las
funciones nuevas; no se presenta como una auditoría global de hallazgos previos.

Publicación Dev comprobada el 31/10: revisión
`c4a4d99f114ff9777cd3265ae97b516399248699`, con
[Trainer 41189757858](https://github.com/jchjdev/entrenaop/actions/runs/41189757858)
y [ADMIN 41189757872](https://github.com/jchjdev/entrenaop/actions/runs/41189757872)
correctos. Verificación HTTPS independiente de ambos manifiestos y recursos,
entorno `development`, proyecto `sxbxfjqgoddzhtcyhalw` y revisión coincidentes.
SHA-256 de JavaScript: Trainer
`f55c107ea971d0992323a81e1c91396d74b2661cf43efa2a41bbef8f5fbb7d32`;
ADMIN `66e8109c5901de776a93407526570863efa93b65a404b3c78f10003d9974526f`.

**Aceptación humana acordada:** Javier indica la semana del 2 al 8 de noviembre
para probar la planificación de Ervi y comenzar el seguimiento de Isabel,
comprobando recepción, ejecución y resultados. No se da ese recorrido por probado
por ejecutar fixtures ni se crea un recordatorio automático.

### Mejoras de chat y planificación · 31/10/2026

Javier pide orientación habitual de chat, planificación recibida en móvil y
avatar junto al nombre. Confirma que el fallo aparece en **Entrenador → Agenda**.
Se implementa en cliente, sin modificar SQL, permisos ni cuotas:

- `ConversationView`, común a alumno, profesional web y modo Entrenador, muestra
  antiguo arriba y reciente abajo; editor fijo inferior también en móvil. El
  cursor de servidor continúa descendente. Conserva borrador/reintento y páginas;
  al recibir mientras se lee atrás no desplaza y ofrece «Ver mensajes nuevos».
  Los añadidos en curso de cabeceras/acciones del directorio se preservan como
  trabajo ajeno; no se guardan dentro de esta entrega.
- Agenda móvil reúne las pautas propias con las recibidas para la identidad
  personal fijada por el repositorio autenticado. Reutiliza
  `get_trainer_shared_calendar`, con autor, estado y consulta sin editar, mover
  o retirar lo ajeno. Filtra fuentes ajenas al entrenador, duplicados y retiradas,
  conserva el filtro de alumno y fechas civiles de día/semana/mes. Pagina el
  calendario personal con su cursor completo y descarta respuestas obsoletas;
  fallar esa lectura no elimina el resto de sesiones/citas. No consulta otras
  carteras de alumnos ni crea un vínculo «Para mí» para cargar la agenda.
- La cabecera de planificación web utiliza `ProfilePhotoAvatar` y el mismo lector
  privado que las fichas; muestra iniciales si la imagen no está disponible.
- Fotos, sin cambios: perfil 512×512/JPEG hasta 200 KiB antes de subir, con límite
  defensivo de repositorio/servidor 500 KiB; ejercicios se reducen para 1280×720 y
  JPEG hasta 500 KiB. Portadas: variantes 800 px/180 KiB y 1600 px/500 KiB. Estos
  límites no corresponden a vídeos ni implican subir el original sin reducir.

La app requiere actualizarse desde GitHub y compilarse; no se prepara APK ni se
acredita prueba física nueva del iPhone en esta tarea. Verificación y publicación
web se registran cuando finalicen las comprobaciones.

**Cierre comprobado · 31/10/2026:** análisis y baterías completas de raíz, Trainer y
ADMIN correctos; 59 pruebas del UI común y 10 del chat seleccionado de forma
independiente correctas. Capturas revisadas: planificación web y agenda recibida
390 px con texto 1,3×; no equivalen a una prueba física nueva del iPhone.

Publicación automática Dev confirmada por HTTPS, entorno `development`, proyecto
`sxbxfjqgoddzhtcyhalw`, fuentes guardadas y SHA-256 del JavaScript verificado:

- [Trainer · ejecución 41202037819](https://github.com/jchjdev/entrenaop/actions/runs/41202037819):
  `213a6e0cf167f1e9f1a0b40153e9da01ccb9a96d-41202037819-1`;
  SHA-256 `0e1f274b22a7f8bf052034b27888875796210848227bfe3b87d7a867222efc9d`.
- [ADMIN · ejecución 41202037752](https://github.com/jchjdev/entrenaop/actions/runs/41202037752):
  `213a6e0cf167f1e9f1a0b40153e9da01ccb9a96d-41202037752-1`;
  SHA-256 `28d97c9414264546c695ff40447dd2d11dca8dd3e5414c0a80d73d30d5d60e7f`.

Los precios continúan como borrador; no se crean ofertas ni se activan cobros reales.

### Inventario de los dieciséis puntos · 29/10/2026

Javier pide el estado de los dieciséis puntos y añade gestión de borrado de
sesiones, programas y ejercicios en ambos portales. Se contrasta el mapa del
22/10 con las entregas posteriores y el código de los catálogos. Esta revisión
no vuelve a certificar físicamente cada recorrido ni convierte ampliaciones
opcionales en funciones obligatorias nuevas. Un guion indica que no se añade
otra carencia funcional básica en este inventario.

| Punto original | Base disponible | Pendiente principal |
| --- | --- | --- |
| 1. Inicio profesional | Resumen de alumnos, planificación y revisión | — |
| 2. Ficha del alumno | Notas, objetivos de oposición, resultados y calendario conjunto autorizado | — |
| 3. Calendario editable | Mes/semana/día/lista, fichas arrastrables, sesiones y citas con avisos | Sincronización Google Calendar aplazada; no es parte del recorrido interno ya implementado |
| 4. Adaptación individual | Receta individual manual y recuperación persistente | La adaptación automática profesional pertenece al motor pendiente |
| 5. Creador ágil | Editores compartidos, arrastre y recuperación de biblioteca, hijos y adaptaciones | — |
| 6. Biblioteca eficiente | Fotos, origen oficial/propio, colecciones, búsqueda interna, formatos, papelera y limpieza protegida de archivos | Aceptación de la búsqueda completa en el portal web |
| 7. Grupos y envío conjunto | Grupos, asignación conjunta y copia semanal | Aceptación humana con varias cuentas; recorrido automatizado y accesos por destinatario ampliados el 31/10 |
| 8. Evolución | Métricas por periodo y evolución del servicio | — |
| 9. Bandeja de revisión | Resultados, revisión persistente y correcciones | — |
| 10. Vídeos en ambas direcciones | Archivos propios, enlaces externos, demostraciones y técnica; eliminación protegida de demostraciones, recuperación de reservas y aviso Android aceptado | La técnica histórica se conserva; no se habilita borrado libre de vídeos de alumnos |
| 11. Formularios | Plantillas, asignación y respuestas en el espacio Preparador | — |
| 12. Comunicación | Chat con refresco, globos y push profesional Android aceptada en beta.3 | Apple/APNs y pruebas físicas extendidas de descanso/cuentas/recordatorios |
| 13. Automatizaciones controladas | Recurrencias finitas | Automatización adaptativa profesional y sus reglas; no se presenta como motor ya entregado |
| 14. Cobros y servicio | Registro/recuperación web, acceso manual y contratación EntrenaOP→preparador ensayada con Stripe sandbox | Tarifas y políticas finales, operación de cobros reales y circuito alumno→preparador |
| 15. Informes | Resumen por periodo y CSV | Otros formatos serían ampliaciones, no un requisito básico acreditado como ausente |
| 16. Oposición y dispositivos | Metas, marcas y pruebas privadas; integraciones con su contrato propio | Cierre de los recorridos deportivos/oficiales y de dispositivos según sus bloques; este inventario no reaudita Garmin |

**Actualización móvil · TRN-048 · 30/10/2026:** biblioteca, asignación rápida,
agenda visual y acciones ligeras de seguimiento disponibles en el modo Entrenador;
creadores y programas permanecen en web. No cambia los pendientes del inventario
ni acredita su aceptación física completa.
[Contrato móvil](TRAINER_MOBILE_WORKSPACE.md#planificación-ligera--trn-048--30102026).

### Limpieza protegida de medios · TRN-046

El 29/10 Javier autoriza continuar la gestión de archivos y confirma que el
ejercicio de prueba ya fue borrado definitivamente. Se amplía TRN-045 con una
cola durable de limpieza: la cuota se libera únicamente tras confirmar el
borrado en Storage o el proveedor de vídeo. Las comprobaciones y bloqueos se
hacen en servidor y los reintentos no crean medios nuevos.

La papelera conserva lo necesario para recuperar contenido. Al purgar una
receta se revisan sus medios, manteniendo cualquier archivo usado en otras
versiones, trabajos guardados, asignaciones o historial. Los vídeos propios
sueltos son biblioteca válida; se eliminan de forma explícita. La técnica de
alumnos vinculada a una ejecución sigue protegida. Las reservas abandonadas se
revisan con antigüedad mínima y espera por credenciales de subida vigentes.
Los fallos dejan la limpieza pendiente y siguen consumiendo cuota hasta su
confirmación; no se declara liberado un archivo porque desaparezca su fila.

Accesos: Trainer → Vídeos, Ejercicios o Papelera → «Limpiar archivos sin uso»;
ADMIN → Ejercicios o su papelera → el mismo mantenimiento. Los motivos de
protección se explican en castellano. Cada solicitud revisa hasta 50 candidatos,
priorizando los nunca revisados y después la revisión más antigua; repetir el
mismo UUID recupera su lote original. El trabajador procesa hasta 3 eliminaciones
por llamada y Cron reintenta únicamente solicitudes ya encoladas cada minuto.
No realiza un barrido global por su cuenta.

Verificación: 2.189 pruebas Flutter y 60 Node correctas; análisis limpios. Tres
contratos SQL nuevos y ocho regresiones relacionadas comprobados con ROLLBACK.
La imagen huérfana de prueba dejó de existir en Storage tras el borrado por API;
`image_used` bajó de 2 a 1 y la otra imagen utilizada permaneció intacta. No se
eliminaron vídeos reales para ensayar. Los GUID inciertos, subidas con credencial
vigente y fallos de proveedor conservan sus reservas hasta poder confirmar la
operación. `freed_bytes` expresa reserva de vídeo recuperada, no bytes físicos.

Migraciones `20261029215210_exercise_media_cleanup_outbox.sql` y
`20261029222944_media_cleanup_sweep_progress.sql`, funciones `exercise-video` y
`trainer-media-cleanup`; activación reproducible en
`tools/enable_exercise_media_cleanup_dev.sql`. Los permisos y el aislamiento se
comprueban en servidor; limpiar medios propios no exige suscripción activa.
Solo Dev; 252 migraciones locales/remotas coinciden, sin fixtures persistentes.
Los avisos de seguridad no añaden WARN/ERROR para este alcance; las tres tablas
privadas nuevas conservan RLS sin acceso directo del cliente.

Publicación comprobada el 29/10: ambos portales sirven
`5961fd6ce66324317d684d04eedc9bae5170a548`, identidad Dev correcta y árbol de
compilación limpio, con hashes/recursos HTTPS verificados. Trainer
`40966741896`, ADMIN `40966741837` y contratos del servidor `40966741856`
terminaron correctamente en GitHub. El acceso desde Ejercicios abre el informe
privado con una reserva recuperada; la biblioteca muestra 1/1000 y la imagen
conservada sigue visible. ADMIN muestra únicamente su informe oficial vacío,
sin mezclar la limpieza privada de la misma cuenta. Se revisaron ambas pantallas.
Los contadores del informe describen solicitudes registradas, no el inventario
completo de archivos que podrían quedar protegidos en futuras revisiones.
El circuito anterior de papelera y recuperación sigue vigente; cuentas, cobros
y producción mantienen su contrato.

### Gestión de la biblioteca · TRN-045 · 29/10/2026

Recorrido implementado: **Mover a papelera → recuperar → borrar definitivamente**.
Cada biblioteca tiene entrada Papelera; las acciones de retirada están en la
ficha del contenido propio. Retirar una plantilla no retira su pauta del
calendario ni descarta trabajos de edición.

En Trainer la unidad es la familia completa de versiones de un ejercicio,
sesión o programa. Una entrada conserva identificador, miembros y sello de
retirada. Recuperar devuelve las mismas versiones sin crear otra ni promover
una antigua. Lo ya asignado conserva su receta y sigue siendo ejecutable;
el contenido retirado no se ofrece para nuevas selecciones o asignaciones.
El material oficial sigue siendo de consulta para el preparador.

El borrado definitivo se confirma y se bloquea si alguna versión tiene
referencias protegidas: recetas/programas, trabajos abiertos, pautas,
ejecuciones/resultados, recurrencias u operaciones/snapshots de dispositivos.
Se comprueban FK y referencias JSON; no se borran esos datos para liberar una
plantilla. Las versiones internas solo se purgan juntas cuando es seguro.
Los recibos antiguos no recrean contenido purgado. El ejercicio técnico Carrera
está protegido aunque no aparezca en el catálogo.

ADMIN añade ejercicios oficiales y mantiene el contrato previo: sesiones por
versión y programas por familia con sus trabajos vinculados. Un ejercicio
recuperado se ve retirado; editarlo muestra **Guardar y publicar**. Recuperarlo
no lo vuelve público. Una creación cuya imagen falla se limpia por el mismo
contrato protegido; una purga no confirmada o bloqueada conserva el medio.

`CatalogTrashView`, en `entrena_ui`, comparte carga, paginación, confirmaciones,
errores y reintentos; los adaptadores mantienen sus contratos. Los recibos nuevos
se validan antes de declarar éxito y una respuesta incierta conserva el UUID.
Cambiar de cuenta invalida vista y respuestas anteriores.
`WorkoutEditorExercise.selectable` separa mostrar una referencia conservada de
ofrecerla para una receta nueva: los portales recuperan nombres y fotos por IDs
autorizados. El editor común conserva también el nombre de la receta original
si el consumidor solo aporta catálogo activo. Para guardar otra receta hay que
recuperar o sustituir los ejercicios retirados.

Las migraciones `20261029195445_trainer_admin_catalog_trash.sql` y
`20261029204524_admin_session_trash_scope_guard.sql` están aplicadas solo
en Dev. Exigen identidad, MFA y acceso de autoría; mantienen aislamiento de cuentas
y ADMIN. Recibos y sellos protegen reintentos y retiradas posteriores. Bloqueos
por recurso/familia evitan una exclusión global de todas las cuentas. Las listas
nuevas se paginan por sello e ID, 50 por página. El listado administrativo de
sesiones restringe explícitamente `origin=system` y dueño nulo: no depende del
antiguo CHECK de papelera, que ahora también permite contenido profesional.

Purgar ejercicios libera únicamente las unidades de versiones eliminadas.
Las reservas/ficheros de imágenes y vídeos se conservan y siguen contando según
su contrato: este bloque no añade limpieza remota de medios ni vaciado automático.

**Verificación al cierre:** análisis limpios y baterías completas: raíz 1.446
pruebas (una omisión previa), Trainer 323, editor compartido 223 y `entrena_ui` 41.
ADMIN 358 (dos omisiones previas). Las tres papeleras y el listado de ejercicios
administrativos están conectados a la guarda real del router: confirmación y
envío bloquean salida; una respuesta incierta conserva el recurso/UUID y ofrece
reintento incluso después de refrescar. Total: 2.391 pruebas correctas. La revisión
visual elimina la cabecera duplicada; los recorridos de papelera afectados vuelven
a pasar tras el ajuste, sin modificar sus acciones. Seis regresiones del router
real cubren el regreso de las tres papeleras tras entrada directa/recarga, con
carga inicial terminada o pendiente. El padre se actualiza al volver sin exigir
Actualizar, conserva búsqueda visible/filtros y no duplica la consulta del
recorrido normal por push. La señal de ruta es local a Trainer; no reconstruye
la biblioteca ni añade sondeo.
Dos contratos SQL nuevos y diez regresiones correctos, todos con ROLLBACK: catálogos
privados, vídeos, recuperación de sesiones/programas/contextos y operaciones/
papelera editorial ADMIN. Dos conexiones reales comprueban que una asignación
retiene el recurso compartido: el exclusivo de otra familia sigue disponible y
el del mismo recurso espera hasta el límite de 700 ms. Ambas hacen ROLLBACK;
sin fixtures persistentes. La prueba de contextos mezcla sesiones oficiales y
familias de dos preparadores: ADMIN no lista las privadas y Trainer conserva
aislamiento, versiones y cursores. Historial Dev local/remoto coincidente.
Advisors del alcance: cuatro INFO intencionales por RLS sin políticas/grants en
tablas privadas; ningún WARN/ERROR nuevo del ciclo. La inspección de JSON de
dispositivos sigue siendo global porque pertenece al alumno y puede sobrevivir
al vínculo; no es una prueba de carga a gran escala.

**Publicación Dev verificada · 29/10/2026:** Trainer `7d9c8c12`
([ejecución 40956621457](https://github.com/jchjdev/entrenaop/actions/runs/40956621457))
y ADMIN `249e472f`
([ejecución 40953026080](https://github.com/jchjdev/entrenaop/actions/runs/40953026080)).
Se contrastan HTTPS, manifiestos, identidad del proyecto, hashes de JavaScript,
bootstrap y recursos publicados. Ambos paquetes declaran `development`, proyecto
`sxbxfjqgoddzhtcyhalw` y fuente de compilación limpia; producción no se modifica.
Comprobación en navegador de las seis entradas y del recorrido real de una
sesión privada existente: desaparece del catálogo activo, se bloquea su purga
por referencias y no aparece en la papelera de ADMIN. Recuperar devuelve la
misma versión; tras recargar directamente la papelera, volver actualiza la
biblioteca sin Actualizar. La búsqueda conserva texto visible y filtro después
de refrescar. Una consulta transitoria se recupera con Reintentar. La sesión de
pruebas queda recuperada y las bibliotecas oficiales no se alteran. Se comprueba
y cancela la confirmación de purga administrativa; no se purgan datos reales.

**Siguiente recorrido recomendado:** aceptación de invitaciones por enlace con
la beta instalada y un alumno real, incluyendo apertura con/sin sesión sin
copiar el código. Los cobros reales y Apple conservan sus bloques.

**TRN-028 · 24/10/2026:** dos preparadores activos por alumno en el piloto,
con calendario y pauta compartidos solo si lo habilita el alumno. Cada
preparador conserva su cupo, cartera, biblioteca, notas, resultados y
conversaciones; solo modifica sus propias pautas. Sustituye la exclusividad
anterior, sin equipos globales ni edición cruzada.
[Contrato y evidencia](TRAINER_MULTI_COACH_2026_10_24.md).

## Ampliación TRN-020 en curso

El alcance vigente incluye los dieciséis recorridos de
[la coordinación profesional](PROFESSIONAL_DELIVERY_COORDINATION.md). El código
local conecta inicio, ficha, agenda editable, adaptación individual, grupos,
copia semanal, recurrencia finita, evolución/CSV, revisión de resultados,
formularios, conversaciones y medios privados. La app recibe formularios,
conversaciones, técnica y baterías de pruebas; su sección de formularios/pruebas
aparece solo cuando existen entregas propias. Las baterías son un circuito
versionado de marcas, sin crear ejecuciones ficticias ni puntos oficiales.

Los creadores conservan composición única y adaptadores de cada portal. ADMIN
recibe búsqueda y creación contextual, duplicación y herramientas de vídeo;
solo permite subir vídeos, mientras Trainer admite además enlaces HTTPS.
El seguimiento, las conversaciones y el contenido profesional no se vuelven
administrativos por compartir editor.

La implementación y las evidencias de integración están en
[el contrato operativo](TRAINER_OPERATIONAL_WORKFLOW.md) y en los contratos
específicos que enlaza. Las diez migraciones y veinticuatro contratos han pasado
juntos en Dev con ROLLBACK, se han aplicado las migraciones y se han repetido
los 24 contratos sobre el esquema real aplicado. Publicación web y aceptación
móvil se acreditan por separado. El núcleo comercial tiene únicamente un ensayo
tipado con proveedor ficticio: no hay cobros reales. Favoritos/recientes se integran en los mismos creadores; recuperación persistente
de programas se incorpora en TRN-021 con servidor Dev verificado; la recuperación
de sesiones internas y el motor profesional mantienen sus entregas pendientes.
INT-004 conecta Salud con historial privado en la app principal, todavía sin
distribución/aceptación física ni entrega automática de registros al preparador.

## Objetivo y propiedad del contenido

Javier concreta que el portal debe ser una herramienta de trabajo profesional
para preparadores de oposiciones. El preparador crea ejercicios, sesiones y
programas propios, reutiliza su biblioteca con cualquiera de sus alumnos y
elige qué pautar a cada persona. Una sesión puede ser suelta o formar parte de
varios programas. Nada se publica en el catálogo oficial por ese motivo.
Los creadores se comparten con ADMIN mediante adaptadores; no se mantienen dos
implementaciones del mismo creador.

El portal necesita agenda conjunta y planificación por alumno, consulta de
resultados y evolución. El alumno utiliza la app existente y recibe el contenido
que le han pautado, sin una segunda compra obligatoria ni aumento de sus cuotas
personales. ADMIN gestiona cuentas, acceso profesional y cupos sin adquirir por
ello lectura general de bibliotecas y resultados privados. Identidad, permiso
ADMIN, Pro, acceso profesional, servicio con el alumno y pago siguen separados.

TRN-016 implementa sesiones privadas, pautas y resultados. TRN-017 amplía a
programas versionados y agenda. TRN-019 incorpora ejercicios profesionales
versionados, imágenes privadas y acceso del alumno, reutilizando el formulario
de ADMIN. Su publicación y validación se acreditan en
[el contrato específico](TRAINER_PRIVATE_EXERCISES.md).

## Directorio profesional futuro · TRN-040 · 28/10/2026

**Inicio de implementación autorizado el 30/10/2026, exclusivamente en Dev.**
Javier confirma pasar de los acuerdos futuros a una primera entrega, conservando
el trabajo simultáneo de Arquitectura. Se desarrolla el directorio de entrenadores
para web/app; los centros mantienen su fase posterior. La habilitación pública
y el piloto con cuentas reales siguen sujetos al catálogo y textos pendientes.

### Recorrido y límites acordados

- Cada entrenador decide publicitarse. La ficha prevista incluye foto,
  presentación breve y especialidades; dispone de espacio para explicar su
  propuesta y sus servicios con su propia voz.
- «Mi preparador» será el punto de entrada previsto para descubrir profesionales
  desde la app. Javier confirma el 30/10 que **Preparador estará siempre visible
  en la navegación del espacio personal**, también sin vínculo ni contenido
  recibido, para poder buscar. Se conserva la prioridad de los vínculos actuales.
  La concreción del 30/10 añade
  fichas solo para la app: la solución ya no puede depender únicamente de abrir
  el directorio público; la secuencia de entregas web/app queda por diseñar.
- El primer contacto se inició con canales externos publicados voluntariamente:
  correo profesional, web o WhatsApp, sin tomar el correo privado de acceso.
  El acuerdo del 31/10 amplía esos canales con contacto dentro de EntrenaOP,
  activable por el profesional y con aceptación previa a continuar la charla.
  [Contrato del contacto](#primer-contacto-en-el-chat-existente--31102026).
- Se reafirma el máximo actual de **dos preparadores externos activos por
  alumno** de TRN-028. Consultar una ficha o contactar no consume plaza, acepta
  una invitación ni concede acceso al calendario, resultados u otros datos
  privados. La vinculación conserva su aceptación explícita y controles
  existentes. El vínculo interno «Para mí» conserva su tratamiento independiente.
- La segunda fase añade centros. Una ficha pública de centro no aprueba por sí
  sola organizaciones, equipos, acceso a alumnos compartido ni un cambio del
  límite de preparadores.

### Criterios adicionales acordados

Javier confirma estas propuestas el 28/10/2026. La primera entrega técnica del
30/10 desarrolla este alcance, todavía sin habilitar la publicación real:

- Combinar presentación libre con campos comunes de especialidad, preparaciones,
  modalidad online/presencial y ubicación para ofrecer filtros útiles. Explicar
  los servicios concretos, por ejemplo fuerza, carrera, preparación completa o
  revisión técnica, para facilitar también la elección de un segundo preparador.
- Mostrar si admite alumnos o está sin plazas y permitir pausar la publicación.
- Dar a cada ficha un enlace propio compartible para difundirla por sus canales.
- En «Mi preparador», priorizar los vínculos actuales y ofrecer una entrada
  «Buscar preparador». Tener dos preparadores no sustituye ninguno automáticamente:
  informar del límite antes de intentar aceptar un tercero; buscar/contactar
  sigue siendo independiente de las plazas activas.
- Empezar con un grupo pequeño de profesionales activos: Javier confirma el
  30/10 que el piloto será con su cuenta y la de Ervi, sin habilitarlas por esta
  conversación. Distinguir el uso de EntrenaOP de titulaciones verificadas.

### Concreción del 30/10/2026 · pendiente de implementación

**Publicidad y planes · actualizado por acuerdo del 31/10.** Directorio incluido
en Profesional y Completo; Básico puede contratarlo como complemento opcional de
pago. Sustituye la exclusión absoluta del Básico planteada el 30/10. La compra
no sustituye la publicación voluntaria, aceptación por canal ni moderación. No
se aprueban por ello importes, cupos, prestaciones completas ni posiciones
preferentes. Al perder acceso o elegibilidad se ocultará/suspenderá la ficha,
conservando su contenido; cancelar no adelanta el fin del periodo pagado. Un
cambio a Básico conserva elegibilidad solo si incluye el complemento vigente.
Regalos y piloto temporal mantienen su contrato separado.
[Borrador comercial, sin activar ofertas](TRAINER_PRICING_DRAFT.md).

Javier acepta gestión desde ADMIN y pregunta cómo encajarla con el pago. Se
propone separar elegibilidad comercial, voluntad de publicación y bloqueo por
moderación: ADMIN podría suspender/restablecer la visibilidad de una ficha
elegible, sin simular pagos ni saltarse el plan. La concesión manual general de
acceso profesional conserva su contrato independiente; no se aprueba que un
regalo permita anunciarse gratis. Excepciones y alcance del permiso manual
siguen pendientes. El piloto no concede ni cambia planes reales.

**Fichas y favoritos.** Javier acepta el conjunto de campos propuesto: nombre
profesional, foto, descripción breve, preparaciones/especialidades, servicios,
modalidad, zona y al menos un contacto; precio opcional. Los valores, límites y
validación se concretarán al diseñar. Quiere permitir guardar preparadores en
favoritos para encontrarlos después. Una ficha sin plazas puede seguir visible
con un estado claro. No se deduce automáticamente que el cupo comercial lleno
equivalga a no aceptar contactos; automatización y significado de «solicitud»
quedan por acordar, dado que el contacto inicial sigue siendo externo.

**Visibilidad elegida y datos.** El profesional deberá aceptar expresamente la
publicación de sus datos y poder elegir aparecer solo en la app o también en la
web pública. El acceso público sin cuenta se limita a fichas autorizadas para
web; la modalidad solo app requiere lectura autenticada y autorización en
servidor, sin exponer la ficha/contactos mediante una URL pública ni confiar
solo en ocultarla de resultados o buscadores. Se debe revisar privacidad,
condiciones de publicación y retirada antes del lanzamiento; no se redactan ni
validan textos legales en esta tarea. No se promete impedir capturas o reenvíos.
Los enlaces compartibles y favoritos deberán respetar la visibilidad vigente,
las pausas y las retiradas; guardar una ficha no debe mantener accesible una
copia de sus datos si deja de estar autorizada. Persistencia y restauración de
favoritos quedan por diseñar.

**Moderación con poca carga manual.** Javier prefiere evitar revisar manualmente
cada alta y confirma **publicación directa con denuncias**, sin aprobación humana
previa obligatoria. La publicación sigue exigiendo elegibilidad, aceptación y
visibilidad autorizada; no elimina controles de datos o seguridad. La revisión
será por incidencias; su flujo y las reglas concretas siguen pendientes.
Los motivos propuestos incluyen imágenes sexuales
explícitas o violentas, acoso/odio, suplantación, spam/enlaces engañosos y datos o
credenciales profesionales presuntamente falsos. Pagar no se considera una
garantía de contenido apropiado. Una denuncia no acredita por sí sola una
infracción: retirada automática, revisión, respuesta y posible restitución deben
definirse antes de implementarlas.

Javier plantea asistencia automática futura para revisar perfiles y reducir su
trabajo. Se registra la intención, sin elegir proveedor, crear automatizaciones
ni suponer supervisión permanente de este chat. Revisión de nuevas versiones de
foto/texto y priorización de casos dudosos son propuestas por evaluar, no una
verificación de titulaciones ni un sistema de moderación ya contratado.

### Arquitectura acordada

**Arquitectura confirmada el 30/10:** el directorio seguirá Clean Architecture
por funcionalidad, con dominio independiente, adaptadores de datos y
presentación separados. Reutilizar contratos entre web/app no permite duplicar
las reglas ni delegar seguridad o derechos comerciales a la interfaz. No se
añaden capas o clases sin una frontera real.
[Criterio arquitectónico](ARCHITECTURE.md#clean-architecture-aplicada-a-entrenaop).

### Cuestiones pendientes

Concretar catálogo y elegibilidad por plan, alcance de ADMIN y excepciones,
fecha efectiva de ocultación y reglas de reactivación. Diseñar campos/filtros,
orden de resultados, contacto con/sin plazas, favoritos, navegación sin vínculos,
publicación/edición/denuncias y posible asistencia automática. Cerrar la entrega
web/app y los consentimientos/textos de privacidad para ambas visibilidades.
Los centros mantienen su fase posterior, con representación y relación con
entrenadores por decidir. Aparecer en el directorio no fija tarifas, comisiones,
suplementos ni acreditaciones. Reseñas, reservas, chat de captación y contratación
automática no forman parte del primer alcance acordado.

### Primera entrega técnica · 30/10/2026

- `trainer_access/lib/directory/` reúne dominio puro, puerto de repositorio,
  codec/adaptador Supabase y presentación compartida, con dependencias hacia el
  dominio. Se declara Flutter como dependencia directa ya presente en el grafo;
  no se incorpora otro paquete externo ni se actualizan versiones.
- La app conserva Preparador visible sin vínculos y ofrece «Buscar preparador».
  `/directory` y `/directory/:profileId` consultan fichas, filtros, favoritos,
  contacto externo y denuncias. Trainer ofrece las mismas rutas en modo web
  público y `/directory-profile` para editar el borrador propio con MFA y guard
  de cambios. ADMIN añade `/directory-reports` para el responsable de cuentas.
- `20261030175018_trainer_directory.sql` crea tablas privadas con RLS/grants
  restringidos, fachadas invoker e internos autorizados por identidad. Publicar
  exige prestación comercial en la oferta pagada, periodo vigente, acceso
  profesional, consentimiento y habilitación del directorio. No se deduce por
  cupo, Pro personal ni regalos. El catálogo actual conserva el derecho apagado.
- Publicación directa, favoritos privados e idempotentes, una denuncia pendiente
  por pareja y hasta diez denuncias nuevas por día/cuenta. Denunciar no suspende:
  el responsable decide, explica el motivo y deja auditoría. Una edición no
  levanta la suspensión y restablecer no concede derechos comerciales.
- Fotos en bucket privado, JPEG hasta 500 KB y máximo tres archivos por cuenta;
  se reutiliza el selector/optimizador existente, que reencodifica sin EXIF/GPS.
  La descarga verifica RLS y visibilidad, sin URL pública ni firmada persistente.
  Reemplazar la foto limpia la anterior si ya no está referenciada. El editor
  permite limpiar fotos no guardadas, con confirmación, protegiendo la actual.
- Suspensión, pausa, solo-app y vencimiento se aplican también a búsqueda,
  favorito, enlace directo y foto en nuevas peticiones. No se almacenan copias
  persistentes en el cliente; una captura o dato ya recibido no puede revocarse.
- El buscador pagina de veinte en veinte por identificador estable, sin ranking
  comercial; especialidad/preparación y servicio se buscan por texto, junto a
  modalidad y zona. El orden comercial y la taxonomía final siguen pendientes.

**Límite deliberado de esta entrega:** `directory_private.settings.enabled` queda
en falso y todas las ofertas existentes mantienen `directory_enabled=false`.
Se permite preparar borradores, pero no publicar fichas reales ni habilitar
planes desde Flutter. No se cambian las cuentas de Javier/Ervi ni se crean pagos.
El aviso de publicación del editor no se presenta como revisión jurídica de las
políticas. Antes de activar el piloto: concretar las ofertas elegibles y sus
condiciones/textos, revisar las fichas de ambos y comprobar el recorrido real.

La migración se aplica solo en `entrenaop-dev` y el contrato
`supabase/tests/trainer_directory.sql` termina con ROLLBACK. El historial reúne
253 migraciones coincidentes. El asesor de seguridad conserva sus avisos WARN;
solo se añaden cinco INFO esperados por las tablas privadas con RLS y sin acceso
directo. Análisis limpios en raíz, Trainer y ADMIN; baterías completas de 1.510,
360 y 365 pruebas correctas, con una omisión previa en raíz y dos en ADMIN.
Veinticuatro comprobaciones de navegación/directorio y dos recorridos
visuales a 320/1200 píxeles (texto 2× en móvil) pasan; capturas con fuentes reales
revisadas. No se da por cerrado el directorio ni su aceptación física.

**Corrección de CI · 30/10/2026:** los primeros procesos de ADMIN/Trainer para
`22b8d554` se detienen en el análisis de la raíz: el ajuste final de fuentes del
script `tools/directory_visual_test.dart` tenía un `if` sin llaves, añadido
después del análisis local anterior. Se corrige el estilo sin cambiar el
comportamiento ni reducir comprobaciones. La publicación posterior conserva los
gráficos `df772e09` del otro chat y su cierre documental `3d9466ab`.

Al superar el análisis, la comprobación de copias detecta además que faltaba
`directory_private` en `BACKUP_SCHEMAS`. Se incorpora al inventario común de
exportación, comprobación de claves foráneas y ensayo aislado de restauración.
Storage ya inventaría todos los buckets, incluido `trainer-directory`. Se
mantienen las comprobaciones de cobertura: no se omite el esquema ni se reduce
la prueba para permitir el despliegue. La corrección no restaura datos remotos
ni cambia la política de copias existente.
Tras la corrección pasan las 46 pruebas de herramientas ADMIN y las 17 de
Trainer, incluidas cobertura de esquemas, rechazo de producción e integridad
del publicador. No se ejecuta una copia real ni una restauración remota.

**Publicación y apertura pública · 30/10/2026:** `366bb341` queda publicado
correctamente en Dev por [Trainer 41137424169](https://github.com/jchjdev/entrenaop/actions/runs/41137424169)
y [ADMIN 41137424137](https://github.com/jchjdev/entrenaop/actions/runs/41137424137).
Verificación HTTPS independiente: revisión y fuentes guardadas, proyecto Dev,
SHA-256 del JavaScript, entrada activa, cabeceras y MIME WebAssembly correctos.

La apertura de la primera publicación `d871ecd7` detectó un 404 en `/directory`:
el portal conserva las rutas en el fragmento, como las invitaciones.
Se centraliza la base pública
`https://trainer.entrenaop.es/#/directory` en `directory/links.dart`, utilizada
por app y Trainer, y se añade una regresión del enlace que copia una ficha web.
El [buscador público](https://trainer.entrenaop.es/#/directory) abre sin iniciar
sesión; un identificador inexistente muestra ficha no disponible, sin datos.
Tras recargar el navegador se comprueba que JavaScript y bootstrap proceden de
la revisión nueva. La corrección supera los tres análisis y las baterías
completas y queda publicada y contrastada. Se cierra este recorrido técnico
inicial, con el piloto comercial y la aceptación física pendientes.
Lectura final en Dev:
publicación deshabilitada, cero ofertas elegibles y cero fichas publicadas.

### Primer contacto en el chat existente · 31/10/2026

Javier aprueba primer mensaje, aceptación/rechazo/bloqueo y continuación dentro
de EntrenaOP, manteniendo el contacto externo. El preparador puede activar
«Recibir contactos por EntrenaOP» en su ficha. El primer mensaje muestra su
finalidad y límites; registrar el aviso de contacto no sustituye la aceptación
de publicación V2, que conserva su contenido y alcance.

Se reutilizan `ConversationView`, `TrainerMessage`, `trainer_private.messages`,
los UUID de reintento y los recibos de lectura. `contact_threads` representa la
solicitud y sus participantes; no duplica los mensajes ni el motor del chat.
El dominio/puerto de contacto es Dart puro; el adaptador Supabase y la composición
visual están separados. El paquete declara la dependencia interna en `entrena_ui`,
ya usada en las apps, sin paquetes externos nuevos. El chat de alumnos conserva
sus interfaces y valores por defecto.

Un usuario con correo confirmado puede iniciar como máximo cinco primeras
consultas en las últimas 24 horas y solo una por pareja. Mientras está pendiente hay un único
mensaje. El preparador conserva MFA; aceptar no crea relación ni consume cupos.
Ambos participantes pueden bloquear la consulta; el bloqueo conserva la lectura
y detiene envíos. En el piloto no se reabre una solicitud rechazada o bloqueada.
La denuncia del preparador usa la revisión existente del directorio; el bloqueo
permite al profesional detener contactos no deseados. No se muestran fotos
personales privadas ni se abren permisos sobre historiales o entrenamientos.

Si ya existe vínculo, se abre su chat. Al formalizarlo después del primer contacto
pendiente o aceptado, los mensajes se enlazan a la relación conservando UUID,
autor, fecha y lecturas. Una consulta rechazada o bloqueada permanece en consulta.
Al reactivar un vínculo, el acceso continúa en su nueva etapa y el historial
anterior permanece en la etapa original.
La transición y los envíos comparten exclusión por alumno; el reintento también
se confirma si la relación se creó durante el envío. Los recibos de lectura
admiten las etapas de esa pareja y rechazan lotes mixtos sin escribir parcialmente.
Si el cambio a alumno ocurre mientras se escribe, el borrador sigue visible para
copiarlo antes de salir; no se envía automáticamente. La bandeja y avisos de
Trainer incluyen las solicitudes y mensajes de contactos con el mismo sondeo
existente. Un intento distinto desde otra pestaña recibe error explícito y
conserva el texto: no se confirma como enviado un mensaje no almacenado.
Desactivar la captación retira nuevas solicitudes; conserva la consulta de
contactos previos. La suspensión impide aceptar o enviar en el contacto.
No se dan por acreditados mensajes reales, aceptación o push hasta
probarlos con las cuentas; no se envían mensajes por Isabel ni por Javier.

**Verificación técnica · 31/10/2026:** las migraciones `20261031114038` y
`20261031123938` están aplicadas solo en `entrenaop-dev`: 259 migraciones
sincronizadas. Pasan los contratos SQL
de contactos, resumen del chat existente, historial/reactivación y fotos privadas;
todos terminan con `ROLLBACK`. Cero contactos reales creados. Sin avisos WARN
nuevos en Advisors; el INFO adicional corresponde a la tabla privada con RLS y
sin acceso directo. La validación final integrada con los cambios de chat/agenda
`bd50a9f7` y `213a6e0c` pasa los cuatro análisis y baterías completas: deportista
1537 (una omisión previa), Trainer 412, ADMIN 365 (dos omisiones previas),
`entrena_ui` 59. Incluye siete pruebas del contacto y su borrador, avisos en
Trainer y uso a 320 píxeles con texto doble.

**Publicación y habilitación · 31/10/2026:** fuente `70f0b4f4` publicada y
contrastada por HTTPS en Trainer y ADMIN: entorno `development`, backend
`sxbxfjqgoddzhtcyhalw`, árbol de fuentes limpio y hashes/recursos correctos.
[Trainer correcto](https://github.com/jchjdev/entrenaop/actions/runs/41203875000)
y [ADMIN correcto](https://github.com/jchjdev/entrenaop/actions/runs/41203875005).
Tras verificarlas se activa el canal en Dev y en la ficha de Javier, preservando
foto, presentación, contactos externos, publicación y consentimiento V2.
La simulación SQL de solo lectura con el contexto de Isabel devuelve primer
contacto disponible; termina en `ROLLBACK` y no equivale a iniciar sesión ni a
probar un envío real. El acceso comercial de Ervi conserva su alcance anterior;
puede elegir el canal desde su ficha. No se modifica producción.

**Revisión del piloto · 31/10/2026:** Javier muestra la solicitud de Isabel y
detecta incoherencia entre el contador de Conversaciones y la bandeja separada
de Solicitudes. La corrección reúne ambas en Conversaciones → Alumnos/Contactos,
con mensajes sin leer por pestaña; la campana abre Contactos directamente.
Cuando solo hay mensajes nuevos de contactos, el acceso de navegación abre
esa pestaña. `/contacts` conserva compatibilidad mediante redirección. Los chats
de contactos ya vinculados pasan a Alumnos y se refresca la lista al regresar.
Se retira la nota general de la bandeja, cuyo «tus entrenamientos» resultaba
confuso para el profesional. En el chat se explica explícitamente la espera,
el rechazo o el bloqueo y la posibilidad de escribir tras aceptar.

El chat aceptado ofrece «Invitar como alumno» al preparador. Abre Alumnos con
el diálogo existente de invitación: solicita el correo de la cuenta de EntrenaOP,
prepara el enlace personal y el preparador decide cómo compartirlo. Abrir el
diálogo no crea invitaciones ni vínculos. Se conservan cupos, MFA y aceptación
del destinatario; no se consulta ni revela su correo privado desde el contacto.
La preparación y los reintentos reutilizan el recorrido existente. Esta entrega
no incorpora una invitación enviada automáticamente dentro de los mensajes.
La corrección pasa los cuatro análisis y las baterías completas: deportista 1541
(una omisión previa), Trainer 415, ADMIN 365 (dos omisiones previas), UI 59.
Incluye apertura desde el aviso y la navegación, contadores a 320 píxeles y
texto doble, solicitud aceptada al volver, traslado a Alumnos y preparación de
la invitación sin alta automática ni desbordar el cupo. No cambia contratos SQL,
permisos o datos reales.

**Publicación comprobada de la corrección · 31/10/2026:** implementación
`3ecd5e72`; ADMIN publicado en esa revisión. Trainer se publica desde `76306efa`,
que incorpora únicamente avances documentales sobre el mismo código. Las
subidas documentales simultáneas hicieron actuar el control de main y detener
tres intentos de publicación; se coordinó la espera con los chats activos y se
conservaron las comprobaciones. El último proceso de
[Trainer termina correctamente](https://github.com/jchjdev/entrenaop/actions/runs/41218293954);
[ADMIN también está correcto](https://github.com/jchjdev/entrenaop/actions/runs/41214560406).
Verificación HTTPS independiente de ambos: revisiones esperadas, entorno Dev,
backend `sxbxfjqgoddzhtcyhalw`, fuentes limpias y recursos/hashes correctos.
El siguiente recorrido del directorio es la invitación real y su aceptación por
Isabel, con continuidad del historial. Esta comprobación técnica no la vincula.

**Siguiente recorrido:** cargar el código nuevo mediante Hot Restart en localhost
y recargar Trainer. Isabel entra en Mi preparador → Buscar preparador → ficha de
Javier → Contactar en EntrenaOP y envía el primer mensaje. Javier lo revisa en
Conversaciones → Contactos, acepta y responde. Después abre «Invitar como alumno»,
prepara y comparte el enlace para que Isabel lo acepte, y se comprueba
que la invitación y aceptación del vínculo conservan esa misma conversación.

### Piloto con Javier y Ervi · 31/10/2026

El recorrido inicial de publicación ya está confirmado: tras actualizar la
pestaña antigua, Javier publica con aceptación V2 y visualiza su ficha desde
localhost. Confirma que correo y WhatsApp se abren; su nueva petición es poder
iniciar el contacto mediante la conversación de EntrenaOP.

Javier confirma el alcance del ensayo e incluye a Ervi para comparar varios
preparadores y filtrar por localidad. Solo se habilitan estas dos cuentas en
Dev, hasta el 28/11/2026 a las 21:07:47 UTC, fin del ensayo vigente de Javier.
Ervi mantiene su acceso profesional y participa en ese mismo periodo sin crearle
contratación ni pagos. Los planes comerciales pagados intermedio/superior siguen
siendo el criterio general futuro; precios y catálogo completo no se aprueban.

`directory_private.dev_pilot_members` separa el permiso individual de las
ofertas. La elegibilidad exige acceso profesional vigente, permiso no revocado,
fecha vigente y periodo fuente no vencido; el JWT debe proceder de Auth Dev.
El piloto solo admite visibilidad app, también al consultar enlaces y fotos.
El servidor rechaza publicar en web con este permiso. Isabel y los demás usuarios
identificados con correo confirmado pueden buscar y consultar sin comprar un
plan profesional. Encontrar/contactar no crea vínculos; se mantienen los dos
preparadores máximos y el contacto externo.

Contrato y presentación de privacidad/condiciones compartidos en
`trainer_access/directory`, sin dependencias nuevas ni imports entre aplicaciones.
La aceptación V2 identifica destinatarios, finalidad y retirada; la información
ampliada incluye responsable/contacto vigentes, datos, conservación, proveedores,
derechos y moderación. Es accesible desde búsqueda, ficha y editor, incluso a
320 píxeles con texto 2×. Cada propietario debe aceptarla y publicar expresamente
desde Trainer. Guardar un borrador no publica. La versión y fecha se conservan
por revisión en `publication_acceptances`, incluso al pausar la ficha. Los
clientes antiguos pueden guardar borradores, pero no publicar sin la versión V2.
Las fotos tampoco permiten firmar URLs que mantengan acceso tras retirar la ficha.

La migración `20261031084002_trainer_directory_dev_pilot` pasa ambos contratos
SQL antes y después de aplicar solo en Dev, siempre con ROLLBACK. El cotejo al
aplicar acredita 256 revisiones locales/remotas coincidentes. El asesor conserva
los WARN anteriores;
solo añade dos INFO esperados por las tablas privadas sin acceso directo.
La copia/recuperación existente incluye `directory_private`. La búsqueda prueba
dos preparadores/localidades, filtro parcial sin distinguir mayúsculas,
caducidad/revocación, emisor de otro proyecto, MFA/correo confirmado,
consentimiento antiguo, visibilidad web y rechazo de fotos firmadas.
El 31/10 se habilitan exclusivamente Javier y Ervi con periodo efectivo hasta
el 28/11/2026 a las 21:07:47 UTC. Ambos conservan acceso profesional y MFA;
Isabel tiene correo confirmado. Lectura posterior: dos permisos activos,
cero ofertas con derecho de directorio y cero fichas publicadas. Javier conserva
su borrador y Ervi todavía debe crear el suyo. No se modifica ninguna aceptación
ni se publica por los titulares.

Validación aislada desde `56054fc5` más este bloque, equivalente al código de
main antes del guardado (los commits posteriores solo actualizan documentación):
análisis limpios, app 1.526 pruebas correctas y una omisión previa, Trainer 402,
ADMIN 365 y dos omisiones previas. Cuatro regresiones cubren comparar/filtrar,
información ampliada móvil, versión enviada y permiso temporal, y publicación
sin aceptación automática. Se corrige el selector de modalidad que desbordaba
a 320 píxeles con texto 2×. CI de `559051c1` reconfirma los tres análisis y las
baterías completas, junto a las 46 pruebas de herramientas ADMIN y 17 de Trainer:
[Trainer](https://github.com/jchjdev/entrenaop/actions/runs/41187614052),
[ADMIN](https://github.com/jchjdev/entrenaop/actions/runs/41187614125).
Ambos portales Dev publicados desde esa revisión y contrastados de forma
independiente por HTTPS: identidad Dev/proyecto, fuentes guardadas, SHA-256 del
JavaScript, entrada activa, cabeceras y MIME WebAssembly correctos. El buscador
web público mantiene el alcance web; la comparación del piloto se hace desde
Buscar preparador en la app. No se modifica la web comercial ni producción.

**Guardado observado tras activar:** Javier comunica el error genérico de acceso.
Los registros de las 09:24:59 y 09:25:04 UTC muestran 403 en el control de
publicación de `directory_private.save`, línea 12. La consulta propia anterior
responde 200; cuenta, emisor Dev, acceso profesional y permisos están vigentes.
El borrador permanece en revisión 3, con aceptación V1 y sin publicar. La hipótesis
principal es una pestaña anterior que no envía V2; falta contrastar el texto de
la casilla. Se indica preservar lo editado guardando con Publicar ficha apagado
y recargar solo tras confirmar el borrador. La publicación real y su recepción
en la cuenta de Isabel siguen pendientes de confirmar.

**Siguiente recorrido:** Javier y Ervi revisan su localidad/contactos/foto,
aceptan y publican sus fichas desde Trainer. Isabel abre Buscar preparador,
compara, filtra por localidad y consulta contacto/favoritos.

### Preparación del piloto con Javier · 31/10/2026

Esta sección conserva el diagnóstico previo a la aprobación. El alcance
confirmado y la habilitación vigente están en el piloto con Javier y Ervi
documentado arriba.

Javier pide comenzar por su cuenta y comunica que ha rellenado la ficha pero
no consigue subirla. Ervi mantiene su participación posterior; no se habilita
ninguna cuenta ni se publica contenido por esta petición de diagnóstico.

Lectura de `entrenaop-dev`: publicación apagada, única oferta «Ensayo de
contratación · sin cobro real» sin derecho de directorio, una foto subida y cero
fichas guardadas. La cuenta de la foto tiene contratación de ensayo con periodo
vigente. Son dos asuntos distintos: guardar un borrador no exige elegibilidad
comercial, mientras publicar sí la exige. Se solicita el mensaje de «Guardar
ficha» antes de atribuir el fallo a una causa concreta o recargar el formulario.

**Recomprobación del 31/10, tras el guardado:** Dev contiene una ficha en
borrador, con visibilidad solo app y sin suspensión; ninguna está publicada.
La publicación global sigue apagada y no hay ofertas con derecho de directorio.
Por tanto, el guardado ya tiene evidencia, pero la ficha no aparece al buscar
desde la cuenta de Isabel. «Buscar preparador» abre el directorio; la pantalla
Resumen muestra el contenido recibido y el acceso a vínculos/historial. Se
mantiene pendiente concretar la elegibilidad del ensayo y los textos antes de
habilitar el piloto; el titular deberá aceptar su publicación desde el formulario.
Esta comprobación es de lectura y no cambia cuentas, ofertas ni consentimientos.

Para el piloto se propone concretar el derecho del directorio en la oferta de
ensayo y limitar su alcance a la cuenta de Javier en Dev, sin convertirla en un
plan comercial aprobado ni simular pagos. Esta propuesta sigue pendiente de
confirmar. El reparto futuro básico sin anuncio e intermedio/superior pagados
con anuncio conserva el acuerdo previo; precios, nombres y catálogo completo
no se consideran decididos por iniciar este ensayo.

Quedan por cerrar las condiciones de publicación y moderación, la información
de privacidad correspondiente y el texto de autorización según visibilidad:
solo app para usuarios identificados o también web pública sin cuenta. Deben
explicarse los datos/contactos publicados, la retirada y sus límites, y no
presentar el directorio como verificación de titulaciones. Se conservará la
aceptación expresa del titular desde el formulario; no se acepta en su nombre.

**Avisos al guardar · 31/10/2026:** Javier concreta que el botón «no hace
nada». Se reproduce un defecto de presentación: validaciones locales y errores
del repositorio solo se mostraban al principio del formulario, fuera de la
vista al guardar desde abajo. El editor muestra ahora un aviso inmediato y
mantiene el motivo junto a «Guardar ficha». Reintentar conserva la edición y
el guardado confirmado sustituye el aviso anterior. También se aplican los
avisos visibles a errores de carga y gestión de fotos.

Dos regresiones fallan con la versión anterior y pasan con la corrección:
validación visible desde el final y rechazo del repositorio seguido de
reintento con el texto editado. La prueba existente conserva el guardado de
borrador sin derecho de publicación. Esto corrige el aviso oculto; todavía no
identifica el dato o rechazo concreto de la ficha real de Javier. No se cambian
validaciones, permisos, ofertas ni consentimientos, ni se activa el piloto.
Análisis Trainer limpio y batería completa de 362 pruebas correcta. La revisión
`e111cf5b` queda publicada en Trainer Dev por
[41144218840](https://github.com/jchjdev/entrenaop/actions/runs/41144218840), con
validación y despliegue correctos. Verificación HTTPS independiente: proyecto
Dev, fuentes guardadas, revisión, SHA-256 del JavaScript, entrada activa,
cabeceras y MIME WebAssembly. La comprobación del guardado con los datos reales
de Javier sigue pendiente; no se da por guardada ni publicada su ficha.

## Dos circuitos comerciales

1. El preparador contrata EntrenaOP con un cupo de alumnos activos. Los tramos
   deben ser configurables; 5, 7 o 100 son ejemplos de capacidad, no tarifas ni
   planes de venta aprobados. El servidor debe hacer cumplir el cupo y permitir
   concesiones manuales auditadas, separadas de la compra.
2. El alumno paga a su preparador por el servicio. El portal debe ayudar a
   gestionar esos cobros, aparte de lo que el preparador paga a EntrenaOP.

Javier vuelve a incluir expresamente ambos circuitos en el alcance de la
plataforma. No ha elegido proveedor, precios, comisiones, periodicidad ni reglas
de impago/reducción de cupo. No hay cobros profesionales reales implementados.
No sustituirlos por un botón de pago sin conciliación de servidor.

Para desarrollar los cobros se propone catálogo de planes/capacidad, estado
canónico del proveedor, eventos idempotentes, conciliación y auditoría; después
suscripciones del alumno a su preparador, recibos/estado de pago y devoluciones
según el proveedor y contrato elegidos. La interfaz no concede derechos por una
redirección exitosa del navegador. No se suspende ni archiva automáticamente al
alumno por un estado comercial cuya regla todavía no esté acordada.

## Seguimiento que debe aportar valor

El resultado individual ya muestra prescrito frente a realizado, RPE, comentarios
y formatos de carrera/fuerza. La siguiente ampliación de seguimiento propuesta
es cumplimiento en un periodo, sesiones realizadas/pendientes, últimas marcas y
evolución por prueba o ejercicio. Las métricas deben explicar su periodo, origen
y tratamiento de sesiones omitidas/retiradas. No contar una sesión futura como
incumplimiento ni convertir rondas AMRAP en series inventadas.

La ampliación local añade una bandeja persistente de revisión, conversaciones,
formularios y consulta longitudinal del servicio. El inicio declara sus periodos
y paginación; no afirma detectar a todos los alumnos sin pauta ni enviar alertas
push. Abrir un resultado no lo marca automáticamente como revisado. Véanse los
contratos específicos antes de interpretar una cifra parcial como total.

La planificación debe permitir adaptar una receta para una persona conservando
la biblioteca reutilizable, revisar fechas y avisar de coincidencias con el plan
automático sin sustituirlo. TRN-017 permite fechas explícitas, fases y repetición
finita de una pauta; no implementa arrastrar citas, recurrencia indefinida ni
adaptación automática del algoritmo profesional.

## Recursos, continuidad e integraciones

Los cupos de alumnos no sustituyen los límites técnicos de contenido y medios.
Antes de habilitar ejercicios propios con imágenes o vídeo se necesitan propiedad
profesional, acceso del alumno por recurso asignado, revisión versionada y cuotas
de almacenamiento/subida verificadas en servidor. No se acuerdan creaciones ni
medios infinitos, ni se reutiliza por accidente la cuota personal Free. TRN-019
concreta el piloto confirmado: 500 ejercicios/versiones y 1.000 reservas de imagen
de hasta 500 KB. Son límites técnicos configurables, no planes de pago. Los
archivos de vídeo profesionales se añaden en la ampliación local descrita en
[TRAINER_PRIVATE_VIDEOS.md](TRAINER_PRIVATE_VIDEOS.md), con límites propios;
los enlaces externos HTTPS siguen disponibles sin realojarlos.

La baja conserva la cartera e historial del servicio y libera la plaza conforme
a TRN-015/016. Retornar requiere nueva aceptación. El archivo es recuperable;
una futura purga no se confunde con desactivar una cuenta o cancelar un pago.

Javier lleva la conexión de relojes en otro chat. Este trabajo no implementa
integraciones de Garmin u otros fabricantes ni presupone sus condiciones de
API. Los futuros datos deberán conservar origen, unidades y referencias de
actividad para evitar duplicar entrenamientos o alterar resultados históricos.

## Criterio de entrega

Se valida el recorrido completo: crear contenido privado → asignarlo a otro
usuario → verlo y realizarlo en la app → consultar resultados autorizados →
revisar contenido → comprobar que el historial anterior no cambia. Añadir
aislamiento entre profesionales, MFA, reintentos, concurrencia, baja/vuelta,
cuotas, móvil estrecho y recuperación de errores. La publicación web Dev, la
distribución de la app móvil y el lanzamiento comercial son hitos distintos.

## Ritmo realizado por tramo · 30/10/2026

La ficha compartida de resultados de carrera muestra el ritmo medio del tramo
completado junto a su distancia y tiempo. Reutiliza el cálculo de
`workout_core`: duración medida del dispositivo cuando existe, en otro caso la
registrada, dividida por la distancia real. No suma recuperación ni sustituye
una distancia ausente por la pautada. La cifra visible se redondea al segundo
por kilómetro; la comparación interna mantiene su precisión. Sin tiempo o
distancia válidos, o sin tramo completado, no se presenta un ritmo calculado.

La ampliación siguiente implementa el gráfico y la regularidad descritos abajo.
No se presumen datos fisiológicos ausentes.

## Gráfico de ritmos y regularidad · 30/10/2026

`running_pace_analysis.dart` proyecta las instantáneas ya autorizadas de resultados;
reutiliza `reviewSetFromJson` y su prioridad de tiempo medido. La muestra conserva
fase, bloque, posición, objetivo, medida y recuperación. Se ordena por la receta,
sin alterar resultados ni unir huecos de series omitidas o sin medición válida.
Las fases antiguas/desconocidas no se atribuyen a carrera de esfuerzo.

`RunningPaceChart` en `workout_editor_ui` dibuja con Flutter, sin añadir paquetes.
Trainer y la consulta profesional móvil lo reciben desde
`TrainerWorkoutResultContent`; el historial del deportista usa el mismo componente
con el adaptador de su ejecución tipada y la revisión que ya calcula. No se importa
una aplicación dentro de otra ni se duplica la interfaz completa de resultados.

- Eje horizontal por serie/tramo; eje vertical en min/km, ritmos más rápidos arriba.
- Rango de objetivo independiente por muestra, con medidas sin redondear al dibujar.
- Series de esfuerzo por defecto; Todos los tramos permite ver las otras fases.
  Si faltan las fases, se muestran todos y se explica la falta de clasificación.
- Huecos sin valores inventados; no se conectan puntos a través de una repetición
  sin ritmo ni de cambios de fase/bloque. Desplazamiento horizontal en móvil.
- Ratón, teclado y toque dan acceso al ritmo, distancia, tiempo, objetivo,
  recuperaciones y RPE registrado. Consulta sin operaciones de escritura.
- Media = suma de tiempos / suma de distancias, convertida a s/km. Se excluyen
  muestras incompletas o sin medidas válidas; los ritmos visibles se redondean al
  segundo y las diferencias de regularidad conservan centésimas al mostrarse.
- Regularidad: grupos con al menos dos esfuerzos completados del mismo bloque,
  distancia y objetivo de ritmo/tiempo, modalidad y pauta de recuperación/descanso.
  La distancia realizada debe estar dentro del 1 % de la pautada, coherente con la
  tolerancia de distancia de la revisión. Una serie parcial no entra en el grupo.
- Se propone el grupo mayor y se puede cambiar entre grupos. Se muestra diferencia
  máxima de ritmos y última frente a primera entre los registros completados.

El gráfico representa toda la ejecución; el filtro de diferencias permanece en
el detalle situado debajo. No es una nueva nota deportiva ni un análisis de pulso,
VFC o trazas instantáneas. No requiere migraciones ni llamadas adicionales al servidor.

Validación local del 30/10/2026: análisis limpio y batería completa de raíz con
1.503 pruebas correctas (una omisión existente), Trainer con 359 y ADMIN con 365
(dos omisiones existentes). Se validó el cambio en una copia aislada de main para
excluir el directorio profesional en curso. Las 11 pruebas del gráfico compartido
cubren fases, huecos, precisión, correcciones, teclado, toque y detalle con texto
2× en 320/1200 px, claro y oscuro. Catorce pruebas de dominio cubren media ponderada,
medida del dispositivo, datos incompletos y agrupación. Capturas del componente
real revisadas en escritorio claro/oscuro y móvil. La app necesita una nueva
compilación para recibir el gráfico; no se genera APK en este bloque.

### Publicación del análisis de carrera · 30/10/2026

Revisión `df772e09` publicada automáticamente en Dev:
[Trainer 41104213468](https://github.com/jchjdev/entrenaop/actions/runs/41104213468)
y [ADMIN 41104213480](https://github.com/jchjdev/entrenaop/actions/runs/41104213480),
ambos correctos en validación y despliegue. La verificación Garmin de la misma
revisión termina correctamente sin publicar Garmin. Comprobación HTTPS
independiente: revisión y proyecto Dev correctos, entrada activa, integridad del
JavaScript, cabeceras sin caché y MIME WebAssembly verificados en ambos portales.

- Trainer: `c56007ee5c94f4e5e10b1161946f8236af129169f720cf94974b8041f38342cb`.
- ADMIN: `14f9a674a54eb0caac82c9a974a7d0b393c5096fe40bbecb1063985b46210b7c`.

El código móvil está guardado en main; esta publicación no instala una nueva
versión de iOS o Android. La aceptación con el iPhone queda para su siguiente
compilación, a cargo de Javier conforme a lo acordado.

## Creación compartida y planes sandbox · 31/10/2026

El creador compartido abre el selector al pulsar una posición vacía «Elegir
ejercicio», conservando las dosis. La configuración del bloque del inspector
se abre inicialmente. Trainer y ADMIN permiten insertar calentamientos
publicados desde «Insertar calentamiento» en sesiones de fuerza, también al
crear sesiones dentro de programas. El consumidor aporta la lectura autorizada;
el editor solo compone recetas. Se usa una fachada SQL paginada, con identidad,
MFA y autoría profesional activa (o ADMIN). Solo entrega versiones publicadas
oficiales cuyos ejercicios son públicos; no se abre la RLS de sus plantillas.

Insertar **copia** los bloques a la sesión editable, sin modificar ni vincular
la plantilla oficial. El formato interno warm_up se convierte a series
convencionales, como al editar calentamientos en ADMIN, para conservar incluso
cantidades de series diferentes por ejercicio. No concede autoría oficial ni
cambia la prohibición de enlazar calentamientos oficiales en programas privados.
Los segmentos de calentamiento de carrera conservan su circuito existente.

Suscripción muestra un selector de cupo y tres niveles del catálogo sandbox;
Básico permite ensayar el suplemento de directorio como una oferta conjunta.
Un pago pendiente muestra y conserva su oferta. Por ahora el pago solo activa
acceso/cupo: Pro y concesión comercial del directorio siguen pendientes y así
se indica en pantalla. [Contrato](TRAINER_COMMERCIAL_CONTRACT.md).

Validación del bloque: análisis sin incidencias en una copia de HEAD con los
cambios propios; 1.549 pruebas de raíz (una omisión declarada), 365 de ADMIN
(dos omisiones declaradas), 421 de Trainer, 246 del editor compartido y 40 del adaptador de
contratación. Los contratos SQL de catálogo, cupo, identidad, MFA e idempotencia
terminan en ROLLBACK. Se contrastan cuatro migraciones propias aplicadas en Dev
y los veinte precios activos del sandbox contra sus ofertas del servidor.
No se incorporan los cambios Apple o promocionales abiertos en otros trabajos.
La primera aceptación manual de Checkout se acredita en la sección posterior.

### Publicación comprobada del catálogo y creador · 31/10/2026

El código de `eaf091ec` está incluido en la revisión publicada `9ee9acfa`.
Trainer termina correctamente en [41227859256](https://github.com/jchjdev/entrenaop/actions/runs/41227859256)
y ADMIN en [41228571275](https://github.com/jchjdev/entrenaop/actions/runs/41228571275).
Se verifican por HTTPS identidad, revisión, arranque y hash de JavaScript de
ambos portales: `development`, proyecto `sxbxfjqgoddzhtcyhalw`. Publicación
automática, sin administrador de archivos Hostinger. Las 421 pruebas de Trainer
incluyen conservar la oferta pendiente y recuperar la contratación preparada
por otra pestaña. En esta publicación inicial aún faltaba la prueba manual, acreditada después.
El ensayo activa acceso/cupo, no concede aún Pro ni la
elegibilidad comercial del directorio. No se activan cobros reales.

### Aceptación del primer pago del catálogo nuevo · 31/10/2026

Javier completa Checkout y entra al panel. Se contrastan el pedido con su sesión
Stripe de sandbox: estado complete, payment_status paid, livemode false,
2.490 céntimos EUR y la misma suscripción. En Dev queda una factura registrada,
contrato activo, cupo efectivo de cinco y manual_enabled=false: las plazas
proceden del pago, sin regalo de ADMIN. Corresponde a Completo · 5 alumnos,
24,90 EUR ficticios/mes y cobertura hasta el 30/11/2026. No concede todavía
Pro o elegibilidad comercial del directorio. Se acredita este caso, no veinte
compras por Checkout ni cobros reales.

Javier indica que creía haber elegido más de cinco plazas. El contrato y Stripe
registran cinco; no hay evidencia de qué selección mostró antes el navegador.
La revisión detecta una vía que reiniciaba el cupo: al abrir el autenticador se
sustituía la contratación. Se conserva ahora su pantalla apilando la verificación
y regresando a ella; las entradas directas al autenticador mantienen la vuelta
normal a Suscripción. Volver no inicia pagos automáticamente. La regresión
elige diez plazas y complemento, verifica MFA, conserva la selección y envía
solo esa oferta al confirmar de nuevo. No se modifica la suscripción probada
ni se concede cupo manual para ocultar la diferencia. Los cambios de plan de
una suscripción activa siguen fuera del ensayo implementado.

La corrección pasa flutter analyze y las 422 pruebas de Trainer, incluida la
regresión de vuelta de MFA sin cambiar diez plazas ni su complemento.
