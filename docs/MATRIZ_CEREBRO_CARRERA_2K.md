# Trazabilidad del documento deportivo de 26 puntos: carrera de 2 km

> **Estado vigente (01/10/2026):** [Motor 2 km v2](MOTOR_CARRERA_2K_V2.md).
> Incluye motor común por programa, corrección de continuidad/RPE, margen propio
> y laboratorio de 1.573 semanas. Las referencias a pendientes de v1 o del
> piloto que siguen son antecedentes; consultar v2 para implementación actual.

## Revisión v2: correspondencia de cambios

| Puntos | Evidencia nueva | Límite |
| --- | --- | --- |
| 6, 21 | Meta libre, explícita o mínimo propio con margen; adaptador común para programas 2 km. | La meta no garantiza capacidad ni aprobar toda una evaluación. |
| 7, 8, 10 | RPE contrastado con dosis/ritmo, desconocido separado de omitido, regularidad de todos los tramos. | Falta aclaración individual de RPE y factores externos. |
| 13–15 | Progresión R y tiempo fácil dentro de calidad; segunda calidad condicionada en tres días. | Dosis y puertas operativas provisionales. |
| 16, 17 | Horizonte y fases; separación entre semanas; consolidación tras reducción por dificultad. | No prueba una periodización óptima para toda población. |
| 18–20 | Tres controles comparables y patrón V mejora/test estable; sugerir control sin elegirlo automáticamente. | Es una hipótesis de selección, no diagnóstico fisiológico. |
| 24–26 | Motor v2 único, 1.573 semanas/13 perfiles; recorridos SQL y Flutter existentes. | Validación humana y recorrido visual completo de la app pendientes. |

La matriz que sigue conserva el diagnóstico original del piloto, anterior a
v1/v2. Para código activo y pruebas, consultar `MOTOR_CARRERA_2K_V2.md`.

## Actualización 01/10/2026: motor v1

La tabla extensa posterior describe el diagnóstico **previo** a la v1. El estado
actual, fórmulas, límites y contraste de las 20 sesiones están en
[`MOTOR_CARRERA_2K_V1.md`](MOTOR_CARRERA_2K_V1.md).

| Punto | Implementado en v1 / límite pendiente |
| --- | --- |
| 1 | Núcleo común y laboratorio 4–52 semanas; adaptador real FAS. Otros adaptadores pendientes. |
| 2 | E/T/V/S/R; trabajo intenso separado del tiempo total. Calibración provisional. |
| 3 | Hasta dos calidades, separación entre días y fuerza conservadora. |
| 4 | Ancla 2 km con procedencia; no VAM ni umbral medidos. |
| 5 | Rangos estimados versionados y RPE por familia. |
| 6 | Meta libre/tiempo; exposición corta limitada al objetivo. Mínimo oficial con margen pendiente. |
| 7 | Escalones, dos tolerancias comparables y cambios auditados. |
| 8 | Trabajo, ritmo, pausas, RPE, deterioro primer/último tramo y ausencias. Regularidad completa/contexto pendientes. |
| 9 | T sostenido por duración; no equivalencia con zonas del reloj. |
| 10 | E por esfuerzo y rango orientativo; FC no interviene aún. |
| 11 | V 4×2 hasta 4×4 con escalones y encaje temporal. |
| 12 | S 200/400/600/800 y 4×500; puerta específica. Pirámides y mixtos diferidos. |
| 13 | R breve; selector usa entrada 4×15. Cuestas diferidas. |
| 14 | 2–5 días, distribución fácil/intensa y rotación. |
| 15 | Solo dosis cuyos tramos completos caben; resto de tiempo fácil. |
| 16 | General/desarrollo/específico/taper por fecha y elegibilidad. |
| 17 | Descarga de intensidad, global y taper; revisión 2:1/3:1 con exposición previa. |
| 18 | Tendencias comparables, dos patrones de foco, declive amplio y fallo aislado. Transferencia V→test 2 km pendiente. |
| 19 | Exposiciones intermedias; solicitud de control por caducidad. Cadencia personalizada pendiente. |
| 20 | Nueva ancla recalibra sin reescribir pasado ni aumentar dosis esa semana. |
| 21 | Contexto existente y meta opcional. Experiencia por continuidad, no solo marca. |
| 22 | Registrado/declarado/estimado/inferido documentado. |
| 23 | Reservas y agenda de fuerza tratadas como piernas. Motor de fuerza pendiente. |
| 24 | Catálogo, evaluación, evidencia, selección y adaptador separados. Único decisor servidor. |
| 25 | 198 semanas sintéticas e integración transaccional. No acreditan eficacia fisiológica. |
| 26 | Especificación ejecutable; el producto deportivo completo sigue abierto. |

