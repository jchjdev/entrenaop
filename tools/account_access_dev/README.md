# Cuenta · configuración de desarrollo

Proyecto permitido: **entrenaop-dev**, `sxbxfjqgoddzhtcyhalw`. No usar estos
comandos contra producción ni aplicar el `supabase/config.toml` general generado
por `supabase init`, que contiene valores distintos a los del proyecto remoto.

## Retornos

La configuración parcial declara retornos de localhost/127.0.0.1 y el callback
móvil. Antes de aplicar, inspeccionar el diff:

```powershell
supabase config diff --workdir tools/account_access_dev --project-ref sxbxfjqgoddzhtcyhalw --output-format json
```

## Correo de recuperación

Javier acuerda utilizar **EntrenaOP <acceso@entrenaop.es>**, una dirección propia
para el acceso, separada de su correo personal de empresa. El asunto y HTML de
recuperación están en `supabase/config.toml` y `supabase/templates/recovery.html`.
El HTML conserva `{{ .ConfirmationURL }}` para botón y enlace alternativo; no
recibe ni solicita contraseñas, no añade seguimiento ni fija la duración del
enlace. Utiliza el logotipo público actual de la web, con texto alternativo.

**Estado al 08/10/2026:** buzón activo, **SMTP conectado y asunto/HTML españoles
aplicados y comprobados en desarrollo**. Javier ha completado la contraseña en
Hostinger y la configuración SMTP en Supabase. La consulta remota acredita host,
puerto, usuario, remitente y nombre acordados; también coincide exactamente la
plantilla versionada. El bloqueo HTTP 400 inicial del proveedor predeterminado
queda resuelto al conectar SMTP propio. No se ha comprado ningún plan ni se han
modificado DNS o producción. La entrega real y el recorrido desde el correo aún
están pendientes.
Confirmación de alta y otras plantillas no se modifican en este tramo.

El CLI instalado 2.117.0 compara el `subject` de esta plantilla, pero no carga
su `content_path` en ese recorrido remoto. No basta un diff limpio del CLI para
afirmar que el HTML está aplicado. `apply_recovery_template.py` utiliza la
Management API oficial, dirige la operación únicamente al proyecto de
desarrollo y permite comprobar ambas propiedades antes/después:

Requiere Python 3.11 o posterior; utiliza únicamente la biblioteca estándar.

```powershell
# SUPABASE_ACCESS_TOKEN debe estar disponible mediante configuración segura,
# nunca escrito en el código, el historial del terminal o un archivo versionado.
python tools/account_access_dev/apply_recovery_template.py
python tools/account_access_dev/apply_recovery_template.py --apply
```

Sin `--apply` solo consulta. Al aplicar envía únicamente
`mailer_subjects_recovery` y `mailer_templates_recovery_content`. Comprueba el
contenido exacto y que las demás propiedades no cambien. No imprime la
configuración completa, credenciales ni tokens. No guarda claves en Flutter.

La API actualiza automáticamente sus dos mapas de indicadores de personalización.
La comprobación admite únicamente el indicador de recuperación dentro de cada
mapa; cualquier cambio en los indicadores de otros correos, permisos, cuotas o
configuración SMTP sigue provocando fallo. Hay cinco regresiones locales:

```powershell
python -B -m unittest discover -s tools/account_access_dev -p test_recovery_template.py
```

## Entrega: comprobación aún abierta

Comprobar envío real, bandeja/spam, identidad del remitente, firma/alineación del
dominio, validación del enlace, nueva contraseña y entrada posterior. No se ha
enviado ningún correo de prueba ni se ha cambiado la contraseña de la cuenta de
Javier. El remitente SMTP de Supabase es común a los correos de Auth, aunque aquí
solo se ha traducido la plantilla de recuperación. Las credenciales permanecen
en servidor y no se versionan.

Comprobaciones del 08/10/2026:

- Dominio `entrenaop.es`, plan activo **Free Business Email**, caducidad mostrada
  `2028-11-05`, **99 de 100 plazas libres**. El formulario ofrece crear el buzón
  sin compra ni cambio de plan.
