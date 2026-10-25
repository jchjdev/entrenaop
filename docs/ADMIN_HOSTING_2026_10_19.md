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

**Publicado en HTTPS el 19/10/2026:** `https://admin.entrenaop.es/`, conectado
exclusivamente al proyecto Dev `sxbxfjqgoddzhtcyhalw`. Javier ya ha cambiado la
contraseña y activado TOTP con Microsoft Authenticator. La comprobación previa
al despliegue confirma un administrador, un requisito MFA activo y un factor
administrativo verificado. Javier confirma su entrada en el subdominio y se
contrasta el panel autenticado, con las cuatro preparaciones y los dos programas
guiados de Dev. Queda pendiente su confirmación de haber desactivado el permiso
temporal de archivos de la extensión ChatGPT; ya ha indicado que lo desactiva.
La carga ha terminado y no requiere mantener ese permiso.

Paquete completo publicado: `fcf60d7-20261019T095548Z.zip`, SHA-256
`891CCDD254C90E72FD98A2669784CD6A2F65ACC341BE891469E1229275FFBA80`.
El manifiesto remoto acredita revisión `fcf60d7`, entorno `development` y el
proyecto Dev esperado. El JavaScript descargado desde el subdominio coincide
con su SHA-256 `0394034862E227AE62E009089B7D819338371C7B80C4198D797E33FE81AA3E72`.
Se reutiliza el build de aplicación validado en `9d88cd6` y se incorpora la
configuración de Hostinger de `fcf60d7`, sin recompilar ni integrar los cambios
simultáneos de otro chat. Por esos cambios presentes al empaquetar, el manifiesto
registra literalmente `sourceTreeDirty=true`; no se afirma que el checkout
compartido estuviera limpio ni que esos cambios formen parte del JavaScript.

Todos los ZIP y el parche MIME intermedio permanecen en `admin-releases`, fuera
de `public_html`. La extracción definitiva usa solo `public_html/admin`, sin
borrar el `default.php` ni modificar la web principal. La carpeta requiere el
nombre `.` en el selector de extracción de Hostinger para publicar en el destino.

Durante la preparación se corrigen dos incidencias: GoTrue Dart antepone una URI
al SVG y la imagen se codificaba dos veces; se normaliza antes de codificar en
base64. Además, recargar perdía la confirmación de contraseña; el QR tiene ahora
acceso directo y el cambio de contraseña es opcional. Las capturas locales y de
cargas anteriores documentan esas etapas, no la publicación vigente.

`hosted-login.png` y `chrome-hosted-login.png` muestran el acceso real publicado
con campos vacíos en el navegador integrado y en Chrome, respectivamente.

## Acceso y segundo factor

Javier confirma el alta con **Microsoft Authenticator**, no Google Authenticator.
La comprobación de Dev previa a la extracción devuelve un administrador, un
requisito MFA activado y un factor administrativo verificado. El paquete
`9d88cd6-20261019T094805Z.zip` se extrae en `public_html/admin` el 19/10/2026.
El manifiesto público y el SHA-256 del JavaScript servido coinciden con el paquete.
El primer arranque detecta que Hostinger sirve `.wasm` como `text/plain`;
`AddType application/wasm .wasm` en el `.htaccess` exclusivo del subdominio lo
corrige. Las respuestas GET de CanvasKit normal, Chromium y WebParagraph pasan
a `application/wasm`, y una sesión nueva del navegador carga el acceso sin errores.
El paquete completo `fcf60d7-20261019T095548Z.zip` incorpora el ajuste y renueva
también los recursos que Chrome había conservado con el tipo MIME anterior.
Chrome y una sesión nueva del navegador integrado cargan el formulario de acceso.
Javier confirma la entrada remota y se comprueban los catálogos autenticados.
La captura `hosted-authenticated-guided-programs.png` acredita los dos programas
y el trabajo privado recuperable. No se muestra ni se registra su código TOTP.

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

