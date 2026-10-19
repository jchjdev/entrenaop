# Organización del admin local · UI-052 · 19/10/2026

## Alcance confirmado

Javier pide revisar qué está conectado, recuperar herramientas sin acceso y
ordenar el admin con una columna lateral por tipos antes de preparar el
subdominio. Este bloque organiza la aplicación existente en local. No publica
la web, no configura DNS y no cambia producción ni los permisos de servidor.

## Hallazgos y recorrido

La antigua pantalla de Programas reunía el menú general, creación y listado de
preparaciones, accesos comerciales y laboratorio. Programas guiados y
calentamientos se habían añadido como más tarjetas de esa misma portada.
No había un marco común visible al cambiar de catálogo.

El código de `AdminPushUpPolicyLab` tenía pruebas, pero no se importaba desde
ninguna pantalla de producción del admin. Ahora está accesible en Laboratorio,
junto al simulador de fuerza y rendimiento. Ambos consultan el catálogo real
de ejercicios; sus entradas, resultados y progresiones son simulaciones locales.
No escriben resultados de deportistas ni publican prescripciones.

| Grupo | Sección y ruta conservada | Conexión existente |
| --- | --- | --- |
| Contenido | Programas guiados · `/guided-programs` | `guided_programs`, categorías y vínculos; guardado atómico con `save_guided_program`, publicación/retiro con `set_guided_program_status`. Rutinas y programas por fases usan el creador existente. |
| Contenido | Sesiones · `/sessions` | Enlaces `program_workout_templates` de ámbito general y plantillas versionadas; crear, revisar, publicar y retirar con sus RPC administrativas. Publicar aquí alimenta la biblioteca general. |
| Contenido | Calentamientos · `/warmups` | `guided_warmups` y `save_guided_warmup`; versiones reutilizables vinculadas desde programas guiados. |
| Contenido | Ejercicios · `/exercises` | Catálogo oficial y perfiles deportivos; `create_admin_exercise`, `update_admin_exercise`, imágenes en Storage y función `exercise-video` para Bunny y fotogramas. |
| Preparación deportiva | Preparaciones · `/programs` | `preparation_programs`, pruebas, baremos, mínimos, simulación y estrategias; autoría y publicación mediante las RPC existentes. Sus sesiones siguen dentro de `/programs/:id/sessions`, con ámbito de programa. |
| Gestión | Cuentas y Pro · `/accounts` | Directorio, ficha y regalos mediante `admin_list_pro_accounts`, `admin_find_pro_account` y `admin_set_free_pro_access`. Solo aparece con `can_manage_pro_accounts`; COM-017 sigue vigente. |
| Herramientas | Laboratorio · `/laboratory` y `/laboratory/push-ups` | Fuerza/rendimiento y política experimental de flexiones. Lectura del catálogo y cálculo en memoria; sin guardado deportivo. |

Las categorías siguen en el catálogo y creador de Programas guiados; imágenes,
vídeos y baremos siguen junto al recurso al que pertenecen. No se añaden
secciones vacías de Entrenadores, Facturación o Estadísticas.

El 19/10/2026 se consultan exclusivamente metadatos y recuentos de Supabase Dev:
las ocho tablas principales revisadas tienen RLS activado; las dieciséis RPC
principales de autoría/acceso y las cinco de ejercicios/portadas consultadas
están instaladas. Hay cuatro preparaciones, dos programas guiados, tres
calentamientos y 73 registros de ejercicios de origen `system`. El repositorio
de ejercicios excluye de su listado la referencia técnica de carrera.

Esto acredita que existen las conexiones y sus contratos instalados, no una
nueva ejecución autenticada de cada operación ni una auditoría integral de RLS,
del algoritmo o del servicio de vídeo. No se escribe contenido ni se consulta
producción para esta revisión.

## Organización aplicada

- `ShellRoute` mantiene el marco administrativo y las URLs existentes.
  El login queda fuera. La ruta inicial continúa en `/programs`.
- Columna lateral de 248 px desde 1100 px de ventana. En pantallas menores o
  texto superior a 1,5×, un menú lateral desplazable conserva el ancho del editor.
- Grupos, iconos, sección seleccionada y contexto de sección estables.
  Se reutilizan el tema y la marca de `entrena_ui`, sin dependencias nuevas.
- La antigua portada pasa a ser exclusivamente Preparaciones: búsqueda,
  contadores derivados del listado recibido, creación y actualización.
  «Programas guiados» conserva el nombre del catálogo editorial.
- Cambiar de sección usa `go`; abrir un detalle/editor y volver conserva
  `push`/`pop`, resultados y recargas de los catálogos. Los guards existentes
  siguen decidiendo sobre borradores y operaciones pendientes.
