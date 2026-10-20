# Recuperación y errores en desarrollo · ADM-002 · 20/10/2026

Javier pide copias y registro de errores para recuperar el trabajo si una prueba
sale mal. El único proyecto autorizado es `sxbxfjqgoddzhtcyhalw` (Dev). No se
habilita restauración sobre una base remota ni se cambia producción.

## Contrato y alcance

GitHub Actions reutiliza `admin-dev`. Recoge errores cada hora y solicita una
copia diaria a las 03:17 UTC; GitHub puede retrasar una ejecución. El disparo
manual permite solicitar otra copia. Sin secretos, el trabajo no accede a Dev
y el admin sigue mostrando que no existe evidencia verificada.

La copia contiene roles sin contraseñas, esquema y datos de `public`, `auth`,
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

GPG cifra con AES-256 y una frase de al menos 24 caracteres transmitida por
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

## Activación preparada

El entorno GitHub `admin-dev` necesita:

1. `SUPABASE_DEV_OPERATIONS_TOKEN`: token limitado al proyecto Dev, con Projects
   read, Database read-write (la conexión temporal del CLI lo exige), Connection
   Pooling read, API Keys read, API Key Secrets read y Logs read. Sin permisos de
   administración/borrado de proyectos ni acceso a producción.
2. `DEV_BACKUP_PASSPHRASE`: frase única de 24 caracteres o más, sin saltos de línea,
   conservada además en el gestor de Javier.

Crear esos accesos persistentes y guardar los valores requiere la intervención
del propietario. Nunca se pegan en el chat ni en el repositorio. La activación
no queda acreditada hasta la primera copia real y su evidencia en ADMIN.

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

## Verificación del punto de preparación

19 pruebas Python correctas, incluido cifrado/descifrado real en Windows,
aislamiento de entorno, privacidad de eventos, presupuesto y análisis de COPY.
Análisis ADMIN limpio, 280 pruebas correctas con dos omisiones previas y build
web release Dev correcto. Cinco SQL con ROLLBACK pasan sobre el esquema instalado,
incluidas las nuevas guardas y regresiones de autoría/publicación/MFA.
La migración nueva es `20261020205917_dev_recovery_observability.sql`.

**Pendiente en este punto:** ensayo Docker en GitHub, secretos, primera copia
real, recogida real y publicación remota de esta interfaz. No confundir la
prueba de cifrado con una copia completa ya disponible.

## Borrado de programas

La consulta de Javier se contrasta en el código: Programas guiados no ofrece
borrado definitivo. Los publicados tienen «⋯ → Retirar del catálogo», que
conserva versiones, sesiones y seguimientos. Los borradores no tienen esa acción
en la tarjeta actual. No se elimina ningún programa ni se añade borrado por el
hecho de preparar copias. Una futura papelera recuperable necesita definir su
efecto sobre familias/versiones y borradores de trabajo antes de implementarse.
