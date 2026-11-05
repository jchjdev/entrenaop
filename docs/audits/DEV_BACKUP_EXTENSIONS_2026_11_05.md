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

48 pruebas Python locales correctas. La ejecución CI 42084320986 acredita el
ensayo aislado real de extensiones; no hay Docker local disponible. La copia
42085037509-3 queda restaurada, cifrada y conservada como verified antes de aplicar
la migración de autoría: 4.235.835 bytes, restauración del 05/11/2026 a las
19:06:45 UTC y caducidad del 12/11.

El intento anterior ya superaba restauración y cifrado, pero no conservaba el
paquete por espacio ocupado por compilados Trainer. La retención autorizada
se aplica en 42088472822: cinco Trainer y cinco ADMIN ocupan 158.250.328 bytes.
No se aumenta el presupuesto de 400 MiB ni se eliminan copias de datos.
[Alcance de la limpieza](TRAINER_COMPILED_RETENTION_2026_11_05.md).

La corrección de extensiones no cambia por sí misma esquemas de Dev ni modifica
datos del deportista. La copia posterior a la migración de autoría también completa
el ensayo real: 42092600721-1, restauración verificada a las 19:24:19 UTC,
4.280.331 bytes cifrados y recibo verified a las 19:24:24 UTC, disponible hasta
el 12/11 a las 19:24:21 UTC. Incluye builtin_assessment_private y los vínculos
de revisiones. La recogida de errores de servicios también termina correctamente.
