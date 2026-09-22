# Roadmap de EntrenaOP

Este roadmap expresa prioridades, no fechas cerradas. Debe actualizarse cuando
el código y las decisiones de producto cambien.

## Paso 0: comprender y estabilizar

1. Auditar repositorio, dependencias, Git, arranque, navegación, autenticación,
   ejercicios, esquema SQL, RLS, correspondencia de modelos y pruebas.
2. Clasificar hallazgos por roturas, seguridad/integridad, arquitectura que
   conviene corregir ahora y mejoras aplazables.
3. Acordar un único orden de corrección antes de modificar código funcional.
4. Mover la configuración de Supabase a entornos adecuados y resolver los
   defectos críticos que confirme la auditoría.
5. Incorporar el esquema remoto a migraciones reproducibles, junto con
   constraints, políticas RLS y datos de prueba controlados.
6. Dejar autenticación, restauración de sesión, análisis estático y pruebas base
   en un estado verificable antes de ampliar funcionalidad.

## Fase 1: concretar el dominio PAEF/PAFA

Antes de diseñar las tablas definitivas se trabajará con ejemplos reales para
definir:

- Pruebas, convocatorias, categorías y baremos versionados.
- Diferencia entre programas de acceso y evaluaciones internas.
- Tramos de edad, tablas de puntos y cálculo total para PAEF/PAFA cuando se
  disponga de sus fuentes oficiales.
- Datos que se prescriben y resultados que se registran.
- Fuerza, carrera, circuitos, superseries, AMRAP, EMOM, Tabata e isométricos.
- Reglas ante sesiones completadas, fallidas, omitidas o con molestias.
- Límites de adaptación y capacidad de anulación del entrenador.

El resultado de esta fase serán conceptos de dominio comprensibles y pruebas de
sus reglas principales, no solo un diagrama o un conjunto de tablas.

## Fase 2: primera vertical funcional

Se completará un único recorrido antes de extender horizontalmente el producto:

1. Registrar una marca inicial.
2. Generar o recibir una sesión con pocos ejercicios reales.
3. Ejecutar la sesión, incluso ante una pérdida temporal de conexión.
4. Guardar el resultado prescrito y el realizado sin confundirlos.
5. Mostrar evolución y comparación con el baremo usado.
6. Producir una recomendación siguiente explicable.

Esta vertical incluirá:

- Autenticación y persistencia de sesión fiables.
- Conjunto mínimo de ejercicios necesario para la vertical.
- Creación y asignación de la sesión.
- Modelo de entrenamiento capaz de expresar los formatos necesarios.
- Pantalla de sesión activa.
- Registro detallado de resultados y feedback.
- Base inicial de ingreso a Tropa y Marinería, baremos versionados y
  pruebas/simulacros.

El modelo permite que un usuario siga varias preparaciones simultáneas. Inicio
muestra únicamente las añadidas por él y el catálogo se mantiene en una
pantalla separada para no mezclar objetivos propios con toda la oferta futura.
La primera vertical deportiva continúa limitada a Tropa y Marinería hasta que
los demás programas dispongan de reglas y baremos verificados.

El primer incremento del motor utiliza una plantilla pública mínima almacenada
en Supabase y una ejecución persistente serie a serie. Ya permite recuperar el
progreso, temporizar descansos, conservar la prescripción usada y registrar el
resultado real o la omisión de cada serie. Las series por duración incluyen una
cuenta atrás que puede pausarse, reanudarse y restaurarse al volver a la sesión.
Salir conserva la sesión activa, mientras que el abandono definitivo registra
el motivo sin convertir automáticamente las series restantes en omitidas.
Las sesiones completadas y abandonadas ya aparecen en Evolución, donde puede
consultarse el objetivo y el resultado real de cada serie. Las evaluaciones
físicas conservan un historial separado dentro de la misma área para no mezclar
pruebas de acceso con entrenamientos cotidianos.
Al completar una sesión se registra el esfuerzo global y una nota opcional de
sensaciones, que permanece visible en el resumen y el historial.
Los errores de registro pueden corregirse desde el detalle durante 24 horas y
con un máximo de tres cambios por serie. Cada cambio exige motivo y queda
auditado en PostgreSQL.
Durante la ejecución se muestra la descripción técnica del ejercicio y, cuando
el catálogo dispone de él, un vídeo opcional cargado bajo demanda.
Los temporizadores emiten avisos al preparar, comenzar y terminar el trabajo y
al finalizar un descanso. Sonido y respuesta háptica se configuran de forma
independiente y la preferencia queda guardada en el dispositivo.
Los resultados pueden guardarse durante una pérdida de conexión. Una cola
persistente conserva las operaciones, la interfaz indica cuántas quedan
pendientes y Supabase las acepta de forma idempotente al volver la red, sin
duplicar series aunque una respuesta se haya perdido.

La biblioteca completa y otros formatos se ampliarán después de validar este
recorrido.

La primera Biblioteca ya consulta las plantillas públicas publicadas y abre su
detalle mediante una ruta genérica. La sesión inicial es su primer contenido
real. Las plantillas públicas, las rutinas personales y las futuras
prescripciones adaptativas comparten motor de ejecución, pero conservan origen,
visibilidad y versionado distintos.

