# Motor de fuerza y rendimiento: integración operativa

**Actualización STR-021, 04/10/2026:** el selector descrito abajo es histórico.
El recorrido aplicado y sus límites están en
[MOTOR_FUERZA_RENDIMIENTO_V2.md](MOTOR_FUERZA_RENDIMIENTO_V2.md).

Estado técnico inicial comprobado el 03/10/2026; correcciones del recorrido
observado por Javier verificadas el 04/10/2026 en **entrenaop-dev**.
**Revisión STR-019 (04/10/2026):** el recorrido técnico funciona, pero la
programación deportiva completa sigue abierta. La entrada copia una dosis
declarada; no implementa aún el banco de estímulos, la dosis inicial desde
capacidad ni la preparación por componentes del circuito. No presentar este
documento como cierre de esas capacidades. Detalle y fuentes recibidas en
[MODELOS_PROGRESION_FUERZA_RENDIMIENTO_V1.md](MODELOS_PROGRESION_FUERZA_RENDIMIENTO_V1.md).

Política deportiva `performance_v1_1`, coordinador `preparation_coordinator_v1`
y carrera `running_2k_v5`. No se ha desplegado producción. Esta entrega conecta
la aplicación del deportista; los laboratorios anteriores de ADMIN conservan
su identidad experimental y no son la autoridad de publicación.

## Recorrido disponible

Preparación → **Fuerza y carrera** → **Tu semana** → **Movimientos** →
**Propuesta** → **Guardar semana en mi agenda**. Las ejecuciones usan la agenda,
el ejecutor, la cola de reintentos y el historial comunes. La semana siguiente
se decide al solicitar otra propuesta con las ejecuciones guardadas, conservando
la prescripción anterior. No se genera por terminar una sesión o avanzar el calendario.

La disponibilidad expresa minutos totales para entrenar. Cada movimiento
registra sus datos pertinentes en un bloque completo. Carrera mantiene su
cuestionario; solo se ofrece cuando pertenece a la preparación. Registrar una
referencia no equivale a realizar un test máximo: se explica el trabajo
submáximo y el margen de repeticiones que pide la app. No se precargan marcas,
RIR, validez o tolerancia ficticios.

Una sola serie o intento es suficiente. El descanso solo se solicita cuando
hay varios; cero en una referencia de una serie significa que no existe un
intervalo entre series. En plancha se registran segundos y postura válida; no
se pide una puntuación de esfuerzo ni RIR de repeticiones en la calibración.
La ejecución recoge técnica, condiciones y tolerancia reales. «Detalles para
repetirlo» permite describir cambios; siguiendo el protocolo mostrado puede
dejarse vacío. Altura de flexiones inclinadas, asistencia e instrumentos
reactivos siguen necesitando descripción para mantener comparabilidad.

ADMIN configura **Cómo se prepara cada prueba** en el programa borrador:
variante exacta, medición, ventana/trayecto cuando corresponda y revisión del
protocolo. El servidor valida permisos y compatibilidad. Cambiar una estrategia
publicada requiere otra versión del programa; la copia conserva las condiciones.
El administrador no decide las series individuales de cada deportista.
La edad y categoría resueltas por la evaluación delimitan las pruebas del
programa; una referencia que deja de ser pertinente se conserva, pero no se pauta.

FAS y Tropa usan adaptadores de sus catálogos existentes: flexiones de dos
minutos, plancha y circuito de 16 m con pelota. No se alteran sus baremos ni
se trasladan marcas entre programas. FAS excluye el circuito desde los 45 años
para la fecha objetivo; la ausencia de fecha de nacimiento no implica exención.
El circuito tiene perfil propio: catálogo v1 conserva sus 63 variantes y la
ampliación v2 añade una, sin reinterpretar el shuttle 5–10–5.

## Arquitectura y persistencia

Las funciones deportivas puras reciben referencia, perfil, ejecuciones,
semana y decisión anterior. Los adaptadores autenticados resuelven esos datos;
Flutter presenta y registra mediante un repositorio independiente de Supabase.
No hay cálculo de progresión dentro de widgets ni duplicación de la autoridad
entre Dart y PostgreSQL. Los mapas de respuesta transportan instantáneas
versionadas; las mediciones de serie tienen objetos y codecs compartidos.

- `performance_training_contexts`: disponibilidad/material y confirmación actual.
- `performance_training_references`: revisiones conservadas de calibración por
  objetivo, variante, protocolo, montaje y condiciones.
- `performance_exercise_relations`: relaciones expresas de regresión/apoyo.
  Compartir músculos no autoriza una sustitución ni convertir una marca.
- `preparation_week_decisions`: decisión publicada e instantánea de
  contexto/referencias. La evidencia conserva las ejecuciones consideradas,
  sus resultados originales y la señal interpretada.
