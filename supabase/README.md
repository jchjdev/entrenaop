# Supabase

El esquema remoto original fue creado desde el panel y no tenía migraciones en
Git. El catálogo de producción se auditó en modo de solo lectura el 19 de
septiembre de 2026.

## Línea base y evolución

- `20260919000000_initial_remote_schema.sql` reconstruye las tablas, función y
  trigger originales para entornos nuevos.
- `20260919001000_secure_existing_access.sql` sustituye las políticas remotas
  solapadas por un modelo cerrado por defecto y separa la administración del
  campo comercial heredado `profiles.role`.

Las migraciones posteriores constituyen el esquema funcional vigente del
repositorio. Incorporan, en orden:

- historial de evaluaciones, recomendaciones de foco, preferencias y varias
  preparaciones activas;
- plantillas jerárquicas, ejecuciones, resultados por serie, abandono, notas,
  vídeos, correcciones auditadas y recibos idempotentes;
- creación, duplicado, archivado y revisiones versionadas de sesiones
  personales;
- agenda semanal con instantáneas de plantilla y sincronización de estado; el
  deportista programa contenido libre sin vínculo, mientras las asignaciones a
  preparaciones oficiales quedan reservadas a servicios de confianza;
- bloques convencionales, superseries, circuitos y transiciones, intervalos de
  trabajo, Tabata, EMOM y AMRAP;
- creación segura de ejercicios privados con descripción y URL HTTPS opcional;
- Carrera V1 con prescripción por distancia o duración, ritmo, recuperaciones,
  resultados manuales, correcciones y controles de 2 km por preparación;
- borradores de programas y sesiones oficiales, publicación, revisiones,
  catálogos general/por programa y retirada protegida desde `admin_app/`;
- programa, baremos mínimos, registro e historial separados para la evaluación
  periódica FAS 2027, con edad comprobada desde el perfil.

Las funciones sensibles toman el usuario de `auth.uid()`, validan de nuevo los
borradores y escriben jerarquías completas en una transacción. Las políticas
RLS y los `CHECK` de PostgreSQL son parte del contrato, no una duplicación
prescindible de las validaciones de Flutter.

La primera migración describe objetos que ya existían en producción al recuperar
el proyecto. Antes de
usar `supabase db push` contra ese proyecto hay que marcar la línea base como
aplicada en el historial remoto y probar la segunda migración en un entorno
local o de staging. No se debe ejecutar la línea base directamente sobre la
base de producción existente.

El contenido de este directorio demuestra el estado esperado del esquema, no
el despliegue efectivo de cada migración. Ese estado debe comprobarse contra el
historial remoto antes de cualquier publicación.

## Verificación

**COM-008 · 10/10/2026:** 138 migraciones coincidentes en EntrenaOP Dev, hasta
`20261010003000`. Las cuatro nuevas migraciones incorporan derechos temporales
Pro, cuotas Free 8/4, guardas comerciales con propiedad comprobada primero y
creación oficial fuera de la cuota personal y conservación del estado de los
programas terminados o pausados por el usuario. La gestión administrativa de prueba
requiere permiso y una habilitación de servidor cerrada por defecto; se habilita
expresamente en Dev. No hay proveedor de cobro, eventos ni suscripciones de tienda.

Dieciséis pruebas SQL transaccionales con `ROLLBACK` correctas: nueva cobertura
comercial, trece regresiones de programas/semanas/carrera y los smoke tests de
edición de ejercicios personales y borradores oficiales. Los fixtures deportivos
conceden derechos temporales dentro de su transacción; la prueba comercial
comprueba Free, Pro, cuotas, caducidad, RLS y administración. No dejan datos de
prueba. [Contrato, verificación y recorrido](../docs/PRO_LAUNCH.md).
Esta comprobación acredita desarrollo, no producción ni una reconstrucción vacía.

A 6 de octubre de 2026, las 131 migraciones locales coinciden con el historial
del proyecto enlazado de **desarrollo**, hasta `20261006005000`. En el inicio de
la auditoría, solo 50 estaban en el commit de Git y 81 estaban sin seguimiento.
Coincidencia de versiones desplegadas no significa que el trabajo local esté
guardado en Git ni que se haya reconstruido una base vacía.
Esta comprobación no acredita el estado de producción.

Se ejecutaron las 55 baterías SQL existentes con transacción y `ROLLBACK`.
Una expectativa obsoleta de tamaño global en `strength_training_profiles_smoke.sql`
falló inicialmente; se sustituyó por el conjunto visible según enlaces públicos,
manteniendo la exclusión explícita del perfil interno, y la repetición pasó.
El esquema instalado tiene 51 tablas públicas con RLS; las dos vistas de
evaluaciones son `security_invoker` y las funciones `SECURITY DEFINER` públicas
tienen `search_path` explícito. Los detalles y límites están en
[AUDIT_2026_10_06.md](../docs/AUDIT_2026_10_06.md).

Las pruebas SQL de `supabase/tests/` se ejecutan contra desarrollo, abren una
transacción y terminan con `ROLLBACK`; no dejan los datos temporales creados
durante la verificación:

- `admin_workout_draft_smoke.sql`: permisos, borradores, publicación,
  revisiones, catálogos y retirada administrativa;
- `running_security_smoke.sql`: resultados de carrera, validaciones, propiedad
  y controles de 2 km por preparación;
- `fas_periodic_security_smoke.sql`: propiedad, edad, conjunto obligatorio de
  pruebas e historial de la evaluación periódica;
- `exercise_creator_security_smoke.sql`: separación entre ejercicios privados
  y oficiales, autorización administrativa e invariantes de origen y propiedad.
- Las demás baterías cubren evaluación configurable, carrera v1–v5, catálogo y
  estrategias de rendimiento, semanas coordinadas, ciclo adaptativo, alcance,
  pausa/reanudación, contexto compartido y portadas. La lista completa comprobada
  figura en el informe de auditoría.

Ejecutar primero `supabase migration list` y después la prueba relacionada con
el cambio mediante `supabase db query --linked --file <ruta>`. Una nueva función,
restricción o política RLS sensible debe incorporar o ampliar su prueba SQL en
la misma tarea.

Los tokens, contraseñas y cadenas de conexión no se guardan en este directorio.
