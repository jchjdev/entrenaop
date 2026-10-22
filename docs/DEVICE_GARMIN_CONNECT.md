# Garmin Connect · integración directa · INT-005

## Estado comprobado · 22/10/2026

La aplicación existente `EntrenaOP Dev` utiliza OAuth 2.0 y Starter. Javier ha
activado Training desde API Tools → API Configuration. Después de recargar esa
página se comprueba **Activity y Training: Enabled y Approved**. Health, Women's
Health y Courses están desactivadas. Activity informa cero endpoints activos.
No se crea otra aplicación ni se borra la existente.

El selector de APIs de Edit está deshabilitado: no sirve para ampliar el acceso.
La configuración se realiza en [API Configuration](https://apis.garmin.com/tools/apiConfiguration).
El [caso del foro de mayo de 2026](https://developerportal.garmin.com/node/2496#comment-2349)
orientó esta comprobación, pero la evidencia actual es la página autenticada
recargada, no la extrapolación del antiguo modelo Evaluation/Production.

Habilitar una API en la aplicación no conecta una cuenta de deportista ni
acredita entrega de carreras o de sesiones al reloj. El usuario puede conceder
solo algunos permisos. No se han leído ni conservado valores de Client ID,
Client Secret, tokens o datos deportivos de cuentas Garmin en esta revisión.

## Primer tramo implementado: adaptador OAuth de servidor

`supabase/functions/_shared/garmin/oauth.ts` utiliza HTTP y Web Crypto nativos,
sin paquetes nuevos. No importa Flutter, dominio deportivo ni código de Trainer.
Se contrasta con la especificación autenticada
[OAuth2 PKCE 2.0](https://developerportal.garmin.com/sites/default/files/OAuth2PKCE%202.0.pdf),
páginas 2–6, y con OAuth2 Tools del portal el 22/10/2026.

- Genera `state` y verifier independientes, aleatorios de 256 bits; PKCE S256.
- Construye la autorización en `https://connect.garmin.com/oauth2Confirm` sin
  exponer verifier ni secreto. El retorno HTTPS es configuración del servidor.
- Valida endpoint y state del callback; rechaza parámetros duplicados, retorno
  distinto y mezclas de código/error. **Esta validación no consume un intento
  persistente ni impide por sí sola reutilizar un callback válido.**
- Canjea código/verifier y renueva tokens desde servidor en
  `https://diauth.garmin.com/di-oauth2-service/oauth/token`, con Basic y formulario.
  La renovación devuelve el refresh token nuevo; no hay reintentos automáticos.
- Consulta identidad y permisos en `/partner-gateway/rest/user/id` y
  `/partner-gateway/rest/user/permissions` de `https://apis.garmin.com`.
  `ACTIVITY_EXPORT` acredita lectura autorizada y `WORKOUT_IMPORT` envío autorizado;
  los scopes genéricos del token no sustituyen esa consulta.
- Rechaza tokens/respuestas inválidos, limita la respuesta a 64 KiB y el tiempo
  de petición a diez segundos; no sigue redirecciones ni propaga cuerpos/secretos
  en errores. No interpreta un 400 genérico como revocación del usuario.

Este archivo es un adaptador probado con fixtures, **no una Edge Function
desplegada**, una conexión funcional desde Perfil ni un almacenamiento de tokens.
No se modifica la persistencia de Salud ni se amplía silenciosamente su contrato.

## Único siguiente tramo: autorización persistente por cuenta en Dev

Antes de exponer el callback reservado, conectar un servicio de aplicación con
almacenamiento privado y transaccional de intentos por cuenta/entorno:

1. Inicio autenticado en EntrenaOP y comprobación de la cuenta esperada; guardar
   state/verifier, caducidad y generación. No devolver verifier al cliente.
2. Reclamar el intento una sola vez y comprobar caducidad/generación antes del
   canje. Resolver replay, cambio/borrado de cuenta y llamadas simultáneas en SQL.
3. Consultar identidad/permisos efectivos y asociar por identidad verificada,
   nunca por un propietario enviado por Garmin o por el navegador.
4. Guardar tokens cifrados solo en servidor; serializar renovación y conservar
   el token rotado con CAS. Una respuesta incierta no autoriza renovar a ciegas.
5. Añadir revocación/desconexión y eliminación de cuenta, con invalidación de
   trabajos tardíos y llamada al endpoint de deregistro documentado por Garmin.

Este tramo exige migración, contrato SQL con ROLLBACK, pruebas de concurrencia y
configuración de secretos Dev. Todavía no están implementados ni desplegados.
Después se conectará recepción autenticada de carreras y revisión/guardado en
el historial por cuenta. Training habilitada permite preparar después el envío
explícito de sesiones compatibles; no modifica la prescripción de Trainer.

## Validación de este tramo

`node --test tests/*_test.ts` desde `supabase/functions`: 80 pruebas correctas,
incluidas nueve nuevas de Garmin. Cubren vector PKCE RFC 7636, separación de
state/verifier, callback hostil, petición de canje, rotación, permisos parciales,
errores sanitizados y límites/respuestas inválidas. Son fixtures sin llamadas
reales al proveedor; no acreditan replay transaccional, RLS, renovación concurrente
ni conexión física. No hay cambios en Flutter, SQL, producción o Trainer.
