# Acceso administrativo · 19/10/2026

`security-setup.png` captura el formulario inicial vacío en Chrome,
`http://localhost:55555/#/security`, antes de entregar el control al usuario.
Se comprueba la elegibilidad de su cuenta con Supabase Dev. No se ha solicitado
ni fotografiado una contraseña, QR, clave TOTP o código de verificación.

El subdominio ya está publicado con Dev y la entrada autenticada está comprobada.
Las capturas locales iniciales se conservan como historial y no acreditan el
despliegue remoto por sí mismas.

`hostinger-private-release.png` acredita la carga del primer ZIP en la carpeta
privada, sin extracción pública. Ese paquete requiere sustitución por la
corrección del QR antes de publicar. `security-login-handoff.png` muestra el
acceso local con campos vacíos entregado al usuario.

`qr-format-check.png` muestra una imagen sintética cargada por Chrome mediante
la conversión corregida del formato de GoTrue Dart. Se verifican `complete=true`
y dimensiones naturales de 210×210. No contiene un QR de autenticación válido,
una clave ni datos de ninguna cuenta. La página temporal se retira de `build/web`
antes de preparar el nuevo ZIP.

`hostinger-corrected-release.png` acredita la carga privada del paquete corregido
`c2d7e4e-20261019T093931Z.zip` junto al primero, que queda sustituido para publicar.
Todavía no acredita extracción ni acceso remoto autenticado.

`security-direct-qr.png` muestra en Chrome el acceso directo a «Mostrar QR del
autenticador» y el cambio de contraseña opcional cerrado. Se verifica el botón
visible sin pulsarlo; la captura precede al alta privada del factor por Javier.
El paquete de este flujo fue `9d88cd6-20261019T094805Z.zip`, sustituido después
por el paquete consolidado `fcf60d7-20261019T095548Z.zip` con MIME WebAssembly.

`hosted-login.png` y `chrome-hosted-login.png` acreditan el acceso real desde
`https://admin.entrenaop.es/#/login`, con campos vacíos, en navegador integrado y
Chrome. El manifiesto publicado declara Dev y la revisión `fcf60d7`; su JavaScript
coincide con el SHA-256 contrastado en el documento de despliegue. Una ruta privada
solicitada sin sesión redirige al login. La entrada con contraseña y código del
propietario se realiza mediante entrega del control, sin observar esos datos.

`hosted-authenticated-preparations.png` y
`hosted-authenticated-guided-programs.png` muestran los catálogos Dev después de
que Javier confirme su entrada remota con Microsoft Authenticator.
`hosted-recovered-work.png` acredita la recuperación del trabajo privado de
prueba creado previamente en local, con su nombre y modalidad conservados. Se
vuelve al catálogo sin editar ni publicar el trabajo. El acceso anónimo y el
acceso autenticado pertenecen a sesiones distintas de navegador.
