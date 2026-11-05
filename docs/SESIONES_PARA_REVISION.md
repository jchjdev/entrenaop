# Sesiones para revisar con Javier

Extracción del 05/11/2026. Estas primeras pautas proceden del laboratorio de
dominadas, con respuesta favorable ficticia y después de tolerar la entrada
de la semana 1. Representan el bloque de tirón y sus apoyos de la semana 2.
Los calentamientos y cierres completos quedan por desarrollar en estas fichas.
Las cantidades permiten revisar qué decide hoy el ensayo. Su eficacia y su
dosis óptima requieren práctica observada.

## Cómo leer los dos circuitos

- **A** tiene 2 australianas supinas normales + 2 cerradas + 2 segundos de
  hold con agarre cerrado.
- **B** tiene 2 australianas supinas abiertas + 2 normales + 2 cerradas +
  2 segundos de hold con agarre cerrado.
- Cada receta se hace como un circuito. El presupuesto permite hasta diez
  segundos para recolocar manos entre anchos. Se mantienen altura de barra,
  posición de pies y posición del hold para poder comparar.
- Si va después del principal, hay una pausa previa de 120 segundos.
- Dos repeticiones por ancho y dos segundos de hold son la entrada experimental
  elegida. Cada circuito se calibra por separado. El objetivo de receta de A es
  5 + 5 y 5 segundos de hold. El de B es 5 + 5 + 5 y 5 segundos de hold.

## Cero dominadas, con barra alta, gomas y barra baja

Agenda combinada con carrera.

| Día | Principal | Pausa entre series | Apoyo final |
| --- | --- | --- | --- |
| Lunes | 3×5 dominadas pronas asistidas con la misma goma y montaje | 120 s | Circuito A |
| Viernes | 3×5 dominadas pronas asistidas con la misma goma y montaje | 120 s | Circuito B, primera calibración |

El calendario de ejemplo conserva la calidad del miércoles y un rodaje fácil
de 30 minutos el viernes. El bloque de tirón con apoyo ocupa 19 minutos
estimados cada día. El nivel de ayuda del guion identifica un montaje ficticio,
sin asignar kilos ni deducir una goma concreta desde la marca estricta.

## Cero dominadas, solo barra baja

Agenda de fuerza.

| Día | Principal | Forma del bloque |
| --- | --- | --- |
| Lunes | Circuito A | Una secuencia, con recolocación entre anchos |
| Miércoles | Circuito B, primera calibración | Una secuencia, con recolocación entre anchos |

El ensayo reserva cuatro minutos por bloque. Se conserva el cero en dominadas
estrictas. Progresar en el remo necesita una comprobación vertical posterior
para observar transferencia cuando exista material adecuado.

## Cinco dominadas estrictas de referencia, con barra alta, gomas y barra baja

Agenda de fuerza.

| Día | Principal | Pausa entre series | Apoyo final |
| --- | --- | --- | --- |
| Lunes | 4×2 dominadas pronas estrictas | 120 s | Circuito A |
| Miércoles | 3×2 dominadas pronas estrictas | 150 s | Circuito B, primera calibración |

El bloque de tirón con apoyo ocupa 20 y 19 minutos estimados respectivamente.
Las cinco estrictas son una referencia ficticia. La primera semana incluye
práctica de entrada para comprobar si la dosis propuesta se tolera.

## Dieciocho dominadas estrictas de referencia, con barra alta, gomas y barra baja

Agenda combinada con carrera.

| Día | Principal | Pausa entre series | Apoyo final |
| --- | --- | --- | --- |
| Lunes | 4×7 dominadas pronas estrictas | 120 s | Circuito A |
| Viernes | 13 + 6 + 6 dominadas pronas estrictas | 150 s | Aplazado por tiempo |

El viernes conserva el rodaje fácil de 30 minutos. El tirón ocupa 15 minutos
estimados y cabe en los 50 disponibles. El circuito adicional excedería ese
hueco. El lunes, principal y apoyo ocupan 22 minutos estimados.

## Qué revisar en cada pauta

1. Si la combinación tiene sentido para ese nivel y material.
2. Si las pausas, el orden y el margen de esfuerzo resultan practicables.
3. Qué señal justificaría cambiar el montaje, sustituir un ejercicio o ajustar
   el reparto entre los dos días.
4. Cómo completar el calentamiento y el cierre propios de esa sesión.

La política del circuito exige dos días recientes comparables para añadir una
repetición o, después de completar las repeticiones objetivo, un segundo de
hold. Dos dificultades comparables reducen trabajo. Una dificultad aislada o
un dato desconocido mantienen la dosis. Si el apoyo se aplaza, su historial
permanece sin una nueva ejecución. Los registros de A, B y del tirón vertical
tienen su propia comparación.

La alternancia de otros agarres verticales, las negativas de agarre contrario,
el lastre y las variantes de tronco siguen pendientes de completar en las
fichas. El [informe del laboratorio](ESTRATEGIA_DOMINADAS_PROPUESTA.md#comparación-de-australianas--05112026)
recoge las simulaciones de 26 y 52 semanas, las fuentes y sus límites.

## Dónde están los demás objetivos

El listado de revisión conjunto sigue incompleto. Estas son sus fuentes
existentes, con su estado diferenciado.

| Objetivo | Documento para consultar | Estado de las fichas de revisión |
| --- | --- | --- |
| Carrera | [Motor 2 km](MOTOR_CARRERA_2K_V6.md) y [catálogo candidato](CATALOGO_CANDIDATO_CARRERA_2K.md) | El motor implementado y las propuestas del catálogo se distinguen en esos documentos. |
| Flexiones | [Repertorio activo](CATALOGO_ACTIVO_RENDIMIENTO.md#repertorio-revisado-para-las-pruebas-actuales) y [banco original de Javier](references/2026-10-04_banco_bloques_v2_propuesta_usuario.txt) | Pendiente extraer las sesiones completas para esta revisión y cotejar cada bloque con la implementación. |
| Plancha | [Repertorio activo](CATALOGO_ACTIVO_RENDIMIENTO.md#repertorio-revisado-para-las-pruebas-actuales) y [estrategias vigentes](ESTRATEGIAS_RENDIMIENTO_V3.md) | Pendiente presentar las sesiones completas en este listado. |
| Agilidad | [Repertorio activo](CATALOGO_ACTIVO_RENDIMIENTO.md#repertorio-revisado-para-las-pruebas-actuales) | Pendiente presentar las sesiones completas por protocolo en este listado. |
| Cuerda, saltos y transportes | [Catálogo de rendimiento](CATALOGO_FUERZA_RENDIMIENTO_V1.md) | Pendiente desarrollar y contrastar sus fichas específicas. |

## Reproducción

Se ejecutó `simulatePullUps` con `PullApproach.australian`, 26 semanas y
`PullResponse.favorable`, seleccionando la semana 2. Los cuatro casos usan
las referencias 0, 0, 5 y 18, los materiales `bandsAndRows`, `rows`,
`bandsAndRows` y `bandsAndRows`, y las agendas `combined`, `strength`,
`strength` y `combined`, en ese orden. Esta extracción documental conserva
las reglas del laboratorio.
