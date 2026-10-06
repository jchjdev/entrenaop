# Estrategias de rendimiento v3

## Alcance de esta entrega · 06/10/2026

Amplía STR-029 para flexiones libres/cronometradas, plancha y cambios de dirección.
La estrategia y la selección viven en PostgreSQL; Flutter presenta estado,
previsión y calibraciones. `running_plan_v5` y
`calculate_running_week_constrained` no se redefinen en esta migración.
Las decisiones anteriores conservan su versión y sus entrenamientos.
Una lectura de fases de una pauta anterior se identifica como tal; no la recalcula.

La política auditable está en `supabase/policies/performance_strategy_v3.sql`;
`tools/build_performance_v3_migration.py` genera la migración a partir de esa
política y las fronteras vigentes. El núcleo parte de la revisión por necesidad
`20261004009000`, no recupera la cadencia antigua de tests cada tres semanas.

## Fases reales y previsión

| Énfasis | Decisión real | Trabajo |
| --- | --- | --- |
| Consolidar | Sin dos exposiciones recientes toleradas; entrada/retorno | Dosis practicable, técnica y variante accesible. |
| Desarrollar | Dos últimas exposiciones en días distintos, comparables con su propia dosis, toleradas; o continuidad de esa fase | Principal y, si procede, un apoyo calibrado. Adaptación desde resultados del estímulo, sin trasladar kilos o tiempos entre variantes. |
| Especificidad | Quedan hasta 28 días | Prioridad del protocolo. En COD no basta acercarse al examen para acreditar dominio técnico. |
| Puesta a punto | Quedan hasta 7 días | Menos series/frecuencia y gesto conocido. Sin nuevos apoyos ni máximos. |

El desarrollo no tiene una transición por acumular clics: una exposición
desconocida o difícil entre las dos últimas impide acreditar dos toleradas.
Una interrupción reinicia la comprobación; una referencia caducada necesita
práctica reciente. La dificultad reduce dosis, no obliga a hacer un test.
Se conservan entrada a la fase, semanas transcurridas, motivo y evidencia.

La previsión visual distribuye orientativamente consolidación, desarrollo,
especificidad y puesta a punto. **14/28/7 días son parámetros operativos**, no
duraciones óptimas demostradas ni un calendario de mesociclos obligatorios.
El estado real de cada objetivo puede diferir de las fechas previstas.
Un horizonte largo no cierra doce meses de sesiones: el gestor mantiene revisión
semanal de dosis y el cambio de énfasis según respuesta/fecha.

## Repertorio seleccionable

| Objetivo | Principal | Complemento admisible con referencia propia |
| --- | --- | --- |
| Flexiones libres | Estándar; inclinadas como regresión si la específica no es practicable | Flexión lastrada o banca calibrada en desarrollo. |
| Flexiones cronometradas | Fragmentos de ritmo desde medición temporal compatible; serie libre como apoyo mientras falta esa medición | Trabajo libre o carga calibrada; nunca convertir una serie con RIR en una marca temporal. |
| Plancha | Misma postura/protocolo, dosis submáxima y progresión de segundos válidos | `dead_bug` conocido como práctica de control, subordinada; no acredita tiempo de plancha. |
| COD | Frenada → sectores/giro → recorrido integrado, con calidad previa | Fuerza unilateral calibrada, cuando la relación deportiva y recuperación lo permiten. |

Se elige una práctica principal y como máximo un complemento por objetivo.
En desarrollo puede entrar un complemento inicialmente en consolidación: sus
resultados no se inventan a partir de la experiencia con el principal.
La regresión útil como complemento de plancha conserva su referencia y se
identifica como apoyo en la propuesta, sin reinterpretar su resultado.
No se activa todo el banco de 40 recetas ni el V2 indiscriminadamente.

El coordinador compara dosis normales/breves, frecuencias, distribuciones y
candidatas **con y sin apoyos**. Cubre objetivos y carrera antes de accesorios;
una pareja principal/apoyo no habilita apilar cualquier ejercicio del patrón.
Se conserva la cota de cuatro series compartidas donde corresponde y las
guardas de recuperación. No se rellena el tiempo liberado al omitir calentamiento.

## Calibración y comprobación

