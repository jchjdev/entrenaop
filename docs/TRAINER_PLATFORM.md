# Plataforma para preparadores · alcance acordado · 21/10/2026

## Inventario y siguiente bloque · 29/10/2026

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
| 6. Biblioteca eficiente | Fotos, origen oficial/propio, colecciones, búsqueda interna, formatos y ciclo papelera/recuperación/borrado protegido | Filtros actuales sobre filas cargadas; limpieza de medios independiente |
| 7. Grupos y envío conjunto | Grupos, asignación conjunta y copia semanal | Aceptación completa con varios alumnos y revisión por destinatario |
| 8. Evolución | Métricas por periodo y evolución del servicio | — |
| 9. Bandeja de revisión | Resultados, revisión persistente y correcciones | — |
| 10. Vídeos en ambas direcciones | Archivos propios, enlaces externos, demostraciones y técnica; aviso Android aceptado | Completar la gestión de medios/reservas dentro del futuro ciclo de limpieza, protegiendo usos históricos |
| 11. Formularios | Plantillas, asignación y respuestas en el espacio Preparador | — |
| 12. Comunicación | Chat con refresco, globos y push profesional Android aceptada en beta.3 | Apple/APNs y pruebas físicas extendidas de descanso/cuentas/recordatorios |
| 13. Automatizaciones controladas | Recurrencias finitas | Automatización adaptativa profesional y sus reglas; no se presenta como motor ya entregado |
| 14. Cobros y servicio | Registro/recuperación web, acceso manual y contratación EntrenaOP→preparador ensayada con Stripe sandbox | Tarifas y políticas finales, operación de cobros reales y circuito alumno→preparador |
| 15. Informes | Resumen por periodo y CSV | Otros formatos serían ampliaciones, no un requisito básico acreditado como ausente |
| 16. Oposición y dispositivos | Metas, marcas y pruebas privadas; integraciones con su contrato propio | Cierre de los recorridos deportivos/oficiales y de dispositivos según sus bloques; este inventario no reaudita Garmin |

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

La migración `20261029195445_trainer_admin_catalog_trash.sql` está aplicada solo
en Dev. Exige identidad, MFA y acceso de autoría; mantiene aislamiento de cuentas
y ADMIN. Recibos y sellos protegen reintentos y retiradas posteriores. Bloqueos
por recurso/familia evitan una exclusión global de todas las cuentas. Las listas
nuevas se paginan por sello e ID, 50 por página.

Purgar ejercicios libera únicamente las unidades de versiones eliminadas.
Las reservas/ficheros de imágenes y vídeos se conservan y siguen contando según
su contrato: este bloque no añade limpieza remota de medios ni vaciado automático.

**Verificación al cierre:** análisis limpios y baterías completas: raíz 1.446
pruebas (una omisión previa), Trainer 317, editor compartido 223 y `entrena_ui` 40.
ADMIN 358 (dos omisiones previas). Las tres papeleras y el listado de ejercicios
administrativos están conectados a la guarda real del router: confirmación y
envío bloquean salida; una respuesta incierta conserva el recurso/UUID y ofrece
reintento incluso después de refrescar. Total: 2.384 pruebas correctas.
Contrato SQL nuevo y diez regresiones correctos, todos con ROLLBACK: catálogos
privados, vídeos, recuperación de sesiones/programas/contextos y operaciones/
papelera editorial ADMIN. Dos conexiones reales comprueban que una asignación
retiene el recurso compartido: el exclusivo de otra familia sigue disponible y
el del mismo recurso espera hasta el límite de 700 ms. Ambas hacen ROLLBACK;
sin fixtures persistentes. Historial de migraciones Dev local/remoto coincidente.
Advisors del alcance: cuatro INFO intencionales por RLS sin políticas/grants en
tablas privadas; ningún WARN/ERROR nuevo del ciclo. La inspección de JSON de
dispositivos sigue siendo global porque pertenece al alumno y puede sobrevivir
al vínculo; no es una prueba de carga a gran escala. Fuentes validadas y listas
para publicación automática en Dev, pendiente de acreditar la versión servida.

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

**Acordado para más adelante; sin implementación ni fecha de entrega.** Javier
confirma incorporar un directorio voluntario de profesionales. Primero se hará
el directorio de entrenadores en la web y después se ampliará a centros. Este
trabajo no sustituye el siguiente bloque comercial vigente del roadmap.

### Recorrido y límites acordados

- Cada entrenador decide publicitarse. La ficha prevista incluye foto,
  presentación breve y especialidades; dispone de espacio para explicar su
  propuesta y sus servicios con su propia voz.
- «Mi preparador» será el punto de entrada previsto para descubrir profesionales
  desde la app. La primera entrega sigue siendo web; queda por diseñar si esa
  entrada abre el directorio web o incorpora búsqueda nativa posteriormente.
  Buscar no debe sustituir el acceso a los preparadores ya vinculados.
- El primer contacto será externo al chat de EntrenaOP. Cada profesional elige
  qué canales publicar entre correo profesional, web o WhatsApp. El botón
  «Contactar» ofrece únicamente los canales publicados voluntariamente; no se
  utiliza por defecto el correo privado de acceso a la cuenta.
- Se reafirma el máximo actual de **dos preparadores externos activos por
  alumno** de TRN-028. Consultar una ficha o contactar no consume plaza, acepta
  una invitación ni concede acceso al calendario, resultados u otros datos
  privados. La vinculación conserva su aceptación explícita y controles
  existentes. El vínculo interno «Para mí» conserva su tratamiento independiente.
- La segunda fase añade centros. Una ficha pública de centro no aprueba por sí
  sola organizaciones, equipos, acceso a alumnos compartido ni un cambio del
  límite de preparadores.

### Criterios adicionales acordados

Javier confirma estas propuestas el 28/10/2026 para cuando se retome el
directorio. Son acuerdos de producto futuros, sin implementación ahora:

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
- Empezar con un grupo pequeño de profesionales activos, con criterios de
  revisión y retirada por concretar. Distinguir el uso de EntrenaOP de las
  titulaciones que se hayan verificado.

### Cuestiones pendientes

Concretar el diseño de los canales de contacto, valores y filtros iniciales,
gestión/publicación de fichas, criterios de revisión/retirada y orden de
resultados. También decidir qué ocurre con la ficha al perder el acceso
profesional y cómo se representa un
centro y su relación con los entrenadores. Aparecer en el directorio no fija
tarifas, comisiones, suplementos ni acreditaciones. Reseñas, reservas, chat de
captación y contratación automática no forman parte del primer alcance acordado.

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
