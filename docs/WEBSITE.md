# Web pública de EntrenaOP

## Portada con grabación real · WEB-008 · 31/10/2026

Javier descarta que la imagen anterior represente por sí sola la oferta actual
y elige una grabación real de EntrenaOP para el espacio visual de portada.
El 31/10 Javier autoriza preparar la demo y grabarla, manteniendo todo en local.
La imagen se sustituye en `website/next/` por una grabación de la interfaz real,
con datos ficticios. La web publicada y las aplicaciones publicadas no cambian.

### Resultado local · 31/10/2026

- Portada: `assets/athlete-demo.mp4`, H.264, 390 × 844, 20 fps, 30,25 segundos,
  sin audio. Inicio, plan, semana, biblioteca, detalle de ejercicio, comparación
  de marcas, espacio del preparador y conversación de ejemplo.
- Página Trainer: `assets/trainer-demo.mp4`, H.264, 1280 × 800, 20 fps,
  15,05 segundos, sin audio. Cuatro alumnos, ficha, agenda y conversación.
- Los formatos se separan para conservar legibilidad en cada página. Hay
  pósteres WebP, pausa/reproducción, enlace al vídeo grande y rótulo de datos
  ficticios. Se intenta reproducción automática en bucle cuando el vídeo está
  visible; se respeta movimiento reducido y se pausa fuera de vista o al ocultar
  la pestaña. El navegador puede requerir que el usuario pulse reproducir.
- `tools/promo/` y `trainer_app/tool/promo/` contienen entradas de demo, datos y
  recorridos. Reutilizan widgets y Cubits existentes con repositorios en memoria.
  No inicializan Supabase, push ni compras; no crean cuentas, derechos o datos en
  Dev/producción. No modifican los `main.dart`, rutas o Cubits de producto.
- `tools/promo/record.ps1` reproduce los recorridos, captura los fotogramas
  reales del motor Flutter y los codifica con FFmpeg. No son pantallas dibujadas
  para el vídeo ni una sucesión de capturas históricas. Fuentes y limitaciones
  en `tools/promo/README.md`. PNG y manifiestos originales en `build/promo/`.
- Los builds navegables se sirven en `http://127.0.0.1:8780/` y
  `http://127.0.0.1:8781/` con `node tools/promo/serve.mjs`. Solo los recorridos
  preparados están conectados; las demás rutas muestran un aviso de demo.
  Cada proceso tiene datos locales: no se simula un backend compartido real.
- La maqueta se revisa con Live Server en `http://127.0.0.1:5500/`. Mantener
  abierta su ventana de VS Code. Las demos tienen servidor propio separado.

Comprobaciones: análisis de Flutter en raíz y Trainer sin incidencias, dos
recorridos de grabación correctos, script completo de exportación correcto,
compilaciones web de ambas demos y revisión de los vídeos en navegador con
vistas de 1440 y 390 px. Las dos páginas cargan los MP4 y sus dimensiones sin
errores; pausa/reproducción y pausa fuera de vista contrastadas. No equivale a
una prueba en un iPhone físico ni valida las funciones ajenas a la demo.
Capturas en `website/reviews/2026-10-31-video/`.
Copia recuperable completa de la web: `docs/audits/website-2026-10-31-video.bundle`,
con el commit local `14f2faf`. Se conserva la copia anterior y no se añade un
gitlink ni un remoto al repositorio independiente.

### Guion de demostración propuesto · 31/10/2026

Javier pide preparar alumnos y contenido ficticios para poder grabar la app.
Se propone una pieza de aproximadamente 25–30 segundos, sin sonido y en bucle,
con una indicación discreta de datos de demostración. No se atribuirán mejoras
deportivas, opiniones ni resultados comerciales a clientes reales.

