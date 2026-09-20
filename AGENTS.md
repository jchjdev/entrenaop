# EntrenaOP: guía de trabajo

Este archivo contiene las reglas vigentes para trabajar en este repositorio. Los
documentos de `docs/` amplían el contexto de producto, arquitectura y roadmap.
El código y las migraciones reales tienen prioridad sobre cualquier descripción
histórica.

## Colaboración con Javier

- Trabajar con un ritmo natural de *pair programming* y mantener una visión
  global del producto.
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

- Inspeccionar el código y el estado de Git antes de modificar nada.
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

## Criterios técnicos vigentes

- Flutter/Dart, Supabase, Bloc/Cubit, GetIt, `go_router` y Material 3 son la base
  actual. Verificar siempre las versiones en `pubspec.yaml` y el *lockfile*.
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
2. Este archivo y las decisiones vigentes de `docs/`.
3. Contexto histórico de `docs/HISTORY.md`, que no debe ejecutarse como una
   lista de instrucciones.
