# Carrera: contrato de la primera semana (borrador v1)

Estado: **decisión de dominio probada, todavía sin publicación en la agenda**.
Ámbito: preparación de Tropa y Marinería; no se aplica automáticamente a otros
programas que también incluyan 2 km.

## Principios deportivos acordados

- Dos semanas de carga y una de descarga como estructura de producto. No se
  atribuye a la literatura una superioridad universal del ciclo 2:1; la dosis
  de carga y descarga sigue pendiente de validación.
- Una sola sesión de calidad controlada como norma inicial con 2–4 días de
  carrera. La segunda calidad requiere base y tolerancia demostradas; nunca
  aparece únicamente por disponer de más días.
- La mayor parte del tiempo de carrera será fácil. La distribución se medirá
  en minutos, no contando sesiones, porque el calentamiento y la vuelta a la
  calma también forman parte de una sesión de calidad.
- La calidad toma del modelo noruego el **control del esfuerzo y las series
  submáximas**, no sus dobles sesiones, volúmenes de élite ni objetivos de
  lactato que EntrenaOP no mide.
- Un test de 2 km aporta una referencia de rendimiento, pero no determina
  individualmente LT1, LT2 ni zonas de FC. La primera sesión se denominará
  «calidad controlada», no «umbral confirmado».
- Dolor, lesión declarada o necesidad de revisión profesional bloquean la
  propuesta automática. La aplicación recomendará valoración profesional;
  no prescribirá movilidad o rehabilitación por defecto.

## Entradas necesarias para generar una semana real

1. Preparación activa y versión del programa.
2. Test de 2 km con identificador, protocolo, fecha, tiempo, RPE e incidencias.
3. **Asignación conjunta de carrera y fuerza dentro de los días totales.**
   `availableDaysPerWeek` actual cubre ambas modalidades. El plan padre debe
   repartir días de carrera, días de fuerza y posibles días mixtos antes de
   invocar el componente de carrera. También necesita los días concretos de
   la semana; el número total no basta para distribuir la carga. Cada prueba
   del programa aportará sus prioridades y límites, pero el calendario se
   resuelve una sola vez para toda la preparación, no con algoritmos que
   llenen los mismos días independientemente.
4. Tiempo máximo por sesión y carrera reciente tolerada (frecuencia y minutos).
5. Estado de dolor o lesión y bandera de revisión profesional.
6. Sesiones ya programadas en esa semana, incluidas las de otras preparaciones,
   para evitar duplicados y colisiones de carga.

No se publicará una semana oficial si faltan datos necesarios, si hay un aviso
de salud o si ya existe una semana oficial para esa preparación. El cliente no
debe poder concederse plantillas o sesiones oficiales mediante una inserción
directa: la publicación futura corresponderá a un servicio/RPC de confianza
que valide propietario, reglas y versión.

## Decisión determinista ya implementada

`InitialRunningWeekPlanner.version = tropa_running_initial_week_v1` recibe
los días **totales**, la asignación explícita a fuerza/carrera y las entradas
de carrera. Rechaza una asignación que exceda los días totales. Los días
mixtos quedan bloqueados hasta acordar cómo se combinan las cargas. Para 2,
3 o 4 días **asignados a carrera** con una base
reciente de al menos dos días de carrera propone, respectivamente:

| Días asignados a carrera | Composición del componente de carrera |
| --- | --- |
| 2 | 1 calidad controlada + 1 fácil |
| 3 | 1 calidad controlada + 2 fáciles |
| 4 | 1 calidad controlada + 2 fáciles + 1 regenerativa |

Si solo cabe un día de carrera porque otro se reserva a fuerza, ese día es de
calidad controlada únicamente cuando existe base reciente; si no, será fácil.
No se interpreta como una distribución óptima de intensidades: con tan poca
frecuencia de carrera habrá que valorar si el objetivo de 2 km es realista o
si se pueden compartir días de forma segura.

Con menos de dos días recientes de carrera, la calidad se sustituye por una
semana de familiarización fácil. Ese umbral es una **regla conservadora de
producto**, no un punto de corte clínico validado. El motor devuelve códigos de bloqueo y razones
versionadas; no genera aún ritmos, duraciones, fechas o plantillas ejecutables.
La tabla **no** significa que una persona con dos días totales hará dos
carreras: Tropa necesita reservar también fuerza y otros componentes.

## Lo que falta antes de publicar sesiones

- Diseñar un asignador conjunto de carrera y fuerza que respete los días
  totales, los días concretos y los objetivos de cada prueba. Capturar
  historial reciente de carrera sin confundirlo con fuerza.
- Definir y probar con Javier el contenido de la calidad controlada, los
  límites de minutos por semana, la progresión de la segunda semana y la
  reducción de la tercera. No se codificará un porcentaje de descarga como
  supuesto científico.
- Diseñar una calibración de ritmos que no etiquete el resultado de 2 km como
  umbral medido. RPE y FC son señales de comprobación, no sustitutos perfectos
  del lactato. Una FC alta aislada exige contexto (calor, sueño, terreno,
  hidratación, sensor); no rebaja ritmos automáticamente.
- Guardar cada propuesta con versión de reglas, versión deportiva, entradas
  utilizadas, razones, fuente de cada marca y posible anulación profesional.
  Publicar de forma atómica plantillas privadas de origen `algorithm` y
  entradas `scheduled_workouts` ligadas a la preparación. Nunca modificar
  retrospectivamente plantillas o ejecuciones previas.
- Revisión de rendimiento tras varias sesiones comparables: cumplimiento,
  parciales, RPE, FC opcional e incidencias. Una sesión completada no aumenta
  ritmo por sí sola; un abandono aislado tampoco diagnostica pérdida de forma.

## Evidencia y límites de extrapolación

- Casado et al. (2023), modelo de intervalos al umbral guiado por lactato en
  corredores de élite: https://pubmed.ncbi.nlm.nih.gov/36900796/
- Campos et al. (2022), distribución de intensidad en corredores y diferencias
  entre métodos de cuantificación: https://pubmed.ncbi.nlm.nih.gov/34749417/
- Estudio de anclajes fijos de intensidad en corredores recreativos (2025):
  https://pubmed.ncbi.nlm.nih.gov/40088270/
- Consenso de retorno al deporte tras lesión:
  https://bjsm.bmj.com/content/50/14/853

Estos trabajos justifican una base fácil y cautela al trasladar el método
noruego. **No validan una receta individual de ritmos derivada solo del 2 km
ni el número exacto de series, porcentaje de descarga o regla de progresión.**
