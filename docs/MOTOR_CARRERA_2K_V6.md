# Carrera 2 km: selección y progresión v6

## Decisión PLAN-026 · 16/10/2026

Javier autoriza corregir selección y progresión para aprovechar el repertorio
activo, sin añadir variedad por apariencia, y repetir el mismo FAS de seis
meses. El diagnóstico previo se conserva como evidencia histórica en
[VARIEDAD_CARRERA_2026_10_16.md](audits/VARIEDAD_CARRERA_2026_10_16.md).
La aceptación de esta corrección no autoriza incorporar automáticamente las
sesiones candidatas pendientes ni hacer que todos los perfiles recorran todo
el catálogo.

## Problemas y corrección

1. **Comparabilidad confundida con ancla.** V5 contaba éxitos de una dosis solo
   si el ancla estaba dentro del 3 % de la actual. Una marca nueva podía
   descartar datos que todavía cumplían el ritmo, esfuerzo y recuperaciones
   vigentes. `running_dose_evidence_v6` vuelve a evaluar los parciales reales
   contra la receta de la misma familia y escalón con el ancla actual. Exige
   que la ejecución fuese tolerada originalmente y siga siendo compatible.
   Conserva la ventana de 56 días, excluye futuro y puesta a punto, y una
   incidencia posterior de esa familia reinicia el permiso de progresar.
   No transforma sesiones lentas, incompletas, con molestias o esfuerzo
   desconocido en éxitos nuevos. La tendencia fisiológica no se recalcula:
   `running_evidence_v2` mantiene sus comparadores anteriores.
2. **La meta retrasaba la progresión del formato.** En las series S cortas,
   dos éxitos podían activar +3 % de velocidad y retener el escalón, incluso
   cuando ya procedía probar el siguiente. V6 no introduce ese incremento
   desde el tiempo deseado. Progresa una dosis compatible y las marcas reales
   recalibran sus ritmos por separado. Un factor histórico se conserva mientras
   no cambia el ancla; el cambio de referencia sigue sin aumentar dosis,
   frecuencia o minutos fáciles simultáneamente.
3. **Más días expulsaban la calidad conocida.** Llegar a 75 minutos podía
   repartir tres salidas de 25, sin espacio para el estímulo previamente
   tolerado. Antes de ampliar frecuencia, v6 comprueba que esa receta completa
   quepa junto a los mínimos de las otras salidas. Si no cabe, conserva días y
   puede desarrollar minutos fáciles según las reglas existentes. No obliga
   a entrenar más días ni rellena toda la disponibilidad.
4. **Prioridad poco específica al acercarse el examen.** En desarrollo y
   especificidad se prioriza S, con las puertas de entrada y las tendencias
   observadas existentes. Si no es viable se prueban las alternativas completas;
   no se recortan repeticiones, pausas o calentamiento para publicar S a toda
   costa. En preparación general se conserva el reparto de funciones T/V/S.
5. **Reserva inviable de otra calidad.** La reserva de una pareja podía retener
   la progresión de la primera sesión aunque la segunda exigiera una familia
   todavía desconocida que el colocador rechazaría. V6 comprueba ambas familias
   antes de reservar; mantiene las demás puertas de frecuencia, trabajo y agenda.
6. **El primer día ocultaba un hueco posterior.** Si el escalón nuevo no cabía
   en el primer día elegido, se volvía inmediatamente al anterior aunque otro
   día ya previsto tuviera tiempo. V6 comprueba ese hueco con las mismas
   restricciones de recuperación antes de aceptar la regresión de formato.
   Conserva el presupuesto semanal y no añade otra salida para resolverlo.
7. **Un control consumía una práctica que había sustituido.** La propuesta
   ordinaria avanzaba su rotación antes de que el control reemplazara la calidad.
   En la siguiente decisión parecía haberse practicado T aunque solo se hubiera
   realizado el test. El adaptador normaliza ese contador, con
   `running_previous_evidence_v6`, si el control tipado sustituyó la única
   calidad y no hubo recalibración que ya hubiera impedido avanzar. La operación
   es idempotente, conserva el historial y distingue tests de sesiones de trabajo.
   Queda auditada como `running_control_evidence_v1`; no modifica la política
   pura v6 ni las semanas guardadas.

