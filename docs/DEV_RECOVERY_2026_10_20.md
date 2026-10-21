# Recuperación y errores en desarrollo · ADM-002 · 20/10/2026

Javier pide copias y registro de errores para recuperar el trabajo si una prueba
sale mal. El único proyecto autorizado es `sxbxfjqgoddzhtcyhalw` (Dev). No se
habilita restauración sobre una base remota ni se cambia producción.

## Contrato y alcance

GitHub Actions reutiliza `admin-dev`. Recoge errores cada hora y solicita una
copia diaria a las 03:17 UTC; GitHub puede retrasar una ejecución. El disparo
manual permite solicitar otra copia. Sin secretos, el trabajo no accede a Dev
y el admin sigue mostrando que no existe evidencia verificada.

La copia contiene roles sin contraseñas, su inventario gestionado, esquema y datos de `public`, `auth`,
`storage`, `admin_ops_private`, `trainer_private` y `supabase_migrations`, las
extensiones necesarias, migraciones del repositorio y los archivos reales de
Storage, incluidos los privados. Los nombres originales de objetos se guardan
en un índice dentro del cifrado; en disco se usan nombres derivados por hash.
Una ausencia, un archivo modificado o una inconsistencia aborta la copia.

**No incluye** los MP4 externos de Bunny, secretos de Edge Functions/proveedores,
claves de firma ni la clave raíz de cifrado de Auth/Vault. No es una imagen
completa de todos los servicios del proyecto. Recuperar en el mismo proyecto
conserva sus claves; migrar a otro exige configurar los servicios y conservar
o restablecer MFA/campos cifrados según la guía de Supabase. Las contraseñas de
roles propios también deben restablecerse. No se promete restaurar Auth/MFA
funcional en otro proyecto únicamente a partir del SQL.

## Copia y ensayo

`dev_operations.py` fija proyecto, repositorio y main. Utiliza CLI 2.117.0 con
hash oficial, sin imprimir salida de dump, respuestas remotas o credenciales.
El paquete se comprueba en `dev_restore_drill.py`: contenedor nuevo de
`supabase/postgres:17.6.1.166` fijado por digest, sin red exterior ni puertos
publicados. Se restauran esquemas/datos, se contrastan las cantidades del COPY,
todas las claves foráneas y la correspondencia entre `storage.objects` y los
archivos incluidos. Se verifica el hash de cada archivo. El contenedor se
retira al terminar; ninguna URL de base remota es un argumento del ensayo.
El inventario de `pg_roles` complementa el exportador oficial, que omite
CREATE/ALTER de roles gestionados. En el ensayo solo se crean los ausentes,
sin LOGIN y conservando los privilegios inventariados; no se reemplaza el
superusuario local. El arranque espera TCP local para evitar el servidor
transitorio de inicialización. Ninguno de estos preparativos se ejecuta en Dev.

La frase se comprueba antes de exportar. GPG cifra con AES-256 y una frase de al menos 24 caracteres transmitida por
entrada estándar, nunca como argumento visible. Se descifra el paquete y se
contrasta su hash con el original antes de subirlo. Solo se sube `*.gpg`;
SQL, índices, metadatos internos y archivos sin cifrar permanecen temporales.

La retención es de siete días. Se limita el origen a 256 MiB, el archivo cifrado
a 16 MiB y la suma de artefactos activos de este repositorio a 400 MiB con margen
de empaquetado. Superar un límite falla y deja aviso; no borra otras versiones
ni contrata capacidad. Estos límites no acreditan el consumo agregado de otros
repositorios de la cuenta; hay que revisarlo antes de ampliar retención/tamaño.

Se registra `verified` solo después de que GitHub confirme el artefacto disponible
y su caducidad. La evidencia incluye hash, tamaño, archivos y fecha del ensayo.
Una copia caducada o de más de 36 h no se presenta como copia diaria reciente.
El paquete cifrado exige conservar la frase en un gestor independiente de GitHub.
Perderla impide descifrar las copias.

## Errores y permisos

La recogida consulta una ventana de 24 h con solapamiento, hasta 1.000 eventos,
y deduplica por identidad. Conserva únicamente servicio, fecha, código y grupo
de componente. No importa mensajes, consultas, URLs, cabeceras, correos o
identidades de usuario. Registra HTTP 5xx y errores PostgreSQL, excluyendo
rechazos habituales de validación/permisos. Una consulta incompleta se indica;
cero filas no acredita ausencia de errores. Auth/Storage propios se recogen
cuando publican el estado esperado; la capa API también registra sus 5xx.

ADMIN añade captura de errores no controlados de Flutter y tareas asíncronas,
con códigos cerrados, grupo de pantalla y revisión compilada. Conserva los
manejadores existentes, limita avisos repetidos y descarta fallos del propio
informador. Los fallos atrapados en formularios no se convierten automáticamente
en errores globales; los errores de servidor correspondientes pueden aparecer
en la recogida. No es monitorización de caídas cuando Supabase o GitHub están
inaccesibles. La fecha de recogida permite detectar ese hueco.

