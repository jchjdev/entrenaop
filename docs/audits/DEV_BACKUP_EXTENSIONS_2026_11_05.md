# Restauración Dev y extensiones · 05/11/2026

Al preparar la autoría versionada FAS/Tropa se comprueban las copias existentes.
La ejecución 42016513181 falla con `isolated_restore_extensions:42939`.
`pg_cron` vive en `pg_catalog`; el exportador generaba CREATE SCHEMA IF NOT EXISTS
para ese nombre reservado. PostgreSQL rechaza la operación aunque el esquema exista.
La última copia registrada como verificada es del 22/10 y caducó el 29/10; no se
presentan las ejecuciones fallidas posteriores como copias recuperables.

El exportador conserva instalación/esquema de cada extensión y omite únicamente
crear `pg_catalog`. Los identificadores se escapan y validan. El ensayo aislado
incorpora `pg_cron` y `pg_stat_statements`, además del nuevo esquema de autoría
`builtin_assessment_private`. Las fuentes del tag de imagen fijado ya precargan
cron y apuntan a la base postgres; no se cambia el contenedor ni sus credenciales.

48 pruebas Python locales correctas. Falta acreditar el ensayo de contenedor en
CI y una copia real cifrada/restaurada antes del cierre del bloque de autoría.
No hay Docker local disponible. Esta corrección no cambia esquemas de Dev ni
modifica datos del deportista.
