# Motor de carrera 2 km v1

> **Estado vigente (01/10/2026):** [Motor 2 km v2](MOTOR_CARRERA_2K_V2.md).
> Incluye motor común por programa, corrección de continuidad/RPE, margen propio
> y laboratorio de 1.573 semanas. Las referencias a pendientes de v1 o del
> piloto que siguen son antecedentes; consultar v2 para implementación actual.

Implementación del 01/10/2026. Sustituye las decisiones nuevas del piloto
`fas_running_week_v6`. Estado: **motor determinista operativo en desarrollo;
calibración deportiva provisional**. Una simulación verifica decisiones del
software, no demuestra que una persona vaya a mejorar cierta marca.

## Fuentes originales y alcance

Se han leído completos el documento de 26 puntos (adjunto
`f790c360-5cc5-4f27-bf5b-e889a8b0043b/Texto pegado.txt`) y las 20 sesiones
(`0240c2a3-deb1-4976-aa6a-ff1822b91801/Texto pegado.txt`). La matriz,
especificación y catálogo candidato son análisis posteriores, no sustitutos.
Este documento fija la primera política ejecutable y señala sus límites.

El núcleo no contiene identificadores FAS. El adaptador activo sigue siendo
FAS: resuelve su referencia seleccionada, contexto y resultados propios. Los
otros programas necesitan su adaptador de referencia/objetivo antes de poder
publicar; Flutter ya no les fabrica una semana con un segundo algoritmo local.
No se comparten automáticamente marcas ni baremos entre programas.

## Recorrido real y archivos

1. `20261001005000_running_engine_catalog_and_evidence.sql`: política versionada,
   catálogo, expansión de tramos e interpretación de una ejecución.
2. `20261001006000_running_engine_week_policy.sql`: evidencia comparable y
   decisión semanal pura. Recibe fecha y estado; no lee el reloj del sistema.
3. `20261001007000_running_engine_fas_adapter.sql`: autentica, obtiene datos
   propios, llama al núcleo y publica transaccionalmente.
4. Se conservan `workout_templates → workout_blocks → workout_items →
   workout_sets → scheduled_workouts`. `start_scheduled_workout`,
   `complete_workout_set` y `finish_workout_execution` son el ejecutor existente.
5. `running_week_sessions.prescription` conserva la ficha exacta. La decisión
   guarda contexto, referencia, observaciones, razones, cambios y versiones.
   Publicar dos veces la misma semana devuelve la misma decisión. Una semana
   publicada nunca cambia por introducir una nueva política.

Los auxiliares puros no tienen permiso de ejecución para `authenticated` ni
`anon`. El cliente no envía al publicador una supuesta decisión válida; el
servidor reconstruye los datos. Se conserva el bloqueo de publicación hasta
el cierre semanal y la simulación explícita de la siguiente semana.

## Qué sabe y qué no sabe

- **Declarado:** disponibilidad diaria, cuatro semanas recientes, capacidad de
  carrera cómoda, reservas de fuerza, salud y meta opcional.
- **Registrado:** marca 2 km, fecha, sesiones y parciales, recuperaciones y RPE.
  El registro manual no acredita que se haya medido correctamente.
- **Estimado:** rangos de ritmo desde la marca; no son VAM, umbral ni zonas
  fisiológicas medidas. FC se conserva en el ejecutor, pero no gobierna esta
  política: aún no tenemos un contrato de fiabilidad/zona individual.
- **Inferido:** tolerancia y tendencia a esfuerzo comparable. No se diagnostica
  una capacidad fisiológica ni una lesión.

El motor no aprende parámetros por sí solo ni utiliza una IA conversacional.
«Toleró dos exposiciones» es una condición comprobable para probar una dosis,
no una garantía de que la tolerará mañana.

## Catálogo cerrado para v1

Tiempo total = calentamiento + trabajo + recuperaciones entre repeticiones +
vuelta a la calma. Calidad: 10 min iniciales y al menos 6 finales. Tiempo
sobrante es fácil, nunca repeticiones adicionales implícitas. Los tramos por
distancia se encajan usando el extremo lento del rango. No se recorta una
repetición para hacerla caber.

| Familia | Escalones de trabajo | Recuperación | Control y límites |
| --- | --- | --- | --- |
| E | Rodaje 25–60 min | No aplica | Conversación; techo operativo RPE 5. Aumentos de 5 min cuando no aumenta otra dosis. |
| T | 2×5, 2×6, 2×8, 2×10, 2×12 min | 2 min entre tramos | Trabajo sostenido controlado; RPE ≤7. Acumula duración sin acelerar a la vez. |
| V | 4×2, 5×2, 6×2, 4×3, 5×3, 4×4 min | 2 min; 3 min en 4×4 | RPE ≤8. Más duración por repetición compensa reduciendo repeticiones. |
| S | 6×200, 8×200, 10×200, 5×400, 6×400, 4×600, 3×800, 4×500 m | 90 s; 120 s en 600; 180 s en 800 | RPE ≤8. Dos exposiciones comparables antes del siguiente escalón. 800 y 4×500 requieren además cuatro exposiciones S toleradas de nivel ≥6×400 en 56 días. |
| R | Fácil + 4×15 s, 6×15 s o 6×20 s | 75 s suaves | Rápido relajado, no máximo ni porcentaje >105 % obligatorio. Selector v1 usa solo 4×15; otros escalones quedan definidos pero no se progresan automáticamente. |

