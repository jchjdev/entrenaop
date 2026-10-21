# Recuperación profesional y Salud · entrega preparada · 21/10/2026

## Identidad y estado

Fuentes guardadas y subidas a `main`:
`37dcd14b3e2a1df0f23cfc117e2e42d5d8791ca0`. La compilación web se repitió desde
ese commit y el empaquetador comprobó las fuentes consumidas limpias.

- Destino autorizado: `https://trainer.entrenaop.es/`, exclusivamente Dev
  `sxbxfjqgoddzhtcyhalw`.
- Release preparada: `37dcd14b3e2a1df0f23cfc117e2e42d5d8791ca0-20261021-9`.
- ZIP local: `build/trainer-recovery-release-20261021.zip`.
- SHA-256 ZIP: `a831ef00fc6c54c093daa4a5ce7cbb1ed4dd87a3c2beaa448f7ac07045834f75`.
- SHA-256 JavaScript: `fb04edd98edc9d9a371eeb4bc7b3e17ee8b5ce666032f9ca43202dcd8f4d651c`.
- Fecha del manifiesto: `2026-10-21T18:05:08.248887+00:00`.

**La nueva release todavía no está publicada ni verificada por HTTPS/Chrome.**
La sesión anterior del gestor de archivos devolvió 403 durante la carga. Tras
renovarla desde hPanel, la revisión automática del navegador rechazó conceder
autoridad al origen `srv1589-files.hstgr.io`: el gestor muestra también otros
archivos privados del alojamiento. Se solicitó a Javier autorización específica
para ese acceso y para modificar únicamente `public_html/trainer`; permanece
pendiente. No se ha extraído el paquete ni se han cambiado permisos para eludir
el bloqueo. La revisión también rechazó observar hPanel al intentar guardar una
captura del destino; no hay captura nueva ni se solicita ese acceso adicional,
innecesario si el gestor específico queda autorizado. La publicación anterior
conserva su evidencia en
[TRN-020](TRAINER_PROFESSIONAL_RELEASE_2026_10_21.md).

Al recibir autorización, terminar la carga en el directorio no público
`trainer-releases`, extraer solo en `public_html/trainer` conservando releases
anteriores, ejecutar `trainer_release.py verify` y comprobar en Chrome la
recuperación de programas con la sesión MFA existente. Registrar aquí las
capturas y el resultado real antes de declarar publicada esta entrega.

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
