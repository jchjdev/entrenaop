# Cerebro de carrera de 2 km: especificación de trabajo

> **Estado vigente (01/10/2026):** [Motor 2 km v5](MOTOR_CARRERA_2K_V5.md).
> El diseño que sigue conserva preguntas e hipótesis originales. Consultar v4
> para el comportamiento implementado y sus límites actuales.

**Actualización 01/10/2026:** la primera especificación ejecutable, las decisiones
provisionales y sus pruebas están en [`MOTOR_CARRERA_2K_V1.md`](MOTOR_CARRERA_2K_V1.md).
Este texto conserva el diseño amplio y las preguntas originales. La política
nueva sustituye v6 y los selectores Dart; no declara cerrado todo el diseño.

Estado: **diseño general en borrador; solo el catálogo piloto v5/v6 y su primera
progresión están implementados en desarrollo. No hay validación deportiva**.
El selector de foco del punto 18 tiene una primera implementación de dominio
en `running_stimulus_focus_policy.dart`, probada con escenarios de respuesta.
Recibe tendencias ya interpretadas, no las calcula desde las ejecuciones, y
todavía no participa en la publicación semanal. Por tanto, el piloto FAS
sigue siendo el único motor que publica sesiones hoy.
Ámbito: módulo de carrera de 2 km, primero en el piloto Mejora FAS. El texto
aportado por Javier el 1 de octubre de 2026 es el punto de partida, no un
conjunto de constantes listo para publicar. El comportamiento implementado se
describe en `RECORRIDO_CARRERA_2K.md`; código y migraciones prevalecen.
La trazabilidad de los **26 apartados completos** del documento deportivo está
en `MATRIZ_CEREBRO_CARRERA_2K.md`. Esta especificación no sustituye ninguno de
ellos: en particular, mesociclos (16), carga y descarga (17) y adaptación del
tipo de estímulo (18) siguen pendientes de un contrato deportivo comprobable.
La selección posterior de veinte entrenamientos aportada por Javier se analiza
en `CATALOGO_CANDIDATO_CARRERA_2K.md`; sus formatos aún no son reglas activas.
Javier ha aclarado que los registros actuales del piloto son de prueba y
pueden descartarse si resulta necesario rediseñar. Esto permite reemplazar
contratos de ensayo, pero no convierte una regla deportiva sin validar en apta
para publicar ni requiere borrar nada ahora. El bloque actual se centra en el
motor determinista, sin integrar un modelo de lenguaje.

## Qué reutilizamos y qué falta

| Pieza | Hoy | Para el cerebro propuesto |
| --- | --- | --- |
| Preparación y fecha objetivo | `preparation_goals` | Añadir una marca objetivo explícita y separarla del mínimo normativo. |
| Marca de 2 km | Selección fechada del mismo programa; ventana RUN-005 | Conservar protocolo, calidad e incertidumbre; comparar nuevos intentos. |
| Contexto | Días/minutos recientes, disponibilidad, fuerza reservada y salud | Incorporar carga real de ejecuciones, fatiga/recuperación y fuerza de pierna sin repetir preguntas innecesarias. |
| Decisión semanal | FAS v5 elige minutos y cuatro variantes piloto, incluida calidad 4 × 2 y 5 × 2 | Ampliar la selección E/T/V/S/R solo con dosis y señales de respuesta revisadas. |
| Ejecución | Plantillas, series, agenda y ejecutor compartido | Leer parciales, distancia, duración, RPE y motivo de incumplimiento por intención de sesión. |
| Auditoría | Política, referencia y razón en `running_week_decisions` | Guardar estado deportivo, candidatos descartados, política de selección, dosis y razón de cada progresión. |
| Coordinación | Evita días ocupados y reserva fuerza | Coordinar carga de carrera y fuerza dentro de una sola semana. |

## Modelo lógico mínimo

- `PerformanceAnchor`: prueba, protocolo, versión, fecha, resultado, incidencias
  y calidad del dato (`medido`, `estimado` o `inferido`). El 2 km oficial conserva
  además su baremo propio, que no se convierte en ritmo.
- `RunningState`: continuidad y carga recientes, rendimiento y tendencias
  comparables, tolerancia a cada familia de estímulos, disponibilidad,
  restricciones, salud, fecha/objetivo y confianza de cada inferencia. Ausencia
  de información y valor cero son estados distintos.
- `Stimulus`: intención primaria E (fácil), T (trabajo sostenido controlado), V
  (intervalos de alta demanda aeróbica), S (específico de 2 km) o R (exposición
  neuromuscular breve). La etiqueta no afirma un umbral fisiológico medido.
- `SessionVariant`: identificador y versión, propósito, condiciones de entrada,
  calentamiento, trabajo, recuperación, vuelta a la calma, límites de dosis,
  tiempo necesario, material y forma de evaluar el resultado. Puede generar
  varias dosis de una misma variante, sin almacenar cientos de sesiones casi
  idénticas.
- `WeeklyDecision`: fase, demanda prioritaria, candidatos, dosis elegida,
  sesiones, razón, restricciones y versión de políticas. Se materializa como
  plantillas y agenda del ejecutor existente; no crea un ejecutor nuevo.