Los pasos de entrada reducidos T/V/S son **adaptaciones de los ejemplos**, no
sesiones textuales del documento ni dosis supuestamente validadas por un paper.
R se ofrece con al menos tres días y evidencia fácil reciente, sin juntarlo a
otra carga intensa o fuerza. Reentrada con capacidad <30 min conserva el
protocolo de 5 min caminando + 8×(1 min trote/90 s andando) + 5 min caminando;
exige actualizar capacidad para abandonar ese protocolo.

### Contraste individual de las 20 sesiones originales

| Nº | Sesión fuente | Resolución v1 y puntos aplicados |
| --- | --- | --- |
| 1 | E 30–60 | Activa, con suelo técnico 25 heredado; puntos 3,10,15,21. |
| 2 | T 3×8 | Se adopta familia, entrada 2×5 y escalera 2×N; 3×8 no se publica. Puntos 7–9,15. |
| 3 | V 4×4/3 min | Escalón final V, no entrada por defecto; puntos 7,8,11,15. |
| 4 | S 6×400 | Escalón S tras series cortas; recuperación operativa 90 s, no deducida del texto. Puntos 6–8,12. |
| 5 | E + 6–8 progresivos | Entrada reducida 4×15; técnica, separación y volumen fácil. Puntos 3,13,23. |
| 6 | T 2×10–12 | Escalones superiores T, tolerancia y tiempo suficiente. Puntos 7–9,15. |
| 7 | V 5×3 | Activa después de 4×3 tolerado. Puntos 7,8,11. |
| 8 | 2 km fraccionado | Solo 4×500, tardío; combinación 800+600+400+200 diferida. Puntos 6,8,12,16. |
| 9 | E 50–75 | V1 llega a 60; 75 diferido para no aumentar catálogo/carga sin criterio. Puntos 10,14,15. |
| 10 | V 6×2 | Entrada 4×2, luego 5 y 6. Puntos 7,8,11. |
| 11 | S 3×800 | Puerta específica adicional, nunca por marca rápida solamente. Puntos 6,8,12,18. |
| 12 | S 12–20×200 | V1 usa 6/8/10; 12–20 diferido por volumen. Puntos 6–8,12. |
| 13 | S 8–10×300 | Diferida; cubierta la finalidad con escalera 200/400/600. Puntos 7,12,24. |
| 14 | Fartlek 1–2–3–2–1 | Diferido: V cubre inicialmente la finalidad, evita variedad sin necesidad. Puntos 2,11,24. |
| 15 | Cuestas 45–60 s | Diferidas: faltan pendiente/terreno y tolerancia mecánica. Puntos 8,13,21,23. |
| 16 | Progresivo E→T | Diferido: analizar dos intenciones en una sesión requiere otro contrato. Puntos 2,8–10. |
| 17 | Bloques 30/30 | Diferidos: densidad y parciales específicos por cerrar. Puntos 7,8,11. |
| 18 | 400 + 200 | Diferida: ritmos mixtos, fatiga y recuperación necesitan ficha propia. Puntos 6,8,12. |
| 19 | Pirámide 200…800…200 | Diferida; son 3.200 m, no 2.000; no elegirla por estética. Puntos 7,8,12,15. |
| 20 | Sprints cuesta 8–12 s | Diferidos: requisitos de terreno y experiencia no capturados. Puntos 13,21,23. |

## Intensidad y meta

Para `t` segundos en 2 km, `v=2000/t`; para fracción `f`, ritmo `t/(2f)` s/km.
Rangos provisionales del documento: E 65–78 %, T 84–90 %, V 96–102 %; S usa
98–102 % para permitir un rango alrededor de la velocidad actual. Redondeo
conservado en ficha. Conversación/RPE tienen prioridad sobre perseguir el reloj.

La app admite meta libre (vacío) o tiempo elegido. Guarda `target_2k_seconds`
en contexto. Brecha `t/objetivo−1`. Para S corta tolerada dos veces, puede
acercarse al objetivo como máximo un 3 % de velocidad, manteniendo el escalón.
Ese 3 % es una **cota operativa provisional**, no un umbral universal de mejora.
Las series largas conservan ese ritmo intermedio; una meta enorme no lo
reemplaza. La derivación automática del mínimo oficial con margen sigue
pendiente; no se ha fijado margen de diez segundos ni copiado baremo ajeno.