| Personaje ficticio | Uso en la demostración |
| --- | --- |
| Lucía Vega | Deportista protagonista: semana con fuerza y carrera, sesión pendiente y resultados de ejemplo. |
| Dani Torres | Alumno que trabaja la carrera; aparece en el listado profesional y en su agenda. |
| Nora Martín | Alumna con trabajo de dominadas y una revisión técnica de ejemplo. |
| Marcos Vidal | Alumno centrado en mantener su condición física, con seguimiento reciente. |

El preparador se identifica como «Entrenador demo». No hacen falta correos,
teléfonos ni fotografías personales. Los nombres, estados y resultados son
material de demostración, no personas ni historiales de entrenamiento reales.

| Tiempo orientativo | Escena propuesta con pantallas existentes |
| --- | --- |
| 0–4 s | Inicio y preparación de Lucía. |
| 4–9 s | Mi plan y organización de su semana. |
| 9–14 s | Biblioteca y vista de una sesión guiada. |
| 14–19 s | Registro o consulta de resultados de ejemplo. |
| 19–25 s | Trainer: alumnos, agenda y seguimiento del mismo caso. |
| 25–30 s | Vuelta al espacio con el preparador en la app del deportista. |

Hay herramientas de capturas con widgets reales y repositorios ficticios en
`tools/athlete_navigation_visual_test.dart` y
`trainer_app/tool/capture_clients.dart`. Son base de trabajo; no constituyen
una grabación de navegación ni una app demo completa.

El guion anterior orienta el rodaje; el resultado se concreta en dos piezas
según la relación de pantallas del apartado «Resultado local». La demo utiliza
las fronteras de repositorio existentes. No se han necesitado altas en Dev ni
cambios en los Cubits, rutas de producción o reglas de negocio.

Para recorrer y revisar la maqueta se mantiene Live Server en
`http://127.0.0.1:5500/`. El servidor auxiliar `preview.mjs` utiliza el puerto
8765. El origen elegido debe permanecer abierto durante la revisión: cerrar
el servidor anterior dejaba sin servicio sus enlaces HTTP.

## App del deportista y oferta Trainer · WEB-007 · 31/10/2026

Javier pide renovar la maqueta tras la evolución de la app y la existencia del
portal profesional. La portada `website/next/index.html` presenta el recorrido
del deportista, incluyendo biblioteca, sesiones propias y trabajo con su
preparador. `website/next/trainers.html` explica por separado las herramientas y
la propuesta comercial para entrenadores. Ambas páginas comparten navegación
e identidad, sin construir un segundo panel.

El registro, acceso y contratación se enlazan con las rutas existentes:

- `https://trainer.entrenaop.es/#/register`.
- `https://trainer.entrenaop.es/#/login`.
- `https://trainer.entrenaop.es/#/subscription`.

Se contrasta el formulario público de registro y la redirección a login al
abrir contratación sin sesión. El guard de Trainer sigue resolviendo identidad,
estado de acceso y seguridad. No se añaden formularios de alta ni se envían
importes, capacidades o identificadores de producto desde la maqueta.

La comparativa usa los importes provisionales de
[TRAINER_PRICING_DRAFT.md](TRAINER_PRICING_DRAFT.md): cinco tramos de 5/10/20/50/100
alumnos activos y tres niveles. Un selector cambia los tres importes; el extra
opcional de directorio suma 4,90 EUR/mes únicamente al Básico. Hay una tabla
completa que permite consultar los precios sin JavaScript.

La página identifica los precios y prestaciones como orientativos, pendientes
de cierre y en pruebas. Directorio incluido en Profesional/Completo; Pro personal
propuesto en Profesional y cobertura de alumnos activos propuesta en Completo.
No se ofrece algoritmo profesional ni almacenamiento ilimitado. Se explican
las exclusiones del cupo: «Para mí», alumnos inactivos/archivados e invitaciones
pendientes. El alumno no necesita Pro para recibir y ejecutar lo pautado.

Los enlaces de contratación abren el catálogo de ensayo vigente del portal,
que puede diferir de esta propuesta: no crean un Checkout desde la web pública.
No se modifica el catálogo ni el servidor, ni se activan cobros reales.
El rediseño sigue siendo local y conserva `website/dist/` y la web publicada.