- La sesión se cierra desde la cabecera común de los catálogos; desde un editor
  se vuelve primero al catálogo pasando por su guard de borrador. El entorno compilado se indica
  como Desarrollo o Producción, sin selector que cambie de base de datos.
- El permiso de cuentas falla cerrado y permite reintentar sin desmontar el
  catálogo de contenido. Ocultar un acceso no sustituye las comprobaciones de
  las rutas, las RPC ni RLS.

Referencias consultadas: [Atlassian Navigation System](https://atlassian.design/components/navigation-system/layout)
para navegación lateral agrupada y adaptación de pantalla;
[GitLab Pajamas](https://design.gitlab.com/product-foundations/layout/)
para separar navegación persistente del contenido contextual. Se aplican esos
patrones con los componentes Material y la identidad ya existentes.

## Validación y límites

- `flutter analyze` de `admin_app/` sin incidencias.
- Batería completa del admin: 147 pruebas correctas y dos capturas optativas
  omitidas. Las pruebas de publicación, edición, baremos, permisos y borradores
  conservan sus aserciones; se ajusta el desplazamiento a la nueva área visible.
- Ocho regresiones nuevas comprueban todos los destinos, los dos laboratorios,
  la selección desde una URL de editor, salida cancelada/confirmada con borrador,
  permisos comerciales, rechazo administrativo, login separado y menú a
  390 px/320 px con texto 2×.
- Captura adicional ejecutada con `CAPTURE_ADMIN=true`: widgets y router reales
  con repositorios de prueba, marca y fuentes del SDK. Escritorio 1440 × 1000,
  menú móvil 390 × 844 y menú de 320 × 900 con texto 2×, revisados visualmente.
  [Capturas y procedencia](visual-audit/admin-navigation-2026-10-19/README.md).
- Compilación `flutter build web --release` de desarrollo correcta. No se
  modifican migraciones, funciones, grants, paquetes compartidos ni deportista;
  no corresponde una nueva batería de raíz ni SQL transaccional de mutaciones.

## Comprobación autenticada posterior · 19/10/2026

Javier entra en Chrome y aporta una captura con la portada anterior. Se
identifican dos servidores distintos en el mismo puerto: una ejecución antigua
de Flutter en `::1:55555` y la compilación nueva en `127.0.0.1:55555`.
`localhost` resolvía al primero. El JavaScript servido desde localhost era
distinto del build; no era evidencia de un fallo del nuevo marco.

Se detiene únicamente ese proceso antiguo, comprobando antes su comando y
puerto, y se sirve el mismo build en ambos loopbacks. Las dos respuestas HTTP
200 coinciden por SHA-256 con `admin_app/build/web/main.dart.js`. Tras recargar,
Chrome conserva la sesión de Javier y muestra la navegación nueva y las cuatro
preparaciones. No se cambian credenciales ni configuración de Supabase.

Desde esa sesión administrativa se crea y guarda `Prueba ADMIN 19-10-2026`:
un tramo de carrera de 400 m a 6:00/km, con indicaciones explícitas de prueba
técnica que no debe usarse como entrenamiento. Se reabre desde el listado y
se comprueba el contenido. La publicación se confirma desde su diálogo real.
Una consulta de solo lectura en Dev confirma el identificador
`cf3f50a5-0b60-4023-ba1f-7c72e93759ad`, versión 1, estado `published`,
visibilidad `public` y ámbito `general`. No se asigna a planes ni agendas ni se
registra una ejecución deportiva. El contenido de prueba permanece en Dev.

Las capturas `authenticated-desktop.png` y `session-published-admin.png`
acreditan respectivamente la navegación con datos reales y la sesión publicada;
se distinguen de las tres capturas con fixtures. No se modifica código fuente,
esquema o servidor remoto en esta comprobación; no requiere repetir Flutter ni
una prueba transaccional de migraciones.

Tras el acceso personal de Javier a la app de desarrollo en Chrome
(`localhost:55554`), se recorre Biblioteca → Sesiones → Explorar sesiones.
`Prueba ADMIN 19-10-2026` aparece en el catálogo EntrenaOP y abre su vista de
sesión con el mismo identificador, versión 1, un tramo de 400 m a 6:00/km y
la descripción de prueba. Se guardan `session-library-athlete.png` y
`session-preview-athlete.png`. No se pulsa Registrar resultado.

Queda comprobado el recorrido autenticado crear → guardar → reabrir → publicar
en ADMIN → consultar biblioteca y contenido en la app de desarrollo. El único
siguiente tramo recomendado es preparar el acceso administrativo desde el
subdominio, concretando antes alojamiento, entorno y autenticación. No se da por
cerrada toda la autoría ni las revisiones deportivas o de vídeo de otros bloques.
