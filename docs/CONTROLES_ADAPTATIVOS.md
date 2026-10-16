# Controles adaptativos por necesidad

## Acuerdo y alcance · STR-041 · 16/10/2026

Javier autoriza cerrar el recorrido automático de controles y tests para las
estrategias actuales. Solicita por separado un diagnóstico de la repetición de
carrera, sin corregir su catálogo, formatos, calentamiento o progresión ordinaria.
La revisión de carrera figura en
[VARIEDAD_CARRERA_2026_10_16.md](audits/VARIEDAD_CARRERA_2026_10_16.md).

El módulo se sitúa después de la propuesta del coordinador. Reutiliza su semana
ya viable y sustituye trabajo; no crea días ni incrementa el presupuesto
disponible. Las estrategias siguen adaptando el entrenamiento ordinario desde sus
ejecuciones. Un test resuelve una pregunta de información, no autoriza por sí
solo a aumentar dosis ni acredita capacidad de otro ejercicio.

## Decidir si medir aporta algo

La política pura `adaptive_control_decision_v1` necesita práctica nueva suficiente,
datos recientes y contexto vigente. Decide entre observar trabajo, aplazar o
medir el protocolo. Una oportunidad procede de:

- Transferencia por comprobar al entrar en especificidad.
- Cambio suficiente en el trabajo tolerado desde la última comprobación.
- Repetición de trabajo comparable sin nueva información sobre transferencia;
  no se repite el mismo control de meseta sin cambio de firma o fase.
- Una primera marca del protocolo ausente después de consolidar práctica.
- En carrera, una referencia que alcanza la ventana de reutilización del motor
  y limita su próxima decisión, con práctica tolerada y continuidad observadas.

El paso del tiempo solo no activa un test. No hay contador cada N semanas.
Cuatro días tolerados, dos recientes, crecimiento del 20 %, seis observaciones
para revisar repetición y las ventanas de datos son guardas **operativas y
versionadas**, no dosis o calendarios óptimos demostrados por estudios. El motor
no convierte una meseta de dosis en diagnóstico de estancamiento fisiológico.
Los plazos de referencia de carrera preexistentes se conservan: la caducidad se
combina con necesidad y preparación, no se presenta como evidencia de que haya
que correr un 2 km máximo mensualmente.

Cuatro semanas completas con carrera realmente registrada pueden acreditar
continuidad para reutilizar una referencia entre treinta y cuarenta y cinco
días, sin volver a preguntar un dato observado. No renuevan salud ni convierten
una referencia de más de cuarenta y cinco días en ritmos actuales: se conserva
la salida prudente del motor mientras se encuentra una oportunidad de control.

Las series propias del movimiento acreditan preparación; banca y plancha alta
no acreditan por sí solas tolerancia del protocolo de flexión o antebrazos.
La práctica técnica pertinente de agilidad aporta información de calidad, sin
convertirse en marca del circuito. Un esfuerzo desconocido no acredita tolerancia.

## Coste y colocación

No se pauta un máximo al inicio sin práctica suficiente, tras respuesta adversa,
con contexto de salud no vigente, en reentrada/puesta a punto o con la meta ya
acreditada recientemente. Una reducción global de carrera, su reentrada o una
revisión real de datos o esfuerzo pendiente posponen también los máximos de las
demás pruebas, sin reescribir el entrenamiento ordinario del coordinador. La
proximidad se comprueba en la fecha concreta del control: no dentro de los
últimos catorce días antes del examen. Si el protocolo
no está revisado o faltan datos se sigue observando o se explica la revisión.

Como techo de evaluación se coloca como máximo un control de protocolo por
semana. Es un límite de carga, **no la obligación de hacer uno cada semana**.
Se comprueba separación de tres días de calendario respecto a otra calidad de
carrera y cargas realizadas próximas de la semana anterior. Un rodaje fácil
conocido no se equipara a una calidad: el límite con
trabajo ordinario tolerado es de dos días, y con un test, calidad o esfuerzo alto
es de tres. Las citas sin ejecución no acreditan recuperación; las cargas
manuales futuras del usuario también bloquean una colocación incompatible.
Alrededor del
control se retira trabajo pertinente que comprometería recuperación; las otras
exposiciones del mismo objetivo se sustituyen esa semana. El calentamiento,
registro y cierre siguen presupuestados. La recuperación individual puede exigir
aplazar más; la separación por fechas no acredita una cantidad exacta de horas.

Si no cabe una oportunidad compatible, la semana ordinaria sigue disponible y
la decisión se conserva para auditoría. Omitir, abandonar o invalidar un control
no genera una marca ni obliga a repetirlo semanalmente. Se reconsidera cuando
haya una necesidad nueva y trabajo suficiente.

## Protocolos y registro

Se reutiliza `PerformanceSetPrescription` con intención `control`, sin RIR.
La pantalla indica qué medir y recoge el esfuerzo real, sin exigir la marca
anterior ni el objetivo deseado. No hay que perseguir RPE 10.

