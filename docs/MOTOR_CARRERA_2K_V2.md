# Motor de carrera 2 km: revisión v2

> La selección activa es [v3](MOTOR_CARRERA_2K_V3.md). Este documento y su
> visor conservan el estado v2; no representan las nuevas decisiones.

Estado comprobado el 01/10/2026: **implementado en Supabase de desarrollo**,
con parámetros deportivos provisionales. Amplía [v1](MOTOR_CARRERA_2K_V1.md),
que conserva el catálogo, fórmulas y contraste individual de las 20 sesiones
originales con los 26 puntos. No es una certificación de eficacia deportiva.

## Un motor para los programas de 2 km

`20261001008000_running_engine_response_v2.sql` contiene interpretación,
evidencias, objetivos, tendencias de controles y planificador puro v2.
`20261001009000_running_program_adapter.sql` resuelve las fuentes y publica.
La política recibe estado y fecha explícitos; los adaptadores autenticados
reconstruyen esos datos desde la preparación propia. Flutter no decide sesiones.

Fuentes admitidas: evaluación periódica FAS; evaluación oficial o control de
Tropa; evaluación configurable con una prueba vinculada desde ADMIN al módulo
`running_2000m_v1`. No basta con escribir «2 km» en el nombre. El vínculo exige
distancia, unidad, dirección y protocolo compatibles. Una evaluación con más
de una marca válida vinculada al módulo se rechaza como ambigua.

Las RPC `calculate_running_week`, `preview_running_initial_week`,
`preview_running_next_week` y `publish_running_week` usan el mismo núcleo.
Los nombres FAS anteriores son alias de compatibilidad. Se preservan versiones
anteriores para trazabilidad, sin una segunda política activa de publicación.
Todas las sesiones siguen `workout_templates → bloques/items/sets → agenda →
start_scheduled_workout → complete_workout_set → finish_workout_execution`.
Publicar es idempotente y una semana publicada no se reescribe.

## Interpretación y RPE

| Evidencia | Decisión operativa |
| --- | --- |
| Sesión completada sin parciales suficientes | Desconocida: mantener y pedir completar datos; no inferir inactividad. |
| Todas las sesiones explícitamente omitidas o hueco de semanas publicadas | Reentrada, sin recuperar sesiones atrasadas. |
| RPE alto aislado | Consolidar, sin concluir pérdida de forma. |
| RPE alto repetido, dosis completada, sin dificultad objetiva | Mantener minutos y señalar revisión de la escala; no aumentar ni recortar volumen automáticamente. |
| Dificultad objetiva repetida | Reducción global, conservando frecuencia si caben salidas mínimas. |
| Ritmo demasiado rápido respecto a la pauta | Fuera de intención; no se premia con más intensidad ni se interpreta como pérdida de capacidad. |

Se consideran señales objetivas **dentro del registro manual**: trabajo
incompleto, mayoría de tramos demasiado lentos, recuperación alargada, caída
de ritmo o irregularidad de T/V/S. No son datos verificados por sensores.
En v2 se examinan todos los parciales: desviación máxima respecto a su mediana
>8 % en al menos tres tramos T/V/S es una señal operativa provisional.
Una E antigua se reconstruye como duración por esfuerzo, sin inventarle un
ritmo objetivo retrospectivo. La calidad antigua sin ficha sigue desconocida.

El motor no puede decidir si un RPE alto coherente con la dosis significa
fatiga, calor o una escala mal entendida. Se muestra una explicación en la
propuesta; falta una entrevista breve de aclaración y calibración individual.
No hay corrección automática del RPE del usuario ni diagnóstico de su estado.
Los porcentajes de ritmo y techos RPE siguen siendo estimaciones provisionales.

## Progresión, calendario y punto 18

- Se permite aumentar minutos fáciles dentro de una sesión de calidad para que
  pueda caber después un escalón mayor, sin aumentar ambas cosas a la vez.
- R puede recorrer 4×15 → 6×15 → 6×20 s tras tolerancia repetida.
- Dos calidades pueden caber con tres días, al menos 120 minutos y cuatro
  exposiciones de calidad toleradas, siempre sin señales recientes adversas.
- Se comprueba separación de intensidad también entre domingo y lunes y para
  R/taper. La fuerza reservada y las sesiones existentes bloquean colisiones.