### Comprobación · 31/10/2026

Portada de Trainer servida por HTTP local con respuesta 200. Sintaxis de los
tres scripts y 48 referencias/capturas locales correctas. Se prueban en navegador
los 15 precios base y los cinco totales con directorio opcional, conservando
los importes de Profesional/Completo; la tabla completa coincide.

Ambas páginas conservan el ancho disponible en viewports 320, 390, 768 y 1280.
El mayor tramo con extra también cabe a 320. Navegación entre espacios y nueva
vista del preparador del deportista comprobadas; sin errores de consola
observados. Capturas en `website/reviews/2026-10-31/`. El registro remoto se
inspecciona sin enviar datos y contratación sin sesión redirige al login.
No se crean usuarios, compras ni permisos para verificar esta maqueta.

## Enfoque acordado · WEB-004 · 16/10/2026

La web se diseña para presentar EntrenaOP cuando la aplicación esté preparada
para su lanzamiento. Su mensaje explica qué aporta el producto y a quién ayuda:
opositores, personal de las Fuerzas Armadas de Tierra, Armada, Aire y Espacio,
Guardia Civil y militares que preparan un ascenso.

Javier descarta organizar esta presentación según lo que está o no implementado
en cada programa. No será un catálogo de preparaciones ni una exposición del
roadmap. La descripción pública es general: preparación física vinculada al
objetivo, plan adaptado al contexto, entrenamiento semanal y seguimiento de
marcas y resultados. Este criterio editorial no cambia la cobertura del MVP,
las reglas deportivas ni el estado de implementación documentados en producto.

## Propuesta inicial · 16/10/2026

El borrador sigue en `website/next/`. HTML, CSS y JavaScript sin dependencias
ni servicios externos. La página puede abrirse como archivo o con
`node preview.mjs`, que sirve únicamente en `127.0.0.1:8765`.

Referencias solicitadas:

- [Calisteniapp](https://calisteniapp.com/es): protagonismo de la app y explicación
  visual de lo que aporta al entrenamiento.
- [Kotcha](https://www.kotcha.com/en): fotografía deportiva, jerarquía tipográfica
  y mensajes breves.

La composición mantiene el naranja y la identidad de EntrenaOP. La portada
utiliza una fotografía original generada con ImageGen. Las pantallas de la app
proceden de las revisiones visuales existentes del proyecto, con datos de ejemplo;
no se han dibujado funciones inexistentes ni añadido testimonios o estadísticas.
El selector de funciones cambia entre plan, semana y marcas. Las preguntas
frecuentes usan controles nativos de HTML.

Las entradas de entrenadores y administración solicitadas en WEB-003 quedaron
inicialmente desactivadas y marcadas como en construcción. WEB-007 sustituye
esos marcadores por la presentación Trainer y enlaces a los portales existentes.
La presencia de iOS y Android no incluye enlaces inventados a tiendas. La
política existente mantiene su contenido.

El alcance es local: `website/dist/` y el alojamiento no forman parte de este
rediseño. El guardado se realiza con commits locales y una copia del historial
independiente de `website/` en `docs/audits/`.

## Comprobación del borrador · 16/10/2026

- Vista HTTP local con respuesta 200; sintaxis de `site.js` y `preview.mjs`
  correcta.
- 23 referencias locales entre portada y privacidad comprobadas sin incidencias.
- Revisión de geometría a 320, 390, 768 y 1280 píxeles de viewport: contenido
  dentro del ancho disponible, descontando la barra de desplazamiento.
- Capturas de portada en móvil y escritorio y de producto en
  `website/reviews/2026-10-16/`.
- Selector de plan/semana/marcas comprobado, con una única opción activa y
  anuncio accesible; preguntas frecuentes y navegación a privacidad comprobadas.
- Sin errores de consola observados. Accesos profesionales desactivados.
- No se cambia la aplicación Flutter, el contenido legal ni la versión publicada.
