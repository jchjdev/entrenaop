# Contrato deportivo de fuerza y rendimiento · v1

**Contrato ampliado STR-021, 04/10/2026:** entradas explícitas, estímulos,
formatos cortos, cobertura, publicación mixta y feedback por familia se concretan
en [MOTOR_FUERZA_RENDIMIENTO_V2.md](MOTOR_FUERZA_RENDIMIENTO_V2.md), que prevalece
sobre las limitaciones de implementación v1 descritas en este documento.

Fecha: 03/10/2026. **Estado vigente STR-017:** motor de servidor, coordinación,
publicación y resultados del deportista implementados en desarrollo. El catálogo
v1 conserva 63 variantes; v2 añade el circuito de 16 m con pelota. Reglas,
recorrido, verificación y límites actuales en
[MOTOR_FUERZA_RENDIMIENTO_V1.md](MOTOR_FUERZA_RENDIMIENTO_V1.md).

**STR-019, 04/10/2026:** la sesión real revisada detecta límites deportivos de
esa integración. Sigue pendiente seleccionar estímulos y dosificar desde
capacidad, descomponer circuito y programar su evolución. Las referencias
actuales no distinguen expresamente máximo, serie submáxima y dosis repetible.
El banco externo de 40 propuestas recibido queda conservado y revisado en
[MODELOS_PROGRESION_FUERZA_RENDIMIENTO_V1.md](MODELOS_PROGRESION_FUERZA_RENDIMIENTO_V1.md).
No atribuir a STR-017 el cierre de ese banco ni considerar aprobadas sus dosis.

Los apartados que identifican STR-007/010/012/013/016 describen entregas
anteriores de diseño y laboratorio. Sus menciones a trabajo pendiente no
sustituyen el estado operativo de STR-017. Se conservan los criterios deportivos,
la revisión de evidencia y el alcance independiente de cámara (STR-015).

## Alcance acordado

Javier aporta una revisión amplia de fuerza/rendimiento y unas pautas finales
para construir la base antes de la programación adaptativa. Se conserva su
alcance completo: fuerza máxima/relativa, resistencia muscular, repeticiones
en ventana temporal, isométricos, cuerda, potencia, reactividad, cambio de
dirección, agilidad y circuitos. Flexiones, dominadas e isométricos constituyen
la entrada recomendada al algoritmo posterior, no una retirada del resto.

Javier reafirma que el motor será general y podrá funcionar sin oposición,
programa o prueba oficial. Recibirá objetivos de entrenamiento, capacidades y
contexto pertinentes; un adaptador de evaluación podrá aportar una referencia
comparable cuando exista. El enlace CNP es un consumidor opcional de las
definiciones, no una dependencia del dominio ni un requisito de disponibilidad.

Esto no convierte las propuestas de EntrenaOP en planes genéricos de condición
física. Javier precisa que, dentro de una preparación, sus pruebas pautadas
dirigen los objetivos y la prioridad de selección. El adaptador del programa
debe aportar esos objetivos y sus condiciones deportivas, además de referencias
cuando existan. La independencia del núcleo significa desconocer nombres de
oposiciones y baremos, no ignorar qué rendimiento se quiere mejorar.

Las pautas son la guía de requisitos. Las matizaciones distinguen evidencia,
decisiones editoriales y reglas pendientes. La arquitectura reutiliza ejercicios,
sesiones, ejecuciones, agenda y baremos existentes. La interfaz puede presentar
«Fuerza y rendimiento»; el nombre todavía no se ha cambiado en la aplicación.

Esta entrega contiene:

- Este contrato, con semántica de medición y fronteras de integración.
- Un catálogo editorial de 63 variantes en
  `supabase/catalogs/strength_exercises_v1.json`, revisable y versionado en Git.
- Entidades y validación de dominio comunes en
  `packages/workout_core/lib/strength_exercise_catalog.dart`, independientes de
  Flutter y Supabase; adaptación JSON en `strength_exercise_catalog_codec.dart`.
- Persistencia versionada en Supabase de desarrollo, lectura desde ambas apps
  y las 63 variantes como ejercicios públicos de EntrenaOP. Dos pruebas del
  borrador CNP tienen además una asociación opcional a esas definiciones.
- Casos de contrato que verifican las combinaciones necesarias sin atribuir al
  ejecutor soporte que todavía no tiene.

El JSON es la entrada editorial del seed de servidor. No se incluye como asset
de Flutter ni como segundo catálogo operativo. Supabase conserva las 63
definiciones y sus versiones; cada una tiene su ejercicio oficial público.
La primera entrega dejó 60 entradas pendientes por una restricción de alcance
incorrecta, corregida tras la observación de Javier mediante una migración
posterior. Las clasificaciones siguen siendo editoriales; la visibilidad de un
ejercicio no acredita soporte de todos sus modos de registro.

## Fronteras y fuente de verdad

| Concepto | Significado y frontera |
| --- | --- |
| Ejercicio/variante | Movimiento y condiciones estructurales: agarre, aparato, apoyos, unilateralidad. No fija objetivo ni intensidad. |
| Familia | Agrupa variantes relacionadas; no declara equivalencia de resultados ni una escalera universal de dificultad. |
| Objetivo | Resultado que se busca mejorar; puede exigir varias capacidades y combinar varios estímulos. |
| Adaptación/intención | Finalidad de una prescripción concreta: fuerza, resistencia local, soporte muscular, potencia, habilidad, etc. |
| Prescripción | Lo previsto para ese día, conservado en una versión e instantánea. |
| Resultado | Lo realmente declarado/medido, incluida su validez y procedencia. No se copia como hecho por existir una prescripción. |
| Protocolo | Define tarea, medida, condiciones y criterios de validez/comparabilidad. |
| Baremo | Convierte la marca válida en aptitud o puntos de un programa y versión. Sigue en los almacenes actuales. |

La marca medida, el protocolo y la fecha alimentarán el entrenamiento. Los
puntos no se convierten en kilos, repeticiones o dosis. Se conservan EVAL-001,
EVAL-002 y la frontera específica de tests FAS. No se impone una batería
general obligatoria ni se trasladan marcas de otro programa automáticamente.

## Selección orientada a objetivos

**Criterio confirmado; política e implementación pendientes.** La entrada del
selector serán objetivos deportivos concretos: tarea/variante, medición y
condiciones del protocolo, rendimiento buscado y contexto disponible. Las
pruebas de la preparación activa aportan estos objetivos mediante adaptadores;
un plan de mejora de repeticiones de dominadas o de 1RM de banca puede aportar
la misma entrada sin programa oficial. Repeticiones máximas y carga máxima son
objetivos distintos, aunque compartan ejercicio.

El catálogo actual de 63 variantes expresa capacidades y restricciones; no
contiene todavía una política de pertinencia a objetivos. El vínculo de una
prueba con su variante tampoco declara todos los ejercicios auxiliares útiles.
Compartir músculos, patrón o familia sirve como información, pero no acredita
transferencia ni justifica automáticamente una selección.

Se propone una relación versionada **objetivo–variante**, independiente de la
identidad del programa, con función, motivo, condiciones de uso y procedencia
de la revisión. Las funciones propuestas para la primera matriz son:

| Función propuesta | Criterio de selección | Ejemplo ilustrativo para mejorar flexiones |
| --- | --- | --- |
| Trabajo específico | Practica la tarea pertinente y sus condiciones, sin exigir que cada sesión sea un test máximo. | Flexión compatible con apoyo, ROM y conteo de la prueba. |
| Trabajo de apoyo | Desarrolla una capacidad pertinente o permite practicar una regresión/progresión con una justificación revisada. | Flexión inclinada si necesita una variante accesible; banca o flexión lastrada si encajan con el objetivo y su contexto. |
| Complemento | Aporta trabajo adicional justificado, subordinado al tiempo y carga necesarios para los objetivos principales. | Dominadas como complemento cuando no son otra prueba prioritaria de esa preparación. |

