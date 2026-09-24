# Roadmap de EntrenaOP

Este roadmap expresa prioridades, no fechas cerradas. Su estado se ha
contrastado con código, migraciones y pruebas el 22 de septiembre de 2026, tras
el cierre de Carrera V1 mínima. Prioridades de programa revisadas el 23 de
septiembre de 2026; esta revisión documental no sustituye una auditoría del
bloque adaptativo, que todavía no existe.

## Estado del ciclo principal

El ciclo objetivo continúa siendo:

> Evaluación inicial → plan semanal → entrenamiento guiado → registro real →
> adaptación → simulacro.

| Tramo | Estado | Evidencia y límite actual |
| --- | --- | --- |
| Acceso y contexto inicial | Terminado | Autenticación restaurable, varias preparaciones, evaluación inicial e historial de Tropa y Marinería, y preferencias de disponibilidad, experiencia y material. |
| Biblioteca y sesiones personales | Terminado para fuerza V1 | Biblioteca pública, sesiones privadas, ejercicios propios, descripción y vídeo HTTPS, duplicado, archivado, borradores locales y revisiones versionadas. |
| Agenda semanal manual | Terminada | Reúne biblioteca y sesiones personales; permite programar, reprogramar, retirar, iniciar y continuar. Inicio resume los siete días y abre la fecha seleccionada. Conserva nombre, versión y duración como instantánea. |
| Contexto por preparación | Terminado | Permite entrar en una preparación activa, ver objetivo, últimas marcas compatibles y sesiones oficiales vinculadas. El deportista solo consulta y ejecuta: no puede crear, vincular, mover ni retirar sesiones del plan oficial. |
| Creador de fuerza por bloques | Terminado en V1 | Series variables, superseries A1/A2, circuitos con transiciones, intervalos de trabajo, Tabata 8 × 20/10, EMOM y AMRAP, con vista previa coherente. |
| Sesión guiada e historial | Terminado para los formatos V1 | Objetivo y resultado real, omisión, abandono, RPE final, notas, vídeos, temporizadores restaurables, avisos configurables, cola idempotente e historial con correcciones auditadas. |
| Funcionamiento sin conexión | Parcial | Encola completar/omitir serie, AMRAP, finalizar y abandonar una ejecución cargada. No replica catálogo o agenda, no inicia contenido desconocido y las correcciones exigen conexión. |
| Evaluación y progreso | Parcial | Registra, evalúa y compara marcas con el catálogo versionado de ingreso a Tropa y Marinería, calcula evolución y recomienda focos. No hay panel longitudinal completo ni simulacro. |
| Plan semanal adaptativo | No existe | La agenda es manual; no se generan prescripciones a partir de preparaciones, evaluación, disponibilidad o historial. |
| Adaptación posterior | No existe | No hay reglas versionadas que interpreten resultados y produzcan la siguiente recomendación o semana. |
| Carrera especializada | Terminada en V1 manual | Creador de carrera continua, series y pirámides; repeticiones agrupadas al prescribir, registro individual obligatorio de parciales y recuperaciones, ritmo calculado, RPE, FC opcional, clasificación de cumplimiento e historial. No incluye GPS, mapas, zonas ni integraciones. |
| Seguimiento profesional | No existe | No hay relación entrenador-cliente, asignación, anulación manual, panel profesional ni chat. |
| Derechos y monetización | No existe | La separación conceptual está decidida, pero no hay suscripciones ni concesión fiable de derechos comerciales. |

## Base completada

### Estabilización y seguridad

- Entornos de Supabase separados por configuración.
- Línea base SQL reproducible, saneamiento de acceso, RLS, constraints e
  índices.
- Restauración y observación de autenticación, navegación centralizada y
  pruebas base.
- Arquitectura modular aplicada sin imponer capas que no aporten valor.

### Dominio de evaluación y contexto

- Catálogo versionado de ingreso a Tropa y Marinería 2026 y evaluación de sus
  cuatro pruebas.
- Historial de evaluaciones, progreso y recomendación explicable del foco.
- Preferencias de entrenamiento y bloqueo cuando se solicita revisión
  profesional.
- Múltiples preparaciones activas, sin duplicar un mismo programa activo.
- Detalle de preparación que compone fecha objetivo, última evaluación
  compatible y agenda semanal relacionada, sin generar aún decisiones
  deportivas. El vínculo queda reservado al futuro algoritmo o a un servicio
  administrativo de confianza.

