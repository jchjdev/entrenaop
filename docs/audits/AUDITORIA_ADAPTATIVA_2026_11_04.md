# Auditoría del sistema adaptativo · 04/11/2026

## Alcance y reproducibilidad

Punto de partida `bd33ef52` en `main`. En Supabase Dev se compararon los tres
alcances de una misma preparación FAS. Las propuestas pasan por
`preview_adaptive_program_activation` y, cuando están listas, por
`activate_adaptive_program`. Las ejecuciones del ensayo de controles usan los
RPC de revisión, inicio y cierre que usa Flutter. La comparación se hace con
datos ficticios; las consultas terminan con `ROLLBACK`. Las pruebas puras de
los motores usan `BEGIN READ ONLY`. El informe evalúa decisiones del software;
la respuesta de deportistas y la aceptación física quedan fuera del ensayo.

## Comparación de los tres modos

Nueve escenarios por tres alcances, con perfil base de 9:55 en 2 km, objetivo
8:20, dos días de carrera reciente, capacidad declarada de 30 minutos y
referencias de trabajo para flexiones, plancha y circuito. Dentro de cada fila
se mantienen las mismas entradas entre alcances. Los minutos de la tabla son
por cita, sumando el coste conjunto en los días compartidos.

| Escenario | Solo carrera | Solo rendimiento | Combinado |
| --- | --- | --- | --- |
| Cuatro días de 60–75 min | Publica 30 + 30 | Publica 25 + 18 | Publica 48 + 18 + 30. Conserva las dos salidas y las tres pruebas. |
| Dos días de 35 min | Publica 30 + 30 | Publica 25 + 18 | Queda en revisión. Una salida de dos, una exposición de plancha y una de flexiones. |
| Dos días de 40 min | Publica 30 + 30 | Publica 25 + 18 | Publica 40 + 30. Dos salidas y una exposición de cada prueba de rendimiento. |
| Dos días de 45 min | Publica 30 + 30 | Publica 25 + 18 | Publica 45 + 33. Conserva dos salidas y una exposición por prueba, con otro reparto. |
| Dos días de 50 min | Publica 30 + 30 | Publica 25 + 18 | Publica 50 + 43. Recupera la segunda exposición de flexiones y plancha. |
| Dos días de 24 min | Queda en revisión por tiempo | Publica 21 + 18 con una exposición de flexiones | Queda en revisión por tiempo de carrera. |
| Se retira el material del circuito | Publica 30 + 30 | Queda en revisión por material | Queda en revisión por material; conserva una propuesta con dos salidas. |
| Falta marca de 2 km | Queda en revisión por referencia | Publica 25 + 18 | Queda en revisión por referencia de carrera. |
| Falta referencia de plancha | Publica 30 + 30 | Queda en revisión por calibración | Queda en revisión por calibración; conserva dos salidas en la propuesta. |

En el caso base, carrera propone un trabajo sostenido de 2 × 5 min y un
rodaje fácil. Rendimiento propone dos exposiciones de flexiones `5 + 5`,
dos de plancha `36 + 36 s` y una práctica de cuatro frenadas. El coordinador
conserva las dosis y agrupa parte del trabajo en una cita, que cuesta 48 min
frente a los 55 min separados. A 35 min reduce frecuencias y bloquea la
activación por cobertura mínima de carrera. A 40 y 45 min conserva todas las
pruebas y declara las exposiciones secundarias que quedan fuera. Son resultados
de este perfil y agenda, no umbrales generales de entrenamiento.

Las 27 propuestas cumplieron disponibilidad y alcance. La vista previa no
creó agenda ni decisión. Las 18 propuestas listas publicaron una decisión
con el número de citas previsto; las otras nueve quedaron sin publicar.
[Consulta y salidas por día, propuesta y motivo](auditoria_adaptativa_tres_modos_2026_11_04.sql).

## Hallazgos reproducidos, por prioridad

| Prioridad | Frontera | Qué se observó y cuál es el límite |
| --- | --- | --- |
| Alta | Control de carrera usa sesiones como días | Cuatro citas de agenda distinta se realizaron y cerraron el mismo día local. El candidato registró `4/4/4` en sus tres contadores de días con un solo día real. Con 140 min recientes propuso el control y quedó sin colocar. Con 160 min, la continuación automática publicó y materializó un control de 2 km. La regla documentada exige días de práctica. [Recorrido por RPC](auditoria_adaptativa_controles_2026_11_04.sql), [contrato](../CONTROLES_ADAPTATIVOS.md). |
| Alta | Progresión específica y tendencia de carrera dependen del orden de un empate | Con una ejecución tolerada y una difícil de la misma fecha, invertir solo el orden cambia de 1 a 2 éxitos compatibles. La calidad pasa de S:0 de 30 min a S:1 de 35 min. En otra fixture, invertir dos observaciones aeróbicas del mismo día cambia la tendencia de mejora a empeoramiento y la calidad de T:0 a V:1. Las dos diferencias se reproducen en `running_plan_v6` instalado. El adaptador usa día de realización y UUID como desempate; la reproducción de la prescripción completa con ese empate queda pendiente por RPC. [Entradas y salidas](auditoria_adaptativa_carrera_2026_11_04.sql). |
| Media | La puerta de agilidad usa una unidad distinta de la fase | En desarrollo, una frenada tolerada conserva `COD-T01`; dos ejecuciones el mismo día eligen `COD-SP01` aunque la fase acredite un día. También avanza con una segunda observación de hace 30 días y, en otro caso, cuando la fase reconoce dificultad reciente junto a ejecuciones toleradas. En especificidad, la puerta sí distingue días recientes. La prueba acredita selección del motor, pendiente de verificar colocación en una semana publicada. [Nueve casos](auditoria_adaptativa_rendimiento_2026_11_04.sql). |
| Media | Una causa principal produce avisos que sugieren otra solución | Con agenda de 60–75 min y sin marca, la propuesta pide una marca vigente y también añade «añade tiempo u otro día». El segundo aviso se devuelve incluso en solo carrera. Con 24 min, el aviso de tiempo menciona carrera v5 aunque el cálculo actual usa v6. Flutter muestra los motivos del servidor en la propuesta. [Casos de agenda y marca](auditoria_adaptativa_tres_modos_2026_11_04.sql), [composición de avisos](../../supabase/migrations/20261016191546_adaptive_protocol_controls.sql#L601). |

En las comprobaciones adicionales, carrera conservó el tiempo de la sesión y
descartó calidad cuando solo cabían rodajes o chocaba con carga de piernas.
En la política pura, una referencia de 46 días pasó a rodaje por esfuerzo y
petición de control. La comprobación de acceso Pro y la de validación, corrección
e invalidación de controles pasaron con titulares ficticios. No se midió el
impacto de los hallazgos sobre usuarios reales ni se calibraron umbrales nuevos.

## Siguiente bloque propuesto

Corregir primero la evidencia de carrera. Empezar por hacer cumplir el contrato
ya acordado de días distintos en el control, con la reproducción que hoy llega
a materializarlo. En el mismo diagnóstico de carrera, distinguir las decisiones
que dependen de la secuencia temporal real de las que deben contar por día.
La corrección del empate debe demostrar igualdad al permutar registros y
conservar la respuesta ante dificultad; hace falta un caso por RPC antes de
cerrar ese fallo. La puerta de agilidad y los avisos se mantienen como hallazgos
separados. El diagnóstico de estancamiento depende de que las señales de base
sean fiables.
