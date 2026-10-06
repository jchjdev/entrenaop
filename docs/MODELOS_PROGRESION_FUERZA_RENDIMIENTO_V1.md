# Modelos de progresión de fuerza y rendimiento · propuesta v1

**Actualización STR-021, 04/10/2026:** banco operativo, reglas activas y límites
en [MOTOR_FUERZA_RENDIMIENTO_V2.md](MOTOR_FUERZA_RENDIMIENTO_V2.md). Este documento
conserva la revisión de fuentes y propuestas; no todas sus recetas son políticas
activas. El selector aplicado ya no es `performance_v1_1`.

Fecha: 03/10/2026. Decisión: STR-011.

**Estado vigente STR-019 (04/10/2026):** existe integración técnica de servidor
con `performance_v1_1` y carrera. La revisión de la sesión real confirma que
esa política reproduce una dosis declarada y adapta cifras; **no implementa
todavía toda la programación por estímulos y fases propuesta aquí**. La matriz
exacta, verificación y límites están en
[MOTOR_FUERZA_RENDIMIENTO_V1.md](MOTOR_FUERZA_RENDIMIENTO_V1.md).
Los apartados de STR-012/016 conservan el contexto de los laboratorios anteriores.

## Revisión del banco aportado el 04/10/2026

Fuentes conservadas literalmente, como propuestas externas para revisar:

- [40 propuestas de entrenamiento](references/2026-10-04_banco_entrenamiento_propuesta_usuario.txt).
- [Composición de bloques](references/2026-10-04_composicion_bloques_propuesta_usuario.txt).

Sus porcentajes, duraciones, compatibilidades y repartos temporales no son
parámetros aprobados ni reglas activadas. Tampoco son 40 programas publicados
en la aplicación. Se revisan tanto sus ideas útiles como sus contradicciones.

### Diferencia entre medición, estímulo y programación

Una medición registra lo ocurrido bajo un protocolo. Una dosis indica el trabajo
de una exposición. Un bloque aporta ese estímulo a un objetivo; una receta
compuesta reúne bloques; el coordinador construye la sesión y después la semana.
La progresión decide cómo cambia cada estímulo con el historial y la fase.

El segundo texto aclara la modularidad, pero muchas fichas originales contienen
varios estímulos y ejercicios. Por ejemplo, F03 incluye fuerza lastrada,
volumen reglamentario y plancha alta. Debe descomponerse antes de combinarla
con P04, que vuelve a añadir plancha alta. M01–M04 son recetas de composición,
no cuatro estímulos independientes que sumar otra vez. No hace falta crear
un ejercicio nuevo por cada ficha ni multiplicar motores por oposición.

La arquitectura recomendada conserva reglas deportivas puras de servidor,
adaptadores de datos y el coordinador común. Las fichas revisadas aportarán
objetivo, protocolo, requisitos, demanda y dosis parametrizada. Flutter recoge
datos y ejecuta instantáneas: no selecciona el estímulo ni calcula progresión.
ADMIN vincula objetivos reconocidos y restricciones; no necesita redactar la
rutina individual de cada inscrito.

### Entrada y dosis: correcciones necesarias

1. `M` representa un máximo de repeticiones válidas **del protocolo indicado**;
   `P`, un máximo de duración válida. Una serie de 55 con RIR 3 es una referencia
   submáxima declarada, no `M=55` ni `M=58`. Repeticiones en 120 s, serie continua
   libre y repeticiones a cadencia obligatoria no son bases intercambiables.
2. La entrada futura distinguirá máximo/control, serie submáxima y dosis repetible
   de varias series. No obligará a todos a hacer un máximo: una política de entrada
   podrá usar una referencia submáxima compatible como base conservadora, declarando
   esa base y sus propios parámetros. No la renombrará silenciosamente como máximo.
   El campo de tipo y esa política **todavía no existen en el servidor**.
3. Las referencias isométricas antiguas son especialmente ambiguas: las instrucciones
   pedían terminar al perder la postura y el motor reutilizaba los segundos como
   trabajo. El ejecutor y el nuevo texto explican terminar con buena postura;
   eso no transforma retrospectivamente la medición antigua en dosis repetible.
4. Los porcentajes de las fichas son heurísticas. F01/F05 no imponen 5–6 series
   a una persona por conocer una sola serie. El volumen y la frecuencia de entrada
   necesitan límites por trabajo reciente y una respuesta posterior verificable.
5. No diagnosticar falta de fuerza por hacer 15 repeticiones ni falta de resistencia
   por hacer 35. Se necesita información del ritmo, técnica, trabajo tolerado y
   resultados específicos. Si falta, comenzar por práctica accesible y explicarlo.
6. RIR no debe contradecir la dosis: una primera serie al 40 % del máximo puede
   dejar un margen muy grande. No exigir RIR 4–5 en todas las series fáciles ni
   fingir un valor exacto superior a la escala 0–10 existente. La ampliación de
   registro para márgenes amplios requiere un contrato explícito.

Ejemplo **para revisión**, condicionado a una medición máxima real: si `P=55 s`,
la horquilla P02 de 45–55 % da aproximadamente 24–30 s por serie. Cuatro series
de 27 s con 90 s entre ellas son 6:18 de trabajo y descansos, antes de preparación
y transiciones. Ilustra la diferencia frente a repetir dos máximos; **no es la
nueva prescripción aprobada ni se deriva de una medición de 55 s de tipo desconocido**.

### Inventario completo revisado: destino de las 40 fichas

Todas siguen siendo candidatas; esta tabla evita perder propuestas o declarar
como implementadas tareas ausentes. «Descomponer» significa separar los estímulos
y contabilizar sus componentes una sola vez.