Los eventos se conservan 14 días; el admin muestra hasta 100. Pruebas controladas
pueden generar eventos reales y no deben confundirse con incidencias confirmadas.
Investigar enlaza al proyecto Dev de Supabase. El trabajo registra también
fallos de recogida/copia cuando puede alcanzar la base de datos.

Las tres tablas nuevas son privadas, con RLS y sin grants de cliente. Lectura y
notificación requieren `is_admin()`, incluido MFA. La notificación no acepta
texto libre y tiene límite de servidor. Se revisan los avisos esperados del asesor:
[RLS sin políticas](https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy)
deniega acceso directo; [RPC autenticadas](https://supabase.com/docs/guides/database/database-linter?lint=0029_authenticated_security_definer_function_executable)
tienen guard de servidor. Los avisos anteriores no se declaran solucionados.

## Activación comprobada · 21/10/2026

El entorno GitHub `admin-dev` necesita:

1. `SUPABASE_DEV_OPERATIONS_TOKEN`: token limitado al proyecto Dev, con Project
   Settings read, Database read-write (la conexión temporal del CLI lo exige), Connection
   Pooling read, API Keys read, API Key Secrets read y Logs read. Sin permisos de
   administración/borrado de proyectos ni acceso a producción.
2. `DEV_BACKUP_PASSPHRASE`: frase única de 24 caracteres o más, sin saltos de línea,
   conservada además en el gestor de Javier.

Crear esos accesos persistentes y guardar los valores requiere la intervención
del propietario. Nunca se pegan en el chat ni en el repositorio. La activación
se acredita mediante la primera copia real y su recibo privado `verified`,
consultado por ADMIN. No se han compartido los valores en el repositorio.

## Procedimiento de recuperación

1. Para cambios editoriales recientes, usar primero Historial → Recuperar como
   borrador: conserva el contenido actual y evita restaurar toda la base.
2. Para un incidente mayor, detener escrituras y descargar una copia cifrada aún
   disponible desde su ejecución de GitHub. Guardarla fuera de la cuenta si el
   incidente afecta a GitHub. Verificar hash y descifrar mediante GPG usando la
   frase del gestor. Nunca extraer un paquete que no proceda de la copia validada.
3. Revisar manifiesto, fecha y alcance; repetir el ensayo aislado con los datos
   descifrados antes de elegir destino. Conservar el estado actual del destino.
   Con Docker disponible, ejecutar `python admin_app/tool/dev_restore_drill.py
   --directory <carpeta-del-paquete-descifrado>`. Solo crea un contenedor temporal;
   no tiene una opción de URL de destino remoto.
4. Preparar un destino Dev y sus claves/servicios siguiendo la guía oficial.
   Restaurar con control explícito del destino, con el trabajo de Javier parado.
   La restauración real es una operación separada que requiere autorización;
   el trabajo periódico no la puede ejecutar.
5. Cargar los objetos de Storage bajo sus nombres originales y verificar el
   inventario. Configurar de nuevo secretos/proveedores excluidos y comprobar
   login/MFA, contenido, programas y ejecución antes de reabrir escrituras.

Fuentes comprobadas: [copias de Supabase](https://supabase.com/docs/guides/platform/backups),
[restauración con CLI](https://supabase.com/docs/guides/platform/migrating-within-supabase/backup-restore),
[consulta de logs](https://supabase.com/docs/guides/observability/advanced-log-filtering)
y [tokens limitados](https://supabase.com/docs/guides/platform/personal-access-tokens).

## Verificación y cierre · 21/10/2026

30 pruebas Python correctas, incluido cifrado/descifrado real en Windows,
aislamiento de entorno, privacidad de eventos, presupuesto y análisis de COPY.
Análisis ADMIN limpio, 280 pruebas correctas con dos omisiones previas y build
web release Dev correcto. Cinco SQL con ROLLBACK pasan sobre el esquema instalado,
incluidas las nuevas guardas y regresiones de autoría/publicación/MFA.
La migración nueva es `20261020205917_dev_recovery_observability.sql`.

El ensayo Docker con datos ficticios y las 19 pruebas Python pasan en GitHub
([ejecución 39499687926](https://github.com/jchjdev/entrenaop/actions/runs/39499687926)).
La comprobación previa de la interfaz en `admin.entrenaop.es` corresponde a
`50bb45c52350cb17a537e603784b8076d895bda5`: despliegue correcto e identidad Dev,
hash de JavaScript, activación, caché y cabeceras comprobados por HTTPS.

El token limitado de sustitución está conectado y permite leer/escribir solo
Dev. Caduca a los 90 días; debe rotarse antes de vencer. La recogida real pasa y
su recibo en la base acredita tres eventos sin truncado en
[39503164726](https://github.com/jchjdev/entrenaop/actions/runs/39503164726).
La Management API acepta las fechas UTC terminadas en Z; se cubre la regresión.
Los errores iniciales de credencial y fechas quedan diferenciados por códigos
cerrados, sin publicar cuerpos de respuesta. El fallo de logs tampoco impide
intentar un respaldo, pero mantiene la ejecución fallida para hacerlo visible.

El ensayo ficticio con el grant a un rol gestionado ausente pasa en
[39504020366](https://github.com/jchjdev/entrenaop/actions/runs/39504020366).
La restauración aislada de los datos reales también pasa en
[39504060417](https://github.com/jchjdev/entrenaop/actions/runs/39504060417),
pero esa ejecución termina con `invalid_encryption_passphrase`: no produce
ninguna copia cifrada disponible. Storage inventaría 11 objetos, 1.060.653 bytes.

El 21/10 Javier corrige la frase. La ejecución
[39548459484](https://github.com/jchjdev/entrenaop/actions/runs/39548459484)
supera la restauración y el cifrado, pero falla con `artifact_budget_limit`.
El inventario real contiene 31 compilados ADMIN (486.652.893 bytes), por encima
del presupuesto conservador de 400 MiB. No se sube una copia ni se aumenta
el presupuesto; tampoco se borra ningún archivo durante el diagnóstico.

### Retención de compilados: autorizada el 21/10/2026

`admin_artifact_retention.py` ejecuta un plan de solo lectura por defecto.
Conserva cinco compilados recientes y protege siempre frente a esta limpieza la revisión
publicada. Solo selecciona `admin-dev-<SHA40>` de main cuya revisión coincida
con su ejecución; excluye copias `entrenaop-dev-*`, otros artefactos y expirados.
El plan del 21/10 conserva cinco y retiraría 26 compilados, 407.851.236 bytes.
El código fuente y su historial Git no se retiran; los ZIP antiguos dejarán
de estar disponibles para descargar, aunque pueden volver a compilarse.

Javier autoriza la limpieza inicial y la retención automática limitada descrita
el 21/10. La activación añade un job tras un despliegue correcto. Solo ese job
tiene `actions: write`, sin credenciales de Hostinger ni de Supabase. Antes
de aplicar exige repositorio/main correctos, manifiesto HTTPS de Dev y revisión
publicada coincidente; revisa otra vez la identidad de cada artefacto. Las seis
regresiones de retención cubren exclusiones, versión publicada, contexto y modo
sin mutaciones. Los paquetes conservados siguen sujetos al vencimiento de 14
días del proveedor; esta limpieza no amplía su caducidad.

### Resultado real comprobado

La ejecución [39549982599](https://github.com/jchjdev/entrenaop/actions/runs/39549982599)
pasa análisis, 280 pruebas ADMIN (dos omisiones previas), 30 Python, build,
publicación y retención. La revisión publicada es
`fda22a5ffa9a00ecd0bac2cd1625a4adda0b6527`, contrastada de forma independiente por
HTTPS. Retira 27 compilados (incluido el desplazado por la nueva compilación),
423.611.569 bytes; quedan cinco, 78.801.647 bytes. No retira copias de datos.

La ejecución [39551387164](https://github.com/jchjdev/entrenaop/actions/runs/39551387164)
termina correctamente el 21/10: ensayo ficticio, exportación real, restauración
SQL/Storage aislada, cifrado y descifrado de comprobación, subida y registro de
evidencia. La consulta directa en Dev confirma:

- Recibo `39551387164-1`: `verified`; artefacto GitHub `12323941684`,
  `entrenaop-dev-39551387164-1`, disponible y no caducado.
- Archivo cifrado: 2.253.989 bytes; ZIP contenedor de GitHub: 2.254.179 bytes.
  SHA-256 del archivo cifrado:
  `bf8020cb14838325c4e9e725042a51ece298c5d6b8d7e9126db32717bbb9d0e1`.
- 11 objetos de Storage; ensayo correcto a las 05:49:37 UTC, recibo a las
  05:49:41 UTC; caducidad del artefacto: 28/10/2026 a las 05:49:38 UTC.
- Recogida de servicios correcta a las 05:46:37 UTC, tres eventos reducidos a
  códigos, sin truncar. Su presencia no acredita tres incidencias de producto.

La automatización diaria queda activa, con siete días de retención de copias;
la primera ejecución manual completa está comprobada. La ejecución programada
00:37 UTC también acredita recogida de errores. No se afirma haber observado
ya una copia diaria programada: su primera comprobación llegará con el horario
normal. La interfaz ya desplegada consulta estos recibos reales; no se ha
recargado el trabajo abierto de Javier ni sobrescrito contenido del catálogo.

**Bloque cerrado:** copia disponible, ensayo aislado y registro real de errores.
Se conservan los límites y exclusiones de este contrato. **Único siguiente bloque
recomendado:** papelera recuperable de programas, definiendo antes qué ocurre
con borradores, versiones y sesiones reutilizadas.

## Borrado de programas

La consulta de Javier se contrasta en el código: Programas guiados no ofrece
borrado definitivo. Los publicados tienen «⋯ → Retirar del catálogo», que
conserva versiones, sesiones y seguimientos. Los borradores no tienen esa acción
en la tarjeta actual. No se elimina ningún programa ni se añade borrado por el
hecho de preparar copias. Una futura papelera recuperable necesita definir su
efecto sobre familias/versiones y borradores de trabajo antes de implementarse.
