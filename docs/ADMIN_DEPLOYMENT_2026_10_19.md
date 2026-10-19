# Publicación automática de ADMIN Dev · WEB-006 · 19/10/2026

## Acuerdo y estado

Javier pide automatizar la publicación de las mejoras validadas del admin en
`admin.entrenaop.es`, conectado a desarrollo, sin subir ZIP manualmente.
Se prepara `.github/workflows/admin-dev.yml`. La conexión y la primera ejecución
real siguen pendientes: no dar esta automatización por operativa hasta contrastar
un despliegue de GitHub Actions y su manifiesto HTTPS.

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
4. Conserva el paquete validado como artefacto de GitHub durante 14 días. La
   publicación está desactivada hasta configurar los secretos y poner la variable
   de repositorio `ADMIN_DEV_DEPLOY_ENABLED` a `true`.
5. Antes de transferir contrasta que el commit siga siendo el `main` vigente.
   La cuenta FTPS debe estar confinada por Hostinger a `public_html/admin`. Se
   usa TLS verificado en control y datos, sin FTP en claro ni excepciones de
   certificado. No necesita habilitar SSH del alojamiento.
6. Sube los archivos a `releases/<sha>-<run>-<attempt>/` antes de activar el
   índice mediante rename. El `<base href="/">` conserva las URLs del admin;
   bootstrap, aplicación, CanvasKit y assets usan la misma carpeta de versión.
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
- Usuario específico para CI, por ejemplo `admin_ci`; conservar el nombre completo
  que muestre Hostinger después de crearlo.
- Contraseña única generada y guardada por Javier. El agente no la introduce,
  fotografía ni la solicita en la conversación.

En GitHub, entorno `admin-dev`, guardar como secretos:

- `HOSTINGER_ADMIN_FTPS_USER`: nombre completo de esa cuenta adicional.
- `HOSTINGER_ADMIN_FTPS_PASSWORD`: su contraseña.

La contraseña se introduce directamente en GitHub por el propietario, sin
compartirla con el agente. El host `srv1589.hstgr.io:21` se ha contrastado sin
credenciales con certificado de Hostinger válido y TLS 1.3; el acceso a la carpeta
debe comprobarse en la primera ejecución. El publicador exige que la raíz de la
cuenta tenga el manifiesto actual de ADMIN Dev antes de escribir nada.

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
  La validación real de GitHub y la primera transferencia quedan pendientes.

Referencias: [cuentas limitadas de Hostinger](https://www.hostinger.com/support/1583246-how-to-create-additional-ftp-accounts-in-hostinger/),
[inicialización de Flutter](https://docs.flutter.dev/platform-integration/web/initialization),
[entornos de GitHub](https://docs.github.com/en/actions/how-tos/deploy/configure-and-manage-deployments/manage-environments),
[FTPS de Python](https://docs.python.org/3/library/ftplib.html#ftplib.FTP_TLS).