- `AdaptationState`: para cada familia, última exposición comparable, variable
  progresada, respuesta, estado de confianza y necesidad de consolidar,
  progresar, reducir o solicitar datos. No se infiere de una sola carrera mala.

## Orden de decisión propuesto

1. Validar propiedad y programa, vigencia de datos, estado de salud y agenda.
   Las restricciones duras pueden impedir una propuesta.
2. Reconstruir el estado desde medidas y ejecuciones. Conservar qué es
   declarado y qué es medido; no fabricar zonas ni umbrales desde un solo 2 km.
3. Elegir la fase según tiempo hasta la prueba, estado, historial y necesidad
   observada. General, desarrollo específico, descarga y puesta a punto son
   estados posibles; no se cambia de fase solo por pasar una fecha.
4. Distribuir intenciones E/T/V/S/R para la semana completa y coordinar fuerza.
   Contar minutos intensos reales, no toda la duración de la sesión de calidad.
   Evitar estímulos duros consecutivos salvo regla explícita y auditable.
5. Filtrar variantes de un catálogo pequeño por requisitos, tiempo, historial
   tolerado y objetivo. Seleccionar dosis dentro de límites revisados. Si no
   hay una dosis defendible, pedir datos o elegir una propuesta conservadora.
6. Validar duración de todos los tramos, recuperaciones, carga y conflictos de
   agenda. Publicar con versión y razón, usando la agenda y el ejecutor actual.
7. Tras la ejecución, interpretar cada resultado frente a la **intención** de
   su sesión, acumular evidencia comparable y decidir la siguiente semana.

Un modelo local de pesos abiertos podría proponer o explicar entre variantes
permitidas, pero no sustituye estas entradas, contratos y validaciones. Su
salida requerirá evaluación deportiva antes de poder publicarse.

## Rendimiento y objetivo: matemáticas sin falsa precisión

Para un intento válido de `t` segundos:

`current2kSpeedMps = 2000 / t`.

Para una marca objetivo explícita de `u` segundos:

`target2kSpeedMps = 2000 / u` y
`targetGap = target2kSpeedMps / current2kSpeedMps - 1`.

El cociente describe la distancia entre objetivo y rendimiento actual. No
determina por sí solo la viabilidad, la velocidad de umbral ni una sesión. Los
modos de meta que deberá representar el producto son mejorar sin cifra, una
marca elegida por el usuario y superar el mínimo oficial del programa con
holgura. El ejemplo personal 7:58 → 7:45 no fija una meta universal. Una
holgura de diez segundos es solo una idea pendiente de decidir por programa;
el mínimo normativo y la meta deportiva deben conservar su procedencia. Los
rangos E 65–78 %, T 84–90 %, V 96–102 % y R >105 % de la velocidad del 2 km
del texto de partida son **hipótesis a contrastar**. No se han adoptado como
prescripción ni se convertirán en constantes ocultas. Una futura política de
ritmos debe guardar fuente, rango, incertidumbre y versión; RPE, conversación
y frecuencia cardíaca fiable sirven para contrastar la intención.

La velocidad objetivo no reemplaza a la actual. Las exposiciones a ella
requieren elegibilidad por historial y una dosis limitada. Todavía no hay
umbrales justificados de `targetGap` para decidir 100, 200, 400 u 800 m; son
preguntas de calibración y laboratorio, no reglas cerradas.

## Progresión y adaptación

- Registrar por sesión la variable principal que se intenta progresar:
  intensidad, tiempo/distancia de repetición, número de repeticiones, volumen
  total de calidad o recuperación. La política no aumentará varias a la vez
  sin una razón explícita revisada.
- Comparar cumplimiento, parciales, degradación, RPE, molestias y condiciones
  de la sesión con exposiciones equivalentes. El RPE de un test máximo no se
  interpreta como el de un rodaje fácil. Una sesión aislada no demuestra
  adaptación ni pérdida de forma.
- Acciones posibles: consolidar, progresar una variable, reducir el estímulo,
  descargar, recalibrar referencia o pedir información. No existe una
  secuencia automática universal entre ellas.
- Los valores sugeridos en el texto, como degradación del 3–5 %, dosis T por
  duración, porcentajes de ritmos y ciclos 2:1 o 3:1, **no están aprobados**.
  Serán parámetros versionados solamente tras revisión de evidencia y pruebas.
- Descarga y puesta a punto son decisiones diferentes. La primera puede
  reducir calidad o carga global; la segunda depende de la prueba próxima.

## Primer catálogo que hay que diseñar, sin fijar aún las dosis

### Incremento piloto ya implementado en desarrollo

`fas_running_week_v5` introduce un catálogo **cerrado y versionado** en
`fas_running_session_variant_v1`: rodaje fácil, caminar/trotar 8 × 1,
calidad controlada 4 × 2 y calidad controlada 5 × 2. Son variantes de ejecución,
no afirmaciones de que el corredor haya alcanzado un umbral o VO₂ determinado.
La selección y la publicación permanecen en el servidor; `variant_code`,
`intention`, dosis y motivo quedan en la decisión y el registro de sesión.
Las semanas antiguas conservan su versión y sus plantillas originales.

