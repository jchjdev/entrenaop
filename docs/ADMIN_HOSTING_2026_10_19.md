# ADMIN en Hostinger conectado a desarrollo · WEB-005 · 19/10/2026

## Alcance autorizado y estado

Javier autoriza publicar `admin.entrenaop.es` conectado a **EntrenaOP Dev** y
probarlo con su única cuenta administrativa. Confirma que usa esa misma cuenta
para entrenar en la aplicación del deportista. Una contraseña cambiada desde
cualquiera de las dos aplicaciones sirve para ambas dentro de Dev. No se crea
otra identidad ni se modifica el proyecto de Supabase de producción.

Comprobado en el panel de Hostinger: alojamiento PHP/HTML Premium existente,
espacio disponible y subdominio creado con carpeta `public_html/admin`.
DNS resuelve y HTTPS valida correctamente, sin omitir la verificación TLS.
La web principal y su repositorio independiente `website/` no se modifican.

El paquete de la revisión `2939c96` está cargado en `admin-releases`, fuera de
`public_html`, y todavía no se ha extraído en el subdominio. Javier confirma el
cambio de contraseña y ha habilitado temporalmente el acceso a archivos de la
extensión de Chrome para esta carga. Queda pendiente que desactive ese permiso
al terminar. La publicación y el recorrido con la cuenta real quedan pendientes
del alta del autenticador por el propio Javier. La comprobación de Dev después
de su aclaración sigue mostrando un administrador, ningún requisito MFA activado
y ningún factor administrativo verificado. Este apartado se
actualiza con la evidencia de publicación; no acredita por sí mismo un panel
ya operativo en el subdominio.

Paquete cargado: `2939c96-20261019T090124Z.zip`, SHA-256
`057CD1EC7CA0009787E3C2A4511667373F4767C1651636BE566A50188543AD31`.
Este primer paquete queda sustituido para publicar: Javier detecta que la imagen
TOTP no carga. GoTrue Dart 2.27.2 antepone `data:image/svg+xml;utf-8,` al SVG
de Auth y la pantalla codificaba de nuevo toda esa URI. Se retira el prefijo
del SDK antes de generar una URI SVG base64, conservando los caracteres del SVG.
No cambia el factor ni el mecanismo de autorización. El admin local está
recompilado y el paquete corregido ya está cargado en la misma carpeta privada:
`c2d7e4e-20261019T093931Z.zip`, SHA-256
`0557D8AAFC5BC95302F29E820C096716501750BC90CFFE641D60B0B955B0A414`.
Su manifiesto indica revisión `c2d7e4e`, fuentes limpias y SHA-256 del JavaScript
`615EA8A181B4D38B43E996D79650C6D821C5855F4E9AD69626A2428AD47A4864`.
`hostinger-corrected-release.png` acredita esa carga. Se conserva el ZIP anterior
sin extraerlo. La extracción pública sigue pendiente del alta del autenticador.
La captura `hostinger-private-release.png` acredita únicamente la carga privada.
`security-login-handoff.png` muestra el acceso local entregado al propietario,
con campos vacíos, antes de configurar el autenticador.

Después de separar la contraseña del alta del autenticador queda preparado
localmente `9d88cd6-20261019T094805Z.zip`, SHA-256
`74315EDCABB5041B2D1C2414419BDCE8D896EEDA96149E8C6C75E38C4AC8EA84`.
Es el paquete vigente para la publicación y todavía debe cargarse en Hostinger;
los paquetes privados anteriores se conservan sin extraer. La revisión es
`9d88cd6`, las fuentes están limpias y el SHA-256 del JavaScript es
`0394034862E227AE62E009089B7D819338371C7B80C4198D797E33FE81AA3E72`.
La captura `security-direct-qr.png` acredita la pantalla real local con el botón
directo visible y la contraseña opcional cerrada, antes de generar el factor.

## Acceso y segundo factor