| Fichas | Finalidad aprovechable | Revisión previa a activación |
| --- | --- | --- |
| F01 | Técnica y práctica fácil | Individualizar series; separar la plancha añadida. |
| F02 | Fuerza mediante dificultad mecánica | Variante accesible y referencia propia; separar volumen reglamentario. |
| F03 | Fuerza con flexión lastrada | Carga calibrada; descomponer lastre, volumen y plancha. |
| F04 | Fuerza de empuje y práctica específica | Banca/remo con datos propios; evitar acumular otras dosis de empuje. |
| F05 | Volumen específico | Base compatible, tolerancia de volumen y descanso; no seis series por defecto. |
| F06 | Densidad EMOM | Garantizar trabajo y descanso dentro de cada minuto; progresar una demanda. |
| F07 | Ritmo en ventana reglamentaria | Ritmo practicable desde capacidad, no imponer cadencia objetivo inalcanzable. |
| F08 | Ventana fraccionada | Guardar segmentos y pausas; no sumar segmentos como marca continua. |
| F09 | Potencia de empuje | Perfil explosivo y ejecutor pertinentes; descomponer lastre/potencia/volumen. |
| F10 | Control completo de flexiones | Intento de control, intervalo adecuado y trabajo opcional contabilizado. |
| P01 | Técnica y acumulación isométrica | 30–45 s no son accesibles para todos; diferenciar antebrazos/plancha alta. |
| P02 | Duración relativa submáxima | Tipo de referencia, redondeo, volumen tolerado y descansos. |
| P03 | Continuidad isométrica | Duración accesible; no convertir cada serie larga en un máximo. |
| P04 | Plancha alta y trabajo específico | Descomponer sus tres ejercicios; contabilizar carga de hombros y empuje. |
| P05 | Apoyo de tronco | Referencia pertinente por tarea; no medir control motor solo con RIR. |
| P06 | Tronco en varios planos | Cargas, lados y material propios; no asumir transferencia equivalente a plancha. |
| P07 | Resistencia en circuito | Mantener pausas, lados y calidad; coste acumulado compartido. |
| P08 | Control isométrico | Máximo/control separado de la dosis; no obligatorio en semana de examen. |
| A01 | Aceleración y frenada | Perfil y trazado propios; progresar dominio antes de velocidad/volumen. |
| A02 | Giro de 90° | Protocolo y lados; no reutilizar el shuttle 5–10–5. |
| A03 | Giro de 180° | Protocolizar trayectos y giros, descanso y validez. |
| A04 | Shuttle 5–10–5 | Identidad existente; diferente del circuito con pelota. |
| A05 | Sectores del circuito objetivo | Vincular cada sector a su protocolo; circuito final como opción, no obligación. |
| A06 | Fuerza lateral y cambios de dirección | Descomponer y limitar dosis total de apoyos y frenadas. |
| A07 | Pliometría y cambios de dirección | Pocos intentos de calidad accesibles; evitar duplicar E01. |
| A08 | Cambios de dirección con lastre | Candidato avanzado; no entrada automática ni extrapolación del chaleco experimental. |
| A09 | Circuito completo específico | Familiarización/control espaciados; mayor prioridad cerca de la prueba, sin máximos diarios. |
| A10 | Respuesta a estímulos | Requiere señal externa; solo aquí corresponden aciertos/estímulos. |
| E01 | Pliometría breve | «Breve» no acredita poco coste: experiencia, contactos e intensidad. |
| E02 | Potencia horizontal/lateral | Intentos y lados, calidad y recuperación. |
| E03 | Potencia multidireccional | Dosis total de aterrizajes; separar componentes. |
| E04 | Fuerza de sentadilla | Carga demostrada o calibrada; no inventar 1RM. |
| E05 | Fuerza de bisagra | Carga y dominio propios; descomponer dos ejercicios. |
| E06 | Fuerza y salto combinados | Receta avanzada con recuperación y calidad explícitas. |
| E07 | Fuerza complementaria de piernas | Receta con varios ejercicios; coste compartido con carrera/COD. |
| E08 | Activación breve | Dosis menor y conocida; no aprender saltos nuevos antes de competir. |
| M01 | Empuje y tronco | Receta compuesta: reutiliza estímulos, sin duplicar accesorios. |
| M02 | Densidad y tronco | Receta compuesta: EMOM viable y carga de apoyos acumulada. |
| M03 | Potencia, COD y fuerza | Receta compuesta: prioridad del día y recuperación de piernas. |
| M04 | Activación antes de la prueba | Receta con dosis conocidas; no añade controles máximos. |

El catálogo actual ya contiene banca, flexión lastrada, trap bar, planchas,
saltos y gran parte del material necesario. **No contiene todavía perfiles
específicos de frenada, giro de 90°, sectores del circuito ni flexión explosiva.**
Crear esas variantes implica materializarlas en la biblioteca EntrenaOP y
definir sus protocolos/mediciones; no basta escribir nombres en una ficha.
Los textos no desarrollan dominadas, suspensión y cuerda: esos objetivos siguen
en el alcance general, con sus contratos existentes, y necesitan fichas propias.

### Composición y evolución

- Calcular duración desde dosis, pausas, bilateralidad, transiciones y preparación
  compartida. Los ejemplos de 34/35 min del segundo texto son ilustraciones,
  no pruebas de cabida. El combinador no rellena todo el tiempo disponible.
- Calcular demanda desde la instancia dosificada, no solo desde el nombre:
  un bloque «core» puede cargar hombros y empuje. F03 + F05 + P04 requiere revisar
  esa suma. Las etiquetas de fatiga son editoriales, no mediciones fisiológicas.
- Una prioridad principal y bloques secundarios/microdosis orientan la composición;
  no justifican por sí solos compatibilidad. Ordenar por objetivo y frescura de la
  tarea, con recuperación explícita; no adoptar una secuencia universal.
- Mantener práctica del gesto durante horizontes largos y aumentar la especificidad
  al aproximarse la prueba. No retirar todo el circuito hasta el último mes ni
  entrenarlo completo y máximo en cada sesión desde el inicio.
- La puesta a punto no prescribe automáticamente F10 + P08 + A09: tres controles
  máximos pueden contradecir la reducción de fatiga. Revisar fecha, último control,
  carga previa y recuperación. Una semana específica no es una semana de máximos.
- Conservar 1/2/3/4/6/12 **meses de calendario**, como carrera. Cuatro semanas son una
  ventana operativa posible, no la identidad de un mes: dos meses no equivalen
  siempre a ocho semanas. Fases y revisiones dependen de fechas y respuesta real.
- Coordinar propuestas de fuerza/COD con calidad, rodajes, agenda y recuperación
  de carrera mediante su adaptador. No cambiar la dosificación v5 para hacer caber
  por fuerza una receta externa ni deducir fatiga de una puntuación inventada.

### Contraste de fuentes primarias

