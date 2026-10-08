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

**Estado al 08/10/2026:** asunto y contenido de recuperación preparados para
desarrollo, pero **no aplicados**. La API rechaza la modificación con HTTP 400:
el plan gratuito con el proveedor de correo predeterminado requiere configurar
SMTP propio para personalizar las plantillas. La consulta posterior confirma
que siguen el asunto original y la ausencia de SMTP propio. No se ha comprado
ningún plan. **Javier ha creado `acceso@entrenaop.es` y el panel confirma el
buzón activo**, con 98 de 100 plazas libres. La contraseña se ha completado en
Hostinger, sin pasar por el chat. SMTP permanece pendiente de introducir la
credencial en Supabase; el buzón aún no es el remitente del servicio Auth.
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

## Buzón y entrega: tareas aún abiertas

1. Entrar en el panel de Supabase y configurar SMTP **solo en desarrollo**.
   Host `smtp.hostinger.com`, puerto 465, usuario y remitente
   `acceso@entrenaop.es`, nombre `EntrenaOP`. Javier introduce allí la contraseña
   del buzón; no usar la credencial de su dirección personal. El remitente SMTP de
   Supabase es común a los correos de Auth, aunque aquí solo se ha traducido la
   plantilla de recuperación. Las credenciales permanecen en servidor.
2. Aplicar la plantilla mediante el script y comprobar tanto el asunto como
   el HTML remoto. No repetir la aplicación mientras no cambie el bloqueo SMTP.
3. Comprobar envío real, bandeja/spam, identidad del remitente, validación del
   enlace, nueva contraseña y entrada posterior. No se ha enviado ningún correo
   de prueba ni se ha cambiado la contraseña de la cuenta de Javier.

Comprobación del panel del 08/10/2026, antes de crear el buzón:

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
- Supabase de desarrollo conserva SMTP sin configurar y la plantilla original.
  El panel web necesita iniciar sesión aunque el acceso del CLI ya funciona.

La revisión de HTML en navegador con un enlace ficticio no acredita la entrega,
la representación en todos los clientes de correo ni un recorrido autenticado.
El proveedor predeterminado de Supabase limita destinatarios y envíos; esta
configuración de plantilla no elimina esos límites.

Validación local del 08/10/2026: HTML/TOML y sintaxis comprobados; simulación de
consulta sin escritura, actualización limitada a las dos propiedades,
idempotencia y detección de cambios ajenos. Las salidas no incluyen el token ni
la contraseña SMTP de las simulaciones. Esto valida la preparación local, no
el envío pendiente ni la aplicación remota rechazada.

Vista revisada en navegador a 320 y 560 píxeles, con enlace ficticio:

![Vista previa del correo; no es un envío real](../../docs/visual-audit/recovery-email-2026-10-08/preview.png)

Fuentes: [plantillas de Supabase](https://supabase.com/docs/guides/auth/auth-email-templates),
[SMTP de Supabase](https://supabase.com/docs/guides/auth/auth-smtp),
[configuración SMTP de Hostinger](https://www.hostinger.com/support/1575756-how-to-get-email-account-configuration-details-for-hostinger-email/),
[buzones de Hostinger](https://www.hostinger.com/support/1583217-how-to-create-and-manage-mailboxes-for-hostinger-email/).