El router comprueba el estado administrativo antes de resolver una ruta
privada. `/security` vive fuera del marco de contenido y permite completar:

1. Acceso directo a «Mostrar QR del autenticador». Javier confirma que la
   contraseña ya está cambiada y comunica que la recarga le devuelve al cambio
   de contraseña. Se retira esa barrera de estado local: actualizar la contraseña
   queda en un apartado opcional cerrado, con mínimo de 16 caracteres y máximo
   de 72 bytes. La recarga no exige repetir ni confirmar el cambio para llegar al
   QR. Esto no certifica la fortaleza de una contraseña desde el cliente.
2. Revocación de la renovación de otras sesiones mediante Supabase Auth,
   conservando esta sesión de configuración. Se realiza antes de generar el
   factor aunque no se use el formulario opcional de contraseña. Un fallo permite
   reintentar desde el mismo botón, sin generar el factor hasta completar el cierre.
3. Alta de TOTP con QR o clave manual, verificación del código y activación
   del requisito de MFA en servidor. Las siguientes entradas piden el código.

Contraseñas, QR, clave TOTP y códigos son introducidos y conservados por el
usuario. No se almacenan en preferencias ni logs ni se capturan como evidencia.
Un fallo al revocar otras sesiones se reintenta sin cambiar otra vez la
contraseña; un fallo al confirmar el requisito después de verificar TOTP
reintenta ese paso sin volver a consumir el mismo código.

`admin_security_requirements` mantiene un requisito activado por administrador.
No tiene acceso directo para anon/authenticated. La activación requiere permiso
administrativo real, JWT AAL2 y factor verificado; el cliente no puede desactivarlo.
`is_admin()` incorpora ese requisito y devuelve **false**, nunca NULL, cuando
falta la claim o el factor verificado. Se conservan los controles de propiedad,
contenido y permiso comercial. La operación antigua de reinicio de ensayos y
su indicador de capacidad pasan a usar esta misma comprobación.

Durante la puesta en marcha no se activa el requisito hasta que el propietario
verifica el autenticador. Antes de publicar el contenido se comprueba que la
única cuenta administrativa ya tiene el requisito activo y un factor verificado.
El dato editable `user_metadata` no concede ni retira autoridad.

La app del deportista conserva el uso normal de sus datos con su sesión; una
sesión sin AAL2 deja de tener facultades administrativas cuando se activa MFA.
Cambiar la contraseña y verificar el factor pueden requerir volver a iniciar
sesión en otros dispositivos/orígenes. Revocar sesiones impide renovarlas;
los JWT ya emitidos conservan su vigencia hasta caducar según Supabase. El
requisito MFA de servidor bloquea las antiguas sesiones AAL1 para administrar.

Si se pierde el autenticador, no existe una opción Flutter para quitar esa
protección. La recuperación requiere intervención del propietario verificado
en el proyecto de Supabase y una actuación de confianza específica. La clave
de configuración debe conservarse mediante el mecanismo seguro del autenticador
o gestor elegido; no se prometen códigos de recuperación de Supabase.

## Paquete y alojamiento

`admin_app/tool/prepare_hostinger_dev.ps1` genera un paquete nuevo bajo `build/`
sin borrar paquetes anteriores. Compila en release con configuración Dev,
`--csp`, recursos web locales y sin mapas de fuentes. Comprueba que el ZIP tenga
el índice, JavaScript, robots, metadatos y `.htaccess`, y rechaza fuentes Dart,
mapas o archivos de entorno. El manifiesto público incluye revisión, estado de
los archivos fuente y SHA-256 del JavaScript, sin secretos administrativos.

`deployment/hostinger-dev.htaccess` se aplica **solo a la carpeta del admin**:

- HTTPS y nombre canónico `admin.entrenaop.es`, sin listar directorios.
- CSP: scripts locales, ejecución WebAssembly limitada al motor de Flutter,
  sin objetos embebidos ni inclusión en marcos externos. HTTPS para los medios
  y conexiones conserva los proveedores de foto/vídeo admitidos por el editor.