- HTTPS real válido, índice y manifiesto HTTP 200; HTTP redirige a HTTPS,
  `entrenaop.es/admin/` redirige al host administrativo y el listado de CanvasKit
  devuelve 403. Se comprueban CSP, HSTS, noindex, no-sniff, bloqueo de marcos,
  política de permisos, referrer y no-store de los puntos de entrada.
- Manifiesto y JavaScript final coinciden con Dev y el paquete consolidado.
  Motor normal, Chromium y WebParagraph con MIME correcto. Chrome y navegador
  integrado muestran el login; navegar anónimamente a `#/guided-programs`
  vuelve a `#/login` antes de mostrar contenido privado.
- Después del alta real se repite `admin_web_mfa_access.sql` con ROLLBACK y se
  contrasta otra vez el historial de migraciones Dev, sin diferencias.
- Entrada del propietario con Microsoft Authenticator confirmada y panel remoto
  autenticado verificado: cuatro preparaciones, dos programas guiados y el trabajo
  privado de prueba conservado desde local. Se abre «Continuar» en
  `QA recuperacion admin` y se comprueban su nombre, modalidad por fases y estado
  guardado en el editor remoto; se vuelve al catálogo sin modificarlo. No se publica
  contenido de prueba ni se modifica el catálogo del deportista durante la aceptación.

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


## Transporte automático de ADMIN Dev · 25/10/2026

La ejecución `40196467093` de GitHub Actions validó y compiló ADMIN, pero la
publicación falló en la conexión FTPS, antes de iniciar sesión o escribir:
`OSError`, `errno=101`, en tres intentos. El mismo paquete se publicó después
por el administrador de archivos de Hostinger; esa publicación manual no
acredita que se haya recuperado el transporte automático.

`srv1589.hstgr.io` publica direcciones IPv4 e IPv6. El publicador usa ahora
resolución IPv4 explícita, sin fijar una IP que pueda quedar obsoleta. Conserva
el nombre del servidor para SNI y la validación del certificado, TLS 1.2 como
mínimo y el cifrado del canal de datos. No existe alternativa con FTP sin TLS
ni se omite la verificación del certificado.

El workflow incorpora `connection-check` antes de descargar Flutter cuando la
publicación automática está habilitada. Esta comprobación establece la conexión
y negocia TLS sin leer secretos, iniciar sesión ni escribir archivos. Reintenta
solo fallos de transporte, como el despliegue; un certificado inválido detiene
el proceso. Un fallo de esta comprobación no cambia la versión pública.

La activación mantiene la cuenta confinada a ADMIN Dev, el contraste de `main`
antes de cada conexión, los recursos versionados antes de activar la entrada y
la restauración de la entrada anterior si falla la verificación HTTPS. Los
reintentos no se amplían a fallos durante la activación o la restauración.

Verificado localmente el 25/10: 42 pruebas Python del publicador y operaciones
ADMIN correctas, incluidas seis regresiones de transporte; conexión pública
IPv4 y certificado TLS correctos, sin credenciales. La recuperación completa
queda pendiente de una nueva publicación automática desde GitHub Actions y
su comprobación pública: la conectividad local no demuestra la del runner.


### Publicación automática acreditada

La ejecución [40217442803](https://github.com/jchjdev/entrenaop/actions/runs/40217442803)
termina con `validate`, `deploy` y `retain-packages` correctos. El probe IPv4/TLS
pasa desde el runner y se publica sin usar Hostinger manual. HTTPS acredita
fuentes `e790a6af305a7ac52f1d8b47614bf96ff4a23304`, release
`e790a6af305a7ac52f1d8b47614bf96ff4a23304-40217442803-1`, JavaScript SHA-256
`c9612d2a6b3249ce17ade3665ae2b4c0d240f945e2ed248a6afeaab80f46a7fd`,
entrada versionada, cabeceras y MIME WebAssembly. Fuentes limpias al empaquetar.
Análisis ADMIN limpio, 316 pruebas Flutter correctas con dos omisiones previas,
42 Python ADMIN y siete Python Trainer correctas. El fallo de conectividad
anterior queda mitigado y la recuperación automática verificada; una ejecución
correcta no promete disponibilidad permanente de la red del proveedor.
