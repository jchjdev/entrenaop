# Supabase

El esquema remoto original fue creado desde el panel y no tenía migraciones en
Git. El catálogo de producción se auditó en modo de solo lectura el 19 de
septiembre de 2026.

## Migraciones iniciales

- `20260919000000_initial_remote_schema.sql` reconstruye las tablas, función y
  trigger originales para entornos nuevos.
- `20260919001000_secure_existing_access.sql` sustituye las políticas remotas
  solapadas por un modelo cerrado por defecto y separa la administración del
  campo comercial heredado `profiles.role`.

La primera migración describe objetos que ya existen en producción. Antes de
usar `supabase db push` contra ese proyecto hay que marcar la línea base como
aplicada en el historial remoto y probar la segunda migración en un entorno
local o de staging. No se debe ejecutar la línea base directamente sobre la
base de producción existente.

Los tokens, contraseñas y cadenas de conexión no se guardan en este directorio.
