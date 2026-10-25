# Producto EntrenaOP

**TRN-030 · 25/10/2026 · publicado y verificado en Dev:** Trainer y ADMIN aprovechan el espacio
de escritorio mediante bibliotecas, composición y detalle en contexto. La ficha
del alumno separa planificación, resultados, técnica, evolución, formularios,
conversación, notas e historial; mantiene pruebas y calendario compartido.
La revisión final `6fe1d35c` añade propiedades de la selección en fuerza/carrera,
fases y sesiones resumidas, guardado fijo y ejercicios en dos columnas, usando
los mismos creadores en ambos portales. La pasada visual de las pantallas actuales
está completada y publicada; la aceptación humana sigue pendiente.
Arrastrar a la agenda exige revisar y confirmar. La autoría oficial y la privada
conservan permisos independientes. Pagos y activación push siguen pospuestos.
[Alcance y evidencia](TRAINER_DESKTOP_2026_10_25.md).

**TRN-029 · 24/10/2026:** Trainer permite retomar sesiones internas de programas
y adaptaciones sin modificar la pauta hasta confirmar. Las etiquetas de ejercicios
son privadas por autor/contexto y se comparten como capacidad de editor con ADMIN.
La app del alumno prepara avisos push opcionales; permanecen desactivados en Dev
hasta configurar proveedor/Apple y aceptar recepción física. Los avisos internos
y la campana condicionada a novedades siguen siendo el acceso disponible.
[Alcance y activación](TRAINER_PUSH_NOTIFICATIONS_2026_10_24.md).

**Preparación compartida · TRN-028 · 24/10/2026:** El alumno puede recibir pautas de dos
preparadores. Decide si ambos pueden consultar su calendario y pautas para coordinar
carga; no comparte los demás alumnos, conversaciones, resultados ni notas privadas de
los profesionales.
[Contrato y evidencia](TRAINER_MULTI_COACH_2026_10_24.md).