| Estrategia actual | Control | Lo que acredita |
| --- | --- | --- |
| Flexiones libres | Repeticiones válidas del mismo protocolo | Marca de esa variante; no una RM ni un resultado temporal. |
| Flexiones FAS en dos minutos | Ventana completa de 2:00 y repeticiones válidas | Marca temporal real. Un registro de 1:00 no se multiplica por dos. Otros programas temporales necesitan una ventana compatible ya definida. |
| Plancha de antebrazos | Postura válida con techo de tiempo explícito | Si termina antes, tiempo válido observado; alcanzar el techo acredita **al menos** ese tiempo, no el máximo exacto. |
| Circuito de 16 m con pelota | Un intento del recorrido completo ya practicado | Tiempo bruto del protocolo, sin repetir para buscar un récord. Un intento nulo no actualiza la marca. |
| Carrera de 2 km | Distancia medida completa, cronometraje y esfuerzo | Referencia `trainingControl` de la preparación. No es una evaluación oficial ni un resultado extrapolado desde intervalos. |

Las marcas de rendimiento se leen desde sus series cerradas y conservan
objetivo, medición y procedencia. Las metas se contrastan con ellas sin
sobrescribir evaluaciones/baremos. Las sesiones ordinarias no reutilizan el
RPE alto esperado de un test como si fuera dificultad de una serie submáxima.
Los controles submáximos de transición existentes continúan sustituyendo una
exposición cuando no se coloca un test de protocolo.

La revisión de datos distingue registros desconocidos de un test ya conocido
que sustituyó una salida ordinaria. El contador de sesiones comparables de v5
puede bajar al excluir ese test; eso no acredita datos perdidos ni fatiga.

Carrera guarda un control validado en la tabla existente de controles, con
`source_execution_set_id` único y clave foránea. Cerrar/continuar sincroniza la
marca antes de recalcular; el reintento no duplica y una corrección válida
actualiza el mismo origen. Invalidar el origen impide reutilizarlo. El guardián
de inserción impide adjudicar a ese origen una cifra distinta. Las series
ordinarias de carrera siguen exigiendo sus datos completos; la excepción tipada
solo permite registrar un control de 2 km, incluido un intento parcial/nulo sin
fabricar su distancia o su marca. Datos faltantes no se completan desde el objetivo.

## Evidencia y límites científicos

La decisión combina utilidad, comparabilidad, carga y respuesta individual. El
[consenso sobre monitorización de carga](https://pubmed.ncbi.nlm.nih.gov/28463642/)
y el [consenso de selección de pruebas](https://pubmed.ncbi.nlm.nih.gov/28054257/)
fundamentan qué pregunta se quiere resolver y si la medición es practicable.
El [marco multidimensional de monitorización](https://pmc.ncbi.nlm.nih.gov/articles/PMC13388359/)
sitúa las respuestas breves dentro de la adaptación a largo plazo; no justifica
convertir cualquier oscilación aislada en un test máximo.

La [revisión sobre fatiga al entrenar al fallo](https://pubmed.ncbi.nlm.nih.gov/34881412/)
respalda contabilizar el coste de esos esfuerzos. No demuestra un plazo de
recuperación universal. La [revisión de puesta a punto en resistencia](https://pubmed.ncbi.nlm.nih.gov/37163550/)
apoya reducir fatiga cerca de la competición; no establece que exactamente
catorce días sea una prohibición universal de tests para estos cuatro protocolos.
Estas guardas conservadoras se declaran operativas, susceptibles de revisión,
y se distinguen de conclusiones científicas.

Las simulaciones comprueban decisiones, datos, integración y continuidad, no la
eficacia fisiológica ni la fiabilidad de un autorregistro doméstico. La aceptación
física sigue siendo necesaria. Nuevos movimientos requieren su protocolo y
guardas específicos; este módulo no habilita máximos indiscriminados de toda la
biblioteca.

## Verificación de desarrollo · 16/10/2026

Análisis de Flutter sin incidencias y batería completa de raíz: 923 pruebas
correctas y una omisión web preexistente. Pasan las 25 baterías SQL
transaccionales relacionadas, con `ROLLBACK`; las 152 migraciones locales y
remotas coinciden. Se cotejan 22 cuerpos instalados, incluidos núcleo, catálogos
y constructores originales de carrera, y las tres migraciones de este bloque
coinciden con sus sentencias registradas. Los avisos de seguridad del proyecto
mantienen el recuento previo; no se declaran resueltos por este bloque.

El caso FAS de seis meses completa 26 semanas, 102 sesiones y 679 registros,
con doce controles de los cuatro protocolos, sin añadir marcas manuales para
desbloquear carrera ni exceder días o minutos. La simulación revierte todos los
datos y restaura las funciones temporales. Informe y límites en
[CONTROLES_AUTOMATICOS_SEIS_MESES_2026_10_16.md](audits/CONTROLES_AUTOMATICOS_SEIS_MESES_2026_10_16.md).
La aceptación física, el ensayo conjunto anual y el estrés de concurrencia
siguen pendientes; este cierre no los sustituye.
