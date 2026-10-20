# UI-062 · widgets reales · 20/10/2026

Capturas generadas por `flutter test`, con datos sintéticos y tipografías reales.
No son capturas de la cuenta de Javier ni prueba de aceptación en iPhone.

- [Series en ADMIN](series-admin.png): pantalla administrativa real con valores
  por serie, usada también en la regresión de conservación de la receta.
- [Campos compartidos en escritorio](series-escritorio.png): valores comunes y excepciones,
  etiquetas separadas del título de cada serie, RIR histórico conservado.
- [Series en móvil](series-movil.png): distribución adaptada al ancho.
- [Panel dentro del programa](panel-programa.png): el creador existente conserva
  el contexto de montaje y ofrece Guardar en programa, sin publicación de sesión.
- [Panel con texto ampliado](panel-texto-ampliado.png): cierre accesible y contenido
  desplazable a 320 px con texto 2×.

Generación optativa: `CAPTURE_PERFORMANCE_REVIEW=true` en los tests de
`workout_editor_page_test.dart` y `admin_guided_authoring_flow_test.dart`.
No se cambian opciones de fuente o zoom de las aplicaciones del usuario.