El primer creador de sesiones personales permite ordenar ejercicios del
catálogo y prescribir series homogéneas por repeticiones, tiempo o distancia,
con descanso, carga y RIR opcionales. El guardado es privado y atómico en
PostgreSQL. El catálogo ya permite buscar, separar contenido de EntrenaOP y
ejercicios propios, y crear estos últimos como recursos privados con
descripción y vídeo HTTPS opcional.
El editor conserva además un borrador automático local por sesión. Puede
recuperarse después de abandonar o reiniciar la aplicación y se limpia tras un
guardado correcto, evitando escrituras continuas en el backend.

La segunda iteración ya permite variar cada serie, copiar la primera al resto,
añadir o retirar series, duplicar una sesión completa y archivarla sin perder
su historial. La edición de una sesión existente crea una revisión enlazada y
archiva la anterior, por lo que el ciclo básico de rutinas personales queda
cerrado sin reinterpretar ejecuciones pasadas.

El creador organiza ya una sesión personal en varios bloques convencionales.
El usuario puede nombrarlos, ordenarlos, eliminarlos y mover ejercicios entre
ellos. Esta estructura precede a los formatos avanzados: circuitos, superseries
e intervalos añadirán comportamiento al bloque sin sustituir el editor actual.

La primera ampliación de formatos incorpora superseries y circuitos. Ambos
definen rondas y descanso entre rondas; la ejecución intercala los ejercicios
de cada vuelta y descansa únicamente al finalizar la ronda. No son etiquetas
visuales sobre una secuencia convencional. El editor muestra posiciones A1/A2
en superseries y estaciones ordenadas en circuitos; cada posición es
independiente aunque reutilice un ejercicio del catálogo.

La segunda ampliación añade intervalos de trabajo de un solo ejercicio y
Tabata canónico 8 × 20/10. Tabata permite elegir una secuencia de movimientos y
la repite hasta completar sus ocho posiciones. Ambos reutilizan el
temporizador, la pausa, la restauración y el historial del motor guiado. Este
formato de intervalos no pretende cubrir el entrenamiento de carrera.

La ampliación específica de carrera se diseñará antes de implementarse. Debe
cubrir al menos series regulares, pirámides, fartlek y carrera continua mediante
tramos ordenados con distancia o duración, ritmo objetivo y recuperación
individual. El creador será especializado, pero publicará en la misma sesión,
agenda, ejecución e historial que el resto de entrenamientos. Las decisiones de
ritmo y progresión pertenecerán a un motor determinista y versionado.

La tercera ampliación incorpora EMOM con uno o varios ejercicios alternados.
Cada estación inicia automáticamente su minuto, conserva el tiempo restante
como pausa y restaura su reloj si se interrumpe la pantalla. El bloque no puede
superar sesenta minutos.

La cuarta ampliación incorpora AMRAP con un reloj global de hasta sesenta
minutos. Su resultado no falsea series convencionales: conserva vueltas
completas y el avance parcial alcanzado al terminar el tiempo.

La V1 del creador de fuerza queda cerrada con una vista previa que explica el
orden de cada bloque, sus rondas, transiciones, descansos y objetivos por
serie antes de iniciar la sesión. El recorrido conserva esos datos al guardar,
programar, ejecutar y consultar el historial. Las siguientes ampliaciones del
creador se tratarán como nuevas iteraciones, no como requisitos pendientes de
esta primera versión.

La agenda semanal global ya permite combinar sesiones personales y contenido
de la biblioteca, seleccionar el día, reprogramar, retirar e iniciar cada
entrenamiento. Cada entrada conserva una instantánea del nombre, versión y
duración previstos para que el calendario no cambie retrospectivamente. Las
futuras prescripciones del algoritmo y del entrenador utilizarán esta misma
agenda sin mezclar sus responsabilidades.

## Fase 3: adaptación y seguimiento

- Algoritmo determinista de progresión, con auditoría y anulación manual.
- Evolución de marcas y comparación con baremos.
- Panel de administración y gestión de clientes.
- Servicio de seguimiento personalizado.
- Chat y notificaciones cuando permisos y modelo comercial estén consolidados.

## Fase 4: monetización e integraciones

- Suscripciones y derechos multiplataforma.
- Integraciones de salud y actividad priorizadas por valor real.
- Garmin y Strava si los acuerdos y APIs disponibles lo permiten.
- Nutrición básica si no desvía el foco del producto.
- Nuevas oposiciones: CNP, Guardia Civil y otras, una vez estabilizado el modelo.

## Fase futura: entrenadores y academias

El panel profesional comenzará con las necesidades reales de Javier y del
seguimiento personalizado. Si el uso demuestra demanda, podrá evolucionar a:

- Espacios de trabajo de entrenador.
- Invitación e incorporación de clientes.
- Grupos, alumnos y varios entrenadores por academia.
- Programación compartida y métricas agregadas.

La posibilidad futura de academias influye en la separación entre identidad,
relaciones y organizaciones, pero no autoriza a implementar multi-tenancy antes
de necesitarlo.

## Fuera del camino crítico del MVP

- Resolver todas las oposiciones a la vez.
- Integraciones externas antes de disponer de una sesión activa sólida.
- Algoritmos opacos o aprendizaje automático antes de validar reglas
  deterministas.
- Arquitectura preventiva para funcionalidades todavía indefinidas.

## Regla de ejecución

Cada fase debe entregar un recorrido utilizable y probado. No se abrirán varias
áreas grandes a la vez ni se considerará terminada una funcionalidad porque
existan sus capas si el usuario todavía no puede completar el caso de uso.
