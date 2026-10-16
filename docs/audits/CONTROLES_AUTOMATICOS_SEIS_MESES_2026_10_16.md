# Ensayo de controles automáticos · seis meses

26 semanas completadas, 102 sesiones físicas y 679 registros de series/tramos. Se utilizan las mismas marcas iniciales, metas, cuatro días y capacidades ficticias del caso FAS. Esta variante responde a los controles realmente pautados y **no añade marcas manuales de 2 km**. Las confirmaciones de salud/contexto siguen siendo intervenciones explícitas; no se fabrican desde los entrenamientos.

Los resultados de los tests son ficticios y explícitos. No prueban que alguien alcance 50 flexiones, cuatro minutos, 8:20 o 12,5 segundos. La prueba verifica programación, registro, reutilización y continuidad, no eficacia fisiológica.

## Controles pautados

| Semana | Día | Protocolo | Pregunta |
| --- | --- | --- | --- |
| 3 | 2026-11-02 | Plancha frontal sobre antebrazos | Obtener una primera marca del protocolo tras consolidar práctica tolerada. |
| 4 | 2026-11-13 | Flexión estándar | Obtener una primera marca del protocolo tras consolidar práctica tolerada. |
| 5 | 2026-11-16 | Control de 2 km | La referencia anterior ya limita decisiones de carrera; comprobarla permite recalibrar sin inventar ritmos. |
| 8 | 2026-12-11 | Plancha frontal sobre antebrazos | El trabajo tolerado ha cambiado; medir el protocolo permite revisar la referencia y la prioridad. |
| 9 | 2026-12-18 | Flexión estándar | El trabajo tolerado ha cambiado; medir el protocolo permite revisar la referencia y la prioridad. |
| 11 | 2026-12-28 | Control de 2 km | La referencia anterior ya limita decisiones de carrera; comprobarla permite recalibrar sin inventar ritmos. |
| 15 | 2027-01-25 | Control de 2 km | La referencia anterior ya limita decisiones de carrera; comprobarla permite recalibrar sin inventar ritmos. |
| 19 | 2027-02-22 | Control de 2 km | La referencia anterior ya limita decisiones de carrera; comprobarla permite recalibrar sin inventar ritmos. |
| 20 | 2027-03-05 | Flexión estándar | El trabajo tolerado ha cambiado; medir el protocolo permite revisar la referencia y la prioridad. |
| 22 | 2027-03-15 | Plancha frontal sobre antebrazos | El trabajo tolerado ha cambiado; medir el protocolo permite revisar la referencia y la prioridad. |
| 23 | 2027-03-22 | Circuito de agilidad de 16 m con pelota | Comprobar cómo se traslada el trabajo al formato de la prueba antes de la puesta a punto. |
| 24 | 2027-03-29 | Flexión estándar | Comprobar cómo se traslada el trabajo al formato de la prueba antes de la puesta a punto. |

No se pauta un test en las demás semanas. El máximo de uno por semana limita carga y no actúa como cadencia. Cada prueba sustituye trabajo y el registro conserva su protocolo. La colocación puede trasladar un control a otro día ya previsto para evitar coincidir con calidad de carrera.

## Verificación del recorrido

- Los cuatro protocolos actuales reciben controles cuando existe una oportunidad compatible.
- No se superan cuatro días ni los 60–75 minutos declarados. La estimación de cada sesión materializada coincide con la suma coordinada; se comprueba también el calentamiento al cambiar el orden.
- No hay pruebas de protocolo en los últimos catorce días antes del examen.
- Carrera reutiliza los controles de 2 km antes de continuar. Salud no se renueva automáticamente; la continuidad observada evita volver a declarar entrenamientos ya registrados.
- Una marca submáxima o una prueba interrumpida/nula no se escala a máximo. Alcanzar el techo de una plancha es un límite inferior explícito.
- El ensayo termina con ROLLBACK y las funciones recuperan su definición previa. No deja usuarios ficticios ni modifica sesiones o marcas reales.

## Confirmaciones de contexto

Semanas en que la fixture confirmó de nuevo salud/contexto: 5, 10, 15, 20, 25. No se insertó un control manual al hacerlo.

La guarda común de recuperación/datos y la protección de cargas manuales externas se contrastan además en las baterías SQL. No cambian esta trayectoria favorable: la fixture no añade esas cargas ni tiene incertidumbre real en las semanas con control. Se conservan las entradas de la guarda para distinguir un control conocido de un dato perdido.

## Límites

La aceptación física sigue pendiente. Los umbrales son guardas operativas documentadas, no un calendario científicamente óptimo demostrado. El diagnóstico de formatos ordinarios de carrera se mantiene separado: no se amplía su biblioteca ni se modifica su progresión en este bloque.

Evidencia JSON: `CONTROLES_AUTOMATICOS_SEIS_MESES_2026_10_16.json`. SHA-256: `9d0525724b5d994e0ea925548ae03d6df99e3221940ecb3f479c8bef01f5b356`.
