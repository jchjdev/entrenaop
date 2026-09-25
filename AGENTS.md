# EntrenaOP: guía de trabajo

Este archivo contiene las reglas vigentes para trabajar en este repositorio. Los
documentos de `docs/` amplían el contexto de producto, arquitectura y roadmap.
El código y las migraciones reales tienen prioridad sobre cualquier descripción
histórica.

## Colaboración con Javier

- Trabajar con un ritmo natural de *pair programming* y mantener el contexto
  global del producto sin reauditar todo el repositorio en cada tarea.
- No convertir cada paso en una pregunta o examen. Avanzar con supuestos
  razonables y señalar los que sean relevantes.
- Entregar directamente configuración, infraestructura repetitiva y
  *boilerplate*. Involucrar a Javier especialmente en entidades, reglas de
  negocio, algoritmo, estados importantes y decisiones que deba comprender.
- Si Javier se atasca, explicar o dar una pista antes de completar su parte.
- No dar por buena una idea solo por venir del usuario: explicar con claridad
  los riesgos y alternativas.
- Distinguir siempre hechos comprobados, suposiciones y recomendaciones.
- Evitar abrir varios caminos a la vez. Proponer un flujo principal ordenado y
  ejecutable.
- Explicar antes de aplicar una decisión que cambie materialmente la
  arquitectura, el modelo de datos, la seguridad o un criterio acordado.
- Escribir los mensajes de commit en castellano.
- Añadir comentarios en castellano cuando aclaren reglas de negocio,
  conversiones, seguridad o decisiones no evidentes. Evitar comentarios que
  solo repitan literalmente lo que ya expresa el código.

## Reglas del repositorio

- Inspeccionar el estado de Git y el código directamente relacionado antes de
  modificar nada.
- Consultar `docs/DECISIONS.md` y el documento de dominio que este enlace cuando
  la tarea afecte a una decisión de producto, deporte, datos o arquitectura.
- Cuando Javier confirme, corrija o descarte una decisión relevante, registrarla
  en `docs/DECISIONS.md` y desarrollarla en su documento responsable dentro de
  la misma tarea. No dejar decisiones vigentes únicamente en una conversación.
- Preservar cambios existentes y no revertir trabajo ajeno.
- No realizar operaciones destructivas.
- No hacer refactorizaciones generales al resolver un problema pequeño.
- No introducir paquetes sin justificar su necesidad y comprobar su
  compatibilidad real.
- Usar `go_router`, eligiendo según el flujo entre `go`, `push`, `pop` y rutas
  anidadas; ninguna de estas operaciones es una regla universal.
- Ejecutar `flutter analyze` y las pruebas relevantes después de cambios
  materiales.
- Añadir pruebas para dominio, algoritmo, permisos y regresiones importantes;
  evitar pruebas que solo repitan la implementación.
- No crear commits salvo petición de Javier o acuerdo expreso sobre el punto de
  commit.
- Mantener secretos fuera del repositorio y separar los entornos de desarrollo
  y producción. Una clave pública/anónima de Supabase puede estar en el cliente,
  pero debe configurarse por entorno.
- La seguridad y los derechos comerciales nunca pueden depender solo de
  Flutter.

## Flujo de trabajo por alcance

Priorizar avanzar con rapidez sin degradar la arquitectura ni acumular deuda
técnica innecesaria. El nivel de inspección y verificación depende del alcance
real del cambio.

### Durante una tarea cotidiana

Antes de modificar código:

- Inspeccionar únicamente los archivos, dependencias, modelos, pruebas y
  migraciones directamente relacionados con la tarea.
- Respetar la arquitectura, patrones, contratos y decisiones ya existentes.
- Usar el código y las migraciones como fuente principal de verdad.
- Consultar la documentación solo cuando sea necesaria para entender una
  decisión o comportamiento existente.
- No realizar una auditoría global del repositorio ni releer toda la
  documentación en cada tarea.

Si durante la implementación resulta necesario cambiar materialmente una
decisión arquitectónica, el modelo de datos, la seguridad, un contrato entre
capas o un comportamiento acordado, detenerse y explicar el cambio antes de
realizarlo. En ese caso se amplía la inspección solo a las áreas afectadas y a
sus fronteras de integración.

Al terminar la tarea, realizar una mini-verificación:

1. Revisar los archivos modificados y su integración con el código directamente
   relacionado.
2. Ejecutar `flutter analyze` y las pruebas relevantes cuando corresponda por
   el tipo de cambio.
3. Comprobar que no se hayan introducido errores evidentes, regresiones o
   inconsistencias.
4. Indicar brevemente qué se cambió, qué se validó y si queda alguna deuda o
   riesgo conocido.

No ampliar el alcance para corregir problemas ajenos a la tarea salvo que
impidan completarla correctamente.

### Matriz de verificación

Aplicar solo las comprobaciones correspondientes al alcance modificado:

- Cambios en la aplicación del deportista: ejecutar `flutter analyze` y las
  pruebas relevantes desde la raíz. En cambios materiales o cierres de bloque,
  ejecutar también la batería completa de la raíz.