La primera calidad del piloto sigue siendo 4 × 2. Una semana completa y
tolerada permite elegir 5 × 2 **solo** si existen al menos dos exposiciones
4 × 2 finalizadas en las ocho semanas anteriores, cada una con RPE final
de 7 o menos, sin abandono por molestias y con al menos el 70 % de la duración
total registrada. Desde `fas_running_week_v6`, también tienen que constar los
cuatro intervalos de dos minutos completos en el ejecutor. Debe caber una
sesión de 36 minutos como mínimo en el día
y en la capacidad cómoda declarada; si el día no da, permanece 4 × 2. El paso
a 5 × 2 añade una repetición, sin elevar ritmo ni acortar recuperación. Si
existe espacio, la vuelta a la calma absorbe el tiempo adicional para que la
duración total no crezca innecesariamente. Esta puerta de entrada es una
**hipótesis de producto provisional**, no un umbral fisiológico probado.
El RPE final y la duración de los tramos no demuestran que cada repetición
alcanzara la intención de intensidad: el selector fino necesitará comparar
ritmo, RPE por tramo cuando exista y consistencia. La política no elige aún 200 m, 400 m,
fartlek, T, V, S o R.

| Familia | Variantes candidatas para revisar | Dato imprescindible para elegir |
| --- | --- | --- |
| E | Rodaje cómodo; caminar/trotar de retorno | Continuidad, duración cómoda y respuesta reciente. |
| T | Bloques sostenidos controlados por tiempo | Capacidad de repetirlos sin terminar al límite; referencia provisional. |
| V | Intervalos de 2–5 min | Base reciente, historial de calidad y recuperación disponible. |
| S | Exposiciones de 200–800 m o combinaciones | Marca actual, objetivo y dosis específica ya tolerada. |
| R | Strides, cuesta corta o exposición breve | Técnica, material/terreno y ausencia de molestias. |

«15 × 200» y «10 × 400» son posibles configuraciones, no respuestas universales
del motor. Hay que definir sus requisitos, finalidad, recuperaciones, carga de
calidad y criterios de salida antes de ofrecerlas.

## Laboratorio obligatorio antes de publicar una política nueva

Usar los escenarios A–D del texto de Javier y, además, el corredor de 7:58 con
dos días de carrera recientes y 45 min disponibles por día. Simular horizontes
de 1, 3, 6 y 12 meses con respuestas buenas, irregulares y malas. Incluir
semana perdida, RPE alto en rodaje fácil, RPE alto en test máximo, nueva marca,
objetivo inalcanzable a corto plazo, cambio de 4 a 2 días, fuerza de pierna y
molestias. Comprobar como invariantes:

- Toda sesión cabe en su día y la suma de tramos coincide con la duración.
- Ninguna decisión usa ritmo objetivo como capacidad actual.
- Una mala sesión aislada no dispara una regresión completa.
- Los días y minutos de calidad respetan los límites de su política y fase.
- El historial publicado permanece versionado e interpretable.
- El plan puede evolucionar más allá de sumar minutos fáciles y también sabe
  mantener o reducir sin progresar por calendario.

El laboratorio detecta contradicciones y fallos de diseño. No demuestra por
sí solo eficacia fisiológica; esa afirmación necesitará resultados comparables
en usuarios reales. La literatura sobre programación de intervalos no ofrece
un método óptimo universal para todos los corredores:
https://pubmed.ncbi.nlm.nih.gov/33826121/.

Como referencias experimentales para revisar variantes, un ensayo de ocho
semanas comparó intervalos aeróbicos de 4 × 4 min con dos formas de sprint en
varones bien entrenados y midió 3.000 m; su población, distancia y carga no
validan una receta automática de 2.000 m para opositores:
https://pubmed.ncbi.nlm.nih.gov/36314990/. Otro ensayo en corredores
recreativos comparó prescripción individualizada con un plan predefinido;
apoya estudiar señales de respuesta, pero tampoco proporciona nuestros
umbrales de RPE o progresión:
https://pubmed.ncbi.nlm.nih.gov/36940300/.

## Decisiones aún abiertas

1. Definir los campos mínimos y las comprobaciones de calidad de una ejecución
   comparable para cada familia, sin imponer pulsómetro.
2. Revisar cada variante y sus dosis con fuentes primarias y criterio
   deportivo; separar claramente evidencia, experiencia e hipótesis de producto.
3. Fijar reglas de entrada, progresión y retirada de T, V, S y R, y cómo cambia
   su presencia según días disponibles y fase.
4. Acordar cómo se estima rendimiento actual cuando el único 2 km caduca, sin
   obligar a esfuerzos máximos innecesarios ni inventar equivalencias.
5. Definir la interfaz de carga de pierna entre carrera y fuerza.
6. Definir la revisión de objetivos demasiado agresivos y qué mensajes muestra
   la app al usuario.
7. Elegir y medir el modelo local solo después de disponer de casos deportivos
   evaluables; revisar licencia, hardware, latencia y costes operativos.
