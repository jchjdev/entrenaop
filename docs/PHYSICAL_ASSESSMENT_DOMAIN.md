# Dominio de evaluación física

Última revisión: 26 de septiembre de 2026.

## Decisión vigente

EntrenaOP no modelará `PAEF` o `PAFA` como si fueran una oposición. Son pruebas
internas con reglas propias, tramos de edad, puntuaciones y cálculo agregado;
se incorporarán cuando sus baremos oficiales estén disponibles. Los accesos a
Tropa y Marinería, Suboficiales y Oficiales también serán programas distintos,
aunque compartan parte de la normativa o de las pruebas.

La [Orden DEF/15/2026](https://www.boe.es/eli/es/o/2026/01/13/def15) establece
un régimen unificado y separa, entre otros contextos, ingreso, formación,
egreso y evaluación periódica.

El programa implementado `armed_forces_troop_entry` corresponde al **ingreso
desde fuera a las escalas de Tropa y Marinería**, no a las pruebas periódicas
de quien ya es militar. El artículo 6 comparte los tipos de prueba, pero el
artículo 12 separa las tablas: anexo III para ingreso y anexo II, por marca,
sexo y edad, para evaluación periódica. La disposición transitoria segunda
aplaza la entrada en vigor de los nuevos baremos periódicos al 1 de enero de
2027. Igual ejercicio no implica igual objetivo, puntuación ni programa.

La evaluación inicial que tenía la app antes de incorporar preparaciones usaba
el único catálogo disponible. La migración
`20260920003000_preparation_goals.sql` asoció las evaluaciones existentes de
ese catálogo al programa de Tropa sin alterar las marcas. Eso explica la
sensación de que una evaluación «general» terminó dentro de Tropa: fue una
transición de datos, no una regla de producto para futuros programas. No se
renombrará ni reutilizará su identificador, porque hay preparaciones y
evaluaciones vinculadas. La futura captura inicial debe nacer en el contexto
del programa elegido. Podrá sugerir una medición previa pertinente y vigente,
pero solo después de que el usuario confirme que quiere usarla; no trasladará
el apto oficial de otro baremo.

### Entrada y alcance de la evaluación inicial acordados

El inicio consulta por identificador de preparación si hay al menos un intento
guardado: Tropa en `physical_assessments`, Mejora FAS en
`fas_periodic_assessments` y programas configurables en
`program_assessment_attempts`. Ninguna evaluación de un programa satisface la
de otro. La pantalla configurable obtiene el identificador del programa de la
preparación activa; no acepta ese dato desde la URL. Tener un intento guardado
solo completa el paso de captura: la vigencia del resultado y su utilidad para
prescribir son decisiones deportivas posteriores.

Al iniciar una preparación, el programa abre su evaluación inicial y pide solo
los datos que necesita para planificar y puntuar sus propias pruebas. No habrá
una batería física general obligatoria fuera de los programas: preparar CNP no
debe exigir el circuito de FAS. Una calculadora pública puede existir fuera de
una preparación, pero simular puntos no inicia ni completa una evaluación para
un plan. La calculadora FAS gratuita seguirá accesible desde fuera de FAS,
igual que una herramienta de ritmos. Si el usuario guarda expresamente un test
desde ella, permanece en su historial FAS. Solo Mejora FAS puede alimentarse
de ese test: ningún otro programa puede usarlo, aunque comparta alguna prueba
o unidad. Esta frontera se comprueba al asociar el test en PostgreSQL.

Este será **un único recorrido visible dentro de cada preparación**, con
componentes reutilizables para capturar marcas y contexto. Un intento puede
cumplir varias funciones sin duplicar la actividad: puntuarse según el baremo
del programa y aportar su marca medida al planificador. Las reglas de aptitud
y los puntos permanecen ligados a su versión normativa; el entrenamiento usa
el resultado medido, su protocolo y su fecha. Hoy aún existen pantallas y
almacenes históricos separados para Tropa, Mejora FAS y programas configurables;
la lectura inicial de marcas y su elección explícita ya se conectan con una
vista común, pero la dosificación deportiva sigue pendiente. El
recorrido único puede contener varios pasos o pantallas; esta especificación
no elimina registros, calculadoras, controles ni evaluaciones existentes.
STR-008/009 concretan la preferencia de Javier: bloques breves relacionados con progreso,
atrás/continuar y datos conservados, contexto común preguntado una vez y
preguntas condicionales por objetivo/protocolo. El reparto del tiempo entre
tareas de EntrenaOP corresponde a la coordinación común de PLAN-001;
no se pide al deportista reservar manualmente minutos para cada motor.
El flujo y sus límites se desarrollan en
`docs/CONTRATO_FUERZA_RENDIMIENTO_V1.md`, apartado «Preparación guiada y reparto
automático» y «Cobertura completa y contrato entre módulos». Se avanza por
bloque completo con Atrás/Continuar, no automáticamente tras cada respuesta.
La cobertura se diseña para todas las capacidades desde ahora; no limita el
recorrido futuro a carrera y flexiones. Es diseño pendiente; no describe un
asistente ya operativo.
La primera vista común «Datos para empezar» lee las marcas de 2 km ligadas
a cada preparación y permite introducir días y minutos disponibles, días
reservados a fuerza, cuatro semanas completas de carrera y estado actual de
salud. Estos datos se guardan por preparación en `running_intake_contexts`.
La marca elegida y, si procede, la confirmación de continuidad se guardan en
`running_reference_selections`. La lectura revalida fecha y contexto; todavía
no se publica un plan.

Si ya hay una marca oficial reciente y compatible de 2.000 m **de esa misma
preparación**, bastará como referencia provisional para empezar y no se
exigirá Cooper ni VAMEVAL. Si no la hay, la referencia inicial de carrera
ofrecerá Cooper como opción principal o VAMEVAL continuo como alternativa,
sin exigir ambos. Más adelante cualquiera de ellos podrá servir de calibración
opcional. La prueba oficial conserva su marca y baremo propios; su puntuación
no se utiliza como ritmo, y su tiempo no se etiqueta como VAM. La vigencia
deportiva de la marca de carrera sigue RUN-005: sugerencia hasta el día 30,
revisión condicionada hasta el día 45 y, desde el 46, solo historial para fijar
ritmos. Esta ventana por sí sola no confirma continuidad ni autoriza el plan. El
usuario registrará manualmente el resultado de la actividad que haya hecho;
la evaluación no presupone que
lleve el móvil mientras corre. Una marca anterior se podrá **sugerir**, con
su fecha y procedencia visibles, solo si es pertinente para ese programa,
compatible en unidad, protocolo y versión, y suficientemente reciente. El
usuario decidirá si la utiliza o introduce una nueva; no habrá autocompletado
silencioso de toda la evaluación. La antigüedad se cuenta desde la fecha de
realización. La asociación explícita de un test personal FAS con Mejora FAS
usa provisionalmente un máximo de 30 días, comprobado también en PostgreSQL;
no se extiende a otras pruebas ni permite trasladar un test FAS a otro programa.
Falta definir la vigencia por tipo de prueba para las demás sugerencias ajenas
a la referencia de carrera. La
interpretación y la puntuación permanecen
separadas por programa y versión normativa. No se migrarán ni fusionarán
históricos por compartir el nombre de una prueba.

El acceso al historial FAS desde Mejora FAS y su asociación manual están
implementados: el historial muestra todos los tests y solo ofrece asociar los
personales aún no vinculados y recientes, con su fecha visible. El usuario
decide. La asociación conserva marcas, baremo y fecha.
La captura de Tropa ya se inicia dentro de su preparación y exige sus cuatro
marcas oficiales. Mejora FAS guarda su evaluación periódica y su propio 2.000 m;
Tropa mantiene además un control específico de carrera separado. El recorrido
común acordado todavía no sustituye esas pantallas. Falta ofrecer Cooper o
VAMEVAL cuando no haya 2.000 m utilizable, cerrar sus protocolos e interpretar
los resultados para planificar; tampoco existe todavía una política de vigencia
y reutilización confirmada para todas las pruebas. La calculadora FAS
independiente y su guardado explícito ya existen; no se convertirán en
una evaluación física general para el resto de programas.

El detalle de Tropa ya no muestra registros del historial general por mera
coincidencia de versión de catálogo. Conserva sus datos en el historial
original, sin asociarlos automáticamente a una preparación. La app ya no ofrece
registro nuevo desde ese historial general. Desde el propio
detalle se pueden registrar las cuatro pruebas oficiales: la RPC
`record_troop_goal_assessment` comprueba propietario, programa activo, catálogo
vigente y marcas antes de vincular el nuevo intento a `preparation_goal_id`
en la misma transacción. Solo la última evaluación vinculada se muestra allí.
El control separado de 2 km también pertenece a la preparación y muestra su
última marca. Los registros generales anteriores podrán sugerirse para
reutilización cuando se diseñe su confirmación explícita; por ahora no se
trasladan ni se usan en el planificador.

### Pruebas definidas desde administración

El panel de administración permite añadir, editar y borrar pruebas de un programa borrador. Cada
definición guarda código, nombre, unidad (repeticiones, segundos o metros),
dirección favorable, protocolo, orden, resolución de la marca, edades aplicables
y aplicación a ambas columnas del baremo o solo H/M. Un mismo ejercicio puede tener variantes
distintas, como dominadas H y suspensión M. H/M son columnas normativas: la
simulación exige elegir la que corresponda, sin inferirla automáticamente de la
identidad del perfil. La captura futura del deportista deberá pedir o proponer
esa columna y confirmar la elección conforme a la convocatoria.

`program_assessment_scoring_rules` guarda versión, enlace y nombre de fuente,
modalidad, vigencia, referencia para la edad y el tipo de calificación. En
modo puntos también guarda media, suma o solo mínimos por prueba, máximo por
ejercicio, mínimo por ejercicio y mínimo total cuando corresponda.
`program_assessment_score_bands` guarda intervalos cerrados por columna, edad y
puntos. `program_assessment_pass_standards` guarda mínimos apto/no apto por
columna y edad. Las RPC de administración impiden añadir o editar tramos superpuestos,
marcas que no respeten la resolución y puntos superiores al máximo. Cada tramo
de borrador puede editarse o quitarse. Sus campos «desde», «hasta» y «puntos»
son la fuente de verdad del baremo: la marca mínima para obtener los puntos
exigidos por prueba y la marca que alcanza la puntuación máxima se derivan por
columna H/M. No se guardan mínimos y máximos duplicados en la ficha de prueba.
Cambiar unidad, dirección favorable, columna, resolución o edades incompatibles
con baremos existentes exige confirmar su borrado y volver a definirlos. Borrar
una prueba borra sus tramos y mínimos. No se pueden editar baremos de programas
publicados, también mediante escritura directa a las tablas. Cada prueba
define uno o varios intentos, con repetición libre o solo tras nulo. La
simulación contextual `preview_program_assessment_attempt_v3` valida los
intentos y calcula la mejor marca válida, aptitud y, cuando proceda, puntos y
media o suma. Sin intento válido, el ejercicio queda no apto y recibe cero
puntos. ADMIN permite importar una tabla completa; si una fila falla, se
revierte toda la importación. La autoría está restringida a administradores y borradores;
el deportista solo puede leer definiciones de programas publicados. Las tablas
nuevas no sustituyen los catálogos oficiales existentes de Tropa o FAS.

Una prueba cronometrada puede declarar `distance_meters` y un
`measurement_protocol` estructurado además de sus instrucciones libres. Para
el primer caso se admite `run_2000m_v1` solo con 2.000 m, segundos y mejor
marca baja. ADMIN puede vincular expresamente esa prueba al módulo deportivo
`running_2000m_v1` mediante `program_training_modules`. El vínculo queda
inmutable al publicar y se copia al crear una nueva edición. El vínculo no se
muestra como tarjeta sin acción dentro de la preparación. La marca y su
puntuación siguen perteneciendo
al programa; aún no se transfieren al planificador ni entre programas.

Las tablas de marcas y puntos del anexo II de
[BOE-A-2026-15055](https://www.boe.es/buscar/doc.php?id=BOE-A-2026-15055)
están cargadas en el borrador CNP 2026: circuito de agilidad y 1.000 m comunes,
dominadas H y suspensión M, 66 tramos H/M de 0 a 10 puntos, eliminación si
cualquier ejercicio obtiene cero y media mínima de cinco. Las marcas de
referencia y los extremos de las tablas se contrastaron con el BOE. El programa
sigue sin publicarse hasta que Javier lo revise y publique desde ADMIN. El
circuito de agilidad tiene configurado un segundo intento solo tras nulo. El
deportista puede registrar intentos nulos y marcas válidas en su preparación.
ADMIN puede copiarlo a un borrador con versión nueva sin tocar el historial.
Falta consumir este resultado en el algoritmo semanal y decidir cómo se ofrece
una edición nueva a preparaciones ya activas.

Cada catálogo tendrá un identificador de versión, fuente oficial y fecha de
vigencia. Una marca guardada conservará la versión del baremo con la que fue
evaluada. Publicar una versión nueva no recalculará silenciosamente el
histórico.

### Revisión transversal de la evaluación (27/09/2026)

**Estado en desarrollo:** el editor de borradores ya permite que Javier configure
desde ADMIN una regla apto/no apto o de puntos, fuente y versión, modalidad o
fase, vigencia, forma de calcular la edad, pruebas aplicables por H/M y edad,
mínimos por H/M y edad o tramos de puntos por H/M y edad. Puede crear, editar y
borrar esas definiciones. La simulación pide columna, nacimiento y fechas,
muestra solo pruebas aplicables y calcula aptitud, puntos si proceden y margen
respecto al mínimo. Los RPC validan edad, columna, resolución y solapamientos.
Cada modalidad normativa distinta se representa mediante un programa distinto.
La política de intentos es editable por prueba. La revisión previa a publicar
detecta pruebas sin umbral, sin cobertura continua de puntos, cuyo máximo no
sea alcanzable o que premien una marca peor en las columnas y edades
aplicables. El deportista introduce las marcas manualmente y el
servidor conserva resultado, versión y preparación. La adaptación semanal aún
no consume esta evaluación genérica.

Las fuentes oficiales muestran al menos cuatro formas distintas de evaluar:

- Ingreso a Tropa 2026: cuatro pruebas y marcas mínimas H/M por hito. La
  calificación física de ingreso es apto/no apto; el margen de cada marca es
  útil para entrenar, pero no se inventará una nota oficial.
- CNP Escala Básica 2026: tres ejercicios aplicables por columna H/M,
  intervalos de 0 a 10 puntos, cero eliminatorio y media mínima de cinco.
- Ingreso a Cabos y Guardias 2026: cuatro ejercicios, marcas mínimas según
  H/M y grupos de edad menores de 35, 35–39 y 40 o más; calificación física
  apto/no apto.
- Evaluación periódica FAS desde 2027: tablas de 0 a 100 por prueba, H/M y
  bandas de edad; mínimo general de 20 puntos en cada prueba. El circuito no
  se exige a partir de los 45 años. Puede haber exigencias superiores o pruebas
  complementarias para destinos concretos. No existe suma oficial general.
- Oficiales y suboficiales de ingreso añaden natación y tienen umbrales
  distintos según proceso con o sin titulación.

Fuentes contrastadas: [Orden DEF/15/2026](https://www.boe.es/eli/es/o/2026/01/13/def15),
[convocatoria de Tropa 2026](https://www.boe.es/buscar/doc.php?id=BOE-A-2026-436),
[CNP 2026](https://www.boe.es/buscar/doc.php?id=BOE-A-2026-15055),
[Cabos y Guardias 2026](https://www.boe.es/buscar/doc.php?id=BOE-A-2026-9982),
[Suboficiales 2026](https://www.boe.es/buscar/doc.php?id=BOE-A-2026-8623)
y [Oficiales 2026](https://www.boe.es/buscar/doc.php?id=BOE-A-2026-8620).

**Contrato de producto acordado:** al iniciar una preparación, el usuario
confirma la modalidad concreta y la columna normativa H/M que le corresponde;
se pide fecha de nacimiento cuando la convocatoria use edad. El programa
resuelve una sola batería aplicable y muestra únicamente esas pruebas. La edad
se calcula en la fecha que establezca el baremo, no siempre en la fecha actual.
Cada intento conserva marca, fecha, validez, programa, modalidad, columna y
versión normativa. El resultado separa aptitud estimada según la norma,
puntuación calculada cuando exista y margen de entrenamiento. Haber superado
el mínimo no equivale a una buena nota en un sistema puntuado. En uno
apto/no apto, el
margen se muestra como dato de entrenamiento, nunca como nota inventada.

**Pendiente para el algoritmo:** consumir los resultados normalizados de estas
evaluaciones sin interpretar cada BOE, revisar con Javier cada catálogo oficial
antes de publicarlo y decidir cómo migra el usuario de un programa publicado
a una edición posterior. La importación masiva reduce el trabajo
con tablas grandes, pero no acredita por sí sola que las marcas copiadas
coincidan con el documento oficial.

## Primera vertical

El primer catálogo implementado es `es_def_15_2026_troop_v1`, correspondiente
a las escalas de tropa y marinería del anexo III. Incluye los tres hitos
oficiales:

- ingreso;
- fin de la fase de formación militar general;
- fin de la enseñanza de formación.

Las cuatro pruebas son flexo-extensiones de brazos en dos minutos, plancha
isométrica, carrera continua de 2.000 metros y circuito de
agilidad-velocidad. Las categorías `men` y `women` reflejan literalmente las
dos columnas H/M del baremo oficial; no se reutilizarán como identidad de
género del usuario.

## Reglas de modelado

- Las repeticiones y los tiempos son unidades distintas y no se pueden
  comparar entre sí.
- En flexiones y plancha una marca mayor es mejor; en carrera y agilidad un
  tiempo menor es mejor.
- Los tiempos se almacenan internamente en milisegundos para conservar décimas
  en agilidad sin usar números decimales.
- La prueba acuática pertenece a determinados accesos de oficiales y
  suboficiales; no forma parte de este primer catálogo de tropa y marinería.
- Los baremos de evaluación periódica de la nueva orden entran en vigor el 1 de
  enero de 2027. Se implementarán como otro catálogo, no mezclados con ingreso.

## Estado de la primera vertical

Se ha elegido como primer recorrido al aspirante a tropa y marinería que prepara
las pruebas de ingreso. La aplicación permite seleccionar el baremo H/M,
introducir las cuatro marcas, obtener un informe con el mínimo y el margen de
cada prueba, guardar el intento y consultar el historial propio.

La persistencia separa la cabecera de la evaluación de sus cuatro marcas. El
cliente envía las mediciones originales a la función
`record_physical_assessment`; PostgreSQL comprueba de nuevo la sesión, versión,
categoría, hito, número de pruebas, identificadores y valores antes de insertar
todo en una única transacción. La interfaz no puede concederse a sí misma un
resultado apto.

Las políticas RLS limitan el historial al propietario y a los administradores.
La vista `physical_assessment_results` reconstruye cada resultado desde la marca
y el baremo versionado, conservando el criterio que se usó en ese momento.

El historial agrupa correctamente las cuatro filas de la vista en una única
evaluación y compara los dos últimos intentos. La diferencia favorable mantiene
el mismo significado en todas las pruebas: positiva es mejora, aunque para
carrera y agilidad se obtenga reduciendo el tiempo.

La recomendación `assessment_focus_v1` prioriza el mayor déficit porcentual
respecto al mínimo. Cuando las cuatro pruebas están superadas, prioriza la de
menor margen relativo. PostgreSQL guarda la versión, prueba elegida, margen y
razón junto a la evaluación; una versión futura no reescribirá esta decisión.

La prescripción se aplaza hasta validar sus reglas deportivas. La evaluación
periódica y otros accesos se incorporarán como programas y catálogos posteriores
sin alterar esta primera vertical.

## Siguiente piloto de evaluación periódica

Javier prefiere trabajar primero con las pruebas que conoce como PAFAS/PAEF.
Para el nuevo régimen se ha creado el programa estable
`fas_periodic_assessment`, de tipo `internal_assessment`, **habilitado en
desarrollo**.
Ambos nombres se tratan como formas de referirse a esta evaluación periódica,
no como dos baremos inventados. La referencia
`assets/programs/fas_periodic_2027/assessment_reference_v1.json` contiene la
tabla íntegra de **0 a 100 puntos** del anexo II de la Orden DEF/15/2026:
marca, columnas H/M y tramos 17–25 a 60+ para las cuatro pruebas. Conserva
milisegundos para tiempos y no copia los mínimos de ingreso de Tropa. El
calculador puro `FasPeriodicScoreCalculator` aplica el mejor umbral alcanzado;
entre dos filas no interpola ni redondea a favor. En agilidad elimina las
centésimas y usa la décima inferior, como prescribe el anexo I. Conforme al
artículo 10, el circuito no se exige desde el mismo día en que se cumplen 45
años, aunque el último tramo visible de su tabla se titule 41–45. La vigencia
de este régimen periódico comienza el 1 de enero de 2027.

El texto oficial consultado el 24/09/2026 no muestra correcciones ni
modificaciones posteriores. La tabla II.3 publicada contiene una secuencia
anómala después de 15:14 (`16:22` a `16:54`, seguida de `16:02`). El catálogo
conserva literalmente esas filas y no las sustituye por una progresión
inferida mientras no exista corrección oficial.

La calculadora gratuita está separada del registro: no requiere una
preparación activa, no guarda marcas ni altera el historial y está disponible
en los accesos rápidos de Inicio. Muestra puntos por prueba, el cumplimiento
orientativo del mínimo general de 20 puntos y la fuente/versión. No suma ni
promedia las pruebas como calificación normativa. Para evitar cálculos manuales,
muestra además una suma matemática grande y claramente rotulada como
orientativa; la orden no define esa suma como resultado oficial. Antes de 2027
etiqueta el resultado como referencia futura y nunca lo presenta como
calificación oficial.

La migración
`20260923006000_fas_periodic_assessments.sql` guarda cada intento fechado en
tablas independientes del ingreso, con edad calculada desde la fecha de
nacimiento del perfil para la fecha del test,
categoría, versión y las tres o cuatro marcas exigibles. El servidor valida
propiedad de la preparación activa, conjunto exacto de pruebas y valores no
negativos. La migración `20260923007000_fas_periodic_age_from_profile.sql`
comprueba en servidor que la edad guardada coincide con el perfil. La app
permite repetir el test y consultar sus marcas frente al
mínimo de 20 puntos; desde los 45 años el circuito no se exige. Las marcas
anteriores a 2027 quedan etiquetadas como referencia de entrenamiento, no
como evaluación oficial bajo el nuevo régimen. Aún faltan la verificación
independiente de la categoría declarada y las reglas de aptitud operativa. Un
escenario normativo de 2026 requiere su catálogo
histórico propio; no se le aplican anticipadamente los baremos de 2027.
