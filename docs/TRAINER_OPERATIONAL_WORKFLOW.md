# Trabajo profesional diario · ampliación de los 16 puntos

## Encargo y límites

El 21/10/2026 Javier autoriza implementar los dieciséis puntos de la propuesta,
coordinar los chats de Trainer/ADMIN/arquitectura/dispositivos y usar subagentes.
Ratifica conservar Clean Architecture, código ajeno y capacidades superiores a
las referencias de Harbiz. El mapa transversal y responsables viven en
[PROFESSIONAL_DELIVERY_COORDINATION.md](PROFESSIONAL_DELIVERY_COORDINATION.md).
La autorización de alcance no transforma pruebas físicas, precios ni alta del
proveedor de pagos en hechos ya realizados.

Trainer sigue siendo propietario de sus clientes y entregas. ADMIN conserva su
catálogo y administración de accesos; no recibe por ello lectura de conversaciones,
respuestas, vídeos ni resultados profesionales ajenos. Una identidad puede tener
varios contextos, sin que uno amplíe el acceso del otro.

## Creadores modulares, sin dependencia entre portales

Javier aclara que se refiere especialmente a los editores de programas y ratifica
la independencia de ADMIN y Trainer. Las mejoras generales de composición,
duplicación, búsqueda y edición pertenecen a los componentes compartidos. Cada
portal las consume mediante su adaptador: ADMIN publica contenido oficial y
Trainer guarda contenido privado y lo asigna a sus alumnos. No se importa
`admin_app` desde `trainer_app`, no se copia otro creador y compartir interfaz no
concede permisos. Las capacidades exclusivas se inyectan desde el consumidor;
los límites de acceso se comprueban de nuevo en servidor.

## Agenda mutable y receta fijada

Antes de añadir cambios de fecha/receta se conserva la orden inicial en un ledger
inmutable. Reintentar la asignación original debe devolver la misma pauta aunque
se haya movido después. Una orden nueva aporta identificador, revisión esperada y
payload inmutable. Los cambios se serializan con inicio/baja mediante el bloqueo
del alumno; solo se alteran pendientes sin ejecución y con servicio activo.

Adaptar crea una receta privada para esa entrega. No revisa la biblioteca ni el
programa original; los campos descriptivos de la cita cambian junto a su receta.
La interfaz explica el alcance. Las coincidencias con planes ajenos a este servicio
solo revelan presencia y fecha de otra sesión, nunca sus datos privados.

## Revisión y comunicación

Cada entrega mantiene revisión de resultados y revisión de agenda separadas.
Registrar o corregir una serie, AMRAP o cabecera de ejecución invalida la revisión
anterior; abrir un resultado no lo marca como leído/revisado automáticamente.
Las notas internas se mantienen separadas de mensajes compartidos con el alumno.
Una baja conserva la consulta histórica del servicio y bloquea nuevos envíos.

Las operaciones nuevas necesitan pruebas de aislamiento ADMIN/profesional/alumno,
de respuestas perdidas e inicio/corrección/baja simultáneos. Una cola o indicador
con paginación no se presenta como total si solo refleja filas cargadas.

## Vídeos y medios

Javier confirma expresamente conservar dos vías para el preparador: archivo
propio y enlace externo HTTPS. No se descarga ni realoja automáticamente el enlace.
Las cuotas de alojamiento de EntrenaOP no cuentan el archivo servido por otro
proveedor. Disponibilidad, reproducción y privacidad externas dependen de él.
ADMIN conserva solo subida como opción de autoría, según la corrección expresa
de Javier en ese chat; su adaptador oculta el campo externo sin borrar medios
existentes. La diferencia se inyecta en el componente común, no crea dos campos.

La implementación prepara límites provisionales configurables para medios
privados, separados de las tarifas; no modifica los límites oficiales existentes.
El envío de técnica es una ampliación específica de VID-005 a una ejecución de
sesión asignada, sin abrir una biblioteca de vídeos personales ilimitada.

## Estado

Tramo operativo técnico verificado; ampliación completa aún abierta. El portal
conecta en código Inicio, agenda, adaptación,
revisión, grupos, recurrencias finitas, formularios, ficha/informes y medios;
la app recibe formularios, conversación, técnica contextual del historial y pruebas
versionadas. La agenda profesional representa las pruebas con su tipo propio y
cursor de 200 elementos, separado de las pautas; no permite moverlas como sesiones.
Las versiones publicadas antes de esta ampliación se documentan por separado.

