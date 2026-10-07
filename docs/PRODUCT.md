# Producto EntrenaOP

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
El único siguiente tramo UX es Evolución/Marcas, filtros e historial antiguo.

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
- **Profesional:** el entrenador incorpora y gestiona clientes desde un espacio
  de trabajo propio.

Una variante para academias podría incorporar organizaciones, grupos, alumnos y
varios entrenadores. Es una dirección futura, no alcance del MVP. El modelo
actual debe evitar bloquearla, pero no implementarla anticipadamente.

## Free y Pro: reparto confirmado, diseño comercial pendiente

**Aclaración de Javier · 07/10/2026:** existen pruebas y algoritmos en desarrollo,
pero Pro todavía no está diseñado ni implementado como producto comercial.
No hay oferta cerrada, pantallas de contratación, precios, suscripciones o
concesión de derechos Pro verificada. Javier concreta a continuación la frontera
comercial: las herramientas y el entrenamiento manual limitado pertenecen a
Free; los programas que generan/adaptan entrenamientos con los algoritmos
pertenecen a Pro. Este reparto está confirmado, pero no describe restricciones
actuales implementadas en servidor. Tener un algoritmo implementado no convierte
su recorrido en una función comercial Pro ya disponible.

### Reparto confirmado por Javier · COM-001

| Capacidad | Nivel acordado | Límite o pendiente |
| --- | --- | --- |
| Herramientas de ritmos | Free | No se convierten en Pro por utilizar cálculos. |
| Calculadora PAEF/PAFAS | Free | Conserva su acceso gratuito. |
| Crear sesiones propias | Free con límite | Javier plantea dos o tres; la cifra definitiva está pendiente. |
| Ejercicios | Free con límite pendiente | Falta concretar cantidad y qué operación o colección limita. |
| Algunas sesiones de EntrenaOP | Free | Falta elegir las sesiones incluidas y el criterio de acceso. |
| Programas con algoritmos de generación/adaptación | Pro | Generación y continuidad adaptativa requieren derechos Pro de servidor cuando se implemente el producto comercial. |

La frontera utiliza «programa adaptativo» como concepto de producto: no implica
cobrar por cualquier cálculo matemático de una herramienta. No se introducen
ahora cuotas, candados funcionales o cobros. Precios, contratación, derechos,
cancelación y experiencias sin Pro siguen pendientes de diseño e implementación.

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
Biblioteca porque esa sección ya tiene su pestaña propia; retirarla es una
recomendación de esta revisión, todavía no una modificación aplicada.

#### Recorrido prioritario con acceso completo · UI-009

La pregunta que debe resolver Inicio es «¿qué otro programa puedo preparar y
por qué me interesa?». «Tus preparaciones» conserva las elegidas y su diseño
actual: fotografía, encuadre, estado, nombre, fecha y «Gestionar preparación».
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
movimientos y la secuencia se repite hasta completar los ocho intervalos. EMOM
alterna uno o varios ejercicios, asigna un minuto a cada uno y
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
- Vídeos previstos: MP4/H.264, normalmente cortos y hasta 720p; esta política se
  validará con costes, accesibilidad y necesidades reales antes de cerrar la
  implementación.

## Consulta y tareas de entrenamiento · 06/10/2026

Las secciones de consulta conservan dónde estaba el usuario. Configurar el
programa o contexto, registrar una marca, crear ejercicios, editar sesiones y
entrenar utilizan pantallas dedicadas sin barra de secciones. Los cambios sin
guardar tienen salida confirmada; los borradores válidos y las series ya
confirmadas se conservan. Salir de una sesión permite retomarla, sin abandonarla.

Perfil y «Mi programa» comparten disponibilidad y material exacto. Guardar los
datos actualiza el contexto para la siguiente adaptación y conserva el historial.
El motor de carrera y el coordinador siguen en servidor; esta corrección no
redefine sus reglas. Detalle en `PROGRAMA_ADAPTATIVO.md` y `VISUAL_DESIGN.md`.

## Integraciones futuras

- Suscripciones: RevenueCat o solución equivalente, después de validar iOS,
  Android, web y Windows.
- Salud móvil: Health Connect y las APIs vigentes del ecosistema Apple/Google;
  no diseñar una integración nueva alrededor del antiguo Google Fit.
- Garmin Connect y Strava se investigarán más adelante y no deben bloquear el
  MVP. La investigación de Garmin debe cubrir tanto sincronizar sesiones de
  carrera como vincularlas a planes de preparación de oposiciones.
- Nutrición, si se incorpora, comenzará con un alcance limitado.

La IA generativa no decidirá la progresión inicial. Podrá ayudar en el futuro a
explicar, resumir o redactar, pero las decisiones de entrenamiento comenzarán
con reglas deterministas, explicables, versionadas y anulables por el
entrenador.
