# Fuerza y rendimiento: selección y coordinación v2

**Ampliación vigente, 06/10/2026:** la estrategia/coordinador v3 conserva las
reglas submáximas y amplía fases, selección, calibración y alternativas comunes.
Este documento describe la base v2; el comportamiento nuevo, sus parámetros y
límites están en [ESTRATEGIAS_RENDIMIENTO_V3.md](ESTRATEGIAS_RENDIMIENTO_V3.md).

Estado del 04/10/2026. Sustituye el selector v1 en desarrollo mediante
`20261004003000`, `20261004004000`, `20261004005000` y `20261004006000`.
Carrera conserva `running_2k_v5`;
el coordinador aplicado es `preparation_coordinator_v2_2` desde
`20261004012000`: filtra la selección de cada programa y mantiene la coordinación
común. Su adaptador de carrera incorpora carga compatible entre preparaciones,
conservando la marca propia. Pausa/reanudación y pruebas en
`PROGRAMA_ADAPTATIVO.md`. Las reglas de dosis v2.1 no cambian. Los parámetros son
decisiones operativas revisables, no dosis científicamente óptimas.

## Referencias y responsabilidad

Una marca oficial (`official_test`), un máximo con técnica válida
(`capacity_test`), una serie realizada (`performed_set`) y trabajo repetido
(`repeated_work`) son entradas diferentes. Las marcas no tienen RIR prescrito.
Una serie basta para comenzar; varias requieren su descanso real. RIR y esfuerzo
isométrico pueden quedar desconocidos. Ni la ausencia de dato es cero, ni
repeticiones + RIR es un máximo medido, ni el objetivo deseado es capacidad actual.

Las referencias antiguas ambiguas requieren aclaración. Se pueden editar
conservando sus cifras si siguen actuales, sin reiniciar la preparación ni
repetir máximos. Las decisiones y ejecuciones guardadas conservan instantáneas.

PostgreSQL decide selección, dosis, compatibilidad y agenda. Flutter recoge y
presenta; no contiene otro selector de producción. `workout_core` comparte
mediciones, esfuerzo, codec y validación sin depender de Supabase. ADMIN mantiene
objetivos y restricciones por prueba. Su laboratorio local v1 se identifica como
histórico: no representa el planificador v2.

## Banco operativo

`performance_bank_v2()` normaliza quince estímulos con procedencia de las fichas
aportadas. Las cuarenta fichas V2 permanecen conservadas y comparadas en
`MODELOS_PROGRESION_FUERZA_RENDIMIENTO_V1.md`; no se activan todas sus recetas
por el mero hecho de estar escritas.

| Familia | Entrada y selección | Dosis y límites |
| --- | --- | --- |
| REP-T01 / REP-E01 | Repeticiones realmente realizadas; técnica para capacidad muy baja, resistencia con margen para el resto | Desde una serie: dos series al 50%, redondeando abajo. Trabajo repetido: hasta cuatro series al 70%, o 85% con margen declarado ≥3. No estima un máximo. |
| LOAD-S01 | Variante y carga realizadas; incremento disponible si se conoce | El usuario registra repeticiones reales, sin elegir el rango futuro. El servidor prescribe 4–6 para un objetivo RM y 6–10 para los demás. Doble progresión: tras consolidar el rango, solo sube un escalón declarado ≤10% de la carga. Un RM aislado pide una serie con carga y repeticiones. |
| TIME-SP01 / TIME-SP02 | Resultado de ventana temporal compatible | Fragmentos cortos/medios con identidad y duración propias. No convierte la marca en repeticiones libres ni RIR. |
| ISO-T01 / ISO-E01 / ISO-E02 | Segundos válidos y significado del registro | De 55 s aislados: 2 × 27 s. Trabajo repetido con esfuerzo ≤7: 80% de la menor duración. Técnica hasta 5/10, resistencia hasta 7/10; detenerse antes de perder postura. |
| COD-T01 / COD-SP01 / COD-SP02 | Recorrido identificado e intento real | Frenada, sectores e integración según fase y dominio declarado. Familiarización periódica del recorrido conocido también antes del último mes. No inventa tiempos de sectores. |
| POWER-P01 | Práctica conocida de potencia | Hasta tres intentos demostrados; repeticiones explosivas limitadas. Buena calidad no autoriza aumentar automáticamente altura, distancia ni volumen. |
| ROPE-T01 | Práctica de trepa con protocolo conocido | Mantiene intentos conocidos. Una marca máxima no acredita repetibilidad; no inventa progresión de altura o asistencia. |
| CARRY-E01 / SKILL-T01 | Transporte o práctica de condiciones conocidas | Trabajo reducido o mantenimiento técnico; no extrapola protocolos desconocidos. |

El contrato de repeticiones está probado también con dominadas. Suspensión usa
duración/esfuerzo, no RIR de repeticiones. La ampliación específica de cuerda
necesita ejemplos con altura, técnica de piernas, asistencia, exposición previa
y calidad. Saltos/reactividad requieren protocolo de instrumento, contactos
tolerados y progresión de intensidad. No se presentan estos vacíos como
programación avanzada completamente validada.