- `superseded_at` en decisiones conjuntas y de carrera: marca una revisión
  sustituida sin borrar su contenido ni sus vínculos. Solo una revisión activa
  por preparación/semana; las lecturas de planificación usan esa revisión.
- `performance_week_work`: vínculo entre cada bloque ejecutable y las referencias
  a las que sirve. Compartir trabajo no duplica las series físicas.

Cada serie conserva `performance_prescription`; cada ejecución conserva su
copia y `performance_result`. Distancia, altura, tiempos decimales, carga,
masa corporal, ventana real, técnica, esfuerzo y motivo permanecen distintos.
`PASS_FAIL` usa éxito booleano, no una marca numérica inventada. Las métricas
reactivas instrumentadas conservan método y altura de salto cuando se declara;
no se confunden con aciertos ante señales de agilidad reactiva. Los campos
antiguos son una proyección de presentación, nunca la fuente del motor.

Registro idempotente y cola offline mantienen el identificador de operación.
Las correcciones conservan motivo, auditoría y los límites de 24 horas/tres
cambios. No declarar esfuerzo conserva `null`, también en el historial antiguo.
La publicación compara la propuesta revisada con los datos actuales y guarda
agenda, plantillas privadas, decisiones y vínculos en una transacción. Los
candados por deportista/preparación evitan publicaciones concurrentes incompatibles.
La actualización de contexto comparte el candado. Añadir material desde una
referencia no renueva la declaración de salud.

## Reglas deportivas operativas

La entrada reproduce una dosis de trabajo que el usuario ha realizado, con
1–6 series, descanso real cuando hay varias y una o dos sesiones semanales declaradas. No convierte
un máximo de examen en volumen ni obtiene RM sumando repeticiones y RIR.
En trabajo dinámico la calibración pide RIR 2–4; la ejecución admite 0–10 o
ausencia. Dos respuestas comparables, en fechas distintas, justifican la
adaptación. La técnica inválida, condiciones distintas, carga diferente o
esfuerzo ausente no se convierten en éxito.

| Modelo | Respuesta al trabajo comparable |
| --- | --- |
| Repeticiones | +1 repetición total en la serie menor después de dos exposiciones toleradas; dificultad repetida reduce una serie. |
| Carga/repeticiones | +1 repetición dentro de la horquilla calibrada. Consolidar todas las series permite el escalón de carga disponible, limitado al 10 %, y volver al inicio de la horquilla. Sin escalón practicable mantiene o pide calibrar. |
| Repeticiones en tiempo | Aumenta repeticiones conservando la ventana. Cambiarla impide atribuir progreso. Las series libres de apoyo se identifican como apoyo, no como una marca de la prueba. |
| Isometría | +2 segundos en una serie con postura válida; dificultad repetida reduce duración. No pide RIR de repeticiones. |
| Saltos y lanzamientos medidos | Conserva intentos, carga y montaje; actualiza distancia/altura objetivo solo al rendimiento válido repetido en dos exposiciones. No pide un récord calculado. |
| Cuerda y circuito cronometrado | Conserva altura/recorrido e intentos. Una mejora de tiempo repetida actualiza la referencia; no cambia simultáneamente trayecto, ascensos y lastre. |
| Reactividad instrumentada y práctica técnica | Mantiene calidad e intentos. No deriva potencia de contactos, repeticiones o éxito booleano ni cambia complejidad automáticamente. |
| Transportes | Conserva carga y montaje; +2 s o hasta 1 m/10 % en una serie, según medición, tras consolidarla. |

En tareas de calidad, dos dificultades reducen un intento cuando hay varios;
si ya queda uno, se pide una tarea accesible recalibrada. Cambiar variante,
asistencia, palanca, montaje o complejidad exige una referencia propia. El RM
sirve como objetivo/control; el trabajo habitual usa carga y repeticiones.

Las reglas numéricas son **parámetros operativos revisables**, no dosis demostradas
óptimas para cada oposición. La clasificación muscular y la matriz de apoyos
son editoriales. Sin datos de un apoyo no se inventa su capacidad.

## Evolución y coordinación

Los horizontes de 1/2/3/4/6/12 meses se resuelven semana a semana: entrada,
desarrollo, prioridad específica durante los últimos 28 días y puesta a punto
durante los últimos siete. En esta última se reducen series y frecuencia,
conservando el gesto; no se solicitan nuevas progresiones. La revisión cada
cuatro semanas no impone una descarga universal. Dificultad repetida puede
reducir demanda antes; tras interrupción sin datos actuales se recalibra.

El coordinador explora siete rotaciones semanales. Prioriza práctica específica
frente a apoyos, coloca calidad técnica/potencia al principio y solicita a carrera
una propuesta bajo el tiempo restante y las cargas de piernas. Incluye siete
minutos de calentamiento, tres de vuelta a la calma, descansos y transiciones;
son reservas iniciales de tiempo, no garantías fisiológicas. No rellena minutos
libres por obligación. Puede explicar que solo cabe una de dos exposiciones.

