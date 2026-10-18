# Vídeos de ejercicios · VID-002/003

## Dirección acordada y estado real

Javier elige Bunny Stream para el catálogo y las futuras subidas de entrenadores.
Se empieza por ADMIN y clips oficiales de hasta cinco segundos. El espacio de
entrenadores, sus cuotas comerciales, vídeos largos y enlaces externos opcionales
se implementarán en su bloque, sin exigir cuentas de Vimeo o YouTube.

Base técnica desplegada **solo en entrenaop-dev**. Faltan biblioteca y secretos
de Bunny, subida real y reproducción física/web. La función permanece deshabilitada
sin configuración válida. El bloque funcional sigue abierto. No hay vídeos de
prueba subidos al proveedor ni cambios en producción.

## Preparación de Bunny para el piloto

1. Crear cuenta en [Bunny](https://dash.bunny.net/) y una **Video Library** en
   **Stream**, llamada `entrenaop-dev`. No crear un bucket de Storage para este
   flujo. El alta y la aceptación de condiciones corresponden a Javier.
2. Almacenamiento Frankfurt y entrega Standard. Evitar replicaciones adicionales
   hasta medir costes. Producción tendrá una biblioteca independiente cuando se
   autorice expresamente.
3. Codificación estándar, resoluciones 360p, 480p y 720p. Activar **MP4 Fallback
   antes de subir**; no se genera retroactivamente. No activar Premium Encoding,
   transcripción, IA ni DRM de pago para este piloto.
4. Activar autenticación de token en la **Pull Zone del contenido**, no solo en
   el reproductor insertado. Se usa firma HMAC-SHA256. Verificar con un archivo
   real que su URL sin firma devuelve 403 y la firmada funciona, también en HEAD.
5. Permitir acceso directo **firmado** y CORS para las webs que reproducirán el
   vídeo. No basar la protección móvil en Referer/dominios: los reproductores
   nativos no siempre envían ese encabezado.
6. Guardar estas variables en **Edge Function Secrets de entrenaop-dev**, nunca
   en Flutter, Git, capturas ni chat:

   - `BUNNY_ENVIRONMENT`: `DEVELOPMENT`.
   - `BUNNY_STREAM_LIBRARY_ID`: ID numérico de biblioteca.
   - `BUNNY_STREAM_CDN_HOST`: host `….b-cdn.net`, sin esquema ni ruta.
   - `BUNNY_STREAM_API_KEY`: clave API de **esa biblioteca**, no la cuenta global.
   - `BUNNY_STREAM_TOKEN_KEY`: clave de firma de la Pull Zone de contenido.

7. Probar un clip de cinco segundos: peso, calidad, orientación, arranque,
   pausa y reutilización. No cargar el catálogo entero antes de contrastarlo.
   Revisar uso/saldo en Bunny. Esta tarea no contrata recarga automática ni pagos.

## Servidor, permisos y conservación

`exercise-video` comprueba el JWT contra Auth, la identidad esperada y el permiso
`is_admin()` del llamante. ADMIN reserva y recibe autorización TUS temporal para
un vídeo; el archivo va directamente a Bunny sin exponer su clave. La reserva
serializa veinte subidas por administrador y hora. `exercise_video_assets` queda
cerrada para `anon` y `authenticated`; solo el servidor escribe los estados.

Entrada: hasta 20 MiB. Reproducción: MP4 de 720p, 480p o 360p, en ese orden,
hasta cinco MiB. El servidor consulta estado/duración de Bunny y comprueba el
MP4 final mediante HEAD antes de permitir publicarlo. Estados: `uploading`,
`processing`, `ready`, `rejected`, `failed`. Reconsultar no degrada un `ready`.

Bunny informa duración en segundos enteros: la precisión del máximo de cinco
segundos y los clips inferiores a un segundo requieren prueba real. El límite
de entrada se comprueba en ADMIN y en la reserva declarada, pero la firma TUS no
vincula criptográficamente los bytes. Solo se habilitan administradores de
confianza. Antes de admitir entrenadores se endurecerán tamaño real, cuotas,
propiedad, medición y limpieza de originales/rechazos.

Catálogo e instantáneas conservan `video_url` estable sin firma. Cada sustitución
crea otro ID; no se borran vídeos que puedan seguir referenciados por ejecuciones.
La reproducción busca la referencia exacta y comprueba acceso al ejercicio o a
una instantánea propia mediante RLS. No firma rutas arbitrarias del cliente.
Las firmas caducan a los quince minutos y no se guardan en la base de datos.

No hay borrado automático de subidas descartadas, rechazadas o abandonadas:
se revisan manualmente durante el piloto. El reintento TUS recupera el offset
durante la subida abierta; cerrar o recargar el editor aún no restaura la subida.

## ADMIN, reproducción y caché

ADMIN selecciona, sube por fragmentos, comprueba, previsualiza, sustituye y retira.
No guarda con vídeo pendiente; un fallo conserva la referencia anterior. Subir
no publica: se guarda el ejercicio después. El formulario compartido mantiene
los enlaces personales y no exige cambiar las referencias anteriores.

El deportista carga bajo demanda. Los clips gestionados no muestran URLs
internas ni apertura de una referencia sin firma. Otros proveedores conservan
el comportamiento existente. No se añade autoplay ni bucle automático.

En móvil, caché temporal de hasta veinte MP4 de cinco MiB (100 MiB en total),
caducidad de quince días y expulsión de los antiguos. La clave distingue proyecto,
cuenta y activo; no depende de la firma. Se vuelve a autorizar antes de usar
el archivo: no hay modo sin conexión. En web manda la caché del navegador.

## Verificación y cierre pendiente

- Migración `20261018150520_bunny_exercise_videos.sql`, solo en Dev: historial
  comprobado con 161 migraciones coincidentes. Prueba SQL de permisos, cuotas,
  estados, duración, tamaño y referencia estable con ROLLBACK, sin fixtures.
- Función desplegada en Dev; petición sin JWT: 401; OPTIONS: 204 con CORS.
  Trece pruebas HTTP simuladas cubren permisos, identidad, firma, entorno y estados.
- Análisis limpio y baterías completas: 959 pruebas raíz y 123 ADMIN correctas,
  con una omisión previa en cada una, y doce pruebas del editor compartido.
  Compilaciones web de ambas apps comprobadas.
- Advisor: RLS sin políticas en activos (acceso directo cerrado) y ejecución
  autenticada de la reserva SECURITY DEFINER. Son deliberados: se comprueban
  usuario/admin y cuota, y SQL rechaza al deportista. Referencias de diagnóstico:
  [RLS](https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy),
  [función](https://supabase.com/docs/guides/database/database-linter?lint=0029_authenticated_security_definer_function_executable).
- Pendientes para cerrar: biblioteca/secretos reales, firma/CORS de Bunny,
  precisión de duración, subida real, reproducción física y consumo medido.

Fuentes oficiales: [tarifas](https://bunny.net/docs/stream/pricing),
[TUS](https://bunny.net/docs/stream/tus-resumable-uploads),
[MP4](https://bunny.net/docs/stream/mp4-downloads),
[seguridad](https://bunny.net/docs/stream/security),
[firma HMAC](https://bunny.net/docs/cdn/security/token-authentication/advanced).