La práctica técnica para capacidad baja no exige tres repeticiones restantes:
pide control y detenerse al perder calidad. Cuando ni una repetición limpia es
posible, ofrece registrar una variante con apoyo o asistencia, sin convertir
su resultado en capacidad equivalente del gesto de examen.

Los cuatro ejercicios COD añadidos son perfiles y ejercicios públicos reales:
frenada de 10 m, giro de 90°, giro de 180° y sector de eslalon/recogida. No se
cambia el nombre de un circuito para simular que es otro ejercicio.

## Adaptación y calendario

Se recupera la dosis publicada del mismo estímulo y referencia. Se contrastan
fecha, protocolo, carga/masa cuando proceda, ventana, técnica, condiciones,
molestias, volumen y esfuerzo pertinente. Dos clics el mismo día no son dos
exposiciones. Falta de tiempo, omisiones, datos desconocidos y condiciones
distintas no acreditan tolerancia.

Dos exposiciones comparables toleradas permiten subir una demanda: una repetición
o dos segundos en una serie, o el escalón conocido de carga. Una dificultad
comparable reduce trabajo; las molestias requieren actualizar la situación.
Si ambas exposiciones son claramente fáciles (RIR ≥6 en todas las series, o
esfuerzo isométrico ≤4), `performance_task_v2_1` permite un ajuste de volumen
limitado al 10%, hasta tres unidades por serie. Es una regla operativa basada
en respuesta observada, no una estimación de máximo. La coordinación limita
aumentos simultáneos; trabajo descartado no consume permiso de progresión.

La fecha objetivo es de calendario. Se comprueban 1, 2, 3, 4, 6 y 12 meses
regenerando semanas desde resultados, sin proyectar mejoras futuras. La entrada
prioriza práctica/tolerancia; después llega desarrollo. Los últimos 28 días
orientan especificidad y los últimos siete reducen series/frecuencia conservando
estímulos conocidos. El calendario no acredita dominio técnico. STR-022 retira
la revisión informativa por contar cuatro decisiones: se revisa ante dificultad
reciente o transición de fase. Revisar no exige un test ni una descarga universal.
El recorrido de programa y el alcance pendiente de controles están descritos en
`PROGRAMA_ADAPTATIVO.md`.

Referencias aisladas caducadas o interrupciones sin práctica reciente piden
actualización. Historial reciente permite continuar sin repetir máximos cada
semana; el contexto general debe seguir representando la situación actual.

## Coordinación con carrera

Se comparan distribuciones semanales, frecuencia completa, una exposición y
formato corto. Se cubren objetivos antes de segundas exposiciones o apoyos. Una
referencia de apoyo que sea la única entrada de un objetivo no desaparece sin
aviso bloqueante. El formato corto reduce series, conserva técnica/margen y se
registra como dosis real; no aumenta intensidad para compensar tiempo.

Se comprueban regiones/patrones compartidos, días contiguos, otras preparaciones,
frontera entre semanas, examen y tiempo total. Dos bloques exigentes del mismo
patrón no se apilan por tener nombres distintos. Empujes y plancha comparten
apoyo de hombros y tienen una cota conjunta. La frenada/sector a velocidad cómoda
no recibe automáticamente la restricción de carrera de potencia o piernas
intensas. Son reglas conservadoras, no una puntuación universal de fatiga.

La cobertura de carrera se compara con la propuesta de su propio motor usando
la disponibilidad completa. Si caben varias salidas, se preservan al menos dos;
las reducciones se explican. Si no cabe el conjunto, pide tiempo/días y no publica
como completa una preparación sin cubrir. Estos mínimos son guardas de producto,
no garantías de una dosis semanal óptima.

En días mixtos se publica una sola sesión. Conserva segmentos, ritmos, distancias
y recuperaciones de v5, ordenados junto a fuerza. Se comparte calentamiento
general; fuerza reserva tres minutos específicos cuando ya hubo activación.
No duplica una vuelta a la calma existente. Se suman trabajo, pausas n−1 y
transición, sin llenar tiempo sobrante. La búsqueda reserva inicialmente de
forma conservadora; no optimiza exhaustivamente todas las agendas posibles.

El historial de carrera extrae solo sus tramos de una sesión mixta. Su último
tramo de trabajo pregunta por el esfuerzo del bloque de carrera; el esfuerzo
global mixto no lo sustituye. Un dato desconocido sigue desconocido. Las
ejecuciones anteriores conservan su interpretación.

## Ejemplos del servidor

Fixture: lunes/miércoles/viernes; 55 flexiones en una serie a RIR 3; máximo de
plancha de 55 s; circuito de 13 s; carrera previa de tres días y 110 minutos por
semana; objetivo a 90 días. Salidas: `docs/labs/performance_v2_server_examples.json`.