Estas funciones dependen del objetivo y la prescripción, no son una propiedad
universal del ejercicio. Si el plan también exige dominadas, ese ejercicio
pasa a tener un objetivo propio prioritario. Una exposición que sirve a varios
objetivos se cuenta una vez en la coordinación semanal de PLAN-001.

La selección propuesta filtrará primero material, accesibilidad y restricciones;
después resolverá pertinencia y prioridad entre objetivos según el contexto.
Un mínimo eliminatorio no alcanzado, una prueba ya solvente y la proximidad al
examen pueden requerir prioridades diferentes, conservando el mantenimiento
pertinente y el encaje con carrera. No se comparan directamente segundos,
repeticiones o kilos entre pruebas, ni se convierten puntos en dosis.

Un resultado aislado no identifica por sí solo la capacidad limitante. No se
asignarán porcentajes inventados de transferencia ni cuotas universales de
complementos. Si falta la relación revisada de un objetivo, se declara esa
limitación en lugar de generar una sesión genérica haciéndola pasar por
preparación específica.

El siguiente trabajo deportivo recomendado es revisar la primera matriz para
flexiones, dominadas, suspensión y banca, junto al contrato de prescripción y
resultados. La taxonomía, dosis y prioridades concretas permanecen propuestas,
no reglas ya ejecutadas por el algoritmo.

## Autoría en ADMIN y políticas deportivas

**Reparto general confirmado; detalle e implementación pendientes (STR-005).**
Javier respalda conservar la creación en ADMIN y reutilizar estrategias
deportivas, tras solicitar ejemplos para resolver quién configura los planes y
quién decide los ejercicios. Se ha contrastado el panel existente: permite definir
pruebas, protocolos, baremos e intentos y vincular una carrera compatible al
módulo de 2 km. Todavía no ofrece seleccionar objetivos de fuerza ni revisar
una propuesta conjunta de fuerza/carrera.

El reparto acordado mantiene la autoría en ADMIN. Su concreción propuesta es:

| Responsable | Configuración o decisión propuesta |
| --- | --- |
| ADMIN del programa | Pruebas, condiciones normativas, baremos y mínimos; objetivo deportivo reconocido para cada prueba y condiciones estructuradas pertinentes. Preferencias o exclusiones opcionales, sometidas a compatibilidad. |
| Biblioteca de políticas deportivas | Relaciones revisadas objetivo–variante, trabajo específico/apoyo/complementos, condiciones de selección, reglas de dosis/progresión y límites. Reutilizables por programas compatibles y versionadas. |
| Motor para el deportista | Elección concreta de variantes y dosis según objetivos activos, resultados comparables, disponibilidad, material, experiencia y restricciones. Explicación de la propuesta. |
| Coordinador semanal común | Encaje de las propuestas de fuerza y carrera en una sola agenda y presupuesto de tiempo/carga, sin duplicar exposiciones que sirven a varios objetivos. |

La experiencia propuesta en ADMIN es «Cómo se prepara esta prueba»: seleccionar
por ejemplo «Mejorar repeticiones de flexiones», confirmar la variante y, cuando
proceda, ventana temporal, agarre o condiciones del protocolo. Se ofrece una
base deportiva recomendada y un ajuste avanzado opcional de preferencias;
no se exige escoger las 63 variantes ni fijar la dosis individual de todos los
deportistas. Una preferencia no fuerza una variante incompatible o bloqueada.

El nombre de la oposición, el nombre libre de la prueba y su unidad no bastan
para deducir el objetivo. Los datos estructurados compatibles pueden sugerirlo,
pero ADMIN debe confirmar la correspondencia deportiva. Carrera en segundos
y suspensión en segundos no comparten política; distintos tipos de flexiones
o dominadas no se equiparan únicamente por familia.

Crear otra oposición con objetivos/protocolos ya cubiertos no requiere código
nuevo. Incorporar una tarea o capacidad no soportada requiere añadir y revisar
su política deportiva: no se promete interpretar cualquier prueba arbitraria.
El panel indicará qué pruebas tienen cobertura automática y cuáles no.
Publicar una evaluación/baremo completo conserva su recorrido actual y no
acredita, por sí solo, cobertura de entrenamiento para todas sus pruebas.
La propuesta no cambia hoy los requisitos de publicación existentes.

Mi papel durante el desarrollo es ayudar a construir y comprobar esas políticas
comunes; la autoría cotidiana de nuevos programas compatibles permanece en
ADMIN. Los planes iniciales pueden cargarse por migración/seed para facilitar
el arranque, sin convertir el código en su único canal de creación.

Referencias públicas consultadas el 03/10/2026:

| Referencia | Comportamiento documentado y alcance de la comparación |
| --- | --- |
| [Fitbod: algoritmo](https://fitbod.me/blog/fitbod-algorithm/) | Expone componentes separados para selección de ejercicios y recomendación de series/repeticiones/carga, con adecuación a objetivos y equipo. Sirve como referencia de responsabilidades; sus porcentajes de recuperación o afirmaciones de eficacia no son reglas adoptadas por EntrenaOP. |
| [Fitbod: Focus Exercises](https://help.fitbod.me/hc/en-us/articles/35301260960663-Focus-Exercises) | Permite mantener y sustituir ejercicios principales mientras adapta apoyos. Referencia para preferencias controladas y continuidad, sin adoptar su ciclo o frecuencia. |
| [TrainerRoad: Plan Builder](https://support.trainerroad.com/hc/trainerroad-support/articles/360037923191-plan-builder-overview) | Configura objetivos/eventos, prioridades, historial y agenda; ofrece revisión antes de incorporar la propuesta al calendario. Referencia de configuración estructurada y vista previa. |
| [Runna: fuerza junto a carrera](https://support.runna.com/en/articles/15624879-adding-strength-training-to-your-runna-plan) | Configura objetivo/material y sesiones de fuerza junto a las carreras. Su documentación indica que la fuerza no influye en la adaptación de carrera. Mostrar ambas en un calendario no acredita coordinación de carga entre motores. |

Estas fuentes describen productos, no permiten auditar sus algoritmos ni
demuestran cuál es superior para oposiciones. El modelo de responsabilidades
anterior desarrolla el criterio de EntrenaOP; no es una implementación copiada
ni acredita que el nuevo flujo de ADMIN ya exista.

## Núcleo común, políticas específicas y personalización

STR-005 y STR-006 orientan el diseño futuro. «Minimotores» puede servir como
explicación informal de las políticas especializadas, pero no implica sistemas
independientes ni un motor nuevo por oposición o ejercicio.

El núcleo común conservará el contexto del deportista, referencias comparables,
historial de prescripción/ejecución, restricciones y trazabilidad. Las políticas
deportivas decidirán estímulos, variantes y progresión pertinentes a cada
objetivo. Un objetivo de dominadas máximas puede necesitar trabajo específico,
fuerza y resistencia; no queda reducido a una sola capacidad fisiológica.
Repeticiones máximas, repeticiones en una ventana y carga máxima pueden compartir
movimiento y requerir políticas distintas. Los límites concretos entre políticas
y su contrato común todavía deben especificarse.

El coordinador semanal resolverá agenda, prioridades y exposiciones compartidas
entre propuestas de fuerza y carrera. Tendrá que poder pedir que una propuesta
se reduzca, desplace o vuelva a generar; sumar dos calendarios ya cerrados no
resuelve esa interacción. No se sumarán kilos, repeticiones y kilómetros como
una medida universal de fatiga ni se presentará un porcentaje ficticio de
recuperación. Carrera conserva por ahora su cobertura real de 2 km; el
coordinador y las políticas de fuerza aún no están implementados.

Javier destaca la personalización como valor central de la suscripción. La
misma preparación no obliga a recibir la misma rutina. Capacidad, material,
tiempo y respuesta distintos pueden cambiar variante, dosis, frecuencia o
progresión, conservando objetivo y protocolo. Si el contexto es equivalente,
una prescripción idéntica puede ser correcta. No se cambiarán ejercicios al
azar para que dos clientes vean diferencias, ni para prometer exclusividad.

Ejemplo conceptual, sin dosis aprobadas: una persona sin dominadas válidas
podría necesitar una variante asistida accesible y aprendizaje del patrón;
otra con un historial sólido de repeticiones podría necesitar otra combinación
de fuerza y volumen específico. Una marca aislada no diagnostica el factor
limitante. Compartir la captura de una semana tampoco comparte la adaptación
posterior basada en resultados propios.

La arquitectura mantiene el dominio deportivo separado de Flutter, ADMIN y
Supabase. Se reutilizan ejecutor, agenda y contratos existentes; estas
responsabilidades no obligan a crear servicios, paquetes o capas nuevas.

La primera simulación está especificada en
[`ESTRATEGIA_FLEXIONES_V1.md`](ESTRATEGIA_FLEXIONES_V1.md). Reutiliza el
catálogo real y permite revisar selección, dosis y respuesta en ADMIN. Sus
constantes y protocolos de laboratorio no son reglas deportivas aprobadas ni
protocolo oficial. Los doce recorridos y la integración de servidor siguen
siendo requisitos antes de activar planes de fuerza para deportistas.

## Preparación guiada y reparto automático

**Criterio solicitado por Javier; flujo propuesto, sin implementación nueva
(STR-008).** El formulario largo del laboratorio no es el diseño del recorrido
del deportista. Se mantiene EVAL-012: una entrada visible dentro de la preparación,
compuesta por pasos breves reutilizables según objetivos y protocolos reconocidos.
La interfaz no decide pertinencia deportiva interpretando nombres libres.

La propuesta principal es:

| Paso | Contenido y condiciones |
| --- | --- |
| Tu preparación | Pruebas pertinentes y fecha objetivo, si existe; cobertura real del entrenamiento. El programa aporta protocolos y baremos, no se pide al deportista redefinirlos. |
| Tu semana | Días y tiempo total disponibles, material, experiencia, actividad reciente y limitaciones actuales. Bloques breves cuando sea necesario; no repetir disponibilidad por disciplina. |
| Carrera, si procede | Referencia compatible elegida expresamente, fecha y continuidad; carga reciente pertinente. Respetar RUN-001/005 y el límite actual de 2 km. |
| Flexiones, si procede | Práctica reciente, variante/montaje y referencia de trabajo comparable con esfuerzo declarado cuando lo requiera la política. La marca máxima de examen no se sustituye por esa serie ni viceversa. |
| Otros objetivos, cuando tengan soporte | Preguntas propias de suspensión, plancha, dominadas o circuito según protocolo. Un circuito predefinido no equivale automáticamente a agilidad reactiva. Una pantalla de captura no acredita política de prescripción. |
| Revisión | Datos confirmados, pendientes y cobertura; cuando exista coordinación operativa, propuesta semanal con sesiones completas, duración estimada y motivos de selección. |

Los pasos exactos dependen de los datos que faltan y del contexto. Se muestra
progreso sobre los pasos pertinentes, se conserva lo introducido al retroceder
y se valida cada bloque. Un antecedente compatible se ofrece con fecha y origen
para confirmación; no se copia como resultado actual ni se traslada entre
programas saltándose EVAL-002/003. No se fuerza un test adicional solo para
rellenar una pantalla. «No lo sé» deja información pendiente y activa una vía
de calibración revisada; no inventa marcas ni esfuerzo.

La captura de marcas puede continuar para pruebas sin cobertura automática,
conservando la evaluación existente. Debe explicarse que su entrenamiento aún
no se puede generar. La experiencia final no contiene respuestas simuladas,
versiones internas de política ni un «laboratorio» por disciplina.

### Disponibilidad, sesiones y coordinación

El usuario comunica el tiempo total real por día. La reserva manual del
laboratorio es una entrada de simulación: no se convierte en el mecanismo
ordinario para repartir carrera, flexiones u otras tareas de EntrenaOP.
La planificación común recibe propuestas especializadas y decide su encaje
semanal y, cuando proceda, su composición dentro de una sesión. Carrera no
asume la responsabilidad de dosificar fuerza ni de dirigir el conjunto.

El cálculo incluye calentamiento pertinente, trabajo, descansos, transiciones
y cierre, distinguiendo estimaciones de duración medida. Un calentamiento puede
tener una parte común y preparación específica posterior: no se duplica entero
por cada módulo ni se elimina sin revisar su pertinencia. También se comprueban
recuperación, solapamientos y prioridades. Que dos bloques quepan en sesenta
minutos no demuestra que deban hacerse juntos ni que se toleren.

El tiempo disponible es un límite, no una obligación de llenarlo. Cuando no
quepa una propuesta adecuada, se debe reducir lo modificable, reubicar o
explicar el conflicto; no recortar arbitrariamente descansos ni eliminar una
prueba prioritaria en silencio. La actividad externa, como un entrenamiento
con otro preparador, se declara con contexto: reservar minutos por sí solo no
representa su carga. Los criterios deportivos concretos siguen pendientes.

### Modularidad y grupos de ejercicios

Se separan tres responsabilidades: componentes de preguntas en presentación,
políticas deportivas en dominio y coordinación común de propuestas. Una
pregunta reutilizable no es un algoritmo nuevo. Sustituir un paso visual no
autoriza sustituir una tarea por otra incompatible. Los adaptadores de datos
conservarán protocolo, procedencia y versión; no se modifica hoy el esquema
existente de contextos de carrera para darlo por un contexto común terminado.

Los grupos de trabajo se organizan alrededor de un objetivo y de las funciones
específico/apoyo/complemento de STR-004. Para flexiones, la variante estándar
compatible puede ser práctica específica y la inclinada un apoyo accesible
calibrado. La altura y montaje importan; sus repeticiones no equivalen a la
marca estándar. Banca, lastradas u otros apoyos exigen justificar selección y
dosificación; no entran por compartir pectoral/tríceps. Cada persona recibe
los elementos pertinentes del grupo, no el grupo completo por defecto.

### Referencias de interfaz y límites de la comparación

El 03/10/2026 se revisaron capturas distribuidas a lo largo de los dos vídeos
aportados por Javier. Kotcha separa carga habitual, referencia, tipo de objetivo,
fecha y propuesta; Calisteniapp muestra progreso segmentado, días, fecha y
resumen de programa. Se usan como referencias de recorrido, no como evidencia
de sus fórmulas, de sus mensajes de cálculo ni de su eficacia.

[Freeletics](https://help.freeletics.com/hc/en-us/articles/115004675229-Get-started-with-Freeletics-Training)
documenta preguntas iniciales de días/material/preferencias y ajuste por respuesta.
[Runna](https://support.runna.com/en/articles/15624879-adding-strength-training-to-your-runna-plan)
documenta configuración separada de fuerza y su presencia en el calendario,
pero señala que no influye en la adaptación de carrera.
[Kotcha](https://www.kotcha.com/en) anuncia preparación de fuerza integrada;
esa descripción comercial no permite comprobar cómo coordina su carga.
Estas referencias orientan UX y responsabilidades, no establecen una solución
deportiva universal ni permiten atribuir acceso a proyectos privados ajenos.

La [revisión cinética de variantes de flexiones](https://pubmed.ncbi.nlm.nih.gov/30284496/)
describe características e intensidades distintas entre variantes; sus autores
limitan expresamente la inferencia sobre consecuencias prácticas. Sirve para
exigir condiciones de variante y montaje, no para aprobar una matriz de
transferencia o una progresión individual universal.

STR-009 corrige la concreción del siguiente tramo: la entrada compartida,
estados de cobertura/calibración y contrato de coordinación se diseñan para
todo el alcance deportivo desde ahora. Carrera/flexiones sirven para contrastar
una integración ejecutable, sin condicionar a ellas la representación del resto.
La activación sigue requiriendo revisión y pruebas de cada política; un formulario
de plancha o circuito no acredita dosis ni entrenamiento ya implementados.

## Cobertura completa y contrato entre módulos

**Alcance reafirmado por Javier (STR-009); detalle propuesto.** El avance se
organiza por bloques completos de preguntas relacionadas, no por una pantalla
nueva después de cada respuesta. Carrera conserva su agrupación como referencia;
empujes, tirones, isométricos, cuerda y las demás tareas se presentan cuando
son pertinentes. Disponibilidad/material generales se preguntan una vez.
Los bloques concretos pueden ajustarse a los datos necesarios y tamaño de
pantalla; no se exige una página sin desplazamiento a costa de perder claridad
o accesibilidad. Atrás/Continuar conservan lo introducido.

Javier aclara que carrera puede evolucionar para coordinarse con el resto,
sin perder lo construido por modificaciones incidentales. Se preserva como
base su comportamiento comprobado: cuestionario, reglas de cálculo,
referencias, publicación y recorrido. La modularidad del resto no exige
reescribir carrera ni uniformar sus pantallas. Su participación se diseña mediante una
frontera explícita con las entradas/propuestas existentes; no se modifica hoy
su contrato ni se sustituye su agenda por la nueva coordinación.
Si coordinar propuestas reales requiere cambiar el comportamiento de carrera,
se explicará el impacto y se acordará expresamente antes de aplicar ese cambio.
La fase de diseño o simulación conjunta no autoriza alterar sesiones publicadas
ni acredita integración operativa. Se exigirán las regresiones pertinentes de
carrera cuando se implemente esa frontera. Esta protección no congela el
algoritmo ni impide una evolución acordada, versionada y comprobada.

Un módulo deportivo reúne una capacidad de preparación reconocida, sus
necesidades de información, calibración, selección y adaptación. Su pantalla
pertenece a presentación, la captura/lectura a aplicación/datos y sus reglas
deportivas a dominio. No es un conjunto de algoritmos ajenos entre sí ni un
motor por oposición. Los grupos visuales no determinan por sí solos la política:
flexiones máximas, flexiones cronometradas y 1RM de banca necesitan objetivos
y reglas diferentes aunque aparezcan dentro de empujes.

### Matriz general de diseño

La matriz cubre las capacidades del catálogo completo; no convierte todos los
ejercicios auxiliares en pruebas obligatorias. La última columna expresa el
estado comprobado, no una promesa de cálculo actual.

| Bloque/capacidad | Datos particulares que debe conservar | Propuesta específica esperada | Estado operativo actual |
| --- | --- | --- | --- |
| Carrera | Distancia/protocolo, referencia y fecha, continuidad, carga reciente y experiencia | Tipo de carrera, duración/dosis, intensidad y alternativas compatibles | Motor de 2 km existente; otras distancias y coordinación conjunta pendientes |
| Empujes por repeticiones | Variante, estándar técnico, referencia de trabajo; ventana temporal/carga cuando procedan | Práctica específica, apoyo calibrado y adaptación de dosis | Solo flexiones estándar sin ventana en laboratorio experimental |
| Tirones por repeticiones | Agarre, ROM, asistencia/lastre separados y referencias comparables | Dominadas pertinentes y apoyos seleccionados por capacidad/material | Biblioteca disponible; política adaptativa pendiente |
| Isométricos | Posición, agarre/apoyo, criterio de finalización, duración válida y práctica reciente | Duración/series/recuperación y apoyos pertinentes a esa tarea | Plancha, suspensión y agarre en biblioteca; política adaptativa pendiente |
| Fuerza con carga | Ejercicio, carga, repeticiones válidas, esfuerzo de trabajo y experiencia; intentos válidos/nulos para RM | Selección y dosis con carga para el objetivo, distinguiendo entrenamiento y test de RM | Biblioteca y registro convencional existentes; política adaptativa de fuerza pendiente |
| Cuerda | Altura/distancia, técnica, uso permitido de piernas, éxito/tiempo, acceso al montaje y experiencia | Práctica de trepa y apoyos pertinentes; alternativas cuando falte material | Biblioteca disponible; política adaptativa pendiente |
| Transportes | Aparato, carga, distancia/duración, recorrido y condición de parada | Dosis y apoyos pertinentes al objetivo de transporte | Biblioteca disponible; representación específica y política pendientes |
| Saltos y lanzamientos | Tarea, técnica, altura/distancia medida, intentos/validez y experiencia | Práctica específica y apoyos; conservar calidad y condiciones comparables | Biblioteca disponible; registro específico y política pendientes |
| Potencia y trabajo reactivo | Tarea, experiencia/tolerancia, calidad de ejecución; contacto/altura solo con instrumentos/protocolo pertinentes | Exposiciones adecuadas a esa tarea, criterio de parada y apoyos | Biblioteca disponible; política pendiente; no se infieren vatios ni métricas no medidas |
| Circuito y cambio de dirección predefinido | Trazado, obstáculos, distancias, reglas, tiempo/nulos y técnica | Práctica del recorrido y componentes pertinentes | Biblioteca genérica disponible; adaptación al circuito oficial y política pendientes |
| Agilidad reactiva | Señal externa, decisión, recorrido, condiciones, validez y medición | Práctica con estímulo/decisión pertinentes y apoyos | Biblioteca disponible; política y registro específicos pendientes |

Una misma variante puede participar en varios objetivos; no se crean copias
de su historial para cada módulo. Fuerza con carga puede compartir preguntas
con empujes/tirones: un objetivo se presenta una vez y conserva su identidad.
No se fuerza al usuario a contestar todos los bloques de la matriz.

Si la preparación no exige cuerda, no se añade un bloque de cuerda por existir
en el catálogo. Una estrategia sí puede necesitar un dato de un apoyo para su
objetivo: por ejemplo, una calibración de tracción pertinente a trepa. Lo pide
con motivo y reutiliza el dato comparable existente; no convierte dominadas en
otra prueba oficial ni exige una batería general. Esto mantiene especificidad
y permite apoyo sin limitarse a reproducir las pruebas del examen.

### Intercambio común propuesto

| Frontera | Contenido |
| --- | --- |
| Programa → objetivos | Tarea/protocolo/versiones, condiciones, prioridad deportiva y capacidad reconocida. ADMIN confirma la correspondencia; los puntos conservan su baremo separado. |
| Contexto → módulos | Disponibilidad común, material, salud/restricciones, experiencia/práctica reciente pertinente, referencias y ejecuciones con fecha/procedencia. No todos los módulos consumen todos los datos. |
| Módulo → coordinación | Estado de cobertura, datos o calibración pendientes; propuestas de trabajo con finalidad, dosis, identidad/versiones, duración estimada, restricciones y alternativas permitidas. Motivos explicables. |
| Coordinación → módulos | Petición de alternativa o revisión dentro del margen permitido cuando existe conflicto de tiempo, prioridades o recuperación. No modifica arbitrariamente las reglas de dosis. |
| Coordinación → agenda | Una propuesta semanal conjunta con composición/orden de sesiones, estimaciones completas, exposiciones compartidas contadas una vez y conflictos explícitos. |
| Ejecución → adaptación | Resultados reales comparables con su prescripción/versiones, validez, esfuerzo cuando proceda y motivo de interrupción. Un dato ausente no se inventa. |

Los estados comunes de diseño son falta de datos, falta de calibración,
bloqueo por restricción, capacidad sin cobertura, propuesta disponible y
conflicto de agenda. No publicar un plan conjunto aparentemente completo
omitiendo objetivos sin cobertura. La decisión de coordinación debe conservar
versiones, alternativas elegidas y motivos, para permitir auditoría y anulación
por entrenador. Las reglas concretas de recuperación aún requieren revisión;
no se deducen sumando kilos/repeticiones/kilómetros ni asignando porcentajes
inventados de fatiga.

Las reglas comunes pueden reutilizar validación, comparabilidad, tendencias,
prioridades y disponibilidad. Las decisiones de dosis y técnica permanecen
propias del objetivo. El rango RIR 2–4 del ensayo de flexiones no se aplica
automáticamente a planchas, cuerda, saltos o marcas máximas. La síntesis
[ACSM 2026](https://pubmed.ncbi.nlm.nih.gov/41843416/) distingue adaptaciones y
variables de prescripción; no proporciona un algoritmo universal para todas
las pruebas de oposiciones ni valida nuestras constantes experimentales.

### Secuencia de implementación recomendada

Se define primero el contrato común para todas estas capacidades y se contrasta
con los doce recorridos de medición existentes; después se conecta a bloques
de captura pertinentes, con cobertura real visible. Las estrategias se revisan
y activan por capacidad usando ese mismo contrato y el coordinador, sin
rediseñarlo al añadir plancha o cuerda. Carrera/flexiones son casos de integración
disponibles, no una etapa que deba quedar «perfecta» para poder diseñar el resto.
La publicación conjunta exige el contrato ejecutable, cobertura comprobada
y revisión deportiva de las políticas que participen.

### Contrato ejecutable inicial (STR-010)

`packages/workout_core/lib/performance_training_contract.dart` implementa
la primera frontera en Dart puro. No contiene Flutter, Supabase, acceso a
cuentas o lógica por oposición. Reutiliza `StrengthTask` como identidad
versionada de tarea; su nombre histórico no limita las mediciones representadas.

- Objetivo: identidad, capacidad deportiva explícita, tarea/protocolo/montaje,
  medición/carga y bloque de preguntas. Un bloque no determina la dosis.
- Pendientes: claves de datos comunes o referencia de una tarea concreta,
  conservando motivos y sin mezclar protocolos por tener igual nombre de campo.
- Propuesta: versión/estado de política, estado de cobertura, motivos y trabajo
  tipado por la estrategia. No se imponen repeticiones/RIR a las demás tareas.
- Revisión conjunta: conserva todos los objetivos y genera un pendiente visible
  cuando falta su propuesta. Rechaza duplicados, cambios de protocolo y trabajo
  compartido contradictorio; una identidad de trabajo común se cuenta una vez.
- Agrupación: devuelve los bloques pertinentes en el orden de los objetivos,
  sin repetirlos. No interpreta nombres libres ni selecciona apoyos por músculos.

Las combinaciones del catálogo se comprueban para sus 63 variantes; esto no
crea políticas adaptativas para ellas. Se verifica además estructura pertinente
en isometría, transporte, cuerda, salto/lanzamiento y recorrido fijo/reactivo;
esas comprobaciones no declaran transferencia deportiva ni dosis aprobadas.
Carrera conserva biblioteca/motor propios: puede representarse como objetivo,
pero este tramo no conecta ni sustituye su planificador existente.

`push_up_performance_proposal.dart` adapta la decisión del ensayo de flexiones.
Conserva prescripción, tarea, versión, estimación y días propuestos; no altera
las constantes ni afirma que esos días estén coordinados con otras disciplinas.
Un trabajo sin ventana temporal no se presenta como cobertura de flexiones
cronometradas. ADMIN usa esta misma frontera y muestra cuántos objetivos tienen
propuesta para revisión; las entradas siguen siendo ficticias.

`readyForReview` y `allGoalsReadyForReview` significan cobertura de propuestas
para inspección, no autorización de publicación, coordinación completada ni
eficacia deportiva. Las políticas experimentales mantienen su etiqueta.
Faltan contexto/resultados generales tipados, preferencias/restricciones y
alternativas de dosis para la coordinación, codec/persistencia de decisiones,
vínculos ADMIN y recorrido de bloques. El contrato no es aún un motor semanal
ni amplía las mediciones del ejecutor. La seguridad y activación operativa
seguirán comprobándose en servidor, nunca mediante estas etiquetas del cliente.

Verificación de este tramo el 03/10/2026: batería completa del deportista,
292 pruebas, y ADMIN con los contratos compartidos, 73 pruebas, correctas.
Incluye conservación de dosis del ensayo, cobertura incompleta visible,
protocolos/cargas incompatibles y deduplicación de trabajo compartido.
No se modifican funciones SQL ni archivos del motor/recorrido de carrera.

## Texto teórico adicional: lectura y límites

El 03/10/2026 Javier aporta «Base teórica de entrenamiento de fuerza y
rendimiento de EntrenaOP». Se ha leído completo, junto al alcance de los textos
iniciales. Es material de trabajo deportivo; no una orden de implementar todas
sus afirmaciones literalmente. Sus marcadores `chatgpt-content-reference` no
incluyen bibliografía resoluble en el archivo. Se han contrastado las fuentes
centrales siguientes, sin dar por verificadas todas las referencias ausentes.

| Principio del texto | Consecuencia para especificar las políticas |
| --- | --- |
| Especificidad y técnica | Priorizar tarea y protocolo relevantes; conservar criterios de repetición/posición válida. No tratar un ejercicio auxiliar como sustituto equivalente. |
| Adaptaciones distintas | Separar fuerza máxima, resistencia, isometría, potencia, reactividad y habilidad. Hipertrofia y fuerza relativa pueden ser apoyos; no inferir falta de masa muscular a partir de una marca. |
| Sobrecarga progresiva | Elegir el cambio pertinente y comprobar tolerancia/calidad. Mantener o reducir puede ser adecuado; no aumentar todas las variables cada semana. |
| Esfuerzo y fallo | Distinguir calentamiento, técnica y trabajo principal; no imponer fallo ni un RIR común a toda tarea. No extrapolar umbrales de hipertrofia a resistencia muscular. |
| Isometría y explosividad | Usar posición/duración o calidad/velocidad cuando corresponda. Sin dispositivo o dato declarado no se inventan velocidad, RFD ni contacto. |
| Volumen, frecuencia, descanso y orden | Distribuir trabajo suficiente y preservar la calidad prioritaria; el cansancio no prueba eficacia. Considerar solapamientos sin declarar una equivalencia fisiológica fija de series indirectas. |
| ROM, tempo y variación | Definir condiciones comparables y finalidad de la variante. Cambiar ROM/agarre o tarea puede exigir una referencia distinta; variar no equivale automáticamente a progresar. |
| Fatiga, descargas y periodización | Observar tendencias y contexto; evitar descargas de calendario obligatorias o diagnosticar sobreentrenamiento. Una sesión adversa puede justificar ajuste inmediato sin declarar pérdida duradera de capacidad. |
| Entrenamiento concurrente | Coordinar prioridades, tiempo y exposiciones de todas las pruebas; una sesión que apoya varios objetivos no se cuenta varias veces. |
| Tests y adaptación | Diferenciar medición máxima y entrenamiento habitual. La respuesta real y su procedencia alimentan la revisión; una meta prescrita no acredita resultado. |

La [síntesis ACSM 2026](https://pubmed.ncbi.nlm.nih.gov/41843416/) respalda
prescripciones diferentes para fuerza, hipertrofia y potencia. Sus rangos y
frecuencias describen resultados agregados en adultos sanos: no son mínimos
obligatorios para todo opositor ni una dosis individual ya resuelta.

La [metarregresión de proximidad al fallo](https://link.springer.com/article/10.1007/s40279-024-02069-2)
encuentra una asociación distinta para hipertrofia y fuerza. Estima RIR a partir
de descripciones de estudios y sus modelos son exploratorios. No fija un RIR
óptimo universal ni valida «8–10 RIR» como umbral para resistencia muscular.
La [revisión de fallo/no fallo de 2026](https://pubmed.ncbi.nlm.nih.gov/42410632/)
encuentra una pequeña ventaja para fuerza dinámica sin fallo y ninguna
diferencia estadísticamente significativa en los otros resultados analizados;
esto no demuestra equivalencia para todas las dosis y poblaciones.

La [revisión de precisión del RIR](https://pubmed.ncbi.nlm.nih.gov/34542869/)
respalda tratarlo como estimación imperfecta. En su análisis, la experiencia de
entrenamiento no explicó de forma clara la precisión: no se asignará confianza
alta automáticamente a usuarios avanzados, ni se afirmará que la imprecisión
pertenece solo a principiantes.

La [revisión concurrente de 2026](https://pubmed.ncbi.nlm.nih.gov/41762427/)
apoya la compatibilidad de fuerza y resistencia en numerosos contextos,
especialmente recreativos; señala escasez de datos en deportistas de alto nivel.
No garantiza ausencia de interferencia ni establece el calendario individual
óptimo. Las reglas de coordinación concretas seguirán requiriendo revisión.

Cada política futura deberá expresar objetivo y protocolo, evidencia y límites,
ejercicios pertinentes y condiciones, dosis inicial, señales para progresar,
mantener/reducir o pedir datos, y relación con las demás pruebas. Los números
elegidos como hipótesis de producto se identificarán y versionarán como tales.
Las pruebas de software acreditarán coherencia y funcionamiento; la mejora
deportiva real requerirá seguimiento de resultados comparables.

## Ejercicio y catálogo

Cada entrada tiene código estable, nombre, familia, patrones, modos de
movimiento, regiones, lateralidad, complejidad técnica, material requerido y
opcional, músculos primarios/secundarios, combinaciones de medición/carga,
ejes posibles de progresión y notas de interpretación.

Los metadatos describen posibilidades. No contienen `fatigue_cost`, un
diagnóstico, porcentajes de contribución muscular o una capacidad objetivo
única fijada por ejercicio. «Primario/secundario» es clasificación editorial
para esta tarea; no representa activación medida ni dosis equivalente.

La clasificación técnica inicial es propuesta editorial. No se deduce de la
antigua columna `difficulty`, ni del nivel declarado por el deportista, ni
decide que alguien avanzado necesite movimientos más complejos.

Un ejercicio personal puede seguir existiendo sin todos estos metadatos. La
falta de información impide seleccionarlo automáticamente hasta su revisión,
pero no su uso manual. El formulario personal actual sigue siendo simple.

### Patrones, modos y regiones

Se conservan todos los patrones solicitados: empujes horizontal/vertical/
diagonal, tirones horizontal/vertical, sentadilla, bisagra, extensión de
cadera, dominante unilateral de rodilla, transporte, cuerda, core, pliometría
vertical/horizontal/lateral, COD y agilidad reactiva. Se añaden flexión de
rodilla, flexión plantar, suspensión de agarre y lanzamiento balístico para
representar curl femoral, gemelos, dead hang y balón sin forzar su categoría.

Los modos son dinámico, isométrico, pliométrico y locomotor. Un ejercicio puede
involucrar varias regiones; estas etiquetas no estiman fatiga. Landmine se
clasifica como empuje diagonal. Un recorrido memorizado es COD; una tarea
reactiva necesita señal externa y decisión verificables en su protocolo.

### Material, carga y variantes

El material utiliza códigos. Todos los elementos requeridos de una entrada
son necesarios; los opcionales no bloquean su versión básica. El catálogo
separa dominada asistida con banda de dominada asistida en máquina, y declara
la variante de material elegida en ejercicios como Pallof o farmer carry.
Más alternativas se añadirán explícitamente, sin tratar aparatos distintos
como equivalentes por compartir un nombre.

Las preferencias actuales (`gym`, `freeWeights`, etc.) son categorías amplias;
no acreditan que exista una cuerda, una máquina o un montaje concreto. Antes
del filtro automático hará falta confirmar el material pertinente.

| Modo de carga | Datos que se deben conservar en la siguiente entrega |
| --- | --- |
| `bodyweight` | Variante y, si es pertinente y está disponible, masa corporal con fecha y procedencia. |
| `external_load` | Valor externo, unidad, aparato y convención: carga total o por implemento/mano. |
| `bodyweight_plus_external` | Lastre externo separado de masa corporal contemporánea. |
| `assisted` | Tipo, configuración e identificación de asistencia; kilos solo si el aparato informa un ajuste numérico interpretable. |

No calcular kilos efectivos de flexiones ni restar la resistencia nominal de
una banda al peso corporal. La carga declarada de una máquina no permite
compararla automáticamente con otra. Una mancuerna de 20 kg en cada mano
debe distinguirse de 20 kg totales. El resultado desconocido permanece nulo.

### Ejes posibles de progresión

Carga, repeticiones, series, duración, asistencia, distancia, densidad,
descanso, velocidad, contacto, altura de cajón, complejidad, ROM, palanca,
especificidad y técnica. Son dimensiones disponibles, no instrucciones para
aumentarlas. Algunas mejoras son resultados observados, mientras otras son
cambios de dosis o tarea. Cada política posterior decidirá qué modificar y
en qué dirección. Cambiar altura, agarre, ROM o palanca puede romper la
comparabilidad de marcas; aumentar complejidad no equivale a mejorar fuerza.

## Mediciones compatibles

La capacidad del ejercicio se expresa como combinaciones explícitas de modo
de medición y modo de carga. No se permite obtener combinaciones mediante
el producto cartesiano de dos listas independientes.

| Código | Resultado principal | Condición/protocolo imprescindible |
| --- | --- | --- |
| `REPS` | Repeticiones válidas, entero ≥ 0. | Variante, ROM, conteo por lado y criterio de finalización. |
| `LOAD_REPS` | Repeticiones y carga externa. | Convención de carga, aparato y ejecución válida. |
| `DURATION` | Tiempo durante el que se cumple la tarea. | Posición, comienzo y pérdida de validez. |
| `REPS_IN_TIME` | Repeticiones válidas en ventana fijada. | Duración prescrita distinta del tiempo realmente realizado. |
| `MAX_LOAD` | Carga de un intento válido de una repetición. | Intentos, ROM y éxito/nulo; no exige RIR. |
| `TIME_FOR_DISTANCE` | Tiempo para completar una distancia fijada. | Distancia, salida/llegada y reglas de ejecución. |
| `TIME_FOR_COURSE` | Tiempo en un recorrido identificado. | Geometría, versión, salidas, señales si procede y penalizaciones. |
| `DISTANCE` | Distancia de salto/lanzamiento o desplazamiento. | El protocolo distingue estas tareas y cómo se mide. |
| `HEIGHT` | Altura conseguida. | Método/instrumento y validez del intento. |
| `PASS_FAIL` | Éxito o fallo de una condición definida. | Conservar motivo/nulo y reglas; no inventar resultado numérico. |
| `REACTIVE_METRICS` | Métricas instrumentadas definidas por protocolo. | Tiempo de contacto, salto y método de cálculo compatibles. |

Tiempo se expresa en segundos con precisión declarada y distancia/altura en
metros. La siguiente migración deberá soportar decimales cuando proceda y
conservar precisión/procedencia. No redondear un circuito a segundos enteros
ni convertir un cronómetro manual en medición de contacto. No sumar tiempos
brutos y penalizaciones sin una regla del protocolo. No convertir altura de
salto en vatios ni deducir fuerza máxima isométrica por tiempo de retención.

`DISTANCE` o `REPS` por sí solos no determinan la adaptación. Las opciones
del catálogo no acreditan que la UI o la base de datos actuales puedan
ejecutarlas todavía.

## Protocolo y comparabilidad

El contrato futuro del protocolo debe identificar versión, variante/familia,
medición, unidad/precisión, dirección favorable, condiciones, criterios de
validez, política de intentos y método de medición. Donde proceda fijará
ventana temporal, distancia, recorrido, agarre, apoyos, asistencia, uso de
piernas y conteo por lado. Los parámetros desconocidos no se completan a
partir del nombre de una oposición.

Se reutilizará `program_assessment_tests` y sus reglas/intentos existentes
para las pruebas configurables. Tropa y FAS conservan sus adaptadores propios.
La extensión deportiva enlazará esos registros a la variante o familia
compatible; no copiará baremos, categorías, puntuaciones o fuentes normativas.
Un protocolo de práctica no se presentará como oficial sin revisar el enlace.

El catálogo contiene un shuttle de 5-10-5 **metros**, no el 5-10-5 en yardas;
tampoco representa por sí solo el circuito oficial CNP. La trepa admite una
distancia por protocolo, en vez de imponer 6 m a todas las preparaciones.

Una serie mala no acredita estancamiento. El motor futuro necesitará varias
exposiciones comparables, adherencia, esfuerzo y contexto. No inferirá de una
marca aislada cuál es la capacidad limitante. La vigencia de referencias de
fuerza queda pendiente por objetivo; no se heredan los 30/45 días de carrera.

## Prescripción y resultado: contrato base, implementado en STR-017

Se ampliarán las estructuras existentes conservando planeado y real. El
contrato permitirá carga, repeticiones, duración, distancia, descanso,
asistencia, intención de ejecución y esfuerzo objetivo, según la tarea.

- `RIR`: solo cuando tiene sentido estimar repeticiones dinámicas restantes.
- `RPE`: especificar escala y si corresponde a serie, tarea o sesión.
- `MAX_TEST`: intención de test máximo bajo protocolo; no exige un RIR ficticio.
- `NONE`: ausencia de objetivo de esfuerzo, distinta de un dato faltante.
- Intención: controlada, explosiva o máxima, sin atribuir velocidad medida.

El esfuerzo y los resultados no se consideran observados por preseleccionar
el valor de la prescripción. Se registrará confirmación/introducción manual o
instrumento cuando corresponda. RPE de sesión ya existe y se reutilizará.

Se distinguirá estado de resolución (`pending`, `completed`, `skipped`) del
cumplimiento (completo/parcial/no conseguido), la validez del intento y el
motivo de interrupción. La decisión concreta de almacenamiento llegará con
la entrega de resultados: no se sustituye el enum actual sin migrar cola,
historial y RPC. Omitir por material o tiempo no acredita incapacidad física.
Una molestia registrada exige que el futuro motor la tenga en cuenta sin
diagnosticar ni clasificar ejercicios como universalmente seguros.

Descanso prescrito, tiempo observado por la app y descanso físico declarado
son datos distintos. Se conservará inicio/fin, pausas/restauración y
procedencia; el exceso de tiempo tras el aviso no desaparece. Resolver una
serie o tocar «continuar» no demuestra inicio físico de la siguiente. Las
recuperaciones de carrera existentes no se reutilizan como descanso de fuerza
sin cambiar su contrato explícitamente.

Los formatos convencionales, superserie, circuito, intervalos, Tabata, EMOM
y AMRAP siguen siendo estructuras de ejecución. No fijan adaptación.

## Casos de aceptación y estado real

### Frontera localizada para conectar resultados (STR-013, 03/10/2026)

La revisión del laboratorio está aceptada como ensayo, no como validación de
eficacia o activación para el deportista. El siguiente enlace reutilizará el
ejecutor actual, con sus adaptadores en la funcionalidad de entrenamientos y
las reglas deportivas en dominio puro. Antes de usar un resultado para
progresar, se deben cerrar estas diferencias comprobadas en el código:

| Dato necesario | Situación localizada | Trabajo pendiente |
| --- | --- | --- |
| Dosis prescrita y realizada | `WorkoutExecutionSet` conserva objetivos y valores reales de repeticiones, segundos, distancia, kg y esfuerzo, con identidad de serie. | Enlazar la exposición y su decisión versionada; no sustituir lo realizado por lo prescrito. |
| Tarea comparable | La serie conserva ejercicio y estructura; no contiene `StrengthTask` con versión de definición, protocolo y montaje. | Conservar la identidad deportiva de la prescripción al ejecutarla; no reconstruir protocolos históricos desconocidos. |
| Técnica y tolerancia | `PerformanceProgressionSet` exige validez técnica y la exposición admite tolerancia/motivo. Esos datos no están en la serie actual. | Registrar declaración explícita, ausencia y motivo con el alcance correcto; terminar una serie no acredita técnica válida. |
| Carga comparable | Se conservan kilos objetivo/reales, pero falta modo de carga y masa corporal fechada para lastre. | Separar carga externa, lastre y asistencia; cambiar carga o montaje no acredita consolidar la dosis anterior. |
| Esfuerzo ausente | La ejecución nueva deja RIR/RPE ausentes si no se declaran. El diálogo de corrección del historial aún inicializa esfuerzo desde el objetivo o un valor por defecto. | Corregir y probar esa frontera antes de consumir resultados: editar repeticiones no debe inventar esfuerzo. |
| Interrupción | Hay estados de serie y motivo de abandono de la sesión. No existe motivo específico de interrupción por tarea. | No atribuir automáticamente el abandono global a todas las tareas, ni confundir omisión por tiempo con dificultad física. |

Esta inspección no es una auditoría de todas las RPC ni una comprobación nueva
del esquema remoto. No modifica todavía almacenamiento, cola sin conexión,
correcciones ni sesiones. La implementación siguiente deberá verificar esas
fronteras conjuntamente con sus migraciones y pruebas transaccionales.

El primer recorrido real debe demostrar: una prescripción con identidad
completa → registro explícito de sus series → comparación con la dosis
original → propuesta explicada. Los tres modelos ya ejecutables cubren
repeticiones, carga/repeticiones y duración isométrica; las demás mediciones
siguen dentro del alcance con estado pendiente, sin aplicarles esas reglas
por analogía. Fases/horizontes y coordinación se conectarán después de que
ese ciclo tenga datos fiables, conservando los horizontes acordados.

STR-016 implementa esa forma de captura solo en el laboratorio de ADMIN,
mediante registros ficticios editables y dosis original conservada. El
contrato de dominio v2 añade carga real por serie, condiciones declaradas y
masa corporal de ejecución cuando corresponde. Esto no amplía todavía
`WorkoutExecutionSet`, las RPC, la cola ni los resultados persistidos; los
pendientes de la tabla anterior siguen vigentes para el deportista. Las
reglas y límites de la revisión se desarrollan en
[`MODELOS_PROGRESION_FUERZA_RENDIMIENTO_V1.md`](MODELOS_PROGRESION_FUERZA_RENDIMIENTO_V1.md).

### Recorridos de aceptación

| Caso solicitado | Representación en el contrato/catálogo | Situación del ejecutor |
| --- | --- | --- |
| 3 × 8 flexiones con RIR | `push_up_standard`, `REPS`, peso corporal. | Estructura básica existente; verificar declaración de resultado/esfuerzo. |
| Flexiones máximas en ventana | Misma variante, `REPS_IN_TIME`, duración y protocolo. | Pendiente de representación específica y registro. |
| Banca 4 × 5 con kg/RIR | `bench_press_barbell`, `LOAD_REPS`, carga externa. | Campos básicos existentes; perfil/material/protocolo pendientes de enlace. |
| Intento de 1RM | Misma variante, `MAX_LOAD`, intento válido o fallido. | Pendiente del modo de test y validez. |
| Dominadas máximas | `pull_up_pronated`, `REPS`, `MAX_TEST`. | Pendiente de protocolo/registro de test. |
| Dominadas lastradas | `pull_up_weighted`, `LOAD_REPS`, peso corporal + lastre. | Falta masa corporal fechada y semántica explícita de carga. |
| Plancha durante X segundos | `front_plank_forearms`, `DURATION`, sin RIR. | Variante y criterio técnico definidos; duración existente. Falta enriquecer prescripción/resultado. |
| Suspensión supina durante X segundos | `supinated_flexed_arm_hang`, `DURATION`. | Ejercicio oficial visible y duración básica disponible; enlace CNP opcional. Falta el registro especializado de test. |
| Trepa de 6 m cronometrada | `rope_climb`, `TIME_FOR_DISTANCE`, 6 m fijados por protocolo. | Pendiente; no convertirla en bloque de carrera. |
| Salto horizontal | `standing_broad_jump`, `DISTANCE`, intento y método. | Pendiente de medición específica. |
| Salto vertical | `countermovement_jump`, `HEIGHT`, intento y método. | Pendiente de medición específica. |
| Circuito con tiempo y penalizaciones | `TIME_FOR_COURSE`, protocolo enlazado. | Pendiente de recorrido, precisión y validez. |

## Integración con carrera

Se conserva PLAN-001: especialistas proponen y una coordinación común
resuelve semana, agenda y preparaciones simultáneas. Una misma sesión puede
servir a varias pruebas y contabiliza una única exposición. El contenido de
una sesión, no solo su formato, permitirá distinguir tren superior, piernas,
saltos, técnica y dosis ejecutada. No se utilizará una puntuación única de
fatiga inventada ni una regla universal de separación horaria.

La política anterior de carrera detectaba como posible carga de piernas cualquier
sesión con bloques ajenos a carrera/calentamiento/vuelta a la calma. Se ha
localizado en `20261001014000_running_prior_quality_context.sql`; la corrección
pertenece al bloque posterior de coordinación y exige pruebas de regresión.
STR-017 corrige esa clasificación en el adaptador y conserva la política v5;
las regresiones se documentan en el motor operativo.

## Ruta de integración y verificación

1. **Realizado:** contraste del catálogo remoto y enlaces de Flexiones,
   Sentadilla con peso corporal y Plancha frontal sobre antebrazos. La plancha
   de ensayo se ha definido expresamente, con autorización de Javier para
   corregir o sustituir datos de desarrollo; conserva su UUID.
2. **Realizado:** `exercise_training_profiles` conserva definiciones JSONB
   inmutables por código/versión, validadas en PostgreSQL y en dominio.
   `exercises` incorpora una referencia opcional solo para contenido de sistema.
   Los ejercicios personales siguen creándose con sus campos simples.
3. **Realizado:** seed de 63 perfiles y 63 entradas públicas de biblioteca.
   `20261003003000` incorpora las 60 entradas pendientes y conserva los UUID
   de las tres anteriores. `program_test_training_bindings`
   vincula variante/medición a una prueba existente mediante revisión expresa,
   sin duplicar baremos. Los enlaces iniciales CNP son dominadas pronas y
   suspensión supina; se exige la fuente/versionado/protocolo exactos del
   borrador existente. No se equipara el circuito normativo con un shuttle.
4. Ampliar prescripción, resultados, temporizadores e instantáneas; comprobar
   borradores locales, cola offline y correcciones, ambas apps y RLS.
5. Cerrar los doce recorridos de aceptación antes del algoritmo adaptativo.

Los enlaces solo se administran mediante RPC con comprobación de permisos.
Una prueba publicada conserva su enlace; una copia conserva los enlaces del
mismo protocolo en un borrador nuevo. Cambiar protocolo, unidad, dirección,
categoría, resolución, versión o distancia retira el enlace del borrador para
exigir otra revisión; renombrar la prueba no lo retira. La compatibilidad de
unidad/medición no sustituye esa revisión deportiva.

El deportista puede leer los 63 perfiles vinculados a los ejercicios públicos,
sin necesitar programa o prueba. También puede leer perfiles de pruebas de
programas publicados. No accede a definiciones internas sin publicar ni enlaces
de borradores. ADMIN puede consultar todo el catálogo. STR-017 incorpora la configuración revisada de estos enlaces en ADMIN.

Verificación de persistencia y biblioteca el 03/10/2026: `flutter analyze --no-pub`
limpio en raíz y ADMIN; batería completa de raíz (255 pruebas) y ADMIN junto
al contrato compartido (36 pruebas), correctas. Inventario documental y JSON:
63 variantes y 30 familias. Las migraciones `20261003000000`,
`20261003001000`, `20261003002000` y `20261003003000` se han aplicado a
**entrenaop-dev**. Historial local/remoto contrastado con
`supabase migration list` tras completar la biblioteca. Las 63
definiciones remotas coinciden con el JSON editorial, sin diferencias.
Pruebas SQL transaccionales de perfiles,
seguridad de ejercicios, módulos de entrenamiento y publicación de evaluaciones
correctas, todas con `ROLLBACK`. La nueva prueba de biblioteca verifica las
63 entradas públicas, los UUID originales, campos compatibles con el editor y
lectura por un deportista después de retirar los enlaces de evaluación borrador.
La regresión de widgets carga las 63 variantes, busca una dominada en el filtro
EntrenaOP, excluye un ejercicio personal y añade la variante a la sesión.
Inventario remoto: 63 perfiles, 63 ejercicios enlazados y dos vínculos CNP en
borrador. La comprobación no acredita producción, registros especializados
nuevos ni eficacia deportiva; el bloque sigue abierto.

## Asistencia técnica por cámara · STR-015

El 03/10/2026 Javier concreta el alcance futuro para Android e iOS:
**flexiones y plancha**. Busca detectar movimientos compensatorios y recorrido
incompleto en flexiones, y evitar acreditar una plancha cuya postura se pierde.
No se amplía a otros ejercicios. El alcance está acordado; la función no está
implementada ni validada y no modifica las políticas actuales.

Propuesta para el piloto, pendiente de validación deportiva y técnica:

- Flexiones: observar el ciclo completo de descenso/ascenso, la extensión
  final y la alineación de hombro, cadera y tobillo. La profundidad exigida y
  las compensaciones invalidantes dependen del protocolo, no de un ángulo
  universal. Un contacto exigido no se acredita solo con puntos articulares.
- Plancha: observar mantenimiento de la alineación y cambios visibles de
  cadera o apoyos. Partir de la variante definida en biblioteca, plancha
  frontal sobre antebrazos, y confirmar el protocolo concreto antes del piloto.
  No aplicar un criterio de recorrido o repeticiones a esta isometría.
- Captura: probar teléfono fijo y vista lateral guiada, verificando visibilidad
  de los puntos necesarios antes y durante el intento. La pérdida de
  observación debe distinguirse de una infracción técnica.
- Validación: comparar con revisión humana del mismo protocolo en vídeos y
  dispositivos Android/iOS variados, midiendo aceptación incorrecta, rechazo
  incorrecto y casos no evaluables. No se presupone precisión suficiente.

Siguen pendientes SDK e integración Flutter, tolerancias y duración de los
desvíos, avisos, condiciones de parada, cómputo del tiempo de plancha,
tratamiento de repeticiones dudosas y persistencia/procedencia del resultado.
Procesar localmente y no guardar vídeo por defecto es una recomendación,
no una decisión de arquitectura cerrada. La asistencia no acredita esfuerzo,
RIR ni aceptación por un examinador oficial.

## Evidencia y decisiones todavía pendientes

La revisión [ACSM 2026](https://pubmed.ncbi.nlm.nih.gov/41843416/) respalda
distinguir prescripciones según resultado; sintetiza adultos sanos y su
búsqueda llega hasta octubre de 2024. No prescribe la política individual de
EntrenaOP. [Pelland et al.](https://pubmed.ncbi.nlm.nih.gov/41343037/) estudian
volumen/frecuencia y trabajo directo/indirecto con rendimientos decrecientes;
sus modelos no son una medida individual de recuperación.

La [revisión de entrenamiento concurrente](https://pubmed.ncbi.nlm.nih.gov/41762427/)
motiva coordinar objetivos. La [revisión de precisión del RIR](https://pubmed.ncbi.nlm.nih.gov/34542869/)
motiva conservar rendimiento y procedencia del esfuerzo, sin convertir RIR en
verdad objetiva. Se utilizarán estas fuentes al especificar reglas por objetivo.

La [revisión de especificidad y transferencia](https://link.springer.com/article/10.1007/s40279-025-02225-2)
contrasta las mejoras de fuerza dinámica entrenada con la transferencia a
fuerza isométrica no entrenada. Apoya distinguir tareas y tipos de contracción;
no valida las relaciones particulares banca–flexiones o dominadas–flexiones
ni proporciona coeficientes para EntrenaOP. La primera matriz será una propuesta
de reglas deportivas revisadas, con su procedencia y límites explícitos.

Quedan pendientes dosis inicial, frecuencia, progresión, meseta, descarga,
mesociclos, proximidad a prueba, calibración de 1RM estimado, comparabilidad
longitudinal, anulación profesional y prioridades entre objetivos. Los siete
grupos de objetivo del texto se conservan como alcance; se implementarán
políticas específicas sobre un núcleo común, sin siete sistemas independientes.