Una nueva referencia seleccionada recalibra ritmos y mantiene dosis esa semana.
Desde 46 días se solicita control y se ofrece fácil sin ritmo numérico. La
confirmación de continuidad 31–45 días sigue en el adaptador. No se obliga a
test máximo semanal. No se simula una marca futura como resultado real.

## Lectura de una ejecución

Se recorren los tramos de trabajo y sus resultados, separados del calentamiento
y vuelta. Estados: `tolerated`, `struggle`, `off_intent`, `unknown`, `missing`,
`pain`. Controla trabajo ≥90 %, ritmo frente al rango (tolerancia lenta 5 %, rápida
3 %), deterioro último/primer parcial ≤5 %, pausas no alargadas >25 % y RPE según
familia (también RPE de tramo si existe). Son parámetros de ensayo. Falta medir
regularidad de todos los parciales, no solo extremos, y contexto ambiental.

Un V de RPE 8 puede tolerarse; una E de RPE 8 no cumplió la intención fácil.
Si la persona corrió demasiado rápido se registra `off_intent`: no se infiere
que haya perdido forma. Datos ausentes no son cero ni éxito. Omitir por tiempo
no es fracasar deportivamente. Una dificultad aislada mantiene; dificultad
repetida en dos semanas reduce. Molestias posteriores al último estado de
salud bloquean hasta actualizarlo.

Tendencia: cuatro exposiciones de misma familia, variante, minutos, ancla,
factor de velocidad y RPE ±1 en 56 días. Compara medias de ritmo de dos pares;
cambio >2 % orienta mejora/empeoramiento. E/T mejorando y S estable orienta S;
S mejorando y T estable orienta T; empeoramiento amplio con dificultad orienta
descarga. Con evidencia insuficiente rota estímulos elegibles, sin inventar
un diagnóstico. V mejorando con test 2 km estancado aún requiere comparador de
tests/contexto que esta versión no tiene.

## Semana, fuerza, descarga y calendario

- Carga inicial: menor de última semana y media declarada; 50 min en dos días
  permite 60 distribuidos. No son los minutos disponibles ni una promesa de
  usar todos los días. Una capacidad continua no limita todo el tiempo de una
  sesión fraccionada.
- Hasta cinco días; una calidad por defecto. Dos requieren cuatro días, ≥140
  min de presupuesto y calidad reciente tolerada. Predominio de minutos fáciles,
  contando solo trabajo T/V/S como intenso.
- Las reservas de fuerza se tratan conservadoramente como carga de piernas.
  También los entrenos programados de fuerza. Se evita calidad/R junto a ellos,
  incluyendo domingo/lunes. No se ha construido el motor de fuerza.
- General >8 semanas; desarrollo 5–8; específico 2–4; puesta a punto última
  semana. Cambia prioridad T/V/S, no habilita dosis no toleradas.
- Revisión tras 2 semanas de carga con <120 min o varias reservas de fuerza;
  3 semanas en el resto, y exige exposiciones reales de calidad. Descarga de
  intensidad: solo fácil. Fatiga repetida: volumen ×0,75. Taper: volumen ×0,60
  y una exposición conocida con la mitad de repeticiones si cabe, no una nueva.
- Semana perdida: reentrada ×0,75, sin recuperar sesiones. Cambio de días
  redistribuye dentro del tiempo real. Progresión de frecuencia como máximo
  un día por decisión; bloquea el aumento de otra variable.
- Las reducciones respetan el suelo técnico de sesión de 25 min. En volúmenes
  muy bajos ese suelo puede impedir alcanzar el porcentaje exacto.

## Pruebas y límites de cierre

`supabase/tests/running_engine_lab.sql`: 198 semanas simuladas entre A, B, C,
D, 7:58, fatiga, semana perdida, disponibilidad, meseta y horizonte anual.
Incluye oráculos de cabida, separación, intensidad, puerta de 800, taper,
caducidad, ancla nueva, omisión, RPE por familia y patrón del punto 18.
Metas ausentes en la fuente: A usa mejorar sin cifra;
C usa 13 semanas como horizonte de ensayo. No es una fecha del usuario.
El ancla se mantiene con controles sintéticos cada cuatro semanas en las
trayectorias; sin ellos se ensaya aparte la salida sin ritmos al caducar.

`running_engine_integration.sql`: RPC bajo rol autenticado, publicación
idempotente, arranque y registro de todos los tramos con el ejecutor real,
simulación posterior, bloqueo de publicación anticipada y RLS entre usuarios.
Ambos terminan con `ROLLBACK`. No dejan sesiones de prueba ni modifican las
marcas guardadas. Las pruebas antiguas v4–v6 de dosis fija se sustituyen por
estas; las migraciones históricas se conservan.

Pendiente para cerrar el producto deportivo: calibración con Javier y registros
reales, comparadores más ricos (2 km/contexto/regularidad), objetivo oficial
con margen, adaptadores de otros programas, coordinación real de fuerza y
revisión visual del flujo completo en dispositivo. No hay evidencia clínica
ni ensayo que valide EntrenaOP como sistema completo. El bloque sigue abierto.