## Diagnóstico anterior a la implementación

Estado: **análisis de requisitos, no prescripción aprobada**. Fuente: documento
de Javier «Quiero que empecemos a diseñar el núcleo del algoritmo de carrera de
EntrenaOP», entregado el 1 de octubre de 2026. Se lee como guía de diseño
completa: sus 26 apartados deben resolverse antes de declarar terminado el
cerebro de carrera. Esta matriz complementa
`ESPECIFICACION_CEREBRO_CARRERA_2K.md`; las migraciones y el código describen
lo que la app hace hoy.

**Leyenda:** «piloto» significa que existe una pieza técnica en FAS, sin
validación deportiva; «diseño» significa criterio documentado sin selector
operativo; «pendiente» exige concretar o contrastar reglas antes de codificarlas.
No se convierte un ejemplo de sesión o un porcentaje del documento en una
constante universal por aparecer en esta tabla.

| Punto | Exigencia del documento | Estado comprobable hoy | Contrato o decisión que falta |
| --- | --- | --- | --- |
| 1 | Un solo ciclo adaptativo para 1–12 meses, 2–5 días y distintos niveles. | Piloto semanal FAS; no hay planificación de meses. | Estado deportivo persistente, horizonte y reglas de revisión; demostrar el ciclo completo con ejecuciones. |
| 2 | Estímulos E, T, V, S y R; predominio aeróbico sin porcentaje fijo. | Piloto «fácil» y «calidad controlada» sin equivalencia fisiológica. | Definir intención, dosis, requisitos y límites de cada familia; medir minutos de trabajo y no solo sesiones. |
| 3 | Alternancia duro/fácil y calidad compatible con 3–5 días. | El piloto evita algunas colisiones de agenda; carece de clasificación integral de carga. | Distinguir carga metabólica, neuromuscular y de piernas; validar separación en la semana completa. |
| 4 | El 2 km es ancla de rendimiento, no umbral o VAM medidos. | Existe referencia 2 km seleccionada; hoy no calcula ritmos de entrenamiento. | Calidad y protocolo del ancla; política de estimación con incertidumbre. |
| 5 | Rangos iniciales E/T/V/S/R derivados del 2 km como hipótesis. | Solo constan en diseño. | Revisar matemáticas, población, dispersión y salvaguardas antes de activar porcentajes; versionarlos. |
| 6 | Acercamiento gradual al ritmo objetivo; brecha de objetivo condiciona la exposición. | Meta explícita y brecha definidas matemáticamente en la especificación; no implementadas. | Tres modos de meta, criterios de elegibilidad y dosis específica; no inferir capacidad desde deseo. |
| 7 | Progresar principalmente una variable por decisión. | Paso piloto 4 × 2 → 5 × 2 añade una repetición. | Registrar variable, valor previo y nuevo por estímulo; reglas de consolidación y excepción. |
| 8 | Progresar por evidencia repetida de cumplimiento, parciales, esfuerzo y recuperación. | La v6 exige dos 4 × 2 terminados, RPE y tramos completos; no compara intensidad real. | Definir «exposición comparable», parciales, degradación, motivo de fallo, confianza y ventana mínima. |
| 9 | T: acumular trabajo sostenido controlado, sin llamarlo zona 4 del reloj. | No existe selector T. | Variantes por tiempo, control de intensidad y criterio de progresión de duración frente a ritmo. |
| 10 | E: ritmo, conversación y RPE; FC solo si fiable. | Rodaje fácil por esfuerzo; datos de FC no gobiernan la pauta. | Comprobar si realmente fue fácil y cuándo ajustar duración o intensidad sin falsas zonas. |
| 11 | V: repeticiones de 2–5 min según nivel, fase y recuperación. | El 4 × 2 piloto no está clasificado ni validado como V. | Catálogo, recuperación, dosis mínima y máxima y criterios de entrada/salida. |
| 12 | S: trabajo específico de 2 km, 200–800 m o pirámides. | No hay S. | Ritmo actual/intermedio/objetivo, exposición acumulada, recuperación y comparación de parciales. |
| 13 | R: strides/cuestas cortas como exposición neuromuscular breve. | No hay R. | Requisitos técnicos, terreno, seguridad, frecuencia y carga de piernas; evitar contarlo como otra sesión dura completa. |
| 14 | Escalar de 2 a 5 días sin multiplicar indiscriminadamente la calidad. | El piloto usa disponibilidad; no distribuye T/V/S/R. | Política por frecuencia y horizonte móvil: con dos días no exigir todos los estímulos en cada semana. |
| 15 | Escalar sesiones de 30/45/60 min con distinta dosis. | La v5/v6 comprueba que quepan 4 × 2 o 5 × 2. | Duración de calentamiento, trabajo, pausas y vuelta; límites por familia y tolerancia previa. |
| 16 | Mesociclos para horizontes 1/2/3/6/12 meses, con énfasis cambiante. | **Pendiente**: la fecha objetivo no gobierna hoy la fase. | Definir estados general, específico, descarga, puesta a punto y transición; entradas y salidas por calendario **y** respuesta, sin extinguir automáticamente capacidades. |
| 17 | Carga/descarga flexible; distinguir descarga de intensidad, global y taper. | **Pendiente**: no hay política de descarga ni puesta a punto. | Señales de fatiga, carga reciente, fuerza, respuesta y cercanía a prueba; 2:1/3:1 son candidatos, no un calendario obligatorio. Definir dosis antes/después y criterios para volver a cargar. |
| 18 | Adaptar el **tipo de estímulo** según patrón de respuesta por capacidades. | **Pendiente crítico**: hoy se ajustan sobre todo minutos/variante, no se identifica qué capacidad limita el 2 km. | Estado por E/T/V/S, comparadores fiables, reglas para cambiar el énfasis, incertidumbre y una salida auditable; una sesión no basta. |
| 19 | Recalibrar sin tests máximos frecuentes; usar señales intermedias. | Hay marcas periódicas registrables; el piloto no aprovecha tendencias de sesiones. | Frecuencia/condiciones de test; comparabilidad de E/T/S, progreso y meseta sin forzar otro 2 km. |
| 20 | Nueva marca válida de 2 km actualiza el ancla sin reescribir historial. | Se conservan intentos y decisiones versionadas. | Política de recalibración y transición de dosis, procedencia y resolución de datos contradictorios. |
| 21 | Entradas mínimas: marca, meta, plazo, días, duración, experiencia/carga y fuerza. | Varias entradas existen en la preparación FAS; la meta de tiempo no. | Contrato mínimo, valores ausentes, actualización y validación por programa; no repetir preguntas del perfil. |
| 22 | Declarar medido/estimado/inferido y no fingir precisión. | Distinción conceptual en especificación; no se conserva en toda decisión de ritmo. | Tipo y confianza de cada señal, rango de prescripción y mensaje claro cuando falte evidencia. |
| 23 | Coordinar fuerza de piernas con carrera intensa. | Se pueden reservar días de fuerza; no se conoce su carga real. | Interfaz con el motor de fuerza y regla de separación de cargas, sin exigir construir ya ese motor. |
| 24 | Políticas y entidades versionadas, no un árbol monolítico de `if`. | Hay decisiones/versiones, pero la política deportiva vive en SQL extenso. | Contratos y fronteras de módulos; extraer políticas al implementar sin cambiar silenciosamente el historial. |
| 25 | Laboratorio A–D y perturbaciones longitudinales. | Hay pruebas SQL de flujo piloto; no prueban los cuatro escenarios deportivos durante meses. | Fixture y oráculo de cada escenario, semanas perdidas, fatiga, nueva marca, meseta, fuerza y cambio de días. |
| 26 | Auditar y entregar modelo, flujo, matemáticas, reglas y riesgos **antes** de programar la política completa. | Esta matriz inicia el trabajo; la especificación existente es un borrador. | Completar contratos y simulaciones revisables con los entrenos que aporte Javier antes de ampliar el motor deportivo. |