| Disponibilidad | Resultado |
| --- | --- |
| 25 min/día | Lunes 20 min: 27 flexiones, 27 s de plancha y dos intentos de frenada. Miércoles/viernes carrera. Explica frecuencias reducidas. |
| 35 min/día | Lunes 28 min: 2 × 27 flexiones, 2 × 27 s y cuatro intentos técnicos. Dos carreras; informa de la tercera que no cabe. |
| 60 min/día | Lunes mixto 53 min; miércoles mixto 52 min; viernes carrera 39 min. Tres carreras y dos exposiciones de flexiones. |

Son dosis de entrada conservadora desde datos aislados, no una rutina definitiva
para quien hace 55 flexiones. Las ejecuciones, margen y disponibilidad determinan
la siguiente dosis. Las pruebas sintéticas verifican decisiones, no eficacia.

## Interacción y continuidad

Tres pasos con respuestas conservadas: tipo/variante, dato real y contexto. En
móvil usa pantalla completa; carrera mantiene su formulario. Tiempos `7:10`,
entrada minutos:segundos o segundos, cuenta atrás para sujeciones/ventanas y
cronómetro manual para recorridos. Usar el tiempo medido es explícito: el reloj
no acredita postura. El cronómetro manual vive mientras su pantalla permanece
abierta; después de salir se puede registrar el tiempo manualmente.

RIR solo donde el estímulo lo utiliza; isometría muestra esfuerzo explicado.
Confirmar calidad es una declaración explícita, no un valor inicial. Las
condiciones estándar no necesitan redacción libre. «Montaje» deja de ser la
pregunta genérica.

Se mantiene calcular → revisar → guardar. Publicación idempotente y revisión de
pendientes sin reiniciar. Las sesiones iniciadas protegen su historial. La semana
siguiente usa la dosis efectivamente publicada, también si fue un formato corto.

## Incorporación de otro objetivo

Una ampliación debe aportar protocolo versionado, ejercicio público enlazado,
medición y condiciones comparables; relación específica/apoyo con el objetivo;
estímulo y requisitos de entrada; dosis, esfuerzo, descanso, progresión,
reducción y fase; regiones/patrones y restricciones de convivencia. Debe
identificar qué resultado devuelve el ejecutor y qué información desconocida
impide avanzar. Si usa una medición existente, reutiliza su formulario y
ejecutor. Una medición nueva exige extender y verificar el contrato compartido
y la validación del servidor, no solo añadir un nombre al catálogo.

Antes de activar la estrategia se verifican entrada baja/alta, respuesta mala,
datos ausentes, cambio de condiciones, transición de semana/fase, cobertura y
coordinación. Dominadas y press con carga ejercitan ya familias diferentes con
estos contratos; no requieren otra rama del coordinador.

## Evidencia e interacción

El ensayo de [Kotarsky y colaboradores](https://pubmed.ncbi.nlm.nih.gov/29466268/)
apoya las variantes progresivas de flexiones para fuerza, sin validar nuestro
porcentaje inicial ni una dosis óptima de resistencia para oposiciones. La
[revisión de isometría](https://pubmed.ncbi.nlm.nih.gov/30580468/) distingue
intensidad, posición e intención; no ofrece una fórmula universal de segundos de
plancha. El [estudio de técnica de cambio de dirección](https://pubmed.ncbi.nlm.nih.gov/31489929/)
apoya trabajar técnica específica con límites de transferencia desde fútbol.
El contraste adicional de RIR, fuerza y entrenamiento concurrente permanece en
el documento de modelos y sus fuentes.

Como referencias de interacción, [Hevy explica RPE/RIR](https://help.hevyapp.com/hc/en-us/articles/34490600233111-RPE-vs-RIR-What-They-Mean-and-How-to-Use-Them-in-Hevy)
y [Freeletics separa preparación, práctica y trabajo](https://help.freeletics.com/hc/en-us/articles/115004676045-Understand-your-Bodyweight-Training-Session).
Orientan claridad de registro; no son evidencia de dosificación.

## Verificación y límites

Dieciocho baterías SQL transaccionales con `ROLLBACK`: referencias, respuesta,
longitudinales, presupuestos, catálogo, publicación, sesión mixta, semana
siguiente, revisión, seguridad y regresiones/horizontes de carrera v5.
Análisis sin incidencias en ambas apps; 348 pruebas de la app y 58 de ADMIN
correctas. Compilación web de la app completada. Historial local/remoto de
migraciones comprobado en desarrollo hasta `20261004006000`.

Se inspeccionaron widgets reales a 390 px con tema de EntrenaOP, capturados en
`build/performance_v2_review/`. No equivale al recorrido completo autenticado en
el dispositivo de Javier. La revisión deportiva debe centrarse en dosis de
entrada, recuperación, respuestas muy fáciles y formatos cortos. Cuerda y
reactividad siguen limitadas a práctica conocida hasta disponer de los datos
específicos descritos arriba.