Las opciones sugeridas requieren material actual y referencias propias. El
diálogo preselecciona variante/medición, conserva instrucciones y pide datos
reales; no rellena repeticiones ni kilos desde otro ejercicio. La ausencia de
un apoyo opcional no bloquea el programa. Una referencia libre y otra temporal
del mismo ejercicio/objetivo pueden coexistir; recalibrar sustituye solo la
misma medición. Se mantienen referencias antiguas para historial.

Al faltar una medición temporal se sugiere registrar un resultado compatible
ya conocido. No impone repetir un máximo. El selector puede entonces utilizar
fragmentos de ritmo sin extrapolar de repeticiones libres.

Una comprobación submáxima sustituye **una primera exposición ordinaria** al
pasar de desarrollo a especificidad, solo con dos exposiciones toleradas y sin
reducción/recuperación pendiente. Pregunta: calidad y esfuerzo ante el énfasis
específico. Conserva la dosis, no añade series, se identifica en sesión y registra
las variables habituales. Actualiza capacidad de trabajo; **no actualiza la
marca oficial ni estima un máximo**. No se repite por un contador de semanas.
Los controles máximos de examen y las prioridades cuantitativas por déficit
requieren reglas propias; no quedan acreditados por este control submáximo.

## Calentamiento y ejecución

La pauta de rendimiento contiene tareas con tiempo orientativo e instrucciones:
activación suave, movilidad y ensayo específico. Total independiente 7:00;
preparación específica compartida con carrera 3:00, sin triplicar cada tarea
al componer la plantilla. Cada tarea tiene temporizador y registro propio.

«Omitir calentamiento» omite de una vez los pasos pendientes de ese bloque,
incluido modo offline mediante la cola existente. No escribe resultados
ficticios ni omite el trabajo principal. **Completarlo u omitirlo por sí solos
tienen el mismo efecto neutro en la progresión.** Las molestias y los resultados
reales siguen contando. Los segmentos nativos de carrera conservan su contrato.

## Fundamento y límites

El banco original, la composición y el V2 del usuario siguen en
`docs/references/`. Se consideran junto a
`MODELOS_PROGRESION_FUERZA_RENDIMIENTO_V1.md`, no como dosis aprobadas para
cualquier capacidad. La evidencia justifica especificidad, autorregulación y
composición; no demuestra los coeficientes ni umbrales exactos de este software.

- [Ensayo de progresiones de flexiones y banca](https://pubmed.ncbi.nlm.nih.gov/29466268/): respalda considerar ambas modalidades; no establece una receta óptima para flexiones cronometradas de oposición.
- [Revisión de entrenamiento isométrico](https://pubmed.ncbi.nlm.nih.gov/30580468/): intensidad, longitud y propósito influyen en la adaptación. No prueba que añadir dos segundos sea la progresión universal de plancha.
- [Revisión de entrenamiento para pro-agility](https://pubmed.ncbi.nlm.nih.gov/36643836/): técnicas específicas y capacidades de apoyo tienen funciones distintas. No acredita equivalencia de ese circuito con el FAS de pelota.
- [Revisión de autorregulación](https://pubmed.ncbi.nlm.nih.gov/32813181/): separar respuesta real y prescripción, sin presentar RIR/RPE como una medición infalible.

Las simulaciones hipotéticas verifican contratos, dosis, recuperación y ciclo;
no demuestran que deportistas reales consigan las mejoras simuladas.

## Verificación reproducible

`tools/build_performance_v3_preflight.py` reúne doce baterías SQL con usuarios
ficticios, SAVEPOINT y `ROLLBACK`. Incluye seis horizontes de los tres modelos
hasta la puesta a punto; dificultad/tolerancia; composición y permisos;
coexistencia de mediciones; neutralidad del calentamiento con ejecuciones reales;
alta, cierre, continuidad, pausa, recuperación y revisiones. Comprueba que las
definiciones de carrera v5 y de su adaptador no cambian dentro de la transacción.
Los tests de carrera conservan sus propios escenarios y aserciones.

La app cuenta con tests de navegación, calibración, presentación de fase real
frente a previsión y omisión completa de calentamiento. Las capturas proceden
de widgets reales con fixtures; no son una prueba autenticada del dispositivo
de Javier. La instalación y resultados finales constan en `ROADMAP.md`.
