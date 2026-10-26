# Primer acceso y bienvenida

## Alcance autorizado · 26/10/2026

UX-ENTRY-001 descarta las cuatro maquetas exploratorias anteriores.
UX-ENTRY-002 recoge la orientación acordada y Javier autoriza implementarla
en UX-ENTRY-003. Se reutilizan las pantallas y recorridos de entrenamiento
existentes; no hay varias versiones de Inicio, nuevos tipos de usuario ni una
preferencia que cambie permanentemente el destino al abrir la aplicación.

## Comportamiento

Al entrar por el acceso normal o por Inicio, una cuenta que aún no haya
completado la bienvenida recibe una sola pregunta: «¿Por dónde empezamos?».

| Acción | Destino existente |
| --- | --- |
| Usar las herramientas | `/tools`: ritmos y calculadora PAEF/PAFAS |
| Empezar a entrenar | `/home`: Inicio y recorridos actuales |
| Tengo una invitación | `/profile/trainer`: revisión y aceptación del vínculo |
| Omitir y no volver a mostrar | Inicio, con la bienvenida completada |

Las elecciones completan la bienvenida, sin asignar roles ni activar programas,
suscripciones o permisos. Las siguientes entradas normales abren Inicio.
Perfil → Volver a la bienvenida permite abrirla voluntariamente. Las cabeceras
principales incluyen un acceso a Herramientas que conserva la pantalla de
origen; su vuelta directa también permite llegar a Inicio.

La preferencia de cuenta usa exclusivamente
`auth.users.raw_user_meta_data.entry_welcome_completed_v1`. Se consulta Auth
para evitar depender de metadata antigua guardada en otro dispositivo.
Las peticiones fijan el token de la cuenta esperada y descartan respuestas tras
un cambio de identidad, sin reemplazar la sesión del SDK. La escritura envía
solo esa clave y confirma la respuesta. Este dato editable **no participa en
autorización, RLS, nombre del perfil ni derechos comerciales**.

Si falla la lectura, se conserva el acceso normal. Si falla el guardado, se
puede reintentar o continuar por ahora: esta última salida solo omite la
bienvenida en la sesión de aplicación actual y no simula una escritura remota.

## Invitaciones

El código hexadecimal de 64 caracteres existente sigue siendo válido.
También se puede pegar un enlace de la ruta `/invite` con el código en su
fragmento o en el parámetro `code`; se admiten las URLs con estrategia hash de
Flutter web. Solo se extrae un código válido: no se abren destinos externos ni
se permite elegir un retorno arbitrario tras autenticarse.

Una invitación directa prevalece sobre la bienvenida. Si hace falta acceder o
registrarse, el contexto se conserva en memoria y temporalmente en el
dispositivo, usando SharedPreferences con caducidad de 24 horas. Al retomar el
acceso autenticado se consume el contexto guardado. El código no es una sesión
ni acredita un vínculo. La recuperación de contraseña y los errores de enlaces
de Auth conservan prioridad y comportamiento anteriores.

La pantalla consulta la invitación y muestra al preparador. Vincularse sigue
requiriendo pulsar **Aceptar y vincularme** y superar las comprobaciones del
servidor existentes. Editar el código invalida la vista previa. Tras aceptar se
abre el espacio Preparador, sin exigir una preparación propia. La bienvenida
no interrumpe enlaces directos a herramientas, sesiones u otros contenidos.

Este bloque no añade emisión de enlaces en Trainer, Universal Links/App Links,
un nuevo dominio público, contratación ni cambios en las reglas de FAS. El
registro por correo debe completarse en el contexto compatible con el flujo
de Auth existente; no se promete trasladar una invitación entre dispositivos o
navegadores diferentes.

## Verificación y límites

Comprobación local del 26/10/2026: `flutter analyze --no-pub` sin incidencias;
batería completa de la raíz con 1.397 pruebas superadas y una omisión existente;
`flutter build web --debug --no-pub --no-wasm-dry-run
--dart-define=APP_ENV=development` correcto. Las capturas se revisaron en móvil,
escritorio y con texto ampliado. No se ha compilado ni instalado iOS desde Windows.

Las pruebas cubren preferencia remota con metadata local antigua, fallo y
reintento, continuidad temporal, cambio de cuenta con respuestas tardías,
caducidad, retorno seguro, omisión, reapertura y aceptación explícita. Se
conserva la prueba original del historial FAS al cambiar cuenta; las esperas
asíncronas se limitan a los puntos de entrada que las necesitan.

`tools/welcome_visual_test.dart` captura widgets de producción con datos
ficticios, sin red, a 390 y 1100 px y a 320 px con texto doble. La evidencia
está en `docs/visual-audit/welcome-2026-10-26/`. No son imágenes generadas.

La aceptación en el iPhone instalado y una prueba autenticada de extremo a
extremo en ese dispositivo quedan pendientes de instalar esta revisión. No se
declara publicada una versión móvil o un despliegue web remoto por compilar
localmente. No hay migraciones, cambios de RLS, paquetes nuevos ni producción.