## 16, 17 y 18: la decisión que debe tomar el cerebro

El orden importa. Primero se reconstruye un estado con **procedencia de cada
dato**; después se decide la fase y la carga tolerable; finalmente se elige el
estímulo y la sesión concreta. «Han pasado tres semanas» y «RPE 8» no son por
sí solos diagnósticos de adaptación. Una regla debe poder explicar qué observó,
con qué sesiones comparó, qué hipótesis consideró y por qué eligió una dosis.

| Patrón del punto 18 | Interpretación que hay que comprobar | Acción candidata, no automática | Dato que falta para decidir bien |
| --- | --- | --- | --- |
| E/T mejoran, S no | Posible limitación específica. | Mantener base y aumentar exposición S tolerable. | Parciales comparables de S, fecha de prueba y carga reciente. |
| S mejora, sostenido pobre | Posible limitación de resistencia/continuidad. | Reforzar E/T sin duplicar calidades. | Tendencia de bloques T y rodajes a esfuerzo comparable. |
| Intervalos mejoran, 2 km no | Transferencia o mantenimiento insuficientes, o test afectado por contexto. | Revisar mezcla, recuperación y calidad del test antes de más intensidad. | Historial de varias sesiones y condiciones del 2 km. |
| Varias familias empeoran y sube el esfuerzo | Posible acumulación de fatiga, enfermedad, cambio externo o dato defectuoso. | Mantener, reducir o descargar según persistencia y señales de riesgo. | Carga de carrera/fuerza, descanso, molestias y motivos declarados. |
| Exposiciones comparables fáciles repetidas | Posible margen de progreso. | Progresar una variable de la familia prioritaria. | Dosis, ejecución y recuperación comparables. |
| Un día falla | Variabilidad normal o problema puntual. | No reescribir la progresión por ese solo dato. | Siguiente exposición o explicación contextual. |
| Fallos repetidos | Dosis o referencia posiblemente inadecuadas. | Reducir o recalibrar, según el patrón. | Comparabilidad, error de registro y carga externa. |