El historial del deportista y el resultado profesional permiten filtrar
opcionalmente las diferencias con la pauta y comparar dos ejecuciones de la
misma sesión/versión. Se conservan datos ausentes, omisiones y contexto; las
diferencias numéricas no son una nota deportiva ni una detección automática de
progreso. [Alcance](TRAINER_PRIVATE_WORKOUTS.md#revisión-y-comparación--24102026).

INT-013 amplía en Dev el ciclo Garmin a fuerza profesional por series para
tres variantes de catálogo comprobadas. Mantiene el creador de las tres apps,
los derechos de cuenta y el cierre revisado del alumno; guarda repeticiones y
kilos observados sin copiar la pauta como resultado. Otros formatos y fuerza
especializada del algoritmo siguen pendientes. El ciclo técnico completo se
comprueba con fēnix 8 y una actividad simulada, sin acreditar ejercicio físico
real. INT-014 muestra tiempos legibles y explica diferencias sin una nota
de calidad. [Cobertura y límites](DEVICE_GARMIN_TRAINING.md#fuerza--recorrido-solicitado-int-013).

INT-012 incorpora en Dev la recepción de carreras Garmin y su revisión desde
Perfil → Garmin → Carreras recibidas. El alumno elige una sesión pendiente,
comprueba vueltas y esfuerzo y confirma para completar su semana e historial.
No se completa nada por recibir una notificación. El retorno de la carrera
física del alumno queda aceptado desde la app web en Dev: recibe FIT, revisa
vueltas y completa la cita con un solo resultado. Nuevo menú iPhone por actualizar.
[Estado y límites](DEVICE_GARMIN_ACTIVITY_RETURN.md).

UI-061 extiende a fuerza las tarjetas por formato, colores, plegado y arrastre
del creador común. Se puede mover el bloque completo o sus ejercicios sin
perder series, rondas y descansos. No habilita todavía fuerza en Garmin.
La primera carrera física de Trainer en fēnix 8 queda contrastada el 23/10;
su enfriamiento era por tiempo. La recepción no completa automáticamente la
cita en EntrenaOP ni acredita el ciclo de cambios/cancelaciones del reloj.
[Creador de fuerza](WORKOUT_EDITOR_SHARED_2026_10_22.md#fuerza-compacta--ui-061).
[Prueba física](DEVICE_GARMIN_TRAINING.md#carrera-física-completa--23102026).

INT-011 compacta el creador común de carrera: resúmenes plegables, series iguales
agrupadas y recuperación con objetivo propio dentro de su tramo. «Sin objetivo»
oculta y retira los ritmos; solo se ofrecen objetivos libres y de ritmo.
[Interfaz y límites](WORKOUT_EDITOR_SHARED_2026_10_22.md#creador-de-carrera-compacto--int-011).

INT-010 permite activar en Dev la sincronización de las carreras próximas del
entrenador y del plan adaptativo, incluidos cambios y cancelaciones, sin abrir
EntrenaOP para cada envío. Requiere derechos y permiso Garmin en servidor;
Garmin Connect sigue sincronizando con el reloj. Primera ventana: catorce días.
[Estado y límites de aceptación](DEVICE_GARMIN_AUTOMATIC_SYNC.md).

**INT-008 · 22/10/2026 · un creador de sesiones para las tres apps:** deportista,
ADMIN y Trainer consumen el mismo formulario de carrera/fuerza mediante sus
adaptadores y permisos propios. Se conservan versiones y recuperación de
borradores; crear fuerza no implica todavía poder enviarla a Garmin. INT-009
incorpora tipos de paso de carrera, tiempo/distancia/avance manual y objetivos
libre o ritmo en las tres apps. Se conserva su semántica al guardar y ejecutar;
el exportador Dev admite avance hasta Lap. La prueba física nueva y los
objetivos de pulso/cadencia/potencia siguen pendientes.
[Alcance de carrera V2](RUNNING_STEPS_V2.md).
[Implementación y límites](WORKOUT_EDITOR_SHARED_2026_10_22.md).

**TRN-025 · 22/10/2026 · navegación del alumno:** Inicio, Mi plan, Biblioteca y
Evolución son destinos generales. Preparador se añade cuando existe vínculo
activo/anterior o seguimiento propio que consultar. Perfil se abre desde el
icono superior y conserva cuenta, preferencias y suscripción personal. La
campana solo aparece con avisos sin leer. Inicio resume esas novedades en una
tarjeta; Preparador concentra recursos, avisos e historial, sin borrar el acceso
cuando termina un vínculo. Implementación Flutter verificada; actualización en
el dispositivo pendiente. [Detalle](ATHLETE_TRAINER_NAVIGATION_2026_10_22.md).

**INT-006 · 22/10/2026 · Salud para todos e integraciones directas de pago:**
Javier aclara que Salud y Health Connect permiten lectura/importación también
en Free. Se corrige la interpretación anterior que los reservaba al pago.
Las conexiones directas a fabricantes y sus nuevas lecturas/sincronizaciones
se reservan a Pro vigente o alumnos con servicio profesional vigente.
Estos últimos no necesitan Pro adicional para
su servicio. El envío inicial al reloj se limita a prescripciones autorizadas
del algoritmo o del entrenador; otras sesiones compatibles podrán añadirse
después para esos usuarios con acceso. La baja conserva el historial y la
lectura/importación de Salud/Health Connect; detiene operaciones comerciales
nuevas. INT-005 prepara en código el control de acceso de la conexión Garmin;
su servidor está publicado y configurado solo en Dev, con conexión y retirada
reales aceptadas desde navegador. INT-007 acredita además el primer envío y
recepción/inicio en fēnix 8 desde iPhone; recepción de actividades y fidelidad
completa de pasos/alertas siguen pendientes. No corresponde bloquear Salud o
Health Connect por ser Free.
[Reglas y límites](DEVICE_INTEGRATIONS.md).

**TRN-022 · 21/10/2026 · continuidad y seguimiento visible:** Trainer permite
retomar sesiones incompletas y nuevas versiones de biblioteca con el editor
compartido. TRN-025 traslada los recursos al espacio Preparador y deja en Inicio
un resumen compacto de avisos; dispone de formularios, conversación, pruebas y acceso directo
a técnica de sus sesiones profesionales. Abrir un aviso no lo marca leído ni
completa su tarea. Las demostraciones preparadas se pueden elegir al crear o
editar ejercicios sin subirlas otra vez. Servidor Dev aplicado y contratos
verificados; publicación web e instalación móvil se acreditan por separado.
Persisten los pendientes de hijos de programa/adaptación, push y cobros reales.
[Evidencia y límites](TRAINER_STUDENT_RECOVERY_2026_10_21.md).

**ADM-008 · 21/10/2026 · sesiones incompletas y pendientes:** ADMIN conserva
campos sin terminar, permite retomarlos y confirma el guardado sin crear otra
versión por un reintento. Dentro del programa conserva el destino de la sesión y
la publicación conjunta. Inicio reúne trabajo por continuar, calidad y diagnóstico
existente de copias/errores. El editor conserva su diseño. Portal Dev publicado y
recuperación comprobada en Chrome; aceptación de Javier pendiente.
[Contrato y límites](ADMIN_SESSION_RECOVERY_2026_10_21.md).

**TRN-021 · 21/10/2026 · programas que pueden retomarse:** código y servidor Dev
incorporan trabajos privados incompletos mediante el creador compartido con
ADMIN. Guardar el trabajo conserva campos pendientes; finalizar valida y crea
la versión asignable. Recargar y renovar sesión conservan su identidad; los
reintentos y otras pestañas no sobrescriben silenciosamente. Interfaz publicada
en Trainer Dev desde `37dcd14`, con HTTPS y entrada al editor comprobados en
Chrome; la recuperación de sesiones internas sigue pendiente.
[Contrato](TRAINER_PROGRAM_WORK_DRAFTS.md),
[publicación](TRAINER_RECOVERY_RELEASE_2026_10_21.md).

**INT-004 · 21/10/2026 · Carreras de Salud:** la app incorpora consulta e
importación explícita al historial privado de la cuenta, con servidor Dev
verificado. No confirma entrenamientos ni entrega historial a preparadores.
Lectura nativa inicial iOS; Health Connect principal, distribución y aceptación
física de este consumidor pendientes. [Estado y límites](DEVICE_RUNNING_HISTORY.md).

**TRN-020 · 21/10/2026 · ampliación profesional en desarrollo:** los dieciséis
puntos se trabajan coordinadamente. ADMIN y Trainer consumen los mismos
creadores mediante adaptadores independientes; publicación oficial y contenido
privado conservan sus permisos. La implementación local amplía operativa,
seguimiento, formularios, comunicación y medios. Se validan integración y
concurrencia antes de distribuirla. Las pruebas/simulacros tipados fijan protocolo, intentos y marcas sin crear
ejecuciones de entrenamiento ficticias; los cobros reales y el algoritmo profesional no se presentan como
operativos. [Estado y límites](TRAINER_OPERATIONAL_WORKFLOW.md).

**TRN-019 · 21/10/2026 · ejercicios profesionales:** creador compartido con
ADMIN, biblioteca privada, versiones conservadas e imágenes privadas, conectados
a sesiones/programas y lectura autorizada del alumno. Límites piloto confirmados:
500 ejercicios/versiones y 1.000 imágenes reservadas de hasta 500 KB, separados
del cupo de alumnos y de las cuotas personales. Vídeo por enlace externo; subida
de vídeo y pagos siguen pendientes. El código del deportista se adapta, sin
acreditar instalación en un móvil. [Contrato y evidencia](TRAINER_PRIVATE_EXERCISES.md).

**TRN-017/018 · 21/10/2026 · programas privados y plataforma profesional:** el
preparador ya puede montar programas con el creador común, pautar fases/sesiones
en fechas concretas y consultar su agenda mensual en Dev. La biblioteca es
reutilizable con cualquier alumno activo y conserva versiones. El alcance
acordado incluye además ejercicios propios (TRN-019), seguimiento, cobros del
alumno a su preparador y contratación de EntrenaOP por cupos configurables;
seguimiento agregado y cobros siguen pendientes, sin tarifas/proveedor elegidos.
La integración de relojes
lleva su bloque propio. [Alcance](TRAINER_PLATFORM.md) y
[programas/agenda](TRAINER_PRIVATE_PROGRAMS.md).

**TRN-016 · 21/10/2026 · sesiones privadas, pautas y resultados en Dev:** el
preparador crea y revisa recetas con el editor compartido, las pauta desde la
ficha del alumno y consulta sus resultados. El alumno utiliza agenda, ejecutor
e historial sin Pro adicional y mantiene sus cuotas personales. La baja retira
pendientes y conserva lo realizado; una revisión no altera pautas anteriores.
ADMIN reutiliza el lector sin obtener acceso a entrenamientos privados ajenos.
El código nuevo del deportista aún no está distribuido ni hay aceptación humana
con dos cuentas. [Alcance y evidencia](TRAINER_PRIVATE_WORKOUTS.md).

**TRN-010 · 21/10/2026 · acceso y clientes profesionales:** panel web independiente
preparado para trainer.entrenaop.es, con contraseña y TOTP obligatorio. ADMIN
gestiona acceso/cupo y lista entrenadores; Perfil → Mi preparador permite
aceptar y finalizar vínculos. Una cuenta puede ser admin, preparador y alumno
simultáneamente. Los entrenamientos futuros solo aparecerán al alumno cuando
tenga contenido autorizado asignado. TRN-011 publica el panel y habilita solo
en Dev la cuenta de Javier con cinco plazas; entrada humana TOTP y sesión tras
recarga comprobadas en Chrome. Cada preparador usa el autenticador de su propia
identidad, sin permisos ADMIN. Contratación autónoma web y tarifas pendientes;
los límites técnicos de ejercicios e imágenes se concretan en TRN-019.
[Recorridos y validación](TRAINER_PORTAL_2026_10_21.md).

**ADM-004 · 21/10/2026 · sesiones y borrado manual:** Sesiones incorpora papelera
recuperable. Ambas papeleras permiten eliminación definitiva confirmada: los
programas conservan todas sus sesiones; las referencias y entrenamientos impiden
eliminar recursos necesarios. Recuperar sesiones mantiene ID y no republica.
El historial no puede resucitar recursos purgados. Publicado y comprobado en Dev
y Chrome, con retirada/recuperación real. [Contrato y pruebas](ADMIN_TRASH_DELETION_2026_10_21.md).

**ADM-003 · 21/10/2026 · papelera de programas:** Programas guiados permite
mover familias y trabajos incompletos a una papelera recuperable. Conserva las
sesiones reutilizadas y los resultados. Recuperar no vuelve a publicar: devuelve
borradores y versiones retiradas para revisión. No se vacía automáticamente.
[Alcance y pruebas](ADMIN_PROGRAM_TRASH_2026_10_21.md).

**ADM-001 · 20/10/2026 · operaciones del administrador:** Gestión incorpora
Historial editorial y Calidad del catálogo. Las sesiones/programas pueden
recuperarse desde un cambio registrado como borrador independiente; se conserva
el original y se revisa antes de publicar. Los avisos separan errores de trabajo
pendiente y llevan al recurso. Cuentas amplía su ficha de soporte para el
responsable único; Herramientas muestra versión desplegada y conexión puntual.
ADM-002 añade recibos de copias y errores reducidos a códigos, con captura de
fallos no controlados del admin. La interfaz está publicada y la recogida real
de servicios funciona en Dev. El 21/10 se comprueba la primera copia cifrada
almacenada y su recibo verificado: SQL y archivos de Storage restaurados en un
ensayo aislado. Copias diarias con siete días de retención; no incluyen vídeos
Bunny ni secretos de servicios. Restaurar sobre Dev requiere revisar el destino.
[Alcance y límites](ADMIN_OPERATIONS_2026_10_20.md).
[Recuperación de Dev](DEV_RECOVERY_2026_10_20.md).

**UI-063 · 20/10/2026 · eficiencia de autoría:** duplicar abre el creador actual
con una copia independiente que se guarda al confirmar. Las sesiones plegadas
muestran resumen; quitar permite deshacer con posición y ajustes. Estado y
versión quedan separados de la opción de mostrarse como sesión suelta.
Se conservan guardado y publicación conjunta.

**UI-062 · 20/10/2026 · creadores y Compacto:** Javier confirma crear y guardar
sesiones dentro del programa como borradores, revisar el conjunto y publicarlo
en una sola operación. Se conserva reutilización, versiones y la opción de
mostrar una sesión suelta. No se exige publicar cada sesión antes de añadirla.
Tras comparar ambas presentaciones, Javier elige la ventana existente para editar.
Las sesiones se leen escritas en el programa y «Editar sesión» abre directamente
el creador en un clic. Calentamiento y ajustes son desplegables. Se conserva la
revisión final conjunta y la autoría independiente de Sesiones.
Se mantienen los kilos opcionales y el RIR por repeticiones compatibles.
[Recorrido vigente](PROGRAM_AUTHORING_WORKSPACE_2026_10_20.md).

**COM-019, 20/10/2026 · programas guiados Free/Pro:** Free permite un programa
activo y Pro varios sin esa cuota. Pausar libera la plaza, retomar conserva fase
e historial y alternar no tiene penalización. El catálogo y las sesiones
oficiales sueltas siguen disponibles. Las cuotas de 8 ejercicios propios y 4
familias de sesiones propias son independientes. **COM-020 corrige la pérdida
de Pro:** cualquier cantidad superior a uno exige elegir qué programa mantener;
el resto se pausa conservando progreso. Hasta elegir no se permiten nuevas
sesiones guiadas ni avances de fase, aunque se pueden terminar sesiones abiertas.
La cuota se comprueba en servidor. Dejar un programa sigue siendo distinto de pausarlo.
[Contrato, validación y límites](PROGRAMAS_GUIADOS.md).

**PLAN-026, 16/10/2026 · progresión de carrera:** una nueva marca no descarta
automáticamente parciales que todavía cumplen el trabajo actual. El motor
prioriza progresión justificada de dosis y especificidad, conserva una calidad
conocida al ampliar días y busca otro hueco ya previsto cuando el primero no
permite el escalón completo. No añade formatos por variedad ni prescribe el
ritmo de la meta como capacidad actual. Las semanas guardadas conservan su
versión. Detalle en [MOTOR_CARRERA_2K_V6.md](MOTOR_CARRERA_2K_V6.md).

**STR-041, 16/10/2026 · controles por necesidad:** el programa decide qué
protocolo conviene medir, sustituye trabajo y explica el propósito. Los datos
válidos del entrenamiento actualizan marcas de seguimiento y la referencia de
2 km automáticamente; no se presentan como evaluaciones oficiales. No hay una
cadencia fija de máximos, ni se añaden durante recuperación global o cerca del
examen. La revisión de variedad de carrera queda documentada sin cambiar sus
formatos ordinarios. Contrato en [CONTROLES_ADAPTATIVOS.md](CONTROLES_ADAPTATIVOS.md).

**STR-040, 16/10/2026 · continuidad y repertorio:** flexiones y plancha pueden
progresar dentro de sus límites sin un veto general por compartir tronco.
Plancha conserva trabajo compatible al cambiar de fase; carrera utiliza rodajes
fáciles registrados para un siguiente ensayo acotado, sin alterar el núcleo v5.
Dead bug deja de seleccionarse automáticamente y plancha alta tiene entrada y
esfuerzo propios. La propuesta distingue metas de marcas y series submáximas.
El caso de seis meses se repite sin cambiar las respuestas ficticias; no prueba
que una persona alcance los objetivos. Aceptación física pendiente; programación
autónoma de tests completada después en STR-041. Contrato y evidencia en
[PROGRAMA_ADAPTATIVO.md](PROGRAMA_ADAPTATIVO.md).

**STR-039, 16/10/2026 · apoyos autónomos:** el motor selecciona un apoyo
pertinente, aprovecha resultados propios compatibles y puede introducir una
práctica guiada opcional si faltan datos. El usuario no necesita calibrar la
biblioteca ni escoger su rutina. La práctica reserva tiempo y no inventa carga;
su resultado permite personalizar el apoyo después. Carrera, cobertura y
recuperación conservan prioridad. Las recetas disponibles, validación y límites
figuran en [PROGRAMA_ADAPTATIVO.md](PROGRAMA_ADAPTATIVO.md).

**STR-038, 16/10/2026 · frecuencia por estímulo:** el programa puede superar
dos exposiciones cuando la dosis acreditada, fase, recuperación y calendario
lo permiten. Puede mantener dosis por sesión diferentes al repartir intentos.
La frecuencia no sustituye la progresión de repeticiones, tiempo o carga ni los
apoyos calibrados pertinentes. Se corrigen el alta y selección que podían
bloquear esos accesorios. El formulario recoge la frecuencia ya tolerada sin
confundirla con disponibilidad. Carrera y semanas publicadas se conservan.
Contrato y validación en [PROGRAMA_ADAPTATIVO.md](PROGRAMA_ADAPTATIVO.md).

**STR-037, 16/10/2026 · frecuencia desde resultados:** fuerza puede repartir el
trabajo tolerado en dos exposiciones por movimiento sin repetir el alta. Se
recupera carrera registrada para revisar el contexto y se simplifica la entrada
con máximo de días, duración habitual y excepciones. No se prometen todos los
días ocupados ni se renueva salud por ausencia de incidencias. Contrato vigente
en [PROGRAMA_ADAPTATIVO.md](PROGRAMA_ADAPTATIVO.md).

**UI-030, 14/10/2026 · revisión de sesión:** los ejercicios con foto muestran
su miniatura junto al nombre, conservando orden, series e instrucciones. La
acción de empezar permanece visible al recorrer el contenido sin taparlo;
carrera conserva su acción de registrar resultado. Fotos ausentes o fallidas
no bloquean el entrenamiento. Se mantiene el diseño propio, el retorno al
origen y las reglas existentes. Alcance y aceptación móvil pendiente en
`VISUAL_DESIGN.md`.

**UI-029, 14/10/2026 · tiempos editables:** los campos de segundos y ritmos
comparten formato `00:00` con separadores automáticos, también en admin.
Los tiempos precisos conservan fracciones, los datos anteriores mantienen sus
unidades y disponibilidad sigue expresándose en minutos completos. No cambia
la programación deportiva. Alcance en `VISUAL_DESIGN.md`.

**UI-022, 09/10/2026 · cinco ajustes cotidianos:** Salir sin guardar descarta,
con confirmación y conexión, la ejecución en curso y sus series; su cita vuelve
a pendiente. Retomar y abandonar conservando resultados siguen siendo opciones
distintas; las sesiones cerradas no se eliminan mediante este recorrido.
El criterio entonces aplicado de Perfil inferior queda sustituido por TRN-025.
Mi semana usa Añadir entrenamiento; Disponibilidad separa días y minutos.
FAS ofrece reintento ante fallo/espera de carga, conservando lo escrito.
Análisis limpio, 685 pruebas correctas con una omisión web existente y tres
pruebas SQL con ROLLBACK; 134 migraciones coincidentes en desarrollo.
[Contrato, evidencia y límites](UX_REVIEW_2026_10_09.md).

**UI-021, 08/10/2026 · Mi plan y formularios:** Preparaciones y Elige una
preparación distinguen objetivos guardados de un programa iniciado. Sin programa,
Mi plan ofrece elegir antes de la agenda y no parece asignar Tropa por defecto.
Disponibilidad/material resume el mismo contexto que el asistente y Perfil.
El bloqueo de cambio abre la sesión concreta y vuelve a la propuesta; salir
para retomar sigue bloqueando, resolverla permite revisar la activación.
Campos separados, selectores completos y ayudas legibles con teclado/texto grande.
Tarjetas fotográficas, motores y negocio conservados. Análisis limpio, 671
pruebas correctas con la omisión web; recorrido autenticado posterior.
[Estados, capturas y límites](PLAN_COHERENCE_2026_10_08.md).

**UI-020, 08/10/2026 · tiempo y salida corregidos:** el tiempo que escribe el
reloj se presenta en min:seg y se registra en segundos, sin exigir reescribirlo.
La flecha ofrece seguir aquí, salir y retomar después, o abandonar conservando
lo realizado con motivo. Cancelar o fallar conserva la sesión y el borrador.
Los diálogos admiten desplazamiento con texto grande. Análisis limpio en app,
admin y UI compartida; 630/91/6 pruebas correctas con las omisiones existentes.
UI-022 incorpora después el descarte explícito de una sesión en curso.
[Contrato y regresiones](SESSION_CONTROLS_2026_10_08.md).

**UI-019, 08/10/2026 · sesión y Mi semana:** abandono disponible mientras la
ejecución esté en curso, también tras resolver todas las series, conservando
resultados y motivo. Mi semana reparte los días en todo el ancho del contenido;
texto ampliado y pantallas estrechas permiten desplazamiento legible. Javier
confirma pitidos a tres, dos y un segundo del final de trabajo, seguidos del
sonido de final. Análisis limpio y 621 pruebas correctas con una omisión web
existente. UI-020 incorpora retomar/abandonar desde la flecha; el posible
descarte de resultados se incorpora después en UI-022, con contrato propio.
[Recorrido y límites](SESSION_CONTROLS_2026_10_08.md).

**UI-018, 08/10/2026 · avisos reales del temporizador:** el ejecutor incluye
pitidos locales de preparación, inicio, mitad, últimos diez segundos y final,
también para descanso. Sonido y vibración conservan controles independientes;
el diálogo añade Probar sonido sin guardar el borrador. Coincidencias y tiempos
cortos evitan duplicados. Comprobado con análisis, 606 pruebas de app, 91 de
admin, reproducción aceptada en Chromium y APK debug. IOS-002 acredita después
compilación y reproducción en simulador iOS, con escucha confirmada por Javier.
Escucha en Android físico pendiente. Se mantiene la
sesión en pantalla para recibir avisos, sin garantía de segundo plano.
Javier comunica una revisión superficial positiva de guardado, Evolución y
fotos en simulador. [Criterio, pruebas y límites](WORKOUT_AUDIO_2026_10_08.md).
El siguiente recorrido es probar audio/vibración en dispositivo físico cuando
esté disponible, conservando los pendientes de publicación/negocio/motores.

**UI-017, 08/10/2026 · formularios más legibles:** nuevo programa admin y
formulario compartido de ejercicios permiten leer la selección completa con
texto ampliado. El borrador de programa conserva nombre/tipo si falla el guardado;
los controles de foto admiten el espacio de un diálogo estrecho. No cambia
opciones, validación, derechos o diseño de Inicio/Mi plan. Comprobado con análisis
de app/admin/paquete y baterías completas: 591, 91 y 8 pruebas correctas, con
las omisiones existentes. [Imágenes y alcance](REFRESH_FORMS_2026_10_08.md).
El siguiente bloque es la comprobación autenticada de los recorridos actuales,
pendiente de sesión disponible; no cierra todo el pulido transversal.

**UI-016, 08/10/2026 · historial con tipo de entrenamiento:** Evolución permite
filtrar Carrera, Fuerza y acondicionamiento, Mixta y Sin clasificar junto a
preparación, fechas y estado. El servidor guarda el tipo al iniciar y lo conserva
aunque después cambie la plantilla; las ejecuciones antiguas no se reclasifican.
La consulta se mantiene al paginar/refrescar/fallar y los selectores admiten
texto grande. Análisis limpio, 591 pruebas completas, 25 específicas y tres
recorridos de captura correctos; una exclusiva web omitida. Migración aplicada
solo en desarrollo, con 133 coincidentes y cuatro pruebas SQL transaccionales
correctas. [Criterio, límites e imágenes](HISTORY_SESSION_TYPE_2026_10_08.md).
El siguiente bloque es el pulido localizado de textos/estados/accesos de app y
admin. Comparación configurable y recorrido autenticado global permanecen
pendientes; recepción y recuperación web ya confirmadas por Javier en MAIL-001.
No cambia el diseño de Inicio/Mi plan ni introduce el negocio Free/Pro.
Las notas anteriores describen la situación en el cierre de cada tramo.

**UI-015, 08/10/2026 · comparación de marcas disponible en desarrollo:**
desde Evolución → Marcas de una preparación se elige prueba y dos fechas para
ver las mediciones guardadas y su cambio. Tropa/FAS comparan dentro de su versión
y contexto; controles de 2 km van separados y muestran esfuerzo. La selección
se mantiene al refrescar/fallar y el historial completo sigue disponible.
Resultados configurables conservan marcas/puntos/intentos; sin unidad/protocolo
históricos completos no se ofrece una comparación inferida. Se conserva la
composición aprobada, portadas y separación de negocio/motores. Análisis limpio,
579 pruebas completas y seis recorridos visuales correctos; una prueba exclusiva
web omitida. Pendientes: definir el tipo deportivo histórico antes de su filtro,
comparación configurable y revisión autenticada. El siguiente bloque UX único
es el contrato del filtro deportivo. Detalle e imágenes en
[MEASUREMENT_COMPARISON_2026_10_08.md](MEASUREMENT_COMPARISON_2026_10_08.md).

**UI-014, 08/10/2026 · detalle administrativo organizado:** acceso fijo a
Contenido (portada/publicación), Evaluación (calificación, pruebas y baremos)
y Entrenamiento (sesiones y preparación vinculada), conservando la misma página
y sus formularios. Los publicados ofrecen consulta del baremo, sin presentar
una edición disponible; las consultas de entrenamiento permiten reintentar.
Comprobado en desarrollo con análisis, 89 pruebas y seis recorridos visuales.
No modifica la app del deportista, motores ni negocio. Se adelanta este tramo
del pulido durante la espera de la prueba real del correo, que permanece abierta.
El siguiente bloque UX sigue siendo Evolución y sus comparativas compatibles;
el resto del pulido transversal no se considera completado.
Detalle en [REFRESH_ADMIN_2026_10_08.md](REFRESH_ADMIN_2026_10_08.md).

**UI-013, 08/10/2026 · Cuenta implementada en desarrollo:** acceso ofrece
recuperación de contraseña; alta/acceso con correo sin confirmar abre una
pantalla persistente con instrucciones y reenvío. El SDK distingue recuperación
del acceso normal y Auth valida el cambio. Los errores conservan los campos;
el éxito permanece visible hasta volver al acceso. La respuesta de solicitud
no revela si existe la cuenta. Se conservan Inicio/Mi plan, fotos y separación
del negocio/motores. Análisis, pruebas y compilaciones contrastados; correo real
y dispositivo siguen pendientes, sin acreditar auditoría integral de seguridad.
Detalle en [REFRESH_ACCOUNT_2026_10_08.md](REFRESH_ACCOUNT_2026_10_08.md).
El siguiente bloque UX recomendado es Evolución: filtro deportivo y comparativas
de mediciones compatibles. Las notas fechadas siguientes describen sus cierres
anteriores; no sustituyen este estado ni el de `ROADMAP.md`.

**UI-008, 07/10/2026 · Inicio/Mi plan cerrado:** Mi plan presenta programa en
curso, semana y sesiones pendientes, con estados separados para preparaciones
por configurar, pausadas y finalizadas. Abre el programa directamente, conserva
el vínculo de la sesión al consultar/retomar y retira accesos duplicados a
Biblioteca. Inicio comparte estados/siguiente paso y conserva su calendario.
El resumen de Mi plan se carga al visitar la raíz, se actualiza al regresar y
se renueva al cambiar de cuenta, conservándolo al renovar la misma sesión.
Análisis limpio, 505 pruebas completas de raíz y ocho capturas verificadas;
20 imágenes de widgets actuales con datos simulados. Sin cambios en admin,
SQL, motores o producción; pendiente la revisión autenticada en dispositivo.
Detalle en [REFRESH_PLAN_2026_10_07.md](REFRESH_PLAN_2026_10_07.md).
Ese cierre dio paso a Evolución/Marcas, implementado después en UI-011 para
resultados, filtros de historial y consulta de registros antiguos.

**UI-008, 07/10/2026 · fiabilidad editorial ampliada:** creación/edición de
pruebas, calificación, baremos/mínimos, importación, clonación y vinculación de
estrategia esperan el guardado sin perder campos ante un fallo. Se conservan
las revisiones y confirmaciones existentes. Se cierra ese pendiente; la siguiente
reorganización es Inicio/Mi plan. Análisis limpio y baterías completas: 482
pruebas de app, 85 de admin (una optativa omitida) y seis del componente UI.

**UI-008, 07/10/2026 · refresco al regresar:** Inicio, Perfil, Mi semana y
Evolución consultan de nuevo al volver de otra sección o una tarea, conservando
su navegación y posición. La agenda mantiene semana/día; Inicio e historial
conservan la última consulta durante la actualización. Comprobado con análisis
limpio y 482 pruebas de raíz; el siguiente tramo es el guardado editorial admin.
El resto del refresh continúa pendiente, como recoge `VISUAL_DESIGN.md`.

**UI-008, 06/10/2026 · primer tramo de fiabilidad:** se mantiene la identidad
visual y se incorpora `go_router` al admin, con rutas recargables por ID,
búsquedas editoriales y laboratorio separado. Las evaluaciones oficiales
protegen cambios pendientes; el editor admin avisa antes de descartar y los
formularios de referencia, creación de programa y edición de ejercicios
permanecen abiertos si falla su guardado. El cierre de sesión de entrenamiento
ofrece volver al origen o consultar su resultado concreto y admite notas largas.
Mi plan, Evolución, Biblioteca, el resto de guardados editoriales y recuperación
de cuenta siguen pendientes del refresh autorizado. No se amplía el motor
deportivo ni se modifica producción. Alcance en `VISUAL_DESIGN.md`.

**STR-032, 06/10/2026:** «Mi programa» presenta «Esta semana» y «Mis fases» de
rendimiento, con propósito actual por objetivo y previsión orientativa. El motor
elige principal y apoyos calibrados; su ausencia no impide entrenar. Las opciones
de calibración recogen capacidad real, sin sustituir referencias de otras
mediciones. Una comprobación submáxima puede sustituir trabajo al cambiar a
especificidad; no es un máximo semanal. El guiado de rendimiento contiene tareas
y reloj; completarlo u omitirlo por sí solos no altera la progresión. La
continuidad sigue automática y carrera conserva v5. Alcance y límites en
[ESTRATEGIAS_RENDIMIENTO_V3.md](ESTRATEGIAS_RENDIMIENTO_V3.md).

**STR-027, 04/10/2026:** el deportista conserva varias preparaciones y un solo
programa generando entrenamientos. «Mi programa» comienza eligiendo preparación
completa, solo carrera o fuerza y otras pruebas, según el soporte disponible.
Muestra únicamente los bloques elegidos e informa qué queda fuera. Activar o
retomar otro programa muestra qué preparación se pausará antes de aceptar.
La pausa conserva progreso, marcas y resultados; retomar revisa los datos con
el calendario actual. Si son utilizables no exige un máximo nuevo. Después,
la continuidad es automática con los resultados de las sesiones realizadas.
El catálogo oficial y los baremos permanecen disponibles para evaluación.
Implementado y comprobado en desarrollo; contrato y límites:
[PROGRAMA_ADAPTATIVO.md](PROGRAMA_ADAPTATIVO.md).

**STR-023, 04/10/2026:** el programa iniciado lleva a entrenar y registrar;
no ofrece crear o calcular otra semana. Inicio y agenda muestran y recuperan la
continuación. El alta y los cambios de datos tienen un recorrido separado.
La consulta de semanas futuras explica su estado, sin volver al cuestionario.
Prevalece sobre los recorridos de publicación manual históricos descritos abajo.
Contrato y límites: [PROGRAMA_ADAPTATIVO.md](PROGRAMA_ADAPTATIVO.md).

**STR-022, 04/10/2026:** «Mi programa» organiza fecha/objetivos, disponibilidad,
carrera condicional, movimientos y propuesta. Tras activar el programa, las
semanas se preparan al resolver todas las sesiones con los resultados reales.
Los datos pendientes requieren revisión explícita; no se generan tests máximos
por periodicidad fija. Metas numéricas de fuerza y programación de controles
específicos tienen límites pendientes descritos en
[PROGRAMA_ADAPTATIVO.md](PROGRAMA_ADAPTATIVO.md).

Actualización 04/10/2026: selección v2 y coordinación v2.1, referencias por pasos,
formatos ajustados al tiempo y una sesión en días mixtos. La cobertura reducida
se muestra antes de guardar. Contrato vigente y límites deportivos:
[MOTOR_FUERZA_RENDIMIENTO_V2.md](MOTOR_FUERZA_RENDIMIENTO_V2.md).

## Fuerza y carrera: recorrido integrado en desarrollo (03/10/2026)

Desde una preparación, «Fuerza y carrera» recoge disponibilidad total y
referencias reales por movimiento, permite revisar una semana y guardarla en
la agenda común. Las ejecuciones informan la siguiente decisión. ADMIN
configura estrategias por prueba; FAS/Tropa reconocen sus pruebas existentes.
Los apoyos no se presentan como marcas del examen. Carrera conserva su
cuestionario y política. Alcance técnico, parámetros revisables y límites en
[MOTOR_FUERZA_RENDIMIENTO_V1.md](MOTOR_FUERZA_RENDIMIENTO_V1.md).

## Carrera: bloque técnico 2 km verificado en desarrollo el 01/10/2026

Motor `running_2k_v5` aplicado en **entrenaop-dev**. FAS, Tropa y programas
con prueba vinculada al módulo 2 km usan un único planificador de servidor,
con sus propias marcas y baremos. Reutiliza agenda y ejecutor; no hay IA de
pago ni selector deportivo en Flutter. Incluye objetivos libre/tiempo/margen,
lectura de registros incompletos, contraste del RPE y vuelta gradual tras fatiga.
V3 corrigió encaje de calidad y repetición del foco; v4 añade dosis repartida
al pasar a dos calidades; v5 permite progresar minutos fáciles al mantenerlas.
Recomendaciones de disponibilidad sin modificar la elección.

Verificados 1.573 semanas sintéticas, el ciclo servidor con `ROLLBACK`, widgets,
análisis y compilación web. El usuario puede declarar series recientes sin que
se cuenten como entrenamientos verificados; puede reiniciar su planificación
automática tras dos confirmaciones. Una sesión completada abre el historial
compartido. El RPE alto persistente mantiene la carga y pide revisar la escala.

Este cierre técnico no acredita eficacia deportiva ni incluye fuerza o
coordinación entre pruebas. Falta una revisión visual autenticada de la app
recompilada. Detalle en [`MOTOR_CARRERA_2K_V5.md`](MOTOR_CARRERA_2K_V5.md).


## Visión

EntrenaOP es una aplicación multiplataforma para preparar pruebas físicas de
oposiciones militares y de fuerzas y cuerpos de seguridad. Combina fuerza,
calistenia, carrera y planificación específica. Debe funcionar en Android,
iPhone, web y Windows con interfaces adaptadas a cada formato.

Las pruebas de cada preparación dirigen los objetivos y la selección de
ejercicios. La mejora general de condición física puede aportar complementos,
pero no desplaza el trabajo pertinente a esas pruebas. El futuro motor general
de fuerza/rendimiento recibirá objetivos deportivos desde el programa o desde
un plan específico, sin depender del nombre de una oposición. Esta prioridad
es STR-004; su primer tramo de selección está implementado en rendimiento v3,
con los controles y prioridades por déficit todavía pendientes.

Javier confirma mantener la creación de programas en ADMIN y reutilizar
estrategias deportivas (STR-005). Cada deportista recibirá una adaptación a
su capacidad, contexto y resultados (STR-006), por lo que una misma preparación
podrá tener variantes, dosis y evolución distintas. Las diferencias tendrán
un motivo deportivo; contextos equivalentes podrán recibir la misma
prescripción. El recorrido inicial de rendimiento y su coordinación con carrera
ya están implementados en desarrollo. Los límites deportivos vigentes están
en `PROGRAMA_ADAPTATIVO.md` y `ESTRATEGIAS_RENDIMIENTO_V3.md`.

STR-007 incorpora una revisión experimental de flexiones en ADMIN con entradas
simuladas y ejercicios de la biblioteca real. Permite contrastar selección y
adaptación; no genera planes publicados. La dosis está pendiente de revisión
deportiva. El ejecutor del deportista requiere declaración explícita para
guardar RIR/RPE de serie; un objetivo de esfuerzo no acredita esfuerzo real.
STR-010 incorpora la primera representación común de objetivos, pendientes y
propuestas, consumida por ese laboratorio. La agrupación permite seleccionar
bloques pertinentes. STR-012 implementa esa captura por bloques en un
laboratorio ADMIN de revisión, con ejemplos de repeticiones, fuerza con carga
e isometría. El contexto se declara una vez y volver conserva respuestas.
Incluye cambios explicados según resultados simulados y conserva objetivos
sin dosificación como pendientes. Ese laboratorio no publica planes; el
recorrido posterior del deportista ya tiene semana conjunta y continuidad
automática. Las simulaciones no acreditan mejoras deportivas humanas.

No pretende ser una biblioteca genérica de ejercicios. Su promesa inicial es:

> Dime dónde estás y cuándo te examinas; EntrenaOP te ayuda a llegar preparado
> y te muestra si vas por buen camino.

El ciclo principal del producto es:

> Evaluación inicial → plan semanal → entrenamiento guiado → registro real →
> adaptación → simulacro.

## Estado validado del producto

**UI-011, comprobación acotada del 07/10/2026:** Evolución abre marcas y
resultados de cada preparación en una vista propia, separada de su gestión.
Incluye registros de Tropa, FAS, evaluación configurable y controles de carrera
cuando existan, conservando sus versiones. Registrar usa los formularios
actuales. El historial consulta sesiones antiguas por páginas y admite
preparación, fechas y estado; distingue un resultado vacío por filtros de un
historial vacío. Retorno, errores y cambio de cuenta están comprobados con
repositorios simulados. No implementa comparativas nuevas, suscripciones ni
cuotas. Inicio, Mi plan y sus tarjetas fotográficas permanecen iguales.
Imágenes y límites: [REFRESH_EVOLUTION_2026_10_07.md](REFRESH_EVOLUTION_2026_10_07.md).

**Chequeo general del 06/10/2026:** ambas apps y los paquetes pasan análisis y
sus pruebas; las dos webs y Android debug/release de desarrollo compilan
(release aún usa firma de depuración). Desarrollo coincide con
las 131 migraciones locales y pasan las 55 baterías SQL tras corregir una
expectativa antigua de catálogo. Se han reproducido defectos de aislamiento
local al cambiar de cuenta; quedan pendientes, junto a la verificación
autenticada en dispositivos y la preparación de publicación. El detalle está
en [AUDIT_2026_10_06.md](AUDIT_2026_10_06.md).

La siguiente instantánea histórica fue comprobada el 24 de septiembre de
2026, tras cerrar Carrera V1 mínima, la autoría oficial inicial y la calculadora
FAS 2027:

- El acceso, la restauración de sesión y la navegación responsive están
  operativos.
- El usuario puede mantener varias preparaciones activas, registrar y consultar
  evaluaciones físicas versionadas de ingreso a Tropa y Marinería, y guardar su
  disponibilidad y contexto de entrenamiento.
- La biblioteca pública y las sesiones personales comparten vista previa,
  agenda semanal, sesión guiada e historial, pero conservan origen, privacidad
  y versión distintos.
- El creador personal admite varios bloques, series con objetivos diferentes,
  superseries, circuitos con transiciones, intervalos de trabajo, Tabata, EMOM y
  AMRAP. También permite crear ejercicios privados con descripción y una URL de
  vídeo HTTPS opcional.
- Biblioteca permite consultar el vídeo bajo demanda, pausarlo y abrir el
  enlace original si el proveedor externo no admite reproducción integrada.
  Los ejercicios personales privados se editan desde su detalle, incluyendo
  foto; un fallo conserva lo escrito y el retorno mantiene la búsqueda. La
  edición actualiza el catálogo privado para futuras ejecuciones y conserva
  las instantáneas de entrenamientos anteriores. El contenido de EntrenaOP
  permanece de consulta en la app del deportista (UI-012, 08/10/2026).
- Gestión de vídeos (VID-003): Javier elige Bunny Stream y autoriza empezar por
  el catálogo oficial. ADMIN incorpora subida, comprobación y previsualización;
  el servidor valida permisos y estado y firma la reproducción bajo demanda.
  Biblioteca y secretos conectados en Dev; subida, publicación y reproducción
  web real comprobadas con un clip propio de Javier de 3.008 segundos.
  El recorrido sigue abierto. El futuro espacio de entrenadores reutilizará esta
  dirección con cuotas y privacidad propias, todavía sin implementar.
  VID-004 unifica foto y vídeo en un bloque superior: la portada se sustituye por
  el reproductor al tocar Play. No se descarga vídeo al abrir la ficha. El audio
  se conserva como venga en el archivo; Javier lo subirá sin sonido cuando no
  lo quiera y descarta añadir controles de silencio o volumen.
  VID-005 obtiene automáticamente la portada del vídeo oficial si no hay foto;
  conserva la elegida y permite sustituirla expresamente. Solo administradores
  pueden subir archivos a Bunny. El deportista guarda únicamente un enlace
  externo para su ejercicio privado; ese campo no aloja una copia de vídeo.
  VID-006 permite elegir otro instante desde ADMIN web con una barra temporal
  y usarlo como portada; se aplica al borrador y se publica al guardar, sin
  volver a subir el vídeo. Cancelar conserva la foto anterior.
  Javier descarta UI-049. UI-050 conserva la tarjeta en fila y usa miniatura
  discreta de 80×60 px con el encuadre de ADMIN. La portada del vídeo muestra
  solo Play en una esquina, sin texto ni oscurecimiento global.
  El listado omite la descripción y ajusta el margen a la foto; la descripción
  completa sigue disponible al abrir el ejercicio.
  Contrato y preparación: [Vídeos](VIDEOS.md).
- Duración confirmada para los vídeos de ejercicios (VID-002, ampliada el 18/10/2026):
  como máximo 10 segundos, con clips más cortos cuando basten. Se podrá revisar
  este máximo coordinando servidor, base de datos y ADMIN. La comparación de
  alojamiento debe usar esta duración
  y explicitar calidad, tamaño y transferencia real. Repetir desde memoria o
  caché no equivale necesariamente a descargar de nuevo. VID-003 comprueba la
  duración comunicada por Bunny y el tamaño del MP4; la precisión fraccionaria y
  el recorrido físico móvil quedan pendientes. Caché móvil de hasta 100 MiB;
  web depende del navegador.
  Reproducción al abrir la ficha y bucle automático siguen sin acordarse;
  el arranque tras tocar la portada sí está implementado en VID-004.
- El creador especializado de carrera admite carrera continua por distancia o
  duración y tramos ordenados con ritmo exacto o rango. Cada tramo conserva su
  recuperación pasiva, andando o trotando por duración o distancia. Repetir un
  tramo y crear una pirámide son ayudas de edición: la prescripción se guarda
  expandida y versionada.
- Los borradores se guardan localmente por sesión. Duplicar, revisar o archivar
  una sesión no reescribe ejecuciones pasadas: las revisiones forman una familia
  versionada y el historial conserva una instantánea de la prescripción.
- La agenda semanal permite añadir sesiones públicas o personales, moverlas,
  retirarlas, iniciarlas y continuar las que están en curso.
- Inicio muestra un resumen compacto de lunes a domingo; cada día indica si hay
  sesiones y abre la agenda completa en la fecha elegida.
- Cada preparación activa dispone de una vista propia con su fecha objetivo,
  la última evaluación compatible y las sesiones de la semana vinculadas a
  ella. Es una vista de solo lectura: el usuario no puede crear, vincular,
  mover ni retirar contenido de un plan oficial.
- La sesión guiada conserva objetivos y resultados por serie, descripciones y
  vídeos, pausas y temporizadores recuperables. Registra omisiones, abandono con
  motivo, esfuerzo final, notas y el resultado agregado propio de AMRAP.
- UI-040 reorganiza el entrenamiento con foto y técnica bajo demanda, acciones
  accesibles y registros agrupados. En series ordinarias se puede terminar y
  descansar con datos pendientes de confirmar; estos se recuperan en el mismo
  dispositivo. Confirmar usa el registro existente. Los retoques de resultados
  ya enviados se consolidan al cerrar con el corrector auditable, que requiere
  conexión y mantiene sus límites. No se confirma una sesión con datos pendientes
  ni se convierte automáticamente el objetivo en resultado realizado.
- Una cola local permite continuar las mutaciones de una ejecución ya cargada
  durante cortes de red; Supabase las aplica de forma idempotente. Las
  correcciones del historial permanecen en línea y se auditan durante 24 horas,
  con motivo obligatorio y un máximo de tres cambios por serie.
- El panel web independiente permite crear, revisar, versionar, publicar y
  retirar sesiones oficiales generales o ligadas a un programa. Comparte el
  modelo y los controles de edición reutilizables con la app, pero conserva
  autenticación, navegación y persistencia propias.
- El creador de ejercicios comparte borrador, validación y formulario. El panel
  solo crea contenido oficial global tras comprobar el permiso administrativo;
  la app solo crea ejercicios privados del usuario autenticado.
- La evaluación periódica FAS 2027 dispone de registro e historial separados
  del ingreso a Tropa, validación de edad en PostgreSQL y una calculadora
  gratuita que no guarda marcas ni presenta la suma orientativa como aptitud
  oficial.

Esto cierra los recorridos manuales de fuerza V1 y Carrera V1 mínima, no el
ciclo principal completo. El contexto de preparación, marcas, agenda y carrera
ya está conectado y el motor 2 km genera y adapta semanas en desarrollo;
fuerza dispone ahora de coordinación, referencias, publicación y adaptación
operativas en desarrollo (STR-017). STR-019 comprueba que esa política conserva
una dosis declarada y adapta cifras: la selección de estímulos y la dosis inicial
desde capacidad todavía necesitan revisión e implementación. No equivale a
programación deportiva completa. Las nuevas semanas se solicitan, revisan y
guardan desde la preparación; avanzar el calendario solo consulta la agenda.
El banco externo de 40 propuestas está recibido y revisado, sin activación
automática. Los simulacros completos y la revisión por
entrenador siguen pendientes. Carrera V1 no incluye GPS, mapas, seguimiento en vivo, zonas
cardíacas ni integraciones. El vídeo propio se referencia por URL; no
hay subida ni gestión de archivos. Los borradores y temporizadores son locales
al dispositivo y el soporte offline no permite descubrir, cargar o iniciar una
sesión que nunca se hubiera obtenido del servidor.

El primer recorrido de acceso **implementado** es el ingreso a Tropa y
Marinería; no equivale a la evaluación periódica del personal ya incorporado.
Para validar el primer plan adaptativo se prioriza ahora un piloto de evaluación
periódica militar, familiar para Javier. Se modela como programa distinto y visible en
desarrollo: permite guardar y repetir intentos con mínimos de 2027 por edad
y sexo, sin convertirlos en una calificación oficial ni en sesiones
automáticas. Las marcas de 2026 son solo referencia para entrenar; no se ha
renombrado Tropa ni tratado como otra oposición. Los accesos a Suboficiales y Oficiales tendrán sus propios
catálogos oficiales. CNP conserva su evaluación definida como borrador y no
se publicará por ahora; Guardia Civil y otros cuerpos quedan fuera del MVP
inicial.

Lema previsto: **Entrena. Supera. Aprueba.**

## Usuarios y evolución del producto

EntrenaOP comienza como una aplicación para el opositor, pero también debe
convertirse en una herramienta profesional para entrenadores. Una misma persona
podrá ser deportista, entrenador de otros usuarios o ambas cosas; estos
contextos no se representarán mediante un único rol excluyente.

La evolución comercial prevista tiene dos vías complementarias:

- **B2C:** el opositor descubre la aplicación, utiliza el nivel gratuito y
  puede contratar adaptación automática o seguimiento humano.
- **Profesional:** el preparador de oposiciones incorpora y gestiona clientes
  desde un espacio de trabajo propio.

**Público profesional confirmado · TRN-005 · 18/10/2026:** Javier confirma que
quiere ayudar principalmente a preparadores de oposiciones. El espacio
profesional mantiene la especialización de EntrenaOP y la aplicación actual para
sus clientes; no se abre otro producto de entrenamiento general. Esta orientación
no amplía por sí sola las pruebas deportivas soportadas por el algoritmo. Los
pendientes sobre preparaciones, intervención del entrenador y condiciones
comerciales de TRN-002/004 siguen abiertos.

Una variante para academias podría incorporar organizaciones, grupos, alumnos y
varios entrenadores. Es una dirección futura, no alcance del MVP. El modelo
actual debe evitar bloquearla, pero no implementarla anticipadamente.

### Administración y entrenadores · TRN-001/002/004 · 18/10/2026

**Criterio de producto acordado; acceso/clientes implementados en TRN-010. Contenido privado y asignaciones pendientes.**
La aplicación del deportista es la aplicación actual: los clientes del entrenador
recibirían allí sus entrenamientos y registrarían sus resultados.

Javier distingue las responsabilidades siguientes:

- **Administración general:** gestionar las cuentas de la plataforma, crear
  ejercicios, sesiones y programas oficiales de EntrenaOP y administrar los
  accesos comerciales autorizados. El producto profesional deberá permitir
  consultar el estado comercial de los entrenadores y concederles acceso
  gratuito. Gestionar cuentas no implica consultar por defecto los entrenamientos
  privados que cada entrenador prescribe a sus clientes. Se conserva COM-017:
  la gestión de cuentas corresponde al responsable autorizado y no se deriva
  del permiso de edición de contenido.
- **Entrenador:** gestionar sus propios clientes y crear sesiones y programas
  privados para ellos. Ese contenido no se publica en el catálogo general de
  EntrenaOP. No puede modificar el contenido oficial, gestionar cuentas ajenas,
  conceder derechos comerciales ni acceder a funciones internas de la plataforma.
- **Accesos comerciales:** Pro del deportista y acceso profesional del entrenador
  son derechos distintos. Regalar uno no implica conceder el otro. Precios,
  límites de clientes y alcance adicional del acceso incluido siguen pendientes.

**Modelo comercial confirmado por Javier · TRN-004:** mantener EntrenaOP como un
único producto. El entrenador paga por las herramientas de creación y gestión,
con una tarifa dependiente del número de clientes. Cada cliente utiliza su
cuenta habitual en la aplicación actual y recibe condiciones de acceso a través
del entrenador. Javier confirma el 19/10/2026 que el paquete profesional debe
incluir el acceso del cliente al servicio de entrenamiento: no se le exige pagar
otra suscripción de EntrenaOP para recibirlo y utilizarlo. Recibir asignaciones,
consultarlas, entrenar y registrar/consultar sus resultados no puede quedar
bloqueado por cuotas Free o por exigir Pro individual. El alcance de funciones
adicionales sigue pendiente; no se ha acordado aún equivalencia con todo Pro.

**Alcance del piloto confirmado el 20/10/2026 · TRN-008/009:** cada alumno podrá
tener un único preparador activo. La relación no le concede Pro ni creación
personal ilimitada: conserva las cuotas de su cuenta, actualmente ocho ejercicios
propios y cuatro sesiones propias en Free. Si tiene Pro individual, sus derechos
siguen siendo independientes. El contenido recibido del preparador pertenece al
servicio incluido y no debe consumir esas cuotas de creación personal.

La base de acceso profesional, invitaciones y vínculos está aplicada y probada
exclusivamente en Dev, sin cuentas habilitadas. Todavía no implementa la recepción
ni ejecución de asignaciones profesionales ni la exención de cuotas para ese
recorrido. [Contrato y verificaciones](TRAINER_ACCESS_2026_10_20.md).

**Confirmación del 19/10/2026:** Javier confirma contemplar paquetes profesionales
según número de clientes desde el diseño inicial. Los precios y cantidades que
aporta son ejemplos, sin tarifas ni tramos aprobados. La relación con el cliente
se mantiene independiente del paquete; la capacidad vigente limita su activación
en servidor. El contrato del piloto de TRN-008 cuenta relaciones aceptadas y
activas; las reglas comerciales de reducción y caducidad siguen pendientes. El proveedor
de cobro puede incorporarse después sobre ese mismo acceso efectivo.

Falta concretar tarifas y tramos, las condiciones comerciales del límite, derechos
adicionales incluidos, convivencia con Pro individual y qué sucede al
terminar la relación o el acceso profesional del entrenador. La propuesta no
requiere otro producto generalista ni otra aplicación para los clientes, y no
resuelve por sí sola la separación técnica del panel profesional. La cancelación
de una suscripción conserva el historial conforme al criterio vigente; no se ha
definido todavía la disponibilidad posterior del contenido privado asignado.

Javier plantea que el entrenador pueda aprovechar el algoritmo de EntrenaOP.
Quedan por acordar la generación y revisión de propuestas, la convivencia con
ajustes manuales y el alcance de las preparaciones oficiales o privadas. No se
ha acordado que crear una preparación permita aplicar automáticamente el motor
a pruebas deportivas que este todavía no soporte.

Javier confirma el 21/10/2026 una aplicación profesional web separada en
trainer.entrenaop.es. TRN-010 implementa acceso y clientes reutilizando identidad,
componentes y contratos. No implementa cobros, contenido privado ni algoritmo
profesional; su publicación es independiente de ADMIN.

**Aclaración de TRN-003 · 19/10/2026:** Javier confirma reutilizar las herramientas
existentes sin duplicar ADMIN. La revisión técnica y la propuesta de una primera
versión se recogen en [Espacio de entrenadores](TRAINER_APP.md), distinguiendo
acuerdos vigentes de decisiones todavía pendientes.

**Panel profesional · TRN-006 · 19/10/2026:** Javier confirma crear el panel y
prioriza un acabado visual especialmente cuidado. Reutilizará la identidad y
los componentes existentes. La propuesta de revisión visual inicial de clientes
y ficha, incluidos estados vacíos, errores, móvil y texto ampliado, está en
`docs/TRAINER_APP.md`. No hay todavía pantallas profesionales implementadas.

## Free y Pro: reparto confirmado, interfaz inicial y pagos pendientes

**Estado actual · COM-008 · 10/10/2026:** existen derechos Pro temporales y cuotas
Free verificadas en Supabase de desarrollo. Los precios de lanzamiento se
acuerdan en COM-004 y el diseño se aprueba en COM-006. La contratación y las
suscripciones de tienda siguen pendientes; [alcance y conexión de pagos](PRO_LAUNCH.md).
COM-013 (13/10) añade código de compra/restauración Test Store y conciliación
de servidor, comprobado con pruebas automatizadas y SQL con ROLLBACK en Dev.
El catálogo EUR y el backend Dev están conectados tras autorización específica.
Una transacción simulada verifica receipt, webhook y conciliación en servidor;
compra/restauración desde la interfaz nativa siguen pendientes. Profile y ventas
reales permanecen deshabilitados.
COM-016 (13/10) implementa Pro gratuito administrado por Javier para familiares,
pareja y beta testers. Cuentas y Pro permite duración temporal o sin fecha de
fin, con motivo, confirmación y auditoría. Solo administración autorizada y la
habilitación del servidor pueden modificarlo. El regalo no cobra ni crea una
suscripción; retirarlo conserva compras vigentes, recursos e historial. Dev
está habilitado; producción no se despliega ni activa. La beta del deportista
debe actualizarse para aceptar el contrato de regalos indefinidos.
COM-017 agrega listado paginado y búsqueda parcial por correo, manteniendo la
ficha al seleccionar una cuenta. Javier será el único responsable de cuentas y
Pro: el permiso de editar contenido por sí solo no permite leer ni gestionar
este directorio. Esa separación se aplica también a los accesos antiguos en
servidor. El listado muestra únicamente identificación y resumen de acceso;
no expone datos deportivos ni bancarios. Configurado exclusivamente en Dev.
La aclaración de Javier del 07/10 distinguió el desarrollo deportivo del producto
comercial; COM-008 implementa ahora su frontera de acceso para pruebas reales.
Javier concreta a continuación la frontera
comercial: las herramientas y el entrenamiento manual limitado pertenecen a
Free; los programas que generan/adaptan entrenamientos con los algoritmos
pertenecen a Pro. Las cuotas y la generación/adaptación se protegen en servidor.
Una concesión de prueba no acredita una compra ni la eficacia deportiva de un
algoritmo.

### Criterio de precio inicial · COM-004 · 10/10/2026

Javier confirma que Pro debe salir con un precio accesible y considera elevado
un importe inicial de 8,99 €/mes para el alcance actual. Tras plantear un rango
de 2,99–4,99 €/mes, confirma **3,99 €/mes** y toma **29,99 €/año** como precio para
diseñar la oferta inicial. Las dos modalidades conceden el mismo acceso Pro.

Doce mensualidades suman 47,88 €. El anual ahorra 17,89 €, un 37,36 % respecto
a ese importe, y equivale aproximadamente a 2,50 €/mes. El total anual debe
mostrarse con más relevancia que su equivalente mensual; el ahorro puede
redondearse a «37 %», indicando que se compara con doce mensualidades.

Son precios de lanzamiento acordados, no una garantía de viabilidad económica
ni de mantenimiento indefinido. COM-006 acepta el diseño con renovación automática;
protección de tarifas, proveedor de cobro y condiciones contractuales definitivas
siguen pendientes. La validación económica
debe contemplar costes del servicio y soporte, impuestos y comisiones. El alcance
Pro debe poder entregarse con fiabilidad. Este acuerdo documental no implementa
cobros, derechos ni restricciones. La propuesta de contratación se describe en
`docs/VISUAL_DESIGN.md`; COM-006 incorpora la interfaz sin habilitar cobros,
derechos ni restricciones de servidor.

### Posible descuento militar · COM-005 · 10/10/2026

Javier propone estudiar un descuento a militares, acreditando su condición con
la TMI y aplicándolo mediante cupón u otro mecanismo. Aclara expresamente que
debe valorarlo: no están aprobados el descuento, sus importes, beneficiarios,
vigencia, renovación ni método de acreditación. Javier confirma después dejarlo
pendiente al pasar al diseño de Pro; queda fuera de la contratación inicial y no
se anuncia como disponible ni se solicita documentación.

La recomendación inicial es utilizar el correo solo para solicitar información,
sin adjuntar documentos. Si se aprueba el servicio, se estudiará una comprobación
manual por un canal seguro, limitada a los datos necesarios, y una oferta
vinculada a la cuenta verificada. Conservar la acreditación mínima y su vigencia
es distinto de conservar una imagen de la tarjeta. El procedimiento, los datos
y plazos deben definirse antes de recoger documentación; una fotografía no
constituye una validación oficial ni garantiza autenticidad o titularidad.

La [AEPD](https://www.aepd.es/preguntas-frecuentes/1-tus-derechos/3-identificacion-con-dni/FAQ-0116-que-puedo-hacer-si-me-solicitan-una-copia-del-dni)
recomienda, para copias del DNI, ocultar los datos innecesarios y evitar su envío
por correo electrónico. Aplicar esa prudencia a la TMI es una recomendación de
diseño, no una acreditación de cumplimiento de un procedimiento aún inexistente.
La referencia a Renfe no implica acceso de EntrenaOP a sistemas de Defensa.
El mecanismo de descuento deberá ser compatible con el proveedor y la tienda
elegidos; un cupón genérico no prueba la condición militar ni concede derechos
por sí solo. No se implementa recogida de documentos, descuentos o integración.

### Retirada del bloque de simulación · COM-003 · 07/10/2026

Javier solicita volver al estado anterior a `308ae18` tras considerar que el
selector y los recorridos no resuelven el producto comercial y percibir problemas
visuales. Se retira el bloque completo, incluida su reorganización de accesos y
ficha básica. Código y pruebas recuperan el estado de `82d74df`; no se modifican
datos remotos, imágenes de Storage ni programas guardados. La simulación local
de COM-002 queda descartada y UI-009 vuelve a quedar pendiente.

La lógica de negocio se abordará en un chat aparte antes de adaptar las vistas:
capacidades y límites de cada nivel, derechos de cuenta en servidor, pago
confirmado que conceda Pro y ciclo de suscripción que conserve datos e historial.
El diseño y proveedor de cobro siguen pendientes. Las tarjetas fotográficas y
el recorrido actual son la referencia; ninguna maqueta sustituye por sí sola
esa experiencia ni acredita funciones comerciales implementadas.

### Reparto confirmado por Javier · COM-001

**COM-008 · 10/10/2026:** Javier retoma la propuesta COM-007 para probar el
negocio con cuentas reales. Free incluye **8 ejercicios propios y 4 familias
de sesiones personales activas**. Pro no tiene esas cuotas comerciales y permite
generar/adaptar programas. Los derechos y las cuotas se aplican en Supabase;
la conexión de pagos sigue pendiente. COM-007 conserva el origen de la propuesta.

El límite se refiere a recursos propios guardados en la biblioteca,
no al número de entrenamientos que el usuario puede realizar o registrar. Los
ejercicios del catálogo, las sesiones oficiales o generadas, las citas de agenda,
el historial y las revisiones de la misma plantilla no consumen esas plazas.
Las cuatro plantillas abarcan fuerza, carrera o mixtas conjuntamente; duplicar
una plantilla sí crea otro recurso y consume una plaza. Archivar una plantilla
libera su plaza sin borrar el historial. Los ejercicios cuentan por identidad
propia; no se introduce archivado de ejercicios ni se eliminan datos para
rebajar el contador. Su eliminación existente conserva sus restricciones de uso.

Las bibliotecas y Mi suscripción muestran los contadores de servidor. Intentar
guardar el noveno ejercicio o la quinta plantilla abre una invitación contextual
a Pro con «Ver Pro» y «Volver», conservando el borrador. Al vencer Pro se mantienen
consulta, uso, edición e historial de los recursos propios, limitando
nuevas creaciones mientras se alcance o supere la cuota Free.

Pro amplía la creación sin estas cuotas comerciales además de los programas
adaptativos; la oferta incorpora ese beneficio. Los triggers validan creación,
duplicado y transiciones que incorporen recursos, serializando mediante el perfil
del propietario. Las revisiones se vinculan a su familia antes de contar plazas.
La administración crea contenido oficial sin consumir plazas personales. El diseño
de creación de sesiones ya distingue plantilla, revisión y ejecución; la cuota
no debe mezclar esos conceptos.

Como referencia de mercado, [Hevy](https://help.hevyapp.com/hc/en-us/articles/33106320824727-Everything-You-Need-to-Know-About-the-Hevy-App-2026-Features-Guide)
ofrece 7 ejercicios propios y 4 rutinas en Free, y amplía ambos en Pro.
[Strong](https://help.strongapp.io/article/105-about-templates) documenta 3
plantillas gratuitas. Esto acredita el uso del patrón, no que una cifra concreta
garantice conversión o sea óptima para EntrenaOP.

| Capacidad | Nivel acordado | Límite o pendiente |
| --- | --- | --- |
| Herramientas de ritmos | Free | No se convierten en Pro por utilizar cálculos. |
| Calculadora PAEF/PAFAS | Free | Conserva su acceso gratuito. |
| Crear sesiones propias | Free con límite | 4 familias personales activas en total; Pro amplía la creación. |
| Ejercicios | Free con límite | 8 ejercicios propios; catálogo excluido y Pro amplía la creación. |
| Algunas sesiones de EntrenaOP | Free | Falta elegir las sesiones incluidas y el criterio de acceso. |
| Programas con algoritmos de generación/adaptación | Pro | Generación y continuidad adaptativa requieren derechos Pro de servidor. |

La frontera utiliza «programa adaptativo» como concepto de producto: no implica
cobrar por cualquier cálculo matemático de una herramienta. COM-004 mantiene
los precios y COM-006 el recorrido. COM-008 añade derechos, cuotas y protección
de servidor en desarrollo; compra, restauración y conciliación de pagos siguen
pendientes. Las concesiones manuales de prueba no representan pagos.

Las listas siguientes conservan detalles del borrador anterior. COM-001 tiene
prioridad: los puntos que no aparecen en el reparto confirmado, como asignar
comercialmente seguimiento de marcas, todavía no se consideran aprobados.
Los contratos vigentes de datos, autoría, conservación del historial y seguridad
se mantienen; aclarar el nivel comercial no elimina esas garantías.

### Borrador anterior: Free

- Biblioteca y sesiones públicas no adaptativas.
- Creación de rutinas propias.
- Creación de sesiones personales de carrera continua, series y pirámides.
- Las rutinas propias son privadas y se distinguen visualmente de la biblioteca
  pública de EntrenaOP.
- El creador mantiene una entrada rápida para series iguales, pero permite
  ajustar objetivo, carga, RIR y descanso de cada serie cuando se necesita.
- El selector permite buscar por nombre, músculo o material y distingue el
  catálogo verificado de EntrenaOP de los ejercicios privados del usuario.
- El usuario puede crear un ejercicio propio con descripción y vídeo HTTPS
  opcional. Nunca puede publicarlo como contenido oficial desde el cliente.
- El creador guarda automáticamente un borrador local. Una sesión nueva y cada
  revisión mantienen espacios separados; al regresar, el usuario decide si
  recupera o descarta los cambios sin finalizar.
- Editar una rutina no cambia entrenamientos pasados: la interfaz guarda una
  nueva versión y conserva la anterior para el historial.
- Historial conservado aunque el usuario deje de pagar.
- Sin progresión adaptativa personalizada.

### Borrador anterior: Pro (nombre provisional)

- Planes específicos de oposiciones.
- Progresión adaptativa automática.
- Prescripciones privadas generadas para las marcas, objetivos y contexto del
  usuario; no son simples copias de las sesiones públicas.
- Seguimiento de marcas y comparación con baremos.
- Sin intervención diaria de un entrenador.

### Borrador anterior: Coaching (nombre provisional)

- Javier asigna y modifica entrenamientos.
- Acceso detallado al progreso del cliente.
- Comunicación directa y feedback.
- Chat interno cuando se desarrolle esa fase.

El nivel comercial, los permisos administrativos y la relación entre entrenador
y cliente son conceptos diferentes.

Los nombres comerciales se validarán antes del lanzamiento. `Pro` y `Coaching`
describen mejor el beneficio que etiquetas genéricas como `Premium` o `VIP`,
pero todavía no son nombres definitivos.

## Alcance de la primera versión validable

### Descubrimiento de preparaciones: revisión abierta · 07/10/2026

Javier señala que «Tus preparaciones» le gusta como colección personal, pero el
botón «Añadir» no permite descubrir fácilmente el resto del catálogo ni explicar
el futuro valor comercial de la adaptación. Plantea una tarjeta con «+ Añadir»,
superficie naranja translúcida, o mostrar preparaciones que se puedan explorar
antes de incorporarlas a la colección personal. Javier acepta la dirección de
la primera maqueta y pide concretarla para la vista actual con acceso completo,
futuro Pro; ese recorrido tiene prioridad sobre la futura entrada de Free.
Javier corrige después el alcance: reorganizar accesos, conservando el aspecto
de la aplicación actual. Rechaza la composición que duplicaba «Añadir
preparación» con un bloque «Explora programas» y sustituía sus tarjetas
fotográficas por una tarjeta genérica de programa en curso. La ubicación
concreta de la entrada única sigue siendo propuesta, sin implementar.
COM-001 fija la frontera comercial de los programas adaptativos,
pero no autoriza presentarla como ya implementada ni publicar programas no
verificados.

La recomendación en revisión es mantener la colección personal y una única
entrada visible al catálogo dentro de «Tus preparaciones», sustituyendo el
botón del encabezado por la tarjeta «+ Añadir» antes solicitada. No se añade un
segundo bloque de descubrimiento. Las fichas de catálogo consultables antes de
seguir una preparación siguen pendientes. El futuro producto comercial
explicaría el beneficio del programa adaptativo en esa ficha. Para quien ya
dispone de acceso, la acción debe llevar
a preparar o empezar el programa, sin volver a ofrecer contratar Pro.
La consulta informativa del catálogo,
guardar una preparación como interés y la oferta comercial de las mediciones
todavía deben diseñarse; la adaptación de entrenamiento queda reservada a Pro.

El posicionamiento quiere representar a opositores y sus pruebas físicas,
conservando los programas militares actuales. La cobertura real no cambia por
mostrar categorías: CNP sigue sujeto a publicación/verificación y Guardia Civil
no se presenta como un programa ya disponible por aparecer como ejemplo de UX.
La incorporación de nuevos cuerpos requiere su propio contenido y comprobación.

Javier prefiere el título «Herramientas» en Inicio. Cuestiona la tarjeta grande de
Biblioteca porque esa sección ya tiene su pestaña propia. UI-026 (10/10/2026)
aplica el título y la retirada del acceso duplicado, sin modificar el negocio.

#### Recorrido prioritario con acceso completo · UI-009

La pregunta que debe resolver Inicio es «¿qué otro programa puedo preparar y
por qué me interesa?». «Tus preparaciones» conserva las elegidas y su diseño
actual: fotografía, encuadre, estado, nombre y fecha. UI-026 cambia únicamente
el acceso a «Ver preparación», confirmado por Javier el 10/10/2026; desde el
detalle se configura o consulta el programa.
Una única entrada permite consultar el catálogo antes de añadir, sin duplicar
el destino con otra sección ni convertir las tarjetas actuales en resúmenes
genéricos. Una futura ficha explica qué prepara, qué datos necesita y cómo
encaja con disponibilidad/material y resultados. No se atribuyen mejoras
medidas, duración fija o cobertura deportiva a programas sin comprobarlos.

El recorrido propuesto es Inicio → catálogo → ficha → preparar el programa →
revisar datos/propuesta → activar. Consultar la ficha no modifica la colección;
añadir conserva el programa que ya está en curso. Los programas ya elegidos
muestran su estado y abren su recorrido existente; el catálogo no los presenta
como novedades sin empezar. La presentación comercial evita justificar Free
con frases defensivas: muestra sus capacidades y comunica el beneficio concreto
de la adaptación cuando corresponde vender Pro.

Se mantiene el contrato vigente de STR-026/027: se guardan varias preparaciones
y solo una genera entrenamientos. Al activar otra, el usuario debe entender
cuál se pausa y cuál se activa. Se conservan marcas, contexto y resultados del
programa anterior; se retiran de la agenda sus sesiones automáticas pendientes
sin empezar, sin borrar su trazabilidad ni afectar a las personales. Una
ejecución en curso bloquea el cambio hasta resolverla. La activación inválida no
puede dejar pausado el programa anterior; ese contrato pertenece al servidor.
Retomar revisa fecha y situación actuales, en lugar de ejecutar una semana vieja.

La corrección de accesos se ilustra conservando las tarjetas de la captura real
aportada por Javier. Solo se propone la entrada única al catálogo; no se
rediseñan otras pantallas. No cambia Flutter, motores, permisos ni SQL. La ficha
informativa previa al alta aún requiere implementación y contenido editorial
verificable; las maquetas anteriores no convierten sus textos en metadatos ya
publicados ni su composición descartada en una decisión vigente.

### Recorrido actual

Un usuario puede guardar y seguir varias preparaciones verificadas. Solo una
genera entrenamientos a la vez, según STR-026/027.
Inicio enseña solo las que ha añadido; el catálogo completo se consulta aparte.
Las sesiones personales no dependen de una oposición concreta. La agenda
semanal ya reúne sesiones personales y de biblioteca; más adelante integrará
las prescripciones de varias preparaciones con una carga global coherente.
Una sesión libre puede convivir el mismo día con una prescripción oficial, pero
no pasa a formar parte de Tropa, CNP ni de otro plan interno porque el usuario
la añada. El vínculo con una preparación queda reservado al algoritmo y a los
servicios de confianza de EntrenaOP. En el futuro, el usuario podrá agrupar sus
sesiones en una planificación personal claramente separada y sin adaptación ni
supervisión de EntrenaOP.
El creador permite dividir una sesión en bloques convencionales con nombre y
orden propios, manteniendo una entrada sencilla con un bloque principal creado
por defecto.
Una superserie enlaza exactamente dos posiciones A1/A2; un circuito recorre dos
o más estaciones. Ambos permiten elegir rondas y descanso entre vueltas y se
presentan en ese orden durante la sesión guiada. En un circuito, cada estación
puede definir además su transición hasta la siguiente. Las posiciones son
independientes y pueden reutilizar un ejercicio del catálogo cuando la
secuencia lo requiera.
Los intervalos de trabajo repiten un único ejercicio y permiten ajustar el
objetivo de cada esfuerzo y una recuperación común. Sirven para trabajo
temporizado de fuerza-resistencia o acondicionamiento; no representan series
de carrera. Tabata se ofrece como protocolo cerrado de ocho rondas de 20
segundos de trabajo y 10 de recuperación. El usuario elige uno o varios
movimientos y la secuencia se repite hasta completar los ocho intervalos.
Desde UI-051, **Iniciar Tabata** activa una preparación inicial de tres segundos
y un reloj continuo para los ocho intervalos, incluida la recuperación final:
cuatro minutos de protocolo, además de la preparación. Trabajo y recuperación
avanzan automáticamente; pausar y reanudar conserva la fase y el tiempo restante.
El bloque termina antes de iniciar cualquier bloque siguiente. Los tiempos del
reloj quedan como borradores locales para revisar; no confirman resultados ni
inventan carga o esfuerzo. Detalle y límites en `SESSION_CONTROLS_2026_10_08.md`.
EMOM alterna uno o varios ejercicios, asigna un minuto a cada uno y
repite la secuencia por vueltas; completar u omitir una estación conserva el
tiempo restante hasta el siguiente minuto. AMRAP usa un único reloj global y
registra vueltas completas, último ejercicio parcial y repeticiones parciales.

La carrera dispone de un creador específico dentro de la sesión unificada.
Expresa tramos ordenados con distancia o duración, ritmo objetivo propio y
recuperación individual, incluida su modalidad. Una pirámide puede así combinar
200/400/600/800/1000 metros y regresar sin fingir que todos los tramos comparten
ritmo o descanso. Las series iguales se editan como un bloque compacto `× N` y
solo se expanden al guardar la prescripción; las pirámides mantienen visibles
sus tramos distintos. Biblioteca, agenda, ejecución e historial leen esa misma
lista final. La duración se estima automáticamente con distancia, ritmo y
recuperaciones temporizadas, sin inventar tiempos para distancias sin ritmo.
El resultado de una carrera continua se registra de forma global. En series,
intervalos o fartlek se registra obligatoriamente cada tramo y su recuperación;
el ritmo se deriva de distancia y tiempo para no ocultar la regularidad detrás
de un promedio. El RPE final es obligatorio y la frecuencia cardíaca media y
máxima son opcionales. Los resultados distinguen entrada manual y dispositivo
para permitir una futura sincronización sin reinterpretar el historial.
El futuro algoritmo generará el mismo contrato versionado, no reglas ocultas en
la interfaz.
La evaluación inicial se abre dentro del programa elegido. Para la referencia
de carrera el usuario elegirá entre un test de VAM y Cooper, sin realizar ambos
por obligación; la prueba oficial de 2.000 m conserva su función cuando el
programa la exige. Los resultados se introducen manualmente tras el esfuerzo.
Una marca previa pertinente y suficientemente reciente puede mostrarse con
su fecha para que el usuario decida si usarla; no se autocompleta la evaluación.
En Mejora FAS ya se puede asociar expresamente un test personal FAS de los
últimos 30 días; ese plazo es provisional y solo se aplica a esta asociación.
Los tests guardados desde la calculadora FAS no alimentan ningún programa
distinto de Mejora FAS.
El administrador puede definir pruebas comunes o diferentes para H/M y edad,
protocolos, intentos y nulos, tablas de marcas y puntos, y regla de aprobado.
Puede importar tablas, simular, revisar la cobertura y publicar un programa
completo. CNP 2026 tiene cargado el anexo II del BOE como borrador y exige
publicación explícita tras su revisión. La columna H/M del baremo se elige
expresamente y no se deduce de la identidad del perfil. En programas publicados,
el deportista registra sus intentos dentro de su preparación y conserva el
resultado y la versión. Falta integrar la evaluación genérica con el algoritmo
semanal, además del protocolo de VAM, la calibración y los plazos de vigencia
del resto de pruebas.
La planificación comienza dentro de cada preparación: el usuario confirma
sus marcas y su contexto de entrenamiento antes de recibir una semana. ADMIN
vinculará módulos deportivos versionados a pruebas y protocolos concretos del
programa; el mismo módulo de 2 km podrá servir a varios programas sin copiar
su algoritmo ni mezclar baremos o historiales. Esta configuración todavía no
está implementada. El plan automático de usuarios ordinarios no necesita un
entrenador del modo Pro. Una limitación o lesión declarada pausa la prescripción
automática por seguridad; no abre una tarea de aprobación profesional en la app.
Los motores de fuerza y carrera no competirán por separado: una capa de
planificación global coordinará la carga semanal del alumno y podrá producir
sesiones específicas o combinadas. La forma comercial de presentar esos
programas se decidirá después; el modelo no debe obligarnos prematuramente a
una única estructura visible.

La primera versión validable debe demostrar el ciclo completo con **un programa
oficial delimitado**. Tropa y Marinería aporta la vertical de evaluación ya
implementada; el piloto de planificación se orientará a la evaluación
periódica tras verificar su fuente y baremo:

1. Alta, acceso y perfil físico.
2. Selección de convocatoria, categoría y fecha objetivo.
3. Registro de marcas iniciales.
4. Generación o asignación de una semana de entrenamiento.
5. Pantalla Hoy con acceso claro a la sesión.
6. Sesión activa con temporizadores, indicaciones, vídeo y registro rápido.
7. Resultado realizado con RPE/RIR, molestias y notas.
8. Evolución de marcas y comparación con el baremo aplicable.
9. Simulacro de las pruebas físicas del programa.
10. Revisión y modificación del plan por el entrenador.

Primero se construirá una vertical completa con un catálogo pequeño pero
revisado de ejercicios de fuerza y sesiones reales de carrera y fuerza. No se
desarrollará toda la biblioteca ni se ampliará la autoría con gestión avanzada
de medios antes de comprobar que evaluación, entrenamiento, resultado y
adaptación funcionan de extremo a extremo. Tampoco se usará un conjunto
insuficiente de movimientos para aparentar una progresión de fuerza validada.

Quedan fuera de esta primera validación el chat, nutrición, desafíos, red
social, Garmin, Strava y la cobertura simultánea de todas las oposiciones.

## Programas guiados oficiales · PRG-001 · 17/10/2026

**Autoría y recorrido del deportista implementados y comprobados en desarrollo;
aceptación en dispositivos pendiente.**
Contrato y límites en [PROGRAMAS_GUIADOS.md](PROGRAMAS_GUIADOS.md).
Javier respalda incorporar programas oficiales de biblioteca con
dos formas dentro del mismo concepto:

- **Rutina:** agrupa sesiones ordenadas que el usuario ejecuta y repite
  con el entrenamiento guiado y registro real de la aplicación.
  Puede mantener ejercicios, series y pautas de esfuerzo mientras el usuario
  registra sus cargas y repeticiones. No exige rotar ejercicios cada semana ni
  un plazo de finalización artificial.
- **Recorrido por fases:** organiza sesiones en etapas con finalidad, duración
  y pautas propias, por ejemplo preparación inicial, desarrollo y consecución
  del objetivo. La evolución puede estar escrita por el autor; no requiere que
  un algoritmo seleccione ejercicios o cambie dosis desde los resultados.

Una guía estable puede representarse como una sola fase repetible, sin obligar
al autor o al deportista a gestionar esa fase en pantalla. Un recorrido puede
añadir varias fases sobre la misma estructura. Las fases del programa no son
los bloques que ya organizan ejercicios dentro de una sesión.

### Autoría común en ADMIN

El creador de programas guiados implementado sirve para ambas
formas. Comparte datos descriptivos, objetivo, destinatarios, requisitos,
material, indicaciones, selección/edición de sesiones, revisión y publicación.
La organización por fases añade sus duraciones, orden e instrucciones sin
crear otro editor de ejercicios o sesiones. La cantidad de sesiones depende
del contenido; cinco o seis son ejemplos, no un límite acordado.

El admin edita sesiones generales o vinculadas a preparaciones y comparte
contratos y campos de sesión con la aplicación del deportista. El catálogo de
Preparaciones mantiene sus pruebas, baremos y módulos; el creador de programas
guiados es independiente. Reutilizar componentes no implica convertir una rutina
de hipertrofia en una oposición ni exigirle pruebas o baremos.

UI-055 permite crear o elegir sesiones desde cada fase/rutina, usando el editor
actual. Guardar, revisar y publicar explícitamente incorpora la versión a la
fase original; el programa se guarda y publica por separado. Las sesiones
generales publicadas siguen disponibles sueltas y son reutilizables. Los
borradores pendientes quedan visibles en el montaje; no se guarda el programa
omitiéndolos sin aviso. Los calentamientos pueden crearse y adjuntarse desde
cada sesión. [Recorrido y límites de conservación](ADMIN_AUTHORING_2026_10_19.md).

UI-056 añade guardado automático y manual del trabajo incompleto por cuenta
administradora. Continuar trabajando recupera sus campos y referencias pendientes,
aunque aún falten sesiones o haya texto inválido. Guardar en catálogo valida el
programa completo y conserva el resultado al reintentar; publicar sigue siendo
una decisión independiente. [Alcance y límites](ADMIN_DRAFT_RECOVERY_2026_10_19.md).

### Personalización y límites

El contenido oficial prescribe la estructura y el esfuerzo aplicable; el usuario
ajusta su carga y registra lo realizado. Prescripción, resultados y seguimiento
personal deben distinguirse, conservando la versión realizada cuando se revise
el contenido editorial. La recuperación de cargas previas es una ayuda de
registro propuesta, no una regla de progresión automática ya implementada.

Estos programas se distinguen de sesiones sueltas, sesiones propias y planes
adaptativos. No redefinen las preparaciones actuales ni STR-026/027. Seguir una
guía junto a una preparación no acredita coordinación de carga entre ambas.
Los desafíos quedan fuera de este alcance. La revisión deportiva debe cubrir
el programa completo, sus requisitos y su evolución; la referencia visual y
la estructura técnica no sustituyen esa revisión.

La referencia de Calisteniapp muestra catálogo, información, fases y sesiones,
así como pautas por esfuerzo sin kilos prescritos en el programa consultado.
El vídeo no acredita su funcionamiento tras iniciar un programa ni sus reglas
internas. Se utiliza como referencia de experiencia, no como contrato deportivo.

### Avance de fase confirmado por Javier

El autor indica la duración y las condiciones de cada fase, y el usuario
confirma cuándo pasa a la siguiente. El mero transcurso del calendario no
provoca el avance: una interrupción no debe consumir etapas sin entrenarlas.
La ficha muestra duración/condiciones y pide confirmación. No comprueba su
cumplimiento como un algoritmo deportivo y rechaza el avance con una sesión
en curso. Reenviar una confirmación no consume otra fase. La pauta siguiente
es la definida por el autor; esta confirmación no activa un motor adaptativo.

### Calentamientos reutilizables solicitados

Javier solicita calentamientos básicos y homogéneos que el administrador pueda
preparar y adjuntar opcionalmente a las sesiones de estos programas. El usuario
puede omitir el calentamiento guiado y realizar el trabajo principal. El
ejecutor actual ya reconoce bloques de calentamiento y permite omitirlos;
STR-031 conserva esa elección separada de los resultados de entrenamiento.
La autoría y selección de calentamientos reutilizables en ADMIN están implementadas
en el bloque 1; el bloque 2 permite ejecutarlos u omitirlos en la sesión real.

Un pequeño catálogo por finalidad permite reutilizar
calentamientos pertinentes sin aplicar uno idéntico a todas las sesiones. La
selección implementada se realiza por sesión, sin exigir calentamiento. La
sesión conserva la versión adjunta; revisar un calentamiento no debe cambiar
lo ya entrenado. Las dosis y contenidos concretos requieren revisión propia.

### Ajustes de descanso implementados

Javier confirma permitir cambios antes de entrenar. El autor distingue
descansos ajustables y descansos fijados
por la pauta, con una duración recomendada y límites cuando proceda. Un acceso
opcional a los ajustes de la sesión evita añadir un formulario obligatorio.

No debe aplicarse un único cambio global a series, transiciones de circuito,
pausas entre rondas y recuperaciones temporizadas. En EMOM, Tabata, intervalos
y carrera, las recuperaciones forman parte del formato o de la dosis; no se
desbloquean desde un ajuste genérico. La política actual de EMOM calcula el
tiempo restante hasta el minuto. Los ajustes propuestos para programas guiados
no amplían las reglas del plan adaptativo.

La pauta oficial y el descanso aplicado a la ejecución deben distinguirse.
Modificar el ajuste personal no edita la plantilla pública. ADMIN ya guarda
los límites; la ejecución privada guarda el ajuste aplicado y conserva la pauta
oficial. El servidor valida el rango y los reintentos conservan los ajustes.

### Biblioteca: distribución implementada en el bloque 2

Javier pide conservar la identidad y la comodidad actuales, con descubrimiento
claro de programas y sin una portada de desplazamiento interminable. El selector
incorpora Programas, Sesiones y Ejercicios, con cambio
por toque o deslizamiento y conservación de la posición y filtros por sección.
Sesiones y Ejercicios mantienen su separación EntrenaOP/propios y sus accesos
de creación. Dentro de Programas se distinguen **Rutinas** y **Por fases**;
la etiqueta singular en las tarjetas es **Rutina**, según acuerdo del 18/10/2026.

Programas utiliza búsqueda, filtros y dos resultados por página; los controles
de página se ocultan cuando solo existe una. Mantiene la
entrada inicial en Sesiones y el estilo de tarjetas existente. Se han revisado
capturas de widgets reales, incluido texto ampliado; la aceptación física sigue
pendiente. El programa adaptativo conserva su recorrido en Mi plan, sin duplicar
otro catálogo EVO ni renombrar las preparaciones actuales por esta propuesta.

El seguimiento queda fijado a su versión, conserva resultados y permite repetir
un programa terminado sin borrar el anterior. La vista previa permite entrenar
solo la fase actual del programa seguido; las demás son de consulta. No añade
coordinación adaptativa, agenda automática, progresión de cargas ni política
comercial nueva. El siguiente bloque es la aceptación del recorrido en móvil
y ADMIN. Por petición de Javier se publican solo en desarrollo dos demos de
tres sesiones: guía de empuje/tirón/pierna y dominadas con tres fases. Permiten
probar calentamientos opcionales, descansos y confirmación de avance sin acceso
actual a ADMIN. Son contenido de aceptación funcional, pendiente de revisión
deportiva antes de convertirse en programas definitivos.

Javier confirma el 18/10/2026 mantener **Iniciar programa** como paso explícito
para ambas modalidades. Crea el seguimiento y permite después elegir sesión.
Inicio/Hoy muestra **Tus programas**, los tres últimos iniciados activos,
con fase actual y acceso a la ficha. Se actualiza al volver/refrescar, sin crear
sesiones por fecha ni mezclar la rutina con la agenda adaptativa.
En la revisión del mismo día, Javier sitúa esta sección debajo de Preparaciones:
tarjetas de 250 px de ancho y carrusel horizontal con el mismo acabado visual. Si no hay
programas iniciados, se ofrece Añadir programa. Ese acceso y Añadir en la cabecera
abren directamente la pestaña Programas de Biblioteca.

PRG-005 permite **Dejar programa** desde su ficha, con confirmación. Conserva
todos los entrenamientos y registros; retira el seguimiento de Inicio y del
filtro Programas iniciados, reservado a seguimientos sin completar ni abandonar.
El abandono se distingue de completar. Si la versión sigue publicada, se puede
volver a iniciar desde el principio con un seguimiento nuevo y conservar el
historial anterior. Una sesión abierta debe terminarse o abandonarse primero
desde el ejecutor habitual; la ficha lo indica y el servidor lo comprueba.
Implementado y verificado solo en desarrollo; aceptación móvil pendiente.

PRG-004 reutiliza la misma tarjeta editorial de Preparaciones para los programas
de Inicio y Biblioteca; se retiran sus composiciones duplicadas. Las tarjetas de
sesiones dentro de rutinas y fases se conservan. Desde ADMIN → Programas guiados
→ Portada se usa el editor común para seleccionar, encuadrar, sustituir o retirar
la foto. Una fotografía comparte portada y cabecera con encuadres independientes,
y es común a las versiones de la familia. Cambiarla no modifica entrenamiento
ni resultados. Las fotos de las demos quedan a elección editorial. Implementado
solo en desarrollo; aceptación autenticada en dispositivos pendiente.

PRG-006 corrige las proporciones tras la captura de Javier: se elimina la
variante cuadrada que aún diferenciaba Programas de Preparaciones. Ambas usan
una única composición compacta, sin espacio expansible bajo el título, con
altura según contenido y tamaño de texto. Inicio, Biblioteca y la vista previa
de ADMIN comparten este formato; las tarjetas de sesiones se conservan.

PRG-007 conserva Inicio y adapta Biblioteca al ancho disponible: una columna
en móvil y dos en pantallas amplias, usando la misma tarjeta. Los programas
admiten varias categorías editoriales con una principal visible junto a
Rutina/Por fases. ADMIN gestiona el catálogo y permite crear categorías desde
el creador. Renombrar conserva referencias; desactivar conserva asignaciones
y bloquea las nuevas. El guardado de borrador y categorías es atómico.
El buscador encuentra nombre, descripción y todas las categorías con/sin
tildes, antes de paginar; también se puede filtrar por categoría. Las demos de
desarrollo están clasificadas para probarlo. Implementado y verificado solo
en desarrollo; aceptación autenticada en dispositivos pendiente.

PRG-008 sustituye el paginador visible por catálogo directo: búsqueda y Filtros
en una fila, selector Mostrar plegado y categorías de ADMIN en chips que se
deslizan horizontalmente. Texto, modalidad y categoría se combinan; Todos solo
retira la categoría. El catálogo reúne las tandas del repositorio hasta su final,
sin páginas numeradas ni Ver más. Mantiene tarjetas, portadas y anchos vigentes,
y las tarjetas visibles al actualizar tras volver de una ficha. Implementado y
verificado en Flutter; aceptación física pendiente. Detalle y límites en
[PROGRAMAS_GUIADOS.md](PROGRAMAS_GUIADOS.md).

PRG-009 separa publicación y descubrimiento de sesiones. ADMIN elige Mostrar en
Sesiones de EntrenaOP por versión, inicialmente desmarcado al crear desde un
programa y marcado al crear una sesión suelta. La ficha permite cambiarlo sin
revisar la receta ni alterar programas o entrenamientos existentes. Una versión
puede reutilizarse en varios programas. El buscador incluye sus ejercicios y
los chips de Programas solo ofrecen categorías con publicaciones vigentes.
Las elecciones editoriales existentes se conservan. Contrato y verificación en
[SESSION_LIBRARY_EDITORIAL_2026_10_19.md](SESSION_LIBRARY_EDITORIAL_2026_10_19.md).

## Plataformas

- Android e iPhone son prioritarios para la experiencia del opositor.
- La web responsive será inicialmente el espacio de administración y
  seguimiento del entrenador.
- Una web pública convencional podrá utilizarse para captación, contenido y
  posicionamiento sin obligar a que toda la presencia web use Flutter.
- Windows se mantendrá como destino posible, pero no condicionará el MVP.
- La sesión activa debe tolerar pérdida de conexión y poder recuperarse sin
  perder resultados.

## Áreas funcionales previstas

- **Hoy:** calendario semanal, entrenamiento asignado y acceso a la sesión
  activa.
- **Explora:** programas, sesiones públicas, rutinas propias y, más adelante,
  desafíos.
- **Programas:** ingreso a Tropa como primer catálogo implementado; evaluación
  periódica militar como piloto adaptativo tras delimitar su versión; después,
  otros accesos y evaluaciones con sus pruebas y baremos.
- **Resultados:** marcas, evolución, comparación con baremos, historial y
  métricas de carga.
- **Chat:** reservado al seguimiento personalizado en su fase correspondiente.
- **Perfil:** datos personales, métricas físicas, suscripción e integraciones.
- **Administración:** clientes, contenido público, asignaciones, ejercicios,
  progreso y comunicación.

En móvil se estudiará un número razonable de destinos principales. Web y
Windows utilizarán una composición responsive, probablemente con navegación
lateral. La antigua propuesta de seis destinos inferiores no es una obligación.

## Sesión activa

Es el flujo central del producto. Debe ofrecer:

- Temporizador claro.
- Ejercicio, indicaciones y vídeo consultable.
- Progreso de ejercicio, serie o bloque.
- Registro rápido del resultado real.
- Feedback final mediante RPE/RIR, estado y notas.

El modelo representa ya series tradicionales, circuitos, superseries, AMRAP,
EMOM, Tabata y tramos de carrera. Isométricos, calentamiento y vuelta a la calma
siguen siendo necesidades del modelo completo, no recorridos cerrados por esta
entrega.

El historial necesita datos suficientemente detallados para el algoritmo:
series, repeticiones, carga, tiempo, distancia, ritmo, descansos, cumplimiento,
RPE/RIR, modificaciones, pruebas y simulacros.

## Diseño

- Material 3.
- Apariencia oscura, seria y deportiva.
- Naranja `#E65100` como color primario de referencia.
- Fondo histórico de referencia `#0A0A0A`.
- Calisteniapp es una inspiración de experiencia, especialmente durante la
  sesión, pero no una plantilla que deba copiarse.
- Vídeos de ejercicios: máximo de 10 segundos confirmado por Javier (VID-002,
  ampliado el 18/10/2026 para dar margen a demostraciones de ocho a diez segundos).
  MP4/H.264 y hasta 720p siguen como orientación técnica por validar con costes,
  accesibilidad y necesidades reales antes de cerrar la implementación.

## Consulta y tareas de entrenamiento · 06/10/2026

Las secciones de consulta conservan dónde estaba el usuario. Configurar el
programa o contexto, registrar una marca, crear ejercicios, editar sesiones y
entrenar utilizan pantallas dedicadas sin barra de secciones. Los cambios sin
guardar tienen salida confirmada; los borradores válidos y las series ya
confirmadas se conservan al salir para retomar. UI-022 añade la opción explícita
de descartar una ejecución en curso y sus series, con confirmación del servidor.

Perfil y «Mi programa» comparten disponibilidad y material exacto. Guardar los
datos actualiza el contexto para la siguiente adaptación y conserva el historial.
El motor de carrera y el coordinador siguen en servidor; esta corrección no
redefine sus reglas. Detalle en `PROGRAMA_ADAPTATIVO.md` y `VISUAL_DESIGN.md`.

## Integraciones futuras

- Suscripciones: RevenueCat elegido en COM-012; COM-013 añade la integración
  inicial de Test Store conectada en Dev. Pruebas completas de iOS/Android
  pendientes. Venta web y Windows quedan fuera de este primer tramo.
- Dispositivos y actividades, INT-001 (21/10/2026): bloque común acordado para
  deportista, ADMIN y entrenadores, comenzando por contrato y acceso para carrera.
  Salud de Apple, Health Connect, Garmin, COROS, Suunto y Huawei son objetivo de
  cobertura según capacidades reales; no se garantiza todo modelo o función.
  La primera vertical será lectura, revisión y asociación a una sesión prevista;
  el envío requiere integración y compatibilidad propias. Contrato y vías de
  acceso documentados; INT-002 implementa el dominio puro de importación y
  asociación con pruebas, todavía sin consumo desde las apps, conectores o
  relojes probados. No bloquea el trabajo
  profesional activo ni modifica sus derechos. No se diseña sobre Google Fit.
  [Alcance, fases y límites](DEVICE_INTEGRATIONS.md).
- Strava sigue como investigación futura, fuera del primer alcance de INT-001;
  no se añade como dependencia para conectar los fabricantes.
- Nutrición, si se incorpora, comenzará con un alcance limitado.

La IA generativa no decidirá la progresión inicial. Podrá ayudar en el futuro a
explicar, resumir o redactar, pero las decisiones de entrenamiento comenzarán
con reglas deterministas, explicables, versionadas y anulables por el
entrenador.

## Cobro del servicio del preparador · TRN-012 · 21/10/2026

El alumno paga al preparador por su servicio; el preparador paga a EntrenaOP
por herramientas y plazas. El acceso incluido evita otra suscripción obligatoria
de EntrenaOP al alumno y no convierte en gratuito el trabajo del entrenador.
Javier pide facilitar el pago al preparador desde la web. Pasarela, proveedor y
condiciones quedan pendientes en un bloque propio; no se activan cobros aquí.
[Contrato pendiente de pagos](TRAINER_PAYMENTS.md).
