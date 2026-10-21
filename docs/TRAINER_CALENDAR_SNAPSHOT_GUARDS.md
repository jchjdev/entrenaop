# Vistas previas y agenda concurrente · 21/10/2026

**Integración Dev · 21/10/2026:** migración aplicada dentro del conjunto profesional
de diez; 195 migraciones locales/remotas coinciden. Los 24 contratos relacionados
vuelven a pasar con ROLLBACK sobre el esquema aplicado, sin datos de ensayo
persistentes. La publicación web/móvil se acredita por separado.

La migración `20261021161302_trainer_calendar_snapshot_guards.sql` corrige una
carrera observada en PostgreSQL 17: esperar el advisory del alumno no renueva
una instantánea REPEATABLE READ. Copia y creación de series podían confirmar
una huella antigua después de iniciar una pauta o insertar una coincidencia
personal. El runner preserva los tres casos que fallaban antes del arreglo.

Cada cambio INSERT/UPDATE/DELETE en agenda incrementa una revisión privada por
usuario. No se expone como permiso ni campo modificable por Flutter. Los
contadores se crean al necesitarlos; el UPSERT no-op detecta también una fila
concurrente que no existía en la instantánea RR. Es conservador: un cambio en
otra fecha del mismo alumno también puede exigir reintentar una transacción RR.

Copia, series y envío revisado toman clientes en orden UUID, acceso profesional,
perfiles validados con KEY SHARE y después sus revisiones de agenda. Tras esos
locks releen las coincidencias y comprueban la huella. Solo insertan citas
nuevas; nunca bloquean una cita antigua después del contador. Un escritor RR
que esperaba detrás puede recibir 40001 y debe reiniciar su transacción entera.

El trigger de agenda no pide acceso ni advisory extra y no bloquea perfiles.
La tabla privada no tiene FK hacia perfiles para evitar invertir el orden de
bloqueos de una cita antigua frente al borrado de su perfil. Un trigger AFTER
DELETE de perfil, ordenado después de las cascadas RI, elimina el contador;
el bump omite perfiles ya borrados. Las tablas y helpers tienen RLS y ejecución
revocada a PUBLIC, anon y authenticated. La pertenencia a cartera se valida
antes de tocar cualquier contador derivado de una entrada del cliente.

La entrega conjunta ahora exige una huella mediante
`deliver_trainer_batch_reviewed(p_operation_id,p_recipients,p_fingerprint,...)`.
El endpoint anterior y su función interna dejan de ser ejecutables por el
cliente. El ledger guarda UUID, payload y huella originales: tras una respuesta
incierta se reintenta la misma orden; el recibo confirmado se recupera antes de
exigir una vista previa nueva. Un 40001 definitivo devuelve la interfaz a una
nueva revisión y utiliza otro UUID al volver a confirmar.

El ensayo SQL de este contrato termina en ROLLBACK y comprueba permisos,
ausencia de oráculos de FK, lifecycle de contador y cascade real de perfil.
El runner local usa las funciones de planificación y triggers reales con un
motor deportivo mínimo; sus 276 contenciones y 30 solapes independientes no
acreditan RLS completa, todos los motores personales ni una app publicada.
