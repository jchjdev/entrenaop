# Registro y recuperación desde Trainer · 27/10/2026

Javier pide cerrar el alta y la recuperación web sin APK. Los cobros quedan
aplazados y el acceso profesional sigue concediéndose desde ADMIN.

## Recorrido

1. `trainer.entrenaop.es` ofrece **Crear cuenta**, **He olvidado mi contraseña** y
   **Reenviar confirmación de correo** junto al inicio de sesión.
2. El registro recoge nombre, correo y contraseña; exige repetición coincidente
   y al menos ocho caracteres. Usa el mismo Supabase Auth que el deportista,
   sin metadata de roles, Pro o acceso profesional.
3. La persona confirma el correo desde el mismo navegador que inició el alta.
   Si el enlace se confirma en otro perfil/dispositivo y falla PKCE, puede
   iniciar sesión con contraseña; se explica esa salida sin inventar un acceso.
4. La cuenta confirmada ve su estado **Pendiente de habilitación**. Desde ADMIN,
   Javier abre **Cuentas y Pro**, busca su correo y habilita el acceso
   profesional con su cupo, como antes. No necesita crearla desde su teléfono.
5. **Comprobar acceso** detecta la concesión; **Continuar al panel** exige el
   autenticador del propio preparador. Las cuentas con servicio anterior pero
   inactivo conservan su consulta tras MFA. No se incorporan pagos ni compras.

## Recuperación

La solicitud responde de forma genérica y remite al mismo origen web. El
bootstrap procesa una sola vez el callback validado por Supabase, antes de
`go_router`, y limpia código/tokens de la barra y la entrada del historial.
Un query arbitrario `account=recovery` no activa este modo. Un callback fallido
elimina el contexto de recuperación anterior, conservando una salida al login.

La recuperación persiste solamente el UUID de cuenta, separado del estado de la
app del deportista. Contraseñas y códigos no se guardan. Ese UUID no concede
privilegios: cada operación exige la sesión autenticada de esa misma persona.
Cambiar de cuenta invalida el contexto. Si ya tiene factores verificados,
primero se verifica su MFA; no se elimina ni se sustituye el autenticador.
La consulta de factores usa `getUser` con JWT capturado: `listFactors` renueva el
token en el SDK instalado y dispararía otra redirección desde el listener de Auth.

El cambio de contraseña usa el endpoint oficial Auth con el JWT explícito de
la sesión capturada y comprueba el UUID de la respuesta y la identidad vigente.
Así, un cambio concurrente de sesión no dirige la contraseña a otra cuenta.
Después se cierra la sesión local de recuperación y se vuelve a entrar con la
contraseña nueva. No se afirma la revocación de todas las sesiones de otros
navegadores por esta operación local.

## Contrato de servidor y configuración

La migración `20261027204404` añade `get_my_trainer_account_status`, una consulta
previa a MFA que devuelve solo dos booleanos de la cuenta propia confirmada:
si tiene registro/historial profesional y si su acceso está vigente. Rechaza
anónimos, correo no confirmado e identidad esperada distinta. No revela cupos,
alumnos, notas, contenido privado ni datos administrativos. No cambia el
contrato de `get_trainer_access` ni las comprobaciones de MFA existentes.

Aplicada solo en Dev (`sxbxfjqgoddzhtcyhalw`). El contrato SQL transaccional
comprueba alta sin permisos aun con metadata manipulada, consulta ajena denegada,
concesión manual, baja con historial y conservación de MFA, y termina con ROLLBACK.

`tools/account_access_dev/supabase/config.toml` añade únicamente el retorno
`https://trainer.entrenaop.es/`. El diff remoto confirma ese único cambio
declarado; confirma también que el correo sigue requiriendo verificación. Los
retornos de móvil/local existentes y los ajustes SMTP, límites, MFA y plantillas
se conservan. No se aplica el config.toml general de `supabase init`.

Se declaran directamente `shared_preferences 2.5.5` y `http 1.6.0`, ya resueltos
en Trainer: solo cambia su clasificación en el lockfile, sin nuevas versiones.
Se necesitan para conservar el contexto al recargar y fijar el JWT en el cambio
de contraseña. No se incorpora ningún proveedor externo ni coste fijo nuevo.

## Validación y límites

Las pruebas cubren formularios de alta/recuperación, datos genéricos, navegadores
estrechos, confirmación PKCE e implícita, limpieza de callback, persistencia,
petición de contraseña fijada a su cuenta, estado pendiente y alta posterior,
MFA conservado y regreso al panel bloqueado durante la recuperación. Los ensayos
HTTP son simulados y el SQL termina con ROLLBACK. La lectura de configuración
no acredita por sí sola la llegada de un correo nuevo ni el cambio de contraseña
de una persona real: esa aceptación queda para el primer registro desde la web.

El presupuesto se desarrolla en [COST_CONTROL.md](COST_CONTROL.md); no condiciona
el registro a contratar servicios de cobro.


Comprobación local: `flutter analyze` sin incidencias y batería completa de
Trainer con 286 pruebas correctas. Las tres rutas reales prueban entrada pública,
cuenta pendiente sin consultas profesionales, concesión posterior y MFA de
recuperación conservado; nueve ensayos del adaptador y cinco de formularios
completan las regresiones. La prueba real de los creadores existentes conserva
su comportamiento con el estado profesional previo añadido al guard de rutas.
Las 55 pruebas existentes del acceso del deportista pasan sin modificar su código.

`supabase migration list --linked` confirma `20261027204404` aplicada y sin
mismatches en la comprobación. El contrato SQL se ejecuta con ROLLBACK. Los
asesores no señalan las nuevas funciones como públicas definidoras expuestas.
El endpoint público de configuración Auth confirma registro habilitado y correo
con confirmación obligatoria. Ninguna de estas pruebas envía correos de alta
a terceros ni cambia contraseñas de cuentas reales.
