# Roadmap de EntrenaOP

Este roadmap expresa prioridades, no fechas cerradas. Debe actualizarse cuando
el código y las decisiones de producto cambien.

## Paso 0: comprender y estabilizar

1. Auditar repositorio, dependencias, Git, arranque, navegación, autenticación,
   ejercicios, esquema SQL, RLS, correspondencia de modelos y pruebas.
2. Clasificar hallazgos por roturas, seguridad/integridad, arquitectura que
   conviene corregir ahora y mejoras aplazables.
3. Acordar un único orden de corrección antes de modificar código funcional.
4. Mover la configuración de Supabase a entornos adecuados y resolver los
   defectos críticos que confirme la auditoría.
5. Incorporar el esquema remoto a migraciones reproducibles, junto con
   constraints, políticas RLS y datos de prueba controlados.
6. Dejar autenticación, restauración de sesión, análisis estático y pruebas base
   en un estado verificable antes de ampliar funcionalidad.

## Fase 1: concretar el dominio PAEF/PAFA

Antes de diseñar las tablas definitivas se trabajará con ejemplos reales para
definir:

- Pruebas, convocatorias, categorías y baremos versionados.
- Diferencia entre programas de acceso y evaluaciones internas.
- Tramos de edad, tablas de puntos y cálculo total para PAEF/PAFA cuando se
  disponga de sus fuentes oficiales.
- Datos que se prescriben y resultados que se registran.
- Fuerza, carrera, circuitos, superseries, AMRAP, EMOM, Tabata e isométricos.
- Reglas ante sesiones completadas, fallidas, omitidas o con molestias.
- Límites de adaptación y capacidad de anulación del entrenador.

El resultado de esta fase serán conceptos de dominio comprensibles y pruebas de
sus reglas principales, no solo un diagrama o un conjunto de tablas.

## Fase 2: primera vertical funcional

Se completará un único recorrido antes de extender horizontalmente el producto:

1. Registrar una marca inicial.
2. Generar o recibir una sesión con pocos ejercicios reales.
3. Ejecutar la sesión, incluso ante una pérdida temporal de conexión.
4. Guardar el resultado prescrito y el realizado sin confundirlos.
5. Mostrar evolución y comparación con el baremo usado.
6. Producir una recomendación siguiente explicable.

Esta vertical incluirá:

- Autenticación y persistencia de sesión fiables.
- Conjunto mínimo de ejercicios necesario para la vertical.
- Creación y asignación de la sesión.
- Modelo de entrenamiento capaz de expresar los formatos necesarios.
- Pantalla de sesión activa.
- Registro detallado de resultados y feedback.
- Base inicial de ingreso a Tropa y Marinería, baremos versionados y
  pruebas/simulacros.

La biblioteca completa y otros formatos se ampliarán después de validar este
recorrido.

## Fase 3: adaptación y seguimiento

- Algoritmo determinista de progresión, con auditoría y anulación manual.
- Evolución de marcas y comparación con baremos.
- Panel de administración y gestión de clientes.
- Servicio de seguimiento personalizado.
- Chat y notificaciones cuando permisos y modelo comercial estén consolidados.

## Fase 4: monetización e integraciones

- Suscripciones y derechos multiplataforma.
- Integraciones de salud y actividad priorizadas por valor real.
- Garmin y Strava si los acuerdos y APIs disponibles lo permiten.
- Nutrición básica si no desvía el foco del producto.
- Nuevas oposiciones: CNP, Guardia Civil y otras, una vez estabilizado el modelo.

## Fase futura: entrenadores y academias

El panel profesional comenzará con las necesidades reales de Javier y del
seguimiento personalizado. Si el uso demuestra demanda, podrá evolucionar a:

- Espacios de trabajo de entrenador.
- Invitación e incorporación de clientes.
- Grupos, alumnos y varios entrenadores por academia.
- Programación compartida y métricas agregadas.

La posibilidad futura de academias influye en la separación entre identidad,
relaciones y organizaciones, pero no autoriza a implementar multi-tenancy antes
de necesitarlo.

## Fuera del camino crítico del MVP

- Resolver todas las oposiciones a la vez.
- Integraciones externas antes de disponer de una sesión activa sólida.
- Algoritmos opacos o aprendizaje automático antes de validar reglas
  deterministas.
- Arquitectura preventiva para funcionalidades todavía indefinidas.

## Regla de ejecución

Cada fase debe entregar un recorrido utilizable y probado. No se abrirán varias
áreas grandes a la vez ni se considerará terminada una funcionalidad porque
existan sus capas si el usuario todavía no puede completar el caso de uso.
