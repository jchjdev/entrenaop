# Recuperación profesional y Salud · Trainer publicado en Dev · 21/10/2026

## Identidad y estado

Fuentes guardadas y subidas a `main`:
`37dcd14b3e2a1df0f23cfc117e2e42d5d8791ca0`. La compilación web se repitió desde
ese commit y el empaquetador comprobó las fuentes consumidas limpias.

- Destino autorizado: `https://trainer.entrenaop.es/`, exclusivamente Dev
  `sxbxfjqgoddzhtcyhalw`.
- Release publicada: `37dcd14b3e2a1df0f23cfc117e2e42d5d8791ca0-20261021-9`.
- ZIP local: `build/trainer-recovery-release-20261021.zip`.
- SHA-256 ZIP: `a831ef00fc6c54c093daa4a5ce7cbb1ed4dd87a3c2beaa448f7ac07045834f75`.
- SHA-256 JavaScript: `fb04edd98edc9d9a371eeb4bc7b3e17ee8b5ce666032f9ca43202dcd8f4d651c`.
- Fecha del manifiesto: `2026-10-21T18:05:08.248887+00:00`.

**Publicación completada y verificada por HTTPS y Chrome.** Javier confirma
expresamente el acceso a Hostinger y su gestor para actualizar exclusivamente
`public_html/trainer`. Esto resuelve el bloqueo de autorización registrado en
`a686758`; no se cambian permisos del alojamiento ni se elude la revisión.

Se renueva la sesión desde hPanel y se carga el ZIP en `trainer-releases`, fuera
de la raíz pública. El selector de extracción confirma
`/files/public_html/trainer/` antes de activar sobrescritura y extraer con nombre
de carpeta `.`. No se modifican archivos de ADMIN ni se eliminan releases previas.
El SHA-256 del ZIP local se contrasta otra vez antes de extraer.

`trainer_release.py verify --output build/trainer-recovery-release-20261021`
termina correctamente: manifiesto, revisión, release, hash del JavaScript,
entrada activa, cabeceras y MIME de WebAssembly coinciden con el paquete.
La publicación anterior conserva su evidencia histórica en
[TRN-020](TRAINER_PROFESSIONAL_RELEASE_2026_10_21.md).

## Verificación en Chrome

Se conserva la sesión MFA existente y el acceso profesional de cinco plazas
(cero ocupadas). La biblioteca carga desde el servidor y muestra Trabajos
incompletos sin errores; la cuenta no tiene montajes guardados. Crear programa
abre el editor común en una URL estable `/programs/work/<UUID>`, con guardado
parcial, rutina/fases y acceso a sesiones privadas. Se vuelve a la biblioteca
sin escribir ni guardar; permanece vacía. No se crean clientes, sesiones,
programas o trabajos de prueba.

El registro capturado no muestra errores de aplicación en este recorrido;
aparecen únicamente errores de conexión de la extensión KeePassXC. La
recuperación de un trabajo ya escrito, los reintentos y la concurrencia se
acreditan por las pruebas de la matriz, no por esta navegación sin escrituras.

- [Biblioteca publicada](visual-audit/trainer-recovery-2026-10-21/programas-dev-publicado.png).
- [Editor común publicado](visual-audit/trainer-recovery-2026-10-21/creador-dev-publicado.png).

Se deja abierta la biblioteca. Esta comprobación no acredita aceptación con dos
cuentas humanas, archivos reales ni distribución de la app del deportista.

## Cambios y comprobaciones

Los programas privados reutilizan `GuidedWorkRepository`, controlador y editor
comunes. Disponen de URL estable, guardado de campos incompletos, reanudación,
descarte confirmado y finalización atómica. El editor conserva la posición exacta
de sesiones repetidas, compara mapas sin depender del orden de claves y evita
duplicar un enlace al reintentar una respuesta incierta. Estas correcciones
compartidas benefician también a ADMIN.

Las RPC profesionales enlazan la petición a la cuenta autenticada. Salud añade
historial privado, ruta de perfil y configuración nativa iOS a la app principal;
no comparte automáticamente registros con entrenadores.

Dos migraciones aplicadas solo en Dev; 197 migraciones locales/remotas
coincidentes, cero pendientes. Los 26 contratos pasaron juntos sobre el esquema
aplicado con `ROLLBACK`. La recuperación de programas verifica 108 contenciones
locales RC/RR. El asesor conserva los WARN anteriores y añade únicamente cuatro
INFO por tablas privadas cerradas.

Matriz final: raíz 1220 correctas y una omisión previa; Trainer 137; ADMIN 306 y
dos omisiones previas; editor común 124; acceso compartido 20. Análisis de las
aplicaciones y editor limpios. Cuarenta y dos archivos Dart sin cambios de
formato. Compilación web Dev de Trainer y APK de desarrollo correctos.

Dispositivos confirma la CI de Salud `39649281298` sobre este commit terminada
con éxito: Android `119393027027` e iOS `119393027073`, incluido el paso de
compilación de la app principal iOS sin firmar ni publicar. No hay distribución
móvil ni aceptación física de esta integración principal. Android informa que
la lectura nativa de Salud todavía no está integrada.

Dispositivos confirma también la CI ADMIN `39649281484` de este commit terminada
con éxito: validación, despliegue y conservación del paquete. El paso de
publicación incluye comprobación HTTPS; la aceptación visual de los creadores
corresponde al responsable ADMIN. Este resultado no publica Trainer.

## Límites y continuación

La recuperación de sesiones internas sigue pendiente. No se abre otro editor ni
se generalizan permisos del administrador: ADMIN prepara el puerto común y
Trainer sus adaptadores y contratos privados. La finalización incierta debe
quedar recuperable al recargar; un enlace hijo pendiente no puede crear otra
sesión ni sustituir una posición distinta.

Los dieciséis puntos continúan abiertos con su estado individual en
[coordinación](PROFESSIONAL_DELIVERY_COORDINATION.md). Cobros reales, motor
profesional, notificaciones y aceptación con cuentas/dispositivos reales
conservan sus dependencias. Esta entrega no acredita producción ni cobros.

Contratos responsables: [programas](TRAINER_PROGRAM_WORK_DRAFTS.md),
[cuenta autenticada](TRAINER_ACCOUNT_REQUESTS.md),
[historial de Salud](DEVICE_RUNNING_HISTORY.md).