Para el punto 17 hay **tres salidas distintas**: menos volumen de intensidad
manteniendo movimiento fácil, reducción global de carga cuando la fatiga lo
exija, y puesta a punto ligada a la prueba próxima. La descarga no significa
inactividad obligatoria. El calendario 2:1 o 3:1 puede ofrecer una oportunidad
de revisión, pero la decisión final necesita carga y respuesta. La vuelta a
carga también requiere criterios; de lo contrario se encadenan descargas o se
rebota a una dosis que ya había fallado.

El mesociclo del punto 16 cambia el **énfasis** de las familias, no convierte
cada mes en un algoritmo diferente. Para 1 mes debe explicar qué capacidad
puede mejorarse de forma realista y cómo llega a la prueba. Para 6–12 meses
debe sostener base, exposición específica y reevaluación sin fijar de antemano
una secuencia idéntica para todos. Las fases se subordinan a salud, continuidad
y respuesta; no se aceleran solo porque la meta esté cerca.

## Matemáticas y límites de interpretación

Si el 2 km válido dura `t` segundos y el objetivo elegido `u`, velocidad actual
`v = 2000/t`, velocidad deseada `g = 2000/u` y brecha relativa
`g/v - 1 = t/u - 1`. Un 7:58 → 7:45 implica una brecha de velocidad aproximada
de 2,8 %; no demuestra que 7:45 sea alcanzable en cierto plazo. Un 11:00 →
7:30 implica aproximadamente 46,7 % y no autoriza entrenar ya a 7:30.

Para una fracción provisional `f` de la velocidad actual del 2 km, el ritmo
en segundos por kilómetro sería `t/(2f)`. Es una **transformación aritmética**,
no una validación de que `f` represente umbral, VO₂, zona 2 o intensidad
individual. La elección deportiva debe contrastarse con RPE, conversación,
parciales y respuesta en sesiones comparables. La meta oficial de aprobar y
la marca deseada son datos distintos; ningún margen de segundos se supone.

## Contratos que prepararemos con el catálogo de entrenos

Cada variante propuesta por Javier debe registrarse con: familia e intención,
población y fase elegible, requisitos de historial, duración de cada tramo,
intensidad expresable sin pulsómetro, recuperación, dosis mínima/máxima,
variable que puede progresar, respuesta que valida la sesión, motivos para
mantener/reducir/suspender y fuente del criterio. La suma de tramos debe caber
en 30/45/60 min según el día. Dos sesiones con la misma forma aparente pueden
tener fines distintos; el motor debe guardar el propósito.

La salida semanal debe incluir `estado_de_entrada`, `fase`, `familia_prioritaria`,
`candidatos_descartados`, `sesiones_y_dosis`, `variable_cambiada`,
`razones_y_confianza`, `versiones_de_politicas` y `señales_a_observar`.
La sesión se materializa en las plantillas, agenda y ejecutor actuales, y su
resultado retroalimenta el siguiente estado. Esta es la frontera para una IA
propia: podría proponer entre opciones válidas, pero el validador no aceptará
una dosis fuera del contrato.

## Laboratorio previo a nuevas reglas

Los escenarios A–D del punto 25 se deben resolver con una ficha de entradas,
semanas representativas, respuesta simulada y motivo de cada decisión. Si un
objetivo no está especificado, el ensayo usará «mejorar sin cifra» en lugar de
inventar una marca. Cada caso recorrerá inicio, progresión, descarga cuando
proceda, recalibración y fase final. Las perturbaciones del documento serán
ensayos separados. Los invariantes están en
`ESPECIFICACION_CEREBRO_CARRERA_2K.md`.

**Criterio de salida:** no ampliar el catálogo operativo por acumulación de
ejemplos. Primero cerrar con Javier la función deportiva, los límites y los
casos de laboratorio de cada familia; después implementar y versionar una
política por vez, con pruebas de dominio y del flujo de sesión real. Las
v5/v6 actuales siguen identificadas como piloto y no prueban que el cerebro
completo funcione.