Una tarea idéntica dentro de la preparación puede servir a varios objetivos;
se ejecuta y contabiliza una vez. Un específico accesible desplaza su regresión,
y no se pautan dos regresiones alternativas para el mismo objetivo. Práctica
específica ausente, referencia caducada, material ausente o prueba sin estrategia
permanecen visibles; no se presentan como cobertura completa.

Una subida de demanda por región en la misma semana es el límite conservador
inicial. Las restantes mantienen la dosis previa; la elección es determinista,
con rotación semanal y prioridad específica. Si carrera progresa, reserva esa
subida de piernas. Mejorar una marca ya repetida conservando la misma dosis de
intentos no equivale a añadir volumen. No se usa un índice universal de fatiga.

La agenda global reserva las sesiones de otras preparaciones y propias. Protege
cargas contiguas de las mismas regiones, incluida la frontera entre semanas.
La calidad de carrera ya publicada también restringe piernas; no se recalcula
silenciosamente. Fuerza de calidad precede a carrera fácil si coinciden ese día;
la calidad de carrera y las cargas de piernas no se juntan por caber en minutos.

**Límite deliberado:** esta versión publica una preparación cada vez respetando
la agenda global. No es todavía un optimizador conjunto de todos los programas
activos ni fusiona sus decisiones históricas. Tampoco calcula una prioridad
individual mediante diferencias de puntos de baremos distintos.

## Carrera y compatibilidad

`running_plan_v5` conserva su política, dosis, fases, respuesta y contrato.
`calculate_running_week_constrained` añade restricciones internas de coordinación;
el cliente no puede invocarlo. El cálculo normal usa el mismo adaptador sin
restricciones adicionales. La detección de piernas usa los perfiles; ejercicios
sin clasificación siguen siendo carga desconocida. No toda flexión cuenta como
piernas por pertenecer a un bloque de fuerza.

La publicación antigua de carrera dirige al recorrido conjunto cuando existen
referencias activas de fuerza. El reinicio destructivo exclusivo de carrera se
rechaza si existen semanas coordinadas, para no romper sus vínculos; permite
actualizar contexto/referencias para las siguientes. Las preparaciones de solo
carrera también pueden usar el recorrido común sin referencias de fuerza.
Las rutas antiguas conservan compatibilidad, pero no duplican el acceso en la
preparación ni la publicación dentro del cuestionario abierto desde el flujo común.

### Recalcular sin reiniciar

En la propuesta de una semana publicada, **Recalcular con mis datos actuales**
obtiene una vista previa con marca, contexto, referencias e historial actuales.
No cambia la agenda. **Sustituir las sesiones pendientes** compara la propuesta
revisada y reemplaza su publicación de forma atómica: cancela pendientes,
conserva las decisiones anteriores y publica la nueva revisión. Reintentar la
misma operación no duplica sesiones.

Solo se revisa la última semana publicada, actual o próxima, si todas sus
sesiones automáticas siguen planificadas, sin ejecución y con fecha no pasada.
Una ejecución iniciada, realizada u omitida impide sustituir esa semana; sus
datos se usan para decidir la siguiente. Las sesiones personales y de otras
preparaciones siguen ocupando agenda. No es un reinicio ni una simulación de
primera semana: conserva la adaptación basada en el historial previo.

## Verificación y límites de la entrega

Migraciones `20261003004000` a `20261003016000` aplicadas en **entrenaop-dev**.
Pruebas SQL transaccionales de mediciones, política, catálogo, horizontes,
retroalimentación de calidad, recorrido completo y seguridad, junto a las
regresiones de carrera v5, sus horizontes, publicación, reinicio y programas.
Se han comprobado dieciséis baterías SQL; todas terminan con `ROLLBACK`; no dejan sesiones sintéticas en la agenda.

Las trayectorias de fuerza cubren seis modelos durante seis horizontes
(720 semanas sintéticas), además de cada combinación del catálogo. Las pruebas
comprueban reglas y coherencia; no simulan ni demuestran adaptación fisiológica.
La integración FAS comprueba contexto → pruebas pertinentes → deduplicación →
propuesta revisada → publicación idempotente → ejecutor → siguiente decisión.
RLS se comprueba con el rol `authenticated`, no solo con el propietario de la BD.

Análisis de ambas apps y baterías completas: 328 pruebas de raíz y 54 de ADMIN.
Widgets a 360 px: bloques, propuesta pendiente, publicación revisada y resultados
sin autocompletar. Ambas compilaciones web forman parte del cierre técnico.
No había sesión de navegador autenticada accesible para una revisión manual;
no se acredita aquí una prueba real en Android/iOS ni eficacia en deportistas.

