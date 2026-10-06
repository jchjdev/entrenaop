# Estrategia de flexiones · revisión v1

Fecha: 03/10/2026. Estado: cálculo experimental y laboratorio ADMIN
implementados; pendiente revisión deportiva y publicación de planes reales.
Política: `push_up_reps_draft_v1`. Decisión: STR-007.

STR-011 exige consensuar la progresión y evolución temporal antes de ampliar
esta política. [La propuesta por modelos](MODELOS_PROGRESION_FUERZA_RENDIMIENTO_V1.md)
plantea progresar volumen válido y practicar la tarea, con apoyo calibrado
cuando proceda; sus parámetros siguen en revisión. No convierte las dos
series y los incrementos de este laboratorio en un programa longitudinal
aprobado ni los modifica en código.

## Objetivo y alcance

Primera estrategia del motor general: mejorar repeticiones válidas de flexiones
estándar sin ventana temporal. La tarea conserva código/versión de ejercicio,
protocolo/versión, montaje y medición. Una ventana de 60/120 segundos exige
otra política; esta devuelve cobertura ausente y no transforma la marca.
Tampoco representa cualquier variante reglamentaria por compartir nombre.

El prototipo original `AdminPushUpPolicyLab` se conserva con sus regresiones;
STR-012 sustituye su entrada en el panel principal por ADMIN → Laboratorio de
fuerza y rendimiento, que incorpora bloques y la nueva progresión experimental
de una repetición total. El cálculo original documentado aquí no cambia.
El prototipo lee los
ejercicios oficiales y perfiles existentes; usa entradas y respuestas simuladas.
No guarda referencias, resultados, vínculos de programas ni sesiones. Los
protocolos con prefijo `lab_` son identidades de simulación, no protocolos
oficiales validados. La propuesta necesita revisión antes de usarla con atletas.

STR-010 conecta su decisión al contrato común de propuestas mediante
`push_up_performance_proposal.dart`, conservando dosis/versiones y la etiqueta
experimental. ADMIN muestra el número de objetivos con propuesta para revisión.
Una propuesta disponible no es una semana coordinada ni autorización para
publicar; un objetivo cronometrado sigue sin cobertura.

Tras la dificultad de Javier para obtener una propuesta, se añade «Cargar
ejemplo y calcular»: sustituye los campos de simulación por flexión estándar,
8 repeticiones, RIR 3, contexto confirmado, sin molestias/límite temporal,
20 minutos sin reserva y lunes/jueves. Debe mostrar dos propuestas de 2 × 8;
no acredita esos datos de una persona real. El resultado se hace visible al
calcular y los campos inválidos producen un aviso. Si falta el perfil oficial
de flexión estándar v1 en la biblioteca recibida, se informa expresamente y se
ofrece reintentar. Esto no modifica la dosis ni demuestra haber reproducido
la sesión autenticada de Javier.

## Evidencia consultada