Validación de integración local: diez migraciones nuevas y veinticuatro contratos de
servidor relacionados comprobados juntos en Dev con ROLLBACK; cada contrato se
aísla mediante savepoint. `tools/build_trainer_contract_batch.py` reproduce el
archivo de ensayo sin conectarse a ninguna base. Se actualizan fixtures antiguos
al MFA vigente y al reloj de evaluación de la RPC, sin retirar sus aserciones.
Ocho capturas de widgets reales con datos ficticios se generan con
`trainer_app/tool/trainer_professional_visual_audit_test.dart` y se revisan en
`docs/visual-audit/trainer-professional-2026-10-21/`.

Contratos específicos: [formularios](TRAINER_FOLLOWUP_FORMS.md),
[ficha e informes](TRAINER_CLIENT_WORKSPACE.md),
[medios](TRAINER_PRIVATE_VIDEOS.md),
[grupos y copia](TRAINER_GROUPS_AND_WEEK_COPY.md) y
[recurrencia finita](TRAINER_FINITE_RECURRENCE.md).

Las nuevas previsualizaciones que revelen coincidencias con planificación ajena
exigen acceso profesional vigente; conservar la consulta del servicio propio no
abre nuevas señales de agenda personal tras desactivar el acceso profesional.
No se define por ello una política automática de impago, caducidad comercial o
reducción de cupo. La propuesta de [contrato comercial](TRAINER_COMMERCIAL_CONTRACT.md)
mantiene esos puntos pendientes y separa cualquier ensayo de los derechos reales.

Las diez migraciones ya se han aplicado en Dev: 195 coinciden local/remoto y
los 24 contratos vuelven a pasar con ROLLBACK sobre el esquema aplicado.
La función `exercise-video` se ha desplegado solo en ese proyecto Dev.
No acredita pantallas distribuidas, instalación física ni cierre de los dieciséis
puntos. Quedan guardado, publicación del portal y aceptación real; las pruebas/simulacros tipados
se integran con su [contrato de pruebas](TRAINER_ASSESSMENTS.md); el motor
profesional/cobros tienen dependencias explícitas.


La protección nueva de previsualizaciones usa revisiones privadas por agenda y
un orden de bloqueo verificado con 306 ejecuciones locales de concurrencia. La
copia semanal, las series y el envío conjunto comprobado rechazan una revisión
obsoleta; el endpoint anterior de envío conjunto pierde el grant de cliente.
El borrado de perfil limpia el contador tras sus cascadas. La nueva tabla no
expone contadores al cliente ni adquiere una FK inversa que introduzca un ciclo.
El traslado y la adaptación también enlazan payload y coincidencias a una
previsualización revisada, con recibos estables y rechazo de la API anterior.
La adaptación escribe receta y fecha en un único UPDATE para evitar una segunda
comprobación implícita de FK que invertiría el orden de bloqueo del perfil.

Comprobaciones posteriores a las primeras baterías: `entrena_ui` 19 pruebas y
`trainer_access` 20; dominio comercial 21 escenarios de proveedor ficticio.
El simulacro comercial no acredita persistencia, autenticación HTTP, firma de
webhooks, integración Stripe ni concesión de derechos reales.

Verificación de seguridad del proyecto Dev antes/después: no aparecen nuevos
avisos WARN/ERROR en los asesores. Aumentan en 30 los INFO de RLS sin políticas
para tablas privadas cerradas por grants y accedidas exclusivamente por RPC.
Los avisos preexistentes de funciones definidoras públicas y protección de
contraseñas filtradas no se corrigen ni se atribuyen a esta ampliación. Esto no
sustituye los contratos de autorización, que se han ejecutado sobre el esquema
aplicado. El portal web Dev compila en modo release con CSP y recursos locales.


Matriz final del punto de guardado: raíz 1204 pruebas correctas y una omisión
previa; ADMIN 306 y dos previas; Trainer 101; `workout_editor_ui` 110;
`entrena_ui` 19 y `trainer_access` 20. Análisis global, ADMIN, Trainer y editor
común sin incidencias. Node verifica 48 casos (27 de vídeo y 21 comerciales
simulados). Compilación web Dev correcta de los dos portales. El detalle de
ADMIN y las capturas estrechas viven en [su entrega](ADMIN_PROFESSIONAL_DELIVERY.md).
La recuperación persistente de los creadores es el siguiente tramo técnico;
la propuesta reutiliza checkpoints existentes y no se presenta como implementada.

Referencias de los avisos del asesor conservados: [tablas con RLS cerrado](https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy),
[funciones definidoras anónimas](https://supabase.com/docs/guides/database/database-linter?lint=0028_anon_security_definer_function_executable),
[funciones definidoras autenticadas](https://supabase.com/docs/guides/database/database-linter?lint=0029_authenticated_security_definer_function_executable)
y [protección de contraseñas](https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection).