- Cambios en `admin_app/`: ejecutar análisis y pruebas desde `admin_app/`.
- Cambios en `packages/workout_core/` o `packages/workout_editor_ui/`: verificar
  tanto la aplicación del deportista como `admin_app/`, porque ambos consumen
  esos paquetes.
- Cambios en migraciones, funciones, constraints, grants o RLS: comprobar el
  historial con `supabase migration list` contra desarrollo y ejecutar la
  prueba SQL transaccional relacionada. Añadirla si el contrato nuevo aún no
  tiene cobertura. Las pruebas deben terminar con `ROLLBACK` y no dejar datos.
- Cambios de dependencias: revisar `pubspec.yaml`, el *lockfile*, compatibilidad
  resoluble y las dos aplicaciones afectadas; no actualizar paquetes a ciegas.
- Cambios exclusivamente documentales: revisar el diff y su formato; no
  ejecutar Flutter salvo que el contenido documente un comportamiento que
  necesite contrastarse.

Una verificación contra el proyecto enlazado acredita Supabase de desarrollo,
no producción. No consultar, reparar ni desplegar producción salvo que la tarea
lo pida expresamente.

### Ante un cambio transversal o arquitectónico

Ampliar la inspección antes de modificar cuando el cambio afecte a varias
funcionalidades, contratos compartidos, navegación global, identidad, permisos,
modelo de datos, RLS, sincronización, configuración de entornos o decisiones de
producto vigentes. Explicar a Javier el impacto, los riesgos y la alternativa
recomendada antes de aplicar la decisión.

### Al cerrar un bloque funcional importante

Se considera bloque funcional el tramo identificado como tal en
`docs/ROADMAP.md` o acordado expresamente con Javier. En su cierre se realiza
una auditoría completa del bloque y de sus fronteras de integración, no una
revisión indiscriminada de cada archivo del repositorio.

La auditoría debe revisar:

- Git y los cambios acumulados del bloque.
- El código afectado y la arquitectura relacionada.
- Las migraciones y el estado de Supabase cuando el bloque afecte a base de
  datos, funciones, permisos o RLS.
- Las pruebas y los recorridos completos del usuario incluidos en el bloque.
- `AGENTS.md`, `docs/PRODUCT.md`, `docs/ARCHITECTURE.md` y `docs/ROADMAP.md`.
- Los documentos de dominio directamente relacionados con el bloque.

Actualizar la documentación que haya quedado desfasada y comprobar que código,
base de datos, pruebas y documentación describen el mismo estado del producto.
`docs/HISTORY.md` se utiliza únicamente como contexto histórico: no recuperar
decisiones antiguas o descartadas como si siguieran vigentes.

Antes de abrir otro bloque grande, dejar registrado en `docs/ROADMAP.md` qué
recorrido se cerró, la fecha de la comprobación, sus límites conocidos y el
único siguiente bloque recomendado. Actualizar las fechas de instantánea solo
cuando se hayan contrastado realmente código, migraciones y pruebas.

En resumen:

> Desarrollo cotidiano: inspección localizada → implementación →
> mini-verificación. Cambio transversal: ampliar la inspección antes de
> modificar. Cierre de bloque: auditoría del bloque → documentación →
> validación final.

## Criterios técnicos vigentes

- Flutter/Dart, Supabase, Bloc/Cubit, GetIt, `go_router` y Material 3 son la base
  actual. Verificar las versiones en `pubspec.yaml` y el *lockfile* cuando la
  tarea afecte a paquetes, compatibilidad, compilación o infraestructura.
- La arquitectura modular por funcionalidades es una guía. No añadir capas,
  interfaces o casos de uso que no aporten valor solo para cumplir una
  plantilla.
- `Equatable`, repositorios abstractos y casos de uso con `call()` se mantienen
  donde aporten coherencia, pero no son dogmas.
- Validar en Flutter para la experiencia de usuario y en PostgreSQL para la
  integridad. Usar tipos, claves foráneas, `CHECK`, `UNIQUE` y otras restricciones
  adecuadas.
- Separar permisos administrativos, nivel de suscripción, servicio de
  seguimiento y relación entrenador-cliente. No condensarlos en un único
  campo `role`.
- Los derechos Premium o de seguimiento no pueden ser concedidos por el propio
  cliente.
- Diseñar RLS por recurso y caso de acceso: existen datos propios, contenido
  público, entrenadores, clientes y administradores.
- Versionar rutinas, planificaciones, baremos y el algoritmo para no alterar el
  historial retrospectivamente.
- El algoritmo adaptativo inicial debe ser determinista, explicable, probado y
  auditable, y permitir anulación por el entrenador.
- Cancelar una suscripción conserva el historial. El borrado de una cuenta debe
  contemplar borrado o anonimización conforme a las obligaciones aplicables.

## Prioridad documental

1. Código, esquema SQL, migraciones y configuración comprobables.
2. Este archivo, `docs/DECISIONS.md` y los documentos vigentes de `docs/`.
3. Contexto histórico de `docs/HISTORY.md`, que no debe ejecutarse como una
   lista de instrucciones.

El código describe el comportamiento implementado. Una decisión marcada como
acordada en `docs/DECISIONS.md` puede describir trabajo futuro y no debe
presentarse como implementada hasta que exista evidencia comprobable.