- Tras una reducción global por dificultad, la base es el volumen reducido:
  primero se consolida, después se vuelve a progresar. No se restaura de golpe
  la carga previa. Las descargas programadas de intensidad son otro caso.
- Las fases siguen la distancia a la fecha objetivo (>56, 29–56, 8–28 y ≤7 días).
  El calendario no autoriza saltar los requisitos de 3×800 o 4×500.
- Cuatro ejecuciones comparables permiten tendencias por familia. Se acepta
  variación de ancla hasta 3 %; se excluye taper. Tres controles del mismo
  protocolo, separados al menos 14 días, describen tendencia del 2 km en 120
  días. Mejora V sin mejora del test prioriza T como hipótesis auditable, no
  como diagnóstico de un déficit fisiológico.
- Se sugiere actualizar control desde 28 días si quedan más de 14 para la
  prueba. Se conserva selección explícita y confirmación 31–45; desde 46 días
  la pauta es fácil sin ritmos derivados de esa marca.

## Objetivos

El contexto admite mejorar sin cifra, marca elegida o umbral propio con margen
explícito de 0–120 segundos. Son opciones excluyentes validadas en Flutter y
PostgreSQL. La meta no sustituye el rendimiento actual al pautar intensidades.
El servidor obtiene el umbral del intento elegido y conserva categoría y
versión. En FAS se llama **umbral de 20 puntos de esa prueba**, no aptitud
global. En otros programas es el mínimo de esa prueba. Un control de Tropa
sin evaluación oficial no inventa categoría ni mínimo: permite meta libre o
explícita. Los puntos jamás se trasladan entre programas.

## Laboratorio y recorrido verificado

[Abrir visor de trayectorias](labs/running_engine_v2.html).

13 perfiles × 6 horizontes = 78 trayectorias y **1.573 semanas**: 7:58, 11:00,
8:00, 7:30, meseta, exceso de velocidad, fatiga, un mal día, inactividad,
intermitencia, datos incompletos, cambio de disponibilidad y fuerza concurrente.
Horizontes de 4/9/13/17/26/52 semanas aproximan 1/2/3/4/6/12 meses; no significan
que cada horizonte sea un único mesociclo. Controles externos graduales con
techo del 6 % anual son **supuestos**, no una respuesta calculada por el motor.

Pruebas SQL con ROLLBACK:

- `running_engine_v2_regressions.sql`: datos ausentes, omisiones, RPE aislado
  frente a dificultad corroborada, registro legado, regularidad y controles.
- `running_engine_horizons.sql`: agenda, suma exacta de tramos, intensidad,
  separación entre semanas, no premiar exceso, no confundir ausencia de datos,
  recuperación tras fatiga, transferencia V/test, cambio de plazo y molestias.
- `running_engine_integration.sql`: publicar → ejecutar → registrar → adaptar;
  margen FAS, idempotencia, aislamiento y protección de auxiliares internos.
- `running_program_integration.sql`: ADMIN crea/publica programa y baremo →
  intento propio → mínimo y margen → mismo motor → mismo ejecutor; rechazo de
  fuente FAS ajena. Verificado sobre la versión desplegada en desarrollo.

Flutter: análisis sin incidencias y 237 pruebas completas aprobadas. El visor
se revisó en navegador. El nuevo formulario y publicación se verificaron por
widgets; no se certifica aquí el recorrido completo de una app recompilada
con sesión de usuario en navegador. No se modificó producción.

Reproducir el visor: exportar `supabase db query --linked --file
supabase/tests/running_engine_horizons.sql` a JSON en UTF-8 y ejecutar
`python tools/render_running_lab.py archivo.json` desde la raíz.

## Límites que siguen abiertos

No están cerrados todos los 26 puntos: parámetros por población y terreno,
calibración individual de esfuerzo, tratamiento completo de factores externos,
validación prospectiva de resultados humanos, motor de fuerza y coordinación
global entre varios objetivos. La entrada caminar/trotar requiere actualizar
capacidad declarada para evolucionar. Cooper y VAMEVAL no se convierten aquí en
anclas de prescripción. La FC se registra, pero no gobierna el motor.
Las tendencias no demuestran que dos pruebas tuvieran idénticas condiciones.

El siguiente tramo es revisar con Javier las trayectorias del visor y cerrar
la calibración deportiva de esta versión, incluyendo cómo aclarar RPE
persistente. No ampliar familias hasta resolver esos criterios.
