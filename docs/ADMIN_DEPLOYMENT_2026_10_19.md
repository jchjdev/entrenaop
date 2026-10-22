# Publicación automática de ADMIN Dev · WEB-006 · 19/10/2026

## Acuerdo y estado

Javier pide automatizar la publicación de las mejoras validadas del admin en
`admin.entrenaop.es`, conectado a desarrollo, sin subir ZIP manualmente.
La publicación automática está activada y comprobada de extremo a extremo:
[ejecución 39240100206](https://github.com/jchjdev/entrenaop/actions/runs/39240100206),
sobre `6c680f6d549db2a39b8ff911d5bb895489540157`, correcta en 8 min 56 s.
GitHub valida ambas aplicaciones, compila, transfiere por FTPS y contrasta el
resultado por HTTPS. Una segunda comprobación independiente confirma el
manifiesto y el JavaScript servidos. Chrome conserva la sesión de Javier y carga
los dos programas guiados publicados y su trabajo privado recuperable.

Los cambios simultáneos de otros chats se conservan y no forman parte de este
trabajo. El flujo construye desde GitHub, con el commit exacto de `main`, no desde
un build local que pueda tener fuentes pendientes de otros equipos.

## Recorrido

1. Un push a `main` que afecte al admin, paquetes compartidos, dependencias raíz
   o al propio flujo inicia la validación. También existe «Run workflow».
2. Descarga Flutter 3.47.5 del proveedor oficial, verifica el SHA-256 fijado,
   resuelve los lockfiles y ejecuta análisis/pruebas de ADMIN. Si hay cambios
   compartidos o el lanzamiento es manual, verifica además el deportista.
3. Prueba el publicador y compila ADMIN exclusivamente para Supabase Dev. No
   ejecuta migraciones ni usa claves administrativas de Supabase. Las migraciones
   siguen requiriendo su validación Dev conforme a `AGENTS.md`.
4. Conserva el paquete validado como artefacto de GitHub hasta 14 días. Desde
   la autorización del 21/10, tras un despliegue correcto un job separado conserva
   los cinco compilados más recientes y protege la versión publicada frente a
   esta limpieza. Solo retira ZIP `admin-dev-<SHA>` comprobados de main; no toca
   copias de datos. Ese job tiene `actions: write` sin credenciales de Hostinger
   ni Supabase. La
   publicación está activada mediante los secretos del entorno `admin-dev` y la
   variable de repositorio `ADMIN_DEV_DEPLOY_ENABLED=true`. Ponerla a `false`
   permite detener publicaciones futuras sin eliminar la versión que está servida.
5. Antes de transferir contrasta que el commit siga siendo el `main` vigente.
   La cuenta FTPS debe estar confinada por Hostinger a `public_html/admin`. Se
   usa TLS verificado en control y datos, sin FTP en claro ni excepciones de
   certificado. No necesita habilitar SSH del alojamiento.
6. Sube los archivos a `releases/<sha>-<run>-<attempt>/` antes de activar el
   índice mediante rename. El `<base href="/">` conserva las URLs del admin;
   bootstrap, aplicación, CanvasKit y assets usan la misma carpeta de versión.
   Desde la corrección del 22/10, los errores temporales de conexión o transferencia
   anteriores a activar permiten hasta tres intentos, con conexión nueva y otra
   comprobación de main. No se reintentan credenciales rechazadas, certificados
   inválidos ni fallos durante activación o recuperación de la entrada anterior.
   Se registra fase, categoría de excepción y códigos numéricos, sin mensajes
   privados del servidor.
7. Verifica manifiesto, SHA-256 remoto del JavaScript, entrada, cabeceras y MIME
   WebAssembly por HTTPS. Si falla tras activar la entrada, intenta restaurar los
   cuatro archivos raíz anteriores y marca la ejecución fallida. Las versiones
   anteriores y `default.php` se conservan; no hay borrado ni sincronización con
   `--delete`. Una pérdida de conexión puede impedir restaurar y requiere revisar
   el estado servido; un error nunca acredita un despliegue correcto.

Solo `main` puede desplegar. El entorno `admin-dev` permite limitar además la
rama que accede a sus secretos. Las ejecuciones se serializan y no se interrumpe
un despliegue activo por otro push. No se modifica la web principal, el proyecto
Supabase de producción ni la autenticación del administrador.

## Configuración privada de una sola vez

En Hostinger, Cuentas FTP del sitio `entrenaop.es`, crear una cuenta adicional:

- Directorio: `/public_html/admin`, sobre el prefijo del dominio que muestra el panel.
- Usuario específico para CI, por ejemplo `adminci` (solo letras y números); conservar el nombre completo
  que muestre Hostinger después de crearlo.
- Contraseña única generada y guardada por Javier. El agente no la introduce,
  fotografía ni la solicita en la conversación.

En GitHub, entorno `admin-dev`, guardar como secretos:

- `HOSTINGER_ADMIN_FTPS_USER`: nombre completo de esa cuenta adicional.
- `HOSTINGER_ADMIN_FTPS_PASSWORD`: su contraseña.

Cuenta creada por Javier y directorio contrastado en Hostinger:
`u287240541.adminci`, confinada a
`/home/u287240541/domains/entrenaop.es/public_html/admin`. El entorno `admin-dev`
de GitHub permite una sola rama, `main`, sin tags ni bypass administrativo de
las reglas configuradas. Ambos secretos guardados; Javier introduce directamente
la contraseña y autoriza expresamente activar la publicación automática el 19/10/2026.
Variable de repositorio `ADMIN_DEV_DEPLOY_ENABLED=true` contrastada en GitHub.
Primera ejecución completa de validación y publicación correcta sobre `main`.

La contraseña se introduce directamente en GitHub por el propietario, sin
compartirla con el agente. El host `srv1589.hstgr.io:21` se ha contrastado sin
credenciales con certificado de Hostinger válido y TLS 1.3; la primera ejecución
real confirma el acceso a la carpeta y la transferencia con TLS verificado.
El publicador exige que la raíz de la cuenta tenga el manifiesto actual de ADMIN
Dev antes de escribir nada.

Al activar `ADMIN_DEV_DEPLOY_ENABLED=true`, GitHub podrá escribir en esa carpeta
tras validar cada push relevante de `main`. Ese acceso persistente requiere la
confirmación del propietario justo al configurar/activar las credenciales. El
flujo y los controles se preparan y verifican antes de esa confirmación.

## Recuperación y límites

La restauración automática cubre un fallo de comprobación durante la ejecución,
no revierte migraciones, datos o permisos. Para un fallo funcional posterior,
corregir o revertir el cambio por contenido en `main` y dejar que el flujo vuelva
a validarlo y publicarlo. No usar force push ni ejecutar una revisión obsoleta
desde otra rama para saltarse las comprobaciones. Las carpetas de versiones se
conservan; su limpieza futura requiere una política acordada, sin borrado ahora.

## Validación de la preparación

- Nueve pruebas Python correctas: guardas de entorno y rutas, build incompleto,
  contrato de bootstrap, no activar archivos parciales, conservación de archivos
  ajenos, restauración y detección de SHA-256 remoto incorrecto.
- Chrome carga el build previo validado con la distribución versionada, desde
  un servidor local de prueba, con URLs estables y sin errores de arranque.
  `versioned-release-preview.png` contiene solo el login vacío de esa prueba;
  no acredita todavía un despliegue automatizado.
- Flutter y acciones oficiales de checkout/artefactos fijados por versión/hash.
- [Ejecución 39237918107](https://github.com/jchjdev/entrenaop/actions/runs/39237918107):
  validación correcta del commit `24d59946a4ca0d24deae17a6a7a8dbf58d7ed79b` en
  GitHub Actions, con análisis y batería completa de ADMIN, nueve pruebas Python,
  compilación y artefacto conservado. Publicación omitida deliberadamente porque
  en esa ejecución la conexión aún no estaba activada. La primera transferencia
  se acredita después con la ejecución completa indicada arriba.

Referencias: [cuentas limitadas de Hostinger](https://www.hostinger.com/support/1583246-how-to-create-additional-ftp-accounts-in-hostinger/),
[inicialización de Flutter](https://docs.flutter.dev/platform-integration/web/initialization),
[entornos de GitHub](https://docs.github.com/en/actions/how-tos/deploy/configure-and-manage-deployments/manage-environments),
[FTPS de Python](https://docs.python.org/3/library/ftplib.html#ftplib.FTP_TLS).

## Evidencia del primer despliegue completo

- Revisión publicada: `6c680f6d549db2a39b8ff911d5bb895489540157`.
- Versión: `6c680f6d549db2a39b8ff911d5bb895489540157-39240100206-1`.
- Entorno: `development`, proyecto `sxbxfjqgoddzhtcyhalw`.
- SHA-256 del JavaScript servido:
  `68df267d85d5efd294f2f0e3d970e540b3e7c542a9a2598c33a53c467c54e2eb`.
- Validación de app y ADMIN correcta, nueve pruebas del publicador, compilación,
  artefacto y transferencia completos. Manifiesto, hash, índice, no-store,
  X-Frame-Options DENY y MIME WebAssembly comprobados también desde este equipo.
- Capturas y manifiesto público conservados en
  `docs/visual-audit/admin-subdomain-2026-10-19/`.
- GitHub muestra dos avisos del proveedor por acciones de artefactos que declaran
  Node 20 y ejecuta con Node 24. Ambas funcionan en esta ejecución; actualizar
  sus hashes requiere comprobar primero el contrato de sus nuevas versiones.

No hace falta subir ZIP ni habilitar permisos de archivos de la extensión.
Los cambios de contenido guardados en el admin se persisten en Dev directamente;
solo los cambios del código necesitan este flujo de publicación.


## Comprobación del disparo automático por push

El punto de guardado `04ea36d2c6b86a403764a881b1f7644f87c87d77` inicia por sí
solo la [ejecución 39241531224](https://github.com/jchjdev/entrenaop/actions/runs/39241531224),
con evento `push`, sin usar «Run workflow». Termina correctamente en 5 min 29 s:
validación ADMIN, publicador, compilación y publicación. No repite deportista
porque ese commit solo modifica documentación y evidencia, sin código compartido.
El manifiesto público corresponde a esa revisión y a la versión
`04ea36d2c6b86a403764a881b1f7644f87c87d77-39241531224-1`.
Verificación HTTPS independiente correcta, con el mismo SHA-256 del JavaScript
anterior porque no cambia código Dart. Evidencia: `github-ci-push-success.png` y
`ci-push-deployed-build-info.json`. La documentación posterior fuera de
`admin_app/` no inicia compilaciones adicionales.
