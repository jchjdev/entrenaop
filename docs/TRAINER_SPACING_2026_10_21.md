# Espaciado de fichas profesionales · 21/10/2026

Javier señala con capturas acciones pegadas en Planificación y resultados y
etiquetas sin separación en Notas del preparador. Se añaden márgenes entre
conversación/asignación/programa, antes de las pautas y entre tarjetas; en notas,
entre título, explicación, revisión, campos, aviso de reintento y guardado.
No cambian navegación, permisos, contenido ni contratos de servidor.

## Validación y publicación

- Fuentes: `72728238126eea4c04c419e07b1f9117c8131672`, subidas a `main`.
- Release Dev: `72728238126eea4c04c419e07b1f9117c8131672-20261021-10`.
- ZIP: `build/trainer-spacing-release-20261021.zip`.
- SHA-256 ZIP: `539d23fb7496d7a5e61488e569e5a651b9c053f7fc71b00605fe36f016079ffa`.
- SHA-256 JavaScript: `dc075ef250f486d61887e45a939860951710465ebd422632cb2bd09e61dda2cf`.

Compilación desde una copia temporal limpia de ese `main`, en
`build/trainer-layout-source`: no incorpora el editor/ADMIN ni otros cambios en
curso del directorio compartido. El empaquetador verifica HEAD y fuentes limpias.
Análisis Trainer sin incidencias, 137 pruebas correctas y compilación web
correcta. Las 19 pruebas de las dos pantallas pasan también por separado; el
test de reintento desplaza la lista hasta el campo antes de comprobar el texto,
conservando sus aserciones sobre operación, contenido y revisión.

Se inspeccionan capturas de widgets reales con fixtures, sin red: escritorio
1200 px, móvil 390 px y 320 px con texto 2x; seis capturas sin excepciones.
La herramienta temporal queda en el build ignorado, sin añadir otra batería de
pruebas que replique los márgenes.

El ZIP se carga en `trainer-releases`, fuera de la raíz pública, y se extrae
solo después de confirmar `/files/public_html/trainer/` en el selector, con
nombre `.` y sobrescritura. Conserva las releases previas. El verificador HTTPS
confirma manifiesto, versión, hash JS, entrada, cabeceras y MIME.

Chrome comprueba ficha y planificación de la cuenta de prueba existente, sin
escribir notas ni asignar/retirar pautas. La pestaña de trabajo del usuario no
se recarga. Las capturas publicadas se recortan a los controles afectados para
excluir identidad, agenda y resultados del alumno:

- [Notas publicadas](visual-audit/trainer-spacing-2026-10-21/notas-dev-publicado.png).
- [Acciones publicadas](visual-audit/trainer-spacing-2026-10-21/acciones-dev-publicado.png).
- [Planificación con fixture](visual-audit/trainer-spacing-2026-10-21/planning-desktop.png).
- [Notas con fixture y texto 2x](visual-audit/trainer-spacing-2026-10-21/notes-mobile-text2x.png).

Cambio limitado al portal Trainer Dev. No modifica componentes compartidos,
ADMIN, la app del deportista, migraciones ni producción.
