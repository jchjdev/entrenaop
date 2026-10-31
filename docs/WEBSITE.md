# Web pública de EntrenaOP

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
