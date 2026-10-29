# Vídeos de ejercicios · VID-002/003

## Dirección acordada y estado real

Javier elige Bunny Stream para el catálogo y las futuras subidas de entrenadores.
Se empieza por ADMIN y clips oficiales de hasta diez segundos. Javier amplía
el máximo el 18/10/2026 para dejar margen a demostraciones de ocho a diez segundos;
los clips pueden seguir durando menos. El espacio de
entrenadores, sus cuotas comerciales, vídeos largos y enlaces externos opcionales
se implementarán en su bloque, sin exigir cuentas de Vimeo o YouTube.

Base técnica y conexión configuradas **solo en entrenaop-dev**. Biblioteca de
Bunny `783236` (`entrenaop-dev`), CDN `vz-728e7240-d7a.b-cdn.net` y cinco secretos
guardados en Edge Function Secrets. No hay claves en Flutter ni en este documento.
Subida real desde ADMIN, publicación y reproducción web completas comprobadas
con el clip de Javier. Faltan aceptación en móvil físico, límites fraccionarios
y consumo medido. El bloque funcional sigue abierto. No hay cambios en producción.

## Preparación de Bunny para el piloto

1. Crear cuenta en [Bunny](https://dash.bunny.net/) y una **Video Library** en
   **Stream**, llamada `entrenaop-dev`. No crear un bucket de Storage para este
   flujo. El alta y la aceptación de condiciones corresponden a Javier.
2. Biblioteca creada por Javier: Frankfurt principal y réplicas existentes en
   Los Ángeles, Nueva York y Singapur. El panel marca $0.03/GB de almacenamiento
   mensual; indica que las réplicas creadas no se pueden retirar. No se añaden más.
   La entrega ya está en High Volume (desde $0.005/GB); se conserva para medir
   arranque real antes de considerar Standard. Producción tendrá una biblioteca
   independiente cuando se autorice expresamente.
3. Codificación estándar, resoluciones 360p, 480p y 720p. Activar **MP4 Fallback
   antes de subir**; no se genera retroactivamente. No activar Premium Encoding,
   transcripción, IA ni DRM de pago para este piloto. Configurados H.264,
   360p/480p/720p; originales y multipista desactivados antes de subir archivos.
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

7. Javier aporta un clip propio de flexiones: 3.008 s, H.264/AAC, 640×360 y
   518853 bytes. Subido desde ADMIN con su sesión administradora; Bunny genera
   MP4 de 249464 bytes a 360p. Ejercicio de desarrollo «Prueba Bunny · Flexiones
   parque», creado expresamente para la aceptación, sin alterar otros ejercicios.
   Probar además clips de cinco y diez segundos: peso, calidad, orientación, arranque,
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

Bunny informa duración en segundos enteros: la precisión del máximo de diez
segundos y los clips inferiores a un segundo requieren prueba real. El límite
de entrada se comprueba en ADMIN y en la reserva declarada, pero la firma TUS no
vincula criptográficamente los bytes. Solo se habilitan administradores de
confianza. Antes de admitir entrenadores se endurecerán tamaño real, cuotas,
propiedad, medición y limpieza de originales/rechazos.

El máximo es una regla de EntrenaOP, no una limitación permanente de Bunny.
Puede ampliarse después coordinando validación del servidor, constraint de la
base de datos mediante una nueva migración, textos de ADMIN y pruebas. No exige
volver a subir los vídeos existentes. Los topes de entrada (20 MiB), reproducción
(5 MiB) y caché móvil (100 MiB) se conservan al pasar de cinco a diez segundos;
la calidad y el peso del clip de diez segundos requieren contraste real.

Catálogo e instantáneas conservan `video_url` estable sin firma. Cada sustitución
crea otro ID; no se borran vídeos que puedan seguir referenciados por ejecuciones.
La reproducción busca la referencia exacta y comprueba acceso al ejercicio o a
una instantánea propia mediante RLS. No firma rutas arbitrarias del cliente.
Las firmas caducan a los quince minutos y no se guardan en la base de datos.

TRN-046 incorpora una cola de limpieza protegida para medios oficiales y privados
en Dev; sustituye la revisión exclusivamente manual de reservas sin uso.
La papelera y el historial siguen conservando sus archivos. El trabajador usa las
API del proveedor y solo libera reservas después del borrado confirmado.
[Contrato y estado](TRAINER_PLATFORM.md#limpieza-protegida-de-medios--trn-046).
El reintento TUS recupera el offset
durante la subida abierta; cerrar o recargar el editor aún no restaura la subida.

## ADMIN, reproducción y caché

ADMIN selecciona, sube por fragmentos, comprueba, previsualiza, sustituye y retira.
No guarda con vídeo pendiente; un fallo conserva la referencia anterior. Subir
no publica: se guarda el ejercicio después. El formulario compartido mantiene
los enlaces personales y no exige cambiar las referencias anteriores.

**VID-005 · portada automática y límites del deportista, 18/10/2026:** al quedar
listo un vídeo oficial, ADMIN solicita la miniatura JPEG que Bunny ya genera.
La función firma únicamente `thumbnail.jpg` del activo registrado/listo, de la
biblioteca configurada y para administradores autenticados. El cliente valida
host/ruta, HTTPS sin redirecciones, MIME JPEG y hasta 2 MiB recibidos; optimiza
con el mismo flujo de foto existente a JPEG de hasta 500 KiB. Se guarda como
imagen oficial al guardar el ejercicio, sin persistir firmas caducables ni
cambiar el esquema. En esta ruta automática no se descarga el MP4 para extraer
el fotograma en el cliente.

Si no hay foto, se aplica automáticamente. Una foto ya elegida o una retirada
explícita se respetan; «Usar portada del vídeo» permite sustituirla expresamente
o reintentar. Un fallo de miniatura mantiene el vídeo listo y permite elegir
foto o guardar sin portada. Cambiar de cuenta o cerrar el editor descarta
resultados tardíos según las comprobaciones de identidad y montaje existentes.

**VID-006 · fotograma elegido, 18/10/2026:** ADMIN web añade «Elegir fotograma»
junto a la portada automática. Abre el vídeo pausado mediante la reproducción
firmada existente y permite buscar un instante con una barra temporal. Espera
el evento de fin de búsqueda antes de habilitar «Usar como portada»; captura
la imagen decodificada que se está mostrando, con la precisión del vídeo/navegador.
No es selección de un número de fotograma ni edición del clip.

La captura usa vídeo HTML con CORS anónimo y canvas, con tamaño máximo 1280×720;
se optimiza por el flujo de foto existente hasta 500 KiB y sustituye la portada
del borrador solo al confirmarla. Se publica al guardar el ejercicio. No cambia
la miniatura de Bunny, no duplica el vídeo ni necesita funciones o esquema nuevos.
Cancelar o fallar conserva la foto; una referencia de vídeo cambiada descarta
la respuesta tardía. Tiempos de carga/búsqueda acotados; cerrar permite reintentar
con una firma nueva. Al cerrar se retiran eventos, temporizadores y fuente de vídeo.
El selector requiere ADMIN web y CORS habilitado por el proveedor; comprobado
con el CDN de desarrollo. `web` 1.1.1, ya resuelto, se declara dependencia directa
para usar las API del navegador; no cambia ninguna versión resuelta.

El deportista normal no puede crear subidas de Bunny ni escribir activos:
el servidor exige administración, además de la ausencia del selector en su UI.
Su campo personal «Enlace externo al vídeo» guarda solo una URL HTTPS, sin
subir, importar ni almacenar una copia de vídeo en Bunny. El vídeo compatible
se reproduce desde ese proveedor; el enlace original conserva su apertura.
El ejercicio personal sigue privado. Los entrenadores con subidas propias y
cuotas siguen fuera del alcance actual. Aclarado el campo personal con ayuda
explícita; no se elimina la referencia externa existente.

El deportista carga bajo demanda. Los clips gestionados no muestran URLs
internas ni apertura de una referencia sin firma. Otros proveedores conservan
el comportamiento existente. No se reproduce al abrir la ficha ni se añade bucle
automático.

**VID-004 · ficha con un único bloque visual, 18/10/2026:** Javier confirma que
el clip se ve bien y aporta capturas de móvil con foto arriba y un segundo bloque
de vídeo debajo. Se sustituye esa duplicación por un único bloque encima de la
descripción, compartido entre Biblioteca y consulta de técnica en sesión. La foto
es portada con Play y permanece durante la carga; al estar listo se reemplaza por
el vídeo en el mismo espacio. Sin vídeo se mantiene la foto habitual. Se respeta
la proporción del archivo dentro del marco; pausa/reproducción y progreso quedan
juntos debajo. El toque en la portada carga e intenta arrancar el clip; si el
navegador exige otra interacción, se conserva el reproductor listo para pulsar
Play sin repetir la inicialización. Reproducir al terminar vuelve al inicio.

UI-050 deja la portada limpia: Play transparente en la esquina inferior derecha,
sin texto visible ni capa oscura sobre la imagen. La portada completa sigue
siendo pulsable, con etiqueta accesible; carga y reintento usan un indicador o
icono en esa misma esquina.

Javier descarta añadir un control para silenciar: cada archivo conserva su audio.
Si no quiere sonido lo subirá sin pista de audio; si necesita voz podrá conservarla.
No se añaden ajustes de volumen/silencio, ni procesamiento de audio, ni reglas
distintas para tutoriales. No se amplía el máximo de diez segundos.

En móvil, caché temporal de hasta veinte MP4 de cinco MiB (100 MiB en total),
caducidad de quince días y expulsión de los antiguos. La clave distingue proyecto,
cuenta y activo; no depende de la firma. Se vuelve a autorizar antes de usar
el archivo: no hay modo sin conexión. En web manda la caché del navegador.

## Verificación y cierre pendiente

- Migraciones `20261018150520_bunny_exercise_videos.sql` y
  `20261018165149_bunny_video_duration_ten_seconds.sql`, solo en Dev: historial
  comprobado con 162 migraciones coincidentes. Prueba SQL de permisos, cuotas,
  estados, duración, tamaño y referencia estable con ROLLBACK, sin fixtures.
- Función desplegada en Dev; petición sin JWT: 401; OPTIONS: 204 con CORS.
  Catorce pruebas HTTP simuladas cubren permisos, identidad, firma, entorno,
  estados y el límite ampliado (cinco/ocho/diez aceptados, más de diez rechazado).
- Análisis limpio y baterías completas: 959 pruebas raíz y 123 ADMIN correctas,
  con una omisión previa en cada una, y doce pruebas del editor compartido.
  Compilaciones web de ambas apps comprobadas.
- Ampliación a diez segundos del 18/10/2026: análisis de ADMIN limpio, ocho
  pruebas de ejercicios y SQL con ROLLBACK correctos. Se conservan las
  comprobaciones iniciales anteriores; no se repite la compilación web por
  este cambio acotado de límite y textos.
- Conexión real del 18/10/2026: biblioteca y cinco secretos configurados; ajustes
  de seguridad comprobados tras cargar otra vez la página. CDN con token activo,
  sin bloqueo por Referer, acceso directo habilitado. HEAD sin firma: 403;
  preflight de la función: 204 y CORS `*`.
- Prueba real del 18/10/2026: una reserva, subida TUS desde ADMIN, procesamiento,
  HEAD firmado y publicación de MP4 360p. Previsualización completa en ADMIN y
  reproducción completa en la app web: `readyState=4`, duración y posición final
  3.008 s, sin error de vídeo. HEAD sin firma del mismo archivo: 403. Referencia
  estable en ejercicio, sin token persistido. Activo
  `c68b82f5-6304-4e64-ba28-f2365121069b`, ejercicio
  `e0d92a09-237b-45be-b98f-ea4fdc8e0fc3`, solo Dev. Las capturas y el archivo
  personal se conservan fuera de los archivos versionados.
- La aceptación descubre un bloqueo previo del catálogo cuando el deportista
  entra con cuenta administradora: la lectura amplia de RLS incluye ejercicios
  privados de terceros y falla al pedir sus fotos en Storage. La consulta del
  deportista se limita a públicos y propios antes de resolver imágenes; no se
  amplían grants/RLS ni se ocultan errores del resto de ejercicios. Dos
  regresiones con HTTP simulado y recorrido real correctos. Análisis raíz limpio
  y batería completa de 967 pruebas correctas, con la omisión previa existente.
- VID-004: análisis raíz limpio, 970 pruebas correctas con la omisión previa;
  19 específicas de vídeo/ficha/biblioteca. Regresiones de portada única,
  sustitución por vídeo, carga bajo demanda, arranque bloqueado, reintento sin
  crear otro reproductor, audio sin modificar, repetición y liberación al cerrar.
  Clip real reproducido en web desde la portada hasta 3.008 s; vista a 390 px
  revisada. Las capturas móviles de Javier acreditan el problema anterior;
  la nueva interfaz y la caché nativa aún requieren contraste en su móvil.
- VID-005: análisis de ambas apps limpios; 970 pruebas raíz y 135 ADMIN correctas
  con una omisión previa por aplicación, catorce del editor compartido y dieciséis
  HTTP del servidor. Portadas de otro host, HTML y tamaño excesivo rechazados;
  preservación de foto elegida, sustitución expresa y reintento sin nueva subida
  cubiertos. SQL transaccional de Bunny correcto y 163 migraciones coincidentes,
  sin migración nueva. Función actualizada solo en Dev. Prueba real sobre el
  mismo vídeo: miniatura obtenida, optimizada y guardada en el ejercicio de prueba
  como JPEG de 42154 bytes, conservando referencia e ID del vídeo. No hay otro
  vídeo subido para esta comprobación. Captura local fuera de Git.
- VID-006: análisis raíz y ADMIN limpios; 139 pruebas ADMIN correctas y una
  omisión previa. Regresiones de aplicación, cancelación, fallo y cambio de vídeo.
  Prueba web real con las flexiones: barra desplazada a 1,51 s, captura aplicada,
  guardada y portada confirmada al reabrir el ejercicio. Capturas locales fuera
  de Git. Sin cambios de servidor, SQL ni permisos; no acredita otros navegadores.
- Advisor: RLS sin políticas en activos (acceso directo cerrado) y ejecución
  autenticada de la reserva SECURITY DEFINER. Son deliberados: se comprueban
  usuario/admin y cuota, y SQL rechaza al deportista. Referencias de diagnóstico:
  [RLS](https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy),
  [función](https://supabase.com/docs/guides/database/database-linter?lint=0029_authenticated_security_definer_function_executable).
- Pendientes para cerrar: precisión de duración (clips reales de cinco/diez
  segundos y fracciones), reproducción/caché en Android/iPhone físico y consumo
  medido. La prueba web no acredita caché nativa, modo sin conexión ni acceso
  real desde una cuenta no administradora; sus permisos conservan pruebas SQL/HTTP.

Fuentes oficiales: [tarifas](https://bunny.net/docs/stream/pricing),
[miniaturas](https://bunny.net/docs/stream/storage-structure),
[TUS](https://bunny.net/docs/stream/tus-resumable-uploads),
[MP4](https://bunny.net/docs/stream/mp4-downloads),
[seguridad](https://bunny.net/docs/stream/security),
[firma HMAC](https://bunny.net/docs/cdn/security/token-authentication/advanced).
