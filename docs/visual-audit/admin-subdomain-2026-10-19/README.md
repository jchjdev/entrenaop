# Acceso administrativo · 19/10/2026

`security-setup.png` captura el formulario inicial vacío en Chrome,
`http://localhost:55555/#/security`, antes de entregar el control al usuario.
Se comprueba la elegibilidad de su cuenta con Supabase Dev. No se ha solicitado
ni fotografiado una contraseña, QR, clave TOTP o código de verificación.

La puesta en marcha del subdominio está en curso. La evidencia de publicación
y la prueba autenticada se incorporarán después de la configuración privada
del propietario. No interpretar esta captura local como un despliegue remoto.

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