### Vertical manual de entrenamiento

- Plantillas jerárquicas y ejecuciones con instantáneas inmutables de la
  prescripción, el formato y el contenido explicativo usado.
- Biblioteca pública, sesiones personales y agenda semanal común.
- Creador privado y transaccional con múltiples bloques y objetivos por serie.
- Series convencionales, superseries, circuitos, intervalos, Tabata, EMOM y
  AMRAP; posiciones repetibles y transiciones de circuito.
- Ejercicios privados, búsqueda por catálogo, descripción y vídeo HTTPS.
- Borradores locales por sesión, duplicado, archivado y familias de revisiones.
- Vista previa, sesión guiada, temporizadores persistentes, avisos sonoros y
  hápticos, resultados, omisiones, abandono, notas y esfuerzo final.
- Cola local de mutaciones con recibos idempotentes, historial y correcciones
  auditadas limitadas por tiempo y número.
- Carrera personal mediante un formato distinto de los intervalos de fuerza,
  con borrador local, revisión versionada, tramos ordenados, ritmo y
  recuperación propia; usa la biblioteca, agenda, ejecución e historial
  comunes.

## Único siguiente bloque recomendado

El control independiente de carrera de 2 km ya dispone de registro repetible,
fechado y vinculado a una preparación, con RPE obligatorio, FC y parciales de
400 m opcionales. Su protocolo de calentamiento y su cadencia de repetición
siguen pendientes de validación deportiva; ninguna semana se recalcula aún
automáticamente a partir de estas marcas.

El contrato y la primera decisión determinista de carrera se documentan en
`docs/ALGORITMO_CARRERA_V1.md`. Todavía no publican sesiones: la disponibilidad
actual es conjunta para carrera y fuerza; faltan su reparto, días concretos
y carga reciente de carrera.

Antes de publicar la primera semana adaptativa, se cerrará un **piloto de
evaluación periódica militar separado del ingreso a Tropa y Marinería**. Javier
conoce mejor las pruebas que denomina PAFAS/PAEF y prefiere validar ahí el
contenido deportivo. No se cambiará el identificador ni el catálogo del
programa de ingreso existente: tiene marcas y preparaciones históricas. La
Orden DEF/15/2026 comparte tipos de prueba entre ingreso y evaluación
periódica, pero diferencia sus baremos; los nuevos baremos periódicos entran
en vigor el 1 de enero de 2027. Ya existe el programa estable
`fas_periodic_assessment` **habilitado en desarrollo** y un catálogo local
versionado con la tabla íntegra de 0–100 puntos por prueba, columna H/M y edad
del anexo II. La calculadora gratuita está visible en Inicio, no requiere una
preparación activa y no guarda ni altera intentos. Muestra cada puntuación y el
mínimo general de 20 puntos, pero no inventa una suma total ni certifica
aptitud oficial. Su registro e historial periódicos siguen siendo
independientes de Tropa y validan las marcas en PostgreSQL. Antes del 1 de
enero de 2027 se muestra como referencia futura. Tampoco prescribe sesiones
automáticamente.

El siguiente tramo ejecutable será:

1. Completados el contrato separado de registro, los mínimos por edad/sexo,
   el historial y la validación de propiedad en PostgreSQL. Completados también
   la tabla íntegra de 0–100 puntos y su cálculo local auditable. El BOE no
   define una suma total y contiene una secuencia anómala no corregida en II.3;
   se conserva literalmente y se mantiene como limitación conocida.
   La fecha de nacimiento se recoge en el perfil; la edad se calcula para
   cada intento y el servidor comprueba que coincide. El circuito deja de
   exigirse al cumplir 45 años.
2. **Calculadora gratuita de puntos completada** para la evaluación periódica
   FAS 2027: usa la fecha de nacimiento del perfil, permite elegir explícitamente
   H/M, acepta entradas móviles de repeticiones y tiempos, muestra puntos por
   prueba, versión y fuente, y mantiene separados cálculo e historial. Próxima
   ampliación: selección de otros programas/convocatorias cuando dispongan de
   catálogos completos igualmente verificables. La conversión a Premium no
   ocultará el cálculo gratuito ni lo confundirá con una certificación oficial.
3. Curar un catálogo **mínimo** de ejercicios oficiales de fuerza aptos para
   las primeras plantillas: técnica, objetivo, material, variantes y
   limitaciones. El creador administrativo completo, fotos y biblioteca amplia
   no bloquean el piloto; tampoco se debe inventar una progresión de fuerza a
   partir de solo flexiones, sentadillas y plancha.