| Fuente primaria | Qué aporta y qué no acredita |
| --- | --- |
| [ACSM 2026](https://pubmed.ncbi.nlm.nih.gov/41843416/) | Orienta diferencias entre fuerza, hipertrofia y potencia. No determina una dosis individual de máximas flexiones. |
| [Kotarsky et al., 2018](https://pubmed.ncbi.nlm.nih.gov/29466268/) | Ensayo pequeño, 23 hombres, cuatro semanas: progresiones de flexiones mejoraron fuerza y progresión específica. No demuestra el mejor programa de máximas repeticiones reglamentarias. |
| [Kikuchi y Nakazato, 2017](https://pubmed.ncbi.nlm.nih.gov/29541130/) | Ensayo con 18 hombres y ocho semanas: mejoras de fuerza/hipertrofia con flexiones y banca de carga equiparada. No cambió significativamente resistencia muscular; esta se midió en banca. No autoriza sustituir práctica de flexiones ni convertir banca en una marca equivalente. |
| [Revisión del continuo de repeticiones, 2021](https://pmc.ncbi.nlm.nih.gov/articles/pmid/33671664/) | Revisa fuerza, hipertrofia y resistencia local, sin proporcionar una conversión universal entre máximo y dosis submáxima. |
| [Precisión del RIR](https://pubmed.ncbi.nlm.nih.gov/34542869/) | El margen percibido es una estimación imperfecta; requiere contrastar resultado y contexto. |

Estas fuentes orientan las decisiones. Las constantes numéricas siguientes son
hipótesis conservadoras de producto para revisar; no proceden de un ensayo que
valide esta política completa ni demuestran eficacia de EntrenaOP.

## Entrada y selección

La estrategia necesita una serie de trabajo válida de una variante concreta,
repeticiones, RIR declarado, fecha y confirmación de capacidad actual. No
deduce la dosis de puntos, un 1RM de banca o un porcentaje del máximo del
examen. RIR 2–4 es la zona elegida para aceptar esa calibración en el prototipo;
no significa que las otras zonas sean inútiles.

La primera opción es una referencia de flexión estándar con la misma tarea y
protocolo del objetivo. Sin ella puede utilizar flexión inclinada como apoyo
si existe referencia calibrada, altura identificada y apoyo estable confirmado.
El resultado conserva objetivo y tarea de apoyo por separado. No garantiza
práctica estándar ni declara cobertura completa cuando solo puede pautar apoyo.
No incorpora dominadas por compartir músculos ni selecciona banca o lastre
sin calibración y política propias. La relación variante–objetivo vive en esta
política, no en la clasificación muscular global.

Se rechazan referencias futuras, no confirmadas, incompatibles o contradictorias.
La confirmación actual no sustituye una futura política de antigüedad: el
prototipo todavía no establece caducidad automática ni selección persistida.
Molestias/limitación bloquean el cálculo; ausencia de contexto pide datos.

## Dosis experimental

- Dos series con las repeticiones de la referencia calibrada.
- Objetivo RIR 3 y 120 segundos entre series. La técnica y el esfuerzo previsto
  tienen prioridad sobre completar el contador; el resultado real se registra.
- Hasta dos exposiciones por semana, separadas por al menos un día completo
  también al repetir la semana. Si solo cabe una, se explica esa limitación.
- Estimación de agenda: cinco minutos de preparación, cinco segundos por
  repetición como margen y descanso entre series. Es una estimación de tiempo,
  no una prescripción de tempo ni prueba de duración real.

Una serie calibrada no demuestra tolerancia de dos series ni una frecuencia
óptima. Esa limitación es parte de la revisión pendiente, especialmente con
experiencia y volumen previo. El prototipo no añade trabajo auxiliar ni
diagnostica si falta fuerza, resistencia o técnica.

## Adaptación experimental

Las ejecuciones comparables conservan la prescripción completa, política,
objetivo, tarea, montaje y protocolo; cada una tiene identidad y fecha propias.
No se mezclan versiones ni se duplican registros para fabricar tendencia.

| Últimas ejecuciones comparables | Respuesta |
| --- | --- |
| Dos, en días distintos, completas, técnicamente válidas, con repeticiones previstas y RIR declarado ≥3 en todas las series | Añadir una repetición por serie; mantener series, descanso y objetivo de esfuerzo. |
| Dos con interrupción por dificultad, pérdida técnica o RIR <2 | Retirar una repetición por serie. Si ya era una, pedir recalibración; nunca pautar cero. |
| Una sola, datos incompletos, respuesta mixta, repeticiones insuficientes sin motivo claro o interrupción por tiempo | Mantener; explicar qué impide progresar y pedir revisión/registro. Falta de tiempo no acredita fatiga. |
| Cambio de tarea/protocolo/política respecto a la dosis anterior | Pedir recalibración. |

Mantener tras una sesión difícil no significa pedir que se repita una técnica
inválida. Las series deben detenerse ante pérdida del estándar; la molestia
bloquea la propuesta. Esta regla experimental de tendencias no diagnostica
fatiga fisiológica ni sustituye una adaptación inmediata durante la sesión.

## Frontera con carrera, ejecutor y servidor

La entrada de agenda descuenta tiempo reservado para las demás tareas y
permite excluir días con otro trabajo de empuje. Busca una pareja viable antes
de quedarse con una sola sesión. Es encaje temporal inicial; no un coordinador
de carga multideporte. No suma kilómetros y repeticiones ni estima recuperación.
STR-008 aclara que esta reserva manual es propia del ensayo. La experiencia
del deportista preguntará disponibilidad total y contexto una vez, con pasos
pertinentes a su programa; la coordinación común deberá resolver el reparto
entre carrera y fuerza. El laboratorio largo no constituye ese recorrido ni
un formulario que deba trasladarse tal cual a la aplicación del deportista.

`strength_training_policy.dart` es dominio compartido sin Flutter o Supabase.
ADMIN adapta la biblioteca existente y presenta decisiones/motivos. El cálculo
es determinista para las mismas entradas, incluidas fechas; no hay API de IA,
variación aleatoria, duplicación de baremos ni planificador por oposición.

El ejecutor del deportista ahora deja RIR/RPE de serie sin registrar hasta que
el usuario los declara. Guardar una serie no copia el esfuerzo objetivo como
resultado. «No lo sé» conserva nulo y RIR 0 declarado conserva cero. La base
de datos y cola existentes ya aceptan nulos; no cambia el esquema ni se
reinterpretan históricos. Otros resultados siguen su confirmación existente.

Falta conectar observaciones válidas y propiedad/procedencia a esta estrategia,
configurar objetivos revisados por ADMIN, conservar decisiones en servidor,
coordinar la semana real con carrera y cerrar los doce recorridos de medición.
El cálculo experimental no cumple esos requisitos ni habilita publicación
automática. La autorización de Javier para empezar permite construir un
resultado revisable; no convierte las constantes en criterio deportivo aprobado.

## Revisión que corresponde a Javier

Revisar tres escenarios en ADMIN: referencia estándar de 8 frente a 16
repeticiones con igual margen; apoyo inclinado confirmado; dos respuestas
toleradas frente a dificultad o falta de tiempo. Debe revisarse la dosis y
decidir qué información de volumen previo necesita el primer plan real.
La siguiente implementación se centra en ese contrato de entrada/resultado
y en el contexto común/recorrido por bloques de STR-008/009 para todas las
capacidades. Flexiones es un caso de integración, no el límite del alcance
ni una condición para diseñar el resto. La coordinación real y
su revisión deportiva preceden a publicar sesiones conjuntas.

Verificación del tramo el 03/10/2026: análisis limpio en raíz y ADMIN;
batería completa de raíz, 278 pruebas, y ADMIN junto a los contratos compartidos,
56 pruebas, correctas. Compilación web de ADMIN correcta. Los widgets verifican
propuesta/adaptación y cobertura ausente para ventana temporal; el ejecutor
verifica esfuerzo ausente y RIR cero declarado. El dominio contrasta variantes,
protocolos, agenda, respuesta mixta, versiones, duplicados y referencias
contradictorias. No se ha validado un recorrido autenticado en navegador ni
eficacia deportiva con usuarios reales.

Verificación posterior del acceso al ejemplo (03/10/2026): análisis de ADMIN
limpio y sus 31 pruebas completas correctas, incluidas las cinco del laboratorio.
Se comprueban ejemplo directo tras entradas incompatibles, selectores coherentes,
aviso de campos inválidos y ausencia del perfil recibido, además de la adaptación
8 → 9 y el rechazo del protocolo cronometrado. No se reproduce la sesión
autenticada de Javier ni se cambia dominio/SQL en esta corrección de presentación.