- Límites mostrados: 1 GB por buzón y 100 envíos cada 24 horas. Esta capacidad
  se utiliza para desarrollo y pruebas; no acredita dimensionamiento comercial.
- Tras la intervención de Javier, el panel muestra «Buzón creado correctamente»
  y `acceso@entrenaop.es` activo, con 98 plazas libres. No se ha cambiado la
  contraseña de ningún buzón previo.
- SMTP documentado por el proveedor: `smtp.hostinger.com`, puerto 465 con TLS
  implícito; alternativa 587 con STARTTLS. Usuario: dirección completa del
  buzón. La contraseña se introduce en los servicios y se conserva fuera del
  repositorio y del chat.
  El panel «Conecta apps y dispositivos» del buzón nuevo confirma host y puerto.
- Consulta DNS pública: MX `mx1.hostinger.com`/`mx2.hostinger.com`, SPF con
  `_spf.mail.hostinger.com`, tres CNAME `hostingermail-{a,b,c}._domainkey` hacia
  sus destinos DKIM de Hostinger, y DMARC `v=DMARC1; p=none`. No se han modificado
  estos registros. La presencia de registros no acredita todavía la firma y
  alineación de un mensaje entregado.
- Tras guardar SMTP y aplicar la plantilla, la consulta de desarrollo confirma
  `smtp.hostinger.com:465`, usuario/remitente `acceso@entrenaop.es`, nombre
  `EntrenaOP`, límite inicial de **30 envíos por hora** e intervalo por usuario
  de **60 segundos**. Este límite de Supabase se combina con los 100 envíos
  diarios de Hostinger; aumentar uno no elimina el otro. No se han ampliado
  cuotas ni reducido controles contra abuso manualmente.
- Asunto y HTML remotos coinciden con los archivos versionados; SHA-256 del HTML
  `10c4d2b975800a3e43cd30e1c86ed1b9b601e043da0c2f35bc8667d04f6bf121`.
  Solo recuperación aparece marcada como personalizada. Segunda aplicación
  idempotente: ninguna escritura y ninguna propiedad inesperada.

La revisión de HTML en navegador con un enlace ficticio no acredita la entrega,
la representación en todos los clientes de correo ni un recorrido autenticado.
El panel de Supabase muestra asunto y cuerpo españoles; en su previsualización
no carga el logotipo externo, aunque la URL es la misma que carga la vista local.
No se atribuye una causa sin comprobarla. La imagen y el resto de la presentación
en un correo recibido forman parte de la prueba de entrega pendiente; el texto
alternativo identifica EntrenaOP cuando la imagen no se muestra.
Las cuotas de Supabase y Hostinger son independientes; subir la cuota del
proyecto o contratar Supabase Pro no amplía el plan de correo de Hostinger.

Validación local del 08/10/2026: HTML/TOML y sintaxis comprobados; simulación de
consulta sin escritura, actualización limitada a las dos propiedades,
idempotencia y detección de cambios ajenos. Las salidas no incluyen el token ni
la contraseña SMTP de las simulaciones. Las consultas de API acreditan la
configuración remota; las simulaciones y regresiones acreditan el verificador
local. Ninguna de estas comprobaciones acredita el envío real pendiente.

Vista revisada en navegador a 320 y 560 píxeles, con enlace ficticio:

![Vista previa del correo; no es un envío real](../../docs/visual-audit/recovery-email-2026-10-08/preview.png)

Fuentes: [plantillas de Supabase](https://supabase.com/docs/guides/auth/auth-email-templates),
[SMTP de Supabase](https://supabase.com/docs/guides/auth/auth-smtp),
[configuración SMTP de Hostinger](https://www.hostinger.com/support/1575756-how-to-get-email-account-configuration-details-for-hostinger-email/),
[buzones de Hostinger](https://www.hostinger.com/support/1583217-how-to-create-and-manage-mailboxes-for-hostinger-email/).
