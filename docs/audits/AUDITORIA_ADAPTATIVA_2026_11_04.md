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

Esta tabla recoge la primera pasada de auditoría. El seguimiento indica qué
fallos siguen vigentes y cuáles llegaron a una semana publicada.

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

## Seguimiento tras corregir la cronología del control

Las reproducciones siguientes usaron cuentas ficticias y `ROLLBACK` en Dev.
La corrección de cronología se valida por separado en la
[regresión de publicación](../../supabase/tests/running_transfer_control_chronology.sql).

| Prioridad | Fallo pendiente | Reproducción |
| --- | --- | --- |
| Alta | Un control de 2 km puede dejar una semana combinada sin agilidad | En una agenda de siete días de 70 min con examen a 31 días, cuatro salidas toleradas en días distintos y resultados completos de fuerza, la continuación publicó `ready` con un control de transferencia. El ajuste de recuperación retiró la única cita de agilidad y dejó una de dos exposiciones de flexiones y plancha. La propuesta publicada seguía declarando las frecuencias anteriores. Se usaron las referencias de la [auditoría de tres modos](auditoria_adaptativa_tres_modos_2026_11_04.sql) y el recorrido de [control por días distintos](../../supabase/tests/adaptive_running_control_distinct_days.sql). [Ajuste de recuperación](../../supabase/migrations/20261016195705_adaptive_control_shared_recovery_guard.sql#L107). |
| Alta | Una dosis de flexiones casi sin ejecutar puede habilitar un control | Cuatro exposiciones en días distintos se cerraron por RPC. Dos registraron `1 + 1` frente a `46 + 46`; las dos recientes sí completaron la pauta. El selector acreditó los cuatro días como tolerados y la continuación programó un control de dos minutos. La evaluación de elegibilidad mira el estado, RIR y esfuerzo, pero omite el contraste entre repeticiones observadas y pautadas. [Elegibilidad](../../supabase/migrations/20261016191546_adaptive_protocol_controls.sql#L117). |
| Alta | Dos sesiones difíciles del mismo día desencadenan una descarga global | Con dos citas de intervalos y un rodaje, duplicar las pausas de una cita mantuvo `normal`. Duplicarlas en ambas publicó `global_deload`, incluso al registrar ambas citas el mismo día real. La rama cuenta sesiones en vez de distinguir los días de la dificultad. [Condición](../../supabase/migrations/20261016202528_running_format_progression_v6.sql#L126). |
| Alta | Dos marcas de 2 km el mismo día pueden cambiar qué se publica | Se seleccionó como referencia una marca de 9:55 a las 12:00. Al añadir un control de 9:10 a las 08:00 del mismo día, la tendencia usó el de la mañana y la publicación pasó de tempo 2 × 5 min a intervalos 5 × 2 min, con la referencia de ritmo aún en 9:55. Invertir dos controles empatados en la entrada de la función también cambia su tendencia. [Selección por fecha](../../supabase/migrations/20261001008000_running_engine_response_v2.sql#L33). |
| Media | La puerta de agilidad permite avanzar con un solo día tolerado | Con la fase de desarrollo en la decisión anterior y dos frenadas `COD-T01` cerradas el mismo día por RPC, se publicaron dos sesiones `COD-SP01` aunque la fase acreditó un único día tolerado. En el selector de especificidad, dos frenadas toleradas seguidas de dificultad reciente también permiten elegir el circuito completo `COD-SP02`. [Selección](../../supabase/migrations/20261016182512_adaptive_movement_continuity.sql#L281). |
| Media | Una sesión omitida puede bloquear la siguiente calidad | Con dos rodajes tolerados y el lunes como único hueco apto para calidad, una cita de intervalos omitida el domingo dejó tres rodajes publicados. Al mover solo esa cita omitida al sábado, los RPC publicaron 4 × 2 min el lunes y dos rodajes. La regla de separación comprueba fecha y familia sin distinguir la omisión. [Separación](../../supabase/migrations/20261016202528_running_format_progression_v6.sql#L315). |
| Media | Solo carrera muestra un aviso de falta de tiempo al faltar la marca | La propuesta con cuatro huecos de 60–75 min y sin marca de 2 km pide registrar la marca y también añadir tiempo para una preparación conjunta. [Composición de avisos](../../supabase/migrations/20261016191546_adaptive_protocol_controls.sql#L600). |

El siguiente bloque recomendado es conservar la cobertura de las pruebas
obligatorias al colocar el control de 2 km. La verificación debe leer las
citas materializadas y cotejar su frecuencia con la decisión publicada.