| Fuente contrastada | Lectura que se conserva |
| --- | --- |
| [ACSM 2026](https://pubmed.ncbi.nlm.nih.gov/41843416/) | Síntesis amplia de fuerza, potencia y otros resultados; no acredita las dosis exactas de las 40 fichas. |
| [Kotarsky 2018](https://pubmed.ncbi.nlm.nih.gov/29466268/) y [tesis original del autor](https://library.ndsu.edu/ir/bitstream/10365/28060/1/Effect%20of%20Progressive%20Calisthenic%20Push-up%20Training%20on%20Muscle%20Strength%20and%20Thickness.pdf) | Progresión mecánica en hombres moderadamente entrenados, cuatro semanas; protocolo de fuerza con doble progresión. No demuestra que sea el mejor método para máximas flexiones cronometradas. |
| [Hung 2019](https://journals.plos.org/plosone/article?id=10.1371/journal.pone.0213158) | Entrenamiento multimodal de tronco; interacción grupo×tiempo de su test `p=0,076`. El SEPT incluye una secuencia con apoyos levantados: sus segundos no equivalen a una plancha reglamentaria mantenida. |
| [COD con carga, U19](https://pmc.ncbi.nlm.nih.gov/articles/PMC12533869/) | Chaleco y progresión en futbolistas entrenados; diferencia entre grupos en Illinois `p=0,534`. No acredita chaleco del 12,5 % ni ese volumen como entrada para opositores. |
| [Precisión de RIR](https://pubmed.ncbi.nlm.nih.gov/33337690/) | Estimación dependiente de condiciones y carga en los ejercicios estudiados. No proporciona una conversión exacta de 55 repeticiones submáximas a máximo de flexiones. |

Las restantes referencias del texto se conservan como pistas bibliográficas,
sin presentarlas como revisadas en esta tarea. Un ensayo de economía de carrera
o una clasificación editorial de interferencia no valida la programación conjunta.

### Criterios para sustituir la política actual

Antes de publicar desde este banco, habrá que poder revisar estas salidas concretas:

| Caso | Criterio de aceptación |
| --- | --- |
| 55 repeticiones con RIR 3 | Conserva la referencia submáxima; explica base, estímulo y dosis sin declarar un máximo estimado ni copiarla por defecto como rutina. |
| Plancha de 55 s hasta pérdida de postura | Conserva un control máximo válido si está confirmado; pauta trabajo submáximo mediante política revisada, sin repetir automáticamente máximos. |
| Circuito válido de 13 s, prueba a varios meses | Selecciona práctica de componentes pertinente y registra sus resultados; el recorrido completo tiene un propósito explícito. |
| Principiante con poca capacidad o cero repeticiones | Usa una regresión accesible realmente disponible, sin banca/lastre ni duraciones imposibles por defecto. |
| Fuerza, plancha y carrera en 35 min | Descuenta tiempos reales estimados, evita accesorios duplicados y respeta la calidad/recuperación de carrera. |
| Semana completa con datos incompletos de esfuerzo/técnica | No declara progreso fisiológico; prepara una decisión explicable y permite revisarla antes de guardar. |
| Objetivo alcanzado y otra prueba rezagada | Propone mantenimiento y prioridad revisada, sin diagnosticar un déficit ni comparar puntos de baremos incompatibles. |
| Última semana antes del examen | Reduce demanda conocida; no impone una batería de máximos ni introduce tareas nuevas. |

La corrección de usabilidad STR-019 no cumple aún estos criterios deportivos.
La próxima entrega debe concretar parámetros/entradas y recetas para todos los
modelos pertinentes, conectarlas a la autoridad de servidor y contrastar sus
salidas por capacidad, experiencia, material, tiempo, respuesta y horizonte.

## Revisión de la V2 y propuesta de banco único · 04/10/2026

Tercer texto conservado literalmente:
[Banco de bloques V2](references/2026-10-04_banco_bloques_v2_propuesta_usuario.txt).
Javier propone aprovechar también el material anterior. La recomendación es
usar la V2 como base editorial candidata y recuperar las aportaciones útiles
de las primeras fichas en un único banco normalizado. **No equivale a aprobar
sus dosis ni a activar 80 alternativas.** La revisión anterior se conserva para
entender qué ambigüedades se corrigieron; sus porcentajes no son una política
paralela entre la que el motor pueda elegir.

### Qué mejora y qué falta

La V2 distingue resultado oficial, capacidad de una serie y trabajo; separa
técnica, fuerza, resistencia, ritmo, potencia y evaluación. Describe dosis
completa/combinada y reconoce que el apoyo de brazos también carga estructuras
de empuje. Estos criterios se aprovechan como diseño candidato.

Antes de activar las fichas hay que corregir o concretar lo siguiente:

- `WORKING_SET` en el texto significa prescripción. Hace falta además distinguir
  **la serie submáxima realmente ejecutada**, con fecha, técnica, esfuerzo y
  condiciones, de una dosis propuesta que todavía no ha sido realizada. Una
  prescripción no acredita tolerancia ni capacidad.
- `FULL_DOSE` y `COMBINED_DOSE` son variantes editoriales útiles, no un interruptor
  universal de seguridad. Hay que escoger y limitar dosis por experiencia,
  historial, prioridad y carga acumulada. Cambiar una de seis a tres series no
  prueba por sí solo que sea compatible con otro bloque duro.
- Una marca deseada no autoriza su cadencia o duración. `FLEX-SP01/02/03` y
  `PLANK-SP01` necesitan una entrada practicable y una alternativa si el objetivo
  excede el trabajo demostrado. Los segmentos no se convierten en marca continua.
- RPE de plancha será esfuerzo subjetivo declarado junto a duración y postura.
  La horquilla RPE 6–7 no calcula automáticamente cuántos segundos puede sostener
  esa persona. Tampoco se puede reconstruir RPE de una referencia antigua sin él.
- `RUN-S01`: 80–90 % de 1RM, 3–5 repeticiones y RIR 2–3 no son tres equivalencias
  garantizadas. La carga debe permitir el rango y el margen previstos en esa
  persona; un 1RM conocido no obliga a usar 90 %. No se inventa el 1RM.
- La huella de antebrazos y plancha lateral también debe recoger demanda de
  hombros cuando proceda. No basta añadir `PS` a la plancha alta y describir las
  otras solo como `CA` o `CL`. El dead bug no garantiza compatibilidad ilimitada.
- Las cifras de tiempo siguen siendo ejemplos: la sesión «25 minutos» usa
  14–17 + 6–7 minutos de bloques ya preparados, **sin calentamiento inicial**.
  No cabe automáticamente en 25 minutos. El coordinador contabiliza una sola
  preparación común, preparación específica adicional, trabajo, pausas, lados
  y transiciones desde la dosis real. Un bloque posterior no siempre comparte
  el calentamiento o el material del anterior.
- `CORE-S02`, `RUN-P03` y `RUN-P04` siguen siendo recetas de varios ejercicios.
  Pueden conservarse, pero referencian componentes y no vuelven a sumar sus
  estímulos si la sesión ya incluye alguno. `RUN-P04` no es una microdosis
  accesible por definición: requiere experiencia con esos contactos y saltos.
- Faltan reglas numéricas de entrada, mantenimiento, progresión, reducción,
  recalibración y puesta a punto por ficha. La tabla de fases orienta prioridades;
  no sustituye esas reglas ni fija automáticamente cuatro semanas por mes.
- La V2 no añade dominadas, suspensión, cuerda ni estrategias propias de mejora
  de RM. Sus modelos siguen dentro del alcance del motor general y necesitan
  fichas revisadas; la existencia del banco de empuje no cierra todo el motor.

### Aprovechamiento sin duplicar estímulos

Correspondencias conceptuales; no implican equivalencia de dosis ni migración
automática de referencias. Las nuevas fichas son candidatas.

| Material anterior | Destino candidato en V2 | Qué se conserva aparte |
| --- | --- | --- |
| F01 | FLEX-T01 | Práctica fácil; retirar accesorios de la ficha elemental. |
| F02 | FLEX-S01 | Progresión mecánica con referencia de cada variante. |
| F03 | FLEX-S02 | Volumen y plancha pasan a una receta que referencia otras fichas. |
| F04 | FLEX-S03 | Remo/apoyo se conserva como componente con finalidad propia. |
| F05 | FLEX-E01 | Resistencia repetida; los porcentajes antiguos quedan descartados como regla activa. |
| F06 | FLEX-E02 | Densidad con dosis calibrada y rondas realmente posibles. |
| F07 | FLEX-SP01/SP02 | Cadencia según ventana y capacidad. |
| F08 | FLEX-SP03 | Fragmentos y pausas explícitos. |
| F09 | FLEX-P01 | Separar lastre, potencia y volumen cuando la receta los reúna. |
| F10 | FLEX-X01 | Evaluación con protocolo propio. |
| P01 | PLANK-T01 | Posición y tiempos accesibles. |
| P02 | PLANK-E01 | Trabajo submáximo; no mantener el porcentaje antiguo como vía alternativa. |
| P03 | PLANK-E02 | Continuidad y esfuerzo con postura válida. |
| P04 | PLANK-S01 + PLANK-E01 + CORE-S01 | Conservar como receta, sin duplicar sus componentes. |
| P05/P06 | CORE-S01/CORE-S02 | Finalidades y protocolos de cada ejercicio. |
| P07 | Receta de tronco | Opcional; no crea otro estímulo si usa fichas existentes. |
| P08 | PLANK-X01 | Control separado del trabajo habitual. |
| A01/A02/A03 | COD-T01/T02/T03 | Frenada y giros con trayectos y lados definidos. |
| A04 | COD-S01 | Shuttle distinto del circuito reglamentario. |
| A05 | COD-SP01 y, cuando corresponda, COD-T04 | Sectores específicos y elementos técnicos. |
| A06/A07 | Recetas de COD con fuerza/pliometría | Componentes reutilizados y demanda total contabilizada. |
| A08 | COD-R01 | Opción avanzada; sin lastre universal. |
| A09 | COD-SP02 o COD-X01 según finalidad | Entrenamiento completo de calidad y evaluación no son la misma ficha. |
| A10 | AGIL-R01 | Señal externa, percepción y decisión. |
| E01 | RUN-P01/P02 | Contactos y saltos dosificados por separado. |
| E02/E03 | RUN-P03 y recetas multidireccionales | Lados, aterrizajes y recuperación. |
| E04 | RUN-S01 | Fuerza de sentadilla individualizada. |
| E05 | RUN-S02/S03 | Bisagras diferentes, con carga y tolerancia propias. |
| E06/E07 | Recetas con RUN-S y RUN-P | No sumar otra vez la fuerza o los saltos ya incluidos. |
| E08 | RUN-P04 | Activación conocida; dosis que conserve frescura. |
| M01–M04 | Recetas de composición | Referencias a bloques y condiciones; no cuatro estímulos nuevos. |

`FLEX-S04`, `PLANK-SP01` y `RUN-S04/05/06` amplían opciones de la V2. Su
incorporación depende de pertinencia, calibración y recursos; no crea una
obligación de pautarlos. La biblioteca de ejercicios, las fichas de estímulo
y las recetas de sesión son recursos distintos.

### Cómo debe gestionar el banco el motor

La selección determinista sigue este orden:

1. Leer objetivos y protocolos del plan, fecha de prueba y prioridades.
2. Excluir fichas sin material, dominio, entrada compatible o tolerancia conocida
   suficiente. Identificar apoyo opcional y evaluación por separado.
3. Elegir estímulo principal pertinente y dosis de entrada o mantenimiento
   según la referencia y el historial, sin copiar la marca como rutina.
4. Añadir solo secundarios útiles: comprobar solapamiento, dosis acumulada,
   tiempo y recuperación junto a la propuesta de carrera y la agenda.
5. Explicar elección y límites, publicar la instantánea versionada y registrar
   resultados reales. La siguiente decisión aplica la política de respuesta.

Esto es adaptación basada en datos, **no aprendizaje automático de nuevas
reglas fisiológicas**. Completar una sesión, o mejorar una marca una vez, no
demuestra que la receta sea óptima ni autoriza al sistema a inventar otra dosis.
Las modificaciones de política requieren revisión, versión y regresiones.
La variedad responde a objetivos y respuesta; no se cambia de rutina para
aparentar personalización. Carrera mantiene su autoridad deportiva mediante
el adaptador; el catálogo de apoyo no recalcula su política por su cuenta.

### Fuentes adicionales contrastadas para esta V2

| Fuente | Alcance comprobado y límite |
| --- | --- |
| [Repeticiones y %1RM](https://pubmed.ncbi.nlm.nih.gov/37792272/) | Modela medias y variación individual; los ejercicios difieren. No establece una equivalencia exacta de repeticiones, carga y RIR de flexiones. |
| [Especificidad de fuerza](https://pubmed.ncbi.nlm.nih.gov/40314751/) | Compara adaptaciones dinámicas e isométricas no entrenadas. No demuestra directamente que banca tenga una transferencia concreta a flexiones cronometradas. |
| [Entrenamiento resistido y COD](https://pubmed.ncbi.nlm.nih.gov/41985742/) | Síntesis de modalidades resistidas y velocidad de COD; no aporta la dosis óptima del circuito de oposición ni autoriza cargar a principiantes. |
| [Fuerza pesada/pliometría y carrera](https://pubmed.ncbi.nlm.nih.gov/36370207/) | Economía y contrarreloj en corredores de fondo; no valida por sí sola las dosis RUN ni su ubicación junto a carrera v5. |

Las demás fuentes nuevas de la V2 quedan como pistas pendientes de contraste.
El banco sigue en revisión y no sustituye la política activa `performance_v1_1`.

## Qué se está decidiendo

Se conserva el manual aportado por Javier y el alcance completo del contrato.
Los modelos se organizan por resultado deportivo y protocolo, no por oposición,
pantalla, músculo o cada una de las 63 variantes. Una misma dominada puede
participar en resistencia a repeticiones, fuerza con lastre o apoyo a cuerda;
no recibe la misma dosis por tener el mismo nombre.

Para cada modelo se cerrarán: entrada mínima, selección específica/apoyo,
dosis inicial por capacidad, variable de progresión, evidencia para cambiar,
mantenimiento, reducción, recalibración, fase y coordinación. Ninguna revisión
de literatura proporciona por sí sola este algoritmo completo.

Se distinguen tres niveles:

- **Evidencia:** resultados de investigaciones, con población, tarea y límites.
- **Interpretación deportiva propuesta:** elección razonada de método para el
  objetivo de EntrenaOP. Puede tener apoyo indirecto sin validación específica.
- **Parámetro operativo propuesto:** series, incrementos, ventanas o umbrales
  concretos necesarios para programar. Se versionarán; no se presentarán como
  leyes fisiológicas ni como consensuados hasta su revisión.

## Método común propuesto

La base es especificidad, sobrecarga progresiva, continuidad, recuperación e
individualización. La variación tiene una finalidad; no se cambian ejercicios
para aparentar personalización. La hipertrofia puede ser apoyo cuando esté
justificada, sin convertirse en la finalidad de toda preparación.

La dosis empieza en la capacidad de trabajo reciente y comparable, no en la
marca que el usuario desea conseguir. Sin historial suficiente se calibra la
tarea; una referencia de examen no se convierte automáticamente en un
porcentaje universal de entrenamiento. Se conserva protocolo, montaje, carga,
asistencia, técnica, fecha y procedencia del esfuerzo.

Como política candidata, una progresión requiere **dos exposiciones comparables
completadas con calidad y toleradas**, con el esfuerzo correspondiente al
modelo. Dos es un parámetro de producto propuesto, no un número demostrado
óptimo para todas las capacidades. Se modifica una variable principal por
tarea/exposición; cambiar variante o montaje exige nueva referencia y no es
una progresión directamente comparable.

Con una respuesta aislada, datos incompletos o contradictorios, se mantiene o
se solicita información. Una omisión no prueba incapacidad ni justifica subir.
El esfuerzo declarado se contrasta con cumplimiento, técnica y contexto. Una
tendencia negativa comparable motiva reducir demanda o revisar contexto; no
se deduce enfermedad, déficit de fuerza ni otra causa de una sola marca.
La bandera de molestias/limitación conserva el contrato vigente de bloqueo de
prescripción automática.

RIR será una entrada para series dinámicas donde tenga sentido. El candidato
para parte del trabajo de fuerza/resistencia es dejar margen, inicialmente
alrededor de RIR 2–3; no es una obligación para calentamientos, técnica, pruebas
máximas o potencia. RIR no se convierte en segundos de reserva de plancha,
velocidad de salto ni calidad de agilidad. La app no puede observar técnica
que nadie haya registrado ni medir velocidad sin instrumentos.

### Entender la referencia antes de pedirla (STR-014)

Javier detecta que el laboratorio daba por conocido qué debía realizarse.
Antes del registro real, la app explicará la tarea, el montaje y el margen
en lenguaje cotidiano. En trabajo dinámico, la pregunta será: «Al terminar,
¿cuántas repeticiones más crees que podrías haber hecho seguidas, con la
misma técnica y sin descansar?». RIR significa ese margen estimado, no el
número realizado ni una puntuación de cansancio general.

Ejemplo educativo: ocho repeticiones realizadas y unas tres más posibles
se registran como ocho y RIR tres. No se hacen esas tres para comprobarlo,
ni se convierte la suma en un máximo medido de once. El objetivo de margen
y el margen realmente declarado son datos diferentes. La estimación no se
trata como exacta; «No sé estimarlo» debe conservar ausencia, no convertirla
en cero ni en el objetivo solicitado.

Una referencia reciente compatible puede evitar una nueva calibración. Sin
ella, el recorrido guiado tendrá que establecer trabajo submáximo adecuado
a la variante y experiencia; las instrucciones operativas y dosis de esa
entrada todavía están pendientes. No se pauta universalmente «haz ocho a
RIR tres»: ocho es un ejemplo, no una capacidad conocida de cada usuario.
Planchas y suspensiones necesitan duración/postura, no RIR ni segundos
hipotéticos restantes. Se conserva la diferencia entre medición de examen,
referencia de trabajo y resultado de entrenamiento.

ADMIN ya incorpora explicación visible y ayuda desplegable con ejemplo,
aclarando que su referencia y RIR tres son supuestos de simulación. No
implementa el registro real ni declara calibración terminada.

Verificación de esta aclaración: análisis limpio y 42 pruebas completas de
ADMIN correctas, incluida la explicación de RIR, su diferencia con el dato
real y la ausencia de esta escala en la referencia isométrica.

La propuesta utiliza periodización sencilla por énfasis. En usuarios preparados
para fuerza máxima puede alternar exposiciones de carga mayor y trabajo
submáximo. No prescribe ondulación compleja a principiantes ni sostiene que
DUP, bloques, APRE o cualquier marca de método sean universalmente superiores.

## Modelos propuestos

### 1. Fuerza máxima con carga: banca, sentadilla y dominada lastrada

**Método candidato:** doble progresión autorregulada. Dentro de una horquilla
se ganan repeticiones válidas con la misma carga; al consolidar su extremo alto
se aumenta el menor escalón de carga practicable y se vuelve al extremo bajo.
Para usuarios con experiencia, se combina práctica de cargas relativamente
altas con trabajo submáximo. Un principiante empieza con dominio técnico y
dosis tolerable, aunque el examen sea un RM.

Como envolvente inicial para revisar: dos exposiciones semanales cuando encajen
en la preparación, pocas series de trabajo y horquillas como 3–6 repeticiones
en fuerza preparada o 6–10 en entrada técnica. Estas horquillas y frecuencia
son propuestas, no una pauta individual deducible del nombre del ejercicio.
La práctica de RM requiere su protocolo y condiciones propios. Un RM estimado
no se trata como medido; la fórmula y su rango de uso deberán validarse.

Ejemplo ilustrativo: con una horquilla 4–6, pasar de 6/5/4 a 6/6/6 antes de
subir carga. No subir kilos y series a la vez. El lastre, masa corporal y
asistencia permanecen separados; no se transforma el lastre externo en un RM
equivalente de banca ni en una marca de dominadas sin lastre.

### 2. Máximas repeticiones sin límite de tiempo: flexiones y dominadas

**Método candidato:** práctica submáxima específica y progresión de volumen
válido, con apoyo de fuerza calibrado cuando proceda. Quien todavía no logra
una repetición usa una regresión concreta; quien ya acumula muchas necesita
práctica de resistencia del propio gesto. El número de repeticiones, por sí
solo, no diagnostica cuál es su limitación.

Primero se gana alguna repetición total manteniendo variante, series, técnica
y descansos; aumentar series es otra decisión cuando haga falta más volumen,
no el paso obligatorio cada semana. Se usan controles específicos espaciados,
no un máximo en todas las sesiones. Lastre, inclinación o asistencia requieren
referencia propia y una relación revisada con el objetivo.

Ejemplo ilustrativo de una dosis ya calibrada: 6/6/6 → 7/6/6 → 7/7/6. No
implica que todas las personas deban empezar con tres series, seis repeticiones
o una repetición más por semana. Tampoco convierte automáticamente una mayor
carga de banca en más flexiones reglamentarias.

### 3. Repeticiones en una ventana temporal

**Método candidato:** trabajo específico de ritmo sostenible y repeticiones
válidas en el tiempo reglamentario, más la resistencia/fuerza de apoyo
necesarias. Se conserva la duración oficial; no se alarga para aparentar mejor
marca. Si hay cadencia obligatoria, se respeta en vez de intentar ir más rápido.

Se puede practicar por segmentos y consolidarlos antes de cubrir la ventana
completa. La progresión puede aumentar el trabajo a ritmo válido o mejorar la
distribución dentro de la misma ventana, sin subir simultáneamente duración,
velocidad y volumen. Acortar descansos entre series no es la regla universal.
Sumar repeticiones de segmentos con descanso no produce una marca oficial
continua. La dosificación exacta de segmentos queda pendiente por protocolo.

### 4. Resistencia isométrica: plancha y suspensión

**Método candidato:** acumulación de segundos técnicamente válidos y aumento
gradual de la duración de las series, en el ángulo/agarre/postura de la prueba.
Plancha y suspensión comparten reglas de duración, pero sus apoyos y montajes
son distintos. Se detiene el registro válido al perder el criterio técnico.

Ejemplo ilustrativo calibrado: 20/20/20 s → 22/20/20 s, conservando postura y
descansos. Es un escalón operativo para discutir, no la conversión del máximo
del examen ni una obligación semanal. Añadir lastre o cambiar palanca genera
otra referencia; no equivale a sumar segundos. Se practica también la
continuidad exigida por la prueba, sin imponer un máximo diario.

Fuerza isométrica máxima e isométricos con intención explosiva necesitan otra
medición/política. No se prescribe un porcentaje de fuerza máxima isométrica
que EntrenaOP no pueda medir. La evidencia general de isometría no valida
directamente una progresión anual de suspensión o plancha.

### 5. Cuerda

**Método candidato:** aprendizaje del gesto permitido, tramos controlados,
ascenso completo válido y después mejora de velocidad sobre altura fija.
Con pies y sin pies son protocolos diferentes. Los apoyos de tirón/agarre
se seleccionan con condiciones explícitas, sin declarar que una dominada
sustituye una trepa.

Se progresa longitud o número de ascensos tolerados antes de introducir otra
demanda; una vez consolidada la prueba completa se prioriza su tiempo y
ejecución. No se incrementa a la vez altura, ascensos y lastre. Sin material
para practicar cuerda puede haber apoyo, pero queda visible la práctica
específica pendiente. Instalación, descenso y ejecución requieren un contexto
definido antes de automatizar dosis.

En las fuentes localizadas no hay base suficiente para declarar el mejor
protocolo longitudinal de trepa de oposición. Los estudios de ergómetros,
escalada deportiva o respuestas agudas no lo sustituyen. Esta política exige
especialmente revisión deportiva de dosis y transferencia.

### 6. Saltos y lanzamientos

**Método candidato:** técnica específica, fuerza de apoyo y ejecuciones
explosivas con recuperación suficiente. La finalidad es mejorar distancia,
altura o rendimiento de la tarea; hacer más repeticiones fatigadas no acredita
mejora de potencia.

Se consolida ejecución y rendimiento comparable antes de aumentar volumen,
complejidad o carga. Se conserva implemento, superficie y protocolo. Más
peso lanzado no equivale a más distancia con el implemento oficial. La
precisión y validez forman parte del resultado.

### 7. Reactividad y práctica de potencia

**Método candidato:** tareas de baja complejidad que se ejecuten y toleren bien,
seguidas de demandas mayores cuando haya evidencia de preparación. Se
distingue capacidad reactiva de saltos, producción explosiva y técnica de un
ejercicio de potencia. Un registro `PASS_FAIL` acredita ejecución, no fuerza
medida ni índice reactivo.

No se prescribe aumentar alturas de caída o contactos indefinidamente. El
trabajo se limita por calidad y respuesta. Los umbrales numéricos de pérdida
de velocidad/altura necesitan medición fiable y revisión; sin ella se utilizan
resultados y criterios técnicos explícitos, sin inventar un sensor.

### 8. Circuito prefijado y cambios de dirección

**Método candidato:** técnica de aceleración, frenada, giro y obstáculos
relevantes; progresión de componentes a secuencias y recorrido completo.
Fuerza y pliometría son apoyos posibles, junto con práctica específica.

El objetivo principal es tiempo válido en el circuito exacto. Aumentar velocidad
exige conservar ejecución; dificultad añadida o recorrido diferente no se
comparan directamente con el circuito oficial. Practicar descansado y preparar
el circuito bajo fatiga son exposiciones distintas, no intercambiables.

### 9. Agilidad reactiva

**Método candidato:** percepción, decisión y movimiento en respuesta a una
señal externa. Se incrementa incertidumbre/complejidad solo después de dominar
la tarea anterior. Se mantienen precisión y tipo de señal identificados.

Un circuito conocido no representa esta capacidad, aunque se llame «agilidad».
Tampoco un test de tocar una pantalla sustituye una respuesta corporal. Solo
aparecerá como prioridad si la preparación exige realmente este resultado.

### 10. Transportes y otras tareas compuestas

**Método candidato:** especificidad respecto a carga, trayecto, distancia,
duración, agarre e implemento. Se cambia una demanda pertinente cada vez:
primero completar válidamente la tarea objetivo, después su rendimiento.
La fuerza de apoyo se coordina con el resto de la preparación.

No se aplican automáticamente las reglas de RM, carrera o suspensión por
compartir un patrón. Un circuito compuesto necesita además definir orden y
transiciones; sus ejercicios aislados no acreditan cobertura del recorrido.

### Carrera

Se conserva `running_2k_v5`, su cuestionario, reglas de respuesta y contrato
actual. Sus 78 trayectorias de 1/2/3/4/6/12 meses son pruebas de coherencia
con entradas sintéticas; no prueban mejoras fisiológicas. No se extrapola
el motor de 2 km a cualquier distancia.

El ciclo de producto 2:1 ya documentado en carrera no se sustituye por una
descarga común automática. Su integración deportiva con fuerza requerirá
explicar y consensuar cualquier cambio de comportamiento, versionarlo y
ejecutar regresiones. Este documento no cambia sus parámetros.

## Evolución en el tiempo

1, 2, 3, 4, 6 y 12 meses se conservan como **horizontes de preparación**.
Dentro hay semanas y bloques con énfasis y revisiones. Una propuesta de
organización es revisar el bloque aproximadamente cada cuatro semanas, con
adaptación semanal. Cuatro es una cadencia de revisión candidata, no descarga
obligatoria ni duración biológicamente óptima de todo mesociclo.

Las funciones comunes son: calibración/entrada, desarrollo, especificidad y
puesta a punto. No son compartimentos estancos: se mantiene práctica
específica durante el desarrollo y apoyos útiles durante la fase específica.
Un usuario con historial válido puede entrar directamente en el trabajo que
tolera; no repite una fase de principiante por inscribirse en otro programa.

| Horizonte | Organización propuesta |
| --- | --- |
| 1 mes | Aprovechar capacidad existente, calibración breve cuando falte, práctica pertinente y ajuste final. No comprimir una preparación anual ni prometer adquirir todas las capacidades ausentes. |
| 2 meses | Entrada/consolidación, desarrollo dirigido y tramo específico con puesta a punto. El historial decide cuánto necesita la entrada. |
| 3 meses | Desarrollo más sostenido y progresiva prioridad a la prueba; revisión del bloque y controles comparables. |
| 4 meses | Más oportunidades de desarrollo/revisión antes del tramo específico. No añadir ejercicios por disponer de más calendario. |
| 6 meses | Varios bloques con prioridades revisables y mantenimiento de objetivos ya sólidos; último tramo específico según fecha real. |
| 12 meses | Preparación por bloques renovados con datos actuales, mantenimiento y cambios de prioridad. Orientación anual y prescripción próxima; no 52 semanas de dosis cerradas desde el primer día. |

Por encima de un año, carrera conserva el comportamiento y límite de
validación documentados en PLAN-025. Esta propuesta no prohíbe guardar una
fecha más lejana ni amplía la validación a ese horizonte.

**Ejemplo ilustrativo de doce semanas**, con historial inicial insuficiente y
una prueba de repeticiones como prioridad:

| Semanas | Énfasis y decisión |
| --- | --- |
| 1–2 | Confirmar protocolo y capacidad de trabajo, enseñar registro y consolidar una dosis repetible. |
| 3–6 | Aumentar trabajo válido o desarrollar fuerza de apoyo si está justificada, conservando práctica de la prueba. |
| 7–10 | Mayor peso relativo de la tarea del examen y controles comparables; mantener apoyos útiles. |
| 11 | Consolidar lo tolerado y revisar fatiga, disponibilidad y fecha. No es necesariamente una semana de descarga. |
| 12 | Disminuir trabajo fatigante y conservar familiaridad con la prueba para llegar recuperado. Dosis y duración exactas por revisar. |

Este reparto es una propuesta de planificación, no un protocolo validado para
todas las pruebas. No existe obligación de progresar cada semana, añadir un
ejercicio por bloque o hacer un máximo al cambiar de fase.

La descarga es una reducción temporal de demanda para recuperar/consolidar;
la puesta a punto busca rendir en una fecha concreta. Se planifican de forma
distinta. Una tendencia negativa puede anticipar recuperación; no se exige
esperar a la semana prevista. Los porcentajes de taper de powerlifting no se
copian a flexiones, cuerda, plancha o carrera.

## Coordinación y criterios de aceptación

El coordinador recibe propuestas con sus demandas, requisitos, prioridades y
alternativas. Cuenta una sola vez trabajo compartido y duración completa,
incluyendo calentamiento, descanso y transiciones. Resuelve solapamiento de
tirón/cuerda/suspensión o piernas/saltos/carrera y coloca la práctica prioritaria
en condiciones apropiadas. No llena automáticamente el tiempo disponible.

No se suman todos los mínimos de frecuencia de cada modelo ni se hace progresar
todo simultáneamente porque cada módulo lo permita por separado. Tampoco se
impone aquí una única subida global por semana: eso requerirá un contrato de
carga conjunto, y no se deduce de la regla de progresión de carrera v5.

Antes de activar una política deben quedar revisados y versionados sus rangos
por capacidad, entrada, incremento, mantenimiento, reducción/recalibración,
descarga, puesta a punto, variantes y medición del ejecutor. La práctica técnica
y las exposiciones fáciles se distinguen del trabajo exigente. Un máximo de
examen no es una sesión normal ni toda sesión debe llegar al fallo.

Se comprobarán casos de entrada, capacidad alta/baja, mejora, mantenimiento,
respuesta negativa, técnica inválida, datos ausentes, cambio de material,
asistencia/protocolo, retorno tras interrupción y proximidad al examen. Las
trayectorias abarcarán los seis horizontes y objetivos combinados. Las pruebas
de software acreditan reglas y coherencia; la eficacia y calibración requieren
seguimiento deportivo de usuarios, sin prometer mejora a partir de simulación.

La política original `push_up_reps_draft_v1` conserva su código y regresiones;
sus dos series e incrementos por serie no son el programa longitudinal aquí
propuesto. El panel principal pasa al recorrido compartido de STR-012 descrito
a continuación. El resto de dosis y la evolución temporal se cerrarán por
modelo antes de activarlas en planes reales.

## Primer tramo ejecutable de revisión (STR-012)

`performance_progression_policy.dart` incorpora dominio puro compartido, sin
Flutter ni Supabase. `performance_progression_draft_v1` recibe una dosis de
trabajo calibrada, capacidad actual confirmada y contexto; devuelve una
propuesta de una exposición, con versión, acción, motivo y parámetros de
progresión. No genera semanas, no estima el RM y no obtiene la dosis inicial
de un porcentaje del máximo de examen.

Se implementan tres modelos:

- **Repeticiones:** +1 repetición total en la serie menor; ante dificultad
  repetida, −1 en una de las mayores. Solo práctica dinámica de la misma
  variante, sin trasladarlo a pliometría, ejercicios asistidos o apoyos.
- **Carga/repeticiones:** progresar una repetición dentro de la horquilla;
  cuando todas las series consolidan el extremo alto, subir el escalón de
  carga y volver al extremo bajo. El lastre y la masa corporal se conservan
  separados; cambiar la masa declarada rompe la comparabilidad. Una
  dificultad repetida reduce repeticiones; en el mínimo exige recalibración,
  sin inventar una carga adecuada.
- **Duración isométrica:** +2 segundos en una serie; dificultad repetida
  reduce hasta dos segundos de una serie sin bajar de uno. Conserva tarea y
  montaje. No utiliza RIR ni mezcla plancha, suspensión y transporte.

Parámetros experimentales por defecto: dos exposiciones comparables en días
UTC distintos; ventana de 14 días para referencia y respuestas; horquilla
4–6 y escalón externo de 2,5 kg. El RIR objetivo dinámico admitido en este
ensayo es 2–4. La UI usa RIR 3 y descansos de 120 s para trabajo dinámico y
60 s para isometría. Los escalones configurables quedan en la decisión.
Ninguno de estos números se presenta como óptimo universal. Actualizar la
referencia puede proceder de trabajo reciente válido; no implica un máximo
obligatorio cada catorce días.

El perfil publicado de dominada lastrada admite `LOAD_REPS`, todavía no
`MAX_LOAD`: conservar masa corporal/lastre en una dosis no acredita cobertura
de un objetivo de RM para esa variante. Ese caso permanece sin cobertura
hasta revisar su perfil/medición, sin cambiar definiciones inmutables.

Las dos últimas exposiciones pertinentes deben conservar la dosis completa,
versión y protocolo. No se buscan éxitos antiguos ignorando una dosis nueva.
La referencia de trabajo de RM debe conservar también el montaje del objetivo;
la coincidencia del código de ejercicio no permite usar otro agarre/montaje.
Una sola exposición, datos incompletos, respuestas mixtas o interrupción por
tiempo mantienen. Dificultad incluye incumplimiento objetivo conocido, técnica
inválida, tolerancia negativa o RIR inferior a dos. En el mínimo se solicita
calibración. Fechas futuras y duplicados no permiten progresar; falta de
material, contexto y molestias producen estados explícitos.

La reserva temporal de la exposición incluye 300 s de margen, descansos y
duración estimada; para repeticiones usa 5 s por unidad como reserva, sin
prescribir tempo. No suma calentamientos compartidos ni acredita duración
exacta, encaje semanal o recuperación conjunta.

ADMIN → **Laboratorio de fuerza y rendimiento** carga los perfiles oficiales
reales y ofrece «Cargar ejemplo completo». El contexto se declara una vez;
los pasos agrupan empujes, tirones, isométricos y fuerza con carga. Las
respuestas se conservan al volver. Incluye ejemplos de flexiones, dominadas,
plancha, suspensión y banca; la selección es ficticia y no configura objetivos
de un programa. Cada bloque permite simular respuesta y comprobar su razón.
Tras la revisión de Javier (STR-013), la dosis se introduce con un campo
numérico por serie, su unidad y controles para añadir/quitar. Añadir copia
el último valor editable; no es una recomendación de aumentar volumen.
Quitar una serie conserva las demás. El ensayo permite entre una y seis
filas: es un límite del editor de laboratorio, no un máximo deportivo del
motor. No se requiere escribir listas de números separados por espacios.
La UI conserva como pendientes objetivos de cuerda, ventana temporal,
saltos/reactividad, recorridos, agilidad reactiva y transportes. Ninguna salida
de revisión autoriza publicar; no hay planificaciones nuevas del deportista.

Quedan pendientes selección revisada de variantes/apoyos, adaptación por fases
y horizontes, coordinación semanal, contratos de resultados y prescripción de
servidor. El avance no acredita la activación de todas las capacidades ni la
eficacia humana del algoritmo.

Verificado el 03/10/2026: análisis limpio de ambas aplicaciones; 312 pruebas
completas en raíz y 98 en ADMIN con contratos compartidos; compilación web
correcta. Las regresiones incluyen pantalla de 360 px, volver conservando
respuestas, bloque sin datos/perfil y cobertura pendiente junto a dosis
disponibles. El renderizado aislado de widgets con el tema de ADMIN permite
revisar contexto, empujes y resumen; no constituye una sesión autenticada
contra Supabase ni una revisión con resultados reales del deportista.

STR-013 se comprueba con análisis limpio, compilación web y las 41 pruebas
completas de ADMIN, incluidas diez del laboratorio. Se revisa el renderizado de los campos
individuales con el tema de ADMIN y el recorrido de 360 px. No cambia el
dominio compartido ni el motor de carrera.

## Registro de ejecuciones en la revisión ADMIN (STR-016)

El laboratorio deja de solicitar «dos ejecuciones toleradas/difíciles» como
clasificación elegida. Cada objetivo con modelo ejecutable permite registrar
hasta dos exposiciones ficticias, editar o quitar cada una y conservarlas al
volver entre bloques. El límite de dos registros pertenece a este editor de
ensayo, no a la extensión del historial futuro. Se abren en un diálogo
separado para conservar el recorrido principal por bloques.

La captura admite fecha, cantidad realizada por serie, declaración de técnica,
RIR real para trabajo dinámico, kilos utilizados para trabajo con carga,
confirmación de variante/montaje/descansos, tolerancia y motivo de interrupción.
Una cantidad cero es distinta de cantidad desconocida. Los campos reales
empiezan vacíos o «Sin informar/No sé estimarlo», sin copiar la prescripción.
Las isometrías no generan RIR. Editar mantiene identidad, fecha y dosis del
registro salvo cambios expresamente realizados; cancelar descarta el borrador.

La dosis se fija al abrir un nuevo registro. Cambiar después la referencia
del laboratorio no actualiza el pasado. «Cargar dos registros de ejemplo»
crea expresamente dos exposiciones con todos sus datos declarados, separadas
en días de simulación; los campos siguen siendo editables. Las fechas de un
registro nuevo parten de dos/cinco días atrás y se pueden seleccionar en los
catorce días recientes. La referencia del ensayo continúa fechada siete días
atrás: registros anteriores a esa calibración no acreditan su consolidación.
Estos valores son contexto ficticio del ensayo, no fechas del deportista.

El dominio pasa a `performance_progression_draft_v2`. No cambia los escalones
numéricos ni la exigencia de dos exposiciones. Añade una comprobación previa
de condiciones declaradas; sin confirmar variante/montaje/descansos mantiene
con motivo explícito. En carga/repeticiones, una carga real ausente o distinta
en cualquier serie impide atribuir consolidación o dificultad a los kilos de
la dosis original. Para peso corporal más lastre exige también masa corporal
compatible; eso no activa el objetivo de RM de dominada lastrada cuyo perfil
sigue sin cobertura. Las decisiones y referencias antiguas no se convierten
silenciosamente en v2. La interrupción empieza desconocida salvo declaración
expresa; no informarla no equivale a completar sin interrupciones. El RIR
ausente, el tiempo y las respuestas mixtas
mantienen las salvaguardas previas.

No se leen resultados reales del deportista ni se guardan estas entradas.
Siguen pendientes la calibración inicial guiada, instantáneas persistentes de
protocolo/montaje, contexto actual, técnica/tolerancia/motivo por tarea,
descanso observado frente a declarado, correcciones sin inventar esfuerzo,
cola sin conexión y decisión del servidor. La confirmación manual de
condiciones no equivale a una observación instrumental. Fases/horizontes y
coordinación semanal no quedan implementados por este avance.

Verificación del 03/10/2026: análisis limpio en ambas aplicaciones, 315
pruebas completas en raíz y 52 en ADMIN, y compilación web correcta. Incluye carga real diferente,
ausencias, cancelación/edición, dosis histórica conservada, interrupción por
tiempo, isometría sin RIR, fecha sin hora futura y separación entre v1/v2.
El renderizado aislado de ADMIN permite revisar el formulario y el registro;
no acredita un recorrido autenticado ni lectura de datos reales.

## Fuentes contrastadas y límites

La búsqueda combina síntesis recientes y estudios de intervención. Cuando se
dispone únicamente del resumen se limita la interpretación a ese contenido;
no se presenta esta revisión como una búsqueda sistemática exhaustiva.

| Fuente | Aportación y límite para esta propuesta |
| --- | --- |
| [ACSM, 2026: prescripción de fuerza](https://pmc.ncbi.nlm.nih.gov/articles/PMC12965823/) | Síntesis de 137 revisiones; búsqueda hasta octubre de 2024. Distingue resultados y respalda cargas mayores para fuerza máxima e intención rápida para potencia. No determina dosis óptimas de todas las pruebas ni umbrales exactos de RIR. Texto completo consultado. |
| [Moesgaard et al., 2022: periodización](https://pubmed.ncbi.nlm.nih.gov/35044672/) | Síntesis con volumen equiparado: señal favorable a periodización en 1RM y a ondulación en entrenados. No acredita superioridad universal para resistencia local, cuerda o principiantes; se contrasta con la síntesis más amplia de ACSM. Resumen consultado. |
| [Plotkin et al., 2022: progresar carga o repeticiones](https://pubmed.ncbi.nlm.nih.gov/36199287/) | Ensayo de ocho semanas en entrenados: ambas vías fueron viables. No ensaya el algoritmo de doble progresión de EntrenaOP ni todas sus tareas. Resumen consultado. |
| [Hammert et al., 2025: resistencia absoluta y relativa](https://pubmed.ncbi.nlm.nih.gov/40153563/) | El resultado depende del tipo de prueba de resistencia y su carga. No permite asumir que mejorar RM mejora automáticamente cualquier máximo de repeticiones. Resumen consultado. |
| [Oranchuk et al., 2019: isometría](https://pubmed.ncbi.nlm.nih.gov/30580468/) | Importan longitud muscular, intensidad e intención; resultados centrados en fuerza, morfología y función neuromuscular. No valida la receta de segundos para plancha/suspensión. Resumen consultado. |
| [Pliometría en adultos entrenados, 2025](https://pubmed.ncbi.nlm.nih.gov/41034241/) | Apoya utilidad para resultados explosivos y determinados recorridos prefijados. No valida aumentar contactos/altura sin criterio ni convierte esos tests en agilidad reactiva. Resumen consultado. |
| [Agilidad y percepción–acción, 2026](https://pubmed.ncbi.nlm.nih.gov/41710443/) | Distingue exigencias reactivas; estudios dominados por deportes de equipo y certeza moderada/baja. Sus asociaciones de dosis no se trasladan como receta óptima a opositores. Resumen consultado. |
| [Held et al., 2026: entrenamiento concurrente](https://pubmed.ncbi.nlm.nih.gov/41762427/) | Sustenta la viabilidad de combinar resistencia y fuerza. No demuestra ausencia de interferencia en toda persona ni define nuestra agenda conjunta. Resumen consultado. |
| [Travis et al., 2020: puesta a punto de fuerza máxima](https://pmc.ncbi.nlm.nih.gov/articles/PMC7552788/) | Orienta disminuir fatiga antes de un rendimiento máximo. Evidencia específica y limitada; no prescribe porcentajes para todas las pruebas. Texto completo consultado. |
| [Huang et al., 2025: autorregulación de fuerza máxima](https://pubmed.ncbi.nlm.nih.gov/40791980/) | Compara métodos en fuerza máxima; una clasificación probabilística no demuestra el mejor motor para todos los movimientos. Resumen consultado. |
| [Precisión al predecir repeticiones restantes](https://pubmed.ncbi.nlm.nih.gov/34542869/) | Fundamenta tratar RIR como estimación, contrastada con ejecución. No es una medición objetiva equivalente entre personas y tareas. Resumen consultado en la revisión de STR-007. |
| [Ergómetro de trepa, 2018](https://pmc.ncbi.nlm.nih.gov/articles/PMC6226072/) | Desarrollo y caracterización de un dispositivo; no ensayo longitudinal de mejora de trepa reglamentaria. No justifica una política de cuerda por sí mismo. |
| [Entrenamiento en personal militar, 2022](https://pubmed.ncbi.nlm.nih.gov/35247052/) | Contrasta programas tradicionales y no tradicionales en varias capacidades y tareas ocupacionales. Heterogeneidad y poblaciones militares limitan convertir los resultados en una receta óptima para cada opositor. Resumen consultado. |
| [CrossFit y entrenamiento concurrente, 2020](https://pubmed.ncbi.nlm.nih.gov/33239940/) | Revisa demandas y adaptación de fuerza/resistencia en CrossFit. La transferencia de recomendaciones requiere atender a la tarea y al contexto; no valida copiar WOD ni convierte una mejora general en mejora de una prueba concreta. Resumen consultado. |

ACSM es una síntesis relevante, no una fuente exclusiva ni una garantía de
superioridad universal. PubMed es una base bibliográfica, no un método de
entrenamiento. Se selecciona evidencia por diseño, población, tarea y resultado,
incluyendo investigaciones de otras instituciones, calistenia, entrenamiento
militar y CrossFit cuando sean pertinentes.

Los ensayos específicos de flexiones y sus límites se conservan en
[la estrategia experimental](ESTRATEGIA_FLEXIONES_V1.md). El manual de Javier
aporta alcance y principios a revisar; sus referencias no comprobadas no se
presentan como bibliografía validada. No se afirma disponer de una receta
científicamente demostrada para cada combinación de prueba y usuario.