4. Componer y revisar con Javier una semana de plantillas ejecutables de
   carrera y fuerza, registrables con los flujos existentes. Mantenerla como
   borrador hasta validar su contenido.
5. Implementar una propuesta determinista y explicable sin asignación real;
   después validar el recorrido completo antes de publicar en agenda.

El trabajo existente de carrera de Tropa es un prototipo específico de ese
programa: sus reglas y el borrador de `assets/programs/tropa/` no pasan
automáticamente al nuevo piloto. Se reutilizarán contratos y componentes
compatibles, no baremos ni prescripciones sin revisión.

CNP permanece como borrador administrativo sin pruebas ni requisitos: no se
habilitará al opositor por ahora.

La **primera planificación semanal adaptativa**, cuando el piloto deportivo
esté preparado, debe cerrar en este orden un único tramo del ciclo:

1. Definir una prescripción mínima con entradas explícitas: preparaciones
   activas, evaluación vigente, disponibilidad, material e historial necesario;
   y separar el contenido deportivo versionado de las decisiones por usuario.
2. Versionar las reglas y guardar para cada propuesta entradas, salida y razones.
3. Generar una semana privada con origen `algorithm` y colocarla en
   `scheduled_workouts` sin modificar plantillas ni ejecuciones históricas.
4. Mostrar al usuario por qué se pauta cada sesión y permitir ejecutarla o
   registrar su resultado; cualquier sustitución futura deberá decidirla el
   algoritmo o un servicio autorizado bajo reglas versionadas.
5. Cubrir dominio, persistencia, permisos y una prueba vertical desde contexto
   válido hasta semana visible en agenda.

Se recomienda este orden porque el producto ya puede crear, programar,
ejecutar y auditar sesiones, y ya conecta cada preparación con sus marcas y su
agenda. El ciclo se detiene justo antes de convertir ese contexto en un plan,
pero necesita primero un programa familiar y contenido de fuerza revisable.
Una biblioteca completa o nuevos formatos no son condición previa.

La adaptación posterior a una semana realizada será el bloque siguiente, pero
no forma parte de este trabajo: primero debe existir una primera prescripción
determinista y verificable.

El panel administrativo ya tiene una aplicación web separada. Distingue
biblioteca general y plantillas de cada programa; permite crear, buscar
ejercicios, revisar, editar borradores, versionar y retirar sesiones. Solo las
sesiones generales publicadas aparecen en la biblioteca abierta; publicar una
plantilla de programa la deja disponible para las futuras reglas de esa
preparación, sin asignarla aún. Comparte modelo y validación con la app mediante
`workout_core`, pero no reutiliza sus pantallas. Todavía no define mesociclos
ni reglas deportivas. No es un requisito previo para esta primera vertical.
Las reglas y sesiones que alimente el futuro algoritmo deben seguir revisándose
como datos versionados en Git y Supabase. Publicar una sesión en la biblioteca
general no la convierte todavía en parte de un mesociclo ni la asigna a nadie.

## Después, no en paralelo

Una vez validada la primera semana adaptativa, el orden natural será:

1. Interpretar cumplimiento, RPE/RIR, molestias, omisiones y abandono para
   adaptar la semana siguiente con reglas auditables y anulación profesional.
2. Completar evolución longitudinal, simulacros y comparación con baremos.
3. Incorporar relación entrenador-cliente, panel profesional y asignaciones.
4. Consolidar derechos comerciales y monetización antes de integraciones o
   expansión a otras oposiciones.

## Fuera del camino crítico del MVP

- Resolver todas las oposiciones a la vez.
- Chat, nutrición, desafíos o red social.
- Garmin Connect, Strava y otras integraciones antes de cerrar el ciclo
  adaptativo. Después se estudiará el envío de entrenamientos de carrera y su
  vinculación con planes como Guardia Civil o Tropa y Marinería.
- Algoritmos opacos o aprendizaje automático antes de validar reglas
  deterministas.
- Academias y multi-tenancy sin un caso profesional validado.
- Arquitectura preventiva para funcionalidades todavía indefinidas.

## Regla de ejecución

Cada bloque debe entregar un recorrido utilizable y probado. No se abrirán
varias áreas grandes a la vez ni se considerará terminada una funcionalidad
porque existan sus capas si el usuario todavía no puede completar el caso de
uso.
