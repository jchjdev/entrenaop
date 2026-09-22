# Roadmap de EntrenaOP

Este roadmap expresa prioridades, no fechas cerradas. Su estado se ha
contrastado con código, migraciones y pruebas el 22 de septiembre de 2026, tras
el cierre del creador de fuerza V1.

## Estado del ciclo principal

El ciclo objetivo continúa siendo:

> Evaluación inicial → plan semanal → entrenamiento guiado → registro real →
> adaptación → simulacro.

| Tramo | Estado | Evidencia y límite actual |
| --- | --- | --- |
| Acceso y contexto inicial | Terminado | Autenticación restaurable, varias preparaciones, evaluación inicial e historial de Tropa y Marinería, y preferencias de disponibilidad, experiencia y material. |
| Biblioteca y sesiones personales | Terminado para fuerza V1 | Biblioteca pública, sesiones privadas, ejercicios propios, descripción y vídeo HTTPS, duplicado, archivado, borradores locales y revisiones versionadas. |
| Agenda semanal manual | Terminada | Reúne biblioteca y sesiones personales; permite programar, reprogramar, retirar, iniciar y continuar. Conserva nombre, versión y duración como instantánea. |
| Contexto por preparación | Terminado | Permite entrar en una preparación activa, ver objetivo, últimas marcas compatibles y sesiones semanales vinculadas. El vínculo es opcional y no altera el origen de la sesión. |
| Creador de fuerza por bloques | Terminado en V1 | Series variables, superseries A1/A2, circuitos con transiciones, intervalos de trabajo, Tabata 8 × 20/10, EMOM y AMRAP, con vista previa coherente. |
| Sesión guiada e historial | Terminado para los formatos V1 | Objetivo y resultado real, omisión, abandono, RPE final, notas, vídeos, temporizadores restaurables, avisos configurables, cola idempotente e historial con correcciones auditadas. |
| Funcionamiento sin conexión | Parcial | Encola completar/omitir serie, AMRAP, finalizar y abandonar una ejecución cargada. No replica catálogo o agenda, no inicia contenido desconocido y las correcciones exigen conexión. |
| Evaluación y progreso | Parcial | Registra, evalúa y compara marcas con el catálogo versionado de ingreso a Tropa y Marinería, calcula evolución y recomienda focos. No hay panel longitudinal completo ni simulacro. |
| Plan semanal adaptativo | No existe | La agenda es manual; no se generan prescripciones a partir de preparaciones, evaluación, disponibilidad o historial. |
| Adaptación posterior | No existe | No hay reglas versionadas que interpreten resultados y produzcan la siguiente recomendación o semana. |
| Carrera especializada | No existe | Los intervalos actuales son de trabajo con un ejercicio; faltan tramos de carrera, ritmo y recuperación por tramo. |
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
  deportivas.

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

## Único siguiente bloque recomendado

El siguiente bloque será la **primera planificación semanal adaptativa de
Tropa y Marinería**, limitada a producir una semana explicable sobre la agenda
existente.

Debe cerrar, en este orden, un único tramo del ciclo:

1. Definir una prescripción mínima con entradas explícitas: preparaciones
   activas, evaluación vigente, disponibilidad, material e historial necesario.
2. Versionar las reglas y guardar para cada propuesta entradas, salida y razones.
3. Generar una semana privada con origen `algorithm` y colocarla en
   `scheduled_workouts` sin modificar plantillas ni ejecuciones históricas.
4. Mostrar al usuario por qué se propone cada sesión y permitir aceptar o
   regenerar solo bajo reglas definidas.
5. Cubrir dominio, persistencia, permisos y una prueba vertical desde contexto
   válido hasta semana visible en agenda.

Se recomienda este bloque porque el producto ya puede crear, programar,
ejecutar y auditar sesiones, y ya conecta cada preparación con sus marcas y su
agenda. El ciclo se detiene justo antes de convertir ese contexto en un plan.
Añadir ahora más formatos,
la carrera, monetización o herramientas de entrenador ampliaría la superficie
sin resolver esa interrupción principal.

La adaptación posterior a una semana realizada será el bloque siguiente, pero
no forma parte de este trabajo: primero debe existir una primera prescripción
determinista y verificable.

## Después, no en paralelo

Una vez validada la primera semana adaptativa, el orden natural será:

1. Interpretar cumplimiento, RPE/RIR, molestias, omisiones y abandono para
   adaptar la semana siguiente con reglas auditables y anulación profesional.
2. Añadir el creador especializado de carrera con tramos ordenados, distancia o
   duración, ritmo y recuperación individual, usando la misma agenda e
   historial.
3. Completar evolución longitudinal, simulacros y comparación con baremos.
4. Incorporar relación entrenador-cliente, panel profesional y asignaciones.
5. Consolidar derechos comerciales y monetización antes de integraciones o
   expansión a otras oposiciones.

## Fuera del camino crítico del MVP

- Resolver todas las oposiciones a la vez.
- Chat, nutrición, desafíos o red social.
- Garmin, Strava y otras integraciones antes de cerrar el ciclo adaptativo.
- Algoritmos opacos o aprendizaje automático antes de validar reglas
  deterministas.
- Academias y multi-tenancy sin un caso profesional validado.
- Arquitectura preventiva para funcionalidades todavía indefinidas.

## Regla de ejecución

Cada bloque debe entregar un recorrido utilizable y probado. No se abrirán
varias áreas grandes a la vez ni se considerará terminada una funcionalidad
porque existan sus capas si el usuario todavía no puede completar el caso de
uso.