**Corrección del 04/10/2026 (STR-018):** revisión del vídeo de 1 min 44 s,
regresiones móviles de presentación con sesiones, guardado de un único intento
en plancha/circuito, vista previa antes de sustituir y cuestionario de carrera
sin duplicar la propuesta. Análisis limpio y batería completa de raíz correctos.
Diez baterías SQL con `ROLLBACK`: revisión, programa de solo carrera,
coordinación completa, seguridad, respuesta de calidad, integración/reinicio de
carrera, experiencia previa y regresiones/horizontes v5. Migraciones
`20261004000000` y `20261004001000` aplicadas en desarrollo. Estas pruebas no
sustituyen comprobar de nuevo el recorrido en la sesión real de Javier.

**Siguiente bloque recomendado:** piloto deportivo y de usabilidad con sesiones
reales, siguiendo decisiones y causas de mantenimiento/reducción. Cambiar dosis
requiere una nueva versión y nuevas regresiones. Cámara (STR-015), GPS, nuevas
familias de protocolos y optimización conjunta de múltiples preparaciones no se
presentan como implementados por este cierre técnico.

## Corrección de sesión y continuación · STR-019 · 04/10/2026

Revisado el vídeo de 2 min 15 s. El circuito fijo ya no muestra estímulos/aciertos
ni penalizaciones sin que su protocolo declare esos datos; al corregir resultados
antiguos se mantienen los campos que ya contenían información. Se aclaran técnica,
condiciones, esfuerzo y fin de serie. La duración larga se expresa como minutos;
el protocolo estándar interno no se muestra como una instrucción al deportista.

El servidor añade una guía de calentamiento relacionada con los patrones y tareas
de la sesión. La reserva de siete minutos sigue siendo una estimación; la guía
explica preparación general y ensayos específicos sin buscar marcas. Las notas
de cada tarea se copian a `workout_execution_sets.item_instructions` al iniciar
y no pueden modificarse después. No se reescriben ejecuciones históricas. Las
nuevas instrucciones aparecen en nuevas publicaciones; una semana pendiente
puede revisarse por el recorrido permitido, una empezada conserva su instantánea.

La agenda vacía ofrece preparar la semana seleccionada y conserva esa fecha al
elegir preparación. El recorrido común abre por defecto la primera semana actual
o próxima sin publicar; una semana pedida explícitamente sigue siendo esa semana.
Tras guardar se puede ir a su agenda o preparar la siguiente. **Terminar o avanzar
el calendario no publica una semana:** sigue siendo calcular → revisar → guardar.

Verificación: análisis limpio de ambas aplicaciones, 344 pruebas de raíz y
58 de ADMIN; doce baterías SQL relacionadas con resultados, políticas, catálogo,
seguridad, coordinación, revisión y carrera, todas con `ROLLBACK`. La prueba de
revisión verifica además que editar la plantilla no cambia las instrucciones
de una ejecución y que estas no pueden reescribirse. Migración
`20261004002000` aplicada en **entrenaop-dev**, con historial local/remoto coincidente.
Producción no intervenida. No se acredita todavía una comprobación manual de
la aplicación corregida en el dispositivo de Javier.

**Límite vigente:** estos cambios no reemplazan la dosis copiada de la referencia
por `performance_v1_1` ni implementan el banco de estímulos. El siguiente bloque
es cerrar entradas y dosis parametrizadas y sustituir la selección deportiva
con las regresiones pertinentes. La recomendación anterior de pasar directamente
al piloto no implica que esa programación esté cerrada. STR-020 conserva y revisa
el banco V2 y las aportaciones anteriores, todavía sin activarlos.

## Fuentes y límites de transferencia

- [Autorregulación de carga y volumen](https://pubmed.ncbi.nlm.nih.gov/35038063/)
  y [métodos de regulación](https://pubmed.ncbi.nlm.nih.gov/33312273/): examinar
  rendimiento y esfuerzo juntos, respetando población y medición.
- [Entrenamiento concurrente](https://pubmed.ncbi.nlm.nih.gov/37847373/): coordinar
  objetivo, experiencia y potencia; no proporciona una puntuación de fatiga.
- [Puesta a punto en fuerza](https://pubmed.ncbi.nlm.nih.gov/32917000/): datos de
  powerlifting que no validan copiar porcentajes a todas las pruebas.
- [Orden DEF/15/2026](https://www.boe.es/buscar/doc.php?id=BOE-A-2026-1379):
  identidad del circuito, flexiones y plancha de los adaptadores FAS/Tropa.

La revisión deportiva completa y las fuentes por modelo permanecen en
[MODELOS_PROGRESION_FUERZA_RENDIMIENTO_V1.md](MODELOS_PROGRESION_FUERZA_RENDIMIENTO_V1.md).