Cada dosis seleccionada conserva los datos utilizados por el permiso de
progresión: número de ejecuciones revisadas, compatibles, sus fechas, anclas,
ritmos y esfuerzo. Una incompatibilidad con el nuevo ritmo no se presenta como
pérdida de forma ni borra el resultado original.

## Fronteras conservadas

Se añade `running_plan_v6`, manteniendo v1–v5 reproducibles. El adaptador vigente
elige v6 para nuevas propuestas y acepta evidencia de las seis versiones. Las
semanas publicadas se conservan con su versión; no se reescriben prescripciones
ni ejecuciones. No cambia el contrato de Flutter, el ejecutor, las tablas, los
derechos o las reglas RLS.

Se conserva el catálogo v2, sus constructores y sus recuperaciones temporales:
no aparecen 10×400, 15×200, 1 km o recuperaciones de 200 m por esta corrección.
También se conservan calentamiento y cierre completos, límites de tiempo,
puertas de series largas, control del esfuerzo, reentrada, descarga, puesta a
punto, vigencia de salud y referencia, segunda calidad y coordinación con fuerza.
Los controles de PLAN/STR-041 siguen sustituyendo trabajo y reutilizando marcas.

## Evidencia deportiva y límites

La revisión de [Buchheit y Laursen](https://pubmed.ncbi.nlm.nih.gov/23539308/)
explica que intensidad, duración, repeticiones y recuperaciones cambian el
estímulo cardiovascular y mecánico. Fundamenta revisar la sesión completa y
su intención; no valida una escalera universal 200→400→800 ni los umbrales del
software. Los ensayos de [intervalos de distinta duración e intensidad](https://pubmed.ncbi.nlm.nih.gov/23679147/)
ilustran intervenciones distintas, sin demostrar que el formato más largo sea
siempre mejor para cada corredor.

El ensayo [Run Clever](https://pubmed.ncbi.nlm.nih.gov/29527322/) no halló una
diferencia significativa en riesgo de lesión entre sus progresiones de volumen
e intensidad. No permite vender nuestra regla de una demanda por decisión como
garantía de seguridad. La mantenemos como guarda operativa conservadora.

Dos respuestas compatibles, ventanas, fases y umbrales son parámetros operativos
versionados, pendientes de calibración física. El modelo de ritmo estimado desde
2 km no equivale a medir umbrales fisiológicos. Las simulaciones contrastan
decisiones y límites, no predicen adaptaciones ni garantizan las metas.

## Resistencia y estancamiento en 2 km · 04/11/2026

En un estudio de seis semanas y 20 participantes, tanto la carrera continua
como los esprints de 30 segundos en cinta mejoraron el tiempo de 2 km. Los
protocolos fueron distintos, así que el resultado apoya varias vías de trabajo
y no fija su reparto en EntrenaOP. En otro ensayo, 30 corredores con experiencia
fueron asignados a entrenamiento concurrente o control durante diez semanas;
se observó una diferencia de 11,3 segundos favorable al concurrente en 2 km.
Los participantes corrían más de 30 km semanales antes del estudio.
[Macpherson et al.](https://pubmed.ncbi.nlm.nih.gov/20473222/),
[Trowell et al.](https://onlinelibrary.wiley.com/doi/full/10.1111/sms.14092).

El ensayo de Nevin de 2026 midió 2 km en 48 soldados británicos entrenados.
Su resumen informa de ventajas claras en peso muerto y dominadas; el
resultado de carrera no establece superioridad del programa para este
objetivo. En 3 km, Hov observó que 4 × 4 min produjo mayor mejora que uno
de los dos formatos de esprint comparados en hombres entrenados. Es apoyo
indirecto para incluir intervalos aeróbicos, con dosis y población distintas
de las de nuestro caso de 2 km.
[Nevin et al.](https://pubmed.ncbi.nlm.nih.gov/41576259/),
[Hov et al.](https://pubmed.ncbi.nlm.nih.gov/36314990/).

Reutilizamos del banco de Javier las funciones de rodaje fácil, bloques
sostenidos, intervalos aeróbicos y práctica específica. Los formatos largos
como 3 × 800 conservan sus condiciones de entrada. Una marca repetida no
informa por sí sola de que falte velocidad, volumen o recuperación.
[Catálogo candidato](CATALOGO_CANDIDATO_CARRERA_2K.md).

### Comparación ejecutada en Dev

El [diagnóstico SQL](audits/estancamiento_carrera_2k_2026_11_04.sql) usa el
perfil ficticio de 9:55 con objetivo de 8:20, aislado de fuerza, con tres
controles fijos de 9:55 y cuatro exposiciones al mismo formato de intervalos.
Las respuestas son entradas de prueba. Se consultó la política instalada
en solo lectura y con `ROLLBACK`.

| Respuesta a los intervalos | Tendencia de intervalos | Próxima calidad |
| --- | --- | --- |
| Ritmo y esfuerzo iguales | Estable | V, de 4 × 2 a 5 × 2 min |
| Ritmo igual, esfuerzo baja de 7 a 6 | Estable | V, de 4 × 2 a 5 × 2 min |
| Mejor ritmo a esfuerzo similar | Mejora | T, 2 × 5 min sostenidos |
| Esfuerzo ausente en las últimas dos exposiciones | Desconocida | V, mantiene 4 × 2 min |

La marca de 2 km se mantiene estable en los cuatro casos. El motor ya
reconoce series más rápidas a esfuerzo comparable sin mejora de la marca y
refuerza el trabajo sostenido. Usa el esfuerzo para valorar tolerancia y
comparabilidad, pero la tendencia por familia se calcula por ritmo. Por eso,
en la segunda fila no aparece como señal que el mismo trabajo costó menos.

La misma consulta contrasta otros ocho escenarios con la marca fija. Los
resultados proceden de la política instalada en Dev, en solo lectura.

| Última semana o cambio observado | Respuesta de v6 |
| --- | --- |
| Una calidad con pausas prolongadas | Consolida el 4 × 2 min. |
| Pausas prolongadas en la misma calidad durante dos semanas | Descarga global. |
| Semana sin registros | Mantiene la decisión sin inferir inactividad. En la fixture no prescribe calidad. |
| Las tres salidas constan como omitidas | Reentrada con reducción. |
| Interrupción por falta de tiempo | Consolida el 4 × 2 min. |
| Dos dosis completas con esfuerzo alto y sin dificultad objetiva | Mantiene el 4 × 2 min y propone revisar la escala de esfuerzo. |
| Solo una exposición a menor esfuerzo | Misma tendencia y prescripción que la referencia. |
| Cambia solo el pulso | La respuesta completa del motor es idéntica a la referencia. |

La revisión distingue **ritmo, esfuerzo y marca** antes de concluir que el
corredor lleva tiempo sin mejorar. En el ensayo de
Nuuttila con corredores recreativos, una prueba de campo a esfuerzo percibido
fue reproducible y tuvo sensibilidad limitada para cambios pequeños. Su
protocolo evalúa velocidad a esfuerzo fijado, por lo que no valida un punto de
RPE a ritmo fijo como umbral para EntrenaOP. La comparación
exploratoria de dos exposiciones iniciales con dos recientes, todas toleradas,
detectó el descenso repetido de esfuerzo y se abstuvo ante un único descenso,
pausas alargadas o datos insuficientes. Los límites sirven para las fixtures.
La comparación de sesiones reales sigue requiriendo dosis, pausas y condiciones
equivalentes. Los rodajes de Javier son útiles para comprobar comparabilidad
por tramos, con evidencia insuficiente para afirmar una meseta en 2 km.
[Nuuttila et al.](https://pubmed.ncbi.nlm.nih.gov/39244198/).

### Cuándo mostrar menor esfuerzo

Javier descartó este aviso tras el [ensayo local](audits/mismo_trabajo_menos_esfuerzo.mjs).
El texto ensayado para el resultado más reciente de una pauta por distancia fue
«En las dos últimas sesiones comparables, anotaste menos esfuerzo para el
mismo trabajo». Compara las cuatro últimas ejecuciones de esa pauta en días
distintos, en un máximo de 56 días entre la primera y la última. Los dos
esfuerzos recientes deben ser inferiores a ambos anteriores, con la misma
escala y el mismo alcance de la valoración (bloque o sesión). Una sola pareja,
un valor aislado o un dato ausente dejan la observación sin mostrar.

| Comprobación | Márgenes del ensayo |
| --- | --- |
| Trabajo completo y misma secuencia | Cada distancia medida queda a un 2 % o menos de la pautada. |
| Ritmo comparable | Diferencia de hasta el 3 % por parcial y del 2 % en la media de ritmos. |
| Recuperación comparable | Mismo tipo. La diferencia de duración admite hasta el menor de 10 s y el 10 % por pausa. Para distancia admite el mayor de 10 m y el 20 %. Se admiten hasta 10 s fuera del temporizador sin asignar. |
| Contexto y resto de la sesión | Misma ruta, sentido, superficie y condiciones de exposición al viento. Hasta 3 °C y 10 km/h de diferencia. Hasta 2 min de diferencia tanto en calentamiento como en vuelta a la calma. |

Los límites son hipótesis de trabajo. Los 30 escenarios ficticios cubren
variaciones pequeñas, diferencias que la media oculta, duplicados, orden
invertido y la falta de datos. El ensayo se ejecuta con
`node docs/audits/mismo_trabajo_menos_esfuerzo.mjs`.

Al contrastar las sesiones reales de Javier, los bloques largos tuvieron
parciales muy parecidos y menor esfuerzo anotado, con otra forma de recuperar
y distintas condiciones. En las series cortas se observó menor esfuerzo a un
ritmo más rápido y pausas fuera del temporizador que no se pudieron localizar.
Ambas parejas quedan como observaciones privadas del historial. Los datos
normalizados actuales no garantizan contexto ni tipo real de recuperación. Si
no hay información suficiente, la regla se abstiene. La frecuencia cardíaca
queda fuera de la comparación.

### Orden del entrenamiento y del control de 2 km

En Dev, dos series recientes más rápidas a esfuerzo similar llevan a v6 a
proponer 2 × 5 min de tempo con el motivo «series mejoran sin transferencia al
2 km». La decisión aparece incluso cuando el último control comparable de
2 km es anterior a las dos series mejoradas. También aparece si el control se
hizo entre ambas. En los tres casos, las marcas registradas son de 9:55.

La [reproducción SQL](audits/estancamiento_carrera_2k_2026_11_04.sql) mantiene
el mismo historial de entrenamiento y mueve la fecha de los controles. Al
retirar su tendencia en los dos casos anteriores, el cálculo de laboratorio
propone 5 × 2 min de intervalos, con la misma referencia de ritmo y agenda.
Así se aísla el efecto de usar una tendencia de marcas que precede a las
series. Los dos formatos son salidas del cálculo, sin pronóstico de mejora en
el examen.

La [prueba por RPC](audits/cronologia_control_carrera_rpc.sql) registra las
mismas ejecuciones en dos preparaciones ficticias. Comprueba que ambas publican
2 × 5 min, con el último control antes o después de las series mejoradas, y
revierte la transacción en Dev. El siguiente paso es probar que el cambio de
familia por falta de transferencia exige un control posterior a las sesiones
que sustentan la mejora, con la misma referencia y calendario de controles.

## Orden de ejecuciones del mismo día · PLAN-028

El día local delimita las ventanas de historial. Dentro del día, v6 ordena
por el instante observado. Los registros sin hora se sitúan antes de los
que la tienen. En un empate de hora o si falta en ambos, el motor compara
fecha programada, receta y datos deportivos de la ejecución. Ese desempate
es reproducible y no acredita una hora real. Ni el UUID ni la hora de
recepción deciden qué ejecución se considera posterior.

La revisión `running_history_sequence_v1` queda en la evidencia de las nuevas
decisiones. El mismo orden alimenta la dosis compatible, la selección de
observaciones y las dos parejas de la tendencia por familia. Se conservan
las reglas de progresión, el catálogo y las publicaciones existentes.

- [Regresión por RPC](../supabase/tests/running_same_day_publication.sql).
  Compara las recetas materializadas al intercambiar el orden de los UUID con
  idénticas realizaciones y recepciones. Antes se publicaban `6×200` y
  `8×200`. Ahora ambas publican `6×200` si la dificultad fue posterior.
  Invertir solo las horas de realización permite `8×200`. El historial de
  partida y los inicios offline son sintéticos. La vista previa, el registro
  de resultados, el cierre y la publicación se ejercitan por los RPC.
- [Tendencia e histórico sin hora](../supabase/tests/running_same_day_evidence_v6.sql).
  La tendencia y la propuesta conservan el resultado al permutar el historial
  y los metadatos de recepción. Cambiar la cronología observada sí puede
  invertir la tendencia.
- [Recetas específicas](../supabase/tests/running_format_progression_v6.sql).
  Los perfiles con práctica compatible reciben `5×400`, `4×600` y
  `3×800` m. La prueba verifica las distancias y el número de repeticiones.

La [revisión de estudios sobre 2 km y oposiciones](audits/EVIDENCIA_CARRERA_2KM_2026_11_04.md)
separa los resultados en aspirantes y militares de los obtenidos en otras
distancias o poblaciones. Se registra como base para el análisis deportivo
posterior. Esta corrección se limita a la secuencia de registros.

## Primera sesión de calidad · PLAN-029

El barrido anual encontró una semana con `5×400` en 32 minutos. Al buscar
una segunda calidad, el motor intentaba reconstruir la primera con
`10×200`. Las pausas de esta última requieren 38 min 40 s en total con el
ancla del caso. La reconstrucción devolvía una receta vacía y el coordinador
marcaba la semana como pendiente de carrera.

V6 conserva el `5×400` y los tres rodajes si ese intento de reparto falla.
La corrección protege la receta completa, incluidas las recuperaciones.
La [regresión por RPC](../supabase/tests/running_second_quality_publication.sql)
prepara las recetas históricas de una cuenta ficticia, registra los resultados
por los RPC y verifica los tramos de trabajo de la semana publicada. El
barrido longitudinal añade la trayectoria con tres semanas sin entrenar que
reveló el caso y comprueba los horizontes de 26 y 52 semanas.

## Registro manual del 4×2 por tiempo · PLAN-031

En la receta `V_0_v1` de v6 se pueden guardar los tramos pautados por tiempo
con la distancia en blanco. La app conserva los metros si el deportista
los introduce y usa las mismas reglas al corregir un resultado. Se registra
la duración real, las pausas prescritas y el esfuerzo declarado. Una serie
pautada en metros conserva su validación de distancia.

El motor registra la tolerancia por tiempo con cuatro tramos suficientes,
pausas compatibles y esfuerzo dentro del límite. En el registro por tiempo,
una repetición omitida con las otras tres registradas se conserva como
trabajo parcial y orienta a consolidar. Ante un esfuerzo alto se conserva
la señal de dificultad. Se
reutilizan las tolerancias de duración y recuperación de v6. La evidencia
de ritmo anterior permanece disponible y los tramos por tiempo sin distancia
quedan fuera del cómputo de parciales compatibles para subir escalón.

La [prueba por RPC](../supabase/tests/running_v0_manual_time_results.sql)
guarda 119 s de trabajo y 121 s de recuperación frente a 120 s previstos,
repite el guardado, corrige y calcula la siguiente semana. También cubre
una repetición omitida, esfuerzo 9/10 y una serie por distancia.

## Pulso y cierre desde el reloj

La frecuencia cardíaca recibida se conserva para consulta y queda fuera de las
decisiones del plan. El cálculo usa duración, distancia, pausas y esfuerzo
según la evidencia disponible. El reloj que grabó el entrenamiento y el sensor
que midió el pulso pueden ser distintos. El ensayo de rodajes queda como
antecedente de esa decisión. [Evidencia](audits/PULSO_RODAJES_COMPARABLES_2026_11_04.md).

Una carrera de preparación con receta compatible y retorno asociado puede
quedar completada con las mediciones del reloj. La valoración de la dosis usa
lo observado y el esfuerzo declarado si existe. Un parcial recortado conserva
sus metros y tiempo reales, y un esfuerzo ausente queda sin registrar. El
alcance actual de Apple y Garmin para la preparación es carrera. El recorrido
de fuerza de Garmin corresponde a las asignaciones profesionales compatibles.

La [prueba transaccional](../supabase/tests/adaptive_running_device_completion.sql)
materializa dos citas de carrera de preparación. El retorno Apple y la
conciliación Garmin verifican en Dev el estado completado, los datos observados,
el pulso guardado y un solo cierre ante el reenvío. Usa observaciones sintéticas
y revierte la transacción. La aceptación desde relojes físicos queda aparte.

## Desviaciones leves de ritmo · PLAN-032

El rango pautado orienta al corredor. El historial distingue un pequeño
exceso o defecto de ritmo e indica si conviene aflojar o acelerar. La
tolerancia del motor para cada ritmo sigue siendo la de la política vigente.
La desaceleración entre el primer y el último tramo acredita dificultad
por ritmo cuando rebasa su umbral relativo y el último parcial también
rebasa el margen lento de la receta. Una transición entre 3:38 y 3:53/km
con objetivo 3:40–3:50/km puede acreditar tolerancia con la dosis, pausas
y esfuerzo compatibles.

La [regresión](../supabase/tests/running_small_pace_deviations.sql) compara
ambos órdenes de parciales, verifica la evidencia para la siguiente dosis
y conserva las señales de esfuerzo alto, exceso de velocidad, caída tardía
fuera del margen e irregularidad entre tramos.

## Verificación

Instalado y verificado en desarrollo el 16/10/2026:

- Análisis Flutter limpio; 923 pruebas de raíz correctas y una omisión web.
- Las 29 baterías SQL pasan con `ROLLBACK`, incluidos publicación, reinicio,
  evidencia antigua/nueva, fuerza, controles, tiempo compartido, aislamiento y
  las mismas 78 trayectorias de 1–12 meses (1.573 semanas) ejecutadas también
  con la política pura v6. Se conservan los oráculos y la cobertura de v5.
- Las dos fixtures históricas de publicación/reinicio avanzan ahora por fechas
  reales con el reloj del ensayo completo: no dan por entrenada una semana
  futura al ejecutar sus citas hoy. Los derechos de prueba son explícitos y
  limitados al usuario ficticio; el reloj comercial permanece independiente.
- Coinciden 154 migraciones locales/remotas y 25 cuerpos instalados. Las cinco
  migraciones cotejadas coinciden con sus sentencias registradas, y el núcleo
  v5 y los catálogos/constructores anteriores permanecen intactos. Los avisos
  de seguridad conservan el recuento previo; no se declaran corregidos aquí.

El [mismo caso FAS de seis meses](audits/FAS_SEIS_MESES_CARRERA_V6_2026_10_16.md)
completa 26 semanas, 101 sesiones y 689 registros, con doce controles automáticos,
sin marcas manuales, exceso de días o minutos, ni datos persistentes de ensayo.
Se comprueban por igualdad las marcas, metas, disponibilidad, material y curvas
de capacidad ficticias respecto a STR-041. Los resultados responden al trabajo
realmente pautado: no se fuerzan los formatos ni las marcas finales.

En este perfil aparecen 2×5 y 2×6 min, 4×2 min y 6/8×200 m. No recibe 400/800 m:
no ha reunido su tolerancia específica y esos formatos no se insertan para
embellecer el informe. Las regresiones sí prueban que 400 y 800 son alcanzables
en perfiles con el trabajo previo necesario. El cambio no acredita que toda
sesión candidata esté conectada ni que la trayectoria sea fisiológicamente
óptima. Aceptación física, anualidad conjunta y estrés de concurrencia siguen
pendientes.