- Protección contra interpretación de tipos, referencias salientes sin URL
  de origen, HSTS del subdominio y permisos de dispositivo limitados.
- Índice, arranque, JavaScript principal y metadatos sin almacenamiento en caché.
- `noindex`, `nofollow` y robots: control de indexación, no autorización.

El bootstrap no registra un service worker para uso sin conexión. El contenido
del deportista y las credenciales no se incluyen en el ZIP; Supabase aplica sus
permisos a las consultas. No se usan claves service role en Flutter. El ZIP y
los paquetes de respaldo deben conservarse fuera de `public_html`.

La navegación mantiene URLs con hash, por lo que recargar no exige reescribir
las rutas del admin a través de la web pública. La dirección raíz sirve
`index.html` como prioridad; el `default.php` de Hostinger se conserva.

## Validación del bloque

- Análisis de ADMIN limpio, 176 pruebas correctas y dos capturas optativas
  existentes omitidas; compilación web con la configuración
  de publicación. Pruebas de denegación a no administradores, guardado de
  contraseña independiente del cierre de sesiones, acceso directo al QR después
  de recargar, reintento de revocación sin pedir contraseña, fallo/confirmación MFA,
  ruta privada y pantalla estrecha con texto 2×. El formulario opcional mantiene
  su expansión al mostrar errores y no bloquea el acceso al autenticador.
- Regresión del QR: conversión del formato real de GoTrue y del SVG sin prefijo,
  incluidos colores con `#`. Chrome carga una imagen sintética de 210×210 usando
  la conversión de producción (`complete=true`, dimensiones naturales 210×210).
  `tool/verify_admin_totp_qr.dart` permite regenerar esta comprobación sin cuenta
  ni secretos y fuera del directorio empaquetado. El lanzador de pruebas web de
  Flutter no completó el arranque en este equipo; la comprobación en Chrome se
  realizó por el servidor local existente con el navegador conectado.
- `supabase/tests/admin_web_mfa_access.sql`: activación autorizada, requisito
  persistente, AAL1 y claim ausente rechazados, RLS, RPC de escritura y reinicio,
  permisos comerciales, factor retirado y metadatos sin autoridad. Fixtures
  sintéticos nuevos y ROLLBACK; ningún secreto real se consulta.
- Regresiones SQL de autoría, categorías, seguimiento y recuperación de
  programas correctas antes de la activación en la cuenta real. Los tests SQL
  que suplantan un admin existente deben simular AAL2 cuando tenga MFA activo;
  no desactivar MFA para hacerlos pasar.
- Historial local/Dev coincidente para
  `20261019084842_admin_web_mfa_access.sql`. Asesores revisados: avisos genéricos
  de SECURITY DEFINER con verificación explícita; `is_admin` conserva sus permisos
  previos para no romper políticas anónimas y devuelve false sin identidad.
- Formulario local cargado con la cuenta real, todavía vacío en la captura
  previa a entregar el control de credenciales. No se observa el formulario
  mientras el usuario introduce sus datos o configura el autenticador.

Las pruebas SQL directas usan claims sintéticas dentro de transacciones;
la validación final de acceso desde internet requiere el inicio de sesión
del propietario en el subdominio y el código de su autenticador.

Referencias: [MFA de Supabase](https://supabase.com/docs/guides/auth/auth-mfa),
[TOTP](https://supabase.com/docs/guides/auth/auth-mfa/totp),
[contraseñas](https://supabase.com/docs/guides/auth/password-security),
[alta de factores de Auth](https://github.com/supabase/auth/blob/master/internal/api/mfa.go)
y [subdominios de Hostinger](https://www.hostinger.com/support/1583405-how-to-create-and-delete-subdomains-in-hostinger/).
