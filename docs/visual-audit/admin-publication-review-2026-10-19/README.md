# Revisión editorial ADMIN · UI-058 · 19/10/2026

Capturas de widgets reales con repositorios sintéticos, router y tema de ADMIN.
No contienen credenciales ni acreditan publicaciones nuevas de contenido en Dev.

- `program-desktop.png`: ficha, fases, comprobaciones y acciones del borrador.
- `program-session-expanded.png`: lector común con bloques, series y descansos.
- `program-mobile-2x.png`: 320 px y escala de texto 2×; contenido desplazable.
- `program-confirm-mobile-2x.png`: confirmación legible con acciones accesibles.

Se generan con `CAPTURE_ADMIN_REVIEW=true` desde las pruebas de la revisión.
Los controles de publicación usan repositorios de prueba; no mutan catálogos reales.
El favicon de ADMIN se contrasta con el recurso existente `web/favicon.png`.
`github-actions-success.png` acredita la publicación automática de `7cca2bc`
en la ejecución 39245586883. `deployed-build-info.json` conserva el manifiesto
público contrastado de forma independiente junto al SHA-256 del JavaScript y
las cabeceras. `hosted-program-warmup.png` y `hosted-program-session.png` muestran
la revisión del programa real y su sesión, con el calentamiento, objetivos y
descansos. Estas últimas capturas usan contenido Dev existente; no lo modifican.

`hosted-running-session-review.png` muestra la revisión independiente de una
sesión de carrera ya existente, con tramos, ritmo y panel editorial. Sin publicar,
retirar ni editar contenido durante esta comprobación.

`hosted-program-review.png` conserva la vista previa tras recargar directamente
su URL estable, con identidad, categorías y fases conservadas.
