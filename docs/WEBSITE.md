# Web pública de EntrenaOP

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

## Propuesta local

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

Se conservan las entradas de entrenadores y administración solicitadas en
WEB-003, desactivadas y marcadas como en construcción hasta disponer de sus
destinos. La presencia de iOS y Android no incluye enlaces inventados a tiendas.
La política existente mantiene su contenido.

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
