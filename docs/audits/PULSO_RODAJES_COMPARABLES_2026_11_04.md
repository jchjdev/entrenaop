# Frecuencia cardíaca en rodajes comparables

Ensayo previo del 04/11/2026. La simulación se ejecuta fuera de la aplicación.

## Qué llega a EntrenaOP

| Origen | Dato comprobado | Límite de la comparación |
| --- | --- | --- |
| Garmin | El lector FIT toma `avgHeartRate` y `maxHeartRate` del resumen. El cierre automático de una ejecución de carrera puede guardar ambos. | El lector de carrera inspeccionado toma tiempo, distancia y marcas de las vueltas. Su contrato no entrega una serie de pulso ni distingue muñeca y banda de forma fiable para esta comparación. |
| Apple Watch | El puente toma media y máxima de las estadísticas de Salud cuando existen. Puede recibir estadísticas por fase, si Salud las devuelve. El cierre asociado y el enriquecimiento tardío conservan la medición en la ejecución. | Las estadísticas por fase pueden faltar y el resumen por sí solo no acredita cobertura del sensor o continuidad del esfuerzo. |

El historial personal importado y el resultado de una pauta son recorridos
distintos. La evidencia que usa v6 para decidir incluye tiempos, metros,
pausas y esfuerzo. El pulso medio y máximo quedan para consulta. Un resumen
de sesión mixta puede incluir otros esfuerzos. Para estudiar la señal interesa
una carrera continua aislada o un tramo estable identificado en ambas salidas.

## Evidencia

- La repetibilidad depende del protocolo. En 44 personas que repitieron una
  prueba submáxima de carrera durante cinco días, Lamberts y colaboradores
  observaron variación incluso con la hora controlada. En la etapa más
  repetible, a alrededor del 90 % de la FC máxima, comunicaron una variación
  de 5 ± 2 lpm. La etapa y su duración difieren de un rodaje suave de 30 min.
  [Estudio de repetibilidad](https://pubmed.ncbi.nlm.nih.gov/15320683/).
- En la comparación de Pasadyn y colaboradores en cinta, el acuerdo con el ECG
  dependió del modelo y de la velocidad. En trail de intensidad variable,
  Navalta y colaboradores encontraron errores importantes para el fēnix 5
  frente a la referencia de banda. Los resultados corresponden a los relojes
  y condiciones ensayados. [Cinta](https://pmc.ncbi.nlm.nih.gov/articles/PMC6732081/)
  · [Trail](https://journals.plos.org/plosone/article?id=10.1371%2Fjournal.pone.0238569).
- En 24 corredores recreativos, Nuuttila y colaboradores observaron que la
  FC de reposo o ejercicio no respondió tan sistemáticamente a la sobrecarga
  como las medidas subjetivas. Un ensayo de individualización del mismo grupo
  combinó varias señales y estudió rendimiento en 10 km. Su resultado no
  permite aislar el valor de la media del reloj para ajustar un plan de 2 km.
  [Sobrecarga](https://doi.org/10.1002/ejsc.12115)
  · [Ensayo de individualización](https://pubmed.ncbi.nlm.nih.gov/35975912/).
- En un experimento con ciclistas de resistencia, el calor y la deshidratación
  aumentaron la FC durante el ejercicio. Esto justifica tener en cuenta el
  entorno, sin extrapolar una corrección numérica a los corredores.
  [Experimento fisiológico](https://pubmed.ncbi.nlm.nih.gov/9104860/).

## Ensayo reproducible

```sh
node docs/audits/pulso_rodajes_comparables.mjs
node --test supabase/functions/tests/garmin_activity_test.ts
```

Se comparan medianas de tres rodajes de referencia y tres recientes. La
referencia simulada es 30 min a 6:00/km y esfuerzo 3/10. La comparación
requiere mismo sensor, misma ruta, esfuerzo registrado y rodaje continuo,
con márgenes respecto a la referencia de ±5 s/km, ±2 min y ±3 °C, y cobertura
de pulso de al menos 90 %. Cada ejecución cuenta una vez. Estos márgenes y
los umbrales de 3, 5 y 8 lpm sirven para tensionar la regla, sin calibración
clínica o deportiva ni estimación de precisión real.

| Escenario sintético | Resultado con 5 lpm |
| --- | --- |
| Mediana de 146 a 139 lpm, igual ritmo y esfuerzo | Pulso menor repetido, tanto con Garmin como con Apple Watch. |
| De 146 a 153 lpm, esfuerzo de 3 a 4 | Suben pulso y esfuerzo. La señal describe lo registrado. |
| Misma subida con esfuerzo 3 | Señales discordantes. |
| Lectura aislada de 168, junto a 146 y 147 | La mediana absorbe el valor aislado. |
| Calor, cuestas, ritmo más rápido, pausas, sensor nuevo, datos ausentes o duplicados | Comparación insuficiente. |
| El sensor mide 7 lpm por debajo en las tres salidas y el resumen parece válido | El sesgo simula una bajada auténtica. Con estos campos es indistinguible. |

Los 25 escenarios se verificaron en ambos órdenes. A 3 lpm aparece una señal
con cuatro pulsaciones de diferencia. A 8 lpm se pierde el cambio de siete.
La simulación comprueba el comportamiento lógico y sus límites. La recepción
se contrastó aparte con las 12 pruebas del lector FIT y la prueba SQL de
métricas tardías de Apple en Dev, con `ROLLBACK`. Ninguna de estas pruebas
constituye una muestra longitudinal real de deportistas.

## Validación retrospectiva pendiente

Reutilizar rodajes ya hechos con permiso, agrupados por persona, ruta y sensor,
y revisar ritmo, esfuerzo, duración, paradas y contexto. Si hay datos por
tramos, usar la misma parte estable después del calentamiento. La media de
toda la actividad solo es comparable si su composición y cobertura lo son.
Registrar cuántas salidas se descartan y por qué. Usar semanas estables para
medir la variación de cada persona y reservar semanas posteriores para
comprobar la señal, primero en paralelo al plan. Cuando exista una medición
simultánea de banda, permite contrastar cambios dudosos del sensor óptico.
La comparación debe mostrar si añadir pulso aporta algo frente a ritmo y
esfuerzo solos. La primera aplicación a evaluar sería mostrar una observación
al deportista. Cualquier cambio de carga requeriría un ensayo separado.
