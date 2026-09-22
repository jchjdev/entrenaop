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
- agenda semanal con instantáneas de plantilla y sincronización de estado;
- bloques convencionales, superseries, circuitos y transiciones, intervalos de
  trabajo, Tabata, EMOM y AMRAP;
- creación segura de ejercicios privados con descripción y URL HTTPS opcional.

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

Los tokens, contraseñas y cadenas de conexión no se guardan en este directorio.
